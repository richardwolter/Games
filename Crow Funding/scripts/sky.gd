@tool
extends Node2D
## Sky director: drives the backdrop gradient through dawn/midday/sunset/night and
## draws the sun, moon, and stars over the run. Shows the morning state (phase 0)
## in the 2D editor, matching the @tool city and balcony.

signal phase_changed(p: float)

const DESIGN_SIZE := Vector2(1152, 648)
const HORIZON := 300.0

const PALETTE_KEYFRAMES: Array[float] = [0.0, 0.32, 0.66, 1.0]
# 3 gradient stops (top, middle, bottom) at each keyframe: dawn, midday, sunset, night.
const PALETTES: Array = [
	[Color(0.58, 0.76, 0.9), Color(0.99, 0.85, 0.66), Color(1.0, 0.72, 0.5)],
	[Color(0.55, 0.78, 0.92), Color(0.95, 0.88, 0.74), Color(0.98, 0.8, 0.58)],
	[Color(0.4, 0.35, 0.62), Color(0.93, 0.5, 0.42), Color(1.0, 0.6, 0.3)],
	[Color(0.05, 0.05, 0.17), Color(0.1, 0.08, 0.25), Color(0.17, 0.13, 0.32)],
]
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

func _ready() -> void:
	_build_stars()
	if not Engine.is_editor_hint():
		var backdrop := get_node_or_null(backdrop_path) as TextureRect
		if backdrop != null and backdrop.texture is GradientTexture2D:
			var tex := backdrop.texture.duplicate(true) as GradientTexture2D
			backdrop.texture = tex
			_gradient = tex.gradient
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
	for i in _stars.size():
		var pos: Vector2 = _stars[i]
		var tw := 0.7 + 0.3 * sin(_elapsed * 2.0 + float(i) * 1.7)
		var col := Color(1.0, 1.0, 0.95, alpha * tw)
		draw_rect(Rect2(pos.x * view.x, pos.y * view.y, 2.2, 2.2), col, true)

func _draw_sun(view: Vector2) -> void:
	var t := phase
	var x := lerpf(view.x * 0.2, view.x * 0.76, t)
	var h := lerpf(210.0, -30.0, smoothstep(0.0, 1.0, t))
	var pos := Vector2(x, HORIZON - h)
	var col := _sample_ramp(SUN_RAMP, t)
	var alpha := clampf((h + 40.0) / 60.0, 0.0, 1.0)
	if alpha <= 0.01:
		return
	col.a = alpha
	var r := lerpf(24.0, 16.0, t)
	draw_circle(pos, r * 1.7, Color(col.r, col.g, col.b, alpha * 0.22))
	draw_circle(pos, r, col)

func _draw_moon(view: Vector2) -> void:
	var t := phase
	var x := lerpf(view.x * 0.78, view.x * 0.24, t)
	var h := lerpf(-180.0, 220.0, smoothstep(0.0, 1.0, t))
	var pos := Vector2(x, HORIZON - h)
	var alpha := clampf((t - 0.5) / 0.3, 0.0, 1.0) * 0.92
	if alpha <= 0.01:
		return
	draw_circle(pos, 42.0, Color(0.9, 0.94, 1.0, alpha * 0.16))
	draw_circle(pos, 22.0, Color(0.92, 0.95, 1.0, alpha))
	draw_circle(pos + Vector2(-7, -5), 4.6, Color(0.8, 0.85, 0.95, alpha * 0.7))
	draw_circle(pos + Vector2(8, 7), 3.2, Color(0.8, 0.85, 0.95, alpha * 0.6))

func _sample_ramp(ramp: Array, t: float) -> Color:
	var p := clampf(t, 0.0, 1.0) * float(ramp.size() - 1)
	var i := clampi(int(floor(p)), 0, ramp.size() - 2)
	var f := p - float(i)
	var c1: Color = ramp[i]
	var c2: Color = ramp[i + 1]
	return c1.lerp(c2, f)