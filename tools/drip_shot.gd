## Drives the truck across a causeway sitting at the waterline and photographs
## the wheels, close up, to check they trickle.
##
##   godot --script tools/drip_shot.gd -- --sandbox=0 --money=9000
##
## Zoomed right in, because the thing being checked is a few drops coming off a
## 38px tyre — at the zoom the game normally plays at it is a smudge, and a
## smudge cannot be judged.
extends SceneTree


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	var main := _find(get_root(), "main")
	var crossing: CrossingManager = main.get(&"_crossing")
	var spawner: Node = main.get(&"_spawner")
	var levels: LevelManager = main.get(&"_levels")
	var camera: Camera2D = main.get_node(^"World/Camera")

	# A flat run of planks, laid so the truck rides with its tyres in the water.
	var plank: ObjectDef = levels.level.shop_pool[0]
	var area: Rect2 = spawner.spawn_area
	for i in 26:
		spawner.spawn(plank, Vector2(area.get_center().x - 940.0 + i * 76.0, 150.0))
	for i in 240:
		await process_frame

	var water: WaterBody = main.get_node(^"World/Water")
	# Started from the middle of the causeway rather than from the shore. The
	# run-up is not what is being tested and it is the part most likely to end
	# with the truck in the drink before it has driven through any water at all.
	crossing.start_position = Vector2(area.get_center().x - 200.0, water.surface_y - 60.0)
	crossing.start_crossing()

	# Wait for the back tyre to actually be in the water, which is the condition
	# under test — not for the truck to reach some x, which it may never do if the
	# causeway folds on the way.
	var back: Node2D = null
	var guard := 0
	while guard < 2400:
		await process_frame
		guard += 1
		if not is_instance_valid(crossing.car):
			printerr("truck did not survive the run-up")
			quit(1)
			return
		back = crossing.car.get_node(^"WheelBack")
		if water.contains_point(back.global_position + Vector2(0.0, 38.0)):
			break
	print("tyre in the water at frame %d" % guard)

	for shot in 3:
		for i in 14:
			# Held every frame: the camera controller re-derives its own zoom and
			# position while it is following the truck.
			camera.zoom = Vector2(2.6, 2.6)
			camera.position = back.global_position
			await process_frame
		get_root().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://tools/_drip_%d.png" % shot)
		)
		print("shot %d  wheel_y=%.0f surface=%.0f drops=%d" % [
			shot, back.global_position.y, water.surface_y, water.splash._drop_life.size()
		])
	quit()


func _find(node: Node, script_file: String) -> Node:
	var script := node.get_script() as Script
	if script != null and script.resource_path.get_file() == script_file + ".gd":
		return node
	for child: Node in node.get_children():
		var hit := _find(child, script_file)
		if hit != null:
			return hit
	return null
