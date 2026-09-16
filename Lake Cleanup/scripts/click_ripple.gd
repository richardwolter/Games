## The click's answer: a quick water ripple under the pointer (2026-09-16, Richard, who did
## not like the bead of water the pointer wore before it).
##
## **Drawn on a layer of its own, not baked into the cursor picture.** A ripple is a moving
## thing, and the pointer is a hardware cursor — a swapped picture can hold one pose but not
## an animation, and the drop that could be held as a pose read as decoration rather than as
## an answer. So `Pad` owns this, over its own `CanvasLayer` above everything, and the arrow
## itself never changes.
##
## **The lake's own ripple, by decision**: rings in the 2:1 of every ellipse in this game,
## drawn as outlines in the pale the angler's wading rings use (`Angler.RIPPLE_*`,
## `_ring`), not a circle and not a flash. The pointer is a wooden thing that has been in
## the lake all day; what comes off it is lake water. It rings over the menus and the boards
## too, because the cursor is one cursor everywhere and a click is a click everywhere.
class_name ClickRipple
extends Control

## How many rings go out per click, and how long after the first each of the rest starts.
## Two, staggered: one ring is a circle drawn on the screen, three is a splash.
const RINGS := 2
const STAGGER := 0.07

## How long a ring lives, and how far it opens in screen pixels. Quick, by the ask — over
## before the button is let go of in ordinary clicking, so it never reads as a thing that
## has to finish.
const LIFE := 0.30
const FROM := 3.0
const TO := 22.0

## The 2:1 the whole game draws an ellipse at, and the weight of the line.
const FLAT := 0.5
const WIDE := 1.5

## The wading rings' own pale (`Angler._draw`), so a ripple off the pointer and a ripple off
## the player's boots are the same water.
const INK := Color(0.86, 0.94, 0.97)

## How many clicks can be ringing at once. A click is 0.3 s and nobody clicks ten times in
## that, so this is only here so a stuck button cannot grow the list without end.
const MOST := 6

## Where each live click was, and when it landed on the play clock.
var _splashes: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	# It is drawn over the whole game and must never be in the way of it: no input, no
	# focus, nothing under the pointer but what was already there.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **It has to be given the viewport's size, and anchors will not do it.** A Control under
	# a CanvasLayer has no parent Control to anchor against, so it stays 0x0 -- and a 0x0
	# CanvasItem is culled before it is drawn, whatever its `_draw` puts out. An opaque red
	# rect drawn from a zero-sized one does not reach the screen either; that is what this
	# cost to find.
	get_viewport().size_changed.connect(_fit)
	_fit()
	set_process(false)


func _fit() -> void:
	size = get_viewport_rect().size


## Ring the water at a spot, in viewport pixels.
func splash(at: Vector2) -> void:
	if _splashes.size() >= MOST:
		_splashes.pop_front()
	_splashes.append({"at": at, "born": _time})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var over := LIFE + STAGGER * float(RINGS - 1)
	for i in range(_splashes.size() - 1, -1, -1):
		if _time - float(_splashes[i]["born"]) > over:
			_splashes.remove_at(i)
	if _splashes.is_empty():
		# Nothing ringing: stop both the clock and the redraws, so an idle menu costs
		# nothing at all.
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for splash: Dictionary in _splashes:
		var age := _time - float(splash["born"])
		for ring in RINGS:
			var t := (age - STAGGER * float(ring)) / LIFE
			if t <= 0.0 or t >= 1.0:
				continue
			# Out fast and then slowing, the way water does, and fading the whole way so the
			# ring is thinnest when it is widest.
			var out := 1.0 - pow(1.0 - t, 2.0)
			_ring(splash["at"], lerpf(FROM, TO, out), Color(INK.r, INK.g, INK.b, 1.0 - t))


## One flat ellipse, drawn as an outline. Twenty-four sides: at this size that is a step of
## under two pixels, which is finer than the water itself is drawn at.
func _ring(at: Vector2, wide: float, ink: Color) -> void:
	var points := PackedVector2Array()
	for i in 25:
		var angle := TAU * float(i % 24) / 24.0
		points.append(at + Vector2(cos(angle) * wide, sin(angle) * wide * FLAT))
	draw_polyline(points, ink, WIDE)
