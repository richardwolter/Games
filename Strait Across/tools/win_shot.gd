## Photographs the panel the player gets for crossing a strait.
##
##   godot --script tools/win_shot.gd -- --sandbox=3 --level=3
##
## The last strait's panel is the interesting one — it carries the campaign's
## closing lines as well as the board and the exits — and it is also the one
## nobody sees without playing the whole game, so it is the one most likely to
## have been left overlapping something. Drives the real HUD rather than building
## a lookalike, for the same reason shop_shot.gd does: the panel measures itself
## against the live viewport and a hand-built one measures against nothing.
extends SceneTree


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	var hud := _find(get_root(), "Hud")
	if hud == null:
		printerr("no Hud in the tree")
		quit(1)
		return

	# Pretend a bridge was just filed into a slot, so the panel draws the line it
	# would draw after a real crossing.
	hud.call(&"report_build_autosaved", 0, 14)
	hud.call(&"show_crossed_panel", 380, 1, 265)
	for i in 30:
		await process_frame

	var shot := get_root().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path("res://tools/_win_shot.png"))
	print("shot %dx%d" % [shot.get_width(), shot.get_height()])
	quit()


func _find(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name or node.get_script() != null \
			and (node.get_script() as Script).resource_path.get_file() \
				== type_name.to_snake_case() + ".gd":
		return node
	for child: Node in node.get_children():
		var hit := _find(child, type_name)
		if hit != null:
			return hit
	return null
