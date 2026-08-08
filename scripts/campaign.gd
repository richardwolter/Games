## The campaign: which levels exist, in what order.
##
## One list, loaded from here by everything that needs it — the level select
## screen, and LevelManager when the scene doesn't supply its own. It used to
## live only in main.tscn as an exported array, which was fine while the game
## opened straight into level 1 and stopped being fine the moment a second scene
## had to show the same levels: two lists in two files, silently drifting.
class_name Campaign
extends RefCounted

const PATHS: Array[String] = [
	"res://data/levels/level_1.tres",
	"res://data/levels/level_2.tres",
	"res://data/levels/level_3.tres",
	"res://data/levels/level_4.tres",
	"res://data/levels/level_5.tres",
	"res://data/levels/level_6.tres",
]

## Which level the player picked on the select screen, or -1 to resume the save.
##
## A static, because it has to survive the scene change that carries the choice
## from the select screen to the game, and it is one integer — an autoload for it
## would be a node, a file and a lifetime to reason about for a value that is
## written once and read once.
static var requested_level: int = -1

## True when the select screen was opened FROM the game rather than from the
## title. It decides where its BACK button goes: a player who stepped out of a
## strait to look at the map expects to be put back in it, not dropped onto the
## start menu with their run apparently gone. Set by the HUD on the way out, and
## cleared by the title screen on the way in.
static var return_to_game: bool = false


static func levels() -> Array[LevelDef]:
	var out: Array[LevelDef] = []
	for path: String in PATHS:
		var level := load(path) as LevelDef
		if level != null:
			out.append(level)
	return out


static func count() -> int:
	return PATHS.size()
