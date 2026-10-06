class_name AimRing
extends RefCounted
## The aiming ring drawn as pixel art (2026-10-03, `/grill-me` with Richard: the smooth ring
## was hard to see, off-style, and its verdict unclear). Picked off `tools/last_aim_sheet.png`
## (`tools/shot_aim.tscn`): candidate **A2**.
##
## A stepped 2:1 ellipse of whole art pixels (`Lake.ART_PIXEL` world px each): a body `THICK`
## art pixels across with its top row lit, ringed by one art pixel of black. The verdict is
## in the **shape** as well as the colour, so it reads with the colour off:
## - **OK** (the throw will catch): a whole ring with four ticks pointing inwards, a
##   `TICK_SHARE` of the ring's half-height long (whole art pixels, `TICK_LEAST`..`TICK_MOST`).
## - **NO** (nothing to lift): the ring broken into four arcs, the gaps on the diagonals.
## - **FAR** (the rod refuses): sparse dashes, which march round (`phase`).
##
## A layout is the set of cells the ring covers, decided by each cell's middle: its signed
## distance from the ellipse (world px, through the gradient) and how far round the perimeter
## it is (by arc length, so gaps and dashes are even all the way round). Only the band round
## the ellipse is walked, never the box. Rims are the body grown a cell at a time,
## eight-neighbour, so they wrap the ends of arcs, dashes and ticks.
##
## **Cached as triangle arrays**, keyed by size (whole art pixels), verdict and phase, so a
## ring that is not changing size costs one draw call and no layout. Halos are the ring's
## body alone, sorted once by a hash of each cell so a halo **dissolves pixel by pixel** (the
## foam's rule) by drawing a shorter prefix of the same array.

enum Verdict { OK, NO, FAR }

const THICK := 2
const TICK_SHARE := 0.15
const TICK_LEAST := 3
const TICK_MOST := 6
## Each of the four gaps of a NO ring, as a share of the perimeter.
const GAP := 0.06
## A FAR dash and the space after it, in art pixels of perimeter each.
const DASH := 6
## How much the body's top row is lifted towards white.
const LIT := 0.3
const OUTLINE := CastNet.AIM_BACK
## How finely a halo's pixels are shuffled for dissolving.
const HALO_BUCKETS := 64
## Layouts kept before the cache is dropped and refilled.
const CACHE_MOST := 400

const TABLE_STEPS := 256
static var _table := PackedFloat32Array()
static var _cache := {}


## Draw a ring, its middle on the canvas's origin (the caller sets the transform, snapped to
## the art grid). `span` is the half-width in world px.
static func draw_ring(on: CanvasItem, span: float, verdict: int, body: Color,
		phase: int = 0) -> void:
	var mesh := _mesh(span, verdict, body, phase, false, THICK, 1.0)
	_draw_mesh(on, mesh, -1)


## Draw a halo: the body alone, `thick` art px, `alpha` its strength, `keep` 0..1 the share of
## its pixels still standing.
static func draw_halo(on: CanvasItem, span: float, body: Color, thick: int, alpha: float,
		keep: float) -> void:
	if keep <= 0.0:
		return
	var mesh := _mesh(span, Verdict.OK, body, 0, true, thick, alpha)
	var cells: int = mesh["cells"]
	_draw_mesh(on, mesh, int(ceilf(float(cells) * clampf(keep, 0.0, 1.0))))


## The art grid's corner nearest `at`: rings are laid with their middle on one.
static func snap(at: Vector2) -> Vector2:
	return (at / Lake.ART_PIXEL).round() * Lake.ART_PIXEL


## `count` to the server is triangles, two a cell.
static func _draw_mesh(on: CanvasItem, mesh: Dictionary, cells: int) -> void:
	var count: int = mesh["cells"] if cells < 0 else mini(cells, mesh["cells"])
	if count <= 0:
		return
	RenderingServer.canvas_item_add_triangle_array(on.get_canvas_item(), mesh["indices"],
		mesh["points"], mesh["colors"], PackedVector2Array(), PackedInt32Array(),
		PackedFloat32Array(), RID(), count * 2)


static func _mesh(span: float, verdict: int, body: Color, phase: int, halo: bool,
		thick: int, alpha: float) -> Dictionary:
	var px := Lake.ART_PIXEL
	var size := maxi(roundi(span / px), 2)
	var key := "%d|%d|%d|%d|%d|%s|%.3f" % [size, verdict, phase, int(halo), thick,
		body.to_html(), alpha]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() >= CACHE_MOST:
		_cache.clear()
	var cells := lay(float(size) * px, verdict, thick, phase, halo)
	var order: Array = []
	var lit := body.lerp(Color.WHITE, LIT)
	if halo:
		# Into buckets by a hash of each cell, not sorted: the order only has to be scattered,
		# and a sort's comparisons were most of the cost of laying a wide halo.
		var buckets: Array = []
		buckets.resize(HALO_BUCKETS)
		for k in HALO_BUCKETS:
			buckets[k] = []
		for cell: Vector2i in cells["body"]:
			buckets[mini(int(_hash(cell) * HALO_BUCKETS), HALO_BUCKETS - 1)].append(cell)
		var ink := Color(body, alpha)
		for bucket: Array in buckets:
			for cell: Vector2i in bucket:
				order.append([cell, ink])
	else:
		for cell: Vector2i in cells["rim"]:
			order.append([cell, OUTLINE])
		for cell: Vector2i in cells["body"]:
			order.append([cell, lit if cells["lit"].has(cell) else body])
	var n := order.size()
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	points.resize(n * 4)
	colors.resize(n * 4)
	indices.resize(n * 6)
	for k in n:
		var entry: Array = order[k]
		var o := Vector2(entry[0]) * px
		var col: Color = entry[1]
		var v := k * 4
		points[v] = o
		points[v + 1] = o + Vector2(px, 0.0)
		points[v + 2] = o + Vector2(px, px)
		points[v + 3] = o + Vector2(0.0, px)
		colors[v] = col
		colors[v + 1] = col
		colors[v + 2] = col
		colors[v + 3] = col
		var t := k * 6
		indices[t] = v
		indices[t + 1] = v + 1
		indices[t + 2] = v + 2
		indices[t + 3] = v
		indices[t + 4] = v + 2
		indices[t + 5] = v + 3
	var mesh := {"points": points, "colors": colors, "indices": indices, "cells": n}
	_cache[key] = mesh
	return mesh


## The ring's cells (offsets in art px; cell (0, 0) has its top-left corner on the middle):
## {"body": [...], "lit": {cell: true}, "rim": [...]}. `halo` lays a plain body, no ticks, no
## gaps, no rim.
##
## Every shape but the marching dashes is the same in all four quarters, so only one quarter
## is walked and mirrored: a wide net's halos are laid on the frame they first open, and a
## quarter is what keeps that frame inside the bar.
static func lay(span: float, verdict: int, thick: int = THICK, phase: int = 0,
		halo: bool = false) -> Dictionary:
	var px := Lake.ART_PIXEL
	var a := maxf(span, px * 2.0)
	var b := a * 0.5
	var half := float(thick) * px * 0.5
	var tick := clampi(roundi(b * TICK_SHARE / px), TICK_LEAST, TICK_MOST)
	var shape := Verdict.OK if halo else verdict
	var ticks := shape == Verdict.OK and not halo
	var inner := half + (float(tick) * px if ticks else 0.0) + px
	var outer := half + px
	var dashes := maxi(8, roundi(perimeter(a) / (float(DASH) * px * 2.0)))
	var quarter := shape != Verdict.FAR
	var solid := {}
	var rows := ceili((b + outer) / px)
	for j in range(0 if quarter else -rows, rows):
		var y := (float(j) + 0.5) * px
		var x_out := _half_chord(y, a + outer, b + outer)
		if x_out <= 0.0:
			continue
		var x_in := _half_chord(y, maxf(a - inner, 0.0), maxf(b - inner, 0.0))
		var from := maxi(floori(x_in / px) - 1, 0)
		var to := ceili(x_out / px) + 1
		for i in range(from, to):
			var x := (float(i) + 0.5) * px
			if quarter:
				if _in_body(Vector2(x, y), a, b, half, shape, dashes, thick, tick, phase, ticks):
					solid[Vector2i(i, j)] = true
					solid[Vector2i(-i - 1, j)] = true
					solid[Vector2i(i, -j - 1)] = true
					solid[Vector2i(-i - 1, -j - 1)] = true
				continue
			if _in_body(Vector2(x, y), a, b, half, shape, dashes, thick, tick, phase, ticks):
				solid[Vector2i(i, j)] = true
			if _in_body(Vector2(-x, y), a, b, half, shape, dashes, thick, tick, phase, ticks):
				solid[Vector2i(-i - 1, j)] = true
	var body: Array = solid.keys()
	var lit := {}
	var rim: Array = []
	if not halo:
		for cell: Vector2i in body:
			if not solid.has(cell + Vector2i(0, -1)):
				lit[cell] = true
		var taken := solid.duplicate()
		for cell: Vector2i in body:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n := cell + Vector2i(dx, dy)
					if not taken.has(n):
						taken[n] = true
						rim.append(n)
	return {"body": body, "lit": lit, "rim": rim}


## Half the width of the ellipse (a, b) at height `y`, or 0 outside it.
static func _half_chord(y: float, a: float, b: float) -> float:
	if b <= 0.0 or absf(y) >= b:
		return 0.0
	return a * sqrt(1.0 - (y / b) * (y / b))


static func _in_body(q: Vector2, a: float, b: float, half: float, verdict: int,
		dashes: int, thick: int, tick: int, phase: int, ticks: bool) -> bool:
	var px := Lake.ART_PIXEL
	var s := _signed(q, a, b)
	var on_band := s >= -half and s < half
	if verdict == Verdict.OK:
		if on_band:
			return true
		if not ticks:
			return false
		# Four ticks, at the ends of the axes, pointing at the middle: inside the band, near
		# an axis, within the tick's length of that axis's end.
		var wide := float(maxi(thick, 2)) * px * 0.5
		var reach := half + float(tick) * px
		if absf(q.y) < wide:
			var along := a - absf(q.x)
			return along >= 0.0 and along < reach
		if absf(q.x) < wide:
			var along := b - absf(q.y)
			return along >= 0.0 and along < reach
		return false
	if not on_band:
		return false
	var u := around(q, a, b)
	if verdict == Verdict.NO:
		for k in 4:
			var mid := 0.125 + 0.25 * float(k)
			if absf(u - mid) < GAP * 0.5:
				return false
		return true
	# Dashes, marched round by `phase` art pixels of perimeter.
	var shift := float(phase) * px / perimeter(a)
	return fposmod((u - shift) * float(dashes), 1.0) < 0.5


## World px from the ellipse (a, b) to `q`, outside positive: the level set's value over its
## gradient, which is the distance near the line and all a band a few pixels wide needs.
static func _signed(q: Vector2, a: float, b: float) -> float:
	var d := sqrt((q.x * q.x) / (a * a) + (q.y * q.y) / (b * b))
	if d < 0.0001:
		return -b
	var gx := q.x / (a * a)
	var gy := q.y / (b * b)
	var g := sqrt(gx * gx + gy * gy) / d
	return (d - 1.0) / g


## How far round the perimeter `q` is, 0..1 by arc length, from the right-hand end, clockwise
## on the screen (y down).
static func around(q: Vector2, a: float, b: float) -> float:
	if _table.is_empty():
		_build_table()
	var t := fposmod(atan2(q.y / b, q.x / a), TAU) / TAU * float(TABLE_STEPS)
	var k := mini(int(t), TABLE_STEPS - 1)
	return lerpf(_table[k], _table[k + 1], t - float(k))


static func perimeter(a: float) -> float:
	# Ramanujan's, for b = a / 2.
	var b := a * 0.5
	return PI * (3.0 * (a + b) - sqrt((3.0 * a + b) * (a + 3.0 * b)))


## A FAR dash period, in art pixels: how many `phase` steps before the dashes repeat.
static func dash_period() -> int:
	return DASH * 2


static func _hash(cell: Vector2i) -> float:
	var h := sin(float(cell.x) * 12.9898 + float(cell.y) * 78.233) * 43758.5453
	return h - floorf(h)


static func _build_table() -> void:
	_table.resize(TABLE_STEPS + 1)
	var total := 0.0
	_table[0] = 0.0
	for k in TABLE_STEPS:
		var t := (float(k) + 0.5) / float(TABLE_STEPS) * TAU
		total += sqrt(pow(sin(t), 2.0) + pow(0.5 * cos(t), 2.0)) * TAU / float(TABLE_STEPS)
		_table[k + 1] = total
	for k in TABLE_STEPS + 1:
		_table[k] /= total
