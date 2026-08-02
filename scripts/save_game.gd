## Reading and writing the single save slot.
##
## The save has to survive the player alt-F4ing mid-build, so it holds the bridge
## itself — every placed piece's def, position, rotation and artwork variant —
## not just progression. Coming back to an empty strait with the right amount of
## money in hand would still be starting over.
##
## Stored as JSON in user://, which is deliberate for a prototype: it is
## readable, hand-editable when a physics change makes an old build nonsense, and
## a corrupt file fails at parse time instead of crashing the game.
##
## Defs are referenced by resource path. A save from before a .tres was renamed
## or deleted therefore loads with that piece missing rather than failing whole —
## every lookup goes through _def_at(), which returns null and is skipped.
class_name SaveGame
extends RefCounted

const PATH := "user://save.json"
## Bumped when the shape of the file changes incompatibly. A save from a
## different version is discarded rather than half-read.
const VERSION := 1


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


## Which level the save is sitting on, without restoring anything.
##
## For the title screen, which wants to match its music to how far the player has
## got but has no game to apply a save to. Zero when there is no save, which is
## also the right answer: a new game starts on level 1.
static func saved_level() -> int:
	var data := load_data()
	return int(data.get("level", 0)) if not data.is_empty() else 0


static func delete() -> void:
	if not has_save():
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## Gathers the whole game into one dictionary. `bridge` is passed in rather than
## read from the spawner, because during a crossing attempt the pieces on screen
## are mid-collapse and the layout worth keeping is the one from before the car.
static func capture(
	levels: LevelManager,
	economy: Economy,
	inventory: Inventory,
	shop: Shop,
	bridge: Array[Dictionary],
	blueprints: Blueprints
) -> Dictionary:
	return {
		"version": VERSION,
		"level": levels.index,
		"unlocked": levels.unlocked,
		"money": economy.money,
		"best_score": economy.best_score,
		"best_progress": economy.best_progress,
		"inventory": _defs_to_paths(inventory.counts()),
		"shop": _defs_to_paths(shop.remaining_all()),
		"bridge": bridge_to_json(bridge),
		# Added after VERSION 1 shipped. A key that simply isn't there reads back as
		# "no slots", so this needed no version bump and no discarded saves.
		"blueprints": blueprints.to_json(),
	}


static func save(data: Dictionary) -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


## Returns the saved dictionary, or an empty one if there's nothing usable.
## Never throws: a save that can't be read is treated as no save at all, because
## refusing to start the game is a worse outcome than losing a build.
static func load_data() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_warning("Save file is not valid JSON; ignoring it")
		return {}
	var data := parsed as Dictionary
	if data.get("version", 0) != VERSION:
		push_warning("Save file is version %s, expected %d; ignoring it" % [
			data.get("version", "?"), VERSION
		])
		return {}
	return data


## Puts a captured save back into the live systems. The caller must have loaded
## the right level first — that sets up the world, the shop's full stock and the
## piece pool this then overwrites.
static func apply(
	data: Dictionary,
	levels: LevelManager,
	economy: Economy,
	inventory: Inventory,
	shop: Shop,
	spawner: Node,
	blueprints: Blueprints
) -> void:
	levels.unlocked = int(data.get("unlocked", 0))

	# Set money by delta so the change signal fires and the dock updates; there
	# is deliberately no setter on Economy, since nothing else may assign money.
	economy.add(int(data.get("money", 0)) - economy.money)
	economy.best_score = int(data.get("best_score", 0))
	# Absent in saves written before distance records existed. Zero is the right
	# reading of that: the next attempt sets the first record of the run.
	economy.best_progress = float(data.get("best_progress", 0.0))
	economy.score_changed.emit(economy.best_score)

	inventory.set_counts(_paths_to_defs(data.get("inventory", {})))
	shop.set_remaining(_paths_to_defs(data.get("shop", {})))
	spawner.restore(bridge_from_json(data.get("bridge", [])))
	blueprints.from_json(data.get("blueprints", []))


static func _defs_to_paths(counts: Dictionary) -> Dictionary:
	var out := {}
	for def: ObjectDef in counts:
		if def != null and not def.resource_path.is_empty():
			out[def.resource_path] = counts[def]
	return out


static func _paths_to_defs(by_path: Variant) -> Dictionary[ObjectDef, int]:
	var out: Dictionary[ObjectDef, int] = {}
	if by_path is not Dictionary:
		return out
	for path: Variant in (by_path as Dictionary):
		var def := _def_at(str(path))
		if def != null:
			out[def] = int((by_path as Dictionary)[path])
	return out


static func bridge_to_json(bridge: Array[Dictionary]) -> Array:
	var out := []
	for entry: Dictionary in bridge:
		var def := entry.get(&"def") as ObjectDef
		if def == null or def.resource_path.is_empty():
			continue
		var at := entry.get(&"position") as Vector2
		out.append({
			"def": def.resource_path,
			"x": at.x,
			"y": at.y,
			"rotation": entry.get(&"rotation", 0.0),
			"variant": entry.get(&"variant", -1),
		})
	return out


static func bridge_from_json(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if raw is not Array:
		return out
	for item: Variant in (raw as Array):
		if item is not Dictionary:
			continue
		var entry := item as Dictionary
		var def := _def_at(str(entry.get("def", "")))
		if def == null:
			continue
		out.append({
			&"def": def,
			&"position": Vector2(
				float(entry.get("x", 0.0)), float(entry.get("y", 0.0))
			),
			&"rotation": float(entry.get("rotation", 0.0)),
			&"variant": int(entry.get("variant", -1)),
		})
	return out


## Null when the .tres has been renamed or removed since the save was written.
static func _def_at(path: String) -> ObjectDef:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as ObjectDef
