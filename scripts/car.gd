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

## Surface friction that earns full drive torque. Wood sits here, so a plank or
## crate deck drives exactly as the truck always has and everything else is
## measured against it.
@export var reference_grip: float = 0.9
## Floor on the grip penalty. Bare steel is meant to be a genuine struggle, not a
## dead stop — a truck that simply cannot move is a bug report, not a joke.
@export_range(0.0, 1.0, 0.05) var min_grip_factor: float = 0.35
## Friction assumed for a body that carries no PhysicsMaterial at all. Nothing
## the truck can drive on should be in that state any more, so this is a floor
## for anything added later rather than a value the game relies on.
@export var default_surface_grip: float = 0.8

## How much faster than the truck a tyre may turn before it counts as spinning,
## in world units per second. Some slip is normal under acceleration.
@export var slip_tolerance: float = 90.0
## Slip beyond the tolerance at which torque has fallen all the way to
## spin_torque_floor. A spinning tyre puts almost nothing into the ground, and
## the point of modelling it is that the player SEES the wheel racing while the
## truck goes nowhere.
@export var slip_range: float = 260.0
@export_range(0.0, 1.0, 0.05) var spin_torque_floor: float = 0.15

## Pitch the engine sound plays at with the wheels stopped and with them at
## their cap. Under 1.0 at rest because the recording is of a truck already
## moving, so its own pitch is somewhere in the middle of the range.
const IDLE_PITCH := 0.75
const FULL_PITCH := 1.55
## How fast the heard revs chase the real ones, per second. Wheel speed is noisy
## over a bridge made of barrels — fed straight to the pitch it warbles — and
## this is the exponential rate that smooths it. Applied as
## 1 - exp(-delta * rate) so it behaves the same at 60 fps on the web build as
## at whatever the desktop is running.
const REV_SMOOTHING := 8.0
## How long a wheel-speed reading is taken over. Several physics ticks on either
## build (120Hz desktop, 60 web), and short enough that the engine still answers
## the throttle rather than trailing it.
const REV_WINDOW := 0.05

@onready var chassis: RigidBody2D = $Chassis

var driving: bool = false

## The strait, so the tyres can drip after coming out of it. Set by whoever
## spawns the truck; without it the wheels simply stay dry.
var water: WaterBody = null

var _throttle: float = 0.0
var _wheels: Array[RigidBody2D] = []
var _radii: PackedFloat32Array = PackedFloat32Array()
var _drips: Array[WheelDrip] = []

## Smoothed revs, 0..1, and last frame's wheel angles to measure them from.
var _revs: float = 0.0
var _last_angles: PackedFloat32Array = PackedFloat32Array()
## Time since the angles were last read, so a frame in which the wheels have not
## moved yet is waited out rather than counted as a stop.
var _rev_elapsed: float = 0.0
## Whether this car is the one currently making the engine noise. There is one
## engine player for the whole game and there can be more than one truck in a
## scene — the parked one on the shore, a replay puppet — so a car only silences
## the engine if it was the car that started it.
var _engine_on: bool = false


func _ready() -> void:
	_wheels = [$WheelBack, $WheelFront]
	for wheel: RigidBody2D in _wheels:
		var radius := float(wheel.get(&"radius"))
		_radii.append(radius)
		_drips.append(WheelDrip.new(wheel, radius))
		# Needed so the wheel can be asked what it is standing on. Four is well
		# clear of what a tyre touches at once even wedged into a gap between
		# pieces, and reporting contacts is only paid for on the two wheels.
		wheel.max_contacts_reported = 4
		wheel.contact_monitor = true
		_last_angles.append(wheel.rotation)


## Dripping is decoration and runs on the render clock, not with the drive
## torque. It also has to keep running on the replay's puppet truck, which has
## its physics process switched off precisely so that nothing simulates it.
func _process(delta: float) -> void:
	_update_engine(delta)
	if water == null:
		return
	for drip: WheelDrip in _drips:
		drip.update(delta, water)


## Keeps the engine sound in step with the wheels.
##
## On _process for the same reason the drips are: _physics_process returns early
## when the truck isn't driving, so it could never fade the engine back out, and
## the web build runs physics at half the desktop's rate — a note that ramped in
## per tick would ramp at half speed on itch.
func _update_engine(delta: float) -> void:
	if delta <= 0.0:
		return
	var audio := get_node_or_null(^"/root/Audio")
	if audio == null:
		return

	var target := _measure_revs(delta)
	# Exponential, so the smoothing is the same at 60fps on the web build as at
	# 144 on a desktop. A raw reading warbles: wheel speed jitters over a deck
	# made of barrels, and pitch tracks every bit of it.
	_revs = lerpf(_revs, target, 1.0 - exp(-delta * REV_SMOOTHING))

	# A parked truck is a truck with the engine off, and there is usually one
	# sitting on the shore. The revs are what tell it apart from a replay puppet,
	# whose flag is never set but whose wheels are visibly turning.
	var wants_engine := driving or _revs > 0.02
	if wants_engine and not _engine_on:
		_engine_on = true
		audio.engine_start()
	elif not wants_engine and _engine_on:
		_engine_on = false
		audio.engine_stop()

	if _engine_on:
		audio.engine_pitch(lerpf(IDLE_PITCH, FULL_PITCH, _revs))


## How fast the wheels are turning, 0..1 against their cap.
##
## Measured from how far the wheels have actually rotated rather than from
## angular_velocity, which is zero on a replay's puppet truck: its bodies are
## frozen static and teleported, so they turn without the physics server ever
## being told they moved. Reading the angle works for both, and means a replay
## sounds like the attempt it is a replay of.
##
## Wheel speed rather than road speed on purpose, and free: a wheel racing in a
## gap while the truck goes nowhere is heard as revs, which is what it would be.
func _measure_revs(delta: float) -> float:
	_rev_elapsed += delta
	# Measured over a window rather than per frame. The angles only change when
	# physics runs, and rendering is faster than physics — so a per-frame reading
	# is a real number divided by whichever fraction of a tick the frame happened
	# to cover, which comes out anywhere between half the true speed and twice it.
	# Over a window several ticks long that error washes out.
	if _rev_elapsed < REV_WINDOW:
		return _revs

	var turned := 0.0
	for i: int in _wheels.size():
		turned = maxf(turned, absf(wrapf(_wheels[i].rotation - _last_angles[i], -PI, PI)))
	# A wheel at the speed cap turns about a radian and a half in a window, so
	# anything that could wrap past PI is a hitch rather than a fast wheel, and
	# reads as slow. Rare enough, and smoothed, that it is not worth guarding.
	var speed := turned / _rev_elapsed
	_sync_angles()
	return clampf(speed / max_wheel_speed, 0.0, 1.0)


func _sync_angles() -> void:
	_rev_elapsed = 0.0
	for i: int in _wheels.size():
		_last_angles[i] = _wheels[i].rotation


func start() -> void:
	driving = true


func stop() -> void:
	driving = false
	_throttle = 0.0


## A truck is usually removed rather than stopped — a failed attempt is cleared
## away, a replay ends and its puppets go — and the engine player outlives it, so
## it has to be handed back or it runs on over an empty strait.
func _exit_tree() -> void:
	if not _engine_on:
		return
	_engine_on = false
	var audio := get_node_or_null(^"/root/Audio")
	if audio != null:
		audio.engine_stop()


func _physics_process(delta: float) -> void:
	if not driving:
		return
	_throttle = minf(_throttle + delta / spin_up_time, 1.0)
	var truck_speed := chassis.linear_velocity.x
	for i: int in _wheels.size():
		var wheel: RigidBody2D = _wheels[i]
		if wheel.angular_velocity >= max_wheel_speed:
			continue
		var traction := _traction(wheel, _radii[i], truck_speed)
		if traction <= 0.0:
			continue
		wheel.apply_torque(drive_torque * _throttle * traction)


## What fraction of full torque this wheel can actually put down, from what it is
## standing on and how badly it is already spinning.
##
## The tyre's own PhysicsMaterial still does the real contact work in the solver;
## this sits on top of it. Friction alone would only cap how hard the truck can
## push before it slides, and with this much torque available the wheel just
## reaches its speed cap while spinning and the truck creeps along looking
## perfectly normal. Scaling the torque by the surface is what makes a steel deck
## read as steel.
func _traction(wheel: RigidBody2D, radius: float, truck_speed: float) -> float:
	var bodies := wheel.get_colliding_bodies()
	if bodies.is_empty():
		# In the air. Revving up mid-jump did nothing but spin the wheel, which
		# then landed already at speed and kicked the truck sideways.
		return 0.0

	var grip := 0.0
	for body: Node in bodies:
		var pm: PhysicsMaterial = body.get(&"physics_material_override")
		grip = maxf(grip, pm.friction if pm != null else default_surface_grip)
	var factor := clampf(grip / reference_grip, min_grip_factor, 1.0)

	# Slip is how much faster the contact patch is travelling than the truck. A
	# little is how a tyre accelerates at all; a lot is a wheel racing in place.
	var slip := wheel.angular_velocity * radius - truck_speed
	if slip > slip_tolerance:
		var over := clampf((slip - slip_tolerance) / slip_range, 0.0, 1.0)
		factor *= lerpf(1.0, spin_torque_floor, over)
	return factor


## True once the car is tipped far enough that it isn't driving anywhere.
func is_flipped() -> bool:
	return absf(wrapf(chassis.rotation, -PI, PI)) > 2.0
