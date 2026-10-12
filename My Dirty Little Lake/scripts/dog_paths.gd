class_name DogPaths
## The way round things on the lake, for the pack (2026-10-11, `/grill-me` with Richard: "make
## dogs smarter when avoiding obstacles and moving around"). Lifts the no-path-search rule of
## 2026-09-16 and 2026-09-22: a dog that only looked a tile ahead rocked at corners, took odd
## lines and, once the piers and the driftwood were things to go round, had pockets it could
## not see its way out of.
##
## One grid for the whole pack, `RES` points a tile, over every tile a dog may stand on: the
## island, the water and the bank's beach as far as `Dog.BEACH_WALK`. Solid where a dog may
## not be — off its ground, in the hut, the crate, the pump, the hive, a pier or a log — each
## grown by its own walk margin, read the way `Dog._may_stand` reads them. The cells next to a
## thing (not next to the edge of the ground) cost more (`NEAR_COST`), so a path runs down the
## middle of a gap instead of scraping a wall. Built once, the first time a dog asks, and
## again only if one of the things it was built round has moved.
##
## A path is the grid's own cells pulled straight wherever the next point is in plain sight
## (`plan`, `clear`), the shed's way. Moving things — the angler, the other dogs, the animals —
## are not on the grid: the dog steers round those as it goes (`Dog._steer`).

## Grid points a tile.
const RES := 2
## What a cell one, then two, from a thing costs over an open cell: paths keep a cell clear
## where they can and take the gap anyway where they must.
const NEAR_COST := [4.0, 1.6]
## How far round a pier's deck and platform a dog keeps, in tiles.
const PIER_KEEP := 0.25
## How far round a driftwood log's drawing a dog keeps, world px.
const LOG_GROW := 6.0
## How far along a line `clear` looks between samples, in cells.
const SEE_STEP := 0.5

## The four yards' piers as [foot, axis], tile space, and every log's drawn box, world px.
## Handed in by the lake (`setup`).
static var piers: Array = []
static var logs: Array = []

static var _astar: AStarGrid2D
static var _key := ""
## Per cell: 0 open, 1 solid, 2 open but next to a thing (no straight line through it).
static var _flags := PackedByteArray()
static var _w := 0
static var _h := 0


## The piers and the logs the grid is built round. The next `plan` builds it afresh.
static func setup(dropoffs: Array, grounds: Array) -> void:
	piers.clear()
	for stop in dropoffs:
		piers.append([stop.foot, stop.axis])
	logs.clear()
	for g in grounds:
		for box: Rect2 in g.driftwood:
			logs.append(box)
	_key = ""


## Is this tile-space point on a pier's deck or platform, grown by `keep` tiles? The jetty
## runs `Dropoff.JETTY_OUT` out from the foot and is a tile wide; the platform runs two tiles
## landward and is two wide (`tools/build_piers.py`, JETTY_WIDE, PLATFORM_BACK/WIDE).
static func on_pier(at: Vector2, keep: float = PIER_KEEP) -> bool:
	for p: Array in piers:
		var axis: Vector2 = p[1]
		var off: Vector2 = at - (p[0] as Vector2)
		var s := off.dot(axis)
		if s < -2.0 - keep or s >= Dropoff.JETTY_OUT + keep:
			continue
		var across := absf(off.dot(Vector2(-axis.y, axis.x)))
		if across < (0.5 if s >= 0.0 else 1.0) + keep:
			return true
	return false


## Is this tile-space point on a driftwood log's drawing, grown by `grow` world px?
static func on_log(at: Vector2, grow: float = LOG_GROW) -> bool:
	if logs.is_empty():
		return false
	var world := Iso.tile_to_world(at.x, at.y)
	for box: Rect2 in logs:
		if box.grow(grow).has_point(world):
			return true
	return false


## The ground a dog may be on, before anything standing on it: `Dog._may_stand` less the things.
static func on_ground(at: Vector2) -> bool:
	if Iso.island_fraction(at.x, at.y) < 1.0:
		return true
	if Iso.shore_fraction(at.x, at.y) < 1.0:
		return true
	return Iso.on_beach_at(at, -1.0, Dog.BEACH_WALK)


## Something standing here a dog goes round, each read with the margin `Dog._may_stand` uses.
static func on_thing(at: Vector2, crate: Vector2) -> bool:
	return (
		Iso.in_shed(at.x, at.y, Iso.SHED_KEEP)
		or Pump.covers(at, Pump.WALK_KEEP)
		or Hive.covers(at, Hive.WALK_KEEP)
		or Yard.covers(crate, at, Yard.WALK_KEEP)
		or on_pier(at)
		or on_log(at)
	)


static func _build(crate: Vector2) -> void:
	var key := "%s|%s|%s|%d|%d" % [crate, Pump.tile, Hive.tile, piers.size(), logs.size()]
	if key == _key and _astar != null:
		return
	_key = key
	_w = Iso.COLS * RES
	_h = Iso.ROWS * RES
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, _w, _h)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	_flags = PackedByteArray()
	_flags.resize(_w * _h)
	var things := PackedInt32Array()
	for y in _h:
		for x in _w:
			var at := Vector2((float(x) + 0.5) / RES, (float(y) + 0.5) / RES)
			if not on_ground(at):
				_flags[y * _w + x] = 1
				_astar.set_point_solid(Vector2i(x, y), true)
			elif on_thing(at, crate):
				_flags[y * _w + x] = 1
				_astar.set_point_solid(Vector2i(x, y), true)
				things.append(y * _w + x)
	# The rings round the things: dearer, and no straight line through them.
	for i in things:
		var cx := i % _w
		var cy := i / _w
		for dy in range(-NEAR_COST.size(), NEAR_COST.size() + 1):
			for dx in range(-NEAR_COST.size(), NEAR_COST.size() + 1):
				var x := cx + dx
				var y := cy + dy
				if x < 0 or y < 0 or x >= _w or y >= _h or _flags[y * _w + x] == 1:
					continue
				var ring := maxi(absi(dx), absi(dy))
				var cost := 1.0 + float(NEAR_COST[ring - 1])
				var cell := Vector2i(x, y)
				if cost > _astar.get_point_weight_scale(cell):
					_astar.set_point_weight_scale(cell, cost)
				if ring == 1:
					_flags[y * _w + x] = 2


static func _cell(at: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor(at.x * RES)), 0, _w - 1), clampi(int(floor(at.y * RES)), 0, _h - 1))


static func _flag(cell: Vector2i) -> int:
	return _flags[cell.y * _w + cell.x]


## The open cell nearest `cell`, ring by ring; Vector2i(-1, -1) when there is none close.
static func _open_near(cell: Vector2i) -> Vector2i:
	if _flag(cell) != 1:
		return cell
	for r in range(1, 8):
		var best := Vector2i(-1, -1)
		var nearest := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := cell + Vector2i(dx, dy)
				if c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _h or _flag(c) == 1:
					continue
				var d := float(dx * dx + dy * dy)
				if d < nearest:
					nearest = d
					best = c
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## Can a dog walk the straight line from `a` to `b`? Nothing solid on it and, if `strict`,
## nothing next to a thing either — which is what keeps a pulled-straight path clear of the
## walls the costs steered it off. The cells `a` and `b` stand in are not asked: a dog standing
## by a wall, or going to a piece under a pier, may start or end in one.
static func clear(a: Vector2, b: Vector2, strict: bool = true, crate: Vector2 = Vector2.INF) -> bool:
	if crate != Vector2.INF:
		_build(crate)
	if _astar == null:
		return true
	var ca := _cell(a)
	var cb := _cell(b)
	var span := (b - a) * RES
	var steps := int(ceil(span.length() / SEE_STEP))
	for i in range(1, steps):
		var c := _cell(a.lerp(b, float(i) / float(steps)))
		if c == ca or c == cb:
			continue
		var f := _flag(c)
		if f == 1 or (strict and f == 2):
			return false
	return true


## The way from `from` to `to`, tile space, as the points to walk to in turn (not `from`), the
## last one `to`. Straight when the line is clear; otherwise the grid's path pulled straight.
## A `to` inside something (a piece under a pier) is gone to from the open cell nearest it.
static func plan(from: Vector2, to: Vector2, crate: Vector2) -> PackedVector2Array:
	_build(crate)
	var out := PackedVector2Array()
	if clear(from, to):
		out.append(to)
		return out
	var a := _open_near(_cell(from))
	var b := _open_near(_cell(to))
	if a.x < 0 or b.x < 0:
		out.append(to)
		return out
	var ids := _astar.get_id_path(a, b, true)
	if ids.is_empty():
		out.append(to)
		return out
	var points := PackedVector2Array()
	for id: Vector2i in ids:
		points.append((Vector2(id) + Vector2(0.5, 0.5)) / RES)
	points.append(to)
	# Pulled straight: from where the dog stands, on to the furthest point it can see, and so
	# on. A point not even the next one can be seen to is taken anyway; the grid joins them.
	var anchor := from
	var i := 0
	while i < points.size():
		var j := i
		while j + 1 < points.size() and clear(anchor, points[j + 1]):
			j += 1
		out.append(points[j])
		anchor = points[j]
		i = j + 1
	return out


## For the harness: is the cell under this point solid on the grid built round `crate`?
static func solid_at(at: Vector2, crate: Vector2) -> bool:
	_build(crate)
	return _flag(_cell(at)) == 1
