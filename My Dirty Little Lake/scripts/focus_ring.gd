## The pad's focus mark: a shining gold halo round the control the stick has picked.
##
## Pad focus (2026-09-26, `/grill-me` with Richard): the stick snaps from control to control
## and the control itself answers as it does to a hovering mouse — `Pad` puts the hidden
## pointer on it, so every board's own hover wash and swell come for nothing. This mark is
## the one thing added over that, so the pick reads on any face, cream paper or dark water.
## Drawn once, here, for every board, rather than taught to each.
##
## **A shine, not a square** (2026-10-06, Richard: "the yellow square around the buttons and
## decoration is ugly, make it a shiny hue around, pretty and noticeable"). Four things:
## a soft gold glow breathing outward from the box (a gradient, drawn round it and never over
## it, so the control under it stays readable), a thin gold edge with a pale inner lip, two
## glints running round the edge the way light runs round a polished frame, and the finds'
## four-point stars twinkling in turn at its corners. The halo glides from one pick to the
## next rather than jumping. Supersedes the two-pixel gold rectangle.
class_name FocusRing
extends Control

## The finds' gold and the paler gold their glint lifts it to. Written out: this is built by
## an autoload, before `Style` can be named.
const INK := Color(1.00, 0.80, 0.30)
const PALE := Color(1.00, 0.96, 0.78)
const DEEP := Color(0.10, 0.06, 0.02, 0.45)
## How far the edge stands clear of the box, and how far the glow reaches past the edge,
## breathing between the two over `BREATH` seconds.
const OUT := 3.0
const GLOW_LEAST := 7.0
const GLOW_MOST := 12.0
const GLOW_ALPHA := 0.55
const BREATH := 1.6
## The glints: how many run round at once, how fast (canvas pixels a second), and how long a
## tail each draws.
const GLINTS := 2
const GLINT_SPEED := 150.0
const GLINT_TAIL := 30.0
## The corner stars: one every `STAR_EVERY` seconds, round the four corners in turn, each up
## for `STAR_LIFE`, its arms reaching `STAR_ARM` at the peak.
const STAR_EVERY := 0.55
const STAR_LIFE := 0.7
const STAR_ARM := 5.0
## How fast the halo glides to a new pick, and how far a pick may be before it jumps there.
const GLIDE := 22.0
const JUMP := 600.0

## The box ringed, in the viewport's canvas pixels; empty draws nothing.
var box := Rect2():
	set(value):
		if value == box:
			return
		if box.size == Vector2.ZERO or value.size == Vector2.ZERO \
				or value.get_center().distance_to(box.get_center()) > JUMP:
			_shown = value
		box = value
		set_process(box.size != Vector2.ZERO)
		queue_redraw()

## Where the halo is drawn this frame, gliding after `box`.
var _shown := Rect2()
var _clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Under a CanvasLayer with no parent Control: sized by hand, as `ClickRipple` is.
	get_viewport().size_changed.connect(_fit)
	_fit()
	set_process(false)


func _fit() -> void:
	size = get_viewport_rect().size


func _process(delta: float) -> void:
	_clock += delta
	var k := 1.0 - exp(-GLIDE * delta)
	_shown = Rect2(_shown.position.lerp(box.position, k), _shown.size.lerp(box.size, k))
	queue_redraw()


func _draw() -> void:
	if box.size == Vector2.ZERO or _shown.size == Vector2.ZERO:
		return
	var ring := Rect2(_shown.position.round(), _shown.size.round()).grow(OUT)
	var breath := 0.5 + 0.5 * sin(_clock * TAU / BREATH)
	_draw_glow(ring, lerpf(GLOW_LEAST, GLOW_MOST, breath), GLOW_ALPHA * (0.7 + 0.3 * breath))
	# A dark hairline outside the gold, so the edge holds on the cream paper as on water.
	draw_rect(ring.grow(1.0), DEEP, false, 1.0)
	draw_rect(ring, INK, false, 2.0)
	draw_rect(ring.grow(-1.0), Color(PALE, 0.55), false, 1.0)
	_draw_glints(ring)
	_draw_stars(ring)


## The glow: four bands from the edge outward, gold at the edge and nothing at `reach`, their
## corners mitred so the band runs round unbroken.
func _draw_glow(ring: Rect2, reach: float, alpha: float) -> void:
	var inner := [ring.position, Vector2(ring.end.x, ring.position.y), ring.end, Vector2(ring.position.x, ring.end.y)]
	var outer_box := ring.grow(reach)
	var outer := [
		outer_box.position, Vector2(outer_box.end.x, outer_box.position.y),
		outer_box.end, Vector2(outer_box.position.x, outer_box.end.y),
	]
	var near := Color(INK, alpha)
	var far := Color(INK, 0.0)
	for i in 4:
		var j := (i + 1) % 4
		draw_polygon(
			PackedVector2Array([inner[i], inner[j], outer[j], outer[i]]),
			PackedColorArray([near, near, far, far])
		)


## The glints running round the edge, each a bright head fading down its tail.
func _draw_glints(ring: Rect2) -> void:
	var around := 2.0 * (ring.size.x + ring.size.y)
	if around <= 0.0:
		return
	for g in GLINTS:
		var head := fposmod(_clock * GLINT_SPEED + around * float(g) / float(GLINTS), around)
		var step := 0.0
		while step < GLINT_TAIL:
			var at := _round_edge(ring, fposmod(head - step, around))
			var fade := 1.0 - step / GLINT_TAIL
			draw_rect(Rect2((at - Vector2.ONE).round(), Vector2(2.0, 2.0)), Color(PALE, fade * fade))
			step += 2.0


## A point `along` the edge, clockwise from the top left corner.
static func _round_edge(ring: Rect2, along: float) -> Vector2:
	var w := ring.size.x
	var h := ring.size.y
	if along < w:
		return ring.position + Vector2(along, 0.0)
	along -= w
	if along < h:
		return Vector2(ring.end.x, ring.position.y + along)
	along -= h
	if along < w:
		return Vector2(ring.end.x - along, ring.end.y)
	along -= w
	return Vector2(ring.position.x, ring.end.y - along)


## The corner stars, one at a time round the four corners: a pale core and four arms that
## grow and shrink, the finds' twinkle.
func _draw_stars(ring: Rect2) -> void:
	var corners := [ring.position, Vector2(ring.end.x, ring.position.y), ring.end, Vector2(ring.position.x, ring.end.y)]
	var turn := int(floorf(_clock / STAR_EVERY))
	for back in 2:
		var n := turn - back
		var age := _clock - float(n) * STAR_EVERY
		if n < 0 or age < 0.0 or age > STAR_LIFE:
			continue
		var bloom := sin(age / STAR_LIFE * PI)
		var at: Vector2 = (corners[posmod(n * 3, 4)] as Vector2).round()
		var arm := roundf(STAR_ARM * bloom)
		var tone := Color(PALE, bloom)
		draw_rect(Rect2(at - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(1, 1, 1, bloom))
		if arm >= 1.0:
			draw_rect(Rect2(at.x - 0.5, at.y - 1.0 - arm, 1.0, arm), tone)
			draw_rect(Rect2(at.x - 0.5, at.y + 1.0, 1.0, arm), tone)
			draw_rect(Rect2(at.x - 1.0 - arm, at.y - 0.5, arm, 1.0), tone)
			draw_rect(Rect2(at.x + 1.0, at.y - 0.5, arm, 1.0), tone)
