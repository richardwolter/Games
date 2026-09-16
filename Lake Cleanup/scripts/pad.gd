## The gamepad: which hand the player is using, and the pointer the pad drives over menus.
##
## Issue #33, decided with `/grill-me` (2026-09-14). **The last device wins**: a pad button or
## a stick pushed past `WAKE_AXIS` puts the game in pad mode, a mouse moved `MOUSE_WAKE`
## pixels or clicked puts it back. No setting. What pad mode means on the lake — the
## reticle, the assist, the buttons — is the lake's business (`Lake._pad_*`, `PadAim`); what
## it means everywhere else is here.
##
## **Everywhere else is a virtual cursor, by decision.** The boards are drawn and take the
## mouse — the shop, the tree screen, the shed, the settings, the main menu, the farewell —
## and teaching each of them focus navigation is six jobs. So wherever a scene wants a
## pointer (`pad_cursor_wanted`, asked of the current scene; a scene without it always wants
## one), the right stick moves the real mouse pointer and the pad's buttons are turned into
## the mouse and keys those boards already read: A is the left button (held, it drags),
## B is Escape, LB and RB are the wheel. Real events, parsed back into the engine, so
## nothing downstream can tell a pad from a mouse and there is nothing to keep in step.
##
## The events made here carry `SYNTH_DEVICE`, which is how the tracker tells them from a
## real mouse. A warp makes a motion event too and there is no tagging that, so motion for
## `WARP_QUIET_MS` after a warp is not counted as the mouse being picked up.
extends Node

enum Mode { MOUSE, PAD }

signal mode_changed(mode: Mode)

## The device id on every event this node makes.
const SYNTH_DEVICE := 0x5AD

## How far a stick or trigger has to go before it counts as the pad being picked up. Past
## any resting drift, so a pad lying on the desk does not take the game off the mouse.
const WAKE_AXIS := 0.5

## How far the mouse has to move, in screen pixels, before it counts as picked up. A desk
## nudged under a mouse nobody is holding is not a switch.
const MOUSE_WAKE := 3.0

## How long after a warp the motion it causes is ignored, in milliseconds.
const WARP_QUIET_MS := 80

## The virtual cursor's speed at full push, in window heights a second, and the curve on the
## push: over one, so a small push is fine placement and a full one crosses the board.
const CURSOR_SPEED := 1.1
const CURSOR_CURVE := 1.8

## The pointer itself: a wooden arrow in the menus' oak, black-outlined, drawn by
## `tools/build_cursor.py` (2026-09-16, `/grill-me` with Richard).
##
## **One arrow, everywhere, set once at boot** — menu, lake, shed, every board. It lives here
## because this is already the one node that decides what the pointer does: whether it is
## shown at all, and where it is while the pad drives it. What it looks like belongs beside
## those. The shapes Godot swaps in for itself (the I-beam over a `LineEdit`, the hand over a
## link) are left stock, by decision: the game has one clickable language and it is drawn
## boards, so there is nothing for a second wooden shape to mean.
const CURSOR_ART := "res://assets/cursor.png"

## Where the tip is in the picture, in its own pixels: one art pixel in from each edge for
## the black outline, at the size the art was baked at. `build_cursor.py` prints it; the two
## must agree or every click lands off the point of the arrow.
const CURSOR_TIP := Vector2(2.0, 2.0)

## The click's own answer is a ripple on a layer over everything (`ClickRipple`), not
## anything the arrow wears. **Retired, by decision** (2026-09-16, Richard): a bead of lake
## water baked into a second cursor picture and swapped in while the button was down. A
## hardware cursor can hold a pose but not an animation, and the pose read as decoration
## hanging off the pointer rather than as an answer to the press.
##
## Above the HUD's own layers, and above the pigeons at 21 and the finds' beams at 20: a
## ripple under the pointer is over whatever the pointer is over.
const RIPPLE_LAYER := 40

var mode: Mode = Mode.MOUSE

var _cursor := Vector2.INF
var _warped_at: int = -100000
## A press was sent for A and its release is owed, whatever has opened or closed since.
var _holding: bool = false
## Events waiting for `_process` to parse them. Not parsed inside `_input`, which is the
## middle of dispatching the pad's own event.
var _queue: Array[InputEvent] = []
var _shown := Input.MOUSE_MODE_VISIBLE
## The layer the click's ripple is drawn on. Built here and kept for the session, so it
## survives every scene change the way the pointer it answers for does.
var ripples: ClickRipple = null


func _ready() -> void:
	wear_wood()
	var layer := CanvasLayer.new()
	layer.layer = RIPPLE_LAYER
	ripples = ClickRipple.new()
	layer.add_child(ripples)
	add_child(layer)


## Put the wooden arrow on. Missing art leaves the system pointer alone rather than
## clearing it — a game with no cursor at all is worse than a game with the stock one, and
## the art can be missing, the way every placeholder in this project allows for.
func wear_wood() -> void:
	if not ResourceLoader.exists(CURSOR_ART):
		return
	var art := load(CURSOR_ART) as Texture2D
	if art == null:
		return
	Input.set_custom_mouse_cursor(art, Input.CURSOR_ARROW, CURSOR_TIP)


func is_pad() -> bool:
	return mode == Mode.PAD


## Whether the scene up now wants the pad to drive a pointer. The lake wants one only while
## a board is open; the menu always does.
func cursor_wanted() -> bool:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method(&"pad_cursor_wanted"):
		return bool(scene.call(&"pad_cursor_wanted"))
	return true


func set_mode(to: Mode) -> void:
	if to == mode:
		return
	mode = to
	_cursor = Vector2.INF
	mode_changed.emit(mode)


func _input(event: InputEvent) -> void:
	# The ripple is rung before the synthetic events are dropped, so the pad's own A button
	# rings the water exactly as a mouse click does. Everything below this is about which
	# device is being held; this is about answering the press whichever it was.
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			ring_water()
	if event.device == SYNTH_DEVICE:
		return
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			set_mode(Mode.PAD)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= WAKE_AXIS:
			set_mode(Mode.PAD)
	elif event is InputEventMouseMotion:
		if Time.get_ticks_msec() - _warped_at >= WARP_QUIET_MS \
				and (event as InputEventMouseMotion).relative.length() >= MOUSE_WAKE:
			set_mode(Mode.MOUSE)
		return
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			set_mode(Mode.MOUSE)
		return

	if not (event is InputEventJoypadButton):
		return
	var button := event as InputEventJoypadButton
	# A release owed is paid even if the board it was pressed on has gone: a drag let go of
	# over the lake still has to be let go of.
	if not button.pressed and _holding and button.is_action(&"interact"):
		_holding = false
		_queue.append(_click(MOUSE_BUTTON_LEFT, false))
		get_viewport().set_input_as_handled()
		return
	if mode != Mode.PAD or not cursor_wanted() or not button.pressed:
		return
	if button.is_action(&"interact"):
		_holding = true
		_queue.append(_click(MOUSE_BUTTON_LEFT, true))
	elif button.is_action(&"pad_back"):
		_queue.append(_key(KEY_ESCAPE, true))
		_queue.append(_key(KEY_ESCAPE, false))
	elif button.is_action(&"zoom_in"):
		_queue.append(_click(MOUSE_BUTTON_WHEEL_UP, true))
		_queue.append(_click(MOUSE_BUTTON_WHEEL_UP, false))
	elif button.is_action(&"zoom_out"):
		_queue.append(_click(MOUSE_BUTTON_WHEEL_DOWN, true))
		_queue.append(_click(MOUSE_BUTTON_WHEEL_DOWN, false))
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var pending := _queue
	_queue = []
	for event in pending:
		Input.parse_input_event(event)

	var wanted := cursor_wanted()
	var shown := Input.MOUSE_MODE_HIDDEN if mode == Mode.PAD and not wanted else Input.MOUSE_MODE_VISIBLE
	if shown != _shown:
		_shown = shown
		Input.mouse_mode = shown

	if mode != Mode.PAD or not wanted:
		_cursor = Vector2.INF
		return
	move_cursor(Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down"), delta)


## Move the pointer by a stick. The right stick's job everywhere, and the left stick's too
## while a piece is in hand in the shed (`ShedRoom._carry_with_pad`).
func move_cursor(stick: Vector2, delta: float) -> void:
	if stick == Vector2.ZERO:
		return
	var view := get_viewport().get_visible_rect()
	if _cursor == Vector2.INF:
		_cursor = get_viewport().get_mouse_position()
	var push := pow(minf(stick.length(), 1.0), CURSOR_CURVE)
	_cursor += stick.normalized() * push * CURSOR_SPEED * view.size.y * delta
	_cursor = _cursor.clamp(view.position, view.end - Vector2.ONE)
	_warped_at = Time.get_ticks_msec()
	get_viewport().warp_mouse(_cursor)


## A mouse button event at the pointer, in the window's own pixels — the space a real one
## arrives in, before the stretch is taken off it.
func _click(index: MouseButton, pressed: bool) -> InputEventMouseButton:
	var at := get_viewport().get_mouse_position()
	var window := get_tree().root.get_final_transform() * at
	var event := InputEventMouseButton.new()
	event.device = SYNTH_DEVICE
	event.button_index = index
	event.pressed = pressed
	event.position = window
	event.global_position = window
	if index == MOUSE_BUTTON_LEFT and pressed:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	if index == MOUSE_BUTTON_WHEEL_UP or index == MOUSE_BUTTON_WHEEL_DOWN:
		event.factor = 1.0
	return event


## Ring the water where the pointer is. **Nothing is drawn when there is no pointer to draw
## it under** — pad mode on the bare lake hides the mouse, and a ripple opening on empty
## water where nobody is pointing is a splash from nowhere.
func ring_water() -> void:
	# `_shown` rather than `Input.mouse_mode`: this node is what decided whether the pointer
	# is up, and asking the engine back is a second answer that can differ from it.
	if ripples == null or _shown != Input.MOUSE_MODE_VISIBLE:
		return
	ripples.splash(get_viewport().get_mouse_position())


func _key(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.device = SYNTH_DEVICE
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event
