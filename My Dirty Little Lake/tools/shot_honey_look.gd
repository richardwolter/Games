extends Node
## Photographs the honey's look on the lake (2026-10-18, the hive overhaul, Richard's picks
## 1A / 2A / 3C / 4A): the jar plate idle and running, the bees round the angler at a full
## window, half and nearly out, a honeyed net dripping, and honey coins in the air. Desktop
## build (nothing renders headless), `--fixed-fps 60`:
##
##     <exe> --path . --fixed-fps 60 res://tools/shot_honey_look.tscn --log-file <path>
##
## Writes tools/last_honey_look_<shot>.png (whole window) and _<shot>_crop.png (zoomed round
## what it is about), and tools/last_honey_look.log. On a save of its own, under its own node.

const LOG_PATH := "res://tools/last_honey_look.log"
const SAVE_PATH := "user://shot_honey_look.save"
const QUIT_AFTER_MS := 90000
const ZOOM := 4

var _main: Node
var _net: CastNet
var _angler: Angler
var _skin: Control
var _log: FileAccess
var _frames := 0
var _started := 0
var _hold := -1.0
var _cast_at := -1
var _landed := -1


func _ready() -> void:
	_started = Time.get_ticks_msec()
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	add_child(_main)


func _say(line: String) -> void:
	_log.store_line(line)
	_log.flush()


func _physics_process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _started > QUIT_AFTER_MS:
		_say("FAIL out of time")
		get_tree().quit(1)
		return
	if _hold >= 0.0:
		_main.set(&"_honey_left", _hold)
	match _frames:
		3:
			_net = _main.get_node(^"Net") as CastNet
			_angler = _main.get_node(^"Angler") as Angler
			_skin = _main.get(&"_skin")
			(_main.get_node(^"Flock") as Flock).spawning = false
			(_main.get(&"_hive") as Hive).jars = 3
			_main.set(&"net_width_level", 6)
			_main.set(&"net_range_level", 3)
			_main.call(&"_push_net_numbers")
		40:
			_take("plate_idle", _plate_box())
			(_main.get(&"_hive") as Hive).jars = 2
			_main.set(&"_honey_span", 15.0)
			_hold = 15.0
		100:
			_take("plate_full", _plate_box())
			_take("bees_full", _angler_box())
		110:
			_hold = 7.4
		170:
			_take("plate_half", _plate_box())
			_take("bees_half", _angler_box())
		180:
			_hold = 0.9
		240:
			_take("bees_out", _angler_box())
			_take("plate_out", _plate_box())
		250:
			_hold = 15.0
			var where := Vector2.INF
			for k in 16:
				where = _water_along(Vector2.RIGHT.rotated(TAU * float(k) / 16.0))
				if where != Vector2.INF:
					break
			if not _net.cast_to(where):
				_say("FAIL cast refused at %s" % str(where))
			_cast_at = _frames
	if _cast_at > 0 and _landed < 0 and _net.state != CastNet.State.FLYING and _frames > _cast_at + 2:
		_landed = _frames
	if _landed > 0:
		var since := _frames - _landed
		for at: int in [10, 30, 50, 75]:
			if since == at:
				_take("net_%d" % at, _net_box())
		if since == 4 or since == 12:
			_take("coins_%d" % since, Rect2(Vector2.ZERO, Vector2(720.0, 420.0)), 2)
		if since > 80:
			_say("done")
			get_tree().quit()


## The jar plate's box on the window's canvas, with a margin.
func _plate_box() -> Rect2:
	var box: Rect2 = _skin.call(&"honey_box")
	var on: Rect2 = _skin.get_global_transform_with_canvas() * box
	return on.grow(16.0)


func _angler_box() -> Rect2:
	var at := get_viewport().get_canvas_transform() * _angler.global_position
	return Rect2(at - Vector2(70.0, 90.0), Vector2(140.0, 110.0))


func _net_box() -> Rect2:
	var at := get_viewport().get_canvas_transform() * _net.draw_at()
	var half := _net.mouth_extent() * get_viewport().get_canvas_transform().get_scale().x
	return Rect2(at - Vector2(half + 30.0, half * 0.6 + 30.0), Vector2(half * 2.0 + 60.0, half * 1.2 + 70.0))


## Saves the whole window, and `canvas` (the 1280 x 720 canvas's own px) cropped and zoomed.
func _take(name: String, canvas: Rect2, zoom := ZOOM) -> void:
	var shot := get_viewport().get_texture().get_image()
	shot.save_png("res://tools/last_honey_look_%s.png" % name)
	var over: Vector2 = Vector2(shot.get_size()) / get_viewport().get_visible_rect().size
	var rect := Rect2i(Rect2(canvas.position * over, canvas.size * over)).intersection(
		Rect2i(Vector2i.ZERO, shot.get_size()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		_say("%s: crop off screen %s" % [name, str(canvas)])
		return
	var crop := shot.get_region(rect)
	crop.resize(crop.get_width() * zoom, crop.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	crop.save_png("res://tools/last_honey_look_%s_crop.png" % name)
	_say("%s: canvas %s, over %s, jars %d, left %.1f, bees %d, drips %d" % [
		name, str(canvas), str(over), int((_main.get(&"_hive") as Hive).jars),
		float(_main.get(&"_honey_left")), int((_main.get(&"_honey_bees") as HoneyBees).orbiting()),
		int(_net.get_node(^"HoneyDrips").call(&"count"))])


## The farthest catchable spot from the angler along `dir`, in world units.
func _water_along(dir: Vector2) -> Vector2:
	var best := Vector2.INF
	var span := 0.5
	while span <= _net.range_tiles:
		var tile := _angler.tile_pos + dir * span
		var where := Iso.tile_to_world(tile.x, tile.y)
		if _net.can_cast_to(where) and _net.would_catch(where):
			best = where
		span += 0.5
	return best
