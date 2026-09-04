class_name AcidPool
extends Node2D

## A puddle of stomach acid on the floor. Standing in it hurts, on a tick, for
## as long as you stand in it.
##
## Deliberately not an Area2D. The player's hurtbox wraps his whole drawn body,
## so an overlap test would burn him for standing a body-width away from the
## edge -- the same reason the pedestal pickup is a point test. What matters is
## where his FEET are, so that is what is tested, against the polygon that is
## actually drawn.

## Seconds between ticks of damage. Long enough that clipping a corner of a pool
## costs one tick and not a health bar.
const TICK_INTERVAL: float = 0.6
const TICK_DAMAGE: float = 1.0

## How far the outline wobbles in and out around the base radius, as a fraction.
## This is the whole difference between "puddle" and "circle".
const EDGE_JITTER: float = 0.38
const POINT_COUNT: int = 18

## Sits on a near-black floor, so the fill carries most of the read and the
## bright rim is what says exactly where the edge is.
const COLOR_BODY: Color = Color(0.72, 0.88, 0.18, 0.62)
const COLOR_EDGE: Color = Color(0.90, 1.0, 0.40, 0.95)

## Base size before the jitter. Set by whoever places the pool.
var radius: float = 90.0

var _points: PackedVector2Array = PackedVector2Array()
var _tick: float = 0.0
var _bubble: float = 0.0


## Builds the outline. Called before the pool is in the tree, so it takes its own
## rng rather than reaching for the room's -- a pool has to be shaped the same
## way on every visit to a given room, and that means a seeded caller.
func shape(rng: RandomNumberGenerator, p_radius: float) -> void:
	radius = p_radius
	_points = PackedVector2Array()
	# Two overlaid sine terms of different frequency, plus per-vertex noise: one
	# term alone reads as a flower, and noise alone reads as a torn circle.
	var phase := rng.randf() * TAU
	var lobes := rng.randi_range(2, 4)
	for i in POINT_COUNT:
		var a := TAU * float(i) / POINT_COUNT
		var wobble := sin(a * lobes + phase) * 0.6 + sin(a * 2.0 - phase) * 0.4
		var r := radius * (1.0 + EDGE_JITTER * wobble + rng.randf_range(-0.06, 0.06))
		# Squashed vertically: the floor is seen at an angle, and a round puddle
		# on it reads as a ball.
		_points.append(Vector2(cos(a) * r, sin(a) * r * 0.62))


func _ready() -> void:
	# NOT negative. A negative z on a child of the room puts the pool behind the
	# room's OWN _draw -- which paints a solid floor rect over the whole
	# interior, so the puddle was there the entire time and buried under it.
	# Zero already draws after the parent and still under the player and enemies,
	# which live outside this room node.
	z_index = 0


func _process(delta: float) -> void:
	_bubble += delta
	queue_redraw()

	_tick = maxf(_tick - delta, 0.0)
	var player := get_tree().get_first_node_in_group(&"player_body") as Node2D
	if player == null:
		return
	if not contains(player.global_position):
		# Timer resets on leaving, so hopping in and out costs a tick each time
		# rather than banking progress toward one.
		_tick = 0.0
		return
	if _tick > 0.0:
		return
	_tick = TICK_INTERVAL
	if player.has_method(&"take_damage"):
		# No knockback: being shoved out of the acid would be the pool solving
		# itself. Walking out is the player's job.
		player.take_damage(TICK_DAMAGE, Vector2.ZERO, {}, false)


func contains(world_point: Vector2) -> bool:
	if _points.is_empty():
		return false
	return Geometry2D.is_point_in_polygon(to_local(world_point), _points)


func _draw() -> void:
	if _points.is_empty():
		return
	draw_colored_polygon(_points, COLOR_BODY)
	draw_polyline(_points + PackedVector2Array([_points[0]]), COLOR_EDGE, 3.0)

	# Bubbles, so a pool that damages on a clock does not look like a decal. Laid
	# out off the vertex list rather than randomly per frame -- a puddle that
	# sparkles everywhere is noise, and this has to stay readable under a fight.
	for i in range(0, _points.size(), 3):
		var p: Vector2 = _points[i] * 0.55
		var t := fposmod(_bubble * 0.8 + float(i) * 0.37, 1.0)
		draw_circle(p - Vector2(0.0, t * 4.0), 2.0 + 2.0 * (1.0 - t),
			Color(COLOR_EDGE, 0.5 * (1.0 - t)))
