extends Control
## One sprite drawn the way the battlefield draws it — on paper, standing on a
## ground line, at a real pixel height — so a sprite can be judged before it is
## rigged into a scene.
##
## Anchoring mirrors the two conventions the field actually uses:
##   BASE   — LaneField._draw_prop_sprite: bottom edge on the ground line.
##   CENTER — LaneField._draw_obstacle_sprite / Combatant._draw: centred.

## Not named `Anchor`, and the property below not `anchor_mode` — Control
## already owns both names.
enum AnchorMode { BASE, CENTER }

const GROUND_INSET := 18.0

var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()

## Drawn height in design-canvas pixels. The player sees this at 0.67x.
var draw_height := 140.0:
	set(v):
		draw_height = v
		queue_redraw()

var preview_anchor: AnchorMode = AnchorMode.BASE:
	set(v):
		preview_anchor = v
		queue_redraw()

var show_ground := true:
	set(v):
		show_ground = v
		queue_redraw()

## Thundaar's 67px collision radius drawn behind the art — he is the widest
## thing that must fit down a lane (ART_BIBLE), so he is the size everything
## else is judged against.
var show_reference := false:
	set(v):
		show_reference = v
		queue_redraw()

const REFERENCE_RADIUS := 67.0

## Tight bounds of the sprite's non-transparent pixels, in TEXTURE pixel space.
## Zero-size means "not measured" and the bounds overlay stays off.
var opaque_rect := Rect2():
	set(v):
		opaque_rect = v
		queue_redraw()

## Draws what the art actually occupies (dashed) against the circle the game
## actually collides with (solid). The gap between them is transparent margin
## the unit is paying for — see Combatant._collision_radius, which spans the
## full image square, padding included.
var show_bounds := false:
	set(v):
		show_bounds = v
		queue_redraw()

## Off for UI/menu art, where a collision circle means nothing.
var collides := true

## Units (heroes, minions, villains) get a proposed OVAL footprint hugging the
## opaque art instead of the circle that currently spans the whole image square.
var is_unit := false:
	set(v):
		is_unit = v
		queue_redraw()

## How much of the art the oval wraps. 1.0 touches the art's bounding box;
## below that it sits inside it — "covers most of the sprite, but not all".
var oval_coverage := 0.85:
	set(v):
		oval_coverage = v
		queue_redraw()

var show_oval := false:
	set(v):
		show_oval = v
		queue_redraw()

const ELLIPSE_SEGMENTS := 48

const DASH_LEN := 7.0

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, UIStyle.PAGE_SOLID)
	var ground_y := size.y - GROUND_INSET
	if show_ground:
		draw_line(Vector2(6.0, ground_y), Vector2(size.x - 6.0, ground_y),
				UIStyle.RULE, 2.0)
	if show_reference:
		var ref_center := Vector2(size.x * 0.5, ground_y - REFERENCE_RADIUS)
		draw_circle(ref_center, REFERENCE_RADIUS, Color(UIStyle.RULE, 0.35))
	if texture == null:
		return
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var draw_size := Vector2(tex_size.x * (draw_height / tex_size.y), draw_height)
	var pos: Vector2
	match preview_anchor:
		AnchorMode.BASE:
			pos = Vector2(size.x * 0.5 - draw_size.x * 0.5, ground_y - draw_size.y)
		_:
			pos = size * 0.5 - draw_size * 0.5
	# Combatant.SPRITE_ALPHA — units and decor both draw at this paper-cutout
	# alpha, so previewing fully opaque would read darker than the game does.
	draw_texture_rect(texture, Rect2(pos, draw_size), false,
			Color(1.0, 1.0, 1.0, Combatant.SPRITE_ALPHA))
	if show_bounds and opaque_rect.size.x > 0.0:
		_draw_bounds_overlay(Rect2(pos, draw_size), tex_size)
	if show_oval and is_unit and opaque_rect.size.x > 0.0:
		_draw_oval_overlay(Rect2(pos, draw_size), tex_size)
	draw_rect(r, UIStyle.INK_MUTED, false, 2.0)

## `drawn` is where the full image landed on screen; `tex_size` its native size.
func _draw_bounds_overlay(drawn: Rect2, tex_size: Vector2) -> void:
	if collides:
		# Mirrors Combatant._draw / LaneField._draw_obstacle_sprite: art is
		# scaled so the LONGEST image edge spans the collision diameter, so the
		# circle circumscribes the whole image square — margin included.
		var radius := maxf(drawn.size.x, drawn.size.y) * 0.5
		draw_arc(drawn.get_center(), radius, 0.0, TAU, 48, UIStyle.DANGER, 2.0, true)
	var scale_v := drawn.size / tex_size
	var box := Rect2(drawn.position + opaque_rect.position * scale_v,
			opaque_rect.size * scale_v)
	_draw_dashed_rect(box, UIStyle.GOOD, 2.0)

## The proposed unit footprint: an axis-aligned oval centred on the ART, not on
## the padded image, so it tracks what is actually drawn.
func _draw_oval_overlay(drawn: Rect2, tex_size: Vector2) -> void:
	var scale_v := drawn.size / tex_size
	var box := Rect2(drawn.position + opaque_rect.position * scale_v,
			opaque_rect.size * scale_v)
	var radii := box.size * 0.5 * oval_coverage
	_draw_ellipse(box.get_center(), radii, UIStyle.INFO, 2.5)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in ELLIPSE_SEGMENTS + 1:
		var a := TAU * float(i) / float(ELLIPSE_SEGMENTS)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_polyline(pts, color, width, true)

func _draw_dashed_rect(rect: Rect2, color: Color, width: float) -> void:
	var corners := [rect.position, rect.position + Vector2(rect.size.x, 0.0),
			rect.end, rect.position + Vector2(0.0, rect.size.y)]
	for i in 4:
		_draw_dashed_line(corners[i], corners[(i + 1) % 4], color, width)

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var span := to - from
	var length := span.length()
	if length <= 0.0:
		return
	var step := span / length * DASH_LEN
	var i := 0
	while i * DASH_LEN < length:
		# Every other dash skipped, and the last one clipped to the true end so
		# a corner never overshoots into the neighbouring edge.
		if i % 2 == 0:
			var a := from + step * i
			var b := from + step * minf(float(i + 1), length / DASH_LEN)
			draw_line(a, b, color, width)
		i += 1
