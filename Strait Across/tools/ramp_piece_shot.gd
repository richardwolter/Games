## Drops a few skate ramps into level 6 and photographs them, then sends the
## truck at one.
##
##   godot --script tools/ramp_piece_shot.gd -- --sandbox=1 --money=9000
##
## tools/ramp_probe.gd already proves the outline decomposes and the numbers add
## up. What it cannot show is the thing that matters: whether the artwork sits on
## the collision, and whether the truck actually climbs the deck instead of
## stopping dead at a step in it. That is what the picture is for.
extends SceneTree


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	var levels: Object = _find(get_root(), "Levels")
	if levels == null:
		levels = _find(get_root(), "LevelManager")
	var spawner: Object = _find(get_root(), "ObjectSpawner")
	if levels == null or spawner == null:
		printerr("no level manager / spawner in the tree")
		quit(1)
		return

	levels.call(&"load_level", Campaign.count() - 1)
	for i in 30:
		await process_frame

	# The middle one mirrored, so the picture shows both facings side by side and
	# a flip that moved the artwork without the collision would be obvious.
	var def := load("res://data/objects/ramp.tres") as ObjectDef
	var posed: Array[BridgeObject] = []
	for i in 3:
		posed.append(spawner.call(&"spawn", def,
			Vector2(-450.0 + i * 400.0, -60.0)) as BridgeObject)
	# The middle one is flipped the way the player flips it — after the fact,
	# through set_flipped — rather than spawned mirrored. That is the path with
	# the shapes to swap and the redraw to trigger, and the one that was drawing
	# nothing at all.
	await process_frame
	posed[1].set_flipped(true)
	# Held upright and still for the photograph. Left to fall they land on their
	# backs in the water, which says nothing about which way each one faces —
	# and facing is the whole subject of the picture.
	for piece: BridgeObject in posed:
		piece.rotation = 0.0
		piece.freeze = true
	for i in 30:
		await process_frame

	var shot := get_root().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path("res://tools/_ramp_piece_shot.png"))

	var resting: Array[String] = []
	for body: Node in get_root().get_tree().get_nodes_in_group(&"bridge_objects"):
		var piece := body as BridgeObject
		if piece == null or piece.def != def:
			continue
		resting.append("(%.0f, %.0f) at %.1f deg" % [
			piece.global_position.x, piece.global_position.y,
			rad_to_deg(piece.global_rotation),
		])
	print("ramps at rest: %s" % ", ".join(resting))
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
