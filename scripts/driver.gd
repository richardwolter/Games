## The bloke behind the wheel, and the reason the truck reads as *driven* rather
## than as a rolling object.
##
## The body is welded to the chassis; only the head moves. It hangs off a
## critically-ish damped spring driven by the chassis's own acceleration, so it
## snaps back on a landing, lolls when the truck pitches, and whips when a plank
## gives way — all of it falling out of the physics rather than from an
## animation, which means it can never be out of sync with what the truck did.
##
## Sits on top of the body sprite rather than behind it. Behind, the cab's glass
## is opaque and he would simply not be there; on top, he reads as riding in an
## open cage, which is what monster trucks actually have.
class_name Driver
extends Node2D

## How hard the head is thrown by chassis acceleration. This is the amplitude
## dial — raise it for a wobblier passenger.
@export var response: float = 0.35
## Spring pulling the head back to centre. Higher = quicker, tighter bobble.
@export var stiffness: float = 130.0
## Bleeds the wobble off. Below about 12 the head oscillates for whole seconds
## after a bump, which reads as a broken neck rather than a jolt.
@export var damping: float = 14.0
## Hard cap on the swing, in world units. The head must never leave the cab, and
## a big enough impact would otherwise put it through the roof.
@export var max_offset: float = 2.5
## Radians of tilt per world unit of horizontal swing. Tying the two together is
## what turns a sliding head into a nodding one.
@export var tilt_per_unit: float = 0.085

## Where the two sprites sit relative to this node, and how big they are.
##
## Set against the punched window opening, which lands at roughly x +2..+42 and
## y -100..-67 in the chassis's frame. He sits forward in that opening rather
## than centred in it: the driver's seat is at the front of the cab, behind the
## wheel, and centring him in the cabin instead put him visibly too far back.
## Both sprites are trimmed to their own contents by the art pipeline, so there
## is no landmark inside them to compute these from.
@export var body_offset: Vector2 = Vector2(20, -68)
@export var body_scale: float = 0.073
## The head's origin is its neck, so this is where the neck sits — the bottom of
## the window opening, not its middle, which is what the old sprite's centre
## offset was measuring.
@export var head_offset: Vector2 = Vector2(16, -74)
@export var head_radius: float = 9.0

## Fraction of the body sprite to keep, from the top. Cropping at the window
## sill keeps his legs out of the frame — they belong under the dashboard, and
## the window is the only place he is visible from.
@export_range(0.2, 1.0, 0.01) var body_visible_fraction: float = 0.62

## The cab interior, drawn behind the driver to fill the punched window.
##
## Without it the opening is a hole straight through the truck and you see sky
## where the far door should be, which reads as a missing panel rather than as a
## window. Matches the punched rectangle in tools/punch_cab_window.ps1, mapped
## into the chassis's frame.
@export var cab_interior_rect: Rect2 = Rect2(-15, -97, 46, 35)
@export var cab_interior_color: Color = Color("2b2724")

var _chassis: RigidBody2D
var _head: DriverHead

## Head displacement from its rest position, in the chassis's frame, and its
## rate of change. This pair *is* the spring.
var _offset: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _previous_chassis_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Walked up rather than taken from get_parent(): the driver hangs off the
	# SuspensionRig, which is itself a child of the chassis, and it is the
	# chassis's motion the head reacts to.
	var node: Node = get_parent()
	while node != null and _chassis == null:
		_chassis = node as RigidBody2D
		node = node.get_parent()
	if _chassis == null:
		push_error("Driver must be somewhere under the chassis RigidBody2D")
		return

	# First child, so everything else draws over it.
	var interior := Polygon2D.new()
	interior.color = cab_interior_color
	interior.polygon = PackedVector2Array([
		cab_interior_rect.position,
		Vector2(cab_interior_rect.end.x, cab_interior_rect.position.y),
		cab_interior_rect.end,
		Vector2(cab_interior_rect.position.x, cab_interior_rect.end.y),
	])
	add_child(interior)

	var body := Sprite2D.new()
	body.texture = load("res://art/driver_body.png") as Texture2D
	body.position = body_offset
	body.scale = Vector2(body_scale, body_scale)
	if body.texture != null:
		var full := body.texture.get_size()
		body.region_enabled = true
		body.region_rect = Rect2(
			Vector2.ZERO, Vector2(full.x, full.y * body_visible_fraction)
		)
	add_child(body)

	# Drawn, not a sprite — see driver_head.gd. It already has its origin at the
	# neck, so the pivot juggling the sprite needed is gone: rotating the node
	# nods the head, which is what the spring below wants.
	_head = DriverHead.new()
	_head.radius = head_radius
	_head.position = head_offset
	add_child(_head)

	_previous_chassis_velocity = _chassis.linear_velocity


func _physics_process(delta: float) -> void:
	if delta <= 0.0 or _chassis == null or _head == null:
		return

	# The head is not attached to the world, it is attached to the truck — so
	# what throws it is the truck's acceleration, expressed in the truck's own
	# frame. Using world acceleration would make it swing sideways every time
	# the truck merely tilted.
	var acceleration := (_chassis.linear_velocity - _previous_chassis_velocity) / delta
	_previous_chassis_velocity = _chassis.linear_velocity
	var local_acceleration := acceleration.rotated(-_chassis.global_rotation)

	# Newton's first law, as a puppet: the truck changes speed, the head does
	# not, so it lags in the opposite direction.
	#
	# Scaled by delta like every other term. Without it the kick is applied once
	# per physics tick rather than once per second, so at 120 Hz the head is
	# pinned against its limit permanently — and the whole effect would change
	# if the tick rate ever did.
	_velocity -= local_acceleration * response * delta
	_velocity += (-_offset * stiffness - _velocity * damping) * delta
	_offset += _velocity * delta

	if _offset.length() > max_offset:
		_offset = _offset.normalized() * max_offset
		# Kill the outward component too, or the head sits pinned at the limit
		# buzzing against it for as long as the truck keeps accelerating.
		_velocity = _velocity.slide(_offset.normalized())

	_head.position = head_offset + _offset
	_head.rotation = _offset.x * tilt_per_unit
