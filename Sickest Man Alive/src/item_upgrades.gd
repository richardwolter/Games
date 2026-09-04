@tool
class_name ItemUpgrades
extends Resource

## One item's whole upgrade track.
##
## Keyed by resource PATH rather than by holding the Item itself, because the
## save file has to name it too, and a path is the one identifier that survives
## being written to JSON. It also keeps this resource from pulling every item in
## the game into memory the moment the table loads.

@export var item_path: String = ""

## Levels in order, so `levels[0]` is level 1. Owning fewer levels than the
## table's `max_level` is normal and simply means the last ones are not authored
## yet -- see UpgradeTable.effective_max_level.
@export var levels: Array[UpgradeLevel] = []


func level(n: int) -> UpgradeLevel:
	if n < 1 or n > levels.size():
		return null
	return levels[n - 1]
