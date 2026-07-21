class_name HeroPanelUI
extends PanelContainer
## Displays a single hero's status: name, level, HP bar, cooldown indicator.
## Clicking the panel asks the battle camera to lock onto this hero (via HUD).

signal clicked(hero_name: String)

const FOCUS_COLOR := Color("b08a3e")

var hero_name := ""

var name_label: Label
var level_label: Label
var hp_bar: ProgressBar
var cooldown_indicator: Label
var cooldown_bar: ProgressBar
var cooldown_indicator2: Label
var cooldown_bar2: ProgressBar
var buff_label: RichTextLabel
## Live per-run readout: kills, XP gained, special-ability hit rate (see
## GameState.hero_kills_run/hero_xp_run/hero_ability_pct_run). Prep menu shows
## the lifetime equivalents — see PrepMenu._build_hero_card.
var run_stats_label: Label
var _ko := false
var _focused := false

func _ready() -> void:
	name_label = find_child("NameLabel", true, false) as Label
	level_label = find_child("LevelLabel", true, false) as Label
	hp_bar = find_child("HPBar", true, false) as ProgressBar
	cooldown_indicator = find_child("CooldownLabel", true, false) as Label
	cooldown_bar = find_child("CooldownBar", true, false) as ProgressBar
	cooldown_indicator2 = find_child("CooldownLabel2", true, false) as Label
	cooldown_bar2 = find_child("CooldownBar2", true, false) as ProgressBar
	buff_label = find_child("BuffLabel", true, false) as RichTextLabel
	run_stats_label = find_child("RunStatsLabel", true, false) as Label
	# The panel itself is the click target; children must not swallow the click.
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if hp_bar != null:
		hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(hero_name)
		accept_event()

## Gold name while the camera is locked onto this hero.
func set_focused(focused: bool) -> void:
	if focused == _focused or name_label == null:
		return
	_focused = focused
	if _focused:
		name_label.add_theme_color_override("font_color", FOCUS_COLOR)
	else:
		name_label.remove_theme_color_override("font_color")

func update_display(hero_name_in: String, level: int, current_hp: int, max_hp: int, cooldown_remaining: float, cooldown_max: float = 1.0, buffs: Array = [], intent: String = "", ability_name: String = "", second_name: String = "", second_remaining: float = 0.0, second_max: float = 1.0, kills: int = 0, xp_gained: int = 0, ability_pct: float = -1.0) -> void:
	if name_label == null or level_label == null or hp_bar == null or cooldown_indicator == null:
		return

	# Undo the grey-out set_incoming() applies while waiting on the deploy
	# timer — without this the panel stayed dimmed forever once the hero
	# actually arrived on the field (set_incoming's modulate was never reset).
	modulate = Color.WHITE

	name_label.text = hero_name_in
	# Level line doubles as the live intent readout (what the hero is doing now),
	# so the pre-battle priority/pairing choices are legible during the fight.
	level_label.text = "LV %d  ·  %s" % [level, intent] if intent != "" else "LV %d" % level
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp

	_set_cooldown_row(cooldown_indicator, cooldown_bar, ability_name, cooldown_remaining, cooldown_max)

	# Second ability row (LV20 Shockwave/Multishot); heroes without one hide it.
	if cooldown_indicator2 != null and cooldown_bar2 != null:
		var has_second := second_name != ""
		cooldown_indicator2.visible = has_second
		cooldown_bar2.visible = has_second
		if has_second:
			_set_cooldown_row(cooldown_indicator2, cooldown_bar2, second_name, second_remaining, second_max)

	if buff_label != null:
		if buffs.is_empty():
			buff_label.text = ""
		else:
			var parts: Array[String] = []
			for buff in buffs:
				parts.append("[color=#%s]%s[/color]" % [(buff["color"] as Color).to_html(false), buff["text"]])
			# One buff per line: joining on spaces let RichTextLabel's word-wrap
			# break mid-row, stacking wrapped lines on top of the fixed-height
			# BuffLabel rect once 2+ buffs were active. Newlines make each buff
			# own a line, so fit_content grows the label's minimum height
			# instead of overlapping.
			buff_label.text = "\n".join(parts)

	if run_stats_label != null:
		var abl_text := "%d%%" % int(round(ability_pct)) if ability_pct >= 0.0 else "—"
		run_stats_label.text = "KILLS %d  ·  XP %d  ·  ABL %s" % [kills, xp_gained, abl_text]

## Fills one ability cooldown label+bar: "NAME  READY" when up, "NAME  2.1"
## while cooling, in the shared gold/green palette.
func _set_cooldown_row(label: Label, bar: ProgressBar, ability_name: String, remaining: float, cd_max: float) -> void:
	var prefix := ("%s  " % ability_name) if ability_name != "" else ""
	if bar != null:
		bar.value = 1.0 - clampf(remaining / maxf(cd_max, 0.001), 0.0, 1.0)
	if remaining > 0.0:
		label.text = "%s%.1f" % [prefix, remaining]
		label.add_theme_color_override("font_color", Color("b08a3e"))
	else:
		label.text = "%sREADY" % prefix
		label.add_theme_color_override("font_color", Color("5c7a3f"))

func set_ko() -> void:
	if _ko or cooldown_indicator == null:
		return
	_ko = true
	hp_bar.value = 0
	if cooldown_bar != null:
		cooldown_bar.value = 0
	cooldown_indicator.text = "DOWN"

## Second-Duo-wave hero not on the field yet (still counting down to its
## staggered arrival) — distinct from set_ko() so waiting doesn't read as
## dead. No _ko-style latch: called every frame while waiting, since the
## countdown text needs to keep updating.
func set_incoming(seconds_left: float) -> void:
	if name_label == null or level_label == null or hp_bar == null or cooldown_indicator == null:
		return
	name_label.text = hero_name
	level_label.text = "ARRIVES IN %ds" % int(ceil(seconds_left))
	hp_bar.value = hp_bar.max_value if hp_bar.max_value > 0 else 100
	if cooldown_bar != null:
		cooldown_bar.value = 0
	cooldown_indicator.text = "—"
	cooldown_indicator.add_theme_color_override("font_color", Color("c63d3d"))
	if cooldown_bar2 != null:
		cooldown_bar2.value = 0
	if cooldown_indicator2 != null and cooldown_indicator2.visible:
		cooldown_indicator2.text = "DOWN"
		cooldown_indicator2.add_theme_color_override("font_color", Color("c63d3d"))
	if buff_label != null:
		buff_label.text = ""
	modulate = Color(0.72, 0.72, 0.72, 0.85)
