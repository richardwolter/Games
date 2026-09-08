## The cross in a panel's corner.
##
## Drawn rather than fetched off the UI sheet: the sheet has four pieces on it and none of
## them is a cross, and a cross is two lines. Drawn on its own wood plaque now (WoodUI's
## pieces), so it reads as the same square close button the settings reference shows,
## wherever it is pinned — the shed's boards or the settings' own plank background.
class_name CloseButton
extends Control

const Style := preload("res://scripts/style.gd")

## The ink. It goes brighter under the cursor by the wash the whole game shares — a corner
## cross that does nothing when the mouse is over it reads as a decoration rather than a
## button.
@export var tint: Color = Style.INK

## The arms of the cross, as a fraction of the box.
const ARM := 0.3
const STROKE := 0.1

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
	# A wood plaque under the cross, drawn by the same helper as every other plaque in the
	# game, so the corner cross and the button beside it cannot bevel differently.
	Style.plaque(self, box, Style.WOOD_LIT if _hovered else Style.WOOD)
	var arm := side * ARM
	var thick := maxf(side * STROKE, 2.0)
	draw_line(middle - Vector2(arm, arm), middle + Vector2(arm, arm), ink, thick, true)
	draw_line(middle - Vector2(arm, -arm), middle + Vector2(arm, -arm), ink, thick, true)
