## The farmer: the one worker with no weak side, and the only one who fixes a trampled bed.
## Walks with WASD on the ground plane. E on the nearest thing: a bed, a crate (pick it up),
## the machine, trough or market (deliver what's in hand; empty-handed at the machine,
## clone) starts its task (the Worker steps up to it and stays locked there until done; E
## again cancels); a clone opens the role choice, picked with 1-4 (0 = no role), and
## Carregar then asks the destination with 1-3.
class_name Farmer
extends Worker

## How close a clone must be for E to pick it.
const CLONE_REACH := 1.6

## The clone whose role is being chosen, or null.
var choosing: Clone = null
## True once Carregar was picked and the destination is being chosen.
var choosing_dest := false


func _think() -> void:
	if Input.is_action_just_pressed("interact"):
		interact()
	if choosing == null:
		return
	for i in Clone.ROLES.size():
		if Input.is_action_just_pressed("role_%d" % i):
			if choosing_dest:
				pick_dest(i)
			else:
				pick_role(i)
			return
	# Walked off: the choice closes.
	if _ground(choosing.global_position - global_position).length() > CLONE_REACH * 2.0:
		close_choice()


## E: cancel the task going, close the role choice, or act on the nearest thing.
func interact() -> void:
	if is_working():
		cancel_work()
	elif choosing != null:
		close_choice()
	else:
		var target := nearest_target()
		if target is Clone:
			choosing = target
			choosing_dest = false
		elif target is Workplace:
			work(target)


func close_choice() -> void:
	choosing = null
	choosing_dest = false


## Gives the clone being chosen the role at `index` in Clone.ROLES; Carregar first asks
## where to.
func pick_role(index: int) -> void:
	if choosing == null or index >= Clone.ROLES.size():
		return
	if Clone.ROLES[index] == Traits.CARRY:
		choosing_dest = true
		return
	choosing.set_role(Clone.ROLES[index])
	close_choice()


## Sends the Carregar clone being chosen to the depot with this slot number.
func pick_dest(slot: int) -> void:
	if choosing == null:
		return
	for node in get_tree().get_nodes_in_group("depots"):
		var depot := node as Depot
		if depot.slot == slot:
			choosing.set_role(Traits.CARRY, depot)
			close_choice()
			return


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
