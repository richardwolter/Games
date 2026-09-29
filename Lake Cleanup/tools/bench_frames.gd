## Runs the real game in a real window and reports how long its frames take.
##
## The harness in test_lake.gd is headless, so it never draws, and a stutter is a drawing
## problem as often as a logic one. This opens the actual scene, throws away the first
## ninety frames while the atlas and the shaders warm up, and then times six hundred.
##
## Vsync is off and the frame rate uncapped, so the mean is what a frame really costs rather
## than the refresh it was pinned to. The budget is 16.7 ms; the bar for this game is a mean
## under 8 ms with nothing over 16.7, which leaves room for a machine half as fast.
##
## BENCH_WALK=1 walks the angler round a square (right, down, left, up, two seconds each),
## because standing still is the one case that never had a problem: the camera follows, the
## view moves, and whatever that sets off is what the player feels.
##
## BENCH_OFF turns suspects off so their cost can be read off the difference:
##   BENCH_OFF=ripple   the ring layer under the floating junk
##   BENCH_OFF=water    every shader on the lake
##   BENCH_OFF="ripple water"
##   BENCH_OFF=raindraw   (with BENCH_RAIN) the rain still falls but is not drawn
##
## BENCH_CAST=1 casts the net again at the nearest green spot each time it comes home.
## BENCH_OFF=count (with BENCH_CAST) hides the haul's count over the angler.
##
## BENCH_BIG=1 (with BENCH_CAST) maxes the net's Width, Catch, Strength, Range and Reel first.
## BENCH_LUCK="lucky double" (with BENCH_CAST) makes every cast lucky and/or doubled.
## BENCH_HIDE / BENCH_STOP: space-separated lake members to hide / stop processing, by variable
##   name (`_splash`) or, prefixed with @, by node path (`@Grid/Ripples`). @ rather than / because
##   Git Bash rewrites a leading slash into a Windows path.
## Frames over 12 ms are listed after the summary with the net's state, the node count and the
## renderer's own CPU and GPU time for that frame.
## BENCH_RAIN=1 pours a shower at full strength from the first frame, puddles full.
##
##   godot --path . res://tools/bench_frames.tscn
extends Node

## Where the result goes as well as to stdout. The Godot build here is a GUI one, so `print`
## reaches nothing when the run is started from a shell — same reason test_lake.gd keeps a
## log. Overwritten each run, so the file is always the last bench and never a pile of them.
const LOG_PATH := "res://tools/last_bench.log"

const WARMUP := 90
const SAMPLES := 600
const WALK_LEG := 2.0
const WALK := [&"walk_right", &"walk_down", &"walk_left", &"walk_up"]

var _main: Node2D
var _grid: Node2D
var _n: int = 0
var _times: PackedFloat32Array = PackedFloat32Array()
var _last: int = 0
var _walking: bool = false
var _clock: float = 0.0
var _held: StringName = &""

## Totals over the sampled frames, for what the grid did and what the engine reports.
var _start := {}
var _rebuild_ms_total: float = 0.0
var _seen_rebuilds: int = 0
var _process_ms_total: float = 0.0
var _draws_total: int = 0


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"autoload_save", false)
	var half := OS.get_environment("BENCH_CLEAN") == "1"
	if half:
		# An emptied lake is not the player's to keep: this run writes its own file.
		_main.set(&"save_path", "user://bench_clean.save")
	add_child(_main)
	_grid = _main.get_node(^"Grid")
	if half:
		_half_clean()
	if OS.get_environment("BENCH_BIG") == "1":
		for key in [&"net_width", &"net_hold", &"net_strength", &"net_range", &"reel"]:
			var track: UpgradeTrack = _main.get(&"_upgrades")[key]
			_main.set(StringName(String(key) + "_level"), track.level_cap)
		_main.call(&"_push_net_numbers")
	_walking = OS.get_environment("BENCH_WALK") == "1"
	var mode := OS.get_environment("BENCH_OFF")
	if mode.contains("ripple"):
		var r := _grid.get_node(^"Ripples") as Node2D
		r.set_process(false)
		r.visible = false
	if mode.contains("water"):
		var fill := _main.get_node(^"Sky/Fill") as CanvasItem
		fill.material = null
		for child in _grid.get_children():
			(child as CanvasItem).material = null
		(_grid as CanvasItem).material = null
	if OS.get_environment("BENCH_RAIN") == "1":
		var weather: Weather = _main.get(&"_weather")
		weather.pour(600.0)
		weather.set(&"_rain", 1.0)
		var puddles: Puddles = _main.get(&"_puddles")
		puddles.wet = 1.0
		puddles.sand_wet = 1.0
		if mode.contains("rings"):
			weather.splash = null
		if mode.contains("puddles"):
			weather.puddles = null
			puddles.visible = false
			puddles.process_mode = Node.PROCESS_MODE_DISABLED
		if mode.contains("sky"):
			weather.day = null
		if mode.contains("raindraw"):
			weather.self_modulate.a = 0.0
			weather.visible = false
	for v in OS.get_environment("BENCH_HIDE").split(" ", false):
		var hd = _main.get(StringName(v)) if not v.begins_with("@") else _main.get_node(NodePath(v.substr(1)))
		hd.visible = false
	for v in OS.get_environment("BENCH_STOP").split(" ", false):
		var nd: Node = _main.get(StringName(v)) if not v.begins_with("@") else _main.get_node(NodePath(v.substr(1)))
		if nd != null:
			nd.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			print("no node ", v)
	print("bench mode: ", mode, " walk: ", _walking)
	_last = Time.get_ticks_usec()


## BENCH_CLEAN=1: the west half of the lake emptied, so nature and the animals are out —
## a fresh lake has none of them and says nothing about what they cost.
func _half_clean() -> void:
	for index in _grid.stacks.size():
		if _grid.tile_of(index).x < int(Iso.CENTRE.x):
			_grid.stacks[index].resize(0)
	_grid._rebuild()
	_main._build_filth_map()
	var wild: Wildlife = _main.get(&"_wildlife")
	for n in 6:
		wild.set(&"_brood_in", 0.0)
		wild._reckon()
	var mode := OS.get_environment("BENCH_OFF")
	if mode.contains("wild"):
		wild.process_mode = Node.PROCESS_MODE_DISABLED
		wild.visible = false
	if mode.contains("flora"):
		var flora: Flora = _main.get(&"_flora")
		flora.process_mode = Node.PROCESS_MODE_DISABLED
		flora.visible = false


var _casting: bool = OS.get_environment("BENCH_CAST") == "1"
var _casts: int = 0
var _placed: bool = false
var _spikes: Array[String] = []


func _cast_again() -> void:
	if not _casting:
		return
	var net: CastNet = _main.get(&"_net")
	if net.state != CastNet.State.IDLE:
		return
	var angler: Node2D = _main.get(&"_angler")
	if _casts == 0 and not _placed:
		_placed = true
		angler.stand_at(angler.shore_toward(Iso.ISLAND_CENTRE + Vector2(1.0, 1.0) * 20.0))
	var spot := net.nearest_catch(angler.position, 400.0)
	if spot == Vector2.INF:
		# No green spot: throw straight out at three quarters of the range.
		var out := (angler.position - Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)).normalized()
		if out == Vector2.ZERO:
			out = Vector2.DOWN
		for k in 16:
			var at := angler.position + out.rotated(TAU * k / 16.0) * 160.0
			if net.in_reach(at):
				spot = at
				break
	if spot == Vector2.INF:
		if _casts == 0 and _n % 60 == 0:
			print("no spot; hold ", net.hold, " state ", net.state)
		return
	_main._cast_at(spot)
	_casts += 1
	var luck := OS.get_environment("BENCH_LUCK")
	if luck.contains("lucky"):
		net.luck_power = 1
		net.luck_hold = _main.LUCKY_EXTRA
	if luck.contains("double"):
		var net2: CastNet = _main.get(&"_net2")
		if net2 != null and net2.state == CastNet.State.IDLE:
			var at: Vector2 = _main._double_spot(Iso.world_to_tile(spot))
			if at != Vector2.INF:
				net2.cast_to(Iso.tile_to_world(at.x, at.y))
	if OS.get_environment("BENCH_OFF").contains("count"):
		var count: Node = _main.get(&"_haul_count")
		if count != null:
			count.process_mode = Node.PROCESS_MODE_DISABLED
			(count as CanvasItem).visible = false


func _walk(delta: float) -> void:
	if not _walking:
		return
	_clock += delta
	var want: StringName = WALK[int(_clock / WALK_LEG) % WALK.size()]
	if want == _held:
		return
	if _held != &"":
		Input.action_release(_held)
	Input.action_press(want)
	_held = want


func _counters() -> Dictionary:
	return {
		"rebuilds": _grid.get("rebuilds"),
		"view": _grid.get("from_view"),
		"detail": _grid.get("from_detail"),
		"patch": _grid.get("from_patch"),
	}


func _process(delta: float) -> void:
	_walk(delta)
	_cast_again()
	var now := Time.get_ticks_usec()
	var ms := float(now - _last) / 1000.0
	_last = now
	_n += 1
	if _n <= WARMUP:
		if _n == WARMUP:
			_start = _counters()
			_seen_rebuilds = _start.rebuilds
		return
	_times.append(ms)
	if ms > 12.0:
		var n: CastNet = _main.get(&"_net")
		_spikes.append("%.1f ms  net state %d  caught %d  nodes %d objects %d" % [ms, n.state, n.catch.size(), get_tree().get_node_count(), Performance.get_monitor(Performance.OBJECT_COUNT)])
		_spikes.append("   cpu render %.2f gpu %.2f process-mon %.2f" % [RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()), RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	# A rebuild happens inside the grid's draw, so the one this frame's counter shows was
	# paid for in the frame just timed.
	var rebuilds := int(_grid.get("rebuilds"))
	if rebuilds != _seen_rebuilds:
		_rebuild_ms_total += float(_grid.get("rebuild_ms"))
		_seen_rebuilds = rebuilds
	_process_ms_total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_draws_total += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if _times.size() < SAMPLES:
		return
	_report()


func _report() -> void:
	print("casts ", _casts)
	var sorted := Array(_times)
	sorted.sort()
	var total := 0.0
	for t in sorted:
		total += t
	var over := 0
	for t in sorted:
		if t > 16.7:
			over += 1
	var count := sorted.size()
	var line := "frames %d  mean %.2f ms (%.0f fps)  median %.2f  p95 %.2f  p99 %.2f  worst %.2f  over-16.7ms %d (%.1f%%)" % [
		count, total / count, 1000.0 / (total / count), sorted[count / 2],
		sorted[int(count * 0.95)], sorted[int(count * 0.99)],
		sorted[count - 1], over, 100.0 * float(over) / float(count)
	]
	var end := _counters()
	var causes := "grid rebuilds %d (view %d detail %d patch %d)  last rebuild %.2f ms over %d tiles" % [
		end.rebuilds - _start.rebuilds, end.view - _start.view,
		end.detail - _start.detail, end.patch - _start.patch,
		_grid.get("rebuild_ms"), _grid.get("walked")
	]
	var engine := "rebuilds %.2f ms/frame  process %.2f ms/frame  draw calls %.0f/frame  pieces %d" % [
		_rebuild_ms_total / count, _process_ms_total / count, float(_draws_total) / count, _grid.get("drawn_pieces")
	]
	var label := "%s | walk %s | off '%s'" % [
		OS.get_environment("BENCH_LABEL"), _walking, OS.get_environment("BENCH_OFF")
	]
	for text in [label, line, causes, engine]:
		print(text)
	for text in _spikes.slice(0, 40):
		print(text)
	var log := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if log != null:
		for text in [label, line, causes, engine]:
			log.store_line(text)
		for text in _spikes.slice(0, 40):
			log.store_line(text)
		log.close()
	if _held != &"":
		Input.action_release(_held)
	get_tree().quit()
