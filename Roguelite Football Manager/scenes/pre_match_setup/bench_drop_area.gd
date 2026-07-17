class_name BenchDropArea
extends PanelContainer

## Accepts a player chip dragged out of a lineup slot and clears that slot.
signal player_returned(source_slot: int)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("source_slot") and data["source_slot"] != -1

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	player_returned.emit(data["source_slot"])
