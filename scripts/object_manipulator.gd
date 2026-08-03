## Grab / drag / rotate / drop.
##
## The held object stays a full RigidBody2D and is steered toward the cursor, so
## it still collides with everything — you can wedge a plank against a crate.
## Gravity is disabled while held so pieces don't sag out of the hand.
##
## The grip is acceleration-limited, but only far enough to stop a mouse flick
## teleport-matching the velocity and turning the piece into an infinitely strong
## actuator. The limit is set high enough to be imperceptible in normal dragging —
## it only bites on violent flicks. Runaway momentum is held down by the speed
## cap instead, which costs nothing in responsiveness.
extends Node2D

## Higher = the piece sits closer to the cursor while you're moving. This is a
## first-order lag, not a spring, so raising it can't make the grip oscillate —
## the residual gap while dragging is roughly mouse_speed / follow_stiffness.
## At 60 a brisk 1500 px/s drag trailed the cursor by 25px, which reads as the
## piece being on a rubber band; at 160 the same drag trails by under 10px and
## the piece feels stuck to the pointer.
@export var follow_stiffness: float = 160.0
## Only bites on a flick. Has to stay well above follow_stiffness times the
## largest gap you can open up, or the stiffness above goes to waste.
@export var max_follow_speed: float = 7000.0
## Grip strength, divided by the piece's mass to get its acceleration limit.
## Lowering this makes heavy pieces sluggish — the hook for a future
## "stronger crane" upgrade, if that becomes a progression axis. Set high enough
## that even the heaviest piece keeps up with the cursor; a flick can't be
## turned into an infinitely strong actuator because max_follow_speed caps it.
@export var grip_power: float = 9000000.0
@export var rotate_stiffness: float = 60.0
@export var max_rotate_speed: float = 24.0
## Angular acceleration limit, same idea as grip_power.
@export var twist_power: float = 240000.0

@export var ghost_free_tint: Color = Color(0.75, 1.0, 0.75, 0.6)
@export var ghost_blocked_tint: Color = Color(1.0, 0.5, 0.45, 0.6)

signal grabbed(obj: BridgeObject)
signal released(obj: BridgeObject)
## The player wants this piece gone. Main handles the refund and the freeing.
signal delete_requested(obj: BridgeObject)
## Tried to put a piece down somewhere it doesn't fit.
signal release_blocked()

var held: BridgeObject = null
## Whether the held piece would fit where it is right now.
var can_place: bool = false

## Set for the length of a crossing attempt, from the car spawning to the bridge
## being put back. The strait is not the player's to touch during that window:
## anything they move is either being driven over — which turns the attempt into
## nonsense — or is missing from the layout the restore is about to reinstate, so
## it would be silently deleted the moment the wreck is cleared.
##
## Anything in hand when the lock comes on is stashed rather than dropped, since
## dropping it would place a piece that the restore then eats.
var locked: bool = false:
	set(value):
		if locked == value:
			return
		locked = value
		if locked:
			stash_held()

## Where on the body it was grabbed, in the body's local space.
var _grab_offset: Vector2 = Vector2.ZERO
var _target_rotation: float = 0.0
## Where a freshly bought piece waits before the player has moved the cursor off
## the shop panel. Vector2.INF means "follow the cursor", the normal case.
var _park_at: Vector2 = Vector2.INF

## The strait, so a piece put down in it can be heard to land. Injected by Main
## rather than looked up: the manipulator is otherwise entirely ignorant of the
## world it moves things around in, and it should stay that way.
var water: WaterBody = null


## The wheel is the camera's, always — including while a piece is held.
##
## It used to rotate the held piece, which meant the one moment you most want to
## zoom (lining a plank up against the gap it has to span) was the one moment you
## couldn't. Rotation is Q and E, which spin continuously and are the better
## control for it anyway; the wheel does one thing everywhere.
##
## There is deliberately no _input override here any more. Consuming the wheel
## ahead of the unhandled pass was the only way to stop the camera zooming
## underneath the rotation, and with nothing to consume, the camera simply sees
## every wheel event.
func _unhandled_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_try_grab(get_global_mouse_position())
				else:
					release()
			MOUSE_BUTTON_RIGHT:
				# Right-click puts a piece back in stock: the held one if there is
				# one, otherwise whatever is under the cursor.
				#
				# Recalling a placed piece used to mean picking it up first, which is
				# two gestures for one intention and — worse — the pick-up moves the
				# piece, so a mis-aimed grab disturbs the bridge you were only trying
				# to take something out of. Aiming straight at it touches nothing else.
				if not mb.pressed:
					pass
				elif held != null:
					stash_held()
					get_viewport().set_input_as_handled()
				elif _recall_at(get_global_mouse_position()):
					get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_X:
			stash_held()


## Return the held piece to stock. Main does the refunding; this only has to get
## the piece out of the hand without placing it.
func stash_held() -> void:
	if held == null:
		return
	var doomed := held
	release(true)
	delete_requested.emit(doomed)


func _physics_process(delta: float) -> void:
	if held == null or not is_instance_valid(held):
		held = null
		return

	# Continuous rotation while Q/E are down, on top of the wheel steps.
	var spin := 0.0
	if Input.is_key_pressed(KEY_Q):
		spin -= 1.0
	if Input.is_key_pressed(KEY_E):
		spin += 1.0
	_target_rotation += spin * 2.5 * delta

	# A piece bought from the panel hovers where it was spawned until the cursor
	# reaches the world. Steering it at a cursor that's still over a button would
	# drag it back to the panel and pin it against the build bounds.
	var target := get_global_mouse_position()
	if _park_at != Vector2.INF:
		if _cursor_in_world():
			_park_at = Vector2.INF
			# Re-anchor to the centre so the handover to the cursor is one clean
			# move rather than a lurch about some arbitrary corner.
			_grab_offset = Vector2.ZERO
		else:
			target = _park_at

	var grab_point := held.to_global(_grab_offset)
	var to_cursor := target - grab_point
	var wanted := (to_cursor * _closing_rate(follow_stiffness, delta)).limit_length(
		max_follow_speed
	)
	var accel_limit := grip_power / maxf(held.mass, 1.0)
	held.linear_velocity = held.linear_velocity.move_toward(wanted, accel_limit * delta)

	var angle_error := wrapf(_target_rotation - held.rotation, -PI, PI)
	var wanted_spin := clampf(
		angle_error * _closing_rate(rotate_stiffness, delta),
		-max_rotate_speed, max_rotate_speed
	)
	var spin_limit := twist_power / maxf(held.mass, 1.0)
	held.angular_velocity = move_toward(held.angular_velocity, wanted_spin, spin_limit * delta)

	can_place = _has_room(held)
	held.modulate = ghost_free_tint if can_place else ghost_blocked_tint


## Turns a follow stiffness into the velocity multiplier to use THIS step.
##
## The naive form is `gap * stiffness`, which is what this used to do, and it is
## stable only while `stiffness * delta < 2`. At 120 Hz the follow stiffness of
## 160 gives 1.33 and settles; at 60 Hz it gives 2.67 and the controller
## diverges — each step overshoots by more than the last, so a held piece rings
## harder and harder until it hits max_follow_speed and is flung across the
## strait. That is precisely what dropping the web build to 60 Hz caused, and the
## comment above follow_stiffness — "raising it can't make the grip oscillate" —
## is true of a continuous first-order lag and false of the explicit step that
## was actually being used, which is why it hid.
##
## The exponential form is the same lag solved properly over the step: it decays
## the gap by exp(-k*dt), so the multiplier can never exceed 1/dt and the piece
## can never travel further than the gap in one step. Unconditionally stable at
## any tick rate, and identical to the old behaviour as dt gets small — so the
## feel at 120 Hz, which is what everything was tuned at, does not change.
func _closing_rate(stiffness: float, delta: float) -> float:
	if delta <= 0.0:
		return stiffness
	return (1.0 - exp(-stiffness * delta)) / delta


func _try_grab(world_position: Vector2) -> void:
	var piece := _piece_at(world_position)
	if piece != null:
		_grab(piece, world_position)


## Send the piece under the cursor back to stock without picking it up first.
## Returns whether there was one. Main does the refunding, same as for a stash.
func _recall_at(world_position: Vector2) -> bool:
	var piece := _piece_at(world_position)
	if piece == null:
		return false
	UITheme.play(&"piece_click")
	delete_requested.emit(piece)
	return true


## The topmost placed piece under a point, or null.
func _piece_at(world_position: Vector2) -> BridgeObject:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_position
	params.collide_with_bodies = true
	params.collide_with_areas = false

	var hits := get_world_2d().direct_space_state.intersect_point(params, 8)
	for hit: Dictionary in hits:
		var body := hit.get("collider") as Node
		if body is BridgeObject:
			return body as BridgeObject
	return null


## Pick up a piece the player didn't click on — used so a freshly bought object
## arrives already held instead of dropping into a pile.
##
## `park` holds it at its spawn point instead of yanking it to the cursor, for the
## case where the cursor is still on the button that bought it. It takes over on
## its own once the cursor is over the world.
func grab_object(obj: BridgeObject, park: bool = false) -> void:
	if not is_instance_valid(obj):
		return
	_grab(obj, obj.global_position)
	_park_at = obj.global_position if park else Vector2.INF


## False while the cursor is over a HUD control or outside the window entirely.
func _cursor_in_world() -> bool:
	var vp := get_viewport()
	if vp.gui_get_hovered_control() != null:
		return false
	return vp.get_visible_rect().has_point(vp.get_mouse_position())


func _grab(obj: BridgeObject, world_position: Vector2) -> void:
	if held != null:
		release(true)
	held = obj
	held.is_held = true
	held.gravity_scale = 0.0
	held.sleeping = false
	held.set_ghost(true)
	# Above the water overlay (z 10), which is translucent and would otherwise
	# mute the free/blocked ghost tint the moment you carry a piece below the
	# waterline - exactly when you most need to read it.
	held.z_index = 20
	held.z_as_relative = false
	_grab_offset = held.to_local(world_position)
	_target_rotation = held.rotation
	# A deliberate click always follows the cursor; grab_object() re-parks after.
	_park_at = Vector2.INF
	UITheme.play(&"piece_click")
	grabbed.emit(held)


## True if the piece could become solid where it currently is.
func _has_room(obj: BridgeObject) -> bool:
	if obj.shape == null:
		return true
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = obj.shape
	params.transform = obj.global_transform
	params.collision_mask = BridgeObject.MASK_PLACED
	params.exclude = [obj.get_rid()]
	params.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()


## Put the piece down. Refuses unless there's physical room for it, so a drop can
## never shove the bridge apart. `force` bypasses the check for recall/deletion,
## where the piece is about to stop existing anyway.
func release(force: bool = false) -> bool:
	if held == null:
		return false
	if not force and not _has_room(held):
		release_blocked.emit()
		return false

	var obj := held
	held = null
	can_place = false
	_park_at = Vector2.INF
	# Only a deliberate placement into the water splashes. `force` covers recall
	# and deletion, where the piece is about to stop existing — a splash there
	# would be announcing the opposite of what happened.
	if not force and water != null and water.touches(obj):
		UITheme.play(&"piece_release")
	if is_instance_valid(obj):
		obj.is_held = false
		obj.gravity_scale = 1.0
		obj.set_ghost(false)
		# Back under the water overlay, so a placed piece gets submerged again.
		obj.z_index = 0
		obj.z_as_relative = true
		# Don't fling on release — keep some throw, but not a catapult.
		obj.linear_velocity = obj.linear_velocity.limit_length(600.0)
		obj.angular_velocity = clampf(obj.angular_velocity, -6.0, 6.0)
	released.emit(obj)
	return true
