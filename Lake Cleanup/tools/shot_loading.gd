extends Node
## Makes the loading screen's two pictures. Two runs, with a reimport between them, because
## the second photographs a control that draws the first.
##
## 1. **The lake** (no variable set): a fresh, untouched lake in the menu's own pose and at
##    the menu's own view, with nothing over it, saved as `assets/loading_lake.png`. The
##    loading screen dissolves into the live menu, so the picture has to be the menu's
##    framing to the pixel — it is taken through `Lake._enter_menu` rather than by setting a
##    camera here, and cannot drift from it. The flock is hidden: a bird frozen in mid-air
##    would hang there as a ghost while the picture goes.
## 2. **The splash** (`SHOT_SPLASH=1`): `LoadingScreen` itself with its bar filthy, saved as
##    `assets/boot_splash.png` — the engine's splash is a photograph of the loading screen's
##    first frame, which is what makes the hand-over from one to the other no cut at all.
##    Also `tools/last_loading.png` with the bar part way, for judging the darkening, the
##    logo and the bar by eye.
##
## Desktop build, not --headless (nothing renders under the dummy driver), on a 1920x1080
## window, from the project root:
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_loading.tscn
##   <godot> --path . --headless --import
##   SHOT_SPLASH=1 <godot> --path . --fixed-fps 60 res://tools/shot_loading.tscn
##   <godot> --path . --headless --import
##
## On a save of its own, started empty and never the player's. **Re-run both if the menu's
## view, the island, the fill or the loading screen's layout change.**

const SAVE_PATH := "user://probe_loading.save"
const LAKE_OUT := "res://assets/loading_lake.png"
const SPLASH_OUT := "res://assets/boot_splash.png"
const LOOK_OUT := "res://tools/last_loading.png"
const LOG_PATH := "res://tools/last_loading.log"
## Frames the lake is given to lay its soup out and settle before it is photographed.
const SETTLE := 90

var _splash: bool = false
var _lake: Node
var _screen: LoadingScreen
var _frames: int = 0
var _log: FileAccess


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_splash = OS.get_environment("SHOT_SPLASH") == "1"
	if _splash:
		_screen = LoadingScreen.new()
		add_child(_screen)
		_screen.progress = 0.0
		return
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_lake = load("res://scenes/main.tscn").instantiate()
	_lake.set(&"save_path", SAVE_PATH)
	_lake.set(&"autoload_save", false)
	add_child(_lake)
	# The menu's pose and the menu's view, and then no menu: what is behind the doors.
	_lake.call(&"_enter_menu", true)
	(_lake.get(&"_menu") as MainMenu).put_away(true)
	var flock := _lake.get(&"_flock") as Node2D
	if flock != null:
		flock.visible = false


func _process(_delta: float) -> void:
	_frames += 1
	if _splash:
		match _frames:
			20:
				_save(SPLASH_OUT)
				_screen.progress = 0.55
			26:
				_save(LOOK_OUT)
				_say("done")
				get_tree().quit()
		return
	if _frames == SETTLE:
		_save(LAKE_OUT)
		var camera := _lake.get(&"_camera") as Camera2D
		_say("the lake at zoom %.3f, camera %s" % [camera.zoom.x, str(camera.position)])
		_say("done")
		get_tree().quit()


func _save(to: String) -> void:
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(to))
	_say("%s  %dx%d" % [to, shot.get_width(), shot.get_height()])


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()
