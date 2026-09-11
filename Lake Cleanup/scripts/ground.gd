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

## The daylight, handed over by the level, and where the sun was when this was last baked.
## Null anywhere there is no day — the ground then draws no shadows at all rather than
## guessing at a sun the rest of the scene would disagree with.
var day: DayCycle
var _sun_baked: float = INF

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

## How far short of the face/side boundary a clipped quad's UV is pulled back, in source
## pixels at the pack's own resolution.
##
## Found by rendering a low skirt against an earth-sided tile and comparing pixel colour to
## the source image row by row: the boundary itself sampled true, but a solid extra source
## row of the tile's own dirt still showed past it, on every one of them. Nearest filtering
## rounds a fragment to the nearer texel, and a UV sitting exactly on the boundary rounds to
## either side of it by the width of half a texel — for a fragment unlucky enough to land
## past the middle of the last kept row, that is the first row of dirt. One row of headroom
## is enough that no rounding reaches across it.
const SEAM_GUARD := 6.0

## How far above the sand the grass sits, in screen pixels.
##
## The pack's tiles are not all the same height — grass is a full cube and sand is a slab —
## and where in its cell a tile's top face starts is measured per tile and taken out again
## when it is drawn, so every top face lands on one plane. This is what is deliberately put
## back: a lawn wants an edge to catch the light, and a lawn exactly level with the beach
## reads as a colour change rather than as ground. It was 24 by accident, which was a ledge.
##
## Four was as good as nothing. The tile in front is drawn after this one and its top face
## covers everything below its own plane, so a lawn lifted by less than a few pixels has its
## side face painted out by the beach and the two come out level — the turf reading as if it
## were the lower of the two. What is seen is exactly this many pixels of the grass tile's
## own side standing above the sand, so this is the height of the step, not a nudge towards
## one.
##
## Three. Eight was a proper kerb once the batches were put in height order and the step
## actually showed — a lawn on a plinth. What is wanted is the line a lawn's edge catches,
## which is about as thin as it can be and still be there.
const GRASS_LIFT := 0.1

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

## The border pool: what a lawn tile takes when the tile past it is sand.
##
## The plain grass tiles are a cube with a flat-cut face — nothing stands proud of the
## diamond's own edge — and on the two front sides, south-east and south-west, that edge is
## also where the lawn ends. A straight cut against sand reads as a cut picture there, not as
## turf, because there is no silhouette to catch the eye before the sand starts. The back two
## sides get away with it because the pack draws a few blades leaning up over those edges;
## the front two do not.
##
## These four are low tufted mounds instead, bushy on every side including the front two, and
## with no bare-earth side to clash with the flat sand next to them — see
## `tools/tile_sides.gd`. Border tiles are picked from this pool at random rather than one
## fixed tile, same as the open lawn, so the seam does not repeat itself in a visible pattern.
##
## One pool, not two. The pack's tufted mounds are all light — measured, not eyeballed, see
## `tools/tile_color_check.gd` — and nothing in it is dark enough to sit next to
## GRASS_ROUGH without standing out worse than a cut edge does. GRASS_YARD and GRASS_ROUGH
## stay apart everywhere else; only the border, where there is no darker tile to keep them
## apart with, shares this one.
const GRASS_BORDER := [37, 38, 43, 45]

## Why the pack's joining pieces are not used.
##
## The pack has grass tops with sand worn through them, and they look like the answer to a
## lawn meeting a beach. `tools/tile_edges.gd` reads the sand off each tile's four sides, and
## the set is a corner set — sand along two adjacent sides or three, never one — so a straight
## run of shore has no piece. Fitting them anyway (two-side pieces on the straights, and two
## generated pieces for the corners the pack lacks) was tried and rejected: the sand on each
## face stops on the tile's own diagonal, so a shore of them reads as a staircase of diagonal
## cuts, worse than the plain edge it replaced.
##
## What the shore is instead is a mixed band — see `BLEND` — made only of tiles the pack has
## whole: rough grass, the low tufted mounds, sand with tufts on it, and plain sand.

## Sand with grass growing through it: the pack's sand cubes with a tuft or two on top. Not
## sand for the beach — a beach of them is a beach with a rash — but the middle of the mixed
## band, where a tile is neither lawn nor beach yet.
const SAND_TUFTED := [6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

## How wide the mixed band between lawn and beach is, in tiles, either side of the line
## `_kind_at` draws.
##
## Tiles are diamonds, and a line between two kinds of tile is a staircase whatever the
## pieces are. What a real edge has is a width: grass thinning out, sand showing through,
## then sand with the odd tuft left in it. So a tile within BLEND of the line does not take
## its kind's picture outright; it rolls, by a stable hash, between the four pictures in
## proportion to how far across the line it sits. On the grass side the roll runs rough grass
## to tufted mound to tufted sand; on the sand side tufted sand to plain sand. `BLEND_TUFTS`
## is how much of the band's sand side keeps tufts at the line itself.
const BLEND := 2.2
const BLEND_TUFTS := 0.8

## How wide a patch of one grass tile is, in tiles, and how far a patch's middle is allowed to
## wander off the lattice, as a fraction of that width.
##
## Grass used to be picked per tile, which on ground made of one repeated diamond is a
## shimmer: every square a different texture, and no square part of anything. Then it was
## picked per `floor(tx / 3)` square, which is worse in its own way: those squares are squares
## in tile space, so on screen they are diamonds, all the same size, all lined up — a
## checkerboard laid over the lawn at forty-five degrees, which is exactly what a lawn does
## not have.
##
## A patch is now the ground nearest one of a set of scattered points, measured on the screen
## rather than in tile space. Round-ish areas of uneven size with wandering borders, and no
## two the same. The points are rolled from the lattice cell they belong to and the SEED, so
## the same lawn comes up every run and adding ground in one place does not move a patch
## anywhere else.
@export var grass_patch: float = 4.0
@export_range(0.0, 0.5) var grass_patch_wander: float = 0.42

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

## The fringe that hangs over the sand: where the strips are, how many there are, and how
## they sit against the tile they hang off.
##
## A grass tile is drawn as a rectangle cut off a hair below its top face (see
## `_add_tile_quad`'s `skirt`), and that cut is a horizontal line. Worse, it is the *same*
## horizontal line on every grass tile: the lift the tile is raised by and the height of its
## own face cancel out, so the cut always lands at `mid.y + TILE_H * 0.5` whatever picture the
## tile took. A shoreline of them is one unbroken horizontal edge repeated per tile, and at a
## low camera angle that is what reads as a cut picture rather than as turf.
##
## The strips are blades drawn past that cut and over the sand tile in front, one of
## `FRINGE_COUNT` silhouettes picked per tile by the same stable hash everything else here
## uses. They are generated, not from the pack — `_pipeline/tools/generate_fringe.py` — but
## their colours are sampled off the pack's own border tiles, so nothing in them can be a
## green the pack does not have.
##
## Why a hanging strip and not another pool of whole tiles: a tile's blades stop at the tile's
## own edge, which is the line being broken. Only something drawn past the edge, over the
## ground in front, actually crosses it.
const FRINGE := "res://assets/fringe/fringe_%d.png"
const FRINGE_COUNT := 8

## How much of a strip is above the cut and how much hangs below, in source pixels. Must match
## `OVERLAP` and `HANG` in the generator: the strip is placed by these, not measured.
##
## The rows above the cut are the join. A strip starting exactly at the edge shows a seam of
## its own wherever a blade's colour differs from the tile's last row; starting a couple of
## rows up puts that join inside the lawn where nothing is looking.
const FRINGE_OVERLAP := 5.0
const FRINGE_HANG := 12.0

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

## How far the island's sand carries on past the water's drawn edge, in tiles, under the
## water.
##
## The island is drawn under the water now, the same as the ground outside, and the shader
## cuts the water out inside the island's curve (`island_fraction` there, `Iso.past_shelf`
## here — one function, two languages). So the island's coast is that curve, not the tiles'
## staircase, and all the sand has to do is be there under every pixel of it. A diamond's
## corner reaches seven tenths of a tile from its middle, so a tile whose middle is a whole
## tile past the curve is entirely under opaque water and drawing it buys nothing.
##
## This replaces the drowned shelf — rows of sand stepping down and fading into the water
## (SINK_REACH, SINK_STEP, SINK_TINT and the rest). Those were the island's coast when the
## island stood on top of the water and had to end somewhere; under it, the water's own
## shoaling is the shallows and nothing else has to be drawn. `Iso.SHELF_TILES` outlives
## them: it still holds the rubbish off the beach, because a first cast has to reach.
const ISLAND_UNDER := 1.0

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
## Both are drawn below the water. Where the tiles stop is a staircase whatever tiles are
## picked; the water's edge is a curve, drawn by the shader, and laying that over the sand is
## what gives either shore a coastline. Outside, the water polygon simply ends at the bank.
## On the island, which the polygon spans, the shader discards its pixels inside the
## island's curve instead — same edge, cut from the other side.
enum Layer { OUTSIDE, ISLAND }

## What is on the ground at a tile. WATER is the shader's, and NONE is off the end of what
## this layer covers; both draw nothing, but they are not the same to a neighbour — sand
## takes a lip against water and stops caring past the ring.
enum Kind { NONE, WATER, SAND, GRASS }

var layer: Layer = Layer.OUTSIDE
var _dirty: bool = true

## Mesh data per slice: indices, points, uvs, colors
var _mesh_data: Dictionary = {}  # slice -> {indices, points, uvs, colors}

## The slices in submission order, lowest ground first. Filled on the first draw. See
## `_slice_order`.
var _order: Array = []

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

## The fringe strips, and one batch of geometry per strip. Kept apart from `_mesh_data`
## because they are not ground: they are drawn after every slice, over whatever the ground
## put down, and they take no part in `_slice_order`.
var _fringe_art: Array = []
var _fringe_data: Array = []

## The props' atlas, where each picture is in it, where each prop stands, and the one batch
## they and their shadows are drawn from. See `_pack_props` and `_lay_props`.
var _prop_atlas: ImageTexture
var _prop_uv: Dictionary = {}
var _placed: Array = []
var _prop_points := PackedVector2Array()
var _prop_uvs := PackedVector2Array()
var _prop_colors := PackedColorArray()
var _prop_indices := PackedInt32Array()

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
	# Both layers sit under the water. Tiles are diamonds, so a shore drawn by where the
	# tiles stop is a staircase however carefully they are picked; the water's edge is a
	# curve, and laying the water over the sand is what gives a shore a coastline. See
	# `Layer`, and ISLAND_UNDER for what that asks of the island's sand.
	#
	# The island stood above the water for a long while, because the water polygon spans it
	# and nothing drawn from below could show through. Its coast was then the tiles' own
	# staircase, and three attempts were made to soften that from on top: a shelf of drowned
	# sand rows stepping down and fading into the lake; the same shelf under a flat
	# water-coloured plate (a fixed colour cannot be the water it stands on — the shader
	# varies by depth, bands, foam and filth, and the plate followed none of it, so it read
	# as teal plates pasted on the lake); and the shelf fading by itself, jittered so the
	# rows could not be counted. Every one of them still ended on a stepped edge somewhere,
	# because the edge was still made of tiles. The shader discarding its water inside the
	# island's curve is what finally made the coast a curve, and it made the shelf pointless:
	# the water is opaque, and its own shoaling is the shallows.
	z_index = 1
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
	for i in FRINGE_COUNT:
		_fringe_art.append(load(FRINGE % i) as Texture2D)
		_fringe_data.append({
			"indices": PackedInt32Array(),
			"points": PackedVector2Array(),
			"uvs": PackedVector2Array(),
			"colors": PackedColorArray()
		})
	_sow()
	_pack_props()
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
			# Not on the sand that runs out under the water: a tuft half under the lake's edge
			# is a tuft cut in half.
			if Iso.past_shelf(at) > -0.6:
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


## How far the sun has to move before the ground is worth baking again, in units of `lean`.
## Small enough that a shadow never visibly jumps, large enough that a ten minute day is a
## handful of rebuilds rather than a rebuild a frame.
const SUN_STEP := 0.06


func _process(_delta: float) -> void:
	if day == null:
		return
	if absf(day.lean - _sun_baked) < SUN_STEP:
		return
	_sun_baked = day.lean
	queue_redraw()


func _draw() -> void:
	if _dirty:
		_rebuild()

	# One batch per slice, lowest ground first.
	#
	# Batching by slice is what makes forty thousand tiles a handful of draw calls, and it is
	# also the one thing that breaks painter's order: every tile of a slice goes down together,
	# so which slice is submitted first decides which ground covers which, and the back-to-front
	# order `_rebuild` so carefully builds only holds *within* a slice.
	#
	# The sand used to be submitted last, for no better reason than being last into the
	# dictionary, and a sand tile's whole quad — its side included — painted over the lawn in
	# front of it. A beach standing on top of the turf it runs into.
	#
	# Ordered by how high off the plane a slice is drawn instead: sand, then grass. Ground can
	# only ever be covered by ground above it, which is the part of painter's order that
	# matters here. Tiles at the same height still go down in whatever order their slices
	# happen to sit in, and that is sound as long as everything at one height is one flat
	# surface — see `_slice_lift`.
	for slice: int in _slice_order():
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

	# The fringe last, over every slice: it hangs off a grass tile and onto the sand tile in
	# front, so it has to be drawn after both of them whichever order their slices went down
	# in. Still before the props — a tuft of grass does not hang over a tree trunk.
	for i in _fringe_data.size():
		var fringe: Dictionary = _fringe_data[i]
		if fringe["indices"].is_empty():
			continue
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(),
			fringe["indices"],
			fringe["points"],
			fringe["colors"],
			fringe["uvs"],
			PackedInt32Array(),
			PackedFloat32Array(),
			_fringe_art[i].get_rid()
		)

	# The props last, all of them in one batch: every tree, rock and tuft and every shadow
	# they throw, in painter's order, off one atlas. They used to be a draw call each — two
	# with the shadow — and a wood of a few thousand was nearly six thousand draw calls a
	# frame, which was most of what a frame cost.
	_lay_props()
	if not _prop_indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(),
			_prop_indices,
			_prop_points,
			_prop_colors,
			_prop_uvs,
			PackedInt32Array(),
			PackedFloat32Array(),
			_prop_atlas.get_rid()
		)


func _rebuild() -> void:
	_dirty = false
	# Clear all mesh data
	for slice in _mesh_data.keys():
		_mesh_data[slice]["indices"].resize(0)
		_mesh_data[slice]["points"].resize(0)
		_mesh_data[slice]["uvs"].resize(0)
		_mesh_data[slice]["colors"].resize(0)
	for fringe: Dictionary in _fringe_data:
		fringe["indices"].resize(0)
		fringe["points"].resize(0)
		fringe["uvs"].resize(0)
		fringe["colors"].resize(0)

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

			# The grass keeps only as much of its own side as the step it stands on. See
			# `skirt`. The sand keeps all of its: the outer ring's last row is a real edge.
			var skirt := GRASS_LIFT if slice != SAND else INF
			_add_tile_quad(slice, mid, lift, Color.WHITE, skirt)
			# The fringe hangs off a lawn's cut edge onto whatever is in front. Not off the
			# tufted sand: that is beach with grass in it, and blades hanging off it would be
			# a lawn's edge drawn on the beach.
			if slice != SAND and not SAND_TUFTED.has(slice):
				_add_fringe(tx, ty, mid)


## One tile into the batch, at the size it was drawn.
##
## `lift` is how far above the tile's own diamond the picture's first opaque row starts: the
## empty part of the cell above the top face, plus whatever the caller wants added or taken
## off. It moves the quad, it does not resize it — the quad is always `SPRITE * SCALE` square,
## because that is the size the pack drew the tile at and any other size is a stretch.
##
## Getting that wrong is what put a 32x32 cube inside a 64x32 diamond box: the top face came
## out squashed, and because each slice has its own `_face_top`, tiles with different empty
## headroom were squashed by different amounts. That read as grass at different heights in the
## middle of the lawn, which is not a height at all, it is a scale.
##
## `skirt` is how much of the tile's side to keep below its top face, in screen pixels, or
## INF for all of it. Height and side are two different things and the lawn needs them apart:
## the pack draws every grass tile as a cube with thirteen source pixels of earth under the
## turf, so a lawn drawn whole stands a twenty-six pixel wall over the beach in front of it
## however little it is lifted. Moving the tile does not change that wall — the wall is the
## picture. Cutting the quad off `skirt` below the face is what makes the step the height it
## is asked to be, and the rest of the cube is simply not drawn.
func _add_tile_quad(
	slice: int, mid: Vector2, lift: float, tint: Color, skirt: float = INF
) -> void:
	var data: Dictionary = _mesh_data[slice]
	var tex: Texture2D = _art[slice]
	if tex == null:
		return

	# Quad corners in screen space. The top edge sits `lift` above the diamond's top corner;
	# the rest hangs down from there at native size, cut short by `skirt`.
	var half_w: float = Iso.TILE_W * 0.5
	var top: float = mid.y - Iso.TILE_H * 0.5 - lift
	var full: float = SPRITE * SCALE
	# Where the top face stops and the side of the cube starts, measured down from the top of
	# the quad: the empty rows above the face, then the face itself.
	var face_end: float = (_face_top[slice] + FACE) * SCALE
	# skirt is how far past the face the quad is allowed to reach; it does not pull the edge
	# back above the face, so a caller cannot ask for less than the face alone.
	var bottom: float = top + clampf(face_end + skirt, 0.0, full)
	var tl := Vector2(mid.x - half_w, top)
	var tr := Vector2(mid.x + half_w, top)
	var br := Vector2(mid.x + half_w, bottom)
	var bl := Vector2(mid.x - half_w, bottom)
	# The picture is cropped with the quad, not squeezed into it — except right at a skirt cut
	# short enough to land near the face/side boundary, where the row sampled is pulled back by
	# SEAM_GUARD so the sampler's own texel rounding can never reach across into the dirt on the
	# far side of it. The polygon's own edge stays where it was worked out above, so the tile
	# still meets the ground at the right place; only the last sliver of the picture is
	# stretched the extra distance to reach it, which one almost-flat row of pixels does not
	# show.
	#
	# Only where the quad is actually short of the sprite's own bottom. The sand's own skirt
	# runs to the true edge of the picture — a drowned row closing the gap to the tile in
	# front of it, or the outer ring's real edge — and pulling that back would open the same
	# kind of gap this is meant to close.
	var guard := SEAM_GUARD if bottom < top + full else 0.0
	var v: float = (bottom - top - guard) / full

	var base_idx: int = data["points"].size()
	data["points"].append(tl)
	data["points"].append(tr)
	data["points"].append(br)
	data["points"].append(bl)

	# UVs: the whole width, and as far down the picture as the quad reaches.
	data["uvs"].append(Vector2(0, 0))
	data["uvs"].append(Vector2(1, 0))
	data["uvs"].append(Vector2(1, v))
	data["uvs"].append(Vector2(0, v))

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


## The fringe on one grass tile: blades hanging past its cut edge and onto the sand in front.
##
## Only where there is sand in front. The cut edge runs the whole width of the tile, but only
## the half of it with a beach under it is a line anybody sees — the other half is covered by
## the next tile of lawn. `+tx` is the south-east step on the screen and `+ty` the south-west
## one (see `Iso.tile_to_world`), so those two neighbours are the two front edges, and a
## strip is emitted per edge rather than per tile. Hanging a full-width strip off a tile with
## grass on one side would drape blades over that lawn, which reads as a smear.
##
## Both halves come out of one picture: the left half of a strip is the south-west edge and
## the right half the south-east, so a tile with sand on both sides gets a single silhouette
## across the whole of its front rather than two unrelated ones meeting at the corner.
##
## `mid.y + TILE_H * 0.5` is where every grass tile's quad is cut, worked out in `FRINGE`'s
## block. If the fringe ever floats off the edge or sinks into it, that is the number that
## moved, not this one.
func _add_fringe(tx: int, ty: int, mid: Vector2) -> void:
	var se := _kind_at(float(tx) + 1.5, float(ty) + 0.5) == Kind.SAND
	var sw := _kind_at(float(tx) + 0.5, float(ty) + 1.5) == Kind.SAND
	if not se and not sw:
		return
	var pick := int(_hash(float(tx) * 7.7 + 13.0, float(ty) * 4.3 - 5.0) * float(FRINGE_COUNT))
	var data: Dictionary = _fringe_data[pick % FRINGE_COUNT]
	var top := mid.y + Iso.TILE_H * 0.5 - FRINGE_OVERLAP * SCALE
	var bottom := top + (FRINGE_OVERLAP + FRINGE_HANG) * SCALE
	if sw:
		_add_fringe_half(data, mid.x - Iso.TILE_W * 0.5, mid.x, 0.0, 0.5, top, bottom)
	if se:
		_add_fringe_half(data, mid.x, mid.x + Iso.TILE_W * 0.5, 0.5, 1.0, top, bottom)


## One half of a strip into its batch, at the size it was drawn: a quad the width of half a
## tile, taking the matching half of the picture. No stretching anywhere — the strips are
## authored one tile wide at the pack's own resolution.
func _add_fringe_half(
	data: Dictionary, left: float, right: float, u0: float, u1: float,
	top: float, bottom: float
) -> void:
	var base_idx: int = data["points"].size()
	data["points"].append(Vector2(left, top))
	data["points"].append(Vector2(right, top))
	data["points"].append(Vector2(right, bottom))
	data["points"].append(Vector2(left, bottom))
	data["uvs"].append(Vector2(u0, 0.0))
	data["uvs"].append(Vector2(u1, 0.0))
	data["uvs"].append(Vector2(u1, 1.0))
	data["uvs"].append(Vector2(u0, 1.0))
	for _i in 4:
		data["colors"].append(Color.WHITE)
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
func _plant(mid: Vector2, art: Texture2D) -> void:
	var size := Vector2(art.get_width(), art.get_height()) * SCALE
	var uv: Rect2 = _prop_uv[art]
	_lay_shadow(mid, size, uv)
	var box := Rect2(mid - Vector2(size.x * 0.5, size.y - Iso.TILE_H * 0.5), size)
	_prop_quad(
		Transform2D.IDENTITY,
		[box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)],
		uv, Color.WHITE
	)


## A tree's or a rock's shadow: the same picture again, laid out on the ground away from the
## sun in flat ink. See Shade.
##
## The ground is baked rather than drawn per frame — a wood of several hundred trees is laid
## out once and left alone — so these move in steps rather than continuously: `_process`
## below asks for a fresh bake when the sun has moved enough to be worth one. Over a ten
## minute day that is a handful of rebuilds, against sixty a second for a shadow nobody can
## see moving anyway.
##
## Hinged at the prop's own foot, `mid` plus half a tile down, which is where `_plant` stands
## the picture. It was hinged at the layer's origin once, and every shadow in the wood came
## out stacked on top of each other in one black streak at the corner of the tile field.
func _lay_shadow(mid: Vector2, size: Vector2, uv: Rect2) -> void:
	if day == null:
		return
	var foot := mid + Vector2(0.0, Iso.TILE_H * 0.5)
	var lie := Shade.lying(foot, day.lean, day.stretch)
	var box := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	_prop_quad(
		lie,
		[box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)],
		uv, Shade.tint(day.ink)
	)


## One picture into the prop batch: four corners (top-left, top-right, bottom-right,
## bottom-left) put through `xform`, the atlas rectangle, and the colour it is multiplied by.
func _prop_quad(xform: Transform2D, corners: Array, uv: Rect2, tint: Color) -> void:
	var base := _prop_points.size()
	for corner: Vector2 in corners:
		_prop_points.append(xform * corner)
		_prop_colors.append(tint)
	_prop_uvs.append(uv.position)
	_prop_uvs.append(Vector2(uv.end.x, uv.position.y))
	_prop_uvs.append(uv.end)
	_prop_uvs.append(Vector2(uv.position.x, uv.end.y))
	_prop_indices.append_array(
		PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3])
	)


## Lay every prop and its shadow into the batch, for the sun as it is now.
func _lay_props() -> void:
	_prop_points.resize(0)
	_prop_uvs.resize(0)
	_prop_colors.resize(0)
	_prop_indices.resize(0)
	if _props.is_empty():
		return
	if _placed.is_empty():
		_place_props()
	for i in range(0, _placed.size(), 2):
		_plant(_placed[i], _placed[i + 1])


## Where each prop stands, in painter's order, as flat pairs of foot point and picture. The
## walk over the whole ground and its `_kind_at` per tile is paid once, not on every bake.
func _place_props() -> void:
	var span := _span()
	for s in range((span.position.x + span.position.y), (span.end.x + span.end.y) + 1):
		for tx in range(span.position.x, span.end.x + 1):
			var ty := s - tx
			if ty < span.position.y or ty > span.end.y:
				continue
			var cell := Vector2i(tx, ty)
			if not _props.has(cell):
				continue
			var mid := Iso.tile_to_world(float(tx) + 0.5, float(ty) + 0.5)
			# On the same surface the tile under it was drawn at. A tree standing at the
			# plane on turf lifted by GRASS_LIFT is a tree buried to the ankles.
			if _kind_at(float(tx) + 0.5, float(ty) + 0.5) == Kind.GRASS:
				mid.y -= GRASS_LIFT
			for art: Texture2D in _props[cell]:
				_placed.append(mid)
				_placed.append(art)


## Every picture a prop uses, packed into one texture so the whole wood is one batch.
##
## Shelf packing with a transparent gutter round each picture: the layer draws nearest, and
## a gutter means no sample at a picture's edge can land on its neighbour.
const ATLAS_WIDE := 1024
const ATLAS_GUTTER := 2


func _pack_props() -> void:
	var arts: Array[Texture2D] = []
	for list: Array in _props.values():
		for art: Texture2D in list:
			if not arts.has(art):
				arts.append(art)
	arts.sort_custom(func(a: Texture2D, b: Texture2D) -> bool: return a.get_height() > b.get_height())
	var spots: Array[Vector2i] = []
	var x := ATLAS_GUTTER
	var y := ATLAS_GUTTER
	var shelf := 0
	for art in arts:
		if x + art.get_width() + ATLAS_GUTTER > ATLAS_WIDE:
			x = ATLAS_GUTTER
			y += shelf + ATLAS_GUTTER
			shelf = 0
		spots.append(Vector2i(x, y))
		x += art.get_width() + ATLAS_GUTTER
		shelf = maxi(shelf, art.get_height())
	var tall := y + shelf + ATLAS_GUTTER
	var sheet := Image.create_empty(ATLAS_WIDE, maxi(tall, 1), false, Image.FORMAT_RGBA8)
	for i in arts.size():
		var img := arts[i].get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), spots[i])
		_prop_uv[arts[i]] = Rect2(
			Vector2(spots[i]) / Vector2(sheet.get_size()),
			Vector2(img.get_size()) / Vector2(sheet.get_size())
		)
	_prop_atlas = ImageTexture.create_from_image(sheet)


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
	if layer == Layer.ISLAND:
		var r := Iso.ISLAND_RADIUS + Vector2.ONE * (ISLAND_UNDER + 2.0)
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
	if layer == Layer.ISLAND:
		# Out to a whole tile past the water's drawn edge, so there is sand under every pixel
		# the shader leaves open, and no further. See ISLAND_UNDER.
		if Iso.past_shelf(at) > ISLAND_UNDER:
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
## One picture for sand, a pool of pictures for the open grass, and on the mainland a mixed
## band between them (see BLEND). The island's yard keeps its plain edge and the tufted
## mounds: a kept yard has a decided edge rather than a worn one.
func _slice_at(tx: float, ty: float, rng: RandomNumberGenerator) -> int:
	var kind := _kind_at(tx, ty)
	if kind == Kind.NONE or kind == Kind.WATER:
		return 0

	if layer == Layer.OUTSIDE:
		return _blend_at(tx, ty, kind, rng)
	if kind == Kind.SAND:
		return SAND
	if _borders_sand(tx, ty):
		return _pick(GRASS_BORDER, tx, ty, rng)
	return _pick(GRASS_YARD, tx, ty, rng)


## The mainland's picture at a spot, mixed across the lawn's edge. See BLEND.
##
## `across` is how far past the grass/sand line the spot is, in tiles, grass side positive.
## Each tile rolls once, by position, against thresholds that slide with `across`, so the
## mix thins smoothly from one picture to the next and the same tile always rolls the same.
func _blend_at(tx: float, ty: float, kind: Kind, rng: RandomNumberGenerator) -> int:
	var at := Vector2(tx, ty)
	var across := out_of_water(tx, ty) - (SAND_OUT + _wander(at))
	var roll := _hash(tx * 3.7 + 19.0, ty * 6.3 + 5.0)
	if kind == Kind.SAND:
		# Sand side: tufts thinning out toward the water. A tile past the band's reach is
		# beach outright, whatever it rolled.
		var t := clampf(1.0 + across / BLEND, 0.0, 1.0)
		if roll < t * BLEND_TUFTS:
			return _pick(SAND_TUFTED, tx, ty, rng)
		return SAND
	# Grass side: rough lawn well in, then mounds, then tufted sand right at the line. Two
	# thresholds sliding with `across`, one for each step down.
	var t := clampf(1.0 - across / BLEND, 0.0, 1.0)
	if roll < t * t * 0.45:
		return _pick(SAND_TUFTED, tx, ty, rng)
	if roll < t * 0.9:
		return _pick(GRASS_BORDER, tx, ty, rng)
	return _pick(GRASS_ROUGH, tx, ty, rng)


## Whether a grass tile has sand on any of the four sides it can be seen from. See
## `GRASS_BORDER`.
func _borders_sand(tx: float, ty: float) -> bool:
	return (
		_kind_at(tx - 1.0, ty) == Kind.SAND
		or _kind_at(tx, ty - 1.0) == Kind.SAND
		or _kind_at(tx + 1.0, ty) == Kind.SAND
		or _kind_at(tx, ty + 1.0) == Kind.SAND
	)


## Every slice this node can draw, so they are all in hand before the first frame.
func _every_slice() -> Array:
	var out: Array = GRASS_YARD.duplicate()
	out.append_array(GRASS_ROUGH)
	out.append_array(GRASS_BORDER)
	out.append_array(SAND_TUFTED)
	out.append(SAND)
	return out


## How far off the plane a slice's ground is drawn, in screen pixels. The grass stands on a
## step; the sand is the plane. Keep this agreeing with what `_rebuild` adds to `lift`.
func _slice_lift(slice: int) -> float:
	return 0.0 if slice == SAND else GRASS_LIFT


## The slices in the order they are submitted: lowest ground first, so anything drawn later
## can only be ground standing above what is already down. See `_draw`.
##
## Worked out once and kept, because it cannot change while the node lives and `_draw` runs
## on every redraw.
func _slice_order() -> Array:
	if _order.is_empty():
		_order = _mesh_data.keys()
		_order.sort_custom(func(a: int, b: int) -> bool:
			return _slice_lift(a) < _slice_lift(b)
		)
	return _order


## One of a set, chosen by where the tile is rather than by how far into the draw we are, so
## adding ground somewhere does not reshuffle the ground everywhere else.
##
## Along the edge between two patches the tile rolls for which patch it belongs to: a patch's
## edge is otherwise a run of whole diamonds changing texture on one line, and a lawn's
## patches do not have edges like that. One roll against the first neighbour that differs, so
## a tile at a meeting of three patches is still one tile.
func _pick(of: Array, tx: float, ty: float, _rng: RandomNumberGenerator) -> int:
	var patch := _patch_of(tx, ty)
	for step: Vector2 in [Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0), Vector2(0, 1)]:
		var beside := _patch_of(tx + step.x, ty + step.y)
		if beside != patch:
			if _hash(tx * 2.3 + 41.0, ty * 5.1 - 7.0) < 0.5:
				patch = beside
			break
	return of[int(_hash(patch.x, patch.y) * float(of.size())) % of.size()]


## Which patch of one texture a spot belongs to, as the lattice cell of the scattered point
## it is nearest. See `grass_patch`.
##
## Nearest on screen, not in tile space. A tile step across is twice a tile step down, so a
## circle drawn with tile distance comes out as a diamond twice as tall as it should be, and
## patches measured that way are the diamonds this was meant to get rid of. Measuring the
## real distance between the two tiles' middles is what makes a patch a patch of ground
## rather than a patch of grid.
##
## Only the nine cells around this one are looked at. A point can only wander by
## `grass_patch_wander` of a cell, well under half, so nothing outside those nine can be
## nearer than the nearest of them.
func _patch_of(tx: float, ty: float) -> Vector2:
	var size := maxf(grass_patch, 1.0)
	var home := Vector2(floor(tx / size), floor(ty / size))
	var here := Iso.tile_to_world(tx, ty)
	var best := home
	var best_d := INF
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var cell := home + Vector2(float(dx), float(dy))
			# Rolled off two different corners of the cell so the two axes wander apart
			# rather than together, which would only slide the lattice about.
			var jitter := Vector2(
				_hash(cell.x, cell.y) - 0.5, _hash(cell.y + 31.0, cell.x - 17.0) - 0.5
			)
			var point := (cell + Vector2(0.5, 0.5) + jitter * 2.0 * grass_patch_wander) * size
			var d := here.distance_squared_to(Iso.tile_to_world(point.x, point.y))
			if d < best_d:
				best_d = d
				best = cell
	return best


## A stable number in 0..1 for a spot on the plane.
func _hash(x: float, y: float) -> float:
	var h := sin(x * 127.1 + y * 311.7 + float(SEED) * 0.0001) * 43758.5453
	return h - floor(h)
