@tool
extends Node2D
## Pen-and-ink balcony across the foreground. Classic: carved stone balustrade
## (art/scene/balcony.png). Modern: glass panels under a steel handrail
## (art/scene/balcony_modern.png, see tools/balcony_modern_template.py). The crew
## perches on the top rail; the see-through parts let the city show behind. It
## dims with the evening but stays readable.

const Envs = preload("res://scripts/environments.gd")

const DESIGN_SIZE := Vector2(1152, 648)
# top: top of the texture. Both put the rail's upper edge at y ~491, just under
# the crows' feet (RAIL_PERCH_Y 484 + crow FEET_Y 11).
const ART := {
	Envs.CLASSIC: {"tex": "res://art/scene/balcony.png", "top": 476.0},
	Envs.MODERN: {"tex": "res://art/scene/balcony_modern.png", "top": 476.0},
}

var _night := 0.0
var _tex: Texture2D
var _top := 476.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_load_env(Envs.current(self))
	Envs.watch(self, _load_env)

func _load_env(id: String) -> void:
	_tex = load(ART[id]["tex"])
	_top = ART[id]["top"]
	queue_redraw()

func set_night(v: float) -> void:
	_night = clampf(v, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var tint := Color.WHITE.lerp(Color(0.55, 0.56, 0.66), _night)
	draw_texture_rect(_tex, Rect2(0.0, _top, DESIGN_SIZE.x, DESIGN_SIZE.y - _top), false, tint)
