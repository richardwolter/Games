## The hive room's first step: the swarm dragged out of the air into the box (2026-09-30, the
## beehive's second pass, Richard; off `tools/hive_mockup2.py` `room_catch`).
##
## **No branch.** The swarm is in the air over the lawn as clouds of real bees — every one the
## sheet's own bee sprite, wings flicking — split into `CLUMPS` clumps, each hanging about its
## own spot in the sky and breathing, a dashed ring breathing round where a press takes it.
## The open brood box stands on the lawn; its mouth lights while a clump in hand is over it.
## **The player presses on a clump and drags it**: its middle follows the pointer and every bee
## in it chases its own place round that middle at its own pace (`CHASE`), so a clump pulled
## fast strings out into a trail behind the pointer and gathers again when it stops. **Let go
## over the box** and the clump pours into its mouth: most of it goes in and joins the heap,
## and `MISS` of it veers off at the lip and flies back to a cloud still in the air. Let go
## anywhere else and it drifts home. No failure, no timer.
##
## **The box says how full it is twice**: the heap of bees over its bars grows with what is in
## (`HEAP_TALL`), and the five comb cells on its front fill with bees one by one. **At
## `ENOUGH` (80%) boxed the step is done**: the last of the air pours in by itself, the pile
## crawls down through the cracks between the bars, the shared ending plays over the box
## (`HiveStep.payoff`) with `hive_crown`, and `finished` follows `PAYOFF_HOLD` later.
##
## **Sound** (2026-10-04): the colony's buzz while a clump is in hand, higher the faster it is
## dragged; a whoomp and a chime a step up the scale for each clump poured in.
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
const PIP_STEP := 18.0
const PIPS := 5

## The swarm: this many clumps, each of `PER_CLUMP` bees spread `SPREAD` painted pixels about
## its middle (a gaussian, half-widths), round these homes in the sky.
const CLUMPS := 5
const PER_CLUMP := 64
const SPREAD := Vector2(34.0, 20.0)
const HOMES: Array[Vector2] = [
	Vector2(104.0, 112.0), Vector2(212.0, 82.0), Vector2(338.0, 66.0), Vector2(452.0, 88.0),
	Vector2(548.0, 118.0),
]
const SEED := 2101
## A clump drifts about its home this far on slow sines, and breathes this much.
const DRIFT := Vector2(14.0, 7.0)
const BREATHE := 0.12
## The clumps are loose (2026-10-04, Richard: "messier, not all concentrated"): every bee in the
## air jitters `JITTER` px about its place, and now and then strays out on a loop up to `STRAY`
## px and back, each on its own clock. A clump in hand pulls its strays in.
const JITTER := 4.0
const STRAY := 46.0
## Loose bees with no clump, wandering the sky (`HiveStep.wanderers`): not catchable.
const AIR := 28
const AIR_BOX := Rect2(20.0, 20.0, 600.0, 190.0)
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
## Long enough for the pile to go in through the cracks and the shared ending to land.
const PAYOFF_HOLD := 2.6
## The heap over the bars: its half-width across the mouth and its height when all are in.
const HEAP_HALF := 52.0
const HEAP_TALL := 26.0
## The box's mouth brightens while a clump in hand is over it (2026-10-04, Richard: the three
## yellow ellipses round the box were "really ugly"; gone): this strong at most.
const MOUTH_LIT := 0.55
## The shadow under the box, in the one ink every shadow on land takes (`Shade.tint_on`),
## nudged along the sun as if from `CONTACT_RISE` painted px up: a solid core under its base and
## a checkered fringe round it (2026-10-04, Richard: the plain ellipse "looks bad").
const CONTACT_RISE := 4.0
const SHADE_CORE := Vector2(56.0, 4.0)
const SHADE_FRINGE := Vector2(68.0, 6.0)
## The round comb cells on the box's front: their middle across the front from the box's feet
## mark, their row, their radius and step.
const PIP_Y := 51.0
const PIP_R := 5.0
## The ring on each clump in the air, round where a press takes it: its pulse (painted px and
## a second), and its dashes turning.
const MARK_BREATHE := 2.5
const MARK_RATE := 2.6
const MARK_TURN := 0.6
## The pile going in through the cracks once the swarm is caught: the gaps between the box's
## top bars, as offsets across from the mouth's middle (the builder's bars, every 11 px), when
## the first bee starts down and how long each takes.
const CRACK_FIRST := -49.0
const CRACK_STEP := 11.0
const CRACKS := 10
const DRAIN_FROM := 0.3
const DRAIN_SPREAD := 1.0
const DRAIN_TIME := 0.5
## Sound: the colony's buzz while a clump is in hand, swelling in and out over `BUZZ_FADE`, up
## to `BUZZ_DB`. **Dragged fast it gets louder, not much higher** (2026-10-04, Richard: the
## pitch sweep "sounds like a formula 1 car"): a few percent of pitch at most
## (`BUZZ_PITCH_PER` a painted px a second, to `BUZZ_PITCH_MOST`), `BUZZ_LOUDER` dB more at
## full tilt, and a wavering `BUZZ_WAVER` so it hums like a swarm rather than an engine. The
## whoomp as a clump pours in, and the chime over it, a step up the scale (`CHIME_STEPS`) for
## each clump boxed.
const BUZZ_DB := -14.0
const BUZZ_FADE := 0.15
const BUZZ_PITCH_PER := 0.0004
const BUZZ_PITCH_MOST := 1.08
const BUZZ_LOUDER := 4.0
const BUZZ_FAST := 300.0
const BUZZ_WAVER := 0.025
const WHOOMP_DB := -6.0
const CHIME_DB := -14.0
const CHIME_STEPS: Array[float] = [1.0, 1.122, 1.26, 1.335, 1.498]
## The trail of a clump in hand: this many ghost places, one every `TRAIL_EVERY` seconds.
const TRAIL := 7
const TRAIL_EVERY := 0.035
## The wing whisk behind a flying bee, and how fast wings beat (flips a second).
const WHISK := Color(248 / 255.0, 244 / 255.0, 232 / 255.0)
const BEAT := 22.0
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
var _buzz: AudioStreamPlayer
var _buzz_level := 0.0
var _whoomp: AudioStreamPlayer
var _chime: AudioStreamPlayer
var _held_was := Vector2.ZERO
var _drag_speed := 0.0


func begin() -> void:
	super.begin()
	_roll.seed = SEED
	_held = -1
	_in = 0
	_caught = false
	_caught_age = 0.0
	_was_down = false
	_trail.clear()
	_make_players()
	_buzz_level = 0.0
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
	wanderers(AIR, AIR_BOX, SEED + 7)


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
	if best >= 0:
		_held_was = _mid[best]
	return best


func drag_to(p: Vector2) -> void:
	_pointer = p


## Let the clump in hand go where the pointer is: into the box if it is over the mouth.
func let_go() -> void:
	if _held < 0:
		return
	var c := _held
	_held = -1
	if _over_mouth(_pointer):
		_pour(c)
		var boxed := 0
		for k in CLUMPS:
			if _gone[k]:
				boxed += 1
		_ring(_whoomp, WHOOMP_DB, 1.0)
		_ring(_chime, CHIME_DB, CHIME_STEPS[clampi(boxed - 1, 0, CHIME_STEPS.size() - 1)])


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


## Whether a clump let go at `p` pours into the box.
func _over_mouth(p: Vector2) -> bool:
	var gap := p - _mouth()
	return Vector2(gap.x / DROP_REACH.x, gap.y / DROP_REACH.y).length() <= 1.0


func _make_players() -> void:
	if _buzz != null:
		return
	_buzz = _player(&"Buzz", HiveSounds.loop_stream(&"hive_hum"))
	_whoomp = _player(&"Whoomp", HiveSounds.make(&"hive_whoomp"))
	_chime = _player(&"Chime", HiveSounds.make(&"hive_chime"))


func _player(called: StringName, stream: AudioStream) -> AudioStreamPlayer:
	var made := AudioStreamPlayer.new()
	made.name = called
	made.bus = Prefs.BUS_SFX
	made.stream = stream
	made.volume_db = Prefs.BUS_SILENT
	add_child(made)
	return made


func _ring(player: AudioStreamPlayer, db: float, pitch: float) -> void:
	if player == null or player.stream == null:
		return
	player.volume_db = db
	player.pitch_scale = pitch
	player.play()


## The buzz while a clump is in hand: in and out over `BUZZ_FADE`, higher the faster it goes.
func _drive_buzz(delta: float) -> void:
	if _buzz == null or _buzz.stream == null:
		return
	if _held >= 0:
		var moved := _mid[_held].distance_to(_held_was) / maxf(delta, 0.0001)
		_drag_speed = lerpf(_drag_speed, moved, 1.0 - exp(-8.0 * delta))
		_held_was = _mid[_held]
	else:
		_drag_speed = lerpf(_drag_speed, 0.0, 1.0 - exp(-8.0 * delta))
	_buzz_level = move_toward(_buzz_level, 1.0 if _held >= 0 else 0.0, delta / BUZZ_FADE)
	if _buzz_level <= 0.0:
		if _buzz.playing:
			_buzz.stop()
		return
	if not _buzz.playing:
		_buzz.play()
	var fast := clampf(_drag_speed / BUZZ_FAST, 0.0, 1.0)
	_buzz.volume_db = lerpf(Prefs.BUS_SILENT, BUZZ_DB + BUZZ_LOUDER * fast, sqrt(_buzz_level))
	var waver := sin(age * 5.3) * 0.6 + sin(age * 8.9 + 1.7) * 0.4
	_buzz.pitch_scale = minf(1.0 + _drag_speed * BUZZ_PITCH_PER, BUZZ_PITCH_MOST) + waver * BUZZ_WAVER


func _pour(c: int) -> void:
	_gone[c] = true
	for b in _pos.size():
		if _clump[b] != c or _state[b] == Bee.IN:
			continue
		_state[b] = Bee.POUR
		_off[b] = Vector2(_roll.randf_range(-1.0, 1.0) * POUR_SPREAD.x, _roll.randf_range(-1.0, 1.0) * POUR_SPREAD.y)


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
	payoff(_mouth() + Vector2(0.0, -6.0), 90.0)
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
			var ph := _phase[b]
			var jitter := Vector2(sin(age * (2.4 + fmod(ph, 1.3)) + ph), cos(age * (1.9 + fmod(ph, 1.1)) + ph * 1.7)) * JITTER
			target = _mid[c] + _off[b] * tight + jitter
			if c != _held and s == Bee.AIR:
				target += _stray(b)
		_pos[b] = _pos[b].lerp(target, 1.0 - exp(-_chase[b] * delta))
		if s == Bee.BACK and _pos[b].distance_to(target) < 6.0:
			_state[b] = Bee.AIR
		elif s == Bee.POUR and _pos[b].distance_to(target) < IN_REACH:
			if not _caught and _roll.randf() < MISS:
				_send_back(b)
			else:
				_land(b)
	_check_enough()
	_drive_buzz(delta)
	if _caught:
		_caught_age += delta
		if _caught_age >= PAYOFF_HOLD:
			done_once()


func pad_mark() -> Rect2:
	return Rect2()


## Bee `b`'s loop out of its clump this moment: nothing most of the time, then out along its
## own heading to `STRAY` and back, eased at both ends.
func _stray(b: int) -> Vector2:
	var ph := _phase[b]
	var h := fposmod(ph * 7.31, 1.0)
	var p := fposmod(age / (4.0 + 6.0 * h) + h * 3.7, 1.0)
	var peel := sin(clampf((p - 0.72) / 0.28, 0.0, 1.0) * PI)
	if peel <= 0.0:
		return Vector2.ZERO
	var turn := ph * 3.0 + sin(age * 2.0 + ph) * 0.8
	return Vector2(cos(turn), sin(turn) * 0.6) * STRAY * (0.5 + 0.5 * h) * peel


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	var feet := _box_feet()
	var mouth := _mouth()
	_draw_shadow(feet)
	HiveArt.draw(self, &"box", to_canvas(feet), &"feet")
	_draw_pips(feet)
	# A clump in hand over the mouth: the mouth lights, warm, so a let-go here is a pour.
	if _held >= 0 and _over_mouth(_pointer):
		var lit := MOUTH_LIT * (0.8 + 0.2 * sin(age * 8.0))
		_ellipse(mouth + Vector2(0.0, 1.0), Vector2(56.0, 5.0), Color(HiveArt.HONEY_SHINE, lit * 0.5))
		_ellipse(mouth + Vector2(0.0, 1.0), Vector2(40.0, 3.0), Color(HiveArt.STAR_WHITE, lit * 0.4))
	# The heap over the bars: every bee in, in its slot, the heap as tall as what is in. Once
	# the swarm is caught the pile goes in through the cracks, the top of it last.
	var tall := HEAP_TALL * sqrt(boxed_share())
	for b in _pos.size():
		if _state[b] != Bee.IN:
			continue
		var slot := _slot[b]
		var at := mouth + Vector2(slot.x * sqrt(boxed_share() / ENOUGH * 0.9 + 0.1), slot.y * tall - 1.0)
		var alpha := 1.0
		if _caught:
			var start := DRAIN_FROM + (-slot.y) * DRAIN_SPREAD + fposmod(_phase[b], 0.3)
			var s := clampf((_caught_age - start) / DRAIN_TIME, 0.0, 1.0)
			if s >= 1.0:
				continue
			if s > 0.0:
				var k := clampi(roundi((at.x - mouth.x - CRACK_FIRST) / CRACK_STEP), 0, CRACKS - 1)
				var crack := Vector2(mouth.x + CRACK_FIRST + k * CRACK_STEP, mouth.y + 3.0)
				at = at.lerp(crack, s * s * (3.0 - 2.0 * s))
				alpha = 1.0 - clampf((s - 0.6) / 0.4, 0.0, 1.0)
		_bee(at, sin(_phase[b] + age * 0.7) > 0.0, sin(age * BEAT * 0.3 + _phase[b]) > 0.6, alpha)
	# The trail of the clump in hand: soft honey-light smudges where it has been.
	for k in _trail.size():
		var fade := 1.0 - float(k + 1) / float(TRAIL + 1)
		var ink := HiveArt.HONEY_LIGHT
		ink.a = 0.28 * fade
		_ellipse(_trail[k], Vector2(16.0 - k, 9.0 - k * 0.6), ink)
	draw_wanderers()
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
	_draw_marks()
	draw_payoff()


func _bee(at: Vector2, left: bool, wings: bool, alpha := 1.0) -> void:
	var piece := &"bee_r" if wings else &"bee_r_rest"
	var canvas := to_canvas(at.floor())
	if HiveArt.has(piece):
		HiveArt.draw(self, piece, canvas, &"c", left, alpha)
	else:
		draw_rect(Rect2(canvas, Vector2(3.0, 2.0) * HiveArt.PIXEL), Color(HiveArt.BEE_GOLD, alpha))


## The shadow under the box: a solid core and a checkered fringe, along the sun.
func _draw_shadow(feet: Vector2) -> void:
	var ink := Shade.tint_on(null, Shade.On.LAND)
	var at := Vector2(feet.x, feet.y - 1.0) + Shade.drop(null, CONTACT_RISE).round()
	for y in range(floori(at.y - SHADE_FRINGE.y), ceili(at.y + SHADE_FRINGE.y)):
		var outer := _row(at, SHADE_FRINGE, y)
		if outer.y <= outer.x:
			continue
		var inner := _row(at, SHADE_CORE, y)
		for x in range(int(outer.x), int(outer.y)):
			var core := inner.y > inner.x and x >= int(inner.x) and x < int(inner.y)
			if core or (x + y) % 2 == 0:
				draw_rect(Rect2(to_canvas(Vector2(x, y)), Vector2.ONE * HiveArt.PIXEL), ink)


## Where an ellipse's row `y` runs, as (left, right); empty off it.
static func _row(middle: Vector2, half: Vector2, y: int) -> Vector2:
	var dy := (float(y) + 0.5 - middle.y) / half.y
	if absf(dy) >= 1.0:
		return Vector2.ZERO
	var w := half.x * sqrt(1.0 - dy * dy)
	return Vector2(roundf(middle.x - w), roundf(middle.x + w))


## The ring round each clump still in the air: dashes on an ellipse round where a press takes
## it, turning slowly and breathing in and out, a dark pixel under each so it reads on the sky.
## Not on the clump in hand, and none once the swarm is caught.
func _draw_marks() -> void:
	if _caught:
		return
	for c in CLUMPS:
		if _gone[c] or c == _held:
			continue
		var breathe := sin(age * MARK_RATE + c * 1.3) * MARK_BREATHE
		var half := Vector2(GRAB_REACH + breathe, (GRAB_REACH + breathe) / 1.6)
		var steps := int(half.x * 2.4)
		var turn := age * MARK_TURN + c
		var glow := 0.65 + 0.25 * sin(age * MARK_RATE * 1.3 + c)
		for s in steps:
			var u := float(s) / steps
			if fmod(u * 16.0 + turn, 2.0) > 1.1:
				continue
			var ang := TAU * u
			var p := (_mid[c] + Vector2(cos(ang) * half.x, sin(ang) * half.y)).floor()
			draw_rect(Rect2(to_canvas(p + Vector2(0.0, 1.0)), Vector2.ONE * HiveArt.PIXEL), Color(HiveArt.OUT, 0.35 * glow))
			draw_rect(Rect2(to_canvas(p), Vector2.ONE * HiveArt.PIXEL), Color(HiveArt.HONEY_SHINE, glow))


## The five round comb cells on the box's front, centred on it: filled with bees one by one as
## the box fills.
func _draw_pips(feet: Vector2) -> void:
	var tl := feet - (HiveArt.anchor(&"box", &"feet") if HiveArt.knows(&"box") else BOX_FEET)
	var middle_x := feet.x
	var lit := int(floorf(boxed_share() / ENOUGH * PIPS + 0.001))
	for k in PIPS:
		var at := Vector2(middle_x + (k - (PIPS - 1) * 0.5) * PIP_STEP, tl.y + PIP_Y)
		var full := k < lit
		_disc(at, PIP_R + 1.0, HiveArt.OUT)
		_disc(at, PIP_R, HiveArt.HONEY if full else CELL_EMPTY)
		if full:
			_disc(at + Vector2(-1.0, -1.0), PIP_R - 2.0, HiveArt.HONEY_LIGHT)
			_cell(at + Vector2(-3.0, -1.0), Vector2(6.0, 1.0), HiveArt.BEE_STRIPE)
			_cell(at + Vector2(-3.0, 2.0), Vector2(6.0, 1.0), HiveArt.BEE_STRIPE)
			_cell(at + Vector2(-2.0, -3.0), Vector2(2.0, 1.0), HiveArt.HONEY_SHINE)
		else:
			_disc(at + Vector2(1.0, 1.0), PIP_R - 2.0, Color(0.0, 0.0, 0.0, 0.25))


## A filled round disc of whole painted px.
func _disc(middle: Vector2, r: float, ink: Color) -> void:
	_ellipse(middle + Vector2(0.5, 0.5), Vector2(r + 0.5, r + 0.5), ink)


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

