extends Node2D
## Look C: the cartoon whirlwind. No solid body: the funnel is a crowd of curved wind strokes
## hugging the harness's invisible cone, each a brush stroke that tapers to one art pixel at
## both ends and swells to two (three on the big sweeps) in the middle. Their near halves are
## drawn in front of the carried rubbish, lit from the right (foam on the sunny side, pale
## blue across the middle, shallow blue on the shaded left), backed by one pixel of dark ink so
## they read over any water; their far halves are faint single pixels behind it, so the cone
## turns in 3D. Short flicks crowd the neck and the cone flares into a churning mound of foam
## at the foot, spray peaks climbing out of it into the strokes. On the water a two-arm foam
## spiral, thick at the foot and breaking into flecks outward, sweeps round inside a patch of
## wind-darkened chop.
##
## A hit breaks the funnel for two stepped frames: most strokes vanish, a starburst of short
## thick dashes flies off the cone and a foam puff jumps off the foot; then the strokes grow
## back from the bottom, smaller. The collapse: one white frame of the funnel, then it bursts
## into a dozen long gusts flying outward with the spin, the mound slumps into a ring of foam
## that spreads on the water with the spiral, and both fade.
##
## Every shape is plotted into whole art pixels of the world's grid through one cell map per
## layer, so strokes crossing never stack alpha. All pattern time (strokes, collar, spiral,
## chop, hits, collapse) is stepped at 8 fps; only the funnel's place glides. No randf().

const DebrisDraw := preload("res://tools/tornado_mock/debris_draw.gd")
const Style := preload("res://scripts/style.gd")

const ART := 2.0
const PIXEL_FPS := 8.0

## Strokes on the funnel; the first `LOW` are short flicks crowding the neck.
const STROKES := 36
const LOW := 12
## Crown wisps flaring off the top.
const WISPS := 5
## Leaves and foam flecks riding up inside.
const FLECKS := 24
## Far halves are not drawn above this share of the height: the top is open wisps.
const FAR_TOP := 0.8
## A hit: stepped frames 0-1 are the break, 2-5 the regrowth from the bottom.
const REGROW_CAP := [0.35, 0.6, 0.85, 1.2]
const REGROW_R := [0.72, 0.8, 0.88, 0.95]
## The starburst's dashes, per stepped frame of the break: distance out, cells long.
const BURST_GO := [5.0, 17.0, 30.0]
const BURST_LONG := [4, 4, 2]
## The collapse, seconds long (the harness's COLLAPSE_LONG).
const COLLAPSE_LONG := 1.5
const GUSTS := 13
## Seconds of the collapse the mound takes to slump flat.
const SLUMP := 0.5

var _ctx: Dictionary
var _s: Dictionary = {}
var _p: Palette
var _day: DayCycle
var _water: Node2D
var _wide := false

## The look's own turn: its pace follows strength, a hit whips it, the collapse lets it run
## down. `_rot_q` is it sampled on the 8 fps beat: everything that turns reads that.
var _rot := 0.0
var _rot_q := 0.0
var _beat := -1
## The funnel as it stood when the third net landed: the gusts fly off that shape.
var _snap_axis: PackedVector2Array = PackedVector2Array()
var _snap_r: PackedFloat32Array = PackedFloat32Array()
var _snap_time := 0.0
var _snap_rot := 0.0
var _snap_strength := 0.5
## How strong the water's spiral is, eased.
var _swirl := 0.0
var _origin := Vector2.ZERO

var _white := Color.WHITE
var _foam := Color.WHITE
var _pale := Color.WHITE
var _shade := Color.WHITE
var _mid := Color.WHITE
var _leaf := Color.WHITE
var _leaf_lit := Color.WHITE
var _ink := Color.BLACK
## Light to dark; a stroke's under-pixel is one step down its main colour.
var _ladder: Array[Color] = []


func setup(ctx: Dictionary) -> void:
	_ctx = ctx
	_p = ctx["palette"]
	_day = ctx["day"]
	_wide = OS.get_environment("TORNADO_WIDE") == "1"
	_white = _p.foam_light
	_foam = _p.foam
	_pale = _p.water_clean_light
	_shade = _p.water_clean_shallow
	_mid = _p.water_clean_mid
	_leaf = _p.leaf
	_leaf_lit = _p.grass_light
	_ink = Style.HOLE_RIM
	_ladder = [_white, _foam, _pale, _shade, _mid]
	_water = _WaterLayer.new()
	_water.look = self
	_water.z_as_relative = false
	# Over the splash layer's rings (same z, later in the tree), under the rubbish soup (5).
	_water.z_index = 4
	add_child(_water)


func tick(delta: float, s: Dictionary) -> void:
	_s = s
	var strength: float = s["strength"]
	var rate := lerpf(2.6, 4.0, strength) + 5.0 * float(s["hit_flash"])
	if s["phase"] == "collapse":
		rate *= 1.0 - float(s["collapse"]) * 0.8
	elif s["phase"] == "gone":
		rate = 0.6
	_rot += rate * delta
	var beat := int(floorf(float(s["time"]) * PIXEL_FPS))
	if beat != _beat:
		_beat = beat
		_rot_q = _rot
	var want := strength
	if s["phase"] == "collapse" or s["phase"] == "gone":
		want = 0.0
	_swirl = lerpf(_swirl, maxf(want, 0.0), 1.0 - exp(-(4.0 if want > _swirl else 1.2) * delta))
	if int(s["hits"]) >= 3 and _snap_axis.is_empty():
		_take_snapshot()
	_water.queue_redraw()


func _take_snapshot() -> void:
	var axis_at: Callable = _s["axis_at"]
	var radius_at: Callable = _s["radius_at"]
	for k in 21:
		var f := float(k) / 20.0
		_snap_axis.append(axis_at.call(f))
		_snap_r.append(radius_at.call(f))
	_snap_time = _stepped()
	_snap_rot = _rot_q
	_snap_strength = maxf(float(_s["strength"]), 0.3)


# ======================================================================================
# Small tools
# ======================================================================================

static func _hash(i: float, k: float) -> float:
	var h := sin(i * 12.9898 + k * 78.233) * 43758.5453
	return h - floorf(h)


func _stepped() -> float:
	return floorf(float(_s["time"]) * PIXEL_FPS) / PIXEL_FPS


func _cell(local: Vector2) -> Vector2i:
	var w := _origin + local
	return Vector2i(floori(w.x / ART), floori(w.y / ART))


func _flush(canvas: CanvasItem, cells: Dictionary) -> void:
	for key: Vector2i in cells:
		canvas.draw_rect(Rect2(Vector2(key) * ART - _origin, Vector2(ART, ART)), cells[key])


static func _with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


static func _steps3(v: float) -> float:
	if v > 0.66:
		return 1.0
	if v > 0.33:
		return 0.66
	if v > 0.02:
		return 0.33
	return 0.0


func _axis(f: float) -> Vector2:
	if not _snap_axis.is_empty():
		var x := clampf(f, 0.0, 1.0) * 20.0
		var i := mini(int(x), 19)
		return _snap_axis[i].lerp(_snap_axis[i + 1], x - float(i))
	return (_s["axis_at"] as Callable).call(f)


func _radius(f: float) -> float:
	if not _snap_r.is_empty():
		var x := clampf(f, 0.0, 1.0) * 20.0
		var i := mini(int(x), 19)
		return lerpf(_snap_r[i], _snap_r[i + 1], x - float(i))
	return (_s["radius_at"] as Callable).call(f)


func _strength() -> float:
	if not _snap_axis.is_empty():
		return _snap_strength
	return maxf(float(_s["strength"]), 0.0)


## The foot mound's half-width.
func _foot_rx() -> float:
	return _radius(0.0) * 1.8 + 11.0 * sqrt(_strength())


## The drawn radius: the harness's cone, flared at the neck into a skirt that meets the mound,
## so the funnel plunges into the foam instead of standing on a thread.
func _rdraw(f: float) -> float:
	var r := _radius(f)
	var skirt := maxf(_foot_rx() * 0.72 - _radius(0.0), 0.0)
	var k := maxf(1.0 - f / 0.24, 0.0)
	return r + skirt * k * k


func _ring(f: float, a: float, r: float) -> Vector2:
	return _axis(f) + Vector2(cos(a) * r, sin(a) * r * 0.5)


## Which stepped frame of a hit we are on, 0-5, or -1 (never for the third net).
func _hit_step() -> int:
	var hits := int(_s["hits"])
	var since: float = _s["since_hit"]
	if hits < 1 or hits >= 3 or since < 0.0 or since >= 0.75:
		return -1
	return int(floorf(since * PIXEL_FPS))


## Seconds since the third net landed, stepped at 8 fps; -1 before it.
func _collapse_t() -> float:
	if int(_s["hits"]) < 3:
		return -1.0
	var ct := float(_s["collapse"]) * COLLAPSE_LONG
	if _s["phase"] == "gone":
		ct = COLLAPSE_LONG + float(_s["t"])
	return floorf(ct * PIXEL_FPS) / PIXEL_FPS


# ======================================================================================
# The draw
# ======================================================================================

func _draw() -> void:
	if _s.is_empty():
		return
	_origin = global_position
	var back := {}
	var front := {}
	var ink := {}
	var top := {}
	var strength: float = _s["strength"]
	var ct := _collapse_t()
	var hit := _hit_step()
	var alive: bool = strength > 0.02 and _s["phase"] != "gone"
	var funnel := (alive and ct < 0.0) or (ct >= 0.0 and ct < 0.125)
	if funnel:
		_strokes(back, front, ink)
		_wisps(back, front, ink)
	if hit >= 0 and hit <= 2:
		_burst(back, front, ink, hit)
	if alive and ct < 0.0:
		_flecks(back, front)
	if (alive and ct < 0.0) or (ct >= 0.0 and ct < SLUMP):
		_collar(back, front, ink)
	if ct >= 0.125:
		_gusts(front, ink, ct)
	_flush(self, back)
	_draw_debris(false)
	if funnel and ct < 0.0:
		_haze(smoothstep(0.1, 1.7, float(_s["time"])) * 1.1)
	for key: Vector2i in front:
		ink.erase(key)
	_flush(self, ink)
	_flush(self, front)
	_draw_debris(true)
	if alive and ct < 0.0:
		_spit(top)
		_flung_trails(top)
		_flush(self, top)


# --- The haze ----------------------------------------------------------------------------

## A faint dark air mass inside the cone from above the mound up, the lower halves of the
## cross-sections only, so the top stays open. One tone, a fainter one for the top fifth.
func _haze(reach: float) -> void:
	var strength := _strength()
	var spans := {}
	var tops := {}
	var steps := int(float(_s["height"]) * strength / ART) + 2
	for k in steps + 1:
		var f := 0.12 + float(k) / float(steps) * 0.83
		if f > reach:
			break
		var c := _axis(f)
		var rx := _rdraw(f) * 0.9
		var ry := rx * 0.5
		var cy0 := _cell(c).y
		var cy1 := _cell(c + Vector2(0.0, ry)).y
		for y in range(cy0, cy1 + 1):
			var yy := (float(y) + 0.5) * ART - (_origin.y + c.y)
			var q := 1.0 - (yy * yy) / maxf(ry * ry, 0.01)
			if q <= 0.0:
				continue
			var half := rx * sqrt(q)
			var x0 := floori((_origin.x + c.x - half) / ART)
			var x1 := floori((_origin.x + c.x + half) / ART)
			if spans.has(y):
				var was: Vector2i = spans[y]
				spans[y] = Vector2i(mini(was.x, x0), maxi(was.y, x1))
				tops[y] = maxf(float(tops[y]), f)
			else:
				spans[y] = Vector2i(x0, x1)
				tops[y] = f
	var fade := _steps3(minf(strength * 2.5, 1.0))
	var body := _with_alpha(_ink, 0.18 * fade)
	var faint := _with_alpha(_ink, 0.09 * fade)
	for y: int in spans:
		var sp: Vector2i = spans[y]
		if sp.y - sp.x < 2:
			continue
		var col := faint if float(tops[y]) > 0.8 else body
		draw_rect(Rect2(Vector2(float(sp.x), float(y)) * ART - _origin, Vector2(float(sp.y - sp.x + 1), 1.0) * ART), col)


# --- Strokes -----------------------------------------------------------------------------

## The funnel's strokes. The first `LOW` are short flicks spread evenly over the neck; the rest
## are spread over the body by the golden ratio, a third of them flicks and the rest long
## sweeps, some of those fat. Each is born at its tail, shoots round (the head runs ahead) and
## is swallowed from the tail, on the 8 fps beat, while the crowd turns with `_rot_q`, the low
## ones faster.
func _strokes(back: Dictionary, front: Dictionary, ink: Dictionary) -> void:
	var strength := _strength()
	var ct := _collapse_t()
	var hit := _hit_step()
	var reach := smoothstep(0.1, 1.7, float(_s["time"])) * 1.15
	var clock := _stepped() if ct < 0.0 else _snap_time
	var rot := _rot_q if ct < 0.0 else _snap_rot
	var cap := 2.0
	var rm := 1.0
	var broken := hit >= 0 and hit <= 1
	if hit >= 2:
		cap = REGROW_CAP[hit - 2]
		rm = REGROW_R[hit - 2]
	var white := broken or ct >= 0.0
	for i in STROKES:
		var fi := float(i)
		var low := i < LOW
		var f0: float
		if low:
			f0 = (fi + _hash(fi, 1.0) * 0.8) / float(LOW) * 0.27 - 0.02
		else:
			f0 = 0.26 + fposmod(fi * 0.618034 + 0.05 * _hash(fi, 1.0), 1.0) * 0.62
		if ct < 0.0 and f0 > reach:
			continue
		if f0 > cap:
			continue
		if broken and _hash(fi, 17.0) < 0.6:
			continue
		if ct < 0.0 and not low and _hash(fi, 7.0) > 0.85 + strength * 0.3:
			continue
		var flick := low or _hash(fi, 2.0) < 0.33
		var span := (lerpf(0.6, 1.0, _hash(fi, 3.0)) if low else lerpf(0.4, 0.7, _hash(fi, 3.0)) if flick else lerpf(0.85, 1.35, _hash(fi, 3.0))) * PI
		var rise := lerpf(0.03, 0.07, _hash(fi, 4.0)) if flick else lerpf(0.08, 0.15, _hash(fi, 4.0))
		var period := lerpf(0.75, 1.1, _hash(fi, 5.0)) if flick else lerpf(1.0, 1.5, _hash(fi, 5.0))
		var life := fmod(clock / period + _hash(fi, 6.0), 1.0)
		var head := clampf(life / 0.4, 0.0, 1.0)
		var tail := clampf((life - 0.62) / 0.38, 0.0, 1.0)
		if ct >= 0.0:
			head = maxf(head, 0.6)
			tail = minf(tail, 0.15)
		if head - tail < 0.06:
			continue
		var turn := lerpf(1.4, 0.8, clampf(f0, 0.0, 1.0))
		var start := rot * turn + _hash(fi, 8.0) * TAU
		var wmax := 2 if flick and not low else 3
		if not flick and _hash(fi, 10.0) < 0.35:
			wmax = 4
		if _wide:
			wmax = mini(wmax + 1, 4)
		var gap := -1.0
		if not flick and _hash(fi, 11.0) < 0.45:
			gap = lerpf(0.3, 0.6, _hash(fi, 12.0))
		_arc(back, front, ink, f0, rise, start, span, tail, head, wmax, rm, 1.0, white, gap, 1.0)


## One stroke: an arc round the cone at height `f0` climbing `rise`, angle `a0` to `a0 + span`,
## shown from `tail` to `head` (0-1). Tapers from one pixel at both ends to `wmax` in the
## middle and to one at the limbs, where every stroke turns round the cone. `rm` scales the
## radius (the regrowth), `flare` opens it towards the head (the crown), `gap` cuts one short
## break along it (a dashed streak).
func _arc(
	back: Dictionary, front: Dictionary, ink: Dictionary, f0: float, rise: float, a0: float,
	span: float, tail: float, head: float, wmax: int, rm: float, fade: float, white: bool,
	gap: float, flare: float
) -> void:
	var r_mid := _rdraw(f0 + rise * 0.5) * rm
	var steps := maxi(int(span * (head - tail) * maxf(r_mid, 4.0) / (ART * 0.6)), 4)
	var seen := {}
	var was := Vector2.INF
	var ink_col := _with_alpha(_ink, 0.5 * fade)
	for k in steps + 1:
		var u := lerpf(tail, head, float(k) / float(steps))
		var a := a0 + span * u
		var f := f0 + rise * u
		var along := (u - tail) / maxf(head - tail, 0.001)
		if f > 1.02 or f < -0.03:
			was = Vector2.INF
			continue
		var r := _rdraw(f) * rm * lerpf(1.0, flare, along)
		var p := _ring(f, a, r)
		var dir := (p - was) if was != Vector2.INF else Vector2(-sin(a), cos(a) * 0.5)
		was = p
		if gap >= 0.0 and absf(along - gap) < 0.05:
			continue
		var c := _cell(p)
		if seen.has(c):
			continue
		seen[c] = true
		var taper := sin(PI * clampf(along, 0.0, 1.0))
		var lit := cos(a)
		if sin(a) > 0.0:
			# A band `n` cells deep: lit top row, body, shaded bottom row, then the ink.
			var n := clampi(int(roundf(1.0 + float(wmax - 1) * pow(taper, 0.7))), 1, wmax)
			if absf(lit) > 0.86:
				n = 1
			elif absf(lit) > 0.7:
				n = mini(n, 2)
			# Sunny side: white over foam; middle: foam over pale; shaded left: pale over shallow.
			var side := 0 if lit > 0.3 else (1 if lit > -0.45 else 2)
			if along < 0.22:
				side = mini(side + 1, 2)
			var top_c: Color = [_white, _foam, _pale][side]
			var body_c: Color = [_foam, _foam, _pale][side]
			var low_c: Color = [_pale, _pale, _shade][side]
			if along > 0.72 and lit > 0.0:
				top_c = _white
			if white:
				top_c = _white
				body_c = _white
				low_c = _foam
			var off := Vector2i(0, 1) if absf(dir.x) >= absf(dir.y) * 0.8 else Vector2i(1 if lit > 0.0 else -1, 0)
			front[c] = _with_alpha(top_c if n > 1 or lit > -0.4 else body_c, fade)
			for m in range(1, n):
				if not front.has(c + off * m):
					front[c + off * m] = _with_alpha(low_c if m == n - 1 else body_c, fade)
			ink[c + off * n] = ink_col
		elif f <= FAR_TOP and taper > 0.2:
			var far := _pale if along > 0.5 else _shade
			back[c] = _with_alpha(far, (0.42 if along > 0.5 else 0.32) * fade)


# --- The crown -----------------------------------------------------------------------

## Short wisps opening out past the top and hooking over; front halves only.
func _wisps(back: Dictionary, front: Dictionary, ink: Dictionary) -> void:
	var strength := _strength()
	var ct := _collapse_t()
	var hit := _hit_step()
	if strength < 0.25 or (hit >= 0 and hit < 5):
		return
	var clock := _stepped() if ct < 0.0 else _snap_time
	var rot := _rot_q if ct < 0.0 else _snap_rot
	for i in WISPS:
		var fi := float(i) + 100.0
		var period := lerpf(0.9, 1.4, _hash(fi, 4.0))
		var life := fmod(clock / period + _hash(fi, 5.0), 1.0)
		var head := clampf(life / 0.55, 0.0, 1.0)
		var tail := clampf((life - 0.45) / 0.55, 0.0, 1.0)
		if head - tail < 0.08:
			continue
		var f0 := lerpf(0.86, 0.94, _hash(fi, 1.0))
		var start := rot * 0.8 + _hash(fi, 6.0) * TAU
		var span := lerpf(0.5, 0.9, _hash(fi, 2.0)) * PI
		var wmax := 4 if _wide else 3
		_arc({}, front, ink, f0, 0.06, start, span, tail, head, wmax, 1.0, 1.0, ct >= 0.0, -1.0,
			lerpf(1.2, 1.4, _hash(fi, 3.0)))


# --- The hit ---------------------------------------------------------------------------

## The startled puff: a starburst of short thick dashes flying straight off the cone at four
## heights, all round, for the break's two stepped frames and a third of flecks.
func _burst(back: Dictionary, front: Dictionary, ink: Dictionary, step: int) -> void:
	var dashes := 18
	for k in dashes:
		var fk := float(k)
		var f := float([0.2, 0.45, 0.68, 0.88][k % 4])
		var a := fk * TAU / float(dashes) + 0.4 * _hash(fk, 60.0) + _rot_q
		var r := _rdraw(f)
		var out := Vector2(cos(a), sin(a) * 0.5).normalized()
		var go := float(BURST_GO[step]) * lerpf(0.8, 1.35, _hash(fk, 61.0))
		var tip := _ring(f, a, r) + out * go
		var n: int = BURST_LONG[step]
		var is_front := sin(a) > -0.25
		var col := _white if step < 2 else _foam
		for m in n:
			var q := tip - out * float(m) * ART
			var c := _cell(q)
			if is_front:
				front[c] = col
				if step < 2:
					var off := Vector2i(0, 1) if absf(out.x) > 0.6 else Vector2i(1, 0)
					if not front.has(c + off):
						front[c + off] = _foam if m < n - 1 else _pale
					ink[c + off * 2] = _with_alpha(_ink, 0.5)
			else:
				back[c] = _with_alpha(_pale, 0.5)


# --- The collapse ------------------------------------------------------------------------

## The funnel bursts into long gusts: each leaves the funnel's silhouette as it stood when the
## third net landed and flies straight out with the spin's lean, two pixels thick and hooked
## upward at its head; whole for four stepped frames, then two steps fainter, then gone.
func _gusts(front: Dictionary, ink: Dictionary, ct: float) -> void:
	var fade := 1.0 if ct < 0.5 else (0.66 if ct < 0.625 else (0.33 if ct < 0.75 else 0.0))
	if fade <= 0.0:
		return
	for k in GUSTS:
		var fk := float(k) + 300.0
		var f := 0.08 + 0.84 * (float(k) + 0.5 * _hash(fk, 1.0)) / float(GUSTS)
		# Mostly off the two sides, a few off the front and back diagonals.
		var side := 0.0 if k % 2 == 0 else PI
		var a := side + lerpf(-0.75, 0.75, _hash(fk, 2.0))
		var r := _rdraw(f)
		var start := _ring(f, a, r)
		var out := Vector2(cos(a), sin(a) * 0.5).normalized()
		var tangent := Vector2(-sin(a), cos(a) * 0.5).normalized()
		var dir := (out + tangent * 0.45 + Vector2(0.0, -0.12)).normalized()
		var dist := (1.0 - exp(-ct * 3.2)) * lerpf(70.0, 125.0, _hash(fk, 3.0))
		var long := lerpf(8.0, 14.0, _hash(fk, 4.0)) * minf(1.0, 0.45 + ct * 3.0)
		var tip := start + dir * dist
		var bend := Vector2(-dir.y, dir.x)
		if bend.y > 0.0:
			bend = -bend
		var n := int(long)
		var last_c := Vector2i.MAX
		for m in n * 2:
			var t := float(m) / float(n * 2)
			var q := tip - dir * t * long * ART + bend * sin(PI * t) * 3.0
			var c := _cell(q)
			if c == last_c:
				continue
			last_c = c
			var lit := dir.x > 0.0
			var col := _white if (lit and t < 0.5) else (_foam if t < 0.7 else _pale)
			front[c] = _with_alpha(col, fade)
			var off := Vector2i(0, 1) if absf(dir.x) >= absf(dir.y) * 0.8 else Vector2i(1 if dir.x > 0.0 else -1, 0)
			if t > 0.08 and t < 0.85 and not front.has(c + off):
				front[c + off] = _with_alpha(_pale if t < 0.5 else _shade, fade)
			ink[c + off * 2] = _with_alpha(_ink, 0.45 * fade)
		if _hash(fk, 5.0) < 0.65:
			_hook(front, ink, tip, dir, 5.0 + 2.0 * _hash(fk, 6.0), _with_alpha(_white, fade), fade)


## A cartoon hook: the line turns up and over, an open C, never a closed loop.
func _hook(cells: Dictionary, ink: Dictionary, at: Vector2, dir: Vector2, r: float, colour: Color, fade: float) -> void:
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var n := Vector2(-d.y, d.x)
	if n.y > 0.0:
		n = -n
	var turn_sign := 1.0 if d.cross(n) > 0.0 else -1.0
	var centre := at + n * r
	var from := at - centre
	var steps := int(r * 2.5)
	for k in steps:
		var t := float(k) / float(steps) * PI * 0.85
		var p := centre + from.rotated(t * turn_sign) * (1.0 - t * 0.12)
		var c := _cell(p)
		cells[c] = colour
		if t < PI * 0.5:
			if not cells.has(c + Vector2i(0, 1)):
				cells[c + Vector2i(0, 1)] = _with_alpha(_foam, fade)
			ink[c + Vector2i(0, 2)] = _with_alpha(_ink, 0.45 * fade)


# --- Flecks ----------------------------------------------------------------------------

## Leaves and foam flecks swept up inside the cone, turning round it: foam low, leaves tumbling
## (four stepped poses) higher up.
func _flecks(back: Dictionary, front: Dictionary) -> void:
	var strength := _strength()
	var time: float = _s["time"]
	var ts := _stepped()
	for i in FLECKS:
		var fi := float(i) + 200.0
		if _hash(fi, 7.0) > strength * 1.1:
			continue
		var period := lerpf(1.4, 2.6, _hash(fi, 1.0))
		var u := fmod(time / period + _hash(fi, 2.0), 1.0)
		if u < 0.08 or u > 0.97:
			continue
		var f := u
		var a := _hash(fi, 3.0) * TAU + _rot * 1.1 + u * 3.0
		var r := _rdraw(f) * lerpf(0.4, 0.95, _hash(fi, 4.0))
		var p := _ring(f, a, r)
		var is_front := sin(a) > 0.0
		var cells: Dictionary = front if is_front else back
		var c := _cell(p)
		var leaf := _hash(fi, 5.0) < 0.5 and f > 0.2
		if leaf:
			var lit := _leaf_lit if is_front else _with_alpha(_leaf_lit, 0.66)
			var dark := _leaf if is_front else _with_alpha(_leaf, 0.66)
			match int(ts * PIXEL_FPS + _hash(fi, 6.0) * 4.0) % 4:
				0:
					cells[c] = lit
					cells[c + Vector2i(1, 0)] = dark
				1:
					cells[c] = lit
					cells[c + Vector2i(1, 1)] = dark
				2:
					cells[c] = dark
					cells[c + Vector2i(0, 1)] = lit
				_:
					cells[c] = lit
		else:
			cells[c] = _white if is_front else _with_alpha(_pale, 0.66)


# --- The foot --------------------------------------------------------------------------

## The foot: a filled mound of churning foam over the whole base ellipse, so the funnel
## plunges into it. Its top heaves in narrow spray peaks that taper to a pixel and climb into
## the neck's flicks, turning with the spin on the beat, each re-rolled every beat, the odd one
## flicking a bead off its tip. Lit along the top on the right, pale on the shaded left and at
## the waterline, speckled with churn, a shaded line on the water under it. A hit throws it
## wider and taller with a puff of foam; the collapse slumps it flat and wide.
func _collar(back: Dictionary, front: Dictionary, ink: Dictionary) -> void:
	var strength := _strength()
	var step_i := floorf(_stepped() * PIXEL_FPS)
	var hit := _hit_step()
	var ct := _collapse_t()
	var kick := 0.0
	if hit >= 0 and hit <= 2:
		kick = float([1.0, 0.7, 0.35][hit])
	var slump := 1.0
	var rx := _foot_rx() * (1.0 + kick * 0.25)
	if ct >= 0.0:
		slump = clampf(1.0 - ct / SLUMP, 0.0, 1.0)
		rx *= 1.0 + ct * 1.3
	if slump <= 0.0:
		return
	var ry := rx * 0.45
	var root := sqrt(strength)
	var hm := (6.0 + 8.0 * kick) * root * slump
	# Scallops: small round bubbles of foam along the top, turning on the beat.
	var bub := 5.0 * root * slump
	# Spray peaks round the ring, turning on the beat, each re-rolled every beat.
	var peaks := 9
	var px := PackedFloat32Array()
	var ph := PackedFloat32Array()
	var pw := PackedFloat32Array()
	for k in peaks:
		var fk := float(k)
		var ang := _rot_q * 1.3 + fk * TAU / float(peaks) + 0.35 * _hash(fk, 40.0)
		if sin(ang) < -0.2:
			continue
		px.append(cos(ang) * rx * 0.8)
		ph.append(lerpf(2.0, 7.0, _hash(fk, step_i + 41.0)) * root * slump * (1.0 + kick * 0.8))
		pw.append(lerpf(2.0, 3.5, _hash(fk, 50.0)) * ART)
	var cx0 := _cell(Vector2(-rx, 0.0)).x
	var cx1 := _cell(Vector2(rx, 0.0)).x
	for cx in range(cx0, cx1 + 1):
		var lx := (float(cx) + 0.5) * ART - _origin.x
		var e := clampf(lx / rx, -1.0, 1.0)
		var q := 1.0 - e * e
		if q <= 0.0:
			continue
		var sq := sqrt(q)
		var peak := 0.0
		for k in px.size():
			var d := absf(lx - px[k]) / pw[k]
			if d < 1.0:
				peak = maxf(peak, ph[k] * (1.0 - d) * (1.0 - d * 0.3))
		var sc := fposmod(lx + _rot_q * 10.0, 12.0) / 12.0
		var scallop := bub * sqrt(maxf(1.0 - (sc * 2.0 - 1.0) * (sc * 2.0 - 1.0), 0.0))
		var top := -ry * sq * 0.25 - hm * pow(sq, 0.5) - scallop * sq - peak
		var ybot := _cell(Vector2(lx, ry * sq)).y
		var ytop := _cell(Vector2(lx, top)).y
		var rows := maxi(ybot - ytop, 1)
		for y in range(ytop, ybot + 1):
			var v := float(y - ytop) / float(rows)
			# Light from the upper right: white cap, foam body, pale lower third, shallow waterline;
			# the shaded left a step darker all the way down.
			var idx := 1 if v < 0.65 else 2
			if y <= ytop and e > 0.15:
				idx = 0
			if y >= ybot:
				idx = 3
			if e < -0.4 and idx > 0:
				idx += 1
			# Churn: cells drop a step on the beat, so the mound seethes.
			if idx < 3 and _hash(float(cx) * 1.3 + float(y), step_i + 7.0) < 0.2:
				idx += 1
			front[Vector2i(cx, y)] = _ladder[mini(idx, 4)]
		ink[Vector2i(cx, ybot + 1)] = _with_alpha(_ink, 0.45)
		ink[Vector2i(cx, ybot + 2)] = _with_alpha(_ink, 0.2)
	_jets(back, front, ink, rx, ry, hm, root * slump * (1.0 + kick * 0.7), step_i)
	if kick > 0.0:
		_puff(back, front, rx, ry, hit)


## Spray jets out of the mound: tapering columns of foam leaning outward with the spin, three
## pixels at the root to one at the tip, a bead flicked off the tallest; rolled every beat.
func _jets(back: Dictionary, front: Dictionary, ink: Dictionary, rx: float, ry: float, hm: float, power: float, step_i: float) -> void:
	var jets := 12
	for k in jets:
		var fk := float(k) + 700.0
		var ang := _rot_q * 1.1 + fk * TAU / float(jets) + 0.5 * _hash(fk, 1.0)
		var tall := lerpf(5.0, 24.0, _hash(fk, step_i)) * power
		if tall < 4.0 or _hash(fk, step_i + 2.0) < 0.2:
			continue
		var is_front := sin(ang) > -0.15
		var root_p := Vector2(cos(ang) * rx * 0.78, sin(ang) * ry * 0.6 - hm - 2.0)
		var out := Vector2(cos(ang), 0.0)
		var tangent := Vector2(-sin(ang), 0.0)
		var d := (Vector2(0.0, -1.0) + out * 0.55 + tangent * 0.35).normalized()
		var n := int(tall / ART)
		for m in n:
			var t := float(m) / float(maxi(n - 1, 1))
			var p := root_p + d * float(m) * ART + Vector2(out.x * t * t * 5.0, 0.0)
			var c := _cell(p)
			var wide := 3 if t < 0.4 else (2 if t < 0.75 else 1)
			for w in wide:
				var cc := c + Vector2i(w - wide / 2, 0)
				var col := _white if (w == wide - 1 or t > 0.6) else (_foam if t > 0.2 else _pale)
				if is_front:
					front[cc] = col
				else:
					back[cc] = _with_alpha(col, 0.7)
			if is_front and m == 0:
				ink[c + Vector2i(0, 1)] = _with_alpha(_ink, 0.3)
		if tall > 20.0:
			var tip := root_p + d * (float(n) + 2.5) * ART + Vector2(out.x * 7.0, 0.0)
			(front if is_front else back)[_cell(tip)] = _white


## A hit's puff off the foot: round blobs of foam jumping up and out, shrinking each frame.
func _puff(back: Dictionary, front: Dictionary, rx: float, ry: float, step: int) -> void:
	var blobs := 7
	for k in blobs:
		var fk := float(k) + 500.0
		var ang := fk * TAU / float(blobs) + _hash(fk, 1.0) * 0.6
		var out := Vector2(cos(ang), sin(ang) * 0.5).normalized()
		var at := Vector2(cos(ang) * rx, sin(ang) * ry) + out * (6.0 + 12.0 * float(step)) \
			- Vector2(0.0, 10.0 + 9.0 * float(step) - 4.0 * float(step * step))
		var rad := float([7.0, 5.0, 3.0][step]) * lerpf(0.8, 1.2, _hash(fk, 2.0))
		var cells: Dictionary = front if sin(ang) > -0.3 else back
		var c0 := _cell(at)
		var n := int(ceilf(rad / ART))
		for y in range(-n, n + 1):
			for x in range(-n, n + 1):
				if Vector2(x, y).length() * ART > rad:
					continue
				var col := _white if y < 0 and x >= -1 else (_foam if y < n - 1 else _pale)
				cells[c0 + Vector2i(x, y)] = col if cells == front else _with_alpha(col, 0.6)


## Water spat out of the foot: bursts of single beads thrown out along the spin, arcing and
## falling back, a new burst every fifth of a second.
func _spit(cells: Dictionary) -> void:
	var strength: float = _s["strength"]
	var time: float = _s["time"]
	if strength < 0.2:
		return
	var foot := _foot_rx() * 0.9
	var now := floorf(time * 5.0)
	for back_by in 4:
		var b := now - float(back_by)
		var age := time - b / 5.0
		if age < 0.0:
			continue
		for k in 4:
			var fk := float(k)
			var a := _hash(b, fk) * TAU
			var speed := lerpf(60.0, 130.0, _hash(b, fk + 10.0)) * strength
			var up := lerpf(90.0, 160.0, _hash(b, fk + 20.0)) * strength
			var ground := Vector2(cos(a) * foot, sin(a) * foot * 0.45)
			var outward := Vector2(cos(a), sin(a) * 0.5)
			var tangent := Vector2(-sin(a), cos(a) * 0.5)
			var move := (outward * 0.8 + tangent * 0.7) * speed * age
			var h := up * age - 0.5 * 520.0 * age * age
			if h < 0.0:
				continue
			cells[_cell(ground + move - Vector2(0.0, h))] = _white


# --- What it carries --------------------------------------------------------------------

## The carried rubbish, one side of the funnel, back to front, each piece with a two-pixel
## wind line trailing it round its orbit so its circling reads.
func _draw_debris(is_front: bool) -> void:
	var list: Array = []
	for d: Dictionary in _s.get("debris", []):
		if bool(d["front"]) == is_front:
			list.append(d)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["depth"]) < float(b["depth"]))
	for d: Dictionary in list:
		if d["state"] == "orbit":
			var trail := {}
			var a: float = d["angle"]
			var r: float = d["radius"]
			var local: Vector2 = d["local"]
			var centre := local - Vector2(cos(a) * r, sin(a) * r * 0.5)
			var def: TrashDef = d["def"]
			var clear := maxf(def.size.x, def.size.y) * 0.5 + 3.0
			var from := a - clear / maxf(r, 1.0)
			var steps := int(r * 0.8 / ART) + 3
			for k in steps:
				var t := float(k) / float(steps - 1)
				var aa := from - t * 0.8
				var p := centre + Vector2(cos(aa) * r, sin(aa) * r * 0.5)
				if (sin(aa) > 0.0) != is_front:
					continue
				var c := _cell(p)
				if is_front:
					var col := _white if t < 0.3 else (_foam if t < 0.65 else _pale)
					trail[c] = col
					if t < 0.65 and not trail.has(c + Vector2i(0, 1)):
						trail[c + Vector2i(0, 1)] = _pale if t < 0.3 else _shade
				else:
					trail[c] = _with_alpha(_pale, 0.45)
			_flush(self, trail)
		DebrisDraw.draw_piece(self, d["def"], d["local"], float(d["rot"]), float(d["scale"]), float(d["alpha"]))


## A short swoosh of air behind every flung piece, along the arc it has just flown.
func _flung_trails(cells: Dictionary) -> void:
	for f: Dictionary in _s.get("flung", []):
		var dur: float = f["dur"]
		var t: float = f["t"]
		if t > dur * 0.85:
			continue
		for k in 6:
			var back_t := t - 0.025 * float(k + 2)
			if back_t < 0.0:
				break
			var u := clampf(back_t / dur, 0.0, 1.0)
			var ground: Vector2 = (f["from"] as Vector2).lerp(f["to"], u)
			var h := float(f["h0"]) * pow(1.0 - u, 1.4) + float(f["peak"]) * 4.0 * u * (1.0 - u)
			var p := ground - Vector2(0.0, h) - position
			cells[_cell(p)] = _white if k < 2 else (_foam if k < 4 else _pale)


# ======================================================================================
# The water under it (a child at z 4: over the splash rings, under the rubbish)
# ======================================================================================

func _draw_water(on: Node2D) -> void:
	if _s.is_empty():
		return
	_origin = global_position
	var phase: String = _s["phase"]
	var time: float = _s["time"]
	var ts := _stepped()
	var ct := _collapse_t()
	var gone_t: float = _s["t"] if phase == "gone" else 0.0
	var spread := 1.0 + clampf(ct, 0.0, 1.5) * 0.5 + gone_t * 0.25
	var fade := 1.0
	if phase == "gone":
		fade = 0.66 if gone_t < 0.5 else (0.33 if gone_t < 1.1 else 0.0)
	var grow := smoothstep(0.0, 1.2, time)
	var sw := maxf(_swirl, 0.0)
	if fade <= 0.0 or grow <= 0.0:
		return
	var step_i := floorf(ts * PIXEL_FPS)
	var ink_a := clampf(float(_s.get("ink", 0.3)), 0.2, 0.34)
	var foot_rx := _foot_rx()
	var foot_ry := foot_rx * 0.45
	# The wind-darkened water: one tone of the day's shadow ink over a ragged ellipse, its rim
	# nibbled per cell on the beat, left clear under the foam mound. The funnel's shadow sits
	# in the same map, a step deeper, so the two never stack.
	var patch := {}
	var size := grow * lerpf(0.6, 1.0, maxf(sw, 0.5 if ct >= 0.0 else 0.0)) * spread
	var rx := 112.0 * size
	var ry := rx * 0.5
	var rows := int(ry / ART)
	var c0 := _cell(Vector2.ZERO)
	var tone := _with_alpha(_ink, ink_a * fade)
	var clear_mound: bool = ct < SLUMP and (_s["strength"] > 0.05 or ct >= 0.0)
	for y in range(-rows, rows + 1):
		var yy := (float(y) + 0.5) * ART
		var k := 1.0 - (yy * yy) / (ry * ry)
		if k <= 0.0:
			continue
		var wob := 1.0 + 0.10 * sin(float(y) * 0.9 + ts * 3.0) + 0.06 * sin(float(y) * 2.3 - ts * 5.0)
		var half := int(rx * sqrt(k) * wob / ART)
		for x in range(-half, half + 1):
			if absi(x) >= half - 1 and _hash(float(x) + float(y) * 3.1, step_i) < 0.45:
				continue
			if clear_mound:
				var xx := (float(x) + 0.5) * ART
				if (xx * xx) / (foot_rx * foot_rx) + (yy * yy) / (foot_ry * foot_ry) < 0.9:
					continue
			patch[c0 + Vector2i(x, y)] = tone
	if _s["strength"] > 0.05 and phase != "gone" and ct < 0.0:
		_shadow(patch, _with_alpha(_ink, minf(ink_a + 0.08, 0.42) * fade))
	_flush(on, patch)
	# Chop: little crests of lit water across the patch, flickering on the beat.
	var chop := {}
	var crest := _with_alpha(_shade, 0.66 * fade)
	var cells_x := int(rx / ART / 4.0)
	var cells_y := int(ry / ART / 3.0)
	for gy in range(-cells_y, cells_y + 1):
		for gx in range(-cells_x, cells_x + 1):
			var h := _hash(float(gx) + 0.37 * step_i, float(gy) * 1.7 + step_i * 0.13)
			if h > 0.24:
				continue
			var local := Vector2(float(gx) * 4.0 * ART, float(gy) * 3.0 * ART)
			var e := Vector2(local.x / rx, local.y / ry)
			if e.length() > 0.92 or e.length() < 0.4:
				continue
			var c := _cell(local)
			chop[c] = crest
			chop[c + Vector2i(1 if e.y < 0.0 else -1, 0)] = crest
	_flush(on, chop)
	# The slumped mound, a torn ring of foam spreading on the water after the collapse.
	if ct >= SLUMP and ct < 1.4:
		var ring := {}
		var rr := foot_rx * (1.0 + ct * 1.3)
		var ra := 1.0 if ct < 0.875 else (0.66 if ct < 1.125 else 0.33)
		var n := int(rr * 1.2)
		for m in n:
			var a := float(m) / float(n) * TAU
			if _hash(floorf(float(m) / 3.0), step_i + 90.0) < 0.3:
				continue
			var p := Vector2(cos(a) * rr, sin(a) * rr * 0.45)
			var c := _cell(p)
			var col := _white if sin(a) > 0.0 and cos(a) > -0.3 else _foam
			ring[c] = _with_alpha(col, ra)
			if sin(a) > 0.0:
				ring[c + Vector2i(0, 1)] = _with_alpha(_pale, ra)
		_flush(on, ring)
	# The foam spiral: two arms on a log spiral, a turn and three quarters from the foot out,
	# the gap between turns growing. Each arm leads with a thick bright head at the foot,
	# thins to one pixel, and breaks into flecks at its outer tail; the whole turns a clear
	# step every beat, the outer end trailing.
	var foam := {}
	var show := sw
	if ct >= 0.0 or phase == "gone":
		show = 1.0
	if show < 0.05:
		return
	var r_in := foot_rx * 0.95 * spread
	var trough := _with_alpha(_ink, 0.35 * fade)
	var r_out := 150.0 * size
	var turns := 1.1 * TAU
	var kk := log(maxf(r_out / r_in, 1.1)) / turns
	for j in 2:
		var th := 0.0
		var idx := 0
		while th < turns:
			var u := th / turns
			if u > show * 1.05:
				break
			var r := r_in * exp(kk * th)
			var a := _rot_q * 0.95 + float(j) * PI - th
			th += ART * 0.7 / r
			idx += 1
			var s_along := u * 9.0 - ts * 2.0 + float(j) * 0.37
			var duty := lerpf(1.0, 0.45, smoothstep(0.6, 1.0, u))
			if fposmod(s_along, 1.0) > duty:
				continue
			var p := Vector2(cos(a) * r, sin(a) * r * 0.5)
			var c := _cell(p)
			var col := _white if u < 0.3 else (_foam if u < 0.62 else _pale)
			var alpha := fade * (1.0 if u < 0.8 else 0.66)
			var outward := Vector2(cos(a), sin(a))
			var off := Vector2i(0, 1 if outward.y > 0.0 else -1) if absf(outward.y) > 0.45 else Vector2i(1 if outward.x > 0.0 else -1, 0)
			var thick := 3 if u < 0.35 else (2 if u < 0.7 else 1)
			foam[c] = _with_alpha(col, alpha)
			for m in range(1, thick):
				var cc := c - off * m
				if not foam.has(cc) or foam[cc] == trough:
					foam[cc] = _with_alpha(_foam if (m == 1 and u < 0.3) else _pale, alpha)
			# The trough in front of the crest: a line of shadow on its outer side.
			if u < 0.85 and not foam.has(c + off):
				foam[c + off] = trough
			if u > 0.6 and idx % 5 == 0 and _hash(float(idx) + float(j) * 97.0, step_i) < 0.5:
				var jit := Vector2i(int(_hash(float(idx), 3.0) * 5.0) - 2, int(_hash(float(idx), 4.0) * 3.0) - 1)
				foam[c + jit] = _with_alpha(_pale, alpha * 0.66)
	_flush(on, foam)


## The funnel's shadow: its axis laid on the water along the day's lean and stretch (the sun
## is to the right, so it falls down-left), a band half as wide as the funnel.
func _shadow(cells: Dictionary, col: Color) -> void:
	var lean: float = _day.lean if _day != null else -0.2
	var stretch: float = _day.stretch if _day != null else 0.42
	for k in 60:
		var f := 0.08 + float(k) / 59.0 * 0.92
		var ax := _axis(f)
		var h := -ax.y
		var at := Vector2(ax.x + lean * h, stretch * 0.5 * h)
		var w := _rdraw(f) * 0.55
		var y := _cell(at).y
		var x0 := _cell(at - Vector2(w, 0.0)).x
		var x1 := _cell(at + Vector2(w, 0.0)).x
		for x in range(x0, x1 + 1):
			if cells.has(Vector2i(x, y)):
				cells[Vector2i(x, y)] = col


class _WaterLayer:
	extends Node2D
	var look: Node2D

	func _draw() -> void:
		if look != null:
			look._draw_water(self)
