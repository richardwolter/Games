## The farmer: the one worker with no weak side. Walks with WASD on the ground plane. E on
## the nearest thing: a bed or the machine starts its task (the Worker steps up to it and
## stays locked there until done; E again cancels); a clone opens the role choice, picked
## with 1-3 (0 = no role). Fixing the clones' messes comes later.
class_name Farmer
extends Worker

## How close a clone must be for E to pick it.
const CLONE_REACH := 1.6

## The clone whose role is being chosen, or null.
var choosing: Clone = null


func _think() -> void:
	if Input.is_action_just_pressed("interact"):
		interact()
	if choosing == null:
		return
	for i in Clone.ROLES.size():
		if Input.is_action_just_pressed("role_%d" % i):
			pick_role(i)
			return
	# Walked off: the choice closes.
	if _ground(choosing.global_position - global_position).length() > CLONE_REACH * 2.0:
		choosing = null


## E: cancel the task going, close the role choice, or act on the nearest thing.
func interact() -> void:
	if is_working():
		cancel_work()
	elif choosing != null:
		choosing = null
	else:
		var target := nearest_target()
		if target is Clone:
			choosing = target
		elif target is Workplace:
			work(target)


## Gives the clone being chosen the role at `index` in Clone.ROLES.
func pick_role(index: int) -> void:
	if choosing == null:
		return
	choosing.set_role(Clone.ROLES[index])
	choosing = null


## What E acts on: the nearer of the workplace in reach and the clone in reach, or null.
func nearest_target() -> Node3D:
	var place := nearest_workplace()
	var clone := nearest_clone()
	if clone == null:
		return place
	if place == null:
		return clone
	var to_place := _ground(place.global_position - global_position).length()
	var to_clone := _ground(clone.global_position - global_position).length()
	return clone if to_clone < to_place else place


func nearest_clone() -> Clone:
	var best: Clone = null
	var best_d := CLONE_REACH
	for node in get_tree().get_nodes_in_group("clones"):
		var clone := node as Clone
		var d := _ground(clone.global_position - global_position).length()
		if d <= best_d:
			best = clone
			best_d = d
	return best


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
