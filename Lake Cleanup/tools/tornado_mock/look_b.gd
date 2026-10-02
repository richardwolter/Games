extends Node2D
## Look B: the storm funnel. A dark rope tornado hanging out of a wide shelf of storm cloud,
## drawn row by row in whole art pixels. The ramp is built at run time from the game's own
## storm tones (`WashBackdrop.STORM_INK` / `STORM_SKY`, the water shader's `sky_storm_ink`)
## nudged towards the clean water's blues, so it sits in the lake and moves with a retune.
##
## Rotation reads as narrow barber-pole bands wound up the height: each band runs the whole
## ramp, a lit crest two art pixels wide, body, a dark groove. They scroll right to left
## across the front (the way the debris goes round), a third of a band per 8 fps step (more
## would alias into standing still), and fade towards the silhouette (cylinder shading), so the
## middle carries the motion and the edges carry the form. The sunny right is a lit face a few
## pixels deep that follows the torn edge inwards, with the outermost pixel kept dark, the
## way the game's sprites end on a dark edge.
##
## The cloud is a wide flat shelf of lobes on four rings that turn at four speeds (so it
## swirls into the funnel) with a darker tier towering behind it; each lobe is lit on a
## crescent along its top and shaded under, so overlapping lobes curl like cauliflower. The
## outer rings are remnants, so the shelf frays out instead of ending like a lid. Its shadow
## lies broad on the water round the funnel, above the rubbish, so the cloud reads overhead.
##
## At the foot: a spray sheath (the waterspout's bottom third) drawn as two surfaces, its back
## wall turning the other way from its front; foam spray spiralling up; a torn foam crest over
## the front of the foot; and on the water under the soup a dark churned wound with foam arms
## wound into the foot and a genuinely torn foam ring sitting inside it.
##
## Touchdown: the cloud gathers and the rope lowers out of it, touching down with a splash.
## Hits: the band the net struck is torn out with a lit flash on its edges and a burst of flat
## smeared vapour, and heals. Collapse: it ropes out, holds a moment twisting, breaks; the top
## half retracts slowly into a lifting cloud, the bottom erodes in clumps into puffs, and the
## cloud frays away lobe by lobe and clump by clump from its edge.
##
## No class_name, loaded by path; draws only, never touches the grid, never the global RNG.

const DebrisDraw := preload("res://tools/tornado_mock/debris_draw.gd")

const ART := 2.0
## Pattern motion ticks at the game's `pixel_fps`.
const PIXEL_FPS := 8.0
const REMNANT := 0.5                           # the foam's second alpha step

# --- Funnel shape --------------------------------------------------------------------------
## How concave the funnel is: its radius climbs `pow(frac, FLARE)` from the tip to the top,
## always inside the harness's `radius_at` (pow 1.4), so the debris orbits outside it.
const FLARE := 2.3
const TIP_R := 7.0
## Helix: how far round the bands turn from the water to the cloud, radians.
const TWIST := 3.8
## Bands round the funnel (half of them on the front).
const STREAKS := 12
## Band scroll, rad/s, at no strength and full: about a third of a band per 8 fps step.
const SPIN_LOW := 0.8
const SPIN_HIGH := 1.3
## Where the rope breaks in the collapse, a share of its height, and when (collapse 0-1).
const BREAK := 0.3
const BREAK_AT := 0.5

# --- The cloud -----------------------------------------------------------------------------
const CLOUD_WIDE := 3.3       # cloud's half-width as a multiple of the funnel's top radius
const CLOUD_FLAT := 0.3       # its half-height as a share of its half-width
const CLOUD_LIFT := 14.0      # how far the cloud's middle sits above the funnel's top
const CLOUD_RISE := 72.0      # how far it lifts away through the collapse

# --- Shadows (the ferry's and the pigeons' bargain: the day's ink is set for sand) ----------
const SHADE_GAIN := 1.1
const SHADE_MOST := 0.36

# --- The foot ------------------------------------------------------------------------------
const SHEATH_TOP := 0.24      # the spray sheath's height, a share of the funnel's
const SHEATH_WIDE := 24.0     # how far it spreads past the funnel at the water, world px
const SPRAY_BITS := 46
const CHURN_R := 84.0
const RING_AT := 0.72         # the foam ring's place inside the churned wound

var _ctx: Dictionary
var _s: Dictionary = {}
var _pal: Palette
var _ramp: Array[Color] = []   # 0 highlight .. 6 core dark
var _foam := Color.WHITE
var _foam_shade := Color.WHITE
var _foam_deep := Color.WHITE
var _churn := Color.WHITE
var _churn_mid := Color.WHITE

var _rng := RandomNumberGenerator.new()
var _tick := -1
var _pt := 0.0                 # stepped pattern time
var _spin_acc := 0.0
var _spin_shown := 0.0
var _time := 0.0
var _strength := 0.0

## The funnel as it is drawn this frame: one entry per art row.
var _rows: Array[Dictionary] = []
var _height := 0.0
var _top := Vector2.ZERO       # local, the funnel's top on its axis
var _top_r := 0.0
var _cloud := 0.0              # 0-1 how much cloud there is
var _cloud_alpha := 1.0
var _cloud_up := 0.0           # how far the cloud has lifted in the collapse
var _water := 0.0              # 0-1 how hard the foot works the water
var _touched := false

var _cloud_puffs: Array[Dictionary] = []
var _puffs: Array[Dictionary] = []    # vapour, in world px
var _hits_seen := 0
var _bands: Array[Vector2] = []       # (frac, time) of each torn band
var _broke := false
var _dissolve := 0.0
var _collapse_t0 := -1.0
var _collapse_h := 1.0

var _ground: Node2D
var _sky: Node2D


class _Layer:
	extends Node2D
	var look: Node2D
	var kind := 0

	func _draw() -> void:
		if kind == 0:
			look._draw_ground(self)
		else:
			look._draw_sky_shadow(self)


func setup(ctx: Dictionary) -> void:
	_ctx = ctx
	_pal = ctx["palette"]
	_rng.seed = 7071
	var storm_ink := WashBackdrop.STORM_INK
	var storm_sky := WashBackdrop.STORM_SKY
	var storm_deep := _water_storm_ink()
	_ramp = [
		_pal.water_clean_light,                              # 0 highlight / flash
		_pal.water_clean_shallow.lerp(storm_ink, 0.3),       # 1 lit crest
		storm_ink.lerp(_pal.water_clean_mid, 0.3),           # 2 lit body
		storm_sky.lerp(_pal.water_clean_mid, 0.25),          # 3 body
		storm_deep.lerp(_pal.water_clean_deep, 0.3),         # 4 shade
		storm_deep.darkened(0.25),                           # 5 dark
		storm_deep.darkened(0.5),                            # 6 core
	]
	_foam = _pal.foam
	_foam_shade = _pal.water_clean_light
	_foam_deep = _pal.water_clean_shallow
	_churn = _pal.water_clean_deep.darkened(0.5)
	_churn_mid = _pal.water_clean_deep.darkened(0.25)
	# The cloud's lobes: [ring, count, size, opaque share, turn rate, lift lo, lift hi]. Inner
	# rings turn faster, so the cloud swirls into the funnel; the outer two are mostly or all
	# remnant, so the shelf frays out at its edge.
	var rings := [
		[0.14, 5, 0.38, 1.0, 0.5, -0.1, 0.3],
		[0.46, 10, 0.29, 1.0, 0.32, -0.1, 0.45],
		[0.8, 16, 0.21, 0.6, 0.2, -0.15, 0.5],
		[1.1, 22, 0.15, 0.0, 0.12, -0.25, 0.45],
	]
	for rg: Array in rings:
		for k in int(rg[1]):
			var ring := float(rg[0]) * _rng.randf_range(0.88, 1.08)
			_cloud_puffs.append({
				"ang": TAU * float(k) / float(rg[1]) + _rng.randf_range(-0.25, 0.25),
				"ring": ring,
				"size": float(rg[2]) * _rng.randf_range(0.8, 1.15),
				"alpha": 1.0 if _rng.randf() < float(rg[3]) else REMNANT,
				"turn": float(rg[4]),
				"lift": _rng.randf_range(float(rg[5]), float(rg[6])),
				"born": _rng.randf_range(0.0, 0.7),
				"die": 0.55 * _rng.randf() + 0.45 * (1.0 - clampf(ring / 1.15, 0.0, 1.0)),
				"tower": false, "fringe": float(rg[0]) > 1.0, "seed": _cloud_puffs.size(),
			})
	# The tier towering behind the shelf: darker, lit only on its crowns, remnant at the top.
	for k in 9:
		var across := lerpf(-0.78, 0.78, float(k) / 8.0) + _rng.randf_range(-0.08, 0.08)
		_cloud_puffs.append({
			"across": across, "lift": lerpf(1.3, 0.8, absf(across)) + _rng.randf_range(0.0, 0.5),
			"size": _rng.randf_range(0.26, 0.36), "born": _rng.randf_range(0.2, 0.8),
			"alpha": 1.0 if absf(across) < 0.55 else REMNANT,
			"die": _rng.randf() * 0.5 + 0.2, "tower": true, "sway": _rng.randf() * TAU,
			"seed": _cloud_puffs.size(),
		})
	_ground = _Layer.new()
	_ground.look = self
	_ground.kind = 0
	_ground.z_index = -17   # 20 - 17 = 3: on the water, under the splash rings and the soup
	add_child(_ground)
	_sky = _Layer.new()
	_sky.look = self
	_sky.kind = 1
	_sky.z_index = -13      # 7: the cloud's shadow over the soup and its shadows, under walkers
	add_child(_sky)


## The water shader's storm-cloud colour, read off the shader itself so it moves with a retune.
func _water_storm_ink() -> Color:
	var fallback := WashBackdrop.STORM_SKY.darkened(0.2)
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


# ======================================================================================
# Tick: the clocks, the funnel's rows, the puffs
# ======================================================================================

func tick(delta: float, s: Dictionary) -> void:
	_s = s
	_time = float(s["time"])
	_strength = float(s["strength"])
	var step := int(floor(_time * PIXEL_FPS))
	# The bands' own spin runs continuously and is shown on the pattern's beat.
	_spin_acc += delta * lerpf(SPIN_LOW, SPIN_HIGH, clampf(_strength, 0.0, 1.0))
	if step != _tick:
		_tick = step
		_pt = float(step) / PIXEL_FPS
		_spin_shown = _spin_acc
	var phase: String = s["phase"]
	var col: float = s["collapse"]
	# Height: the harness's (strength) so the debris sits on it, but held through touchdown
	# (the rope lowers out of a cloud already up) and through the collapse (it breaks and
	# goes up into a cloud that does not come down to the water).
	if phase == "touchdown":
		_height = float(s["height"]) * lerpf(0.86, 1.0, _strength)
	elif phase == "collapse" or phase == "gone":
		_height = float(s["height"]) * _collapse_h
	else:
		_height = float(s["height"]) * _strength
		_collapse_h = maxf(_strength, 0.3)
	_cloud = 1.0
	_cloud_alpha = 1.0
	_cloud_up = 0.0
	if phase == "touchdown":
		_cloud = smoothstep(0.0, 0.6, _time)
	_dissolve = 0.0
	if phase == "collapse" or phase == "gone":
		if _collapse_t0 < 0.0:
			_collapse_t0 = _time
		var since := _time - _collapse_t0
		# The cloud lifts away as the rope goes, and outlives it: it frays out after.
		_cloud_up = CLOUD_RISE * smoothstep(0.1, 1.8, since) + 40.0 * smoothstep(1.5, 3.5, since)
		_dissolve = smoothstep(1.1, 3.3, since) * 1.05
		_cloud = 1.0 - _dissolve * 0.25
		if _dissolve >= 1.0:
			_cloud_alpha = 0.0
	# The foot works the water from the moment the rope touches it.
	var want := _strength
	if phase == "touchdown":
		want = smoothstep(0.7, 1.2, _time) * maxf(_strength, 0.4)
	elif phase == "collapse":
		want = _strength * (1.0 - smoothstep(0.35, 0.75, col))
	elif phase == "gone":
		want = 0.0
	_water = lerpf(_water, want, 1.0 - exp(-6.0 * delta))
	if not _touched and phase == "touchdown" and _time >= 0.85:
		_touched = true
		var splash: WaterSplash = _ctx["splash"]
		splash.splash(global_position, 0.7, true)
		splash.ripple(global_position, 26.0)
	_hits_react(s)
	_collapse_react(col)
	_build_rows(s)
	_tick_puffs(delta)
	_ground.queue_redraw()
	_sky.queue_redraw()


func _hits_react(s: Dictionary) -> void:
	var hits: int = s["hits"]
	while _hits_seen < hits:
		_hits_seen += 1
		if _hits_seen >= 3:
			continue
		var band := 0.52 if _hits_seen == 1 else 0.4
		_bands.append(Vector2(band, _time))
		var axis_at: Callable = s["axis_at"]
		var c: Vector2 = global_position + _axis(band, axis_at)
		var r := _radius(band) + 4.0
		for k in 10:
			var a := TAU * float(k) / 10.0 + _rng.randf_range(-0.15, 0.15)
			var out := Vector2(cos(a), sin(a) * 0.5)
			# Round the way the funnel turns: the front goes left.
			var tan := Vector2(-sin(a), cos(a) * 0.5)
			_puffs.append({
				"at": c + out * r + Vector2(0.0, _rng.randf_range(-10.0, 10.0)),
				"vel": out * _rng.randf_range(50.0, 110.0) + tan * _rng.randf_range(60.0, 110.0) + Vector2(0.0, _rng.randf_range(-25.0, 5.0)),
				"size": _rng.randf_range(6.0, 10.0), "grow": _rng.randf_range(10.0, 18.0),
				"age": 0.0, "life": _rng.randf_range(0.6, 0.95), "depth": sin(a), "lobes": _puff_lobes(),
				"seed": _rng.randi_range(0, 9999),
			})


func _collapse_react(col: float) -> void:
	if col >= BREAK_AT and not _broke:
		_broke = true
		var axis_at: Callable = _s["axis_at"]
		for k in 9:
			var f := lerpf(0.04, BREAK, float(k) / 8.0)
			var c: Vector2 = global_position + _axis(f, axis_at)
			var a := _rng.randf() * TAU
			_puffs.append({
				"at": c + Vector2(_rng.randf_range(-4.0, 4.0), 0.0),
				"vel": Vector2(cos(a) * _rng.randf_range(20.0, 45.0) - 25.0, -_rng.randf_range(5.0, 25.0)),
				"size": _rng.randf_range(5.0, 8.0), "grow": _rng.randf_range(6.0, 12.0),
				"age": 0.0, "life": _rng.randf_range(0.8, 1.3), "depth": sin(a), "lobes": _puff_lobes(),
				"seed": _rng.randi_range(0, 9999),
			})


## Two or three lobes side by side for one puff: (x, y) offset and size, shares of its size.
func _puff_lobes() -> Array[Vector3]:
	var out: Array[Vector3] = [Vector3(0.0, 0.0, 1.0)]
	out.append(Vector3(_rng.randf_range(-1.0, -0.6), _rng.randf_range(-0.05, 0.15), _rng.randf_range(0.55, 0.75)))
	if _rng.randf() < 0.7:
		out.append(Vector3(_rng.randf_range(0.6, 1.0), _rng.randf_range(-0.15, 0.05), _rng.randf_range(0.45, 0.7)))
	return out


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
		p["vel"] = v * exp(-2.2 * delta) + Vector2(0.0, -6.0 * delta)
		p["size"] = float(p["size"]) + float(p["grow"]) * delta
		i += 1


## The funnel's axis at `frac`, local: the harness's own sideways shape (lean, snake, jolt)
## on this look's height, plus the rope's twist as it ropes out.
func _axis(frac: float, axis_at: Callable) -> Vector2:
	var a: Vector2 = axis_at.call(frac)
	var lean: Vector2 = _s.get("lean", Vector2.ZERO)
	var x := a.x
	var col: float = _s.get("collapse", 0.0)
	if col > 0.0:
		var wig := 13.0 * smoothstep(0.05, 0.45, col)
		x += sin(frac * 11.0 - _time * 9.0) * wig * sin(frac * PI)
	return Vector2(x, -_height * frac + lean.y * 0.2 * frac)


## The funnel's radius at `frac`, before its edges are torn.
func _radius(frac: float) -> float:
	var st := clampf(_strength, 0.0, 1.0)
	var phase: String = _s.get("phase", "")
	if phase == "collapse" or phase == "gone":
		st = _collapse_h
	var top: float = _ctx["top_r"]
	var r := lerpf(TIP_R, top, pow(clampf(frac, 0.0, 1.0), FLARE)) * lerpf(0.45, 1.0, st)
	r *= 1.0 + 0.25 * float(_s.get("hit_flash", 0.0))
	# Breathing: the rope swells and thins a little along its length.
	r *= 1.0 + 0.08 * sin(frac * 9.0 - _pt * 3.0)
	return r


func _build_rows(s: Dictionary) -> void:
	_rows.clear()
	var axis_at: Callable = s["axis_at"]
	var phase: String = s["phase"]
	var col: float = s["collapse"]
	var origin := global_position
	var lean: Vector2 = s["lean"]
	var span := _height - lean.y * 0.2          # local y of the top is -span
	_top = _axis(1.0, axis_at)
	_top_r = _radius(1.0)
	if phase == "gone" or _height < 4.0:
		return
	# The rope lowering out of the cloud: rows under `tip` are not there yet.
	var tip := 0.0
	if phase == "touchdown":
		tip = 1.0 - smoothstep(0.05, 0.85, _time)
	# The collapse: thin to a rope and hold it twisting, break at `BREAK`; the top goes up
	# slowly, the bottom erodes away in clumps.
	var rope := 1.0
	var upper_from := 0.0
	var lower_fade := 0.0
	var broken := phase == "collapse" and col >= BREAK_AT
	if phase == "collapse":
		rope = lerpf(1.0, 0.28, smoothstep(0.0, 0.35, col))
		if broken:
			upper_from = lerpf(BREAK, 1.02, smoothstep(BREAK_AT, 1.0, col))
			lower_fade = smoothstep(BREAK_AT, BREAK_AT + 0.3, col)
	var top_cell := int(floor((origin.y - span) / ART))
	var foot_cell := int(floor(origin.y / ART))
	for cy in range(top_cell, foot_cell + 1):
		var y_local := (float(cy) + 0.5) * ART - origin.y
		var frac := clampf(-y_local / maxf(span, 1.0), 0.0, 1.0)
		if frac < tip:
			continue
		var lower := frac < BREAK
		if broken and lower and lower_fade >= 1.0:
			continue
		if broken and not lower and frac < upper_from:
			continue
		var r := _radius(frac) * rope
		# The descending tip and the retracting stub taper to a point.
		if phase == "touchdown":
			r *= clampf(smoothstep(tip, tip + 0.18, frac), 0.12, 1.0)
		if broken and not lower:
			r *= clampf(smoothstep(upper_from, upper_from + 0.14, frac), 0.12, 1.0)
		if broken and lower:
			r *= clampf(1.0 - smoothstep(BREAK - 0.1, BREAK, frac), 0.15, 1.0)
		# A band the net struck: torn out, its edges flashing lit, then growing back.
		var tear := 0.0
		for b: Vector2 in _bands:
			var age := _time - b.y
			if age > 0.6:
				continue
			var wide := 0.1 * (1.0 - smoothstep(0.1, 0.6, age))
			var d := absf(frac - b.x)
			if d < wide:
				var heal := smoothstep(0.12, 0.6, age)
				r *= lerpf(0.0, 1.0, maxf(heal, d / wide * 0.7))
				if d > wide * 0.72 and age < 0.25:
					tear = 1.0
			elif d < wide + 0.03 and age < 0.25:
				tear = 1.0
		if r < 1.0:
			continue
		var cx := _axis(frac, axis_at).x
		var row := int(floor(-y_local / ART))
		# Torn edges: bumps rising up the silhouette, bigger up in the cloud and down in the
		# spray than along the rope.
		var rough := lerpf(1.0, 2.2, smoothstep(0.55, 1.0, frac)) + 0.8 * (1.0 - smoothstep(0.0, 0.15, frac))
		var nl := (_n1(float(row) * 0.33 - _pt * 5.0, 11) - 0.5) * 2.0 * ART * rough * 1.4
		var nr := (_n1(float(row) * 0.29 - _pt * 5.0, 23) - 0.5) * 2.0 * ART * rough * 1.1
		var left := cx - r + nl
		var right := cx + r + nr
		var il := int(roundf((origin.x + left) / ART))
		var ir := int(roundf((origin.x + right) / ART)) - 1
		if ir < il:
			il = int(floor((origin.x + cx) / ART))
			ir = il
		var alpha := 1.0
		if phase == "touchdown" and frac < tip + 0.08:
			alpha = REMNANT
		_rows.append({
			"cy": cy, "row": row, "frac": frac, "cx": origin.x + cx, "r": r,
			"il": il, "ir": ir, "alpha": alpha, "erode": lower_fade if lower else 0.0,
			"tear": tear,
		})


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


## Noise that wraps every `period` cells: for round the funnel.
static func _np(x: float, period: int, sd: int) -> float:
	var i := floori(x)
	var f := x - float(i)
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_h2(posmod(i, period), sd), _h2(posmod(i + 1, period), sd), f)


## 2D value noise wrapping every `period` cells along x (round the funnel).
static func _n2p(x: float, y: float, period: int, sd: int) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - float(ix)
	var fy := y - float(iy)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var x0 := posmod(ix, period)
	var x1 := posmod(ix + 1, period)
	return lerpf(
		lerpf(_h2(x0, iy, sd), _h2(x1, iy, sd), fx),
		lerpf(_h2(x0, iy + 1, sd), _h2(x1, iy + 1, sd), fx), fy)


## One hash per clump of `cw` x `ch` art pixels: erosion and see-through go by clumps, never
## by single pixels (the game's no-dither rule).
static func _clump(i: int, j: int, cw: int, ch: int, sd: int) -> float:
	return _h2(floori(float(i) / float(cw)), floori(float(j) / float(ch)), sd)


# ======================================================================================
# Drawing
# ======================================================================================

func _draw() -> void:
	if _s.is_empty():
		return
	_draw_churn_lip()
	_draw_puffs(false)
	_draw_spray(false)
	_draw_sheath(true)
	DebrisDraw.draw_debris(self, _s, false)
	_draw_funnel()
	_draw_cloud()
	_draw_sheath(false)
	_draw_foot_crest()
	DebrisDraw.draw_debris(self, _s, true)
	_draw_spray(true)
	_draw_puffs(true)


func _shade(idx: int, alpha: float) -> Color:
	var c := _ramp[clampi(idx, 0, _ramp.size() - 1)]
	return Color(c.r, c.g, c.b, alpha)


func _draw_funnel() -> void:
	if _rows.is_empty():
		return
	var origin := global_position
	var flash: float = _s.get("flash", 0.0)
	var lit_by_flash := 1 if flash > 0.35 else 0
	for rw: Dictionary in _rows:
		var il: int = rw["il"]
		var ir: int = rw["ir"]
		var frac: float = rw["frac"]
		var cx: float = rw["cx"]
		var r: float = maxf(float(rw["r"]), 1.0)
		var row: int = rw["row"]
		var alpha: float = rw["alpha"]
		var erode: float = rw["erode"]
		var tear: float = rw["tear"]
		var y := float(rw["cy"]) * ART - origin.y
		var w := ir - il + 1
		var lit_deep := clampi(int(float(w) * 0.13), 1, 4)
		var q_shift := frac * TWIST - _spin_shown
		var wobble := (_n1(float(row) * 0.17 + _pt * 1.5, 5) - 0.5) * 0.5
		var dark_top := 1.0 * smoothstep(0.78, 1.0, frac)
		var light_foot := 0.7 * (1.0 - smoothstep(0.0, 0.22, frac))
		var run_start := il
		var run_col := -1
		var run_a := 0.0
		for i in range(il, ir + 2):
			var ci := -1
			var a := alpha
			if i <= ir:
				var px := (float(i) + 0.5) * ART
				var u := clampf((px - cx) / r, -1.0, 1.0)
				var ang := acos(u)
				# The bands: a lit crest, body, a dark groove, their widths rolled per band.
				var q := (ang + q_shift) * float(STREAKS) / TAU + wobble
				var bi := floori(q)
				var sq := q - float(bi)
				var bk := posmod(bi, STREAKS)
				var crest := 0.16 + 0.1 * _h2(bk, 1, 201)
				var groove := 0.66 + 0.14 * _h2(bk, 2, 201)
				var off := 0.0
				if sq < crest:
					off = -2.2
				elif sq < crest + 0.12:
					off = -1.0
				elif sq > groove + 0.12:
					off = 2.0
				elif sq > groove:
					off = 1.0
				# Cylinder shading: the bands carry the middle, the edges carry the form.
				var amp := sqrt(maxf(1.0 - u * u, 0.0))
				off *= smoothstep(0.12, 0.62, amp)
				var lum := 3.3 - 1.1 * u + dark_top - light_foot + off
				ci = clampi(roundi(lum), 1, 6)
				var dr := ir - i
				var dl := i - il
				if w >= 5:
					# The lit face on the sunny right, following the torn edge in; the last
					# pixel stays dark so the silhouette ends on a dark edge.
					if dr == 0:
						ci = maxi(ci, 4)
					elif dr <= lit_deep:
						ci = mini(ci, 2)
						if off < -0.5 or dr == 1:
							ci = 1
					if dl == 0:
						ci = 6
					elif dl == 1 and w >= 8:
						ci = maxi(ci, 5)
				else:
					if dl == 0 and w >= 2:
						ci = 5
					elif dr == 0:
						ci = mini(ci, 2)
				ci = maxi(ci - lit_by_flash, 0)
				# The torn band's edges flash lit for a step or two.
				if tear > 0.0 and dr >= 1 and dl >= 1:
					ci = 0 if off < -0.5 else mini(ci, 1)
				# The rope's lower half eroding in clumps, going see-through a clump at a time.
				if erode > 0.0:
					var n := _clump(i, row, 3, 3, 29)
					if n < erode:
						ci = -1
					elif n < erode + 0.25:
						a = alpha * REMNANT
			if ci != run_col or not is_equal_approx(a, run_a) or i > ir:
				if run_col >= 0 and i > run_start:
					draw_rect(Rect2(float(run_start) * ART - origin.x, y, float(i - run_start) * ART, ART), _shade(run_col, run_a))
				run_start = i
				run_col = ci
				run_a = a
		# Tufts torn off the edges in clumps two rows tall, trailing the spin (to the left).
		if w >= 4 and alpha >= 1.0 and erode <= 0.0:
			var tuft := _h2(row >> 1, int(_pt * 8.0), 41)
			if tuft > 0.78:
				var n_len := 1 + int(tuft * 10.0) % 3
				draw_rect(Rect2(float(il - 1 - n_len) * ART - origin.x, y, float(n_len) * ART, ART), _shade(5, REMNANT))
			elif tuft < 0.1 and frac > 0.3:
				draw_rect(Rect2(float(ir + 2) * ART - origin.x, y, ART * 2.0, ART), _shade(2, REMNANT))


## The storm's shelf: lobes on four rings round the funnel's top turning at four speeds, with
## a darker tier towering behind. Each lobe is lit on a crescent along its top and shaded under,
## so front lobes curl over the ones behind. It dissolves lobe by lobe (an order rolled per
## lobe, the outer rings first) and clump by clump, lifting away.
func _draw_cloud() -> void:
	if _cloud <= 0.01 or _cloud_alpha <= 0.0:
		return
	var rx := _top_r * CLOUD_WIDE * lerpf(0.45, 1.0, _cloud) * (1.0 + 0.2 * _dissolve)
	var ry := rx * CLOUD_FLAT
	var centre := _top - Vector2(0.0, CLOUD_LIFT + _cloud_up)
	var flash: float = _s.get("flash", 0.0)
	var up := 1 if flash > 0.35 else 0
	var origin := global_position
	var touch: bool = _s["phase"] == "touchdown"
	var lobes: Array[Dictionary] = []
	for p: Dictionary in _cloud_puffs:
		var born: float = p["born"]
		var grow := smoothstep(born, born + 0.4, _time * 2.0) if touch else 1.0
		if grow <= 0.05:
			continue
		var a: float = p["alpha"]
		# Each lobe goes in its own turn: eaten from its edge inwards in lumps, a remnant
		# once it is a third gone.
		var eat := clampf((_dissolve - float(p["die"]) * 0.8) / 0.32, 0.0, 1.0)
		if eat >= 1.0:
			continue
		if eat > 0.12:
			a = REMNANT
		var sd: int = p["seed"]
		if bool(p["tower"]):
			var sway := sin(_pt * 0.4 + float(p["sway"])) * 0.03
			lobes.append({
				"at": centre + Vector2((float(p["across"]) + sway) * rx, -float(p["lift"]) * ry),
				"r": float(p["size"]) * rx * grow, "depth": -2.0 + float(p["lift"]) * -0.1,
				"tone": 4, "rim": float(p["across"]) > 0.0, "alpha": a, "eat": eat, "seed": sd, "flat": 0.62,
			})
			continue
		var ang: float = float(p["ang"]) + _pt * float(p["turn"])
		var ring: float = float(p["ring"]) * (1.0 + 0.4 * _dissolve)
		var depth := sin(ang) * ring
		var fringe: bool = p["fringe"]
		# The fray is at the sides and the back: out in front it would hang over the water
		# as loose grey balls.
		if fringe and sin(ang) > 0.15:
			continue
		var tone := 3
		if depth > 0.35 or fringe:
			tone = 4
		# The near underside is tucked up, so the shelf does not hang down over the funnel.
		var dy := sin(ang) * ry * ring
		if dy > 0.0:
			dy *= 0.55
		lobes.append({
			"at": centre + Vector2(cos(ang) * rx * ring, dy - float(p["lift"]) * ry),
			"r": float(p["size"]) * rx * grow, "depth": depth, "tone": tone,
			"rim": cos(ang) * ring > 0.1 and depth < 0.35 and not fringe,
			"alpha": a, "eat": eat, "seed": sd, "flat": 0.45 if fringe else 0.62,
		})
	lobes.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["depth"]) < float(y["depth"]))
	# Painted into one buffer, back lobe to front, so every pixel has one colour and one of
	# the two alpha steps however many lobes overlap it.
	var buf := {}
	for lb: Dictionary in lobes:
		_paint_lobe(buf, origin + (lb["at"] as Vector2), lb["r"], int(lb["tone"]) - up, lb["alpha"], lb["rim"],
			lb["flat"], lb["eat"], lb["seed"])
	_draw_buffer(buf)


## One lobe of cloud painted into `buf` (cell -> (ramp index, alpha)), centred on `wc`
## (world), `lr` wide and `flat` of that tall. Lit on a crescent along its top (a rim of the
## highlight on the sunny right when `rim`), shaded along its underside, its lower-left the
## seam where it sits on the lobe behind. A remnant lobe never thins an opaque pixel.
func _paint_lobe(buf: Dictionary, wc: Vector2, lr: float, tone: int, a: float, rim: bool, flat: float,
		eat: float = 0.0, sd: int = 0) -> void:
	if lr < 1.5:
		return
	var lry := lr * flat
	for cy in range(int(floor((wc.y - lry) / ART)), int(floor((wc.y + lry) / ART)) + 1):
		var yy := (float(cy) + 0.5) * ART - wc.y
		var f := 1.0 - (yy * yy) / (lry * lry)
		if f <= 0.0:
			continue
		# Each row's ends nudged by a pixel or so, so a lobe's edge is lumpy, not a lens.
		var half := lr * sqrt(f) + (_h2(cy - int(floor(wc.y / ART)), int(lr * 3.0), 141) - 0.5) * ART * 1.6
		var il := int(roundf((wc.x - half) / ART))
		var ir := int(roundf((wc.x + half) / ART)) - 1
		for i in range(il, ir + 1):
			var xx := (float(i) + 0.5) * ART - wc.x
			var dn := Vector2(xx / lr, yy / lry)
			var d := dn.length()
			# Eaten from the edge in lumps: a coarse bite round the lobe, never single pixels.
			if eat > 0.0:
				var bite := _np(atan2(dn.y, dn.x) * 5.0 / TAU + float(sd) * 0.37, 5, 150 + sd)
				if d > 1.0 - eat * (0.55 + 0.6 * bite):
					continue
			var ci := tone
			if dn.y < -0.3 and d > (0.6 if rim else 0.74) and dn.x > -0.55:
				ci = tone - 1
				if rim and dn.x > 0.15 and d > 0.84:
					ci = tone - 2
			elif dn.y > 0.28 and d > 0.5:
				ci = tone + 1
			if dn.x < -0.5 and dn.y > -0.05 and d > 0.78:
				ci = tone + 2
			ci = clampi(ci, 0, 6)
			var cell := Vector2i(i, cy)
			if a < 1.0 and buf.has(cell) and (buf[cell] as Vector2).y >= 1.0:
				continue
			buf[cell] = Vector2(ci, a)


## A wisp of vapour into `buf`: a lumpy head wider than tall, lit along its top and shaded
## under, lighter than the funnel it was torn from, and a ragged tail of remnant trailing
## behind the way it flies (`trail` -1 or 1: which side the tail is on).
func _paint_vapour(buf: Dictionary, wc: Vector2, lr: float, a: float, trail: float, sd: int) -> void:
	if lr < 1.5:
		return
	var lry := maxf(lr * 0.55, ART * 1.5)
	var base_cy := int(floor(wc.y / ART))
	for cy in range(int(floor((wc.y - lry) / ART)), int(floor((wc.y + lry) / ART)) + 1):
		var yy := (float(cy) + 0.5) * ART - wc.y
		var f := 1.0 - (yy * yy) / (lry * lry)
		if f <= 0.0:
			continue
		var rr := cy - base_cy
		var shear := yy * 0.5 * trail
		var half := lr * sqrt(f) + (_h2(rr, sd, 161) - 0.5) * ART * 2.0
		var tail := lr * (0.3 + 0.9 * _h2(rr, sd, 163)) * sqrt(f)
		var x0 := wc.x + shear - half
		var x1 := wc.x + shear + half
		var t0 := x0 - tail if trail < 0.0 else x0
		var t1 := x1 + tail if trail > 0.0 else x1
		var il := int(roundf(t0 / ART))
		var ir := int(roundf(t1 / ART)) - 1
		var hl := int(roundf(x0 / ART))
		var hr := int(roundf(x1 / ART)) - 1
		var ci := 2
		if yy < -lry * 0.25:
			ci = 1
		elif yy > lry * 0.4:
			ci = 3
		for i in range(il, ir + 1):
			var in_head := i >= hl and i <= hr
			var ca := a if in_head else REMNANT
			var cell := Vector2i(i, cy)
			if ca < 1.0 and buf.has(cell) and (buf[cell] as Vector2).y >= 1.0:
				continue
			buf[cell] = Vector2(ci if in_head else ci + 1, ca)


## Draws a buffer of cells -> (ramp index, alpha) in horizontal runs.
func _draw_buffer(buf: Dictionary) -> void:
	if buf.is_empty():
		return
	var origin := global_position
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
			draw_rect(Rect2(float(start) * ART - origin.x, float(cy) * ART - origin.y, float(last - start + 1) * ART, ART), _shade(int(was.x), was.y))
			start = x
			last = x
			was = v


## The waterspout's bottom third: a ragged bell of spray round the foot, foam greys, in the
## foam's two alpha steps. See-through, so drawn twice: its back wall (behind the funnel)
## turns the other way across the screen from its front (over it), which is what makes the
## spin read.
func _draw_sheath(back: bool) -> void:
	if _water <= 0.02:
		return
	var origin := global_position
	var axis_at: Callable = _s["axis_at"]
	var span := maxf(_height, 1.0)
	var top := SHEATH_TOP * clampf(_water * 1.2, 0.25, 1.0)
	var top_cell := int(floor((origin.y - span * top) / ART))
	var foot_cell := int(floor(origin.y / ART))
	for cy in range(top_cell, foot_cell + 1):
		var y_local := (float(cy) + 0.5) * ART - origin.y
		var frac := clampf(-y_local / span, 0.0, 1.0)
		var k := frac / maxf(top, 0.01)
		if k > 1.0:
			continue
		var row := int(floor(-y_local / ART))
		var cx := _axis(frac, axis_at).x
		# A bell of spray: widest at the water, flaring at the very foot.
		var r := _radius(frac) * 1.1 + SHEATH_WIDE * _water * pow(1.0 - k, 1.4)
		r *= 1.0 + 0.25 * (1.0 - smoothstep(0.0, 0.15, k))
		r += (_n1(float(row) * 0.4 + _pt * 6.0, 51) - 0.5) * 6.0 * (0.5 + k)
		var il := int(roundf((origin.x + cx - r) / ART))
		var ir := int(roundf((origin.x + cx + r) / ART)) - 1
		var y := float(cy) * ART - origin.y
		for i in range(il, ir + 1):
			var px := (float(i) + 0.5) * ART
			var u := clampf((px - origin.x - cx) / maxf(r, 1.0), -1.0, 1.0)
			var ang := acos(u)
			if back:
				ang = TAU - ang
			# Tall fingers of spray rising and going round: the noise is fine across and
			# coarse up the height. A hollow shell of spray is thickest seen edge-on, so the
			# sides of the bell are denser than its middle; the front is thickest at the water.
			var q := (ang - _spin_shown * 3.0 + k * 1.2) * 16.0 / TAU
			var v := float(row) * 0.14 - _pt * 3.5
			var n := _n2p(q, v, 16, 61) * 0.75 + _n2p(q * 2.0, v * 2.0, 32, 67) * 0.25
			var dense := n - k * 0.5 + absf(u) * absf(u) * 0.22 - 0.08
			var c: Color
			var a := 1.0
			if back:
				if dense < 0.46:
					continue
				c = _foam_deep
				a = REMNANT
			else:
				dense += 0.14 * (1.0 - smoothstep(0.0, 0.3, k))
				if dense < 0.46:
					continue
				a = 1.0 if dense > 0.6 else REMNANT
				c = _foam if u > 0.3 else (_foam_shade if u > -0.45 else _foam_deep)
			draw_rect(Rect2(float(i) * ART - origin.x, y, ART, ART), Color(c.r, c.g, c.b, a))


## The middle of the churned wound drawn again over everything lying on the water there (the
## net, the soup), at the remnant step: what lands at the foot is sunk in the churn.
func _draw_churn_lip() -> void:
	if _water <= 0.05:
		return
	var origin := global_position
	var rx := CHURN_R * lerpf(0.55, 1.0, _water) * 0.56
	var ry := rx * 0.5
	var rows := int(ceil(ry / ART))
	var oy := int(floor(origin.y / ART))
	for rr in range(-rows, rows + 1):
		var cy := oy + rr
		var yy := (float(cy) + 0.5) * ART - origin.y
		var f := 1.0 - (yy * yy) / (ry * ry)
		if f <= 0.0:
			continue
		var half := rx * sqrt(f) * (0.85 + 0.2 * _n1(float(rr) * 0.5 + _pt * 2.5, 221))
		var il := int(roundf((origin.x - half) / ART))
		var ir := int(roundf((origin.x + half) / ART))
		if ir > il:
			draw_rect(Rect2(float(il) * ART - origin.x, float(cy) * ART - origin.y, float(ir - il) * ART, ART),
				Color(_churn_mid.r, _churn_mid.g, _churn_mid.b, REMNANT))


## The torn crest of foam across the front of the foot, over the net and the churn: the lip
## of the water being thrown up where the rope meets it.
func _draw_foot_crest() -> void:
	if _water <= 0.05:
		return
	var origin := global_position
	var rx := _radius(0.0) * 2.3 + 12.0 * _water
	var ry := rx * 0.42
	var steps := maxi(int(PI * rx / ART), 10)
	var done := {}
	for k in steps + 1:
		var ang := PI * float(k) / float(steps)   # 0 right .. PI left, the near half
		var n := _np((ang + _spin_shown * 1.6) * 9.0 / TAU, 9, 211)
		if n < 0.36 * (1.0 + 0.2 * (1.0 - _water)):
			continue
		var p := origin + Vector2(cos(ang) * rx, sin(ang) * ry)
		var cell := Vector2i(int(floor(p.x / ART)), int(floor(p.y / ART)))
		if done.has(cell):
			continue
		done[cell] = true
		var tall := 1 + int((n - 0.36) * 6.0 * _water)
		var c := _foam if cos(ang) > -0.2 else _foam_shade
		for t in mini(tall, 3):
			var a := 1.0 if t == 0 or n > 0.7 else REMNANT
			draw_rect(Rect2(Vector2(cell.x, cell.y - t) * ART - origin, Vector2(ART, ART)), Color(c.r, c.g, c.b, a))


## Foam spray thrown up and round from the foot, stateless: every bit's place is a function
## of the clock and its own hash. Bits are 1x1, 1x2 or 2x1 art pixels.
func _draw_spray(front: bool) -> void:
	if _water <= 0.02:
		return
	var foot := _radius(0.0)
	for i in SPRAY_BITS:
		var h1 := _h2(i, 1, 71)
		var h2 := _h2(i, 2, 71)
		var h3 := _h2(i, 3, 71)
		var period := 0.6 + h1 * 0.6
		var ph := fposmod(_time / period + h2, 1.0)
		var ang := h3 * TAU + _spin_acc * 3.0 + ph * 2.4
		var depth := sin(ang)
		if (depth > 0.0) != front:
			continue
		var out := foot * (1.1 + ph * (1.6 + h1 * 1.6))
		var up := (4.0 * ph * (1.0 - ph)) * (26.0 + 46.0 * h2) * _water + ph * 18.0 * _water
		var at := Vector2(cos(ang) * out, sin(ang) * out * 0.5 - up)
		if ph > 0.85:
			continue
		var a := 1.0 if ph < 0.55 else REMNANT
		var c := _foam if h3 > 0.3 else _foam_shade
		var p := DebrisDraw.snap(self, at)
		var shape := int(h1 * 3.0)
		var size := Vector2(ART, ART)
		if shape == 1:
			size = Vector2(ART, ART * 2.0)
		elif shape == 2:
			size = Vector2(ART * 2.0, ART)
		draw_rect(Rect2(p, size), Color(c.r, c.g, c.b, a))


## Vapour off a hit and the broken rope: flat smears of the storm's own cloud, two or three
## side by side, sheared the way the funnel turns, going in two alpha steps.
func _draw_puffs(front: bool) -> void:
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
	_draw_buffer(buf)


# ======================================================================================
# On the water, under the soup (the child at z 3)
# ======================================================================================

func _draw_ground(on: Node2D) -> void:
	if _s.is_empty() or _water <= 0.02:
		return
	var w := _water
	var rx := CHURN_R * lerpf(0.55, 1.0, w)
	var ry := rx * 0.5
	var origin := on.global_position
	# The churned wound: a dark core in whole alpha, a torn remnant band round it.
	var rows := int(ceil(ry / ART))
	var oy := int(floor(origin.y / ART))
	for rr in range(-rows, rows + 1):
		var cy := oy + rr
		var yy := (float(cy) + 0.5) * ART - origin.y
		var f := 1.0 - (yy * yy) / (ry * ry)
		if f <= 0.0:
			continue
		var t := float(rr) * 0.45 + _pt * 2.0
		var half_out := rx * sqrt(f) * (0.84 + 0.2 * _n1(t, 81))
		var fi := 1.0 - (yy * yy) / (ry * ry * 0.5)
		var half_in := 0.0
		if fi > 0.0:
			half_in = rx * 0.7 * sqrt(fi) * (0.8 + 0.3 * _n1(t + 7.0, 83))
		var shift := (_n1(t * 0.6, 85) - 0.5) * ART * 3.0
		_run(on, origin, cy, origin.x + shift - half_out, origin.x + shift + half_out, _churn, REMNANT)
		if half_in > ART:
			_run(on, origin, cy, origin.x + shift - half_in, origin.x + shift + half_in, _churn, 1.0)
	# Foam arms wound into the foot, turning with it (outer ends trailing), torn in runs.
	for j in 3:
		var steps := 44
		for t in steps:
			var d := lerpf(0.16, 0.92, float(t) / float(steps - 1))
			if _n1(float(t) * 0.35 + float(j) * 13.0 - _pt * 4.0, 101 + j) < 0.38:
				continue
			var ang := float(j) * TAU / 3.0 + _spin_shown * 2.2 - d * 3.4
			var p := origin + Vector2(cos(ang) * rx * d, sin(ang) * ry * d)
			var cell := Vector2(floor(p.x / ART), floor(p.y / ART)) * ART - origin
			var a := 1.0 if d < 0.6 else REMNANT
			var c := _foam if d < 0.45 else _foam_shade
			on.draw_rect(Rect2(cell, Vector2(ART * (2.0 if d < 0.5 else 1.0), ART)), Color(c.r, c.g, c.b, a))
	# The torn foam ring, inside the wound.
	_torn_ring(on, rx * RING_AT, ry * RING_AT, 2.0, 91)


## A foam ring that is really torn: gaps in runs (about a third of it), 1 to 3 art pixels
## thick where it holds, and clumps trailing behind the way it turns.
func _torn_ring(on: Node2D, rx: float, ry: float, turn: float, sd: int) -> void:
	var origin := on.global_position
	var steps := maxi(int(TAU * rx / ART), 12)
	var done := {}
	for k in steps:
		var ang := TAU * float(k) / float(steps)
		var n := _np((ang + _spin_shown * turn) * 11.0 / TAU, 11, sd)
		if n < 0.42:
			continue
		var thick := 1 + int((n - 0.42) / 0.19)
		var a := 1.0 if n > 0.6 else REMNANT
		var c := _foam if sin(ang) > -0.3 else _foam_shade
		for t in mini(thick, 3):
			var p := origin + Vector2(cos(ang) * (rx + float(t) * ART), sin(ang) * (ry + float(t) * ART * 0.5))
			_foam_cell(on, done, p, c, a if t == 0 else REMNANT)
		# A clump trailing behind the spin (the ring turns with it, backwards in angle here).
		if n > 0.72:
			for t in 2:
				var ab := ang + (float(t) + 1.0) * 2.0 * ART / rx
				var p := origin + Vector2(cos(ab) * rx, sin(ab) * ry)
				_foam_cell(on, done, p, _foam_shade, REMNANT)


func _foam_cell(on: Node2D, done: Dictionary, p: Vector2, c: Color, a: float) -> void:
	var cell := Vector2i(int(floor(p.x / ART)), int(floor(p.y / ART)))
	if done.has(cell):
		return
	done[cell] = true
	on.draw_rect(Rect2(Vector2(cell) * ART - on.global_position, Vector2(ART, ART)), Color(c.r, c.g, c.b, a))


## A horizontal run of whole art pixels on art row `cy`, between two world x's.
func _run(on: Node2D, origin: Vector2, cy: int, x0: float, x1: float, c: Color, a: float) -> void:
	var il := int(roundf(x0 / ART))
	var ir := int(roundf(x1 / ART))
	if ir <= il:
		return
	on.draw_rect(Rect2(float(il) * ART - origin.x, float(cy) * ART - origin.y, float(ir - il) * ART, ART), Color(c.r, c.g, c.b, a))


# ======================================================================================
# Over the soup (the child at z 7): the cloud's shadow and the funnel's
# ======================================================================================

## The cloud's shadow, broad and lumpy on the water round the funnel, laid along the day's
## sun at the cloud's height: a core in the shadow's ink at the boosted strength, a ragged
## band round it at half. And the funnel's own shadow row by row under it.
func _draw_sky_shadow(on: Node2D) -> void:
	if _s.is_empty():
		return
	var day: DayCycle = _ctx["day"]
	var ink := minf(day.ink * SHADE_GAIN, SHADE_MOST)
	var origin := on.global_position
	var cloud_a := ink * _cloud * clampf(1.0 - _dissolve, 0.0, 1.0) * _cloud_alpha
	if cloud_a > 0.02:
		var h := _height + CLOUD_LIFT + _cloud_up
		# Tucked in under the cloud (half the true throw), so the water round the funnel is dark.
		var c := origin + Vector2(_top.x + day.lean * h * 0.5, day.stretch * 0.25 * h)
		var rx := _top_r * CLOUD_WIDE * lerpf(0.45, 1.0, _cloud) * (1.0 + 0.2 * _dissolve) * 1.05
		var ry := rx * 0.5
		var colour := Shade.INK
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
			_run(on, origin, cy, c.x + shift - half_out, c.x + shift + half_out, colour, cloud_a * REMNANT)
			if fi > 0.0:
				var half_in := rx * 0.66 * sqrt(fi) * (0.8 + 0.3 * _n1(t + 5.0, 305))
				_run(on, origin, cy, c.x + shift - half_in, c.x + shift + half_in, colour, cloud_a * REMNANT)
	_draw_cast_shadow(on, ink)


## The funnel's shadow on the water: each row laid down along the day's sun (the lean and
## stretch every caster in the game uses), merged into one flat shape in the shadow's ink.
func _draw_cast_shadow(on: Node2D, ink: float) -> void:
	if _rows.is_empty():
		return
	var day: DayCycle = _ctx["day"]
	var lean := day.lean
	var stretch := day.stretch
	var origin := on.global_position
	var spans := {}
	for rw: Dictionary in _rows:
		if float(rw["alpha"]) < 1.0:
			continue
		var h := origin.y - (float(rw["cy"]) + 0.5) * ART
		if h < 0.0:
			h = 0.0
		var gy := origin.y + stretch * 0.5 * h
		var gx := float(rw["cx"]) + lean * h
		var half := float(rw["r"]) * 0.85
		var cy := int(floor(gy / ART))
		var il := int(roundf((gx - half) / ART))
		var ir := int(roundf((gx + half) / ART)) - 1
		if spans.has(cy):
			var sp: Vector2i = spans[cy]
			spans[cy] = Vector2i(mini(sp.x, il), maxi(sp.y, ir))
		else:
			spans[cy] = Vector2i(il, ir)
	var colour := Shade.tint(ink * REMNANT)
	for cy: int in spans:
		var sp: Vector2i = spans[cy]
		if sp.y < sp.x:
			continue
		on.draw_rect(Rect2(float(sp.x) * ART - origin.x, float(cy) * ART - origin.y, float(sp.y - sp.x + 1) * ART, ART), colour)
