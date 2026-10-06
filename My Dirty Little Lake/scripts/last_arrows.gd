class_name LastArrows
extends Control
## An arrow at the window's edge for each of the lake's last few pieces the view does not hold
## (2026-09-26, `Lake._mark_last_pieces`). On the piece itself the pale rim and the white
## column do the pointing; this is only for the ones off screen. Draws only.

const Style := preload("res://scripts/style.gd")

## How far in from the window's edge an arrow's point stands, canvas px.
const INSET := 28.0
## The arrow: length and half-width, canvas px.
const LONG := 18.0
const HALF := 10.0
## A gentle push towards the piece and back, so it reads as pointing rather than parked.
const NUDGE := 4.0
const NUDGE_RATE := 5.0
const INK := Color(0.92, 0.97, 1.0)
## Pieces off screen within this angle of each other, seen from the window's middle, share
## one arrow.
const GROUP_ANGLE := deg_to_rad(22.0)
## The count on a shared arrow: its size and how far behind the arrow's back it stands.
const COUNT_PX := Style.TEXT_SMALL
const COUNT_BACK := 12.0
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


## Where each arrow stands, which way it points and how many pieces it stands for. Pieces
## off screen in about the same direction share one arrow (`GROUP_ANGLE`), with their count
## on it (2026-10-05, Richard: the last thirty marked, and thirty arrows would crowd the
## window). The line from the window's middle to the group's mean direction, cut at the
## inset edge. Empty when every piece is in view.
func arrows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var xf := get_viewport().get_canvas_transform()
	var view := Rect2(Vector2.ZERO, size)
	var inner := view.grow(-INSET)
	var middle := view.get_center()
	var angles: Array[float] = []
	for spot in spots:
		var at := xf * spot
		if view.grow(-4.0).has_point(at):
			continue
		var way := (at - middle)
		if way.length_squared() < 0.0001:
			continue
		angles.append(way.angle())
	if angles.is_empty():
		return out
	angles.sort()
	# Greedy runs round the circle, each no wider than `GROUP_ANGLE` from its first; a run
	# that wraps past pi is joined to the first run.
	var groups: Array = []
	var run: Array[float] = [angles[0]]
	for i in range(1, angles.size()):
		if angles[i] - run[0] <= GROUP_ANGLE:
			run.append(angles[i])
		else:
			groups.append(run)
			run = [angles[i]]
	groups.append(run)
	if groups.size() > 1:
		var first: Array = groups[0]
		var last: Array = groups[groups.size() - 1]
		if float(first[first.size() - 1]) + TAU - float(last[0]) <= GROUP_ANGLE:
			for angle in last:
				first.append(float(angle) - TAU)
			groups.pop_back()
	var half := inner.size * 0.5
	for group: Array in groups:
		var sum := Vector2.ZERO
		for angle in group:
			sum += Vector2.from_angle(float(angle))
		var way := sum.normalized()
		if way == Vector2.ZERO:
			way = Vector2.from_angle(float(group[0]))
		# How far along the way the inner box's edge is.
		var reach := INF
		if absf(way.x) > 0.0001:
			reach = minf(reach, half.x / absf(way.x))
		if absf(way.y) > 0.0001:
			reach = minf(reach, half.y / absf(way.y))
		out.append({"at": middle + way * reach, "way": way, "count": group.size()})
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
		var count := int(arrow.get("count", 1))
		if count > 1:
			var text := str(count)
			var span := Style.font().get_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, COUNT_PX
			)
			var middle := back - way * COUNT_BACK
			# The text's middle on that point: the baseline sits under its cap height.
			var at := (middle + Vector2(-span.x * 0.5, span.y * 0.3)).round()
			Style.write(self, text, COUNT_PX, at, INK)
