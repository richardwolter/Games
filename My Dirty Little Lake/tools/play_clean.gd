extends Node
## A playable lake nearly cleaned, for judging the nature and the animals by eye: the lake
## on a save of its own, every stack emptied bar a few scattered pools, then handed over.
## Never touches the player's save. Desktop build:
##
##   godot --path . res://tools/play_clean.tscn

const SAVE_PATH := "user://play_clean.save"
## Share of stacks kept, hashed by tile, so a few grimy pools stay to compare against.
const KEEP := 0.03

var _main: Node
var _frames := 0


func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	# Under this node, not the root: the root's lake wears the menu.
	add_child.call_deferred(_main)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames != 6 or _main == null or not _main.is_inside_tree():
		return
	var grid: LakeGrid = _main.get(&"_grid")
	for index in grid.stacks.size():
		if grid.stacks[index].is_empty():
			continue
		var tile := grid.tile_of(index)
		var h := sin(float(tile.x) * 12.9898 + float(tile.y) * 78.233) * 43758.5453
		if h - floor(h) >= KEEP:
			grid.stacks[index].resize(0)
	grid._rebuild()
	_main._build_filth_map()
	set_process(false)
