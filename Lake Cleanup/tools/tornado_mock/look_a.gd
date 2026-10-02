extends Node2D
## Look A, "waterspout of foam".
##
## A pale rope of spray, narrow at the water and flaring into a dark storm cloud, drawn in the
## lake's own foam language: whole art pixels on the world's grid, the palette's foam and
## clean-water swatches, hard alpha steps, coming apart into bubbles and clumps rather than
## fading. Layers, all children of this node so they ride the base:
##
##   _water  (z 3, under the rubbish)  the cloud's shadow and the spout's, the ring of darker
##                                    disturbed water with foam arms spiralling in, the boiling
##                                    foam skirt, a hit's torn ring and the collapse's rings.
##   _back   (in the look's z)         the back half of the carried debris, of the crown's
##                                    plumes and drops, of a hit's waist ring and of the
##                                    collapse's falling spray.
##   _spout  (in the look's z)         the cloud (a mass of lit cumulus puffs), the column and
##                                    the spray mound at its foot, one shader quad.
##   _front  (in the look's z)         the front halves of all of the above.
##
## The cloud sits at its own sky height, above anything the funnel carries, and LEADS: it is
## pushed ahead along the base's velocity, and the column hangs from it like a rope whose
## foot drags behind (an S: the foot trails, the top runs ahead). The drawn column is never
## wider than the harness's funnel where the debris orbits, and the debris is drawn pulled
## part of the way onto the drawn axis (`DEBRIS_FOLLOW`), so it orbits the rope it is seen on.

const DebrisDraw := preload("res://tools/tornado_mock/debris_draw.gd")
## The wash room's storm tones, by reference: its clouds are painted white multiplied by
## STORM_INK at full rain, and its sky sinks to STORM_SKY.
const WASH := preload("res://scripts/wash_backdrop.gd")
const SPOUT_SHADER := "res://tools/tornado_mock/look_a_spout.gdshader"
const WATER_SHADER := "res://tools/tornado_mock/look_a_water.gdshader"

const ART := 2.0
const N := 48
## Pattern animation, frames a second: the game's pixel_fps.
const FPS := 8.0

## The cloud: its middle's height over the water (world px), its body's half width.
const CLOUD_H := 305.0
const CLOUD_RX := 84.0
## The column is drawn at most this share of the harness's radius where the debris orbits.
const SHEATH := 0.9
## How far the drawn debris is pulled from the harness's axis onto the drawn one.
const DEBRIS_FOLLOW := 0.55
## Seconds of collapse, from the third hit.
const COLLAPSE_LONG := 2.4
const COLLAPSE_AT := 12.5
## The foam skirt's radius and the disturbed ring's, world px (circles, drawn 2:1).
const SKIRT_R := 50.0
const RING_R := 118.0

const PUFFS := 64
const PLUMES := 9
const DROPS := 30

var _ctx: Dictionary
var _s: Dictionary = {}
var _splash: WaterSplash
var _pal: Palette

var _water: _Quad
var _back: _Canvas
var _spout: _Quad
var _front: _Canvas
var _spout_mat: ShaderMaterial
var _water_mat: ShaderMaterial

var _prof := PackedVector3Array()
var _frozen := PackedVector3Array()
var _top_h := CLOUD_H
var _lead := Vector2.ZERO
var _cloud_c := Vector2(0.0, -CLOUD_H)
var _time := 0.0
var _pat_t := 0.0
var _pat_spin := 0.0
var _step := -1
var _cc := -1.0
var _form := 0.0
var _foot := 0.0
var _skirt_r := SKIRT_R
var _vis_lo := 0.0
var _vis_hi := CLOUD_H
var _pinch := 0.0
var _solid := 0.0
var _touched := false
var _collapse_said := false
var _spin_at_collapse := 0.0
var _sun := Vector2(-0.3, 0.2)

## The cloud's puffs, laid out once: {kind, ang, dist, r, lift, tone, seed, group}.
var _puffs: Array[Dictionary] = []
## This frame's puffs for the shaders.
var _puff_a := PackedVector4Array()
var _puff_b := PackedVector4Array()
var _puff_g := PackedVector4Array()

## The collapse's falling spray.
var _chunks: Array[Dictionary] = []
var _spawn_h := -1.0
var _rng := RandomNumberGenerator.new()


func setup(ctx: Dictionary) -> void:
	_ctx = ctx
	_splash = ctx["splash"]
	_pal = ctx["palette"]
	_rng.seed = 7071
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = _shader(WATER_SHADER)
	_spout_mat = ShaderMaterial.new()
	_spout_mat.shader = _shader(SPOUT_SHADER)

	_water = _Quad.new()
	_water.material = _water_mat
	_water.z_as_relative = false
	_water.z_index = 3
	add_child(_water)
	_back = _Canvas.new()
	_back.painter = _paint_back
	add_child(_back)
	_spout = _Quad.new()
	_spout.material = _spout_mat
	add_child(_spout)
	_front = _Canvas.new()
	_front.painter = _paint_front
	add_child(_front)

	# A debugging aid: LOOK_A_ONLY=water films the water layer alone.
	if OS.get_environment("LOOK_A_ONLY") == "water":
		_back.visible = false
		_spout.visible = false
		_front.visible = false

	# The cloud's ramp: the wash room's two storm rules over the palette's swatches. The tops
	# are painted white under part of the storm's ink, the body under all of it, the shade is
	# the storm sky, the seams that sky under the ink again.
	var ink: Color = WASH.STORM_INK
	var sky: Color = WASH.STORM_SKY
	_spout_mat.set_shader_parameter(&"k_rim", _pal.foam_light * Color.WHITE.lerp(ink, 0.3))
	_spout_mat.set_shader_parameter(&"k_light", _pal.foam * Color.WHITE.lerp(ink, 0.62))
	_spout_mat.set_shader_parameter(&"k_mid", _pal.foam * ink)
	_spout_mat.set_shader_parameter(&"k_dark", sky)
	_spout_mat.set_shader_parameter(&"k_seam", sky * ink)
	_spout_mat.set_shader_parameter(&"s_edge", _pal.water_clean_deep)
	_spout_mat.set_shader_parameter(&"s_deep", _pal.water_clean_mid)
	_spout_mat.set_shader_parameter(&"s_shade", _pal.water_clean_shallow)
	_spout_mat.set_shader_parameter(&"s_body", _pal.water_clean_light)
	_spout_mat.set_shader_parameter(&"s_lit", _pal.foam)
	_spout_mat.set_shader_parameter(&"s_hi", _pal.foam_light)
	_water_mat.set_shader_parameter(&"w_dark", Color(0.03, 0.08, 0.11))
	_water_mat.set_shader_parameter(&"deep", _pal.water_clean_deep)
	_water_mat.set_shader_parameter(&"chop", _pal.water_clean_shallow)
	_water_mat.set_shader_parameter(&"foam", _pal.foam)
	_water_mat.set_shader_parameter(&"foam_hi", _pal.foam_light)

	# Where a shadow falls, from the day (the piers' rule: a point `up` high throws its
	# shadow (lean * up, stretch * 0.5 * up) from the ground under it).
	var day: Object = ctx.get("day")
	if day != null:
		_sun = Vector2(float(day.get(&"lean")), float(day.get(&"stretch")) * 0.5)
	# Down and to the left, whatever the day says, and not so far it leaves the picture.
	_sun = Vector2(clampf(_sun.x, -0.4, -0.12), clampf(_sun.y, 0.12, 0.3))
	print("look_a: sun slide per px up ", _sun)
	_lay_puffs()


## The shader's text, loaded as text: a .gdshader under tools/ has never been through the
## editor's import, and this needs none.
func _shader(path: String) -> Shader:
	var sh := Shader.new()
	sh.code = FileAccess.get_file_as_string(path)
	return sh


## The cloud, once. Not a disk with even arms: a ring of lumpy puffs round the funnel's mouth
## (the part that turns), a tower of bigger puffs heaped to one side on top, ONE long inflow
## tail curling off the other side and a stub opposite it, and a dark wall cloud hanging
## under the middle where the funnel goes up into it.
func _lay_puffs() -> void:
	var roll := RandomNumberGenerator.new()
	roll.seed = 4412
	var group := 0
	for k in 13:
		_puffs.append({"kind": 0, "ang": float(k) / 13.0 * TAU + roll.randf_range(-0.2, 0.2),
			"dist": roll.randf_range(0.82, 1.05), "r": roll.randf_range(15.0, 26.0),
			"lift": roll.randf_range(4.0, 14.0), "tone": 0.0, "seed": roll.randf(), "group": k % 5})
	# The tower: heaped up the back and to the left, the biggest puffs in the cloud.
	for k in 8:
		var a := -2.0 + roll.randf_range(-1.2, 1.2)
		_puffs.append({"kind": 1, "ang": a, "dist": roll.randf_range(0.2, 0.72),
			"r": roll.randf_range(18.0, 26.0), "lift": roll.randf_range(10.0, 24.0), "tone": 0.0,
			"seed": roll.randf(), "group": 5 + k % 2})
	# Two more over the middle, lower, so the top is not a hole.
	for k in 3:
		_puffs.append({"kind": 1, "ang": roll.randf() * TAU, "dist": roll.randf_range(0.0, 0.35),
			"r": roll.randf_range(17.0, 23.0), "lift": roll.randf_range(8.0, 16.0), "tone": 0.0,
			"seed": roll.randf(), "group": k % 5})
	# The tail: one long band of shrinking puffs curling out off the right and round the front.
	for k in 11:
		var t := float(k) / 10.0
		_puffs.append({"kind": 2, "ang": 0.1 + t * 1.45, "dist": 0.95 + t * 0.95,
			"r": lerpf(23.0, 12.0, t), "lift": lerpf(12.0, 4.0, t), "tone": 1.0, "sq": 0.78,
			"seed": roll.randf(), "group": 7})
	# The wall cloud: a ring of small dark puffs hanging under the middle, turning fastest.
	for k in 13:
		_puffs.append({"kind": 3, "ang": float(k) / 13.0 * TAU + roll.randf_range(-0.2, 0.2),
			"dist": roll.randf_range(0.28, 0.4), "r": roll.randf_range(14.0, 18.0),
			"lift": roll.randf_range(-36.0, -26.0), "tone": 0.0, "sq": 0.8, "seed": roll.randf(), "group": 9})
	# Rags of scud under the near edge.
	for k in 6:
		var a := 0.5 + float(k) / 5.0 * 2.2 + roll.randf_range(-0.15, 0.15)
		_puffs.append({"kind": 4, "ang": a, "dist": roll.randf_range(0.6, 0.85),
			"r": roll.randf_range(7.0, 10.0), "lift": roll.randf_range(-20.0, -12.0), "tone": -1.0,
			"seed": roll.randf(), "group": k % 5})


# ======================================================================================
# The frame
# ======================================================================================

func tick(delta: float, s: Dictionary) -> void:
	_s = s
	_time = s["time"]
	var step := int(floorf(_time * FPS))
	if step != _step:
		_step = step
		_pat_t = float(step) / FPS
		_pat_spin = float(s["spin"]) * 0.7
	var hits: int = s["hits"]
	_cc = _time - COLLAPSE_AT if hits >= 3 else -1.0
	if _cc >= 0.0 and _frozen.is_empty():
		_frozen = _prof.duplicate()
		_spin_at_collapse = float(s["spin"])
		_spawn_h = _top_h - 60.0
	# The cloud leads along the base's way, eased; a hit's knock is a jump, not a way.
	var v: Vector2 = s["velocity"]
	if v.length() > 110.0:
		v = v.normalized() * 110.0
	if _cc >= 0.0:
		v = Vector2.ZERO
	_lead = _lead.lerp(Vector2(v.x * 0.85, v.y * 0.4), 1.0 - exp(-1.6 * delta))
	_shape(s)
	_lay_cloud(s)
	_events(s)
	_push(s)
	_tick_chunks(delta, s)
	_water.queue_redraw()
	_back.queue_redraw()
	_spout.queue_redraw()
	_front.queue_redraw()


## The rope's axis x at height h (local): the foot trails, the belly lags, the top runs ahead
## into the cloud.
func _axis(h: float) -> Vector2:
	var g := clampf(h / _top_h, 0.0, 1.0)
	var sm := g * g * (3.0 - 2.0 * g)
	var belly := sin(PI * g) * 0.55 * (1.0 - g)
	var x := _lead.x * (sm - belly)
	x += sin(_time * 1.7 + g * 3.0) * 7.0 * g
	var flash: float = _s.get("hit_flash", 0.0)
	var hits: int = _s.get("hits", 0)
	if hits < 3:
		x += sin(_time * 40.0) * 10.0 * flash * g
	return Vector2(x, -h + _lead.y * sm)


## The column's heights and profile for this frame.
func _shape(s: Dictionary) -> void:
	var strength: float = s["strength"]
	var phase: String = s["phase"]
	_top_h = CLOUD_H
	_foot = 1.0
	_vis_lo = 0.0
	_vis_hi = _top_h
	if phase == "touchdown":
		# The swirl forms first, the rope comes down out of it, the foot boils up to meet it.
		_form = smoothstep(0.0, 1.15, _time)
		var u := smoothstep(0.35, 1.35, _time)
		_vis_lo = _top_h * (1.0 - u)
		_foot = smoothstep(0.8, 1.6, _time)
	else:
		_form = 1.0
	if _cc >= 0.0:
		# Unravels from under the cloud down, the foot last.
		_vis_hi = (_top_h - 40.0) * (1.0 - smoothstep(0.2, 1.9, _cc))
		_foot = 1.0 - smoothstep(1.3, 2.3, _cc)
	_skirt_r = SKIRT_R * lerpf(0.7, 1.0, strength if _cc < 0.0 else 0.5) * maxf(_foot, 0.3)

	# The hit's pinch and flash: a hard notch and two frames of solid white.
	var since: float = s["since_hit"]
	var hits: int = s["hits"]
	_pinch = 0.0
	_solid = 0.0
	if hits > 0 and hits < 3:
		_pinch = smoothstep(0.0, 0.06, since) * (1.0 - smoothstep(0.24, 0.46, since))
		_solid = 1.0 if since < 0.25 else 0.0

	if _cc >= 0.0:
		_prof = _frozen
		return
	var radius_at: Callable = s["radius_at"]
	var hs: float = float(s["height"]) * strength
	var scale := lerpf(0.55, 1.0, strength)
	_prof.resize(N)
	for i in N:
		var h := float(i) / float(N - 1) * _top_h
		var at := _axis(h)
		var g := h / _top_h
		# A rope at the foot, widening up the body, flaring into the cloud's mouth.
		var r := lerpf(7.0, 32.0, smoothstep(0.04, 0.6, g)) * scale
		r += 40.0 * pow(smoothstep(0.55, 1.0, g), 1.5) * lerpf(0.7, 1.0, strength)
		if hs > 4.0 and h <= hs:
			r = minf(r, float(radius_at.call(h / hs)) * SHEATH)
		_prof[i] = Vector3(at.x, at.y, r)


## The column's point and radius at height `h` (local), from this frame's profile.
func _prof_at(h: float) -> Vector3:
	if _prof.is_empty():
		return Vector3(0.0, -h, 4.0)
	var f := clampf(h / maxf(_top_h, 1.0), 0.0, 1.0) * float(N - 1)
	var i := mini(int(f), N - 2)
	return _prof[i].lerp(_prof[i + 1], f - float(i))


## Where every puff is this frame: the ring and the wall cloud turn with the spout, the tower
## and the tail only drift, so the cloud turns without its silhouette spinning like a top.
## Touchdown grows it from the middle out; the collapse breaks it into lumps that drift apart,
## shrink by whole art pixels, thin and flatten into wisps.
func _lay_cloud(s: Dictionary) -> void:
	var spin: float = s["spin"]
	if _cc >= 0.0:
		# Winding down: what it had turned, plus a slowing turn.
		spin = _spin_at_collapse + 2.0 * (1.0 - exp(-_cc * 1.2))
	var top := _prof_at(_top_h)
	var drift := Vector2(sin(_time * 0.37) * 6.0, sin(_time * 0.29) * 3.0)
	_cloud_c = Vector2(top.x, -CLOUD_H) + drift
	_puff_a.resize(0)
	_puff_b.resize(0)
	_puff_g.resize(0)
	for p: Dictionary in _puffs:
		var kind: int = p["kind"]
		var turn := 0.0
		match kind:
			0: turn = spin * 0.22
			1: turn = spin * 0.06
			2: turn = spin * 0.05
			3: turn = spin * 0.38
			4: turn = spin * 0.22
		var ang: float = float(p["ang"]) + turn
		var dist: float = p["dist"]
		var r: float = p["r"]
		var lift: float = p["lift"]
		var tone: float = p["tone"]
		var sn := sin(ang)
		if kind == 0:
			# The near side of the ring hangs low and dark (the shelf), the far side towers.
			var near := clampf(sn, 0.0, 1.0)
			lift = lerpf(lift + 10.0, -6.0, near)
			tone = -near * 0.7
			r *= lerpf(1.15, 0.9, near)
		var plane := Vector2(cos(ang) * dist * CLOUD_RX, sn * dist * CLOUD_RX * 0.5)
		var at := _cloud_c + plane - Vector2(0.0, lift)
		var key := sn * dist
		if kind == 3:
			key = 0.55 + sn * 0.1
		elif kind == 4:
			key = 0.95 + sn * 0.05
		elif kind == 1:
			key = sn * dist * 0.5 - 0.1 + lift * 0.004
		var alpha := 1.0
		var squash: float = p.get("sq", 1.0)
		# Touchdown: from the middle outwards.
		var grow_at := clampf(dist * 0.45 + (0.25 if kind == 2 else 0.0), 0.0, 0.75)
		r *= smoothstep(grow_at, grow_at + 0.3, _form)
		if _cc >= 0.0:
			var g: int = p["group"]
			var delay := float(g % 5) * 0.12 + (0.0 if kind == 3 or kind == 4 else 0.25)
			var u := clampf((_cc - delay) / 1.9, 0.0, 1.0)
			# Each lump drifts off its own way, out and up, the wall cloud first to go.
			var way := Vector2(cos(float(g) * 1.9 + 0.4), sin(float(g) * 1.9 + 0.4) * 0.5)
			at += way * (60.0 * pow(u, 1.1)) + plane * 0.35 * u - Vector2(0.0, 18.0 * u)
			var shrink := u * (1.3 if kind >= 3 else 1.0)
			r *= clampf(1.0 - shrink * shrink, 0.0, 1.0)
			if u > 0.45:
				squash *= 0.62
				alpha = 0.55
			if u > 0.75:
				squash *= 0.72
		r = floorf(r / ART) * ART
		if r < 4.0:
			continue
		_puff_a.append(Vector4(at.x, at.y, r, key))
		_puff_b.append(Vector4(tone, alpha, squash, float(p["seed"])))
		# Its shadow on the water: the plane point under it, slid by the sun.
		var up := CLOUD_H + lift
		var shade := at + Vector2(0.0, up) + _sun * up
		_puff_g.append(Vector4(shade.x, shade.y, r * 1.1, alpha))
		if _puff_a.size() >= PUFFS:
			break


## One-off water: the touchdown's slap, the collapse's heave.
func _events(s: Dictionary) -> void:
	var base: Vector2 = s["base"]
	if not _touched and _vis_lo < 8.0 and _time > 0.5 and _time < 3.0:
		_touched = true
		_splash.splash(base, 0.9, true)
		_splash.ripple(base, 34.0)
		_splash.ripple(base, 18.0)
	if not _collapse_said and _cc >= 1.4:
		_collapse_said = true
		_splash.splash(base, 0.8, true)
		_splash.ripple(base, 40.0)


func _push(s: Dictionary) -> void:
	var strength: float = s["strength"]
	var phase: String = s["phase"]
	var hits: int = s["hits"]
	var since_hit: float = s["since_hit"]
	var gpos := global_position
	_spout_mat.set_shader_parameter(&"base", gpos)
	_spout_mat.set_shader_parameter(&"prof", _prof)
	_spout_mat.set_shader_parameter(&"top_h", _top_h)
	_spout_mat.set_shader_parameter(&"vis_lo", _vis_lo)
	_spout_mat.set_shader_parameter(&"vis_hi", _vis_hi)
	_spout_mat.set_shader_parameter(&"pat_t", _pat_t)
	_spout_mat.set_shader_parameter(&"spin", _pat_spin)
	_spout_mat.set_shader_parameter(&"solid", _solid)
	_spout_mat.set_shader_parameter(&"pinch_h", _top_h * 0.36)
	_spout_mat.set_shader_parameter(&"pinch", _pinch)
	_spout_mat.set_shader_parameter(&"puff", _puff_a)
	_spout_mat.set_shader_parameter(&"puff_b", _puff_b)
	_spout_mat.set_shader_parameter(&"puff_n", _puff_a.size())
	_spout_mat.set_shader_parameter(&"cloud_c", _cloud_c)
	_spout_mat.set_shader_parameter(&"cloud_rx", CLOUD_RX)
	var turn: float = float(s["spin"]) * 0.22 if _cc < 0.0 else _spin_at_collapse * 0.22
	_spout_mat.set_shader_parameter(&"cloud_turn", turn)
	_spout_mat.set_shader_parameter(&"bolt", float(s["flash"]))
	var sz := lerpf(0.6, 1.0, strength if _cc < 0.0 else 0.6) * _foot
	_spout_mat.set_shader_parameter(&"mound_r", 26.0 * sz)
	_spout_mat.set_shader_parameter(&"mound_h", 30.0 * sz)
	var lo := Vector2(_cloud_c.x - CLOUD_RX * 2.4 - 80.0, _cloud_c.y - 130.0)
	var hi := Vector2(_cloud_c.x + CLOUD_RX * 3.2 + 80.0, 12.0)
	for v: Vector3 in _prof:
		lo.x = minf(lo.x, v.x - v.z * 1.4 - 8.0)
		hi.x = maxf(hi.x, v.x + v.z * 1.4 + 8.0)
	_spout.rect = Rect2(lo, hi - lo)

	# The water.
	var ring_keep := 1.0
	if phase == "touchdown":
		ring_keep = smoothstep(0.5, 1.6, _time)
	if _cc >= 0.0:
		ring_keep = 1.0 - smoothstep(0.6, 2.2, _cc)
	var spread_keep := 0.0
	var spread_r := 0.0
	if _cc >= 1.2:
		var sc := _cc - 1.2
		spread_r = SKIRT_R * (1.0 + sc * 2.8)
		spread_keep = 1.0 - smoothstep(0.5, 2.3, sc)
	var burst_keep := 0.0
	var burst_r := 0.0
	if hits > 0 and hits < 3 and since_hit < 0.8:
		burst_r = SKIRT_R * (0.9 + since_hit * 5.0)
		burst_keep = 1.0 - since_hit / 0.8
	_water_mat.set_shader_parameter(&"base", gpos)
	_water_mat.set_shader_parameter(&"pat_t", _pat_t)
	_water_mat.set_shader_parameter(&"spin", _pat_spin)
	_water_mat.set_shader_parameter(&"skirt_r", _skirt_r)
	_water_mat.set_shader_parameter(&"skirt_keep", _foot)
	_water_mat.set_shader_parameter(&"ring_r", RING_R * lerpf(0.75, 1.0, strength if _cc < 0.0 else 0.6))
	_water_mat.set_shader_parameter(&"ring_keep", ring_keep)
	_water_mat.set_shader_parameter(&"burst_r", burst_r)
	_water_mat.set_shader_parameter(&"burst_keep", burst_keep)
	_water_mat.set_shader_parameter(&"spread_r", spread_r)
	_water_mat.set_shader_parameter(&"spread_keep", spread_keep)
	_water_mat.set_shader_parameter(&"shade", _puff_g)
	_water_mat.set_shader_parameter(&"shade_n", _puff_g.size())
	# The cloud's shadow at two hard steps; the touchdown's darkening comes in with the cloud.
	_water_mat.set_shader_parameter(&"shade_a", 0.36)
	# The spout's own shadow, a streak down and to the left from the foot.
	var spout_len := (_vis_hi - _vis_lo) * 0.55 * _foot
	_water_mat.set_shader_parameter(&"spout_to", Vector2(_sun.x, _sun.y) / _sun.length() * spout_len)
	_water_mat.set_shader_parameter(&"spout_w", 10.0 * lerpf(0.6, 1.0, strength))
	var reach := maxf(maxf(RING_R * 1.3, spread_r * 1.25 + 20.0), burst_r * 1.25 + 20.0)
	var lo_w := Vector2(-reach, -reach * 0.5 - 8.0)
	var hi_w := Vector2(reach, reach * 0.5 + 8.0)
	for g: Vector4 in _puff_g:
		lo_w = Vector2(minf(lo_w.x, g.x - g.z - 12.0), minf(lo_w.y, g.y - g.z * 0.6 - 8.0))
		hi_w = Vector2(maxf(hi_w.x, g.x + g.z + 12.0), maxf(hi_w.y, g.y + g.z * 0.6 + 8.0))
	_water.rect = Rect2(lo_w, hi_w - lo_w)


# ======================================================================================
# Drawing: debris, the crown's plumes and drops, a hit's waist ring, the falling spray
# ======================================================================================

func _paint_back(on: Node2D) -> void:
	if _s.is_empty():
		return
	_paint_debris(on, false)
	var cells := {}
	_paint_crown(on, cells, false)
	_paint_waist_ring(cells, false)
	_paint_chunks(cells, false)
	_flush(on, cells)


func _paint_front(on: Node2D) -> void:
	if _s.is_empty():
		return
	_paint_debris(on, true)
	var cells := {}
	_paint_crown(on, cells, true)
	_paint_waist_ring(cells, true)
	_paint_chunks(cells, true)
	_flush(on, cells)


## The carried pieces, pulled `DEBRIS_FOLLOW` of the way from the harness's axis onto the
## drawn rope, and hidden where they would be inside the cloud.
func _paint_debris(on: Node2D, front: bool) -> void:
	var list: Array = []
	var strength: float = _s["strength"]
	var hs: float = float(_s["height"]) * strength
	var axis_at: Callable = _s["axis_at"]
	# Up in the cloud's base a piece is drawn behind the cloud, which swallows it.
	var ceiling := CLOUD_H - 44.0
	for d: Dictionary in _s.get("debris", []):
		var in_front := bool(d["front"]) and float(d["height"]) < ceiling
		if in_front != front:
			continue
		list.append(d)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["depth"]) < float(b["depth"]))
	for d: Dictionary in list:
		var h: float = d["height"]
		var at: Vector2 = d["local"]
		if hs > 4.0 and _cc < 0.0:
			var theirs: Vector2 = axis_at.call(clampf(h / hs, 0.0, 1.0))
			at.x += (_axis(h).x - theirs.x) * DEBRIS_FOLLOW
		var alpha: float = d["alpha"]
		DebrisDraw.draw_piece(on, d["def"], at, float(d["rot"]), float(d["scale"]), alpha)


func _hash(a: float, b: float) -> float:
	var h := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return h - floorf(h)


## A cell of the world's art grid, from a local point on `on`.
func _cell(at: Vector2) -> Vector2i:
	var w := global_position + at
	return Vector2i(int(floorf(w.x / ART)), int(floorf(w.y / ART)))


## Fill the art pixels of a disc of radius `r` (world px) round `at` (local).
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


## A block `wide` x `tall` art pixels, its top-left cell at `at` (local).
func _block(cells: Dictionary, at: Vector2, wide: int, tall: int, col: Color) -> void:
	var c := _cell(at)
	for y in tall:
		for x in wide:
			cells[c + Vector2i(x - (wide >> 1), y - (tall >> 1))] = col


func _flush(on: Node2D, cells: Dictionary) -> void:
	var origin := on.global_position
	for key: Vector2i in cells:
		on.draw_rect(Rect2(Vector2(key) * ART - origin, Vector2(ART, ART)), cells[key])


## The crown at the foot: the net-landing crown's own plumes, bigger and never finished:
## sheets of water thrown up and outward round the foot, each on its own beat with a shape
## rolled per beat, turning with the spout, tearing at the tip into a few large drops.
func _paint_crown(_on: Node2D, cells: Dictionary, front: bool) -> void:
	if _foot <= 0.02:
		return
	var strength: float = _s["strength"]
	var spin: float = _s["spin"]
	var foam := _pal.foam
	var hi := _pal.foam_light
	var peak := 44.0 * _foot * lerpf(0.65, 1.0, strength if _cc < 0.0 else 0.6)
	for k in PLUMES:
		var fk := float(k)
		var period := 0.62 + 0.4 * _hash(fk, 1.0)
		var cycle := _time / period + _hash(fk, 2.0)
		var beat := floorf(cycle)
		var u := cycle - beat
		var roll := _hash(fk * 13.0 + beat, 3.0)
		var th := fk / float(PLUMES) * TAU + spin * 0.8 + (roll - 0.5) * 0.7
		var sn := sin(th)
		if (sn > 0.0) != front:
			continue
		var tall := peak * (0.55 + 0.6 * _hash(fk + beat * 7.0, 4.0)) * pow(sin(PI * minf(u * 1.15, 1.0)), 0.7)
		if tall < 4.0:
			continue
		var wide := 38.0 * (0.7 + 0.5 * _hash(fk + beat, 5.0)) * _foot
		var lean := 0.8 + 0.5 * roll
		var out := Vector2(cos(th), sn * 0.5)
		var root := out * _skirt_r * 0.42 + Vector2(_prof_at(0.0).x, 0.0)
		var ctrl := root + out * wide * 0.22 * lean + Vector2(0.0, -tall * 1.05)
		var tip := root + out * wide * 0.55 * lean + Vector2(0.0, -tall * 0.6)
		var thick := maxf(wide * 0.13, 3.0) * (1.0 - u * 0.35)
		var col := hi if cos(th) > 0.1 else foam
		col.a = 1.0 if u < 0.7 else 0.72
		var steps := int((tall + wide) / ART) + 2
		for i in steps + 1:
			var t := float(i) / float(steps)
			# The tip tears as the plume falls back: whole runs of it go, not single pixels.
			if t > 0.55 and _hash(fk * 3.0 + beat, floorf(t * 7.0)) < (u - 0.45) * 1.8:
				continue
			var a := root.lerp(ctrl, t)
			var b := ctrl.lerp(tip, t)
			var pt := a.lerp(b, t)
			var taper := (1.0 - t) * (1.0 - t) * 0.5 + (1.0 - t) * 0.5
			_disc(cells, pt, thick * taper, col)
		# Late in its beat the tip lets go of two or three big drops.
		if u > 0.55:
			var fall := (u - 0.55) * period
			for j in 3:
				if _hash(fk + beat * 3.0, 10.0 + float(j)) < 0.35:
					continue
				var spread := out * (8.0 + 30.0 * fall * (0.6 + 0.4 * float(j)))
				var drop := tip + spread + Vector2(0.0, -30.0 * fall + 300.0 * fall * fall) + Vector2(float(j - 1) * 4.0, 0.0)
				if drop.y > root.y + 4.0:
					continue
				var n := 2 if fall < 0.18 else 1
				var dc := foam
				dc.a = 0.9 if fall < 0.22 else 0.55
				_block(cells, drop, n, n + (1 if fall > 0.08 else 0), dc)


## A hit: a flat ring of foam bursts off the pinched waist, a torn band of the crown's own
## stuff racing outwards and sinking, its arcs breaking into drops at their ends.
func _paint_waist_ring(cells: Dictionary, front: bool) -> void:
	var hits: int = _s["hits"]
	var since: float = _s["since_hit"]
	if hits == 0 or hits >= 3 or since > 0.6:
		return
	var waist := _prof_at(_top_h * 0.36)
	var rr := waist.z + 10.0 + since * 200.0
	var sink := 80.0 * since * since
	var centre := Vector2(waist.x, waist.y + sink)
	var keep := lerpf(0.9, 0.3, since / 0.6)
	var thick := 3 if since < 0.15 else (2 if since < 0.35 else 1)
	var col := _pal.foam_light if since < 0.2 else _pal.foam
	col.a = 1.0 if since < 0.3 else 0.72
	var arcs := 11
	var steps := int(TAU * rr / ART)
	for i in steps:
		var th := float(i) / float(steps) * TAU
		if (sin(th) > 0.0) != front:
			continue
		var f := th / TAU * float(arcs)
		var arc := floorf(f)
		var along := f - arc
		var start := _hash(arc + float(hits) * 20.0, 1.0) * 0.2
		var fill := keep * (0.7 + 0.3 * _hash(arc + float(hits) * 20.0, 2.0))
		if along < start or along > start + fill:
			continue
		var at := centre + Vector2(cos(th) * rr, sin(th) * rr * 0.5)
		_block(cells, at, thick, thick, col)
		# Drops shaken off the arc's ends.
		if since > 0.2 and (along - start < 0.04 or start + fill - along < 0.04):
			var dc := _pal.foam
			dc.a = 0.72
			_block(cells, at + Vector2(0.0, 40.0 * (since - 0.2)), 1, 2, dc)


## The collapse: as the unravel runs down the column, the spray it held falls away in
## clumps, out and round, shrinking by whole art pixels to single bubbles before it lands.
func _tick_chunks(delta: float, s: Dictionary) -> void:
	if _cc < 0.0:
		return
	var base: Vector2 = s["base"]
	while _spawn_h > _vis_hi and _spawn_h > 6.0:
		var p := _prof_at(_spawn_h)
		var count := 3 + int(_hash(_spawn_h, 1.0) * 3.0)
		for k in count:
			var th := _hash(_spawn_h, 2.0 + float(k)) * TAU
			_chunks.append({
				"at": Vector2(p.x + cos(th) * p.z * 0.9, p.y + sin(th) * p.z * 0.45),
				"vel": Vector2(cos(th), sin(th) * 0.5) * _rng.randf_range(25.0, 80.0)
					+ Vector2(-sin(th), cos(th) * 0.5) * _rng.randf_range(20.0, 60.0)
					+ Vector2(0.0, -_rng.randf_range(0.0, 40.0)),
				"h": _spawn_h, "age": 0.0, "n": 3 if _rng.randf() < 0.55 else 2,
				"front": sin(th) > 0.0, "ring": _rng.randf() < 0.25,
			})
		_spawn_h -= 9.0
	var i := 0
	while i < _chunks.size():
		var c: Dictionary = _chunks[i]
		c["age"] = float(c["age"]) + delta
		var vel: Vector2 = c["vel"]
		vel.y += 330.0 * delta
		c["vel"] = vel
		var at: Vector2 = c["at"]
		at += vel * delta
		c["at"] = at
		# Its height over the water drops as it falls: the plane point is at + height.
		c["h"] = float(c["h"]) - vel.y * delta
		if float(c["h"]) <= 0.0:
			if c["ring"]:
				_splash.ripple(base + at, 6.0)
			_chunks.remove_at(i)
			continue
		i += 1


func _paint_chunks(cells: Dictionary, front: bool) -> void:
	var foam := _pal.foam
	var hi := _pal.foam_light
	for c: Dictionary in _chunks:
		if bool(c["front"]) != front:
			continue
		var age: float = c["age"]
		var n := maxi(int(c["n"]) - int(age / 0.32), 1)
		var col := hi if age < 0.25 else foam
		col.a = 0.95 if age < 0.7 else 0.55
		var tall := n + (1 if float((c["vel"] as Vector2).y) > 60.0 else 0)
		_block(cells, c["at"], n, tall, col)


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
