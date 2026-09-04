## The cross in a panel's corner.
##
## Drawn rather than fetched off the UI sheet: the sheet has four pieces on it and none of
## them is a cross, and a cross is two lines. Drawing it also means it takes the colour of
## whatever panel it is pinned to — pale on the shed's boards, pale on the settings' slate —
## instead of being one painted plaque that only suits one of them.
class_name CloseButton
extends Control

## The ink, and how much brighter it goes under the cursor. A corner cross that does nothing
## when the mouse is over it reads as a decoration rather than a button.
@export var tint: Color = Color(0.86, 0.84, 0.79)
const HOVER_WASH := Color(1.25, 1.25, 1.25)

## The arms of the cross, and the disc behind them, as fractions of the box.
const ARM := 0.3
const DISC := 0.46
const STROKE := 0.085

signal pressed

var _hovered: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Close"


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		_hovered = what == NOTIFICATION_MOUSE_ENTER
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	pressed.emit()


func _draw() -> void:
	var side := minf(size.x, size.y)
	var middle := size * 0.5
	var ink := tint * HOVER_WASH if _hovered else tint
	# A disc under the cross so it is a target rather than two hairlines, and so the corner
	# it sits in does not have to be plain for it to be read.
	draw_circle(middle, side * DISC, Color(0.0, 0.0, 0.0, 0.35 if _hovered else 0.22))
	var arm := side * ARM
	var thick := maxf(side * STROKE, 2.0)
	draw_line(middle - Vector2(arm, arm), middle + Vector2(arm, arm), ink, thick, true)
	draw_line(middle - Vector2(arm, -arm), middle + Vector2(arm, -arm), ink, thick, true)
