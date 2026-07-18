class_name Formation
extends Resource

enum SlotCategory { GK, DEF, MID, FWD }

@export var formation_name: String = ""

## Ordered list of SlotCategory, one entry per pitch slot (always 11 total).
@export var slots: Array[SlotCategory] = []

func get_count(category: SlotCategory) -> int:
	var count: int = 0
	for slot in slots:
		if slot == category:
			count += 1
	return count
