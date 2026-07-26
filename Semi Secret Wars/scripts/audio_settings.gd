extends Node
## Autoload owning the three audio volumes (Master / Music / Effects) and the
## bus routing they act on. See scenes/ui/settings_panel.gd for the UI.
##
## Buses are created HERE at runtime rather than in a default_bus_layout.tres:
## the layout resource is loaded before autoloads run and silently falls back
## to a Master-only layout if it fails to import, which would leave every
## `player.bus = "SFX"` assignment pointing at a bus that doesn't exist (Godot
## logs an error per player and drops it back to Master — i.e. the sliders
## would appear to do nothing). Building them in code means the buses exist
## before any scene is loaded, on every machine, with no import step.
##
## Routing: Music and SFX both send to Master, so the Master slider scales
## everything and the other two trim within it. Anything that forgets to set a
## bus lands on Master, which is the safe default — it still responds to the
## master slider, it just can't be trimmed separately.
##
## Settings live in their own file, NOT in save.json: GameState.full_reset()
## deletes the save, and losing your volume settings because you started a new
## game would be a bug.

const CONFIG_PATH := "user://settings.cfg"
const CONFIG_SECTION := "audio"

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

## Below this the slider snaps to true silence instead of a very quiet mix —
## linear_to_db(0.0) is -inf, which some platforms mishandle, so we mute the
## bus outright at the bottom of the range.
const MUTE_THRESHOLD := 0.001

signal changed

## All three are linear 0.0-1.0 (what the sliders show), converted to dB only
## when pushed to the AudioServer — a linear slider is what reads as
## "half volume" to a player, a dB one does not.
var master := 1.0
var music := 1.0
var effects := 1.0

func _ready() -> void:
	_ensure_buses()
	_load()
	apply_all()

## Creates Music/SFX if this project's bus layout doesn't already define them,
## and makes sure both route into Master. Safe to call twice.
func _ensure_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, BUS_MASTER)

func set_master(v: float) -> void:
	master = clampf(v, 0.0, 1.0)
	_apply_bus(BUS_MASTER, master)
	_save()
	changed.emit()

func set_music(v: float) -> void:
	music = clampf(v, 0.0, 1.0)
	_apply_bus(BUS_MUSIC, music)
	_save()
	changed.emit()

func set_effects(v: float) -> void:
	effects = clampf(v, 0.0, 1.0)
	_apply_bus(BUS_SFX, effects)
	_save()
	changed.emit()

func apply_all() -> void:
	_apply_bus(BUS_MASTER, master)
	_apply_bus(BUS_MUSIC, music)
	_apply_bus(BUS_SFX, effects)

func _apply_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= MUTE_THRESHOLD)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, MUTE_THRESHOLD)))

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return  # no settings file yet — keep the full-volume defaults
	master = clampf(float(cfg.get_value(CONFIG_SECTION, "master", 1.0)), 0.0, 1.0)
	music = clampf(float(cfg.get_value(CONFIG_SECTION, "music", 1.0)), 0.0, 1.0)
	effects = clampf(float(cfg.get_value(CONFIG_SECTION, "effects", 1.0)), 0.0, 1.0)

## Written on every slider change. Cheap (three floats) and means a crash or an
## alt-F4 never loses the setting the player just made.
func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(CONFIG_SECTION, "master", master)
	cfg.set_value(CONFIG_SECTION, "music", music)
	cfg.set_value(CONFIG_SECTION, "effects", effects)
	cfg.save(CONFIG_PATH)
