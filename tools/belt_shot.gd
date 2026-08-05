## Photographs the piece belt with its new buy bars, and the header's bridge value.
##
##   godot --script tools/belt_shot.gd -- --sandbox=0 --money=60
##
## Buys and places a couple of pieces first, so the shot shows a card carrying a
## recall bar and a buy bar at once, an affordable card, and an unaffordable one.
extends SceneTree


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	var main := get_root().get_child(get_root().get_child_count() - 1)
	var shop: Node = main.get_node("Shop")
	var levels: Node = main.get_node("Levels")
	var hud: Node = main.get_node("HUD")
	var level = levels.get(&"level")
	var def = level.shop_pool[0]
	for i in 3:
		shop.call(&"buy", def)
	# --drain empties the wallet and the first piece's shelf, for the NEED $N and
	# SOLD OUT states.
	if OS.get_cmdline_user_args().has("--drain"):
		for i in 400:
			for other in level.shop_pool:
				shop.call(&"buy", other)
	hud.emit_signal(&"place_requested", def)
	await process_frame
	hud.emit_signal(&"place_requested", def)
	for i in 40:
		await process_frame

	# --recall raises the per-type recall prompt, for photographing it.
	if OS.get_cmdline_user_args().has("--recall"):
		hud.call(&"_on_recall_type_pressed", def)
		for i in 20:
			await process_frame

	var shot := get_root().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path("res://tools/_belt_shot.png"))
	print("shot %dx%d" % [shot.get_width(), shot.get_height()])
	quit()
