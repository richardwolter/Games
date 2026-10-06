class_name KickDust
extends Node2D
## What a walker's feet throw up when they start or turn hard: dust off the ground, and
## droplets and a little foam off the water. Drawn only — nothing reads it back.
##
## One node for the angler and the whole pack, drawn as whole art pixels in the ground's own
## palette colour: pale grains off the sand, a smaller greenish puff off the lawn. The water
## goes through the lake's `WaterSplash` (its drops are already whole art pixels), so a
## splash here is the same water as every other splash on the lake.
##
## `Tracker` is what decides when: a start from rest, or a heading that has swung more than
## `TURN_AT` from the one the walker settled into. The settled heading drifts after the real
## one at `SETTLE`, so a long gentle curve fires nothing and a sharp turn does.

## Whole art pixels, as everything else on the lake.
const PIXEL := 2.0
## How long a grain lives, seconds, rolled between the two.
const LIFE_LEAST := 0.28
const LIFE_MOST := 0.45
## Grains per puff at size 1, and how fast they leave the feet (world px a second).
const GRAINS := 7
const SPEED_LEAST := 18.0
const SPEED_MOST := 46.0
## How far up the screen a grain drifts as it goes, world px a second, and how fast its
## outward speed dies away.
const RISE := 14.0
const DRAG := 5.0
## The lawn throws less than the sand.
const GRASS_SHARE := 0.55
## Colours: the palette's sand, lifted a little; the lawn's light green, lifted into dust.
const SAND_LIFT := 0.12
const GRASS_LIFT := 0.25
const ALPHA := 0.8
## Most grains alive at once, so four dogs on the beach cannot run it away.
const MOST := 220

## Water: droplets thrown per burst at size 1, their speed, and the foam ring's span.
const DROPS := 5
const DROP_SPEED := 70.0
const DROP_UP := 90.0
const DROP_LIFE := 0.35
const FOAM_SPAN := 10.0
## A footfall in the water is this share of a start's burst.
const STEP_SHARE := 0.45
## The animals keep to half the splash layer's ring cap, like the rain and the wildlife.
const RING_SHARE := 0.5

var _at := PackedVector2Array()
var _vel := PackedVector2Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _ink := PackedColorArray()
var _rng := RandomNumberGenerator.new()
var _sand := Color(0.91, 0.804, 0.592)
var _grass := Color(0.427, 0.529, 0.251)


func _ready() -> void:
	_rng.randomize()
	var pal := Palette.master()
	if pal != null:
		_sand = pal.colors.get(&"sand", _sand)
		_grass = pal.colors.get(&"grass_light", _grass)
	set_process(false)


## How many grains are in the air now. For the test.
func grains() -> int:
	return _age.size()


## The colour a grain off `ground` is drawn in. Public for the test.
func ink_of(ground: StringName) -> Color:
	if ground == &"grass":
		return _grass.lerp(Color.WHITE, GRASS_LIFT)
	return _sand.lerp(Color.WHITE, SAND_LIFT)


## A puff of dust off `ground` (`&"sand"` or `&"grass"`) at the feet, thrown mostly back
## against `heading` (a screen direction; zero throws it all round). `size` scales the count.
func puff(at: Vector2, ground: StringName, heading: Vector2, size: float = 1.0) -> void:
	var count := roundi(GRAINS * size * (GRASS_SHARE if ground == &"grass" else 1.0))
	var ink := ink_of(ground)
	var back := -heading.normalized() if heading.length_squared() > 0.0001 else Vector2.ZERO
	for i in count:
		if _age.size() >= MOST:
			break
		var way := Vector2.from_angle(_rng.randf() * TAU)
		way = (way + back * 1.2).normalized() if back != Vector2.ZERO else way
		# Flattened to the ground's 2:1, like every ellipse on the lake.
		way.y *= 0.5
		_at.append(at + Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-1.0, 1.0)))
		_vel.append(way * _rng.randf_range(SPEED_LEAST, SPEED_MOST))
		_age.append(0.0)
		_life.append(_rng.randf_range(LIFE_LEAST, LIFE_MOST))
		_ink.append(ink)
	if not _age.is_empty():
		set_process(true)


## Droplets and a foam ring off the water at the feet, through the lake's splash layer.
static func splash_at(
	splash: WaterSplash, at: Vector2, heading: Vector2, size: float, rng: RandomNumberGenerator
) -> void:
	if splash == null:
		return
	var back := -heading.normalized() if heading.length_squared() > 0.0001 else Vector2.ZERO
	for i in maxi(1, roundi(DROPS * size)):
		var way := Vector2.from_angle(rng.randf() * TAU)
		way = (way + back).normalized() if back != Vector2.ZERO else way
		var vel := Vector2(way.x, way.y * 0.5) * DROP_SPEED * rng.randf_range(0.5, 1.0)
		vel.y -= DROP_UP * rng.randf_range(0.6, 1.0) * sqrt(size)
		splash.drip(at + Vector2(rng.randf_range(-2.0, 2.0), 0.0), vel, PIXEL, DROP_LIFE)
	if splash.ripples_up() < int(WaterSplash.MAX_RIPPLES * RING_SHARE):
		splash.ripple(at, FOAM_SPAN * sqrt(size))


func _process(delta: float) -> void:
	var i := 0
	while i < _age.size():
		_age[i] += delta
		if _age[i] >= _life[i]:
			_at.remove_at(i)
			_vel.remove_at(i)
			_age.remove_at(i)
			_life.remove_at(i)
			_ink.remove_at(i)
			continue
		_vel[i] *= exp(-DRAG * delta)
		_at[i] += (_vel[i] + Vector2(0.0, -RISE)) * delta
		i += 1
	if _age.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for i in _age.size():
		var left := 1.0 - _age[i] / _life[i]
		var ink := _ink[i]
		ink.a = ALPHA * left
		var at := (_at[i] / PIXEL).floor() * PIXEL
		draw_rect(Rect2(at, Vector2(PIXEL, PIXEL)), ink)


## Watches one walker's motion and says when its feet should kick: `START` from rest, `TURN`
## on a hard turn, `NONE` otherwise. Fed the walker's position every frame, in any space.
class Tracker:
	extends RefCounted

	enum { NONE, START, TURN }

	## Moving means faster than this, in the units a second that `step` is fed.
	var moving_at := 0.5
	## A turn is a swing of more than this from the settled heading.
	var turn_at := deg_to_rad(60.0)
	## How fast the settled heading follows the real one.
	var settle := 4.0
	## The least time between two kicks.
	var gap := 0.22

	var _was := Vector2.INF
	var _moving := false
	var _heading := Vector2.ZERO
	var _wait := 0.0

	func step(at: Vector2, delta: float) -> int:
		_wait = maxf(_wait - delta, 0.0)
		if _was == Vector2.INF or delta <= 0.0:
			_was = at
			return NONE
		var moved := at - _was
		_was = at
		var speed := moved.length() / delta
		if speed < moving_at:
			_moving = false
			return NONE
		var dir := moved / moved.length()
		if not _moving:
			_moving = true
			_heading = dir
			if _wait <= 0.0:
				_wait = gap
				return START
			return NONE
		if absf(_heading.angle_to(dir)) > turn_at:
			_heading = dir
			if _wait <= 0.0:
				_wait = gap
				return TURN
			return NONE
		_heading = _heading.slerp(dir, 1.0 - exp(-settle * delta)).normalized()
		return NONE

	## Forget where the walker was: a teleport is not a start.
	func reset() -> void:
		_was = Vector2.INF
		_moving = false
