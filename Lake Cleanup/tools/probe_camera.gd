extends Node
## Measures the view during a cast: how fast the camera moves on the way out, on the way
## home and after the net is in, and where the net is on screen at the moment it lands.
## The probe behind issue #19 — a reel upgrade must not be a camera upgrade, and a long
## cast must come down inside the window.
##
## Four casts at each of the lowest and the highest reel level: short and long, thrown
## across the screen and down it. For each, the log gives the peak camera speed in world
## pixels a second by phase (against `Lake.HOME_SPEED`), how long the view took to settle
## after the net was home, and the net's landing spot as a fraction of the view's half-size
## from the camera (against `1 - Lake.LAND_INSET`).
##
## Headless is fine — nothing here needs a renderer — and a fixed frame rate keeps the
## per-frame speeds honest:
##
##   godot --headless --fixed-fps 60 --path . res://tools/probe_camera.tscn
##
## Writes tools/last_camera_probe.log.

const LOG_PATH := "res://tools/last_camera_probe.log"
const SAVE_PATH := "user://probe_camera.save"
const SHORT_TILES := 3.0
## How long the probe waits for the view to settle before giving up on a cast, in frames.
const PATIENCE := 60 * 40

var _main: Node
var _net: CastNet
var _angler: Angler
var _camera: Camera2D
var _log: FileAccess

var _frames := 0
var _plan: Array = []
var _step := -1
var _phase := 0
var _failed := 0

var _last_cam := Vector2.INF
var _peak := PackedFloat32Array([0.0, 0.0, 0.0])
var _was_state := 0
var _reel_frames := 0
var _glide_frames := 0
var _still := 0
var _land_frac := Vector2.ZERO
var _land_extent := 0.0
var _land_slack := 0.0
var _flight_frames := 0


func _ready() -> void:
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_say("--- probe_camera start")
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	add_child(_main)


func _say(line: String) -> void:
	_log.store_line(line)
	_log.flush()


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_failed += 1
	_say("%s %s%s" % ["ok  " if ok else "FAIL", what, "  (%s)" % detail if detail != "" else ""])


func _process(delta: float) -> void:
	_frames += 1
	if _frames == 3:
		_setup()
		return
	if _frames < 4:
		return
	if _step < 0:
		_step = 0
		_begin()
		return
	if _step >= _plan.size():
		return
	_watch(delta)


func _setup() -> void:
	_net = _main.get_node(^"Net") as CastNet
	_angler = _main.get_node(^"Angler") as Angler
	_camera = _main.get_node(^"Camera") as Camera2D
	(_main.get_node(^"Flock") as Flock).spawning = false
	var dog := _main.get_node_or_null(^"Dog")
	if dog != null:
		dog.set_process(false)
	_main.call(&"_zoom_by", 1000.0)
	_main.set(&"net_range_level", 16)
	_say("zoom %.3f  view %s  HOME_SPEED %.0f  LAND_INSET %.2f  CAST_LOOK %.2f" % [
		_camera.zoom.x, str(get_viewport().get_visible_rect().size / _camera.zoom),
		Lake.HOME_SPEED, Lake.LAND_INSET, Lake.CAST_LOOK])
	for level in [0, 20]:
		for dir in [Vector2(1.0, -1.0).normalized(), Vector2(1.0, 1.0).normalized()]:
			for long in [false, true]:
				_plan.append([level, dir, long])


## Start the next cast in the plan: set the reel level, find the water, throw.
func _begin() -> void:
	var level: int = _plan[_step][0]
	var dir: Vector2 = _plan[_step][1]
	var long: bool = _plan[_step][2]
	_main.set(&"reel_level", level)
	_main.call(&"_push_net_numbers")
	var where := _water_along(dir, long)
	var span := _angler.tile_pos.distance_to(Iso.world_to_tile(where))
	_say("")
	_say("cast %d: reel level %d (%.1f tiles/s), %s, %s: %.1f tiles" % [
		_step + 1, level, _net.reel_speed,
		"across the screen" if dir.y < 0.0 else "down the screen",
		"long" if long else "short", span])
	_peak = PackedFloat32Array([0.0, 0.0, 0.0])
	_reel_frames = 0
	_glide_frames = 0
	_flight_frames = 0
	_still = 0
	_phase = 0
	_last_cam = _camera.position
	_was_state = CastNet.State.IDLE
	if not _net.cast_to(where):
		_check(false, "the cast is thrown", "refused at %s" % str(where))
		_next()


## The farthest (or a short) castable spot from the angler along `dir`, in world units.
func _water_along(dir: Vector2, long: bool) -> Vector2:
	var best := Vector2.INF
	var span := SHORT_TILES if not long else 0.5
	while span <= _net.range_tiles:
		var tile := _angler.tile_pos + dir * span
		var where := Iso.tile_to_world(tile.x, tile.y)
		if _net.can_cast_to(where):
			best = where
			if not long:
				break
		span += 0.5
	return best


func _watch(delta: float) -> void:
	var moved := (_camera.position - _last_cam).length() / delta
	_last_cam = _camera.position
	var state := _net.state
	match state:
		CastNet.State.FLYING:
			_flight_frames += 1
			_peak[0] = maxf(_peak[0], moved)
		CastNet.State.REELING, CastNet.State.SETTLED:
			if _was_state == CastNet.State.FLYING:
				# The first frame after the net came down: where did it land on screen?
				# The lake moved the view before the net took its last step, so what is
				# measured here is the view as the throw left it — the step counts as the
				# throw's, and the landing is allowed to be that one step off the margin.
				var land := Iso.tile_to_world(_net.target.x, _net.target.y)
				var half := get_viewport().get_visible_rect().size / _camera.zoom * 0.5
				_land_frac = (land - _camera.position).abs() / half
				_land_extent = _net.open_extent() / half.x
				_land_slack = Iso.tile_circle_extent(CastNet.CAST_SPEED / 60.0) / half.x
				_peak[0] = maxf(_peak[0], moved)
				_was_state = state
				return
			_reel_frames += 1
			_peak[1] = maxf(_peak[1], moved)
		CastNet.State.IDLE:
			if _was_state != CastNet.State.IDLE or _reel_frames > 0:
				_glide_frames += 1
				_peak[2] = maxf(_peak[2], moved)
				if moved < 0.5:
					_still += 1
				else:
					_still = 0
	_was_state = state
	if state == CastNet.State.IDLE and _reel_frames > 0 and _still >= 10:
		_report()
		_next()
	elif _flight_frames + _reel_frames + _glide_frames > PATIENCE:
		_check(false, "the cast came home and the view settled", "gave up after %d frames" % PATIENCE)
		_next()


func _report() -> void:
	var allowed := 1.0 - Lake.LAND_INSET
	_say("  flight %d frames, haul %d frames (%.2f s), settled %d frames (%.2f s) after" % [
		_flight_frames, _reel_frames, _reel_frames / 60.0,
		_glide_frames - _still, (_glide_frames - _still) / 60.0])
	_say("  peak camera speed: out %.0f, home %.0f, after %.0f world px/s" % [
		_peak[0], _peak[1], _peak[2]])
	_say("  net at landing: %.2f x %.2f of the half-view (mouth %.2f wide)" % [
		_land_frac.x, _land_frac.y, _land_extent])
	_check(_peak[1] <= Lake.HOME_SPEED * 1.02 and _peak[2] <= Lake.HOME_SPEED * 1.02,
		"the view came home no faster than HOME_SPEED", "")
	_check(_land_frac.x + _land_extent <= allowed + _land_slack
		and _land_frac.y + _land_extent <= allowed + _land_slack,
		"the net came down inside the landing margin",
		"%.2f allowed, one step of the throw over it" % allowed)


func _next() -> void:
	_step += 1
	if _step >= _plan.size():
		_say("")
		_say("probe_camera: %d casts, %d failed" % [_plan.size(), _failed])
		_log.close()
		get_tree().quit()
		return
	_begin()
