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
## A change in the camera's per-frame velocity change bigger than this (world px/s a frame,
## a frame) is a jolt. 70: the frame a net lands, the target stops dead and the spring
## starts braking, a change of 50-65 at 400-600 px/s — a tenth of the pace, read as the
## view settling, not as a step. The stutter this probe was built for measured 100-300.
const JUMP := 70.0
## The haul's first frames, in which a view still running out with the throw slows to the
## cap rather than being cut to it; the cap is checked after them.
const EASE_IN := 30
## Frames a re-cast may carry the view's homeward pace before it has turned to the new net.
const BACK_MOST := 8

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
## Smoothness: the camera's velocity last frame, the worst change in it from one frame to
## the next (world px/s per frame) and how many frames it turned back on itself.
var _last_vel := Vector2.INF
var _last_acc := Vector2.INF
var _jerk := 0.0
var _flips := 0
var _jumps := 0
## PROBE_FAR=1: the far zoom stop, long casts in eight directions — where the edge clamp bites.
var _far := OS.get_environment("PROBE_FAR") == "1"
## PROBE_RECAST=1: throw the next cast the moment the net is home, while the view is still
## out, and count frames of the throw in which the view heads away from the new net.
var _recast := OS.get_environment("PROBE_RECAST") == "1"
var _back := 0
var _grey := 0


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
		# Let the view settle on the angler before the first throw: it starts the game
		# somewhere else, and that glide is not the cast's.
		if _frames < 4 + 120:
			return
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
	_main.call(&"_zoom_by", 0.0001 if _far else 1000.0)
	_main.set(&"net_range_level", 20 if _far else 16)
	# The zoom about the pointer is written as a pan; in play a cast takes it back, and
	# here the casts are thrown straight at the net, so clear it as play would.
	_main.set(&"_pan", Vector2.ZERO)
	_say("zoom %.3f  view %s  HOME_SPEED %.0f  LAND_INSET %.2f  CAST_LOOK %.2f" % [
		_camera.zoom.x, str(get_viewport().get_visible_rect().size / _camera.zoom),
		Lake.HOME_SPEED, Lake.LAND_INSET, Lake.CAST_LOOK])
	if _far:
		for level in [0, 20]:
			for k in 8:
				_plan.append([level, Vector2.RIGHT.rotated(TAU * k / 8.0), true])
		return
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
	_last_vel = Vector2.INF
	_last_acc = Vector2.INF
	_jerk = 0.0
	_flips = 0
	_jumps = 0
	_grey = 0
	_back = 0
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
	var vel := (_camera.position - _last_cam) / delta
	var moved := vel.length()
	_last_cam = _camera.position
	if _last_vel != Vector2.INF:
		# A jolt is the push changing, not the speed: a view braking hard but evenly is
		# smooth, one whose braking comes and goes from frame to frame is not.
		var acc := vel - _last_vel
		var change := 0.0 if _last_acc == Vector2.INF else (acc - _last_acc).length()
		_last_acc = acc
		_jerk = maxf(_jerk, change)
		if change > JUMP and moved > 30.0:
			_jumps += 1
			_say("    jolt %.0f px/s in state %d, frame %d, speed %.0f" % [
				change, _net.state, _flight_frames + _reel_frames + _glide_frames, moved])
		if vel.dot(_last_vel) < 0.0 and moved > 60.0 and _last_vel.length() > 60.0:
			_flips += 1
	_last_vel = vel
	# Never past the ground: every corner of the view over drawn forest.
	var half_view := get_viewport().get_visible_rect().size / _camera.zoom * 0.5
	if float(_main.call(&"_worst_corner_out", _camera.position, half_view)) > Ground.OUTER_OUT:
		_grey += 1
	if _net.state == CastNet.State.FLYING and moved > 5.0:
		var to_net := Iso.tile_to_world(_net.target.x, _net.target.y) - _camera.position
		if vel.dot(to_net) < 0.0:
			_back += 1
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
				var want: Vector2 = _main.call(&"_clamped_view", _main.call(&"_watching"))
				_say("    landing: camera %s, wants %s, net %s, unclamped %s" % [
					str(_camera.position), str(want), str(land), str(_main.call(&"_watching"))] + " tile %s target %s ext %.1f zoom %.3f" % [str(_net.tile_pos), str(_net.target), _net.open_extent(), _camera.zoom.x])
				_land_extent = _net.open_extent() / half.x
				_land_slack = Iso.tile_circle_extent(CastNet.CAST_SPEED / 60.0) / half.x
				_peak[0] = maxf(_peak[0], moved)
				_was_state = state
				return
			_reel_frames += 1
			if _reel_frames > EASE_IN:
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
	if state == CastNet.State.IDLE and _reel_frames > 0 and (_still >= 10 or _recast):
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
	_say("  smooth: worst push change %.0f px/s a frame a frame, %d jolts over %.0f, %d reversals" % [
		_jerk, _jumps, JUMP, _flips])
	_check(_jumps == 0 and _flips == 0, "the view moved smoothly", "")
	_say("  frames showing past the ground %d, throw frames heading away from the net %d" % [
		_grey, _back])
	_check(_grey == 0, "the view never showed past the ground", "")
	# A view still running home when the click comes carries that pace a few frames as it
	# turns: a turn, not a swing back to the angler. BACK_MOST frames of it are allowed.
	_check(_back <= BACK_MOST, "the throw never swung the view away from the net",
		"%d frames allowed for the turn" % BACK_MOST)
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
