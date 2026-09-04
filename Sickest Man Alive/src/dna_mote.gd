class_name DnaMote
extends Node2D

## A scrap of something's genetic code, on the floor, waiting to be walked over.
##
## DNA is the only thing in the run that outlives it, so picking it up is worth a
## deliberate walk -- it does not fly to you. What it does do is scatter off the
## corpse and settle, so a fight leaves a readable trail rather than a stack of
## tokens on one pixel.
##
## Not an Area2D, for the reason Pedestal spells out: the player's collision is
## far wider than the kid you can see, and an overlap pickup collects things he
## visibly walked past. A distance test against his centre is the honest version.

signal collected(value: int)

## Centre-to-centre. Generous enough to sweep a corpse pile in one pass, small
## enough that DNA on the far side of a cover blob is still a decision.
const PICKUP_RADIUS: float = 26.0

## --- magnet ---------------------------------------------------------------
## Once the room is clear there is nothing left to decide. Walking the floor to
## sweep up motes was a real choice while something was still shooting at you;
## with the last wave down it is just a lap of an empty room, so the DNA comes to
## the player instead.
##
## Accelerating rather than flat: a mote that starts slow reads as being pulled
## loose, and one that arrives fast does not leave the player waiting on it.
const MAGNET_SPEED: float = 620.0
const MAGNET_ACCEL: float = 2200.0
## Held off until the scatter has settled, so a mote dropped by the last enemy to
## die still gets its throw instead of snapping to the player mid-air. Short
## enough that the pull reads as part of the kill rather than as a delay after it.
const MAGNET_DELAY: float = 0.1

## The scatter: motes are thrown off the body and slide to a stop.
const SETTLE_TIME: float = 0.32
const SCATTER_SPEED_MIN: float = 60.0
const SCATTER_SPEED_MAX: float = 150.0

const CORE_COLOR: Color = Color(0.62, 1.0, 0.78)
const HALO_COLOR: Color = Color(0.25, 0.9, 0.55, 0.28)
const BOB_HEIGHT: float = 2.4
const BOB_RATE: float = 3.4

## What it is worth. Bigger motes are drawn bigger, so a boss's drop reads as
## different from a grub's before you are near enough to count them.
var value: int = 1

## The dictionary this mote was built from, and which the run is storing. Held
## rather than rebuilt so collection can erase it by identity -- see DnaLayer.
var record: Dictionary = {}

var _scatter: Vector2 = Vector2.ZERO
var _settle: float = 0.0
var _phase: float = 0.0
var _taken: bool = false
## Set by DnaLayer once the room has nothing left to fight.
var _magnet: bool = false
var _magnet_wait: float = 0.0
var _magnet_speed: float = 0.0
## Where to fly, in world space, or INF for "nobody to fly to right now".
##
## Pushed in by the layer rather than looked up here. Sixty motes each running
## their own group lookup and their own in-the-room test, every frame, is sixty
## copies of one answer -- and the answer has to be the same for all of them or
## half the floor chases a player the other half has decided is gone.
var _magnet_to: Vector2 = Vector2.INF


func _ready() -> void:
	_phase = randf() * TAU


## Throws the mote off the body it dropped from. Called only for a FRESH mote:
## one loaded back out of the run's record has already landed, and re-scattering
## it every time you re-enter the room would walk it across the floor.
func scatter() -> void:
	_settle = SETTLE_TIME
	_scatter = Vector2.from_angle(randf() * TAU) \
		* randf_range(SCATTER_SPEED_MIN, SCATTER_SPEED_MAX)


## Starts the mote drifting to the player. Idempotent: the room can clear once,
## but a mote dropped after that (a straggler, a boss's last tick) is told the
## same thing on the way in.
func magnetise() -> void:
	if _magnet:
		return
	_magnet = true
	_magnet_wait = MAGNET_DELAY
	_magnet_speed = 0.0


func _process(delta: float) -> void:
	if _settle > 0.0:
		_settle -= delta
		position += _scatter * delta
		# Eases to a stop rather than cutting: it is sliding on a wet floor.
		_scatter = _scatter.move_toward(Vector2.ZERO, 420.0 * delta)
		if _settle <= 0.0:
			# Where it came to rest is where the run remembers it. Written once,
			# into the same dictionary the map is holding.
			record["p"] = position
	elif _magnet:
		_tick_magnet(delta)
	_phase += delta * BOB_RATE
	queue_redraw()
	_try_pickup()


## Flies the mote at the player. Runs only once the scatter is done, so the two
## never fight over the same position.
##
## The run's record is rewritten as it travels. A magnetised mote is about to be
## collected and erased anyway, but "about to be" is not "was" -- quitting to the
## menu mid-flight has to leave the DNA somewhere real rather than back where it
## first landed.
func _tick_magnet(delta: float) -> void:
	if _magnet_wait > 0.0:
		_magnet_wait -= delta
		return
	if _magnet_to == Vector2.INF:
		# Nobody to fly to -- the player walked out, or died. Speed is dropped
		# rather than held, so a mote that gets a target again winds up from a
		# standstill instead of resuming at whatever it had built up.
		_magnet_speed = 0.0
		return
	_magnet_speed = minf(_magnet_speed + MAGNET_ACCEL * delta, MAGNET_SPEED)
	var to_player := _magnet_to - global_position
	global_position += to_player.normalized() * minf(_magnet_speed * delta, to_player.length())
	record["p"] = position


## The layer's answer for this frame: where to fly, or INF for nowhere.
func set_magnet_target(where: Vector2) -> void:
	_magnet_to = where


func _try_pickup() -> void:
	if _taken:
		return
	var player := get_tree().get_first_node_in_group(&"player_body") as Node2D
	if player == null:
		return
	# A corpse does not go shopping. Without this the death slide hoovers up the
	# floor on the way past, and the run's payout counts DNA collected by a body.
	if player.has_method(&"is_dead") and player.is_dead():
		return
	if player.global_position.distance_to(global_position) > PICKUP_RADIUS:
		return
	_taken = true
	collected.emit(value)
	queue_free()


func _radius() -> float:
	# Flattens off fast: a 5-point mote should read as bigger than a 1-pointer
	# without a boss drop being a dinner plate.
	return 3.0 + sqrt(float(value)) * 1.6


func _draw() -> void:
	var lift := Vector2(0.0, sin(_phase) * BOB_HEIGHT)
	var r := _radius()
	# Shadow stays on the floor while the mote breathes above it, which is the
	# only thing that stops a flat circle reading as painted on.
	Lighting.draw_shadow(self, Vector2(0.0, 2.0), r * 1.6, 0.0, 0.5)
	draw_circle(lift, r * 2.1, HALO_COLOR)
	draw_circle(lift, r, CORE_COLOR)
	# A brighter nub off-centre, so it glints instead of sitting there.
	draw_circle(lift + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(0.9, 1.0, 0.95))
