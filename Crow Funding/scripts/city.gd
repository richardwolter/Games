@tool
extends Node2D
## Elevated balcony view of the city: layered rooftops receding below the horizon,
## drawn with flat cozy shapes. Windows glow warm at night via set_night().

const DESIGN_SIZE := Vector2(1152, 648)
const HORIZON := 300.0

var _blocks: Array[Dictionary] = []
var _night := 0.0

const FAR_TONES: Array[Color] = [
	Color(0.66, 0.7, 0.82),
	Color(0.74, 0.71, 0.83),
	Color(0.63, 0.74, 0.79),
]
const MID_TONES: Array[Color] = [
	Color(0.82, 0.68, 0.6),
	Color(0.78, 0.73, 0.63),
	Color(0.85, 0.75, 0.62),
]
const NEAR_TONES: Array[Color] = [
	Color(0.9, 0.74, 0.54),
	Color(0.86, 0.66, 0.48),
	Color(0.93, 0.8, 0.6),
]

func _ready() -> void:
	_build()
	queue_redraw()

func set_night(v: float) -> void:
	_night = clampf(v, 0.0, 1.0)
	queue_redraw()

func _build() -> void:
	_blocks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240614
	# far, mid, near layers - nearer layers are lower on screen and larger
	_build_layer(rng, 0.5, 30.0, 54.0, 306.0, 322.0, 336.0, 356.0, FAR_TONES)
	_build_layer(rng, 0.72, 56.0, 100.0, 336.0, 366.0, 396.0, 436.0, MID_TONES)
	_build_layer(rng, 1.0, 84.0, 148.0, 380.0, 424.0, 500.0, 524.0, NEAR_TONES)

func _build_layer(
	rng: RandomNumberGenerator,
	gap_scale: float,
	min_w: float, max_w: float,
	min_top: float, max_top: float,
	min_bot: float, max_bot: float,
	tones: Array,
) -> void:
	var x := -30.0
	var i := 0
	while x < DESIGN_SIZE.x + 60.0:
		var w := rng.randf_range(min_w, max_w)
		var top := rng.randf_range(min_top, max_top)
		var bottom := maxf(top + 18.0, rng.randf_range(min_bot, max_bot))
		var tone: Color = tones[rng.randi() % tones.size()]
		var seedv := 1000 + i * 61 + rng.randi() % 40
		_blocks.append({
			"x": x, "w": w, "top": top, "bottom": bottom,
			"col": tone, "seed": seedv, "near": bottom > 440.0,
		})
		x += w + rng.randf_range(8.0, 26.0) * gap_scale
		i += 1

func _hash(seedv: int, salt: int) -> int:
	var v := (seedv * 2654435761) ^ (salt * 97)
	v = (v ^ (v >> 13)) * 1274126177
	return int(abs(v)) % 10

func _draw() -> void:
	var night_col := Color(0.1, 0.08, 0.2)
	for b in _blocks:
		var bx: float = b["x"]
		var w: float = b["w"]
		var top: float = b["top"]
		var bottom: float = b["bottom"]
		var base: Color = b["col"]
		var near: bool = b["near"]
		var body := base.lerp(night_col, _night * 0.55)
		var roof := base.lightened(0.12).lerp(Color(0.16, 0.13, 0.24), _night * 0.55)
		var outline := base.darkened(0.28).lerp(Color(0.05, 0.04, 0.1), _night * 0.55)
		draw_rect(Rect2(bx, top, w, bottom - top), body, true)
		# roof / parapet edge (read from above)
		draw_rect(Rect2(bx, top, w, 6.0), roof, true)
		draw_rect(Rect2(bx, top + 6.0, w, 2.0), outline, true)
		if near:
			if _hash(b["seed"], 3) < 6:
				draw_rect(Rect2(bx + w * 0.24, top - 10.0, 12.0, 10.0), roof.darkened(0.12), true)
			if _hash(b["seed"], 5) < 6:
				draw_rect(Rect2(bx + w * 0.62, top - 14.0, 10.0, 14.0), roof.darkened(0.08), true)
		# windows that glow at night
		var cols := int((w - 10.0) / 18.0)
		var rows := int((bottom - top - 24.0) / 26.0)
		for cx in range(cols):
			for cy in range(rows):
				if _hash(b["seed"], cx * 31 + cy * 7) >= 6:
					continue
				var wx := bx + 6.0 + float(cx) * 16.0
				var wy := top + 16.0 + float(cy) * 24.0
				if _hash(b["seed"], cx + cy * 17) == 0:
					# golden window, bright and warm at night
					var glow := Color(1.0, 0.8, 0.42, 0.35 + clampf(_night * 1.1, 0.0, 0.9))
					draw_rect(Rect2(wx, wy, 5.0, 7.0), glow, true)
					if _night > 0.3:
						draw_rect(Rect2(wx - 1.0, wy - 1.0, 7.0, 9.0), Color(1.0, 0.75, 0.35, _night * 0.14), true)
				else:
					# cool daytime glass, fades to murk at night
					var cool := Color(0.88, 0.9, 0.96, 0.12 + _night * 0.1)
					draw_rect(Rect2(wx, wy, 5.0, 7.0), cool, true)
