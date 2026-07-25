class_name LevelUpScreen
extends CanvasLayer
## Start-of-level pick overlay: BattleManager queues one of these per living
## Duo in _ready(), before deploy. Each pauses the battle and offers all three
## of that Duo Ultimate's boons (DuoUltimateBoons — a straight pick-1-of-3).
## Emits `picked` with the chosen id; BattleManager routes it to
## RunState.add_duo_boon, then tears the overlay down.
##
## History: introduced 2026-07-21 for per-hero ability boons, generalized
## 2026-07-22 to also drive the per-Duo round via a `def_resolver` Callable.
## The per-hero round was dropped 2026-07-25 (see duo_ultimate_boons.gd), so
## only the Duo catalog is left — `def_resolver` is kept because it costs
## nothing and keeps the overlay catalog-agnostic.
## Styling matches the notebook palette (see results_screen.gd / prep_menu.gd).
##
## process_mode is ALWAYS so the buttons still take input while the tree is
## paused behind the overlay.

signal picked(id: String)

## Paper/ink/borders all come from UIStyle now (see UIStyle.overlay_panel and
## UIStyle.card) — the only colour this screen still names for itself is the
## pick accent, shared with ResultsScreen's unlock banner.
const ACCENT := UIStyle.GOLD

var _picked := false
## Resolves an offered id to its {name, desc, ...} def. Only ever
## DuoUltimateBoons.def today; see the class doc.
var _def_resolver: Callable = DuoUltimateBoons.def

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

## Build the overlay with `title`/`subtitle` and one card per id in `offer`,
## resolved through `def_resolver` (DuoUltimateBoons.def).
func setup(title_text: String, subtitle_text: String, offer: Array, def_resolver: Callable) -> void:
	_def_resolver = def_resolver
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", UIStyle.overlay_panel())
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	box.add_child(UIStyle.centered_label(title_text, UIStyle.SIZE_TITLE, ACCENT))
	box.add_child(UIStyle.centered_label(subtitle_text, UIStyle.SIZE_BODY))

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 22)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(cards)

	for i in offer.size():
		cards.add_child(_build_card(offer[i], i))

## One selectable card (a Button with name + description), resolved via
## _def_resolver — catalog-agnostic. `variant`
## just picks which hand-drawn corner wobble this card gets, so a row of
## cards doesn't read as identical stamped rectangles.
func _build_card(id: String, variant: int) -> Button:
	var d: Dictionary = _def_resolver.call(id)
	var btn := UIStyle.button("%s\n\n%s" % [d.get("name", id), d.get("desc", "")],
			UIStyle.SIZE_SUBHEAD, _on_pick.bind(id))
	btn.custom_minimum_size = Vector2(300, 170)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Every option in either catalog is always hero/Duo-specific (no generic
	# pool on either side), so this accent border always applies.
	var sig_style := UIStyle.card(ACCENT, 8, variant)
	for s in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(s, sig_style)
	return btn

func _on_pick(id: String) -> void:
	if _picked:
		return
	_picked = true
	picked.emit(id)

