## Owns which level is being played and what happens when it's beaten.
##
## Loading a level is a hard reset of everything except money: new geometry, fresh
## shop stock, empty inventory, empty strait. Advancing only happens on an actual
## crossing — a near miss pays out but doesn't open the next level.
class_name LevelManager
extends Node

signal level_loaded(level: LevelDef, index: int)
## Beat the last level. Nothing left to widen.
signal campaign_finished()

@export var levels: Array[LevelDef] = []

var index: int = 0
var level: LevelDef = null
## Highest level index the player has cleared, +1. Used to gate replays.
var unlocked: int = 0

## Leaderboard standings per level index: the best crossings of that strait,
## ascending, capped at STANDINGS_KEPT.
##
## A score is what the bridge cost — every piece in the water when the truck set
## off, at its shop price — so LOWER IS BETTER and the entry at index 0 is first
## place. A level with no entry has never been crossed.
##
## A table rather than a single best, because a leaderboard people are meant to
## climb needs somewhere to stand while they climb it: beating your fifth-best
## run is progress and should show as progress, even though the record is
## untouched.
##
## Kept here beside `unlocked` because it is the same kind of thing — what the
## player has achieved across the campaign, rather than anything about the run
## currently being played.
const STANDINGS_KEPT := 5
var standings: Dictionary[int, PackedInt32Array] = {}

var _world: Node2D
var _shop: Shop
var _economy: Economy
var _inventory: Inventory
var _spawner: Node
var _crossing: CrossingManager


func setup(
	world: Node2D,
	shop: Shop,
	economy: Economy,
	inventory: Inventory,
	spawner: Node,
	crossing: CrossingManager
) -> void:
	_world = world
	_shop = shop
	_economy = economy
	_inventory = inventory
	_spawner = spawner
	_crossing = crossing


func load_level(new_index: int) -> void:
	# The scene may supply its own list; otherwise the campaign is the list.
	if levels.is_empty():
		levels.assign(Campaign.levels())
	if levels.is_empty():
		push_error("LevelManager has no levels")
		return
	index = clampi(new_index, 0, levels.size() - 1)
	level = levels[index]

	_crossing.reset()
	_spawner.discard_all()
	_inventory.clear()

	_world.build(level)
	_spawner.set_area(_world.build_area(), _world.escape_bounds())
	_crossing.truck_power = level.truck_power
	_crossing.set_course(level.car_start(), level.goal_x(), -level.half_width)
	_shop.open_for(level)
	_economy.reward_scale = level.reward_scale
	_economy.level_attempt_floor = level.attempt_floor
	_economy.reset_score()

	level_loaded.emit(level, index)


func is_last() -> bool:
	return index >= levels.size() - 1


## Called after a successful crossing. Returns true if this was the first clear,
## which is what the completion bonus is paid for.
func mark_cleared() -> bool:
	var first := index >= unlocked
	if first:
		unlocked = index + 1
	return first


## File a finished crossing into this level's standings. Returns the rank it took
## (1 is first place) or 0 if it didn't make the table.
##
## Ties keep the older run ahead: matching a score is not beating it, and the
## player who did it first should not be pushed down the board by their own
## repeat of the same bridge.
func submit_bridge(points: int) -> int:
	var table := table_for(index)
	var rank := table.size() + 1
	for i in table.size():
		if points < table[i]:
			rank = i + 1
			break
	if rank > STANDINGS_KEPT:
		return 0

	var updated := PackedInt32Array(table)
	updated.insert(rank - 1, points)
	if updated.size() > STANDINGS_KEPT:
		updated.resize(STANDINGS_KEPT)
	standings[index] = updated
	return rank


func table_for(level_index: int) -> PackedInt32Array:
	return standings.get(level_index, PackedInt32Array())


## What to beat on a level, or -1 if it has never been crossed. Defaults to the
## level being played, so the HUD can ask without knowing an index.
func bridge_record(level_index: int = -1) -> int:
	var table := table_for(level_index if level_index >= 0 else index)
	return table[0] if not table.is_empty() else -1


func advance() -> void:
	if is_last():
		campaign_finished.emit()
		return
	load_level(index + 1)


func retry() -> void:
	load_level(index)
