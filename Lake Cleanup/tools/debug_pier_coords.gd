extends Node

func _ready() -> void:
	await get_tree().process_frame

	var lake = get_parent() as Lake
	if lake == null:
		print("ERROR: Attach to Main node")
		return

	print("\n=== PIER COORDINATES ===")
	for dropoff in lake._dropoffs:
		var world_pos = Iso.tile_to_world(dropoff.berth.x, dropoff.berth.y)
		print("%s: berth = Vector2(%.1f, %.1f) | world = %.1f, %.1f" % [
			dropoff.kind_name(),
			dropoff.berth.x,
			dropoff.berth.y,
			world_pos.x,
			world_pos.y
		])
	print("========================\n")
