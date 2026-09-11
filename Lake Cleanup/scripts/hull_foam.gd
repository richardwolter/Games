## The bow wave a moving boat leaves: a streak of foam each side, pushed up at the bow where
## the hull meets the water, running back along the hull and peeling away behind it.
##
## Not a ring. A ring round the hull read as a halo the boat was sitting in; foam on a boat
## under way is something it leaves, not something it wears. See
## shaders/hull_foam.gdshader for the streak itself. Same colour as the lake's other foam,
## so the white off the bow and the white round a bottle are one substance.
##
## A child of the boat, drawn behind the hull, laid in the boat's own space. It follows the
## boat's heading, and how hard the boat is pushing is eased in and out, so the wave builds as
## it gets going and dies away once it stops rather than switching.
class_name HullFoam
extends Node2D

## How many strip segments make each streak.
const SEGMENTS := 36

## Where on the hull the streaks start, as a fraction of the half length out towards the bow.
const BOW_AT := 0.4

## How long a streak is, as a multiple of the hull's half length, measured back from the bow.
const STREAK_LONG := 1.3

## How far out from the centreline a streak is where it leaves the hull's widest point, and how
## much further it has spread by its tail, both as fractions of the hull's half width.
const HUG := 0.8
const SPREAD := 1.1

## How far along the streak it hugs the hull before it starts peeling off, 0 to 1.
const HUG_UNTIL := 0.6

## How thick the strip each streak is drawn in, at the bow and at the tail, in pixels.
const THICK_BOW := 6.0
const THICK_TAIL := 11.0

## How much the plane squashes the across direction on screen.
const SQUASH := 0.55

## How fast the push eases towards the boat's, per second.
const PUSH_EASE := 2.0

var half_length := 69.0
var half_width := 28.5

var _heading := Vector2(1.0, 0.0)
var _push := 0.0
var _shown_push := -1.0

static var _skin: ShaderMaterial


func _init() -> void:
	# Behind the hull: foam over the paint is a white stripe on the boat.
	z_index = -1
	material = _material()


## Point the streaks along `heading` (on screen) and ease the wave towards `push`, 0 to 1.
func lay(heading: Vector2, push: float, delta: float) -> void:
	if heading.length_squared() > 0.0001:
		_heading = heading.normalized()
	_push = move_toward(_push, clampf(push, 0.0, 1.0), PUSH_EASE * delta)
	# A boat sitting still with no wave draws nothing and needs no redraw.
	if _push <= 0.0 and _shown_push <= 0.0:
		return
	_shown_push = _push
	queue_redraw()


func _draw() -> void:
	if _push <= 0.0:
		return
	var along := _heading
	var across := Vector2(-along.y, along.x)
	across = Vector2(across.x, across.y * SQUASH)
	for side: float in [-1.0, 1.0]:
		_draw_streak(along, across * side)


func _draw_streak(along: Vector2, out: Vector2) -> void:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var tint := Color(1.0, 1.0, 1.0, _push)
	for i in SEGMENTS + 1:
		var u := float(i) / float(SEGMENTS)
		var centre := _centre(along, out, u)
		# The strip's own normal, off the streak's direction here, so it stays the same
		# thickness where it bends away from the hull.
		var ahead := _centre(along, out, minf(u + 0.02, 1.0)) - _centre(along, out, maxf(u - 0.02, 0.0))
		var normal := Vector2(-ahead.y, ahead.x).normalized() if ahead.length_squared() > 0.0 else out
		var half := lerpf(THICK_BOW, THICK_TAIL, u) * 0.5
		points.append(centre - normal * half)
		points.append(centre + normal * half)
		uvs.append(Vector2(u, 0.0))
		uvs.append(Vector2(u, 1.0))
		colours.append(tint)
		colours.append(tint)
		if i < SEGMENTS:
			var base := i * 2
			indices.append_array([base, base + 1, base + 3, base, base + 3, base + 2])
	RenderingServer.canvas_item_add_triangle_array(
		get_canvas_item(), indices, points, colours, uvs
	)


## Where a streak is at `u` of the way from the bow to its tail: back along the hull, out to
## the hull's side quickly, then peeling steadily away behind it.
func _centre(along: Vector2, out: Vector2, u: float) -> Vector2:
	var back := half_length * BOW_AT - half_length * STREAK_LONG * u
	var hug := smoothstep(0.0, HUG_UNTIL, u) * HUG
	var peel := maxf(u - HUG_UNTIL, 0.0) / (1.0 - HUG_UNTIL) * SPREAD
	return along * back + out * half_width * (hug + peel)


## One material for every boat: nothing on it differs between them.
static func _material() -> ShaderMaterial:
	if _skin != null:
		return _skin
	_skin = ShaderMaterial.new()
	_skin.shader = load("res://shaders/hull_foam.gdshader") as Shader
	var lip := LakeGrid.FOAM_COLOUR
	lip.a = 0.75
	_skin.set_shader_parameter("foam", lip)
	return _skin
