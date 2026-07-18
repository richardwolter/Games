class_name PrepMenu
extends Control
## Pre-battle preparation screen — the game's main scene.
##
## The player prepares the whole run in one place (GDD loop steps 1-2 + upgrades):
## per hero — include in party, assign a battlefield priority, and open the
## hero's skill tree page (SkillTreePage) to spend banked XP on tree nodes.
## START BATTLE persists the config and loads the battlefield.
## Placeholder UI in the notebook palette; real styling comes with the HUD pass.

const BATTLEFIELD := "res://scenes/battlefield/battlefield.tscn"
## Stage progression order; the selector appears once stage 1 is beaten.
const STAGE_IDS := ["stage_1", "stage_2", "stage_3"]

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
}

var _hero_ui := {}
var _start_button: Button
var _stage_option: OptionButton
var _main: VBoxContainer
var _tree_page: SkillTreePage

func _ready() -> void:
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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	root.add_child(row)
	for hero_name in GameState.HERO_CATALOG:
		row.add_child(_build_hero_card(hero_name))

	if GameState.stage_1_won:
		root.add_child(_build_stage_row())
	else:
		# Only one stage reachable — make sure no stale override lingers.
		GameState.stage_override = ""

	_start_button = Button.new()
	_start_button.text = "START BATTLE"
	_start_button.add_theme_font_size_override("font_size", 30)
	_start_button.pressed.connect(_on_start)
	root.add_child(_start_button)

	var footer_text := "(F12 = reset save)" if GameState.stage_1_won \
			else "Stage 1 — Dark Mage      (F12 = reset save)"
	var footer := _label(footer_text, 16)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(footer)

## Stage picker, shown once stage 1 is beaten. Defaults to the furthest
## unlocked stage (or this session's earlier pick) and records the choice in
## GameState.stage_override, which BattleManager reads on battle load.
func _build_stage_row() -> HBoxContainer:
	var stage_row := HBoxContainer.new()
	stage_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_row.add_theme_constant_override("separation", 12)
	stage_row.add_child(_label("Stage", 20))

	_stage_option = OptionButton.new()
	_stage_option.add_theme_font_size_override("font_size", 20)
	for stage_id in STAGE_IDS:
		var config: StageConfig = load("res://config/%s_config.tres" % stage_id)
		_stage_option.add_item(config.stage_name)
	var current := STAGE_IDS.find(GameState.stage_override)
	_stage_option.selected = current if current != -1 else STAGE_IDS.size() - 1
	GameState.stage_override = STAGE_IDS[_stage_option.selected]
	_stage_option.item_selected.connect(func(idx: int) -> void:
		GameState.stage_override = STAGE_IDS[idx])
	stage_row.add_child(_stage_option)
	return stage_row

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

func _build_hero_card(hero_name: String) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.6)
	style.border_color = INK_COLOR
	style.set_border_width_all(3)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(2)
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(_build_portrait(hero_name))

	var blurb := _label(HERO_BLURB.get(hero_name, ""), 14)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
	blurb.custom_minimum_size = Vector2(150, 0)
	box.add_child(blurb)

	var selected := CheckBox.new()
	selected.text = hero_name
	selected.button_pressed = GameState.party_of(hero_name).selected
	selected.add_theme_font_size_override("font_size", 24)
	for color_key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		selected.add_theme_color_override(color_key, Color("2c2c2c"))
	selected.toggled.connect(func(on: bool) -> void:
		GameState.set_selected(hero_name, on)
		_refresh())
	box.add_child(selected)

	box.add_child(_label("Priority", 16))
	var pri := OptionButton.new()
	for key in GameState.PRIORITIES:
		pri.add_item(GameState.PRIORITIES[key])
	pri.selected = GameState.PRIORITIES.keys().find(GameState.party_of(hero_name).priority)
	pri.item_selected.connect(func(idx: int) -> void:
		GameState.set_priority(hero_name, GameState.PRIORITIES.keys()[idx]))
	box.add_child(pri)

	var xp_label := _label("", 18)
	box.add_child(xp_label)
	var stats_label := _label("", 15)
	box.add_child(stats_label)

	var upgrades_btn := Button.new()
	upgrades_btn.text = "UPGRADES"
	upgrades_btn.add_theme_font_size_override("font_size", 20)
	upgrades_btn.pressed.connect(_open_skill_tree.bind(hero_name))
	box.add_child(upgrades_btn)

	_hero_ui[hero_name] = {"xp": xp_label, "stats": stats_label}
	return card

## Swap the prep layout for the hero's skill tree page; restore on close.
func _open_skill_tree(hero_name: String) -> void:
	_main.visible = false
	_tree_page = SkillTreePage.new(hero_name)
	_tree_page.closed.connect(_close_skill_tree)
	add_child(_tree_page)

func _close_skill_tree() -> void:
	_tree_page.queue_free()
	_tree_page = null
	_main.visible = true
	_refresh()

func _on_start() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file(BATTLEFIELD)

func _refresh() -> void:
	for hero_name in _hero_ui:
		var ui: Dictionary = _hero_ui[hero_name]
		ui.xp.text = "XP: %d      points: %d" % [GameState.xp_of(hero_name), GameState.level_of(hero_name)]
		ui.stats.text = "HP %d   DMG %d   ATK %.2fs   SPD %d" % [
			100 + int(GameState.bonus_max_hp(hero_name)),
			12 + int(GameState.bonus_damage(hero_name)),
			0.5 * GameState.attack_interval_mult(hero_name),
			70 + int(GameState.bonus_move_speed(hero_name))]
	_start_button.disabled = GameState.selected_heroes().is_empty()

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
