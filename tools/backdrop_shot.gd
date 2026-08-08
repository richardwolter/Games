## Photographs a level's backdrop, zoomed all the way out.
##
##   godot --script tools/backdrop_shot.gd -- --sandbox=1 --level=3
##
## The one thing tools/backdrop_aspect.gd cannot tell you is whether the painting
## looks right once fit_to() has had it: whether it is stretched, whether the
## horizon meets the water, and whether the mirrored margins are visible from
## inside the level. Saves to tools/_backdrop_<n>_shot.png.
extends SceneTree


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	var index := 2
	# Where to point, as a fraction of half_width: 0 is the middle of the strait,
	# 1 the far bank. The banks are the parts a zoomed-out shot of a wide level
	# pushes off the edge of the frame, and they are where the terrain work is.
	var at := 0.0
	var zoom := 0.12
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			index = maxi(int(arg.split("=")[1]) - 1, 0)
		elif arg.begins_with("--at="):
			at = float(arg.split("=")[1])
		elif arg.begins_with("--zoom="):
			zoom = float(arg.split("=")[1])

	var levels: Object = _find(get_root(), "LevelManager")
	var world: Object = _find(get_root(), "World")
	# The world's own camera node, not whatever controller is steering it: this
	# is being pointed somewhere the player would have to pan to.
	var camera: Object = world.get_node("Camera") if world != null else null
	if levels == null:
		printerr("no level manager in the tree")
		quit(1)
		return

	levels.call(&"load_level", index)
	for i in 30:
		await process_frame

	# All the way out, which is where a stretched backdrop or a visible margin
	# shows up. Set directly rather than by faking wheel input.
	if camera != null and camera is Node2D:
		camera.set(&"zoom", Vector2(zoom, zoom))
		if not is_zero_approx(at):
			var level: Object = levels.get(&"level")
			var half := float(level.get(&"half_width"))
			var lift := float(level.get(&"far_shore_lift"))
			# Raised with the bank when pointed at one, or a lifted far shore is
			# below the bottom of the frame.
			(camera as Node2D).position = Vector2(
				at * half, 300.0 - lift * 0.5 if absf(at) > 1.0 else 300.0
			)
		for i in 30:
			await process_frame

	var shot := get_root().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(
		"res://tools/_backdrop_%d_shot.png" % (index + 1)))
	print("level %d backdrop photographed" % (index + 1))
	quit()


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
