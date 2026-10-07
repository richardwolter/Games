## The farmer: the one worker with no weak side. Walks with WASD on the ground plane and
## does whatever the nearest bed is waiting for with E: one press starts the task, it takes
## the task's work time, and walking away cancels it. Fixing the clones' messes comes later.
class_name Farmer
extends CharacterBody3D

const SPEED := 6.0
## How far (on the ground) the farmer reaches to work a bed, from the bed's centre.
const REACH := 1.6

## Multiplies how fast every task goes (Ferramentas upgrades will raise it).
var work_speed := 1.0
## The task in progress, the bed it's on and the seconds of work left (at speed 1).
var work_bed: Bed = null
var work_task := &""
var work_left := 0.0

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
	_bar.position.y = 1.6
	_bar.visible = false
	add_child(_bar)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		work()
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		cancel_work()
	_advance_work(delta)
	var dir := screen_to_ground(input)
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()


## Turns a screen-space input (x right, y down) into a direction on the ground, read off
## the active camera so W is always "up the screen" whatever angle the camera sits at.
## (A hard-coded 45-degree turn had the sign wrong and sent W to the right, 2026-10-07.)
func screen_to_ground(input: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3(input.x, 0.0, input.y)
	var right := cam.global_basis.x
	var up := -cam.global_basis.z
	right.y = 0.0
	up.y = 0.0
	return (right.normalized() * input.x + up.normalized() * -input.y).limit_length(1.0)


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
	return true


func is_working() -> bool:
	return work_bed != null


## How much of the current task is done, 0..1.
func work_progress() -> float:
	if not is_working():
		return 0.0
	return 1.0 - work_left / Bed.WORK_TIME[work_task]


func cancel_work() -> void:
	work_bed = null
	work_task = &""
	work_left = 0.0


func _advance_work(delta: float) -> void:
	if is_working():
		# Someone else did this task first: nothing left to do here.
		if work_bed.next_task() != work_task:
			cancel_work()
		else:
			work_left -= delta * work_speed
			if work_left <= 0.0:
				work_bed.perform(work_task)
				cancel_work()
	_bar.visible = is_working()
	# Lay the bar along the screen's horizontal, whatever angle the camera sits at.
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_bar.rotation.y = atan2(-cam.global_basis.x.z, cam.global_basis.x.x)
	_bar.scale.x = maxf(work_progress(), 0.01)


## The closest bed within REACH on the ground, or null.
func nearest_bed() -> Bed:
	var best: Bed = null
	var best_d := REACH
	for node in get_tree().get_nodes_in_group("beds"):
		var bed := node as Bed
		var d := Vector2(bed.global_position.x - global_position.x,
				bed.global_position.z - global_position.z).length()
		if d <= best_d:
			best = bed
			best_d = d
	return best
