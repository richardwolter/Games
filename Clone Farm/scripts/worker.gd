## Anyone who works the farm: the farmer now, the clones later. Holds the task logic so both
## behave the same: the worker steps to a fixed spot beside the bed, faces it, and stays
## locked there, visibly working, until the task's work time runs out. Nothing happens to a
## bed from a distance. Subclasses decide what to do next by overriding _think().
class_name Worker
extends CharacterBody3D

const SPEED := 6.0
## How far (on the ground) a worker reaches to pick a bed, from the bed's centre.
const REACH := 1.6
## How far outside the bed's edge the work spot sits.
const SPOT_GAP := 0.35
const ARRIVED := 0.05

## Multiplies how fast every task goes (Ferramentas upgrades and traits will change it).
var work_speed := 1.0
## The task in progress, the bed it's on, where the worker stands for it and the seconds of
## work left (at speed 1).
var work_bed: Bed = null
var work_task := &""
var work_spot := Vector3.ZERO
var work_left := 0.0

var _work_clock := 0.0
var _bar: MeshInstance3D


func _ready() -> void:
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
	if is_working():
		_advance_work(delta)
	else:
		var dir := wanted_move()
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


## Starts the nearest bed's next task. Returns false if there's nothing to do or a task is
## already going.
func work() -> bool:
	if is_working():
		return false
	var bed := nearest_bed()
	if bed == null or bed.next_task() == &"":
		return false
	work_bed = bed
	work_task = bed.next_task()
	work_left = Bed.WORK_TIME[work_task]
	work_spot = spot_beside(bed)
	_work_clock = 0.0
	return true


func is_working() -> bool:
	return work_bed != null


func is_at_spot() -> bool:
	return is_working() and _ground(work_spot - global_position).length() <= ARRIVED


## How much of the current task is done, 0..1.
func work_progress() -> float:
	if not is_working():
		return 0.0
	return 1.0 - work_left / Bed.WORK_TIME[work_task]


func cancel_work() -> void:
	work_bed = null
	work_task = &""
	work_left = 0.0
	velocity = Vector3.ZERO


## The spot just outside the side of `bed` the worker is nearest to (toward the camera when
## standing in the middle).
func spot_beside(bed: Bed) -> Vector3:
	var off := _ground(global_position - bed.global_position)
	var side := Vector3(0.0, 0.0, 1.0)
	if absf(off.x) > absf(off.z):
		side = Vector3(signf(off.x), 0.0, 0.0)
	elif off.z < 0.0:
		side = Vector3(0.0, 0.0, -1.0)
	var spot := bed.global_position + side * (Bed.SIZE / 2.0 + SPOT_GAP)
	spot.y = global_position.y
	return spot


## The closest bed within REACH on the ground, or null.
func nearest_bed() -> Bed:
	var best: Bed = null
	var best_d := REACH
	for node in get_tree().get_nodes_in_group("beds"):
		var bed := node as Bed
		var d := _ground(bed.global_position - global_position).length()
		if d <= best_d:
			best = bed
			best_d = d
	return best


## Walk to the work spot first; the clock only runs once the worker stands there.
func _advance_work(delta: float) -> void:
	# Someone else did this task first: nothing left to do here.
	if work_bed.next_task() != work_task:
		cancel_work()
		return
	var to := _ground(work_spot - global_position)
	if to.length() > ARRIVED:
		var v := to.normalized() * minf(SPEED, to.length() / delta)
		velocity.x = v.x
		velocity.z = v.z
		return
	velocity = Vector3.ZERO
	var target := work_bed.global_position
	target.y = global_position.y
	look_at(target)
	work_left -= delta * work_speed
	if work_left <= 0.0:
		work_bed.perform(work_task)
		cancel_work()


## The progress bar over the head and a lean-and-bob loop on the "Body" child while the
## worker stands at the bed, so the result never just appears.
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
