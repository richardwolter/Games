extends Node2D
## The tornado's drawing, ported from tools/tornado_mock/look_d.gd (approved 2026-09-30) with
## only its mock-only hooks taken out: the eye log, the fixed collapse time. Driven by
## scripts/tornado.gd through `setup` and `tick`, exactly as the mock's harness drove it.
##
## Look D: look B's lumpy storm cloud with a tornado's eye turning in its middle, and look A's
## spray column hanging out of the eye, retoned into the cloud's greys so the two read as one
## storm. Everything is copied in from look_a / look_b (nothing is loaded from them at run
## time, so later edits to either cannot break this one).
##
## The cloud (a child at z 23, over the rain at 22, so no drop falls across its face): B's
## lobes on three rings and a towering tier, lit on a crescent along the top and shaded under.
## Its front row hangs unevenly (each lobe there drops and swells by its own roll), so the base
## is scalloped. Its middle ring is replaced by puffs round the eye that ARMS spiral arms are
## wound out of:
## each arm is its puffs' own shading lifted a step, fading back to plain puff towards its
## outer end, with a solid lit lip (two art pixels, three nearest the eye, doubled when the
## camera is zoomed out) only on edges facing right (taken off the spiral's own gradient), and
## a dark seam on the edges facing away; the grooves between are a step darker. The eye sits in
## the cloud's middle, so a ring of lobes stands in front of it: a hole seen from above, its far
## lip catching the light, its inner wall running down in spiral bands (turning faster than the
## arms) through the wall's hazy blue and the storm ink to the throat, Style.BOARD, the one
## swatch darker than every cloud tone by value (measured: 30 against the cloud shade's 40).
##
## The column (a shader quad): A's spray rope, its streaks, bubbles and torn edges, but shaded
## up its height in hard steps: spray-pale in the bottom quarter, then the storm's greys (the
## cloud's own body tones) above, the step lines wound on the helix; the streaks are A's width
## again, a step lighter than the body. Its top flares and goes up behind the eye's front lip
## into the throat's colours. It leans like A's: the cloud leads and the foot drags.
## It is drawn twice, split at the cloud's underside (`_split_y`): under the cloud below the
## line, over it above, so the rope runs up the front lobes into the throat with no gap and no
## seam; its top end is torn, inside the throat's swatch.
##
## The foot: A's foam mound, plumes, the boiling skirt and ring on the water, and B's cloud
## shadow and the column's cast shadow laid over the soup.
##
## Touchdown: the cloud condenses (thin pale lobes at its height, filling and darkening over
## 0.8 s), the arms wind in to a knot, the eye opens out of it a beat at a time with the lips
## running outwards, and only then the rope comes down out of it to the water.
## Hits: the waist pinches, the foot lifts off the water and drops back, the rope lights two
## steps then one, one ring bursts off the waist, the eye flares and the arms kick round;
## weaker each time.
## The vanish is the touchdown backwards: the rope thins and is drawn up into the eye from the
## water (its foam skirt falling into one or two torn spray rings no wider than 1.3x the
## disturbed ring, a step thinner each beat, and one burst of single-pixel spray off the foot),
## the eye spirals shut a beat at a time with the lips going from the inside out, the knot
## melts back into plain puffs (its reach scalloped by the lobes' noise), then the cloud breaks
## up from the rim: each lobe is bitten from its edge (keeping its crescent and underside),
## splits into lumps that part along the way away from the island and throw their own shadow
## down-left, then scalloped grey smears at the remnant step, all gone by about 15.35 s.
## The column is opaque (two alpha steps: whole, and the remnant for fray and loose clumps),
## widens steadily up to a neck the throat swallows, is banded spray-pale to storm grey in
## hard steps across its full width, carries A's streaks two or three steps lighter, and its
## top tears into the throat's swatch. Where it meets the cloud's underside the lobes drape
## over its shoulders (`_paint_collar`, z 25).
##
## No class_name, loaded by path; draws only, never touches the grid, never the global RNG.

const DebrisDraw := preload("res://scripts/tornado_debris_draw.gd")
const Style := preload("res://scripts/style.gd")
const SPOUT_SHADER := "res://shaders/tornado_spout.gdshader"
const WATER_SHADER := "res://shaders/tornado_water.gdshader"

const ART := 2.0
const FPS := 8.0
const REMNANT := 0.5
const N := 48
## When the vanish began on this look's clock (the mock had it fixed at 12.5 s); set on the
## first tick with three hits, off `since_hit`.
var _collapse_at := -1.0

# --- The column ------------------------------------------------------------------------------
## The eye's throat over the water at full strength, world px (the column's height).
const TOP_H := 285.0
## The drawn column is at most this share of the harness's radius where the debris orbits.
const SHEATH := 0.9
## How far the drawn debris is pulled from the harness's axis onto the drawn one.
const DEBRIS_FOLLOW := 0.8
const SKIRT_R := 50.0
const RING_R := 118.0
const PLUMES := 9

# --- The cloud (B's) -----------------------------------------------------------------------
const CLOUD_RX := 238.0
const CLOUD_FLAT := 0.3
const CLOUD_RISE := 34.0
## How much of the dissolve each lobe takes to go, once its turn comes.
const EAT_WINDOW := 0.55
const DIE_SPREAD := 0.45
## The break-up, in seconds after the third hit: it starts at the rim while the knot is still
## letting go and everything is gone by 12.5 + 1.3 + 1.55 = 15.35 s. Each lobe's turn starts at
## `die * DIE_SPREAD` of the dissolve and takes EAT_WINDOW of it (so the last ends at 1).
const BREAK_FROM := 1.3
const BREAK_LONG := 1.55

# --- The eye -------------------------------------------------------------------------------
## Its half-width at full strength (a bit over a quarter of the cloud's width), its flatness
## (the game's 2:1), the throat's place below its middle (a share of its half-height).
const EYE_RX := 66.0
const EYE_FLAT := 0.5
const THROAT_DOWN := 0.3
const ARMS := 3
## The puffs round the eye (plus one over its middle).
const INNER := 7
## The arms' winding: sectors turned per e-fold of radius (a log spiral), and how far out
## (eye half-widths) the vortex winds the cloud.
const WIND := 1.15
const VORTEX_OUT := 1.7
## Turn rates, rad/s: the arms and the eye's inner wall (the wall turns faster, it is nearer
## the core). Both are shown on the 8 fps beat; at these rates a step moves an arm's lip a few
## art pixels, which reads as turning rather than flicker.
const ARM_RATE := 1.1
const WALL_RATE := 2.2

var _ctx: Dictionary
var _s: Dictionary = {}
var _pal: Palette
var _splash: WaterSplash
var _day: DayCycle
## 0 highlight, 1 lit crest, 2 lit body, 3 body, 4 shade, 5 deep, 6 the throat. Real swatches
## only, none darker than the palette's darkest (water_dirty_deep).
var _ramp: Array[Color] = []

var _water: _Quad
var _sky: _Canvas
var _back: _Canvas
var _spout: _Quad
var _spout_top: _Quad
var _front: _Canvas
var _cloud_layer: _Canvas
var _collar: _Canvas
var _spout_mat: ShaderMaterial
var _spout_top_mat: ShaderMaterial
var _water_mat: ShaderMaterial

var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _step := -1
var _pt := 0.0
var _pat_spin := 0.0
var _arm_rot := 0.0
var _arm_shown := 0.0
var _wall_rot := 0.0
var _wall_shown := 0.0
var _cc := -1.0
var _size_s := 0.0
## The funnel's size against the mock's (2026-10-05, `Tornado.SIZE_START`..`SIZE_LAST`),
## eased: every length of the column, the eye, the cloud and the water's rings is multiplied
## by it. The pixel grid is untouched (nothing is scaled as a picture).
var _size := 1.0
var _lead := Vector2.ZERO
var _flare := 0.0

var _prof := PackedVector3Array()
var _top_h := TOP_H
var _vis_lo := 0.0
var _vis_hi := TOP_H
var _rope := 1.0
var _foot := 0.0
var _skirt_r := SKIRT_R
var _pinch := 0.0
var _pinch_h := 100.0
var _lift := 0.0

## World y of the line the column crosses from under the cloud to over it (just below the
## lowest lobe standing over the column's neck).
var _split_y := -100000.0
## 1 at the play zoom, 2 zoomed out: the lips, the throat and the rope's edges are drawn this
## many art pixels bolder, so the eye still reads as a pale spiral round a dark middle.
var _bold := 1
var _eye_c := Vector2.ZERO        # local, the eye's middle
var _eye_rx := EYE_RX
var _eye_open := 0.0
## How far out the arms are wound (a share of VORTEX_OUT): 0 before the eye starts, and again
## once it has shut and the knot has let go.
var _vx := 0.0
## The lit lips run between these two radii (eye half-widths): they grow outwards as the eye
## opens and are taken off from the inside out as it shuts.
var _lip_lo := 1.0
var _lip_hi := VORTEX_OUT
var _cloud_c := Vector2.ZERO      # local
var _cloud_rx := CLOUD_RX
var _cloud_amt := 0.0
var _dissolve := 0.0
var _cloud_up := 0.0

var _cloud_puffs: Array[Dictionary] = []
var _lobes: Array[Dictionary] = []     # this frame's ring and tower lobes
var _lip_lobes: Array[Dictionary] = []  # the front lip over the eye's south side (z 26)
var _lip: _Canvas
var _puffs: Array[Dictionary] = []     # vapour, world px
var _chunks: Array[Dictionary] = []    # falling spray, local
var _burst_hits := 0
var _burst_left := false
var _hits_seen := 0
var _touched := false
var _foot_left := false
## The way from the island to the storm (the break-up drifts off along it).
var _away := Vector2.RIGHT
## This frame's cloud lobes and break-up lumps (world x, y, radius), for their shadows.
var _blobs: Array[Vector3] = []
## How far (whole art pixels) the drawn cloud has been shifted since it was painted; its
## shadows follow.
var _blob_shift := Vector2.ZERO



func setup(ctx: Dictionary) -> void:
	_ctx = ctx
	_pal = ctx["palette"]
	_splash = ctx["splash"]
	_day = ctx["day"]
	_rng.seed = 7072
	_ramp = [
		_pal.water_clean_light,        # 0 highlight, flash, spray
		_pal.water_clean_shallow,      # 1 lit crest
		WashBackdrop.STORM_INK,        # 2 lit body
		WashBackdrop.STORM_SKY,        # 3 body
		_water_storm_ink(),            # 4 shade (the water shader's sky_storm_ink), the wall's grooves
		_pal.water_hazy_deep,          # 5 seams, the eye's inner wall
		Style.BOARD,                   # 6 the throat only: darker than every cloud tone by value
	]
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = _shader(WATER_SHADER)
	var spout_sh := _shader(SPOUT_SHADER)
	_spout_mat = ShaderMaterial.new()
	_spout_mat.shader = spout_sh
	_spout_top_mat = ShaderMaterial.new()
	_spout_top_mat.shader = spout_sh
	for i in 7:
		_sp(StringName("r%d" % i), _ramp[i])
	_sp(&"foam", _pal.foam)
	_sp(&"foam_hi", _pal.foam_light)
	_spout_mat.set_shader_parameter(&"over", 0.0)
	_spout_top_mat.set_shader_parameter(&"over", 1.0)
	_water_mat.set_shader_parameter(&"deep", _pal.water_clean_deep)
	_water_mat.set_shader_parameter(&"chop", _pal.water_clean_shallow)
	_water_mat.set_shader_parameter(&"foam", _pal.foam)
	_water_mat.set_shader_parameter(&"foam_hi", _pal.foam_light)

	_water = _Quad.new()
	_water.material = _water_mat
	_water.z_as_relative = false
	_water.z_index = 3
	add_child(_water)
	_sky = _Canvas.new()
	_sky.painter = _paint_sky
	_sky.z_as_relative = false
	# The water's shadow layer, with the rubbish's own, the piers' and the hulls': under the
	# floating rubbish (5) and every walker (5, 7, 9). It was 7, over a walker behind the crate.
	_sky.z_index = 4
	add_child(_sky)
	_back = _Canvas.new()
	_back.painter = _paint_back
	add_child(_back)
	_spout = _Quad.new()
	_spout.material = _spout_mat
	add_child(_spout)
	_front = _Canvas.new()
	_front.painter = _paint_front
	add_child(_front)
	_cloud_layer = _Canvas.new()
	_cloud_layer.painter = _draw_cloud_painted
	_cloud_layer.z_as_relative = false
	_cloud_layer.z_index = 23
	add_child(_cloud_layer)
	# The column's part above the cloud's underside, drawn over the cloud's front lobes and
	# into the eye's throat (the same shader, the cells above `split_y`).
	_spout_top = _Quad.new()
	_spout_top.material = _spout_top_mat
	_spout_top.z_as_relative = false
	_spout_top.z_index = 24
	add_child(_spout_top)
	# Where the neck meets the cloud's underside, the lobes curl down onto its shoulders (over
	# the column's top half), so the cloud wraps the cone instead of the cone lying on the cloud.
	_collar = _Canvas.new()
	_collar.painter = _paint_collar
	_collar.z_as_relative = false
	_collar.z_index = 25
	add_child(_collar)
	# The front lip: a row of B's lobes round the south of the eye, over the column's top and
	# the collar, so the cone runs up behind a rounded rim of cloud and the join is never seen.
	_lip = _Canvas.new()
	_lip.painter = _draw_lip_painted
	_lip.z_as_relative = false
	_lip.z_index = 26
	add_child(_lip)
	_lay_puffs()


## A spout parameter, on both halves of the column.
func _sp(name: StringName, value: Variant) -> void:
	_spout_mat.set_shader_parameter(name, value)
	_spout_top_mat.set_shader_parameter(name, value)


func _shader(path: String) -> Shader:
	return load(path) as Shader


## The water shader's storm-cloud colour, read off the shader itself so it moves with a retune.
func _water_storm_ink() -> Color:
	var fallback := Color(0.2, 0.24, 0.31)
	var sh: Shader = load("res://shaders/water.gdshader")
	if sh == null:
		return fallback
	var v: Variant = RenderingServer.shader_get_parameter_default(sh.get_rid(), &"sky_storm_ink")
	if v is Color:
		return v
	if v is Vector4:
		var q: Vector4 = v
		return Color(q.x, q.y, q.z, 1.0)
	if v is Plane:
		var p: Plane = v
		return Color(p.x, p.y, p.z, 1.0)
	return fallback


## B's cloud, less its middle ring (the arms and the eye stand there now).
func _lay_puffs() -> void:
	var rings := [
		[0.5, 10, 0.27, 1.0, 0.32, -0.1, 0.45],
		[0.82, 16, 0.21, 0.6, 0.2, -0.15, 0.5],
		[1.1, 22, 0.15, 0.0, 0.12, -0.25, 0.45],
	]
	for rg: Array in rings:
		for k in int(rg[1]):
			var ring := float(rg[0]) * _rng.randf_range(0.9, 1.08)
			_cloud_puffs.append({
				"ang": TAU * float(k) / float(rg[1]) + _rng.randf_range(-0.25, 0.25),
				"ring": ring,
				"size": float(rg[2]) * _rng.randf_range(0.8, 1.15),
				"alpha": 1.0 if _rng.randf() < float(rg[3]) else REMNANT,
				"turn": float(rg[4]),
				"lift": _rng.randf_range(float(rg[5]), float(rg[6])),
				"born": _rng.randf_range(0.0, 0.6),
				"die": 0.55 * _rng.randf() + 0.45 * (1.0 - clampf(ring / 1.15, 0.0, 1.0)),
				"tower": false, "fringe": float(rg[0]) > 1.0, "seed": _cloud_puffs.size(),
			})
	for k in 9:
		var across := lerpf(-0.78, 0.78, float(k) / 8.0) + _rng.randf_range(-0.08, 0.08)
		_cloud_puffs.append({
			"across": across, "lift": lerpf(1.25, 0.8, absf(across)) + _rng.randf_range(0.0, 0.4),
			"size": _rng.randf_range(0.26, 0.34), "born": _rng.randf_range(0.2, 0.7),
			"alpha": 1.0 if absf(across) < 0.55 else REMNANT,
			"die": _rng.randf() * 0.5 + 0.2, "tower": true, "sway": _rng.randf() * TAU,
			"seed": _cloud_puffs.size(),
		})


# ======================================================================================
# The frame
# ======================================================================================

func tick(delta: float, s: Dictionary) -> void:
	_s = s
	_time = s["time"]
	var hits: int = s["hits"]
	var strength: float = s["strength"]
	if hits >= 3 and _collapse_at < 0.0:
		_collapse_at = _time - float(s["since_hit"])
	_cc = _time - _collapse_at if hits >= 3 else -1.0
	if _cc < 0.0:
		_size_s = lerpf(_size_s, strength, 1.0 - exp(-8.0 * delta))
		_size = lerpf(_size, float(s.get("size", 1.0)), 1.0 - exp(-8.0 * delta))
	_flare = float(s["hit_flash"])
	var closing := smoothstep(1.0, 2.0, _cc) if _cc >= 0.0 else 0.0
	# Counter-clockwise seen from above (2026-10-05): the angles run down, so the cloud's arms
	# and the eye's wall wind in towards the throat as they turn.
	_arm_rot -= delta * ARM_RATE * (1.0 + 2.2 * closing + 2.5 * _flare)
	_wall_rot -= delta * WALL_RATE * (1.0 + 1.5 * closing + 1.5 * _flare)
	var step := int(floorf(_time * FPS))
	if step != _step:
		_step = step
		_pt = float(step) / FPS
		_pat_spin = float(s["spin"]) * 0.7
		_arm_shown = _arm_rot
		_wall_shown = _wall_rot
	# The cloud leads along the base's way, eased; the foot drags.
	var v: Vector2 = s["velocity"]
	if v.length() > 170.0:
		v = v.normalized() * 170.0
	if _cc >= 0.0:
		v = Vector2.ZERO
	# Eased slower than the foot moves (2026-10-05: wobblier), so the top lags further.
	_lead = _lead.lerp(Vector2(v.x * 0.7, v.y * 0.35), 1.0 - exp(-1.15 * delta))
	# Zoomed out (the camera's scale on the canvas), everything that carries the eye's read is
	# drawn an art pixel bolder.
	_bold = 2 if get_viewport().get_canvas_transform().get_scale().x < 0.85 else 1
	_shape(s)
	_lay_cloud()
	_events(s)
	_hits_react(s)
	_tick_puffs(delta)
	_tick_chunks(delta, s)
	_push(s)
	_water.queue_redraw()
	_sky.queue_redraw()
	_back.queue_redraw()
	_spout.queue_redraw()
	_spout_top.queue_redraw()
	_front.queue_redraw()
	_collar.queue_redraw()
	_pump_paint()


## The rope's axis at height h (local): the foot trails, the belly lags, the top runs ahead
## into the cloud (A's S), with B's twist as it ropes out.
func _axis(h: float) -> Vector2:
	var g := clampf(h / maxf(_top_h, 1.0), 0.0, 1.0)
	var sm := g * g * (3.0 - 2.0 * g)
	var belly := sin(PI * g) * 0.55 * (1.0 - g)
	var x := _lead.x * (sm - belly)
	x += (sin(_time * 1.7 + g * 3.0) * 11.0 + sin(_time * 3.3 + g * 6.5) * 5.0) * g * _size
	x += sin(_time * 40.0) * 9.0 * _flare * g * (1.0 - g) * 2.0
	if _cc >= 0.0:
		var wig := 12.0 * smoothstep(0.05, 0.45, _cc) * (1.0 - smoothstep(1.1, 1.5, _cc))
		x += sin(g * 11.0 - _time * 9.0) * wig * sin(g * PI)
	return Vector2(x, -h + _lead.y * sm)


func _shape(s: Dictionary) -> void:
	var phase: String = s["phase"]
	var hits: int = s["hits"]
	var st := clampf(_size_s, 0.0, 1.0)
	if _cc < 0.0:
		var hs := 1.0 if phase == "touchdown" else st
		_top_h = TOP_H * _size * lerpf(0.84, 1.0, hs)
	_vis_lo = 0.0
	_vis_hi = _top_h
	_rope = 1.0
	_foot = 1.0
	_pinch = 0.0
	_lift = 0.0
	_pinch_h = _top_h * 0.36
	# Touchdown: the rope only comes down once the eye is open and turning.
	if phase == "touchdown":
		_vis_lo = _top_h * (1.0 - smoothstep(1.05, 1.55, _time))
		_foot = smoothstep(1.45, 1.95, _time)
	# A hit (and the first beat of the collapse): the waist pinches, the foot lifts off the
	# water and drops back, the rope lights two steps then one.
	var since: float = s["since_hit"]
	if hits > 0 and since < 0.5:
		var weak := _weak()
		_pinch = smoothstep(0.0, 0.06, since) * (1.0 - smoothstep(0.24, 0.46, since)) * weak
		_lift = 2.0 if since < 0.1 else (1.0 if since < 0.22 else 0.0)
		# Every hit reads, however weak: at least a beat two steps lighter and one more a step
		# lighter, and a pinch of at least half.
		_pinch = maxf(_pinch, 0.55 * smoothstep(0.0, 0.06, since) * (1.0 - smoothstep(0.24, 0.46, since)))
		_lift = 2.0 if since < 0.12 else (1.0 if since < 0.32 else 0.0)
		if hits < 3:
			_vis_lo = maxf(_vis_lo, _top_h * 0.13 * weak * smoothstep(0.0, 0.05, since) * (1.0 - smoothstep(0.1, 0.32, since)))

	if _cc >= 0.0:
		_rope = lerpf(1.0, 0.34, smoothstep(0.1, 0.5, _cc))
		_vis_lo = maxf(_vis_lo, _top_h * smoothstep(0.35, 1.2, _cc))
		_foot = 1.0 - smoothstep(0.3, 0.75, _cc)
	if float(s["flash"]) > 0.35:
		_lift = maxf(_lift, 1.0)
	_skirt_r = SKIRT_R * _size * lerpf(0.7, 1.0, st) * maxf(_foot, 0.3)

	# The eye, which the column's top flares out to meet. Its opening and shutting are read off
	# the stepped clock, so the hole grows and shrinks a beat at a time (5-6 beats each way).
	_eye_rx = EYE_RX * _size * lerpf(0.72, 1.0, st) * (1.0 + 0.3 * _flare)
	var ts := _pt
	var ccs := _pt - _collapse_at if _cc >= 0.0 else -1.0
	_vx = 1.0
	_eye_open = 1.0
	_lip_lo = 1.0
	_lip_hi = VORTEX_OUT
	if phase == "touchdown":
		# The arms wind in over the gathering cloud into a knot, then the eye opens out of the
		# knot and the lit lips run outwards along the arms as it does.
		_eye_rx = EYE_RX * _size * lerpf(0.8, 1.0, st)
		_vx = smoothstep(0.4, 0.8, ts)
		_eye_open = smoothstep(0.6, 1.3, ts)
		_lip_hi = lerpf(1.0, VORTEX_OUT, smoothstep(0.65, 1.4, ts))
	elif ccs >= 0.0:
		# The rope is gone into the throat by 1.2; the eye spirals shut over the next 0.6 s,
		# the lips going from the inside out, then the knot lets go into plain puffs.
		_eye_open = 1.0 - smoothstep(1.0, 1.6, ccs)
		_lip_lo = lerpf(1.0, VORTEX_OUT, smoothstep(0.95, 1.6, ccs))
		_vx = 1.0 - smoothstep(1.55, 1.95, ccs)

	var radius_at: Callable = s["radius_at"]
	var hs2: float = float(s["height"]) * float(s["strength"])
	var scale := lerpf(0.55, 1.0, st) * _size
	# A funnel: it widens steadily all the way up to a neck the throat can swallow (not the
	# eye's whole width), and never narrows again on the way up.
	var neck_r := clampf(_eye_rx * maxf(_eye_open, 0.4) * 0.55, 12.0 * _size, 36.0 * scale)
	var foot_r := 6.0 * scale
	var widest := 0.0
	_prof.resize(N)
	for i in N:
		var h := float(i) / float(N - 1) * _top_h
		var at := _axis(h)
		var g := h / _top_h
		var r := lerpf(foot_r, neck_r, pow(g, 1.25))
		if hs2 > 4.0 and h <= hs2 * 0.8 and _cc < 0.0:
			r = minf(r, float(radius_at.call(h / hs2)) * SHEATH)
		r = maxf(r, widest)
		widest = r
		_prof[i] = Vector3(at.x, at.y, r * _rope)
	var top := _axis(_top_h)
	var wob := Vector2(sin(_time * 34.0) * 3.0 * _flare, 0.0)
	_eye_c = top - Vector2(0.0, THROAT_DOWN * _eye_rx * EYE_FLAT) + wob


## The column's point and radius at height `h` (local), from this frame's profile.
func _prof_at(h: float) -> Vector3:
	if _prof.is_empty():
		return Vector3(0.0, -h, 4.0)
	var f := clampf(h / maxf(_top_h, 1.0), 0.0, 1.0) * float(N - 1)
	var i := mini(int(f), N - 2)
	return _prof[i].lerp(_prof[i + 1], f - float(i))


## Where every lobe of the cloud is this frame (B's rings and towers, and the arms).
func _lay_cloud() -> void:
	var touch: bool = _s["phase"] == "touchdown"
	_cloud_amt = smoothstep(0.0, 0.8, _time) if touch else 1.0
	_dissolve = 0.0
	_cloud_up = 0.0
	if _cc >= 0.0:
		# The rim starts going while the knot is still letting go, so there is no still beat
		# between the eye shutting and the break-up.
		_dissolve = clampf((_cc - BREAK_FROM) / BREAK_LONG, 0.0, 1.0)
		_cloud_up = CLOUD_RISE * smoothstep(BREAK_FROM, BREAK_FROM + BREAK_LONG, _cc)
	var st := clampf(_size_s, 0.0, 1.0)
	_cloud_rx = CLOUD_RX * _size * lerpf(0.84, 1.0, st) * lerpf(0.5, 1.0, _cloud_amt) * (1.0 + 0.15 * _dissolve)
	var isle: Vector2 = (get_parent() as Node2D).global_transform * Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)
	var way: Vector2 = global_position - isle
	_away = way.normalized() if way.length() > 1.0 else Vector2.RIGHT
	var ry := _cloud_rx * CLOUD_FLAT
	var drift := Vector2(sin(_time * 0.37) * 5.0, sin(_time * 0.29) * 2.0)
	# The eye sits in the cloud's middle (a touch below it), so a ring of B's lobes stands in
	# front of it and the eye's front lip is cloud, not the cloud's edge.
	var off_way := Vector2.ZERO
	if _cc >= 0.0:
		off_way = _away * 60.0 * smoothstep(BREAK_FROM, BREAK_FROM + BREAK_LONG, _cc)
	_cloud_c = _eye_c + Vector2(0.0, 0.18 * ry - _cloud_up) + drift + off_way
	var eye_c := _eye_c - Vector2(0.0, _cloud_up)
	_lobes.clear()
	for p: Dictionary in _cloud_puffs:
		var born: float = p["born"]
		var grow := smoothstep(born, born + 0.55, _time * 1.05) if touch else 1.0
		if grow <= 0.12:
			continue
		var a: float = p["alpha"]
		# A lobe condensing is thin and pale first (vapour at the cloud's height), then fills.
		var lite := 2 if grow < 0.55 else (1 if grow < 0.8 else 0)
		if grow < 0.55:
			a = REMNANT
		var eat := clampf((_dissolve - float(p["die"]) * DIE_SPREAD) / EAT_WINDOW, 0.0, 1.0)
		if eat >= 1.0:
			continue
		var sd: int = p["seed"]
		if bool(p["tower"]):
			var sway := sin(_pt * 0.4 + float(p["sway"])) * 0.03
			_lobes.append({
				"at": _cloud_c + Vector2((float(p["across"]) + sway) * _cloud_rx, -float(p["lift"]) * ry),
				"r": float(p["size"]) * _cloud_rx * grow, "depth": -2.0 - float(p["lift"]) * 0.1,
				"tone": 4 - lite, "rim": float(p["across"]) > 0.0, "alpha": a, "eat": eat, "seed": sd, "flat": 0.62,
				"wisp": grow < 0.55,
			})
			continue
		var ang: float = float(p["ang"]) - _pt * float(p["turn"])
		var ring: float = float(p["ring"]) * (1.0 + 0.12 * _dissolve)
		var depth := sin(ang) * ring
		var fringe: bool = p["fringe"]
		if fringe and sin(ang) > 0.15:
			continue
		var tone := 3
		if depth > 0.35 or fringe:
			tone = 4
		var dy := sin(ang) * ry * ring
		if dy > 0.0:
			dy *= 0.55
		# The front row hangs unevenly (B's scalloped base): each lobe there drops and swells by
		# its own roll, so the underside breaks into bumps rather than running level.
		var fr := clampf((sin(ang) - 0.2) / 0.6, 0.0, 1.0) * (0.0 if fringe else 1.0)
		dy += fr * (_h2(sd, 41, 5) - 0.3) * ry * 0.8
		var swell := 1.0 + fr * (_h2(sd, 42, 5) - 0.45) * 0.5
		_lobes.append({
			"at": _cloud_c + Vector2(cos(ang) * _cloud_rx * ring, dy - float(p["lift"]) * ry),
			"r": float(p["size"]) * _cloud_rx * grow * swell, "depth": depth, "tone": tone - lite,
			"rim": cos(ang) * ring > 0.1 and depth < 0.35 and not fringe,
			"alpha": a, "eat": eat, "seed": sd, "flat": 0.45 if fringe else 0.62, "wisp": grow < 0.55,
		})
	# The inner puffs round the eye, turning with the arms (the vortex pass winds them into
	# arms and grooves), and one over the middle that the eye's hole is cut through: with the
	# eye shut (touchdown's start, the vanish) it is the knot the arms wind into.
	for k in INNER + 1:
		var sd := 500 + k * 17
		var centre := k == INNER
		var ang := float(k) * TAU / float(INNER) + _arm_shown + (_h2(sd, 1, 7) - 0.5) * 0.3
		var rr := 0.0 if centre else _eye_rx * lerpf(1.25, 1.5, _h2(sd, 2, 7))
		var at := eye_c + Vector2(cos(ang) * rr, sin(ang) * rr * 0.42 - (6.0 if centre else _h2(sd, 3, 7) * 10.0))
		var size := (0.21 if centre else 0.2 * lerpf(0.85, 1.15, _h2(sd, 4, 7))) * _cloud_rx
		var grow := 1.0
		if touch:
			var born := 0.15 + 0.3 * _h2(sd, 5, 7)
			grow = smoothstep(born, born + 0.5, _time)
			if grow <= 0.12:
				continue
		var a := 1.0 if grow >= 0.5 else REMNANT
		var lite := 2 if grow < 0.55 else (1 if grow < 0.8 else 0)
		# The knot goes last: the rim of the cloud first, the middle after.
		var die := 0.45 + 0.4 * _h2(sd, 6, 7)
		if centre:
			die = 0.9
		var eat := clampf((_dissolve - die * DIE_SPREAD) / EAT_WINDOW, 0.0, 1.0)
		if eat >= 1.0:
			continue
		_lobes.append({
			"at": at, "r": size * grow, "depth": (sin(ang) * rr / _cloud_rx) if not centre else -0.05,
			"tone": 3 - lite, "rim": true, "alpha": a, "eat": eat, "seed": sd, "flat": 0.55,
			"wisp": grow < 0.55,
		})
	_lay_lip(eye_c, touch)
	# Where the column goes over the cloud: just under the lowest lobe standing over its neck,
	# so from there up the rope is drawn over the front lobes into the throat.
	var neck := _prof_at(_top_h)
	var low := -INF
	for lb: Dictionary in _lobes:
		if lb.get("wisp", false) or float(lb["eat"]) > 0.3:
			continue
		var lat: Vector2 = lb["at"]
		var lr: float = lb["r"]
		# Any lobe whose drawing overlaps the neck's width at all: the rope must be over every
		# lobe it crosses, or a lobe's edge shows across it.
		if absf(lat.x - neck.x) > lr + neck.z:
			continue
		low = maxf(low, lat.y + lr * float(lb["flat"]))
	if low == -INF or _cc >= 1.25:
		_split_y = -100000.0
	else:
		_split_y = floorf((global_position.y + low + ART * 2.0) / ART) * ART


## The front lip is not a layer of its own: it is a ring of B's lobes turning round the eye with
## the arms (the same spin the inner puffs ride). Whichever of them the turn has carried to the
## near (south) side is drawn in front of the cone's join; a lobe swells in as it comes round the
## flank and shrinks away as it goes behind, so the rim is always the cloud turning past.
const LIP_N := 17
const LIP_SPREAD := 1.3    # the ring's radius across, in eye radii
const LIP_DEEP := 0.95     # and down, in eye ry
const LIP_SIZE := 0.15     # of the cloud's radius
const LIP_FROM := 0.12     # sin(angle) where a lobe starts to come round in front
const LIP_FULL := 0.55
const LIP_LOW := 11


func _lay_lip(eye_c: Vector2, touch: bool) -> void:
	_lip_lobes.clear()
	var rx := _eye_rx
	var ry := rx * EYE_FLAT
	# Two rows: the rim round the eye, and a lower, slower row filling the cloud's near
	# underside so the south of the cloud is the fullest part of it.
	for k in LIP_N + LIP_LOW:
		var sd := 900 + k * 23
		var low := k >= LIP_N
		var kk := k - LIP_N if low else k
		var nn := LIP_LOW if low else LIP_N
		var ang := float(kk) * TAU / float(nn) + _arm_shown * (0.75 if low else 1.0) + (_h2(sd, 1, 7) - 0.5) * 0.25
		var near := sin(ang)
		var come := smoothstep(LIP_FROM, LIP_FULL, near)
		if come <= 0.0:
			continue
		var ring := lerpf(0.95, 1.08, _h2(sd, 3, 7)) * (1.45 if low else 1.0)
		var at := eye_c + Vector2(cos(ang) * rx * LIP_SPREAD * ring,
			near * ry * LIP_DEEP * ring * (1.25 if low else 1.0) + (_h2(sd, 4, 7) - 0.5) * 4.0)
		var size := LIP_SIZE * (1.1 if low else 1.0) * _cloud_rx * lerpf(0.88, 1.12, _h2(sd, 2, 7)) * lerpf(0.45, 1.0, come)
		var grow := 1.0
		if touch:
			var born := 0.25 + 0.3 * _h2(sd, 5, 7)
			grow = smoothstep(born, born + 0.5, _time)
			if grow <= 0.12:
				continue
		var a := 1.0 if grow >= 0.5 else REMNANT
		var lite := 2 if grow < 0.55 else (1 if grow < 0.8 else 0)
		var die := 0.3 + 0.45 * _h2(sd, 6, 7)
		var eat := clampf((_dissolve - die * DIE_SPREAD) / EAT_WINDOW, 0.0, 1.0)
		if eat >= 1.0:
			continue
		_lip_lobes.append({
			"at": at, "r": size * grow, "depth": near + (0.5 if low else 0.0), "tone": (4 if low else 3) - lite, "rim": cos(ang) > -0.2,
			"alpha": a, "eat": eat, "seed": sd, "flat": 0.6, "wisp": grow < 0.55,
		})
	_lip_lobes.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["depth"]) < float(y["depth"]))



# ======================================================================================
# The cloud and the lip, painted off the main thread (the port's one change to the drawing)
# ======================================================================================
#
# Painting the cloud cell by cell is ~45 ms of GDScript a frame, which the mock could afford
# (it filmed at a fixed step) and the game cannot. So the same painters (`_paint_cloud`'s and
# `_paint_lip`'s cells, unchanged) run on a WorkerThreadPool task, on a second instance of this
# script (`_painter`) holding a copy of this frame's shape, into triangle arrays. The finished
# cells are drawn in one call and shifted by whole art pixels to follow the base until the
# next paint lands, a frame or three later. What is drawn is exactly what the painters paint,
# a few frames late; the pattern clock it paints on is the look's own 8 fps one.

var _painter: Node2D
var _paint_task := -1
## The finished cloud and lip: [points, colours, indices], points relative to `_painted_at`.
var _cloud_tris: Array = []
var _lip_tris: Array = []
var _painted_at := Vector2.ZERO
var _paint_origin := Vector2.ZERO
## Set on the painter: what it painted.
var _out_cloud: Array = []
var _out_lip: Array = []


func _exit_tree() -> void:
	if _paint_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_paint_task)
		_paint_task = -1
	if _painter != null:
		_painter.free()
		_painter = null


## Once a tick: land a finished paint, start the next one, and keep the drawn cells on the
## base's world grid.
func _pump_paint() -> void:
	if _paint_task >= 0 and WorkerThreadPool.is_task_completed(_paint_task):
		WorkerThreadPool.wait_for_task_completion(_paint_task)
		_paint_task = -1
		_cloud_tris = _painter._out_cloud
		_lip_tris = _painter._out_lip
		_blobs = _painter._blobs.duplicate()
		_painted_at = _paint_origin
		_cloud_layer.queue_redraw()
		_lip.queue_redraw()
	if _paint_task < 0:
		if _painter == null:
			_painter = (get_script() as GDScript).new()
		_painter._s = {
			"flash": _s.get("flash", 0.0), "hits": _s.get("hits", 0), "since_hit": _s.get("since_hit", 99.0),
			"weak": _weak(),
		}
		_painter._lobes = _lobes.duplicate(true)
		_painter._lip_lobes = _lip_lobes.duplicate(true)
		for key: StringName in [&"_cloud_c", &"_away", &"_eye_rx", &"_eye_c", &"_cloud_up", &"_vx",
				&"_eye_open", &"_arm_shown", &"_wall_shown", &"_bold", &"_lip_lo", &"_lip_hi", &"_ramp",
				&"_time", &"_pt", &"_size"]:
			_painter.set(key, get(key))
		_paint_origin = global_position
		_painter._paint_origin = _paint_origin
		_paint_task = WorkerThreadPool.add_task(_painter._paint_off_thread, false, "tornado cloud")
	var d := global_position - _painted_at
	var snapped := (d / ART).round() * ART
	_blob_shift = snapped
	_cloud_layer.position = snapped - d
	_lip.position = snapped - d


## On the worker, on the painter: both buffers, as triangles.
func _paint_off_thread() -> void:
	var flash: float = _s.get("flash", 0.0)
	var up := 1 if flash > 0.35 else 0
	var origin := _paint_origin
	var buf := {}
	_blobs.clear()
	_lobes.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["depth"]) < float(y["depth"]))
	for lb: Dictionary in _lobes:
		_paint_dissolving(buf, origin, lb, int(lb["tone"]) - up)
	_paint_vortex(buf, origin, up)
	_out_cloud = _buffer_tris(buf, origin)
	var lip := {}
	for lb: Dictionary in _lip_lobes:
		_paint_dissolving(lip, origin, lb, int(lb["tone"]) - up)
	_out_lip = _buffer_tris(lip, origin)


## `_draw_buffer`'s runs, as one triangle array: [points, colours, indices].
func _buffer_tris(buf: Dictionary, origin: Vector2) -> Array:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	if buf.is_empty():
		return [pts, cols, idx]
	var rows := {}
	for cell: Vector2i in buf:
		if not rows.has(cell.y):
			rows[cell.y] = []
		(rows[cell.y] as Array).append(cell.x)
	var ys := rows.keys()
	ys.sort()
	for cy: int in ys:
		var xs: Array = rows[cy]
		xs.sort()
		var start: int = xs[0]
		var was: Vector2 = buf[Vector2i(start, cy)]
		var last := start
		for n in range(1, xs.size() + 1):
			var x: int = xs[n] if n < xs.size() else -999999
			var v: Vector2 = buf[Vector2i(x, cy)] if n < xs.size() else Vector2(-1, -1)
			if x == last + 1 and v == was:
				last = x
				continue
			var x0 := float(start) * ART - origin.x
			var y0 := float(cy) * ART - origin.y
			var x1 := x0 + float(last - start + 1) * ART
			var y1 := y0 + ART
			var base := pts.size()
			pts.append_array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
			var c := _shade(int(was.x), was.y)
			cols.append_array([c, c, c, c])
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
			start = x
			last = x
			was = v
	return [pts, cols, idx]


func _draw_tris(on: Node2D, tris: Array) -> void:
	if tris.size() < 3 or (tris[2] as PackedInt32Array).is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(on.get_canvas_item(), tris[2], tris[0], tris[1])


func _draw_cloud_painted(on: Node2D) -> void:
	_draw_tris(on, _cloud_tris)


func _draw_lip_painted(on: Node2D) -> void:
	_draw_tris(on, _lip_tris)


## One-off water: the touchdown's slap, the foot leaving the water in the vanish.
func _events(s: Dictionary) -> void:
	var base: Vector2 = s["base"]
	if not _touched and _vis_lo < 8.0 and _time > 0.5 and _time < 3.0:
		_touched = true
		_splash.splash(base, 0.8, true)
		_splash.ripple(base, 30.0)
		_splash.ripple(base, 16.0)
	if not _foot_left and _cc >= 0.75:
		_foot_left = true
		_splash.ripple(base, 36.0)
		_splash.ripple(base, 20.0)


## A hit's burst off the waist is one ring (`_paint_waist_ring`); the flat vapour smears B threw
## here stacked at several heights round the column and read as a ladder of slabs, so they are
## gone. Only the count is kept.
func _hits_react(s: Dictionary) -> void:
	_hits_seen = s["hits"]


## How hard this hit lands, 1 for the first down to 0.65 for the last (the tornado hands it
## over, since how many hits there are differs from one tornado to the next); the mock's
## three-hit rule when it does not.
func _weak() -> float:
	if _s.has("weak"):
		return float(_s["weak"])
	var hits: int = _s.get("hits", 0)
	return 1.0 if hits == 1 else (0.8 if hits == 2 else 0.65)



func _tick_puffs(delta: float) -> void:
	var i := 0
	while i < _puffs.size():
		var p: Dictionary = _puffs[i]
		p["age"] = float(p["age"]) + delta
		if float(p["age"]) >= float(p["life"]):
			_puffs.remove_at(i)
			continue
		var v: Vector2 = p["vel"]
		p["at"] = (p["at"] as Vector2) + v * delta
		if not p.get("rise", false):
			p["vel"] = v * exp(-2.2 * delta) + Vector2(0.0, -6.0 * delta)
		p["size"] = float(p["size"]) + float(p["grow"]) * delta
		i += 1


## Spray thrown off the foot: a burst when a hit jolts it, and one when the foot leaves the
## water in the vanish. Only ever at the foot's ring (never along the rope's old length), single
## art pixels under gravity, spreading sideways, gone within about 0.35 s in two alpha steps.
func _burst(n: int, power: float) -> void:
	var foot := _prof_at(0.0)
	for k in n:
		var th := TAU * float(k) / float(n) + _rng.randf_range(-0.2, 0.2)
		var r := maxf(foot.z, 6.0) * _rng.randf_range(0.9, 1.4)
		var out := Vector2(cos(th), sin(th) * 0.5)
		_chunks.append({
			"at": Vector2(foot.x, 0.0) + out * r,
			"vel": out * _rng.randf_range(60.0, 130.0) * power + Vector2(0.0, -_rng.randf_range(90.0, 170.0) * power),
			"h": _rng.randf_range(2.0, 8.0), "age": 0.0, "life": _rng.randf_range(0.26, 0.36),
			"front": sin(th) > 0.0, "ring": _rng.randf() < 0.15,
		})


func _tick_chunks(delta: float, s: Dictionary) -> void:
	var base: Vector2 = s["base"]
	var hits: int = s["hits"]
	var hit_no: int = s.get("hit_no", hits)
	if hit_no > _burst_hits:
		_burst_hits = hit_no
		var weak := _weak()
		_burst(int(18.0 * weak), weak)
	if _cc >= 0.75 and not _burst_left:
		_burst_left = true
		_burst(14, 0.8)
	var i := 0
	while i < _chunks.size():
		var c: Dictionary = _chunks[i]
		c["age"] = float(c["age"]) + delta
		var vel: Vector2 = c["vel"]
		vel.y += 420.0 * delta
		c["vel"] = vel
		var at: Vector2 = c["at"]
		at += vel * delta
		c["at"] = at
		c["h"] = float(c["h"]) - vel.y * delta
		if float(c["h"]) <= 0.0 or float(c["age"]) >= float(c["life"]):
			if c["ring"] and float(c["h"]) <= 0.0:
				_splash.ripple(base + Vector2(at.x, at.y + float(c["h"])), 5.0)
			_chunks.remove_at(i)
			continue
		i += 1


func _push(s: Dictionary) -> void:
	var strength: float = s["strength"]
	var hits: int = s["hits"]
	var since_hit: float = s["since_hit"]
	var gpos := global_position
	var st := clampf(_size_s, 0.0, 1.0)
	_sp(&"base", gpos)
	_sp(&"prof", _prof)
	_sp(&"top_h", _top_h)
	_sp(&"vis_lo", _vis_lo)
	_sp(&"vis_hi", _vis_hi)
	_sp(&"pat_t", _pt)
	_sp(&"spin", _pat_spin)
	_sp(&"lift", _lift)
	_sp(&"pinch_h", _pinch_h)
	_sp(&"pinch", _pinch)
	_sp(&"split_y", _split_y)
	_sp(&"bold", float(_bold))

	var sz := lerpf(0.6, 1.0, st) * _foot * _size
	_sp(&"mound_r", 26.0 * sz)
	_sp(&"mound_h", 30.0 * sz)
	var lo := Vector2(-40.0, -_top_h - 12.0)
	var hi := Vector2(40.0, 14.0)
	for v: Vector3 in _prof:
		lo.x = minf(lo.x, v.x - v.z * 1.4 - 10.0)
		hi.x = maxf(hi.x, v.x + v.z * 1.4 + 10.0)
		lo.y = minf(lo.y, v.y - 6.0)
	_spout.rect = Rect2(lo, hi - lo)
	_spout_top.rect = _spout.rect

	var ring_keep := 1.0
	if s["phase"] == "touchdown":
		ring_keep = smoothstep(1.4, 2.0, _time)
	if _cc >= 0.0:
		ring_keep = 1.0 - smoothstep(0.5, 1.8, _cc)
	var spread_keep := 0.0
	var spread_r := 0.0
	if _cc >= 0.55:
		# A's spray ring, the skirt collapsing into it: out to 1.3 times the disturbed ring at
		# most, and a step thinner every beat until it is gone.
		var sc := floorf((_cc - 0.55) * FPS) / FPS
		spread_r = lerpf(SKIRT_R * _size, RING_R * _size * 1.3, 1.0 - pow(1.0 - clampf(sc / 1.6, 0.0, 1.0), 2.0))
		spread_keep = clampf(1.0 - sc * FPS / 12.0, 0.0, 1.0)
	var burst_keep := 0.0
	var burst_r := 0.0
	if hits > 0 and since_hit < 0.8:
		var weak := _weak()
		burst_r = minf(SKIRT_R * _size * (0.9 + since_hit * 5.0 * weak), RING_R * _size * 1.1)
		burst_keep = (1.0 - since_hit / 0.8) * weak
	_water_mat.set_shader_parameter(&"base", gpos)
	_water_mat.set_shader_parameter(&"pat_t", _pt)
	_water_mat.set_shader_parameter(&"spin", _pat_spin)
	_water_mat.set_shader_parameter(&"skirt_r", _skirt_r)
	_water_mat.set_shader_parameter(&"skirt_keep", _foot)
	_water_mat.set_shader_parameter(&"ring_r", RING_R * _size * lerpf(0.75, 1.0, strength if _cc < 0.0 else 0.6))
	_water_mat.set_shader_parameter(&"ring_keep", ring_keep)
	_water_mat.set_shader_parameter(&"burst_r", burst_r)
	_water_mat.set_shader_parameter(&"burst_keep", burst_keep)
	_water_mat.set_shader_parameter(&"spread_r", spread_r)
	_water_mat.set_shader_parameter(&"spread_keep", spread_keep)
	var reach := maxf(maxf(RING_R * _size * 1.3, spread_r * 1.25 + 20.0), burst_r * 1.25 + 20.0)
	_water.rect = Rect2(Vector2(-reach, -reach * 0.5 - 8.0), Vector2(reach * 2.0, reach + 16.0))


# ======================================================================================
# Noise (a hash, never the global RNG: the harness's splash rolls must not move)
# ======================================================================================

static func _hash(n: int) -> float:
	n = n & 0xffffffff
	n = (n ^ 61) ^ (n >> 16)
	n = (n + (n << 3)) & 0xffffffff
	n = n ^ (n >> 4)
	n = (n * 0x27d4eb2d) & 0xffffffff
	n = n ^ (n >> 15)
	return float(n & 0xffffff) / 16777215.0


static func _h2(i: int, j: int, k: int = 0) -> float:
	return _hash(i * 73856093 ^ j * 19349663 ^ k * 83492791)


static func _n1(x: float, sd: int) -> float:
	var i := floori(x)
	var f := x - float(i)
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_h2(i, sd), _h2(i + 1, sd), f)


static func _np(x: float, period: int, sd: int) -> float:
	var i := floori(x)
	var f := x - float(i)
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_h2(posmod(i, period), sd), _h2(posmod(i + 1, period), sd), f)


func _fhash(a: float, b: float) -> float:
	var h := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return h - floorf(h)


func _shade(idx: int, alpha: float) -> Color:
	var c := _ramp[clampi(idx, 0, _ramp.size() - 1)]
	return Color(c.r, c.g, c.b, alpha)


# ======================================================================================
# The cloud (z 23)
# ======================================================================================



## A lobe that is still whole, being bitten away, or broken into small puffs drifting apart.
func _paint_dissolving(buf: Dictionary, origin: Vector2, lb: Dictionary, tone: int) -> void:
	var eat: float = lb["eat"]
	var wc: Vector2 = origin + (lb["at"] as Vector2)
	var lr: float = floorf(float(lb["r"]) / ART) * ART
	var sd: int = lb["seed"]
	var a: float = lb["alpha"]
	var flat: float = lb["flat"]
	if lb.get("wisp", false):
		# Condensing: a thin smear of the storm's own greys at the remnant step, inside the
		# lobe it will become (never pale, which read as slabs lying on the water).
		_paint_vapour(buf, wc, lr, REMNANT, 1.0, sd * 7, -1)
		return
	if eat < 0.35:
		_blobs.append(Vector3(wc.x, wc.y, lr * (1.0 - 0.5 * eat)))
	if eat < 0.35:
		# Bitten from the edge in lumps, still whole cloud (crest, underside, seam), and a step
		# lighter once it is thinning (a thinning cloud lets the light through).
		if eat > 0.18:
			tone -= 1
		_paint_lobe(buf, wc, lr, tone, a, lb["rim"], flat, eat * 1.6, sd)
		return
	# Broken up: two or three small puffs, rolled per lobe, drifting apart outward from the
	# cloud's middle and up with it (never down onto the lake), each still painted as a lobe of
	# cloud (lit crescent, shaded under, torn edge) and shrinking by whole art pixels. Only the
	# last few sizes go to the remnant step, and a step paler, so the end of a puff is vapour
	# thinning out, not a shadow on the water.
	var u := (eat - 0.35) / 0.65
	var n := 2 + int(_h2(sd, 11, 3) * 2.0)
	var from: Vector2 = (lb["at"] as Vector2) - _cloud_c
	# They part along the way away from the island, never back over it.
	var out_x := signf(_away.x) if absf(_away.x) > 0.05 else 1.0
	# The whole cloud is still turning (clockwise seen from above): the far half of it drifts
	# right, the near half left, so the rags are carried round the way the storm went.
	var carry := 1.0 if from.y < 0.0 else -1.0
	# And the wind takes what is left off the way it was going, away from the island, so no
	# rag of it hangs over the grass.
	var away := _away * u * lr * 2.2
	for k in n:
		# The pieces part sideways and rise; they never sink below the lobe they came from, so the
		# cloud breaks up in the sky and nothing lands on the lake or the island.
		var side := out_x * (0.35 + 0.65 * _h2(sd, 20 + k, 3)) * (1.0 if k % 2 == 0 else 0.3)
		var off := Vector2(side * lr * (0.15 + 0.5 * u),
			-lr * 0.12 * float(k) - 18.0 * u - 6.0 * _h2(sd, 30 + k, 3) * u) + away
		var r := floorf(lr * (0.58 - 0.12 * float(k)) * pow(1.0 - u, 0.6) / ART) * ART
		if r < ART * 2.0:
			continue
		var at := wc + off
		if u < 0.4 and r >= maxf(ART * 5.0, lr / 3.0):
			# Still a lump of cloud (crest, underside, seam, torn edge), a step lighter: thinning
			# cloud lets the light through. It throws its own shadow down-left on the lake.
			_paint_lobe(buf, at, r, 2, a, true, flat * lerpf(0.9, 0.75, u / 0.4), 0.15 + 0.3 * u, sd + k * 31)
			if u < 0.25:
				_blobs.append(Vector3(at.x, at.y, r))
		else:
			# The last of it: a thin smear of the storm's greys at the remnant step (no dark
			# underside, nothing pale), sheared along its drift, then gone.
			_paint_vapour(buf, at, r * 1.2, REMNANT, -carry, sd * 7 + k, 0)


## One lobe of cloud painted into `buf` (cell -> (ramp index, alpha)) (B's): lit on a crescent
## along its top (a rim of the highlight on the sunny right when `rim`), shaded along its
## underside, its lower-left the seam where it sits on the lobe behind. Remnant never thins an
## opaque pixel.
func _paint_lobe(buf: Dictionary, wc: Vector2, lr: float, tone: int, a: float, rim: bool, flat: float,
		eat: float = 0.0, sd: int = 0) -> void:
	# Nothing under two art pixels is drawn: a lone cell reads as a stray pixel, not a puff.
	if lr < ART * 2.0:
		return
	var lry := lr * flat
	for cy in range(int(floor((wc.y - lry) / ART)), int(floor((wc.y + lry) / ART)) + 1):
		var yy := (float(cy) + 0.5) * ART - wc.y
		var f := 1.0 - (yy * yy) / (lry * lry)
		if f <= 0.0:
			continue
		var half := lr * sqrt(f) + (_h2(cy - int(floor(wc.y / ART)), int(lr * 3.0), 141) - 0.5) * ART * 1.6
		var il := int(roundf((wc.x - half) / ART))
		var ir := int(roundf((wc.x + half) / ART)) - 1
		for i in range(il, ir + 1):
			var xx := (float(i) + 0.5) * ART - wc.x
			var dn := Vector2(xx / lr, yy / lry)
			var d := dn.length()
			if eat > 0.0:
				# Bitten: the edge comes in by lumps, and the shading is measured to the bitten
				# edge, so what is left keeps its lit crescent and its shaded underside.
				var bite := _np(atan2(dn.y, dn.x) * 5.0 / TAU + float(sd) * 0.37, 5, 150 + sd)
				var keep := 1.0 - eat * (0.55 + 0.6 * bite)
				if d > keep:
					continue
				dn /= maxf(keep, 0.2)
				d = dn.length()
			var ci := tone
			if dn.y < -0.3 and d > (0.6 if rim else 0.74) and dn.x > -0.55:
				ci = tone - 1
				if rim and dn.x > 0.15 and d > 0.84:
					ci = tone - 2
			elif dn.y > 0.28 and d > 0.5:
				ci = tone + 1
			if dn.x < -0.5 and dn.y > -0.05 and d > 0.78:
				ci = tone + 2
			# The throat's swatch is the eye's alone: a lobe's seam stops at the wall's.
			ci = clampi(ci, 0, 5)

			var cell := Vector2i(i, cy)
			if a < 1.0 and buf.has(cell) and (buf[cell] as Vector2).y >= 1.0:
				continue
			buf[cell] = Vector2(ci, a)


## The sun's way on the screen (right and a little up): the lit lips are the arm edges facing it.
const LIGHT := Vector2(0.857, -0.514)


## What a point of the vortex is (offsets from the eye's middle, world px), as
## (kind + 10 * arm, px to the arm's nearer edge, how much that edge faces the sun, radius):
## kind 2 the eye's hole, 1 an arm, 0 a groove between arms, -1 outside the vortex. The arms
## are log spirals in the cloud's plane, the plane easing from the eye's 2:1 to the cloud's
## flatter shelf going out; their edges are scalloped (the puffs they are wound from), and the
## hole's rim steps in at every arm, a pinwheel. The edge distance and facing come off the
## spiral's own gradient, so a lip is a solid run along the edge, not a staircase of dashes.
func _vortex_at(dx: float, dy: float, out: float, hole_on: bool) -> Vector4:
	var rx := maxf(_eye_rx, 1.0)
	var r0 := Vector2(dx, dy / EYE_FLAT).length() / rx
	var t := clampf((r0 - 1.0) / (VORTEX_OUT - 1.0), 0.0, 1.0)
	var flat := lerpf(EYE_FLAT, CLOUD_FLAT + 0.1, t)
	var q := Vector2(dx, dy / flat) / rx
	var rr := q.length()
	var th := atan2(q.y, q.x)
	var sector := TAU / float(ARMS)
	var wound := (th - _arm_shown) / sector + WIND * log(maxf(rr, 0.05))
	var ph := fposmod(wound, 1.0)
	var hole_r := _eye_open * (0.8 + 0.3 * fposmod(ph + 0.35, 1.0))
	if hole_on and rr < hole_r:
		return Vector4(2.0, 0.0, 0.0, rr)
	# The lip of the hole, where the cloud turns over and down into it (+100).
	var rim := 100.0 if (hole_on and rr < hole_r + 0.15) else 0.0
	if rr > out * (0.84 + 0.3 * _np(th * 5.0 / TAU, 5, 181)):
		return Vector4(-1.0, 0.0, 0.0, rr)
	var arm := posmod(floori(wound), ARMS)
	var bump := _n1(rr * 3.0 + float(arm) * 5.0, 177) * 0.6 + _n1(rr * 6.5 + float(arm) * 3.0, 179) * 0.4
	var w := lerpf(0.5, 0.36, t) * (0.65 + 0.7 * bump)
	# Shut (and before it opens) the arms crowd in over the grooves into a knot.
	w += (1.0 - _eye_open) * 0.5 * (1.0 - t)
	if ph >= w:
		return Vector4(rim + 10.0 * float(arm), 0.0, 0.0, rr)
	var r2 := maxf(rr * rr, 0.0025)
	var gq := (Vector2(-q.y, q.x) / sector + WIND * q) / r2
	var gs := Vector2(gq.x / rx, gq.y / (flat * rx))
	var gl := maxf(gs.length(), 0.0001)
	var nrm := gs / gl
	var d_trail := (w - ph) / gl
	var d_lead := ph / gl
	# How much the edge faces the sun, counted only for edges facing right: an edge facing
	# straight up or left is never lit (the lips are the right-hand lips of the arms).
	var out_n := nrm if d_trail < d_lead else -nrm
	var face := out_n.dot(LIGHT)
	if out_n.x < 0.3:
		face = minf(face, 0.0)
	return Vector4(rim + 1.0 + 10.0 * float(arm), minf(d_trail, d_lead), face, rr)


## The eye and the arms winding into it, laid over the puffs already painted. Arms and grooves
## only recolour cloud that is there; the hole is cut through whatever is there.
##  - An arm is the puff's own shading lifted a step (so lumps stay lumps), fading back to the
##    plain puff towards its outer end, so the spiral grows out of the puffs with no rim of its
##    own. Its edge facing the sun (right, up-right) is a solid lip one art pixel thick (two
##    nearest the eye), the clean water's shallow blue, its light step only nearest the eye;
##    each lip stops short on its own arm. The edge facing away is a dark seam.
##  - A groove is the cloud a step or two darker, darker nearer the eye.
##  - The hole: the inner wall runs down in spiral bands (turning faster than the arms) to the
##    throat, the left wall lit, the right in shade, the far lip's inner edge in the light; the
##    throat, nearer the front lip, the darkest blue there is. All opaque.
func _paint_vortex(buf: Dictionary, origin: Vector2, up: int) -> void:
	var rx := _eye_rx
	if rx < 4.0 or _vx <= 0.02:
		return
	var ew := origin + _eye_c - Vector2(0.0, _cloud_up)
	var out := VORTEX_OUT * _vx
	var hole_on := _eye_open * rx * 0.8 >= ART * 2.0
	var reach := rx * VORTEX_OUT * 1.2
	var x0 := int(floor((ew.x - reach) / ART))
	var x1 := int(floor((ew.x + reach) / ART))
	var y0 := int(floor((ew.y - reach * (CLOUD_FLAT + 0.1) * 1.3) / ART))
	var y1 := int(floor((ew.y + reach * EYE_FLAT * 1.05) / ART))
	var sector := TAU / float(ARMS)
	var ry := rx * EYE_FLAT
	var throat := Vector2(0.0, THROAT_DOWN * _eye_open)
	# A hit: for one beat every lip nearest the eye is lit all round, and for two beats the
	# throat opens an art pixel or two wider, then settles.
	var hits: int = _s["hits"]
	var since: float = _s["since_hit"]
	var ring_beat := hits > 0 and hits < 3 and since < 1.0 / FPS
	var pop := 0.0
	if hits > 0 and hits < 3 and since < 2.0 / FPS:
		pop = ART * (2.0 if _weak() > 0.85 else 1.0)
	for cy in range(y0, y1 + 1):
		var dy := (float(cy) + 0.5) * ART - ew.y
		for cx in range(x0, x1 + 1):
			var cell := Vector2i(cx, cy)
			var dx := (float(cx) + 0.5) * ART - ew.x
			var info := _vortex_at(dx, dy, out, hole_on)
			if info.x < 0.0:
				continue
			var kind := int(info.x) % 10
			var arm := (int(info.x) / 10) % 10
			var on_rim := int(info.x) >= 100
			if kind == 2:
				# Down the hole, darkening by value to the throat: the wall's light bands (3),
				# the wall (5), its grooves and the ring round the throat (4), the throat (6, the
				# darkest swatch in the storm). The left wall faces the sun and is a step lit,
				# never a pale lip; the right wall is in shade.
				var q := Vector2(dx / rx, dy / ry)
				var qt := q - throat
				var lt := qt.length()
				var dn := lt / maxf(_eye_open, 0.05)
				var band := fposmod((atan2(qt.y, qt.x) - _wall_shown) / sector + WIND * log(maxf(lt, 0.04)), 1.0)
				var core := maxf(0.4, ART * 2.5 * float(_bold) / maxf(rx * _eye_open, 1.0)) + pop / maxf(rx * _eye_open, 1.0)
				var tone := 5
				if dn < core:
					tone = 6
				elif dn < core + 0.16:
					tone = 4
				else:
					if band < 0.22:
						tone = 3
					elif band < 0.36:
						tone = 4
					elif qt.x < -0.3 and qt.y < 0.2:
						tone = 3
					elif qt.x > 0.35:
						tone = 4
					# The far lip's inner edge catches the light.
					if q.y < -0.2 and q.length() > _eye_open * 0.74:
						tone = 3 if dx < rx * 0.15 else 2
				buf[cell] = Vector2(maxi(tone - up, 0), 1.0)
				continue
			if not buf.has(cell):
				continue
			var was: Vector2 = buf[cell]
			var near := info.w
			var tt := clampf((near - 1.0) / (VORTEX_OUT - 1.0), 0.0, 1.0)
			# The vortex's reach is scalloped with the lobes' own noise, so the knot's outer edge
			# is puffs, not an ellipse: every threshold below reads this rolled distance.
			var bear := atan2(dy / EYE_FLAT, dx)
			tt = clampf(tt + (_np(bear * 7.0 / TAU + float(arm) * 0.3, 7, 211) - 0.5) * 0.45, 0.0, 1.0)
			var tone2: int
			if kind == 1:
				# The lift is the light the open eye lets fall on its arms: as the eye shuts (and
				# before it opens) it goes a step at a time, so the knot is the puffs' own shading
				# wound tight by its grooves and seams, not a pale disc laid on the cloud.
				var lift := 2 if tt < 0.4 else (1 if tt < 0.75 else 0)
				if _eye_open < 0.6:
					# The knot keeps one step (its inner third) while the eye is still closing; shut, it
					# is the puffs' own shading wound by its grooves and seams.
					lift = 1 if (tt < 0.35 and _eye_open > 0.25) else 0
				# The last 0.3 of the reach steps back to the puffs' own tones.
				if tt > 0.7:
					lift = 0
				tone2 = clampi(int(was.x) - lift, 1, 4)
				var dist := info.y
				var facing := info.z
				var lip_end := minf(_lip_hi, 1.3 + (VORTEX_OUT - 1.3) * _h2(arm, 3, 191))
				var lip_w := ART * float(_bold) * (3.0 if near < 1.25 else 2.0)
				if facing > 0.3 and near >= _lip_lo and near <= lip_end and dist < lip_w:
					tone2 = 0 if (near < 1.2 and dist < ART * float(_bold)) else 1
				elif ring_beat and near < 1.3 and dist < lip_w:
					tone2 = 1
				elif facing < -0.25 and dist < ART * float(_bold) and tt < 0.85:
					tone2 = 4

			else:
				# Never as dark as the hole: the hole is the darkest thing in the cloud.
				var deeper := 1
				if (_eye_open < 0.15 and tt > 0.5) or tt > 0.7:
					deeper = 0
				tone2 = clampi(int(was.x) + deeper, 3, 4)
			# The far lip of the hole catches the light (the sun is right, so most on the
			# right); the near lip is left as the arms have it, falling away into the hole.
			if on_rim and dy < -ART:
				tone2 = 1 if dx > rx * 0.15 else 2
			buf[cell] = Vector2(maxi(tone2 - up, 0), was.y)


## The shoulders: at the cloud's underside, over the column's edges, a drape of the cloud's
## shade (widest at the underside, gone three rows up) with one row hanging just under the line
## in the seam tone, the right-hand top lit a step. Rows are (below/above the line, px over the
## column's edge, px out past it).
const DRAPE := [[-1, 2, 2], [0, 3, 2], [1, 3, 1], [2, 2, 1], [3, 1, 0]]


func _paint_collar(on: Node2D) -> void:
	if _s.is_empty() or _split_y < -99999.0 or _vis_hi <= _vis_lo + 2.0 or _prof.is_empty():
		return
	var origin := on.global_position
	var gy := global_position.y
	var gx := global_position.x
	var buf := {}
	var flash: float = _s.get("flash", 0.0)
	var up := 1 if flash > 0.35 else 0
	for row: Array in DRAPE:
		var j: int = row[0]
		var cy := int(floorf(_split_y / ART)) - 1 - j
		var ly := (float(cy) + 0.5) * ART - gy
		# The column at this height, off the profile.
		var hit := -1
		for i in N - 1:
			if ly <= _prof[i].y and ly >= _prof[i + 1].y:
				hit = i
				break
		if hit < 0:
			continue
		var t := (_prof[hit].y - ly) / maxf(_prof[hit].y - _prof[hit + 1].y, 0.001)
		var h := (float(hit) + t) / float(N - 1) * _top_h
		if h < _vis_lo + 4.0:
			continue
		var ax := lerpf(_prof[hit].x, _prof[hit + 1].x, t) + gx
		var r := lerpf(_prof[hit].z, _prof[hit + 1].z, t)
		var inn := int(row[1]) * _bold
		var out := int(row[2])
		for sgn: int in [-1, 1]:
			var edge := int(roundf((ax + float(sgn) * r) / ART))
			for k in range(-out, inn + 1):
				var cx := edge - sgn * k
				var tone := 5 if j < 0 else 4
				if sgn > 0 and j == 3:
					tone = 3
				buf[Vector2i(cx, cy)] = Vector2(maxi(tone - up, 0), 1.0)
	_draw_buffer(on, buf)


## Draws a buffer of cells -> (ramp index, alpha) in horizontal runs.
func _draw_buffer(on: Node2D, buf: Dictionary) -> void:
	if buf.is_empty():
		return
	var origin := on.global_position
	var rows := {}
	for cell: Vector2i in buf:
		if not rows.has(cell.y):
			rows[cell.y] = []
		(rows[cell.y] as Array).append(cell.x)
	for cy: int in rows:
		var xs: Array = rows[cy]
		xs.sort()
		var start: int = xs[0]
		var was: Vector2 = buf[Vector2i(start, cy)]
		var last := start
		for n in range(1, xs.size() + 1):
			var x: int = xs[n] if n < xs.size() else -999999
			var v: Vector2 = buf[Vector2i(x, cy)] if n < xs.size() else Vector2(-1, -1)
			if x == last + 1 and v == was:
				last = x
				continue
			on.draw_rect(Rect2(float(start) * ART - origin.x, float(cy) * ART - origin.y, float(last - start + 1) * ART, ART), _shade(int(was.x), was.y))
			start = x
			last = x
			was = v


# ======================================================================================
# Back and front of the funnel (the look's own z): debris, plumes, the waist ring, spray
# ======================================================================================

func _paint_back(on: Node2D) -> void:
	if _s.is_empty():
		return
	_paint_debris(on, false)
	var cells := {}
	_paint_crown(cells, false)
	_paint_waist_ring(cells, false)
	_paint_chunks(cells, false)
	_flush(on, cells)
	_draw_puffs(on, false)


func _paint_front(on: Node2D) -> void:
	if _s.is_empty():
		return
	_paint_debris(on, true)
	var cells := {}
	_paint_crown(cells, true)
	_paint_waist_ring(cells, true)
	_paint_chunks(cells, true)
	_flush(on, cells)
	_draw_puffs(on, true)


## The carried pieces, pulled `DEBRIS_FOLLOW` of the way from the harness's axis onto the
## drawn rope (they are drawn under the cloud, which swallows the ones up in it).
func _paint_debris(on: Node2D, front: bool) -> void:
	var list: Array = []
	var hs: float = float(_s["height"]) * float(_s["strength"])
	var axis_at: Callable = _s["axis_at"]
	for d: Dictionary in _s.get("debris", []):
		if bool(d["front"]) != front:
			continue
		list.append(d)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["depth"]) < float(b["depth"]))
	for d: Dictionary in list:
		var h: float = d["height"]
		var at: Vector2 = d["local"]
		if hs > 4.0:
			var theirs: Vector2 = axis_at.call(clampf(h / hs, 0.0, 1.0))
			at.x += (_axis(h).x - theirs.x) * DEBRIS_FOLLOW
		# A pigeon in the whirl (2026-10-08) draws itself, through the tornado.
		if d.has("paint"):
			(d["paint"] as Callable).call(on, at, d)
			continue
		DebrisDraw.draw_piece(on, d["def"], at, float(d["rot"]), float(d["scale"]), float(d["alpha"]))


func _cell(at: Vector2) -> Vector2i:
	var w := global_position + at
	return Vector2i(int(floorf(w.x / ART)), int(floorf(w.y / ART)))


func _disc(cells: Dictionary, at: Vector2, r: float, col: Color) -> void:
	var w := global_position + at
	var r2 := maxf(r, ART * 0.5)
	var x0 := int(floorf((w.x - r2) / ART))
	var x1 := int(floorf((w.x + r2) / ART))
	var y0 := int(floorf((w.y - r2) / ART))
	var y1 := int(floorf((w.y + r2) / ART))
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var c := Vector2((float(cx) + 0.5) * ART, (float(cy) + 0.5) * ART)
			if c.distance_to(w) <= r2 + ART * 0.35:
				cells[Vector2i(cx, cy)] = col


func _block(cells: Dictionary, at: Vector2, wide: int, tall: int, col: Color) -> void:
	var c := _cell(at)
	for y in tall:
		for x in wide:
			cells[c + Vector2i(x - (wide >> 1), y - (tall >> 1))] = col


func _flush(on: Node2D, cells: Dictionary) -> void:
	var origin := on.global_position
	for key: Vector2i in cells:
		on.draw_rect(Rect2(Vector2(key) * ART - origin, Vector2(ART, ART)), cells[key])


## A's crown at the foot: sheets of water thrown up and outward round it, each on its own beat
## with a shape rolled per beat, turning with the spout, tearing at the tip into drops.
func _paint_crown(cells: Dictionary, front: bool) -> void:
	if _foot <= 0.02:
		return
	var strength := clampf(_size_s, 0.0, 1.0)
	var spin: float = _s["spin"]
	var foam := _pal.foam
	var hi := _pal.foam_light
	var peak := 40.0 * _foot * _size * lerpf(0.65, 1.0, strength)
	for k in PLUMES:
		var fk := float(k)
		var period := 0.62 + 0.4 * _fhash(fk, 1.0)
		var cycle := _time / period + _fhash(fk, 2.0)
		var beat := floorf(cycle)
		var u := cycle - beat
		var roll := _fhash(fk * 13.0 + beat, 3.0)
		var th := fk / float(PLUMES) * TAU - spin * 0.8 + (roll - 0.5) * 0.7
		var sn := sin(th)
		if (sn > 0.0) != front:
			continue
		var tall := peak * (0.55 + 0.6 * _fhash(fk + beat * 7.0, 4.0)) * pow(sin(PI * minf(u * 1.15, 1.0)), 0.7)
		if tall < 4.0:
			continue
		var wide := 36.0 * (0.7 + 0.5 * _fhash(fk + beat, 5.0)) * _foot
		var lean := 0.8 + 0.5 * roll
		var out := Vector2(cos(th), sn * 0.5)
		var root := out * _skirt_r * 0.42 + Vector2(_prof_at(0.0).x, 0.0)
		var ctrl := root + out * wide * 0.22 * lean + Vector2(0.0, -tall * 1.05)
		var tip := root + out * wide * 0.55 * lean + Vector2(0.0, -tall * 0.6)
		var thick := maxf(wide * 0.13, 3.0) * (1.0 - u * 0.35)
		var col := hi if cos(th) > 0.1 else foam
		col.a = 1.0 if u < 0.7 else REMNANT
		var steps := int((tall + wide) / ART) + 2
		for i in steps + 1:
			var t := float(i) / float(steps)
			if t > 0.55 and _fhash(fk * 3.0 + beat, floorf(t * 7.0)) < (u - 0.45) * 1.8:
				continue
			var a := root.lerp(ctrl, t)
			var b := ctrl.lerp(tip, t)
			var pt := a.lerp(b, t)
			var taper := (1.0 - t) * (1.0 - t) * 0.5 + (1.0 - t) * 0.5
			_disc(cells, pt, thick * taper, col)
		if u > 0.55:
			var fall := (u - 0.55) * period
			for j in 3:
				if _fhash(fk + beat * 3.0, 10.0 + float(j)) < 0.35:
					continue
				var spread := out * (8.0 + 30.0 * fall * (0.6 + 0.4 * float(j)))
				var drop := tip + spread + Vector2(0.0, -30.0 * fall + 300.0 * fall * fall) + Vector2(float(j - 1) * 4.0, 0.0)
				if drop.y > root.y + 4.0:
					continue
				var dc := foam
				dc.a = 1.0 if fall < 0.22 else REMNANT
				_block(cells, drop, 1, 1, dc)


## A hit: a flat ring bursts off the pinched waist, a torn band racing outwards and sinking,
## in the rope's own lit tones, its arcs breaking into drops at their ends.
func _paint_waist_ring(cells: Dictionary, front: bool) -> void:
	var hits: int = _s["hits"]
	var since: float = _s["since_hit"]
	if hits == 0 or since > 0.6:
		return
	var weak := _weak()
	var waist := _prof_at(_pinch_h)
	var rr := waist.z + 10.0 + since * 180.0 * weak
	var sink := 80.0 * since * since
	var centre := Vector2(waist.x, waist.y + sink)
	var keep := lerpf(0.9, 0.3, since / 0.6) * weak
	var thick := 3 if since < 0.15 else (2 if since < 0.35 else 1)
	var col := _ramp[0] if since < 0.2 else _ramp[1]
	col.a = 1.0 if since < 0.3 else REMNANT
	var arcs := 11
	var steps := int(TAU * rr / ART)
	for i in steps:
		var th := float(i) / float(steps) * TAU
		if (sin(th) > 0.0) != front:
			continue
		var f := th / TAU * float(arcs)
		var arc := floorf(f)
		var along := f - arc
		var start := _fhash(arc + float(hits) * 20.0, 1.0) * 0.2
		var fill := keep * (0.7 + 0.3 * _fhash(arc + float(hits) * 20.0, 2.0))
		if along < start or along > start + fill:
			continue
		var at := centre + Vector2(cos(th) * rr, sin(th) * rr * 0.5)
		_block(cells, at, thick, thick, col)
		if since > 0.2 and (along - start < 0.04 or start + fill - along < 0.04):
			var dc := _ramp[1]
			dc.a = REMNANT
			_block(cells, at + Vector2(0.0, 40.0 * (since - 0.2)), 1, 1, dc)


func _paint_chunks(cells: Dictionary, front: bool) -> void:
	for c: Dictionary in _chunks:
		if bool(c["front"]) != front:
			continue
		var young := float(c["age"]) < float(c["life"]) * 0.5
		var col := _pal.foam_light if young else _pal.foam
		col.a = 1.0 if young else REMNANT
		cells[_cell(c["at"])] = col


## Vapour off a hit and off the tip as it is drawn up (B's): flat smears of the storm's own
## cloud, two or three side by side, sheared the way the funnel turns, in two alpha steps.
func _draw_puffs(on: Node2D, front: bool) -> void:
	var buf := {}
	for p: Dictionary in _puffs:
		var depth: float = p["depth"]
		if (depth > 0.0) != front:
			continue
		var u := float(p["age"]) / float(p["life"])
		var a := 1.0 if u < 0.4 else (REMNANT if u < 0.8 else 0.0)
		if a <= 0.0:
			continue
		var at: Vector2 = p["at"]
		var r: float = p["size"]
		var v: Vector2 = p["vel"]
		var trail := -1.0 if v.x > 0.0 else 1.0
		var n := 0
		for lb: Vector3 in p["lobes"]:
			_paint_vapour(buf, at + Vector2(lb.x, lb.y) * r, r * lb.z, a, trail, int(p["seed"]) * 7 + n)
			n += 1
	_draw_buffer(on, buf)


## A thin smear of vapour: three or four small round sub-lobes side by side (a scalloped
## outline, no ragged row tails), the storm's greys only (index 2 over 3, never paler), at `a`.
## `lift` below 0 takes it a step darker (the first condensing wisps).
func _paint_vapour(buf: Dictionary, wc: Vector2, lr: float, a: float, trail: float, sd: int, lift: int = 0) -> void:
	if lr < ART * 2.0:
		return
	var subs: Array[Vector3] = []
	var n := 3 + int(_h2(sd, 1, 171) * 2.0)
	for k in n:
		var along := (float(k) - float(n - 1) * 0.5) / float(n) * 1.5
		subs.append(Vector3(wc.x + along * lr + trail * lr * 0.1 * float(k),
			wc.y - lr * 0.12 * _h2(sd, 10 + k, 171),
			lr * lerpf(0.36, 0.55, _h2(sd, 20 + k, 171)) * (1.0 - absf(along) * 0.35)))
	var x0 := int(floor((wc.x - lr * 1.4) / ART))
	var x1 := int(floor((wc.x + lr * 1.4) / ART))
	var y0 := int(floor((wc.y - lr * 0.7) / ART))
	var y1 := int(floor((wc.y + lr * 0.5) / ART))
	for cy in range(y0, y1 + 1):
		var py := (float(cy) + 0.5) * ART
		for cx in range(x0, x1 + 1):
			var px := (float(cx) + 0.5) * ART
			var inside := false
			var top := false
			for sb: Vector3 in subs:
				var dx := (px - sb.x) / sb.z
				var dy := (py - sb.y) / (sb.z * 0.62)
				if dx * dx + dy * dy <= 1.0:
					inside = true
					if dy < -0.2:
						top = true
			if not inside:
				continue
			var cell := Vector2i(cx, cy)
			if a < 1.0 and buf.has(cell) and (buf[cell] as Vector2).y >= 1.0:
				continue
			var ci := (2 if top else 3) - lift
			buf[cell] = Vector2(clampi(ci, 2, 5), a)


# ======================================================================================
# On the water (z 4): the cloud's shadow and the column's
# ======================================================================================

## One sun (2026-10-02, `/grill-me` with Richard): the cloud, its rags and the column all lie
## where `Shade.drop` puts the ground under them from their height -- the projection the
## angler's and every other shadow use -- in the water's ink (`Shade.On.WATER`). The cloud's
## was laid at half that offset and the whole storm had a gain of its own (1.1, at most 0.36).
func _paint_sky(on: Node2D) -> void:
	var sun := Shade.sun_of(_day)
	if _s.is_empty() or sun == null:
		return
	var ink := Shade.ink_on(sun.ink, Shade.On.WATER)
	var origin := on.global_position
	# The shadow goes in the same steps as the cloud: whole, remnant, gone.
	var amt := _cloud_amt
	var step_a := 1.0 if (amt >= 0.5 and _dissolve < 0.55) else (REMNANT if (amt > 0.15 and _dissolve < 1.0) else 0.0)
	var cloud_a := ink * step_a
	if _dissolve > 0.0:
		# Breaking up, the shadow is the lobes' and the rags' own, each laid down along the sun
		# from where it is, so a rag over the island reads as up in the air, not lying on it.
		_paint_blob_shadows(on, origin, ink, sun)
	elif cloud_a > 0.02:

		var h := _top_h + _cloud_up
		var c := origin + Vector2(_cloud_c.x, 0.0) + Shade.drop(sun, h)
		var rx := _cloud_rx * 1.05
		var ry := rx * 0.5
		var rows := int(ceil(ry / ART))
		var oy := int(floor(c.y / ART))
		for rr in range(-rows, rows + 1):
			var cy := oy + rr
			var yy := (float(cy) + 0.5) * ART - c.y
			var f := 1.0 - (yy * yy) / (ry * ry)
			if f <= 0.0:
				continue
			var t := float(rr) * 0.3 + _pt * 0.5
			var half_out := rx * sqrt(f) * (0.84 + 0.22 * _n1(t, 301))
			var shift := (_n1(t * 0.5, 303) - 0.5) * rx * 0.12
			var fi := 1.0 - (yy * yy) / (ry * ry * 0.42)
			_run(on, origin, cy, c.x + shift - half_out, c.x + shift + half_out, Shade.INK, cloud_a * REMNANT)
			if fi > 0.0:
				var half_in := rx * 0.66 * sqrt(fi) * (0.8 + 0.3 * _n1(t + 5.0, 305))
				_run(on, origin, cy, c.x + shift - half_in, c.x + shift + half_in, Shade.INK, cloud_a * REMNANT)
	# The column's shadow: each art row of it laid down along the sun, merged into one shape.
	if _vis_hi <= _vis_lo + 2.0:
		return
	var spans := {}
	var h := _vis_lo
	var stop := minf(_vis_hi, _top_h - 30.0)
	while h <= stop:
		var p := _prof_at(h)
		var lands := origin + Vector2(p.x, 0.0) + Shade.drop(sun, h)
		var gy := lands.y
		var gx := lands.x
		var half := p.z * 0.85
		var cy := int(floor(gy / ART))
		var il := int(roundf((gx - half) / ART))
		var ir := int(roundf((gx + half) / ART)) - 1
		if spans.has(cy):
			var sp: Vector2i = spans[cy]
			spans[cy] = Vector2i(mini(sp.x, il), maxi(sp.y, ir))
		else:
			spans[cy] = Vector2i(il, ir)
		h += ART
	var colour := Shade.tint(ink * REMNANT)
	for cy: int in spans:
		var sp: Vector2i = spans[cy]
		if sp.y < sp.x:
			continue
		on.draw_rect(Rect2(float(sp.x) * ART - origin.x, float(cy) * ART - origin.y, float(sp.y - sp.x + 1) * ART, ART), colour)


func _run(on: Node2D, origin: Vector2, cy: int, x0: float, x1: float, c: Color, a: float) -> void:
	var il := int(roundf(x0 / ART))
	var ir := int(roundf(x1 / ART))
	if ir <= il:
		return
	on.draw_rect(Rect2(float(il) * ART - origin.x, float(cy) * ART - origin.y, float(ir - il) * ART, ART), Color(c.r, c.g, c.b, a))


# ======================================================================================
# Layers
# ======================================================================================

class _Quad:
	extends Node2D
	var rect := Rect2(-10, -10, 20, 20)

	func _draw() -> void:
		draw_rect(rect, Color.WHITE)


class _Canvas:
	extends Node2D
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


## The break-up's shadows: every lobe and lump painted this frame (`_blobs`, world), laid down
## along the sun from the cloud's height and squashed onto the plane, merged into one shape at
## one alpha step (overlaps never darken).
func _paint_blob_shadows(on: Node2D, origin: Vector2, ink: float, sun: DayCycle) -> void:
	if _blobs.is_empty():
		return
	var h := _top_h + _cloud_up
	var cw := origin + _cloud_c
	var sc := origin + Vector2(_cloud_c.x, 0.0) + Shade.drop(sun, h)
	var spans := {}
	for b: Vector3 in _blobs:
		var c := sc + (Vector2(b.x, b.y) + _blob_shift - cw) * Vector2(1.0, 0.6)
		var rx := b.z * 0.95
		var ry := rx * 0.45
		if rx < ART * 2.0:
			continue
		for cy in range(int(floor((c.y - ry) / ART)), int(floor((c.y + ry) / ART)) + 1):
			var yy := (float(cy) + 0.5) * ART - c.y
			var f := 1.0 - (yy * yy) / (ry * ry)
			if f <= 0.0:
				continue
			var half := rx * sqrt(f)
			var il := int(roundf((c.x - half) / ART))
			var ir := int(roundf((c.x + half) / ART)) - 1
			if ir < il:
				continue
			if not spans.has(cy):
				spans[cy] = []
			(spans[cy] as Array).append(Vector2i(il, ir))
	var colour := Shade.tint(ink * REMNANT)
	for cy: int in spans:
		var runs: Array = spans[cy]
		runs.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
		var cur: Vector2i = runs[0]
		for n in range(1, runs.size() + 1):
			var nx: Vector2i = runs[n] if n < runs.size() else Vector2i(1 << 30, 1 << 30)
			if nx.x <= cur.y + 1:
				cur.y = maxi(cur.y, nx.y)
				continue
			on.draw_rect(Rect2(float(cur.x) * ART - origin.x, float(cy) * ART - origin.y, float(cur.y - cur.x + 1) * ART, ART), colour)
			cur = nx
