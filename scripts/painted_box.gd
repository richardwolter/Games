## A painted surface, drawn rather than loaded.
##
## The dock's signs are hand-painted artwork cut from Buttons.jpg, but that sheet
## only ever contained buttons — there is no painted plate for a panel, a header
## strip or a settings knob, and every panel using a flat StyleBoxFlat is what
## made the chrome read as a different game from the signs sitting on it.
##
## So the plates are painted here instead, in the same recipe the sprites use: a
## flat fill, one heavy ink outline, a single lighting band along the top, and
## nothing else. The only additions are the two details the painted signs
## actually have — plank seams and steel bolt heads — which is what carries the
## "these belong together" read without needing new art.
##
## A StyleBox subclass rather than a custom Control, because that plugs straight
## into every PanelContainer and Button; a background node would mean rebuilding
## the layout around it at each of the four sites.
class_name PaintedBox
extends StyleBox

## Board grain, tin sign, or round bolt head. Which one a surface gets is a
## statement about what it is: boards are structure, signs are readouts, bolts
## are hardware.
enum Kind { BOARD, SIGN, BOLT }

var kind: Kind = Kind.BOARD
var fill: Color = UITheme.WOOD
## Corner rounding. Ignored by BOLT, which is a circle.
var radius: float = UITheme.RADIUS_PANEL
var border: float = UITheme.BORDER
## Steel bolt heads at the corners. The one detail that most reads as "painted
## prop" rather than "UI", so it's opt-in per surface and used sparingly.
var bolts: bool = false
## Number of plank seams across a BOARD. Zero draws a plain plate.
var planks: int = 0
## Paints a music note in the middle of the plate.
##
## Drawn rather than set as "♪" text: the glyph is U+266A, the default font is
## not guaranteed to carry it, and a tofu box in the corner of the screen is a
## worse failure than any amount of drawing code.
var note: bool = false

## How far in from the corner a bolt head sits, and how big it is.
const BOLT_INSET := 11.0
const BOLT_RADIUS := 4.0
## Strength of the top lighting band, as a fraction of the plate's height.
const LIGHT_BAND := 0.34


static func board(fill_color: Color = UITheme.WOOD, plank_count: int = 3) -> PaintedBox:
	var box := PaintedBox.new()
	box.kind = Kind.BOARD
	box.fill = fill_color
	box.planks = plank_count
	# Content clears the bolt heads horizontally. Only the horizontal margin has
	# to grow: the bolts live in the left and right gutters, so anything starting
	# past them is clear of the pair on that side top and bottom alike.
	box.bolts = plank_count > 0
	box.set_margins(20.0 if box.bolts else 12.0, 12)
	return box


## A tin readout plate: same outline, no grain, with a cream keyline inset that
## the boards don't have — so a sign never gets mistaken for a surface you can
## put something on.
static func sign(fill_color: Color = UITheme.MUSTARD) -> PaintedBox:
	var box := PaintedBox.new()
	box.kind = Kind.SIGN
	box.fill = fill_color
	box.radius = UITheme.RADIUS
	box.bolts = true
	box.set_margins(20, 6)
	return box


## A small painted plate: the sign treatment without the bolts.
##
## Bolts are 11px in from each corner, which on anything button-sized puts four
## steel dots inside the lettering — the reason the first pass at the settings
## control read as clutter rather than as hardware. Under about 120x50, a plate
## is just a plate.
static func plate(fill_color: Color) -> PaintedBox:
	var box := PaintedBox.new()
	box.kind = Kind.SIGN
	box.fill = fill_color
	box.radius = UITheme.RADIUS
	box.bolts = false
	box.set_margins(10, 6)
	return box


static func bolt(fill_color: Color = UITheme.STEEL) -> PaintedBox:
	var box := PaintedBox.new()
	box.kind = Kind.BOLT
	box.fill = fill_color
	box.set_margins(2, 2)
	return box


func set_margins(horizontal: float, vertical: float) -> void:
	content_margin_left = horizontal
	content_margin_right = horizontal
	content_margin_top = vertical
	content_margin_bottom = vertical


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	match kind:
		Kind.BOLT:
			_draw_bolt(to_canvas_item, rect)
		Kind.SIGN:
			_draw_plate(to_canvas_item, rect, true)
		_:
			_draw_plate(to_canvas_item, rect, false)


## The shared plate: fill, top lighting band, grain or keyline, outline, bolts.
##
## Order matters — the lighting band and the seams are drawn inside the silhouette
## and then the outline goes over the top, so neither can bleed past the edge the
## way they would if the outline were laid down first.
func _draw_plate(ci: RID, rect: Rect2, is_sign: bool) -> void:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var outline := _round_rect(rect, r)
	RenderingServer.canvas_item_add_polygon(ci, outline, _flat(outline.size(), fill))

	# One band of light along the top, the way every sprite in the set is lit.
	# Clipped to the plate by being inset past the corner radius rather than by a
	# scissor, which a StyleBox cannot set.
	var band := Rect2(
		rect.position + Vector2(r * 0.5, border),
		Vector2(rect.size.x - r, rect.size.y * LIGHT_BAND)
	)
	if band.size.y > 1.0:
		RenderingServer.canvas_item_add_rect(ci, band, Color(fill.lightened(0.13), 0.85))

	if is_sign:
		# A keyline just inside the edge — the enamel border a painted tin sign has.
		var inset := rect.grow(-(border + 3.0))
		if inset.size.x > 0.0 and inset.size.y > 0.0:
			var keyline := _round_rect(inset, maxf(r - 3.0, 1.0))
			keyline.append(keyline[0])
			RenderingServer.canvas_item_add_polyline(
				ci, keyline, _flat(keyline.size(), Color(UITheme.CREAM, 0.5)), 1.5
			)
	else:
		_draw_grain(ci, rect, r)

	outline.append(outline[0])
	RenderingServer.canvas_item_add_polyline(
		ci, outline, _flat(outline.size(), UITheme.INK), border
	)

	if note:
		_draw_note(ci, rect)

	if bolts:
		var inset := BOLT_INSET
		for corner: Vector2 in [
			rect.position + Vector2(inset, inset),
			Vector2(rect.end.x - inset, rect.position.y + inset),
			rect.end - Vector2(inset, inset),
			Vector2(rect.position.x + inset, rect.end.y - inset),
		]:
			_bolt_head(ci, corner, BOLT_RADIUS)


## Plank seams, running the long way so a wide dock reads as boards laid end to
## end and a tall panel as boards stacked. Each seam is a dark line with a light
## one under it: that pair is what makes it read as a gap between two boards
## rather than as a stripe painted on one.
func _draw_grain(ci: RID, rect: Rect2, r: float) -> void:
	if planks <= 1:
		return
	var horizontal := rect.size.x >= rect.size.y
	var span: float = rect.size.y if horizontal else rect.size.x
	var pad: float = r * 0.6
	for i in range(1, planks):
		var at: float = span * float(i) / float(planks)
		var from: Vector2
		var to: Vector2
		if horizontal:
			from = Vector2(rect.position.x + pad, rect.position.y + at)
			to = Vector2(rect.end.x - pad, rect.position.y + at)
		else:
			from = Vector2(rect.position.x + at, rect.position.y + pad)
			to = Vector2(rect.position.x + at, rect.end.y - pad)
		var step := Vector2(0, 1) if horizontal else Vector2(1, 0)
		RenderingServer.canvas_item_add_line(ci, from, to, Color(fill.darkened(0.42), 0.8), 2.0)
		RenderingServer.canvas_item_add_line(
			ci, from + step * 2.0, to + step * 2.0, Color(fill.lightened(0.18), 0.5), 1.0
		)


## A quaver: head, stem, flag. Cream on whatever the plate is, with the same
## squat proportions the sprites are drawn with — a slim engraved note would be
## the one hairline thing in a game with no hairlines.
func _draw_note(ci: RID, rect: Rect2) -> void:
	var unit: float = minf(rect.size.x, rect.size.y) * 0.42
	var centre := rect.get_center()
	var head := centre + Vector2(-unit * 0.24, unit * 0.44)
	RenderingServer.canvas_item_add_circle(ci, head, unit * 0.40, UITheme.CREAM)

	var stem_x: float = head.x + unit * 0.34
	var top := Vector2(stem_x, centre.y - unit * 0.78)
	RenderingServer.canvas_item_add_line(
		ci, Vector2(stem_x, head.y), top, UITheme.CREAM, unit * 0.20
	)
	# The flag, as two strokes: one out and one down, which reads as a hooked
	# pennant at 18px where a curve would just be a smudge.
	var elbow := top + Vector2(unit * 0.46, unit * 0.18)
	RenderingServer.canvas_item_add_line(ci, top, elbow, UITheme.CREAM, unit * 0.18)
	RenderingServer.canvas_item_add_line(
		ci, elbow, elbow + Vector2(-unit * 0.06, unit * 0.34), UITheme.CREAM, unit * 0.18
	)


## A steel bolt: ink ring, steel face, one highlight dot up-left. Same three-tone
## treatment as the bolts painted on the SALVAGE SHOP sign.
func _bolt_head(ci: RID, at: Vector2, size: float) -> void:
	RenderingServer.canvas_item_add_circle(ci, at, size + 1.5, UITheme.INK)
	RenderingServer.canvas_item_add_circle(ci, at, size, UITheme.STEEL)
	RenderingServer.canvas_item_add_circle(
		ci, at - Vector2(size, size) * 0.32, size * 0.34, UITheme.STEEL.lightened(0.45)
	)


## The settings knob: a bolt head blown up to button size, so the one control in
## the corner reads as hardware bolted to the frame rather than as a widget.
func _draw_bolt(ci: RID, rect: Rect2) -> void:
	var centre := rect.get_center()
	var size: float = minf(rect.size.x, rect.size.y) * 0.5 - border
	RenderingServer.canvas_item_add_circle(ci, centre, size + border, UITheme.INK)
	RenderingServer.canvas_item_add_circle(ci, centre, size, fill)
	RenderingServer.canvas_item_add_circle(
		ci, centre - Vector2(size, size) * 0.3, size * 0.42, fill.lightened(0.35)
	)
	# The hex flats, as a ring of short ink ticks — cheaper to read than a drawn
	# hexagon and it survives the button being scaled by the hover motion.
	for i in 6:
		var a: float = TAU * float(i) / 6.0 + PI / 12.0
		var dir := Vector2(cos(a), sin(a))
		RenderingServer.canvas_item_add_line(
			ci, centre + dir * (size * 0.72), centre + dir * (size * 0.94),
			Color(UITheme.INK, 0.5), 2.0
		)


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(border)


func _get_minimum_size() -> Vector2:
	var span := (BOLT_INSET + BOLT_RADIUS) * 2.0 if bolts else radius * 2.0
	return Vector2(span, span)


static func _flat(count: int, color: Color) -> PackedColorArray:
	var colors := PackedColorArray()
	colors.resize(count)
	colors.fill(color)
	return colors


## Corner-rounded outline as a point ring, shared by the fill polygon and the
## outline polyline so the two can never disagree about where the edge is.
static func _round_rect(rect: Rect2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	r = maxf(minf(r, minf(rect.size.x, rect.size.y) * 0.5), 0.0)
	var corners := [
		[rect.position + Vector2(r, r), PI, PI * 1.5],
		[Vector2(rect.end.x - r, rect.position.y + r), PI * 1.5, TAU],
		[rect.end - Vector2(r, r), 0.0, PI * 0.5],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5, PI],
	]
	const STEPS := 5
	for corner: Array in corners:
		for i in STEPS + 1:
			var a: float = lerpf(corner[1], corner[2], float(i) / float(STEPS))
			points.append(corner[0] + Vector2(cos(a), sin(a)) * r)
	return points
