## One step of the hive room: the base the five minigames stand on (2026-09-30, the beehive
## sidequest; `docs/hive/contract.md` section 6).
##
## A step is a full-window Control in the room's step host, drawing its scene in `_draw` on the
## room's art grid (640x360 painted pixels, `HiveArt.PIXEL` canvas pixels to one) and saying
## `finished` once, when its payoff has landed. **It knows nothing of the plan, the plank, the
## hive or the save**: the room decides what comes next and what the lake is told.
##
## What every step shares, so no two of them do it differently:
## - **The wake latch** (`awake`), `WashStand`'s own (2026-09-26, Richard: the nozzle chased
##   the pointer and the choosing click sprayed). The press that opened the room, or that
##   finished the step before, is still held when a step comes up; a step deaf to the player
##   until that press is let go and `WAKE_AFTER` has run cannot be worked by it. **Only the
##   player's paths ask it**: every harness hook (`shake`, `puff`, `find_at`, `cut_to`,
##   `turn`, `pour`) drives the step at once, the way `WashStand.spray` does.
## - **The tool**: the left button, or on the pad RT or A held (`tool_down`).
## - **The art grid**: `art_mouse` is the pointer in painted pixels, `to_canvas` the way back.
## - **The pad**: a hands-on step reads the stick itself (`pad_free`, true by default) and
##   moves the hidden pointer with it (`pad_move`); a step that wants the cross picked
##   instead says false.
## - **One `finished`**, however many times the last shake or the last jar lands
##   (`done_once`).
##
## **The shared housekeeping runs in `_notification`, not in `_ready` or `_process`**:
## GDScript calls `_notification` at every level of a script's inheritance and does not call a
## parent's `_ready` or `_process` for a child that defines its own. A step overriding
## `_process` to drive its bees therefore still wakes, ages and redraws, with no `super` call
## to forget. (A step that defines a `_notification` of its own gets both, and must not call
## `super._notification`, or the clock runs twice.) `begin` is the one hook a step overrides
## and must pass up: call `super.begin()` first, then reset the step's own state.
class_name HiveStep
extends Control

signal finished

## How long the step stays deaf after the press that brought it up has been let go.
const WAKE_AFTER := 0.4
## Loose bees wandering the scene's air (2026-10-04, Richard: "messier, not all concentrated"):
## each flies at its own pace between goals rolled anywhere in its box, weaving off the line
## and turning on a lag, so the air is busy rather than a cloud in one place. Their speed range
## (painted px a second), how hard they turn towards a goal, and how far off it counts as there.
const WANDER_SPEED := Vector2(34.0, 78.0)
const WANDER_STEER := 2.6
const WANDER_NEAR := 14.0
const WANDER_WEAVE := 28.0
## The ending every step shares (2026-10-04, Richard: "improve the looks of the shine and
## glimmer on ending a mini game"; `payoff`, `draw_payoff`): gold rays fanning up out of what
## was just finished, stars twinkling in and out each on its own beat, and the crown dropping
## in with a bounce and a soft gold halo. How long it shows, the rays (how many, how long,
## how wide at the root, how strong), the stars (how many, when they come, how long each),
## and the crown (where it rests over the thing, how far it falls, its scale).
const PAYOFF_LIFE := 2.4
const RAYS := 11
const RAY_REACH := Vector2(34.0, 84.0)
const RAY_ROOT := 4.0
const RAY_ALPHA := 0.3
const PAYOFF_STARS := 14
const STAR_COME := 1.4
const STAR_SHOW := Vector2(0.45, 0.8)
const CROWN_REST := 0.6
const CROWN_FALL := 46.0
const CROWN_DROP := 0.55
const CROWN_SCALE := 2.0

## The room this step is shown in, set before `begin`. A step with no room (a spike, a
## probe) lays its grid out centred on its own size.
var room: HiveRoom
## Seconds since `begin`: every step's own clock, for bobs and pulses.
var age := 0.0

var _await_release := false
var _asleep := 0.0
var _done := false

var _wander_roll := RandomNumberGenerator.new()
var _wander_box := Rect2()
var _wander_pos := PackedVector2Array()
var _wander_vel := PackedVector2Array()
var _wander_goal := PackedVector2Array()
var _wander_speed := PackedFloat32Array()
var _wander_phase := PackedFloat32Array()

var _pay_age := -1.0
var _pay_at := Vector2.ZERO
var _pay_wide := 60.0
var _pay_crown := true
var _pay_stars: Array[Dictionary] = []


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		# Full rect over the room. `mouse_filter` is left at a Control's own default, STOP, and
		# `texture_filter` at inherit, which is the room's NEAREST: set here they would land
		# after a step's own `_ready` and undo whatever it chose.
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		set_process(true)
	elif what == NOTIFICATION_PROCESS:
		var delta := get_process_delta_time()
		age += delta
		_drive_wake(delta)
		_drive_wanderers(delta)
		if _pay_age >= 0.0:
			_pay_age += delta
		queue_redraw()


## Start, or start over: the clock back to nought, `finished` owed again, and the player's
## hand held off until the press that brought the step up is let go. **A step's own `begin`
## calls `super.begin()` first.**
func begin() -> void:
	age = 0.0
	_done = false
	_await_release = true
	_asleep = WAKE_AFTER
	_pay_age = -1.0
	_pay_stars.clear()


## Put `count` loose bees in the air over `box` (painted pixels), off `seed`. Called from a
## step's `begin`; nought clears them. They fly on their own from then on (the base's process)
## and are drawn where the step calls `draw_wanderers`, which is behind its work.
func wanderers(count: int, box: Rect2, seed: int) -> void:
	_wander_roll.seed = seed
	_wander_box = box
	_wander_pos.resize(count)
	_wander_vel.resize(count)
	_wander_goal.resize(count)
	_wander_speed.resize(count)
	_wander_phase.resize(count)
	for k in count:
		_wander_pos[k] = _wander_spot()
		_wander_goal[k] = _wander_spot()
		_wander_speed[k] = _wander_roll.randf_range(WANDER_SPEED.x, WANDER_SPEED.y)
		_wander_phase[k] = _wander_roll.randf() * TAU
		_wander_vel[k] = (_wander_goal[k] - _wander_pos[k]).normalized() * _wander_speed[k]


func wanderer_count() -> int:
	return _wander_pos.size()


func _wander_spot() -> Vector2:
	return _wander_box.position + Vector2(
		_wander_roll.randf() * _wander_box.size.x, _wander_roll.randf() * _wander_box.size.y
	)


func _drive_wanderers(delta: float) -> void:
	for k in _wander_pos.size():
		var to := _wander_goal[k] - _wander_pos[k]
		if to.length() < WANDER_NEAR:
			_wander_goal[k] = _wander_spot()
			to = _wander_goal[k] - _wander_pos[k]
		var phase := _wander_phase[k]
		var side := to.normalized().orthogonal() * sin(age * (2.2 + fmod(phase, 1.7)) + phase) * WANDER_WEAVE
		var want := (to.normalized() * _wander_speed[k]) + side
		var v := _wander_vel[k]
		v += (want - v) * (1.0 - exp(-WANDER_STEER * delta))
		_wander_vel[k] = v
		_wander_pos[k] += v * delta


## The loose bees, wings flicking, each facing the way it flies.
func draw_wanderers(alpha := 1.0) -> void:
	for k in _wander_pos.size():
		var wings := fmod(age * 22.0 + _wander_phase[k], 2.0) < 1.0
		HiveArt.draw(self, &"bee_r" if wings else &"bee_r_rest", to_canvas(_wander_pos[k].floor()),
			&"c", _wander_vel[k].x < 0.0, alpha)


## Start the shared ending over the thing at `at` (painted px), about `wide` across: the rays
## fan up out of it, the stars come round it, and the crown drops in over it unless `crown` is
## false. Drawn where the step calls `draw_payoff`, which is over its work.
func payoff(at: Vector2, wide: float, crown := true) -> void:
	_pay_age = 0.0
	_pay_at = at
	_pay_wide = wide
	_pay_crown = crown
	_pay_stars.clear()
	var roll := RandomNumberGenerator.new()
	roll.seed = int(at.x * 7.0 + at.y * 13.0)
	for k in PAYOFF_STARS:
		var ang := roll.randf_range(-PI * 0.95, PI * 0.15)
		var reach := roll.randf_range(0.45, 1.1)
		_pay_stars.append({
			"at": at + Vector2(cos(ang) * wide * 0.6, sin(ang) * wide * 0.5) * reach,
			"born": roll.randf() * STAR_COME,
			"life": roll.randf_range(STAR_SHOW.x, STAR_SHOW.y),
			"arm": 1 + roll.randi() % 3,
		})


## Seconds since `payoff`, or negative when there is none.
func payoff_age() -> float:
	return _pay_age


## Where the crown is this moment, painted px: falling from `CROWN_FALL` over its rest with a
## bounce, then bobbing a pixel.
func payoff_crown_at() -> Vector2:
	var rest := _pay_at - Vector2(0.0, _pay_wide * CROWN_REST)
	var t := clampf(_pay_age / CROWN_DROP, 0.0, 1.0)
	var fall := (1.0 - _bounce(t)) * CROWN_FALL
	var bob := roundf(sin(maxf(_pay_age - CROWN_DROP, 0.0) * 4.0)) if t >= 1.0 else 0.0
	return rest - Vector2(0.0, fall + bob)


## The ending, on `ci` (this control by default; the queen's lens rim draws it over the glass).
func draw_payoff(ci: CanvasItem = null) -> void:
	if _pay_age < 0.0:
		return
	if ci == null:
		ci = self
	var fade := clampf(_pay_age / 0.25, 0.0, 1.0) * (1.0 - clampf((_pay_age - PAYOFF_LIFE * 0.6) / (PAYOFF_LIFE * 0.4), 0.0, 1.0))
	if fade > 0.0:
		var grow := 1.0 - pow(1.0 - clampf(_pay_age / 0.45, 0.0, 1.0), 3.0)
		for k in RAYS:
			var ang := lerpf(-PI * 0.9, -PI * 0.1, (k + 0.5) / RAYS) + sin(age * 0.7 + k * 1.3) * 0.05
			var long := lerpf(RAY_REACH.x, RAY_REACH.y, fposmod(sin(k * 12.9898) * 43758.5453, 1.0)) * grow
			_ray(ci, _pay_at + Vector2.from_angle(ang) * _pay_wide * 0.3, ang, long, fade)
	for s: Dictionary in _pay_stars:
		var t := _pay_age - float(s["born"])
		var life := float(s["life"])
		if t < 0.0 or t > life:
			continue
		var k := t / life
		var bright := sin(PI * k)
		HiveArt.star(ci, to_canvas(s["at"]), int(ceilf(float(s["arm"]) * bright)), bright)
	if _pay_crown and HiveArt.has(&"crown"):
		var at := to_canvas(payoff_crown_at().floor())
		var come := clampf(_pay_age / 0.12, 0.0, 1.0)
		var halo := Color(1.0, 0.92, 0.6, 0.45 * come)
		for d: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			HiveArt.draw(ci, &"crown", at + d * HiveArt.PIXEL, &"c", false, 1.0, CROWN_SCALE, halo)
		HiveArt.draw(ci, &"crown", at, &"c", false, come, CROWN_SCALE)


## One ray: a wedge of whole painted px from `from` along `ang`, `long` px, narrowing to a
## point and fading out along its length, a row a step so no row is laid twice.
func _ray(ci: CanvasItem, from: Vector2, ang: float, long: float, fade: float) -> void:
	var dir := Vector2.from_angle(ang)
	var step := 1.0 / maxf(absf(dir.y), 0.34)
	var d := 0.0
	while d < long:
		var u := d / long
		var w := maxf(roundf(RAY_ROOT * (1.0 - u) + (1.0 - u) * _pay_wide * 0.02), 1.0)
		var p := from + dir * d
		var ink := HiveArt.GOLD if fmod(d, 9.0) > 2.0 else HiveArt.HONEY_SHINE
		ink.a = RAY_ALPHA * fade * (1.0 - u * 0.8)
		ci.draw_rect(Rect2(to_canvas(Vector2(roundf(p.x - w * 0.5), floorf(p.y))), Vector2(w, 1.0) * HiveArt.PIXEL), ink)
		d += step


static func _bounce(t: float) -> float:
	if t < 1.0 / 2.75:
		return 7.5625 * t * t
	if t < 2.0 / 2.75:
		t -= 1.5 / 2.75
		return 7.5625 * t * t + 0.75
	if t < 2.5 / 2.75:
		t -= 2.25 / 2.75
		return 7.5625 * t * t + 0.9375
	t -= 2.625 / 2.75
	return 7.5625 * t * t + 0.984375


## Whether the player's hand has the step yet: the choosing press let go, and the wait run.
func awake() -> bool:
	return not _await_release and _asleep <= 0.0


func _drive_wake(delta: float) -> void:
	if _await_release:
		_await_release = (
			Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			or Input.is_action_pressed(&"interact") or Input.is_action_pressed(&"cast")
		)
		return
	_asleep = maxf(_asleep - delta, 0.0)


## The tool is down: the left button, or on the pad RT (`cast`) or A (`interact`) held. The
## pad's A also arrives as a synthetic left click, so either reading holds on the pad.
func tool_down() -> bool:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	return Pad.is_pad() and (
		Input.is_action_pressed(&"cast") or Input.is_action_pressed(&"interact")
	)


## The top left of the art grid in this control's canvas pixels: the room's, or the grid
## centred on this control's own size when there is no room.
func origin() -> Vector2:
	if room != null:
		return room.origin()
	return HiveArt.snap((size - HiveArt.GRID * HiveArt.PIXEL) * 0.5)


## The pointer, in painted pixels of the art grid. Not snapped, not clamped: a drag past the
## grid's edge still reads where it is.
func art_mouse() -> Vector2:
	return to_art(get_local_mouse_position())


## A point on the art grid (painted pixels) to this control's canvas pixels.
func to_canvas(p: Vector2) -> Vector2:
	return origin() + p * HiveArt.PIXEL


## A canvas point back onto the art grid, in painted pixels.
func to_art(p: Vector2) -> Vector2:
	return (p - origin()) / HiveArt.PIXEL


## Whether this step reads the stick itself. True by default: the five are hands-on, and the
## room offers the close cross to the stick only while its step says false (a payoff
## playing, say).
func pad_free() -> bool:
	return true


## What A would act on, in this control's pixels, ringed by the pad's gold ring while the
## step has the stick. Nothing by default; the queen step's lens would say itself.
func pad_mark() -> Rect2:
	return Rect2()


## The pad's stick moves the hidden pointer, the wash room's nozzle rule
## (`WashRoom._pad_aim`). Only in pad mode, so a mouse left resting is never pulled.
func pad_move(delta: float) -> void:
	if not Pad.is_pad():
		return
	Pad.move_cursor(
		Input.get_vector(&"walk_left", &"walk_right", &"walk_up", &"walk_down"), delta
	)


## Say `finished`, once. A second call — the last clump landing after the harness already
## shook it done — says nothing.
func done_once() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func is_done() -> bool:
	return _done


## A sound by name through `Sfx`, or nothing where there is no autoload or no such name
## (a harness, a recording not built yet). Returns the player, or null.
static func sound(what: StringName, db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	var sfx := Sfx.main()
	if sfx == null:
		return null
	return sfx.play(what, db, pitch)
