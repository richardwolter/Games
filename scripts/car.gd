## Two wheels pinned to a chassis. Godot has no VehicleBody2D, so drive is just
## torque on the wheel bodies — which means traction, bumps and flipping all
## fall out of the physics for free.
class_name Car
extends Node2D

## Distance from the car's origin down to the bottom of its tyres. Spawning is
## done against the shore surface, so this keeps the truck sitting on the ground
## instead of dropping in or starting buried when its size changes.
##
## The origin is the *nominal* axle line — where the springs put the wheels with
## no load on them — so this is just the tyre radius. The chassis settles down
## onto its springs a moment after spawning, which is the truck taking its own
## weight and is meant to be visible.
const RIDE_HEIGHT := 38.0

@export var drive_torque: float = 220000.0
## Wheel spin cap, in rad/s. Top speed is roughly this times the wheel radius.
@export var max_wheel_speed: float = 24.0
## Seconds to reach full throttle, so the car pulls away gently.
@export var spin_up_time: float = 1.2

@onready var chassis: RigidBody2D = $Chassis

var driving: bool = false

var _throttle: float = 0.0
var _wheels: Array[RigidBody2D] = []


func _ready() -> void:
	_wheels = [$WheelBack, $WheelFront]


func start() -> void:
	driving = true


func stop() -> void:
	driving = false
	_throttle = 0.0


func _physics_process(delta: float) -> void:
	if not driving:
		return
	_throttle = minf(_throttle + delta / spin_up_time, 1.0)
	for wheel: RigidBody2D in _wheels:
		if wheel.angular_velocity < max_wheel_speed:
			wheel.apply_torque(drive_torque * _throttle)


## True once the car is tipped far enough that it isn't driving anywhere.
func is_flipped() -> bool:
	return absf(wrapf(chassis.rotation, -PI, PI)) > 2.0
