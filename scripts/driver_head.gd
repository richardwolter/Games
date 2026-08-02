## The driver's head, drawn rather than loaded.
##
## The sprite it replaces came off the asset sheet badly: a lumpy jaw, a brow at
## the wrong angle, one eye reading as a hole, and a stray grey triangle where
## the cut had taken part of the neighbouring drawing with it. At the size it
## renders — about nineteen world units, smaller than a tyre — none of that could
## be fixed by nudging the extraction, and every one of those faults was a shape
## error rather than a pixel error.
##
## So it is drawn in the same recipe as everything else in this game: flat fills,
## one heavy ink outline, no gradients. Which also means it costs no texture, it
## scales cleanly at any zoom, and the cap can be recoloured from a constant.
##
## The origin is the NECK, not the middle of the head, so the parent can rotate
## this node directly and get a nod instead of a spin.
class_name DriverHead
extends Node2D

## Head radius in world units. Everything else is a fraction of this, so the
## whole head resizes from one number.
@export var radius: float = 9.0
@export var skin: Color = Color("e0a878")
@export var skin_shade: Color = Color("c98a5c")
## A trucker cap, in the game's own mustard. It reads instantly at this size —
## far better than hair, which at nineteen units is a brown smudge — and it puts
## the driver in the same palette as the crates he is driving over.
@export var cap: Color = Color("d8892f")
@export var cap_shade: Color = Color("a8641c")
@export var ink: Color = Color("141414")

## Outline weight, as a fraction of the radius. Constant in proportion, so the
## line stays the right heaviness whatever the head is scaled to.
const OUTLINE := 0.16


func _draw() -> void:
	var r := radius
	var line := r * OUTLINE

	# Neck first, so the head's outline closes over the top of it.
	_ink_poly(PackedVector2Array([
		Vector2(-r * 0.30, 0.0),
		Vector2(r * 0.30, 0.0),
		Vector2(r * 0.26, -r * 0.55),
		Vector2(-r * 0.26, -r * 0.55),
	]), skin_shade, line)

	var centre := Vector2(0.0, -r)
	# The skull, very slightly egg-shaped: a perfect circle reads as a ball.
	_ink_poly(_oval(centre, r * 0.96, r), skin, line)

	# Ear, set back and low, half tucked behind the jaw line.
	_ink_circle(centre + Vector2(-r * 0.42, r * 0.06), r * 0.24, skin_shade, line * 0.7)

	# The cap: crown over the top half, then a peak jutting forward. Drawn after
	# the ear so it sits over the hairline the way a cap does.
	var crown := PackedVector2Array()
	for i in 13:
		var a: float = PI + PI * float(i) / 12.0
		crown.append(centre + Vector2(cos(a), sin(a)) * Vector2(r * 1.02, r * 1.06))
	crown.append(centre + Vector2(r * 0.98, r * 0.02))
	crown.append(centre + Vector2(-r * 0.98, r * 0.02))
	_ink_poly(crown, cap, line)

	# Peak, forward and slightly down — level with the brow, which is what makes
	# it read as a cap rather than as a hat brim.
	_ink_poly(PackedVector2Array([
		Vector2(centre.x + r * 0.10, centre.y - r * 0.12),
		Vector2(centre.x + r * 1.62, centre.y - r * 0.02),
		Vector2(centre.x + r * 1.58, centre.y + r * 0.20),
		Vector2(centre.x + r * 0.10, centre.y + r * 0.18),
	]), cap_shade, line * 0.8)

	# A band where the cap meets the head, so the two are not one silhouette.
	draw_line(
		centre + Vector2(-r * 0.94, r * 0.02),
		centre + Vector2(r * 0.86, -r * 0.04),
		cap_shade, line * 0.9
	)

	# Face, in profile facing right — one eye, one brow, a nose and a mouth. Any
	# more than this is invisible at nineteen units and only muddies the read.
	var eye := centre + Vector2(r * 0.44, -r * 0.02)
	draw_circle(eye, r * 0.155, ink)
	draw_line(
		centre + Vector2(r * 0.20, -r * 0.30),
		centre + Vector2(r * 0.68, -r * 0.34),
		ink, line * 0.8
	)

	# Nose: a small wedge off the front of the face, not a triangle floating
	# beside it — it shares the profile edge, which is what the old sprite got
	# wrong and why that grey shape read as damage.
	_ink_poly(PackedVector2Array([
		Vector2(centre.x + r * 0.82, centre.y + r * 0.02),
		Vector2(centre.x + r * 1.16, centre.y + r * 0.24),
		Vector2(centre.x + r * 0.78, centre.y + r * 0.32),
	]), skin, line * 0.7)

	draw_line(
		centre + Vector2(r * 0.50, r * 0.50),
		centre + Vector2(r * 0.82, r * 0.46),
		ink, line * 0.75
	)

	# Jaw shadow under the chin, the one bit of shading, so the head has a
	# underside and doesn't read as a flat coin.
	draw_line(
		centre + Vector2(-r * 0.42, r * 0.74),
		centre + Vector2(r * 0.46, r * 0.66),
		skin_shade, line * 1.1
	)


## A filled shape with the house outline: the ink pass is a closed polyline
## rather than a scaled-up copy, so corners stay sharp and the line is even.
func _ink_poly(points: PackedVector2Array, fill: Color, width: float) -> void:
	draw_colored_polygon(points, fill)
	var ring := PackedVector2Array(points)
	ring.append(points[0])
	draw_polyline(ring, ink, width, true)


func _ink_circle(at: Vector2, r: float, fill: Color, width: float) -> void:
	draw_circle(at, r, fill)
	draw_arc(at, r, 0.0, TAU, 18, ink, width, true)


func _oval(centre: Vector2, half_x: float, half_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 22:
		var a: float = TAU * float(i) / 22.0
		points.append(centre + Vector2(cos(a) * half_x, sin(a) * half_y))
	return points
