## A button that is the meter's wood with a word on it.
##
## For the buttons that live in the scene and are placed by anchors — the settings button in
## the HUD's corner — so they are the same wood as the HUD's own, rather than a stock Button
## in a theme override. It wears the meter's built border (`Style.meter_frame`) like the
## three corner buttons, and falls back to a clipped plank where that will not fit.
##
## The word is set to the face the border leaves rather than to the whole button, so a button
## sized to its own word has no empty wood around it.
class_name PlankButton
extends Control

const Style := preload("res://scripts/style.gd")

@export var label: String = "":
	set(value):
		label = value
		queue_redraw()

## How much of the face the word is set to, and how much room is left beside it.
const LABEL_SHARE := 0.78
const LABEL_PAD := 12.0

signal pressed

## Whether a press clicks. The menu's own planks turn it off and choose their sound there: New
## game and Continue play the start sound instead.
var clicks: bool = true

var _hovered: bool = false
var _held: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		_hovered = what == NOTIFICATION_MOUSE_ENTER
		if _hovered:
			Sfx.ui(&"ui_hover")
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
		if clicks:
			Sfx.ui(&"ui_click")
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
	var on := box
	if Style.border_fits(box):
		on = Style.border_inset(box)
		draw_rect(on.grow(2.0), Style.BOARD, true)
		Style.meter_frame(self, box, Style.HOVER_WASH if _hovered and not _held else Color.WHITE)
	else:
		Style.plank(self, box, int(global_position.x) * 7 + int(global_position.y) + 3, face, Style.CLIP)
	if label.is_empty():
		return
	# Set to the face, and shrunk if the word is longer than the wood leaves room for.
	var height := Style.step(on.size.y * LABEL_SHARE)
	var wide := Style.measure(label, height).x
	if wide > on.size.x - LABEL_PAD:
		height = Style.step(float(height) * (on.size.x - LABEL_PAD) / wide)
	Style.write(
		self, label, height,
		Vector2(0.0, on.position.y + (on.size.y + float(height) * 0.62) * 0.5),
		Style.RIBBON_INK, HORIZONTAL_ALIGNMENT_CENTER, on
	)
