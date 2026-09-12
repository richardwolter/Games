## The foam a moving boat leaves: a streak each side pushed up at the bow where the hull meets
## the water, running back along the hull and peeling away behind it, and behind those a pair
## that peel wider and run twice as far before falling apart — the trail.
##
## The trail is these same streaks and not a second thing, by decision (2026-09-12): the pale
## wedge with arcs shedding down it that used to sit behind the hull is gone, and what replaced
## it had to be foam the boat drags rather than water it sits on. Four strips in one shader do
## that; a fifth system would be the wedge again under another name.
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

## How long a streak is, as a multiple of the hull's half length, measured back from the bow:
## the pair that hug the hull, and the pair that trail.
const STREAK_LONG := 1.3
const TRAIL_LONG := 2.5

## How far out from the centreline a streak is where it leaves the hull's widest point, and how
## much further it has spread by its tail, both as fractions of the hull's half width. The
## trailing pair start tucked further in and open out much wider, so the four lines fan rather
## than running as two thick ones.
const HUG := 0.8
const SPREAD := 1.1
const TRAIL_HUG := 0.5
const TRAIL_SPREAD := 2.3

## How far along the streak it hugs the hull before it starts peeling off, 0 to 1. The trail
## leaves the hull sooner, because by the stern it is already adrift.
const HUG_UNTIL := 0.6
const TRAIL_HUG_UNTIL := 0.35

## How thick the strip each streak is drawn in, at the bow and at the tail, in pixels.
const THICK_BOW := 6.0
const THICK_TAIL := 11.0
const TRAIL_THICK_BOW := 3.0
const TRAIL_THICK_TAIL := 8.0

## How solid the trailing pair is against the bow pair. Fainter, because it is what is left of
## the wave rather than the wave.
const TRAIL_FADE := 0.6

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
	# The trail first, so the bow's own wave sits over it where the two cross.
	for side: float in [-1.0, 1.0]:
		_draw_streak(along, across * side, true)
	for side: float in [-1.0, 1.0]:
		_draw_streak(along, across * side, false)


func _draw_streak(along: Vector2, out: Vector2, trail: bool) -> void:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var tint := Color(1.0, 1.0, 1.0, _push * (TRAIL_FADE if trail else 1.0))
	var thick_bow := TRAIL_THICK_BOW if trail else THICK_BOW
	var thick_tail := TRAIL_THICK_TAIL if trail else THICK_TAIL
	for i in SEGMENTS + 1:
		var u := float(i) / float(SEGMENTS)
		var centre := _centre(along, out, u, trail)
		# The strip's own normal, off the streak's direction here, so it stays the same
		# thickness where it bends away from the hull.
		var ahead := (
			_centre(along, out, minf(u + 0.02, 1.0), trail)
			- _centre(along, out, maxf(u - 0.02, 0.0), trail)
		)
		var normal := Vector2(-ahead.y, ahead.x).normalized() if ahead.length_squared() > 0.0 else out
		var half := lerpf(thick_bow, thick_tail, u) * 0.5
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
## the hull's side quickly, then peeling steadily away behind it. The trailing pair run the
## same curve with its own numbers — further back, wider, and away from the hull sooner.
func _centre(along: Vector2, out: Vector2, u: float, trail: bool) -> Vector2:
	var long := TRAIL_LONG if trail else STREAK_LONG
	var reach := TRAIL_HUG if trail else HUG
	var spread := TRAIL_SPREAD if trail else SPREAD
	var until := TRAIL_HUG_UNTIL if trail else HUG_UNTIL
	var back := half_length * BOW_AT - half_length * long * u
	var hug := smoothstep(0.0, until, u) * reach
	var peel := maxf(u - until, 0.0) / (1.0 - until) * spread
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
	Palette.dress_foam(_skin, lip.a)
	return _skin
