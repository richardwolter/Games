## The pad's focus mark: a gold ring round the control the left stick has picked.
##
## Pad focus (2026-09-26, `/grill-me` with Richard): the stick snaps from control to control
## and the control itself answers as it does to a hovering mouse — `Pad` puts the hidden
## pointer on it, so every board's own hover wash and swell come for nothing. This ring is
## the one thing added over that, so the pick reads on any face, cream paper or dark water.
## Drawn once, here, for every board, rather than taught to each.
class_name FocusRing
extends Control

## Gold, two whole pixels, stood `OUT` clear of the box so it rings the control rather
## than sitting on its edge.
## `Style.GOLD`, written out: this is built by an autoload, before `Style` can be named.
const INK := Color(1.00, 0.80, 0.30)
const DEEP := Color(0.0, 0.0, 0.0, 0.55)
const LINE := 2.0
const OUT := 3.0

## The box ringed, in the viewport's canvas pixels; empty draws nothing.
var box := Rect2():
	set(value):
		if value == box:
			return
		box = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Under a CanvasLayer with no parent Control: sized by hand, as `ClickRipple` is.
	get_viewport().size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	size = get_viewport_rect().size


func _draw() -> void:
	if box.size == Vector2.ZERO:
		return
	var ring := Rect2(box.position.round(), box.size.round()).grow(OUT)
	# A dark line under the gold, so the ring holds on the cream paper as well as on water.
	draw_rect(ring.grow(1.0), DEEP, false, LINE + 2.0)
	draw_rect(ring, INK, false, LINE)
