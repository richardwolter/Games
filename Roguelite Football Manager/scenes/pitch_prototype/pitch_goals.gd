extends Node2D

## Draws a simple goal frame + net hatch at each end of the pitch.
## The asset pack has no goal sprite, so this is a procedural stand-in,
## drawn the same way as pitch_markings.gd's official lines.

var field_rect: Rect2 = Rect2()

const GOAL_WIDTH_RATIO: float = 0.16
const GOAL_DEPTH: float = 16.0
const LINE_WIDTH: float = 4.0
const LINE_COLOR: Color = Color(1, 1, 1, 0.95)
const NET_COLOR: Color = Color(1, 1, 1, 0.35)
const NET_COLUMNS: int = 4
const NET_ROWS: int = 3


func set_field_rect(rect: Rect2) -> void:
	field_rect = rect
	queue_redraw()


func _draw() -> void:
	if field_rect.size == Vector2.ZERO:
		return

	var goal_height: float = field_rect.size.y * GOAL_WIDTH_RATIO
	var top: float = field_rect.get_center().y - goal_height / 2.0

	var left_goal := Rect2(field_rect.position.x - GOAL_DEPTH, top, GOAL_DEPTH, goal_height)
	_draw_goal(left_goal)

	var right_goal := Rect2(field_rect.end.x, top, GOAL_DEPTH, goal_height)
	_draw_goal(right_goal)


func _draw_goal(rect: Rect2) -> void:
	draw_rect(rect, LINE_COLOR, false, LINE_WIDTH)
	for i in range(1, NET_COLUMNS):
		var x: float = rect.position.x + rect.size.x * i / float(NET_COLUMNS)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), NET_COLOR, 1.0)
	for j in range(1, NET_ROWS):
		var y: float = rect.position.y + rect.size.y * j / float(NET_ROWS)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), NET_COLOR, 1.0)
