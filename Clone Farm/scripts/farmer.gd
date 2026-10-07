## The farmer: the one worker with no weak side. Walks with WASD on the ground plane.
## Doing tasks and fixing the clones' messes come in later issues.
class_name Farmer
extends CharacterBody3D

const SPEED := 6.0


func _physics_process(_delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# The camera looks down the world's -Z/+X diagonal, so screen-up is rotated 45 degrees.
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, deg_to_rad(-45.0))
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()
