## The cross in a panel's corner.
##
## Drawn rather than fetched off the UI sheet: the sheet has four pieces on it and none of
## them is a cross, and a cross is two lines. It sits on a plank of the meter's painted wood
## (`Style.meter_plank`, 2026-09-12), the same wood and the same bitten ends as every board
## and button in the game, so a cross pinned to a title plank is part of it rather than a
## lighter tile bolted on. `Style.plank` is the fallback where the painted wood will not fit.
class_name CloseButton
extends Control

const Style := preload("res://scripts/style.gd")

## The ink. It goes brighter under the cursor by the wash the whole game shares — a corner
## cross that does nothing when the mouse is over it reads as a decoration rather than a
## button.
@export var tint: Color = Style.INK

## The arms of the cross, as a fraction of the box. Brought in (2026-09-12) from 0.3 and 0.1:
## at that size the cross ran off the plank it is nailed to and read as bigger than the title
## beside it.
const ARM := 0.22
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
	var box := Rect2(middle - Vector2(side, side) * 0.5, Vector2(side, side))
	var ink := tint * Style.HOVER_WASH if _hovered else tint
	# A plank of the meter's wood under the cross, so the corner cross and the board it sits
	# on cannot be two woods.
	var wash := Style.HOVER_WASH if _hovered else Color.WHITE
	if not Style.meter_plank(self, box, wash):
		var face := Style.FRAME
		if _hovered:
			face = Color(face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b)
		Style.plank(self, box, int(global_position.x) * 7 + int(global_position.y), face, Style.CLIP)
	var arm := side * ARM
	var thick := maxf(side * STROKE, 2.0)
	draw_line(middle - Vector2(arm, arm), middle + Vector2(arm, arm), ink, thick, true)
	draw_line(middle - Vector2(arm, -arm), middle + Vector2(arm, -arm), ink, thick, true)
