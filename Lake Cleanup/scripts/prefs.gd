## What the player has set, kept between scenes and between sessions.
##
## The settings board (`settings_skin.gd`) is drawn by whichever scene shows it — the menu
## or the lake — and each of those scenes comes and goes. What the player set on one has to
## be what the other one finds, and what they find tomorrow, so the values live here, in an
## autoload, and are written to `user://settings.cfg` the moment they change. The board
## reads them on its way in and writes them on every press; this applies them.
##
## The window mode is applied here on start, before the first scene is up, so a player who
## plays fullscreen never sees the window first.
##
## **Nothing here is ever refused** (2026-09-16, issue #26). A save file from an older build
## is thrown away rather than migrated, because a half-understood lake is worse than a fresh
## one — but a settings file is not a save file. A value that makes no sense on this machine
## (a resolution no monitor has, a bind for an action that no longer exists, a window mode
## from a build that had four of them) falls back to its default and is written back. The
## worst a bad line may cost is that one setting.
##
## **The mix is four audio buses** (2026-09-16, issue #26): Master over Music, SFX and
## Ambience. It used to be a decibel figure added to every player by `Sfx` and
## `MusicStation` as they set it, which worked but left no single point to put a master
## slider on, and meant two scripts each held a copy of what the player had set. Now those
## two set only each sound's own balance and their fades, and the sliders are the buses.
extends Node

const PATH := "user://settings.cfg"
const SECTION := "settings"

## What a slider at `level` means in decibels (2026-09-15, Richard: the sliders worked over
## half their travel and the rest was mute).
##
## Every slider used to run straight from its floor to its ceiling in decibels — sixty of
## them for the music — so the groove was linear in decibels and the ear is not. Half way
## along was 28 dB down, which is a sixteenth of the loudness and reads as off; everything
## the player could actually hear was crowded into the top third of the travel.
##
## A decibel is a ratio, and the ear hears ratios: about ten decibels down is half as loud.
## So the travel is a power law instead — `SLIDER_LAW` decibels for every tenfold — which
## puts half the slider at half the loudness, a quarter at a quarter, and gives the same
## amount of control wherever the thumb is. The drawn fill is then honest: the part of the
## groove that is filled is about the part of the loudness being used.
##
## `loudest` is what the top of the travel is worth to that sound, and `silent` its off.
const SLIDER_LAW := 33.2
## Under this the slider is off: the last hundredth of the travel is not worth a whisper.
const SLIDER_FLOOR := 0.02

## The buses, and what the top of each slider is worth on it. Master's top is 0 dB and its
## default is full, so a player who never touches it hears the mix exactly as it was tuned
## by ear before the buses existed; the other three carry the tops `Sfx` and `MusicStation`
## used to add themselves.
const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_AMBIENCE := &"Ambience"
const BUS_TOP := {
	BUS_MASTER: 0.0,
	BUS_MUSIC: 0.0,
	BUS_SFX: 6.0,
	BUS_AMBIENCE: 6.0,
}
const BUS_SILENT := -60.0

enum WindowMode { WINDOWED, BORDERLESS, EXCLUSIVE }

## The FPS caps the board offers, in the order it cycles them. 0 is uncapped.
const FPS_CAPS := [0, 30, 60, 120, 144]

## The smallest window the board will offer. Under this the drawn boards stop fitting.
const LEAST_WINDOW := Vector2i(1280, 720)


static func volume_db(level: float, on: bool, loudest: float, silent: float) -> float:
	level = clampf(level, 0.0, 1.0)
	if not on or level <= SLIDER_FLOOR:
		return silent
	return maxf(loudest + SLIDER_LAW * (log(level) / log(10.0)), silent)


var master_on: bool = true
var master_level: float = 1.0
var music_on: bool = true
var music_level: float = 0.75
var sfx_on: bool = true
var sfx_level: float = 0.8
## The lake's own sound under everything, on a slider of its own (2026-09-15).
var ambience_on: bool = true
var ambience_level: float = 0.7

var window_mode: int = WindowMode.WINDOWED
## The size the window goes back to when it leaves fullscreen. In fullscreen the board shows
## the monitor's own size and the row is dead — a resolution is a windowed-mode setting, by
## decision (2026-09-16), so there is no video mode to get wrong and nothing to recover from.
var window_size: Vector2i = LEAST_WINDOW
var vsync: int = DisplayServer.VSYNC_ENABLED
var fps_cap: int = 0

## Emitted after any value is stored, so a scene that is up can re-read them. The board
## itself does not listen — it is the one that changed them.
signal changed


func _ready() -> void:
	_build_buses()
	load_prefs()
	apply_audio()
	apply_window()
	apply_frames()


## Music, SFX and Ambience under Master, made here rather than in a bus layout resource: the
## layout would be a second file saying what these four lines say, and it is the sort of file
## nobody opens until it is wrong.
func _build_buses() -> void:
	for bus: StringName in [BUS_MUSIC, BUS_SFX, BUS_AMBIENCE]:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		var at := AudioServer.bus_count
		AudioServer.add_bus(at)
		AudioServer.set_bus_name(at, bus)
		AudioServer.set_bus_send(at, BUS_MASTER)


func load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		Binds.install()
		return
	master_on = bool(cfg.get_value(SECTION, "master_on", master_on))
	master_level = _level_of(cfg, "master_level", master_level)
	music_on = bool(cfg.get_value(SECTION, "music_on", music_on))
	music_level = _level_of(cfg, "music_level", music_level)
	sfx_on = bool(cfg.get_value(SECTION, "sfx_on", sfx_on))
	sfx_level = _level_of(cfg, "sfx_level", sfx_level)
	ambience_on = bool(cfg.get_value(SECTION, "ambience_on", ambience_on))
	ambience_level = _level_of(cfg, "ambience_level", ambience_level)

	# A file from before the display rows says `fullscreen` and nothing else. Borderless is
	# what that switch did, so that is what it becomes.
	var was_full := bool(cfg.get_value(SECTION, "fullscreen", false))
	window_mode = int(cfg.get_value(
		SECTION, "window_mode", WindowMode.BORDERLESS if was_full else WindowMode.WINDOWED
	))
	if window_mode < 0 or window_mode > WindowMode.EXCLUSIVE:
		window_mode = WindowMode.WINDOWED
	var size: Variant = cfg.get_value(SECTION, "window_size", window_size)
	window_size = size if size is Vector2i else window_size
	if window_size.x < LEAST_WINDOW.x or window_size.y < LEAST_WINDOW.y:
		window_size = LEAST_WINDOW
	vsync = int(cfg.get_value(SECTION, "vsync", vsync))
	if vsync < DisplayServer.VSYNC_DISABLED or vsync > DisplayServer.VSYNC_MAILBOX:
		vsync = DisplayServer.VSYNC_ENABLED
	fps_cap = int(cfg.get_value(SECTION, "fps_cap", fps_cap))
	if not (fps_cap in FPS_CAPS):
		fps_cap = 0

	Binds.load_from(cfg)
	Binds.install()


func _level_of(cfg: ConfigFile, key: String, fallback: float) -> float:
	return clampf(float(cfg.get_value(SECTION, key, fallback)), 0.0, 1.0)


func save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_on", master_on)
	cfg.set_value(SECTION, "master_level", master_level)
	cfg.set_value(SECTION, "music_on", music_on)
	cfg.set_value(SECTION, "music_level", music_level)
	cfg.set_value(SECTION, "sfx_on", sfx_on)
	cfg.set_value(SECTION, "sfx_level", sfx_level)
	cfg.set_value(SECTION, "ambience_on", ambience_on)
	cfg.set_value(SECTION, "ambience_level", ambience_level)
	cfg.set_value(SECTION, "window_mode", window_mode)
	cfg.set_value(SECTION, "window_size", window_size)
	cfg.set_value(SECTION, "vsync", vsync)
	cfg.set_value(SECTION, "fps_cap", fps_cap)
	Binds.save_to(cfg)
	cfg.save(PATH)


## Set one value and apply it, without writing the file: what a slider does while it is
## being dragged. The write comes on the release, through `store`.
func preview(key: StringName, value: Variant) -> void:
	if not _take(key, value):
		return
	apply_audio()


## Store one value and write the file. One entry point, so nothing can set a value and
## forget the file.
func store(key: StringName, value: Variant) -> void:
	if not _take(key, value):
		return
	apply_audio()
	save_prefs()
	changed.emit()


## The setting itself. False for a name nothing knows.
func _take(key: StringName, value: Variant) -> bool:
	match key:
		&"master_on":
			master_on = bool(value)
		&"master_level":
			master_level = clampf(float(value), 0.0, 1.0)
		&"music_on":
			music_on = bool(value)
		&"music_level":
			music_level = clampf(float(value), 0.0, 1.0)
		&"sfx_on":
			sfx_on = bool(value)
		&"sfx_level":
			sfx_level = clampf(float(value), 0.0, 1.0)
		&"ambience_on":
			ambience_on = bool(value)
		&"ambience_level":
			ambience_level = clampf(float(value), 0.0, 1.0)
		&"window_mode":
			window_mode = clampi(int(value), 0, WindowMode.EXCLUSIVE)
		&"window_size":
			window_size = value if value is Vector2i else window_size
		&"vsync":
			vsync = int(value)
		&"fps_cap":
			fps_cap = int(value)
		_:
			push_error("Prefs.store: no such setting '%s'" % key)
			return false
	return true


## The binds are the board's to change; this is how they reach the file.
func save_binds() -> void:
	save_prefs()
	changed.emit()


## The four sliders onto the four buses. A slider at its floor mutes its bus rather than
## leaving it whispering.
func apply_audio() -> void:
	_bus(BUS_MASTER, master_level, master_on)
	_bus(BUS_MUSIC, music_level, music_on)
	_bus(BUS_SFX, sfx_level, sfx_on)
	_bus(BUS_AMBIENCE, ambience_level, ambience_on)


func _bus(bus: StringName, level: float, on: bool) -> void:
	var at := AudioServer.get_bus_index(bus)
	if at == -1:
		return
	var db := volume_db(level, on, float(BUS_TOP[bus]), BUS_SILENT)
	AudioServer.set_bus_volume_db(at, db)
	AudioServer.set_bus_mute(at, db <= BUS_SILENT + 0.01)


## Whether there is a window at all. The test harness and the headless probes run under the
## dummy display server, which has no window to size and no vsync to set, and asking it
## prints an error a reader has to learn to ignore.
func _has_window() -> bool:
	return DisplayServer.get_name() != "headless"


func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## What the window is doing now, as one of the three the board offers.
func live_window_mode() -> int:
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return WindowMode.EXCLUSIVE
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			return WindowMode.BORDERLESS
	return WindowMode.WINDOWED


## Put the window where the settings say. Borderless is the fullscreen the game had before
## the three-way row: a window the size of the screen with no border, which alt-tabs cleanly.
func apply_window() -> void:
	if not _has_window():
		return
	if window_mode == WindowMode.WINDOWED:
		if live_window_mode() != WindowMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		apply_window_size()
		return
	if live_window_mode() == window_mode:
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if window_mode == WindowMode.EXCLUSIVE
		else DisplayServer.WINDOW_MODE_FULLSCREEN
	)


## Size the window and put it back in the middle of its screen. Windowed only: in either
## fullscreen the window is the screen's.
func apply_window_size() -> void:
	if not _has_window() or window_mode != WindowMode.WINDOWED:
		return
	if DisplayServer.window_get_size() == window_size:
		return
	DisplayServer.window_set_size(window_size)
	var screen := DisplayServer.window_get_current_screen()
	var into := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(
		into.position + (into.size - window_size) / 2
	)


func apply_frames() -> void:
	if _has_window():
		DisplayServer.window_set_vsync_mode(vsync as DisplayServer.VSyncMode)
	Engine.max_fps = fps_cap


## The window sizes the board offers: the modes this monitor reports, floored at
## `LEAST_WINDOW` and capped at what fits on it, newest-largest first. Measured rather than
## written down, so an odd monitor is offered its own sizes and not a list of guesses.
func window_sizes() -> Array[Vector2i]:
	var room := Vector2i(1 << 16, 1 << 16)
	if _has_window():
		room = DisplayServer.screen_get_usable_rect(
			DisplayServer.window_get_current_screen()
		).size
	var seen: Array[Vector2i] = []
	for size: Vector2i in [
		Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
		Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
	]:
		if size.x > room.x or size.y > room.y:
			continue
		if size.x < LEAST_WINDOW.x or size.y < LEAST_WINDOW.y:
			continue
		seen.append(size)
	if seen.is_empty():
		seen.append(LEAST_WINDOW)
	# Whatever the window is now belongs on the list, or the row would read as a size the
	# player never picked.
	if not (window_size in seen):
		seen.append(window_size)
		seen.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return seen
