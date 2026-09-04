## The isometric projection, and the basin's shape in tile space.
##
## The whole game is one flat plane seen at an angle: the lake is a field of tiles, and
## everything the player can see sits on its surface. There is no cross-section any more,
## so there is no need to draw — or reason about — the rubbish underneath. A tile keeps
## its stack as data; only the top of it is ever on screen.
##
## Both halves of the projection live here so nothing else has to know the tile size, and
## the basin's radius function lives here so the water polygon, the tile depths and the
## shader all agree about where the shore is.
class_name Iso
extends RefCounted

## Screen size of one tile, in the classic 2:1 isometric ratio.
const TILE_W := 64.0
const TILE_H := 32.0

## The tile field. Square, so the basin can be an ellipse inside it without the projection
## favouring one diagonal.
const COLS := 92
const ROWS := 92

## Basin centre and radii, in tiles. Slightly unequal, so the lake is a lake rather than a
## dinner plate.
const CENTRE := Vector2(46.0, 46.0)
const RADIUS := Vector2(40.0, 34.0)

## Deepest point, in stack slots. A tile's stack is this scaled by its depth.
const MAX_SLOTS := 9

## The island in the middle of the basin: the one piece of dry land in the lake, and where
## the upgrade shed stands. It is a hole in the water rather than a decoration — no depth,
## no rubbish laid down on it, and the boat cannot drive over it.
##
## Deliberately not scaled with the basin. The island is a place a person stands on, and
## its size is set by how long it takes to walk from one shore of it to the other — that
## is a constant, and growing it with the lake would only make the lake feel the same size
## as before.
const ISLAND_CENTRE := Vector2(46.0, 46.0)
const ISLAND_RADIUS := Vector2(4.6, 3.9)


static func tile_to_world(tx: float, ty: float) -> Vector2:
	return Vector2((tx - ty) * TILE_W * 0.5, (tx + ty) * TILE_H * 0.5)


## How wide, in world pixels, a circle of `radius` tiles comes out on screen: half the long
## axis of the ellipse it projects to, the short one being half of that like every other
## flat thing here.
##
## Worth a function because the obvious answer is wrong. The projection stretches the
## diagonals, so a tile circle lands a factor of root two wider than `radius * TILE_W * 0.5`
## — which is what the net's range ring was drawn at, and why it was a third short of where
## the net could actually be thrown.
static func tile_circle_extent(radius: float) -> float:
	return radius * TILE_W * 0.5 * sqrt(2.0)


## The inverse. Returns fractional tile coordinates; callers floor them if they want a
## cell rather than a point.
static func world_to_tile(at: Vector2) -> Vector2:
	var a := at.x / (TILE_W * 0.5)
	var b := at.y / (TILE_H * 0.5)
	return Vector2((b + a) * 0.5, (b - a) * 0.5)


## How far out a tile is, as a fraction of the shore's radius in its direction. 0 at the
## middle, 1 exactly on the waterline, more than 1 on dry land.
##
## Mirrored in shaders/water.gdshader. If one drifts, the drawn shore and the shaded shore
## separate visibly, which is a loud enough failure to catch.
static func shore_fraction(tx: float, ty: float) -> float:
	var d := Vector2((tx - CENTRE.x) / RADIUS.x, (ty - CENTRE.y) / RADIUS.y)
	var r := d.length()
	if r < 0.0001:
		return 0.0
	var angle := atan2(d.y, d.x)
	# Two out-of-phase lobes, so the bank is a coastline instead of an ellipse.
	var wobble := 1.0 + 0.09 * sin(angle * 3.0) + 0.05 * sin(angle * 5.0 + 1.3)
	return r / wobble


## The shed's footprint on the plane, as tile radii out from the island's middle, and how
## tall it is drawn in world pixels.
##
## Kept here rather than in whichever script draws it, because two things need it and they
## must not disagree: the lake draws the hut, and the angler walks round it. A building you
## can see and walk through is worse than no building.
const SHED_FOOT := Vector2(1.15, 0.95)
const SHED_TALL := 74.0


## Is this tile inside the shed? An ellipse in tile space, which is the same shape on screen
## as everything else that lies on the plane.
static func in_shed(tx: float, ty: float) -> bool:
	return Vector2(
		(tx - ISLAND_CENTRE.x) / SHED_FOOT.x, (ty - ISLAND_CENTRE.y) / SHED_FOOT.y
	).length_squared() < 1.0


## How far a tile is from the island's middle, as a fraction of the island's edge in that
## direction. Under 1 is on the island: dry land, and not part of the lake.
##
## Mirrored in shaders/water.gdshader, same as shore_fraction.
static func island_fraction(tx: float, ty: float) -> float:
	var d := Vector2(
		(tx - ISLAND_CENTRE.x) / ISLAND_RADIUS.x, (ty - ISLAND_CENTRE.y) / ISLAND_RADIUS.y
	)
	var r := d.length()
	if r < 0.0001:
		return 0.0
	var angle := atan2(d.y, d.x)
	var wobble := 1.0 + 0.11 * sin(angle * 3.0 + 0.7) + 0.06 * sin(angle * 5.0 - 0.4)
	return r / wobble


## 0 at the shore, 1 at the deepest water. The square root pulls the drop-off in towards
## the bank, which is what gives the middle a broad deep floor rather than a point.
static func depth_at(tx: float, ty: float) -> float:
	if island_fraction(tx, ty) < 1.0:
		return 0.0
	var s := shore_fraction(tx, ty)
	if s >= 1.0:
		return 0.0
	return sqrt(1.0 - s)


static func in_lake(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= COLS or ty >= ROWS:
		return false
	if island_fraction(tx, ty) < 1.0:
		return false
	return shore_fraction(tx, ty) < 1.0


## The waterline, as a ring of world points. Walked by angle rather than by marching the
## tile field, because the shore is defined by an angle function in the first place.
##
## `grow` pushes the ring outward by that many tiles, for the shore bands drawn around the
## water. Grown in tile space and projected afterwards, not offset on screen: a fixed
## screen-space offset on a projected ring fattens the near side and pinches the far one,
## which is what makes hand-drawn isometric ground read as a smear.
static func shore_outline(grow: float = 0.0, steps: int = 320) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		var wobble := 1.0 + 0.09 * sin(angle * 3.0) + 0.05 * sin(angle * 5.0 + 1.3)
		var tx := CENTRE.x + cos(angle) * (RADIUS.x * wobble + grow)
		var ty := CENTRE.y + sin(angle) * (RADIUS.y * wobble + grow)
		out.append(tile_to_world(tx, ty))
	return out


## A point on the basin, in tile coordinates, at `angle` around the middle and `inset` of
## the way out to the shore. 1.0 lands exactly on the waterline.
##
## The dropoffs on the bank and the ring the ferry roams along are both placed with this,
## so they agree with the coastline the same wobble drew.
static func basin_point(angle: float, inset: float = 1.0) -> Vector2:
	var wobble := 1.0 + 0.09 * sin(angle * 3.0) + 0.05 * sin(angle * 5.0 + 1.3)
	return Vector2(
		CENTRE.x + cos(angle) * RADIUS.x * wobble * inset,
		CENTRE.y + sin(angle) * RADIUS.y * wobble * inset
	)


## The angle a tile sits at, as basin_point would take it. The inverse of the line above,
## for working out which way round the lake something is.
static func basin_angle(at: Vector2) -> float:
	return atan2((at.y - CENTRE.y) / RADIUS.y, (at.x - CENTRE.x) / RADIUS.x)


## The island's edge, the same way: a ring in tile space, grown by `grow` tiles, projected
## afterwards. `grow` below zero gives the inner bands of the beach.
## One point on the island's edge, at an angle round it and a distance in or out of it, in
## world space. The outline is this walked all the way round; anything scattered along the
## shoreline wants one point at a time instead.
static func island_point(angle: float, grow: float = 0.0) -> Vector2:
	var wobble := 1.0 + 0.11 * sin(angle * 3.0 + 0.7) + 0.06 * sin(angle * 5.0 - 0.4)
	return tile_to_world(
		ISLAND_CENTRE.x + cos(angle) * (ISLAND_RADIUS.x * wobble + grow),
		ISLAND_CENTRE.y + sin(angle) * (ISLAND_RADIUS.y * wobble + grow)
	)


static func island_outline(grow: float = 0.0, steps: int = 96) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		var wobble := 1.0 + 0.11 * sin(angle * 3.0 + 0.7) + 0.06 * sin(angle * 5.0 - 0.4)
		var tx := ISLAND_CENTRE.x + cos(angle) * (ISLAND_RADIUS.x * wobble + grow)
		var ty := ISLAND_CENTRE.y + sin(angle) * (ISLAND_RADIUS.y * wobble + grow)
		out.append(tile_to_world(tx, ty))
	return out
