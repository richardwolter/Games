@tool
extends Node2D
## Pen-and-ink skyline seen from the balcony (art/scene/city.png, sky cut away by
## tools/skyline_art.py). Drawn opaque over the Sky node, so the sun and moon set
## behind the buildings. Its paper takes the colour of the lower sky, and at night
## window lights (art/scene/city_lights.png) glow through additively.

const DESIGN_SIZE := Vector2(1152, 648)
const HORIZON := 300.0
const CITY_TEX := preload("res://art/scene/city.png")
const LIGHTS_TEX := preload("res://art/scene/city_lights.png")
# Where the drawing's own horizon line sits, from its top edge.
const TEX_HORIZON := 141.0
# How dark the ink page gets at full night (the lights stay bright).
const NIGHT_SHADE := Color(0.34, 0.35, 0.44)

@export var sky_path: NodePath = NodePath("../Sky")

var _phase := 0.0
var _lights: Node2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _lights == null:
		_lights = Node2D.new()
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_lights.material = mat
		_lights.draw.connect(_draw_lights)
		add_child(_lights, false, Node.INTERNAL_MODE_BACK)
	queue_redraw()

## p is the sky phase: 0 dawn, 0.32 midday, 0.66 sunset, 1 night.
func set_night(p: float) -> void:
	_phase = clampf(p, 0.0, 1.0)
	queue_redraw()
	if _lights != null:
		_lights.queue_redraw()

func _night_weight() -> float:
	return smoothstep(0.62, 0.95, _phase)

func _paper_tint() -> Color:
	var sky := get_node_or_null(sky_path)
	var tint := Color.WHITE
	if sky != null and sky.has_method("_sample_palette"):
		tint = sky._sample_palette(1)
		tint = tint.lerp(Color.WHITE, 0.35 * (1.0 - _night_weight()))
	return tint * Color.WHITE.lerp(NIGHT_SHADE, _night_weight() * 0.6)

func _draw() -> void:
	draw_texture(CITY_TEX, Vector2(0.0, HORIZON - TEX_HORIZON), _paper_tint())

func _draw_lights() -> void:
	var w := _night_weight()
	if w <= 0.01:
		return
	_lights.draw_texture(LIGHTS_TEX, Vector2(0.0, HORIZON - TEX_HORIZON), Color(1, 1, 1, w))
