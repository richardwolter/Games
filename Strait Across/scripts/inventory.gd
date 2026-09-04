## Objects the player owns but hasn't placed yet.
##
## Placing an object takes it out of here; deleting or clearing a placed object
## puts it back. Nothing is destroyed by experimenting — only by a failed
## crossing being a waste of time, which is the intended cost.
class_name Inventory
extends Node

signal changed()

var _counts: Dictionary[ObjectDef, int] = {}


func add(def: ObjectDef, amount: int = 1) -> void:
	if def == null:
		return
	_counts[def] = _counts.get(def, 0) + amount
	changed.emit()


## Returns false if there was nothing to take.
func take(def: ObjectDef) -> bool:
	if count(def) <= 0:
		return false
	_counts[def] -= 1
	changed.emit()
	return true


## Wipe everything unplaced. Used between levels: money carries over, pieces
## don't, so a level is always solved with pieces bought for that level.
func clear() -> void:
	_counts.clear()
	changed.emit()


func count(def: ObjectDef) -> int:
	return _counts.get(def, 0)


## Every def the player owns at least one of, for saving. Returned by value —
## callers must not hold onto it across a change.
func counts() -> Dictionary[ObjectDef, int]:
	return _counts.duplicate()


## Replace the whole stock at once, on load. Emits one change, not one per def.
func set_counts(counts_by_def: Dictionary[ObjectDef, int]) -> void:
	_counts = counts_by_def.duplicate()
	changed.emit()


func total() -> int:
	var sum := 0
	for amount: int in _counts.values():
		sum += amount
	return sum
