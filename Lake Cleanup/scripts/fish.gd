class_name Fish
extends Node2D
## The fish that come back to clean water: seen only as shadows under the surface and the
## rings they leave on it. Purely ambient, by decision (2026-09-16): nothing catches them,
## nothing pays for them, nothing aims at them. They live in water the filth map calls
## clean — the honest map, never the transient patch a catch opens — and come in tiers as
## the whole lake clears: minnows first, then perch-sized schools, then one big carp.
##
## Drawn between the water (z 2) and the splash layer (4) so the rings the splash layer
## draws lie over the shadow, as a ring on the surface lies over a fish under it.

## Clean share at which each tier appears, and what a school of it is.
##
## About a third more schools in every tier since 2026-09-18 (Richard: "increase fish
## population by a little"): `most` 14/7/2 to 18/9/3 and `per_tiles` 70/160/700 to
## 55/125/550. When each tier arrives, and what a school is, are as they were.
const TIERS := [
	{"at": 0.12, "size": Vector2(7.0, 3.0), "members": Vector2i(3, 6), "speed": 26.0,
		"per_tiles": 55.0, "most": 18, "ripple": 2.6, "span": 6.0, "ink": 0.22},
	{"at": 0.38, "size": Vector2(15.0, 6.0), "members": Vector2i(3, 5), "speed": 34.0,
		"per_tiles": 125.0, "most": 9, "ripple": 1.8, "span": 12.0, "ink": 0.28},
	{"at": 0.68, "size": Vector2(34.0, 13.0), "members": Vector2i(1, 1), "speed": 22.0,
		"per_tiles": 550.0, "most": 3, "ripple": 1.2, "span": 26.0, "ink": 0.34},
]
## Seconds between reconciling what should be swimming with what is.
const RECKON_EVERY := 2.0
## How far ahead a school looks before turning, in tiles, and how hard it turns per second.
const LOOK_AHEAD := 1.6
const TURN := 2.4
## A hull, a net landing or a splash within this many tiles sends a school away.
const FLEE_TILES := 3.0
const FLEE_SPEED := 3.0
const FLEE_TIME := 1.6
## The spread of a school round its leader, in world px, per unit of its shadow's length.
const SPREAD := 1.6
## A school that has left the clean water fades out and is replaced.
const FADE := 0.8

var grid: LakeGrid
var splash: WaterSplash
var boats: Array[Boat] = []
var stage: float = 0.0

## One dictionary a school: tier, at (world), heading (unit, world), members (offsets),
## wobble seeds, ripple clock, fade 0..1, flee timer.
var _schools: Array = []
var _clean_tiles := PackedInt32Array()
var _reckon_in: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 3
	z_as_relative = false
	_rng.seed = 20260916


func school_count() -> int:
	return _schools.size()


func schools() -> Array:
	return _schools


## The lake's clean water changed: `clean` is every water tile index the map calls clean.
func refresh(clean_share: float, clean: PackedInt32Array) -> void:
	stage = clean_share
	_clean_tiles = clean
	_reckon_in = 0.0


## Something hit the water at `at` (world): every school within reach turns and runs.
func scare(at: Vector2, reach_tiles: float = FLEE_TILES) -> void:
	var reach := Iso.tile_circle_extent(reach_tiles)
	for s: Dictionary in _schools:
		var off: Vector2 = (s["at"] as Vector2) - at
		if off.length() > reach:
			continue
		s["heading"] = _flat(off).normalized() if off.length() > 0.5 else Vector2.RIGHT
		s["flee"] = FLEE_TIME


func _process(delta: float) -> void:
	_reckon_in -= delta
	if _reckon_in <= 0.0:
		_reckon_in = RECKON_EVERY
		_reckon()
	if _schools.is_empty():
		return
	for boat in boats:
		if not is_instance_valid(boat):
			continue
		scare(boat.position, FLEE_TILES * 0.8)
	var gone: Array = []
	for s: Dictionary in _schools:
		_swim(s, delta)
		if float(s["fade"]) <= 0.0:
			gone.append(s)
	for s in gone:
		_schools.erase(s)
	queue_redraw()


## Bring the schools up to what the stage buys, and no further.
func _reckon() -> void:
	if grid == null:
		return
	var by_tier := [0, 0, 0]
	for s: Dictionary in _schools:
		by_tier[int(s["tier"])] += 1
	for tier in TIERS.size():
		var spec: Dictionary = TIERS[tier]
		if stage < float(spec["at"]):
			continue
		var want := mini(int(float(_clean_tiles.size()) / float(spec["per_tiles"])), int(spec["most"]))
		var have: int = by_tier[tier]
		if have >= want:
			continue
		for n in want - have:
			var s := _spawn(tier)
			if not s.is_empty():
				_schools.append(s)


func _spawn(tier: int) -> Dictionary:
	if _clean_tiles.is_empty():
		return {}
	var spec: Dictionary = TIERS[tier]
	for attempt in 12:
		var index := _clean_tiles[_rng.randi_range(0, _clean_tiles.size() - 1)]
		var tile := grid.tile_of(index)
		var at := Vector2(float(tile.x) + 0.5, float(tile.y) + 0.5)
		if not _swimmable(at):
			continue
		var count := _rng.randi_range(spec["members"].x, spec["members"].y)
		var members := PackedVector2Array()
		var reach := float(spec["size"].x) * SPREAD
		for i in count:
			members.append(Vector2(_rng.randf_range(-reach, reach), _rng.randf_range(-reach, reach) * 0.5))
		var angle := _rng.randf_range(0.0, TAU)
		return {
			"tier": tier, "at": Iso.tile_to_world(at.x, at.y),
			"heading": Vector2(cos(angle), sin(angle) * 0.5).normalized(),
			"members": members, "seed": _rng.randf() * 100.0, "ripple": _rng.randf() * 2.0,
			"fade": 0.0, "flee": 0.0, "rising": true,
		}
	return {}


## Water a fish may be in: the lake, clean on the map, off both shores.
func _swimmable(at: Vector2) -> bool:
	var tile := Vector2i(int(floor(at.x)), int(floor(at.y)))
	if not Iso.in_lake(tile.x, tile.y):
		return false
	if Iso.island_fraction(at.x, at.y) < 1.0 + Iso.SHELF_CLEAR + 0.4:
		return false
	if Iso.shore_fraction(at.x, at.y) > 0.93:
		return false
	return grid.water_state(grid.index_of(tile.x, tile.y)) == 0


func _swim(s: Dictionary, delta: float) -> void:
	var spec: Dictionary = TIERS[int(s["tier"])]
	var speed := float(spec["speed"])
	var flee := float(s["flee"])
	if flee > 0.0:
		s["flee"] = flee - delta
		speed *= FLEE_SPEED
	var at: Vector2 = s["at"]
	var heading: Vector2 = s["heading"]
	# A slow wander in the heading, so a school meanders rather than running a line.
	var t := float(Time.get_ticks_msec()) * 0.001 + float(s["seed"])
	var wander := sin(t * 0.7) * 0.6 + sin(t * 1.9) * 0.3
	heading = _turn(heading, wander * TURN * 0.4 * delta)
	# Look ahead; if that is not clean water, turn until it is.
	var ahead_tile := Iso.world_to_tile(at + heading * Iso.tile_circle_extent(LOOK_AHEAD))
	if not _swimmable(ahead_tile):
		var turned := false
		for k in range(1, 7):
			for sign in [1.0, -1.0]:
				var try := _turn(heading, sign * 0.5 * float(k))
				if _swimmable(Iso.world_to_tile(at + try * Iso.tile_circle_extent(LOOK_AHEAD))):
					heading = _turn(heading, sign * TURN * delta * 3.0)
					turned = true
					break
			if turned:
				break
		if not turned:
			s["fade"] = maxf(float(s["fade"]) - delta / FADE, 0.0)
			s["rising"] = false
	s["heading"] = heading
	at += heading * speed * delta
	s["at"] = at
	# Where the school is now: still clean? Otherwise fade away, and something new will come.
	if not _swimmable(Iso.world_to_tile(at)):
		s["rising"] = false
		s["fade"] = maxf(float(s["fade"]) - delta / FADE, 0.0)
	elif bool(s["rising"]):
		s["fade"] = minf(float(s["fade"]) + delta / FADE, 1.0)
	# The rings: one from the leader every so often, more often while fleeing.
	var clock := float(s["ripple"]) - delta * (3.0 if flee > 0.0 else 1.0)
	if clock <= 0.0:
		clock = float(spec["ripple"]) * _rng.randf_range(0.7, 1.3)
		if splash != null and float(s["fade"]) > 0.3:
			var m: PackedVector2Array = s["members"]
			var who := m[_rng.randi_range(0, m.size() - 1)] if not m.is_empty() else Vector2.ZERO
			splash.ripple(at + who, float(spec["span"]))
	s["ripple"] = clock


## Turn a heading on the plane (the 2:1 squash taken out and put back).
static func _turn(heading: Vector2, by: float) -> Vector2:
	var flat := Vector2(heading.x, heading.y * 2.0).rotated(by)
	return Vector2(flat.x, flat.y * 0.5).normalized()


static func _flat(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y)


func _draw() -> void:
	for s: Dictionary in _schools:
		var spec: Dictionary = TIERS[int(s["tier"])]
		var size: Vector2 = spec["size"]
		var ink := Color(0.02, 0.06, 0.08, float(spec["ink"]) * float(s["fade"]))
		var heading: Vector2 = s["heading"]
		var at: Vector2 = s["at"]
		var angle := atan2(heading.y * 2.0, heading.x)
		var t := float(Time.get_ticks_msec()) * 0.001 + float(s["seed"])
		var m: PackedVector2Array = s["members"]
		for i in m.size():
			var wag := sin(t * 6.0 + float(i) * 1.7) * 0.12
			var spot := at + m[i] + Vector2(sin(t * 1.3 + float(i)), cos(t * 1.1 + float(i) * 0.7) * 0.5) * 3.0
			_shadow(spot, size, angle + wag, ink)


## A fish-shaped shadow: an ellipse on the plane with a tail notch, squashed to the iso view.
func _shadow(at: Vector2, size: Vector2, angle: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	const N := 12
	for i in N:
		var a := TAU * float(i) / float(N)
		var x := cos(a) * size.x * 0.5
		var y := sin(a) * size.y * 0.5
		# Narrow towards the tail (negative x) and pinch it.
		if x < 0.0:
			y *= 0.55 + 0.45 * (1.0 + x / (size.x * 0.5))
		var p := Vector2(x, y).rotated(angle)
		pts.append(at + Vector2(p.x, p.y * 0.5))
	draw_colored_polygon(pts, ink)
