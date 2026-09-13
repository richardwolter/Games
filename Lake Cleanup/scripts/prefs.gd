## What the player has set, kept between scenes and between sessions.
##
## The settings board (`settings_skin.gd`) is drawn by whichever scene shows it — the menu
## or the lake — and each of those scenes comes and goes. What the player set on one has to
## be what the other one finds, and what they find tomorrow, so the values live here, in an
## autoload, and are written to `user://settings.cfg` the moment they change. The board
## reads them on its way in and writes them on every press; the scenes apply them (the lake
## to its music and sound engine, both scenes to the window).
##
## Fullscreen is applied here on start, before the first scene is up, so a player who plays
## fullscreen never sees the window first.
extends Node

const PATH := "user://settings.cfg"
const SECTION := "settings"

var music_on: bool = true
var music_level: float = 0.75
var sfx_on: bool = true
var sfx_level: float = 0.8
var fullscreen: bool = false

## Emitted after any value is stored, so a scene that is up can re-read them. The board
## itself does not listen — it is the one that changed them.
signal changed


func _ready() -> void:
	load_prefs()
	apply_fullscreen()


func load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music_on = bool(cfg.get_value(SECTION, "music_on", music_on))
	music_level = clampf(float(cfg.get_value(SECTION, "music_level", music_level)), 0.0, 1.0)
	sfx_on = bool(cfg.get_value(SECTION, "sfx_on", sfx_on))
	sfx_level = clampf(float(cfg.get_value(SECTION, "sfx_level", sfx_level)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value(SECTION, "fullscreen", fullscreen))


func save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "music_on", music_on)
	cfg.set_value(SECTION, "music_level", music_level)
	cfg.set_value(SECTION, "sfx_on", sfx_on)
	cfg.set_value(SECTION, "sfx_level", sfx_level)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.save(PATH)


## Store one value and write the file. One entry point, so nothing can set a value and
## forget the file.
func store(key: StringName, value: Variant) -> void:
	match key:
		&"music_on":
			music_on = bool(value)
		&"music_level":
			music_level = clampf(float(value), 0.0, 1.0)
		&"sfx_on":
			sfx_on = bool(value)
		&"sfx_level":
			sfx_level = clampf(float(value), 0.0, 1.0)
		&"fullscreen":
			fullscreen = bool(value)
		_:
			push_error("Prefs.store: no such setting '%s'" % key)
			return
	save_prefs()
	changed.emit()


func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## Borderless fullscreen rather than exclusive: the lake is a window to alt-tab out of.
func apply_fullscreen() -> void:
	if fullscreen == is_fullscreen():
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
