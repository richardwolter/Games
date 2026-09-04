## Opens the real shop panel on a level and saves a screenshot of it.
##
##   godot --script tools/shop_shot.gd -- --sandbox=3 --money=9000
##
## For checking that a level's catalogue actually fits: the panel scales itself
## to the band above the dock, and whether that lands correctly depends on how
## many pieces and booster tiers the level stocks. Building the ShopMenu standing
## alone does NOT answer the question — it is the HUD that gives the panel its
## size, and a hand-built one measures against a viewport nothing else agrees
## with. So this drives the actual scene through the sandbox flag and photographs
## the result.
extends SceneTree


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	# --noshop leaves the panel closed, for looking at the level itself.
	var menu := _find(get_root(), "ShopMenu")
	if menu == null:
		printerr("no ShopMenu in the tree")
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--settings"):
		UITheme.settings(get_root().get_child(get_root().get_child_count() - 1))
	elif not OS.get_cmdline_user_args().has("--noshop"):
		menu.call(&"open_menu")
	for i in 30:
		await process_frame

	var shot := get_root().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path("res://tools/_shot.png"))
	var frame: Control = menu.get(&"_frame")
	print("shot %dx%d  menu=%s frame_min=%s frame_size=%s scale=%s" % [
		shot.get_width(), shot.get_height(), str(menu.size),
		str(frame.get_combined_minimum_size()), str(frame.size), str(frame.scale)
	])
	quit()


func _find(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name or (node.get_script() != null \
			and str(node.get_script().get_global_name()) == type_name):
		return node
	for child: Node in node.get_children():
		var hit := _find(child, type_name)
		if hit != null:
			return hit
	return null
