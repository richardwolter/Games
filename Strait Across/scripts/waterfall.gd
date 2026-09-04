## Water pouring off the far cliff into the strait.
##
## Drawn by hand for the same reasons WaterSplash is: the game renders on the
## Compatibility backend for the web build, and the art is flat and painted, so
## a particle system would both risk looking different in the browser and read as
## a different game pasted over this one.
##
## Nothing here is simulated. The column is a handful of scrolling vertical
## streaks, and the mist at the foot is a small pool of drops recycled forever —
## the cost is constant no matter how long a level is left running.
class_name Waterfall
extends Node2D

## Same foam white the splashes use, so the fall and the crowns it throws are
## obviously the same water.
const FOAM := Color(0.93, 0.98, 1.0)

## How opaque the solid heart of the column is. Short of solid: the cliff behind
## it should still be readable as rock, and a white slab down the far bank hides
## exactly the ground the player is trying to build up to.
const COLUMN_ALPHA := 0.5

## Vertical streaks in the column. Cheap, and the only thing selling the fall as
## moving rather than as a painted stripe.
const STREAKS := 14
## How fast a streak travels down the fall, in pixels per second. Fast enough to
## read as falling water; the eye gives up tracking any one of them well before
## it notices they repeat.
const STREAK_SPEED := 1100.0

## Drops of spray living around the foot of the fall.
const MIST := 46
const MIST_GRAVITY := 1200.0

## Where the fall lands and how wide it is at the surface. Set by World.
var top_y: float = 0.0
var surface_y: float = 300.0
var width: float = 120.0

## How far the column drifts out from the cliff on its way down. Water leaving a
## lip has horizontal speed, so a fall that comes straight down reads as a pipe.
var lean: float = 60.0

## Streak phases, 0..1 down the fall. Kept rather than derived from TIME alone so
## they are unevenly spaced — evenly spaced streaks read as a barber's pole.
var _streak_at := PackedFloat32Array()
var _streak_span := PackedFloat32Array()
var _streak_x := PackedFloat32Array()

var _mist_pos := PackedVector2Array()
var _mist_vel := PackedVector2Array()
var _mist_life := PackedFloat32Array()
var _mist_size := PackedFloat32Array()

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(Vector2(position.x, top_y))
	for i in STREAKS:
		_streak_at.append(_rng.randf())
		_streak_span.append(_rng.randf_range(0.10, 0.34))
		_streak_x.append(_rng.randf_range(-0.42, 0.42))
	for i in MIST:
		_mist_pos.append(Vector2.ZERO)
		_mist_vel.append(Vector2.ZERO)
		_mist_life.append(0.0)
		_mist_size.append(3.0)


## Horizontal centre of the fall at a given height, 0 at the lip and 1 at the
## water. Squared, so the water leaves the lip going down and bends out as it
## picks up speed rather than arcing away immediately.
func _centre_at(t: float) -> float:
	return -lean * t * t


## How wide the column is at that height. It leaves the lip as a tight spout and
## spreads on the way down.
func _half_width_at(t: float) -> float:
	return width * lerpf(0.34, 0.5, t)


func _process(delta: float) -> void:
	var drop := maxf(surface_y - top_y, 1.0)

	for i in _streak_at.size():
		var at := _streak_at[i] + delta * STREAK_SPEED / drop
		_streak_at[i] = at - floorf(at)

	for i in _mist_life.size():
		var life := _mist_life[i] - delta
		if life <= 0.0:
			# Reborn at the foot of the fall rather than removed: a waterfall is
			# permanent, so a pool of drops recycling costs nothing and never grows.
			var foot := _centre_at(1.0)
			_mist_pos[i] = Vector2(
				foot + _rng.randf_range(-1.0, 1.0) * width * 0.5, surface_y
			)
			_mist_vel[i] = Vector2(
				_rng.randf_range(-1.0, -0.15) * width * 2.2,
				-_rng.randf_range(180.0, 520.0)
			)
			_mist_life[i] = _rng.randf_range(0.35, 0.95)
			_mist_size[i] = width * _rng.randf_range(0.02, 0.055)
			continue
		_mist_life[i] = life
		var vel := _mist_vel[i]
		vel.y += MIST_GRAVITY * delta
		_mist_vel[i] = vel
		_mist_pos[i] += vel * delta

	queue_redraw()


func _draw() -> void:
	var drop := maxf(surface_y - top_y, 1.0)
	# Vertical resolution of the column. The shape is two smooth curves, so this
	# only has to be fine enough that the outline does not read as facets.
	var steps := 18

	# The body of the fall: one strip from lip to water, narrowing towards the
	# top and fading a little as it thins.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var tint := PackedColorArray()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var y := top_y + drop * t
		var centre := _centre_at(t)
		var half := _half_width_at(t)
		left.append(Vector2(centre - half, y))
		right.append(Vector2(centre + half, y))
	var body := PackedVector2Array()
	for point: Vector2 in left:
		body.append(point)
	for i in range(right.size() - 1, -1, -1):
		body.append(right[i])
	for i in body.size():
		# Brightest where it hits, palest at the lip: the foot is where the water
		# is aerated and white, the top is still a clear sheet.
		var t := 1.0 - absf(float(i) / float(body.size()) - 0.5) * 2.0
		tint.append(Color(FOAM.r, FOAM.g, FOAM.b, COLUMN_ALPHA * lerpf(0.7, 1.0, t)))
	draw_polygon(body, tint)

	# Streaks. Each is a short bright segment travelling down the column, drawn
	# as a line so it costs one call and stays readable when zoomed out.
	for i in _streak_at.size():
		var at := _streak_at[i]
		var span := _streak_span[i]
		var a_t := at
		var b_t := minf(at + span, 1.0)
		var a := Vector2(
			_centre_at(a_t) + _streak_x[i] * _half_width_at(a_t) * 2.0, top_y + drop * a_t
		)
		var b := Vector2(
			_centre_at(b_t) + _streak_x[i] * _half_width_at(b_t) * 2.0, top_y + drop * b_t
		)
		draw_line(b, a, Color(FOAM.r, FOAM.g, FOAM.b, 0.32), width * 0.06)

	# Where it lands: a permanent white scar on the water, brightest under the
	# spout, so the fall is connected to the strait rather than ending at it.
	var foot := _centre_at(1.0)
	var mouth := width * 0.9
	draw_polygon(
		PackedVector2Array([
			Vector2(foot - mouth, surface_y),
			Vector2(foot + mouth * 0.6, surface_y),
			Vector2(foot + mouth * 0.25, surface_y + 26.0),
			Vector2(foot - mouth * 0.7, surface_y + 26.0),
		]),
		PackedColorArray([
			Color(FOAM.r, FOAM.g, FOAM.b, 0.42),
			Color(FOAM.r, FOAM.g, FOAM.b, 0.42),
			Color(FOAM.r, FOAM.g, FOAM.b, 0.0),
			Color(FOAM.r, FOAM.g, FOAM.b, 0.0),
		])
	)

	for i in _mist_life.size():
		var life := _mist_life[i]
		if life <= 0.0:
			continue
		draw_circle(_mist_pos[i], _mist_size[i], Color(FOAM.r, FOAM.g, FOAM.b, minf(life, 0.55)))
