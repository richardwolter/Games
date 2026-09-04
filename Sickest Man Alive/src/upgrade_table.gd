@tool
class_name UpgradeTable
extends Resource

## Every item's upgrade track, plus the two numbers that price them.
##
## This is the designer's document. It lives at `config/upgrades.tres` and is
## written by the Upgrade Forge dock; the game only ever reads it. Nothing in
## here is per-save state -- what the PLAYER owns is in `user://save.json`, and
## the two are joined by item path.

## What one level costs, whatever the item and whatever the level. Flat on
## purpose: it makes "a full run buys about five upgrades" arithmetic a designer
## can do in their head, and it is the single knob for retuning the whole economy
## against the bands in DnaBalance.
@export var cost_per_level: int = 375

## Ceiling for every item. Lowering this does not delete authored levels, it just
## stops them being bought -- and MetaProgress clamps saved levels to it on load.
@export var max_level: int = 3

@export var entries: Array[ItemUpgrades] = []


func for_item_path(path: String) -> ItemUpgrades:
	for e in entries:
		if e != null and e.item_path == path:
			return e
	return null


## The highest level this item can actually reach: the table's ceiling, or how
## many levels have been authored for it, whichever is lower. An item with no
## entry at all returns 0 and the prep menu says so rather than offering a
## purchase that would do nothing.
func effective_max_level(path: String) -> int:
	var entry := for_item_path(path)
	if entry == null:
		return 0
	return mini(max_level, entry.levels.size())


## Everything owning `level` grants: levels 1..level, in order. Upgrades are
## CUMULATIVE -- level 3 is not a replacement for level 2, it is level 2 plus
## more, which is what lets a track read as a track.
##
## The returned modifiers are the table's own. Callers duplicate before touching
## them; see RunManager._upgraded_copy.
func modifiers_for(path: String, level: int) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	var entry := for_item_path(path)
	if entry == null:
		return out
	for n in range(1, mini(level, entry.levels.size()) + 1):
		var lvl := entry.level(n)
		if lvl == null:
			continue
		for m in lvl.modifiers:
			if m != null:
				out.append(m)
	return out


## The player-facing line for a level, for the prep menu. Empty when the level is
## not authored, which the menu shows as "no upgrades authored" rather than a
## blank row.
func summary_for(path: String, level: int) -> String:
	var entry := for_item_path(path)
	if entry == null:
		return ""
	var lvl := entry.level(level)
	return lvl.summary if lvl != null else ""
