## The hive room's second step: the swarm on the hive's face smoked quiet from the top down
## and walked in at the entrance (2026-09-30, the beehive's second pass, Richard; off
## `tools/hive_mockup2.py` `room_smoke`. Top to bottom since 2026-10-04, Richard. Redrawn
## 2026-10-18, the hive's visual overhaul: option A of `tools/hive_look/last_smoke.png`, "the
## bees say it", with option C's ring of smoke wrapped round the bees, Richard's ask).
##
## The caught swarm hangs over the front of the hive as a beard of bee A: a packed under layer
## baked a band at a time (`beard_under_*`, the mockup's own, lit in three hard steps off the
## room's top-left), and over it the top bees (`BeeArt`, placed at the mockup's points, data
## `beard`), festoons hanging off its foot, bees walking the hive's body and guards on the
## landing board. Loose bees wander the air (`HiveStep.wanderers`). **The bees are the marks**:
## the band waiting to be smoked whirrs along its rim (wings up and blurred, a pixel of jitter),
## comic buzz arcs off its edge and a few bees popping off its side and back; a band smoked
## quiet folds its wings, shuts its eyes, goes a step paler and breathes Zs. **And a scarf of
## smoke wraps round the band being smoked** (option C's, `scarf_*`, its far half behind the
## beard), faint until smoke reaches it and filling as the band calms.
##
## **Three stops, in order**: the top of the beard, its middle, then the entrance slit.
## **The smoker is the pointer's**: no hands, the cursor holds it by the outer board of the
## bellows; it is one hive box tall (the mockup's) and throws a stepped shadow on the path.
## **Hold the button (A or RT) with the nozzle on the stop** and the bellows pump: one billow a
## squeeze leaves the spout, grows as it rolls along the band's edge and curls up into small
## puffs that thin away, in the mockup's stepped billows (`sbillow_*`). While the smoke reaches
## the stop its band calms (`CALM_TIME`): wings fold, the whirr dies and the quiet bees sag
## towards the entrance; once the stop is quiet a few stars pop, its bees **walk down the
## hive's face to the landing board** and crowd there, and the next stop is the scarf's.
## Smoking the entrance sends the whole crowd and the bottom of the beard in at the slit. **No
## penalty**: smoke anywhere else only drifts away.
##
## The last bees in, a sparkle over the roof, and `finished` follows `PAYOFF_HOLD` later.
##
## **Harness hooks, never gated on `awake`**: `smoke_ring(i, seconds)` (only the lit stop takes
## smoke: an out-of-order ask does nothing), `calm(i)`, `rings_done()`, `ring_count()`,
## `stop_now()`, `aim(p)` (the smoker held there for a picture) and `settle()`.
class_name HiveStepSmoke
extends HiveStep

const HIVE_FEET := Vector2(233.0, 304.0)
## The shadow on the lawn under what stands in this step: a contact ellipse in the one ink
## every shadow on land takes (`Shade.tint_on`, 2026-10-02, one sun), nudged along the sun
## (`Shade.drop`) as if from `CONTACT_RISE` painted px up.
const CONTACT_RISE := 4.0
## Loose bees in the air over the whole scene.
const AIR := 12
const AIR_BOX := Rect2(20.0, 30.0, 600.0, 230.0)
## The three stops, top to bottom: the top of the beard, its middle, the entrance slit. Their
## middles and half sizes. A beard bee belongs to the band its row falls in (`BAND_TO`, the
## rows each band runs down to); the bottom band goes with the entrance.
const RINGS: Array[Vector2] = [Vector2(236.0, 142.0), Vector2(236.0, 178.0), Vector2(233.0, 246.0)]
const RING_HALVES: Array[Vector2] = [Vector2(50.0, 17.0), Vector2(56.0, 16.0), Vector2(40.0, 13.0)]
const BAND_TO: Array[float] = [162.0, 197.0]
## The nozzle reaches the lit stop within this (height stretched), and smoke takes `CALM_TIME`
## of holding to quiet it.
const REACH := 80.0
const CALM_TIME := 1.8
## How far a band's quiet bees sag towards the entrance while it is being smoked, painted px.
const SAG := 4.0
## The crowd on the landing board: half its width and its rows over the slit.
const CROWD_HALF := 30.0
const CROWD_UP := Vector2(2.0, 12.0)
## The scarf round a stop fades out over this once quiet.
const DONE_FADE := 1.6
## The billows: one a squeeze, rolling `PUFF_SPEED` painted px a second along their path,
## growing `PUFF_R` (the mockup's r0 to r1); at the path's end the billow thins away over
## `PUFF_THIN` and throws `BREAK` small puffs off along `BREAK_AWAY`. A wisp leaves the spout
## every `SMOLDER` while the bellows rest. How many at once.
const PUFF_SPEED := 45.0
const PUFF_R := Vector2(2.2, 6.6)
const PUFF_THIN := 0.7
const BREAK := 3
const BREAK_AWAY := Vector2(0.55, -1.0)
const BREAK_TIME := 0.9
const SMOLDER := 0.7
const PUFFS_MOST := 40
## The quieted bees walk at this pace, painted pixels a second, a stagger each.
const WALK := 40.0
const STAGGER := 0.9
## The pump: a squeeze every this while held, and its puff's level over its balance.
const PUMP := 0.32
const PUFF_DB := -4.0
const PAYOFF_HOLD := 1.8
## The shared ending over the hive once the last stop is quiet (`HiveStep.payoff`).
const FINALE_AT := Vector2(233.0, 170.0)
const FINALE_WIDE := 110.0
## The last bees are waited on at most this long once the entrance is quiet.
const IN_WAIT := 4.0
const STAR_LIFE := 0.8
## The bees' light steps off the room's top-left sun (the mockup's ramp swaps, as tints): lit,
## mid, shade; a quiet bee a step paler.
const STEP_TINTS: Array[Color] = [Color(1.0, 1.0, 1.0), Color(0.87, 0.84, 0.8), Color(0.72, 0.69, 0.66)]
const CALM_TINT := Color(1.12, 1.1, 1.02)
## The marks' clock: the jitter, the buzz arcs and the scarf step this many times a second.
const MARK_FPS := 6.0
## Bees popping off the waiting band's side: how many, how far out and how often.
const LIFT := 3
const LIFT_REACH := 16.0
const LIFT_CYCLE := 1.8
## The smoker's shadow on the path: no higher up the screen than `GROUND_Y`, its half size, and
## how it shrinks the higher the smoker is held over it.
const GROUND_Y := 200.0
const SMOKER_SHADE := Vector2(13.0, 2.0)
const SMOKER_SHADE_FADE := 120.0
## The guards on the landing board round the entrance slit: (dx, dy, pose, facing left).
const GUARDS := [[-17.0, 8.0, &"worker_walk", false], [-6.0, 9.0, &"worker_rest", true],
	[8.0, 8.0, &"worker_walk", true], [19.0, 9.0, &"worker_rest", false]]

enum Walk { BEARD, DOWN, CROWD, IN, HOME }

var _roll := RandomNumberGenerator.new()
## Per top bee: its spot, where it is, its band, its rolls off the mockup (`_row`), when it goes
## quiet, its walk and stagger, and its place in the crowd.
var _base: PackedVector2Array = []
var _pos: PackedVector2Array = []
var _ring_of: PackedInt32Array = []
var _rows: Array = []
var _calm_at: PackedFloat32Array = []
var _walk_delay: PackedFloat32Array = []
var _walk: PackedByteArray = []
var _crowd: PackedVector2Array = []
var _was: PackedVector2Array = []
var _calm: Array[float] = [0.0, 0.0, 0.0]
var _done_age: Array[float] = [-1.0, -1.0, -1.0]
## The lit stop, 0..2, or 3 once every one is quiet.
var _now := 0
var _puffs: Array[Dictionary] = []
var _smolder := 0.0
var _pointer := Vector2(430.0, 230.0)
var _held_aim := false
var _hook_hold := 0.0
var _down := false
var _pump := 0.0
var _all_age := -1.0
var _stars: Array[Dictionary] = []
## The beard's layout off the builder (`HiveArt.data("beard")`).
var _beard: Dictionary = {}
var _edges: Dictionary = {}
## Per band: how many top bees it has, and how many have left it.
var _band_count: Array[int] = [0, 0, 0]


func begin() -> void:
	super.begin()
	_roll.seed = 4101
	_calm = [0.0, 0.0, 0.0]
	_done_age = [-1.0, -1.0, -1.0]
	_now = 0
	_puffs.clear()
	_stars.clear()
	_all_age = -1.0
	_down = false
	_held_aim = false
	_beard = HiveArt.data("beard", {}) as Dictionary
	_edges = _beard.get("rows", {}) as Dictionary
	_rows = _beard.get("top", []) as Array
	if _rows.is_empty():
		_rows = _fallback_rows()
	var count := _rows.size()
	_base.resize(count)
	_pos.resize(count)
	_was.resize(count)
	_ring_of.resize(count)
	_calm_at.resize(count)
	_walk_delay.resize(count)
	_walk.resize(count)
	_crowd.resize(count)
	_band_count = [0, 0, 0]
	var slit := _entrance()
	for i in count:
		var row: Array = _rows[i]
		var at := Vector2(float(row[0]), float(row[1]))
		_base[i] = at
		_pos[i] = at
		_was[i] = at
		_ring_of[i] = _band_of(at.y)
		_band_count[mini(_ring_of[i], 2)] += 1
		_calm_at[i] = _roll.randf_range(0.1, 0.9)
		_walk[i] = Walk.BEARD
		_walk_delay[i] = _roll.randf() * STAGGER
		_crowd[i] = slit + Vector2(
			_roll.randf_range(-CROWD_HALF, CROWD_HALF), -_roll.randf_range(CROWD_UP.x, CROWD_UP.y)
		)
	wanderers(AIR, AIR_BOX, 4101 + 7)
	if is_inside_tree():
		_pointer = art_mouse()


## A beard with no json behind it (a headless run before an import): a cloud of points.
func _fallback_rows() -> Array:
	var out: Array = []
	for i in 140:
		var t := _roll.randf()
		var half := 50.0 * sin(PI * minf(1.0, t * 1.1)) + 6.0
		out.append([236.0 + _roll.randf_range(-half, half), 135.0 + t * 100.0, 0, 0, 1,
			_roll.randf(), _roll.randi() % 2, 1, 0, 3, _roll.randi() % 6, 0])
	return out


static func _band_of(y: float) -> int:
	for b in BAND_TO.size():
		if y < BAND_TO[b]:
			return b
	return BAND_TO.size()


static func _entrance() -> Vector2:
	return HIVE_FEET - HiveArt.anchor(&"hive_front", &"feet") + HiveArt.anchor(&"hive_front", &"entrance")


# --- the harness's hooks ------------------------------------------------------------------

func ring_count() -> int:
	return RINGS.size()


## The lit stop, or `ring_count()` once all are quiet.
func stop_now() -> int:
	return _now


## How many bees have walked down to the landing board and wait there, or are on their way.
func gathered() -> int:
	var n := 0
	for i in _walk.size():
		if _walk[i] == Walk.CROWD:
			n += 1
	return n


## Smoke ring `i` for `seconds` at once. Only the lit stop takes it.
func smoke_ring(i: int, seconds: float) -> void:
	if i != _now:
		return
	_calm_ring(i, seconds / CALM_TIME)


func calm(i: int) -> float:
	return _calm[clampi(i, 0, 2)]


func rings_done() -> int:
	var n := 0
	for c in _calm:
		if c >= 1.0:
			n += 1
	return n


## Hold the smoker with its bellows at `p`, for a picture.
func aim(p: Vector2) -> void:
	_pointer = p
	_held_aim = true


## Pump the bellows for `seconds` as a held button would, for a picture.
func hold(seconds: float) -> void:
	_hook_hold = seconds


func settle() -> void:
	while _now < RINGS.size():
		_calm_ring(_now, 1.0)
	done_once()


# --- the play -----------------------------------------------------------------------------

func _smoker_tl() -> Vector2:
	return _pointer - HiveArt.anchor(&"smoker", &"bellows")


func _nozzle() -> Vector2:
	return _smoker_tl() + HiveArt.anchor(&"smoker", &"nozzle")


func _calm_ring(r: int, share: float) -> void:
	if r != _now or _calm[r] >= 1.0:
		return
	_calm[r] = minf(_calm[r] + share, 1.0)
	if _calm[r] < 1.0:
		return
	_done_age[r] = 0.0
	_now += 1
	var half := RING_HALVES[r]
	for k in 5:
		_stars.append({
			"at": RINGS[r] + Vector2(_roll.randf_range(-half.x, half.x), _roll.randf_range(-half.y - 4.0, half.y)),
			"age": -_roll.randf_range(0.0, 0.3), "arm": 1 + _roll.randi() % 2,
		})
	HiveStep.sound(&"hive_crown", -8.0, 1.2 + 0.1 * r)
	# The band's bees set off down the face, each after its own stagger; at the entrance, the
	# crowd and the bottom of the beard set off in.
	var last := r == RINGS.size() - 1
	for i in _walk.size():
		if _walk[i] == Walk.HOME or _walk[i] == Walk.IN:
			continue
		if last:
			_walk[i] = Walk.IN
		elif _ring_of[i] == r:
			_walk[i] = Walk.DOWN
	if last:
		_all_age = 0.0
		payoff(FINALE_AT, FINALE_WIDE)


## The lit stop, if the nozzle is on it, or -1.
func _target() -> int:
	if _now >= RINGS.size():
		return -1
	var gap := _nozzle() - RINGS[_now]
	return _now if Vector2(gap.x, gap.y * 1.3).length() < REACH else -1


func _process(delta: float) -> void:
	if is_inside_tree() and not _held_aim:
		pad_move(delta)
		_pointer = art_mouse()
	_hook_hold = maxf(_hook_hold - delta, 0.0)
	_down = ((is_inside_tree() and awake() and tool_down()) or _hook_hold > 0.0) and _all_age < 0.0
	var target := _target()
	if _down:
		# Each squeeze puffs: a breath of the bellows and one billow at the start of every `PUMP`.
		if _pump <= 0.0 or int((_pump + delta) / PUMP) != int(_pump / PUMP):
			_say_puff()
			_emit(target)
		_pump += delta
		if target >= 0 and _pump > 0.25:
			_calm_ring(target, delta / CALM_TIME)
	else:
		_pump = 0.0
		_smolder -= delta
		if _smolder <= 0.0:
			_smolder = SMOLDER
			_emit(-2)
	_drive_puffs(delta)
	_drive_bees(delta)
	for r in RINGS.size():
		if _done_age[r] >= 0.0:
			_done_age[r] += delta
	if _all_age >= 0.0:
		_all_age += delta
		if (_all_age >= PAYOFF_HOLD and _all_in()) or _all_age >= PAYOFF_HOLD + IN_WAIT:
			done_once()
	var kept: Array[Dictionary] = []
	for star: Dictionary in _stars:
		star["age"] = float(star["age"]) + delta
		if float(star["age"]) < STAR_LIFE:
			kept.append(star)
	_stars = kept


## Which picture the smoker is in this moment: open, half, shut, half, open over each `PUMP`.
func _bellows() -> StringName:
	if not _down:
		return &"smoker"
	var p := fmod(_pump, PUMP) / PUMP
	if p < 0.15 or (p >= 0.45 and p < 0.62):
		return &"smoker_half"
	if p < 0.45:
		return &"smoker_shut"
	return &"smoker"


## The bellows' puff (`hive_puff`, its three takes, through `Sfx.play_hive` so the takes turn).
static func _say_puff() -> void:
	var sfx: Node = Sfx.main()
	if sfx == null:
		return
	if sfx.has_method(&"play_hive"):
		sfx.call(&"play_hive", &"hive_puff", true, PUFF_DB)
	else:
		HiveStep.sound(&"hive_puff", PUFF_DB)


func _all_in() -> bool:
	for i in _walk.size():
		if _walk[i] != Walk.HOME:
			return false
	return true


## A band's left and right edge on row `y` of the beard, or none.
func _edge(y: float) -> Vector2:
	var row: Variant = _edges.get(str(int(y)))
	if row is Array and (row as Array).size() >= 2:
		return Vector2(float(row[0]), float(row[1]))
	return Vector2(RINGS[1].x - 50.0, RINGS[1].x + 50.0)


## A billow off the spout: to stop `target` (along the band's right edge to a curl), loose into
## the air (-1), or a smoulder's wisp (-2). Its path is laid once, as the mockup's `chain` lays
## its billows: a Catmull-Rom through the nozzle and the points round the band's edge.
func _emit(target: int) -> void:
	if _puffs.size() >= PUFFS_MOST:
		_puffs.pop_front()
	var n := _nozzle() - Vector2(3.0, 0.0)
	var pts: Array[Vector2] = [n]
	var r := PUFF_R
	if target >= 0:
		var ring := RINGS[target]
		var e := Vector2(_edge(ring.y + 2.0).y, ring.y + 6.0)
		if target == RINGS.size() - 1:
			e = Vector2(ring.x + RING_HALVES[target].x * 0.6, ring.y + 2.0)
		for off: Vector2 in [Vector2(17, 2), Vector2(7, 7), Vector2(0, 3), Vector2(0, -6), Vector2(6, -13)]:
			pts.append(e + off)
	elif target == -1:
		pts.append_array([n + Vector2(-20, -10), n + Vector2(-36, -28), n + Vector2(-40, -46)])
	else:
		r = Vector2(1.6, 2.9)
		pts.append_array([n + Vector2(-3, -10), n + Vector2(-1, -22)])
	var line := _catmull(pts)
	var run := PackedFloat32Array([0.0])
	for k in range(1, line.size()):
		run.append(run[k - 1] + line[k].distance_to(line[k - 1]))
	_puffs.append({"line": line, "run": run, "s": 0.0, "end": -1.0, "r": r,
		"seed": _roll.randi() % 997, "loose": target < 0})


static func _catmull(pts: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	var p: Array[Vector2] = [pts[0]]
	p.append_array(pts)
	p.append(pts[pts.size() - 1])
	for i in range(1, p.size() - 2):
		for k in 12:
			var t := k / 12.0
			out.append(0.5 * ((2.0 * p[i]) + (-p[i - 1] + p[i + 1]) * t
				+ (2.0 * p[i - 1] - 5.0 * p[i] + 4.0 * p[i + 1] - p[i + 2]) * t * t
				+ (-p[i - 1] + 3.0 * p[i] - 3.0 * p[i + 1] + p[i + 2]) * t * t * t))
	out.append(pts[pts.size() - 1])
	return out


static func _along(line: PackedVector2Array, run: PackedFloat32Array, s: float) -> Vector2:
	if line.size() < 2:
		return line[0] if line.size() > 0 else Vector2.ZERO
	s = clampf(s, 0.0, run[run.size() - 1])
	var k := 1
	while k < run.size() - 1 and run[k] < s:
		k += 1
	var t := (s - run[k - 1]) / maxf(run[k] - run[k - 1], 0.0001)
	return line[k - 1].lerp(line[k], t)


func _drive_puffs(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for p: Dictionary in _puffs:
		var run: PackedFloat32Array = p["run"]
		var total := run[run.size() - 1]
		if float(p["end"]) < 0.0:
			p["s"] = float(p["s"]) + PUFF_SPEED * delta
			if float(p["s"]) >= total:
				p["end"] = 0.0
		else:
			p["end"] = float(p["end"]) + delta
			if float(p["end"]) > maxf(PUFF_THIN, BREAK_TIME):
				continue
		kept.append(p)
	_puffs = kept


func _drive_bees(delta: float) -> void:
	var slit := _entrance()
	for i in _walk.size():
		_was[i] = _pos[i]
		var r := _ring_of[i]
		match _walk[i]:
			Walk.HOME:
				continue
			Walk.DOWN:
				if _done_age[mini(r, 2)] < _walk_delay[i]:
					continue
				# Down the face to its spot in the crowd on the landing board.
				if _step_to(i, _crowd[i], delta):
					_walk[i] = Walk.CROWD
				continue
			Walk.IN:
				if _all_age < _walk_delay[i]:
					continue
				if _step_to(i, slit + Vector2(sin(float(i)) * 8.0, 0.0), delta):
					_walk[i] = Walk.HOME
				continue
			Walk.CROWD:
				continue
		var c := _calm[r] if r < RINGS.size() else 0.0
		var quiet := c >= _calm_at[i]
		_pos[i] = _base[i] + (Vector2(0.0, SAG * c) if quiet else Vector2.ZERO)


## Walk bee `i` towards `to`; true once there.
func _step_to(i: int, to: Vector2, delta: float) -> bool:
	var gap := to - _pos[i]
	if gap.length() < 1.5:
		_pos[i] = to
		return true
	_pos[i] += gap.normalized() * minf(WALK * delta, gap.length())
	return false


func pad_mark() -> Rect2:
	return Rect2()


# --- drawing ------------------------------------------------------------------------------

## How much of a band is still on the hive's face, 0..1, in four steps.
func _band_left(band: int) -> float:
	var total := _band_count[band]
	if total <= 0:
		return 0.0 if (band == 2 and _all_age >= 0.0) else 1.0
	var gone := 0
	for i in _walk.size():
		if _ring_of[i] == band and _walk[i] != Walk.BEARD and _is_walking(i):
			gone += 1
	return ceilf((1.0 - float(gone) / total) * 4.0) / 4.0


## Whether bee `i` has set off (after its stagger) or arrived.
func _is_walking(i: int) -> bool:
	match _walk[i]:
		Walk.DOWN:
			return _done_age[mini(_ring_of[i], 2)] >= _walk_delay[i]
		Walk.IN:
			return _all_age >= _walk_delay[i]
		Walk.CROWD, Walk.HOME:
			return true
	return false


## Whether bee `i` is off its spot on the beard (in the crowd, waiting to go in).
func _left_home(i: int) -> bool:
	return _pos[i].distance_squared_to(_base[i]) > 2.0 * SAG * SAG


## The marks' stepped clock.
func _tick() -> int:
	return int(age * MARK_FPS)


func _draw() -> void:
	_ellipse(
		HIVE_FEET + Vector2(0.0, -1.0) + Shade.drop(null, CONTACT_RISE), Vector2(80.0, 9.0),
		Shade.tint_on(null, Shade.On.LAND)
	)
	_draw_smoker_shadow()
	draw_wanderers()
	HiveArt.draw(self, &"hive_front", to_canvas(HIVE_FEET), &"feet")
	_draw_scarf(&"b")
	var waiting := _now if _now < RINGS.size() else -1
	var lefts: Array[float] = []
	for band in 3:
		lefts.append(_band_left(band))
		var under := StringName("beard_under_%d" % band)
		var at: Array = (_beard.get("under", []) as Array)[band] if (_beard.get("under", []) as Array).size() > band else [0, 0]
		if lefts[band] > 0.0 and HiveArt.has(under):
			HiveArt.draw(self, under, to_canvas(Vector2(float(at[0]), float(at[1]))), &"", false, lefts[band])
	for band in [0, 2, 1]:
		if band == waiting:
			continue
		_draw_top(band, waiting)
	_draw_festoons(lefts[2])
	_draw_walkers()
	_draw_guards()
	if waiting >= 0:
		_draw_top(waiting, waiting)
		if lefts[waiting] > 0.0:
			_draw_whirr(waiting)
			_draw_buzz_arcs(waiting)
			_draw_lifted(waiting)
	# The bees walking down, in the crowd and going in, over the beard.
	for i in _walk.size():
		if _walk[i] != Walk.BEARD and _walk[i] != Walk.HOME and (_is_walking(i) or _left_home(i)):
			_draw_walker(i)
	_draw_zs(lefts)
	_draw_scarf(&"f")
	for p: Dictionary in _puffs:
		_draw_puff(p)
	# The smoker, held by its bellows at the pointer: on each squeeze the outer board swings in
	# and out (`smoker_half`, `smoker_shut`), and the can dips a pixel while it is shut.
	var pose := _bellows()
	var squeeze := 1.0 if pose == &"smoker_shut" else 0.0
	var tl := (_smoker_tl() + Vector2(0.0, squeeze)).floor()
	HiveArt.draw(self, pose if HiveArt.has(pose) else &"smoker", to_canvas(tl))
	for star: Dictionary in _stars:
		var t := float(star["age"])
		if t < 0.0:
			continue
		var bright := sin(clampf(t / STAR_LIFE, 0.0, 1.0) * PI)
		HiveArt.star(self, to_canvas(star["at"]), int(roundf(float(star["arm"]) * bright)), bright)
	draw_payoff()


## The top bees of `band` still on the hive's face, by its state: quiet (eyes shut, wings
## folded, a step paler), the waiting band (its rim whirring, the rest crawling awake), or one
## still to come (crawling and resting). The rolls are the mockup's own (`beard`).
func _draw_top(band: int, waiting: int) -> void:
	for i in _walk.size():
		if _ring_of[i] != band or _is_walking(i):
			continue
		if _walk[i] == Walk.CROWD or _left_home(i):
			continue
		var row: Array = _rows[i]
		var step := clampi(int(row[4]), 0, 2)
		var r := float(row[5])
		var left := int(row[6]) == 1
		var rim := int(row[3]) == 1
		var ph := float(row[10]) * 0.29
		var c := _calm[band] if band < RINGS.size() else 0.0
		var at := _pos[i]
		if c >= _calm_at[i]:
			var tint := CALM_TINT if step < 2 else STEP_TINTS[2]
			if r < 0.36:
				bee_at(self, &"worker_rest3", at + Vector2(0.0, 1.0), left, 0, tint)
			elif r < 0.62:
				bee_at(self, &"worker_rest3", at + Vector2(0.0, 1.0), left, int(row[7]), tint)
			else:
				bee_at(self, &"worker_restback0", at + Vector2(0.0, 1.0), left, int(row[8]), tint)
			continue
		var tint := STEP_TINTS[step]
		if band == waiting:
			if rim:
				continue          # the rim is the whirring bees (`_draw_whirr`)
			if r < 0.45:
				bee_at(self, _anim(&"worker_walk", ph), at, left, 0, tint)
			elif r < 0.75:
				bee_at(self, _anim(&"worker_walk", ph), at, left, int(row[7]), tint)
			else:
				bee_at(self, _anim(&"worker_walkback", ph), at, left, int(row[9]), tint)
			continue
		if r < 0.3:
			var pose := &"worker_rest" if int(row[11]) == 1 else &"worker_walk"
			bee_at(self, _anim(pose, ph), at, left, 0, tint)
		elif r < 0.6:
			bee_at(self, _anim(&"worker_walk", ph), at, left, int(row[7]), tint)
		else:
			bee_at(self, _anim(&"worker_walkback", ph), at, left, int(row[8]), tint)


func _anim(anim: StringName, phase: float, speed := 1.0) -> StringName:
	return BeeArt.frame_name(anim, BeeArt.frame_at(anim, age * speed + phase))


## The waiting band's rim, whirring: a bee every few rows down both sides of the silhouette,
## facing out, wings up and blurred, each with its own pixel of jitter on the marks' clock.
## The rim bees inside its silhouette whirr in place the same way.
func _draw_whirr(band: int) -> void:
	var c := _calm[band]
	var tick := _tick()
	var whirr: Array = (_beard.get("whirr", []) as Array)
	if band < whirr.size():
		for k in (whirr[band] as Array).size():
			var w: Array = whirr[band][k]
			var side := int(w[2])
			var jx := float(((tick + k * 3) * 7) % 3 - 1)
			var jy := float(((tick + k * 5) * 11) % 4 - 1) if (tick + k) % 2 == 0 else 0.0
			var at := Vector2(float(w[0]) + jx, float(w[1]) + clampf(jy, -1.0, 1.0))
			if c >= 0.5 + 0.4 * fmod(k * 0.37, 1.0):
				bee_at(self, &"worker_rest3", at + Vector2(0.0, 1.0), side < 0, 0, CALM_TINT)
				continue
			bee_at(self, _anim(&"worker_hover", k * 0.13, 1.8), at, side < 0)
	for i in _walk.size():
		if _ring_of[i] != band or _is_walking(i) or int((_rows[i] as Array)[3]) != 1:
			continue
		if c >= _calm_at[i]:
			continue
		var row: Array = _rows[i]
		var jx := float(((tick + i) * 7) % 3 - 1)
		bee_at(self, _anim(&"worker_hover", float(row[10]) * 0.11, 1.8), _pos[i] + Vector2(jx, 0.0),
			int(row[6]) == 1, 0, STEP_TINTS[clampi(int(row[4]), 0, 2)])


## Comic buzz arcs off the waiting band's left edge: three nested a side, opening a pixel and
## back on the marks' clock, in the outline ink with a pale inner lip. Gone as it calms.
func _draw_buzz_arcs(band: int) -> void:
	if _calm[band] > 0.6:
		return
	var rows: Array = (_beard.get("band_rows", [[135, 162], [162, 197], [197, 237]]) as Array)[band]
	var tick := _tick()
	var lip := Color(HiveArt.TRIM, 1.0)
	for k in 2:
		var y := float(rows[0]) + 13.0 if k == 0 else float(rows[1]) - 6.0
		var edge := _edge(y).x
		var push := float((tick + k) % 2)
		for j in 3:
			var h := [3, 5, 7][j] as int
			var curv := [1, 2, 3][j] as int
			var x0 := edge - (4.0 + j * 4.0 + push)
			for cell: Vector2i in _arc_cells(h, curv):
				var p := Vector2(x0 - cell.x, y + cell.y)
				draw_rect(Rect2(to_canvas(p), Vector2.ONE * HiveArt.PIXEL), HiveArt.OUT)
				draw_rect(Rect2(to_canvas(p + Vector2(1.0, 0.0)), Vector2.ONE * HiveArt.PIXEL), lip)


static func _arc_cells(h: int, curv: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var last := Vector2i(roundi(curv * (1.0 - 1.0)), -h)
	out.append(last)
	for dy in range(-h + 1, h + 1):
		var p := Vector2i(roundi(curv * (1.0 - pow(float(dy) / h, 2.0))), dy)
		while absi(p.x - last.x) > 1:
			last = Vector2i(last.x + (1 if p.x > last.x else -1), last.y)
			out.append(last)
		out.append(p)
		last = p
	return out


## A few bees popping off the waiting band's left side, flying out and back on a loop, with
## motion ticks behind them while they go fast.
func _draw_lifted(band: int) -> void:
	if _calm[band] > 0.7:
		return
	var rows: Array = (_beard.get("band_rows", [[135, 162], [162, 197], [197, 237]]) as Array)[band]
	var y0 := float(rows[0]) + 2.0
	var edge := _edge(y0).x
	for k in LIFT:
		var t := fposmod(age / LIFT_CYCLE + k / float(LIFT), 1.0)
		var out := sin(t * PI)
		var at := Vector2(edge - 4.0 - k * 9.0 * out - LIFT_REACH * out, y0 - 6.0 * out - k * 6.0 * out)
		var going_out := t < 0.5
		bee_at(self, _anim(&"worker_fly", k * 0.21), at, going_out)
		if going_out and out > 0.25:
			for d in 2:
				var tick := Vector2(at.x + 8.0 + float((_tick() + d) % 2), at.y - 2.0 + d * 4.0)
				draw_rect(Rect2(to_canvas(tick.floor()), Vector2(2.0, 1.0) * HiveArt.PIXEL), HiveArt.OUT)


## The festoons: chains of bees hanging leg to leg off the beard's foot, swaying a pixel.
func _draw_festoons(left: float) -> void:
	if left <= 0.0:
		return
	var tint := Color(1.0, 1.0, 1.0, left)
	for f: Array in (_beard.get("festoons", []) as Array):
		var x := float(f[0])
		var y := float(f[1])
		var n := int(f[2])
		var i := int(f[3])
		for k in n:
			var sway := roundf(sin(k * 1.4 + i + age * 1.2) * float(k > 0))
			var odd := (k + i) % 2 == 1
			var shade := STEP_TINTS[2] if f[0] > _beard.get("cx", 236.0) + 8.0 else STEP_TINTS[1]
			var ink := Color(shade.r, shade.g, shade.b, tint.a)
			var anim := &"worker_rest" if k == n - 1 else &"worker_walk"
			var name := _anim(anim, k * 0.3)
			if k < n - 1:
				name = _anim(&"worker_walkback", k * 0.3)
			bee_at(self, name, Vector2(x + sway, y + 3.0 + k * 5.0), not odd, 3 if odd else 1, ink)


## Bees crawling on the hive's body, above and below the beard.
func _draw_walkers() -> void:
	for w: Array in (_beard.get("walkers", []) as Array):
		bee_at(self, _anim(&"worker_walk", float(w[0]) * 0.01), Vector2(float(w[0]), float(w[1])),
			bool(w[2]), int(w[3]))


## The guards on the landing board, and one coming in to land.
func _draw_guards() -> void:
	var slit := _entrance()
	for g: Array in GUARDS:
		bee_at(self, _anim(g[2], float(g[0]) * 0.02), slit + Vector2(float(g[0]), float(g[1])), bool(g[3]))
	var bob := roundf(sin(age * 3.0))
	bee_at(self, _anim(&"worker_fly", 0.2), slit + Vector2(34.0, -5.0 + bob), true)


## A bee walking down the face, in the crowd, or going in: crawling head first the way it goes.
func _draw_walker(i: int) -> void:
	var move := _pos[i] - _was[i]
	var row: Array = _rows[i]
	var ph := float(row[10]) * 0.29
	if move.length_squared() < 0.0001:
		bee_at(self, _anim(&"worker_rest", ph), _pos[i], _pos[i].x > _entrance().x)
		return
	if absf(move.y) > absf(move.x) * 1.2:
		bee_at(self, _anim(&"worker_walk", ph, 1.4), _pos[i], false, 3 if move.y > 0.0 else 1)
	else:
		bee_at(self, _anim(&"worker_walk", ph, 1.4), _pos[i], move.x < 0.0)


## The Zs over a band smoked quiet, still on the hive: three, growing as they rise, bobbing.
func _draw_zs(lefts: Array[float]) -> void:
	var rows: Array = _beard.get("band_rows", [[135, 162], [162, 197], [197, 237]]) as Array
	for band in 3:
		if _calm[band] < 0.5 or lefts[band] < 0.5:
			continue
		var t0 := float((rows[band] as Array)[0])
		var ref := _edge(t0 + 5.0).x
		for z: Array in (_beard.get("zs", []) as Array):
			var n := int(z[0])
			var bob := float((_tick() / 3 + n) % 2)
			var piece := StringName("zed_%d" % n)
			if HiveArt.has(piece):
				HiveArt.draw(self, piece, to_canvas(Vector2(ref + float(z[1]), t0 + float(z[2]) + bob)))


## Option C's scarf round the stop being smoked: its far half (`b`) behind the beard, its near
## half (`f`) over it, drifting on the marks' clock; faint until smoke reaches the band, full as
## it calms, and fading out over `DONE_FADE` once it is quiet.
func _draw_scarf(half: StringName) -> void:
	var at_of: Dictionary = HiveArt.data("scarf_at", {}) as Dictionary
	var frame := int(age * MARK_FPS * 0.66) % 4
	for r in RINGS.size():
		var strength := 0.0
		if r == _now:
			strength = lerpf(0.35, 1.0, _calm[r])
		elif _done_age[r] >= 0.0:
			strength = 1.0 - clampf(_done_age[r] / DONE_FADE, 0.0, 1.0)
		if strength <= 0.0:
			continue
		var key := "%d_%s%d" % [r, half, frame]
		var piece := StringName("scarf_" + key)
		var at: Variant = at_of.get(key)
		if at is Array and HiveArt.has(piece):
			HiveArt.draw(self, piece, to_canvas(Vector2(float(at[0]), float(at[1]))), &"", false,
				ceilf(strength * 4.0) / 4.0)


## One billow: growing along its path, then thinning from the rim and breaking into small puffs.
func _draw_puff(p: Dictionary) -> void:
	var line: PackedVector2Array = p["line"]
	var run: PackedFloat32Array = p["run"]
	var total := maxf(run[run.size() - 1], 1.0)
	var s := float(p["s"])
	var radius: Vector2 = p["r"]
	var u := clampf(s / total, 0.0, 1.0)
	var r := radius.x + (radius.y - radius.x) * pow(u, 0.8)
	var at := _along(line, run, s)
	var end := float(p["end"])
	if end < 0.0:
		_billow(at, r, 0)
		return
	var thin := clampf(end / PUFF_THIN, 0.0, 1.0)
	if thin < 1.0:
		_billow(at, r, 1 if thin < 0.5 else 2)
	if bool(p["loose"]):
		return
	var away := BREAK_AWAY.normalized()
	var k_t := clampf(end / BREAK_TIME, 0.0, 1.0)
	for k in BREAK:
		var d := r * 0.6 + 2.0 + k * 3.6 + k_t * 8.0
		var side := (1.0 if k % 2 == 0 else -1.0) * 2.0
		var q := at + away * d + Vector2(-away.y, away.x) * side
		_billow(q, 2.9 - k * 0.55, mini(1 + int(k_t * 2.0 + k * 0.3), 2))


## The stepped billow nearest radius `r`, thinned `fade` steps (0 whole, 1 ragged, 2 thin).
func _billow(at: Vector2, r: float, fade: int) -> void:
	var radii: Array[float] = [1.6, 2.2, 2.9, 3.6, 4.4, 5.2, 6.0, 6.6]
	var best := 0
	for k in radii.size():
		if absf(radii[k] - r) < absf(radii[best] - r):
			best = k
	var piece := StringName("sbillow_%d_%d" % [best, clampi(fade, 0, 2)])
	if HiveArt.has(piece):
		HiveArt.draw(self, piece, to_canvas(at.floor()), &"c")
	else:
		_ellipse(at, Vector2(r, r * 0.9), Color(HiveArt.TRIM, 0.8))


## The smoker's stepped shadow on the path under it, smaller the higher it is held.
func _draw_smoker_shadow() -> void:
	var feet := _smoker_tl() + HiveArt.anchor(&"smoker", &"feet") + Vector2(6.0, 6.0)
	var lift := maxf(GROUND_Y - feet.y, 0.0)
	feet.y = maxf(feet.y, GROUND_Y)
	var size := clampf(1.0 - lift / SMOKER_SHADE_FADE, 0.4, 1.0)
	var ink := Shade.tint_on(null, Shade.On.LAND)
	ink.a *= 0.8
	_ellipse(feet, SMOKER_SHADE * size, ink)
	_ellipse(feet, Vector2(SMOKER_SHADE.x * 0.55, maxf(1.0, SMOKER_SHADE.y * 0.6)) * size, ink)


func _ellipse(middle: Vector2, half: Vector2, ink: Color) -> void:
	var top := floori(middle.y - half.y)
	for y in range(top, ceili(middle.y + half.y)):
		var dy := (y + 0.5 - middle.y) / half.y
		if absf(dy) >= 1.0:
			continue
		var w := half.x * sqrt(1.0 - dy * dy)
		var from := roundf(middle.x - w)
		draw_rect(Rect2(to_canvas(Vector2(from, y)), Vector2(roundf(middle.x + w) - from, 1.0) * HiveArt.PIXEL), ink)
