extends RefCounted
## Shared drawing helpers for the tornado (ported from tools/tornado_mock/debris_draw.gd). Every look draws its carried debris through
## `draw_debris`, so the pieces look the same whichever funnel they are orbiting, and the
## art-pixel shapes (`pixel_ellipse`, `pixel_ring`, `pixel_line`) so a look's own shapes land
## on the same 2 world px grid as the rest of the game.
##
## No class_name (the global class cache would need an editor import): preload it.
##
##   const DebrisDraw := preload("res://scripts/tornado_debris_draw.gd")
##   DebrisDraw.draw_debris(self, _s, false)   # the back half
##
## Every function takes the canvas it draws on (the node mid-`_draw`) and points in that
## canvas's LOCAL coordinates. The canvas must be a Node2D with no rotation or scale of its
## own (the looks and the harness's layers are): snapping to the world's art grid reads its
## global position for the offset.

const ART := 2.0


## The world's art grid, in the canvas's local coordinates: a local point moved onto the
## nearest whole art pixel of the world.
static func snap(canvas: Node2D, local: Vector2) -> Vector2:
	var origin := canvas.global_position
	var world := ((origin + local) / ART).round() * ART
	return world - origin


## A piece of rubbish, by its TrashDef's atlas and region, centred on `at` (local), turned
## `rot` radians, drawn at `scale` of its lake size and `alpha`. Glides: the centre is not
## snapped, like the haul's flights.
static func draw_piece(
	canvas: CanvasItem, def: TrashDef, at: Vector2, rot: float = 0.0, scale: float = 1.0,
	alpha: float = 1.0, tint: Color = Color.WHITE
) -> void:
	if def == null:
		return
	var colour := Color(tint.r, tint.g, tint.b, tint.a * alpha)
	canvas.draw_set_transform(at, rot, Vector2(scale, scale))
	if def.atlas != null:
		canvas.draw_texture_rect_region(def.atlas, Rect2(-def.size * 0.5, def.size), def.region, colour)
	else:
		def.stamp(canvas, colour)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A filled ellipse of whole art pixels, centred on `centre` (local), half-width `rx` and
## half-height `ry` in world px. Rows of one art pixel; each row's ends snapped to the grid.
static func pixel_ellipse(canvas: Node2D, centre: Vector2, rx: float, ry: float, colour: Color) -> void:
	if rx < 1.0 or ry < 0.5 or colour.a <= 0.0:
		return
	var c := snap(canvas, centre)
	var rows := maxi(int(round(ry / ART)), 1)
	for r in range(-rows, rows):
		var y := (float(r) + 0.5) * ART
		var f := 1.0 - (y * y) / (ry * ry)
		if f <= 0.0:
			continue
		var half := roundf(rx * sqrt(f) / ART) * ART
		if half < ART * 0.5:
			continue
		canvas.draw_rect(Rect2(c.x - half, c.y + float(r) * ART, half * 2.0, ART), colour)


## A soft-free shadow on the water: a flat 2:1 ellipse of whole art pixels, `half_w` wide and
## half that tall, in `colour` -- the one sun's water ink, `Shade.tint_on(day, Shade.On.WATER,
## fade)` (2026-10-02): the tornado used to keep a fixed blue-black of its own.
static func draw_shadow(canvas: Node2D, at: Vector2, half_w: float, colour: Color) -> void:
	pixel_ellipse(canvas, at, maxf(half_w, ART), maxf(half_w * 0.5, ART * 0.5), colour)
