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
	_crossing.set_course(level.car_start(), level.goal_x())
	_shop.open_for(level)
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


func advance() -> void:
	if is_last():
		campaign_finished.emit()
		return
	load_level(index + 1)


func retry() -> void:
	load_level(index)
