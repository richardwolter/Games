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

## Where the slot lives. A variable only so a headless check can point the whole
## save system at a scratch file and exercise the real read/write path without
## writing over somebody's run. Nothing in the game changes it.
static var path: String = "user://save.json"
## Bumped when the shape of the file changes incompatibly. A save from a
## different version is discarded rather than half-read.
##
## 2: the levels themselves changed shape. Level 1 went from a 1600-wide strait
## to a 420-wide one and level 2 from 2400 to 900, so a version 1 save restores
## a bridge built for water that no longer exists — pieces land outside the
## walls, inside the seabed, or floating over dry shore. The file is still
## readable; what it describes is not. Discarding it costs a returning player
## their run once, which is the cheaper of the two bad outcomes.
const VERSION := 2


static func has_save() -> bool:
	return FileAccess.file_exists(path)


## Which level the save is sitting on, without restoring anything.
##
## For the title screen, which wants to match its music to how far the player has
## got but has no game to apply a save to. Zero when there is no save, which is
## also the right answer: a new game starts on level 1.
static func saved_level() -> int:
	var data := load_data()
	return int(data.get("level", 0)) if not data.is_empty() else 0


static func delete() -> void:
	# The in-memory buckets go with the file. Without this, NEW GAME deletes the
	# save and the very next capture writes every old level's bridge, inventory
	# and shop straight back out of the cache — the run would come back from the
	# dead one autosave later.
	_buckets = {}
	_buckets_primed = false
	if not has_save():
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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
	# The straits the player is NOT currently standing in, carried through
	# untouched, from memory.
	#
	# This used to re-read the whole save off disk and deep-copy every other
	# level's bucket on EVERY capture — and a capture happens after every piece
	# dropped and every piece recalled. On a full strait that is a file read, a
	# JSON parse and a recursive copy of the entire save, half a second after each
	# of the player's actions, on the main thread. It was the worst hitch in the
	# game while building.
	#
	# The original reasoning was that a cache living across a scene change can go
	# stale behind you. That only holds if something else writes the file, and
	# nothing does: one process, one writer, and _buckets is updated here with
	# exactly what is about to be written. delete() clears it so New Game cannot
	# resurrect a bucket from the run that was just thrown away.
	if not _buckets_primed:
		_prime_buckets()

	_buckets[str(levels.index)] = {
		"bridge": bridge_to_json(bridge),
		"inventory": _defs_to_paths(inventory.counts()),
		"shop": _defs_to_paths(shop.remaining_all()),
		"best_score": economy.best_score,
		"best_progress": economy.best_progress,
		# Added after VERSION 1 shipped. A key that simply isn't there reads back as
		# "no slots", so this needed no version bump and no discarded saves.
		"blueprints": blueprints.to_json(),
	}

	return {
		"version": VERSION,
		"level": levels.index,
		"unlocked": levels.unlocked,
		"money": economy.money,
		# Same reasoning: a save without this has no leaderboard standings, which
		# is exactly what a player who has never crossed anything should have.
		# JSON object keys are strings, so the level index is stringified here and
		# parsed back in apply().
		"records": _records_to_json(levels.standings),
		# What the numbers in `records` MEAN. See SCORE_BASIS.
		"score_basis": SCORE_BASIS,
		# One entry per strait the player has set foot in. See _bucket().
		"levels": _buckets,
	}


## Every level's bucket, as last written. See the note in capture().
##
## Static so it survives the scene change between straits — that change is
## exactly when the other levels' state has to be carried across, and it is the
## same process throughout.
static var _buckets: Dictionary = {}
static var _buckets_primed: bool = false


static func _prime_buckets() -> void:
	var previous: Variant = load_data().get("levels", {})
	_buckets = (previous as Dictionary) if previous is Dictionary else {}
	_buckets_primed = true


## Everything that belongs to ONE strait, keyed by level index as a string.
##
## The save used to hold a single copy of these at the top level, describing
## whichever strait the player was last in. Stepping out to the level select and
## coming back therefore worked, and going to a DIFFERENT strait and coming back
## did not: the bridge, the pieces in hand and the shop's remaining stock were
## all silently replaced by the new level's. A player who spent an hour on level
## 2, dipped into level 1 to try something, and came back found level 2 empty.
##
## Keeping one bucket per level makes leaving and returning lossless in both
## directions, and it is also what stops a returning player getting free
## material: the pieces in the water are the ones they already bought, not a
## fresh bridge on top of a restocked shop.
##
## Money, unlocks and standings stay global — none of them belong to a strait.
##
## Blueprint slots are in here, not out there, because a saved layout is a set of
## positions in one particular strait and is nonsense in a wider one. They used
## to be global and were cleared outright on every level change for exactly that
## reason; now they simply come back with the strait they were taken in.
static func _bucket(data: Dictionary, index: int) -> Dictionary:
	var buckets: Variant = data.get("levels", null)
	if buckets is Dictionary:
		var found: Variant = (buckets as Dictionary).get(str(index), {})
		return found if found is Dictionary else {}

	# A save written before `levels` existed. Its top-level keys describe exactly
	# one strait — the one it was sitting on — so they are read as that strait's
	# bucket and every other level starts clean, which is what that save actually
	# knew. Migrating in the reader rather than bumping VERSION, because the file
	# is entirely readable and discarding a run over a reshuffle would be gratuitous.
	if int(data.get("level", -1)) != index:
		return {}
	return {
		"bridge": data.get("bridge", []),
		"inventory": data.get("inventory", {}),
		"shop": data.get("shop", {}),
		"best_score": data.get("best_score", 0),
		"best_progress": data.get("best_progress", 0.0),
		"blueprints": data.get("blueprints", []),
	}


## What unit the standings are counted in. Bumped whenever a bridge's score
## changes meaning, which is not the same event as the save changing shape:
##
## Standings used to be tier points, roughly 10-60 for a whole bridge, and are
## now the bridge's shop price, in the hundreds. Both are integers and both load
## fine, so nothing here is unreadable — but a table holding both ranks every old
## run above every new one, permanently, and the record the header shows becomes
## a target nobody can reach.
##
## Deliberately NOT a VERSION bump. The money, the pieces in hand and the bridge
## in the water are all still exactly right; only the scoreboard is in the wrong
## unit, and discarding somebody's entire run to fix a scoreboard is the more
## expensive mistake. A save whose basis doesn't match loads with empty
## standings and everything else intact.
const SCORE_BASIS := "price"


## The standings out of a save, or none if they were scored in an older unit.
static func standings_of(data: Dictionary) -> Dictionary[int, PackedInt32Array]:
	if str(data.get("score_basis", "")) != SCORE_BASIS:
		return {}
	return _records_from_json(data.get("records", {}))


static func _records_to_json(records: Dictionary[int, PackedInt32Array]) -> Dictionary:
	var out := {}
	for index: int in records:
		out[str(index)] = Array(records[index])
	return out


static func save(data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
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
	var file := FileAccess.open(path, FileAccess.READ)
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
##
## One path for every arrival, whether the player resumed where they left off or
## picked a different strait off the select screen. There used to be two, and the
## difference between them WAS the bug: the second one deliberately restored no
## level state, because the save only ever held one strait's worth and it
## belonged to somebody else's level. With per-level buckets there is nothing to
## choose between — a strait the player has never entered simply has no bucket,
## and the untouched fresh level stands.
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
	levels.standings = standings_of(data)

	# Set money by delta so the change signal fires and the dock updates; there
	# is deliberately no setter on Economy, since nothing else may assign money.
	economy.add(int(data.get("money", 0)) - economy.money)

	var here := _bucket(data, levels.index)
	if here.is_empty():
		# Never been here. The freshly loaded level is already correct — full shop,
		# empty strait, no record, no saved layouts — so touching nothing is the
		# restore.
		return

	economy.best_score = int(here.get("best_score", 0))
	# Absent in saves written before distance records existed. Zero is the right
	# reading of that: the next attempt sets the first record of the run.
	economy.best_progress = float(here.get("best_progress", 0.0))
	economy.score_changed.emit(economy.best_score)

	inventory.set_counts(_paths_to_defs(here.get("inventory", {})))
	shop.set_remaining(_paths_to_defs(here.get("shop", {})))
	spawner.restore(bridge_from_json(here.get("bridge", [])))
	blueprints.from_json(here.get("blueprints", []))


static func _records_from_json(raw: Variant) -> Dictionary[int, PackedInt32Array]:
	var out: Dictionary[int, PackedInt32Array] = {}
	if raw is not Dictionary:
		return out
	for key: Variant in raw as Dictionary:
		var entry: Variant = (raw as Dictionary)[key]
		var table := PackedInt32Array()
		# A save written before the table existed holds one number per level.
		# Reading it as a one-entry board keeps the record somebody earned.
		for points: int in (entry if entry is Array else [entry]):
			# Zero or negative is a bridge of no pieces, which cannot have carried
			# anything. Dropped rather than trusted.
			if points > 0:
				table.append(points)
		table.sort()
		if not table.is_empty():
			out[int(key)] = table
	return out


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
		# A non-finite position or rotation is refused at the door rather than
		# handed to the physics server. JSON can carry "nan" and "inf", a save can
		# be hand-edited, and one NaN body poisons every body it touches through
		# the solver — a single bad entry can take the whole bridge with it. The
		# cost of dropping it is one missing piece.
		var x := float(entry.get("x", 0.0))
		var y := float(entry.get("y", 0.0))
		var rotation := float(entry.get("rotation", 0.0))
		if not (is_finite(x) and is_finite(y) and is_finite(rotation)):
			push_warning("Save had a non-finite piece; dropping it")
			continue
		out.append({
			&"def": def,
			&"position": Vector2(x, y),
			&"rotation": rotation,
			&"variant": int(entry.get("variant", -1)),
		})
	return out


## Null when the .tres has been renamed or removed since the save was written.
static func _def_at(path: String) -> ObjectDef:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as ObjectDef
