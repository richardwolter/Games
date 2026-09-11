## The foam collar where a figure standing or swimming in the lake cuts the surface.
##
## The floating rubbish has worn one since the waterline cut went in (LakeGrid.FoamLayer); the
## angler wading off the beach and the dog swimming out were cut at the same water with a bare
## straight edge. This is the same collar for one body: the same corners
## (LakeGrid.collar_corners), the same shader and the same colour, so the foam round a boot and
## the foam round a bottle are one substance.
##
## A child of the figure, drawn behind it, and laid in the figure's own drawing space — the
## figure knows where its cut is on this frame and says so through `lay`. The figure moves
## itself on the CPU, so the shader's bob and sway are switched off here; its tearing and
## bubbles still run on TIME without a redraw.
class_name WaterlineFoam
extends Node2D

var _corners := PackedVector2Array()
var _shown := false

static var _skin: ShaderMaterial


func _init() -> void:
	# Behind the figure it belongs to: a collar drawn over it is a white band across the shins.
	z_index = -1
	material = _material()


## Put the collar on the cut from `left` to `right`, in the figure's drawing space. Only
## redraws when the cut has actually moved.
func lay(left: Vector2, right: Vector2) -> void:
	var corners := LakeGrid.collar_corners(left, right)
	if _shown and corners == _corners:
		return
	_corners = corners
	_shown = true
	queue_redraw()


## Out of the water: no collar.
func clear() -> void:
	if not _shown:
		return
	_shown = false
	queue_redraw()


func _draw() -> void:
	if not _shown:
		return
	# The anchor only seeds the foam's noise here, so no two figures froth alike. The shader
	# reads it as a world x; the figure's own is as good a seed as any.
	var anchor := LakeGrid.pack_anchor(global_position.x, 0.0, 1.0)
	RenderingServer.canvas_item_add_triangle_array(
		get_canvas_item(),
		PackedInt32Array([0, 1, 2, 0, 2, 3]),
		_corners,
		PackedColorArray([anchor, anchor, anchor, anchor]),
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)
		])
	)


## One material for every figure: nothing on it differs between them.
static func _material() -> ShaderMaterial:
	if _skin != null:
		return _skin
	var lip := LakeGrid.FOAM_COLOUR
	lip.a = LakeGrid.FOAM_ALPHA
	_skin = ShaderMaterial.new()
	_skin.shader = load("res://shaders/foam.gdshader") as Shader
	# Still: the figure carries its own movement, and the collar has to stay on its cut.
	_skin.set_shader_parameter("sway", 0.0)
	_skin.set_shader_parameter("wave_amplitude", 0.0)
	_skin.set_shader_parameter("anchor_span", LakeGrid.ANCHOR_SPAN)
	_skin.set_shader_parameter("foam", lip)
	_skin.set_shader_parameter(
		"cut_at", LakeGrid.FOAM_RISE / maxf(LakeGrid.FOAM_RISE + LakeGrid.FOAM_TALL, 0.001)
	)
	return _skin
