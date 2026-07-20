class_name LanePrepMenu
extends Control
## V2 (lane-structure) prep screen — the parallel testing build's entry point.
##
## Deliberately leaner than the old V1 PrepMenu: party draft + gold/ability
## shop only. No priority/support-target pickers — heroes just push the lane,
## which is why the reused Hero code needs no priority changes. START loads
## the lane battlefield.

const LANE_BATTLEFIELD := "res://v2/battlefield/lane_battlefield.tscn"

var _start_button: Button
var _currency_label: Label
var _xp_label: Label
var _hero_row: HBoxContainer
var _main: VBoxContainer
var _abilities_page: AbilitiesPage
var _stats_page: StatsPage

func _ready() -> void:
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

	var title := _label("SEMI-SECRET WARS — V2 LANE TEST", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var meta_row := HBoxContainer.new()
	meta_row.alignment = BoxContainer.ALIGNMENT_CENTER
	meta_row.add_theme_constant_override("separation", 16)
	_currency_label = _label("", 18)
	meta_row.add_child(_currency_label)
	_xp_label = _label("", 18)
	meta_row.add_child(_xp_label)
	var abilities_btn := _button("ABILITIES", 18, _open_abilities)
	meta_row.add_child(abilities_btn)
	var stats_btn := _button("STATS", 18, _open_stats)
	meta_row.add_child(stats_btn)
	root.add_child(meta_row)

	_hero_row = HBoxContainer.new()
	_hero_row.add_theme_constant_override("separation", 32)
	root.add_child(_hero_row)
	_rebuild_hero_row()

	_start_button = _button("START RUN", 30, _on_start)
	root.add_child(_start_button)

	var footer := _label("Lane 1 — push right, destroy the spawn gates, reach the lair      (F12 = full reset)", 15)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(footer)

func _rebuild_hero_row() -> void:
	for child in _hero_row.get_children():
		child.queue_free()
	for hero_name in GameState.HERO_CATALOG:
		if GameState.is_hero_unlocked(hero_name):
			_hero_row.add_child(_build_hero_card(hero_name))
		else:
			_hero_row.add_child(_build_locked_hero_card(hero_name))

func _build_hero_card(hero_name: String) -> PanelContainer:
	var offered := RunState.is_offered(hero_name)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.6)
	style.border_color = Color("161412")
	style.set_border_width_all(3)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	if not offered:
		card.modulate = Color(1, 1, 1, 0.4)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var swatch := ColorRect.new()
	swatch.color = Color(GameState.HERO_CATALOG[hero_name].color, 0.6)
	swatch.custom_minimum_size = Vector2(120, 60)
	box.add_child(swatch)

	var selected := CheckBox.new()
	selected.text = hero_name
	selected.button_pressed = RunState.is_selected(hero_name)
	# Uncapped (Designer, 2026-07-19): every offered hero can be selected.
	selected.disabled = not offered
	selected.add_theme_font_size_override("font_size", 22)
	for color_key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		selected.add_theme_color_override(color_key, Color("2c2c2c"))
	selected.toggled.connect(func(on: bool) -> void:
		RunState.toggle_selected(hero_name, on)
		_rebuild_hero_row()
		_refresh())
	box.add_child(selected)

	box.add_child(_label(_current_stats_text(hero_name), 13))

	return card

## Base hero stats with permanent StatUpgrades purchases applied — same
## formula hero.gd uses at spawn (_apply_stat_upgrades) — so this reads as the
## hero's actual current stats, not just the flat catalog baseline.
func _current_stats_text(hero_name: String) -> String:
	var stats: Dictionary = Hero.HERO_STATS.get(hero_name, {})
	var atk_interval: float = Hero.ARTEMIS_ATTACK_INTERVAL if hero_name == "ARTEMIS" \
			else float(stats.get("attack_interval", 0.5))
	var hp_n := GameState.stat_purchase_count(hero_name, "hp")
	var dmg_n := GameState.stat_purchase_count(hero_name, "damage")
	var aspd_n := GameState.stat_purchase_count(hero_name, "attack_speed")
	var hp: float = float(stats.get("base_hp", 100)) * (1.0 + float(StatUpgrades.def("hp").get("effect_per_purchase", 0.0)) * hp_n)
	var dmg: float = float(stats.get("base_damage", 10)) * (1.0 + float(StatUpgrades.def("damage").get("effect_per_purchase", 0.0)) * dmg_n)
	atk_interval /= 1.0 + float(StatUpgrades.def("attack_speed").get("effect_per_purchase", 0.0)) * aspd_n
	return "HP %d  DMG %d  ATK %.2fs  SPD %d" % [
		int(round(hp)), int(round(dmg)), atk_interval, int(stats.get("move_speed", 70))]

## Card for a not-yet-unlocked hero: shows the achievement gating it (name +
## live career progress) instead of the draft/priority controls. Locked heroes
## already fall out of the draft automatically (RunState.roll_draft_offer reads
## GameState.unlocked_heroes) — this card is purely informational.
func _build_locked_hero_card(hero_name: String) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.6)
	style.border_color = Color("161412")
	style.set_border_width_all(3)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	card.modulate = Color(1, 1, 1, 0.4)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var swatch := ColorRect.new()
	swatch.color = Color(GameState.HERO_CATALOG[hero_name].color, 0.6)
	swatch.custom_minimum_size = Vector2(120, 60)
	box.add_child(swatch)

	box.add_child(_label("%s — LOCKED" % hero_name, 20))

	var ach_id := Achievements.for_hero(hero_name)
	if ach_id != "":
		var d := Achievements.def(ach_id)
		box.add_child(_label(d.get("name", ach_id), 15))
		box.add_child(_label(_achievement_progress_text(d), 13))
	return card

## "84/150 minions" style progress line for a locked hero's achievement.
func _achievement_progress_text(d: Dictionary) -> String:
	var stat: String = d.get("stat", "")
	var threshold = d.get("threshold", 0)
	var current = GameState.career.get(stat, 0)
	if stat == "best_villain_damage_pct":
		return "%d%% / %d%% villain damage" % [int(float(current) * 100.0), int(float(threshold) * 100.0)]
	return "%d / %d %s" % [int(current), int(threshold), stat.replace("_", " ")]

func _open_abilities() -> void:
	_main.visible = false
	_abilities_page = AbilitiesPage.new()
	_abilities_page.closed.connect(_close_abilities)
	add_child(_abilities_page)

func _close_abilities() -> void:
	_abilities_page.queue_free()
	_abilities_page = null
	_main.visible = true
	_refresh()

func _open_stats() -> void:
	_main.visible = false
	_stats_page = StatsPage.new()
	_stats_page.closed.connect(_close_stats)
	add_child(_stats_page)

func _close_stats() -> void:
	_stats_page.queue_free()
	_stats_page = null
	_main.visible = true
	_rebuild_hero_row()  # banked XP may have changed — refresh the card display
	_refresh()

func _on_start() -> void:
	RunState.start_run()
	GameState.save_game()
	get_tree().change_scene_to_file(LANE_BATTLEFIELD)

func _refresh() -> void:
	_start_button.disabled = RunState.selected_heroes().is_empty()
	if _currency_label != null:
		_currency_label.text = "Gold: %d" % GameState.gold
	if _xp_label != null:
		_xp_label.text = "Banked XP: %d" % GameState.banked_xp

func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("2c2c2c"))
	return l

func _button(text: String, font_size: int, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(cb)
	return b
