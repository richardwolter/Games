class_name FumeCloud
extends Node2D

## A puff of propellant left behind by a rolling can. Hurts on a tick while you
## stand in it, then thins out and is gone.
##
## Sibling of AcidPool and the same shape of thing, with one difference that
## matters: acid is placed when a room is built and is part of knowing where you
## are, while this is laid down during a fight by something that is still moving.
## So it expires, and it fades while it does -- a hazard that vanishes has to
## announce that it is going, or the player learns to distrust the floor.
##
## Not an Area2D, for the reason AcidPool spells out: the player's hurtbox wraps
## his whole drawn body, and an overlap test would gas him for walking past.

## Seconds between ticks of damage, and what a tick costs. Cheaper per tick than
## acid: the cloud comes to YOU, and a hazard that moves has to ask less.
const TICK_INTERVAL: float = 0.7
const TICK_DAMAGE: float = 1.0

## How long the puff spends growing to full size, as a fraction of its life. It
## is sprayed, so it billows outward rather than appearing at full width.
const BLOOM: float = 0.18
## The last of its life, over which it fades out. Long enough to read as
## dispersing rather than as being switched off.
const FADE: float = 0.35

const RADIUS: float = 62.0
## How far the cloud creeps outward over its whole life, past the bloom.
const SPREAD: float = 18.0

const COLOR_BODY: Color = Color(0.80, 0.92, 0.55, 0.30)
const COLOR_EDGE: Color = Color(0.92, 1.0, 0.68, 0.42)

## How long this puff lives. Set by whatever laid it down.
var lifetime: float = 5.0

var _age: float = 0.0
var _tick: float = 0.0
var _seed: float = 0.0


func _ready() -> void:
	# Over the floor, under the fight. Same reasoning as AcidPool's: a negative
	# z on a child of the room buries it under the room's own floor fill.
	z_index = 1
	_seed = randf() * TAU


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= lifetime:
		queue_free()
		return

	_tick = maxf(_tick - delta, 0.0)
	var player := get_tree().get_first_node_in_group(&"player_body") as Node2D
	if player == null:
		return
	if not contains(player.global_position):
		# Reset on leaving, so stepping in and out costs a tick each time rather
		# than banking progress toward one. Same rule the acid runs on.
		_tick = 0.0
		return
	if _tick > 0.0:
		return
	_tick = TICK_INTERVAL
	if player.has_method(&"take_damage"):
		# No knockback: being blown clear of the gas would be the cloud solving
		# itself, and walking out is the player's job.
		player.take_damage(TICK_DAMAGE, Vector2.ZERO, {}, false)


## Current size, which grows quickly and then keeps creeping.
func _radius() -> float:
	var t := clampf(_age / maxf(lifetime, 0.001), 0.0, 1.0)
	var bloom := clampf(t / BLOOM, 0.0, 1.0)
	# Eased, so the puff arrives fast and settles rather than popping to size.
	bloom = 1.0 - (1.0 - bloom) * (1.0 - bloom)
	return RADIUS * bloom + SPREAD * t


func contains(world_point: Vector2) -> bool:
	var local := to_local(world_point)
	# Squashed to match how it is drawn: the floor is seen at an angle, so a
	# round test under a flattened cloud gasses people standing clear of it.
	local.y /= 0.62
	return local.length() <= _radius()


func _draw() -> void:
	var t := clampf(_age / maxf(lifetime, 0.001), 0.0, 1.0)
	# Fades only over the tail. Dimming from the first frame would have it at
	# half strength while it is still doing full damage.
	var fade := 1.0 - clampf((t - (1.0 - FADE)) / FADE, 0.0, 1.0)
	if fade <= 0.0:
		return
	var r := _radius()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
	draw_circle(Vector2.ZERO, r, Color(COLOR_BODY, COLOR_BODY.a * fade))
	# Lobes around the rim, breathing on their own phases, so the puff churns
	# instead of sitting there as a disc. Six is enough to break the circle and
	# few enough to stay cheap -- there can be a lot of these on a floor.
	for i in 6:
		var a := TAU * float(i) / 6.0 + _seed + _age * 0.5
		var lobe := Vector2.from_angle(a) * r * 0.52
		var wob := 0.34 + 0.1 * sin(_age * 2.2 + float(i))
		draw_circle(lobe, r * wob, Color(COLOR_BODY, COLOR_BODY.a * 0.7 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(COLOR_EDGE, COLOR_EDGE.a * fade), 2.0)
	draw_set_transform(Vector2.ZERO)
