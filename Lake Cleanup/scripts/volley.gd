## Purified water, fired from the shed and from the boats.
##
## Ammo is not a weapon the player aims. Netting an ammo charm loads everything that can
## already shoot — the hut on the island and every hull on the lake — and they pick their
## own targets for as long as it lasts. That is deliberate: the player has one pair of
## hands and they are busy with the net, so the fleet's job is to be somewhere useful, not
## to be micromanaged.
##
## Shots are stepped along their flight at a fixed distance per step and tested at each
## step, so a fast shot on a slow frame
## cannot step over the thing it should have hit.
class_name Volley
extends Node2D

## How far a shot travels in a second, in tiles, and the longest step it may take before
## testing what it has passed through.
const SPEED := 22.0
const STEP := 0.5

## How close, in tiles, a shot has to pass to a blob to hit it.
const HIT := 0.9

## What one shot takes off, and how far a gun can reach.
const DAMAGE := 9.0
const RANGE := 16.0

## Seconds between shots from one gun. The shed is the steady one; a boat is smaller and
## has a smaller crew.
const SHED_EVERY := 0.55
const BOAT_EVERY := 0.85

## How long a shot's trail is drawn for, in tiles behind the head.
const TRAIL := 1.6

## Everything the guns need to know about.
var swarm: SludgeSwarm
var splash: WaterSplash
var sfx: Sfx

## The hulls that can shoot, filled in by the siege. The shed is not in here: it does not
## move, so its gun is a constant.
var boats: Array = []

## True while there is ammo. Nothing fires otherwise, and this is the only switch.
var armed: bool = false

## Shots in the air.
var shots: Array = []

var _shed_in: float = 0.0
var _boat_in: PackedFloat32Array = PackedFloat32Array()


## Where the shed's gun sits, in tile space: the middle of its footprint.
func shed_muzzle() -> Vector2:
	return Iso.ISLAND_CENTRE


func _process(delta: float) -> void:
	_advance(delta)
	if armed and swarm != null:
		_load_guns(delta)
	queue_redraw()


## Every gun on its own clock, so the fleet does not fire in one volley.
func _load_guns(delta: float) -> void:
	_shed_in -= delta
	if _shed_in <= 0.0:
		if _fire_from(shed_muzzle()):
			_shed_in = SHED_EVERY
		else:
			# Nothing in reach: try again shortly rather than banking up shots to spend
			# the moment something wanders into range.
			_shed_in = 0.2

	while _boat_in.size() < boats.size():
		_boat_in.append(0.0)
	for i in boats.size():
		var boat: Boat = boats[i]
		if boat == null:
			continue
		_boat_in[i] -= delta
		if _boat_in[i] > 0.0:
			continue
		_boat_in[i] = BOAT_EVERY if _fire_from(boat.tile_pos) else 0.25


## One shot, at whatever is nearest that gun. False when there was nothing to shoot at.
func _fire_from(from: Vector2) -> bool:
	var target := swarm.blob_near(from, RANGE)
	if target < 0:
		return false
	var to := swarm.tile_of(target)
	shots.append({
		"at": from,
		"aim": (to - from).normalized(),
		"gone": 0.0,
		"span": from.distance_to(to) + 2.0,
	})
	if sfx != null:
		sfx.play_pop()
	return true


## Walk every shot forward. Stepped rather than lerped, and tested at each step.
func _advance(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot: Dictionary = shots[i]
		var left := SPEED * delta
		var spent := false
		while left > 0.0 and not spent:
			var step := minf(STEP, left)
			left -= step
			shot["at"] = (shot["at"] as Vector2) + (shot["aim"] as Vector2) * step
			shot["gone"] = float(shot["gone"]) + step
			var at: Vector2 = shot["at"]
			if swarm != null:
				var hit := swarm.blob_near(at, HIT)
				if hit >= 0:
					swarm.hurt(hit, DAMAGE)
					if splash != null:
						splash.splash(Iso.tile_to_world(at.x, at.y), 0.45)
					spent = true
					break
			# Past its target and still nothing, or out over the bank: the water it was
			# made of goes back into the lake.
			#
			# The bank, not the island. Every shot the shed fires starts on the island by
			# definition, so expiring a shot for not being over water would kill each one on
			# its first step and leave the hut firing blanks.
			if (
				float(shot["gone"]) >= float(shot["span"])
				or Iso.shore_fraction(at.x, at.y) >= 1.0
			):
				spent = true
		if spent:
			shots.remove_at(i)


## A shot is a bright head with a short tail behind it — enough to read as something
## crossing the water at speed without drawing a beam across the whole lake.
func _draw() -> void:
	for shot: Dictionary in shots:
		var at: Vector2 = shot["at"]
		var aim: Vector2 = shot["aim"]
		var head := Iso.tile_to_world(at.x, at.y)
		var tail_tile := at - aim * TRAIL
		var tail := Iso.tile_to_world(tail_tile.x, tail_tile.y)
		draw_line(tail, head, Color(0.62, 0.86, 0.98, 0.35), 3.0)
		draw_line(tail.lerp(head, 0.5), head, Color(0.90, 0.98, 1.0, 0.75), 2.2)
		draw_circle(head, 3.4, Color(0.95, 1.0, 1.0, 0.9))
		draw_circle(head, 6.0, Color(0.65, 0.90, 1.0, 0.22))
