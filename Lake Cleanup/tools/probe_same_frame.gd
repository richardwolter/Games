## Proves a drawing shortcut draws what the old way drew, on the very same frame.
##
## Opens the lake in a real window (desktop build, not --headless: nothing renders under
## the dummy driver), maxes the net, and throws lucky doubled casts until the moment asked
## for is under way. Then the world is frozen — tree paused, time scale nought — and the
## frame is photographed three times: the old path, the new path, the old path again. The
## first and last must agree (or the freeze leaked and the test says nothing); the middle
## is what the change is judged on. Pixel counts go to tools/last_same_frame.log.
##
## PROBE_WHAT=haul   Haul's batched flights against one draw per piece (Haul.batched).
## PROBE_WHAT=rise   the rising tiles' bob in the soup's shaders against the patch
##                   (PROBE_RISING=n waits for n tiles rising, default 20)
##                   (LakeGrid.gpu_rise).
##
##   godot --path . --fixed-fps 60 --log-file <path> res://tools/probe_same_frame.tscn
##
## Its own save path and no autosave: nothing here may touch the player's run.
extends Node

const LOG_PATH := "res://tools/last_same_frame.log"
const QUIT_AFTER_MS := 90000

var _main: Node2D
var _grid: LakeGrid
var _what := OS.get_environment("PROBE_WHAT")
var _n := 0
var _busy := false
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _what.is_empty():
		_what = "haul"
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"autoload_save", false)
	_main.set(&"save_path", "user://probe_same_frame.save")
	add_child(_main)
	_grid = _main.get_node(^"Grid")
	for key in [&"net_width", &"net_hold", &"net_strength", &"net_range", &"reel"]:
		var track: UpgradeTrack = _main.get(&"_upgrades")[key]
		_main.set(StringName(String(key) + "_level"), track.level_cap)
	_main.call(&"_push_net_numbers")


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > QUIT_AFTER_MS:
		_say("gave up: wall clock")
		_finish()
		return
	if _busy:
		return
	_n += 1
	if _n < 60:
		return
	_cast_again()
	if _ready_to_shoot():
		_busy = true
		_shoot()


func _ready_to_shoot() -> bool:
	if _what == "rise":
		var want := OS.get_environment("PROBE_RISING")
		return _grid.get(&"_emerging").size() >= (int(want) if want != "" else 20)
	var haul: Haul = _main.get(&"_haul")
	return haul.flying() >= 40


func _cast_again() -> void:
	var net: CastNet = _main.get(&"_net")
	if net.state != CastNet.State.IDLE:
		return
	var angler: Node2D = _main.get(&"_angler")
	var spot := net.nearest_catch(angler.position, 400.0)
	if spot == Vector2.INF:
		return
	_main._cast_at(spot)
	net.luck_power = 1
	net.luck_hold = _main.LUCKY_EXTRA
	var net2: CastNet = _main.get(&"_net2")
	if net2 != null and net2.state == CastNet.State.IDLE:
		var at: Vector2 = _main._double_spot(Iso.world_to_tile(spot))
		if at != Vector2.INF:
			net2.cast_to(Iso.tile_to_world(at.x, at.y))


func _set_new(on: bool) -> void:
	if _what == "rise":
		_grid.set_gpu_rise(on)
	else:
		Haul.batched = on
		(_main.get(&"_haul") as CanvasItem).queue_redraw()


func _grab() -> Image:
	for i in 3:
		await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _shoot() -> void:
	get_tree().paused = true
	Engine.time_scale = 0.0
	_say("what %s  frame %d  flying %d  rising %d" % [
		_what, _n, (_main.get(&"_haul") as Haul).flying(), _grid.get(&"_emerging").size()
	])
	_set_new(false)
	var before: Image = await _grab()
	_set_new(true)
	var after: Image = await _grab()
	if _what == "rise":
		var held := 0
		var most := 0.0
		for slot: int in _grid.get(&"_rise_slot"):
			if slot >= 0:
				held += 1
				most = maxf(most, absf((_grid.get(&"_rise") as PackedFloat32Array)[slot]))
		_say("tiles moved by the shaders %d, highest rise %.2f px" % [held, most])
	_set_new(false)
	var again: Image = await _grab()
	_set_new(true)
	before.save_png("res://tools/last_same_frame_old.png")
	after.save_png("res://tools/last_same_frame_new.png")
	_say("old vs old again: %s" % _compare(before, again))
	_say("old vs new:       %s" % _compare(before, after))
	_finish()


func _compare(a: Image, b: Image) -> String:
	var differ := 0
	var worst := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if p != q:
				differ += 1
				worst = maxf(worst, maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))))
	return "%d pixels differ, worst channel %d/255" % [differ, int(round(worst * 255.0))]


func _say(text: String) -> void:
	print(text)
	_lines.append(text)


func _finish() -> void:
	var log := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if log != null:
		for text in _lines:
			log.store_line(text)
		log.close()
	Engine.time_scale = 1.0
	get_tree().quit()
