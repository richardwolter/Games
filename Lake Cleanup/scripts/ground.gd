## The ground the lake sits in, drawn as pixel-art tiles instead of flat fills.
##
## Everything that is not water is a tile from the Forest Isometric pack: the island, the
## three bands of bank around the waterline, and a wide ring of grass and soil past those
## that covers the ground out to well beyond what the camera can pull back to see.
##
## The tiles are cubes with a visible side, not flat diamonds, so they are drawn back to
## front by tile diagonal and the sides of the near ones cover the sides of the far ones.
## Only the outermost ring shows a side face, and the ring reaches far enough out that the
## view never gets there.
##
## What decides which tile goes where is `Iso`, not this file: the same `shore_fraction`
## and `island_fraction` the water shader and the walking rules read. The ground is a
## picture of the basin's shape rather than a second opinion about it.
class_name Ground
extends Node2D

## Where the pack's individual tiles live.
const TILES := "res://assets/Forest Isometric Pack Free/Tileset/Slice %d.png"

## One source pixel to this many screen pixels. At 2.0 a pack tile's top face is exactly one
## game tile, which is what makes the ground grid and the lake's tile grid the same grid.
## At 1.0 the ground is four tiles to a lake tile: finer, and it reads as further away.
const SCALE := 2.0

## A pack tile is this square, and its top face is this tall inside it. The rest is the side
## of the cube, which hangs below the plane.
const SPRITE := 32.0
const FACE := 16.0

## How far above the sand the grass sits, in screen pixels.
##
## The pack's tiles are not all the same height — grass is a full cube and sand is a slab —
## and where in its cell a tile's top face starts is measured per tile and taken out again
## when it is drawn, so every top face lands on one plane. This is what is deliberately put
## back: a lawn wants an edge to catch the light, and a lawn exactly level with the beach
## reads as a colour change rather than as ground. It was 24 by accident, which was a ledge.
const GRASS_LIFT := 4.0

## Which slices go where.
##
## The pack's ground tiles are an edge set, not a bag of variants: a tile carries its lip —
## or, on the grass, its worn patch of sand — along whichever of its sides and corners the
## terrain stops at, and the plain ones are what goes in the middle. Picking from them at
## random is what put lips across the middle of the beach.
##
## Grass in the open. Two pools: the island is a kept yard and the mainland is not, so the
## plain lighter tiles belong to one and the darker, tuftier ones to the other. Nothing is in
## both, which is what keeps the island reading as tended from across the water.
const GRASS_YARD := [1, 2, 19]
const GRASS_ROUGH := [18, 20, 21]

## How wide a patch of one grass tile is, in tiles.
##
## Grass used to be picked per tile, which on ground made of one repeated diamond is a
## shimmer: every square a different texture, and no square part of anything. Picked per
## patch instead, a texture holds across a few tiles and the lawn has areas to it rather than
## a different square everywhere you look.
const GRASS_PATCH := 3.0

## How far out of the water the beach reaches, in tiles, and how far the grass past it runs
## before the outer ring takes over.
##
## Wider than the flat-colour bands they replace (2.8 for the sand): those were a gradient
## of fill and speckle, where these are whole tiles, and a band under two tiles wide comes
## out as a single ragged row that reads as an accident. There is no wet-sand band any more
## — the pack has no darker sand, and the lip at the waterline is what marks the edge.
const SAND_OUT := 5.0
const BANK_OUT := 9.0

## How far short of the waterline the ground stops, in screen pixels.
##
## The lapping water, done from the land's side: rather than painting water over sand, the
## sand simply is not laid where the water is drawn, and the grown water polygon underneath
## shows through. Same picture, and it buys the thing painting over the top cannot — the
## visible shore is now a tile edge, which is what the foam and the earth side hug.
##
## Matches `Lake.SHORE_LAP`, the same distance stated in tiles.
const WATER_LAP := 16.0

## How far one step in tile space carries across the screen, in pixels. The projection puts
## a tile step at half a tile across and half a tile down, so this is the diagonal of that.
const TILE_STEP := 35.777

## The same lap `Lake.SHORE_LAP` grows the water polygon by, in tiles. Where the water is
## actually drawn to, which is what the ground has to hide under and what the foam has to
## sit on — not the waterline Iso holds, which is a little way inside it.
const LAP := Iso.WATER_LAP_TILES

## Sand. One tile, everywhere, whatever is next to it.
##
## The pack has a set of rimmed pieces for the edges of sand and a set of half-sand pieces
## for the grass that meets it, and both are unused: the rim drew a dark line wherever the
## sand stopped, and the half-sand tiles read as dirt patches in the lawn. Ground that runs
## out under the water at one end and under the turf at the other does not want either.
const SAND := 67

## How far in from the island's waterline the grass starts, in tiles. Everything outside it
## is beach.
##
## Wide enough that the beach has a middle to it: a shore one tile across is all edge, and
## every tile of it takes the rimmed-all-round piece, which reads as a kerb. Not much wider,
## though — the grass tiles that meet the sand are half sand on top, so the lawn always reads
## a tile smaller than this says, and an island that is all beach has no middle either.
const BEACH_IN := 2.6

## How far past the waterline the ring of ground reaches, in tiles.
##
## Well past anything the view can pull back to: the last row of it shows the side of its own
## tiles, and that is only hidden if the last row is somewhere nobody can look.
##
## Sized for the worst case, not the average one: `Lake._clamped_view` only keeps the
## viewport's bounding box inside the ring's bounding box, and the ring is an ellipse, so its
## own corners fall well short of that box's corners. A screen's actual corner, at the far
## end of the zoom, can be up to root two times as far from the middle as the box's edge —
## same reason `Iso.tile_circle_extent` isn't `radius * TILE_W * 0.5`. Grown by that factor
## over the old, box-sized reach so the ring's true edge (not its box) clears every corner,
## plus 200 more world pixels of slack past that so the treeline is never exactly on the edge.
const OUTER_OUT := 42.1

## How far the line between beach and grass wanders off the ellipse underneath it, in tiles.
##
## Everything here is drawn from two ellipses, and an ellipse stepped into tiles still reads
## as a machined curve — a ring of sand of even width, which is a shape nothing on a lake
## has. Rolled from the tile's own position and a fixed seed, so the same bays and points are
## in the same places every run.
##
## Only the mainland's beach against its grass. The beach against the water is under the
## drawn water at both shores, so wobbling it moves tiles nobody can see — and the island's
## lawn is a kept yard, which has a decided edge rather than a wandering one.
const EDGE_WANDER := 0.55

## How far the island's sand carries on past the water's edge, in tiles, how far each of
## those tiles is dropped down the screen, in pixels, and how much of the water's colour is
## mixed into the last of them.
##
## Three tiles at the island, which is as much shelf as it can have: past that the rubbish
## would be floating over sand it cannot be told apart from, and the first cast has to reach
## the nearest piece from the beach. The island used to stop dead at the waterline, which
## left it standing on the lake like a coin on a table. A shore does not stop, it goes under: the sand keeps going out, each row
## a little lower and a little more the colour of the water than the one before, until it is
## the water. The outer bank gets this for nothing — its sand runs on under the lake and the
## water is drawn over it — and this is the island being given the same thing by hand.
const SINK_REACH := Iso.SHELF_TILES

## How far each drowned row is dropped, in screen pixels.
##
## Bounded by the height of a sand slab's own side — six pixels drawn — and that is a
## ceiling, not a preference. A row dropped further than the tile in front of it is tall
## opens a gap under it that the lake shows through, and a bed of sand with a seam under
## every row is worse than a flat one. It was nine, and every one of those seams was visible.
##
## Well under that ceiling now. Two pixels a row is barely a slope at all, which is the point:
## the water going darker is what says the bed is dropping away, and the geometry only has to
## agree with it rather than announce it.
const SINK_STEP := 2.0

## How much of the water's colour is mixed into the sand at the top of the shelf and at the
## bottom of it, and the colour itself.
##
## The top is not zero: a piece of sand a hand's width under the surface is already seen
## through water, and the point of the whole band is that the tiling stops being something
## you can count. The bottom is one, and has to be: a shelf that stops at anything less ends
## on a row of half-visible tiles, which is a row of tips along the deep edge.
const SINK_TINT := Color(0.30, 0.50, 0.52)

## How much a drowned tile's fade is nudged off the smooth curve above, by a stable per-tile
## hash.
##
## The curve itself is smooth, but each tile is still its own flat-shaded quad, and a run of
## quads at almost-equal fade, stepping down in an even row, reads as a staircase however
## gently the colour moves between them. Jittered, it reads as noise instead of a countable
## row.
const DISSOLVE_JITTER := 0.10

## How far into the fade the first drowned row already is.
##
## Not zero, or that row is full-strength sand with the tiles' own staircase along its edge —
## a hard step exactly where the ground is meant to stop being a thing with an edge.
const SINK_FADE_START := 0.4

## The wood on the far bank: which pictures, how thickly they stand, and how they keep out
## of each other's way.
##
## Trees thicken with distance from the water — a few scattered along the grass line, closed
## canopy by the outer edge, which is what hides where the ground stops rather than leaving
## the map to end on a row of tiles. Rocks fill open ground between them and never sit on a
## trunk. Leaves are undergrowth and may lie under anything.
## The living trees are listed three times each and the dead ones once, which is the whole of
## the weighting: the pack has two dead trees to three living, and a wood that is two fifths
## dead reads as a blight rather than as a wood.
const TREES := [
	"res://assets/Forest Isometric Pack Free/Trees/Tree_1.png",
	"res://assets/Forest Isometric Pack Free/Trees/Tree_2.png",
	"res://assets/Forest Isometric Pack Free/Trees/Tree_3.png",
	"res://assets/Forest Isometric Pack Free/Trees/Tree_1.png",
	"res://assets/Forest Isometric Pack Free/Trees/Tree_2.png",
	"res://assets/Forest Isometric Pack Free/Trees/Tree_3.png",
	"res://assets/Forest Isometric Pack Free/Trees/Tree_1.png",
	"res://assets/Forest Isometric Pack Free/Trees/Tree_2.png",
	"res://assets/Forest Isometric Pack Free/Trees/Tree_3.png",
	"res://assets/Forest Isometric Pack Free/Trees/death_Tree_2.png",
	"res://assets/Forest Isometric Pack Free/Trees/death_Tree_3.png",
]
const ROCKS := "res://assets/Forest Isometric Pack Free/Rocks/Slice %d.png"
const ROCK_COUNT := 5
const LEAVES := "res://assets/Forest Isometric Pack Free/Leaves/Slice %d.png"
const LEAF_COUNT := 17

## Where the wood begins and where it is thickest, in tiles out from the waterline, and how
## much of the ground is trees at each end.
##
## Thin at the line and solid a few tiles behind it, which is all the run there is: the view
## stops a little way into the wood, so everything past that is thickening the eye never sees
## and sprites drawn for nobody.
const WOOD_FROM := 10.0
const WOOD_FULL := 19.0

## And the same again, measured a different way: how far out of the basin's own box a tile
## is, where 1 is on the box and more is outside it.
##
## Distance past the waterline alone leaves the corners of the window thin. The lake is an
## ellipse and the window is a rectangle, so the ground that lands in the corners is only a
## few tiles past the shore while the ground that fills the sides is the same few tiles — the
## same density, spread over four times the area, reads as bare. This thickens what sits
## beyond the ends of the ellipse without touching the sides, where the wood is already
## right.
const WOOD_CORNER_FROM := 1.0
const WOOD_CORNER_FULL := 1.12
const WOOD_THIN := 0.03
const WOOD_THICK := 0.4

## How much of the open ground gets a rock, and how much of everything gets a leaf.
const ROCK_SHARE := 0.16
const LEAF_SHARE := 0.10

## And on the island: tufts only, sparse, and nothing else. They are undergrowth with no
## collision, so the angler and the dog walk over them rather than round them.
const ISLAND_LEAF_SHARE := 0.14

## Fixed, so a change to the bands is a comparison rather than a new roll of the dice.
const SEED := 20260907

## Which part of the ground this node draws.
##
## The ground outside is drawn below the water, which is what lets the lake's own curve be
## its edge. The island is drawn above it, because it is a hole in that curve. And each of
## them has a second pass over the top — the sand that carries on into the lake and drowns,
## fading as it goes, so neither shore ends anywhere in particular.
enum Layer { OUTSIDE, ISLAND, ISLAND_DEEP }

## What is on the ground at a tile. WATER is the shader's, and NONE is off the end of what
## this layer covers; both draw nothing, but they are not the same to a neighbour — sand
## takes a lip against water and stops caring past the ring.
enum Kind { NONE, WATER, SAND, GRASS }

var layer: Layer = Layer.OUTSIDE
var _dirty: bool = true

## Mesh data per slice: indices, points, uvs, colors
var _mesh_data: Dictionary = {}  # slice -> {indices, points, uvs, colors}

## Slice number to picture. Filled before the first draw rather than as the tiles come up:
## asking for a texture in the middle of `_draw` hands back a blank while the loader is
## still busy with everything else the lake opens with, and a blank texture draws as a
## white square.
var _art: Dictionary = {}

## What stands on each tile, as tile coordinates to a list of pictures. Worked out once, on
## the way in, because it depends on what its neighbours got — a rock has to know whether the
## tile beside it took a tree.
var _props: Dictionary = {}

## Which tiles have something standing on them — a tree or a rock. Leaves are not in here:
## they lie under things rather than taking up room.
var _standing: Dictionary = {}

## Where each picture's top face starts inside its cell, in source pixels. Measured rather
## than assumed: the pack draws a slab and a cube in the same size of cell, and drawing both
## from the cell's corner is what put the lawn two dozen pixels above the sand.
var _face_top: Dictionary = {}

## How far out of the water a tile is, in tiles. `shore_fraction` is a fraction of the
## radius in that tile's own direction, so it is scaled back up by the radius it came from
## rather than by an average of the two.
static func out_of_water(tx: float, ty: float) -> float:
	var d := Vector2((tx - Iso.CENTRE.x) / Iso.RADIUS.x, (ty - Iso.CENTRE.y) / Iso.RADIUS.y)
	var reach := Vector2(d.x * Iso.RADIUS.x, d.y * Iso.RADIUS.y).length()
	var s := Iso.shore_fraction(tx, ty)
	if s <= 0.0001:
		return -reach
	return reach * (s - 1.0) / s


func _ready() -> void:
	# Nearest, or the pack's pixels come out smeared. Set here rather than on the project so
	# the rest of the art keeps the filtering it was drawn against.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The island sits above the water; the ground outside sits under it.
	#
	# Which way round is what decides the shape of the coast. Tiles are diamonds, so a shore
	# drawn by where the tiles stop is a staircase however carefully they are picked. The
	# water's own polygon is a curve, and laying that over the sand is what makes the lake
	# round. Outside it can: the water is a disc and the ground is around it. On the island
	# it cannot — the island is a hole in that disc — so its coast is carried by the sand that
	# walks out under the lake and drowns. See SINK_REACH.
	# The island and its shallows both sit above the water; only the ground outside is under
	# it. Under the water the shallows were hidden well enough to be honest and not enough to
	# be any use: the island still ended on a hard ring, and the point of them is that it
	# should not end anywhere in particular. Over the water they fade out instead.
	# Under the water: the ground outside, and the shelf it sends down into the lake. Over it:
	# the island and its own shelf, because the island is a hole in the water and nothing can
	# be laid over it from below.
	#
	# Standing over the water is why the shelf may not be painted with water of its own. It
	# was, for a while: a flat SINK_TINT diamond per tile, drawn last, thickening to full
	# opacity at the deep end so the sand under it could not be counted. A fixed colour
	# cannot be the water it is standing on. The shader below varies by depth, by the bands
	# moving through it, by the foam, and now by the filth on that particular tile — the
	# overlay followed none of it, so it read as a row of teal plates pasted on the lake,
	# worst exactly where it was thickest, all the way round the island.
	#
	# The tiles' own fade is the whole of it now: they thin out into the real water rather
	# than being covered by a picture of it. If the middle of the shelf reads as dry sand,
	# SINK_FADE_START is the number to move. Do not bring back a plate.
	#
	z_index = 1 if layer == Layer.OUTSIDE else 3
	z_as_relative = false
	for slice: int in _every_slice():
		var tex := load(TILES % slice) as Texture2D
		_art[slice] = tex
		_face_top[slice] = _top_of(tex)
		_mesh_data[slice] = {
			"indices": PackedInt32Array(),
			"points": PackedVector2Array(),
			"uvs": PackedVector2Array(),
			"colors": PackedColorArray()
		}
	_sow()
	_dirty = true
	queue_redraw()


## Scatter the wood. Trees first, so the rocks can see where they are.
##
## One pass over the ground, deciding by position rather than by rolling as we go: the same
## wood every run, and adding a tree in one place does not reshuffle every tree after it.
func _sow() -> void:
	if layer == Layer.ISLAND:
		_sow_island()
		return
	if layer != Layer.OUTSIDE:
		return
	var span := _span()
	for tx in range(span.position.x, span.end.x + 1):
		for ty in range(span.position.y, span.end.y + 1):
			var at := Vector2(float(tx) + 0.5, float(ty) + 0.5)
			if _kind_at(at.x, at.y) != Kind.GRASS:
				continue
			var out := out_of_water(at.x, at.y)
			var thick := clampf((out - WOOD_FROM) / (WOOD_FULL - WOOD_FROM), 0.0, 1.0)
			var share: float = lerpf(WOOD_THIN, WOOD_THICK, thick * thick)
			# Whichever reading says it is further out of the way: the tiles beyond the ends
			# of the lake take the corner's answer, the ones beside it keep the shore's.
			var corner := clampf(
				(_boxed(at) - WOOD_CORNER_FROM) / (WOOD_CORNER_FULL - WOOD_CORNER_FROM),
				0.0, 1.0
			)
			share = maxf(share, lerpf(WOOD_THIN, WOOD_THICK, corner))
			if out < WOOD_FROM or _hash(at.x * 3.1, at.y * 2.7) > share:
				continue
			_stand(Vector2i(tx, ty), load(TREES[
				int(_hash(at.y * 5.3, at.x * 1.9) * float(TREES.size())) % TREES.size()
			]) as Texture2D)

	# Then the rocks, on open ground only: not on a tree, and not beside one, because a
	# canopy hangs over the tile in front of it and a rock under that reads as a mistake.
	for tx in range(span.position.x, span.end.x + 1):
		for ty in range(span.position.y, span.end.y + 1):
			var at := Vector2(float(tx) + 0.5, float(ty) + 0.5)
			if _kind_at(at.x, at.y) != Kind.GRASS:
				continue
			if _wooded(tx, ty):
				continue
			if _hash(at.x * 7.7, at.y * 4.3) > ROCK_SHARE:
				continue
			_stand(Vector2i(tx, ty), load(
				ROCKS % (1 + int(_hash(at.y * 2.2, at.x * 6.1) * float(ROCK_COUNT)) % ROCK_COUNT)
			) as Texture2D)

	# And the leaves, which lie under everything and mind nothing.
	for tx in range(span.position.x, span.end.x + 1):
		for ty in range(span.position.y, span.end.y + 1):
			var at := Vector2(float(tx) + 0.5, float(ty) + 0.5)
			if _kind_at(at.x, at.y) != Kind.GRASS:
				continue
			if _hash(at.x * 1.3, at.y * 8.9) > LEAF_SHARE:
				continue
			_litter(Vector2i(tx, ty), at)


## The island's tufts, on its grass and its sand alike.
func _sow_island() -> void:
	var span := _span()
	for tx in range(span.position.x, span.end.x + 1):
		for ty in range(span.position.y, span.end.y + 1):
			var at := Vector2(float(tx) + 0.5, float(ty) + 0.5)
			var kind := _kind_at(at.x, at.y)
			if kind != Kind.GRASS and kind != Kind.SAND:
				continue
			if Iso.in_shed(at.x, at.y, Iso.SHED_KEEP):
				continue
			if _hash(at.x * 9.1, at.y * 3.7) > ISLAND_LEAF_SHARE:
				continue
			_litter(Vector2i(tx, ty), at)


## One tuft, added under whatever else is on the tile.
func _litter(cell: Vector2i, at: Vector2) -> void:
	var leaf := load(
		LEAVES % (1 + int(_hash(at.y * 4.7, at.x * 2.3) * float(LEAF_COUNT)) % LEAF_COUNT)
	) as Texture2D
	if _props.has(cell):
		_props[cell].insert(0, leaf)
	else:
		_props[cell] = [leaf]


## One thing standing on a tile, claiming it against anything else that stands.
func _stand(cell: Vector2i, art: Texture2D) -> void:
	if _props.has(cell):
		_props[cell].append(art)
	else:
		_props[cell] = [art]
	_standing[cell] = true


## Is there a tree on this tile or against it? See the rocks in `_sow`.
func _wooded(tx: int, ty: int) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if _standing.has(Vector2i(tx + dx, ty + dy)):
				return true
	return false


func _draw() -> void:
	if _dirty:
		_rebuild()

	# Submit triangle arrays per slice
	for slice: int in _mesh_data.keys():
		var data = _mesh_data[slice]
		if data["indices"].is_empty():
			continue
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(),
			data["indices"],
			data["points"],
			data["colors"],
			data["uvs"],
			PackedInt32Array(),
			PackedFloat32Array(),
			_art[slice].get_rid()
		)

	# Props and drowning are still drawn per-tile (optimization can come later)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var span := _span()
	for s in range((span.position.x + span.position.y), (span.end.x + span.end.y) + 1):
		for tx in range(span.position.x, span.end.x + 1):
			var ty := s - tx
			if ty < span.position.y or ty > span.end.y:
				continue
			var mid := Iso.tile_to_world(float(tx) + 0.5, float(ty) + 0.5)
			_plant(Vector2i(tx, ty), mid)


func _rebuild() -> void:
	_dirty = false
	# Clear all mesh data
	for slice in _mesh_data.keys():
		_mesh_data[slice]["indices"].resize(0)
		_mesh_data[slice]["points"].resize(0)
		_mesh_data[slice]["uvs"].resize(0)
		_mesh_data[slice]["colors"].resize(0)

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var span := _span()

	# Iterate tiles in painter's order (back to front by diagonal)
	for s in range((span.position.x + span.position.y), (span.end.x + span.end.y) + 1):
		for tx in range(span.position.x, span.end.x + 1):
			var ty := s - tx
			if ty < span.position.y or ty > span.end.y:
				continue
			var slice := _slice_at(float(tx) + 0.5, float(ty) + 0.5, rng)
			if slice == 0:
				continue

			var mid := Iso.tile_to_world(float(tx) + 0.5, float(ty) + 0.5)
			var lift: float = _face_top[slice] * SCALE
			if slice != SAND:
				lift += GRASS_LIFT

			var tint := Color.WHITE
			if layer == Layer.ISLAND_DEEP:
				var sunk := _sunk_by(Vector2(float(tx) + 0.5, float(ty) + 0.5))
				var deep := clampf(sunk / SINK_REACH, 0.0, 1.0)
				lift -= sunk * SINK_STEP
				# See DISSOLVE_JITTER. Offset from `_pick`'s and `_wander`'s own sampling
				# points so it doesn't just retrace their pattern.
				var jitter := (_hash(tx + 11.0, ty - 7.0) - 0.5) * 2.0 * DISSOLVE_JITTER
				var fade := clampf(
					SINK_FADE_START + (1.0 - SINK_FADE_START) * sqrt(deep) + jitter, 0.0, 1.0
				)
				tint = Color.WHITE.lerp(Color(SINK_TINT, 0.0), fade)

			_add_tile_quad(slice, mid, lift, tint)


func _add_tile_quad(slice: int, mid: Vector2, lift: float, tint: Color) -> void:
	var data: Dictionary = _mesh_data[slice]
	var tex: Texture2D = _art[slice]
	if tex == null:
		return

	# Quad corners in screen space
	var half_w: float = Iso.TILE_W * 0.5
	var half_h: float = Iso.TILE_H * 0.5 + lift
	var tl: Vector2 = mid - Vector2(half_w, half_h)
	var tr: Vector2 = mid + Vector2(half_w, -half_h)
	var br: Vector2 = mid + Vector2(half_w, half_h)
	var bl: Vector2 = mid + Vector2(-half_w, half_h)

	var base_idx: int = data["points"].size()
	data["points"].append(tl)
	data["points"].append(tr)
	data["points"].append(br)
	data["points"].append(bl)

	# UVs: full texture
	data["uvs"].append(Vector2(0, 0))
	data["uvs"].append(Vector2(1, 0))
	data["uvs"].append(Vector2(1, 1))
	data["uvs"].append(Vector2(0, 1))

	# Colors
	data["colors"].append(tint)
	data["colors"].append(tint)
	data["colors"].append(tint)
	data["colors"].append(tint)

	# Two triangles
	data["indices"].append(base_idx + 0)
	data["indices"].append(base_idx + 1)
	data["indices"].append(base_idx + 2)
	data["indices"].append(base_idx + 0)
	data["indices"].append(base_idx + 2)
	data["indices"].append(base_idx + 3)


## The trees, rocks and tufts on one tile, standing on its middle.
##
## Sat on the plane by their feet, not their middles: everything in the pack is drawn as a
## thing standing on the ground, and hanging it by the centre would bury half of every trunk.
func _plant(cell: Vector2i, mid: Vector2) -> void:
	if not _props.has(cell):
		return
	for art: Texture2D in _props[cell]:
		var size := Vector2(art.get_width(), art.get_height()) * SCALE
		draw_texture_rect(
			art,
			Rect2(mid - Vector2(size.x * 0.5, size.y - Iso.TILE_H * 0.5), size),
			false
		)


## The first row of a picture that has anything in it, in source pixels. The top face starts
## there; everything above is the empty part of the cell.
func _top_of(tex: Texture2D) -> int:
	var img := tex.get_image()
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				return y
	return 0


## The box of tiles this layer covers. The island is a handful of tiles in the middle; the
## ground outside runs to the far edge of the ring, which is well past the tile field the
## rubbish uses.
func _span() -> Rect2i:
	if layer == Layer.ISLAND or layer == Layer.ISLAND_DEEP:
		var r := Iso.ISLAND_RADIUS + Vector2.ONE * (SINK_REACH + 2.0)
		return Rect2i(
			Vector2i(Iso.ISLAND_CENTRE - r), Vector2i(r * 2.0) + Vector2i.ONE
		)
	var out := Iso.RADIUS + Vector2.ONE * (OUTER_OUT * 1.3)
	return Rect2i(Vector2i(Iso.CENTRE - out), Vector2i(out * 2.0) + Vector2i.ONE)


## What kind of ground is at a spot on the plane, or NONE for what this layer does not draw:
## the water, which is the shader's, and anything past the outer ring.
##
## Kept apart from which picture to use, because the edges need it for the neighbours as well
## as for the tile itself, and a neighbour's picture is none of this tile's business.
func _kind_at(tx: float, ty: float) -> Kind:
	var at := Vector2(tx, ty)
	var island := Iso.island_fraction(at.x, at.y)
	if layer == Layer.ISLAND or layer == Layer.ISLAND_DEEP:
		# Each of the two draws only its own half of the island: the part standing out of the
		# lake, and the part walking down into it.
		var sunk := _sunk_by(at)
		if (sunk > 0.0) != (layer == Layer.ISLAND_DEEP):
			return Kind.NONE
		# Back from the shoreline by more than half a tile, so no tile's corner reaches past
		# the ring drawn over it. A diamond is widest at its corners, and one whose middle is
		# just inside the curve still pokes its points out through it.
		if sunk > SINK_REACH:
			return Kind.NONE
		# The beach is the outside of the island; the grass starts a little in from it.
		#
		# Never at the very rim, whatever the wander says. A grass tile is a full cube where
		# the sand is a slab, so one at the water's edge hangs its side down past the wash
		# and stands in the lake like a lump of turf someone dropped.
		if Iso.island_ring_fraction(at, LAP + 1.8) >= 1.0:
			return Kind.SAND
		var beach := (1.0 - island) * (Iso.ISLAND_RADIUS.x + Iso.ISLAND_RADIUS.y) * 0.5
		# No wander here. The mainland's shoreline wanders because a shore does; the island's
		# lawn is a yard around a shed, and a yard has an edge somebody decided on.
		return Kind.GRASS if beach > BEACH_IN else Kind.SAND

	if island < 1.0:
		return Kind.NONE
	var out := out_of_water(at.x, at.y)
	# A tile inside the waterline, not at it. The tiles' own edge is a staircase, so it has to
	# start far enough under the water that the water's curve is always the edge that is seen.
	if out < -1.0 - LAP:
		return Kind.WATER
	if out > OUTER_OUT:
		return Kind.NONE
	return Kind.SAND if out < SAND_OUT + _wander(at) else Kind.GRASS


## How far out of the basin's own box a spot is, on the screen's axes rather than the lake's:
## 1 on the box, more outside it. See WOOD_CORNER_FROM.
func _boxed(at: Vector2) -> float:
	var half := Iso.basin_extent() * 0.5
	var here := Iso.tile_to_world(at.x, at.y) - Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)
	if half.x <= 0.0 or half.y <= 0.0:
		return 0.0
	return maxf(absf(here.x) / half.x, absf(here.y) / half.y)


## How far past the water's edge a spot is, in tiles: zero on dry ground, positive out in
## the lake, where the sand is drowning.
##
## The island's only. The bank had a shelf of its own for a while and it never sat right:
## seen almost edge-on from where the camera is, a row of tiles stepping down into the water
## reads as tiles, however faint they are drawn. The bank's sand simply runs under the lake
## and the water's own curve is its edge.
func _sunk_by(at: Vector2) -> float:
	return maxf(Iso.past_shelf(at), 0.0)


## How far the beach reaches past its ellipse at this spot, in tiles. See EDGE_WANDER.
##
## Two waves of different lengths rather than one roll a tile: a roll a tile is a ragged
## fringe, where what a shore has is bays a few tiles across with smaller bites out of them.
func _wander(at: Vector2) -> float:
	var coarse := sin(at.x * 0.41 + at.y * 0.29) + sin(at.x * 0.17 - at.y * 0.53 + 2.1)
	var fine := sin(at.x * 1.13 - at.y * 0.87 + 0.6)
	return (coarse * 0.36 + fine * 0.28) * EDGE_WANDER


## Which tile a spot gets, or 0 for nothing drawn.
##
## One picture for sand and one pool of pictures for grass, and nothing in between. The pack
## has pieces for the join — grass tops with sand worn through one side — and they were used
## here until it was plain that a lawn edged in half-sand tiles reads as a lawn with dirt
## patches in it rather than as a lawn meeting a beach.
func _slice_at(tx: float, ty: float, rng: RandomNumberGenerator) -> int:
	var kind := _kind_at(tx, ty)
	if kind == Kind.NONE or kind == Kind.WATER:
		return 0

	if kind == Kind.SAND:
		return SAND
	return _pick(GRASS_YARD if layer != Layer.OUTSIDE else GRASS_ROUGH, tx, ty, rng)


## Every slice this node can draw, so they are all in hand before the first frame.
func _every_slice() -> Array:
	var out: Array = GRASS_YARD.duplicate()
	out.append_array(GRASS_ROUGH)
	out.append(SAND)
	return out


## One of a set, chosen by where the tile is rather than by how far into the draw we are, so
## adding ground somewhere does not reshuffle the ground everywhere else.
func _pick(of: Array, tx: float, ty: float, _rng: RandomNumberGenerator) -> int:
	var patch := Vector2(floor(tx / GRASS_PATCH), floor(ty / GRASS_PATCH))
	return of[int(_hash(patch.x, patch.y) * float(of.size())) % of.size()]


## A stable number in 0..1 for a spot on the plane.
func _hash(x: float, y: float) -> float:
	var h := sin(x * 127.1 + y * 311.7 + float(SEED) * 0.0001) * 43758.5453
	return h - floor(h)
