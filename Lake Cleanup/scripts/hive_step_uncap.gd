## The harvest's first step: the hot knife slid down the honey frame, the honey running off
## the cut into a gutter and off it into the bucket (2026-09-30, the beehive; the second pass,
## Richard, off `tools/hive_mockup2.py` `room_uncap`).
##
## **No hands.** The frame stands upright in the pine uncapping rest; the knife follows the
## pointer down the comb. **The step Richard singled out: it must be smooth and very
## satisfying.** So nothing in it snaps but the one thing that should. The knife glides after
## the pointer on an exponential ease (`EASE`) held under a top speed (`MOST_SPEED`) and only
## goes down; the wax it lifts rolls up on the blade and thickens as it goes; **the cut line
## snaps to the comb's rows**, each popping open whole with a flash, a glint, a crumb of wax off
## the blade and a crackle.
##
## **The honey is the payoff** (`_drive_honey` and below): it runs off the cut as glossy
## curtains into a thin tin gutter slung on a slant under the frame, rides down it thicker than
## the tin, bulging over the rim and spilling over the lip in places, and falls off the low end
## as a heavy rope — fat, necking, a bead swelling until it lets go, a thread springing back —
## into the bucket, where it folds into coils and the level rises. **The level is kept**: the
## pour step's bucket starts where this one ends (`HiveRoom.honey`).
##
## **The reveal is two pictures, not a mask**: `frame_open` drawn whole and `frame_capped`
## only from the cut row down (`HiveArt.draw_region`). **One face**, not two: the frame's turn
## is gone with the gloves.
##
## **The pad**: the stick pushed down draws the knife, and RT or A held glides it down at a
## steady pace (`GLIDE_PACE`).
##
## **Harness hooks, never gated on `awake`**: `cut_to(share)`, `faces_done()`,
## `bucket_level()`, `honey_left()`, `sizzle_player()` and `settle()` (the face cut, every drop
## in the bucket, `finished` at once).
class_name HiveStepUncap
extends HiveStep

enum Phase { CUT, FACE_DONE, FLIP, SWEEP, DONE }

## Where the frame's top left stands on the art grid: the mockup's own place for it
## (`RW // 2 - frame.width // 2 - 16`, 44), a little left of centre so the knife's handle and
## the glove on it stand clear of the right edge.
const FRAME_AT := Vector2(157.0, 38.0)

## The knife's ease after the pointer, a second (the contract's 18), and the most it may move
## in a second, painted pixels. The cap is what keeps a flung pointer a stroke rather than a
## jump: a face is 165 px, so no face is over in less than a second and a bit.
const EASE := 18.0
const MOST_SPEED := 150.0
## The pad: how far a full push of the stick draws the knife in a second, and the steady
## glide RT or A held gives on its own. Both painted pixels a second.
const PAD_PACE := 120.0
const GLIDE_PACE := 72.0
## The least push of the stick that counts, so a stick resting off centre does not creep.
const PAD_DEAD := 0.15

## A face done: the beat before the frame turns (the sheet drops in it), the turn itself, how
## high the frame lifts at the middle of the turn, and how dark it is edge on.
const FACE_BEAT := 0.3
const FLIP_TIME := 0.35
const FLIP_LIFT := 4.0
const FLIP_SHADE := Color(0.72, 0.64, 0.56)
## After the turn and after the last sweep: the frame settles with a small wobble, this long
## and this deep (painted pixels).
const SETTLE_TIME := 0.6
const SETTLE_DROP := 3.0
## How long the knife takes to come back in on the second face, and to go on the way out.
const KNIFE_IN := 0.22
const KNIFE_OUT := 0.2

## The payoff: a golden sweep of stars down the open comb, then a hold before `finished`.
const SWEEP_TIME := 0.9
const SWEEP_HOLD := 0.6
## After the sweep, the honey still running is waited on at most this long.
const DRAIN_WAIT := 6.0
const SWEEP_STARS := 3
const BURST_STARS := 14

## A row popping: its flash, the stars on it, and the most stars alive at once (a harness
## cutting a whole face in one call pops two dozen rows in a frame).
const FLASH_LIFE := 0.35
const STAR_LIFE := 0.5
const STARS_PER_ROW := 2
const STARS_MOST := 96

## The rolled wax sheet riding the blade: its thickness once the first row is cut and once the
## face is (painted pixels), how quickly it catches up, the swell each popped row gives it, and
## how far short of the blade's end it stops, towards the handle.
const SHEET_BASE := 2.0
const SHEET_MOST := 13.0
const SHEET_EASE := 9.0
const SHEET_SWELL := 0.9
const SHEET_SWELL_MOST := 2.5
const SHEET_TRIM := 36
## How much the sheet's waves turn over per painted pixel the knife travels: the wax rolling.
const SHEET_ROLL := 0.09

## Honey hanging off the hot edge: where along the blade each run hangs (shares of its
## length), how long a run gets before its bead lets go, and how fast it grows.
const DRIP_SLOTS := [0.12, 0.26, 0.41, 0.55, 0.69, 0.83]
const DRIP_LONG := Vector2(6.0, 22.0)
const DRIP_GROW := Vector2(5.0, 12.0)
## Runs down the open face above the knife: the odds a popped row starts one, how many a face
## holds, how long and how fast.
const RUN_ODDS := 0.35
const RUNS_MOST := 10
const RUN_LONG := Vector2(5.0, 16.0)
const RUN_GROW := Vector2(2.5, 6.0)
## Everything that falls — beads, crumbs, the sheet — falls at this, painted pixels a second
## squared.
const FALL := 420.0
## The crumbs of wax a heap is made of, and the most the tray holds before a crumb is lost.
const CRUMBS_FLYING_MOST := 14
const HEAP_MOST := 90
## The sheet landing in the tray: how long it takes to flatten into the heap, and how many
## bits it leaves there.
const SQUASH_TIME := 0.22
const SHEET_BITS := 16

## The capping tray under the frame, the mockup's: `TRAY_GAP` under the frame's foot, in from
## its left edge by `TRAY_INSET`, and the honey pool in it rising with what has been cut.
const TRAY_GAP := 14.0
const TRAY_INSET := 22.0
const TRAY_WIDE := 294.0
const TRAY_TALL := 16.0
const POOL_LEAST := 2.0
const POOL_MOST := 6.0

## The sizzle: its loudest (dB over its own balance), the knife speed at which it is full
## (painted pixels a second), the simmer while the tool is only held on the wax, and how fast
## it comes and goes. The contract's `move_toward`, the wash hiss's own 0.06 s.
const SIZZLE_DB := -13.0
const SIZZLE_FULL := 90.0
const SIZZLE_SIMMER := 0.22
const SIZZLE_ATTACK := 0.06

## The glide: faint copies of the blade where it was this many seconds ago, at these alphas.
const GHOSTS := [0.04, 0.08, 0.12]
const GHOST_ALPHA := [0.43, 0.27, 0.15]
const TRAIL_KEEP := 0.2
## Heat shimmer under the blade, re-rolled this many times a second (the lake's stepped clock).
const SHIMMER_FPS := 10.0
const SHIMMER_DOTS := 46
## A glint runs along the blade's top edge this often while it waits, three times as often
## while it is held.
const GLINT_EVERY := 2.2
## Bees drifting over the frame, for the honey.
const BEES := 5

## The builder's steel and the hot edge (`tools/build_hive.py` `STEEL`, the knife's line).
const STEEL_HI := Color(240 / 255.0, 246 / 255.0, 250 / 255.0)
const STEEL_LIT := Color(214 / 255.0, 224 / 255.0, 232 / 255.0)
const STEEL_BASE := Color(172 / 255.0, 186 / 255.0, 198 / 255.0)
const STEEL_SHADE := Color(126 / 255.0, 140 / 255.0, 156 / 255.0)
const HOT := Color(255 / 255.0, 150 / 255.0, 96 / 255.0)
const HOT_EDGE := Color(255 / 255.0, 120 / 255.0, 60 / 255.0)
## The gloss along the sheet's crown, `wax_sheet`'s own.
const GLOSS := Color(255 / 255.0, 253 / 255.0, 240 / 255.0)

## What the json says, for a harness run before an import: the builder's numbers.
const INNER_FALLBACK := Rect2(20.0, 10.0, 286.0, 165.0)
const PITCH_FALLBACK := 7.0
const FRAME_FALLBACK := Vector2(326.0, 182.0)
const BLADE_L_FALLBACK := Vector2(6.0, 4.0)
const BLADE_R_FALLBACK := Vector2(292.0, 4.0)
const HANDLE_FALLBACK := Vector2(318.0, 7.0)
const EAR_L_FALLBACK := Vector2(9.0, 5.0)
## The blade's rows under its top edge: its foot (the hot line) and where honey hangs from.
const BLADE_TALL := 6.0

## Every roll in the step comes off this, set again at `begin`: a harness sees what a player
## sees.
const SEED := 6301

var _phase := Phase.CUT
var _face := 0
var _faces_done := 0
## Rows open on the face in hand, the rows a face has, and the rows cut over both faces.
var _rows := 0
var _rows_total := 24
var _rows_cut_all := 0
## The blade's top edge on the art grid (painted pixels), where the hand wants it, and how fast
## it is going.
var _knife := 0.0
var _want := 0.0
var _speed := 0.0
var _clock := 0.0
var _need_release := false
var _was_down := false
var _grip := 0.0
var _knife_alpha := 1.0
var _sizzle_kick := 0.0
var _glint_at := 0.0
## The sheet: its thickness, where it is going, the swell off the last rows, and its roll.
var _thick := 0.0
var _swell := 0.0
var _roll_phase := 0.0
## The frame's lift (painted pixels, up is negative) and the settle's clock (negative: none).
var _bob := 0.0
var _settle := -1.0
var _sweep_rows := 0
var _burst_done := false
var _pool := POOL_LEAST
var _pool_bonus := 0.0

## Geometry, on the art grid. `_inner` is the comb, absolute.
var _laid := false
var _inner := Rect2()
var _pitch := PITCH_FALLBACK
var _frame := FRAME_FALLBACK
var _blade_l := BLADE_L_FALLBACK
var _blade_len := 286.0
var _handle := HANDLE_FALLBACK
var _ear_l := EAR_L_FALLBACK
var _tray := Rect2()

var _stars: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _drips: Array[Dictionary] = []
var _beads: Array[Dictionary] = []
var _runs: Array[Dictionary] = []
var _crumbs: Array[Dictionary] = []
var _heap: Array[Dictionary] = []
var _bees: Array[Dictionary] = []
var _trail: Array[Vector2] = []
## The sheet on its way down to the tray, or empty.
var _drop := {}

var _sizzle: AudioStreamPlayer = null
var _sizzle_level := 0.0
var _roll := RandomNumberGenerator.new()


func _ready() -> void:
	_make_sizzle()
	if not _laid:
		_lay()
		_reset()


func begin() -> void:
	super.begin()
	_lay()
	_reset()


# --- The harness's hooks ------------------------------------------------------------------

## Cut the face in hand at least `share` (0..1) of the way down, at once: the knife is put
## there, every row it passes pops, and a whole face turns the frame over (or, on the second,
## starts the golden sweep). A share under what is cut does nothing. Called while the frame is
## turning, the turn is finished first, so two calls of 1.0 cut both faces. Not gated on
## `awake()`. Returns the rows open on the face in hand afterwards.
func cut_to(share: float) -> int:
	if not _laid:
		_lay()
		_reset()
	if _phase == Phase.FACE_DONE or _phase == Phase.FLIP:
		_turn_now()
	if _phase != Phase.CUT:
		return _rows
	var y := _inner.position.y + clampf(share, 0.0, 1.0) * _inner.size.y
	_want = maxf(_want, y)
	_knife = maxf(_knife, y)
	_need_release = false
	_follow_rows()
	return _rows


## Cut the face through, land every drop in the bucket and say `finished` at once.
func settle() -> void:
	cut_to(1.0)
	_drain_all()
	_phase = Phase.DONE
	done_once()


## Which face is being cut: 0, then 1 once the frame has turned over.
func face() -> int:
	return _face


## How many faces are cut through: 0, 1 or 2.
func faces_done() -> int:
	return _faces_done



## The knife's own sizzle player, for the harness (it must be on SFX). Null with no stream.
func sizzle_player() -> AudioStreamPlayer:
	return _sizzle


# --- Laying it out ------------------------------------------------------------------------

func _lay() -> void:
	_laid = true
	var comb := HiveArt.comb()
	var inner_local := INNER_FALLBACK
	if not comb.is_empty():
		inner_local = comb["inner"]
		_pitch = maxf((comb["pitch"] as Vector2).y, 1.0)
	if HiveArt.knows(&"frame_capped"):
		_frame = HiveArt.size(&"frame_capped")
		_ear_l = HiveArt.anchor(&"frame_capped", &"ear_l")
	_inner = Rect2(FRAME_AT + inner_local.position, inner_local.size)
	# Every row down to the comb's foot, the last one clipped by it: 165 over 7 is 23 whole
	# rows and four pixels of a twenty-fourth, and that last sliver is capped too.
	_rows_total = ceili(_inner.size.y / _pitch)
	var blade_r := BLADE_R_FALLBACK
	if HiveArt.knows(&"knife"):
		_blade_l = HiveArt.anchor(&"knife", &"blade_l")
		blade_r = HiveArt.anchor(&"knife", &"blade_r")
		_handle = HiveArt.anchor(&"knife", &"handle")
	_blade_len = maxf(blade_r.x - _blade_l.x, 1.0)
	_tray = Rect2(
		FRAME_AT + Vector2(TRAY_INSET, _frame.y + TRAY_GAP), Vector2(TRAY_WIDE, TRAY_TALL)
	)


func _reset() -> void:
	_roll.seed = SEED
	_lay_honey()
	_phase = Phase.CUT
	_face = 0
	_faces_done = 0
	_rows = 0
	_rows_cut_all = 0
	_knife = _inner.position.y
	_want = _knife
	_speed = 0.0
	_clock = 0.0
	_need_release = false
	_was_down = false
	_grip = 0.0
	_knife_alpha = 1.0
	_sizzle_kick = 0.0
	_glint_at = 0.0
	_thick = 0.0
	_swell = 0.0
	_roll_phase = 0.0
	_bob = 0.0
	_settle = -1.0
	_sweep_rows = 0
	_burst_done = false
	_pool = POOL_LEAST
	_pool_bonus = 0.0
	_stars.clear()
	_flashes.clear()
	_beads.clear()
	_runs.clear()
	_crumbs.clear()
	_heap.clear()
	_trail.clear()
	_drop = {}
	_drips.clear()
	for slot: float in DRIP_SLOTS:
		_drips.append(_new_drip(slot))
	_bees.clear()
	for k in BEES:
		_bees.append({
			"home": Vector2(
				_roll.randf_range(FRAME_AT.x + 30.0, FRAME_AT.x + _frame.x - 30.0),
				_roll.randf_range(FRAME_AT.y - 6.0, FRAME_AT.y + 8.0)
			),
			"w1": _roll.randf_range(0.9, 1.6), "w2": _roll.randf_range(1.7, 2.8),
			"r1": _roll.randf_range(14.0, 30.0), "r2": _roll.randf_range(4.0, 9.0),
			"p1": _roll.randf() * TAU, "p2": _roll.randf() * TAU,
		})


func _new_drip(slot: float) -> Dictionary:
	return {
		"slot": slot + _roll.randf_range(-0.03, 0.03),
		"len": _roll.randf_range(0.0, 3.0),
		"most": _roll.randf_range(DRIP_LONG.x, DRIP_LONG.y),
		"grow": _roll.randf_range(DRIP_GROW.x, DRIP_GROW.y),
	}


# --- Each frame ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _laid or delta <= 0.0:
		return
	var down := tool_down()
	match _phase:
		Phase.CUT:
			_drive_hand(delta, down)
			_drive_knife(delta)
			_knife_alpha = minf(_knife_alpha + delta / KNIFE_IN, 1.0)
		Phase.FACE_DONE:
			_clock += delta
			_knife_alpha = maxf(_knife_alpha - delta / KNIFE_OUT, 0.0)
			if _clock >= FACE_BEAT:
				_phase = Phase.FLIP
				_clock = 0.0
				_say(&"hive_puff", -6.0)
		Phase.FLIP:
			_clock += delta
			_knife_alpha = 0.0
			var t := clampf(_clock / FLIP_TIME, 0.0, 1.0)
			_bob = -FLIP_LIFT * sin(PI * t)
			if _face == 0 and _clock >= FLIP_TIME * 0.5:
				_swap_face()
			if _clock >= FLIP_TIME:
				_phase = Phase.CUT
				_clock = 0.0
				_bob = 0.0
				_settle = 0.0
		Phase.SWEEP:
			_clock += delta
			_knife_alpha = maxf(_knife_alpha - delta / KNIFE_OUT, 0.0)
			_drive_sweep()
			# Done once the sweep has run and nearly all the honey is in the bucket, or a
			# while after, whichever is first: the last drips are not waited on.
			var dry := honey_left() < _total * 0.06
			if _clock >= SWEEP_TIME + SWEEP_HOLD and (dry or _clock >= SWEEP_TIME + DRAIN_WAIT):
				_phase = Phase.DONE
				done_once()
		Phase.DONE:
			_knife_alpha = maxf(_knife_alpha - delta / KNIFE_OUT, 0.0)
	_was_down = down
	_drive_settle(delta)
	_drive_honey(delta)
	_drive_sheet(delta)
	_drive_bits(delta)
	_drive_sizzle(delta, down)
	_trail.append(Vector2(age, _knife))
	while _trail.size() > 1 and age - _trail[0].x > TRAIL_KEEP:
		_trail.remove_at(0)


## The player's hand on the knife: only once the step is awake, and on a new face only once
## the press that finished the last one has been let go.
func _drive_hand(delta: float, down: bool) -> void:
	if not awake():
		return
	var pad := Pad.is_pad()
	var push := 0.0
	if pad:
		push = Input.get_vector(&"walk_left", &"walk_right", &"walk_up", &"walk_down").y
	if _need_release:
		if not down and push <= PAD_DEAD:
			_need_release = false
		return
	if down and not _was_down:
		# Every press answers: the blade lifts a pixel, a glint runs off its tip, and it hisses
		# once on the wax — whether or not the pointer is anywhere it can go.
		_grip = 1.0
		_sizzle_kick = 0.6
		_glint_at = age
		_add_star(Vector2(_inner.position.x + 2.0, _knife + 1.0), 2, 0.0, STAR_LIFE * 0.8)
	var bottom := _inner.end.y
	if pad:
		if push > PAD_DEAD:
			_want += push * PAD_PACE * delta
		if down:
			_want += GLIDE_PACE * delta
	elif down:
		_want = maxf(_want, art_mouse().y)
	_want = clampf(_want, _inner.position.y, bottom)


## The knife after the hand: the exponential ease, under the top speed, down only.
func _drive_knife(delta: float) -> void:
	var gap := _want - _knife
	var step := 0.0
	if gap > 0.0:
		step = minf(gap * (1.0 - exp(-EASE * delta)), MOST_SPEED * delta)
		if gap < 0.02:
			step = gap
	_knife += step
	_roll_phase += step * SHEET_ROLL
	_speed = lerpf(_speed, step / delta, 1.0 - exp(-20.0 * delta))
	_follow_rows()


## Pop every row the blade has passed the middle of, and finish the face at its foot. The cut
## line sits at most half a row above the blade's top edge, under the sheet riding it.
func _follow_rows() -> void:
	var n := mini(int(floorf((_knife - _inner.position.y) / _pitch + 0.5)), _rows_total)
	var at_foot := _knife >= _inner.end.y - 0.01
	if at_foot:
		n = _rows_total
	if n > _rows:
		var from := _rows
		_rows = n
		for r in range(from, n):
			_pop_row(r)
		_say(&"hive_crackle")
	if at_foot and _phase == Phase.CUT:
		_face_done()


func _pop_row(r: int) -> void:
	_rows_cut_all += 1
	_row_honey()
	var y := _inner.position.y + r * _pitch
	_flashes.append({"row": r, "age": 0.0, "gold": false})
	for k in STARS_PER_ROW:
		_add_star(
			Vector2(
				_roll.randf_range(_inner.position.x + 6.0, _inner.end.x - 6.0),
				y + _roll.randf_range(1.0, _pitch)
			),
			1 + _roll.randi() % 3, -_roll.randf_range(0.0, 0.12), STAR_LIFE
		)
	_swell = minf(_swell + SHEET_SWELL, SHEET_SWELL_MOST)
	if _crumbs.size() < CRUMBS_FLYING_MOST:
		_crumbs.append({
			"at": Vector2(
				_inner.position.x + _roll.randf() * _blade_len, floorf(_knife) - 2.0
			),
			"v": Vector2(_roll.randf_range(-25.0, 25.0), -_roll.randf_range(20.0, 70.0)),
			"w": 2.0 + float(_roll.randi() % 2), "h": 1.0 + float(_roll.randi() % 2),
			"lit": _roll.randf() < 0.6,
		})
	if _runs.size() < RUNS_MOST and r > 0 and _roll.randf() < RUN_ODDS:
		var top := y + 2.0
		_runs.append({
			"at": Vector2(
				floorf(_roll.randf_range(_inner.position.x + 8.0, _inner.end.x - 8.0)), top
			),
			"len": 0.0,
			"most": minf(_roll.randf_range(RUN_LONG.x, RUN_LONG.y), maxf(_knife - top - 3.0, 1.0)),
			"grow": _roll.randf_range(RUN_GROW.x, RUN_GROW.y),
		})


func _face_done() -> void:
	_knife = _inner.end.y
	_want = _knife
	_faces_done = mini(_faces_done + 1, 2)
	var foot := _inner.end.y - _pitch * 0.5
	for k in 6:
		_add_star(
			Vector2(lerpf(_inner.position.x + 10.0, _inner.end.x - 10.0, (k + 0.5) / 6.0), foot),
			2 + k % 2, -k * 0.04, STAR_LIFE
		)
	_start_drop()
	_clock = 0.0
	# One face: the cut's foot starts the golden sweep, and the honey runs on under it.
	_phase = Phase.SWEEP
	_sweep_rows = 0
	_burst_done = false
	_say(&"hive_crown")


## The frame turns over to its second face, capped again, and the knife goes back to the top.
func _swap_face() -> void:
	_face = 1
	_rows = 0
	_knife = _inner.position.y
	_want = _knife
	_speed = 0.0
	_runs.clear()
	_flashes.clear()
	_thick = 0.0
	_swell = 0.0
	for drip: Dictionary in _drips:
		drip["len"] = 0.0
	_need_release = true
	_knife_alpha = 0.0
	_trail.clear()


## For a harness asking to cut while the frame turns: finish the turn at once.
func _turn_now() -> void:
	if _face == 0:
		_swap_face()
	_phase = Phase.CUT
	_clock = 0.0
	_bob = 0.0
	_settle = -1.0
	_need_release = false


## The golden sweep: a line of gold running down the open comb, eased out, starring each row
## as it passes; at its foot a burst round the frame and the settle.
func _drive_sweep() -> void:
	var t := clampf(_clock / SWEEP_TIME, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var line := _inner.position.y + eased * _inner.size.y
	while _sweep_rows < _rows_total and line >= _inner.position.y + (_sweep_rows + 1) * _pitch - 0.01:
		var y := _inner.position.y + _sweep_rows * _pitch
		_flashes.append({"row": _sweep_rows, "age": 0.0, "gold": true})
		for k in SWEEP_STARS:
			_add_star(
				Vector2(
					_roll.randf_range(_inner.position.x + 4.0, _inner.end.x - 4.0),
					y + _roll.randf_range(0.0, _pitch)
				),
				1 + _roll.randi() % 3, -_roll.randf_range(0.0, 0.08), STAR_LIFE
			)
		_sweep_rows += 1
	if t >= 1.0 and not _burst_done:
		_burst_done = true
		_settle = 0.0
		var box := Rect2(FRAME_AT, _frame).grow(6.0)
		for k in BURST_STARS:
			var edge := _roll.randi() % 4
			var along := _roll.randf()
			var at := box.position + Vector2(along * box.size.x, 0.0)
			if edge == 1:
				at = box.position + Vector2(along * box.size.x, box.size.y)
			elif edge == 2:
				at = box.position + Vector2(0.0, along * box.size.y)
			elif edge == 3:
				at = box.position + Vector2(box.size.x, along * box.size.y)
			_add_star(at, 2 + _roll.randi() % 2, -_roll.randf_range(0.0, 0.25), STAR_LIFE * 1.2)


func _drive_settle(delta: float) -> void:
	if _settle < 0.0:
		return
	_settle += delta
	if _settle >= SETTLE_TIME:
		_settle = -1.0
		_bob = 0.0
		return
	_bob = SETTLE_DROP * exp(-_settle * 7.0) * sin(_settle * 16.0)


## The sheet thickens after the rows cut, eased, and swells a little with each one.
func _drive_sheet(delta: float) -> void:
	var want := 0.0
	if _phase == Phase.CUT and _rows > 0:
		want = SHEET_BASE + (SHEET_MOST - SHEET_BASE) * float(_rows) / float(_rows_total)
	if _phase == Phase.CUT:
		_thick += (want - _thick) * (1.0 - exp(-SHEET_EASE * delta))
	_swell *= exp(-8.0 * delta)
	_grip *= exp(-10.0 * delta)
	_sizzle_kick = maxf(_sizzle_kick - delta * 4.0, 0.0)
	var pool_want := POOL_LEAST + (POOL_MOST - POOL_LEAST) * minf(
		float(_rows_cut_all) / float(_rows_total * 2) + _pool_bonus, 1.0
	)
	_pool += (pool_want - _pool) * (1.0 - exp(-4.0 * delta))


## Everything small that moves: the stars and flashes age, the honey runs and drops, the
## crumbs fly and land, the sheet falls and squashes into the heap.
func _drive_bits(delta: float) -> void:
	var stars: Array[Dictionary] = []
	for star: Dictionary in _stars:
		star["age"] = float(star["age"]) + delta
		if float(star["age"]) < float(star["life"]):
			stars.append(star)
	_stars = stars
	var flashes: Array[Dictionary] = []
	for flash: Dictionary in _flashes:
		flash["age"] = float(flash["age"]) + delta
		if float(flash["age"]) < FLASH_LIFE:
			flashes.append(flash)
	_flashes = flashes
	for run: Dictionary in _runs:
		run["len"] = minf(float(run["len"]) + float(run["grow"]) * delta, float(run["most"]))
	var tray_top := _tray.position.y + 3.0
	# Honey on the blade only once there is honey on it: a row cut on this face.
	var honey := _phase == Phase.CUT and _rows > 0
	if honey:
		var heat := clampf(_speed / SIZZLE_FULL, 0.0, 1.0)
		var by := floorf(_knife) + BLADE_TALL
		for drip: Dictionary in _drips:
			drip["len"] = float(drip["len"]) + float(drip["grow"]) * delta * (0.6 + heat)
			if float(drip["len"]) >= float(drip["most"]):
				_beads.append({
					"at": Vector2(
						floorf(_inner.position.x + float(drip["slot"]) * _blade_len),
						by + float(drip["len"])
					),
					"v": 0.0,
				})
				var fresh := _new_drip(float(drip["slot"]))
				drip["len"] = 0.0
				drip["most"] = fresh["most"]
				drip["grow"] = fresh["grow"]
	var beads: Array[Dictionary] = []
	for bead: Dictionary in _beads:
		bead["v"] = float(bead["v"]) + FALL * delta
		var at: Vector2 = bead["at"]
		at.y += float(bead["v"]) * delta
		bead["at"] = at
		if at.y >= _gut(at.x) - 3.0 and at.x >= _tray.position.x and at.x < _tray.end.x:
			continue
		if at.y < _tray.end.y + 20.0:
			beads.append(bead)
	_beads = beads
	var crumbs: Array[Dictionary] = []
	for crumb: Dictionary in _crumbs:
		var v: Vector2 = crumb["v"]
		v.y += FALL * delta
		crumb["v"] = v
		var at: Vector2 = crumb["at"]
		at += v * delta
		crumb["at"] = at
		if v.y > 0.0 and at.y >= tray_top:
			_lay_bit(at.x, float(crumb["w"]), float(crumb["h"]), bool(crumb["lit"]))
			continue
		crumbs.append(crumb)
	_crumbs = crumbs
	if not _drop.is_empty():
		_drive_drop(delta, tray_top)


func _start_drop() -> void:
	if _thick < 0.5:
		_thick = 0.0
		return
	_drop = {
		"foot": floorf(_knife) - 1.0, "v": -30.0, "thick": _thick + _swell,
		"roll": _roll_phase, "land": -1.0,
	}
	_thick = 0.0
	_swell = 0.0


func _drive_drop(delta: float, tray_top: float) -> void:
	var land := float(_drop["land"])
	if land < 0.0:
		_drop["v"] = float(_drop["v"]) + FALL * delta
		_drop["foot"] = float(_drop["foot"]) + float(_drop["v"]) * delta
		if float(_drop["foot"]) >= tray_top + 3.0:
			_drop["foot"] = tray_top + 3.0
			_drop["land"] = 0.0
			_say(&"hive_pop", -8.0)
		return
	land += delta
	_drop["land"] = land
	if land < SQUASH_TIME:
		return
	# Flattened into the tray: what is left of it is crumbs in the heap.
	var left := _inner.position.x + 4.0
	var long := _blade_len - float(SHEET_TRIM)
	for k in SHEET_BITS:
		_lay_bit(left + (k + _roll.randf()) / SHEET_BITS * long, 2.0 + float(_roll.randi() % 4), 2.0, k % 3 != 0)
	_pool_bonus = minf(_pool_bonus + 0.05, 0.25)
	_drop = {}


func _lay_bit(x: float, w: float, h: float, lit: bool) -> void:
	if _heap.size() >= HEAP_MOST:
		return
	var left := _tray.position.x + 4.0
	var right := _tray.end.x - 4.0 - w
	_heap.append({
		"at": Vector2(
			floorf(clampf(x, left, right)),
			_tray.position.y + 1.0 + float(_roll.randi() % 5)
		),
		"w": w, "h": h, "lit": lit,
	})


func _add_star(at: Vector2, arm: int, start: float, life: float) -> void:
	if _stars.size() >= STARS_MOST:
		_stars.remove_at(0)
	_stars.append({"at": at, "arm": arm, "age": start, "life": life})


# --- Sound --------------------------------------------------------------------------------

## The knife's own sizzle loop, on SFX from silent: `HiveSounds` hands a recording when there
## is one and the built loop when there is not.
func _make_sizzle() -> void:
	if _sizzle != null:
		return
	var stream: AudioStream = HiveSounds.loop_stream(&"hive_sizzle")
	if stream == null:
		return
	_sizzle = AudioStreamPlayer.new()
	_sizzle.stream = stream
	_sizzle.bus = Prefs.BUS_SFX
	_sizzle.volume_db = Prefs.BUS_SILENT
	add_child(_sizzle)


## Loud with the knife's speed, a simmer while it is only held on the wax, the wash hiss's own
## ease in and out, and a touch higher the faster it goes.
func _drive_sizzle(delta: float, down: bool) -> void:
	if _sizzle == null:
		return
	var want := 0.0
	if _phase == Phase.CUT and _knife < _inner.end.y:
		want = clampf(_speed / SIZZLE_FULL, 0.0, 1.0)
		if down and awake() and not _need_release:
			want = maxf(want, SIZZLE_SIMMER)
		want = maxf(want, _sizzle_kick)
	_sizzle_level = move_toward(_sizzle_level, want, delta / SIZZLE_ATTACK)
	if _sizzle_level <= 0.0:
		if _sizzle.playing:
			_sizzle.stop()
		return
	if not _sizzle.playing:
		_sizzle.play()
	_sizzle.volume_db = lerpf(Prefs.BUS_SILENT, SIZZLE_DB, sqrt(_sizzle_level))
	var pitch := 0.92 + 0.18 * _sizzle_level
	_sizzle.pitch_scale = lerpf(_sizzle.pitch_scale, pitch, clampf(delta * 14.0, 0.0, 1.0))


## A hive one-shot through `Sfx.play_hive` (its takes, its gaps), or plainly through `Sfx.play`
## where that is not there yet; nothing at all with no autoload.
static func _say(what: StringName, db := 0.0) -> void:
	var sfx: Node = Sfx.main()
	if sfx == null:
		return
	if sfx.has_method(&"play_hive"):
		sfx.call(&"play_hive", what, true, db)
	else:
		HiveStep.sound(what, db)


# --- Drawing ------------------------------------------------------------------------------

func _draw() -> void:
	if not _laid:
		return
	HiveArt.draw(self, &"rest", to_canvas(FRAME_AT), &"frame_tl")
	var lift := Vector2(0.0, roundf(_bob))
	# The turn: squashed about the frame's middle, a whole number of painted pixels wide.
	var squash := 1.0
	var tint := Color.WHITE
	if _phase == Phase.FLIP:
		var t := clampf(_clock / FLIP_TIME, 0.0, 1.0)
		var eased := t * t * (3.0 - 2.0 * t)
		squash = absf(cos(PI * eased))
		squash = roundf(squash * _frame.x) / _frame.x
		tint = Color.WHITE.lerp(FLIP_SHADE, 1.0 - squash)
	var middle := to_canvas(FRAME_AT + Vector2(_frame.x * 0.5, 0.0)).x
	if squash > 0.0:
		if squash < 1.0:
			draw_set_transform(Vector2(middle * (1.0 - squash), 0.0), 0.0, Vector2(squash, 1.0))
		_draw_frame(lift, tint)
		_draw_face_life(lift)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_honey()
	if _knife_alpha > 0.01:
		_draw_knife()
	_draw_falling()
	for star: Dictionary in _stars:
		_draw_star(star)
	_draw_bees()
	_draw_guide()


func _draw_frame(lift: Vector2, tint: Color) -> void:
	var at := to_canvas(FRAME_AT + lift)
	var capped_whole := _phase == Phase.FLIP and _face == 1
	if capped_whole:
		HiveArt.draw(self, &"frame_capped", at, &"", false, 1.0, 1.0, tint)
		return
	HiveArt.draw(self, &"frame_open", at, &"", false, 1.0, 1.0, tint)
	if _phase != Phase.CUT or _rows >= _rows_total:
		return
	var cut := _inner.position.y - FRAME_AT.y + minf(_rows * _pitch, _inner.size.y)
	HiveArt.draw_region(
		self, &"frame_capped",
		Rect2(at + Vector2(0.0, cut * HiveArt.PIXEL), Vector2(_frame.x, _frame.y - cut) * HiveArt.PIXEL),
		Rect2(0.0, cut, _frame.x, _frame.y - cut)
	)


## What happens on the comb itself: rows flashing as they open, honey running down the fresh
## cut, and the golden sweep's line.
func _draw_face_life(lift: Vector2) -> void:
	for flash: Dictionary in _flashes:
		var k := clampf(float(flash["age"]) / FLASH_LIFE, 0.0, 1.0)
		var y := _inner.position.y + int(flash["row"]) * _pitch
		var tall := minf(_pitch + 1.0, _inner.end.y - y)
		if tall <= 0.0:
			continue
		var gold := bool(flash["gold"])
		var ink: Color = HiveArt.GOLD if gold else HiveArt.HONEY_SHINE
		_box(Vector2(_inner.position.x, y) + lift, Vector2(_inner.size.x, tall), _ink(ink, 0.5 * (1.0 - k) * (1.0 - k)))
		# The fresh cut glints: a bright line along the row's foot, going first.
		_box(
			Vector2(_inner.position.x, y + tall - 1.0) + lift, Vector2(_inner.size.x, 1.0),
			_ink(HiveArt.STAR_WHITE, 0.7 * (1.0 - k))
		)
	for run: Dictionary in _runs:
		if float(run["len"]) >= 1.0:
			HiveArt.drip(self, to_canvas((run["at"] as Vector2) + lift), float(run["len"]))
	if _phase == Phase.SWEEP and _clock < SWEEP_TIME:
		var t := clampf(_clock / SWEEP_TIME, 0.0, 1.0)
		var line := floorf(_inner.position.y + (1.0 - pow(1.0 - t, 3.0)) * _inner.size.y)
		line = minf(line, _inner.end.y - 2.0)
		_box(Vector2(_inner.position.x, line - 6.0) + lift, Vector2(_inner.size.x, 6.0), _ink(HiveArt.HONEY_SHINE, 0.22))
		_box(Vector2(_inner.position.x, line) + lift, Vector2(_inner.size.x, 2.0), _ink(HiveArt.GOLD, 0.85))


func _draw_knife() -> void:
	var y := floorf(_knife) - roundf(_grip)
	var blade := Vector2(_inner.position.x, y)
	var alpha := _knife_alpha
	if _phase == Phase.CUT:
		_draw_ghosts(blade.x)
		_draw_shimmer(blade, alpha)
	var drawn := HiveArt.draw(self, &"knife", to_canvas(blade), &"blade_l", false, alpha)
	if drawn.size == Vector2.ZERO:
		# No sheet (a harness before an import): a plain steel bar where the blade would be.
		_box(blade, Vector2(_blade_len, BLADE_TALL - 1.0), _ink(STEEL_BASE, alpha))
		_box(blade, Vector2(_blade_len, 2.0), _ink(STEEL_HI, alpha))
		_box(blade + Vector2(0.0, BLADE_TALL - 1.0), Vector2(_blade_len, 1.0), _ink(HOT_EDGE, alpha))
	_draw_glint(blade, alpha)
	if _phase == Phase.CUT and _rows > 0:
		for drip: Dictionary in _drips:
			if float(drip["len"]) >= 1.0:
				HiveArt.drip(
					self,
					to_canvas(Vector2(floorf(blade.x + float(drip["slot"]) * _blade_len), y + BLADE_TALL)),
					float(drip["len"]), alpha
				)
	var thick := _thick + _swell if _thick > 0.3 else 0.0
	if thick > 0.3:
		_draw_sheet(Vector2(blade.x + 4.0, y - 1.0), int(_blade_len) - SHEET_TRIM, thick, _roll_phase, alpha)
	var curl := alpha * clampf(_thick / 3.0, 0.0, 1.0)
	if curl > 0.01:
		HiveArt.draw(self, &"wax_curl", to_canvas(blade + Vector2(-3.0, -1.0)), &"root", false, curl)


## The glide: the blade's edge where it was a moment ago, fainter the longer ago, and only as
## far as it has actually moved since.
func _draw_ghosts(left: float) -> void:
	if _trail.size() < 2:
		return
	var now := floorf(_knife)
	for k in GHOSTS.size():
		var then := floorf(_knife_at(age - float(GHOSTS[k])))
		var gone := now - then
		if gone < 2.0:
			continue
		var a := float(GHOST_ALPHA[k]) * clampf(gone / 6.0, 0.0, 1.0) * _knife_alpha
		_box(Vector2(left, then), Vector2(_blade_len, 4.0), _ink(STEEL_HI, a))
		_box(Vector2(left, then + 4.0), Vector2(_blade_len, 1.0), _ink(HOT, a))


func _knife_at(when: float) -> float:
	for k in range(_trail.size() - 1, -1, -1):
		if _trail[k].x <= when:
			return _trail[k].y
	return _trail[0].y


## Heat off the edge: a broken row of hot pixels under the blade, re-rolled on the stepped
## clock, stronger the faster the knife goes.
func _draw_shimmer(blade: Vector2, alpha: float) -> void:
	var heat := 0.35 + 0.65 * clampf(_speed / SIZZLE_FULL, 0.0, 1.0)
	var tick := int(age * SHIMMER_FPS)
	var ink := _ink(HOT, 0.6 * heat * alpha)
	for k in SHIMMER_DOTS:
		var x := blade.x + 10.0 + k * 6.0 + floorf(_hash(k, tick) * 5.0) - 2.0
		if x >= blade.x + _blade_len:
			break
		_box(Vector2(x, blade.y + BLADE_TALL + 1.0 + float((k + tick) % 3)), Vector2.ONE, ink)
		if _hash(k, tick + 91) < 0.3 * heat:
			_box(Vector2(x + 1.0, blade.y - 2.0 - float(k % 2)), Vector2.ONE, _ink(HOT, 0.3 * heat * alpha))


## A glint running along the blade's top edge: now and then while it waits, often while held,
## and at once on a press.
func _draw_glint(blade: Vector2, alpha: float) -> void:
	var every := GLINT_EVERY / 3.0 if tool_down() else GLINT_EVERY
	var t := fposmod(age - _glint_at, every) / minf(every, 0.9)
	if t >= 1.0:
		return
	var x := floorf(blade.x + t * _blade_len)
	var a := sin(PI * t) * alpha
	_box(Vector2(x - 2.0, blade.y), Vector2(5.0, 1.0), _ink(HiveArt.STAR_WHITE, 0.55 * a))
	_box(Vector2(x, blade.y), Vector2(1.0, 2.0), _ink(HiveArt.STAR_WHITE, a))


## The rolled wax on the blade, `wax_sheet`'s own drawing a painted pixel at a time: a wavy log
## sitting on `foot`, fat at the tip and easing thinner towards the handle, lit along its
## crown, dimpled with the cells it came from, inked round. `squash` flattens it into the tray.
func _draw_sheet(foot: Vector2, length: int, thick: float, roll: float, alpha: float, squash := 1.0) -> void:
	if length <= 1 or alpha <= 0.0:
		return
	var out := _ink(HiveArt.OUT, alpha)
	var last_top := -1.0
	for x in length:
		var t := float(x) / float(length - 1)
		var wave := 1.0 + 0.22 * sin(t * PI * 3.0 + 0.5 + roll) + 0.14 * sin(t * PI * 7.0 + roll * 1.7) - 0.35 * t
		var lift := int(roundf(thick * wave * squash))
		if lift <= 0:
			last_top = -1.0
			continue
		var px := foot.x + x
		var top := foot.y - lift
		# The outline over the crown, and down the ends.
		_box(Vector2(px, top - 1.0), Vector2.ONE, out)
		if x == 0 or x == length - 1 or last_top < 0.0:
			var edge := px - 1.0 if (x == 0 or last_top < 0.0) else px + 1.0
			_box(Vector2(edge, top), Vector2(1.0, lift + 1.0), out)
		elif top < last_top - 1.0:
			# Rising: the step up is inked on the column before, over its own crown.
			_box(Vector2(px - 1.0, top), Vector2(1.0, last_top - 1.0 - top), out)
		elif top > last_top + 1.0:
			# Falling: inked on this column, down to its own crown's line.
			_box(Vector2(px, last_top), Vector2(1.0, top - 1.0 - last_top), out)
		last_top = top
		var lit_end := top + ceilf(0.18 * lift)
		var wax_end := top + ceilf(0.6 * lift)
		var shade_end := top + ceilf(0.85 * lift)
		var gloss := GLOSS if floori(x / 6.0) % 3 != 2 else HiveArt.WAX_LIT
		_box(Vector2(px, top), Vector2.ONE, _ink(gloss, alpha))
		_span(px, top + 1.0, lit_end, HiveArt.WAX_LIT, alpha)
		_span(px, maxf(lit_end, top + 1.0), wax_end, HiveArt.WAX, alpha)
		_span(px, maxf(wax_end, top + 1.0), shade_end, HiveArt.WAX_SHADE, alpha)
		_span(px, maxf(shade_end, top + 1.0), foot.y + 1.0, HiveArt.WAX_WALL, alpha)
		if lift >= 5 and x % 5 == 0:
			_box(Vector2(px, top + floorf(lift * 0.5) - float(floori(x / 5.0) % 2)), Vector2.ONE, _ink(HiveArt.WAX_SHADE, alpha))
		if lift >= 4 and x % 23 == 7:
			_box(Vector2(px, top + 2.0), Vector2(2.0, 2.0), _ink(HiveArt.HONEY_LIGHT, alpha))


func _span(x: float, from: float, to: float, ink: Color, alpha: float) -> void:
	if to > from:
		_box(Vector2(x, from), Vector2(1.0, to - from), _ink(ink, alpha))



## What is in the air: beads of honey, crumbs of wax, and the sheet on its way to the tray.
func _draw_falling() -> void:
	for bead: Dictionary in _beads:
		var at := (bead["at"] as Vector2).floor()
		_box(at + Vector2(-1.0, 0.0), Vector2(2.0, 2.0), HiveArt.HONEY)
		_box(at, Vector2.ONE, HiveArt.HONEY_SHINE)
	for crumb: Dictionary in _crumbs:
		var ink: Color = HiveArt.WAX_LIT if bool(crumb["lit"]) else HiveArt.WAX_SHADE
		_box((crumb["at"] as Vector2).floor(), Vector2(float(crumb["w"]), float(crumb["h"])), ink)
	if _drop.is_empty():
		return
	var squash := 1.0
	var land := float(_drop["land"])
	if land >= 0.0:
		var k := clampf(land / SQUASH_TIME, 0.0, 1.0)
		squash = 1.0 - 0.75 * k * k
	_draw_sheet(
		Vector2(_inner.position.x + 4.0, floorf(float(_drop["foot"]))),
		int(_blade_len) - SHEET_TRIM, float(_drop["thick"]), float(_drop["roll"]), 1.0, squash
	)


func _draw_star(star: Dictionary) -> void:
	var a := float(star["age"])
	if a < 0.0:
		return
	var k := clampf(a / float(star["life"]), 0.0, 1.0)
	var arm := int(ceilf(float(star["arm"]) * sin(PI * k)))
	var alpha := 1.0 if k < 0.7 else (1.0 - k) / 0.3
	HiveArt.star(self, to_canvas(star["at"] as Vector2), arm, alpha)


## A few bees over the frame for the honey, each on its own slow figure, wings beating.
func _draw_bees() -> void:
	for k in _bees.size():
		var bee: Dictionary = _bees[k]
		var a1 := age * float(bee["w1"]) + float(bee["p1"])
		var a2 := age * float(bee["w2"]) + float(bee["p2"])
		var at: Vector2 = (bee["home"] as Vector2) + Vector2(sin(a1) * float(bee["r1"]), sin(a2) * float(bee["r2"]))
		var piece := &"bee_r" if (int(age * 14.0) + k) % 2 == 0 else &"bee_r_rest"
		HiveArt.draw(self, piece, to_canvas(at.floor()), &"c", cos(a1) < 0.0)


## The mouse's promise: with the knife waiting and the pointer below it, a faint gold dashed
## line where a press would draw it to.
func _draw_guide() -> void:
	if _phase != Phase.CUT or Pad.is_pad() or not awake() or _need_release or tool_down():
		return
	var at := art_mouse()
	if at.y <= _knife + 4.0 or at.x < _inner.position.x - 30.0 or at.x > _inner.end.x + 30.0:
		return
	var y := floorf(minf(at.y, _inner.end.y))
	var a := 0.3 + 0.12 * sin(age * 5.0)
	var x := _inner.position.x
	while x < _inner.end.x:
		_box(Vector2(x, y), Vector2(minf(4.0, _inner.end.x - x), 1.0), _ink(HiveArt.GOLD, a))
		x += 7.0


## One run of painted pixels: `p` and `s` on the art grid, whole pixels.
func _box(p: Vector2, s: Vector2, color: Color) -> void:
	if color.a <= 0.0 or s.x <= 0.0 or s.y <= 0.0:
		return
	draw_rect(Rect2(to_canvas(p.floor()), s * HiveArt.PIXEL), color)


static func _ink(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(alpha, 0.0, 1.0))


static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1103515245) & 0x7fffffff
	return float(h % 10007) / 10007.0


# --- The honey: curtains off the cut, the gutter, the rope, the bucket --------------------
#
# The second pass (2026-09-30, Richard): the honey the knife frees runs off the cut as glossy
# curtains into a thin tin gutter slung under the frame on a slant; it is thicker than the tin
# is deep, so it rides down it bulging over the rim, swelling where each curtain feeds it and
# spilling over the lip here and there; off the low end it falls as a heavy rope — fat where it
# leaves, necking thin, a bead swelling at its foot until it lets go, a thread left behind that
# springs back up — into the bucket, where it folds into coils on the pool. **Every unit of
# honey is kept**: what the rows free goes curtain, gutter, rope, bucket, and the bucket's level
# is what reached it, handed on to the pour (`HiveRoom.honey`).

## The gutter's two ends on the art grid, from the frame (the mockup's `fx - 12, fy + fh + 10`
## and `fx + fw + 42, fy + fh + 44`, fw 300 the comb and fh the frame's height).
const GUTTER_IN := Vector2(-12.0, 8.0)
const GUTTER_OUT := Vector2(342.0, 40.0)
## The bucket's mouth, painted pixels, under the gutter's low end.
const BUCKET_MOUTH := Vector2(508.0, 300.0)
## The curtains: across the frame (from its left), and their widths where they leave the blade
## and where they reach the tin.
const CURTAINS: Array[Vector3] = [
	Vector3(70, 12, 8), Vector3(112, 18, 12), Vector3(150, 22, 14), Vector3(186, 14, 10),
	Vector3(224, 10, 7), Vector3(262, 8, 6),
]
## A row frees `ROW_HONEY` of honey (in painted pixels of gutter cross-section), let out of the
## curtains at `RELEASE` of what waits a second, and never slower than `RELEASE_LEAST`.
const ROW_HONEY := 70.0
const RELEASE := 0.9
const RELEASE_LEAST := 40.0
## A curtain grows down at this pace and, once it stops being fed, its tail falls at this.
const CURTAIN_GROW := 90.0
const CURTAIN_FALL := 120.0
## The gutter: honey runs down it at `RUN_BASE` plus `RUN_DEEP` a pixel of depth (thick honey
## runs faster), and spreads a little (`SPREAD_RATE`). Deeper than `SPILL_AT` it spills over
## the lip; drawn no deeper than `DEEP_MOST`.
const RUN_BASE := 80.0
const RUN_DEEP := 8.0
const SPREAD_RATE := 6.0
const DEEP_MOST := 11.0
## The tin's rim is this deep: honey over it bulges above the rim.
const RIM := 3.0
## The rope: its bead hangs `ROPE_REST + ROPE_PER * sqrt(mass)` under the lip, sprung at
## `ROPE_K` with `ROPE_DAMP`, and lets go when it hangs past `SNAP_AT` of the way to the pool
## or weighs `SNAP_MASS`; `KEEP` of it stays on the lip, flicked back up at `RECOIL`.
const ROPE_REST := 3.0
const ROPE_PER := 2.4
const ROPE_K := 70.0
const ROPE_DAMP := 5.0
const SNAP_AT := 0.62
const SNAP_MASS := 150.0
const KEEP := 0.18
const RECOIL := 60.0
## A falling drop, and the coils it folds into on the pool.
const DROP_FALL := 420.0
const COIL_LIFE := 0.9
## A thread left after a snap springs up over this long.
const THREAD_LIFE := 0.35
## Honey on the gutter's lip: a spill grows at this and drops its bead at this long.
const SPILL_GROW := 14.0
const SPILL_LONG := Vector2(5.0, 12.0)
const SPILLS_MOST := 8

var _h: PackedFloat32Array = []
var _g0 := Vector2.ZERO
var _g1 := Vector2.ZERO
var _pending := 0.0
var _curtain_top: PackedFloat32Array = []
var _curtain_bot: PackedFloat32Array = []
var _curtain_flow: PackedFloat32Array = []
var _rope_mass := 0.0
var _rope_y := 0.0
var _rope_v := 0.0
var _rope_in := 0.0
var _thread := 0.0
var _thread_from := 0.0
## `{y, v, mass, x}` falling drops; `{x, age, w}` coils on the pool; `{x, len, most, mass}`
## spills on the lip.
var _falls: Array[Dictionary] = []
var _coils: Array[Dictionary] = []
var _spills: Array[Dictionary] = []
var _landed := 0.0
var _total := 1.0


func _lay_honey() -> void:
	_g0 = FRAME_AT + Vector2(0.0, _frame.y) + GUTTER_IN
	_g1 = FRAME_AT + Vector2(0.0, _frame.y) + GUTTER_OUT
	_h.resize(int(_g1.x - _g0.x) + 1)
	_h.fill(0.0)
	_curtain_top.resize(CURTAINS.size())
	_curtain_bot.resize(CURTAINS.size())
	_curtain_flow.resize(CURTAINS.size())
	_curtain_top.fill(-1.0)
	_curtain_bot.fill(-1.0)
	_curtain_flow.fill(0.0)
	_pending = 0.0
	_rope_mass = 0.0
	_rope_y = ROPE_REST
	_rope_v = 0.0
	_rope_in = 0.0
	_thread = 0.0
	_falls.clear()
	_coils.clear()
	_spills.clear()
	_landed = 0.0
	_total = maxf(float(_rows_total) * ROW_HONEY, 1.0)
	_tray = Rect2(Vector2(_g0.x, _g0.y - 4.0), Vector2(_g1.x - _g0.x, 60.0))


## The gutter's floor under column `x`, painted pixels.
func _gut(x: float) -> float:
	return _g0.y + (x - _g0.x) * (_g1.y - _g0.y) / maxf(_g1.x - _g0.x, 1.0)


## How full the bucket is, 0..1: what has reached it.
func bucket_level() -> float:
	return clampf(_landed / _total, 0.0, 1.0)


## Honey still on its way: in the curtains' store, the gutter, the rope and the air.
func honey_left() -> float:
	var n := _pending + _rope_mass
	for v in _h:
		n += v
	for f: Dictionary in _falls:
		n += float(f["mass"])
	for s: Dictionary in _spills:
		n += float(s["mass"])
	return n


## Everything on its way lands in the bucket at once.
func _drain_all() -> void:
	_landed += honey_left()
	_pending = 0.0
	_rope_mass = 0.0
	_h.fill(0.0)
	_falls.clear()
	_spills.clear()
	_curtain_top.fill(-1.0)
	_curtain_bot.fill(-1.0)
	_push_level()


func _push_level() -> void:
	if room != null:
		room.honey = bucket_level()


func _row_honey() -> void:
	_pending += ROW_HONEY


func _drive_honey(delta: float) -> void:
	if _h.is_empty():
		return
	# The store let out through the curtains, each its share by width.
	var out := minf(_pending, maxf(_pending * RELEASE, RELEASE_LEAST) * delta)
	_pending -= out
	var wide := 0.0
	for c: Vector3 in CURTAINS:
		wide += c.y
	var edge := floorf(_knife) + BLADE_TALL if _phase == Phase.CUT else _inner.end.y
	for k in CURTAINS.size():
		var c := CURTAINS[k]
		var x := FRAME_AT.x + c.x
		var give := out * c.y / wide
		var floor_y := _gut(x) - 2.0
		if give > 0.0:
			_curtain_flow[k] = lerpf(_curtain_flow[k], 1.0, 1.0 - exp(-6.0 * delta))
			if _curtain_bot[k] < 0.0:
				_curtain_top[k] = edge
				_curtain_bot[k] = edge
			_curtain_top[k] = minf(edge, floor_y)
			_curtain_bot[k] = minf(_curtain_bot[k] + CURTAIN_GROW * delta, floor_y)
		else:
			_curtain_flow[k] = lerpf(_curtain_flow[k], 0.0, 1.0 - exp(-3.0 * delta))
			if _curtain_top[k] >= 0.0:
				_curtain_top[k] += CURTAIN_FALL * delta
				_curtain_bot[k] = minf(_curtain_bot[k] + CURTAIN_GROW * delta, floor_y)
				if _curtain_top[k] >= _curtain_bot[k]:
					_curtain_top[k] = -1.0
					_curtain_bot[k] = -1.0
		# Honey only reaches the tin once the curtain does; until then it hangs in the sheet.
		if give > 0.0:
			if _curtain_bot[k] >= floor_y - 0.5:
				_pour_into(x, give)
			else:
				_pending += give
	# Down the tin: each column hands on its share downhill, deeper running faster, in
	# sub-steps so no column hands on more than it holds.
	var n := _h.size()
	var steps := maxi(1, ceili((RUN_BASE + RUN_DEEP * 3.0) * delta / 0.4))
	var dt := delta / steps
	var moved := PackedFloat32Array()
	moved.resize(n)
	for step in steps:
		for i in n:
			var v := _h[i]
			moved[i] = 0.0 if v <= 0.0001 else minf(v, v * minf((RUN_BASE + RUN_DEEP * v / 6.0) * dt, 0.5))
		for i in n:
			var q := moved[i]
			if q <= 0.0:
				continue
			_h[i] -= q
			if i + 1 < n:
				_h[i + 1] += q
			else:
				_rope_in += q
	# A little spread, so a feed swells into a bulge rather than a spike.
	var spread := clampf(SPREAD_RATE * delta, 0.0, 0.3)
	for i in range(1, n - 1):
		var mean := (_h[i - 1] + _h[i + 1]) * 0.5
		_h[i] += (mean - _h[i]) * spread * 0.5
	# Over the lip: a spill starts where the honey stands too deep.
	for i in range(8, n - 8, 5):
		if 3.0 + sqrt(_h[i]) * 2.0 > DEEP_MOST + 2.0 and _spills.size() < SPILLS_MOST and _roll.randf() < delta * 1.5:
			var take := _h[i] * 0.3
			_h[i] -= take
			_spills.append({
				"x": _g0.x + i, "len": 0.0,
				"most": _roll.randf_range(SPILL_LONG.x, SPILL_LONG.y), "mass": take,
			})
	var kept: Array[Dictionary] = []
	for s: Dictionary in _spills:
		s["len"] = float(s["len"]) + SPILL_GROW * delta
		if float(s["len"]) >= float(s["most"]):
			# Its bead drops off the lip and back into the gutter's low end, so nothing is lost.
			_rope_in += float(s["mass"])
			continue
		kept.append(s)
	_spills = kept
	_drive_rope(delta)
	_push_level()


func _pour_into(x: float, amount: float) -> void:
	var at := int(clampf(x - _g0.x, 0.0, _h.size() - 1))
	var weight := 0.0
	for d in range(-6, 7):
		weight += exp(-float(d * d) / 18.0)
	for d in range(-6, 7):
		var i := clampi(at + d, 0, _h.size() - 1)
		_h[i] += amount * exp(-float(d * d) / 18.0) / weight


## The rope off the gutter's low end: a bead sprung under the lip, swelling with what comes
## down, necking as it sinks, letting go, and a thread left to spring back.
func _drive_rope(delta: float) -> void:
	_rope_mass += _rope_in
	var inflow := _rope_in / maxf(delta, 0.0001)
	_rope_in = 0.0
	var lip := _lip()
	var fall := BUCKET_MOUTH.y - lip.y
	var rest := ROPE_REST + ROPE_PER * sqrt(_rope_mass) + minf(inflow * 0.02, 10.0)
	_rope_v += (ROPE_K * (rest - _rope_y) - ROPE_DAMP * _rope_v) * delta
	_rope_y = clampf(_rope_y + _rope_v * delta, 1.0, fall)
	if (_rope_y > fall * SNAP_AT or _rope_mass > SNAP_MASS) and _rope_mass > 8.0:
		var go := _rope_mass * (1.0 - KEEP)
		_rope_mass -= go
		_falls.append({"x": lip.x, "y": lip.y + _rope_y, "v": maxf(_rope_v, 20.0), "mass": go})
		_thread_from = _rope_y
		_thread = THREAD_LIFE
		_rope_y = ROPE_REST + ROPE_PER * sqrt(_rope_mass)
		_rope_v = -RECOIL
	_thread = maxf(_thread - delta, 0.0)
	var kept: Array[Dictionary] = []
	for f: Dictionary in _falls:
		f["v"] = float(f["v"]) + DROP_FALL * delta
		f["y"] = float(f["y"]) + float(f["v"]) * delta
		if float(f["y"]) >= _pool_y():
			_landed += float(f["mass"])
			for k in 3:
				_coils.append({"x": float(f["x"]) + _roll.randf_range(-2.0, 2.0), "age": -k * 0.08,
					"w": 16.0 - k * 4.0 + sqrt(float(f["mass"])) * 0.4})
			continue
		kept.append(f)
	_falls = kept
	var coils: Array[Dictionary] = []
	for c: Dictionary in _coils:
		c["age"] = float(c["age"]) + delta
		if float(c["age"]) < COIL_LIFE:
			coils.append(c)
	_coils = coils


func _lip() -> Vector2:
	return Vector2(_g1.x + 4.0, _g1.y + 1.0)


func _pool_y() -> float:
	return BUCKET_MOUTH.y + 3.0 - bucket_level() * 3.0


## The gutter, the honey in it and over it, the rope, the drops, the bucket and its coils.
func _draw_honey() -> void:
	if _h.is_empty():
		return
	var n := _h.size()
	# The bucket first: the rope falls into it from above.
	HiveArt.draw(self, &"bucket", to_canvas(BUCKET_MOUTH), &"mouth")
	_draw_pool()
	# The tin's back wall.
	for i in n:
		var x := _g0.x + i
		var y := floorf(_gut(x))
		_box(Vector2(x, y - 6.0), Vector2(1.0, 4.0), STEEL_SHADE)
	# The curtains, over the capped face, down to the tin.
	for k in CURTAINS.size():
		if _curtain_top[k] < 0.0:
			continue
		var c := CURTAINS[k]
		var flow := _curtain_flow[k]
		_curtain(FRAME_AT.x + c.x, _curtain_top[k], _curtain_bot[k], maxf(c.y * (0.4 + 0.6 * flow), 3.0),
			maxf(c.z * (0.4 + 0.6 * flow), 2.0), k)
	# The tin, lit along its lip.
	for i in n:
		var x := _g0.x + i
		var y := floorf(_gut(x))
		_box(Vector2(x, y - 3.0), Vector2(1.0, 7.0), HiveArt.OUT)
		_box(Vector2(x, y - 2.0), Vector2(1.0, 5.0), STEEL_BASE)
		_box(Vector2(x, y - 2.0), Vector2.ONE, STEEL_HI)
		_box(Vector2(x, y - 1.0), Vector2.ONE, STEEL_LIT)
		_box(Vector2(x, y + 2.0), Vector2(1.0, 1.0), STEEL_SHADE)
	_box(Vector2(_g0.x - 2.0, floorf(_gut(_g0.x)) - 7.0), Vector2(3.0, 12.0), STEEL_SHADE)
	# The honey riding it, fatter than the tin: a rounded glossy body over the rim.
	for i in n:
		var v := _h[i]
		if v < 0.4:
			continue
		var x := _g0.x + i
		var y := floorf(_gut(x))
		var tall := minf(3.0 + sqrt(v) * 2.0, DEEP_MOST) + sin(x * 0.11 + age * 1.5) * 0.6
		var top := roundf(y - RIM - tall + 2.0)
		var foot := y + 2.0
		var span := foot - top
		_box(Vector2(x, top - 1.0), Vector2.ONE, HiveArt.HONEY_DEEP)
		_span_ink(x, top, top + ceilf(span * 0.14), HiveArt.HONEY_SHINE)
		_span_ink(x, top + ceilf(span * 0.14), top + ceilf(span * 0.32), HiveArt.HONEY_LIGHT)
		_span_ink(x, top + ceilf(span * 0.32), top + ceilf(span * 0.7), HiveArt.HONEY)
		_span_ink(x, top + ceilf(span * 0.7), foot, HiveArt.HONEY_MID)
		_box(Vector2(x, foot), Vector2.ONE, HiveArt.HONEY_DEEP)
		if int(x) % 9 < 3 and v < 30.0:
			_box(Vector2(x, top + 1.0), Vector2.ONE, Color(1.0, 1.0, 0.96))
	# Honey over the lip, running down the tin's face.
	for s: Dictionary in _spills:
		var x := float(s["x"])
		HiveArt.drip(self, to_canvas(Vector2(x, floorf(_gut(x)) + 3.0)), float(s["len"]))
	_draw_rope()
	for f: Dictionary in _falls:
		var r := 2.0 + sqrt(float(f["mass"])) * 0.5
		var stretch := clampf(float(f["v"]) / 400.0, 0.0, 0.8)
		_blob(Vector2(float(f["x"]), float(f["y"])), Vector2(r * (1.0 - stretch * 0.3), r * (1.0 + stretch)))


## The pool in the bucket's mouth, rising, glossy, with the coils folding into it.
func _draw_pool() -> void:
	var level := bucket_level()
	if level <= 0.01:
		return
	var half := HiveArt.anchor(&"bucket", &"half") if HiveArt.knows(&"bucket") else Vector2(48.0, 6.0)
	var lift := (1.0 - level) * 3.0
	var middle := BUCKET_MOUTH + Vector2(0.0, lift)
	var h := half - Vector2(1.0, 1.0 + lift * 0.5)
	_ellipse_rows(middle, h, HiveArt.HONEY_MID)
	_ellipse_rows(middle + Vector2(0.0, 0.5), h - Vector2(2.0, 1.5), HiveArt.HONEY)
	_box(middle + Vector2(-34.0, -h.y + 2.0), Vector2(34.0, 1.0), HiveArt.HONEY_LIGHT)
	_box(middle + Vector2(-28.0, -h.y + 3.0), Vector2(14.0, 1.0), HiveArt.HONEY_SHINE)
	for c: Dictionary in _coils:
		var t := float(c["age"])
		if t < 0.0:
			continue
		var k := clampf(t / COIL_LIFE, 0.0, 1.0)
		var w := float(c["w"]) * (1.0 - 0.5 * k)
		var up := (1.0 - k) * 3.0
		var steps := int(w * 2.0)
		for s in steps:
			var ang := TAU * s / steps
			var at := Vector2(float(c["x"]) + cos(ang) * w * 0.5, _pool_y() - up + sin(ang) * w * 0.16)
			_box(at.floor(), Vector2.ONE, _ink(HiveArt.HONEY_SHINE if s % 2 else HiveArt.HONEY_LIGHT, 1.0 - k))


## The rope: fat off the lip, necking, the bead at its foot; after a snap, a thread springing
## back up to the lip.
func _draw_rope() -> void:
	var lip := _lip()
	var flowing := _rope_mass > 1.0 or _h[_h.size() - 1] > 0.5
	if not flowing and _thread <= 0.0:
		return
	var wtop := clampf(4.0 + _h[_h.size() - 1] * 0.25, 4.0, 14.0)
	var bead_r := 2.0 + sqrt(_rope_mass) * 0.55
	var reach := _rope_y
	for y in int(reach):
		var t := float(y) / maxf(reach, 1.0)
		var neck := maxf(1.0, wtop * 0.22)
		var w := lerpf(wtop, neck, sin(minf(1.0, t * 1.15) * PI * 0.5))
		_rope_row(lip.x, lip.y + y, w)
	if _rope_mass > 1.0:
		_blob(lip + Vector2(0.0, reach + bead_r * 0.6), Vector2(bead_r, bead_r * 1.1))
	if _thread > 0.0:
		var k := _thread / THREAD_LIFE
		var long := _thread_from * k
		_box(Vector2(lip.x, lip.y + reach), Vector2(1.0, maxf(long - reach, 0.0) + 2.0), _ink(HiveArt.HONEY_MID, k))


func _rope_row(cx: float, y: float, w: float) -> void:
	var l := roundf(cx - w * 0.5)
	var r := roundf(cx + w * 0.5)
	var span := r - l
	if span < 1.0:
		_box(Vector2(l, y), Vector2.ONE, HiveArt.HONEY_MID)
		return
	_box(Vector2(l, y), Vector2(span + 1.0, 1.0), HiveArt.HONEY)
	_box(Vector2(l, y), Vector2(maxf(ceilf(span * 0.22), 1.0), 1.0), HiveArt.HONEY_MID)
	_box(Vector2(l + ceilf(span * 0.28), y), Vector2(maxf(ceilf(span * 0.17), 1.0), 1.0), HiveArt.HONEY_SHINE)
	_box(Vector2(l + ceilf(span * 0.45), y), Vector2(maxf(ceilf(span * 0.15), 1.0), 1.0), HiveArt.HONEY_LIGHT)
	_box(Vector2(l, y), Vector2.ONE, HiveArt.HONEY_DEEP)
	_box(Vector2(r, y), Vector2.ONE, HiveArt.HONEY_DEEP)


## A glossy bead: deep rim, honey body, a light patch and a shine on its upper left.
func _blob(middle: Vector2, half: Vector2) -> void:
	_ellipse_rows(middle, half + Vector2.ONE, HiveArt.HONEY_DEEP)
	_ellipse_rows(middle, half, HiveArt.HONEY)
	_ellipse_rows(middle + Vector2(-half.x * 0.3, -half.y * 0.3), half * 0.45, HiveArt.HONEY_LIGHT)
	_box((middle + Vector2(-half.x * 0.45, -half.y * 0.5)).floor(), Vector2(2.0, 1.0), HiveArt.HONEY_SHINE)


## A glossy sheet of honey (mockup2 `curtain`): wobbling at its edges, dark down its left, a
## bright streak a third of the way in, narrowing from `w0` to `w1` as it falls.
func _curtain(x: float, y0: float, y1: float, w0: float, w1: float, k: int) -> void:
	var ph := float(k) * 1.7
	var tall := maxf(y1 - y0, 1.0)
	for yy in range(int(y0), int(y1)):
		var t := (yy - y0) / tall
		var w := maxf(2.0, w0 + (w1 - w0) * pow(t, 0.8) + sin(yy * 0.21 + ph + age * 2.0) * 1.3)
		var cx := x + sin(yy * 0.06 + ph + age * 0.8) * 1.5
		_rope_row(cx, yy, w)


func _ellipse_rows(middle: Vector2, half: Vector2, ink: Color) -> void:
	if half.x <= 0.0 or half.y <= 0.0:
		return
	var top := floori(middle.y - half.y)
	for y in range(top, ceili(middle.y + half.y) + 1):
		var dy := (y + 0.5 - middle.y) / half.y
		if absf(dy) >= 1.0:
			continue
		var w := half.x * sqrt(1.0 - dy * dy)
		var from := roundf(middle.x - w)
		_box(Vector2(from, y), Vector2(maxf(roundf(middle.x + w) - from, 1.0), 1.0), ink)


func _span_ink(x: float, from: float, to: float, ink: Color) -> void:
	if to > from:
		_box(Vector2(x, from), Vector2(1.0, to - from), ink)
