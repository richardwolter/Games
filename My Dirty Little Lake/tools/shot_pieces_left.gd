extends Node
## Opens the lake on a real window, tells the HUD there are 42 pieces left and saves the
## bottom-left corner, so the line can be seen standing over the pollution meter rather than
## behind it. Desktop build, not --headless. Own save; writes nothing of the player's.
##
##   godot --path . --fixed-fps 60 res://tools/shot_pieces_left.tscn

const SHOT := "res://tools/last_pieces_left.png"
const SAVE_PATH := "user://shot_pieces_left.save"

var _main: Node
var _frames := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().root.add_child.call_deferred(_main)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	# Held every frame: the lake recounts twice a second and would put the real figure back.
	_main.set(&"_left_over", 42)
	if _frames < 60:
		return
	var shot := get_viewport().get_texture().get_image()
	var crop := shot.get_region(Rect2i(0, shot.get_height() - 300, 760, 300))
	crop.save_png(ProjectSettings.globalize_path(SHOT))
	get_tree().quit()
