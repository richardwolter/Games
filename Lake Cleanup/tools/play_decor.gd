extends Node
## A playable lake whose shed shelf holds every piece of the 0_mem0ry decoration batch
## (`tools/build_pack_decor.py`, the decor_pk_* pieces), with the shed opened for you. Place,
## turn (R), switch (E), close and reopen the shed as in play. A save of its own, so the
## player's run is never touched. Desktop build:
##
##   godot --path . res://tools/play_decor.tscn

const SAVE_PATH := "user://play_decor.save"

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
	# PLAY_DECOR_SHOT=1: save tools/last_play_decor.png a moment later and quit (a check).
	if _frames == 40 and OS.get_environment("PLAY_DECOR_SHOT") == "1":
		get_viewport().get_texture().get_image().save_png("res://tools/last_play_decor.png")
		get_tree().quit()
	if _frames != 6 or _main == null or not _main.is_inside_tree():
		return
	var sheets: Sheets = _main.get(&"_sheets")
	var unlocked: Array[String] = _main.get(&"unlocked")
	for name: String in sheets.names:
		if (name.begins_with("decor_pk_") or name == "decor_vynil_player") and not unlocked.has(name):
			unlocked.append(name)
	_main.call(&"_set_shed", true)
