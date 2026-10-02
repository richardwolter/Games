extends Node
## Forces a tornado on a lake about 85% cleaned, lets it wander, then casts the real net at
## its foot until three landings have tamed it, and saves what it looks like:
## `tools/last_tornado_{touchdown,roam,hit1,hit2,collapse,calm}.png`, the frames for a film in
## `tools/film/tornado/` (git-ignored, not imported) (made into `tools/last_tornado.mp4` by ffmpeg afterwards), and
## `tools/last_tornado.log`. Compare with tools/tornado_mock/out_d/, the approved look.
##
##   godot --path . --fixed-fps 60 res://tools/shot_tornado.tscn --log-file tools/last_tornado_engine.log
##
## Desktop build, never --headless (nothing renders, no shader compiles). Own save path,
## deleted first; the lake hangs under this node, not the root, so it is not the game and
## wears no menu. Quits on a wall clock as well as on its last frame.

const SAVE_PATH := "user://shot_tornado.save"
const LOG := "res://tools/last_tornado.log"
const FRAMES := "res://tools/film/tornado/"
const QUIT_AFTER_MS := 180000
const CROP := Rect2i(400, 0, 1120, 800)
const CAM_LIFT := 130.0
## Where it comes down, radians round the island (tile space; PI/4 is down the screen).
const ANGLE := 0.55
## Seconds after touchdown the first cast is thrown.
const CAST_FROM := 8.0
const CAST_APART := 2.6

var _main: Node
var _t: Node2D
var _frames := 0
var _log: FileAccess
var _started := 0
var _cam := Vector2.ZERO
var _shots := {}
var _captured := 0
var _cast_at := -99.0
var _hits_seen := 0
var _done_at := -1.0
var _worst_ms := 0.0
var _sum_ms := 0.0
var _n_ms := 0


func _ready() -> void:
	_started = Time.get_ticks_msec()
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG, FileAccess.WRITE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES))
	var dir := DirAccess.open(FRAMES)
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".png"):
				dir.remove(f)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	add_child(_main)


func _say(line: String) -> void:
	_log.store_line(line)
	_log.flush()


func _physics_process(delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _started > QUIT_AFTER_MS:
		_say("wall clock ran out")
		_finish()
		return
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 20:
		_setup()
	if _frames < 20 or _t == null:
		return
	var ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	if _t.down():
		_worst_ms = maxf(_worst_ms, ms)
		_sum_ms += ms
		_n_ms += 1
	_drive_camera(delta)
	var t: float = _t.get(&"_t")
	if _t.active() and t >= 0.0:
		_cast(t)
		_stills(t)
		_capture()
	if _hits_seen != _t.hits():
		_hits_seen = _t.hits()
		_say("[%.2f] hit %d, carrying %d, netted %d" % [t, _hits_seen, _t.carrying(), _t.netted])
		_shots["hit_at"] = t
	if not _t.active() and _frames > 60:
		if _done_at < 0.0:
			_done_at = float(_frames)
			_say("over: lifted %d landed %d netted %d, pieces %d, pollution %.3f" % [
				_t.lifted, _t.landed, _t.netted, (_main.get(&"_grid") as LakeGrid).piece_count(),
				float(_main.get(&"pollution"))])
		elif float(_frames) - _done_at == 30.0:
			_shot("calm")
			_capture()
		elif float(_frames) - _done_at > 40.0:
			_finish()


func _setup() -> void:
	(_main.get(&"_hud_layer") as CanvasLayer).visible = false
	_main.set(&"net_range_level", 6)
	_main.set(&"net_hold_level", 3)
	_main.call(&"_push_net_numbers")
	var grid: LakeGrid = _main.get(&"_grid")
	# About 85% cleaned: a band out from the island left patchy and thin (what the tornado will
	# work through), and a few stacks anywhere else.
	var kept := 0
	for index in grid.stacks.size():
		if grid.stacks[index].is_empty():
			continue
		var tile := Vector2(grid.tile_of(index)) + Vector2(0.5, 0.5)
		var h := sin(tile.x * 12.9898 + tile.y * 78.233) * 43758.5453
		h -= floor(h)
		var out := Iso.past_shelf(tile)
		var keep := 0
		if out < 12.0 and h < 0.7:
			keep = 1 + int(h * 4.0)
		elif h < 0.12:
			keep = 99
		if keep == 0:
			grid.stacks[index] = PackedInt32Array()
			continue
		kept += 1
		var st := grid.stacks[index]
		if st.size() > keep:
			grid.stacks[index] = st.slice(st.size() - keep)
	grid._rebuild()
	grid.queue_redraw()
	_main._build_filth_map()
	var total: float = _main.get(&"_filth_total")
	var left := grid.filth_left()
	_main.set(&"_filth_left", left)
	_main.set(&"pollution", clampf(left / maxf(total, 0.001), 0.0, 1.0))
	_say("cleaned %.1f%%, stacks kept %d, pieces %d" % [
		(1.0 - left / maxf(total, 0.001)) * 100.0, kept, grid.piece_count()])
	get_viewport().warp_mouse(Vector2(8.0, 8.0))
	_main.set(&"_mouse_inside", false)
	_main.set(&"_free_view", true)
	_main.set(&"_view_zoom", 1.0)
	var angler: Node2D = _main.get(&"_angler")
	angler.stand_at(Iso.world_to_tile(Iso.island_point(ANGLE, -0.6)))
	_t = _main.get(&"_tornado")
	_t.start(ANGLE)
	_cam = _t.base() - Vector2(0.0, CAM_LIFT)


func _drive_camera(delta: float) -> void:
	var want: Vector2 = _t.base() - Vector2(0.0, CAM_LIFT) if _t.active() else _cam
	_cam = _cam.lerp(want, 1.0 - exp(-3.0 * delta))
	_main.set(&"_free_at", _cam)
	(_main.get(&"_camera") as Camera2D).position = _cam
	_main.set(&"_view_zoom", 1.0)


## The real net, thrown by the lake's own cast at where the foot will be when it lands. The
## angler is stood on the beach nearest the funnel first, as a player would walk there.
func _cast(t: float) -> void:
	if t < CAST_FROM or _t.hits() >= 3 or t - _cast_at < CAST_APART:
		return
	var net: CastNet = _main.get(&"_net")
	if net.state != CastNet.State.IDLE:
		return
	var theta: float = _t.get(&"_theta")
	var angler: Node2D = _main.get(&"_angler")
	angler.stand_at(Iso.world_to_tile(Iso.island_point(theta, -0.6)))
	var v: Vector2 = _t.get(&"_velocity")
	var aim: Vector2 = _t.base() + v * 0.35
	_cast_at = t
	_main.call(&"_cast_at", aim)
	_say("[%.2f] cast at %s (base %s), net %s" % [t, str(aim.round()), str(_t.base().round()), str(net.state)])


func _stills(t: float) -> void:
	if not _shots.has("touchdown") and t >= 1.5:
		_shot("touchdown")
	if not _shots.has("roam") and t >= 6.0:
		_shot("roam")
	var hit_at: float = _shots.get("hit_at", -1.0)
	if _t.hits() >= 1 and not _shots.has("hit1") and t >= hit_at + 0.1:
		_shot("hit1")
	if _t.hits() >= 2 and not _shots.has("hit2") and t >= hit_at + 0.1:
		_shot("hit2")
	if _t.hits() >= 3 and not _shots.has("collapse") and t >= hit_at + 0.6:
		_shot("collapse")


func _shot(name: String) -> void:
	_shots[name] = true
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tools/last_tornado_%s.png" % name))
	_say("still %s: strength %.2f carrying %d hits %d" % [name, float(_t.get(&"_strength")), _t.carrying(), _t.hits()])


func _capture() -> void:
	if _frames % 2 != 0:
		return
	var image := get_viewport().get_texture().get_image().get_region(CROP)
	image.save_png(ProjectSettings.globalize_path(FRAMES + "f_%04d.png" % _captured))
	_captured += 1


func _finish() -> void:
	_say("frames %d; process ms while down: mean %.2f worst %.2f" % [
		_captured, _sum_ms / maxf(float(_n_ms), 1.0), _worst_ms])
	_say("done")
	get_tree().quit()
