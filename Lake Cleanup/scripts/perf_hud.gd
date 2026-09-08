## Real-time performance overlay. F3 to toggle.
##
## Visible only in debug builds. Logs frame metrics to console.
extends Node2D

const WINDOW_SIZE := 2.0  # seconds of history
const SPIKE_THRESHOLD := 20.0  # ms, what counts as "over 20ms" — missed refresh at 60fps
const LOG_PATH := "user://last_frames.log"

var _visible: bool = false
var _frame_times: PackedFloat32Array = PackedFloat32Array()
var _frame_index: int = 0
var _log_file: FileAccess = null
var _grid: Node2D = null
var _last_frame_count: int = 0
var _f3_held: bool = false
var _g_held: bool = false
var _print_counter: int = 0

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	z_index = 100
	_grid = get_tree().root.get_child(0).get_node_or_null("Grid")
	_open_log()

func _open_log() -> void:
	_log_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if _log_file == null:
		print("perf_hud: failed to open log at ", LOG_PATH)

func _process(_delta: float) -> void:
	var now_usec: int = Time.get_ticks_usec()
	if _frame_index == 0:
		_frame_index = now_usec
		return
	var frame_ms: float = float(now_usec - _frame_index) / 1000.0
	_frame_index = now_usec
	_frame_times.append(frame_ms)

	# Keep only 2 seconds of history
	var max_frames: int = int(Engine.get_frames_per_second() * WINDOW_SIZE)
	if _frame_times.size() > max_frames:
		_frame_times.remove_at(0)

	# Toggle visibility on F3
	if Input.is_key_pressed(KEY_F3):
		if not _f3_held:
			_visible = not _visible
		_f3_held = true
	else:
		_f3_held = false

	# Toggle ground on G (debug only, on release not hold)
	var g_now: bool = Input.is_key_pressed(KEY_G)
	if g_now and not _g_held:
		var roots := get_tree().root.get_children()
		for root in roots:
			for child in root.get_children():
				if child.name.begins_with("Ground") or child.name.begins_with("IslandGround") or child.name.begins_with("IslandShallows"):
					child.visible = not child.visible
	_g_held = g_now

	# Check for spike, log it
	if frame_ms > SPIKE_THRESHOLD and _log_file != null:
		var grid_rebuilds: int = _grid.get("rebuilds") if _grid else 0
		var drawn: int = _grid.get("drawn_pieces") if _grid else 0
		var msg: String = "frame %.1f ms  rebuilds %d  pieces %d" % [frame_ms, grid_rebuilds, drawn]
		_log_file.store_line(msg)
		_log_file.flush()

	# Print stats every 30 frames when visible
	if not _visible:
		_print_counter = 0
		return

	_print_counter += 1
	if _print_counter < 30:
		return
	_print_counter = 0

	var fps: float = Engine.get_frames_per_second()
	var mean_ms: float = 0.0
	var worst_ms: float = 0.0
	for t in _frame_times:
		mean_ms += t
		worst_ms = maxf(worst_ms, t)
	mean_ms /= maxf(float(_frame_times.size()), 1.0)

	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

	var rebuilds: int = _grid.get("rebuilds") if _grid else 0
	var drawn: int = _grid.get("drawn_pieces") if _grid else 0

	var from_view: int = _grid.get("from_view") if _grid else 0
	var from_detail: int = _grid.get("from_detail") if _grid else 0
	var from_patch: int = _grid.get("from_patch") if _grid else 0

	print(
		"FPS %.0f | ms %.1f (worst %.1f) | draws %d prims %d | rebuilds %d"
		% [fps, mean_ms, worst_ms, draw_calls, prims, rebuilds]
		+ " (view %d detail %d patch %d) pieces %d"
		% [from_view, from_detail, from_patch, drawn]
		+ " | rebuild %.1f ms over %d tiles"
		% [_grid.get("rebuild_ms") if _grid else 0.0, _grid.get("walked") if _grid else 0]
	)
