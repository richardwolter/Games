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

## CHARGE! — the one shove the player gets per attempt.
##
## A multiplier on drive torque with the speed cap lifted to match, applied to
## BOTH wheels. Torque rather than a straight push on the chassis, so the boost
## still has to go through the tyres: charging on a steel deck spins the wheels
## and gets you nothing, which keeps the surface rules the game already has
## worth caring about.
##
## The cap has to move with the torque. Extra torque under an unchanged cap only
## reaches the same top speed sooner, which is a fine thing to feel for half a
## second and nothing at all on a bridge you are already crawling across.
@export var charge_seconds: float = 2.5
@export var charge_torque_multiplier: float = 2.4
@export var charge_speed_multiplier: float = 1.35
## Seconds the boost takes to arrive, and to leave. Both non-zero on purpose: a
## step change in torque on a truck standing on a bridge made of barrels is a
## shove that can throw the bridge rather than the truck.
@export var charge_ramp: float = 0.25
@export var charge_fade: float = 0.8

## Airborne thrust, in multiples of the truck's own weight. Above 1.0 the rocket
## beats gravity, so a charge spent at the top of a jump visibly lifts rather
## than merely falling more slowly — which is the difference between reading as a
## rocket and reading as a bug.
@export var charge_air_thrust: float = 1.15
## How far off level the thrust may point, either way. See _rocket().
@export var charge_air_cone_degrees: float = 40.0

## How hard the nose is held down while charging, as a rate: the fraction of the
## chassis's pitch-up spin cancelled per second.
##
## Needed because the drive is a couple. Torque on a wheel pushes back through
## the axle pin into the chassis, and on a truck with this much ground clearance
## the boost simply stands it up and loops it over backwards — a wheelie is
## funny once and is not what the button is for. See _hold_nose_down().
@export var nose_hold_rate: float = 9.0

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
@onready var exhaust: ExhaustFlame = $Chassis/SuspensionRig/Exhaust

var driving: bool = false

## The strait, so the tyres can drip after coming out of it. Set by whoever
## spawns the truck; without it the wheels simply stay dry.
var water: WaterBody = null

## The charge, on the electric truck. Null is the ordinary diesel one, and every
## path below is then exactly what it always was. Set before the truck enters the
## tree, so _ready() can wire the splash.
var battery: Battery = null
## Paint only. Set on the parked truck too, which never gets a live battery — the
## shore has to show which truck START is about to send.
var battery_powered: bool = false

## The charge, spent or not. Per attempt without a timer to reset, because a
## truck is built fresh for every attempt and thrown away at the end of it — the
## "once per crossing" rule is the object's lifetime, not a rule anything has to
## enforce.
var charge_used: bool = false

var _throttle: float = 0.0
## Seconds of boost left to run.
var _charge_left: float = 0.0
## What the whole truck weighs, in newtons — every body's mass against the
## project's gravity. The rocket is quoted in multiples of it, so the thrust
## follows the truck if it is ever made heavier and the export keeps meaning what
## it says. Worked out once, in _ready(), rather than read off ProjectSettings on
## every tick of every boost.
var _weight: float = 0.0
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

	var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	_weight = chassis.mass * gravity
	for wheel: RigidBody2D in _wheels:
		_weight += wheel.mass * gravity

	_tint_for_power()
	# The chassis going in the water is what costs a battery truck its charge.
	# The chassis specifically, not the wheels: the tyres are in and out of the
	# strait constantly on any bridge worth driving over, and draining on those
	# would make the whole idea unplayable rather than tense.
	if battery != null and water != null:
		water.body_entered.connect(_on_water_entered)


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


## Can the player still spend the charge? False on a truck that is not driving,
## one that has already used it, and one whose battery has run flat — there is
## nothing to boost when the motor is off.
func charge_ready() -> bool:
	return driving and not charge_used and (battery == null or not battery.is_empty())


func charge_active() -> bool:
	return _charge_left > 0.0


## Is either tyre touching anything? The charge already asks this per wheel to
## choose between drive and thrust; this is the same question for anything that
## only needs to know whether the truck is currently flying.
func is_grounded() -> bool:
	for wheel: RigidBody2D in _wheels:
		if not wheel.get_colliding_bodies().is_empty():
			return true
	return false


## Spend it. Returns false if there was nothing to spend, so the caller can tell
## a press that did something from one that did not.
func trigger_charge() -> bool:
	if not charge_ready():
		return false
	charge_used = true
	_charge_left = charge_seconds
	exhaust.light()
	return true


func stop() -> void:
	driving = false
	_throttle = 0.0


## A truck is usually removed rather than stopped — a failed attempt is cleared
## away, a replay ends and its puppets go — and the engine player outlives it, so
## it has to be handed back or it runs on over an empty strait.
## A cold blue-green wash over the whole truck. Placeholder paint rather than a
## second car scene: park(), _bodies_of() and the replay's puppets all assume one
## truck scene, and a variant .tscn would have to be kept in step with every one
## of them for what is currently a colour.
func _tint_for_power() -> void:
	if chassis != null:
		chassis.modulate = Color(0.72, 0.94, 0.98) if battery_powered else Color.WHITE


func _on_water_entered(body: Node) -> void:
	if battery != null and body == chassis:
		battery.take_splash()


func _exit_tree() -> void:
	# The water outlives the truck — a truck is freed after every attempt — so the
	# connection has to be handed back or the signal keeps a dead node alive.
	if battery != null and water != null and water.body_entered.is_connected(_on_water_entered):
		water.body_entered.disconnect(_on_water_entered)
	if not _engine_on:
		return
	_engine_on = false
	var audio := get_node_or_null(^"/root/Audio")
	if audio != null:
		audio.engine_stop()


func _physics_process(delta: float) -> void:
	if not driving:
		return

	# Ticked before the battery is checked, so a charge spent on the last of the
	# power runs its course rather than freezing half-used when the motor cuts.
	var boost := _charge_level(delta)

	# Flat means no drive, not an instant end to the attempt. The truck coasts,
	# rolls back down whatever it was climbing, and the crossing manager's stall
	# timer calls it — which is both the funnier outcome and one that needs no new
	# result code, no new banner and no new branch anywhere else.
	if battery != null:
		battery.tick(delta)
		if battery.is_empty():
			_throttle = 0.0
			return

	_throttle = minf(_throttle + delta / spin_up_time, 1.0)
	var torque := drive_torque * lerpf(1.0, charge_torque_multiplier, boost)
	var speed_cap := max_wheel_speed * lerpf(1.0, charge_speed_multiplier, boost)
	var truck_speed := chassis.linear_velocity.x
	for i: int in _wheels.size():
		var wheel: RigidBody2D = _wheels[i]
		if wheel.angular_velocity >= speed_cap:
			continue
		var traction := _traction(wheel, _radii[i], truck_speed)
		if traction <= 0.0:
			continue
		wheel.apply_torque(torque * _throttle * traction)

	if boost > 0.0:
		# What the charge does depends on what the truck is standing on, and the
		# two cases are opposites: on the ground it is drive that has to be kept
		# from standing the truck up, in the air it is thrust with nothing to
		# drive against at all.
		var back_down := not _wheels[0].get_colliding_bodies().is_empty()
		var front_down := not _wheels[1].get_colliding_bodies().is_empty()
		if not back_down and not front_down:
			_rocket(boost)
		elif back_down and not front_down:
			_hold_nose_down(boost)


## How much of the charge is on this tick, 0..1, and spends it as it goes.
##
## Eased in and out rather than switched. The truck is usually standing on
## something loose when the button is pressed, and a step change in drive torque
## kicks the deck out from under it — the boost should throw the TRUCK.
func _charge_level(delta: float) -> float:
	if _charge_left <= 0.0:
		return 0.0
	_charge_left = maxf(_charge_left - delta, 0.0)
	# The flame is put out from here rather than from a timer of its own, so the
	# fire is showing exactly while there is boost being applied — including when
	# a boost ends early because the truck was freed or the battery died.
	if _charge_left <= 0.0:
		exhaust.douse()
	var elapsed := charge_seconds - _charge_left
	var rise := clampf(elapsed / maxf(charge_ramp, 0.001), 0.0, 1.0)
	var fall := clampf(_charge_left / maxf(charge_fade, 0.001), 0.0, 1.0)
	return smoothstep(0.0, 1.0, minf(rise, fall))


## Holds the front wheel down while the charge is on.
##
## The drive is a couple: torque into a wheel comes back through the axle pin as
## an equal torque on the chassis, trying to rotate the truck about the wheel it
## is driving. At normal power the truck's own weight settles that argument; at
## 2.4x it does not, and a monster truck with this much clearance stands up and
## loops itself over backwards the moment the button is pressed.
##
## What is applied is a brake on the pitch, not a fixed attitude: it cancels the
## rate at which the nose is rising and does nothing else. Holding an attitude
## instead would fight the ground — a truck climbing a ramp is nose-up because
## the ramp is, and levelling it there would rip the wheels off the surface.
##
## Called only with the front off the ground and the back on it, which is what a
## wheelie is. With both wheels in the air this would be a reaction wheel — free
## rotation from nothing, mid-jump — so that case gets the rocket instead.
func _hold_nose_down(boost: float) -> void:
	# Nose-up is NEGATIVE rotation: positive turns +x towards +y, and +y is down,
	# so lifting the front is the other way round. Already coming down needs no
	# help — and pushing on it there would plant the nose rather than settle it.
	if chassis.angular_velocity >= 0.0:
		return
	# Through the inertia, so the hold is a rate — "kill this much of the spin per
	# second" — and stays that rate if the chassis is ever resized. Read off the
	# server because RigidBody2D.inertia is 0 while it is computed from the shape,
	# which it is here.
	var inertia := float(PhysicsServer2D.body_get_param(
		chassis.get_rid(), PhysicsServer2D.BODY_PARAM_INERTIA
	))
	chassis.apply_torque(-chassis.angular_velocity * inertia * nose_hold_rate * boost)


## The charge with both wheels off the ground: a rocket.
##
## Wheel torque is worth nothing in the air — _traction() already returns zero
## there, on purpose, because a wheel spun up mid-jump lands at speed and kicks
## the truck sideways. So a charge spent off a ramp used to be a charge thrown
## away, at the exact moment the player most wanted it. This makes the airborne
## case its own thing rather than a dead one.
##
## Thrust runs along the truck's own nose, so what the boost does depends on how
## it left the ramp: level, it is distance; nose-up, it is height. That is the
## interesting version — the player aims it by how they build the take-off.
##
## Two limits on that, both because the alternative is a mechanic that punishes
## you for using it. The angle is clamped to a cone about level, so a truck
## kicked hard nose-up is not fired straight into the sky and dropped; and a
## truck facing backwards gets nothing at all, since a rocket that fires you back
## into the strait you are trying to cross is not a boost.
##
## Applied at the centre of mass, so it adds no spin of its own. The truck keeps
## whatever tumble the ramp gave it — the rocket moves it, it does not fly it.
func _rocket(boost: float) -> void:
	var facing := wrapf(chassis.rotation, -PI, PI)
	if absf(facing) > PI * 0.5:
		return
	var cone := deg_to_rad(charge_air_cone_degrees)
	var thrust := Vector2.RIGHT.rotated(clampf(facing, -cone, cone))
	chassis.apply_central_force(thrust * charge_air_thrust * _weight * boost)


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
