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
var buff_label: RichTextLabel
var _ko := false
var _focused := false

func _ready() -> void:
	name_label = find_child("NameLabel", true, false) as Label
	level_label = find_child("LevelLabel", true, false) as Label
	hp_bar = find_child("HPBar", true, false) as ProgressBar
	cooldown_indicator = find_child("CooldownLabel", true, false) as Label
	cooldown_bar = find_child("CooldownBar", true, false) as ProgressBar
	buff_label = find_child("BuffLabel", true, false) as RichTextLabel
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

func update_display(hero_name_in: String, level: int, current_hp: int, max_hp: int, cooldown_remaining: float, cooldown_max: float = 1.0, buffs: Array = [], intent: String = "") -> void:
	if name_label == null or level_label == null or hp_bar == null or cooldown_indicator == null:
		return

	name_label.text = hero_name_in
	# Level line doubles as the live intent readout (what the hero is doing now),
	# so the pre-battle priority/pairing choices are legible during the fight.
	level_label.text = "LV %d  ·  %s" % [level, intent] if intent != "" else "LV %d" % level
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp

	if cooldown_bar != null:
		var fraction := 1.0 - clampf(cooldown_remaining / maxf(cooldown_max, 0.001), 0.0, 1.0)
		cooldown_bar.value = fraction

	if cooldown_remaining > 0.0:
		cooldown_indicator.text = "COOLDOWN: %.1f" % cooldown_remaining
		cooldown_indicator.add_theme_color_override("font_color", Color("b08a3e"))
	else:
		cooldown_indicator.text = "READY"
		cooldown_indicator.add_theme_color_override("font_color", Color("5c7a3f"))

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

func set_ko() -> void:
	if _ko or cooldown_indicator == null:
		return
	_ko = true
	hp_bar.value = 0
	if cooldown_bar != null:
		cooldown_bar.value = 0
	cooldown_indicator.text = "DOWN"
	cooldown_indicator.add_theme_color_override("font_color", Color("c63d3d"))
	if buff_label != null:
		buff_label.text = ""
	modulate = Color(0.72, 0.72, 0.72, 0.85)
