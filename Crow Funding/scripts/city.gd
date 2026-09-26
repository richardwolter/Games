@tool
extends Node2D
## Pen-and-ink city seen from the balcony (art/scene/city.png, a loose ref-2 style
## sketch). It multiplies over the sky backdrop, so the paper-white of the drawing
## takes the time-of-day tint and the ink lines stay ink.

const DESIGN_SIZE := Vector2(1152, 648)
const HORIZON := 300.0
const CITY_TEX := preload("res://art/scene/city.png")
# The drawing's own horizon sits ~180 px from its top; line it up with HORIZON.
const TEX_HORIZON := 180.0

var _night := 0.0

func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func set_night(v: float) -> void:
	_night = clampf(v, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	draw_texture(CITY_TEX, Vector2(0.0, HORIZON - TEX_HORIZON))
