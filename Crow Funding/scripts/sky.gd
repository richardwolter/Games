@tool
extends Node2D
## Sky director: drives the backdrop gradient through dawn/midday/sunset/night and
## draws the sun, moon, and stars over the run. Shows the morning state (phase 0)
## in the 2D editor, matching the @tool city and balcony.

signal phase_changed(p: float)

const Envs = preload("res://scripts/environments.gd")

const DESIGN_SIZE := Vector2(1152, 648)
const HORIZON := 300.0

const PALETTE_KEYFRAMES: Array[float] = [0.0, 0.32, 0.66, 1.0]
# 3 gradient stops (top, middle, bottom) at each keyframe: dawn, midday, sunset,
# night. Paper tones rather than sky colours: the ink city multiplies over this, so
# the whole page warms, yellows and darkens like paper under changing light.
const PALETTES: Array = [
	[Color(0.9, 0.9, 0.88), Color(0.97, 0.93, 0.86), Color(0.98, 0.9, 0.8)],
	[Color(0.95, 0.95, 0.93), Color(0.98, 0.97, 0.93), Color(0.98, 0.96, 0.9)],
	[Color(0.86, 0.8, 0.78), Color(0.96, 0.82, 0.68), Color(0.97, 0.78, 0.6)],
	[Color(0.2, 0.21, 0.27), Color(0.27, 0.28, 0.35), Color(0.33, 0.33, 0.4)],
]
const INK := Color(0.08, 0.08, 0.09)
# Engraved sun and moon (art/scene/sun.png, moon.png). The Sky node draws before
# the City, whose sky is cut away, so both set behind the buildings.
const SUN_TEX := preload("res://art/scene/sun.png")
const MOON_TEX := preload("res://art/scene/moon.png")
const SUN_SIZE := 78.0
const MOON_SIZE := 58.0
# Modern city: bold graphic shapes instead of engravings - a flat disc and a sharp
# crescent, poster-like, with an ink ring. Light pollution leaves few stars.
const MODERN_STAR_COUNT := 6
const SUN_RAMP: Array[Color] = [
	Color(1.0, 0.9, 0.62),
	Color(1.0, 0.72, 0.38),
	Color(1.0, 0.45, 0.2),
]

@export var backdrop_path: NodePath = NodePath("../Backdrop")

var phase := 0.0
var _elapsed := 0.0
var _tween: Tween
var _gradient: Gradient = null
var _stars: Array[Vector2] = []
var _env: String = Envs.CLASSIC

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_build_stars()
	_env = Envs.current(self)
	Envs.watch(self, _on_env)
	if not Engine.is_editor_hint():
		var backdrop := get_node_or_null(backdrop_path) as TextureRect
		if backdrop != null and backdrop.texture is GradientTexture2D:
			var tex := backdrop.texture.duplicate(true) as GradientTexture2D
			backdrop.texture = tex
			_gradient = tex.gradient
			_update_gradient()
	queue_redraw()

func _on_env(id: String) -> void:
	_env = id
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_elapsed += delta
	queue_redraw()

func _build_stars() -> void:
	if _stars.size() > 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	for i in 28:
		_stars.append(Vector2(rng.randf_range(0.03, 0.97), rng.randf_range(0.02, 0.44)))

func run_day(duration: float) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_method(_set_phase, 0.0, 1.0, maxf(0.2, duration)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func force_night() -> void:
	_kill_tween()
	_set_phase(1.0)

func reset_day() -> void:
	_kill_tween()
	_set_phase(0.0)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

func _set_phase(p: float) -> void:
	phase = clampf(p, 0.0, 1.0)
	_update_gradient()
	phase_changed.emit(phase)
	queue_redraw()

func _update_gradient() -> void:
	if _gradient == null:
		return
	if _gradient.offsets.size() != 3:
		_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	for stop in 3:
		_gradient.set_color(stop, _sample_palette(stop))

func _sample_palette(stop: int) -> Color:
	var keys := PALETTE_KEYFRAMES
	for i in keys.size() - 1:
		var a: float = keys[i]
		var b: float = keys[i + 1]
		if phase <= b:
			var t := clampf((phase - a) / maxf(0.0001, b - a), 0.0, 1.0)
			var c1: Color = PALETTES[i][stop]
			var c2: Color = PALETTES[i + 1][stop]
			return c1.lerp(c2, smoothstep(0.0, 1.0, t))
	return PALETTES[-1][stop]

func _draw() -> void:
	var view := DESIGN_SIZE
	_draw_stars(view)
	_draw_moon(view)
	_draw_sun(view)

func _draw_stars(view: Vector2) -> void:
	var alpha := clampf((phase - 0.6) / 0.35, 0.0, 1.0)
	if alpha <= 0.01:
		return
	var count := _stars.size() if _env == Envs.CLASSIC else MODERN_STAR_COUNT
	for i in count:
		var pos: Vector2 = _stars[i]
		var tw := 0.7 + 0.3 * sin(_elapsed * 2.0 + float(i) * 1.7)
		var p := Vector2(pos.x * view.x, pos.y * view.y)
		var col := Color(0.96, 0.95, 0.9, alpha * tw)
		# a little pen cross, like a doodled star
		draw_line(p - Vector2(2.5, 0), p + Vector2(2.5, 0), col, 1.2)
		draw_line(p - Vector2(0, 2.5), p + Vector2(0, 2.5), col, 1.2)

func _draw_sun(view: Vector2) -> void:
	var t := phase
	# low over the rooftops at dawn, up through the day, down behind the city
	# around sunset (0.8); kept in the open middle of the sky, clear of the HUD
	var u := clampf((t + 0.1) / 0.9, 0.0, 1.0)
	var x := lerpf(view.x * 0.24, view.x * 0.8, u)
	var h := sin(u * PI) * 230.0 - 30.0
	var pos := Vector2(x, HORIZON - h)
	var alpha := clampf((h + 60.0) / 40.0, 0.0, 1.0)
	if alpha <= 0.01:
		return
	# paper-white disc warmed by the time of day; the rays stay ink
	var tint := Color.WHITE.lerp(_sample_ramp(SUN_RAMP, t), 0.55)
	tint.a = alpha
	var size := lerpf(SUN_SIZE, SUN_SIZE * 1.12, t)
	if _env == Envs.MODERN:
		_draw_flat_sun(pos, size * 0.42, t, alpha)
		return
	var rot := _elapsed * 0.03
	draw_set_transform(pos, rot, Vector2.ONE)
	draw_texture_rect(SUN_TEX, Rect2(-size * 0.5, -size * 0.5, size, size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_moon(view: Vector2) -> void:
	var t := phase
	# rises behind the city after sunset and climbs to mid-sky by full night
	var u := clampf((t - 0.55) / 0.9, 0.0, 1.0)
	var x := lerpf(view.x * 0.82, view.x * 0.5, u * 2.0)
	var h := sin(u * PI) * 200.0 - 30.0
	var pos := Vector2(x, HORIZON - h)
	var alpha := 1.0 if t > 0.55 else 0.0
	if alpha <= 0.01:
		return
	if _env == Envs.MODERN:
		_draw_flat_moon(pos, MOON_SIZE * 0.4, alpha)
		return
	draw_texture_rect(MOON_TEX, Rect2(pos - Vector2(MOON_SIZE, MOON_SIZE) * 0.5, Vector2(MOON_SIZE, MOON_SIZE)), false, Color(0.97, 0.96, 0.9, alpha))

# A flat disc: solid paper-warm fill, a clean ink ring, and one offset ring echo
# like a screen-print misregistration.
func _draw_flat_sun(pos: Vector2, r: float, t: float, alpha: float) -> void:
	var fill := _sample_ramp(SUN_RAMP, t).lerp(Color.WHITE, 0.15)
	fill.a = alpha
	draw_circle(pos + Vector2(4, 3), r, Color(INK, 0.18 * alpha))
	draw_circle(pos, r, fill)
	draw_arc(pos, r, 0.0, TAU, 64, Color(INK, alpha), 2.5, true)
	draw_arc(pos, r + 7.0, -0.4, 1.9, 32, Color(INK, 0.8 * alpha), 2.0, true)

# A sharp crescent: the outer disc minus an offset disc, traced as one polygon -
# the outer circle where it clears the cut, then the cut circle back inside it.
func _draw_flat_moon(pos: Vector2, r: float, alpha: float) -> void:
	var off := Vector2(r * 0.5, -r * 0.25)
	var c2 := pos + off
	var r2 := r * 0.92
	var base := (-off).angle()
	var n := 48
	var pts := PackedVector2Array()
	for k in range(-n, n + 1):
		var a := base + PI * float(k) / n
		var q := pos + Vector2(cos(a), sin(a)) * r
		if q.distance_to(c2) >= r2:
			pts.append(q)
	for k in range(n, -n - 1, -1):
		var a := base + PI * float(k) / n
		var q := c2 + Vector2(cos(a), sin(a)) * r2
		if q.distance_to(pos) < r:
			pts.append(q)
	if pts.size() < 3:
		return
	draw_colored_polygon(pts, Color(0.97, 0.96, 0.9, alpha))
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, Color(INK, alpha), 2.0, true)

func _sample_ramp(ramp: Array, t: float) -> Color:
	var p := clampf(t, 0.0, 1.0) * float(ramp.size() - 1)
	var i := clampi(int(floor(p)), 0, ramp.size() - 2)
	var f := p - float(i)
	var c1: Color = ramp[i]
	var c2: Color = ramp[i + 1]
	return c1.lerp(c2, f)