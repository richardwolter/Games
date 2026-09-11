## A button that is a plank of the meter's wood with a word on it.
##
## For the buttons that live in the scene and are placed by anchors — the settings button in
## the HUD's corner — so they are the same wood as the drawn boards rather than a stock
## Button in a theme override. Drawn by `Style.plank`, like the boards' save buttons and the
## corner cross, with the corners clipped a step.
class_name PlankButton
extends Control

const Style := preload("res://scripts/style.gd")

@export var label: String = "":
	set(value):
		label = value
		queue_redraw()

signal pressed

var _hovered: bool = false
var _held: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		_hovered = what == NOTIFICATION_MOUSE_ENTER
		if not _hovered:
			_held = false
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if click.pressed:
		_held = true
		queue_redraw()
		return
	if _held:
		_held = false
		queue_redraw()
		pressed.emit()


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	if _held:
		box.position.y += Style.PRESS_SINK
	elif _hovered:
		box.position.y -= Style.HOVER_LIFT
	var face := Style.FRAME
	if _hovered and not _held:
		face = Color(face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b)
	elif _held:
		face = face.darkened(0.15)
	Style.plank(self, box, int(global_position.x) * 7 + int(global_position.y) + 3, face, Style.CLIP)
	if label.is_empty():
		return
	var height := Style.step(size.y * 0.42)
	Style.write(
		self, label, height,
		Vector2(0.0, box.position.y + (box.size.y + float(height) * 0.62) * 0.5),
		Style.RIBBON_INK, HORIZONTAL_ALIGNMENT_CENTER, box
	)
