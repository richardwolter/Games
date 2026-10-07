## The farmer: the one worker with no weak side. Walks with WASD on the ground plane.
## Doing tasks and fixing the clones' messes come in later issues.
class_name Farmer
extends CharacterBody3D

const SPEED := 6.0


func _physics_process(_delta: float) -> void:
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
