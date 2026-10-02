extends Node
## Films the net drawn by rule (2026-10-02, `NetShape`, `shaders/net_mesh.gdshader`): three
## casts, at the starting width, mid-run and near the top (the last one lucky, in gold), each
## photographed in flight, landed, settled and twice on the reel, cropped round the net. Also
## saves the net's baked picture the shop board and the HUD button are lent.
##
## A probe, not a test: headless has no renderer, so this is what compiles the net's shader.
## Read the engine log. Run it with the desktop build, not --headless:
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_net.tscn --log-file tools/last_net_engine.log
##
## Writes tools/last_net_<width>_<moment>.png, tools/last_net_picture.png, tools/last_net.png
## (all of them on one sheet) and tools/last_net.log. On a save of its own, under its own
## node; the player's is not touched.

const LOG_PATH := "res://tools/last_net.log"
const SAVE_PATH := "user://shot_net.save"
const QUIT_AFTER_MS := 120000

## The casts: the width level, and whether it is lucky.
const CASTS := [[0, false], [10, true], [20, true]]
## When each picture is taken: in flight as a share of the throw, then seconds after landing.
const FLIGHT := [0.15, 0.45, 0.8]
const AFTER := {&"landed": 0.05, &"burst": 0.2, &"settled": 0.4, &"reel_a": 1.0, &"glint": 1.35, &"reel_b": 1.8}

var _main: Node
var _net: CastNet
var _angler: Angler
var _log: FileAccess
var _frames := 0
var _cast := -1
var _landed := -1.0
var _flight_taken := 0
var _taken: Array[StringName] = []
var _shots: Array[Image] = []
var _picture_saved := false
var _started := 0
## NET_FILM=1: every other frame of the second cast (lucky) from its landing, cropped round
## the net at a fixed size, into tools/film/net_lucky/, for a GIF.
var _film := OS.get_environment("NET_FILM") == "1"
var _film_frame := 0
const FILM_SECONDS := 2.8
const FILM_SIZE := Vector2i(560, 360)


func _ready() -> void:
	_started = Time.get_ticks_msec()
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	add_child(_main)


func _say(line: String) -> void:
	_log.store_line(line)
	_log.flush()


func _physics_process(delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _started > QUIT_AFTER_MS:
		_say("FAIL out of time")
		get_tree().quit(1)
		return
	if _frames == 3:
		_net = _main.get_node(^"Net") as CastNet
		_angler = _main.get_node(^"Angler") as Angler
		(_main.get_node(^"Flock") as Flock).spawning = false
		_main.call(&"_zoom_by", 1000.0)
		_main.set(&"net_range_level", 10)
		_main.set(&"net_hold_level", 8)
		_main.call(&"_push_net_numbers")
		return
	if _frames < 30:
		return
	if not _picture_saved:
		var lent: Dictionary = (_main.get(&"_skin") as Node).get(&"sprites").get("net", {})
		if lent.has("sheet"):
			var image := (lent["sheet"] as Texture2D).get_image()
			image.save_png("res://tools/last_net_picture.png")
			_say("picture %s" % str(image.get_size()))
			_picture_saved = true
			# The whole screen, for the HUD's upgrades button that carries it.
			get_viewport().get_texture().get_image().save_png("res://tools/last_net_hud.png")
	if _net.state == CastNet.State.IDLE and (_cast < 0 or _landed >= 0.0):
		_cast += 1
		if _cast >= CASTS.size():
			_finish()
			return
		_main.set(&"net_width_level", int(CASTS[_cast][0]))
		_main.call(&"_push_net_numbers")
		var where := _water_along(Vector2(1.0, -0.6).normalized())
		_landed = -1.0
		_flight_taken = 0
		_taken.clear()
		if not _net.cast_to(where):
			_say("FAIL cast %d refused at %s" % [_cast, str(where)])
			get_tree().quit(1)
			return
		if bool(CASTS[_cast][1]):
			_net.luck_power = 1
			_net.luck_hold = 4
		_say("cast %d: width level %d, mouth %.1f, to %s" % [
			_cast, int(CASTS[_cast][0]), _net.open_extent(), str(where)])
		return
	if _net.state == CastNet.State.FLYING:
		var gone := clampf(Vector2(_net.get(&"_cast_from")).distance_to(_net.tile_pos) / float(_net.get(&"_cast_span")), 0.0, 1.0)
		if _flight_taken < FLIGHT.size() and gone >= float(FLIGHT[_flight_taken]):
			_take("fly%d" % _flight_taken)
			_flight_taken += 1
		return
	if _landed < 0.0:
		_landed = 0.0
		if _film and _cast == 1:
			# Pinned a little towards the angler, so the whole haul stays in the picture.
			_main.set(&"_free_view", true)
			_main.set(&"_free_at", _net.draw_at().lerp(_angler.position, 0.35))
		return
	_landed += delta
	if _film and _cast == 1 and _landed <= FILM_SECONDS and Engine.get_physics_frames() % 2 == 0:
		_film_shot()
	for name: StringName in AFTER:
		if name in _taken or _landed < float(AFTER[name]):
			continue
		_taken.append(name)
		_take(String(name))


func _film_shot() -> void:
	_main.set(&"_free_at", _net.draw_at().lerp(_angler.position, 0.35))
	if _film_frame == 0:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/film/net_lucky"))
	var shot := get_viewport().get_texture().get_image()
	var over: Vector2 = Vector2(shot.get_size()) / get_viewport().get_visible_rect().size
	var middle := Vector2i((get_viewport().get_canvas_transform() * _net.draw_at()) * over)
	var rect := Rect2i(middle - FILM_SIZE / 2, FILM_SIZE).intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		_say("film frame off screen: net at %s, middle %s, shot %s" % [str(_net.draw_at()), str(middle), str(shot.get_size())])
		return
	shot.get_region(rect).save_png("res://tools/film/net_lucky/f_%03d.png" % _film_frame)
	_film_frame += 1


func _take(moment: String) -> void:
	var shot := get_viewport().get_texture().get_image()
	var on_canvas := get_viewport().get_canvas_transform() * _net.draw_at()
	var over: Vector2 = Vector2(shot.get_size()) / get_viewport().get_visible_rect().size
	var middle := Vector2i(on_canvas * over)
	var half := Vector2i(Vector2(_net.open_extent() * 1.8 + 60.0, _net.open_extent() + 60.0) * get_viewport().get_canvas_transform().get_scale() * over)
	var rect := Rect2i(middle - half, half * 2).intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	var crop := shot.get_region(rect)
	crop.save_png("res://tools/last_net_%d_%s.png" % [_cast, moment])
	_shots.append(crop)
	_say("%d %s: state %d, lean %.2f, catch %d, mouth %.1f" % [
		_cast, moment, _net.state, float(_net.get(&"_lean")), _net.catch.size(), _net.mouth_extent()])


func _finish() -> void:
	# All the crops on one sheet, a row a cast.
	var per_row := FLIGHT.size() + AFTER.size()
	var cell := Vector2i.ZERO
	for shot in _shots:
		cell = Vector2i(maxi(cell.x, shot.get_width()), maxi(cell.y, shot.get_height()))
	var rows := int(ceil(float(_shots.size()) / float(per_row)))
	var sheet := Image.create(cell.x * per_row, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.05, 0.05, 0.06))
	for i in _shots.size():
		var shot := _shots[i]
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i((i % per_row) * cell.x, (i / per_row) * cell.y))
	sheet.save_png("res://tools/last_net.png")
	_say("done, %d shots" % _shots.size())
	get_tree().quit()


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
	if best == Vector2.INF:
		span = 0.5
		while span <= _net.range_tiles:
			var tile := _angler.tile_pos + dir * span
			var where := Iso.tile_to_world(tile.x, tile.y)
			if _net.can_cast_to(where):
				best = where
			span += 0.5
	return best
