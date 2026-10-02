extends Node2D
## The tornado (2026-09-30, `/grill-me` with Richard; CLAUDE.md "The Tornado"): a waterspout
## that comes down on a nearly cleaned lake, wanders within the net's reach of the island,
## lifts the top piece off the tiles it passes into its orbit and flings some back out onto
## open water, and is tamed by landing the net on its foot three times.
##
## Everything that happens to the lake is done here, ported from the approved mock's harness
## (tools/tornado_mock/harness.gd); the drawing is `tornado_look.gd`, the mock's look D, driven
## through the same `setup`/`tick` API. The lake owns the schedule's inputs (the gate, the
## holds) and the holds on the fleet and the pack (`began`/`ended`).
##
## No piece is ever lost: a piece is in the grid, in `_debris` (orbiting), in `_flung` (in the
## air) or in a net's catch. `carrying()` counts the two middle ones, and the lake's ending
## waits on it. `settle_now()` puts everything back in the water at once (the menu, a save).
##
## No class_name: the lake preloads it by path.

const DebrisDraw := preload("res://scripts/tornado_debris_draw.gd")
const Look := preload("res://scripts/tornado_look.gd")

signal began
signal ended(tamed: bool)
## A piece went into (negative) or came back to (positive) the water: the meter's move.
signal filth_moved(by: float)
## Something moved the water enough that the filth map should be remapped.
signal remap_owed

# --- The schedule ----------------------------------------------------------------------
## Cleaned share (1 - pollution) past which a run may have tornadoes.
const GATE := 0.8
## How many a run: rolled once, from this range, inclusive.
const MOST_RANGE := Vector2i(2, 3)
## Seconds of play after the gate first opens, then between tornadoes.
const FIRST_AFTER := Vector2(20.0, 70.0)
const GAP := Vector2(150.0, 300.0)
## A due tornado that is held (a board, a tour) is asked again this often.
const HELD_RETRY := 4.0

# --- The event, seconds ----------------------------------------------------------------
## The storm comes in (rain, grey light) before the funnel touches down.
const BREW := 6.0
const TOUCH_END := 2.0
## Untamed, it wanders off this long after touching down.
const LIFE := 60.0
const HIT_LONG := 0.6
const COLLAPSE_LONG := 1.5
## From the vanish starting to the event being over: the look's cloud is gone by 2.85 s.
const GONE_AFTER := 3.4
## A second landing this soon after a hit is the same throw (the double cast): not a hit.
const HIT_APART := 0.5
## How long the storm the tornado brings is poured for (it is cleared when the event ends).
const STORM_LONG := 600.0

# --- The funnel (the mock's numbers) ---------------------------------------------------
const HEIGHT := 300.0
const BASE_R := 12.0
const TOP_R := 72.0
const HIT_STRENGTH: Array[float] = [0.74, 0.5]
## The foot a net's mouth has to touch, half-extents in world px, at full strength.
const FOOT := Vector2(30.0, 15.0)

# --- Moving ----------------------------------------------------------------------------
const SPEED_TOUCH := 10.0
const SPEED_ROAM := 60.0
const SPEED_HURT := 34.0
const SPEED_COLLAPSE := 12.0
## Tiles past the island's shore it keeps between; the far end is the net's range less
## `RANGE_SPARE`, so the player can always reach it from the beach.
const GROW_LEAST := 2.2
const GROW_MOST := 16.0
const RANGE_SPARE := 1.2
const KNOCK := 26.0

# --- Debris (the mock's numbers) -------------------------------------------------------
const LIFT_REACH := 0.9
const LIFT_GAP := 0.14
const RELIFT_AFTER := 3.0
const CARRY_MOST := 14
const LIFT_TIME := 0.9
const FLING_EVERY := 1.2
const FLING_FULL := 0.55
const FLING_FROM := 6
const LIFT_TIER_MOST := 3

# --- Water -----------------------------------------------------------------------------
const SHOVE_REACH := 2.6
const SHOVE_PUSH := 22.0
const BUMP_REACH := 1.8
const REMAP_EVERY := 0.5
const SCARE_EVERY := 0.5

## The wind's loop, when Nuven records one: played on the Ambience bus while a tornado is
## down. Silent until the file exists.
const WIND_SOUND := "res://assets/sfx/wind.ogg"
const WIND_DB := -12.0

var grid: LakeGrid
var splash: WaterSplash
var weather: Weather
var day: DayCycle
var angler: Node2D
var fish: Node
## `func() -> float`: the net's range in tiles.
var net_range: Callable

## Saved: how many this run, how many it will have, seconds until the next (-1 unrolled).
var count := 0
var most := 0
var next_in := -1.0

var _rng := RandomNumberGenerator.new()
var _active := false
var _clock := 0.0          # seconds since the event began (brew included)
var _t := -1.0             # the look's clock: seconds since touchdown began, -1 brewing
var _phase := "off"
var _phase_t := 0.0
var _strength := 0.0
var _hits := 0
var _look_hits := 0
var _hit_flash := 0.0
var _hit_at := -99.0
var _end_at := -1.0
var _end_from := 1.0
var _tamed := false
var _spin := 0.0
var _theta := 0.0
var _grow := 4.0
var _seed := 0.0
var _base := Vector2.ZERO
var _base_was := Vector2.ZERO
var _velocity := Vector2.ZERO
var _lean := Vector2.ZERO
var _knock := Vector2.ZERO

var _debris: Array[Dictionary] = []
var _flung: Array[Dictionary] = []
var _lifted_at := {}
var _lift_in := 0.0
var _fling_in := FLING_EVERY
var _remap_in := 0.0
var _remap_dirty := false
var _scare_in := 0.0
var _ripple_in := 0.0
var _core_ripple_in := 0.0
var _bump_in := 0.0
var _collapse_in := 0.0
var _catch_net: Node = null

var _look: Node2D
var _shadows: _Layer
var _flung_layer: _Layer
var _wind: AudioStreamPlayer
var _state := {}

## For the harness: what happened this event.
var lifted := 0
var landed := 0
var netted := 0


func _ready() -> void:
	_rng.randomize()
	if most <= 0:
		most = _rng.randi_range(MOST_RANGE.x, MOST_RANGE.y)


# ======================================================================================
# The schedule
# ======================================================================================

## Saved values back in. Absent keys read as none yet.
func restore(done: int, next: float, run_most: int) -> void:
	count = maxi(done, 0)
	next_in = next
	if run_most > 0:
		most = run_most


## Once a frame from the lake, while the world runs. `cleaned` is 1 - pollution; `held` is
## true while a tornado must not start (intro, tours, boards, the ending).
func tick_schedule(delta: float, cleaned: float, held: bool) -> void:
	if _active or count >= most:
		return
	if next_in < 0.0:
		if cleaned >= GATE:
			next_in = _rng.randf_range(FIRST_AFTER.x, FIRST_AFTER.y) if count == 0 \
				else _rng.randf_range(GAP.x, GAP.y)
		return
	if cleaned < GATE:
		return
	next_in -= delta
	if next_in > 0.0:
		return
	if held:
		next_in = HELD_RETRY
		return
	start()


func active() -> bool:
	return _active


## Is the funnel down (touchdown to the end of the vanish)?
func down() -> bool:
	return _active and _t >= 0.0


func base() -> Vector2:
	return _base


## Pieces out of the water and not in a net: orbiting, or in the air.
func carrying() -> int:
	return _debris.size() + _flung.size()


func hits() -> int:
	return _hits


# ======================================================================================
# The event
# ======================================================================================

## Begin a tornado now. `angle` (radians round the island, tile space) is where it comes
## down; NAN picks one near the angler, so the player sees it arrive.
func start(angle: float = NAN) -> void:
	if _active or grid == null:
		return
	_active = true
	_clock = 0.0
	_t = -1.0
	_phase = "brew"
	_phase_t = 0.0
	_strength = 0.0
	_hits = 0
	_look_hits = 0
	_hit_flash = 0.0
	_hit_at = -99.0
	_end_at = -1.0
	_tamed = false
	_spin = 0.0
	_knock = Vector2.ZERO
	_lean = Vector2.ZERO
	_debris.clear()
	_flung.clear()
	_lifted_at.clear()
	lifted = 0
	landed = 0
	netted = 0
	_seed = _rng.randf() * TAU
	if is_nan(angle):
		if angler != null:
			var at := Iso.world_to_tile(angler.position) - Iso.ISLAND_CENTRE
			angle = atan2(at.y, at.x) if at.length() > 0.1 else _rng.randf() * TAU
		else:
			angle = _rng.randf() * TAU
		angle += _rng.randf_range(-0.8, 0.8)
	_theta = angle
	_grow = lerpf(GROW_LEAST, _grow_most(), 0.5)
	_base = Iso.island_point(_theta, _grow)
	_base_was = _base
	if weather != null:
		weather.storm(STORM_LONG)
	began.emit()


## The event is over (tamed or wandered off): everything back to how it was.
func _finish() -> void:
	# Nothing may be left in the air.
	while not _debris.is_empty():
		_throw(0, 1.5, 0.3)
	for f in _flung:
		_land(f)
	_flung.clear()
	_drop_look()
	if weather != null:
		weather.clear_storm()
	_stop_wind()
	_active = false
	_phase = "off"
	_t = -1.0
	count += 1
	next_in = _rng.randf_range(GAP.x, GAP.y) if count < most else -1.0
	if _remap_dirty:
		remap_owed.emit()
	ended.emit(_tamed)


## At once, for the menu's pose and a save: every carried piece is put back on the water
## where it would have landed (or where it was lifted), and the event ends untamed.
func settle_now() -> void:
	if not _active:
		return
	for d in _debris:
		var idx := _landing_tile(_base + (d["ground"] as Vector2), Vector2(cos(float(d["angle"])), sin(float(d["angle"]))), 1.5, int(d["from_tile"]))
		_put_back(idx, int(d["def_index"]))
	_debris.clear()
	for f in _flung:
		_put_back(int(f["tile"]), int(f["def_index"]))
	_flung.clear()
	_finish()


func _put_back(idx: int, def_index: int) -> void:
	if idx < 0:
		return
	grid.insert(idx, grid.height_of(idx), def_index)
	filth_moved.emit(1.0)
	_remap_dirty = true
	landed += 1


func _grow_most() -> float:
	var r := 4.0
	if net_range.is_valid():
		r = float(net_range.call())
	return clampf(r - RANGE_SPARE, GROW_LEAST + 0.3, GROW_MOST)


func _process(delta: float) -> void:
	if not _active:
		return
	delta = minf(delta, 0.1)
	_clock += delta
	_phase_t += delta
	if _t < 0.0:
		if _clock < BREW:
			return
		_t = 0.0
		_set_phase("touchdown")
		_make_look()
		if weather != null:
			weather.strike()
		_start_wind()
	else:
		_t += delta
	_step(delta)


func _set_phase(p: String) -> void:
	if p == _phase:
		return
	_phase = p
	_phase_t = 0.0


func _step(delta: float) -> void:
	var t := _t
	if _end_at < 0.0 and t >= TOUCH_END + LIFE:
		_begin_end(false)
	if _end_at >= 0.0:
		if t >= _end_at + GONE_AFTER:
			_finish()
			return
		_set_phase("gone" if t >= _end_at + COLLAPSE_LONG else "collapse")
	elif _hits > 0 and t < _hit_at + HIT_LONG:
		_set_phase("hit")
	elif t < TOUCH_END:
		_set_phase("touchdown")
	else:
		_set_phase("roam")
	_strength = _strength_at(t)
	_hit_flash = maxf(_hit_flash - delta * 2.2, 0.0)
	_spin += delta * lerpf(3.0, 7.0, _strength)

	var speed := SPEED_ROAM
	match _phase:
		"touchdown": speed = SPEED_TOUCH
		"hit": speed = SPEED_HURT * 0.4
		"collapse": speed = SPEED_COLLAPSE
		"gone": speed = 0.0
		_: speed = SPEED_HURT if _hits > 0 else SPEED_ROAM
	_wander(speed, delta)
	_knock *= exp(-2.5 * delta)
	var meander := Vector2(sin(t * 1.3) * 10.0, cos(t * 0.9) * 4.0) * minf(_strength * 1.5, 1.0)
	_base_was = _base
	_base = Iso.island_point(_theta, _grow) + meander + _knock
	_velocity = (_base - _base_was) / maxf(delta, 0.0001)
	var want_lean := -_velocity * 0.55 + Vector2(sin(t * 0.8) * 14.0, 0.0)
	_lean = _lean.lerp(want_lean, 1.0 - exp(-2.0 * delta))

	_track_carried(delta)
	if _strength > 0.35 and _end_at < 0.0:
		_lift(delta)
		_fling_now(delta)
	_tick_flung(delta)
	_tick_collapse(delta)
	_water(delta)

	_remap_in -= delta
	if _remap_in <= 0.0:
		_remap_in = REMAP_EVERY
		if _remap_dirty:
			_remap_dirty = false
			remap_owed.emit()
	_scare_in -= delta
	if _scare_in <= 0.0 and _end_at < 0.0:
		_scare_in = SCARE_EVERY
		if fish != null and fish.has_method(&"scare"):
			fish.scare(_base)
	_push_state(delta)


## Round the island at a speed of `speed` world px/s, turning back now and then, in and out
## between the beach and the net's reach, all on smooth sines off the event's own seed.
func _wander(speed: float, delta: float) -> void:
	var p0 := Iso.island_point(_theta, _grow)
	var per_rad := p0.distance_to(Iso.island_point(_theta + 0.01, _grow)) / 0.01
	var way := clampf(sin(_t * 0.09 + _seed) * 1.8 + 0.25, -1.0, 1.0)
	_theta += way * speed * delta / maxf(per_rad, 1.0)
	var lo := GROW_LEAST
	var hi := _grow_most()
	var want := lerpf(lo, hi, 0.5 + 0.5 * sin(_t * 0.23 + _seed * 1.7))
	_grow = move_toward(_grow, want, delta * 0.8)
	_grow = clampf(_grow, lo, hi)


func _strength_at(t: float) -> float:
	if t < TOUCH_END:
		return smoothstep(0.0, TOUCH_END, t)
	if _end_at >= 0.0:
		var u := clampf((t - _end_at - 0.1) / (COLLAPSE_LONG - 0.3), 0.0, 1.0)
		return _end_from * (1.0 - u) * (1.0 - u) * (1.0 + 0.15 * sin(u * 20.0) * (1.0 - u))
	if _hits == 0:
		return 1.0
	var target: float = HIT_STRENGTH[_hits - 1]
	var since := t - _hit_at
	var dip := 0.14 * exp(-since * 5.0) * cos(since * 14.0)
	var from := 1.0 if _hits == 1 else HIT_STRENGTH[_hits - 2]
	var u2 := smoothstep(0.0, 0.25, since)
	return lerpf(from, target, u2) - dip


func axis_at(frac: float) -> Vector2:
	var h := HEIGHT * _strength * frac
	var snake := Vector2(sin(_t * 1.7 + frac * 3.0) * 7.0 * frac, 0.0)
	var jolt := Vector2(sin(_t * 40.0) * 10.0 * _hit_flash * frac, 0.0)
	return Vector2(_lean.x * frac * frac, _lean.y * 0.2 * frac) + snake + jolt - Vector2(0.0, h)


func radius_at(frac: float) -> float:
	var r := lerpf(BASE_R, TOP_R, pow(clampf(frac, 0.0, 1.0), 1.4))
	return r * lerpf(0.45, 1.0, _strength) * (1.0 + 0.25 * _hit_flash)


# ======================================================================================
# Hits
# ======================================================================================

## Does a net's mouth, down at `at`, touch the foot?
func touches(at: Vector2, mouth: float) -> bool:
	if not down() or _end_at >= 0.0 or _phase == "touchdown":
		return false
	var s := clampf(_strength, 0.5, 1.0)
	return CastNet._touches(at, mouth, _base, FOOT * s)


## A net landed: a hit if it came down on the foot. Returns whether it was one.
func net_down(net: Node, at: Vector2, mouth: float) -> bool:
	if not touches(at, mouth):
		return false
	if _t - _hit_at < HIT_APART:
		return false
	_hits += 1
	_hit_at = _t
	_hit_flash = 1.0
	var away := (_base - angler.position).normalized() if angler != null else Vector2.RIGHT
	_knock += away * KNOCK
	for k in 8:
		var a := TAU * float(k) / 8.0
		splash.ripple(_base + Vector2(cos(a) * 22.0, sin(a) * 11.0), 10.0)
	splash.ripple(_base, 30.0)
	if _hits < 3:
		_look_hits = _hits
		for k in mini(2, _debris.size()):
			_throw(_rng.randi_range(0, _debris.size() - 1), _rng.randf_range(2.0, 3.5), 0.4)
		_fling_in = maxf(_fling_in, 0.6)
	else:
		_tamed = true
		_catch_net = net
		_into_net(net)
		_begin_end(true)
	return true


## The third hit: what the funnel carries falls into that net, up to its room. The rest is
## let go onto the water by `_tick_collapse`.
func _into_net(net: Node) -> void:
	if net == null or not net.has_method(&"room_left"):
		return
	# Highest first, as it sheds.
	_debris.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["height"]) > float(b["height"]))
	while not _debris.is_empty() and int(net.room_left()) > 0:
		var d: Dictionary = _debris.pop_front()
		var held: PackedInt32Array = net.get(&"catch")
		held.append(int(d["def_index"]))
		net.set(&"catch", held)
		netted += 1


## The vanish: the look's collapse, tamed or not. Untamed it drops what it carries onto the
## water; tamed, whatever the net had no room for.
func _begin_end(tamed: bool) -> void:
	if _end_at >= 0.0:
		return
	_end_at = _t
	_end_from = maxf(_strength, 0.3)
	_look_hits = 3
	_hit_at = _t
	_collapse_in = 0.15
	if weather != null:
		weather.strike()


func _tick_collapse(delta: float) -> void:
	if _end_at < 0.0 or _debris.is_empty():
		return
	_collapse_in -= delta
	while _collapse_in <= 0.0 and not _debris.is_empty():
		_collapse_in += 0.06
		var pick := 0
		for i in _debris.size():
			if float(_debris[i]["height"]) > float(_debris[pick]["height"]):
				pick = i
		_throw(pick, _rng.randf_range(1.5, 3.5), 0.25)


# ======================================================================================
# Debris
# ======================================================================================

func _lift(delta: float) -> void:
	_lift_in -= delta
	if _lift_in > 0.0 or _debris.size() >= CARRY_MOST:
		return
	var here := Iso.world_to_tile(_base)
	var centre := grid.tile_at(_base)
	if centre < 0:
		return
	var best := -1
	var best_d := INF
	for index: int in grid.tiles_within(centre, 2.0):
		var st := grid.stacks[index]
		if st.is_empty() or grid.dry[index] == 1:
			continue
		if _t - float(_lifted_at.get(index, -99.0)) < RELIFT_AFTER:
			continue
		var def := grid.defs[st[st.size() - 1]]
		if def.keepsake or def.tier > LIFT_TIER_MOST:
			continue
		var dd := (Vector2(grid.tile_of(index)) + Vector2(0.5, 0.5)).distance_to(here)
		if dd <= LIFT_REACH and dd < best_d:
			best = index
			best_d = dd
	if best < 0:
		return
	_lift_in = LIFT_GAP
	var from := grid.surface_pos(best)
	var def_index := grid.take(best, grid.top_slot(best))
	_lifted_at[best] = _t
	filth_moved.emit(-1.0)
	_remap_dirty = true
	lifted += 1
	var rel := from - _base
	var circ := Vector2(rel.x, rel.y * 2.0)
	_debris.append({
		"def_index": def_index, "def": grid.defs[def_index], "state": "lift", "age": 0.0,
		"angle": atan2(circ.y, circ.x), "r0": circ.length(), "radius": circ.length(),
		"height": 0.0, "band": _rng.randf_range(0.22, 0.88), "margin": _rng.randf_range(6.0, 22.0),
		"seed": _rng.randf() * TAU, "whirl": _rng.randf_range(0.75, 1.35), "rot": grid.tilt[best],
		"spin_rate": _rng.randf_range(-5.0, 5.0),
		"scale": 1.0, "alpha": 1.0, "local": rel, "front": rel.y > 0.0, "depth": rel.y,
		"ground": rel, "from_tile": best,
	})
	splash.ripple(from, 10.0)


func _track_carried(delta: float) -> void:
	for d: Dictionary in _debris:
		d["age"] = float(d["age"]) + delta
		var hf := 0.0
		var rr := 0.0
		var band: float = d["band"]
		var w := lerpf(3.4, 1.9, band) * float(d["whirl"]) * lerpf(0.7, 1.0, _strength)
		d["angle"] = float(d["angle"]) + w * delta
		if d["state"] == "lift":
			var u := clampf(float(d["age"]) / LIFT_TIME, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - u, 3.0)
			hf = band * e
			rr = lerpf(float(d["r0"]), radius_at(hf) + float(d["margin"]), smoothstep(0.0, 0.7, u))
			if u >= 1.0:
				d["state"] = "orbit"
		else:
			var sd: float = d["seed"]
			band = clampf(band + sin(_t * 0.7 + sd) * 0.05 * delta, 0.15, 0.92)
			d["band"] = band
			hf = band + sin(_t * 2.3 + sd) * 0.02
			rr = radius_at(hf) + float(d["margin"])
		var a: float = d["angle"]
		var axis := axis_at(hf)
		var ring := Vector2(cos(a) * rr, sin(a) * rr * 0.5)
		d["local"] = axis + ring
		d["ground"] = Vector2(axis.x, 0.0) + ring
		d["height"] = -axis.y
		d["radius"] = rr
		d["front"] = sin(a) > 0.0
		d["depth"] = sin(a)
		d["rot"] = float(d["rot"]) + float(d["spin_rate"]) * delta


func _fling_now(delta: float) -> void:
	_fling_in -= delta
	if _fling_in > 0.0:
		return
	if _debris.size() <= FLING_FROM:
		_fling_in = 0.2
		return
	_fling_in = FLING_EVERY
	var pick := -1
	for i in _debris.size():
		if _debris[i]["state"] == "orbit":
			pick = i
			break
	if pick >= 0:
		_throw(pick, _rng.randf_range(2.5, 4.5), 0.75)
	if _debris.size() >= CARRY_MOST - 1:
		_fling_in = FLING_FULL


## A floating tile about `tiles` out from `from` along `dir` (tried a few ways round), or the
## tile the piece came from, so a piece always has water to land on.
func _landing_tile(from: Vector2, dir: Vector2, tiles: float, fallback: int) -> int:
	for attempt in 12:
		var turn := (0.35 * float((attempt + 1) / 2)) * (1.0 if attempt % 2 == 0 else -1.0)
		var dd := dir.rotated(turn)
		var reach := tiles * (1.0 - 0.06 * float(attempt / 4))
		var world := from + Vector2(dd.x, dd.y * 0.5) * Iso.tile_circle_extent(reach)
		var idx := grid.tile_at(world)
		if idx < 0:
			continue
		var tile := grid.tile_of(idx)
		if not Iso.floats_here(tile.x, tile.y) or grid.dry[idx] == 1:
			continue
		return idx
	return fallback


func _throw(i: int, tiles: float, tangent: float) -> void:
	var d: Dictionary = _debris[i]
	_debris.remove_at(i)
	var a: float = d["angle"]
	var out := Vector2(cos(a), sin(a))
	var tan := Vector2(-sin(a), cos(a))
	var dir := (tan * tangent + out * (1.0 - tangent * 0.5)).normalized()
	var from: Vector2 = _base + (d["ground"] as Vector2)
	var target := _landing_tile(from, dir, tiles, int(d["from_tile"]))
	var to := grid.surface_still(target) if target >= 0 else from
	var dist := from.distance_to(to)
	_flung.append({
		"def_index": d["def_index"], "def": d["def"], "from": from, "to": to, "tile": target,
		"t": 0.0, "dur": 0.7 + dist / 420.0, "h0": float(d["height"]),
		"peak": 30.0 + dist * 0.25, "rot": float(d["rot"]), "spin": _rng.randf_range(-9.0, 9.0),
		"at": from - Vector2(0.0, float(d["height"])), "ground": from, "height": float(d["height"]),
		"scale": 1.0,
	})


func _tick_flung(delta: float) -> void:
	var i := 0
	while i < _flung.size():
		var f: Dictionary = _flung[i]
		f["t"] = float(f["t"]) + delta
		var u := clampf(float(f["t"]) / float(f["dur"]), 0.0, 1.0)
		var ground: Vector2 = (f["from"] as Vector2).lerp(f["to"], u)
		var h := float(f["h0"]) * pow(1.0 - u, 1.4) + float(f["peak"]) * 4.0 * u * (1.0 - u)
		f["ground"] = ground
		f["height"] = h
		f["at"] = ground - Vector2(0.0, h)
		f["rot"] = float(f["rot"]) + float(f["spin"]) * delta * (1.0 - u * 0.5)
		if u >= 1.0:
			_land(f)
			_flung.remove_at(i)
			continue
		i += 1


func _land(f: Dictionary) -> void:
	var idx: int = f["tile"]
	var def: TrashDef = f["def"]
	if idx >= 0:
		grid.insert(idx, grid.height_of(idx), int(f["def_index"]))
		grid.bump(idx)
		for n: int in grid.tiles_within(idx, 1.0):
			if n != idx:
				grid.bump(n)
	var to: Vector2 = f["to"]
	var weight := clampf(def.size.length() / 60.0, 0.0, 1.0)
	splash.ripple(to, 12.0 + weight * 10.0)
	filth_moved.emit(1.0)
	_remap_dirty = true
	landed += 1


# ======================================================================================
# The water
# ======================================================================================

func _water(delta: float) -> void:
	var s := _strength
	if _phase == "gone":
		_ripple_in -= delta
		if _ripple_in <= 0.0 and _phase_t < 1.2:
			_ripple_in = 0.4
			splash.ripple(_base, 20.0 + _phase_t * 20.0)
		return
	if s < 0.03:
		return
	var tile := grid.tile_at(_base)
	if tile >= 0:
		var here := Iso.world_to_tile(_base)
		for index: int in grid.tiles_within(tile, SHOVE_REACH + 1.0):
			if grid.stacks[index].is_empty() or grid.dry[index] == 1:
				continue
			var rel := Vector2(grid.tile_of(index)) + Vector2(0.5, 0.5) - here
			var dist := rel.length()
			if dist > SHOVE_REACH or dist < 0.2:
				continue
			var w := rel.normalized()
			var world_rel := Iso.tile_to_world(w.x, w.y) - Iso.tile_to_world(0.0, 0.0)
			var tangent := Vector2(-world_rel.y * 2.0, world_rel.x * 0.5).normalized()
			var fall := 1.0 - dist / SHOVE_REACH
			var want := (tangent * 0.85 - world_rel.normalized() * 0.3) * SHOVE_PUSH * s * (0.4 + 0.6 * fall)
			grid.shove_to(index, want, delta)
		_bump_in -= delta
		if _bump_in <= 0.0:
			_bump_in = 0.18
			var near := grid.tiles_within(tile, BUMP_REACH)
			if not near.is_empty():
				grid.bump(near[_rng.randi_range(0, near.size() - 1)])
	_ripple_in -= delta
	if _ripple_in <= 0.0:
		_ripple_in = 0.1
		var k := fmod(_t * 10.0, 7.0)
		var a := _spin * 0.35 + k * 0.9
		var r := (8.0 + k * 7.0) * lerpf(0.6, 1.0, s)
		splash.ripple(_base + Vector2(cos(a) * r, sin(a) * r * 0.5), 5.0 + k)
	_core_ripple_in -= delta
	if _core_ripple_in <= 0.0:
		_core_ripple_in = 0.42
		splash.ripple(_base, 18.0 * s + 6.0)


# ======================================================================================
# Drawing: the look, and the shadows and flying pieces the harness drew
# ======================================================================================

func _make_look() -> void:
	_drop_look()
	_shadows = _Layer.new()
	_shadows.owner_node = self
	_shadows.kind = 0
	# The water's shadow layer (one sun): under the floating rubbish and every walker.
	_shadows.z_index = 4
	_shadows.z_as_relative = false
	add_child(_shadows)
	_flung_layer = _Layer.new()
	_flung_layer.owner_node = self
	_flung_layer.kind = 1
	_flung_layer.z_index = 19
	_flung_layer.z_as_relative = false
	add_child(_flung_layer)
	_look = Node2D.new()
	_look.set_script(Look)
	_look.name = &"TornadoLook"
	_look.z_index = 20
	_look.z_as_relative = false
	add_child(_look)
	_look.position = _base
	_look.call(&"setup", {
		"main": get_parent(), "grid": grid, "splash": splash, "palette": Palette.master(),
		"art_pixel": 2.0, "day": day, "weather": weather, "height": HEIGHT,
		"base_r": BASE_R, "top_r": TOP_R,
	})


func _drop_look() -> void:
	for n: Node in [_look, _shadows, _flung_layer]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_look = null
	_shadows = null
	_flung_layer = null


func _push_state(delta: float) -> void:
	if _look == null:
		return
	_state = {
		"phase": _phase, "t": _phase_t, "time": _t, "strength": _strength, "hits": _look_hits,
		"hit_flash": _hit_flash, "velocity": _velocity, "spin": _spin, "height": HEIGHT,
		"lean": _lean, "base": _base, "debris": _debris, "flung": _flung,
		"axis_at": axis_at, "radius_at": radius_at, "net": {},
		"since_hit": _t - _hit_at,
		"collapse": clampf((_t - _end_at) / COLLAPSE_LONG, 0.0, 1.0) if _end_at >= 0.0 else 0.0,
		"tint": day.tint if day != null else Color.WHITE,
		"ink": day.ink if day != null else 0.3,
		"rain": weather.rain() if weather != null else 1.0,
		"flash": day.flash if day != null else 0.0,
	}
	_look.position = _base
	_look.call(&"tick", delta, _state)
	_look.queue_redraw()
	_shadows.queue_redraw()
	_flung_layer.queue_redraw()


## The carried and flung pieces' shadows on the water. One sun (2026-10-02, `/grill-me` with
## Richard): each lies where the sun puts the ground under a piece that high up
## (`Shade.drop`), not straight below it, in the water's ink (`Shade.On.WATER`) thinning with
## the height, where it used to be a fixed blue-black of the tornado's own.
func _draw_shadows(on: Node2D) -> void:
	for d: Dictionary in _debris:
		var h: float = d["height"]
		var high := clampf(h / HEIGHT, 0.0, 1.0)
		var def: TrashDef = d["def"]
		var w := maxf(def.size.x * 0.4, 4.0) * lerpf(1.0, 0.6, high)
		DebrisDraw.draw_shadow(
			on, _base + (d["ground"] as Vector2) + Shade.drop(day, h), w,
			Shade.tint_on(day, Shade.On.WATER, lerpf(1.0, 0.375, high))
		)
	for f: Dictionary in _flung:
		var h: float = f["height"]
		var high := clampf(h / HEIGHT, 0.0, 1.0)
		var def: TrashDef = f["def"]
		var w := maxf(def.size.x * 0.45, 4.0) * lerpf(1.0, 0.55, high)
		DebrisDraw.draw_shadow(
			on, (f["ground"] as Vector2) + Shade.drop(day, h), w,
			Shade.tint_on(day, Shade.On.WATER, lerpf(1.0, 0.33, high))
		)


func _draw_flung(on: Node2D) -> void:
	for f: Dictionary in _flung:
		DebrisDraw.draw_piece(on, f["def"], f["at"], float(f["rot"]), float(f["scale"]))


class _Layer:
	extends Node2D
	var owner_node: Node
	var kind := 0

	func _draw() -> void:
		if owner_node == null:
			return
		if kind == 0:
			owner_node._draw_shadows(self)
		else:
			owner_node._draw_flung(self)


# ======================================================================================
# Sound: a hook for the wind
# ======================================================================================

func _start_wind() -> void:
	if not ResourceLoader.exists(WIND_SOUND):
		return
	if _wind == null:
		_wind = AudioStreamPlayer.new()
		_wind.bus = Prefs.BUS_AMBIENCE
		_wind.volume_db = WIND_DB
		add_child(_wind)
	_wind.stream = load(WIND_SOUND)
	_wind.play()


func _stop_wind() -> void:
	if _wind != null:
		_wind.stop()
