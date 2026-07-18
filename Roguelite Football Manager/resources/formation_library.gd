class_name FormationLibrary
extends RefCounted

## Designer-approved formation shapes. See BALANCE.md for the slot table.
static func get_all() -> Array[Formation]:
	return [
		_build("High Defense (5-3-2)", 1, 5, 3, 2),
		_build("Solid Defense (4-4-2)", 1, 4, 4, 2),
		_build("Solid Attack (4-3-3)", 1, 4, 3, 3),
		_build("High Attack (3-5-2)", 1, 3, 5, 2),
	]

static func _build(formation_name: String, gk: int, def: int, mid: int, fwd: int) -> Formation:
	var formation := Formation.new()
	formation.formation_name = formation_name
	var slots: Array[Formation.SlotCategory] = []
	for i in gk:
		slots.append(Formation.SlotCategory.GK)
	for i in def:
		slots.append(Formation.SlotCategory.DEF)
	for i in mid:
		slots.append(Formation.SlotCategory.MID)
	for i in fwd:
		slots.append(Formation.SlotCategory.FWD)
	formation.slots = slots
	return formation
