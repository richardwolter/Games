## Does the pad's pointer click where it points? A button off the middle of a stretched
## window, the pointer driven onto it through `Pad`, and A pressed and let go through
## `Pad._input`. Desktop build, not `--headless`: a warp needs a window.
##
## Run: Godot --path <project> res://tools/probe_pad_cursor.tscn --windowed --resolution 1600x900
## Result in tools/last_pad_cursor.log.
extends Node

const LOG_PATH := "res://tools/last_pad_cursor.log"

var _frame: int = 0
var _button: Button
var _pressed: int = 0
var _wheel: int = 0
var _escape: int = 0
var _tagged: int = 0


func _ready() -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	f.close()
	var layer := CanvasLayer.new()
	add_child(layer)
	_button = Button.new()
	_button.text = "target"
	_button.position = Vector2(900, 500)
	_button.size = Vector2(120, 60)
	_button.pressed.connect(func() -> void: _pressed += 1)
	_button.gui_input.connect(_on_button_input)
	layer.add_child(_button)


func _on_button_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	# The shed tells a pad's A from a mouse button by this tag, so it has to survive the trip.
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.device == Pad.SYNTH_DEVICE:
		_tagged += 1
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_WHEEL_UP:
		_wheel += 1


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		_escape += 1


func _process(_delta: float) -> void:
	_frame += 1
	var pad := get_node(^"/root/Pad")
	match _frame:
		10:
			pad.call(&"set_mode", 1)
			get_viewport().warp_mouse(_button.get_global_rect().get_center())
		14:
			_log("pointer %s, button %s, stretch %s" % [
				get_viewport().get_mouse_position(), _button.get_global_rect(),
				get_tree().root.get_final_transform()])
			pad.call(&"_input", _joy(JOY_BUTTON_A, true))
		18:
			pad.call(&"_input", _joy(JOY_BUTTON_A, false))
		22:
			pad.call(&"_input", _joy(JOY_BUTTON_RIGHT_SHOULDER, true))
			pad.call(&"_input", _joy(JOY_BUTTON_B, true))
		28:
			_log("pressed %d, wheel over it %d, escape %d, mode %d, tagged clicks %d" % [
				_pressed, _wheel, _escape, int(pad.get(&"mode")), _tagged])
			_log("RESULT %s" % ("ok" if _pressed == 1 and _wheel == 1 and _escape == 1 and _tagged == 2 and int(pad.get(&"mode")) == 1 else "FAIL"))
			get_tree().quit()


func _joy(index: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	return event


func _log(line: String) -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_line(line)
	f.close()
