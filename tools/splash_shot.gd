## Drops things into the strait and photographs the splash.
##
##   godot --script tools/splash_shot.gd -- --sandbox=1 --money=9000
##
## Waits for the water to actually report a crown rather than guessing at a frame
## number, then takes three shots across the splash's life — a crown is under
## half a second long and the interesting part is whether it reads at all, which
## one frame at an arbitrary moment cannot answer.
extends SceneTree


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	var main := _find(get_root(), "main")
	var spawner: Node = main.get(&"_spawner")
	var levels: LevelManager = main.get(&"_levels")
	var camera: Camera2D = main.get(&"_camera")
	var water: WaterBody = main.get_node(^"World/Water")

	# The heaviest thing the level sells, dropped from well above the waterline so
	# it arrives at a speed the player would only ever produce by knocking a
	# bridge apart.
	var heavy: ObjectDef = levels.level.shop_pool[0]
	for def: ObjectDef in levels.level.shop_pool:
		if def.size.x * def.get_height() > heavy.size.x * heavy.get_height():
			heavy = def
	print("dropping ", heavy.display_name)

	var splash: WaterSplash = water.splash
	camera.position = Vector2(0.0, 120.0)
	for i in 5:
		await process_frame

	for n in 2:
		spawner.spawn(heavy, Vector2(-300.0 + n * 600.0, -560.0))

	# Polled every frame with no gaps. The crown is 0.42s long and the window it
	# is worth photographing is the front half of that.
	var guard := 0
	while splash._crown_age.size() == 0 and guard < 900:
		await process_frame
		guard += 1
	print("first crown at frame %d" % guard)

	for shot in 3:
		_shoot("res://tools/_splash_%d.png" % shot)
		print("  crowns=%d drops=%d" % [splash._crown_age.size(), splash._drop_life.size()])
		for i in 6:
			await process_frame
	quit()


func _shoot(path: String) -> void:
	get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
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
