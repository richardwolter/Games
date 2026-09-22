class_name Wildlife
extends Node2D
## The animals that come back with the clean water (2026-09-22, `/grill-me` with Richard):
## frogs on the beaches and the pads, turtles basking at the water's edge, ducks with their
## ducklings landing on clean water, and dragonflies darting over it. Bees are Flora's.
##
## Purely ambient, like the fish: nothing catches them, nothing pays for them, nothing is
## saved. They live only where the filth map calls the water clean — the honest map, never a
## catch patch — and there are more of them the more of the lake is clean (`stage`), all of
## them from the first clean water. They do flee: a net landing, the angler or a dog walking
## up, a hull coming by. A frog jumps in, a turtle pulls its head in or dives, the ducks take
## off, a dragonfly darts away.
##
## Art: the frogs are the Pixel Frog pack recoloured onto the palette, everything else is
## built by rule (tools/build_wildlife.py). Pictures face left and are mirrored for right.
## Three draw layers: under the water's surface (the swimming frog's shadow), on it and the
## beaches, and in the air (flying ducks, dragonflies).

const FROG_SHEETS := ["res://assets/wildlife/frog_green.png", "res://assets/wildlife/frog_brown.png"]
const CRITTERS := "res://assets/wildlife/critters.png"
const CRITTER_TABLE := "res://assets/wildlife/critters.json"
## World px to a painted px, the game's own.
const SCALE := 2.0
## A frog cell is 16 painted px square (the pack halved); feet on row 15, column 8.
const FROG_CELL := 16.0
const FROG_FOOT := Vector2(8.0, 15.0)

## How many of each at a fully clean lake; `ceil(most * stage)` from the first clean water.
const FROGS_MOST := 30
const TURTLES_MOST := 14
const BROODS_MOST := 5
const DRAGONFLIES_MOST := 20
## Seconds between reconciling what should be about with what is.
const RECKON_EVERY := 2.0
## Seconds between one brood arriving and the next, at most one at a time.
const BROOD_GAP := Vector2(6.0, 16.0)

## Flee radii, tiles: something this close sends the animal off.
const FROG_SHY := 1.6
const TURTLE_SHY := 1.3
const DUCK_SHY := 2.6
const FLY_SHY := 1.1

## Frog timings. A sitting frog waits FROG_SIT_BEATS beats, then picks what to do and the
## beat to do it on: a hop or a jump is launched early enough to **land** on that beat, a
## croak starts on it and swells over FROG_CROAK_BEATS. Each frog picks its own beats, a
## few ahead (FROG_PICK_AHEAD), so the beach grooves without moving in lockstep.
const FROG_SIT_BEATS := Vector2i(3, 10)
const FROG_PICK_AHEAD := Vector2i(1, 3)
const FROG_CROAK_BEATS := 2.0
## A cue whose start is this many beats gone is a clock jump, not a late frame: re-pick it.
const CUE_MISSED := 0.25
const FROG_HOP_TIME := 0.45
const FROG_HOP_REACH := 0.5
const FROG_HOP_HIGH := 5.0
const FROG_JUMP_TIME := 0.62
const FROG_JUMP_HIGH := 14.0
const FROG_SWIM_SPEED := 22.0
const FROG_SWIM_FPS := 6.0
const FROG_SHADOW := 0.34
## How far a frog will swim for a pad, tiles.
const FROG_PAD_REACH := 7.0

## Turtle timings.
const TURTLE_WALK := 9.0
const TURTLE_SWIM := 11.0
const TURTLE_BASK := Vector2(6.0, 16.0)
const TURTLE_TUCK := 3.0
const TURTLE_UNDER := Vector2(2.0, 4.0)
## The walk is paced by ground covered, not by the clock: a turtle's legs step once for
## every TURTLE_STEP_PX world px it moves, so a turtle that is not going anywhere does not
## move its legs. Four frames, one leg at a time (tools/build_wildlife.py TURTLE_STRIDE).
const TURTLE_STEP_PX := 3.0
const TURTLE_STEPS := 4
## The head's slow nod: up one painted pixel for NOD_UP seconds out of every NOD_EVERY,
## each turtle out of step with the others. Resting and walking; not swimming or tucked.
## Since the beat pass: on every beat of the song, up on the beat and down on the off-beat,
## half the turtles a half beat behind the other half so they are not all in lockstep.

## Ducks.
const DUCK_SWIM := 14.0
const DUCK_FLY := 130.0
const DUCK_ALT := 150.0
const DUCK_FROM := 900.0
const DUCK_STAY := Vector2(40.0, 100.0)
const DUCKLINGS := Vector2i(0, 5)
## Leader positions kept for the ducklings to follow, one every TRAIL_STEP seconds.
const TRAIL_STEP := 0.12
const TRAIL_GAP := 4
## A flying duck's shadow: the pigeons' bargain.
const SHADE_GAIN := 2.4
const SHADE_MOST := 0.45
const SHADE_SHRINK := 0.35

## Dragonflies.
const FLY_ALT := Vector2(10.0, 18.0)
const FLY_DART := Vector2(0.18, 0.4)
const FLY_HOVER := Vector2(0.4, 2.2)
const FLY_ROAM := 3.0
const FLY_BODIES := [Color(0.38, 0.64, 0.86), Color(0.82, 0.32, 0.22), Color(0.46, 0.72, 0.36)]
const FLY_WING := Color(0.9, 0.96, 1.0, 0.55)
const ART := 2.0
## A dragonfly hovers a whole number of beats, then darts off on the next one.
const FLY_HOVER_BEATS := Vector2i(1, 5)

## The foam pixels a floating animal sits in.
const FOAM := Color(0.933, 0.965, 0.984, 0.8)
const SHADOW_INK := Color(0.02, 0.06, 0.08)
## Tracks in the sand (2026-09-22, Richard): a frog's hop leaves a pair of dents where it
## lands, a turtle leaves two rows of footprints either side of the drag of its shell. They
## fade over TRACK_LIFE; at most TRACKS_MOST are kept, oldest dropped. Sand only.
const TRACK_LIFE := 14.0
const TRACKS_MOST := 500
const TRACK_INK := Color(0.45, 0.33, 0.2, 0.5)
## How far a turtle walks between one set of prints and the next, world px.
const TURTLE_STRIDE := 6.0

var grid: LakeGrid
var splash: WaterSplash
var flora: Flora
var day: DayCycle
var crate_tile := Vector2.INF
## Tile points the animals keep clear of: the yards' feet and berths.
var avoid := PackedVector2Array()
## World points that frighten: the angler, the dogs, the hulls. Asked once a frame.
var threats: Callable
## The beat the animals move to (MusicStation.beat_clock). Without one they keep to a
## silent FALLBACK_BPM of their own.
var music: MusicStation
var stage: float = 0.0

var _frog_sheets: Array[Texture2D] = []
var _critters: Texture2D
var _table: Dictionary = {}
## One dictionary a shore spot: land/water (world), normal (world, unit, towards water),
## index (the water tile), side ("island" / "bank").
var _shore: Array = []
var _clean := PackedInt32Array()
var _pads := PackedVector2Array()
var _frogs: Array = []
var _turtles: Array = []
var _broods: Array = []
var _flies: Array = []
var _reckon_in := 0.0
var _brood_in := 3.0
var _now := 0.0
## One track mark each: world point (snapped to the art grid), age.
var _track_at := PackedVector2Array()
var _track_age := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()

var _under: Layer
var _ground: Layer
var _air: Layer


## A canvas of its own at its own z, painted by a callable on the owner.
class Layer:
	extends Node2D
	var paint: Callable

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)


func _ready() -> void:
	_rng.seed = 20260922
	for path: String in FROG_SHEETS:
		var tex := load(path) as Texture2D
		if tex != null:
			_frog_sheets.append(tex)
	_critters = load(CRITTERS) as Texture2D
	if FileAccess.file_exists(CRITTER_TABLE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CRITTER_TABLE))
		if parsed is Dictionary:
			_table = parsed
	_under = _layer(&"Under", 3, _paint_under)
	_ground = _layer(&"Ground", 6, _paint_ground)
	_air = _layer(&"Air", 20, _paint_air)
	if grid != null:
		_find_shore()


func _layer(name: StringName, z: int, paint: Callable) -> Layer:
	var layer := Layer.new()
	layer.name = name
	layer.z_index = z
	layer.z_as_relative = false
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.paint = paint
	add_child(layer)
	return layer


func ready_to_live() -> bool:
	return not _frog_sheets.is_empty() and _critters != null and not _table.is_empty()


func frog_count() -> int:
	return _frogs.size()


func turtle_count() -> int:
	return _turtles.size()


func brood_count() -> int:
	return _broods.size()


func dragonfly_count() -> int:
	return _flies.size()


func shore_count() -> int:
	return _shore.size()


func frogs() -> Array:
	return _frogs


func turtles() -> Array:
	return _turtles


func broods() -> Array:
	return _broods


func flies() -> Array:
	return _flies


## The lake's clean water changed: `clean` is every water tile index the map calls clean.
func refresh(clean_share: float, clean: PackedInt32Array) -> void:
	stage = clean_share
	_clean = clean
	_reckon_in = 0.0


## Forget every animal. For the harness, which refills the lake.
func reset() -> void:
	_frogs.clear()
	_turtles.clear()
	_broods.clear()
	_flies.clear()
	_track_at.resize(0)
	_track_age.resize(0)


## Something hit the water at `at` (world): everything within reach runs.
func scare(at: Vector2, reach_tiles: float = DUCK_SHY) -> void:
	var reach := Iso.tile_circle_extent(reach_tiles)
	for f: Dictionary in _frogs:
		if (f["at"] as Vector2).distance_to(at) < reach:
			_frog_fright(f, at)
	for t: Dictionary in _turtles:
		if (t["at"] as Vector2).distance_to(at) < reach:
			_turtle_fright(t, at)
	for b: Dictionary in _broods:
		if (b["at"] as Vector2).distance_to(at) < reach:
			_brood_fright(b, at)
	for d: Dictionary in _flies:
		if (d["at"] as Vector2).distance_to(at) < reach:
			_fly_fright(d, at)


## Beats since the song began, and a beat's length in seconds. See MusicStation.beat_clock.
func beat() -> float:
	if music != null:
		return music.beat_clock()
	return _now * MusicStation.FALLBACK_BPM / 60.0


func beat_length() -> float:
	if music != null:
		return music.beat_length()
	return 60.0 / MusicStation.FALLBACK_BPM


func _process(delta: float) -> void:
	_now += delta
	_reckon_in -= delta
	if _reckon_in <= 0.0:
		_reckon_in = RECKON_EVERY
		_reckon()
	_brood_in -= delta
	_age_tracks(delta)
	var seen := PackedVector2Array()
	if threats.is_valid():
		seen = threats.call()
	for f: Dictionary in _frogs:
		_frog_step(f, delta, seen)
	for t: Dictionary in _turtles:
		_turtle_step(t, delta, seen)
	for b: Dictionary in _broods:
		_brood_step(b, delta, seen)
	for d: Dictionary in _flies:
		_fly_step(d, delta, seen)
	_frogs = _frogs.filter(func(f: Dictionary) -> bool: return not f.get("gone", false))
	_turtles = _turtles.filter(func(t: Dictionary) -> bool: return not t.get("gone", false))
	_broods = _broods.filter(func(b: Dictionary) -> bool: return not b.get("gone", false))
	_flies = _flies.filter(func(d: Dictionary) -> bool: return not d.get("gone", false))
	_under.queue_redraw()
	_ground.queue_redraw()
	_air.queue_redraw()


# ---- where they live --------------------------------------------------------------------

## Every spot along both shores a frog or a turtle might call home: a point on the sand, the
## point in the water in front of it, and the tile that water is. Walked round both shores
## once, on bearings, by finding where each ray crosses the drawn water's edge.
func _find_shore() -> void:
	_shore.clear()
	for i in 90:
		var a := TAU * float(i) / 90.0
		var dir := Vector2(cos(a), sin(a))
		var edge := _cross(Iso.ISLAND_CENTRE, dir, 2.0, 16.0, func(p: Vector2) -> float: return Iso.past_shelf(p))
		if edge == Vector2.INF:
			continue
		_add_shore(edge - dir * 0.8, edge + dir * 1.1, dir, "island")
	for i in 160:
		var a := TAU * float(i) / 160.0
		var dir := Vector2(cos(a), sin(a))
		var edge := _cross(Iso.CENTRE, dir, 20.0, 50.0, func(p: Vector2) -> float: return Ground.out_of_water(p.x, p.y))
		if edge == Vector2.INF:
			continue
		_add_shore(edge + dir * 1.0, edge - dir * 1.1, -dir, "bank")


## Where along a ray a function goes from negative to positive, to a twentieth of a tile.
func _cross(from: Vector2, dir: Vector2, near: float, far: float, f: Callable) -> Vector2:
	var lo := near
	var hi := far
	if float(f.call(from + dir * lo)) > 0.0 or float(f.call(from + dir * hi)) < 0.0:
		return Vector2.INF
	for n in 12:
		var mid := (lo + hi) * 0.5
		if float(f.call(from + dir * mid)) > 0.0:
			hi = mid
		else:
			lo = mid
	return from + dir * (lo + hi) * 0.5


func _add_shore(land: Vector2, water: Vector2, normal: Vector2, side: String) -> void:
	if Iso.in_shed(land.x, land.y, Iso.SHED_COVER + 0.6):
		return
	if Pump.covers(land, 1.0):
		return
	if crate_tile != Vector2.INF and Yard.covers(crate_tile, land, 1.0):
		return
	for p in avoid:
		if land.distance_to(p) < 3.0 or water.distance_to(p) < 3.0:
			return
	var wt := Vector2i(int(floor(water.x)), int(floor(water.y)))
	if not Iso.in_lake(wt.x, wt.y) or grid == null:
		return
	var lw := Iso.tile_to_world(land.x, land.y)
	var ww := Iso.tile_to_world(water.x, water.y)
	_shore.append({
		"land": lw, "water": ww, "normal": (ww - lw).normalized(),
		"index": grid.index_of(wt.x, wt.y), "side": side,
	})


func _shore_clean(spot: Dictionary) -> bool:
	return grid.water_state(int(spot["index"])) == 0


## Is this world point on the beach its shore spot is on: dry, and not far up it.
func _on_sand(at: Vector2, side: String) -> bool:
	var tile := Iso.world_to_tile(at)
	if Iso.in_shed(tile.x, tile.y, Iso.SHED_COVER + 0.3) or Pump.covers(tile, 0.6):
		return false
	if crate_tile != Vector2.INF and Yard.covers(crate_tile, tile, 0.6):
		return false
	if side == "island":
		var shelf := Iso.past_shelf(tile)
		return shelf < -0.15 and shelf > -2.0
	var out := Ground.out_of_water(tile.x, tile.y)
	return out > 0.3 and out < 2.4


## Is this world point clean open water a thing may swim in.
func _swimmable(at: Vector2) -> bool:
	var tile := Iso.world_to_tile(at)
	var t := Vector2i(int(floor(tile.x)), int(floor(tile.y)))
	if not Iso.in_lake(t.x, t.y):
		return false
	if Iso.past_shelf(tile) < 0.15:
		return false
	if Ground.out_of_water(tile.x, tile.y) > -0.15:
		return false
	return grid.water_state(grid.index_of(t.x, t.y)) == 0


## Is this world point in the water as it is drawn (past both edges).
func _wet(at: Vector2) -> bool:
	var tile := Iso.world_to_tile(at)
	return Iso.past_shelf(tile) > 0.05 and Ground.out_of_water(tile.x, tile.y) < -0.05


func _clean_shore() -> Array:
	return _shore.filter(func(s: Dictionary) -> bool: return _shore_clean(s))


# ---- how many ---------------------------------------------------------------------------

func _want(most: int) -> int:
	if stage < 0.02:
		return 0
	return mini(ceili(float(most) * clampf(stage, 0.0, 1.0)), most)


func _reckon() -> void:
	if grid == null or not ready_to_live():
		return
	if flora != null:
		_pads = flora.pad_spots()
	var shore := _clean_shore()
	if not shore.is_empty():
		for n in maxi(_want(FROGS_MOST) - _frogs.size(), 0):
			_frogs.append(_new_frog(shore[_rng.randi_range(0, shore.size() - 1)]))
		for n in maxi(_want(TURTLES_MOST) - _turtles.size(), 0):
			_turtles.append(_new_turtle(shore[_rng.randi_range(0, shore.size() - 1)]))
	if _broods.size() < _want(BROODS_MOST) and _brood_in <= 0.0 and _clean.size() > 12:
		var b := _new_brood()
		if not b.is_empty():
			_broods.append(b)
			_brood_in = _rng.randf_range(BROOD_GAP.x, BROOD_GAP.y)
	if not shore.is_empty() or not _pads.is_empty():
		for n in maxi(_want(DRAGONFLIES_MOST) - _flies.size(), 0):
			_flies.append(_new_fly(shore))


func _nearest(at: Vector2, points: Array) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	for p: Vector2 in points:
		var d := p.distance_to(at)
		if d < bd:
			bd = d
			best = p
	return best


# ---- frogs ------------------------------------------------------------------------------

enum Frog { SIT, CROAK, HOP, JUMP, SWIM }


## A frog arrives out of the water: swimming in towards its shore, fading up as it comes.
func _new_frog(spot: Dictionary) -> Dictionary:
	var water: Vector2 = spot["water"]
	var start := water + (spot["normal"] as Vector2) * _rng.randf_range(16.0, 40.0)
	return {
		"state": Frog.SWIM, "at": start, "from": start, "to": water, "t": 0.0,
		"spot": spot, "sheet": _rng.randi_range(0, _frog_sheets.size() - 1),
		"row": 0, "timer": 0.0, "clock": _rng.randf() * 3.0, "fade": 0.0,
		"on_pad": false, "croaks": 0, "land_at": spot["land"],
	}


func _frog_step(f: Dictionary, delta: float, seen: PackedVector2Array) -> void:
	f["clock"] = float(f["clock"]) + delta
	f["fade"] = minf(float(f["fade"]) + delta / 0.8, 1.0)
	var at: Vector2 = f["at"]
	var state: int = f["state"]
	if state == Frog.SIT or state == Frog.CROAK or state == Frog.HOP:
		var shy := Iso.tile_circle_extent(FROG_SHY)
		for p in seen:
			if p.distance_to(at) < shy:
				_frog_fright(f, p)
				return
	match state:
		Frog.SIT:
			if f.has("plan"):
				_frog_on_cue(f)
			else:
				f["timer"] = float(f["timer"]) - delta
				if float(f["timer"]) <= 0.0:
					_frog_choose(f)
		Frog.CROAK:
			f["t"] = float(f["t"]) + delta / (FROG_CROAK_BEATS * beat_length())
			if float(f["t"]) >= 1.0:
				f["t"] = 0.0
				f["croaks"] = int(f["croaks"]) - 1
				if int(f["croaks"]) <= 0:
					_frog_sit(f)
		Frog.HOP, Frog.JUMP:
			var dur := FROG_HOP_TIME if state == Frog.HOP else FROG_JUMP_TIME
			f["t"] = float(f["t"]) + delta / dur
			var t := minf(float(f["t"]), 1.0)
			f["at"] = (f["from"] as Vector2).lerp(f["to"], t)
			if t >= 1.0:
				_frog_landed(f)
		Frog.SWIM:
			var to: Vector2 = f["to"]
			var step := to - at
			var go := FROG_SWIM_SPEED * delta
			if float(f.get("flee", 0.0)) > 0.0:
				f["flee"] = float(f["flee"]) - delta
				go *= 2.2
			var next := at + step.normalized() * go
			if step.length() <= go:
				f["at"] = to
				_frog_swum(f)
			elif not _wet(next):
				# Never over the sand: the shadow is under the water or nowhere. Out the
				# way its own shore faces, and a fresh place to go.
				f["at"] = at + ((f["spot"] as Dictionary)["normal"] as Vector2) * go
				f["to"] = _frog_swim_target(f)
			else:
				f["at"] = next
				f["row"] = _plane_heading(step)
			f["timer"] = float(f["timer"]) - delta
			if float(f["timer"]) <= 0.0:
				f["timer"] = _rng.randf_range(0.9, 1.8)
				if splash != null and float(f["fade"]) > 0.5:
					_ripple(f["at"], 7.0)


func _frog_sit(f: Dictionary) -> void:
	f["state"] = Frog.SIT
	f.erase("plan")
	f["timer"] = float(_rng.randi_range(FROG_SIT_BEATS.x, FROG_SIT_BEATS.y)) * beat_length()


## How many beats before its cue a move has to start so that it lands on the cue.
func _lead_of(kind: int) -> float:
	match kind:
		Frog.HOP:
			return FROG_HOP_TIME / beat_length()
		Frog.JUMP:
			return FROG_JUMP_TIME / beat_length()
	return 0.0


## What a sitting frog does next — croak, hop along the sand, or go for a swim — and the
## beat it does it on. Nothing moves yet: `_frog_on_cue` starts it when the beat comes.
func _frog_choose(f: Dictionary) -> void:
	var plan := _frog_plan(f)
	if plan.is_empty():
		_frog_sit(f)
		return
	var lead := _lead_of(int(plan["kind"]))
	f["plan"] = plan
	f["cue"] = floorf(beat() + lead) + float(_rng.randi_range(FROG_PICK_AHEAD.x, FROG_PICK_AHEAD.y))


## Start the planned move once its beat is near enough that it lands on it. The clock
## jumps when the heard song changes — backwards to a new song's start, or either way at
## a crossfade's handover — so a cue left far ahead, or already missed, is picked again
## on the new grid rather than waited for or fired late and off the beat.
func _frog_on_cue(f: Dictionary) -> void:
	var plan: Dictionary = f["plan"]
	var lead := _lead_of(int(plan["kind"]))
	var now := beat()
	var start := float(f["cue"]) - lead
	if start - now > 8.0 or now - start > CUE_MISSED:
		f["cue"] = floorf(now + lead) + 1.0
	if now < float(f["cue"]) - lead:
		return
	f.erase("plan")
	match int(plan["kind"]):
		Frog.CROAK:
			f["state"] = Frog.CROAK
			f["t"] = 0.0
			f["croaks"] = int(plan["croaks"])
		Frog.HOP:
			_frog_leap(f, plan["to"], Frog.HOP)
		Frog.JUMP:
			_frog_jump_in(f, f["at"])


## {kind, ...} for the next move, or empty to sit on.
func _frog_plan(f: Dictionary) -> Dictionary:
	var roll := _rng.randf()
	if roll < 0.3:
		return {"kind": Frog.CROAK, "croaks": _rng.randi_range(1, 2)}
	if roll < 0.75 and not bool(f["on_pad"]):
		var spot: Dictionary = f["spot"]
		var along := Vector2(-(spot["normal"] as Vector2).y, (spot["normal"] as Vector2).x)
		for attempt in 4:
			var to: Vector2 = (f["at"] as Vector2) + along * _rng.randf_range(-1.0, 1.0) * Iso.tile_circle_extent(FROG_HOP_REACH) \
				+ (spot["normal"] as Vector2) * _rng.randf_range(-6.0, 4.0)
			if _on_sand(to, String(spot["side"])) and to.distance_to(spot["land"]) < Iso.tile_circle_extent(1.4):
				return {"kind": Frog.HOP, "to": to}
	if roll < 0.87:
		return {"kind": Frog.JUMP}
	return {}


## Two dents a frog's feet leave where it lands (or takes off) on sand.
func _frog_prints(at: Vector2) -> void:
	if not _sandy(at):
		return
	_track(at + Vector2(-ART * 2.0, 0.0))
	_track(at + Vector2(ART, 0.0))


func _frog_leap(f: Dictionary, to: Vector2, kind: int) -> void:
	_frog_prints(f["at"])
	f["from"] = f["at"]
	f["to"] = to
	f["t"] = 0.0
	f["state"] = kind
	f["row"] = _row_of(to - (f["at"] as Vector2))


## Into the water: from the sand to the water in front of it, from a pad to the water beside.
func _frog_jump_in(f: Dictionary, away_from: Vector2) -> void:
	var at: Vector2 = f["at"]
	var to: Vector2
	if bool(f["on_pad"]):
		var off := at - away_from
		if off.length() < 1.0:
			off = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.5, 0.5))
		to = at + off.normalized() * 22.0
	else:
		var spot: Dictionary = f["spot"]
		to = (spot["water"] as Vector2) + Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-4.0, 4.0))
	f["on_pad"] = false
	f["dive"] = true
	_frog_leap(f, to, Frog.JUMP)


func _frog_landed(f: Dictionary) -> void:
	_frog_prints(f["at"])
	if bool(f.get("dive", false)):
		f["dive"] = false
		if splash != null:
			_ripple(f["at"], 10.0)
			_ripple(f["at"], 20.0)
		f["state"] = Frog.SWIM
		f["timer"] = 0.6
		f["to"] = _frog_swim_target(f)
		return
	_frog_sit(f)


## Somewhere to swim to: a pad in reach half the time, else a clean bit of shore.
func _frog_swim_target(f: Dictionary) -> Vector2:
	var at: Vector2 = f["at"]
	if not _pads.is_empty() and _rng.randf() < 0.5:
		var reach := Iso.tile_circle_extent(FROG_PAD_REACH)
		var near: Array = []
		for p in _pads:
			if p.distance_to(at) < reach and _clear_path(at, p):
				near.append(p)
		if not near.is_empty():
			f["pad"] = near[_rng.randi_range(0, near.size() - 1)]
			return f["pad"]
	f.erase("pad")
	var shore := _clean_shore()
	if shore.is_empty():
		return (f["spot"] as Dictionary)["water"]
	var best: Dictionary = f["spot"]
	var bd := INF
	for n in 10:
		var s: Dictionary = shore[_rng.randi_range(0, shore.size() - 1)]
		var d := (s["water"] as Vector2).distance_to(at)
		if d < bd and d < Iso.tile_circle_extent(FROG_PAD_REACH) and _clear_path(at, s["water"]):
			bd = d
			best = s
	f["spot"] = best
	return best["water"]


## A straight swim from `a` to `b` that stays in the water the whole way.
func _clear_path(a: Vector2, b: Vector2) -> bool:
	var n := maxi(int(a.distance_to(b) / 8.0), 1)
	for i in range(1, n + 1):
		if not _wet(a.lerp(b, float(i) / float(n))):
			return false
	return true


## Swum to where it was going: out onto the pad, or out onto the sand.
func _frog_swum(f: Dictionary) -> void:
	if f.has("pad"):
		var pad: Vector2 = f["pad"]
		f.erase("pad")
		f["on_pad"] = true
		_frog_leap(f, pad, Frog.JUMP)
	else:
		var spot: Dictionary = f["spot"]
		f["on_pad"] = false
		_frog_leap(f, spot["land"], Frog.JUMP)
	if splash != null:
		_ripple(f["at"], 9.0)


func _frog_fright(f: Dictionary, from: Vector2) -> void:
	var state: int = f["state"]
	if state == Frog.JUMP:
		return
	if state == Frog.SWIM:
		var off := (f["at"] as Vector2) - from
		if off.length() < 1.0:
			off = Vector2.RIGHT
		var to := (f["at"] as Vector2) + off.normalized() * 60.0
		if _swimmable(to):
			f["to"] = to
			f.erase("pad")
		f["flee"] = 1.2
		return
	_frog_jump_in(f, from)


# ---- turtles ----------------------------------------------------------------------------

enum Turtle { BASK, WALK, TUCK, SWIM, UNDER }


## A turtle arrives under the water in front of its beach, surfaces and swims in.
func _new_turtle(spot: Dictionary) -> Dictionary:
	var water: Vector2 = spot["water"]
	var at := water + (spot["normal"] as Vector2) * _rng.randf_range(20.0, 50.0)
	return {
		"state": Turtle.UNDER, "at": at, "to": water, "spot": spot, "timer": _rng.randf_range(0.5, 2.0),
		"facing": 1.0, "fade": 0.0, "clock": _rng.randf() * 4.0, "then": Turtle.SWIM,
		"nod_seed": 0.5 * float(_rng.randi_range(0, 1)), "walked": 0.0,
	}


func _turtle_step(t: Dictionary, delta: float, seen: PackedVector2Array) -> void:
	t["clock"] = float(t["clock"]) + delta
	var at: Vector2 = t["at"]
	var state: int = t["state"]
	if state != Turtle.UNDER and state != Turtle.TUCK:
		var shy := Iso.tile_circle_extent(TURTLE_SHY)
		for p in seen:
			if p.distance_to(at) < shy:
				_turtle_fright(t, p)
				return
	match state:
		Turtle.BASK:
			t["fade"] = minf(float(t["fade"]) + delta, 1.0)
			t["timer"] = float(t["timer"]) - delta
			if float(t["timer"]) <= 0.0:
				var spot: Dictionary = t["spot"]
				if _rng.randf() < 0.5:
					_turtle_walk(t, spot["water"])
				else:
					var along := Vector2(-(spot["normal"] as Vector2).y, (spot["normal"] as Vector2).x)
					var to := at + along * _rng.randf_range(-24.0, 24.0)
					if _on_sand(to, String(spot["side"])):
						_turtle_walk(t, to)
					else:
						t["timer"] = 3.0
		Turtle.TUCK:
			t["timer"] = float(t["timer"]) - delta
			if float(t["timer"]) <= 0.0:
				t["state"] = Turtle.BASK
				t["timer"] = _rng.randf_range(TURTLE_BASK.x, TURTLE_BASK.y)
		Turtle.WALK, Turtle.SWIM:
			var to: Vector2 = t["to"]
			var wet := _wet(at)
			var speed := TURTLE_SWIM if wet else TURTLE_WALK
			var step := to - at
			if absf(step.x) > 0.5:
				t["facing"] = 1.0 if step.x < 0.0 else -1.0
			var go := speed * delta
			if step.length() <= go:
				t["at"] = to
				_turtle_arrived(t)
			else:
				t["at"] = at + step.normalized() * go
			t["walked"] = float(t.get("walked", 0.0)) + minf(go, step.length())
			if not wet:
				t["stride"] = float(t.get("stride", 0.0)) + go
				if float(t["stride"]) >= TURTLE_STRIDE:
					t["stride"] = 0.0
					_turtle_prints(t["at"], step.normalized())
			var now_wet := _wet(t["at"])
			if now_wet != wet and splash != null:
				_ripple(t["at"], 12.0)
			t["state"] = Turtle.SWIM if now_wet else Turtle.WALK
			t["fade"] = minf(float(t["fade"]) + delta, 1.0)
		Turtle.UNDER:
			t["timer"] = float(t["timer"]) - delta
			if float(t["timer"]) <= 0.0:
				t["state"] = t["then"]
				t["fade"] = 0.0
				if splash != null:
					_ripple(at, 10.0)


## A turtle's prints: a foot each side of the line it walks, and the shell's drag between.
func _turtle_prints(at: Vector2, heading: Vector2) -> void:
	if not _sandy(at):
		return
	var across := Vector2(-heading.y, heading.x * 0.5).normalized() * ART * 2.5
	_track(at + across)
	_track(at - across)
	_track(at)


func _turtle_walk(t: Dictionary, to: Vector2) -> void:
	t["to"] = to
	t["state"] = Turtle.SWIM if _wet(t["at"]) else Turtle.WALK


## Where a walk or a swim ended: a turtle in the water swims a little and comes back out;
## one on the sand basks.
func _turtle_arrived(t: Dictionary) -> void:
	var spot: Dictionary = t["spot"]
	if _wet(t["at"]):
		if _rng.randf() < 0.55 or not _shore_clean(spot):
			# A paddle along the shallows, then out again somewhere near.
			var shore := _clean_shore()
			if not shore.is_empty() and _rng.randf() < 0.4:
				t["spot"] = shore[_rng.randi_range(0, shore.size() - 1)]
				if (t["spot"]["water"] as Vector2).distance_to(t["at"]) > Iso.tile_circle_extent(6.0):
					t["spot"] = spot
			var along := Vector2(-(spot["normal"] as Vector2).y, (spot["normal"] as Vector2).x)
			var to: Vector2 = (t["spot"]["water"] as Vector2) + along * _rng.randf_range(-30.0, 30.0)
			if _swimmable(to):
				t["to"] = to
				return
		t["to"] = (t["spot"] as Dictionary)["land"]
		return
	t["state"] = Turtle.BASK
	t["timer"] = _rng.randf_range(TURTLE_BASK.x, TURTLE_BASK.y)


func _turtle_fright(t: Dictionary, _from: Vector2) -> void:
	var state: int = t["state"]
	if state == Turtle.UNDER:
		return
	if _wet(t["at"]):
		# Dives, and comes up again a little way off.
		t["state"] = Turtle.UNDER
		t["timer"] = _rng.randf_range(TURTLE_UNDER.x, TURTLE_UNDER.y)
		t["then"] = Turtle.SWIM
		if splash != null:
			_ripple(t["at"], 12.0)
		var spot: Dictionary = t["spot"]
		t["at"] = (t["at"] as Vector2) + (spot["normal"] as Vector2) * 24.0
		t["to"] = spot["water"]
		return
	t["state"] = Turtle.TUCK
	t["timer"] = TURTLE_TUCK


# ---- ducks ------------------------------------------------------------------------------

enum Brood { FLY_IN, SWIM, DABBLE, TAKE_OFF }


## A brood flies in from off the lake to a clean tile: a drake alone, or a hen with ducklings.
func _new_brood() -> Dictionary:
	for attempt in 16:
		var index := _clean[_rng.randi_range(0, _clean.size() - 1)]
		var tile := grid.tile_of(index)
		var land := Iso.tile_to_world(float(tile.x) + 0.5, float(tile.y) + 0.5)
		if not _swimmable(land) or not _swimmable(land + Vector2(24.0, 0.0)) or not _swimmable(land - Vector2(24.0, 0.0)):
			continue
		var a := _rng.randf_range(0.0, TAU)
		var from := land + Vector2(cos(a), sin(a) * 0.5) * DUCK_FROM
		var hen := _rng.randf() < 0.65
		var kids := _rng.randi_range(maxi(DUCKLINGS.x, 1), DUCKLINGS.y) if hen else 0
		var kid_list: Array = []
		for k in kids:
			kid_list.append({"at": from, "wobble": _rng.randf() * 10.0})
		return {
			"state": Brood.FLY_IN, "at": from, "from": from, "to": land, "alt": DUCK_ALT,
			"t": 0.0, "kind": "hen" if hen else "drake", "kids": kid_list,
			"trail": PackedVector2Array(), "trail_in": 0.0, "facing": Flock.facing_of(from, land),
			"timer": _rng.randf_range(DUCK_STAY.x, DUCK_STAY.y), "wake": 0.0, "clock": _rng.randf() * 5.0,
			"goal": land,
		}
	return {}


func _brood_step(b: Dictionary, delta: float, seen: PackedVector2Array) -> void:
	b["clock"] = float(b["clock"]) + delta
	var state: int = b["state"]
	var at: Vector2 = b["at"]
	match state:
		Brood.FLY_IN:
			var span := (b["from"] as Vector2).distance_to(b["to"])
			b["t"] = float(b["t"]) + delta * DUCK_FLY / maxf(span, 1.0)
			var t := minf(float(b["t"]), 1.0)
			b["at"] = (b["from"] as Vector2).lerp(b["to"], t)
			# Glides down over the last stretch, not the whole way.
			b["alt"] = DUCK_ALT * clampf((1.0 - t) / 0.45, 0.0, 1.0)
			_kids_fly(b)
			if t >= 1.0:
				b["state"] = Brood.SWIM
				b["alt"] = 0.0
				if splash != null:
					_ripple(b["at"], 20.0)
					_ripple(b["at"], 34.0)
				for kid: Dictionary in b["kids"]:
					kid["at"] = b["at"]
		Brood.SWIM, Brood.DABBLE:
			var shy := Iso.tile_circle_extent(DUCK_SHY)
			for p in seen:
				if p.distance_to(at) < shy:
					_brood_fright(b, p)
					return
			b["timer"] = float(b["timer"]) - delta
			if float(b["timer"]) <= 0.0 or not _swimmable(at):
				_brood_fright(b, at + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)))
				return
			if state == Brood.DABBLE:
				b["dabble"] = float(b["dabble"]) - delta
				if float(b["dabble"]) <= 0.0:
					b["state"] = Brood.SWIM
			else:
				var goal: Vector2 = b["goal"]
				var step := goal - at
				if step.length() < 3.0:
					if _rng.randf() < 0.25:
						b["state"] = Brood.DABBLE
						b["dabble"] = _rng.randf_range(1.5, 3.0)
					b["goal"] = _duck_goal(at)
				else:
					var next := at + step.normalized() * DUCK_SWIM * delta
					if _swimmable(next):
						b["at"] = next
						if absf(step.x) > 0.5:
							b["facing"] = 1.0 if step.x < 0.0 else -1.0
					else:
						b["goal"] = _duck_goal(at)
				b["wake"] = float(b["wake"]) - delta
				if float(b["wake"]) <= 0.0:
					b["wake"] = _rng.randf_range(1.2, 2.0)
					if splash != null:
						_ripple(b["at"], 9.0)
			_kids_swim(b, delta)
		Brood.TAKE_OFF:
			var vel: Vector2 = b["vel"]
			b["t"] = float(b["t"]) + delta
			var speed := minf(float(b["t"]) * 140.0, DUCK_FLY * 1.2)
			b["at"] = at + vel * speed * delta
			b["alt"] = minf(float(b["alt"]) + delta * (40.0 + float(b["t"]) * 60.0), DUCK_ALT * 1.3)
			_kids_fly(b)
			if (b["at"] as Vector2).distance_to(b["from"]) > DUCK_FROM:
				b["gone"] = true


## A new place to paddle to, a couple of tiles off, on clean water.
func _duck_goal(at: Vector2) -> Vector2:
	for n in 8:
		var a := _rng.randf_range(0.0, TAU)
		var to := at + Vector2(cos(a), sin(a) * 0.5) * _rng.randf_range(30.0, 110.0)
		if _swimmable(to):
			return to
	return at


func _brood_fright(b: Dictionary, from: Vector2) -> void:
	if int(b["state"]) == Brood.TAKE_OFF or int(b["state"]) == Brood.FLY_IN:
		return
	var off := (b["at"] as Vector2) - from
	if off.length() < 1.0:
		off = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
	var dir := Vector2(off.x, off.y * 0.5).normalized()
	b["state"] = Brood.TAKE_OFF
	b["vel"] = dir
	b["from"] = b["at"]
	b["t"] = 0.0
	b["facing"] = 1.0 if dir.x < 0.0 else -1.0
	if splash != null:
		_ripple(b["at"], 18.0)
		for kid: Dictionary in b["kids"]:
			_ripple(kid["at"], 8.0)


## Ducklings on the water follow the leader's own wake, a few steps apart.
func _kids_swim(b: Dictionary, delta: float) -> void:
	b["trail_in"] = float(b["trail_in"]) - delta
	var trail: PackedVector2Array = b["trail"]
	if float(b["trail_in"]) <= 0.0:
		b["trail_in"] = TRAIL_STEP
		trail.insert(0, b["at"])
		var keep := ((b["kids"] as Array).size() + 1) * TRAIL_GAP + 1
		if trail.size() > keep:
			trail.resize(keep)
		b["trail"] = trail
	var kids: Array = b["kids"]
	for i in kids.size():
		var kid: Dictionary = kids[i]
		var k := mini((i + 1) * TRAIL_GAP, trail.size() - 1)
		var want: Vector2 = trail[k] if k >= 0 and trail.size() > 0 else b["at"]
		var at: Vector2 = kid["at"]
		var step := want - at
		if absf(step.x) > 0.3:
			kid["facing"] = 1.0 if step.x < 0.0 else -1.0
		kid["at"] = at + step * minf(delta * 4.0, 1.0)


## Ducklings in the air keep station behind the leader.
func _kids_fly(b: Dictionary) -> void:
	var kids: Array = b["kids"]
	var facing := float(b["facing"])
	for i in kids.size():
		var kid: Dictionary = kids[i]
		var row := float(i / 2 + 1)
		var side := -1.0 if i % 2 == 0 else 1.0
		kid["at"] = (b["at"] as Vector2) + Vector2(facing * 10.0 * row, side * 5.0 * row + 3.0)
		kid["facing"] = facing
	b["trail"] = PackedVector2Array()


# ---- dragonflies ------------------------------------------------------------------------

## A dragonfly keeps to a patch near a clean shore or over a pad, hovering and darting.
func _new_fly(shore: Array) -> Dictionary:
	var home: Vector2
	if not _pads.is_empty() and (shore.is_empty() or _rng.randf() < 0.5):
		home = _pads[_rng.randi_range(0, _pads.size() - 1)]
	else:
		var spot: Dictionary = shore[_rng.randi_range(0, shore.size() - 1)]
		home = (spot["water"] as Vector2).lerp(spot["land"], 0.4)
	return {
		"at": home, "from": home, "to": home, "home": home, "t": 1.0, "dur": 0.3,
		"timer": _rng.randf_range(FLY_HOVER.x, FLY_HOVER.y), "alt": _rng.randf_range(FLY_ALT.x, FLY_ALT.y),
		"heading": Vector2.LEFT, "body": _rng.randi_range(0, FLY_BODIES.size() - 1), "fade": 0.0,
		"jit": Vector2.ZERO,
	}


func _fly_step(d: Dictionary, delta: float, seen: PackedVector2Array) -> void:
	d["fade"] = minf(float(d["fade"]) + delta * 1.5, 1.0)
	var at: Vector2 = d["at"]
	if float(d["t"]) < 1.0:
		d["t"] = float(d["t"]) + delta / float(d["dur"])
		var t := minf(float(d["t"]), 1.0)
		var e := 1.0 - pow(1.0 - t, 3.0)
		d["at"] = (d["from"] as Vector2).lerp(d["to"], e)
		return
	var shy := Iso.tile_circle_extent(FLY_SHY)
	for p in seen:
		if p.distance_to(at) < shy:
			_fly_fright(d, p)
			return
	d["timer"] = float(d["timer"]) - delta
	# Hovering: a pixel of jitter now and then.
	if _rng.randf() < delta * 8.0:
		d["jit"] = Vector2(_rng.randi_range(-1, 1), _rng.randi_range(-1, 1)) * ART
	if float(d["timer"]) <= 0.0 and not d.has("cue"):
		d["cue"] = floorf(beat()) + 1.0
	if d.has("cue") and (beat() - float(d["cue"]) > CUE_MISSED or float(d["cue"]) - beat() > 2.0):
		d["cue"] = floorf(beat()) + 1.0
	if d.has("cue") and beat() >= float(d["cue"]):
		d.erase("cue")
		var home: Vector2 = d["home"]
		var reach := Iso.tile_circle_extent(FLY_ROAM)
		var a := _rng.randf_range(0.0, TAU)
		var to := home + Vector2(cos(a), sin(a) * 0.5) * _rng.randf_range(0.2, 1.0) * reach
		_fly_dart(d, to)


func _fly_dart(d: Dictionary, to: Vector2) -> void:
	d["from"] = d["at"]
	d["to"] = to
	d["t"] = 0.0
	d["dur"] = _rng.randf_range(FLY_DART.x, FLY_DART.y)
	d["timer"] = float(_rng.randi_range(FLY_HOVER_BEATS.x, FLY_HOVER_BEATS.y)) * beat_length()
	var step := to - (d["at"] as Vector2)
	if step.length() > 0.5:
		d["heading"] = step.normalized()
	d["jit"] = Vector2.ZERO


func _fly_fright(d: Dictionary, from: Vector2) -> void:
	var off := (d["at"] as Vector2) - from
	if off.length() < 1.0:
		off = Vector2.UP
	_fly_dart(d, (d["at"] as Vector2) + off.normalized() * Iso.tile_circle_extent(2.0))
	d["dur"] = 0.2


func _track(at: Vector2) -> void:
	if _track_at.size() >= TRACKS_MOST:
		_track_at.remove_at(0)
		_track_age.remove_at(0)
	_track_at.append((at / ART).floor() * ART)
	_track_age.append(0.0)


func _age_tracks(delta: float) -> void:
	var drop := 0
	for i in _track_age.size():
		_track_age[i] += delta
		if _track_age[i] >= TRACK_LIFE:
			drop = i + 1
	if drop > 0:
		_track_at = _track_at.slice(drop)
		_track_age = _track_age.slice(drop)


func track_count() -> int:
	return _track_at.size()


## Sand, of either shore, and dry: the only ground that takes a print.
func _sandy(at: Vector2) -> bool:
	var tile := Iso.world_to_tile(at)
	if Iso.island_fraction(tile.x, tile.y) < 1.5:
		return Iso.past_shelf(tile) < -0.1 and Iso.lawn_depth(tile) < -0.2
	var out := Ground.out_of_water(tile.x, tile.y)
	return out > 0.15 and out < Ground.BEACH_IN


## A ring on the water, if the splash layer has room: the animals may use at most half of
## its rings, so a net's landing ring or a walker's entry ring is never the one refused.
func _ripple(at: Vector2, span: float) -> void:
	if splash == null:
		return
	var rings: PackedFloat32Array = splash.get(&"_ripple_age")
	if rings.size() >= WaterSplash.MAX_RIPPLES / 2:
		return
	splash.ripple(at, span)


# ---- facing -----------------------------------------------------------------------------

## The frog sheet's row for a screen direction. The rows run S, SE, E, NE, N, NW, W, SW
## (read off the jump frames, which point the way the frog goes).  Screen angle k, in
## eighths clockwise from east, is row (2 - k).
static func _row_of(v: Vector2) -> int:
	if v.length() < 0.001:
		return 0
	var k := posmod(roundi(atan2(v.y, v.x) / (PI / 4.0)), 8)
	return posmod(2 - k, 8)


## The swim shadow's heading for a screen direction: eighths of a turn on the plane.
static func _plane_heading(v: Vector2) -> int:
	if v.length() < 0.001:
		return 0
	return posmod(roundi(atan2(v.y * 2.0, v.x) / (PI / 4.0)), 8)


# ---- drawing ----------------------------------------------------------------------------

func _region(name: String) -> Rect2:
	var r: Array = _table.get(name, [0, 0, 0, 0])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## A critter picture standing on `at`, facing (+1 left as drawn, -1 mirrored).
func _stamp(on: CanvasItem, name: String, at: Vector2, facing: float, tint: Color = Color.WHITE, scale_by: float = 1.0) -> void:
	var frame := _region(name)
	if frame.size.x <= 0.0:
		return
	Flock.stamp(on, _critters, frame, at, facing, tint, Transform2D.IDENTITY, Vector2.ZERO, scale_by * SCALE / Flock.SCALE)


func _paint_under(on: CanvasItem) -> void:
	for i in _track_at.size():
		var fade := 1.0 - _track_age[i] / TRACK_LIFE
		on.draw_rect(Rect2(_track_at[i], Vector2(ART, ART)), Color(TRACK_INK, TRACK_INK.a * fade))
	for f: Dictionary in _frogs:
		if int(f["state"]) != Frog.SWIM or not _wet(f["at"]):
			continue
		var frame: int = [0, 1, 2, 1][int(float(f["clock"]) * FROG_SWIM_FPS) % 4]
		var name := "frogswim_%d_%d" % [int(f["row"]), frame]
		var ink := Color(SHADOW_INK, FROG_SHADOW * float(f["fade"]))
		var r := _region(name)
		var at: Vector2 = f["at"]
		on.draw_texture_rect_region(_critters, Rect2(at - r.size * SCALE * 0.5, r.size * SCALE), r, ink)
	for t: Dictionary in _turtles:
		if int(t["state"]) != Turtle.UNDER:
			continue
		var r := _region("frogswim_0_1")
		var at: Vector2 = t["at"]
		on.draw_texture_rect_region(_critters, Rect2(at - r.size * SCALE * 0.5, r.size * SCALE * Vector2(1.2, 1.0)), r, Color(SHADOW_INK, 0.2))


func _paint_ground(on: CanvasItem) -> void:
	var items: Array = []
	for f: Dictionary in _frogs:
		if int(f["state"]) != Frog.SWIM:
			items.append([(f["at"] as Vector2).y, 0, f])
	for t: Dictionary in _turtles:
		if int(t["state"]) != Turtle.UNDER:
			items.append([(t["at"] as Vector2).y, 1, t])
	for b: Dictionary in _broods:
		if float(b["alt"]) <= 0.5:
			items.append([(b["at"] as Vector2).y, 2, b])
		else:
			items.append([(b["at"] as Vector2).y, 3, b])
	items.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) < float(c[0]))
	for item: Array in items:
		match int(item[1]):
			0:
				_draw_frog(on, item[2])
			1:
				_draw_turtle(on, item[2])
			2:
				_draw_brood_water(on, item[2])
			3:
				_draw_brood_shadow(on, item[2])


func _paint_air(on: CanvasItem) -> void:
	for b: Dictionary in _broods:
		if float(b["alt"]) > 0.5:
			_draw_brood_air(on, b)
	for d: Dictionary in _flies:
		_draw_fly(on, d)


func _draw_frog(on: CanvasItem, f: Dictionary) -> void:
	var sheet: Texture2D = _frog_sheets[int(f["sheet"]) % _frog_sheets.size()]
	var state: int = f["state"]
	var col := 0
	var lift := 0.0
	match state:
		Frog.SIT:
			col = [0, 0, 0, 1, 2, 1][int(float(f["clock"]) * 4.0) % 6]
		Frog.CROAK:
			col = [3, 4, 5, 6, 6, 5, 4, 3][mini(int(float(f["t"]) * 8.0), 7)]
		Frog.HOP:
			var t := clampf(float(f["t"]), 0.0, 1.0)
			col = 11 + mini(int(t * 5.0), 4)
			lift = sin(t * PI) * FROG_HOP_HIGH
		Frog.JUMP:
			var t := clampf(float(f["t"]), 0.0, 1.0)
			col = 7 if t < 0.12 else (9 if t < 0.5 else (10 if t < 0.88 else 8))
			lift = sin(t * PI) * FROG_JUMP_HIGH
	var at: Vector2 = f["at"]
	if lift > 0.5:
		# A small shadow on the ground under a frog in the air.
		var shade := PackedVector2Array()
		for i in 8:
			var a := TAU * float(i) / 8.0
			shade.append(at + Vector2(cos(a) * 5.0, sin(a) * 2.0))
		on.draw_colored_polygon(shade, Color(SHADOW_INK, 0.18 * float(f["fade"])))
	var row: int = f["row"]
	var src := Rect2(float(col) * FROG_CELL, float(row) * FROG_CELL, FROG_CELL, FROG_CELL)
	var box := Rect2((at - FROG_FOOT * SCALE - Vector2(0.0, lift)).round(), Vector2(FROG_CELL, FROG_CELL) * SCALE)
	on.draw_texture_rect_region(sheet, box, src, Color(1.0, 1.0, 1.0, float(f["fade"])))


func _draw_turtle(on: CanvasItem, t: Dictionary) -> void:
	var state: int = t["state"]
	var name := "turtle_sit"
	match state:
		Turtle.TUCK:
			name = "turtle_tuck"
		Turtle.WALK:
			var stride := int(float(t.get("walked", 0.0)) / TURTLE_STEP_PX) % TURTLE_STEPS
			name = "turtle_walk%d%s" % [stride, _nod(t)]
		Turtle.SWIM:
			name = "turtle_swim%d" % (int(float(t["clock"]) * 1.2) % 2)
		Turtle.BASK:
			# Pulls its head in now and then, for a few seconds.
			name = "turtle_tuck" if fmod(float(t["clock"]), 24.0) > 20.5 else "turtle_sit" + _nod(t)
	var at: Vector2 = t["at"]
	var bob := 0.0
	if state == Turtle.SWIM:
		# Rides up a pixel for a second every six: a slow breath, not a jitter.
		bob = ART if fmod(float(t["clock"]), 6.0) > 5.0 else 0.0
		at += Vector2(0.0, ART * 2.0)
	var tint := Color(1.0, 1.0, 1.0, float(t["fade"]))
	_stamp(on, name, at + Vector2(0.0, -bob), float(t["facing"]), tint)
	if state == Turtle.SWIM:
		_collar(on, at + Vector2(0.0, -bob), 16.0, float(t["clock"]), float(t["fade"]))


## "_up" while this turtle's head is lifted in its slow nod, "" otherwise.
func _nod(t: Dictionary) -> String:
	var phase := fposmod(beat() + float(t.get("nod_seed", 0.0)), 1.0)
	return "_up" if phase < 0.5 else ""


func _draw_brood_water(on: CanvasItem, b: Dictionary) -> void:
	var kind := String(b["kind"])
	var clock := float(b["clock"])
	for kid: Dictionary in b["kids"]:
		var kat: Vector2 = kid["at"]
		var name := "duckling_swim%d" % (int(clock * 2.0 + float(kid["wobble"])) % 2)
		_stamp(on, name, kat.round(), float(kid.get("facing", b["facing"])))
		_collar(on, kat, 9.0, clock + float(kid["wobble"]), 1.0)
	var pose := "dabble" if int(b["state"]) == Brood.DABBLE else "swim%d" % (int(clock * 1.6) % 2)
	var at: Vector2 = b["at"]
	_stamp(on, "%s_%s" % [kind, pose], at.round(), float(b["facing"]))
	_collar(on, at, 20.0, clock, 1.0)


## A flying brood's shadow on the water: its own silhouette laid down by the sun.
func _draw_brood_shadow(on: CanvasItem, b: Dictionary) -> void:
	if day == null:
		return
	var up := clampf(float(b["alt"]) / DUCK_ALT, 0.0, 1.0)
	var ink := minf(day.ink * SHADE_GAIN, SHADE_MOST) * (1.0 - 0.5 * up)
	var frame := _region("%s_%s" % [String(b["kind"]), _fly_pose(b)])
	Flock.stamp(on, _critters, frame, Vector2.ZERO, float(b["facing"]), Shade.tint(ink),
		Shade.lying(b["at"], day.lean, day.stretch), Vector2.ZERO, (1.0 - SHADE_SHRINK * up) * SCALE / Flock.SCALE)


func _fly_pose(b: Dictionary) -> String:
	return ["fly0", "fly1", "fly2", "fly1"][int(float(b["clock"]) * 10.0) % 4]


func _draw_brood_air(on: CanvasItem, b: Dictionary) -> void:
	var lift := Vector2(0.0, -float(b["alt"]))
	var clock := float(b["clock"])
	for kid: Dictionary in b["kids"]:
		var name := "duckling_fly%d" % (int(clock * 14.0 + float(kid["wobble"])) % 2)
		_stamp(on, name, ((kid["at"] as Vector2) + lift).round(), float(kid.get("facing", b["facing"])))
	_stamp(on, "%s_%s" % [String(b["kind"]), _fly_pose(b)], ((b["at"] as Vector2) + lift).round(), float(b["facing"]))


## Whole foam pixels along the waterline either side of a floating animal, torn by time.
func _collar(on: CanvasItem, at: Vector2, wide: float, clock: float, fade: float) -> void:
	var beat := int(clock * 2.0)
	var y: float = floor(at.y / ART) * ART
	var x0: float = floor((at.x - wide * 0.5) / ART) * ART
	var n := int(wide / ART)
	for i in n:
		var h := fmod(sin(float(i) * 12.9898 + float(beat) * 78.233) * 43758.5453, 1.0)
		if absf(h) < 0.45:
			continue
		on.draw_rect(Rect2(x0 + float(i) * ART, y - ART * 0.5, ART, ART), Color(FOAM, FOAM.a * fade))


## A dragonfly on whole art pixels: head, thorax and a long abdomen along its heading
## (snapped to eighths), two pairs of wings flicking, a faint dot of shadow on the water.
func _draw_fly(on: CanvasItem, d: Dictionary) -> void:
	var fade := float(d["fade"])
	var ground := ((d["at"] as Vector2) / ART).floor() * ART
	on.draw_rect(Rect2(ground, Vector2(ART, ART)), Color(SHADOW_INK, 0.18 * fade))
	var at := ground + Vector2(0.0, -float(d["alt"])).snapped(Vector2(ART, ART)) + (d["jit"] as Vector2)
	var h: Vector2 = d["heading"]
	var k := posmod(roundi(atan2(h.y, h.x) / (PI / 4.0)), 8)
	var dir := Vector2(roundf(cos(float(k) * PI / 4.0)), roundf(sin(float(k) * PI / 4.0)))
	var side := Vector2(-dir.y, dir.x)
	var body: Color = FLY_BODIES[int(d["body"])]
	body.a = fade
	var dark := body.darkened(0.45)
	var wing := Color(FLY_WING, FLY_WING.a * fade)
	var beat := int(_now * 22.0) % 2 == 0
	var wing_at := at - dir * ART if beat else at - dir * ART * 2.0
	for s in [1.0, -1.0]:
		on.draw_rect(Rect2(wing_at + side * ART * s, Vector2(ART, ART)), wing)
		on.draw_rect(Rect2(wing_at + side * ART * 2.0 * s, Vector2(ART, ART)), wing)
		on.draw_rect(Rect2(wing_at + (side * ART * s) - dir * ART, Vector2(ART, ART)), wing)
	on.draw_rect(Rect2(at + dir * ART, Vector2(ART, ART)), dark)
	on.draw_rect(Rect2(at, Vector2(ART, ART)), body)
	for i in range(1, 5):
		on.draw_rect(Rect2(at - dir * ART * float(i), Vector2(ART, ART)), body if i < 4 else dark)
