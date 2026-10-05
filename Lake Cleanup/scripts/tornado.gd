extends Node2D
## The tornado (2026-09-30, `/grill-me` with Richard; CLAUDE.md "The Tornado"): a waterspout
## that comes down on the lake, wanders within the net's reach of the island, lifts the top
## piece off the tiles it passes into its orbit and flings some back out onto open water, and
## is tamed by landing the net on its foot.
##
## Second pass (2026-10-05, `/grill-me` with Richard): four a run, one as the meter passes
## each of `MARKS`; 3 / 4 / 4 / 5 hits to tame them (`HITS_NEEDED`); it comes down at
## `SIZE_START` and every hit takes it a step smaller; it hunts the fullest water in its band,
## darting and churning on a jittery path (`_hunt`); a hit knocks it back and sends it off a
## new way, and puts everything it carries into that net, past the net's room
## (`netted_into`). It turns counter-clockwise and the water runs into its foot.
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
## A hit put `pieces` of what it carried into `net` (the lake's storm tally). Sent on every
## hit, nought included.
signal netted_into(net: Node, pieces: int)

# --- The schedule ----------------------------------------------------------------------
## Four a run, one as the meter passes each of these cleaned shares (1 - pollution), each
## rolled up to `MARK_JITTER` either way (2026-10-05). Supersedes the 80% gate and the time
## gaps between tornadoes.
const MARKS: Array[float] = [0.2, 0.4, 0.6, 0.8]
const MARK_JITTER := 0.03
## A mark the meter is already this far past is skipped, not owed: a save from before the
## marks, or a stretch cleared in a rush, does not get tornadoes back to back.
const MARK_SKIP := 0.12
## Hits to tame each of the run's tornadoes, in order: the later ones meet a wider net.
const HITS_NEEDED: Array[int] = [3, 4, 4, 5]
## A due tornado waits this long once nothing holds it (a board just closed, a tour ended).
const CALM_FIRST := 2.0

# --- The event, seconds ----------------------------------------------------------------
## The storm comes in (rain, grey light) before the funnel touches down.
const BREW := 6.0
const TOUCH_END := 2.0
## Untamed, it wanders off this long after touching down, plus `LIFE_PER_HIT` for every hit
## it takes to tame (`life()`): 76 s for a three-hit one, 100 s for the last.
const LIFE := 40.0
const LIFE_PER_HIT := 12.0
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
## The funnel's size against the mock's (2026-10-05): it comes down at `SIZE_START`, and each
## hit takes it a step towards `SIZE_LAST`, reached with one hit to go. Height, radius, foot,
## the look and how much it carries all follow it.
const SIZE_START := 1.5
const SIZE_LAST := 0.5
const SIZE_EASE := 6.0
## The foot a net's mouth has to touch, half-extents in world px, at size 1.
const FOOT := Vector2(30.0, 15.0)

# --- Moving ----------------------------------------------------------------------------
const SPEED_TOUCH := 10.0
const SPEED_COLLAPSE := 12.0
## The hunt (2026-10-05): it samples `HUNT_SAMPLES` spots in its band within `HUNT_ARC` of
## where it is, scores each by the pieces within `HUNT_REACH` tiles (the grime is where the
## rubbish is), a spot `HUNT_NEAR` px off counting half, darts to the best at `SPEED_DART`
## and churns over it at `SPEED_CHURN` for `CHURN` seconds, then hunts again.
const HUNT_SAMPLES := 18
const HUNT_ARC := 1.6
const HUNT_REACH := 2.5
const HUNT_NEAR := 360.0
## A goal is somewhere else: at least this far off, px.
const HUNT_LEAST := 70.0
const SPEED_DART := 150.0
const SPEED_CHURN := 34.0
const CHURN := Vector2(2.5, 5.0)
## A dart eases up to speed over this long and slows inside `ARRIVE_SLOW` px of its goal.
const DART_RISE := 0.35
const ARRIVE_SLOW := 70.0
const ARRIVE := 16.0
## Chaos: the heading wanders up to `JITTER_TURN` radians off the line on short noise, and
## the foot shakes `JITTER_PX` world px round where it is going.
const JITTER_TURN := 0.75
const JITTER_PX := 6.0
## After a hit the new goal is off the way it was going: its direction's dot with the old
## heading under `FLEE_DOT`, and `FLEE_CLEAR` px from the old goal.
const FLEE_DOT := 0.3
const FLEE_CLEAR := 140.0
## Tiles past the island's shore it keeps between; the far end is the net's range less
## `RANGE_SPARE`, so the player can always reach it from the beach.
const GROW_LEAST := 2.2
const GROW_MOST := 16.0
const RANGE_SPARE := 1.2
const KNOCK := 40.0

# --- Debris (the mock's numbers) -------------------------------------------------------
const LIFT_REACH := 0.9
const LIFT_GAP := 0.14
const RELIFT_AFTER := 3.0
## How much it carries at size 1; `carry_most()` scales it with the size.
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
## `count` is how many of `MARKS` are behind (had or skipped); `next_in` the rolled cleaned
## share of the next, -1 unrolled; `most` is always `MARKS.size()`.
var count := 0
var most := MARKS.size()
var next_in := -1.0
var _calm := 0.0
## Hits this one takes to tame, set at `start`.
var _need := 3
var _size := SIZE_START
var _goal_theta := 0.0
var _goal_grow := 4.0
var _goal_set := false
var _goal_at := Vector2.ZERO
var _fleeing := false
var _churn := 0.0
var _dart_t := 0.0
var _heading := Vector2.ZERO
var _path := Vector2.ZERO

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


# ======================================================================================
# The schedule
# ======================================================================================

## Saved values back in. Absent keys read as none yet. A `next` outside 0..1 is from before
## the marks (it was seconds) and is rolled again.
func restore(done: int, next: float) -> void:
	count = clampi(done, 0, MARKS.size())
	next_in = next if next >= 0.0 and next <= 1.0 else -1.0


## Once a frame from the lake, while the world runs. `cleaned` is 1 - pollution; `held` is
## true while a tornado must not start (intro, tours, boards, the ending).
func tick_schedule(delta: float, cleaned: float, held: bool) -> void:
	if _active:
		return
	while count < MARKS.size() and cleaned > MARKS[count] + MARK_SKIP:
		count += 1
		next_in = -1.0
	if count >= MARKS.size():
		return
	if next_in < 0.0:
		next_in = clampf(MARKS[count] + _rng.randf_range(-MARK_JITTER, MARK_JITTER), 0.05, 0.95)
	if cleaned < next_in:
		_calm = 0.0
		return
	if held:
		_calm = 0.0
		return
	_calm += delta
	if _calm < CALM_FIRST:
		return
	_calm = 0.0
	start()


## Hits the next tornado (or this one, while out) takes to tame.
func hits_needed() -> int:
	return _need if _active else HITS_NEEDED[clampi(count, 0, HITS_NEEDED.size() - 1)]


## Seconds it roams before wandering off untamed.
func life() -> float:
	return LIFE + LIFE_PER_HIT * float(_need)


## How many pieces it may carry at its size now.
func carry_most() -> int:
	return maxi(int(round(float(CARRY_MOST) * _size)), 4)


func size() -> float:
	return _size


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
	_need = HITS_NEEDED[clampi(count, 0, HITS_NEEDED.size() - 1)]
	_size = SIZE_START
	_goal_set = false
	_goal_at = Vector2.ZERO
	_fleeing = false
	_churn = 0.0
	_dart_t = 0.0
	_heading = Vector2.ZERO
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
	_path = _base
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
	count = mini(count + 1, MARKS.size())
	next_in = -1.0
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
	if _end_at < 0.0 and t >= TOUCH_END + life():
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
	if _end_at < 0.0:
		_size = lerpf(_size, _size_target(), 1.0 - exp(-SIZE_EASE * delta))
	_hit_flash = maxf(_hit_flash - delta * 2.2, 0.0)
	_spin += delta * lerpf(3.0, 7.0, _strength)

	match _phase:
		"touchdown": _hunt(delta, SPEED_TOUCH)
		"hit": pass
		"collapse": _hunt(delta, SPEED_COLLAPSE)
		"gone": pass
		_: _hunt(delta, INF)
	_knock *= exp(-2.5 * delta)
	var calm := minf(_strength * 1.5, 1.0)
	var meander := Vector2(sin(t * 1.3) * 10.0, cos(t * 0.9) * 4.0) * calm
	var shake := Vector2(
		sin(t * 7.3 + _seed) * 0.6 + sin(t * 12.1 + _seed * 2.0) * 0.4,
		cos(t * 6.1 + _seed * 3.0) * 0.6 + sin(t * 10.7) * 0.4
	) * Vector2(JITTER_PX, JITTER_PX * 0.5) * calm
	_base_was = _base
	var on_path := Iso.island_point(_theta, _grow)
	if on_path.distance_to(_path) > 0.5:
		_heading = (on_path - _path).normalized()
	_path = on_path
	_base = on_path + meander + shake + _knock
	_velocity = (_base - _base_was) / maxf(delta, 0.0001)
	var want_lean := -_velocity.limit_length(220.0) * 0.75 + Vector2(sin(t * 0.8) * 18.0, 0.0)
	_lean = _lean.lerp(want_lean, 1.0 - exp(-2.6 * delta))

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


func _size_target() -> float:
	if _need <= 1:
		return SIZE_START
	return lerpf(SIZE_START, SIZE_LAST, clampf(float(_hits) / float(_need - 1), 0.0, 1.0))


## The hunt (2026-10-05): dart to the fullest water in the band, churn over it, hunt again.
## Moves in the band's own terms (`_theta` round the island, `_grow` tiles out), so a goal on
## the far side is reached round the ring and never across the island; each step is laid in
## world px, bent off the line by the jitter, and solved back into those terms. `cap` holds
## the pace down (touchdown, the collapse).
func _hunt(delta: float, cap: float) -> void:
	var lo := GROW_LEAST
	var hi := _grow_most()
	if not _goal_set:
		_pick_goal(_fleeing)
		_fleeing = false
	_goal_grow = clampf(_goal_grow, lo, hi)
	var here := Iso.island_point(_theta, _grow)
	var tang := (Iso.island_point(_theta + 0.01, _grow) - here) / 0.01
	var norm := (Iso.island_point(_theta, _grow + 0.1) - here) / 0.1
	var dth := wrapf(_goal_theta - _theta, -PI, PI)
	var dgr := _goal_grow - _grow
	var speed := SPEED_DART
	if _churn > 0.0:
		# Churning: a small loop round the goal, slow.
		_churn -= delta
		dth += sin(_t * 1.7 + _seed) * 0.06
		dgr += cos(_t * 1.3 + _seed) * 0.7
		speed = SPEED_CHURN
		if _churn <= 0.0:
			_goal_set = false
	var line := tang * dth + norm * dgr
	var left := line.length()
	if _churn <= 0.0 and _goal_set:
		_dart_t += delta
		speed *= smoothstep(0.0, DART_RISE, _dart_t) * 0.85 + 0.15
		speed *= clampf(left / ARRIVE_SLOW, 0.3, 1.0)
		if left < ARRIVE:
			_churn = _rng.randf_range(CHURN.x, CHURN.y)
	speed = minf(speed, cap)
	if left < 0.001 or speed <= 0.0:
		return
	var turn := JITTER_TURN * (
		sin(_t * 2.9 + _seed) * 0.6 + sin(_t * 6.3 + _seed * 2.0) * 0.4
	)
	var w := line.normalized().rotated(turn) * minf(speed * delta, left)
	var det := tang.x * norm.y - tang.y * norm.x
	if absf(det) < 0.0001:
		return
	_theta += (w.x * norm.y - w.y * norm.x) / det
	_grow = clampf(_grow + (tang.x * w.y - tang.y * w.x) / det, lo, hi)


## The fullest water within `HUNT_ARC` of here in the band. Fleeing (just hit), it may not go
## on the way it was going, nor back to where it was headed.
func _pick_goal(fleeing: bool) -> void:
	var lo := GROW_LEAST
	var hi := _grow_most()
	var here := _path
	var best := -1.0
	var pick := Vector2(_theta, _grow)
	for k in HUNT_SAMPLES:
		var th := _theta + _rng.randf_range(-HUNT_ARC, HUNT_ARC)
		var gr := _rng.randf_range(lo, hi)
		var at := Iso.island_point(th, gr)
		var dist := at.distance_to(here)
		if dist < HUNT_LEAST:
			continue
		if fleeing:
			if _heading != Vector2.ZERO and (at - here).normalized().dot(_heading) > FLEE_DOT:
				continue
			if _goal_at != Vector2.ZERO and at.distance_to(_goal_at) < FLEE_CLEAR:
				continue
		var score := (1.0 + _richness(at)) * _rng.randf_range(0.8, 1.2) / (1.0 + dist / HUNT_NEAR)
		if score > best:
			best = score
			pick = Vector2(th, gr)
	if best < 0.0:
		pick = Vector2(_theta + _rng.randf_range(-HUNT_ARC, HUNT_ARC), _rng.randf_range(lo, hi))
	_goal_theta = pick.x
	_goal_grow = pick.y
	_goal_at = Iso.island_point(pick.x, pick.y)
	_goal_set = true
	_churn = 0.0
	_dart_t = 0.0


## Pieces in the water round `at`: the rubbish, and the grime that is wherever it is.
func _richness(at: Vector2) -> float:
	if grid == null:
		return 0.0
	var idx := grid.tile_at(at)
	if idx < 0:
		return 0.0
	var n := 0
	for i: int in grid.tiles_within(idx, HUNT_REACH):
		if grid.dry[i] == 0:
			n += grid.stacks[i].size()
	return float(n)


func _strength_at(t: float) -> float:
	if t < TOUCH_END:
		return smoothstep(0.0, TOUCH_END, t)
	if _end_at >= 0.0:
		var u := clampf((t - _end_at - 0.1) / (COLLAPSE_LONG - 0.3), 0.0, 1.0)
		return _end_from * (1.0 - u) * (1.0 - u) * (1.0 + 0.15 * sin(u * 20.0) * (1.0 - u))
	if _hits == 0:
		return 1.0
	# The size carries the shrink; strength only takes the hit's jolt.
	var since := t - _hit_at
	return 1.0 - 0.14 * exp(-since * 5.0) * cos(since * 14.0)


func axis_at(frac: float) -> Vector2:
	var h := HEIGHT * _size * _strength * frac
	var snake := Vector2(
		(sin(_t * 1.7 + frac * 3.0) * 12.0 + sin(_t * 3.4 + frac * 6.0 + _seed) * 6.0) * frac, 0.0
	)
	var jolt := Vector2(sin(_t * 40.0) * 10.0 * _hit_flash * frac, 0.0)
	return Vector2(_lean.x * frac * frac, _lean.y * 0.2 * frac) + snake + jolt - Vector2(0.0, h)


func radius_at(frac: float) -> float:
	var r := lerpf(BASE_R, TOP_R, pow(clampf(frac, 0.0, 1.0), 1.4))
	return r * _size * lerpf(0.45, 1.0, _strength) * (1.0 + 0.25 * _hit_flash)


# ======================================================================================
# Hits
# ======================================================================================

## Does a net's mouth, down at `at`, touch the foot?
func touches(at: Vector2, mouth: float) -> bool:
	if not down() or _end_at >= 0.0 or _phase == "touchdown":
		return false
	var s := clampf(_strength, 0.5, 1.0) * _size
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
	var ring := 22.0 * _size
	for k in 8:
		var a := TAU * float(k) / 8.0
		splash.ripple(_base + Vector2(cos(a) * ring, sin(a) * ring * 0.5), 10.0)
	splash.ripple(_base, 30.0 * _size)
	netted_into.emit(net, _into_net(net))
	if _hits < _need:
		_look_hits = 1
		# Reel, then flee: the knock carries it back, and once the hit's beat is over it darts
		# off a new way (`_pick_goal` with `fleeing`).
		_goal_set = false
		_fleeing = true
		_churn = 0.0
		_fling_in = maxf(_fling_in, 0.6)
	else:
		_tamed = true
		_catch_net = net
		_begin_end(true)
	return true


## Every hit (2026-10-05): all it carries falls into that net, past the net's room, its
## Strength and its Catch. Returns how many.
func _into_net(net: Node) -> int:
	if net == null or not (&"catch" in net):
		return 0
	var held: PackedInt32Array = net.get(&"catch")
	for d: Dictionary in _debris:
		held.append(int(d["def_index"]))
		netted += 1
	var n := _debris.size()
	_debris.clear()
	net.set(&"catch", held)
	return n


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
	if _lift_in > 0.0 or _debris.size() >= carry_most():
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
		# Counter-clockwise seen from above (2026-10-05): the angle runs down.
		d["angle"] = float(d["angle"]) - w * delta
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
	if _debris.size() >= carry_most() - 1:
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
	var tan := Vector2(sin(a), -cos(a))
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
			# Counter-clockwise round the foot and drawn in towards it.
			var tangent := Vector2(world_rel.y * 2.0, -world_rel.x * 0.5).normalized()
			var fall := 1.0 - dist / SHOVE_REACH
			var want := (tangent * 0.8 - world_rel.normalized() * 0.45) * SHOVE_PUSH * s * (0.4 + 0.6 * fall)
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
		var a := -_spin * 0.35 - k * 0.9
		var r := (8.0 + k * 7.0) * lerpf(0.6, 1.0, s) * _size
		splash.ripple(_base + Vector2(cos(a) * r, sin(a) * r * 0.5), 5.0 + k)
	_core_ripple_in -= delta
	if _core_ripple_in <= 0.0:
		_core_ripple_in = 0.42
		splash.ripple(_base, (18.0 * s + 6.0) * _size)


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
		"hit_flash": _hit_flash, "velocity": _velocity, "spin": _spin, "height": HEIGHT * _size,
		"size": _size, "hit_no": _hits,
		"weak": lerpf(1.0, 0.65, clampf(float(_hits - 1) / float(maxi(_need - 1, 1)), 0.0, 1.0)),
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
