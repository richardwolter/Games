## Photographs the experimental rope: two pieces in the strait with a rope tied
## between them, and the dock's rope tab beside it.
##
##   godot --script tools/rope_shot.gd -- --experimental --sandbox=1 --money=9000
##
## The one thing that cannot be checked by assertion. The joint's anchors are
## derived from the joint node's own transform, so a sign error in the rotation
## produces a rope that is drawn plausibly and pulls the wrong way — the numbers
## agree and the picture does not.
extends SceneTree


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	var ropes := _find(get_root(), "RopeManager")
	var spawner := _find(get_root(), "ObjectSpawner")
	if ropes == null or spawner == null:
		printerr("no rope manager in the tree — was --experimental passed?")
		quit(1)
		return

	# Two pieces, dropped apart, then tied at their centres once they have settled.
	var level: Object = _find(get_root(), "LevelManager").get(&"level")
	var def: Object = (level.get(&"shop_pool") as Array)[0]
	var a: Node2D = spawner.call(&"spawn", def, Vector2(-160, 0))
	var b: Node2D = spawner.call(&"spawn", def, Vector2(160, 0))
	for i in 60:
		await process_frame

	ropes.call(&"try_point", a.global_position)
	ropes.call(&"try_point", b.global_position)
	for i in 40:
		await process_frame

	var shot := get_root().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path("res://tools/_rope_shot.png"))
	var rope_list: Array = ropes.call(&"ropes")
	if rope_list.is_empty():
		printerr("no rope was placed")
		quit(1)
		return
	var rope: Node2D = rope_list[0]
	var joint: Node2D = rope.get(&"joint")
	var ends: PackedVector2Array = rope.call(&"endpoints")
	print("rope cost=%d rest=%.1f  ends=%s  joint_at=%s length=%.1f anchor_b=%s" % [
		rope.get(&"cost"), rope.get(&"rest"), str(ends), str(joint.global_position),
		joint.get(&"length"), str(joint.global_transform * Vector2(0, joint.get(&"length")))
	])
	quit()


func _find(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name or (node.get_script() != null \
			and str(node.get_script().get_global_name()) == type_name):
		return node
	if node.name == type_name:
		return node
	for child: Node in node.get_children():
		var hit := _find(child, type_name)
		if hit != null:
			return hit
	return null
