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

## The room this step is shown in, set before `begin`. A step with no room (a spike, a
## probe) lays its grid out centred on its own size.
var room: HiveRoom
## Seconds since `begin`: every step's own clock, for bobs and pulses.
var age := 0.0

var _await_release := false
var _asleep := 0.0
var _done := false


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
		queue_redraw()


## Start, or start over: the clock back to nought, `finished` owed again, and the player's
## hand held off until the press that brought the step up is let go. **A step's own `begin`
## calls `super.begin()` first.**
func begin() -> void:
	age = 0.0
	_done = false
	_await_release = true
	_asleep = WAKE_AFTER


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
