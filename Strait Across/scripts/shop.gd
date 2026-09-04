## Sells bridge pieces for money. Replaces the old factory: the player chooses
## what they get, but not without limit.
##
## Two counters that are easy to confuse, so: `remaining` is how many units of a
## piece this level will *sell* you, and Inventory is what you've bought and not
## yet placed. Buying moves one unit from the first to the second. Recalling a
## placed piece returns it to Inventory, never to the shop — the level's stock is
## spent for good once bought.
class_name Shop
extends Node

signal stock_changed()
## A tier was opened. `contents` is what came out, in roll order.
signal box_opened(box: BoxDef, contents: Array[ObjectDef])
signal purchase_failed(reason: String)

var level: LevelDef = null

var _economy: Economy
var _inventory: Inventory
## Units of each piece this level will still sell.
var _remaining: Dictionary[ObjectDef, int] = {}


func setup(economy: Economy, inventory: Inventory) -> void:
	_economy = economy
	_inventory = inventory


## Restock for a new level. Anything unsold from the previous level is gone.
func open_for(new_level: LevelDef) -> void:
	level = new_level
	_remaining.clear()
	for i in level.shop_pool.size():
		_remaining[level.shop_pool[i]] = level.stock_for(i)
	stock_changed.emit()


func remaining(def: ObjectDef) -> int:
	return _remaining.get(def, 0)


## The whole stock table, for saving. Only defs in the current level's pool are
## in here, which is exactly what a save needs to restore.
func remaining_all() -> Dictionary[ObjectDef, int]:
	return _remaining.duplicate()


## Overwrite what's left to sell, on load. Called after open_for() has set the
## level's full stock, so anything the save doesn't mention keeps its fresh count
## — that's the right answer when a level's pool has grown since the save.
func set_remaining(counts_by_def: Dictionary[ObjectDef, int]) -> void:
	for def: ObjectDef in counts_by_def:
		if _remaining.has(def):
			_remaining[def] = counts_by_def[def]
	stock_changed.emit()


## Buy one unit into stock. Returns false and says why if it can't happen, so the
## HUD doesn't have to re-derive the reason.
func buy(def: ObjectDef) -> bool:
	if remaining(def) <= 0:
		purchase_failed.emit("%s is sold out this level" % def.display_name)
		return false
	if not _economy.spend(def.price):
		purchase_failed.emit("Not enough money for a %s" % def.display_name)
		return false

	_remaining[def] -= 1
	_inventory.add(def, 1)
	stock_changed.emit()
	return true


## Boxes ignore per-piece stock on purpose: once the shop's good pieces are sold
## out, gambling is the only way left to improve the build. It's a worse deal
## per dollar in expectation only when you'd have bought the cheap pieces anyway.
func buy_box(box: BoxDef) -> bool:
	if box.pool.is_empty():
		purchase_failed.emit("%s is empty" % box.display_name)
		return false
	if not _economy.spend(box.price):
		purchase_failed.emit("Not enough money for a %s" % box.display_name)
		return false

	var contents := box.roll()
	for def: ObjectDef in contents:
		_inventory.add(def, 1)
	box_opened.emit(box, contents)
	return true
