extends Node
## Prefs (autoload): every player setting that outlives a session, in
## user://settings.cfg. Sound (four audio buses, built here at boot), the window
## (windowed / borderless / exclusive, the windowed size, vsync, frame cap), the
## city the balcony looks over, and the key binds (scripts/binds.gd).
##
## Nothing in the file is ever refused: a value that makes no sense here falls
## back to its default. Tools and probes run headless and never write the file.
##
## Pattern after Lake Cleanup's prefs.gd (power-law sliders, buses, the window
## rows); not its look.

signal environment_changed(id: String)
signal changed

const Envs = preload("res://scripts/environments.gd")
const Binds = preload("res://scripts/binds.gd")

const PATH := "user://settings.cfg"

## A decibel is a ratio and the ear hears ratios: half the slider is about half
## the loudness. dB = top + LAW * log10(level).
const SLIDER_LAW := 33.2
const SLIDER_FLOOR := 0.02
const BUS_SILENT := -60.0
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"Ambience"]
## Each bus at a full slider. Master 0 so the mix stays as tuned.
const BUS_TOP := {&"Master": 0.0, &"Music": 0.0, &"SFX": 0.0, &"Ambience": 0.0}

enum WindowMode { WINDOWED, BORDERLESS, EXCLUSIVE }
const FPS_CAPS := [0, 30, 60, 120, 144]
const VSYNCS := [DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_ADAPTIVE]
const LEAST_WINDOW := Vector2i(1152, 648)

var levels := {&"Master": 1.0, &"Music": 0.75, &"SFX": 0.8, &"Ambience": 0.7}
var mutes := {&"Master": false, &"Music": false, &"SFX": false, &"Ambience": false}
var window_mode: int = WindowMode.WINDOWED
var window_size: Vector2i = LEAST_WINDOW
var vsync: int = DisplayServer.VSYNC_ENABLED
var fps_cap: int = 0
var environment: String = Envs.CLASSIC
var binds: Dictionary = {}


static func volume_db(level: float, on: bool, loudest: float) -> float:
	level = clampf(level, 0.0, 1.0)
	if not on or level <= SLIDER_FLOOR:
		return BUS_SILENT
	return maxf(loudest + SLIDER_LAW * (log(level) / log(10.0)), BUS_SILENT)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_buses()
	_load()
	Binds.install(binds)
	apply_audio()
	apply_window()
	apply_frames()


func _build_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var at := AudioServer.bus_count - 1
			AudioServer.set_bus_name(at, bus)
			AudioServer.set_bus_send(at, &"Master")


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for bus in BUSES:
		levels[bus] = clampf(float(cfg.get_value("audio", str(bus).to_lower() + "_level", levels[bus])), 0.0, 1.0)
		mutes[bus] = bool(cfg.get_value("audio", str(bus).to_lower() + "_mute", false))
	window_mode = clampi(int(cfg.get_value("display", "window_mode", WindowMode.WINDOWED)), 0, 2)
	# the old F1 switch said borderless fullscreen
	if cfg.has_section_key("display", "fullscreen") and bool(cfg.get_value("display", "fullscreen")):
		window_mode = WindowMode.BORDERLESS
	var ws = cfg.get_value("display", "window_size", LEAST_WINDOW)
	window_size = ws if ws is Vector2i and ws.x >= LEAST_WINDOW.x and ws.y >= LEAST_WINDOW.y else LEAST_WINDOW
	var v := int(cfg.get_value("display", "vsync", DisplayServer.VSYNC_ENABLED))
	vsync = v if VSYNCS.has(v) else DisplayServer.VSYNC_ENABLED
	var f := int(cfg.get_value("display", "fps_cap", 0))
	fps_cap = f if FPS_CAPS.has(f) else 0
	environment = str(cfg.get_value("scene", "environment", Envs.CLASSIC))
	if not Envs.IDS.has(environment):
		environment = Envs.CLASSIC
	binds = {}
	if cfg.has_section("binds"):
		for key in cfg.get_section_keys("binds"):
			if Binds.ACTIONS.has(StringName(key)):
				binds[StringName(key)] = int(cfg.get_value("binds", key))


func save() -> void:
	if not _has_window():
		return
	var cfg := ConfigFile.new()
	for bus in BUSES:
		cfg.set_value("audio", str(bus).to_lower() + "_level", levels[bus])
		cfg.set_value("audio", str(bus).to_lower() + "_mute", mutes[bus])
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "window_size", window_size)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "fps_cap", fps_cap)
	cfg.set_value("scene", "environment", environment)
	for action in binds:
		cfg.set_value("binds", str(action), binds[action])
	cfg.save(PATH)


func _has_window() -> bool:
	return DisplayServer.get_name() != "headless"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"toggle_fullscreen"):
		# the key flips the two modes that cannot go wrong
		set_window_mode(WindowMode.WINDOWED if window_mode != WindowMode.WINDOWED else WindowMode.BORDERLESS)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"next_city"):
		var i := Envs.IDS.find(environment)
		set_environment(Envs.IDS[(i + 1) % Envs.IDS.size()])
		get_viewport().set_input_as_handled()


# --- sound ---------------------------------------------------------------

func set_level(bus: StringName, level: float, keep: bool = true) -> void:
	levels[bus] = clampf(level, 0.0, 1.0)
	apply_audio()
	if keep:
		save()


func set_mute(bus: StringName, mute: bool) -> void:
	mutes[bus] = mute
	apply_audio()
	save()


func apply_audio() -> void:
	for bus in BUSES:
		var at := AudioServer.get_bus_index(bus)
		if at == -1:
			continue
		var db := volume_db(levels[bus], not mutes[bus], float(BUS_TOP[bus]))
		AudioServer.set_bus_volume_db(at, db)
		AudioServer.set_bus_mute(at, db <= BUS_SILENT + 0.01)


# --- screen --------------------------------------------------------------

func set_window_mode(mode: int, keep: bool = true) -> void:
	window_mode = clampi(mode, 0, 2)
	apply_window()
	if keep:
		save()
	changed.emit()


func set_window_size(size: Vector2i) -> void:
	window_size = size
	apply_window()
	save()
	changed.emit()


func set_vsync(mode: int) -> void:
	vsync = mode
	apply_frames()
	save()


func set_fps_cap(cap: int) -> void:
	fps_cap = cap
	apply_frames()
	save()


func live_window_mode() -> int:
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return WindowMode.EXCLUSIVE
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			return WindowMode.BORDERLESS
	return WindowMode.WINDOWED


func apply_window() -> void:
	if not _has_window():
		return
	match window_mode:
		WindowMode.WINDOWED:
			if live_window_mode() != WindowMode.WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			if DisplayServer.window_get_size() != window_size:
				DisplayServer.window_set_size(window_size)
				var into := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
				DisplayServer.window_set_position(into.position + (into.size - window_size) / 2)
		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WindowMode.EXCLUSIVE:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func apply_frames() -> void:
	if _has_window():
		DisplayServer.window_set_vsync_mode(vsync as DisplayServer.VSyncMode)
	Engine.max_fps = fps_cap


## The windowed sizes offered: common 16:9 sizes that fit this monitor.
func window_sizes() -> Array[Vector2i]:
	var room := Vector2i(1 << 16, 1 << 16)
	if _has_window():
		room = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	var out: Array[Vector2i] = []
	for s: Vector2i in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900),
			Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]:
		if s.x <= room.x and s.y <= room.y:
			out.append(s)
	if not out.has(window_size):
		out.append(window_size)
		out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return out


# --- city ----------------------------------------------------------------

func set_environment(id: String) -> void:
	if not Envs.IDS.has(id) or id == environment:
		return
	environment = id
	save()
	environment_changed.emit(id)


# --- binds ---------------------------------------------------------------

func set_binds(overrides: Dictionary) -> void:
	binds = overrides
	Binds.install(binds)
	save()
