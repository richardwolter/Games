## Exercises shift-click bulk placement and the SCORES panel, and photographs
## the result.
##
##   godot --script tools/bulk_shot.gd -- --sandbox=1 --money=9000
##
## Both are things that only happen on a real click in a real dock, so they are
## driven through the HUD's own signals rather than called on Main directly.
extends SceneTree


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	var main := _find(get_root(), "main")
	var hud := _find(get_root(), "hud")
	if main == null or hud == null:
		printerr("no Main/Hud in the tree")
		quit(1)
		return

	var inventory: Inventory = main.get(&"_inventory")
	var levels: LevelManager = main.get(&"_levels")
	var def: ObjectDef = levels.level.shop_pool[0]
	inventory.add(def, 12)
	for i in 5:
		await process_frame

	hud.emit_signal(&"place_all_requested", def)
	for i in 240:
		await process_frame

	_shoot("res://tools/_bulk_shot.png")

	hud.call(&"_open_scoreboard")
	for i in 40:
		await process_frame
	_shoot("res://tools/_scores_shot.png")
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
