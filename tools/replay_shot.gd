## Runs a real crossing, then plays the recording back and photographs both.
##
##   godot --script tools/replay_shot.gd -- --sandbox=0 --money=9000
##
## Proves the thing that actually matters about a transform replay: that the
## puppets sit where the bodies sat. The two shots are taken at the same point in
## the run — a fixed distance into the attempt, and the same distance into the
## playback — so they should be the same picture.
extends SceneTree


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	var main := _find(get_root(), "main")
	var hud := _find(get_root(), "hud")
	var crossing: CrossingManager = main.get(&"_crossing")
	var spawner: Node = main.get(&"_spawner")
	var levels: LevelManager = main.get(&"_levels")
	var inventory: Inventory = main.get(&"_inventory")

	# A rough causeway of planks, laid flat across the water.
	var plank: ObjectDef = levels.level.shop_pool[0]
	inventory.add(plank, 24)
	var area: Rect2 = spawner.spawn_area
	for i in 24:
		var obj: BridgeObject = spawner.spawn(
			plank, Vector2(area.get_center().x - 900.0 + i * 78.0, 120.0)
		)
		obj.rotation = 0.0
	for i in 180:
		await process_frame

	crossing.start_crossing()
	for i in 220:
		await process_frame
	_shoot("res://tools/_live_shot.png")

	# Let it finish, however it finishes, then watch it back.
	var guard := 0
	while crossing.is_running and guard < 1800:
		await process_frame
		guard += 1
	for i in 20:
		await process_frame

	hud.emit_signal(&"replay_requested", false)
	for i in 220:
		await process_frame
	_shoot("res://tools/_replay_shot.png")

	var replay: Node = main.get(&"_replay")
	print("replay playing=%s puppets=%d recorded_frames=%d" % [
		str(replay.get(&"is_playing")),
		replay.get_child_count(),
		(main.get(&"_recorder") as Node).get(&"frames").size(),
	])
	quit()


func _shoot(path: String) -> void:
	var shot := get_root().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


func _find(node: Node, script_file: String) -> Node:
	var script := node.get_script() as Script
	if script != null and script.resource_path.get_file() == script_file + ".gd":
		return node
	for child: Node in node.get_children():
		var hit := _find(child, script_file)
		if hit != null:
			return hit
	return null
