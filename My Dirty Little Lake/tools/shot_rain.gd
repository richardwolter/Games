extends Node
## Pours a shower over a fresh lake and saves what it looks like: the view in full rain
## (`last_rain_far.png`), the island close up with its puddles (`last_rain_near.png`), a
## lightning flash (`last_rain_flash.png`) and `last_rain.log`. Desktop build, not
## --headless: nothing renders under the dummy driver and no shader compiles.
##
##   godot --path . --fixed-fps 60 res://tools/shot_rain.tscn --log-file tools/last_rain_engine.log
##
## Own save path, deleted first; the lake hangs under this node, not the root, so it is
## not the game and wears no menu. Quits on a wall clock as well as on its last shot.

const SAVE_PATH := "user://shot_rain.save"
const LOG := "res://tools/last_rain.log"
const QUIT_AFTER_MS := 90000

var _main: Node
var _frames := 0
var _log: FileAccess
var _started := 0


func _ready() -> void:
	_started = Time.get_ticks_msec()
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG, FileAccess.WRITE)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	add_child(_main)


func _say(line: String) -> void:
	_log.store_line(line)
	_log.flush()


func _shot(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tools/last_rain_%s.png" % name))
	var weather: Weather = _main.get(&"_weather")
	var puddles: Puddles = _main.get(&"_puddles")
	_say("%s: rain %.2f flash %.2f drops %d bits %d puddles wet %.2f" % [
		name, weather.rain(), float(weather.get(&"_flash")),
		(weather.get(&"_drop_at") as PackedVector2Array).size(),
		(weather.get(&"_bit_at") as PackedVector2Array).size(), puddles.wet])


func _physics_process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _started > QUIT_AFTER_MS:
		_say("wall clock ran out")
		get_tree().quit()
		return
	if _main == null or not _main.is_inside_tree():
		return
	var weather: Weather = _main.get(&"_weather")
	var puddles: Puddles = _main.get(&"_puddles")
	match _frames:
		30:
			# A lake nearly cleaned first, so the sky's reflection in clean water shows on a fair
			# day and can be seen going as the shower comes in.
			var grid: LakeGrid = _main.get(&"_grid")
			for index in grid.stacks.size():
				var tile := grid.tile_of(index)
				var h := sin(float(tile.x) * 12.9898 + float(tile.y) * 78.233) * 43758.5453
				if h - floor(h) >= 0.04:
					grid.stacks[index] = PackedInt32Array()
			grid._rebuild()
			grid.queue_redraw()
			_main._build_filth_map()
			get_viewport().warp_mouse(Vector2(8.0, 8.0))
		150:
			var left := 0
			for st in (_main.get(&"_grid") as LakeGrid).stacks:
				if not st.is_empty():
					left += 1
			_say("stacks left %d" % left)
			_shot("fair")
			weather.pour(600.0)
		# Fill the puddles in a hurry: the look is the thing, not the minutes it takes.
		400:
			puddles.wet = 1.0
			_shot("far")
			puddles.sand_wet = 1.0
			_main.set(&"_view_zoom", 1.5)
		520:
			_shot("near")
			weather.strike()
		523:
			_shot("flash")
			_say("done")
			get_tree().quit()
