extends Node

## Player settings that outlive a session. For now only fullscreen: the game
## boots windowed, F1 (action `toggle_fullscreen`) flips borderless fullscreen,
## and the choice is restored on the next launch.

const PATH := "user://settings.cfg"

var fullscreen := false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		fullscreen = cfg.get_value("display", "fullscreen", false)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen") and not event.is_echo():
		fullscreen = not fullscreen
		_apply()
		_save()
		get_viewport().set_input_as_handled()


func _apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _save() -> void:
	# Tools and probes run headless; they must never touch the player's file.
	if DisplayServer.get_name() == "headless":
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(PATH)
