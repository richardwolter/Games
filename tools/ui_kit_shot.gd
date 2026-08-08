## Photographs the screens the UI kit was applied to.
##
##   godot --script tools/ui_kit_shot.gd -- --what=settings --sandbox=2 --money=900
##   godot --script tools/ui_kit_shot.gd -- --what=levels
##
## settings — the modal off the HUD's corner sign.
## levels   — the level select scene, whose frame is the kit's own.
##
## Both drive the real scenes rather than building lookalikes: these panels size
## themselves against the live viewport, and the kit frames are 9-patched, so a
## hand-built copy proves nothing about what the player sees.
extends SceneTree


func _initialize() -> void:
	var what := "settings"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--what="):
			what = arg.trim_prefix("--what=")

	if what == "levels":
		change_scene_to_file("res://scenes/level_select.tscn")
		for i in 60:
			await process_frame
	else:
		change_scene_to_file("res://scenes/main.tscn")
		for i in 90:
			await process_frame
		# Parented where the HUD parents it, so the panel measures against the UI
		# layer rather than against the world — under a camera it comes out at
		# whatever the zoom happens to be.
		var hud := _find(get_root(), "HUD")
		if hud == null:
			printerr("no Hud in the tree")
			quit(1)
			return
		UITheme.settings(hud)
		for i in 30:
			await process_frame

	var shot := get_root().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path("res://tools/_kit_%s.png" % what))
	print("shot %dx%d" % [shot.get_width(), shot.get_height()])
	quit()


func _find(node: Node, named: String) -> Node:
	if node.name == named:
		return node
	for child in node.get_children():
		var hit := _find(child, named)
		if hit != null:
			return hit
	return null
