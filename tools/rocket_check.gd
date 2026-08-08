## Measures what CHARGE! is worth in the air, against a run that never fires it.
##
##   godot --headless --script tools/rocket_check.gd -- --sandbox=5 --money=9000
##
## Level 6 is the one with a launch ramp cut into the shore, so the truck leaves
## the ground on its own and the airborne case can be tested without a bridge.
##
## Three runs of the same jump: one that never fires the charge, one that spends
## it on the ground at the start, and one that holds it until both wheels are off
## the ground. The numbers to read are the height gained and how far down the
## strait the truck got — the first pair says the rocket does something at all,
## and the second says whether holding the charge for the air is a real choice or
## a trap.
extends SceneTree

## How long each run is watched, and how often it is sampled.
const RUN_SECONDS := 8.0
const SAMPLE := 0.05


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	var crossing := _find(get_root(), "CrossingManager")
	if crossing == null:
		printerr("no crossing manager in the tree")
		quit(1)
		return

	var runs: Dictionary = {}
	for mode: String in ["none", "ground", "air"]:
		runs[mode] = await _run(crossing, mode)
		crossing.call(&"reset")
		for i in 30:
			await process_frame

	for mode: String in ["none", "ground", "air"]:
		print("%-7s peak height=%.0f  reached x=%.0f  airborne=%.2fs" % (
			[mode] + (runs[mode] as Array)
		))
	print("air over ground  height=%+.0f  distance=%+.0f" % [
		runs["air"][0] - runs["ground"][0], runs["air"][1] - runs["ground"][1]
	])
	quit()


## One jump. `mode` is "none", "ground" or "air" — when the charge is spent.
## Returns [peak height above the take-off, furthest x, seconds airborne].
func _run(crossing: Object, mode: String) -> Array:
	crossing.call(&"start_crossing")
	var car: Object = crossing.get(&"car")
	var chassis: Node2D = car.get(&"chassis")
	var wheels: Array[Node] = [
		car.get_node(^"WheelBack") as Node, car.get_node(^"WheelFront") as Node
	]

	var ground_y: float = chassis.global_position.y
	var peak := 0.0
	var furthest: float = chassis.global_position.x
	var airborne := 0.0
	var fired := false

	if mode == "ground":
		fired = car.call(&"trigger_charge")

	var elapsed := 0.0
	while elapsed < RUN_SECONDS:
		await create_timer(SAMPLE).timeout
		elapsed += SAMPLE
		if not is_instance_valid(car) or not crossing.get(&"is_running"):
			break
		var at: Vector2 = chassis.global_position
		peak = maxf(peak, ground_y - at.y)
		furthest = maxf(furthest, at.x)

		var up := true
		for wheel: Node in wheels:
			if not (wheel.call(&"get_colliding_bodies") as Array).is_empty():
				up = false
		if up:
			airborne += SAMPLE
			if mode == "air" and not fired:
				fired = car.call(&"trigger_charge")
	return [peak, furthest, airborne]


func _find(node: Node, type_name: String) -> Node:
	if node.name == type_name or node.get_class() == type_name \
			or (node.get_script() != null \
			and str(node.get_script().get_global_name()) == type_name):
		return node
	for child: Node in node.get_children():
		var hit := _find(child, type_name)
		if hit != null:
			return hit
	return null
