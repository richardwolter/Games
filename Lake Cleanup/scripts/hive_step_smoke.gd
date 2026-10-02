## The hive room's second step: the swarm on the hive's face smoked quiet, ring by ring
## (2026-09-30, the beehive's second pass, Richard; off `tools/hive_mockup2.py` `room_smoke`).
##
## The caught swarm hangs over the front of the hive in a beard of some `BEES` real bee
## sprites, every one fidgeting, wings flicking. **Three rings** sit on it, to be smoked in any
## order. **The smoker is the pointer's**: no hands, the cursor holds it by the bellows and it
## goes wherever the pointer goes. **Hold the button (A or RT) with the nozzle on a ring** and
## the bellows pump: billows of smoke leave the spout every `PUFF_EVERY`, roll along a curl to
## the ring, grow, drift up and thin away — four greys, lit from the top left, rims broken
## into whole pixels (the builder's `billow_*` pieces). While the smoke reaches a ring its
## bees calm (`CALM_TIME`): one by one their wings fold, their fidget dies, and once the ring
## is quiet they walk down the hive's face in a file and in at the entrance. The ring turns
## green with stars. **No penalty**: smoke off a ring only drifts away.
##
## All three quiet, the last bees file in, a sparkle over the roof, and `finished` follows
## `PAYOFF_HOLD` later.
##
## **Harness hooks, never gated on `awake`**: `smoke_ring(i, seconds)`, `calm(i)`,
## `rings_done()`, `ring_count()`, `ring_pos(i)`, `aim(p)` (the smoker held there for a
## picture) and `settle()`.
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
## Air bees about the swarm.
const AIR := 60
## The three rings: middles (the mockup's), and half sizes.
const RINGS: Array[Vector2] = [Vector2(202.0, 166.0), Vector2(262.0, 154.0), Vector2(242.0, 214.0)]
const RING_HALF := Vector2(24.0, 17.0)
## A bee belongs to a ring when inside it grown by this.
const RING_TAKE := 1.2
## The nozzle reaches a ring within this (height stretched), and smoke takes `CALM_TIME` of
## holding to quiet it.
const REACH := 110.0
const CALM_TIME := 1.8
## Puffs: one every this while held; the flight to the ring; the linger after; how many at once.
const PUFF_EVERY := 0.06
const FLY_TIME := 0.9
const LINGER := 1.0
const PUFFS_MOST := 60
## The smoke rolls this far off the straight line and curls up.
const CURL := 12.0
const ARC := 16.0
## The quieted bees walk in at this pace, painted pixels a second, a stagger each.
const WALK := 24.0
const STAGGER := 0.9
## The pump: a squeeze every this while held.
const PUMP := 0.32
const PAYOFF_HOLD := 1.2
const STAR_LIFE := 0.8
const BEAT := 22.0

var _roll := RandomNumberGenerator.new()
var _base: PackedVector2Array = []
var _pos: PackedVector2Array = []
var _ring_of: PackedInt32Array = []
var _phase: PackedFloat32Array = []
var _calm_at: PackedFloat32Array = []
var _walk_delay: PackedFloat32Array = []
var _home: PackedByteArray = []
var _air: PackedVector2Array = []
var _air_phase: PackedFloat32Array = []
var _calm: Array[float] = [0.0, 0.0, 0.0]
var _done_age: Array[float] = [-1.0, -1.0, -1.0]
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
	_home.resize(BEES)
	var cx := HIVE_FEET.x + 3.0
	var rows: Array = []
	for i in BEES:
		var t := _roll.randf()
		var half := 58.0 * (0.55 + 0.45 * sin(PI * minf(1.0, t * 1.1))) * (1.0 - t * t * t) + 4.0
		rows.append(Vector2(cx + _roll.randf_range(-half, half), MASS_TOP + t * MASS_TALL))
	rows.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	for i in BEES:
		var at: Vector2 = rows[i]
		_base[i] = at
		_pos[i] = at
		_phase[i] = _roll.randf() * TAU
		_calm_at[i] = _roll.randf_range(0.1, 0.9)
		_home[i] = 0
		_ring_of[i] = -1
		for r in RINGS.size():
			var gap := (at - RINGS[r]) / (RING_HALF * RING_TAKE)
			if gap.length() <= 1.0:
				_ring_of[i] = r
				break
		_walk_delay[i] = _roll.randf() * STAGGER
	_air.resize(AIR)
	_air_phase.resize(AIR)
	for k in AIR:
		_air[k] = Vector2(cx + _roll.randfn(0.0, 0.5) * 110.0, 180.0 + _roll.randfn(0.0, 0.5) * 70.0)
		_air_phase[k] = _roll.randf() * TAU
	if is_inside_tree():
		_pointer = art_mouse()


# --- the harness's hooks ------------------------------------------------------------------

func ring_count() -> int:
	return RINGS.size()


func ring_pos(i: int) -> Vector2:
	return RINGS[clampi(i, 0, RINGS.size() - 1)]


## Smoke ring `i` for `seconds` at once.
func smoke_ring(i: int, seconds: float) -> void:
	if i < 0 or i >= RINGS.size():
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
	for r in RINGS.size():
		_calm_ring(r, 1.0)
	done_once()


# --- the play -----------------------------------------------------------------------------

func _smoker_tl() -> Vector2:
	return _pointer - HiveArt.anchor(&"smoker", &"bellows")


func _nozzle() -> Vector2:
	return _smoker_tl() + HiveArt.anchor(&"smoker", &"nozzle")


func _calm_ring(r: int, share: float) -> void:
	if _calm[r] >= 1.0:
		return
	_calm[r] = minf(_calm[r] + share, 1.0)
	if _calm[r] >= 1.0:
		_done_age[r] = 0.0
		for k in 5:
			_stars.append({
				"at": RINGS[r] + Vector2(_roll.randf_range(-26.0, 26.0), _roll.randf_range(-20.0, 16.0)),
				"age": -_roll.randf_range(0.0, 0.3), "arm": 1 + _roll.randi() % 2,
			})
		HiveStep.sound(&"hive_crown", -8.0, 1.2)
		if rings_done() == RINGS.size():
			_all_age = 0.0


## The ring the nozzle is on, or -1: the nearest still to be quieted within `REACH`.
func _target() -> int:
	var best := -1
	var near := REACH
	var nozzle := _nozzle()
	for r in RINGS.size():
		if _calm[r] >= 1.0:
			continue
		var gap := nozzle - RINGS[r]
		var d := Vector2(gap.x, gap.y * 1.3).length()
		if d < near:
			near = d
			best = r
	return best


func _process(delta: float) -> void:
	if is_inside_tree() and not _held_aim:
		pad_move(delta)
		_pointer = art_mouse()
	_hook_hold = maxf(_hook_hold - delta, 0.0)
	_down = ((is_inside_tree() and awake() and tool_down()) or _hook_hold > 0.0) and _all_age < 0.0
	var target := _target()
	if _down:
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
		if _all_age >= PAYOFF_HOLD + STAGGER + 1.2:
			done_once()
	var kept: Array[Dictionary] = []
	for star: Dictionary in _stars:
		star["age"] = float(star["age"]) + delta
		if float(star["age"]) < STAR_LIFE:
			kept.append(star)
	_stars = kept


## A billow off the spout: to ring `target`, loose into the air (-1), or a smoulder's wisp (-2).
func _emit(target: int) -> void:
	if _puffs.size() >= PUFFS_MOST:
		_puffs.pop_front()
	var from := _nozzle()
	var to := from + Vector2(-70.0, -40.0) + Vector2(_roll.randf_range(-10.0, 10.0), _roll.randf_range(-8.0, 8.0))
	if target >= 0:
		to = RINGS[target] + Vector2(_roll.randf_range(-12.0, 12.0), _roll.randf_range(-8.0, 8.0))
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
	var entrance := HIVE_FEET - HiveArt.anchor(&"hive_front", &"feet") + HiveArt.anchor(&"hive_front", &"entrance")
	for i in BEES:
		var r := _ring_of[i]
		var c := _calm[r] if r >= 0 else 0.0
		if r >= 0 and _done_age[r] >= 0.0:
			if _home[i] == 1:
				continue
			if _done_age[r] < _walk_delay[i]:
				continue
			# The file: down the hive's face to the landing board and in.
			var to := entrance + Vector2(sin(_phase[i]) * 10.0, 0.0)
			var gap := to - _pos[i]
			if gap.length() < 2.0:
				_home[i] = 1
				continue
			_pos[i] += gap.normalized() * minf(WALK * delta, gap.length())
			continue
		var quiet := c >= _calm_at[i]
		var fidget := 0.4 if quiet else 1.6
		_pos[i] = _base[i] + Vector2(sin(age * 2.7 + _phase[i]), cos(age * 2.1 + _phase[i] * 1.3)) * fidget
	for k in AIR:
		_air[k] += Vector2(cos(age * 1.1 + _air_phase[k]), sin(age * 1.7 + _air_phase[k] * 2.0)) * 22.0 * delta


func pad_mark() -> Rect2:
	return Rect2()


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	_ellipse(
		HIVE_FEET + Vector2(0.0, -1.0) + Shade.drop(null, CONTACT_RISE), Vector2(80.0, 9.0),
		Shade.tint_on(null, Shade.On.LAND)
	)
	HiveArt.draw(self, &"hive_front", to_canvas(HIVE_FEET), &"feet")
	# The beard's dark core under its bees (`bee_mass`'s own), thinning as rings go quiet and
	# their bees walk in.
	var core := 1.0 - float(rings_done()) / float(RINGS.size()) * 0.8
	var cx := HIVE_FEET.x + 3.0
	for row in int(MASS_TALL):
		var t := float(row) / MASS_TALL
		var half := 58.0 * (0.55 + 0.45 * sin(PI * minf(1.0, t * 1.1))) * (1.0 - t * t * t) + 4.0 - 4.0
		if half <= 1.0:
			continue
		var y := MASS_TOP + row + 3.0
		var ink := HiveArt.HONEY_DEEP.lerp(HiveArt.BEE_STRIPE, 0.55 + 0.25 * float(row % 2))
		ink.a = 0.85 * core
		draw_rect(Rect2(to_canvas(Vector2(roundf(cx - half), y)), Vector2(roundf(half * 2.0), 1.0) * HiveArt.PIXEL), ink)
	# Under each quiet ring a darker settle where the bees have gone still.
	for r in RINGS.size():
		if _calm[r] > 0.0:
			var ink := Color(60 / 255.0, 40 / 255.0, 26 / 255.0, 90 / 255.0 * _calm[r])
			_ellipse(RINGS[r], RING_HALF * 1.08, ink)
	for i in BEES:
		if _home[i] == 1:
			continue
		var r := _ring_of[i]
		var c := _calm[r] if r >= 0 else 0.0
		var quiet := c >= _calm_at[i]
		var walking := r >= 0 and _done_age[r] >= _walk_delay[i]
		var wings := not quiet and fmod(age * BEAT + _phase[i], 2.0) < 1.0
		var piece := &"bee_r" if wings else &"bee_r_rest"
		if walking:
			piece = &"bee_d"
		HiveArt.draw(self, piece, to_canvas(_pos[i].floor()), &"c", sin(_phase[i]) < 0.0)
	for k in AIR:
		HiveArt.draw(self, &"bee_r" if fmod(age * BEAT + _air_phase[k], 2.0) < 1.0 else &"bee_r_rest",
			to_canvas(_air[k].floor()), &"c", cos(age * 1.1 + _air_phase[k]) < 0.0)
	var target := _target()
	for r in RINGS.size():
		_draw_ring(r, r == target)
	# The smoker, held by its bellows at the pointer, bobbing on each squeeze.
	var squeeze := 0.0
	if _down:
		squeeze = 1.0 if fmod(_pump, PUMP) < PUMP * 0.4 else 0.0
	var tl := (_smoker_tl() + Vector2(0.0, squeeze)).floor()
	HiveArt.draw(self, &"smoker", to_canvas(tl))
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


## A ring: faint dashes to come, gold and doubled with a halo and its calm sweeping round it
## while smoked, green with a star once quiet.
func _draw_ring(r: int, now: bool) -> void:
	var middle := RINGS[r]
	var done := _calm[r] >= 1.0
	if now:
		for g in range(6, 0, -1):
			_ellipse(middle, RING_HALF + Vector2(g * 2.0, g), Color(HiveArt.GOLD, 14.0 / 255.0))
	var steps := 120
	for s in steps:
		var ang := TAU * s / steps
		var at := middle + Vector2(cos(ang) * RING_HALF.x, sin(ang) * RING_HALF.y)
		if done:
			draw_rect(Rect2(to_canvas(at.floor() - Vector2.ONE), Vector2.ONE * 3.0 * HiveArt.PIXEL), HiveArt.OUT)
			draw_rect(Rect2(to_canvas(at.floor()), Vector2.ONE * 2.0 * HiveArt.PIXEL), Color8(112, 199, 107))
		elif now:
			draw_rect(Rect2(to_canvas(at.floor() - Vector2.ONE), Vector2.ONE * 3.0 * HiveArt.PIXEL), HiveArt.OUT)
			draw_rect(Rect2(to_canvas(at.floor()), Vector2.ONE * 2.0 * HiveArt.PIXEL),
				HiveArt.GOLD if s % 10 else HiveArt.HONEY_SHINE)
		elif s % 6 < 3:
			draw_rect(Rect2(to_canvas(at.floor()), Vector2.ONE * 2.0 * HiveArt.PIXEL), Color8(245, 232, 200, 170))
	if not done and _calm[r] > 0.0:
		var sweep := int(steps * _calm[r])
		for s in sweep:
			var ang := -PI * 0.5 + TAU * s / steps
			for w in 3:
				var at := middle + Vector2(cos(ang) * (RING_HALF.x - 4.0 - w), sin(ang) * (RING_HALF.y - 3.0 - w))
				HiveArt.px(self, to_canvas(at), HiveArt.HONEY_LIGHT)
	if done:
		var bright := 0.6 + 0.4 * sin(age * 4.0 + r)
		HiveArt.star(self, to_canvas(middle + Vector2(RING_HALF.x - 2.0, -RING_HALF.y + 2.0)), 3, bright)
		HiveArt.star(self, to_canvas(middle + Vector2(-RING_HALF.x + 4.0, -RING_HALF.y - 2.0)), 2, bright)


func _ellipse(middle: Vector2, half: Vector2, ink: Color) -> void:
	var top := floori(middle.y - half.y)
	for y in range(top, ceili(middle.y + half.y)):
		var dy := (y + 0.5 - middle.y) / half.y
		if absf(dy) >= 1.0:
			continue
		var w := half.x * sqrt(1.0 - dy * dy)
		var from := roundf(middle.x - w)
		draw_rect(Rect2(to_canvas(Vector2(from, y)), Vector2(roundf(middle.x + w) - from, 1.0) * HiveArt.PIXEL), ink)
