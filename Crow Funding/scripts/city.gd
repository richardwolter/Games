@tool
extends Node2D
## Pen-and-ink skyline seen from the balcony, sky cut away by tools/skyline_art.py.
## Drawn opaque over the Sky node, so the sun and moon set behind the buildings.
## Its paper takes the colour of the lower sky and darkens at night.
##
## Night lights depend on the environment (scripts/environments.gd):
## - classic: warm window glows baked into art/scene/city_lights.png.
## - modern: live layers read from art/scene/city_modern_lights.json - window grids
##   switching on and off, flickering neon signs, red aviation blinkers, traffic
##   streaks and a glow off the streets. Neon is the one place colour other than
##   the scarves shows up, so it stays saturated (the scarves are pastel) and
##   below the balcony line.

const Envs = preload("res://scripts/environments.gd")

const DESIGN_SIZE := Vector2(1152, 648)
const HORIZON := 300.0
# How dark the ink page gets at full night (the lights stay bright).
const NIGHT_SHADE := Color(0.34, 0.35, 0.44)

# Per environment: the drawing, and where its own horizon sits from its top edge
# (the value tools/skyline_art.py prints).
const ART := {
	Envs.CLASSIC: {"city": "res://art/scene/city.png", "lights": "res://art/scene/city_lights.png", "horizon": 141.0},
	Envs.MODERN: {"city": "res://art/scene/city_modern.png", "lights_json": "res://art/scene/city_modern_lights.json", "horizon": 141.0},
}

const WINDOW_COLS: Array[Color] = [Color(1.0, 0.86, 0.55), Color(1.0, 0.93, 0.78), Color(0.78, 0.88, 1.0)]
const NEON_COLS: Array[Color] = [Color(1.0, 0.16, 0.55), Color(0.1, 0.85, 1.0), Color(1.0, 0.32, 0.12), Color(0.62, 0.3, 1.0)]
const BLINK_COL := Color(1.0, 0.12, 0.08)

@export var sky_path: NodePath = NodePath("../Sky")

var _phase := 0.0
var _time := 0.0
var _lights: Node2D
var _env: String = Envs.CLASSIC
var _city_tex: Texture2D
var _lights_tex: Texture2D
var _tex_horizon := 141.0
var _data := {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _lights == null:
		_lights = Node2D.new()
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_lights.material = mat
		_lights.draw.connect(_draw_lights)
		add_child(_lights, false, Node.INTERNAL_MODE_BACK)
	_load_env(Envs.current(self))
	Envs.watch(self, _load_env)

func _load_env(id: String) -> void:
	_env = id
	var art: Dictionary = ART[id]
	_city_tex = load(art["city"])
	_lights_tex = load(art["lights"]) if art.has("lights") else null
	_tex_horizon = art["horizon"]
	_data = {}
	if art.has("lights_json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(art["lights_json"]))
		if parsed is Dictionary:
			_data = parsed
			_tex_horizon = float(_data.get("horizon", _tex_horizon))
	queue_redraw()
	_lights.queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _env != Envs.MODERN:
		return
	_time += delta
	_lights.queue_redraw()

## p is the sky phase: 0 dawn, 0.32 midday, 0.66 sunset, 1 night.
func set_night(p: float) -> void:
	_phase = clampf(p, 0.0, 1.0)
	queue_redraw()
	if _lights != null:
		_lights.queue_redraw()

func _night_weight() -> float:
	return smoothstep(0.62, 0.95, _phase)

func _paper_tint() -> Color:
	var sky := get_node_or_null(sky_path)
	var tint := Color.WHITE
	if sky != null and sky.has_method("_sample_palette"):
		tint = sky._sample_palette(1)
		tint = tint.lerp(Color.WHITE, 0.35 * (1.0 - _night_weight()))
	return tint * Color.WHITE.lerp(NIGHT_SHADE, _night_weight() * 0.6)

func _origin() -> Vector2:
	return Vector2(0.0, HORIZON - _tex_horizon)

func _draw() -> void:
	if _city_tex != null:
		draw_texture(_city_tex, _origin(), _paper_tint())

func _draw_lights() -> void:
	var w := _night_weight()
	if _env == Envs.MODERN:
		_draw_modern_lights(w)
		return
	if w <= 0.01 or _lights_tex == null:
		return
	_lights.draw_texture(_lights_tex, _origin(), Color(1, 1, 1, w))

# Cheap stable hash in [0, 1) for per-item randomness that does not need state.
func _h(a: int, b: int) -> float:
	var n := (a * 73856093) ^ (b * 19349663)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65536.0

func _draw_modern_lights(w: float) -> void:
	var o := _origin()
	var c := _lights
	# glow rising off the streets: a band along the bottom of the city
	if w > 0.01:
		var y1 := DESIGN_SIZE.y
		var y0 := o.y + _tex_horizon + 20.0
		var warm := Color(1.0, 0.55, 0.25, 0.0)
		var hot := Color(1.0, 0.55, 0.25, 0.28 * w)
		c.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(DESIGN_SIZE.x, y0), Vector2(DESIGN_SIZE.x, y1), Vector2(0, y1)]),
			PackedColorArray([warm, warm, hot, hot]))
	# window grids: each window keeps its own slow on/off rhythm, and more of
	# them are on as the evening deepens
	if w > 0.01:
		var wins: Array = _data.get("windows", [])
		for i in wins.size():
			var r: Array = wins[i]
			var period := 6.0 + _h(i, 1) * 14.0
			var slot := int(floor((_time + _h(i, 2) * period) / period))
			var on_chance := lerpf(0.15, 0.55, w)
			if _h(i, slot + 7) > on_chance:
				continue
			var col: Color = WINDOW_COLS[int(_h(i, 3) * WINDOW_COLS.size())]
			col.a = w * (0.75 + 0.25 * _h(i, 4))
			c.draw_rect(Rect2(o + Vector2(r[0], r[1]), Vector2(r[2], r[3])), col)
	# neon signs: a tube outline and a soft glow, each flickering on its own
	if w > 0.01:
		var signs: Array = _data.get("neon", [])
		for i in signs.size():
			var s: Array = signs[i]
			var rect := Rect2(o + Vector2(s[0], s[1]), Vector2(s[2], s[3]))
			var col: Color = NEON_COLS[int(s[4]) % NEON_COLS.size()]
			var flick := 1.0
			var beat := int(floor(_time * 12.0))
			if _h(i, int(floor(_time * 0.5))) < 0.3 and _h(i, beat) < 0.35:
				flick = 0.15
			var a := w * flick
			for g in 3:
				var grow := 2.0 + g * 3.0
				c.draw_rect(rect.grow(grow), Color(col, 0.1 * a), false, 3.0)
			c.draw_rect(rect, Color(col, 0.25 * a))
			c.draw_rect(rect, Color(col.lerp(Color.WHITE, 0.4), 0.95 * a), false, 1.5)
			# a few tube strokes inside, read as lettering at this size
			var tube := Color(col.lerp(Color.WHITE, 0.55), 0.9 * a)
			var n := int(rect.size.x / 7.0)
			for k in n:
				var lx := rect.position.x + 3.0 + k * (rect.size.x - 6.0) / maxf(1.0, n - 1)
				var tall := 0.35 + 0.5 * _h(i * 31 + k, 9)
				c.draw_line(Vector2(lx, rect.end.y - 2.0), Vector2(lx, rect.end.y - 2.0 - (rect.size.y - 4.0) * tall), tube, 1.2)
	# aviation blinkers: slow red pulses on tower tops and cranes, from dusk
	var bw := smoothstep(0.5, 0.8, _phase)
	if bw > 0.01:
		var blinks: Array = _data.get("blinkers", [])
		for i in blinks.size():
			var b: Array = blinks[i]
			var t := fmod(_time * 0.8 + _h(i, 5), 1.0)
			var pulse := clampf(1.0 - t * 4.0, 0.0, 1.0)
			if pulse <= 0.0:
				continue
			var p := o + Vector2(b[0], b[1])
			c.draw_circle(p, 5.0, Color(BLINK_COL, 0.25 * pulse * bw))
			c.draw_circle(p, 1.8, Color(BLINK_COL, pulse * bw))
	# traffic: headlights one way, tail lights the other, along street lines
	if w > 0.01:
		var streets: Array = _data.get("streets", [])
		for i in streets.size():
			var st: Array = streets[i]
			var x0: float = st[0]
			var x1: float = st[2]
			var y: float = st[1]
			var span := x1 - x0
			for k in 6:
				var speed := 30.0 + _h(i, k) * 40.0
				var dir := 1.0 if k % 2 == 0 else -1.0
				var u := fmod(_h(i, k + 20) * span + _time * speed, span)
				var x := x0 + (u if dir > 0.0 else span - u)
				var col := Color(1.0, 0.92, 0.7) if dir > 0.0 else Color(1.0, 0.2, 0.12)
				var p := o + Vector2(x, y + (0.0 if dir > 0.0 else 2.0))
				c.draw_line(p, p - Vector2(10.0 * dir, 0.0), Color(col, 0.55 * w), 1.5)
				c.draw_circle(p, 1.2, Color(col, 0.9 * w))
