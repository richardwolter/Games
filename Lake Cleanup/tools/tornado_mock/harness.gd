extends Node
## The tornado mock: a waterspout wanders a nearly cleaned lake near the island, lifts the
## top piece off every tile on its way into its funnel, carries them round, flings them out
## to splash down on new tiles, and is tamed by three net landings. Everything that happens
## to the lake is done here, identically for every look; a look only draws the funnel and
## the debris it carries. See README.md.
##
##   godot --path . --fixed-fps 60 res://tools/tornado_mock/shot_a.tscn \
##       --log-file tools/tornado_mock/a_engine.log
##
## Desktop build, never --headless (nothing renders, no shader compiles). Env overrides:
## TORNADO_LOOK=a|b|c picks the look whatever the scene says; TORNADO_WIDE=1 films the same
## (deterministic) event from further out into out_<look>/wide/.
##
## Own save path, deleted first; the lake hangs under this node, not the root, so it is not
## the game and wears no menu. Quits on a wall clock as well as on its last frame.

const DebrisDraw := preload("res://tools/tornado_mock/debris_draw.gd")
const Style := preload("res://scripts/style.gd")

@export var look_letter: String = "a"

const SAVE_PATH := "user://tornado_mock.save"
const QUIT_AFTER_MS := 150000
const SEED := 20260929
## The hour, held: early afternoon, light enough to read under the storm.
const DAY_PHASE := 0.5

## Frames of set-up before the tornado's clock starts: the lake builds, is thinned, the
## rain is poured and the camera lands.
const PREROLL := 150

# --- The timeline, in seconds of the tornado's own clock --------------------------------
const TOUCH_END := 2.0
const HITS: Array[float] = [9.5, 11.0, 12.5]
const HIT_LONG := 0.6
const COLLAPSE_LONG := 1.5
const END := 16.0

# --- The funnel ------------------------------------------------------------------------
## Funnel height at strength 1, world px.
const HEIGHT := 300.0
## Funnel radius at the water and at the top, world px, at strength 1 (see `radius_at`).
const BASE_R := 12.0
const TOP_R := 72.0
## Strength after each of the first two hits; the third collapses it.
const HIT_STRENGTH: Array[float] = [0.74, 0.5]

# --- Moving ----------------------------------------------------------------------------
## Speed along the path, world px/s, by phase.
const SPEED_TOUCH := 10.0
const SPEED_ROAM := 72.0
const SPEED_HURT := 34.0
const SPEED_COLLAPSE := 12.0
## The path: round the island, `PATH_GROW` tiles past its shore, from `PATH_FROM` (radians,
## tile space; PI/4 is straight down the screen) the way the angle grows.
const PATH_FROM := -1.05
const PATH_GROW := 7.0
const PATH_GROW_SWING := 1.6
const PATH_LONG := 900.0
## Knockback off each hit, world px, away from the angler.
const KNOCK := 26.0

# --- Debris ----------------------------------------------------------------------------
const LIFT_REACH := 0.9
const LIFT_GAP := 0.14
const RELIFT_AFTER := 3.0
const CARRY_MOST := 14
const LIFT_TIME := 0.9
const FLING_EVERY := 1.2
## When it is carrying all it can, it sheds faster, so it keeps lifting along its path.
const FLING_FULL := 0.55
const FLING_FROM := 6
const LIFT_TIER_MOST := 3

# --- Water ----------------------------------------------------------------------------
const SHOVE_REACH := 2.6
const SHOVE_PUSH := 22.0
const BUMP_REACH := 1.8
const SPRAY_RATE := 42.0
const REMAP_EVERY := 0.5

# --- Camera and capture ----------------------------------------------------------------
const ZOOM_NEAR := 1.0
const ZOOM_WIDE := 0.667
const CAM_LIFT := 130.0
const CAM_LIFT_WIDE := 40.0
const CAM_EASE := 3.0
## The crop saved for the gif: the base stands 560 px down it, the funnel's top ~110.
const CROP := Rect2i(560, 175, 800, 640)
const STILLS := {"touchdown": 1.5, "roam_mid": 6.0, "hit2": 11.1, "collapse": 13.1, "calm": 15.5}

var _main: Node
var _grid: LakeGrid
var _splash: WaterSplash
var _weather: Weather
var _day: DayCycle
var _look: Node2D
var _shadows: Node2D
var _flung_layer: Node2D
var _net_layer: Node2D
var _rng := RandomNumberGenerator.new()
var _frames := 0
var _started := 0
var _wide := false
var _out := ""
var _log: FileAccess

var _path := PackedVector2Array()
var _path_len := PackedFloat32Array()
var _along := 0.0

var _clock := -1.0
var _phase := "wait"
var _phase_t := 0.0
var _strength := 0.0
var _hits := 0
var _hit_flash := 0.0
var _hit_at := -99.0
var _spin := 0.0
var _base := Vector2.ZERO
var _base_was := Vector2.ZERO
var _velocity := Vector2.ZERO
var _lean := Vector2.ZERO
var _knock := Vector2.ZERO
var _cam := Vector2.ZERO

var _debris: Array[Dictionary] = []
var _flung: Array[Dictionary] = []
var _lifted_at := {}
var _lift_in := 0.0
var _fling_in := FLING_EVERY
var _remap_in := 0.0
var _ripple_in := 0.0
var _core_ripple_in := 0.0
var _bump_in := 0.0
var _spray_owed := 0.0
var _collapse_in := 0.0
var _net: Dictionary = {}

var _stats := {}
var _stills_done := {}
var _task_was := -1
var _captured := 0
var _state: Dictionary = {}
## What the look asks of the harness (`harness_opts()` on the look, optional; every key has
## a default that keeps the older looks exactly as they were):
##   lift_splash  (true)  a crown splash where each piece is lifted; false: a ring only
##   foot_spray   (true)  the harness's drips spat off the foot; false: the rolls are still
##                        made (so the event is the same for every look) but nothing is drawn
##   land_splash  (true)  a crown splash where each flung piece lands; false: a ring only
##   hit_spray    (true)  a hit's crown splash and drips at the foot; false: the rolls are
##                        still made, only its rings are drawn (the look draws its own burst)
##   net_beside   (false) the stand-in net lies beside the foot, on the angler's side, instead
##                        of round it
##   net_off      (40.0)  with net_beside: how far from the base (world px) it lands; a look
##                        with a wide foam skirt pushes it clear of the skirt
##   crop         (CROP)  the Rect2i cut out of the window for each frame
var _opts: Dictionary = {}
var _crop := CROP


func _ready() -> void:
	seed(SEED)
	_rng.seed = SEED
	_started = Time.get_ticks_msec()
	var env_look := OS.get_environment("TORNADO_LOOK")
	if env_look != "":
		look_letter = env_look
	_wide = OS.get_environment("TORNADO_WIDE") == "1"
	_out = "res://tools/tornado_mock/out_%s/" % look_letter
	if _wide:
		_out += "wide/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_clear_frames()
	_log = FileAccess.open(_out + "log.txt", FileAccess.WRITE)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	add_child(_main)
	_say("look %s wide %s" % [look_letter, str(_wide)])


func _clear_frames() -> void:
	var dir := DirAccess.open(_out)
	if dir == null:
		return
	for f in dir.get_files():
		if f.begins_with("f_") and f.ends_with(".png"):
			dir.remove(f)


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()


# ======================================================================================
# Set-up
# ======================================================================================

func _setup_lake() -> void:
	_grid = _main.get(&"_grid")
	_splash = _main.get(&"_splash")
	_weather = _main.get(&"_weather")
	_day = _main.get(&"_day")
	(_main.get(&"_hud_layer") as CanvasLayer).visible = false
	for dog: Node in _main.get(&"_dogs"):
		dog.visible = false
		dog.process_mode = Node.PROCESS_MODE_DISABLED
	var flock: Node = _main.get(&"_flock")
	if flock != null:
		flock.visible = false
		flock.process_mode = Node.PROCESS_MODE_DISABLED
	_build_path()
	_thin()
	_grid._rebuild()
	_grid.queue_redraw()
	_main._build_filth_map()
	var total: float = _main.get(&"_filth_total")
	var left := _grid.filth_left()
	_main.set(&"_filth_left", left)
	_main.set(&"pollution", clampf(left / maxf(total, 0.001), 0.0, 1.0))
	_say("cleaned %.1f%% (pollution %.3f), pieces %d" % [
		(1.0 - left / maxf(total, 0.001)) * 100.0, float(_main.get(&"pollution")), _grid.piece_count()])
	get_viewport().warp_mouse(Vector2(960.0, 540.0))
	_main.set(&"_mouse_inside", false)
	_main.set(&"_free_view", true)
	_main.set(&"_view_zoom", ZOOM_WIDE if _wide else ZOOM_NEAR)
	_weather.pour(600.0)
	_weather.set(&"_rain", 1.0)
	_base = _path_point(0.0)
	_base_was = _base
	_cam = _base - Vector2(0.0, CAM_LIFT_WIDE if _wide else CAM_LIFT)
	_add_layers()


func _add_layers() -> void:
	_shadows = _Layer.new()
	_shadows.harness = self
	_shadows.kind = 0
	_shadows.z_index = 6
	_main.add_child(_shadows)
	_flung_layer = _Layer.new()
	_flung_layer.harness = self
	_flung_layer.kind = 1
	_flung_layer.z_index = 19
	_main.add_child(_flung_layer)
	_net_layer = _Layer.new()
	_net_layer.harness = self
	_net_layer.kind = 2
	_net_layer.z_index = 19
	_main.add_child(_net_layer)
	var path := "res://tools/tornado_mock/look_%s.gd" % look_letter
	if not ResourceLoader.exists(path):
		_say("no %s, drawing look_a in its place" % path)
		path = "res://tools/tornado_mock/look_a.gd"
	var script: Script = load(path)
	_look = Node2D.new()
	_look.set_script(script)
	_look.z_index = 20
	_main.add_child(_look)
	_look.position = _base
	_look.call(&"setup", {
		"main": _main, "grid": _grid, "splash": _splash, "palette": Palette.master(),
		"art_pixel": 2.0, "day": _day, "weather": _weather, "height": HEIGHT,
		"base_r": BASE_R, "top_r": TOP_R,
	})
	if _look.has_method(&"harness_opts"):
		_opts = _look.call(&"harness_opts")
		_crop = _opts.get("crop", CROP)
		_say("look opts %s" % str(_opts))


## The path in world px: round the island, `PATH_GROW` tiles out with a slow swing in and
## out, sampled until it is `PATH_LONG` long.
func _build_path() -> void:
	var a := PATH_FROM
	var length := 0.0
	var was := Vector2.INF
	while length < PATH_LONG and a < PATH_FROM + TAU:
		var u := a - PATH_FROM
		var grow := PATH_GROW + PATH_GROW_SWING * sin(u * 5.0 + 0.4)
		var p := Iso.island_point(a, grow)
		if was != Vector2.INF:
			length += was.distance_to(p)
		_path.append(p)
		_path_len.append(length)
		was = p
		a += 0.004


func _path_point(d: float) -> Vector2:
	d = clampf(d, 0.0, _path_len[_path_len.size() - 1])
	var lo := 0
	var hi := _path_len.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _path_len[mid] <= d:
			lo = mid
		else:
			hi = mid
	var span := maxf(_path_len[hi] - _path_len[lo], 0.0001)
	return _path[lo].lerp(_path[hi], (d - _path_len[lo]) / span)


## Clean the lake to about 85%, by a hash, but leave the tornado's corridor and a few pools
## beside it whole, so there is plenty to lift and a trail of clean water behind it.
func _thin() -> void:
	var corridor: Array[Vector2] = []
	var d := 0.0
	var total := SPEED_TOUCH * TOUCH_END + SPEED_ROAM * (HITS[0] - TOUCH_END) + SPEED_HURT * 3.0 + 40.0
	while d <= total:
		corridor.append(Iso.world_to_tile(_path_point(d)))
		d += 12.0
	var pools: Array[Vector3] = []
	for k in 5:
		var at := Iso.world_to_tile(_path_point(total * (0.12 + 0.19 * float(k))))
		var side := 2.8 if k % 2 == 0 else -2.6
		var dir := (at - Iso.ISLAND_CENTRE).normalized()
		pools.append(Vector3(at.x + dir.x * side, at.y + dir.y * side, 1.6))
	var kept := 0
	for index in _grid.stacks.size():
		if _grid.stacks[index].is_empty():
			continue
		var tile := Vector2(_grid.tile_of(index)) + Vector2(0.5, 0.5)
		var h := sin(tile.x * 12.9898 + tile.y * 78.233) * 43758.5453
		h -= floor(h)
		var h2 := sin(tile.x * 39.3468 + tile.y * 11.135) * 24634.6345
		h2 -= floor(h2)
		# The corridor's edge wanders, so it reads as the lake's own dirty patches rather
		# than a stripe; its stacks are thin (one to three), so what it lifts leaves water.
		var reach := 1.1 + 0.7 * sin(tile.x * 0.9 + tile.y * 0.6) * cos(tile.y * 0.7 - tile.x * 0.3)
		var keep := 0
		for c in corridor:
			if tile.distance_squared_to(c) <= reach * reach:
				keep = 1 + int(h2 * 2.0)
				break
		if keep == 0:
			for p in pools:
				if tile.distance_to(Vector2(p.x, p.y)) <= p.z:
					keep = 1 + int(h2 * 3.0)
					break
		if keep == 0 and h < 0.1:
			keep = 99
		if keep == 0:
			_grid.stacks[index] = PackedInt32Array()
			continue
		kept += 1
		var st := _grid.stacks[index]
		if st.size() > keep:
			# Keep the top of the stack as it was dressed; drop from the bottom.
			_grid.stacks[index] = st.slice(st.size() - keep)
	_say("tiles kept %d" % kept)


# ======================================================================================
# The frame
# ======================================================================================

func _physics_process(delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _started > QUIT_AFTER_MS:
		_say("wall clock ran out")
		_finish()
		return
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 20:
		_setup_lake()
	if _frames < 20:
		return
	# Held weather and hour, so every look is filmed in the same light.
	_day.phase = DAY_PHASE
	_weather.set(&"_flash_in", 999.0)
	if _frames >= PREROLL:
		if _clock < 0.0:
			_clock = 0.0
			_set_phase("touchdown")
			_weather.strike()
		else:
			_clock += delta
		_step(delta)
	_drive_camera(delta)
	_count_remaps()
	if _clock >= 0.0:
		_capture()
		if _clock >= END:
			_finish()


func _set_phase(p: String) -> void:
	if p == _phase:
		return
	_log_phase()
	_phase = p
	_phase_t = 0.0
	_stats = {"lifted": 0, "flung": 0, "landed": 0, "remaps": 0, "carried_most": 0}
	_say("[%.2f] phase %s" % [_clock, p])


func _log_phase() -> void:
	if _stats.is_empty():
		return
	_say("  %s: lifted %d flung %d landed %d remaps %d carried now %d most %d" % [
		_phase, _stats["lifted"], _stats["flung"], _stats["landed"], _stats["remaps"],
		_debris.size(), _stats["carried_most"]])


func _step(delta: float) -> void:
	_phase_t += delta
	var t := _clock
	# Phase and strength.
	if _hits < HITS.size() and t >= HITS[_hits]:
		_hit()
	if _hits >= 3:
		if t >= HITS[2] + COLLAPSE_LONG:
			_set_phase("gone")
		else:
			_set_phase("collapse")
	elif _hits > 0 and t < _hit_at + HIT_LONG:
		_set_phase("hit")
	elif t < TOUCH_END:
		_set_phase("touchdown")
	else:
		_set_phase("roam")
	_strength = _strength_at(t)
	_hit_flash = maxf(_hit_flash - delta * 2.2, 0.0)
	_spin += delta * lerpf(3.0, 7.0, _strength)

	# Moving.
	var speed := SPEED_ROAM
	match _phase:
		"touchdown": speed = SPEED_TOUCH
		"hit": speed = SPEED_HURT * 0.4
		"collapse": speed = SPEED_COLLAPSE
		"gone": speed = 0.0
		_: speed = SPEED_HURT if _hits > 0 else SPEED_ROAM
	_along += speed * delta
	_knock *= exp(-2.5 * delta)
	var meander := Vector2(sin(t * 1.3) * 10.0, cos(t * 0.9) * 4.0) * minf(_strength * 1.5, 1.0)
	_base_was = _base
	_base = _path_point(_along) + meander + _knock
	_velocity = (_base - _base_was) / maxf(delta, 0.0001)
	# The top trails the way it is going, and swings with a hit.
	var want_lean := -_velocity * 0.55 + Vector2(sin(t * 0.8) * 14.0, 0.0)
	_lean = _lean.lerp(want_lean, 1.0 - exp(-2.0 * delta))

	_track_carried(delta)
	if _strength > 0.35 and _phase != "collapse" and _phase != "gone":
		_lift(delta)
		_fling_now(delta)
	_tick_flung(delta)
	_tick_collapse(delta)
	_water(delta)
	_tick_net(delta)

	_remap_in -= delta
	if _remap_in <= 0.0:
		_remap_in = REMAP_EVERY
		_main.set(&"_filth_stale", true)

	_stats["carried_most"] = maxi(int(_stats.get("carried_most", 0)), _debris.size())
	_push_state(delta)


func _strength_at(t: float) -> float:
	if t < TOUCH_END:
		return smoothstep(0.0, TOUCH_END, t)
	if _hits == 0:
		return 1.0
	if _hits >= 3:
		var u := clampf((t - HITS[2] - 0.1) / (COLLAPSE_LONG - 0.3), 0.0, 1.0)
		return HIT_STRENGTH[1] * (1.0 - u) * (1.0 - u) * (1.0 + 0.15 * sin(u * 20.0) * (1.0 - u))
	# A hit knocks it lower than it settles, and it recovers to the step over half a second.
	var target: float = HIT_STRENGTH[_hits - 1]
	var since := t - _hit_at
	var dip := 0.14 * exp(-since * 5.0) * cos(since * 14.0)
	var from := 1.0 if _hits == 1 else HIT_STRENGTH[_hits - 2]
	var u2 := smoothstep(0.0, 0.25, since)
	return lerpf(from, target, u2) - dip


# ======================================================================================
# The funnel's shape, shared with the look through the state
# ======================================================================================

## The funnel's axis at `frac` of its height (0 water, 1 top), relative to the base.
func axis_at(frac: float) -> Vector2:
	var h := HEIGHT * _strength * frac
	var snake := Vector2(sin(_clock * 1.7 + frac * 3.0) * 7.0 * frac, 0.0)
	var jolt := Vector2(sin(_clock * 40.0) * 10.0 * _hit_flash * frac, 0.0)
	return Vector2(_lean.x * frac * frac, _lean.y * 0.2 * frac) + snake + jolt - Vector2(0.0, h)


## The funnel's radius at `frac` of its height, world px, strength applied.
func radius_at(frac: float) -> float:
	var r := lerpf(BASE_R, TOP_R, pow(clampf(frac, 0.0, 1.0), 1.4))
	return r * lerpf(0.45, 1.0, _strength) * (1.0 + 0.25 * _hit_flash)


# ======================================================================================
# Debris
# ======================================================================================

func _lift(delta: float) -> void:
	_lift_in -= delta
	if _lift_in > 0.0 or _debris.size() >= CARRY_MOST:
		return
	var here := Iso.world_to_tile(_base)
	var centre := _grid.tile_at(_base)
	if centre < 0:
		return
	var best := -1
	var best_d := INF
	for index: int in _grid.tiles_within(centre, 2.0):
		var st := _grid.stacks[index]
		if st.is_empty() or _grid.dry[index] == 1:
			continue
		if _clock - float(_lifted_at.get(index, -99.0)) < RELIFT_AFTER:
			continue
		var def := _grid.defs[st[st.size() - 1]]
		if def.keepsake or def.tier > LIFT_TIER_MOST:
			continue
		var dd := (Vector2(_grid.tile_of(index)) + Vector2(0.5, 0.5)).distance_to(here)
		if dd <= LIFT_REACH and dd < best_d:
			best = index
			best_d = dd
	if best < 0:
		return
	_lift_in = LIFT_GAP
	var from := _grid.surface_pos(best)
	var def_index := _grid.take(best, _grid.top_slot(best))
	_lifted_at[best] = _clock
	_move_pollution(-_grid.defs[def_index].pollution)
	_stats["lifted"] = int(_stats["lifted"]) + 1
	var rel := from - _base
	var circ := Vector2(rel.x, rel.y * 2.0)
	_debris.append({
		"def_index": def_index, "def": _grid.defs[def_index], "state": "lift", "age": 0.0,
		"angle": atan2(circ.y, circ.x), "r0": circ.length(), "radius": circ.length(),
		"height": 0.0, "band": _rng.randf_range(0.22, 0.88), "margin": _rng.randf_range(6.0, 22.0),
		"seed": _rng.randf() * TAU, "whirl": _rng.randf_range(0.75, 1.35), "rot": _grid.tilt[best], "spin_rate": _rng.randf_range(-5.0, 5.0),
		"scale": 1.0, "alpha": 1.0, "local": rel, "front": rel.y > 0.0, "depth": rel.y,
		"ground": rel,
	})
	if _opts.get("lift_splash", true):
		_splash.splash(from, 0.28, true)
	_splash.ripple(from, 10.0)


func _track_carried(delta: float) -> void:
	for d: Dictionary in _debris:
		d["age"] = float(d["age"]) + delta
		var hf := 0.0
		var rr := 0.0
		var band: float = d["band"]
		# Faster low down, slower up top, and every piece at its own pace, so pieces lifted
		# together off the same side spread round the funnel instead of orbiting as a clump.
		var w := lerpf(3.4, 1.9, band) * float(d["whirl"]) * lerpf(0.7, 1.0, _strength)
		d["angle"] = float(d["angle"]) + w * delta
		if d["state"] == "lift":
			var u := clampf(float(d["age"]) / LIFT_TIME, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - u, 3.0)
			hf = band * e
			rr = lerpf(float(d["r0"]), radius_at(hf) + float(d["margin"]), smoothstep(0.0, 0.7, u))
			if u >= 1.0:
				d["state"] = "orbit"
		else:
			var sd: float = d["seed"]
			band = clampf(band + sin(_clock * 0.7 + sd) * 0.05 * delta, 0.15, 0.92)
			d["band"] = band
			hf = band + sin(_clock * 2.3 + sd) * 0.02
			rr = radius_at(hf) + float(d["margin"])
		var a: float = d["angle"]
		var axis := axis_at(hf)
		var ring := Vector2(cos(a) * rr, sin(a) * rr * 0.5)
		d["local"] = axis + ring
		d["ground"] = Vector2(axis.x, 0.0) + ring
		d["height"] = -axis.y
		d["radius"] = rr
		d["front"] = sin(a) > 0.0
		d["depth"] = sin(a)
		d["rot"] = float(d["rot"]) + float(d["spin_rate"]) * delta


func _fling_now(delta: float) -> void:
	_fling_in -= delta
	if _fling_in > 0.0:
		return
	if _debris.size() <= FLING_FROM:
		_fling_in = 0.2
		return
	_fling_in = FLING_EVERY
	var pick := -1
	for i in _debris.size():
		if _debris[i]["state"] == "orbit":
			pick = i
			break
	if pick >= 0:
		_throw(pick, _rng.randf_range(2.5, 4.5), 0.75)
	if _debris.size() >= CARRY_MOST - 1:
		_fling_in = FLING_FULL


## Throw carried piece `i` out of the funnel, `tiles` tiles, `tangent` of its way off the
## tangent of its orbit (the rest straight out).
func _throw(i: int, tiles: float, tangent: float) -> void:
	var d: Dictionary = _debris[i]
	_debris.remove_at(i)
	var a: float = d["angle"]
	var out := Vector2(cos(a), sin(a))
	var tan := Vector2(-sin(a), cos(a))
	var dir := (tan * tangent + out * (1.0 - tangent * 0.5)).normalized()
	var from: Vector2 = _base + (d["ground"] as Vector2)
	var target := -1
	var to := Vector2.ZERO
	for attempt in 12:
		var turn := (0.35 * float((attempt + 1) / 2)) * (1.0 if attempt % 2 == 0 else -1.0)
		var dd := dir.rotated(turn)
		var reach := tiles * (1.0 - 0.06 * float(attempt / 4))
		var world := from + Vector2(dd.x, dd.y * 0.5) * Iso.tile_circle_extent(reach)
		var idx := _grid.tile_at(world)
		if idx < 0:
			continue
		var tile := _grid.tile_of(idx)
		if not Iso.floats_here(tile.x, tile.y) or _grid.dry[idx] == 1:
			continue
		target = idx
		to = _grid.surface_still(idx)
		break
	if target < 0:
		# Nowhere to land it: put it straight back under the base.
		target = _grid.tile_at(_base)
		to = _base
	var dist := from.distance_to(to)
	_flung.append({
		"def_index": d["def_index"], "def": d["def"], "from": from, "to": to, "tile": target,
		"t": 0.0, "dur": 0.7 + dist / 420.0, "h0": float(d["height"]),
		"peak": 30.0 + dist * 0.25, "rot": float(d["rot"]), "spin": _rng.randf_range(-9.0, 9.0),
		"at": from - Vector2(0.0, float(d["height"])), "ground": from, "height": float(d["height"]),
		"scale": 1.0,
	})
	_stats["flung"] = int(_stats["flung"]) + 1


## The meter's running total, moved by hand: the lake's own `_on_net_caught` would also mark
## the filth map stale on every lift, and the map is remapped on `REMAP_EVERY` instead.
func _move_pollution(by: float) -> void:
	var total: float = _main.get(&"_filth_total")
	var left := maxf(float(_main.get(&"_filth_left")) + by, 0.0)
	_main.set(&"_filth_left", left)
	_main.set(&"pollution", clampf(left / maxf(total, 0.001), 0.0, 1.0))


func _tick_flung(delta: float) -> void:
	var i := 0
	while i < _flung.size():
		var f: Dictionary = _flung[i]
		f["t"] = float(f["t"]) + delta
		var u := clampf(float(f["t"]) / float(f["dur"]), 0.0, 1.0)
		var ground: Vector2 = (f["from"] as Vector2).lerp(f["to"], u)
		var h := float(f["h0"]) * pow(1.0 - u, 1.4) + float(f["peak"]) * 4.0 * u * (1.0 - u)
		f["ground"] = ground
		f["height"] = h
		f["at"] = ground - Vector2(0.0, h)
		f["rot"] = float(f["rot"]) + float(f["spin"]) * delta * (1.0 - u * 0.5)
		if u >= 1.0:
			_land(f)
			_flung.remove_at(i)
			continue
		i += 1


func _land(f: Dictionary) -> void:
	var idx: int = f["tile"]
	var def: TrashDef = f["def"]
	if idx >= 0:
		_grid.insert(idx, _grid.height_of(idx), int(f["def_index"]))
		_grid.bump(idx)
		for n: int in _grid.tiles_within(idx, 1.0):
			if n != idx:
				_grid.bump(n)
	var to: Vector2 = f["to"]
	var weight := clampf(def.size.length() / 60.0, 0.0, 1.0)
	if _opts.get("land_splash", true):
		_splash.splash(to, 0.35 + weight * 0.4, true)
	_splash.ripple(to, 12.0 + weight * 10.0)
	# A piece landing puts its pollution back; the map catches up on the next remap.
	_move_pollution(def.pollution)
	_stats["landed"] = int(_stats["landed"]) + 1


# ======================================================================================
# Hits and the collapse
# ======================================================================================

func _hit() -> void:
	_hits += 1
	_hit_at = _clock
	_hit_flash = 1.0
	_say("[%.2f] hit %d, carrying %d" % [_clock, _hits, _debris.size()])
	var angler: Node2D = _main.get(&"_angler")
	var away := (_base - angler.position).normalized() if angler != null else Vector2.RIGHT
	_knock += away * KNOCK
	var spray: bool = _opts.get("hit_spray", true)
	if spray:
		_splash.splash(_base, 0.85, true)
	for k in 8:
		var a := TAU * float(k) / 8.0
		_splash.ripple(_base + Vector2(cos(a) * 22.0, sin(a) * 11.0), 10.0)
	_splash.ripple(_base, 30.0)
	for k in 26:
		var a := TAU * float(k) / 26.0 + _rng.randf() * 0.2
		var at := _base + Vector2(cos(a) * 10.0, sin(a) * 5.0)
		var vel := Vector2(cos(a) * _rng.randf_range(90.0, 200.0), sin(a) * 60.0 - _rng.randf_range(150.0, 320.0))
		var size := _rng.randf_range(2.0, 4.0)
		var life := _rng.randf_range(0.45, 0.8)
		if spray:
			_splash.drip(at, vel, size, life)
	if _hits < 3:
		# The jolt shakes a couple of pieces loose.
		for k in mini(2, _debris.size()):
			_throw(_rng.randi_range(0, _debris.size() - 1), _rng.randf_range(2.0, 3.5), 0.4)
		_fling_in = maxf(_fling_in, 0.6)
	else:
		# Collapse: everything it carried is let go, staggered, outward.
		_collapse_in = 0.15
		_weather.strike()


func _tick_collapse(delta: float) -> void:
	if _hits < 3 or _debris.is_empty():
		return
	_collapse_in -= delta
	while _collapse_in <= 0.0 and not _debris.is_empty():
		_collapse_in += 0.06
		# Highest first, so it sheds from the top as it falls.
		var pick := 0
		for i in _debris.size():
			if float(_debris[i]["height"]) > float(_debris[pick]["height"]):
				pick = i
		_throw(pick, _rng.randf_range(1.5, 3.5), 0.25)


# ======================================================================================
# The water
# ======================================================================================

func _water(delta: float) -> void:
	var s := _strength
	if _phase == "gone":
		_ripple_in -= delta
		if _ripple_in <= 0.0 and _phase_t < 1.2:
			_ripple_in = 0.4
			_splash.ripple(_base, 20.0 + _phase_t * 20.0)
		return
	if s < 0.03:
		return
	var tile := _grid.tile_at(_base)
	# Pieces round it are pushed round it, and set bobbing.
	if tile >= 0:
		var here := Iso.world_to_tile(_base)
		for index: int in _grid.tiles_within(tile, SHOVE_REACH + 1.0):
			if _grid.stacks[index].is_empty() or _grid.dry[index] == 1:
				continue
			var rel := Vector2(_grid.tile_of(index)) + Vector2(0.5, 0.5) - here
			var dist := rel.length()
			if dist > SHOVE_REACH or dist < 0.2:
				continue
			var w := rel.normalized()
			var world_rel := Iso.tile_to_world(w.x, w.y) - Iso.tile_to_world(0.0, 0.0)
			var tangent := Vector2(-world_rel.y * 2.0, world_rel.x * 0.5).normalized()
			var fall := 1.0 - dist / SHOVE_REACH
			var want := (tangent * 0.85 - world_rel.normalized() * 0.3) * SHOVE_PUSH * s * (0.4 + 0.6 * fall)
			_grid.shove_to(index, want, delta)
		_bump_in -= delta
		if _bump_in <= 0.0:
			_bump_in = 0.18
			var near := _grid.tiles_within(tile, BUMP_REACH)
			if not near.is_empty():
				_grid.bump(near[_rng.randi_range(0, near.size() - 1)])
	# Spray off the foot, thrown round and up.
	_spray_owed += SPRAY_RATE * s * delta
	while _spray_owed >= 1.0:
		_spray_owed -= 1.0
		var a := _spin * 0.5 + _rng.randf() * TAU
		var r := radius_at(0.0) * _rng.randf_range(0.8, 1.6)
		var at := _base + Vector2(cos(a) * r, sin(a) * r * 0.5)
		var tan := Vector2(-sin(a), cos(a) * 0.5)
		var vel := tan * _rng.randf_range(70.0, 170.0) * s + Vector2(0.0, -_rng.randf_range(60.0, 220.0) * s)
		var size := _rng.randf_range(2.0, 3.5)
		var life := _rng.randf_range(0.3, 0.6)
		if _opts.get("foot_spray", true):
			_splash.drip(at, vel, size, life)
	# Rings spiralling out of the foot.
	_ripple_in -= delta
	if _ripple_in <= 0.0:
		_ripple_in = 0.1
		var k := fmod(_clock * 10.0, 7.0)
		var a := _spin * 0.35 + k * 0.9
		var r := (8.0 + k * 7.0) * lerpf(0.6, 1.0, s)
		_splash.ripple(_base + Vector2(cos(a) * r, sin(a) * r * 0.5), 5.0 + k)
	_core_ripple_in -= delta
	if _core_ripple_in <= 0.0:
		_core_ripple_in = 0.42
		_splash.ripple(_base, 18.0 * s + 6.0)


# ======================================================================================
# The stand-in net
# ======================================================================================

const NET_FLY := 0.45
const NET_LIE := 0.35
const NET_REEL := 0.55


func _tick_net(_delta: float) -> void:
	_net = {}
	var angler: Node2D = _main.get(&"_angler")
	var hand := (angler.position + Vector2(0.0, -40.0)) if angler != null else _base + Vector2(-300.0, 0.0)
	# Where it lands: on the foot, or (for a look that asks) just beside it on the angler's
	# side, so it reads as a net thrown at the foot rather than a ring drawn round it.
	var land := _base
	if _opts.get("net_beside", false):
		var way := (hand - _base) * Vector2(1.0, 2.0)
		way = way.normalized() if way.length() > 1.0 else Vector2.LEFT
		land = _base + Vector2(way.x, way.y * 0.5) * float(_opts.get("net_off", 40.0))
	for when: float in HITS:
		var since := _clock - when
		if since < -NET_FLY or since > NET_LIE + NET_REEL:
			continue
		if since < 0.0:
			var u := 1.0 - (-since / NET_FLY)
			var ground := hand.lerp(land, u)
			_net = {"state": "fly", "at": ground - Vector2(0.0, sin(u * PI) * 120.0), "open": u * 0.4,
				"hand": hand, "ground": ground}
		elif since < NET_LIE:
			_net = {"state": "lie", "at": land, "open": 1.0, "hand": hand, "ground": land}
		else:
			var u := (since - NET_LIE) / NET_REEL
			var ground := land.lerp(hand, u * 0.35)
			_net = {"state": "reel", "at": ground, "open": 1.0 - u * 0.7, "hand": hand,
				"ground": ground, "fade": 1.0 - u}
		return


# ======================================================================================
# State for the look, the camera, the capture
# ======================================================================================

func _push_state(delta: float) -> void:
	_state = {
		"phase": _phase, "t": _phase_t, "time": _clock, "strength": _strength, "hits": _hits,
		"hit_flash": _hit_flash, "velocity": _velocity, "spin": _spin, "height": HEIGHT,
		"lean": _lean, "base": _base, "debris": _debris, "flung": _flung,
		"axis_at": axis_at, "radius_at": radius_at, "net": _net,
		"since_hit": _clock - _hit_at,
		"collapse": clampf((_clock - HITS[2]) / COLLAPSE_LONG, 0.0, 1.0) if _hits >= 3 else 0.0,
		"tint": _day.tint, "ink": _day.ink, "rain": _weather.rain(), "flash": _day.flash,
	}
	_look.position = _base
	_look.call(&"tick", delta, _state)
	_look.queue_redraw()
	_shadows.queue_redraw()
	_flung_layer.queue_redraw()
	_net_layer.queue_redraw()


func _drive_camera(delta: float) -> void:
	if _grid == null:
		return
	var lift := CAM_LIFT_WIDE if _wide else CAM_LIFT
	var want := _base - Vector2(0.0, lift)
	_cam = _cam.lerp(want, 1.0 - exp(-CAM_EASE * delta))
	var camera: Camera2D = _main.get(&"_camera")
	_main.set(&"_free_at", _cam)
	camera.position = _cam
	_main.set(&"_view_zoom", ZOOM_WIDE if _wide else ZOOM_NEAR)


func _count_remaps() -> void:
	var task: int = _main.get(&"_filth_task")
	if task >= 0 and _task_was < 0 and not _stats.is_empty():
		_stats["remaps"] = int(_stats["remaps"]) + 1
	_task_was = task


func _capture() -> void:
	var frame := int(round(_clock * 60.0))
	if frame < 2:
		return
	for name: String in STILLS:
		if not _stills_done.has(name) and _clock >= float(STILLS[name]):
			_stills_done[name] = true
			var full := get_viewport().get_texture().get_image()
			full.save_png(ProjectSettings.globalize_path(_out + "still_%s.png" % name))
			_say("[%.2f] still %s: strength %.2f carried %d flung %d" % [
				_clock, name, _strength, _debris.size(), _flung.size()])
	if frame % 2 != 0:
		return
	var image := get_viewport().get_texture().get_image()
	if _wide:
		image.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	else:
		image = image.get_region(_crop)
	image.save_png(ProjectSettings.globalize_path(_out + "f_%04d.png" % _captured))
	_captured += 1


func _finish() -> void:
	_log_phase()
	_stats = {}
	_say("frames %d, pieces left in lake %d" % [_captured, _grid.piece_count() if _grid != null else -1])
	_say("done")
	get_tree().quit()


# ======================================================================================
# The harness's own drawing: shadows on the water, pieces in flight, the stand-in net
# ======================================================================================

class _Layer:
	extends Node2D
	var harness: Node
	var kind := 0

	func _draw() -> void:
		if harness == null:
			return
		match kind:
			0: harness._draw_shadows(self)
			1: harness._draw_flung(self)
			2: harness._draw_net(self)


const SHADOW_INK := Color(0.03, 0.08, 0.11)


func _draw_shadows(on: Node2D) -> void:
	for d: Dictionary in _debris:
		var h: float = d["height"]
		var high := clampf(h / HEIGHT, 0.0, 1.0)
		var def: TrashDef = d["def"]
		var w := maxf(def.size.x * 0.4, 4.0) * lerpf(1.0, 0.6, high)
		DebrisDraw.draw_shadow(on, _base + (d["ground"] as Vector2), w, lerpf(0.32, 0.12, high), SHADOW_INK)
	for f: Dictionary in _flung:
		var h: float = f["height"]
		var high := clampf(h / HEIGHT, 0.0, 1.0)
		var def: TrashDef = f["def"]
		var w := maxf(def.size.x * 0.45, 4.0) * lerpf(1.0, 0.55, high)
		DebrisDraw.draw_shadow(on, f["ground"], w, lerpf(0.36, 0.12, high), SHADOW_INK)


func _draw_flung(on: Node2D) -> void:
	for f: Dictionary in _flung:
		DebrisDraw.draw_piece(on, f["def"], f["at"], float(f["rot"]), float(f["scale"]))


func _draw_net(on: Node2D) -> void:
	if _net.is_empty():
		return
	var ink: Color = Style.NET_INK
	var fade: float = _net.get("fade", 1.0)
	ink.a *= fade
	var at: Vector2 = _net["at"]
	var open: float = _net["open"]
	# The rope from the hand, a line of art pixels.
	DebrisDraw.pixel_line(on, _net["hand"], at, Color(ink.r, ink.g, ink.b, ink.a * 0.8))
	if _net["state"] == "fly":
		DebrisDraw.pixel_ellipse(on, at, 6.0 + 20.0 * open, 4.0 + 8.0 * open, ink)
		return
	var rx := 40.0 * open * (0.75 if _opts.get("net_beside", false) else 1.0)
	var ry := rx * 0.5
	DebrisDraw.pixel_ring(on, at, rx, ry, ink, 2)
	for k in range(-3, 4):
		var x := float(k) / 4.0 * rx
		var yy := ry * sqrt(maxf(1.0 - (x / rx) * (x / rx), 0.0))
		DebrisDraw.pixel_line(on, at + Vector2(x, -yy), at + Vector2(x, yy), ink)
		var y := float(k) / 4.0 * ry
		var xx := rx * sqrt(maxf(1.0 - (y / ry) * (y / ry), 0.0))
		DebrisDraw.pixel_line(on, at + Vector2(-xx, y), at + Vector2(xx, y), ink)
