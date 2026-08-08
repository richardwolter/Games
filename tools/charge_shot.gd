## Sends the truck out and photographs the CHARGE! plate, before and during.
##
##   godot --script tools/charge_shot.gd -- --sandbox=0 --money=9000
##
## Prints the truck's own state beside each picture, so the plate can be checked
## against what it is supposed to be showing rather than just looked at.
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

	main.call(&"_on_start_crossing_requested")
	for i in 60:
		await process_frame
	await _shoot("ready")

	main.call(&"_on_charge_requested")
	for i in 20:
		await process_frame
	await _shoot("charging")

	# Past charge_seconds, so the plate has to have gone to SPENT on its own.
	for i in 200:
		await process_frame
	await _shoot("spent")
	quit()


func _shoot(name: String) -> void:
	var crossing := _find(get_root(), "CrossingManager")
	var car: Object = crossing.get(&"car")
	var shot := get_root().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path("res://tools/_charge_%s.png" % name))
	if car == null:
		print("%s: no truck out" % name)
		return
	print("%s: used=%s active=%s ready=%s" % [
		name, car.get(&"charge_used"), car.call(&"charge_active"),
		car.call(&"charge_ready")
	])


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
