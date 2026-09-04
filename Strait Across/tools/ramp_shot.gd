## Photographs the near shore's launch ramp on a level that has one.
##
##   godot --script tools/ramp_shot.gd -- --sandbox=1
##
## The ramp is terrain, so the assertions can only say the top line has the shape
## it should. What they cannot say is whether the lip lands at the water's edge
## and the truck spawns on flat ground behind it — that is what the picture is for.
extends SceneTree


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	var levels: Object = _find(get_root(), "Levels")
	var world: Object = _find(get_root(), "World")
	if levels == null or world == null:
		printerr("no level manager / world in the tree")
		quit(1)
		return

	# Last level in the campaign is the one with the ramp.
	levels.call(&"load_level", Campaign.count() - 1)
	for i in 30:
		await process_frame

	var level: Object = levels.get(&"level")
	var half: float = level.get(&"half_width")
	var rise: float = level.get(&"near_ramp_rise")
	var run: float = level.get(&"near_ramp_run")
	var start: Vector2 = level.call(&"car_start")
	print("level=%s half_width=%.0f rise=%.0f run=%.0f start_x=%.0f" % [
		level.get(&"display_name"), half, rise, run, start.x,
	])
	assert(rise > 0.0 and run > 0.0, "the last level should carry a ramp")
	assert(start.x < -half - run, "the truck spawns on the ramp instead of behind it")

	var camera: Node2D = world.get_node("Camera")
	camera.position = Vector2(-half - run * 0.5, 300.0 - rise)
	camera.set(&"zoom", Vector2(0.55, 0.55))
	for i in 10:
		await process_frame

	var shot := get_root().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path("res://tools/_ramp_shot.png"))
	print("saved tools/_ramp_shot.png")
	quit()


func _find(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var hit := _find(child, name)
		if hit != null:
			return hit
	return null
