## What the player has done to the electric truck, kept across the whole run.
##
## The first thing in the game that is bought once and stays bought. Pieces are
## per level — Inventory is emptied by every LevelManager.load_level — and that is
## right for material, but an upgrade that evaporated when you moved strait would
## not be progression at all. So this is deliberately NOT touched by a level load,
## and it is saved next to money and unlocks rather than in a level's bucket.
##
## Two axes only, and both change what the truck can DO rather than scaling a
## number the player never sees: a bigger battery buys time, and sealing buys
## mistakes. See the design note in CLAUDE.md — the toolbox gets better, the
## numbers do not just get bigger.
class_name SalvageUpgrades
extends Node

enum Kind { CAPACITY, SEALING }

signal changed()

## Enough charge to cross a short strait at a walking pace with nothing to spare.
const BASE_CAPACITY := 100.0
const CAPACITY_STEP := 40.0
## A dunk costs a quarter of a stock battery, so three of them are fatal.
const BASE_SPLASH := 25.0
## Each sealing level takes this fraction off the remaining splash drain.
## Multiplicative, so the last level is worth less than the first and maxing it
## never makes water free.
const SEALING_STEP := 0.22
const MAX_LEVEL := 4

const CAPACITY_COSTS := [150, 300, 550, 900]
const SEALING_COSTS := [180, 340, 600, 950]

var capacity_level: int = 0
var sealing_level: int = 0
## Which truck START sends. A preference rather than an upgrade, but it is global
## in exactly the same way and belongs in the same place.
var truck_type: int = 0


func capacity() -> float:
	return BASE_CAPACITY + CAPACITY_STEP * float(capacity_level)


func splash_drain() -> float:
	return BASE_SPLASH * pow(1.0 - SEALING_STEP, float(sealing_level))


func level_of(kind: Kind) -> int:
	return capacity_level if kind == Kind.CAPACITY else sealing_level


## What the next level costs, or -1 when there isn't one.
func cost_of(kind: Kind) -> int:
	var level := level_of(kind)
	if level >= MAX_LEVEL:
		return -1
	var costs: Array = CAPACITY_COSTS if kind == Kind.CAPACITY else SEALING_COSTS
	return int(costs[level])


func can_buy(kind: Kind, economy: Economy) -> bool:
	var cost := cost_of(kind)
	return cost >= 0 and economy != null and economy.can_afford(cost)


func buy(kind: Kind, economy: Economy) -> bool:
	if not can_buy(kind, economy):
		return false
	if not economy.spend(cost_of(kind)):
		return false
	if kind == Kind.CAPACITY:
		capacity_level += 1
	else:
		sealing_level += 1
	changed.emit()
	return true


func set_truck(kind: int) -> void:
	if truck_type == kind:
		return
	truck_type = kind
	changed.emit()


## A fresh battery at the current upgrade levels. One per attempt — a battery is
## never carried over, so a failed run always starts the next one full.
func make_battery() -> Battery:
	return Battery.new(capacity(), splash_drain())


## What the next level of each upgrade actually buys, for the shop card. Named
## effects rather than a percentage, because "two more dunks" is the thing the
## player is deciding about.
func effect_of(kind: Kind) -> String:
	if level_of(kind) >= MAX_LEVEL:
		return "Fully upgraded"
	if kind == Kind.CAPACITY:
		return "+%d charge (%d total)" % [
			int(CAPACITY_STEP), int(capacity() + CAPACITY_STEP)
		]
	var next := BASE_SPLASH * pow(1.0 - SEALING_STEP, float(sealing_level + 1))
	return "Dunks cost %d instead of %d" % [roundi(next), roundi(splash_drain())]


func to_json() -> Dictionary:
	return {
		"capacity": capacity_level,
		"sealing": sealing_level,
		"truck": truck_type,
	}


## A save written before any of this existed has no key at all, which reads back
## as an unupgraded diesel truck — exactly what that save meant.
func from_json(raw: Variant) -> void:
	var data := (raw as Dictionary) if raw is Dictionary else {}
	capacity_level = clampi(int(data.get("capacity", 0)), 0, MAX_LEVEL)
	sealing_level = clampi(int(data.get("sealing", 0)), 0, MAX_LEVEL)
	truck_type = clampi(int(data.get("truck", 0)), 0, 1)
	changed.emit()
