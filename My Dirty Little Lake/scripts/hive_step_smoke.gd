## The hive room's second step: the swarm on the hive's face smoked quiet from the top down
## and walked in at the entrance (2026-09-30, the beehive's second pass, Richard; off
## `tools/hive_mockup2.py` `room_smoke`. Top to bottom since 2026-10-04, Richard).
##
## The caught swarm hangs over the front of the hive in a beard of some `BEES` real bee
## sprites, every one fidgeting, wings flicking, and loose bees wander the air round it
## (`HiveStep.wanderers`). **Three stops, in order, one ring lit at a time**: the top of the
## beard, its middle, then the entrance slit. A faint arrow points down from the lit ring to
## where the next one will be. **The smoker is the pointer's**: no hands, the cursor holds it by
## the bellows. **Hold the button (A or RT) with the nozzle on the lit ring** and the bellows
## pump: billows leave the spout every `PUFF_EVERY`, roll along a curl to the ring, grow, drift
## up and thin away. While the smoke reaches the ring its band calms (`CALM_TIME`): wings fold,
## the fidget dies and the quiet bees sag towards the entrance; once the ring is quiet it turns
## green with stars, its bees **walk down the hive's face to the landing board** and crowd there,
## and the next ring lights. Smoking the entrance sends the whole crowd and the bottom of the
## beard in at the slit. **No penalty**: smoke anywhere else only drifts away.
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
## (`Shade.drop`) as if from `CONTACT_RISE` painted px up, so it falls down and to the left
## like every other shadow on the island. Kept an ellipse and kept flat, by decision: the
## step is seen from eye height over the lawn, where a footprint is a thin band, and a
## silhouette cast off the close-up would be the one shadow in the room not lying on it.
const CONTACT_RISE := 4.0
## The swarm over the hive's face: this many bees in the mockup's beard, from `MASS_TOP` down
## `MASS_TALL` rows, off a fixed seed.
const BEES := 400
const MASS_TOP := 124.0
const MASS_TALL := 100.0
const SEED := 4101
## Loose bees in the air over the whole scene.
const AIR := 36
const AIR_BOX := Rect2(20.0, 30.0, 600.0, 250.0)
## The three stops, top to bottom: the top of the beard, its middle, the entrance slit. Their
## middles and half sizes. A beard bee belongs to the band its row falls in (`BAND_TO`, the
## rows each band runs down to); the bottom band goes with the entrance.
const RINGS: Array[Vector2] = [Vector2(236.0, 142.0), Vector2(236.0, 178.0), Vector2(233.0, 246.0)]
const RING_HALVES: Array[Vector2] = [Vector2(50.0, 17.0), Vector2(56.0, 16.0), Vector2(40.0, 13.0)]
const BAND_TO: Array[float] = [158.0, 194.0]
## The nozzle reaches the lit ring within this (height stretched), and smoke takes `CALM_TIME`
## of holding to quiet it.
const REACH := 80.0
const CALM_TIME := 1.8
## How far a band's quiet bees sag towards the entrance while it is being smoked, painted px.
const SAG := 7.0
## The crowd on the landing board: half its width and its rows over the slit.
const CROWD_HALF := 36.0
const CROWD_UP := Vector2(3.0, 18.0)
## A green ring fades out over this once quiet.
const DONE_FADE := 1.6
## Puffs: one every this while held; the flight to the ring; the linger after; how many at once.
const PUFF_EVERY := 0.06
const FLY_TIME := 0.9
const LINGER := 1.0
const PUFFS_MOST := 60
## The smoke rolls this far off the straight line and curls up.
const CURL := 12.0
const ARC := 16.0
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
const BEAT := 22.0
## The arrow down to the next stop: its alpha and its pulse.
const ARROW_ALPHA := 0.55
const ARROW_RATE := 3.0

enum Walk { BEARD, DOWN, CROWD, IN, HOME }

var _roll := RandomNumberGenerator.new()
var _base: PackedVector2Array = []
var _pos: PackedVector2Array = []
var _ring_of: PackedInt32Array = []
var _phase: PackedFloat32Array = []
var _calm_at: PackedFloat32Array = []
var _walk_delay: PackedFloat32Array = []
var _walk: PackedByteArray = []
var _crowd: PackedVector2Array = []
var _calm: Array[float] = [0.0, 0.0, 0.0]
var _done_age: Array[float] = [-1.0, -1.0, -1.0]
## The lit stop, 0..2, or 3 once every one is quiet.
var _now := 0
## `{pos, from, to, t, big, seed, drift, alpha}`.
var _puffs: Array[Dictionary] = []
var _puff_clock := 0.0
var _smolder := 0.0
var _pointer := Vector2(430.0, 230.0)
var _held_aim := false
var _hook_hold := 0.0
var _down := false
var _pump := 0.0
var _all_age := -1.0
var _stars: Array[Dictionary] = []


func begin() -> void:
	super.begin()
	_roll.seed = SEED
	_calm = [0.0, 0.0, 0.0]
	_done_age = [-1.0, -1.0, -1.0]
	_now = 0
	_puffs.clear()
	_stars.clear()
	_all_age = -1.0
	_down = false
	_held_aim = false
	_base.resize(BEES)
	_pos.resize(BEES)
	_ring_of.resize(BEES)
	_phase.resize(BEES)
	_calm_at.resize(BEES)
	_walk_delay.resize(BEES)
	_walk.resize(BEES)
	_crowd.resize(BEES)
	var cx := HIVE_FEET.x + 3.0
	var rows: Array = []
	for i in BEES:
		var t := _roll.randf()
		var half := 58.0 * (0.55 + 0.45 * sin(PI * minf(1.0, t * 1.1))) * (1.0 - t * t * t) + 4.0
		rows.append(Vector2(cx + _roll.randf_range(-half, half), MASS_TOP + t * MASS_TALL))
	rows.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	var slit := _entrance()
	for i in BEES:
		var at: Vector2 = rows[i]
		_base[i] = at
		_pos[i] = at
		_phase[i] = _roll.randf() * TAU
		_calm_at[i] = _roll.randf_range(0.1, 0.9)
		_walk[i] = Walk.BEARD
		_ring_of[i] = _band_of(at.y)
		_walk_delay[i] = _roll.randf() * STAGGER
		_crowd[i] = slit + Vector2(
			_roll.randf_range(-CROWD_HALF, CROWD_HALF), -_roll.randf_range(CROWD_UP.x, CROWD_UP.y)
		)
	wanderers(AIR, AIR_BOX, SEED + 7)
	if is_inside_tree():
		_pointer = art_mouse()


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
	for i in BEES:
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
	for i in BEES:
		if _walk[i] == Walk.HOME or _walk[i] == Walk.IN:
			continue
		if last:
			_walk[i] = Walk.IN
		elif _ring_of[i] == r:
			_walk[i] = Walk.DOWN
	if last:
		_all_age = 0.0
		payoff(FINALE_AT, FINALE_WIDE)


## The lit ring, if the nozzle is on it, or -1.
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
		# Each squeeze puffs: a breath of the bellows at the start of every `PUMP`.
		if _pump <= 0.0 or int((_pump + delta) / PUMP) != int(_pump / PUMP):
			_say_puff()
		_pump += delta
		_puff_clock -= delta
		if _puff_clock <= 0.0:
			_puff_clock = PUFF_EVERY
			_emit(target)
		if target >= 0 and _pump > 0.25:
			_calm_ring(target, delta / CALM_TIME)
	else:
		_pump = 0.0
		_smolder -= delta
		if _smolder <= 0.0:
			_smolder = 0.7
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
	for i in BEES:
		if _walk[i] != Walk.HOME:
			return false
	return true


## A billow off the spout: to ring `target`, loose into the air (-1), or a smoulder's wisp (-2).
func _emit(target: int) -> void:
	if _puffs.size() >= PUFFS_MOST:
		_puffs.pop_front()
	var from := _nozzle()
	var to := from + Vector2(-70.0, -40.0) + Vector2(_roll.randf_range(-10.0, 10.0), _roll.randf_range(-8.0, 8.0))
	if target >= 0:
		var half := RING_HALVES[target]
		to = RINGS[target] + Vector2(_roll.randf_range(-half.x, half.x) * 0.6, _roll.randf_range(-half.y, half.y) * 0.5)
	var wisp := target == -2
	if wisp:
		to = from + Vector2(-6.0, -26.0)
	_puffs.append({
		"pos": from, "from": from, "to": to, "t": 0.0, "age": 0.0,
		"big": 0.4 if wisp else 1.0, "seed": _roll.randf() * TAU,
		"drift": Vector2(_roll.randf_range(-6.0, 4.0), -_roll.randf_range(8.0, 16.0)),
		"curl": _roll.randf_range(-1.0, 1.0),
	})


func _drive_puffs(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for p: Dictionary in _puffs:
		p["age"] = float(p["age"]) + delta
		var age_now := float(p["age"])
		if age_now > FLY_TIME + LINGER:
			continue
		var t := clampf(age_now / FLY_TIME, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - t, 2.0)
		var from: Vector2 = p["from"]
		var to: Vector2 = p["to"]
		var along := from.lerp(to, e)
		var side := (to - from).orthogonal().normalized()
		along += side * sin(e * PI * 2.2 + float(p["seed"])) * CURL * e * float(p["curl"])
		along.y -= sin(e * PI) * ARC
		var after := maxf(age_now - FLY_TIME, 0.0)
		along += (p["drift"] as Vector2) * after
		along.x += sin(after * 2.0 + float(p["seed"])) * 4.0 * after
		p["pos"] = along
		kept.append(p)
	_puffs = kept


func _drive_bees(delta: float) -> void:
	var slit := _entrance()
	for i in BEES:
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
				if _step_to(i, slit + Vector2(sin(_phase[i]) * 8.0, 0.0), delta):
					_walk[i] = Walk.HOME
				continue
			Walk.CROWD:
				_pos[i] = _crowd[i] + Vector2(sin(age * 1.4 + _phase[i]), cos(age * 1.1 + _phase[i])) * 0.5
				continue
		var c := _calm[r] if r < RINGS.size() else 0.0
		var quiet := c >= _calm_at[i]
		var fidget := 0.4 if quiet else 1.6
		var sag := Vector2(0.0, SAG * c) if quiet else Vector2.ZERO
		_pos[i] = _base[i] + sag + Vector2(sin(age * 2.7 + _phase[i]), cos(age * 2.1 + _phase[i] * 1.3)) * fidget


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

func _draw() -> void:
	_ellipse(
		HIVE_FEET + Vector2(0.0, -1.0) + Shade.drop(null, CONTACT_RISE), Vector2(80.0, 9.0),
		Shade.tint_on(null, Shade.On.LAND)
	)
	draw_wanderers()
	HiveArt.draw(self, &"hive_front", to_canvas(HIVE_FEET), &"feet")
	# No dark core under the beard and no settle under the ring being smoked (2026-10-04,
	# Richard: "a weird shadow behind the swarm"): the bees are the swarm.
	for i in BEES:
		if _walk[i] == Walk.HOME:
			continue
		var r := _ring_of[i]
		var c := _calm[r] if r < RINGS.size() else 1.0
		var quiet := c >= _calm_at[i] or _walk[i] != Walk.BEARD
		var moving := (_walk[i] == Walk.DOWN and _done_age[mini(r, 2)] >= _walk_delay[i]) \
			or (_walk[i] == Walk.IN and _all_age >= _walk_delay[i])
		var wings := not quiet and fmod(age * BEAT + _phase[i], 2.0) < 1.0
		var piece := &"bee_r" if wings else &"bee_r_rest"
		if moving:
			piece = &"bee_d"
		HiveArt.draw(self, piece, to_canvas(_pos[i].floor()), &"c", sin(_phase[i]) < 0.0)
	var target := _target()
	for r in RINGS.size():
		_draw_ring(r, r == target)
	_draw_arrow()
	# The smoker, held by its bellows at the pointer: on each squeeze the back board swings in
	# and out (`smoker_half`, `smoker_shut`), and the can dips a pixel while it is shut.
	var pose := _bellows()
	var squeeze := 1.0 if pose == &"smoker_shut" else 0.0
	var tl := (_smoker_tl() + Vector2(0.0, squeeze)).floor()
	HiveArt.draw(self, pose if HiveArt.has(pose) else &"smoker", to_canvas(tl))
	if squeeze > 0.0:
		for k in 3:
			var at := _pointer + Vector2(12.0 + k * 3.0, -8.0 + k * 6.0)
			draw_rect(Rect2(to_canvas(at.floor()), Vector2(6.0, 1.0) * HiveArt.PIXEL), Color(HiveArt.TRIM, 0.8))
	# The smoke over everything, oldest first.
	for p: Dictionary in _puffs:
		var age_now := float(p["age"])
		var grow := clampf(age_now / (FLY_TIME * 0.9), 0.0, 1.0) * float(p["big"])
		var which := clampi(1 + int(grow * 3.0 + 0.5), 0, 4)
		var fade := 1.0 - clampf((age_now - FLY_TIME) / LINGER, 0.0, 1.0)
		fade *= clampf(age_now / 0.08, 0.0, 1.0)
		HiveArt.draw(self, StringName("billow_%d" % which), to_canvas((p["pos"] as Vector2).floor()), &"c",
			false, fade * 0.8)
	for star: Dictionary in _stars:
		var t := float(star["age"])
		if t < 0.0:
			continue
		var bright := sin(clampf(t / STAR_LIFE, 0.0, 1.0) * PI)
		HiveArt.star(self, to_canvas(star["at"]), int(roundf(float(star["arm"]) * bright)), bright)
	draw_payoff()


## The lit ring: gold and doubled with a halo while smoked, its calm sweeping round it; a ring
## already quiet is green with a star, fading out over `DONE_FADE`; one still to come is not
## drawn at all.
func _draw_ring(r: int, now: bool) -> void:
	var done := _calm[r] >= 1.0
	if not done and r != _now:
		return
	var fade := 1.0
	if done:
		fade = 1.0 - clampf(_done_age[r] / DONE_FADE, 0.0, 1.0)
		if fade <= 0.0:
			return
	var middle := RINGS[r]
	var ring_half := RING_HALVES[r]
	if now:
		for g in range(6, 0, -1):
			_ellipse(middle, ring_half + Vector2(g * 2.0, g), Color(HiveArt.GOLD, 14.0 / 255.0))
	var steps := 140
	var out := Color(HiveArt.OUT, fade)
	for s in steps:
		var ang := TAU * s / steps
		var at := middle + Vector2(cos(ang) * ring_half.x, sin(ang) * ring_half.y)
		draw_rect(Rect2(to_canvas(at.floor() - Vector2.ONE), Vector2.ONE * 3.0 * HiveArt.PIXEL), out)
		if done:
			draw_rect(Rect2(to_canvas(at.floor()), Vector2.ONE * 2.0 * HiveArt.PIXEL), Color(Color8(112, 199, 107), fade))
		else:
			draw_rect(Rect2(to_canvas(at.floor()), Vector2.ONE * 2.0 * HiveArt.PIXEL),
				HiveArt.GOLD if s % 10 else HiveArt.HONEY_SHINE)
	if not done and _calm[r] > 0.0:
		var sweep := int(steps * _calm[r])
		for s in sweep:
			var ang := -PI * 0.5 + TAU * s / steps
			for w in 3:
				var at := middle + Vector2(cos(ang) * (ring_half.x - 4.0 - w), sin(ang) * (ring_half.y - 3.0 - w))
				HiveArt.px(self, to_canvas(at), HiveArt.HONEY_LIGHT)
	if done:
		var bright := (0.6 + 0.4 * sin(age * 4.0 + r)) * fade
		HiveArt.star(self, to_canvas(middle + Vector2(ring_half.x - 2.0, -ring_half.y + 2.0)), 3, bright)
		HiveArt.star(self, to_canvas(middle + Vector2(-ring_half.x + 4.0, -ring_half.y - 2.0)), 2, bright)


## A faint dashed arrow from under the lit ring down to where the next stop is, pulsing.
func _draw_arrow() -> void:
	if _now >= RINGS.size() - 1:
		return
	var from := RINGS[_now] + Vector2(0.0, RING_HALVES[_now].y + 4.0)
	var to := RINGS[_now + 1] - Vector2(0.0, RING_HALVES[_now + 1].y + 3.0)
	if to.y <= from.y + 8.0:
		to.y = from.y + 10.0
	var pulse := 0.6 + 0.4 * sin(age * ARROW_RATE)
	var ink := Color(HiveArt.HONEY_SHINE, ARROW_ALPHA * pulse)
	var x := roundf(from.x)
	var y := from.y
	while y < to.y - 5.0:
		draw_rect(Rect2(to_canvas(Vector2(x, floorf(y))), Vector2(2.0, 3.0) * HiveArt.PIXEL), ink)
		y += 6.0
	# The head: a chevron of single pixels, its point on `to`.
	for k in 5:
		var at := Vector2(x, floorf(to.y) - k)
		draw_rect(Rect2(to_canvas(at + Vector2(-k, 0.0)), Vector2.ONE * HiveArt.PIXEL), ink)
		draw_rect(Rect2(to_canvas(at + Vector2(k + 1.0, 0.0)), Vector2.ONE * HiveArt.PIXEL), ink)


func _ellipse(middle: Vector2, half: Vector2, ink: Color) -> void:
	var top := floori(middle.y - half.y)
	for y in range(top, ceili(middle.y + half.y)):
		var dy := (y + 0.5 - middle.y) / half.y
		if absf(dy) >= 1.0:
			continue
		var w := half.x * sqrt(1.0 - dy * dy)
		var from := roundf(middle.x - w)
		draw_rect(Rect2(to_canvas(Vector2(from, y)), Vector2(roundf(middle.x + w) - from, 1.0) * HiveArt.PIXEL), ink)
