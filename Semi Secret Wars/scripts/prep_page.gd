class_name PrepPage
extends Control

## Ruled notebook-paper background, matching the battlefield's page draw
## (stage_field.gd _draw_page) so the prep screen reads as the same world.

const PAGE_COLOR := Color("f4efe1")
const RULE_COLOR := Color("aac4dd")
const MARGIN_COLOR := Color("d98f8f")
const INK_COLOR := Color("161412")

const RULE_SPACING := 42.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, PAGE_COLOR, true)
	var y := fmod(RULE_SPACING, RULE_SPACING)
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), RULE_COLOR, 1.5, true)
		y += RULE_SPACING
	var mx := size.x * 0.08
	draw_line(Vector2(mx, 0), Vector2(mx, size.y), MARGIN_COLOR, 2.0, true)
