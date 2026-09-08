## The things that come out of the water when the lake goes bad.
##
## One node owns the whole swarm, the way the flock owns every pigeon: a monster is a row
## in an array and a shape in one `_draw`, not a scene with a script and a body on it.
## There is no physics here either — a blob is a point in tile space that walks towards the
## island, and everything that happens to it is an analytic test against a tile radius.
##
## What they want is the shed. They swim in from the rim of the basin, stop at the island's
## shore because they cannot climb it, and hammer at the hut from the water.
class_name SludgeSwarm
extends Node2D

## Swimming in, hitting the shed, and sinking. A dying blob is kept for a moment so there
## is something to see: a monster that vanishes on its last point of health reads as a
## rendering bug rather than a kill.
enum State { SWIM, ATTACK, DYING }

## Tiles a second at full health and no ice on it.
const SPEED := 2.6

## How much slower and clumsier a fully frozen blob is. Ice never stops one dead: a monster
## frozen in place beside the shed would be a monster the player can ignore.
const CHILL_SPEED := 0.35
const CHILL_SWING := 0.45

## How long a blob holds its chill after leaving the ice, in seconds. Without this an ice
## field reads as a wall rather than as cold water.
const CHILL_FADE := 3.0

## Where it stops: how far out from the island's middle, as island_fraction, a blob has to
## be before it can reach the shed. Just off the beach, so the swarm rings the island
## rather than piling onto it.
const REACH := 1.5

## Seconds between blows, and what one blow takes off the shed.
const ATTACK_EVERY := 1.8
const ATTACK_DAMAGE := 6.0

## Health of a first-wave blob, and what each wave after adds to it.
##
## The per-wave figure is gentle because there are a dozen waves to get through: the siege
## gets longer and thicker rather than each monster turning into a wall, which keeps the
## last wave a matter of covering the water rather than of standing still and out-damaging
## one blob at a time.
const HEALTH := 24.0
const HEALTH_PER_WAVE := 5.0

## Sludge paid for a kill. The siege has no rubbish to sell, so this is where the money
## comes from: killing things is the economy now.
const BOUNTY := 7.0

## Drawn size in world pixels at full health, and how much of that a blob loses as it is
## worn down. A hurt monster is visibly smaller, which is the readout that does not need a
## bar over its head.
const BODY := Vector2(44.0, 30.0)
const WORN := 0.35

## How long the sink takes, in seconds.
const SINK := 0.55

var grid: LakeGrid
var sfx: Sfx
var splash: WaterSplash

## Every blob. Dictionaries, like the flock's birds, for the same reason: adding a field to
## a monster should not be a refactor.
var blobs: Array = []

## Emitted when a blob lands a blow on the shed, and when one dies.
signal struck(damage: float)
signal died(at: Vector2, bounty: float)

var _rng := RandomNumberGenerator.new()
var _time: float = 0.0


func _ready() -> void:
	_rng.randomize()


## Put a blob on the water at the rim of the basin.
##
## Angle first, position second: they come from all the way round rather than from a spawn
## point, so no side of the island is ever the safe one.
func add_blob(wave: int = 1, angle: float = -1.0) -> bool:
	var turn := angle if angle >= 0.0 else _rng.randf() * TAU
	var at := Iso.basin_point(turn, 0.94)
	if not Iso.in_lake(int(at.x), int(at.y)):
		return false
	var health := HEALTH + HEALTH_PER_WAVE * float(maxi(wave - 1, 0))
	blobs.append({
		"tile": at,
		"health": health,
		"whole": health,
		"state": State.SWIM,
		"chill": 0.0,
		"burn": 0.0,
		"attack_in": _rng.randf_range(0.0, ATTACK_EVERY),
		"phase": _rng.randf() * TAU,
		"sink": 0.0,
	})
	queue_redraw()
	return true


## How many are still coming. A dying blob does not count: the wave is over when nothing
## left in the water can still reach the shed.
func alive() -> int:
	var count := 0
	for blob: Dictionary in blobs:
		if int(blob["state"]) != State.DYING:
			count += 1
	return count


## The nearest living blob within `radius` tiles of a point, or -1. The shape the volley
## and the net's fields both ask their question in.
func blob_near(at: Vector2, radius: float) -> int:
	var best := -1
	var closest := radius
	for i in blobs.size():
		var blob: Dictionary = blobs[i]
		if int(blob["state"]) == State.DYING:
			continue
		var gap := (blob["tile"] as Vector2).distance_to(at)
		if gap <= closest:
			closest = gap
			best = i
	return best


## Where a blob is, in tile space.
func tile_of(index: int) -> Vector2:
	if index < 0 or index >= blobs.size():
		return Vector2.ZERO
	return blobs[index]["tile"]


## Take health off one. Safe to call on anything, including something already dying.
func hurt(index: int, amount: float) -> void:
	if index < 0 or index >= blobs.size():
		return
	var blob: Dictionary = blobs[index]
	if int(blob["state"]) == State.DYING:
		return
	blob["health"] = float(blob["health"]) - amount
	if float(blob["health"]) <= 0.0:
		_kill(blob)


## An area soaked in something for one frame: fire burns, ice chills, and a cast carrying
## both does both. This is the one call the enchanted net makes, every frame it lies on the
## water, so it takes a delta and applies a rate rather than a lump.
func soak(at: Vector2, radius: float, burn: float, chill: float, delta: float) -> void:
	# Guarded the same way as the step loop: hurting one of these ends in a signal, and a
	# listener is allowed to do anything, including taking the rest of the swarm away.
	for i in range(blobs.size() - 1, -1, -1):
		if i >= blobs.size():
			continue
		var blob: Dictionary = blobs[i]
		if int(blob["state"]) == State.DYING:
			continue
		if (blob["tile"] as Vector2).distance_to(at) > radius:
			continue
		if chill > 0.0:
			blob["chill"] = maxf(float(blob["chill"]), chill)
		if burn > 0.0:
			blob["burn"] = 1.0
			hurt(i, burn * delta)


func _process(delta: float) -> void:
	_time += delta
	# Walked backwards and guarded, because a blob's own step can empty this array out from
	# under the loop: a blow lands, the shed falls, and the siege calls off the whole swarm
	# inside the signal. Anything that hits the shed on the frame it goes down would take
	# the run down with it otherwise.
	for i in range(blobs.size() - 1, -1, -1):
		if i >= blobs.size():
			continue
		if not _step(blobs[i], delta):
			if i < blobs.size():
				blobs.remove_at(i)
	# The swarm breathes on its own clock, so any blob at all earns the frame. None means
	# there is no siege on, and the layer has nothing in it.
	if not blobs.is_empty():
		queue_redraw()


## One blob, one frame. False means it is gone.
func _step(blob: Dictionary, delta: float) -> bool:
	# The chill wears off wherever it is, and the burn glow is re-lit every frame the blob
	# is still in the fire, so both fade on their own the moment the net is moved.
	blob["chill"] = maxf(float(blob["chill"]) - delta / CHILL_FADE, 0.0)
	blob["burn"] = maxf(float(blob["burn"]) - delta * 3.0, 0.0)
	blob["phase"] = float(blob["phase"]) + delta * (1.6 + 1.4 * (1.0 - float(blob["chill"])))

	match int(blob["state"]):
		State.DYING:
			blob["sink"] = float(blob["sink"]) + delta / SINK
			return float(blob["sink"]) < 1.0
		State.SWIM:
			var at: Vector2 = blob["tile"]
			var toward := Iso.ISLAND_CENTRE - at
			if toward.length() < 0.001:
				return true
			var pace := SPEED * lerpf(1.0, CHILL_SPEED, float(blob["chill"]))
			var next := at + toward.normalized() * pace * delta
			blob["tile"] = next
			if Iso.island_fraction(next.x, next.y) <= REACH:
				blob["state"] = State.ATTACK
		State.ATTACK:
			# Frozen things swing slower as well as swim slower, which is what makes ice
			# worth casting on something that is already at the wall.
			var rate := lerpf(1.0, CHILL_SWING, float(blob["chill"]))
			blob["attack_in"] = float(blob["attack_in"]) - delta * rate
			if float(blob["attack_in"]) <= 0.0:
				blob["attack_in"] = ATTACK_EVERY
				_strike(blob)
	return true


## One blow.
func _strike(blob: Dictionary) -> void:
	struck.emit(ATTACK_DAMAGE)
	if sfx != null:
		sfx.play_splash(0.7)
	if splash != null:
		splash.splash(_world_of(blob), 0.5)


func _kill(blob: Dictionary) -> void:
	blob["state"] = State.DYING
	blob["sink"] = 0.0
	if splash != null:
		splash.splash(_world_of(blob), 0.8)
	if sfx != null:
		sfx.play_pop()
	died.emit(_world_of(blob), BOUNTY)


func _world_of(blob: Dictionary) -> Vector2:
	var at: Vector2 = blob["tile"]
	return Iso.tile_to_world(at.x, at.y)


## The swarm, drawn flat on the plane like everything else on this water: a squashed body
## in a ring of disturbed water, a paler crust when it is frozen, and a glow when it burns.
func _draw() -> void:
	for blob: Dictionary in blobs:
		var at := _world_of(blob)
		var worn := clampf(float(blob["health"]) / maxf(float(blob["whole"]), 0.001), 0.0, 1.0)
		var sink := float(blob["sink"])
		var fade := 1.0 - sink
		var swell := 1.0 + 0.08 * sin(float(blob["phase"]))
		var body := BODY * lerpf(1.0 - WORN, 1.0, worn) * swell * (1.0 - sink * 0.6)

		# The water it is standing in.
		draw_circle(
			at + Vector2(0.0, body.y * 0.30), body.x * 0.62,
			Color(1.0, 1.0, 1.0, 0.10 * fade)
		)

		var chill := float(blob["chill"])
		var skin := Color(0.10, 0.13, 0.11).lerp(Color(0.55, 0.72, 0.82), chill * 0.7)
		var burn := float(blob["burn"])
		if burn > 0.0:
			skin = skin.lerp(Color(0.95, 0.45, 0.15), clampf(burn, 0.0, 1.0) * 0.6)
			draw_circle(at, body.x * 0.85, Color(1.0, 0.55, 0.2, 0.22 * burn * fade))
		skin.a = fade

		_wobble(at, body, skin, float(blob["phase"]))
		# Two eyes, the only part of it that is not muck. They are what turns a dark shape
		# on dark water into something looking back.
		var glare := Color(0.95, 0.88, 0.45, fade * 0.9)
		draw_circle(at + Vector2(-body.x * 0.16, -body.y * 0.28), 2.4, glare)
		draw_circle(at + Vector2(body.x * 0.16, -body.y * 0.28), 2.4, glare)


## A lumpy ellipse: ten points around a squashed circle, each pushed in or out by its own
## slow wave, so the thing crawls rather than slides.
func _wobble(at: Vector2, body: Vector2, skin: Color, phase: float) -> void:
	var ring := PackedVector2Array()
	for i in 10:
		var angle := TAU * float(i) / 10.0
		var push := 1.0 + 0.16 * sin(phase * 1.7 + angle * 3.0)
		ring.append(at + Vector2(cos(angle) * body.x * 0.5, sin(angle) * body.y * 0.5) * push)
	draw_colored_polygon(ring, skin)
	var edge := ring.duplicate()
	edge.append(ring[0])
	draw_polyline(edge, Color(0.03, 0.05, 0.04, skin.a * 0.8), 1.6)
