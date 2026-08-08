## Checks the seabed prop stands where it should and that things land on it.
##
##   godot --script tools/seabed_prop_probe.gd -- --sandbox=1 --money=9000
##
## Two things can go silently wrong with a prop: it can be built at the wrong
## height — buried in the floor or breaking the surface — and it can be built
## with no working collision, which looks identical and is a tree pieces fall
## straight through. So this measures the first and drops crates on it to settle
## the second, then photographs the result.
extends SceneTree

## Level 4, the one with the drowned tree.
const LEVEL := 3


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	var levels: Object = _find(get_root(), "LevelManager")
	var world: Object = _find(get_root(), "World")
	var spawner: Object = _find(get_root(), "ObjectSpawner")
	if levels == null or world == null or spawner == null:
		printerr("no level manager / world / spawner in the tree")
		quit(1)
		return

	levels.call(&"load_level", LEVEL)
	for i in 30:
		await process_frame

	var prop: Node2D = _find(get_root(), "SeabedProp") as Node2D
	if prop == null:
		printerr("level %d built no seabed prop" % (LEVEL + 1))
		quit(1)
		return

	var sprite := prop.get_child(0) as Sprite2D
	var height: float = sprite.texture.get_height() * sprite.scale.y
	var top := prop.global_position.y - height * 0.5
	var base := prop.global_position.y + height * 0.5
	var surface: float = world.get(&"SURFACE_Y")
	print("prop at x %.0f  top %.0f (%.0f under the surface)  base %.0f" % [
		prop.global_position.x, top, top - surface, base
	])

	var body: StaticBody2D = null
	for child: Node in prop.get_children():
		if child is StaticBody2D:
			body = child
	print("collision: %s" % ("none" if body == null else "%d polygon(s)" % body.get_child_count()))

	# Dropped down the trunk, and deliberately NOT with something that floats: a
	# crate would bob at the surface next to the tree and prove nothing either
	# way. A girder sinks, so where it comes to rest is the answer — held up on
	# the trunk, or lying on the seabed underneath it.
	var level: Object = levels.get(&"level")
	var sinker: Object = null
	for candidate: Object in (level.get(&"shop_pool") as Array):
		if float(candidate.get(&"buoyancy")) < 0.5:
			sinker = candidate
			break
	if sinker == null:
		printerr("this level stocks nothing that sinks; cannot test the collision")
		quit(1)
		return

	for i in 3:
		spawner.call(&"spawn", sinker,
			Vector2(prop.global_position.x - 40.0 + i * 40.0, top - 300.0))
	for i in 300:
		await process_frame

	# Held means it stopped clear of the floor. Not "in the top half of the prop":
	# the trunk narrows as it rises, so a piece dropped on it slides down to
	# where the wood is wide enough to carry it, and that is the trunk working
	# rather than failing.
	const CLEAR := 60.0
	var held_up := 0
	var lowest := top
	for piece: Node in get_root().get_tree().get_nodes_in_group(&"bridge_objects"):
		var at := (piece as Node2D).global_position
		lowest = maxf(lowest, at.y)
		if at.y < base - CLEAR:
			held_up += 1
	print("%s held clear of the floor: %d of 3  (lowest rest %.0f, seabed %.0f)" % [
		sinker.get(&"display_name"), held_up, lowest, base
	])

	var shot := get_root().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path("res://tools/_seabed_prop_shot.png"))
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
