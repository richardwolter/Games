## The farmer: the one worker with no weak side. Walks with WASD on the ground plane and
## does whatever the nearest bed is waiting for with E. Fixing the clones' messes comes later.
class_name Farmer
extends CharacterBody3D

const SPEED := 6.0
## How far (on the ground) the farmer reaches to work a bed, from the bed's centre.
const REACH := 1.6


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		work()
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
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


## Does the nearest bed's next task. Returns what it produced.
func work() -> int:
	var bed := nearest_bed()
	if bed == null:
		return 0
	return bed.perform(bed.next_task())


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
