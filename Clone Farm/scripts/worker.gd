## Anyone who works the farm: the farmer and the clones. Holds the task logic so both
## behave the same: the worker steps to a fixed spot beside a Workplace (bed, machine), faces
## it, and stays locked there, visibly working, until the task's work time runs out. Nothing
## happens to a place from a distance. Subclasses decide what to do next by overriding _think().
class_name Worker
extends CharacterBody3D

const SPEED := 6.0
## How far (on the ground) a worker reaches to pick a place, from the place's edge.
const REACH := 0.8
## How far outside the place's edge the work spot sits.
const SPOT_GAP := 0.35
const ARRIVED := 0.05
## Physics layer workers live on: they stand on the ground but walk through each other.
const LAYER := 2

## Multiplies how fast every task goes (Ferramentas upgrades and traits will change it).
var work_speed := 1.0
## The task in progress, the place it's on, where the worker stands for it and the seconds
## of work left (at speed 1).
var work_place: Workplace = null
var work_task := &""
var work_spot := Vector3.ZERO
var work_left := 0.0

var _work_clock := 0.0
var _bar: MeshInstance3D


func _ready() -> void:
	add_to_group("workers")
	collision_layer = LAYER
	collision_mask = 1
	_bar = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.15, 0.15)
	_bar.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bar.material_override = mat
	# Its own transform, so it doesn't turn or lean with the worker.
	_bar.top_level = true
	_bar.visible = false
	add_child(_bar)


func _physics_process(delta: float) -> void:
	_think()
	if is_paused():
		velocity = Vector3.ZERO
	elif is_working():
		_advance_work(delta)
	else:
		var dir := wanted_move() * move_mult()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
	move_and_slide()
	_show_work(delta)


## Hook for subclasses: read input or decide on a task. Called first every physics frame.
func _think() -> void:
	pass


## Where the worker wants to walk this frame (ground direction, length <= 1). Ignored while
## a task is going.
func wanted_move() -> Vector3:
	return Vector3.ZERO


# Hooks a clone's traits override; the farmer has no weak side and keeps the defaults.

## Multiplies walking speed.
func move_mult() -> float:
	return 1.0


## How fast this worker does `task` (1 = the task's work time as written).
func task_speed(_task: StringName) -> float:
	return work_speed


## Extra produção this worker gets out of a harvest.
func harvest_bonus() -> int:
	return 0


## Multiplies how fast a bed grows once this worker planted or watered it.
func grow_boost() -> float:
	return 1.0


## True while the worker stands still on its own (a clone chatting), task clock stopped.
func is_paused() -> bool:
	return false


## Called when the work time runs out; does the task.
func _finish_task() -> void:
	work_place.perform(work_task, self)


## Starts `place`'s next task (the nearest place in reach when null). The worker walks up
## to the place first, however far. Returns false if there's nothing to do or a task is
## already going.
func work(place: Workplace = null) -> bool:
	if is_working():
		return false
	if place == null:
		place = nearest_workplace()
	if place == null or place.next_task() == &"":
		return false
	work_place = place
	work_task = place.next_task()
	work_left = place.work_time(work_task)
	work_spot = spot_beside(place)
	_work_clock = 0.0
	return true


func is_working() -> bool:
	return work_place != null


func is_at_spot() -> bool:
	return is_working() and _ground(work_spot - global_position).length() <= ARRIVED


## How much of the current task is done, 0..1.
func work_progress() -> float:
	if not is_working():
		return 0.0
	return 1.0 - work_left / work_place.work_time(work_task)


func cancel_work() -> void:
	work_place = null
	work_task = &""
	work_left = 0.0
	velocity = Vector3.ZERO


## The spot just outside the side of `place` the worker is nearest to (toward the camera
## when standing in the middle).
func spot_beside(place: Workplace) -> Vector3:
	var off := _ground(global_position - place.global_position)
	var side := Vector3(0.0, 0.0, 1.0)
	if absf(off.x) > absf(off.z):
		side = Vector3(signf(off.x), 0.0, 0.0)
	elif off.z < 0.0:
		side = Vector3(0.0, 0.0, -1.0)
	var spot := place.global_position + side * (place.half_size() + SPOT_GAP)
	spot.y = global_position.y
	return spot


## The closest place whose edge is within REACH on the ground, or null.
func nearest_workplace() -> Workplace:
	var best: Workplace = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("workplaces"):
		var place := node as Workplace
		var d := _ground(place.global_position - global_position).length()
		if d <= place.half_size() + REACH and d < best_d:
			best = place
			best_d = d
	return best


## Walk to the work spot first; the clock only runs once the worker stands there.
func _advance_work(delta: float) -> void:
	# Someone else did this task first, or it can't be done any more: stop.
	if work_place.next_task() != work_task:
		cancel_work()
		return
	var to := _ground(work_spot - global_position)
	if to.length() > ARRIVED:
		var v := to.normalized() * minf(SPEED * move_mult(), to.length() / delta)
		velocity.x = v.x
		velocity.z = v.z
		return
	velocity = Vector3.ZERO
	var target := work_place.global_position
	target.y = global_position.y
	look_at(target)
	work_left -= delta * task_speed(work_task)
	if work_left <= 0.0:
		_finish_task()
		cancel_work()


## The progress bar over the head and a lean-and-bob loop on the "Body" child while the
## worker stands at the place, so the result never just appears.
func _show_work(delta: float) -> void:
	var at := is_at_spot()
	_bar.visible = at
	_bar.global_position = global_position + Vector3(0.0, 1.6, 0.0)
	# Lay the bar along the screen's horizontal, whatever angle the camera sits at.
	var angle := 0.0
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		angle = atan2(-cam.global_basis.x.z, cam.global_basis.x.x)
	_bar.global_basis = Basis(Vector3.UP, angle).scaled(
			Vector3(maxf(work_progress(), 0.01), 1.0, 1.0))
	var body := get_node_or_null("Body") as Node3D
	if body == null:
		return
	if at:
		_work_clock += delta
		var beat := sin(_work_clock * 12.0)
		body.rotation.x = -(0.25 + 0.15 * beat)
		body.position.y = 0.06 * absf(beat)
	else:
		body.rotation.x = 0.0
		body.position.y = 0.0


static func _ground(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
