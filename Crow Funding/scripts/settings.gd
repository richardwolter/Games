extends Node

## Player settings that outlive a session. Fullscreen: the game boots windowed,
## F1 (action `toggle_fullscreen`) flips borderless fullscreen. Environment: which
## city the balcony looks over (see scripts/environments.gd); F2 cycles it and the
## scene swaps live. Both are restored on the next launch.

signal environment_changed(id: String)

const Envs = preload("res://scripts/environments.gd")

const PATH := "user://settings.cfg"

var fullscreen := false
var environment: String = Envs.CLASSIC


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		fullscreen = cfg.get_value("display", "fullscreen", false)
		environment = cfg.get_value("scene", "environment", Envs.CLASSIC)
	if not Envs.IDS.has(environment):
		environment = Envs.CLASSIC
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen") and not event.is_echo():
		fullscreen = not fullscreen
		_apply()
		_save()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		var i := Envs.IDS.find(environment)
		set_environment(Envs.IDS[(i + 1) % Envs.IDS.size()])
		get_viewport().set_input_as_handled()


func set_environment(id: String) -> void:
	if not Envs.IDS.has(id) or id == environment:
		return
	environment = id
	_save()
	environment_changed.emit(id)


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
	cfg.set_value("scene", "environment", environment)
	cfg.save(PATH)
