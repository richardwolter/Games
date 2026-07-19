class_name PrepMenu
extends Control
## Pre-battle preparation screen — the game's main scene.
##
## The player prepares the whole run in one place (GDD loop steps 1-2): per
## hero — include in party, assign a battlefield priority. Base stats/abilities
## are flat and intrinsic (Milestone 2 — power now grows only in-run via
## RunState boons); persistent meta-currency/unlocks live behind the
## account-wide UNLOCK SHOP button (see UnlockShopPage), not per hero.
## START BATTLE persists the config and loads the battlefield.
## Placeholder UI in the notebook palette; real styling comes with the HUD pass.

const BATTLEFIELD := "res://scenes/battlefield/battlefield.tscn"

## Notebook-page palette, matching the battlefield's hand-inked look
## (see stage_field.gd) so the prep screen reads as the same world.
const PAGE_COLOR := Color("f4efe1")
const RULE_COLOR := Color("aac4dd")
const MARGIN_COLOR := Color("d98f8f")
const INK_COLOR := Color("161412")

## Per-hero portrait (face crop of the full-body sketch) and a short
## description grounded in the shipped ability, not invented lore/mechanics.
## Source wording matches hero.gd's ability comments / PRODUCTION.md.
const HERO_PORTRAIT := {
	"THUNDAAR": {"path": "res://assets/sprites/Thundaar.png", "region": Rect2(947, 150, 620, 620)},
}
const HERO_BLURB := {
	"THUNDAAR": "Stomp — AoE damage + knockback",
	"ARTEMIS": "Clone — taunting stand-in",
	"WARDEN": "Ensnare — roots enemy clusters",
	"BEACON": "Rally — buffs nearby allies",
}

var _start_button: Button
var _main: VBoxContainer
var _shop_page: UnlockShopPage
var _currency_label: Label
var _hero_row: HBoxContainer

func _ready() -> void:
	# Milestone 3: re-roll the draft offer every time the prep screen loads
	# (start of a new run, or returning here after a win/loss).
	RunState.roll_draft_offer()
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var bg := PrepPage.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	_main = root

	var title := _label("SEMI-SECRET WARS — PREPARE YOUR RUN", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	root.add_child(_build_meta_row())

	_hero_row = HBoxContainer.new()
	_hero_row.add_theme_constant_override("separation", 32)
	root.add_child(_hero_row)
	_rebuild_hero_row()

	_start_button = Button.new()
	_start_button.text = "START RUN"
	_start_button.add_theme_font_size_override("font_size", 30)
	_start_button.pressed.connect(_on_start)
	root.add_child(_start_button)

	# Every run begins at Level 1 (progression is knowledge + gold, not stage
	# unlocks) — no stage picker.
	var footer := _label("Level 1 — the run begins here      (F12 = full reset)", 16)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(footer)

## Meta-currency total + the single account-wide unlock-shop button
## (Milestone 2 — replaces the old per-hero UPGRADES button, since currency
## and unlocks aren't hero-scoped).
func _build_meta_row() -> HBoxContainer:
	var meta_row := HBoxContainer.new()
	meta_row.alignment = BoxContainer.ALIGNMENT_CENTER
	meta_row.add_theme_constant_override("separation", 16)

	_currency_label = _label("", 18)
	meta_row.add_child(_currency_label)

	var shop_btn := Button.new()
	shop_btn.text = "ABILITY SHOP"
	shop_btn.add_theme_font_size_override("font_size", 18)
	shop_btn.pressed.connect(_open_shop)
	meta_row.add_child(shop_btn)
	return meta_row

## Face portrait cropped from the hero's full-body sketch, ink-outlined to
## match the notebook style. Heroes with no art yet (Artemis — no sprite
## exists in assets/sprites/) get a color-tagged placeholder instead.
const PORTRAIT_SIZE := 84.0

func _build_portrait(hero_name: String) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4efe1")
	style.border_color = INK_COLOR
	style.set_border_width_all(3)
	style.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)

	var portrait: Dictionary = HERO_PORTRAIT.get(hero_name, {})
	if portrait.is_empty():
		var placeholder := ColorRect.new()
		placeholder.color = Color(GameState.HERO_CATALOG[hero_name].color, 0.35)
		placeholder.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
		frame.add_child(placeholder)
		return frame

	var atlas := AtlasTexture.new()
	atlas.atlas = load(portrait.path)
	atlas.region = portrait.region
	var face := TextureRect.new()
	face.texture = atlas
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	frame.add_child(face)
	return frame

## Rebuilds the hero row from RunState.draft_offer. Called on load and after
## every checkbox toggle, since a pick at the cap changes which of the other
## offered heroes' checkboxes are disabled.
func _rebuild_hero_row() -> void:
	for child in _hero_row.get_children():
		child.queue_free()
	for hero_name in GameState.unlocked_heroes:
		_hero_row.add_child(_build_hero_card(hero_name))

func _build_hero_card(hero_name: String) -> PanelContainer:
	var offered := RunState.is_offered(hero_name)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.6)
	style.border_color = INK_COLOR
	style.set_border_width_all(3)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(2)
	card.add_theme_stylebox_override("panel", style)
	if not offered:
		card.modulate = Color(1, 1, 1, 0.4)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(_build_portrait(hero_name))

	var blurb_text: String = HERO_BLURB.get(hero_name, "")
	if not offered:
		blurb_text += "\n(not offered this run)"
	var blurb := _label(blurb_text, 14)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
	blurb.custom_minimum_size = Vector2(150, 0)
	box.add_child(blurb)

	var selected := CheckBox.new()
	selected.text = hero_name
	selected.button_pressed = RunState.is_selected(hero_name)
	# Milestone 3: cap enforcement — once PARTY_CAP heroes are picked, the
	# remaining unpicked (but offered) checkboxes disable rather than letting
	# a new pick silently bump an existing one.
	selected.disabled = not offered or (not RunState.is_selected(hero_name) and RunState.party.size() >= RunState.PARTY_CAP)
	selected.add_theme_font_size_override("font_size", 24)
	for color_key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		selected.add_theme_color_override(color_key, Color("2c2c2c"))
	selected.toggled.connect(func(on: bool) -> void:
		RunState.toggle_selected(hero_name, on)
		_rebuild_hero_row()
		_refresh())
	box.add_child(selected)

	var hero_priority: String = GameState.party_of(hero_name).priority

	box.add_child(_label("Priority", 16))
	var pri := OptionButton.new()
	for key in GameState.PRIORITIES:
		pri.add_item(GameState.PRIORITIES[key])
	pri.selected = GameState.PRIORITIES.keys().find(hero_priority)
	pri.disabled = not offered
	pri.item_selected.connect(func(idx: int) -> void:
		GameState.set_priority(hero_name, GameState.PRIORITIES.keys()[idx])
		_rebuild_hero_row())
	box.add_child(pri)

	# Support-target control: only meaningful (and only shown) while this
	# hero's priority is SUPPORT_ALLIES — picks which specific ally to shadow
	# instead of always chasing the nearest one.
	if RunState.is_selected(hero_name) and hero_priority == "SUPPORT_ALLIES":
		box.add_child(_build_support_target_row(hero_name))

	# Base stats are flat now (Milestone 2 — no persistent upgrades), so this
	# can render once from Hero.HERO_STATS instead of refreshing from GameState.
	var stats: Dictionary = Hero.HERO_STATS.get(hero_name, {})
	var atk_interval: float = Hero.ARTEMIS_ATTACK_INTERVAL if hero_name == "ARTEMIS" \
			else float(stats.get("attack_interval", 0.5))
	var stats_label := _label("HP %d   DMG %d   ATK %.2fs   SPD %d" % [
		int(stats.get("base_hp", 100)),
		int(stats.get("base_damage", 10)),
		atk_interval,
		int(stats.get("move_speed", 70))], 15)
	box.add_child(stats_label)

	return card

## Support-target picker for one SUPPORT_ALLIES hero: [Nearest Ally] + every
## other drafted hero. Choosing one makes this hero shadow that specific ally
## instead of always chasing whichever is nearest; "Nearest Ally" clears it.
func _build_support_target_row(hero_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_label("Follow", 16))

	var current: String = GameState.party_of(hero_name).get("support_target", "")
	var others: Array = RunState.selected_heroes().filter(
			func(h: String) -> bool: return h != hero_name)

	var opt := OptionButton.new()
	opt.add_item("Nearest Ally")
	opt.set_item_metadata(0, "")
	var selected_idx := 0
	for other in others:
		opt.add_item(other)
		opt.set_item_metadata(opt.item_count - 1, other)
		if other == current:
			selected_idx = opt.item_count - 1
	opt.selected = selected_idx
	# Nothing to target yet (only this hero drafted): show a disabled control.
	opt.disabled = others.is_empty()
	opt.item_selected.connect(func(idx: int) -> void:
		var chosen: String = opt.get_item_metadata(idx)
		GameState.set_support_target(hero_name, chosen)
		_rebuild_hero_row())
	row.add_child(opt)
	return row

## Swap the prep layout for the account-wide unlock shop; restore on close.
func _open_shop() -> void:
	_main.visible = false
	_shop_page = UnlockShopPage.new()
	_shop_page.closed.connect(_close_shop)
	add_child(_shop_page)

func _close_shop() -> void:
	_shop_page.queue_free()
	_shop_page = null
	_main.visible = true
	_refresh()

func _on_start() -> void:
	# A brand-new run: reset per-run state (levels, boons, HP carryover, fallen
	# heroes) to a clean Level 1. Chained level-to-level transitions do NOT come
	# through here, so they preserve that state. Party draft is untouched.
	RunState.start_run()
	GameState.save_game()
	get_tree().change_scene_to_file(BATTLEFIELD)

func _refresh() -> void:
	_start_button.disabled = RunState.selected_heroes().is_empty()
	if _currency_label != null:
		_currency_label.text = "Gold: %d" % GameState.gold

func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("2c2c2c"))
	return l

## Ruled notebook-paper background, matching the battlefield's page draw
## (stage_field.gd _draw_page) so the prep screen reads as the same world.
class PrepPage extends Control:
	const RULE_SPACING := 42.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, PrepMenu.PAGE_COLOR, true)
		var y := fmod(RULE_SPACING, RULE_SPACING)
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), PrepMenu.RULE_COLOR, 1.5, true)
			y += RULE_SPACING
		var mx := size.x * 0.08
		draw_line(Vector2(mx, 0), Vector2(mx, size.y), PrepMenu.MARGIN_COLOR, 2.0, true)
