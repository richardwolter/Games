## Player-made checkpoints of a bridge.
##
## The autosave already keeps the strait exactly as you left it, but that is the
## one thing it can do: it follows you forward and has no memory of the span that
## was working ten minutes ago. Recalling everything, gambling on a box that
## reshapes the plan, or simply pulling one plank too many are all one-way, and
## the only way back was to rebuild by hand.
##
## A slot is a *layout*, not a save game. It records where the pieces were and
## nothing else — no money, no shop stock, no level progress — so loading one can
## never undo a purchase or hand back money that was spent. The pieces come out of
## the same pool they always do: everything in the water is recalled to stock
## first, then the layout is re-placed from stock as far as stock allows.
##
## Slots are tied to the level they were taken on. A span shaped for The Narrows
## is nonsense across a wider strait, and silently dropping it into one would look
## like the feature was broken.
class_name Blueprints
extends Node

## Three, because the interesting uses are "before I try something", "the one
## that nearly worked" and "the one I keep coming back to". A longer list turns a
## one-click safety net into filing.
const SLOTS := 3

signal changed()

## One entry per slot: an empty Dictionary for an unused one, otherwise
## {level: int, bridge: Array[Dictionary]}.
var _slots: Array[Dictionary] = []


func _init() -> void:
	for i in SLOTS:
		_slots.append({})


func slot(index: int) -> Dictionary:
	if index < 0 or index >= _slots.size():
		return {}
	return _slots[index]


func is_empty(index: int) -> bool:
	return slot(index).is_empty()


## How many pieces a slot holds, for the label on its row.
func piece_count(index: int) -> int:
	var data := slot(index)
	if data.is_empty():
		return 0
	return (data["bridge"] as Array).size()


## The level a slot was taken on, or -1 for an empty slot.
func level_of(index: int) -> int:
	var data := slot(index)
	return int(data.get("level", -1)) if not data.is_empty() else -1


## Overwrites without asking. The HUD puts the confirmation in front of it, where
## it can name what is being written over.
func store(index: int, level_index: int, bridge: Array[Dictionary]) -> void:
	if index < 0 or index >= _slots.size():
		return
	_slots[index] = {"level": level_index, "bridge": bridge.duplicate(true)}
	changed.emit()


func clear_slot(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	_slots[index] = {}
	changed.emit()


## Levels are wiped along with everything else when a new game starts.
func clear_all() -> void:
	for i in _slots.size():
		_slots[i] = {}
	changed.emit()


## Slots survive quitting, so they ride along in the save file. Defs go out as
## resource paths, same as the live bridge does.
func to_json() -> Array:
	var out := []
	for data: Dictionary in _slots:
		if data.is_empty():
			out.append(null)
			continue
		out.append({
			"level": data["level"],
			"bridge": SaveGame.bridge_to_json(data["bridge"] as Array[Dictionary]),
		})
	return out


func from_json(raw: Variant) -> void:
	clear_all()
	if raw is not Array:
		return
	var items := raw as Array
	for i in mini(items.size(), _slots.size()):
		if items[i] is not Dictionary:
			continue
		var entry := items[i] as Dictionary
		var bridge := SaveGame.bridge_from_json(entry.get("bridge", []))
		# A slot whose every piece has since been renamed out of the project comes
		# back empty; keeping it would offer a load that does nothing.
		if bridge.is_empty():
			continue
		_slots[i] = {"level": int(entry.get("level", 0)), "bridge": bridge}
	changed.emit()
