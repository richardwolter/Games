extends Node
## The ending at its own pace, for watching the filmed bubble (2026-10-12): a lake on a save
## of its own, emptied bar one piece so the animals and plants come back, and after
## `GROW_FOR` seconds the last piece taken, which raises the farewell, the credits and the
## reel as a finished run does. Nothing is sped up. Never touches the player's save.
## Desktop build:
##
##   godot --path . res://tools/play_ending.tscn

const Iso := preload("res://scripts/iso.gd")
const SAVE_PATH := "user://play_ending.save"
## Seconds the cleaned lake is left to fill with life before the last piece goes.
const GROW_FOR := 30.0

var _main: Node
var _frames := 0
var _clock := 0.0
var _last := -1


func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	# Under this node, not the root: the root's lake wears the menu.
	add_child.call_deferred(_main)


func _process(delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	var grid: LakeGrid = _main.get(&"_grid")
	if _frames == 6:
		# The piece kept is the one nearest the island, so it can be netted from the beach
		# rather than waited out.
		var near := INF
		for index in grid.stacks.size():
			if grid.stacks[index].is_empty() or grid.dry[index]:
				continue
			var tile := grid.tile_of(index)
			var out := Iso.past_shelf(Vector2(tile))
			if out > 0.5 and out < near:
				near = out
				_last = index
		for index in grid.stacks.size():
			if index == _last:
				grid.stacks[index].resize(1)
			else:
				grid.stacks[index].resize(0)
		grid._rebuild()
		_main._build_filth_map()
		return
	if _frames < 6 or _last < 0:
		return
	_clock += delta
	if _clock >= GROW_FOR and not grid.stacks[_last].is_empty():
		grid.stacks[_last].resize(0)
		grid._rebuild()
		_main._build_filth_map()
		_main.call(&"_ask_the_end")
	if _clock >= GROW_FOR + 3.0 and _clock - delta < GROW_FOR + 3.0:
		print("play_ending: farewell up %s" % str(_main.get(&"_farewell") != null))
