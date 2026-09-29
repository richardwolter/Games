class_name LastArrows
extends Control
## An arrow at the window's edge for each of the lake's last few pieces the view does not hold
## (2026-09-26, `Lake._mark_last_pieces`). On the piece itself the pale rim and the white
## column do the pointing; this is only for the ones off screen. Draws only.

## How far in from the window's edge an arrow's point stands, canvas px.
const INSET := 28.0
## The arrow: length and half-width, canvas px.
const LONG := 18.0
const HALF := 10.0
## A gentle push towards the piece and back, so it reads as pointing rather than parked.
const NUDGE := 4.0
const NUDGE_RATE := 5.0
const INK := Color(0.92, 0.97, 1.0)
const RIM := Color(0.08, 0.06, 0.06)

## The pieces, in world space. Set by the lake.
var spots: Array[Vector2] = []:
	set(value):
		spots = value
		set_process(not spots.is_empty())
		queue_redraw()

var _clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	get_viewport().size_changed.connect(_fit)
	set_process(not spots.is_empty())


## Sized by hand: a Control on a CanvasLayer has no parent rect to anchor to.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## Where each off-screen piece's arrow stands and which way it points: the line from the
## window's middle to the piece, cut at the inset edge. Empty for a piece in view.
func arrows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var xf := get_viewport().get_canvas_transform()
	var view := Rect2(Vector2.ZERO, size)
	var inner := view.grow(-INSET)
	var middle := view.get_center()
	for spot in spots:
		var at := xf * spot
		if view.grow(-4.0).has_point(at):
			continue
		var way := (at - middle).normalized()
		if way == Vector2.ZERO:
			continue
		# How far along the way the inner box's edge is.
		var half := inner.size * 0.5
		var reach := INF
		if absf(way.x) > 0.0001:
			reach = minf(reach, half.x / absf(way.x))
		if absf(way.y) > 0.0001:
			reach = minf(reach, half.y / absf(way.y))
		out.append({"at": middle + way * reach, "way": way})
	return out


func _draw() -> void:
	var push := NUDGE * (0.5 + 0.5 * sin(_clock * NUDGE_RATE))
	for arrow in arrows():
		var way: Vector2 = arrow["way"]
		var tip: Vector2 = (arrow["at"] as Vector2) + way * push
		var side := Vector2(-way.y, way.x)
		var back := tip - way * LONG
		var shape := PackedVector2Array([tip, back + side * HALF, back - side * HALF])
		var rim := PackedVector2Array([
			tip + way * 2.5, back + side * (HALF + 2.5) - way * 1.5,
			back - side * (HALF + 2.5) - way * 1.5,
		])
		draw_colored_polygon(rim, RIM)
		draw_colored_polygon(shape, INK)
