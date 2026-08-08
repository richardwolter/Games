## Sends the experimental electric truck out and photographs the charge gauge.
##
##   godot --script tools/battery_shot.gd -- --experimental --sandbox=0 --money=9000
##
## Prints the model's own reading beside the picture, so the bar can be checked
## against the number it is supposed to be showing rather than just looked at.
extends SceneTree


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	var main := get_root().get_child(get_root().get_child_count() - 1)
	var crossing := _find(get_root(), "CrossingManager")
	var spawner := _find(get_root(), "ObjectSpawner")
	if crossing == null or spawner == null:
		printerr("no crossing manager in the tree")
		quit(1)
		return

	# Something to drive onto, so the truck leaves the shore.
	var level: Object = _find(get_root(), "LevelManager").get(&"level")
	var def: Object = (level.get(&"shop_pool") as Array)[0]
	for i in 6:
		spawner.call(&"spawn", def, Vector2(-260.0 + i * 90.0, 0.0))
	for i in 60:
		await process_frame

	crossing.call(&"set_truck", 1)  # CrossingManager.Truck.BATTERY
	main.call(&"_on_start_crossing_requested")
	for i in 120:
		await process_frame

	var car: Object = crossing.get(&"car")
	if car == null or car.get(&"battery") == null:
		printerr("the truck went out with no battery")
		quit(1)
		return
	var battery: Object = car.get(&"battery")
	var shot := get_root().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path("res://tools/_battery_shot.png"))
	print("battery %.1f / %.1f  (%.0f%%)  splash=%.1f" % [
		battery.get(&"charge"), battery.get(&"capacity"),
		battery.call(&"fraction") * 100.0, battery.get(&"splash_drain")
	])
	quit()


func _find(node: Node, type_name: String) -> Node:
	# By node name too: ObjectSpawner has no class_name, so its script cannot be
	# asked what it is.
	if node.name == type_name or node.get_class() == type_name \
			or (node.get_script() != null \
			and str(node.get_script().get_global_name()) == type_name):
		return node
	for child: Node in node.get_children():
		var hit := _find(child, type_name)
		if hit != null:
			return hit
	return null
