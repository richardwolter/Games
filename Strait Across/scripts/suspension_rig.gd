## The truck's ride, done visually: everything above the axles — bodywork, cage,
## driver — hangs off this node, and this node is sprung against the chassis.
##
## WHY NOT REAL JOINTS. A GrooveJoint2D + DampedSpringJoint2D per corner is the
## textbook answer and it does not work here: the groove stops transmitting
## drive, so the wheels never spin past about 1 rad/s against a 14.9 cap and the
## truck pogos on the spot instead of moving. Every stiffness from 45k to 600k
## behaved the same way. See the comment above the axles in car.tscn.
##
## What survives that trade is the thing the player actually sees. The wheels
## stay welded to the chassis, so driving is exactly as reliable as it was with a
## rigid axle, while the body heaves and pitches against them — which is the part
## you read as suspension. The visible tell is the gap between tyre and arch
## opening changing as the truck works, and that gap is real: the arch is drawn
## 46 units across against a 38-unit tyre precisely to leave room for it.
##
## The cost of the trade, stated plainly: the chassis collider does not move with
## the sprung body, so a bump still transfers to the physics as if the truck were
## rigid. This buys the look and the feel of travel, not its consequences.
class_name SuspensionRig
extends Node2D

## How far the body is thrown by a given chassis acceleration.
@export var heave_response: float = 0.42
## How hard it springs back. Higher = tauter, more sports car.
@export var stiffness: float = 105.0
## Bleeds the bounce off. Too low and the truck wallows for seconds after a bump.
@export var damping: float = 11.0
## Hard limit on vertical travel, in world units. Must stay under the 8 units of
## clearance between tyre and arch, or the body lifts far enough to show daylight
## where the tyre should be.
@export var max_heave: float = 6.0
## Radians of body pitch per world unit of fore-aft throw. This is what makes the
## truck squat under power and dive when it lands nose-first.
@export var pitch_per_unit: float = 0.016
@export var max_pitch_degrees: float = 7.0

var _chassis: RigidBody2D
## Displacement from rest in the chassis's frame, and its rate of change.
var _offset: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _previous_chassis_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	_chassis = get_parent() as RigidBody2D
	if _chassis == null:
		push_error("SuspensionRig must be a child of the chassis RigidBody2D")
		return
	_previous_chassis_velocity = _chassis.linear_velocity


func _physics_process(delta: float) -> void:
	if delta <= 0.0 or _chassis == null:
		return

	# Taken in the chassis's own frame, so that merely tilting the truck doesn't
	# read as a sideways shove through the springs.
	var acceleration := (_chassis.linear_velocity - _previous_chassis_velocity) / delta
	_previous_chassis_velocity = _chassis.linear_velocity
	var local_acceleration := acceleration.rotated(-_chassis.global_rotation)

	# The body carries on while the wheels change speed, so it lags the opposite
	# way — the same reason the driver's head does.
	_velocity -= local_acceleration * heave_response * delta
	_velocity += (-_offset * stiffness - _velocity * damping) * delta
	_offset += _velocity * delta

	_offset.y = clampf(_offset.y, -max_heave, max_heave)
	# Fore-aft is only ever read as pitch, never as the body sliding along the
	# frame, so it is clamped harder than the vertical.
	_offset.x = clampf(_offset.x, -max_heave, max_heave)

	position = Vector2(0, _offset.y)
	rotation = clampf(
		_offset.x * pitch_per_unit,
		-deg_to_rad(max_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)
