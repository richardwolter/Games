## The gamepad: which hand the player is using, and how the pad works the boards.
##
## Issue #33, decided with `/grill-me` (2026-09-14). **The last device wins**: a pad button or
## a stick pushed past `WAKE_AXIS` puts the game in pad mode, a mouse moved `MOUSE_WAKE`
## pixels or clicked puts it back. No setting. What pad mode means on the lake — the
## reticle, the assist, the buttons — is the lake's business (`Lake._pad_*`, `PadAim`); what
## it means everywhere else is here.
##
## **Everywhere else the left stick walks the board's controls** (2026-09-26, `/grill-me`
## with Richard; supersedes the right-stick virtual cursor of 2026-09-14). Wherever a scene
## wants the pad off the lake (`pad_cursor_wanted`, asked of the current scene; a scene
## without it always does), the board on top lists its controls (`FOCUS_GROUP`, `pad_focus`
## below) and the stick or the D-pad snaps between them, or the board reads the stick itself
## (`pad_free`: the shed's walking and carrying, the wash stand's nozzle). The pad's buttons
## are still turned into the mouse and keys the boards already read: A is the left button
## (held, it drags), B is Escape, LB and RB are the wheel — real events at the picked
## control, parsed back into the engine, so nothing downstream can tell a pad from a mouse.
## The mouse's arrow is never shown in pad mode.
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

## Pad focus (2026-09-26, `/grill-me` with Richard): **on a board the left stick (or the
## D-pad) snaps from control to control**, and the right-stick pointer is only the fallback
## for a board that has not learnt it yet. A board joins by being in `FOCUS_GROUP` and
## answering `pad_focus()` with its controls, each a Dictionary in its own local pixels:
##   `box`    the control, ringed when picked
##   `at`     where the pointer goes (default the box's middle)
##   `key`    what the control is, so a pick survives a re-layout (default its index)
##   `first`  true on the control picked when the board comes up
## and optionally `pad_press(key) -> bool` (A handled by the board itself, no click),
## `pad_nudge(key, step) -> bool` (left/right spent on the control, a slider's level),
## `pad_scroll(step) -> bool` (a step off the end of a list that scrolls), `pad_hold() -> bool`
## (the stick is not to move the pick: the bind board capturing), and `pad_free() -> bool`
## with `pad_mark() -> Rect2` (the board reads the stick itself — the shed, the wash stand).
## An entry with `ring` false is picked without being ringed (the whole screen, say).
##
## **The pick drives the real pointer, hidden**: the pointer is warped onto the control and
## A is the same left click it always was, so every board's hover, sound and click are the
## mouse's own and there is nothing to keep in step. Of every board up, the one on the
## highest canvas layer and latest in the tree is the one listening.
const FOCUS_GROUP := &"pad_focus"
## How far the stick goes before it counts as a step, and the repeat while held.
const NAV_AXIS := 0.55
const NAV_FIRST := 0.32
const NAV_REPEAT := 0.13
## How much a control off to the side counts against it, against one straight ahead.
const NAV_ACROSS := 2.5
## Under the ripple, over every board.
const RING_LAYER := 39

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
## The gold ring round the picked control.
var ring: FocusRing = null

## Who the stick is picking on and what: the board, the control's key, and its middle in
## canvas pixels (what a re-layout that lost the key is matched back against).
var _focus_owner: Node = null
var _focus_key: Variant = null
var _focus_at := Vector2.INF
var _nav_dir := Vector2i.ZERO
var _nav_wait := 0.0


func _ready() -> void:
	wear_wood()
	var layer := CanvasLayer.new()
	layer.layer = RIPPLE_LAYER
	ripples = ClickRipple.new()
	layer.add_child(ripples)
	add_child(layer)
	var over := CanvasLayer.new()
	over.layer = RING_LAYER
	ring = FocusRing.new()
	over.add_child(ring)
	add_child(over)
	# F12 saves the screen for the store screenshots; debug builds only (`shot_key.gd`).
	if OS.is_debug_build():
		add_child(preload("res://scripts/shot_key.gd").new())


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
		if focus_press():
			get_viewport().set_input_as_handled()
			return
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
	var focused := mode == Mode.PAD and wanted and _drive_focus(delta)
	if not focused:
		_drop_focus()
	# **No pointer in pad mode at all** (2026-09-26): the boards are walked with the stick
	# and the rooms read it themselves, so the right-stick pointer that stood in for both is
	# gone and the arrow is only the mouse's.
	var shown := Input.MOUSE_MODE_HIDDEN if mode == Mode.PAD else Input.MOUSE_MODE_VISIBLE
	if shown != _shown:
		_shown = shown
		Input.mouse_mode = shown
	if not focused:
		_cursor = Vector2.INF


## Move the pointer by a stick: the left stick carrying a piece in the shed
## (`ShedRoom._carry_with_pad`) and aiming the wash room's nozzle (`WashRoom._pad_aim`).
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
	if ripples == null or (_shown != Input.MOUSE_MODE_VISIBLE and _focus_owner == null):
		return
	ripples.splash(get_viewport().get_mouse_position())


func _key(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.device = SYNTH_DEVICE
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


## A on the picked control, when its board handles the press itself. True when it did.
func focus_press() -> bool:
	return (
		_focus_owner != null and is_instance_valid(_focus_owner)
		and _focus_owner.has_method(&"pad_press")
		and bool(_focus_owner.call(&"pad_press", _focus_key))
	)


## The key of the picked control, or null.
func focus_key() -> Variant:
	return _focus_key


## The board listening to the stick: of those up that offer controls or want the stick for
## themselves (`pad_free`), the one on the highest canvas layer, then the latest in the tree
## (a board opened over another is its child or its later sibling). Null when none is.
func focus_owner() -> Node:
	var best: Node = null
	var best_layer := -(1 << 30)
	for node: Node in get_tree().get_nodes_in_group(FOCUS_GROUP):
		var item := node as CanvasItem
		if item == null or not item.is_visible_in_tree():
			continue
		var holder := item.get_canvas_layer_node()
		var layer := holder.layer if holder != null else 0
		if best != null and (layer < best_layer or (layer == best_layer and not node.is_greater_than(best))):
			continue
		if not _is_free(node) and (node.call(&"pad_focus") as Array).is_empty():
			continue
		best = node
		best_layer = layer
	return best


## A board that wants the stick for itself right now: the shed while the angler walks or a
## piece is carried, the wash stand while a find is on it. No stops and no pointer of ours;
## the board reads the stick, and `pad_mark` may say what A would act on.
static func _is_free(node: Node) -> bool:
	return node.has_method(&"pad_free") and bool(node.call(&"pad_free"))


## The board's controls in canvas pixels, keyed.
func _focus_entries(owner: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var to := (owner as CanvasItem).get_global_transform_with_canvas()
	var list: Array = owner.call(&"pad_focus")
	for i in list.size():
		var entry: Dictionary = list[i]
		var box: Rect2 = to * (entry["box"] as Rect2)
		var at: Vector2 = box.get_center()
		if entry.has("at"):
			at = to * (entry["at"] as Vector2)
		out.append({
			"box": box, "at": at, "key": entry.get("key", i),
			"first": bool(entry.get("first", false)), "ring": bool(entry.get("ring", true)),
		})
	return out


## One frame of the stick picking. False when no board wants the stick.
func _drive_focus(delta: float) -> bool:
	var owner := focus_owner()
	if owner == null:
		return false
	if _is_free(owner):
		_focus_owner = owner
		_focus_key = null
		_focus_at = Vector2.INF
		var mark := Rect2()
		if owner.has_method(&"pad_mark"):
			mark = owner.call(&"pad_mark")
			if mark.size != Vector2.ZERO:
				mark = (owner as CanvasItem).get_global_transform_with_canvas() * mark
		ring.box = mark
		_nav_dir = Vector2i(9, 9)
		return true
	var entries := _focus_entries(owner)
	var index := -1
	if owner == _focus_owner:
		index = _find_again(entries)
	if index < 0:
		index = 0
		for i in entries.size():
			if entries[i]["first"]:
				index = i
				break
		# A board coming up does not take a stick already held as a step.
		_nav_dir = Vector2i(9, 9)
	_focus_owner = owner

	var held := owner.has_method(&"pad_hold") and bool(owner.call(&"pad_hold"))
	var dir := Vector2i.ZERO if held else nav_step(delta)
	if dir != Vector2i.ZERO:
		var spent := false
		if dir.y == 0 and owner.has_method(&"pad_nudge"):
			spent = bool(owner.call(&"pad_nudge", entries[index]["key"], dir.x))
		if not spent:
			var next := step_from(entries, index, Vector2(dir))
			# Nothing that way on a list that scrolls: scroll it, and look again.
			if next < 0 and owner.has_method(&"pad_scroll") and bool(owner.call(&"pad_scroll", dir.y)):
				spent = true
			elif next >= 0:
				index = next
		if spent:
			entries = _focus_entries(owner)
			index = _find_again(entries)
			if index < 0:
				index = 0

	var entry: Dictionary = entries[index]
	_focus_key = entry["key"]
	_focus_at = (entry["box"] as Rect2).get_center()
	ring.box = entry["box"] if entry["ring"] else Rect2()
	var at: Vector2 = entry["at"]
	if get_viewport().get_mouse_position().distance_to(at) > 0.5:
		_warped_at = Time.get_ticks_msec()
		get_viewport().warp_mouse(at)
	return true


## The control picked last frame in a fresh list: by key, else the nearest to where it was.
func _find_again(entries: Array[Dictionary]) -> int:
	for i in entries.size():
		if entries[i]["key"] == _focus_key:
			return i
	if _focus_at == Vector2.INF:
		return -1
	var index := -1
	var nearest := INF
	for i in entries.size():
		var gap := (entries[i]["box"] as Rect2).get_center().distance_to(_focus_at)
		if gap < nearest:
			nearest = gap
			index = i
	return index


func _drop_focus() -> void:
	_focus_owner = null
	_focus_key = null
	_focus_at = Vector2.INF
	if ring != null:
		ring.box = Rect2()


## The left stick or the D-pad as one step in four directions, a held push repeating: the
## first step at once, the next after `NAV_FIRST`, then every `NAV_REPEAT`. A push already
## held when a board comes up (`_nav_dir` poisoned) waits to be let go.
func nav_step(delta: float) -> Vector2i:
	var push := Vector2.ZERO
	for pad: int in Input.get_connected_joypads():
		var stick := Vector2(
			Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)
		)
		if stick.length() > push.length():
			push = stick
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT):
			push = Vector2.LEFT
		elif Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT):
			push = Vector2.RIGHT
		elif Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP):
			push = Vector2.UP
		elif Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN):
			push = Vector2.DOWN
	return nav_from(push, delta)


## `nav_step` given the push, for the harness.
func nav_from(push: Vector2, delta: float) -> Vector2i:
	var dir := Vector2i.ZERO
	if push.length() >= NAV_AXIS:
		if absf(push.x) > absf(push.y):
			dir = Vector2i(int(signf(push.x)), 0)
		else:
			dir = Vector2i(0, int(signf(push.y)))
	if dir == Vector2i.ZERO:
		_nav_dir = Vector2i.ZERO
		return Vector2i.ZERO
	if _nav_dir == Vector2i(9, 9):
		return Vector2i.ZERO
	if dir != _nav_dir:
		_nav_dir = dir
		_nav_wait = NAV_FIRST
		return dir
	_nav_wait -= delta
	if _nav_wait > 0.0:
		return Vector2i.ZERO
	_nav_wait = NAV_REPEAT
	return dir


## The control a step lands on: ahead of this one in `dir`, the nearest, counting sideways
## distance `NAV_ACROSS` times over. -1 when nothing lies that way.
static func step_from(entries: Array, from: int, dir: Vector2) -> int:
	var here := (entries[from]["box"] as Rect2).get_center()
	var best := -1
	var score := INF
	for i in entries.size():
		if i == from:
			continue
		var gap := (entries[i]["box"] as Rect2).get_center() - here
		var along := gap.dot(dir)
		if along <= 1.0:
			continue
		var s := along + absf(gap.cross(dir)) * NAV_ACROSS
		if s < score:
			score = s
			best = i
	return best
