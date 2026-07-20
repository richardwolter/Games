class_name LevelUpScreen
extends CanvasLayer
## In-run level-up overlay (Milestone 1): a hero levelled up — pause the battle
## and offer 1 of 3 run boons for THAT hero. Emits `picked` with the chosen boon
## id; BattleManager applies it live (Hero.apply_run_boon) and tears the overlay
## down. Styling matches the notebook palette (see results_screen.gd / prep_menu.gd).
##
## process_mode is ALWAYS so the buttons still take input while the tree is
## paused behind the overlay.

signal picked(boon_id: String)

## Palette shared with the sibling battle overlay (ResultsScreen) — single
## source so the two screens can't drift apart visually.
const PAGE_COLOR := ResultsScreen.PAGE_COLOR
const INK_COLOR := ResultsScreen.INK_COLOR
const BORDER_COLOR := ResultsScreen.BORDER_COLOR
const ACCENT := ResultsScreen.UNLOCK_COLOR

var _picked := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

## Build the overlay for `hero_name` with the given boon id offer.
func setup(hero_name: String, offer: Array) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = PAGE_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(3)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := _label("%s — LEVEL %d!" % [hero_name, RunState.level_of(hero_name)], 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)

	var subtitle := _label("Choose a boon (this run only)", 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(cards)

	for id in offer:
		cards.add_child(_build_card(id))

## One selectable boon card (a Button with name + description).
func _build_card(id: String) -> Button:
	var d := Boons.def(id)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(220, 120)
	btn.text = "%s\n\n%s" % [d.get("name", id), d.get("desc", "")]
	btn.add_theme_font_size_override("font_size", 22)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, INK_COLOR)
	# Signature (hero-specific) boons get an accent border so the "your hero's
	# own card" reads at a glance against the generic offers.
	if d.has("hero"):
		var sig_style := StyleBoxFlat.new()
		sig_style.bg_color = PAGE_COLOR
		sig_style.border_color = ACCENT
		sig_style.set_border_width_all(3)
		sig_style.set_content_margin_all(8)
		for s in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(s, sig_style)
	btn.pressed.connect(_on_pick.bind(id))
	return btn

func _on_pick(id: String) -> void:
	if _picked:
		return
	_picked = true
	picked.emit(id)

func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", INK_COLOR)
	return l
