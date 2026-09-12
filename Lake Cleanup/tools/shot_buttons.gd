extends Node
## Opens the corner buttons' canvas (`ButtonTuner`, F7) on a real window and saves a picture
## of it. A probe, not a test: what the canvas is for is looking at, and this is how the
## panel gets checked after it is changed without opening the game by hand.
##
## Run it with the desktop build, not --headless: nothing renders under the dummy driver.

const SHOT := "res://tools/last_buttons.png"

var _main: Node
var _frames := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 8:
		_main.call(&"_tune_buttons")
	if _frames == 20:
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path(SHOT)
		)
	if _frames >= 24:
		get_tree().quit()
