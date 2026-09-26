@tool
extends Node2D
## Pen-and-ink wooden balcony railing across the foreground (art/scene/balcony.png).
## The crew perches on the top rail; gaps between balusters are transparent so the
## city shows through. It dims with the evening but stays readable.

const DESIGN_SIZE := Vector2(1152, 648)
const BALCONY_TEX := preload("res://art/scene/balcony.png")
# Top of the texture; puts the top rail's upper edge at y ~491, just under the
# crows' feet (RAIL_PERCH_Y 484 + crow FEET_Y 11).
const TOP_Y := 476.0

var _night := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func set_night(v: float) -> void:
	_night = clampf(v, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var tint := Color.WHITE.lerp(Color(0.55, 0.56, 0.66), _night)
	draw_texture_rect(BALCONY_TEX, Rect2(0.0, TOP_Y, DESIGN_SIZE.x, DESIGN_SIZE.y - TOP_Y), false, tint)
