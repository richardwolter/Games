## Screenshot probe for tree test mode's tree screen: a tree run with part of the tree bought,
## the screen open and a tooltip up, saved to tools/last_tree.png.
##
## Desktop build, not --headless (nothing renders under the dummy driver):
##   <godot> --path . res://tools/shot_tree.tscn --log-file tools/last_tree_shot.log
extends Node

const SAVE_PATH := "user://shot_tree.save"
const OUT := "res://tools/last_tree.png"
const BUY := ["ferry_1", "line_1", "hull_1", "bag_1", "line_2", "pull_1", "bag_2", "dog", "sails_1", "hull_2"]

var _main: Node
var _frames: int = 0


func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	TreeLog.path = "user://shot_tree_playtest.log"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	_main.set(&"tree_mode", true)
	add_child(_main)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 5:
		_main.set(&"sludge", 100000.0)
		for id: String in BUY:
			_main.call(&"buy_node", id)
		_main.set(&"sludge", 2600.0)
		_main.call(&"_set_menu", true)
	if _frames == 8:
		var screen: TreeScreen = _main.get(&"_tree_screen")
		screen.set(&"_hover", "ferry_2")
	if _frames == 40:
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path(OUT))
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(SAVE_PATH)
		get_tree().quit()
