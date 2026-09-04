extends SceneTree

## Headless check that the ramp's traced outline survives the trip into physics.
##
##   godot --headless --script tools/ramp_probe.gd
##
## The polygon is the one part of a piece with no way to fail loudly: a bad
## outline is not a crash, it is a truck driving through the deck. So this asks
## the things that would be silent otherwise — did the concave outline decompose,
## are the buoyancy points inside the piece, and does the collision cover the
## same area the drawing does.
func _init() -> void:
	await process_frame
	var def := load("res://data/objects/ramp.tres") as ObjectDef
	print("def: %s  shape=%s  size=%s  points=%d" % [
		def.display_name, def.shape, def.size, def.polygon.size()
	])

	var piece := BridgeObject.new()
	piece.setup(def)
	root.add_child(piece)
	await process_frame

	var collisions := 0
	for child: Node in piece.get_children():
		if child is CollisionShape2D:
			collisions += 1
	print("convex parts: %d  collision children: %d" % [
		piece.shapes.size(), collisions
	])

	var outline := def.polygon_points()
	var inside := 0
	for point: Vector2 in piece.buoyancy_points:
		if Geometry2D.is_point_in_polygon(point, outline):
			inside += 1
	print("buoyancy points: %d  inside the outline: %d" % [
		piece.buoyancy_points.size(), inside
	])

	# The convex parts should add up to the outline. Well short means the
	# decomposition dropped pieces; well over means it is claiming air.
	var whole := _area(outline)
	var parts := 0.0
	for part: Shape2D in piece.shapes:
		parts += _area((part as ConvexPolygonShape2D).points)
	print("outline area: %.0f  parts area: %.0f  (%.1f%%)" % [
		whole, parts, parts / whole * 100.0
	])
	print("hull area: %.0f  (%.1f%% of outline — the room-query overclaim)" % [
		_area((piece.shape as ConvexPolygonShape2D).points),
		_area((piece.shape as ConvexPolygonShape2D).points) / whole * 100.0,
	])

	# Flipping has to mirror the collision, not just the picture, and has to
	# leave the piece as valid as it was: same area, same number of parts, points
	# still inside. A mirror that reversed the winding badly would show up here as
	# parts that no longer add up.
	piece.set_flipped(true)
	await process_frame
	var mirrored := def.polygon_points(true)
	var flipped_parts := 0.0
	for part: Shape2D in piece.shapes:
		flipped_parts += _area((part as ConvexPolygonShape2D).points)
	var flipped_inside := 0
	for point: Vector2 in piece.buoyancy_points:
		if Geometry2D.is_point_in_polygon(point, mirrored):
			flipped_inside += 1
	var collisions_after := 0
	for child: Node in piece.get_children():
		if child is CollisionShape2D and not child.is_queued_for_deletion():
			collisions_after += 1
	print("flipped: parts %d (%.0f area, %.1f%%)  collision children %d" % [
		piece.shapes.size(), flipped_parts, flipped_parts / whole * 100.0,
		collisions_after,
	])
	print("flipped: buoyancy points inside %d of %d  mirror is a mirror: %s" % [
		flipped_inside, piece.buoyancy_points.size(),
		is_equal_approx(_area(mirrored), whole),
	])
	quit()


func _area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5
