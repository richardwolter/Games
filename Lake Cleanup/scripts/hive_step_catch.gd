## The hive room's first step: the swarm dragged out of the air into the box (2026-09-30, the
## beehive's second pass, Richard; off `tools/hive_mockup2.py` `room_catch`).
##
## **No branch.** The swarm is in the air over the lawn as clouds of real bees — every one the
## sheet's own bee sprite, wings flicking — split into `CLUMPS` clumps, each hanging about its
## own spot in the sky and breathing. The open brood box stands on the lawn in a warm glow.
## **The player presses on a clump and drags it**: its middle follows the pointer and every bee
## in it chases its own place round that middle at its own pace (`CHASE`), so a clump pulled
## fast strings out into a trail behind the pointer and gathers again when it stops. **Let go
## over the box** and the clump pours into its mouth: most of it goes in and joins the heap,
## and `MISS` of it veers off at the lip and flies back to a cloud still in the air. Let go
## anywhere else and it drifts home. No failure, no timer.
##
## **The box says how full it is twice**: the heap of bees over its bars grows with what is in
## (`HEAP_TALL`), and the five comb cells on its front fill with bees one by one. **At
## `ENOUGH` (80%) boxed the step is done**: the last of the air pours in by itself, the box
## glows gold, a crown pops over it with stars and `hive_crown`, and `finished` follows
## `PAYOFF_HOLD` later.
##
## Everything moves on exponential eases and is drawn on whole painted pixels: a bee glides,
## its picture never lands between pixels.
##
## **The pad**: the stick moves the hidden pointer (`pad_move`) and A or RT held is the grab.
##
## **Harness hooks, never gated on `awake`**: `grab_at(p)` (the clump taken there, or -1),
## `drag_to(p)`, `let_go()`, `box_clump(i)` (the whole clump in at once), `boxed_share()`,
## `caught()`, `clump_pos(i)`, `clump_count()` and `settle()`.
class_name HiveStepCatch
extends HiveStep

## The box's feet on the art grid, and its pieces' own numbers for a layout with no json.
const BOX_FEET_AT := Vector2(318.0, 302.0)
const BOX_MOUTH := Vector2(61.0, 6.0)
const BOX_FEET := Vector2(55.0, 69.0)
## The five comb cells on the box's front, in the box piece's own pixels: the first cell's top
## left and the step to the next (the mockup's 278 + 18k, 283 on its pasted box).
const PIP_AT := Vector2(24.0, 45.0)
const PIP_STEP := 18.0
const PIPS := 5

## The swarm: this many clumps, each of `PER_CLUMP` bees spread `SPREAD` painted pixels about
## its middle (a gaussian, half-widths), round these homes in the sky.
const CLUMPS := 5
const PER_CLUMP := 64
const SPREAD := Vector2(26.0, 15.0)
const HOMES: Array[Vector2] = [
	Vector2(104.0, 112.0), Vector2(212.0, 82.0), Vector2(338.0, 66.0), Vector2(452.0, 88.0),
	Vector2(548.0, 118.0),
]
const SEED := 2101
## A clump drifts about its home this far on slow sines, and breathes this much.
const DRIFT := Vector2(14.0, 7.0)
const BREATHE := 0.12
## A bee's chase after its place, a second: the slowest and the quickest. The spread is the
## trail: the quick ones stay on the pointer, the slow ones string out behind.
const CHASE := Vector2(3.0, 12.0)
## A clump in hand draws in to this share of its spread, and its middle eases after the pointer
## this fast.
const HELD_TIGHT := 0.55
const HELD_EASE := 22.0
## Grab reach round a clump's middle, painted pixels, measured with the height stretched.
const GRAB_REACH := 34.0
## Let go within this of the box's mouth (height stretched), the clump pours in.
const DROP_REACH := Vector2(70.0, 46.0)
## A pouring bee within this of the mouth goes in; `MISS` of them veer off back to the air.
const IN_REACH := 7.0
const MISS := 0.12
## The fly-in: a pouring bee's place is the mouth, spread this much.
const POUR_SPREAD := Vector2(20.0, 4.0)
## Done at this share boxed.
const ENOUGH := 0.8
const PAYOFF_HOLD := 1.6
## The heap over the bars: its half-width across the mouth and its height when all are in.
const HEAP_HALF := 52.0
const HEAP_TALL := 26.0
## The glow under the box and the halo it turns gold in once caught.
const GLOW_INK := Color(252 / 255.0, 204 / 255.0, 84 / 255.0)
## The shadow on the lawn under what stands in this step: a contact ellipse in the one ink
## every shadow on land takes (`Shade.tint_on`, 2026-10-02, one sun), nudged along the sun
## (`Shade.drop`) as if from `CONTACT_RISE` painted px up, so it falls down and to the left
## like every other shadow on the island. Kept an ellipse and kept flat, by decision: the
## step is seen from eye height over the lawn, where a footprint is a thin band, and a
## silhouette cast off the close-up would be the one shadow in the room not lying on it.
const CONTACT_RISE := 4.0
## The trail of a clump in hand: this many ghost places, one every `TRAIL_EVERY` seconds.
const TRAIL := 7
const TRAIL_EVERY := 0.035
## The wing whisk behind a flying bee, and how fast wings beat (flips a second).
const WHISK := Color(248 / 255.0, 244 / 255.0, 232 / 255.0)
const BEAT := 22.0
const STAR_LIFE := 0.8
## Empty comb cells on the box front, and the stripes across a full one.
const CELL_EMPTY := Color(60 / 255.0, 40 / 255.0, 26 / 255.0)

enum Bee { AIR, POUR, IN, BACK }

var _roll := RandomNumberGenerator.new()
## Per bee: its clump, its state, its place, its offset in the clump, its chase and its phase.
var _clump: PackedInt32Array = []
var _state: PackedInt32Array = []
var _pos: PackedVector2Array = []
var _off: PackedVector2Array = []
var _chase: PackedFloat32Array = []
var _phase: PackedFloat32Array = []
var _was: PackedVector2Array = []
## Its place in the heap once in, the heap slot.
var _slot: PackedVector2Array = []
## Per clump: its middle, whether it is still in the air (not poured), and its home.
var _mid: PackedVector2Array = []
var _gone: Array[bool] = []
var _held := -1
var _pointer := Vector2.ZERO
var _trail: Array[Vector2] = []
var _trail_clock := 0.0
var _in := 0
var _total := 1
var _caught := false
var _caught_age := 0.0
var _was_down := false
## `{at, age, arm}`, painted pixels.
var _stars: Array[Dictionary] = []


func begin() -> void:
	super.begin()
	_roll.seed = SEED
	_held = -1
	_in = 0
	_caught = false
	_caught_age = 0.0
	_was_down = false
	_trail.clear()
	_stars.clear()
	_mid = PackedVector2Array(HOMES)
	_gone.clear()
	for k in CLUMPS:
		_gone.append(false)
	var count := CLUMPS * PER_CLUMP
	_total = count
	_clump.resize(count)
	_state.resize(count)
	_pos.resize(count)
	_was.resize(count)
	_off.resize(count)
	_chase.resize(count)
	_phase.resize(count)
	_slot.resize(count)
	for i in count:
		var c := i / PER_CLUMP
		_clump[i] = c
		_state[i] = Bee.AIR
		var off := Vector2(_roll.randfn(0.0, 0.5) * SPREAD.x, _roll.randfn(0.0, 0.5) * SPREAD.y)
		_off[i] = off
		_pos[i] = HOMES[c] + off
		_was[i] = _pos[i]
		_chase[i] = _roll.randf_range(CHASE.x, CHASE.y)
		_phase[i] = _roll.randf() * TAU
		# The heap: wide at its foot, rounding off as it rises (bee_mass's own shape).
		var t := _roll.randf()
		var half := HEAP_HALF * sqrt(maxf(1.0 - t, 0.0))
		_slot[i] = Vector2(_roll.randf_range(-half, half), -t)


# --- the harness's hooks ------------------------------------------------------------------

func clump_count() -> int:
	return CLUMPS


## A clump's middle, painted pixels, or the mouth once it has poured.
func clump_pos(i: int) -> Vector2:
	if i < 0 or i >= CLUMPS:
		return Vector2.ZERO
	return _mid[i]


## Take the clump under `p`, if any is still in the air. Returns its index, or -1.
func grab_at(p: Vector2) -> int:
	_pointer = p
	if _caught:
		return -1
	var best := -1
	var near := GRAB_REACH
	for c in CLUMPS:
		if _gone[c]:
			continue
		var gap := p - _mid[c]
		var d := Vector2(gap.x, gap.y * 1.6).length()
		if d < near:
			near = d
			best = c
	_held = best
	_trail.clear()
	return best


func drag_to(p: Vector2) -> void:
	_pointer = p


## Let the clump in hand go where the pointer is: into the box if it is over the mouth.
func let_go() -> void:
	if _held < 0:
		return
	var c := _held
	_held = -1
	var gap := _pointer - _mouth()
	if Vector2(gap.x / DROP_REACH.x, gap.y / DROP_REACH.y).length() <= 1.0:
		_pour(c)


## Put a whole clump in the box at once, none missed.
func box_clump(i: int) -> void:
	if i < 0 or i >= CLUMPS or _gone[i]:
		return
	_gone[i] = true
	if _held == i:
		_held = -1
	for b in _pos.size():
		if _clump[b] == i and _state[b] != Bee.IN:
			_land(b)
	_check_enough()


func boxed_share() -> float:
	return float(_in) / float(maxi(_total, 1))


func caught() -> bool:
	return _caught


## Every clump in and `finished` at once.
func settle() -> void:
	for c in CLUMPS:
		box_clump(c)
	done_once()


# --- the play -----------------------------------------------------------------------------

func _mouth() -> Vector2:
	return _box_feet() - HiveArt.anchor(&"box", &"feet") + HiveArt.anchor(&"box", &"mouth") \
		if HiveArt.knows(&"box") else _box_feet() - BOX_FEET + BOX_MOUTH


func _box_feet() -> Vector2:
	return BOX_FEET_AT


func _pour(c: int) -> void:
	_gone[c] = true
	for b in _pos.size():
		if _clump[b] != c or _state[b] == Bee.IN:
			continue
		_state[b] = Bee.POUR
		_off[b] = Vector2(_roll.randf_range(-1.0, 1.0) * POUR_SPREAD.x, _roll.randf_range(-1.0, 1.0) * POUR_SPREAD.y)
	HiveStep.sound(&"hive_swarm", -12.0, 1.3)


func _land(b: int) -> void:
	_state[b] = Bee.IN
	_in += 1


## A missed bee: back to the nearest clump still in the air, or into the box when none is.
func _send_back(b: int) -> void:
	var best := -1
	var near := INF
	for c in CLUMPS:
		if _gone[c] or c == _held:
			continue
		var d := _pos[b].distance_to(_mid[c])
		if d < near:
			near = d
			best = c
	if best < 0:
		_land(b)
		return
	_clump[b] = best
	_state[b] = Bee.BACK
	_off[b] = Vector2(_roll.randfn(0.0, 0.5) * SPREAD.x, _roll.randfn(0.0, 0.5) * SPREAD.y)


func _check_enough() -> void:
	if _caught or boxed_share() < ENOUGH:
		return
	_caught = true
	_caught_age = 0.0
	_held = -1
	# The last of the air follows the rest in.
	for c in CLUMPS:
		if not _gone[c]:
			_pour(c)
	var at := _mouth() + Vector2(0.0, -HEAP_TALL - 10.0)
	for k in 10:
		_stars.append({
			"at": at + Vector2(_roll.randf_range(-60.0, 60.0), _roll.randf_range(-24.0, 20.0)),
			"age": -_roll.randf_range(0.0, 0.4), "arm": 1 + _roll.randi() % 3,
		})
	HiveStep.sound(&"hive_crown")


func _process(delta: float) -> void:
	if is_inside_tree() and awake() and not _caught:
		pad_move(delta)
		var down := tool_down()
		var at := art_mouse()
		if down and not _was_down:
			grab_at(at)
		elif down:
			drag_to(at)
		elif _was_down:
			let_go()
		_was_down = down
	# The clumps' middles: home and breathing, or on the pointer.
	for c in CLUMPS:
		if _gone[c]:
			_mid[c] = _mid[c].lerp(_mouth(), 1.0 - exp(-4.0 * delta))
			continue
		if c == _held:
			_mid[c] = _mid[c].lerp(_pointer, 1.0 - exp(-HELD_EASE * delta))
			continue
		var home := HOMES[c] + Vector2(
			sin(age * 0.5 + c * 1.7) * DRIFT.x, sin(age * 0.8 + c * 2.3) * DRIFT.y
		)
		_mid[c] = _mid[c].lerp(home, 1.0 - exp(-1.6 * delta))
	if _held >= 0:
		_trail_clock -= delta
		if _trail_clock <= 0.0:
			_trail_clock = TRAIL_EVERY
			_trail.push_front(_mid[_held])
			if _trail.size() > TRAIL:
				_trail.pop_back()
	elif not _trail.is_empty():
		_trail_clock -= delta
		if _trail_clock <= 0.0:
			_trail_clock = TRAIL_EVERY
			_trail.pop_back()
	var mouth := _mouth()
	for b in _pos.size():
		_was[b] = _pos[b]
		var s := _state[b]
		if s == Bee.IN:
			continue
		var c := _clump[b]
		var target: Vector2
		if s == Bee.POUR:
			target = mouth + _off[b]
		else:
			var tight := HELD_TIGHT if c == _held else 1.0 + BREATHE * sin(age * 1.3 + c)
			var jitter := Vector2(sin(age * 3.1 + _phase[b]), cos(age * 2.3 + _phase[b] * 1.7)) * 2.5
			target = _mid[c] + _off[b] * tight + jitter
		_pos[b] = _pos[b].lerp(target, 1.0 - exp(-_chase[b] * delta))
		if s == Bee.BACK and _pos[b].distance_to(target) < 6.0:
			_state[b] = Bee.AIR
		elif s == Bee.POUR and _pos[b].distance_to(target) < IN_REACH:
			if not _caught and _roll.randf() < MISS:
				_send_back(b)
			else:
				_land(b)
	_check_enough()
	if _caught:
		_caught_age += delta
		if _caught_age >= PAYOFF_HOLD:
			done_once()
	var kept: Array[Dictionary] = []
	for star: Dictionary in _stars:
		star["age"] = float(star["age"]) + delta
		if float(star["age"]) < STAR_LIFE:
			kept.append(star)
	_stars = kept


func pad_mark() -> Rect2:
	return Rect2()


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	var feet := _box_feet()
	var mouth := _mouth()
	# The glow the box stands in, gold once the swarm is in; its shadow on the lawn.
	var gold := clampf(_caught_age / 0.5, 0.0, 1.0) if _caught else 0.0
	for ring: Vector3 in [Vector3(120, 40, 26), Vector3(85, 28, 34), Vector3(60, 18, 44)]:
		var ink := GLOW_INK.lerp(HiveArt.GOLD, gold)
		ink.a = (ring.z + gold * 30.0) / 255.0
		_ellipse(Vector2(mouth.x, feet.y - 48.0), Vector2(ring.x, ring.y), ink)
	_ellipse(
		Vector2(feet.x, feet.y - 1.0) + Shade.drop(null, CONTACT_RISE), Vector2(85.0, 8.0),
		Shade.tint_on(null, Shade.On.LAND)
	)
	HiveArt.draw(self, &"box", to_canvas(feet), &"feet")
	_draw_pips(feet)
	# The heap over the bars: every bee in, in its slot, the heap as tall as what is in.
	var tall := HEAP_TALL * sqrt(boxed_share())
	for b in _pos.size():
		if _state[b] != Bee.IN:
			continue
		var slot := _slot[b]
		var at := mouth + Vector2(slot.x * sqrt(boxed_share() / ENOUGH * 0.9 + 0.1), slot.y * tall - 1.0)
		_bee(at, sin(_phase[b] + age * 0.7) > 0.0, sin(age * BEAT * 0.3 + _phase[b]) > 0.6)
	# The trail of the clump in hand: soft honey-light smudges where it has been.
	for k in _trail.size():
		var fade := 1.0 - float(k + 1) / float(TRAIL + 1)
		var ink := HiveArt.HONEY_LIGHT
		ink.a = 0.28 * fade
		_ellipse(_trail[k], Vector2(16.0 - k, 9.0 - k * 0.6), ink)
	# The bees in the air, back to front.
	for b in _pos.size():
		if _state[b] == Bee.IN:
			continue
		var move := _pos[b] - _was[b]
		var left := move.x < -0.02 or (absf(move.x) <= 0.02 and sin(_phase[b]) < 0.0)
		if move.length_squared() > 0.04:
			var back := Vector2(3.0, 1.0) if left else Vector2(-3.0, 1.0)
			for k in 3:
				var whisk := WHISK
				whisk.a = (110.0 - k * 30.0) / 255.0
				HiveArt.px(self, to_canvas(_pos[b] + back + Vector2(k, 0.0) * (1.0 if left else -1.0)), whisk)
		_bee(_pos[b], left, fmod(age * BEAT + _phase[b], 2.0) < 1.0)
	if _caught:
		var grow := 2.0 * _back_out(clampf(_caught_age / 0.35, 0.0, 1.0))
		if grow > 0.05:
			HiveArt.draw(self, &"crown", to_canvas((mouth + Vector2(0.0, -tall - 22.0)).floor()), &"c", false, 1.0, grow)
	for star: Dictionary in _stars:
		var t := float(star["age"])
		if t < 0.0:
			continue
		var bright := sin(clampf(t / STAR_LIFE, 0.0, 1.0) * PI)
		HiveArt.star(self, to_canvas(star["at"]), int(roundf(float(star["arm"]) * bright)), bright)


func _bee(at: Vector2, left: bool, wings: bool) -> void:
	var piece := &"bee_r" if wings else &"bee_r_rest"
	var canvas := to_canvas(at.floor())
	if HiveArt.has(piece):
		HiveArt.draw(self, piece, canvas, &"c", left)
	else:
		draw_rect(Rect2(canvas, Vector2(3.0, 2.0) * HiveArt.PIXEL), HiveArt.BEE_GOLD)


## The five comb cells on the box's front: filled with bees one by one as the box fills.
func _draw_pips(feet: Vector2) -> void:
	var tl := feet - (HiveArt.anchor(&"box", &"feet") if HiveArt.knows(&"box") else BOX_FEET)
	var lit := int(floorf(boxed_share() / ENOUGH * PIPS + 0.001))
	for k in PIPS:
		var at := tl + PIP_AT + Vector2(PIP_STEP * k, 0.0)
		_cell(at, Vector2(14.0, 12.0), HiveArt.OUT)
		var full := k < lit
		_cell(at + Vector2.ONE, Vector2(12.0, 10.0), HiveArt.HONEY if full else CELL_EMPTY)
		if full:
			_cell(at + Vector2(1.0, 1.0), Vector2(12.0, 1.0), HiveArt.HONEY_LIGHT)
			_cell(at + Vector2(3.0, 3.0), Vector2(8.0, 2.0), HiveArt.BEE_STRIPE)
			_cell(at + Vector2(3.0, 7.0), Vector2(8.0, 2.0), HiveArt.BEE_STRIPE)


func _cell(at: Vector2, span: Vector2, ink: Color) -> void:
	draw_rect(Rect2(to_canvas(at.floor()), span * HiveArt.PIXEL), ink)


## A filled ellipse in whole painted-pixel rows.
func _ellipse(middle: Vector2, half: Vector2, ink: Color) -> void:
	var top := floori(middle.y - half.y)
	for y in range(top, ceili(middle.y + half.y)):
		var dy := (y + 0.5 - middle.y) / half.y
		if absf(dy) >= 1.0:
			continue
		var w := half.x * sqrt(1.0 - dy * dy)
		var from := roundf(middle.x - w)
		draw_rect(Rect2(to_canvas(Vector2(from, y)), Vector2(roundf(middle.x + w) - from, 1.0) * HiveArt.PIXEL), ink)


static func _back_out(t: float) -> float:
	var over := 1.70158
	var s := t - 1.0
	return 1.0 + (over + 1.0) * s * s * s + over * s * s
