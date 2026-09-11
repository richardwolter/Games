## The ground's sliders. F4 to show or hide; debug builds only.
##
## The ground is built in code (`Lake._shape_bank`, `_shape_island`), so there is no
## inspector to tune it in. This is the inspector: one slider per number the ground shader
## takes, pushed to both layers as it moves, and every setting written to
## `user://ground_tune.log` so a picked value can be copied into `Ground`'s constants
## afterwards and the panel closed for good.
##
## The beach cannot be tuned thinner than the dog walks: `Dog.BEACH_WALK` (3.0) and
## `Iso.BEACH_LITTER` (2.4) both count on sand out to about 3.5 tiles, so the wander's
## amplitude is clamped to what keeps `beach_width - wander_amp` past `BEACH_FLOOR`.
class_name GroundTuner
extends CanvasLayer

const LOG_PATH := "user://ground_tune.log"
const BEACH_FLOOR := 3.5

## What is tunable: name, the least and most it goes to, the step, and whether moving it
## has to lay the props out again (only the numbers that move the line, or the tufts).
const ROWS := [
	["beach_width", 3.5, 8.0, 0.1, true],
	["wander_amp", 0.0, 2.0, 0.05, true],
	["wander_scale", 60.0, 600.0, 10.0, true],
	["wander_fine", 0.0, 1.0, 0.05, true],
	["patch_size", 1.0, 10.0, 0.5, false],
	["patch_wander", 0.0, 0.5, 0.02, false],
	["fringe_mode", 0.0, 2.0, 1.0, false],
	["fringe_depth", 0.0, 8.0, 1.0, false],
	["fringe_share", 0.0, 1.0, 0.05, false],
	["lip", 0.0, 1.0, 1.0, false],
	["tuft_share", 0.0, 1.0, 0.02, true],
	["tuft_reach", 0.0, 3.0, 0.1, true],
]

var grounds: Array[Ground] = []

var _panel: PanelContainer
var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _resow_pending: bool = false


func _ready() -> void:
	layer = 30
	visible = false
	_panel = PanelContainer.new()
	# Named for test_lake's CLICK_EATERS: a slider panel is meant to keep clicks off the
	# water while it is up.
	_panel.name = &"GroundTuner"
	_panel.position = Vector2(16, 16)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Ground (F4)  —  values in user://ground_tune.log"
	box.add_child(title)
	var first := grounds[0] if not grounds.is_empty() else null
	for row: Array in ROWS:
		var key: String = row[0]
		var line := HBoxContainer.new()
		var name := Label.new()
		name.custom_minimum_size.x = 110
		name.text = key
		line.add_child(name)
		var slider := HSlider.new()
		slider.custom_minimum_size.x = 220
		slider.min_value = row[1]
		slider.max_value = row[2]
		slider.step = row[3]
		var start: float = _read(first, key) if first != null else row[1]
		slider.value = start
		_values[key] = start
		line.add_child(slider)
		var shown := Label.new()
		shown.custom_minimum_size.x = 56
		shown.text = _fmt(start)
		line.add_child(shown)
		box.add_child(line)
		_sliders[key] = [slider, shown]
		slider.value_changed.connect(_on_slid.bind(key, row[4]))
		slider.drag_ended.connect(_on_dropped.bind(row[4]))
	add_child(_panel)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F4:
		return
	visible = not visible
	get_viewport().set_input_as_handled()


func _read(ground: Ground, key: String) -> float:
	var v: Variant = ground.get(key)
	if v is bool:
		return 1.0 if v else 0.0
	return float(v)


func _fmt(v: float) -> String:
	return "%.2f" % v if absf(v - roundf(v)) > 0.001 else "%d" % int(roundf(v))


## A slider moved: keep the beach past the floor, push the numbers, and if the line moved,
## lay the props out again when the drag ends rather than on every tick of it.
func _on_slid(value: float, key: String, resows: bool) -> void:
	_values[key] = value
	if key == "beach_width" or key == "wander_amp":
		var most := maxf(_values["beach_width"] - BEACH_FLOOR, 0.0)
		if _values["wander_amp"] > most:
			_values["wander_amp"] = most
			var amp: Array = _sliders["wander_amp"]
			(amp[0] as HSlider).set_value_no_signal(most)
			(amp[1] as Label).text = _fmt(most)
	(_sliders[key][1] as Label).text = _fmt(value)
	for ground in grounds:
		for k: String in _values:
			var v: float = _values[k]
			if k == "lip":
				ground.set(k, v >= 0.5)
			elif k == "fringe_mode":
				ground.set(k, int(roundf(v)))
			else:
				ground.set(k, v)
		ground.retune(false)
	_resow_pending = _resow_pending or resows
	_log()


func _on_dropped(_changed: bool, resows: bool) -> void:
	if not (resows or _resow_pending):
		return
	_resow_pending = false
	for ground in grounds:
		ground.retune(true)


func _log() -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	for row: Array in ROWS:
		var key: String = row[0]
		file.store_line("%s = %s" % [key, _fmt(_values[key])])
	file.close()
