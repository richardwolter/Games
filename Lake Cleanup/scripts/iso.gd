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

## The art-pixel snap for things that move, in world pixels; 0 is off. Set by lake.gd (F4)
## to `Lake.ART_PIXEL`, on trial: the camera is snapped to whole screen pixels, but the
## angler, dog, boat and the rubbish on the swell glide between art pixels, and against the
## water's fixed pixel grid that reads as shimmer. Snapped, they step a whole art pixel at a
## time, the way a low-res render would draw them. Only where a thing is drawn moves —
## `tile_pos` and everything that reads it stay smooth.
static var art_snap: float = 0.0


## Where a moving thing at `at` is drawn: on the art-pixel grid when `art_snap` is on.
static func drawn(at: Vector2) -> Vector2:
	if art_snap <= 0.0:
		return at
	return (at / art_snap).round() * art_snap

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
## Grown (from 4.6 x 3.9, by way of 6.44 x 5.46) when the ground became tiles.
##
## Tiles are what set this now. The island has to hold a beach with a middle to it — a shore
## one tile wide is all edge, and every tile of it takes the rimmed-all-round piece, which
## reads as a kerb — and a lawn wide enough to be somewhere rather than a patch. That is
## about two and a half tiles of sand and five of grass out from the middle, and this is what
## adds up to it. It costs a longer walk across, which is the thing this number is really
## setting.
const ISLAND_RADIUS := Vector2(8.0, 6.8)


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
##
## Grown from 1.15x0.95 / 74px once the rubbish stopped all drawing at one size: at 74 the
## hut was a tenth taller than the biggest thing floating past it, which read as a shed the
## size of a wardrobe. At 118 it is about three quarters again as tall as the largest find
## and takes a third of its island, leaving beach on every side.
const SHED_FOOT := Vector2(1.70, 1.40)
const SHED_TALL := 118.0


## Is this tile inside the shed? An ellipse in tile space, which is the same shape on screen
## as everything else that lies on the plane.
##
## `grow` widens it, and is what anything that walks passes in. The hut is drawn as a picture
## a great deal taller and a little wider than the ground it stands on, so a walker allowed
## right up to the footprint ends up with the wall drawn across its middle — standing in the
## shed as far as the eye is concerned. Kept out of a slightly bigger ellipse, it either
## walks past the hut or goes behind it, and never through it.
static func in_shed(tx: float, ty: float, grow: float = 0.0) -> bool:
	var foot := SHED_FOOT + Vector2(grow, grow)
	return Vector2(
		(tx - ISLAND_CENTRE.x) / foot.x, (ty - ISLAND_CENTRE.y) / foot.y
	).length_squared() < 1.0


## How much wider than its footprint the hut is kept clear of, in tiles, for anything that
## walks. See `in_shed`.
##
## Barely anything now. It was half a tile, which on an island nine tiles across is a wall
## standing well clear of the hut it belongs to: walking round the shed meant being shoved
## out onto the sand, and the grass between the two was land the player could see and not
## use. The picture is taller than its footprint, not much wider, so this only has to keep a
## walker off the wall itself.
const SHED_KEEP := 0.12


## How far a tile is from the island's middle, as a fraction of the island's edge in that
## direction. Under 1 is on the island: dry land, and not part of the lake.
##
## Under half of what the basin's is (0.07/0.035/0.02 against 0.09/0.05), not the third it
## was: a flat foam ring round too round a shape was reading as a stencil cut rather than a
## shore, and the island could take more before the lumps turned into a star. A third term
## added on top of the original two, at a frequency (7) that shares no common divisor with
## the other two (3, 5) — so the three peaks never stack into one bigger lump the way
## harmonics of the same base would, which is what a star's points are. Still not a circle:
## a perfectly round island reads as a drawn shape, not a place.
##
## Mirrored in shaders/water.gdshader, same as shore_fraction — the two must move together
## or the shaded shore and the drawn one part ways.
static func island_fraction(tx: float, ty: float) -> float:
	var d := Vector2(
		(tx - ISLAND_CENTRE.x) / ISLAND_RADIUS.x, (ty - ISLAND_CENTRE.y) / ISLAND_RADIUS.y
	)
	var r := d.length()
	if r < 0.0001:
		return 0.0
	var angle := atan2(d.y, d.x)
	var wobble := (
		1.0 + 0.07 * sin(angle * 3.0 + 0.7) + 0.035 * sin(angle * 5.0 - 0.4)
		+ 0.02 * sin(angle * 7.0 + 2.1)
	)
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


## How far off either shoreline rubbish is laid, as a fraction of the radius it is measured
## against.
##
## The water is drawn a little way over the sand at both shores, so a tile that is only just
## in the lake is under the part of the lake that is painted on the beach — and a bottle
## bobbing there reads as a bottle lying on the sand. Held off by rather more than the paint,
## because a piece of rubbish is drawn a good deal wider than the tile it sits on.
##
## Only where rubbish is laid down, not in `in_lake` itself: the net has to be able to reach
## the whole of the water, and a shore the cast is turned away from is a shore that feels
## fenced off — which is the same reason the angler is allowed to wade.
##
## Small, and it has to stay small. The first cast of a run is thrown from the island's own
## beach, and every tile held clear here is a tile further for it to travel: at 0.06 — about
## a tile off each shore — the opening cast could not reach anything at all.
const LAKE_EDGE := 0.03


## How far clear of the island rubbish is laid, in world pixels past its waterline.
##
## Bigger than the margin at the outer bank, and for a different reason. The water shoals
## up to the island (see water.gdshader), and a piece floating in the lightest of that
## shallows, right against the beach, reads as lying on it. Worse, it reads as somewhere the
## player cannot cast, which is the sort of thing that gets learned once and then avoided
## for the rest of a run. (This band used to be a drawn shelf of drowned sand; the island is
## under the water now and the shelf is gone, but the holdoff it set is still the right one.)
##
## How far the drawn water is carried past the island's waterline, in tiles, and how far the
## island's sand carries on under it before it is lost.
##
## Geometry, so it lives here rather than in whatever happens to draw it: the shelf is what
## the eye reads as the island's edge, and the rubbish and the walking both have to agree
## with the picture. `Ground` draws to these; nothing should hold a second copy.
const WATER_LAP_TILES := 0.45
## Two and a bit, not three: the shelf is what pushes the rubbish out, and the first net
## reaches three and a half tiles from a beach the angler may only step six pixels off. At
## three, the nearest piece of rubbish was exactly a cast away and the opening throw of a run
## caught nothing.
const SHELF_TILES := 2.2

## How far a rubbish tile is kept past the end of that shelf, in tiles. A piece is drawn a
## good deal wider than the tile it sits on, and one sitting exactly on the last row of sand
## overlaps it.
##
## Was 0.5, which held the ring a full half tile off sand that has already faded to nothing
## by then — the island sat in a moat of clean water it had not been cleaned out of. At 0.1
## the nearest rubbish is 2.3 tiles out: still clear of the drawn sand, close enough that the
## island reads as something the filth has washed up against rather than something it keeps
## away from. The overlap this guards against is a few pixels of a sprite over the faintest
## end of the shelf, which is what a piece of junk aground at the water's edge looks like.
const SHELF_CLEAR := 0.1


## How far past the water's edge a spot is, in tiles: negative under the island, zero at the
## edge the water is drawn to, and `SHELF_TILES` at the point where the sand under the lake
## has faded out altogether.
static func past_shelf(at: Vector2) -> float:
	var mean := (ISLAND_RADIUS.x + ISLAND_RADIUS.y) * 0.5 - WATER_LAP_TILES
	return (island_ring_fraction(at, WATER_LAP_TILES) - 1.0) * mean


## Is this tile on the strand line: water, right against the outer bank, in the band
## `floats_here` keeps the ordinary fill out of? This is where the small rubbish washes up —
## see LakeGrid.STRAND_CHANCE. Outer bank only; the island's own beach is kept tidy.
static func on_strand(tx: int, ty: int) -> bool:
	if not in_lake(tx, ty):
		return false
	if island_fraction(tx, ty) < 2.0:
		return false
	return shore_fraction(tx, ty) >= 1.0 - LAKE_EDGE


## The band of outer-bank beach rubbish lies on, in tiles past the waterline: from just clear
## of where the water is drawn (`WATER_LAP_TILES` up the sand) to a couple of tiles up the
## beach, well short of the grass. See LakeGrid.BEACH_CHANCE.
const BEACH_LITTER := Vector2(0.9, 2.4)


## Is this tile's middle on that band of the outer bank's beach? Dry sand, so a piece here
## lies still: no bob, no waterline, no foam.
static func on_beach(tx: int, ty: int) -> bool:
	return on_beach_at(Vector2(float(tx) + 0.5, float(ty) + 0.5), BEACH_LITTER.x, BEACH_LITTER.y)


## The same question of any spot, with the band's two edges given — the dog walks a little
## further either side of it than rubbish is laid.
static func on_beach_at(at: Vector2, from: float, to: float) -> bool:
	if island_fraction(at.x, at.y) < 2.0:
		return false
	var out := Ground.out_of_water(at.x, at.y)
	return out >= from and out <= to


## Is this spot on the island's dry ground, as it is seen?
##
## The curve, not the tile: the water shader discards itself inside this same ring, so what
## is seen as beach is exactly what this says is beach. It used to ask the tile under the
## spot instead, back when the island's diamonds were drawn over the water and their
## staircase was the edge that showed.
static func on_island_ground(at: Vector2) -> bool:
	return past_shelf(at) <= 0.0


## How far past the water's drawn edge a spot is, in world pixels: negative on the beach,
## zero on the edge, positive out in the water. `past_island` measured from the waterline,
## which is a little way out from where the water is actually drawn; anything that wants to
## know what the eye sees — is the angler standing in the water, and how deep — asks this.
##
## The spot and the edge below it lie on one ray out of the island's middle, and the ring
## fraction grows linearly along that ray (the wobble depends only on the angle, which the
## ray holds fixed), so the edge is the spot pulled back by that fraction — no search.
static func past_water(at: Vector2) -> float:
	var middle := tile_to_world(ISLAND_CENTRE.x, ISLAND_CENTRE.y)
	var here := tile_to_world(at.x, at.y) - middle
	var f := island_ring_fraction(at, WATER_LAP_TILES)
	if f < 0.0001:
		return -here.length()
	return here.length() * (1.0 - 1.0 / f)


## Is this tile far enough from both shores to float something on?
static func floats_here(tx: int, ty: int) -> bool:
	if not in_lake(tx, ty):
		return false
	# Out past the island's drowned sand, at whatever distance that is in this direction. Not
	# a fixed number of pixels: the shelf is measured on a squashed ellipse, so it reaches
	# twice as far out on one axis as on the other, and a flat margin leaves rubbish sitting
	# on sand down one side of the island and empty water down the next.
	if past_shelf(Vector2(tx, ty)) < SHELF_TILES + SHELF_CLEAR:
		return false
	return shore_fraction(tx, ty) < 1.0 - LAKE_EDGE


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


## How big the whole basin is on screen at zoom 1, in world pixels.
##
## Walked off `shore_outline` rather than worked out from RADIUS, because the wobble that
## makes the lake a lake rather than a dinner plate is what decides its widest point. Cheap
## enough to ask for whenever the view is clamped, and asked for there rather than cached so
## a change to the basin's shape cannot leave a stale number behind.
static func basin_extent(grow: float = 0.0) -> Vector2:
	var ring := shore_outline(grow)
	var lo := ring[0]
	var hi := ring[0]
	for at: Vector2 in ring:
		lo = Vector2(minf(lo.x, at.x), minf(lo.y, at.y))
		hi = Vector2(maxf(hi.x, at.x), maxf(hi.y, at.y))
	return hi - lo


## One point on the shore, at an angle round the lake and a distance out past the waterline,
## in world space. `shore_outline` is this walked all the way round; anything scattered
## along the bank wants one point at a time instead.
##
## The same wobble as `shore_outline` and `shore_fraction`, and it has to stay the same: the
## sand drawn here and the water's own edge are the same line seen from two sides.
static func shore_point(angle: float, grow: float = 0.0) -> Vector2:
	var wobble := 1.0 + 0.09 * sin(angle * 3.0) + 0.05 * sin(angle * 5.0 + 1.3)
	return tile_to_world(
		CENTRE.x + cos(angle) * (RADIUS.x * wobble + grow),
		CENTRE.y + sin(angle) * (RADIUS.y * wobble + grow)
	)


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
	var wobble := (
		1.0 + 0.07 * sin(angle * 3.0 + 0.7) + 0.035 * sin(angle * 5.0 - 0.4)
		+ 0.02 * sin(angle * 7.0 + 2.1)
	)
	return tile_to_world(
		ISLAND_CENTRE.x + cos(angle) * (ISLAND_RADIUS.x * wobble + grow),
		ISLAND_CENTRE.y + sin(angle) * (ISLAND_RADIUS.y * wobble + grow)
	)


## How far past the island's waterline a spot is, in world pixels. Negative on the beach,
## zero on the waterline, positive out in the water.
##
## `island_fraction` answers the same question as a fraction of the island's radius, which
## is not the same distance twice: the island is an ellipse in tile space and the projection
## stretches one diagonal against the other, so a tenth of a radius is four times as many
## pixels off the eastern shore as it is off the northern one. Anything that wants to be the
## same distance out all the way round — where a walker may stand, how deep it is standing —
## has to ask in pixels.
##
## Both the spot and the edge below it lie on the same ray out of the island's middle, in
## tile space and so also on screen, because the projection is linear. That makes this a
## comparison of two lengths along one line rather than a search for the nearest point on a
## wobbling outline.
static func past_island(at: Vector2) -> float:
	var middle := tile_to_world(ISLAND_CENTRE.x, ISLAND_CENTRE.y)
	var here := tile_to_world(at.x, at.y) - middle
	if here.length_squared() < 0.0001:
		return -island_point(0.0).distance_to(middle)
	var edge := island_point(basin_angle_of_island(at)) - middle
	return here.length() - edge.length()


## The angle round the island a spot sits at, as `island_point` takes it.
static func basin_angle_of_island(at: Vector2) -> float:
	return atan2(
		(at.y - ISLAND_CENTRE.y) / ISLAND_RADIUS.y, (at.x - ISLAND_CENTRE.x) / ISLAND_RADIUS.x
	)


## The island as the water shader sees it, with both its radii pulled in by `shrink` tiles.
##
## Not the same curve as `island_outline(-shrink)`, and the difference is the whole point.
## That one pushes the outline along its own radius, which is one distance; this one shrinks
## the ellipse, which on a shape half again as wide as it is tall is a third of a tile
## further in at the ends of the long axis than at the ends of the short one. The shader
## shrinks, so anything meant to sit on the water's edge has to shrink too.
static func island_ring(shrink: float, steps: int = 96) -> PackedVector2Array:
	var r := ISLAND_RADIUS - Vector2(shrink, shrink)
	var out := PackedVector2Array()
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		var wobble := (
			1.0 + 0.07 * sin(angle * 3.0 + 0.7) + 0.035 * sin(angle * 5.0 - 0.4)
			+ 0.02 * sin(angle * 7.0 + 2.1)
		)
		out.append(tile_to_world(
			ISLAND_CENTRE.x + cos(angle) * r.x * wobble,
			ISLAND_CENTRE.y + sin(angle) * r.y * wobble
		))
	return out


## How far out a spot is on that same shrunken island, as a fraction: 1 exactly on the
## water's edge. Mirrors the shader's `island_fraction` with its `shore_lap` applied.
static func island_ring_fraction(at: Vector2, shrink: float) -> float:
	var r := ISLAND_RADIUS - Vector2(shrink, shrink)
	var d := Vector2((at.x - ISLAND_CENTRE.x) / r.x, (at.y - ISLAND_CENTRE.y) / r.y)
	var len := d.length()
	if len < 0.0001:
		return 0.0
	var angle := atan2(d.y, d.x)
	var wobble := (
		1.0 + 0.07 * sin(angle * 3.0 + 0.7) + 0.035 * sin(angle * 5.0 - 0.4)
		+ 0.02 * sin(angle * 7.0 + 2.1)
	)
	return len / wobble


static func island_outline(grow: float = 0.0, steps: int = 96) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		var wobble := (
			1.0 + 0.07 * sin(angle * 3.0 + 0.7) + 0.035 * sin(angle * 5.0 - 0.4)
			+ 0.02 * sin(angle * 7.0 + 2.1)
		)
		var tx := ISLAND_CENTRE.x + cos(angle) * (ISLAND_RADIUS.x * wobble + grow)
		var ty := ISLAND_CENTRE.y + sin(angle) * (ISLAND_RADIUS.y * wobble + grow)
		out.append(tile_to_world(tx, ty))
	return out
