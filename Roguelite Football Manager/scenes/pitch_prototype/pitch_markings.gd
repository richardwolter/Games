extends Node2D

## Draws the white pitch markings (boundary, halfway line, center circle,
## penalty boxes) over the grass TileMapLayer. Geometry is derived from
## the field rect passed in by pitch_prototype.gd, not hardcoded here.

var field_rect: Rect2 = Rect2()

const LINE_WIDTH: float = 4.0
const LINE_COLOR: Color = Color(1, 1, 1, 0.9)
const CENTER_CIRCLE_RADIUS_RATIO: float = 0.16
const PENALTY_BOX_WIDTH_RATIO: float = 0.14
const PENALTY_BOX_HEIGHT_RATIO: float = 0.5


func set_field_rect(rect: Rect2) -> void:
	field_rect = rect
	queue_redraw()


func _draw() -> void:
	if field_rect.size == Vector2.ZERO:
		return

	draw_rect(field_rect, LINE_COLOR, false, LINE_WIDTH)

	var center: Vector2 = field_rect.get_center()
	draw_line(Vector2(center.x, field_rect.position.y), Vector2(center.x, field_rect.end.y), LINE_COLOR, LINE_WIDTH)

	var radius: float = field_rect.size.y * CENTER_CIRCLE_RADIUS_RATIO
	draw_arc(center, radius, 0, TAU, 48, LINE_COLOR, LINE_WIDTH)

	var box_w: float = field_rect.size.x * PENALTY_BOX_WIDTH_RATIO
	var box_h: float = field_rect.size.y * PENALTY_BOX_HEIGHT_RATIO
	var box_y: float = center.y - box_h / 2.0

	var left_box: Rect2 = Rect2(field_rect.position.x, box_y, box_w, box_h)
	draw_rect(left_box, LINE_COLOR, false, LINE_WIDTH)

	var right_box: Rect2 = Rect2(field_rect.end.x - box_w, box_y, box_w, box_h)
	draw_rect(right_box, LINE_COLOR, false, LINE_WIDTH)
