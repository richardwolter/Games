## The pad's focus mark: four cream corner brackets round the control the stick has picked.
##
## Pad focus (2026-09-26, `/grill-me` with Richard): the stick snaps from control to control
## and the control itself answers as it does to a hovering mouse — `Pad` puts the hidden
## pointer on it, so every board's own hover wash and swell come for nothing. This mark is
## the one thing added over that, so the pick reads on any face, cream paper or dark water.
## Drawn once, here, for every board, rather than taught to each.
##
## **Corner brackets, not a halo** (2026-10-13, `/grill-me` with Richard: the gold halo was
## ugly; picked C off `tools/last_focus_sheet.png`, `tools/shot_focus.tscn`). Four short
## cream corners just outside the box, each ringed in one dark pixel so they hold on cream
## paper as on dark water, stepping a whole pixel out and back with the breath, gliding from
## one pick to the next. No gold, no glow, nothing over the control. Supersedes the shining
## gold halo (glow, edge, glints and corner stars, 2026-10-06), which superseded the
## two-pixel gold rectangle. "No mark at all" (the hover alone) was mocked and read on the
## bind cells and the switches, but showed nothing on the menu's doors and the shop's rows.
class_name FocusRing
extends Control

## Written out: this is built by an autoload, before `Style` can be named.
const CREAM := Color(0.99, 0.95, 0.84)
const RIM := Color(0.10, 0.06, 0.02, 0.85)
## How far the corners stand clear of the box, how thick they are, and how long an arm runs
## (a share of the box's shorter side, held between the two).
const OUT := 3.0
const THICK := 2.0
const ARM_SHARE := 0.3
const ARM_LEAST := 5.0
const ARM_MOST := 12.0
## One breath out and back, in seconds: a whole pixel.
const BREATH := 1.6
## How fast the mark glides to a new pick, and how far a pick may be before it jumps there.
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

## Where the mark is drawn this frame, gliding after `box`.
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
	var breath := 0.5 + 0.5 * sin(_clock * TAU / BREATH)
	var ring := Rect2(_shown.position.round(), _shown.size.round()).grow(OUT + roundf(breath))
	var arm := roundf(clampf(minf(ring.size.x, ring.size.y) * ARM_SHARE, ARM_LEAST, ARM_MOST))
	var corners := [
		[ring.position, Vector2(1, 1)], [Vector2(ring.end.x, ring.position.y), Vector2(-1, 1)],
		[ring.end, Vector2(-1, -1)], [Vector2(ring.position.x, ring.end.y), Vector2(1, -1)],
	]
	# The dark ring first, a pixel wider every way, then the cream over it.
	for pass_ in 2:
		var grow := 1.0 if pass_ == 0 else 0.0
		var tone := RIM if pass_ == 0 else CREAM
		for c: Array in corners:
			var at: Vector2 = c[0]
			var way: Vector2 = c[1]
			draw_rect(Rect2(at, Vector2(arm * way.x, THICK * way.y)).abs().grow(grow), tone)
			draw_rect(Rect2(at, Vector2(THICK * way.x, arm * way.y)).abs().grow(grow), tone)
