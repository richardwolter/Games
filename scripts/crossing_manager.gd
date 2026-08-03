## Runs a crossing attempt: spawn the car, watch it, decide how it went.
## Owns no physics of its own — it only observes the car and reports the result.
class_name CrossingManager
extends Node

const CAR_SCENE := preload("res://scenes/car.tscn")

enum Result { SUCCESS, DROWNED, STALLED }

signal attempt_started()
signal attempt_finished(result: Result, progress: float)

## Point on the left shore surface (y = 300) the wheels are set down on.
@export var start_position: Vector2 = Vector2(-2600, 300)
## Chassis past this x counts as landed on the far shore (shore starts at 1600).
@export var goal_x: float = 1680.0
## Chassis below this y is in the drink. Water surface is at y = 300.
@export var drown_y: float = 420.0
## 0% progress line — the near water's edge, not where the car spawns.
@export var progress_from_x: float = -1600.0
## Give up if the car hasn't gained ground for this long.
@export var stall_seconds: float = 3.5
## Ignore stalling during the initial roll-out.
@export var grace_seconds: float = 1.5
@export var container_path: NodePath

var car: Car = null
## The truck sitting on the left shore between attempts. Not the same object as
## `car`: this one is frozen and has no collision, and never moves.
var parked: Car = null
var is_running: bool = false
var progress: float = 0.0

var _container: Node2D
var _best_x: float = 0.0
var _stall_timer: float = 0.0
var _elapsed: float = 0.0


func _ready() -> void:
	_container = get_node(container_path) as Node2D


## Where the run starts and where it counts as finished. Set per level, since a
## wider strait moves both ends.
##
## Progress is measured across the water only — the run-up along the left shore
## is free distance and would otherwise show as 20-odd percent before the car has
## touched the bridge at all.
func set_course(start: Vector2, goal: float) -> void:
	start_position = start
	goal_x = goal
	progress_from_x = -goal + 80.0
	# The start line just moved, so the parked truck has to move with it. This is
	# also what puts it on the shore in the first place, on the first level load.
	if _container != null:
		unpark()
		park()


## Puts the truck on the left shore, where it waits until you send it.
##
## Between attempts the start line used to be empty, so what the player was
## building towards was an idea rather than a thing they could see. Parking the
## real truck there answers "how big is it, and where does it start" without a
## word of UI, and gives the START button something to visibly act on.
##
## Frozen, and with its collision switched off on every body. Frozen because a
## live truck left on a slope for the several minutes a bridge takes to build
## will eventually creep, roll or settle somewhere it shouldn't; collisionless
## because nothing the player does should be able to nudge the parked truck, and
## nothing about it should be able to catch a piece.
func park() -> void:
	if is_instance_valid(parked) or is_running:
		return
	parked = CAR_SCENE.instantiate() as Car
	parked.position = start_position - Vector2(0, Car.RIDE_HEIGHT)
	_container.add_child(parked)
	for body: PhysicsBody2D in _bodies_of(parked):
		if body is RigidBody2D:
			(body as RigidBody2D).freeze = true
		body.collision_layer = 0
		body.collision_mask = 0


func unpark() -> void:
	if is_instance_valid(parked):
		parked.queue_free()
	parked = null


## The chassis and both wheels. Named rather than listed, so a truck that grows
## a trailer one day doesn't quietly leave half of itself unfrozen.
func _bodies_of(vehicle: Node) -> Array[PhysicsBody2D]:
	var out: Array[PhysicsBody2D] = []
	for child: Node in vehicle.get_children():
		if child is PhysicsBody2D:
			out.append(child as PhysicsBody2D)
	return out


func start_crossing() -> void:
	reset(false)
	unpark()
	car = CAR_SCENE.instantiate() as Car
	car.position = start_position - Vector2(0, Car.RIDE_HEIGHT)
	_container.add_child(car)
	car.start()

	_best_x = start_position.x
	_stall_timer = 0.0
	_elapsed = 0.0
	progress = 0.0
	is_running = true
	attempt_started.emit()


## `re_park` is false only when a crossing is about to launch, which would
## otherwise build a parked truck and delete it again in the same call.
func reset(re_park: bool = true) -> void:
	is_running = false
	if is_instance_valid(car):
		car.queue_free()
	car = null
	# Straight back to the start line, so the truck is waiting there again the
	# moment the wreck is cleared.
	if re_park:
		park()


func _physics_process(delta: float) -> void:
	if not is_running or not is_instance_valid(car):
		return

	_elapsed += delta
	var pos := car.chassis.global_position

	if pos.x > _best_x:
		_best_x = pos.x
		_stall_timer = 0.0
	else:
		_stall_timer += delta

	progress = clampf(
		(_best_x - progress_from_x) / maxf(goal_x - progress_from_x, 1.0), 0.0, 1.0
	)

	if pos.x >= goal_x and pos.y < drown_y:
		_finish(Result.SUCCESS)
	elif pos.y > drown_y:
		_finish(Result.DROWNED)
	elif _elapsed > grace_seconds and (_stall_timer > stall_seconds or car.is_flipped()):
		_finish(Result.STALLED)


func _finish(result: Result) -> void:
	is_running = false
	if is_instance_valid(car):
		car.stop()
	attempt_finished.emit(result, progress)
