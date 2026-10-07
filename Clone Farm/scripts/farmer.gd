## The farmer: the one worker with no weak side. Walks with WASD on the ground plane; E
## starts whatever the nearest bed is waiting for (the Worker steps to the bed and stays
## locked there until done), and E again cancels. Fixing the clones' messes comes later.
class_name Farmer
extends Worker


func _think() -> void:
	if Input.is_action_just_pressed("interact"):
		interact()


## E: start a task, or cancel the one going.
func interact() -> void:
	if is_working():
		cancel_work()
	else:
		work()


func wanted_move() -> Vector3:
	return screen_to_ground(Input.get_vector("move_left", "move_right", "move_up", "move_down"))


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
