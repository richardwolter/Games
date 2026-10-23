## The hive room's first step: the swarm dragged out of the air into the box (2026-09-30, the
## beehive's second pass, Richard; off `tools/hive_mockup2.py` `room_catch`. Redrawn 2026-10-18,
## the hive's visual overhaul: option A of `tools/hive_look/last_catch.png`, "bees on the
## frames").
##
## **No branch.** The swarm is in the air over the lawn as `CLUMPS` living clouds of bee A
## (`BeeArt`), each hanging about its own spot in the sky and breathing: a back row tucked in
## and a step darker, a middle crawling over one another, a rim hovering with its faces turned
## out, and a few loose ones circling. The clouds are drawn into one `CanvasGroup` through
## `shaders/hive_swarm.gdshader`, so the whole swarm wears one ink outline and where two bees
## touch the line between them is the soft brown (the mockup's `_lay` and `_ring_outline`),
## not a black lattice. A dashed ring breathes round each, where a press takes it.
##
## The box is the nucleus box front-on in the hive's sky blue (`catchbox_*`, baked by
## `tools/build_hive.py` off the mockup): lid off, five frame top bars, a pine cleat, the
## entrance and its landing board, a guard bee walking it. **Its mouth lights** — the gaps
## between the frames glow honey-warm and two bees fan on the landing board (`catchbox_lit`) —
## while a clump in hand is over it, and while a clump is pouring in.
##
## **The player presses on a clump and drags it**: its middle follows the pointer and every bee
## in it chases its own place round that middle at its own pace (`CHASE`), so a clump pulled
## fast strings out behind the pointer, flying, and balls up round it again when it stops. **Let
## go over the box** and the clump pours in: a curtain of bees diving head first between the
## frames, `MISS` of them veering off back to a cloud still in the air. Let go anywhere else and
## it drifts home. No failure, no timer.
##
## **The box counts on its frames, no UI**: every clump's worth boxed settles on the next frame,
## left to right — its own crowd on the bar, one squeezing down the gap with only its tail out,
## the gaps beside it showing stripes — and as it fills they spill onto the bar ends, the rim
## and the back rim (`catch_bar_bees`, the mockup's `_bar_bees`). A new frame's bees drop in.
## **At `ENOUGH` (80%) boxed the step is done**: the last of the air pours in by itself, the
## shared ending plays over the box (`HiveStep.payoff`) with `hive_crown`, and `finished`
## follows `PAYOFF_HOLD` later.
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
const BOX_MOUTH := Vector2(93.0, 59.0)
const BOX_FEET := Vector2(93.0, 114.0)
const BOX_BOARD := Vector2(93.0, 110.0)
## The five frames on the box, the six gaps round them.
const BARS := 5

## The swarm: this many clumps round these homes in the sky (the middle one 8 px lower than it
## was: a clump of bee A is about 40 px across, and at 66 its top sat on the step board).
const CLUMPS := 5
const HOMES: Array[Vector2] = [
	Vector2(104.0, 112.0), Vector2(212.0, 82.0), Vector2(338.0, 74.0), Vector2(452.0, 88.0),
	Vector2(548.0, 118.0),
]
const SEED := 2101
## A clump drifts about its home this far on slow sines, and breathes this much.
const DRIFT := Vector2(14.0, 7.0)
const BREATHE := 0.06
## Every bee in a clump jitters this many painted px about its place; a rim bee now and then
## strays out on a loop up to `STRAY` px and back (2026-10-04, Richard: "messier").
const JITTER := 0.6
const STRAY := 22.0
## The loose bees round a clump circle it at this many radians a second.
const ORBIT := 0.9
## The back row of a clump is tucked in and a step darker.
const BACK_TINT := Color(0.82, 0.8, 0.79)
## Loose bees with no clump, wandering the sky (`HiveStep.wanderers`): not catchable.
const AIR := 10
const AIR_BOX := Rect2(20.0, 20.0, 600.0, 170.0)
## A bee's chase after its place, a second: the slowest and the quickest. The spread is the
## trail: the quick ones stay on the pointer, the slow ones string out behind.
const CHASE := Vector2(3.0, 12.0)
## A clump in hand draws in to this share of its spread, and its middle eases after the pointer
## this fast. A bee further than `FLYING` from its place is drawn flying, facing the way it goes.
const HELD_TIGHT := 0.85
const HELD_EASE := 22.0
const FLYING := 8.0
## Grab reach round a clump's middle, painted pixels, measured with the height stretched.
const GRAB_REACH := 34.0
## Let go within this of the box's mouth (height stretched), the clump pours in.
const DROP_REACH := Vector2(70.0, 46.0)
## A pouring bee within this of its gap goes in; `MISS` of them veer off back to the air.
const IN_REACH := 3.0
const MISS := 0.12
## A pouring bee dives head first once it is within this of its gap.
const DIVE_FROM := 40.0
## The mouth stays lit this long after the last pouring bee went in.
const LIT_AFTER := 0.4
## Done at this share boxed.
const ENOUGH := 0.8
## Long enough for the shared ending to land.
const PAYOFF_HOLD := 1.7  # A third off (2026-10-23, Richard's QA run: the endings were slow); was 2.6.
## A new frame's crowd drops in from this far up over this long.
const DROP_IN := 10.0
const DROP_TIME := 0.35
## The box's shadow on the lawn: its footprint (the front's width, a step narrower at the back,
## `FOOT_DEPTH` rows deep) swept along the one sun (`Shade.drop`) as if from `SHADE_RISE`
## painted px up; a solid core in the one ink every shadow on land takes, and a checkered
## fringe a pixel round it at `FRINGE_SHARE` of the ink (the mockup's core and fringe).
const FOOT_HALF := 57.0
const FOOT_DEPTH := 26.0
const FOOT_INSET := 10.0
const SHADE_RISE := 30.0
const FRINGE_SHARE := 0.5
## The ring on each clump in the air, round where a press takes it: its pulse (painted px and
## a second), and its dashes turning.
const MARK_BREATHE := 2.5
const MARK_RATE := 2.6
const MARK_TURN := 0.6
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
## The swarm's outline and the soft brown where two bees touch (`look.SW["coin_deep"]`).
const SOFT_LINE := Color(132 / 255.0, 88 / 255.0, 22 / 255.0)

enum Bee { AIR, POUR, IN, BACK }

var _roll := RandomNumberGenerator.new()
## Per bee: its clump, its state, its place, its offset in the clump, its chase, its phase, its
## role in the cloud and its pose there, and the box gap it pours into.
var _clump: PackedInt32Array = []
var _state: PackedInt32Array = []
var _pos: PackedVector2Array = []
var _off: PackedVector2Array = []
var _chase: PackedFloat32Array = []
var _phase: PackedFloat32Array = []
var _was: PackedVector2Array = []
var _role: PackedByteArray = []
var _pose: Array[StringName] = []
var _faces_left: PackedByteArray = []
var _loose: Array[Dictionary] = []
var _gap_of: PackedInt32Array = []
## Per clump: its middle, whether it is still in the air (not poured), and its home.
var _mid: PackedVector2Array = []
var _gone: Array[bool] = []
var _held := -1
var _pointer := Vector2.ZERO
var _in := 0
var _total := 1
var _caught := false
var _caught_age := 0.0
var _was_down := false
var _lit_left := 0.0
var _buzz: AudioStreamPlayer
var _buzz_level := 0.0
var _whoomp: AudioStreamPlayer
var _chime: AudioStreamPlayer
var _held_was := Vector2.ZERO
var _drag_speed := 0.0
## The bar bees' layout, read once; when each frame's crowd first showed (step age).
var _bar_bees: Array = []
var _frame_at: Array[float] = []
## The shadow's runs, laid out once: `[Vector2 start, int long, bool core]`.
var _shade_runs: Array = []
var _group: CanvasGroup
var _swarm: SwarmLayer
var _front: FrontLayer

const ROLE_BACK := 0
const ROLE_MIDDLE := 1
const ROLE_RIM := 2
const ROLE_LOOSE := 3


func _ready() -> void:
	_group = CanvasGroup.new()
	_group.name = &"Swarm"
	_group.fit_margin = 12.0
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/hive_swarm.gdshader")
	mat.set_shader_parameter(&"ink", HiveArt.OUT)
	mat.set_shader_parameter(&"soft", SOFT_LINE)
	_group.material = mat
	add_child(_group)
	_swarm = SwarmLayer.new()
	_swarm.step = self
	_group.add_child(_swarm)
	_front = FrontLayer.new()
	_front.step = self
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_front)
	_front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func begin() -> void:
	super.begin()
	_roll.seed = SEED
	_held = -1
	_in = 0
	_caught = false
	_caught_age = 0.0
	_was_down = false
	_lit_left = 0.0
	_make_players()
	_buzz_level = 0.0
	_mid = PackedVector2Array(HOMES)
	_gone.clear()
	for k in CLUMPS:
		_gone.append(false)
	_bar_bees = HiveArt.data("catch_bar_bees", []) as Array
	_frame_at.clear()
	for k in BARS + 1:
		_frame_at.append(-1.0)
	_frame_at[0] = 0.0
	var clumps: Array = HiveArt.data("catch_clumps", []) as Array
	var count := 0
	for c in CLUMPS:
		count += (clumps[c] as Array).size() if c < clumps.size() else 14
	_total = count
	_clump.resize(count)
	_state.resize(count)
	_pos.resize(count)
	_was.resize(count)
	_off.resize(count)
	_chase.resize(count)
	_phase.resize(count)
	_role.resize(count)
	_faces_left.resize(count)
	_gap_of.resize(count)
	_pose.clear()
	_loose.clear()
	var i := 0
	for c in CLUMPS:
		var members: Array = clumps[c] if c < clumps.size() else []
		var n := members.size() if not members.is_empty() else 14
		for m in n:
			var bee: Dictionary = members[m] if m < members.size() else {}
			_clump[i] = c
			_state[i] = Bee.AIR
			var role := _role_of(String(bee.get("role", "middle")))
			_role[i] = role
			_off[i] = Vector2(float(bee.get("x", _roll.randfn(0.0, 6.0))), float(bee.get("y", _roll.randfn(0.0, 4.0))))
			_pose.append(StringName("worker_" + String(bee.get("pose", "walk"))))
			_faces_left[i] = 1 if bool(bee.get("left", false)) else 0
			_phase[i] = float(bee.get("phase", 0)) * 0.37 + _roll.randf() * TAU
			_loose.append(bee)
			_pos[i] = HOMES[c] + _home_off(i)
			_was[i] = _pos[i]
			_chase[i] = _roll.randf_range(CHASE.x, CHASE.y)
			_gap_of[i] = _roll.randi() % (BARS + 1)
			i += 1
	_lay_shadow()
	wanderers(AIR, AIR_BOX, SEED + 7)


static func _role_of(name: String) -> int:
	match name:
		"back":
			return ROLE_BACK
		"rim":
			return ROLE_RIM
		"loose":
			return ROLE_LOOSE
	return ROLE_MIDDLE


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


## How many frames the bees in the box have settled on, 0..5: a clump's worth a frame.
func frames_taken() -> int:
	return clampi(int(floorf(boxed_share() / ENOUGH * BARS + 0.001)), 0, BARS)


# --- the play -----------------------------------------------------------------------------

func _box_tl() -> Vector2:
	var feet: Vector2 = HiveArt.anchor(&"catchbox_0", &"feet") if HiveArt.knows(&"catchbox_0") else BOX_FEET
	return BOX_FEET_AT - feet


## A point of the box's own picture on the art grid.
func _on_box(name: StringName, fallback: Vector2) -> Vector2:
	if HiveArt.knows(&"catchbox_0"):
		return _box_tl() + HiveArt.anchor(&"catchbox_0", name)
	return _box_tl() + fallback


func _mouth() -> Vector2:
	return _on_box(&"mouth", BOX_MOUTH)


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


## Where a pouring bee is headed: the top of its gap between the frames, a pixel either way.
func _gap_target(b: int) -> Vector2:
	var g := _gap_of[b]
	var at := _on_box(StringName("gap%d_t" % g), BOX_MOUTH + Vector2((g - 2.5) * 18.0, -9.0))
	return at + Vector2(sin(_phase[b] * 3.0), 3.0)


func _pour(c: int) -> void:
	_gone[c] = true
	_lit_left = LIT_AFTER
	for b in _pos.size():
		if _clump[b] != c or _state[b] == Bee.IN:
			continue
		_state[b] = Bee.POUR


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
	_role[b] = ROLE_RIM
	_pose[b] = &"worker_hover"
	_off[b] = Vector2(_roll.randfn(0.0, 7.0), _roll.randfn(0.0, 5.0))


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
	payoff(_mouth() + Vector2(0.0, -4.0), 90.0)
	HiveStep.sound(&"hive_crown")


## Bee `b`'s place in its clump this moment, from the clump's middle: a loose one circles it,
## the rest keep their spot in the cloud breathing and jittering, a rim bee now and then strays.
func _home_off(b: int) -> Vector2:
	if _role[b] == ROLE_LOOSE:
		var bee: Dictionary = _loose[b]
		var a := float(bee.get("a0", 0.0)) + age * ORBIT * float(bee.get("spin", 1))
		var rr := float(bee.get("rr", 1.4))
		return Vector2(cos(a) * float(bee.get("rx", 20.0)) * rr, sin(a) * float(bee.get("ry", 15.0)) * rr)
	return _off[b]


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
	var pouring := false
	for b in _pos.size():
		_was[b] = _pos[b]
		var s := _state[b]
		if s == Bee.IN:
			continue
		var c := _clump[b]
		var target: Vector2
		if s == Bee.POUR:
			pouring = true
			target = _gap_target(b)
		else:
			var tight := HELD_TIGHT if c == _held else 1.0 + BREATHE * sin(age * 1.3 + c)
			var ph := _phase[b]
			var jitter := Vector2(sin(age * (2.4 + fmod(ph, 1.3)) + ph), cos(age * (1.9 + fmod(ph, 1.1)) + ph * 1.7)) * JITTER
			target = _mid[c] + _home_off(b) * tight + jitter
			if c != _held and s == Bee.AIR and _role[b] == ROLE_RIM:
				target += _stray(b)
		_pos[b] = _pos[b].lerp(target, 1.0 - exp(-_chase[b] * delta))
		if s == Bee.BACK and _pos[b].distance_to(target) < 6.0:
			_state[b] = Bee.AIR
		elif s == Bee.POUR and _pos[b].distance_to(target) < IN_REACH:
			if not _caught and _roll.randf() < MISS:
				_send_back(b)
			else:
				_land(b)
	if pouring:
		_lit_left = LIT_AFTER
	else:
		_lit_left = maxf(_lit_left - delta, 0.0)
	_check_enough()
	# A frame's crowd drops in the first time the count reaches it.
	var taken := frames_taken()
	for k in range(1, taken + 1):
		if _frame_at[k] < 0.0:
			_frame_at[k] = age
	_drive_buzz(delta)
	if _caught:
		_caught_age += delta
		if _caught_age >= PAYOFF_HOLD:
			done_once()
	if _swarm != null:
		_swarm.queue_redraw()
		_front.queue_redraw()
		var scale := (get_viewport().get_final_transform() * get_global_transform_with_canvas()).get_scale()
		(_group.material as ShaderMaterial).set_shader_parameter(&"art_px", absf(scale.x) * HiveArt.PIXEL)


func pad_mark() -> Rect2:
	return Rect2()


## Bee `b`'s loop out of its clump this moment: nothing most of the time, then out along its
## own heading to `STRAY` and back, eased at both ends.
func _stray(b: int) -> Vector2:
	var ph := _phase[b]
	var h := fposmod(ph * 7.31, 1.0)
	var p := fposmod(age / (5.0 + 7.0 * h) + h * 3.7, 1.0)
	var peel := sin(clampf((p - 0.78) / 0.22, 0.0, 1.0) * PI)
	if peel <= 0.0:
		return Vector2.ZERO
	var turn := ph * 3.0 + sin(age * 2.0 + ph) * 0.8
	return Vector2(cos(turn), sin(turn) * 0.6) * STRAY * (0.5 + 0.5 * h) * peel


# --- drawing ------------------------------------------------------------------------------

## Whether the mouth is lit: a clump in hand over it, or one pouring in.
func _lit() -> bool:
	return (_held >= 0 and _over_mouth(_pointer)) or _lit_left > 0.0


func _draw() -> void:
	_draw_shadow()
	var tl := _box_tl()
	var lit := _lit()
	var piece := &"catchbox_lit" if lit else StringName("catchbox_%d" % (0 if _caught else frames_taken()))
	if _caught:
		piece = StringName("catchbox_%d" % BARS)
	if HiveArt.has(piece):
		HiveArt.draw(self, piece, to_canvas(tl))
	else:
		draw_rect(Rect2(to_canvas(tl + Vector2(36.0, 48.0)), Vector2(114.0, 67.0) * HiveArt.PIXEL), Color(0.6, 0.75, 0.9))
	_draw_bar_bees(tl)
	_draw_board(lit)
	draw_wanderers()


## The bees on the frames: each crowd shows from the count of frames it needs, dropping in the
## first time; the far end of a bar in the box's shade; one half down a gap, its tail out.
func _draw_bar_bees(tl: Vector2) -> void:
	var taken := BARS if _caught else frames_taken()
	for bee: Dictionary in _bar_bees:
		var need := int(bee.get("from", 1))
		if need > taken:
			continue
		var at := tl + Vector2(float(bee["x"]), float(bee["y"]))
		var since := age - _frame_at[clampi(need, 0, BARS)] if _frame_at[clampi(need, 0, BARS)] >= 0.0 else DROP_TIME
		var drop := clampf(since / DROP_TIME, 0.0, 1.0)
		var left := bool(bee.get("left", false))
		var turn := int(bee.get("turn", 0))
		var ph := float(bee.get("frame", 0)) * 0.41
		var tint := BACK_TINT if bool(bee.get("shade", false)) else Color.WHITE
		if drop < 1.0:
			var e := 1.0 - pow(1.0 - drop, 3.0)
			bee_at(self, BeeArt.frame_name(&"worker_hover", BeeArt.frame_at(&"worker_hover", age + ph)),
				at - Vector2(0.0, DROP_IN * (1.0 - e)), left, 0, tint)
			continue
		var anim := StringName("worker_" + String(bee.get("pose", "walk")))
		var name := BeeArt.frame_name(anim, BeeArt.frame_at(anim, age + ph))
		if bool(bee.get("half", false)):
			_bee_half(name, at, left, turn)
		else:
			bee_at(self, name, at, left, turn, tint)


## The landing board: a guard walking it, or, while the mouth is lit, two bees fanning on it,
## tails to the entrance, wings a blur: the scent that tells a swarm where home is.
func _draw_board(lit: bool) -> void:
	var board := _on_box(&"board", BOX_BOARD)
	if lit:
		for j in 2:
			var dx := -12.0 if j == 0 else 12.0
			bee_at(self, BeeArt.frame_name(&"worker_hover", BeeArt.frame_at(&"worker_hover", age * 1.6 + j * 0.05)),
				board + Vector2(dx, -6.0), j == 0)
		return
	var stroll := sin(age * 0.5) * 7.0
	var left := cos(age * 0.5) < 0.0
	bee_at(self, BeeArt.frame_name(&"worker_walk", BeeArt.frame_at(&"worker_walk", age)),
		board + Vector2(-6.0 + stroll, -6.0), left)


## A bee half down a gap: only the end still out is drawn (the top half on screen), the rest is
## gone into the dark between the frames.
func _bee_half(name: StringName, p: Vector2, left: bool, turn: int) -> void:
	var sheet := BeeArt.sheet()
	if sheet == null or not BeeArt.has(name):
		return
	var cut := BeeArt.region(name)
	var scale := HiveArt.PIXEL
	var at := to_canvas(p.floor())
	var mark := BeeArt.anchor(name, left)
	var box := Rect2(at - mark * scale, cut.size * scale)
	var whole := sheet.get_size()
	var u0 := cut.position.x / whole.x
	var u1 := cut.end.x / whole.x
	var v0 := cut.position.y / whole.y
	var v1 := cut.end.y / whole.y
	var ul := u1 if left else u0
	var ur := u0 if left else u1
	# Which side of the unturned picture ends up on top of the screen after the turn.
	var keep_left := posmod(turn, 4) == 3
	var split := at.x + scale * 0.5
	var share := clampf((split - box.position.x) / box.size.x, 0.0, 1.0)
	var um := lerpf(ul, ur, share)
	var x0 := box.position.x if keep_left else split
	var x1 := split if keep_left else box.end.x
	var ua := ul if keep_left else um
	var ub := um if keep_left else ur
	var corners := [Vector2(x0, box.position.y), Vector2(x1, box.position.y), Vector2(x1, box.end.y), Vector2(x0, box.end.y)]
	var points := PackedVector2Array()
	for corner: Vector2 in corners:
		points.append(at + BeeArt._turned(corner - at, turn))
	draw_primitive(points, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]),
		PackedVector2Array([Vector2(ua, v0), Vector2(ub, v0), Vector2(ub, v1), Vector2(ua, v1)]), sheet)


## The swarm, on the CanvasGroup the outline shader reads: every bee not yet in the box, the
## clouds back to front, a bee far off its place flying the way it goes, a pouring bee diving
## head first between the frames.
func _draw_swarm(ci: CanvasItem) -> void:
	var order := range(_pos.size())
	order.sort_custom(func(a: int, b: int) -> bool: return _pos[a].y < _pos[b].y)
	for b: int in order:
		var s := _state[b]
		if s == Bee.IN:
			continue
		var move := _pos[b] - _was[b]
		var c := _clump[b]
		var ph := _phase[b]
		var place := _gap_target(b) if s == Bee.POUR else _mid[c] + _home_off(b)
		var far := _pos[b].distance_to(place)
		if s == Bee.POUR and far < DIVE_FROM:
			# Head first: hovering wings, turned so the head points down the screen.
			var left := _pos[b].x > _mouth().x
			var name := BeeArt.frame_name(&"worker_hover", BeeArt.frame_at(&"worker_hover", age + ph))
			var tint := Color(0.75, 0.72, 0.7) if far < 6.0 else Color.WHITE
			bee_at(ci, name, _pos[b], left, 1 if left else 3, tint)
			continue
		if s != Bee.AIR or c == _held or far > FLYING or _role[b] == ROLE_LOOSE:
			var going_left := move.x < -0.01 or (absf(move.x) <= 0.01 and _faces_left[b] == 1)
			var fly := BeeArt.frame_name(&"worker_fly", BeeArt.frame_at(&"worker_fly", age + ph))
			bee_at(ci, fly, _pos[b], going_left)
			continue
		var anim := _pose[b]
		var name := BeeArt.frame_name(anim, BeeArt.frame_at(anim, age + ph))
		var tint := BACK_TINT if _role[b] == ROLE_BACK else Color.WHITE
		bee_at(ci, name, _pos[b], _faces_left[b] == 1, 0, tint)


## The shadow under the box, laid out once: the footprint swept along the sun, a solid core
## and a checkered fringe round it.
func _lay_shadow() -> void:
	_shade_runs.clear()
	var feet := BOX_FEET_AT
	var fy := feet.y
	var foot := [
		Vector2(feet.x - FOOT_HALF, fy + 1.0), Vector2(feet.x + FOOT_HALF - 1.0, fy + 1.0),
		Vector2(feet.x + FOOT_HALF - 1.0 - FOOT_INSET, fy - FOOT_DEPTH),
		Vector2(feet.x - FOOT_HALF + FOOT_INSET, fy - FOOT_DEPTH),
	]
	var run := Shade.drop(null, SHADE_RISE).round()
	var pts := PackedVector2Array()
	for p: Vector2 in foot:
		pts.append(p)
		pts.append(p + run)
	var hull := Geometry2D.convex_hull(pts)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in hull:
		lo = lo.min(p)
		hi = hi.max(p)
	var core := {}
	for y in range(floori(lo.y) - 1, ceili(hi.y) + 2):
		for x in range(floori(lo.x) - 1, ceili(hi.x) + 2):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), hull):
				core[Vector2i(x, y)] = true
	var fringe := {}
	for cell: Vector2i in core:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + d
			if not core.has(n) and (n.x + n.y) % 2 == 0:
				fringe[n] = true
	for cell: Vector2i in core:
		_shade_runs.append([Vector2(cell), true])
	for cell: Vector2i in fringe:
		_shade_runs.append([Vector2(cell), false])


func _draw_shadow() -> void:
	var ink := Shade.tint_on(null, Shade.On.LAND)
	var soft := Color(ink, ink.a * FRINGE_SHARE)
	for run: Array in _shade_runs:
		draw_rect(Rect2(to_canvas(run[0]), Vector2.ONE * HiveArt.PIXEL), ink if run[1] else soft)


## The ring round each clump still in the air: dashes on an ellipse round where a press takes
## it, turning slowly and breathing in and out, a dark pixel under each so it reads on the sky.
## Not on the clump in hand, and none once the swarm is caught.
func _draw_marks(ci: CanvasItem) -> void:
	if _caught:
		return
	for c in CLUMPS:
		if _gone[c] or c == _held:
			continue
		var breathe := sin(age * MARK_RATE + c * 1.3) * MARK_BREATHE
		var half := Vector2(GRAB_REACH + breathe, (GRAB_REACH + breathe) / 1.6)
		var steps := int(half.x * 2.4)
		var turn := age * MARK_TURN + c
		var glow := 0.55 + 0.2 * sin(age * MARK_RATE * 1.3 + c)
		for s in steps:
			var u := float(s) / steps
			if fmod(u * 16.0 + turn, 2.0) > 1.1:
				continue
			var ang := TAU * u
			var p := (_mid[c] + Vector2(cos(ang) * half.x, sin(ang) * half.y)).floor()
			ci.draw_rect(Rect2(to_canvas(p + Vector2(0.0, 1.0)), Vector2.ONE * HiveArt.PIXEL), Color(HiveArt.OUT, 0.3 * glow))
			ci.draw_rect(Rect2(to_canvas(p), Vector2.ONE * HiveArt.PIXEL), Color(HiveArt.HONEY_SHINE, glow))


## What the layer over the swarm draws: the rings and the shared ending.
func _draw_front(ci: CanvasItem) -> void:
	_draw_marks(ci)
	draw_payoff(ci)


## The swarm's drawing, inside the CanvasGroup the outline shader reads.
class SwarmLayer:
	extends Node2D

	var step: HiveStepCatch

	func _draw() -> void:
		if step != null:
			step._draw_swarm(self)


## Over the swarm: the rings round the clumps and the shared ending.
class FrontLayer:
	extends Control

	var step: HiveStepCatch

	func _draw() -> void:
		if step != null:
			step._draw_front(self)
