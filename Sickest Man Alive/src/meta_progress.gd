extends Node

## Everything that outlives a run: the DNA you banked and what you spent it on.
##
## An autoload, and the project's only one. It exists because the game now has
## two scenes -- the prep menu and the run -- and `change_scene_to_file` throws
## away everything that is not here. It holds the scene paths for that reason
## too: the two screens have to name each other, and a const on the singleton is
## the one place that is not a circular reference.
##
## Deliberately dumb about the run itself. It knows a run's RESULT (handed over
## by RunManager as `last_result`) and nothing about how it was played.

signal dna_changed(total: int)
signal levels_changed()

const SCENE_PREP: String = "res://scenes/prep.tscn"
const SCENE_RUN: String = "res://scenes/main.tscn"
const UPGRADES_PATH: String = "res://config/upgrades.tres"

const SAVE_PATH: String = "user://save.json"
## Bumped whenever the shape of the save changes. `MIN_LOADABLE_VERSION` is the
## oldest one this build can still read; anything below it is discarded and the
## player starts fresh, which is the honest failure for a prototype -- a
## half-migrated save is a bug that shows up hours later.
## Version 2 added the carried item. MIN_LOADABLE stayed at 1 because that field
## is purely additive and its absence is a legal state -- "carried nothing" -- so
## a v1 save reads correctly with no migration step and no half-migrated case for
## the warning above to be about. Do not assume the next bump gets off as lightly.
const SAVE_VERSION: int = 2
const MIN_LOADABLE_VERSION: int = 1

var dna: int = 0
## item resource path -> owned level. Absent means level 0.
var levels: Dictionary = {}

## The one thing carried out of the last finished run, as a resource PATH and
## never as an Item.
##
## The whole point of the reward is that it arrives next run at whatever level
## has been BOUGHT by then, and a stored Item would freeze it at the level it was
## won with. A stored Item is also exactly the object RunManager._upgraded_copy
## exists to stop anyone else from creating -- and it would mean serialising a
## StatModifier graph into JSON.
var carried_item_path: String = ""

## The designer's document, loaded once. Null is survivable everywhere: an
## upgrade table that failed to load means no upgrades exist, not a crash.
##
## Read it through `table()`, never directly. Under `--headless --script` the
## autoload node exists from the first line of the harness but its `_ready` has
## not run yet, so anything that waits for `_ready` to fill this in reads null in
## exactly the place the tests live.
var upgrade_table: UpgradeTable = null

## Whether the one-time setup below has happened, however it was triggered.
var _booted: bool = false

## What the last run paid out, as DnaPayout.breakdown plus the run's own
## details. Read by the prep menu for its one-line recap, and by the results
## panel. Empty on a cold boot.
var last_result: Dictionary = {}

## Set to replay a specific map across the scene swap. `run_seed` is exported on
## main.tscn and there is nowhere to inject it through change_scene_to_file, so
## RunManager prefers this when it is non-zero.
var next_run_seed: int = 0


func _ready() -> void:
	_boot()


## Loads the table and the save, once, whoever asks first. Every public entry
## point calls this rather than trusting `_ready`, so the singleton is correct
## the instant anything touches it -- game, editor tool or headless test alike.
func _boot() -> void:
	if _booted:
		return
	_booted = true
	if ResourceLoader.exists(UPGRADES_PATH):
		upgrade_table = load(UPGRADES_PATH) as UpgradeTable
	if upgrade_table == null:
		push_warning("No upgrade table at %s -- items will be un-upgradable." % UPGRADES_PATH)
	load_game()


## The upgrade document, guaranteed loaded. Still nullable: there may not be one.
func table() -> UpgradeTable:
	_boot()
	return upgrade_table


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# --- upgrades ---

func level_of(path: String) -> int:
	_boot()
	return int(levels.get(path, 0))


func max_level_of(path: String) -> int:
	var t := table()
	if t == null:
		return 0
	return t.effective_max_level(path)


## -1 means "cannot be bought at all" -- maxed out, or nothing authored.
func cost_of_next(path: String) -> int:
	var t := table()
	if t == null:
		return -1
	if level_of(path) >= max_level_of(path):
		return -1
	return t.cost_per_level


func can_upgrade(path: String) -> bool:
	var cost := cost_of_next(path)
	return cost >= 0 and dna >= cost


## What the NEXT level does, for the prep menu to advertise. Falls back to the
## level already owned once the item is maxed, so the row never goes blank.
func next_summary(path: String) -> String:
	var t := table()
	if t == null:
		return ""
	var lvl := level_of(path)
	if lvl < max_level_of(path):
		return t.summary_for(path, lvl + 1)
	return t.summary_for(path, lvl)


## Spends and banks in one step. A deliberate player action, so it saves
## immediately -- the sibling project's rule, and the reason a crash never costs
## someone a purchase they watched happen.
func buy_upgrade(path: String) -> bool:
	if not can_upgrade(path):
		return false
	dna -= cost_of_next(path)
	levels[path] = level_of(path) + 1
	save_game()
	dna_changed.emit(dna)
	levels_changed.emit()
	return true


# --- currency ---

## Banking a run's payout. Does NOT save on its own: the caller is RunManager,
## which saves once after writing `last_result` as well, and two writes for one
## event is how a save file ends up half-updated.
func add_dna(amount: int) -> void:
	_boot()
	if amount == 0:
		return
	dna = maxi(dna + amount, 0)
	dna_changed.emit(dna)


# --- persistence ---

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"dna": dna,
		"levels": levels,
		"carried": carried_item_path,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write %s: %s" % [SAVE_PATH, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


## Reads the save, or leaves the defaults standing. Every failure path here is a
## warning and a fresh start rather than an error: a save this build cannot read
## is not worth crashing a game over.
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("Could not read %s" % SAVE_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file is not a JSON object; ignoring it.")
		return

	var data: Dictionary = parsed
	var version := int(data.get("version", 0))
	if version < MIN_LOADABLE_VERSION or version > SAVE_VERSION:
		push_warning("Save version %d is not readable by this build (%d..%d); starting fresh."
			% [version, MIN_LOADABLE_VERSION, SAVE_VERSION])
		return

	dna = maxi(int(data.get("dna", 0)), 0)

	# Rebuilt key by key rather than assigned wholesale: JSON gives back untyped
	# values, an item may have been deleted since the save was written, and the
	# table's ceiling may have come DOWN -- and a level past the authored ones
	# would have modifiers_for read off the end of the array.
	levels = {}
	var stored: Variant = data.get("levels", {})
	if typeof(stored) == TYPE_DICTIONARY:
		for path: String in (stored as Dictionary):
			var cap := max_level_of(path)
			if cap <= 0:
				continue
			var owned := clampi(int((stored as Dictionary)[path]), 0, cap)
			if owned > 0:
				levels[path] = owned

	# Validated the same way and for the same reason the levels are: an item may
	# have been deleted or renamed since the save was written, and a carried path
	# that no longer names anything the run can build would wedge the grant.
	# Tested against ITEM_PATHS rather than against the disk, because a .tres that
	# still exists but is no longer in the run's pool is not something the run can
	# hand out.
	carried_item_path = ""
	var carried := String(data.get("carried", ""))
	if carried != "" and RunManager.ITEM_PATHS.has(carried):
		carried_item_path = carried

	dna_changed.emit(dna)
	levels_changed.emit()


## Records the one thing carried out of a finished run.
##
## Saves immediately, on the same rule `buy_upgrade` follows: it is a deliberate
## choice the player watched themselves make, and a crash on the results screen
## must never take it back.
func set_carried(path: String) -> void:
	_boot()
	carried_item_path = path
	save_game()


## Hands the carried item over and forgets it. Consumed at the GRANT rather than
## expiring on a clock: an expiry would need a "runs elapsed" counter nothing
## else in the save has, and the observable behaviour is identical, because the
## only moment the item can be used is the start of the very next run. Consuming
## here rather than at pick-up is also what lets the player quit from the results
## screen and still walk in with it.
func take_carried() -> String:
	_boot()
	var path := carried_item_path
	if path == "":
		return ""
	carried_item_path = ""
	save_game()
	return path


## The prep menu's reset button, and the way a test starts from nothing.
func reset_progress() -> void:
	_boot()
	dna = 0
	levels = {}
	last_result = {}
	# Easy to forget, and the symptom is a ghost item appearing in the first run
	# after an erase that nobody would connect back to this button.
	carried_item_path = ""
	save_game()
	dna_changed.emit(dna)
	levels_changed.emit()
