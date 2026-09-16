## The ground the lake sits in, drawn as pixel-art tiles instead of flat fills.
##
## Everything that is not water is a picture from the Forest Isometric pack: the island, the
## beach around the waterline, and a wide ring of lawn past it that covers the ground out to
## well beyond what the camera can pull back to see.
##
## The ground is not laid tile by tile any more. Each layer is one polygon with
## `shaders/ground.gdshader` on it, and every pixel of that polygon works out for itself
## which tile of the plane it lies on, whether that spot is lawn or beach, which patch of
## the lawn it is in, and so which texel of the pack's own top faces to show. The pictures
## are still the pack's, at their own size, on the same grid the rubbish uses; what is per
## pixel is the *line* between lawn and beach and the lines between patches, which are
## curves stepped only at art pixels rather than staircases of whole diamonds. The water
## shader cuts the island's coast the same way, and that is the look this borrows.
##
## The trees, rocks and tufts still stand on tiles, and this node still lays them out and
## draws them as one batch. Where they may stand is decided by the same rule the shader
## draws by — `coverage_at` here, `coverage` there — one edge in two languages.
##
## What decides where the water is, is `Iso`, not this file: the same `shore_fraction` and
## `island_fraction` the water shader and the walking rules read. The ground is a picture of
## the basin's shape rather than a second opinion about it.
class_name Ground
extends Node2D

## The daylight, handed over by the level, and where the sun was when this was last baked.
## Null anywhere there is no day — the ground then draws no shadows at all rather than
## guessing at a sun the rest of the scene would disagree with.
var day: DayCycle
var _sun_baked: float = INF

## Where the pack's individual tiles live.
const TILES := "res://assets/Forest Isometric Pack Free/Tileset/Slice %d.png"
const SHADER := "res://shaders/ground.gdshader"

## One source pixel to this many screen pixels. At 2.0 a pack tile's top face is exactly one
## game tile, which is what makes the ground grid and the lake's tile grid the same grid.
const SCALE := 2.0

## A pack tile is this square, and its top face is this tall inside it. The rest is the side
## of the cube, which is not drawn any more: the ground is flat, and the only place a side
## could show is the outer ring's last row, which is further out than the view can get.
const SPRITE := 32.0
const FACE := 16.0

## Where, in a pack picture, the top face's diamond has its top corner — measured off the
## shading of the cube's sides, not off the first opaque row. The grass tiles are drawn
## bushy: the turf leans back over the two rear edges of the diamond by up to eight source
## pixels and its blade tips reach three rows above the corner, so the first opaque row is
## the overhang, not the face. The sand slab has no overhang and its corner is lower in the
## cell. Both are copied into the strip so that the corner lands on `SHEET_FACE_ROW`, and
## the shader reads every picture the same way.
const GRASS_FACE_ROW := 3
const SAND_FACE_ROW := 13
const SHEET_FACE_ROW := 3
## Rows kept per picture: the overhang above the corner, and the sixteen rows of the face.
const SHEET_ROWS := 19

## Which slices go where.
##
## Grass in the open. Two pools: the island is a kept yard and the mainland is not, so the
## plain lighter tiles belong to one and the darker, tuftier ones to the other. Nothing is in
## both, which is what keeps the island reading as tended from across the water.
const GRASS_YARD := [1, 2, 19]
const GRASS_ROUGH := [18, 20, 21]

## Sand. One tile, everywhere, whatever is next to it.
##
## The pack has a set of rimmed pieces for the edges of sand and a set of half-sand pieces
## for the grass that meets it, and both are unused: the rim drew a dark line wherever the
## sand stopped, and the half-sand tiles read as dirt patches in the lawn. Ground that runs
## out under the water at one end and under the turf at the other does not want either.
##
## The pack's grass/sand join tiles (a corner set — see `tools/tile_edges.log`), the tufted
## mounds, the sand-with-tufts cubes and a mixed band of all of them were each tried as the
## lawn's edge and each was still a staircase of diamonds, because a line drawn by choosing
## whole tiles cannot be anything else. The shader's per-pixel curve is what replaced them.
const SAND := 67

## The strip the shader reads: the sand first, then the island's pool, then the mainland's.
## `GRASS_FIRST` for each layer is its pool's first cell in this order.
const SHEET := [SAND, 1, 2, 19, 18, 20, 21]
const YARD_FIRST := 1
const ROUGH_FIRST := 4

## How far out of the water the lawn starts, in tiles. Wider than the flat-colour band it
## replaced (2.8): the dog walks the beach to `Dog.BEACH_WALK` (3.0) and the litter lies
## up it to `Iso.BEACH_LITTER` (2.4), so the beach at its narrowest — this less
## `wander_amp` — has to stay past 3.5 or the dog fetches off the lawn.
const SAND_OUT := 5.3

## How far the line between beach and lawn wanders off the ellipse underneath it, in tiles,
## how wide its bays are in world pixels, and how much of the wander is the finer second
## octave of bites out of the bays.
##
## Everything here is drawn from two ellipses, and an ellipse still reads as a machined
## curve — a ring of sand of even width, which is a shape nothing on a lake has. Value noise
## on the screen (not on the tile grid, so a bay is round on the screen), rolled off SEED
## so the same bays are in the same places every run. Only the mainland: the island's lawn
## is a kept yard, which has a decided edge rather than a wandering one.
const WANDER_AMP := 0.7
const WANDER_SCALE := 260.0
const WANDER_FINE := 0.3

## How wide a patch of one grass picture is, in tiles, and how far a patch's middle is
## allowed to wander off the lattice, as a fraction of that width.
##
## Grass used to be picked per tile, which on ground made of one repeated diamond is a
## shimmer: every square a different texture, and no square part of anything. Then it was
## picked per `floor(tx / 3)` square, which is worse in its own way: those squares are
## squares in tile space, so on screen they are diamonds, all the same size, all lined up.
## A patch is now the ground nearest one of a set of scattered points, measured on the
## screen, and — since the shader — decided per pixel rather than per tile, so a patch's
## border is a curve through the tiles rather than a run of diamond edges.
const PATCH_SIZE := 4.5
const PATCH_WANDER := 0.3

## The blades hanging off the lawn's cut edge over the beach, drawn per pixel by the shader.
## Mode 1 hangs them straight down the screen where the beach is below the lawn; mode 2
## points them along the edge's normal wherever it faces. Depth in art pixels, share of
## columns carrying one. The island has none: a kept yard, a clean lip only.
##
## Short and a little sparse, and no lip under the mainland's edge: the turf's own
## overhang and the blades are all the edge wants, and the dark line under it read as a
## kerb. Settled by eye through the F4 tuner (2026-09-11), the numbers here are its picks.
const FRINGE_MODE := 1
const FRINGE_DEPTH := 2.0
const FRINGE_SHARE := 0.6
const LIP := false

## The tufts on the beach just past the line: the pack's Leaves, sparse, within this many
## tiles of the lawn, each at its own sub-tile offset so none of them line up with the grid.
const TUFT_SHARE := 0.36
const TUFT_REACH := 0.9

## How far in from the island's waterline the grass starts, in tiles. Everything outside it
## is beach.
##
## Wide enough that the beach has a middle to it: a shore one tile across is all edge. Not
## much wider, though — an island that is all beach has no middle either.
const BEACH_IN := 2.6

## How far past the waterline the ring of ground reaches, in tiles.
##
## Well past anything the view can pull back to: the ground ends there, and that is only
## hidden if the end is somewhere nobody can look.
##
## Sized for the worst case, not the average one: `Lake._clamped_view` only keeps the
## viewport's bounding box inside the ring's bounding box, and the ring is an ellipse, so its
## own corners fall well short of that box's corners. A screen's actual corner, at the far
## end of the zoom, can be up to root two times as far from the middle as the box's edge —
## same reason `Iso.tile_circle_extent` isn't `radius * TILE_W * 0.5`. Grown by that factor
## over the old, box-sized reach so the ring's true edge (not its box) clears every corner,
## plus 200 more world pixels of slack past that so the treeline is never exactly on the edge.
const OUTER_OUT := 42.1

## How far the island's sand carries on past the water's drawn edge, in tiles, under the
## water.
##
## The island is drawn under the water, the same as the ground outside, and the shader cuts
## the water out inside the island's curve (`island_fraction` there, `Iso.past_shelf` here —
## one function, two languages). So the island's coast is that curve, and all the sand has
## to do is be there under every pixel of it. A diamond's corner reaches seven tenths of a
## tile from its middle, so a tile a whole tile past the curve is entirely under opaque water
## and drawing it buys nothing.
##
## This replaces the drowned shelf — rows of sand stepping down and fading into the water.
## Those were the island's coast when the island stood on top of the water and had to end
## somewhere; under it, the water's own shoaling is the shallows and nothing else has to be
## drawn. `Iso.SHELF_TILES` outlives them: it still holds the rubbish off the beach.
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

## The same lap `Lake.SHORE_LAP` grows the water polygon by, in tiles. Where the water is
## actually drawn to, which is what the ground has to hide under — not the waterline Iso
## holds, which is a little way inside it.
const LAP := Iso.WATER_LAP_TILES

## Which part of the ground this node draws.
##
## Both are drawn below the water. The water's edge is a curve, drawn by the shader, and
## laying that over the sand is what gives either shore a coastline. Outside, the water
## polygon simply ends at the bank. On the island, which the polygon spans, the shader
## discards its pixels inside the island's curve instead — same edge, cut from the other
## side.
enum Layer { OUTSIDE, ISLAND }

## What is on the ground at a spot. WATER is the shader's, and NONE is off the end of what
## this layer covers; both draw nothing.
enum Kind { NONE, WATER, SAND, GRASS }

var layer: Layer = Layer.OUTSIDE

## The tunables, as the ground is drawn now. Constants above are the defaults; these are
## what the debug tuner (`GroundTuner`, F4) moves, and what `retune` pushes to the shader.
var beach_width: float = SAND_OUT
var wander_amp: float = WANDER_AMP
var wander_scale: float = WANDER_SCALE
var wander_fine: float = WANDER_FINE
var patch_size: float = PATCH_SIZE
var patch_wander: float = PATCH_WANDER
var fringe_mode: int = FRINGE_MODE
var fringe_depth: float = FRINGE_DEPTH
var fringe_share: float = FRINGE_SHARE
var lip: bool = LIP
var tuft_share: float = TUFT_SHARE
var tuft_reach: float = TUFT_REACH

## The polygon the shader draws the ground on, and its material.
var _sheet: Polygon2D
var _material: ShaderMaterial

## What stands on each tile, as tile coordinates to a list of [picture, foot]: the foot is
## the world point the picture stands at, which is the tile's middle for a tree or a rock and
## a rolled spot inside the tile for a beach tuft. Worked out once, on the way in, because it
## depends on what its neighbours got — a rock has to know whether the tile beside it took a
## tree.
var _props: Dictionary = {}

## Which tiles have something standing on them — a tree or a rock. Leaves are not in here:
## they lie under things rather than taking up room.
var _standing: Dictionary = {}

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
## rather than by an average of the two. Mirrored in the shader.
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
	# Both layers sit under the water. The water's edge is a curve, and laying the water over
	# the sand is what gives a shore a coastline. See `Layer`, and ISLAND_UNDER for what that
	# asks of the island's sand.
	#
	# The island stood above the water for a long while, because the water polygon spans it
	# and nothing drawn from below could show through. Its coast was then the tiles' own
	# staircase, and three attempts were made to soften that from on top. Every one of them
	# still ended on a stepped edge somewhere, because the edge was still made of tiles. The
	# shader discarding its water inside the island's curve is what finally made the coast a
	# curve — and the lawn's edge is now drawn the same way, for the same reason.
	z_index = 1
	z_as_relative = false
	_build_sheet()
	_sow()
	_pack_props()
	queue_redraw()


## The ground itself: one polygon over everything this layer covers, and the shader on it.
##
## Behind this node's own drawing, which is the props: a child is normally drawn after its
## parent, and a tree has to stand on the ground, not under it.
func _build_sheet() -> void:
	_sheet = Polygon2D.new()
	_sheet.name = &"Sheet"
	_sheet.show_behind_parent = true
	_sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var span := _span()
	var corners := [
		Iso.tile_to_world(span.position.x, span.position.y),
		Iso.tile_to_world(span.end.x + 1.0, span.position.y),
		Iso.tile_to_world(span.end.x + 1.0, span.end.y + 1.0),
		Iso.tile_to_world(span.position.x, span.end.y + 1.0),
	]
	var box := Rect2(corners[0], Vector2.ZERO)
	for c: Vector2 in corners:
		box = box.expand(c)
	_sheet.polygon = PackedVector2Array([
		box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)
	])
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER)
	_material.set_shader_parameter(&"sheet", _strip())
	_material.set_shader_parameter(&"cell_wide", int(SPRITE))
	_material.set_shader_parameter(&"face_top", SHEET_FACE_ROW)
	_material.set_shader_parameter(&"grass_first", YARD_FIRST if layer == Layer.ISLAND else ROUGH_FIRST)
	_material.set_shader_parameter(&"grass_count", GRASS_YARD.size())
	_material.set_shader_parameter(&"layer", 1 if layer == Layer.ISLAND else 0)
	_material.set_shader_parameter(&"tile_w", Iso.TILE_W)
	_material.set_shader_parameter(&"tile_h", Iso.TILE_H)
	_material.set_shader_parameter(&"art_pixel", SCALE)
	_material.set_shader_parameter(&"basin_centre", Iso.CENTRE)
	_material.set_shader_parameter(&"basin_radius", Iso.RADIUS)
	_material.set_shader_parameter(&"island_centre", Iso.ISLAND_CENTRE)
	_material.set_shader_parameter(&"island_radius", Iso.ISLAND_RADIUS)
	_material.set_shader_parameter(&"water_lap", LAP)
	_material.set_shader_parameter(&"outer_out", OUTER_OUT)
	_material.set_shader_parameter(&"island_under", ISLAND_UNDER)
	_material.set_shader_parameter(&"beach_in", BEACH_IN)
	_material.set_shader_parameter(&"seed", float(SEED))
	var palette := Palette.master()
	if palette != null:
		_material.set_shader_parameter(&"fringe_dark", palette.grass_dark)
		_material.set_shader_parameter(&"lip_color", palette.grass_dark.darkened(0.25))
	_push_tunables()
	_sheet.material = _material
	add_child(_sheet)


## The tunables to the shader. The island keeps its own edge whatever the sliders say: a kept
## yard has a decided edge and no fringe, so the mainland's wander and blades are not its.
func _push_tunables() -> void:
	var island := layer == Layer.ISLAND
	_material.set_shader_parameter(&"beach_width", beach_width)
	_material.set_shader_parameter(&"wander_amp", 0.0 if island else wander_amp)
	_material.set_shader_parameter(&"wander_scale", wander_scale)
	_material.set_shader_parameter(&"wander_fine", wander_fine)
	_material.set_shader_parameter(&"patch_size", patch_size)
	_material.set_shader_parameter(&"patch_wander", patch_wander)
	_material.set_shader_parameter(&"fringe_mode", 0 if island else fringe_mode)
	_material.set_shader_parameter(&"fringe_depth", fringe_depth)
	_material.set_shader_parameter(&"fringe_share", fringe_share)
	_material.set_shader_parameter(&"lip", true if island else lip)


## The sliders moved. Push the picture's numbers to the shader at once, and lay the props
## out again if the line they stand by has moved.
func retune(resow: bool) -> void:
	_push_tunables()
	if resow:
		_props.clear()
		_standing.clear()
		_placed.clear()
		_prop_uv.clear()
		_sow()
		_pack_props()
		queue_redraw()


## The strip of top faces the shader reads: every picture in SHEET, side by side, each with
## its diamond's top corner on SHEET_FACE_ROW. See GRASS_FACE_ROW.
func _strip() -> ImageTexture:
	var wide := int(SPRITE)
	var strip := Image.create_empty(wide * SHEET.size(), SHEET_ROWS, false, Image.FORMAT_RGBA8)
	for i in SHEET.size():
		var slice: int = SHEET[i]
		var img := (load(TILES % slice) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var face_row := SAND_FACE_ROW if slice == SAND else GRASS_FACE_ROW
		var from := face_row - SHEET_FACE_ROW
		strip.blit_rect(img, Rect2i(0, from, wide, SHEET_ROWS), Vector2i(i * wide, 0))
	return ImageTexture.create_from_image(strip)


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
	# What each tile's middle is, asked once for the four passes below rather than once a
	# pass: the ring is tens of thousands of tiles, and the shore-shape maths is most of
	# what a pass costs.
	var kinds: Dictionary = {}
	for tx in range(span.position.x, span.end.x + 1):
		for ty in range(span.position.y, span.end.y + 1):
			kinds[Vector2i(tx, ty)] = kind_at(float(tx) + 0.5, float(ty) + 0.5)
	for tx in range(span.position.x, span.end.x + 1):
		for ty in range(span.position.y, span.end.y + 1):
			var at := Vector2(float(tx) + 0.5, float(ty) + 0.5)
			if kinds[Vector2i(tx, ty)] != Kind.GRASS:
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
			if kinds[Vector2i(tx, ty)] != Kind.GRASS:
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
			if kinds[Vector2i(tx, ty)] != Kind.GRASS:
				continue
			if _hash(at.x * 1.3, at.y * 8.9) > LEAF_SHARE:
				continue
			_litter(Vector2i(tx, ty), at)

	# The tufts on the beach, just past the lawn's line. Each is rolled a spot inside its
	# tile rather than standing on the middle, so the scatter does not line up with the
	# grid the way whole tiles of tufted sand did. Only where that spot is beach within
	# TUFT_REACH of the line: the line wanders, so the tile's middle is not enough to ask.
	for tx in range(span.position.x, span.end.x + 1):
		for ty in range(span.position.y, span.end.y + 1):
			# Only tiles whose middle is beach, and then only the rolled spot's own answer:
			# the line can pass through a tile, so the middle is not enough to go on.
			if kinds[Vector2i(tx, ty)] != Kind.SAND:
				continue
			var at := Vector2(
				float(tx) + 0.1 + 0.8 * _hash(float(tx) * 4.9 + 3.0, float(ty) * 2.9 - 1.0),
				float(ty) + 0.1 + 0.8 * _hash(float(ty) * 6.7 + 5.0, float(tx) * 1.7 + 9.0)
			)
			if kind_at(at.x, at.y) != Kind.SAND:
				continue
			if coverage_at(at) < -tuft_reach:
				continue
			if _hash(at.x * 2.9 + 17.0, at.y * 7.1 - 3.0) > tuft_share:
				continue
			_litter(Vector2i(tx, ty), at)


## The island's tufts, on its grass and its sand alike.
func _sow_island() -> void:
	var span := _span()
	for tx in range(span.position.x, span.end.x + 1):
		for ty in range(span.position.y, span.end.y + 1):
			var at := Vector2(float(tx) + 0.5, float(ty) + 0.5)
			var kind := kind_at(at.x, at.y)
			if kind != Kind.GRASS and kind != Kind.SAND:
				continue
			# Clear of the picture, not just of the walls' feet: a walker may stand under the
			# eaves, but a tuft planted there is drawn under the hut and wasted.
			if Iso.in_shed(at.x, at.y, Iso.SHED_COVER):
				continue
			# Not on the sand that runs out under the water: a tuft half under the lake's edge
			# is a tuft cut in half.
			if Iso.past_shelf(at) > -0.6:
				continue
			if _hash(at.x * 9.1, at.y * 3.7) > ISLAND_LEAF_SHARE:
				continue
			_litter(Vector2i(tx, ty), at)


## One tuft, added under whatever else is on the tile, standing at `at` (tile coordinates).
func _litter(cell: Vector2i, at: Vector2) -> void:
	var leaf := load(
		LEAVES % (1 + int(_hash(at.y * 4.7, at.x * 2.3) * float(LEAF_COUNT)) % LEAF_COUNT)
	) as Texture2D
	var entry := [leaf, Iso.tile_to_world(at.x, at.y)]
	if _props.has(cell):
		_props[cell].insert(0, entry)
	else:
		_props[cell] = [entry]


## One thing standing on a tile's middle, claiming it against anything else that stands.
func _stand(cell: Vector2i, art: Texture2D) -> void:
	var entry := [art, Iso.tile_to_world(float(cell.x) + 0.5, float(cell.y) + 0.5)]
	if _props.has(cell):
		_props[cell].append(entry)
	else:
		_props[cell] = [entry]
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


## The props, all of them in one batch: every tree, rock and tuft and every shadow they
## throw, in painter's order, off one atlas. They used to be a draw call each — two with the
## shadow — and a wood of a few thousand was nearly six thousand draw calls a frame, which
## was most of what a frame cost. The ground itself is the `Sheet` child, drawn behind this.
func _draw() -> void:
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


## The trees, rocks and tufts on one tile, standing on `mid`.
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
## above asks for a fresh bake when the sun has moved enough to be worth one. Over a ten
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
## walk over the whole ground is paid once, not on every bake.
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
			for entry: Array in _props[cell]:
				_placed.append(entry[1])
				_placed.append(entry[0])


## Every picture a prop uses, packed into one texture so the whole wood is one batch.
##
## Shelf packing with a transparent gutter round each picture: the layer draws nearest, and
## a gutter means no sample at a picture's edge can land on its neighbour.
const ATLAS_WIDE := 1024
const ATLAS_GUTTER := 2


func _pack_props() -> void:
	var arts: Array[Texture2D] = []
	for list: Array in _props.values():
		for entry: Array in list:
			var art: Texture2D = entry[0]
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
## The same answer the shader gives at that spot, in tile coordinates. The props ask it; so
## may anything else that wants to know whether a spot is lawn or beach as it is drawn.
func kind_at(tx: float, ty: float) -> Kind:
	var at := Vector2(tx, ty)
	if layer == Layer.ISLAND:
		# Out to a whole tile past the water's drawn edge, so there is sand under every pixel
		# the shader leaves open, and no further. See ISLAND_UNDER.
		if Iso.past_shelf(at) > ISLAND_UNDER:
			return Kind.NONE
		return Kind.GRASS if coverage_at(at) > 0.0 else Kind.SAND

	if Iso.island_fraction(at.x, at.y) < 1.0:
		return Kind.NONE
	var out := out_of_water(at.x, at.y)
	# A spot inside the waterline, not at it. The sand starts far enough under the water
	# that the water's curve is always the edge that is seen.
	if out < -1.0 - LAP:
		return Kind.WATER
	if out > OUTER_OUT:
		return Kind.NONE
	return Kind.GRASS if coverage_at(at) > 0.0 else Kind.SAND


## Tiles past the lawn's line at a spot: positive on the lawn, negative on the beach.
## Mirrors the shader's `coverage`, which draws by it; the two must move together.
##
## The island's yard has a decided edge, so it does not wander. The mainland's line is the
## ellipse `SAND_OUT` tiles out of the water, pushed about by `wander_at`.
func coverage_at(at: Vector2) -> float:
	if layer == Layer.ISLAND:
		return Iso.lawn_depth(at)
	var plain := out_of_water(at.x, at.y) - beach_width
	# The wander can only move the line by its amplitude, so anything further from the
	# ellipse than that is decided without rolling the noise. The props ask this for every
	# tile of the ring several times over, and the noise is most of what a call costs.
	if absf(plain) > wander_amp:
		return plain
	return plain - wander_at(Iso.tile_to_world(at.x, at.y))


## How far the lawn's line strays off its ellipse at a world point, in tiles. Mirrors the
## shader's `wander`: two octaves of the same value noise on the screen, the coarse one the
## bays and the fine one the bites out of them.
func wander_at(p: Vector2) -> float:
	var off := Vector2(float(SEED) * 0.001, float(SEED) * 0.0007)
	var coarse := _blob_noise(p / maxf(wander_scale, 1.0) + off) - 0.5
	var fine := _blob_noise(p / maxf(wander_scale * 0.31, 1.0) + off * 1.7 + Vector2(13.0, 7.0)) - 0.5
	return wander_amp * 2.0 * lerpf(coarse, fine, wander_fine)


## `cell_hash` from shaders/pixel.gdshaderinc, in GDScript.
static func _cell_hash(cell: Vector2) -> float:
	var p := Vector2(_fract(cell.x * 123.34), _fract(cell.y * 345.45))
	var d := p.dot(p + Vector2(34.345, 34.345))
	p += Vector2(d, d)
	return _fract(p.x * p.y)


## `blob_noise` from shaders/pixel.gdshaderinc, in GDScript.
static func _blob_noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _cell_hash(i)
	var b := _cell_hash(i + Vector2(1.0, 0.0))
	var c := _cell_hash(i + Vector2(0.0, 1.0))
	var d := _cell_hash(i + Vector2(1.0, 1.0))
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


static func _fract(x: float) -> float:
	return x - floor(x)


## How far out of the basin's own box a spot is, on the screen's axes rather than the lake's:
## 1 on the box, more outside it. See WOOD_CORNER_FROM.
func _boxed(at: Vector2) -> float:
	var half := Iso.basin_extent() * 0.5
	var here := Iso.tile_to_world(at.x, at.y) - Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)
	if half.x <= 0.0 or half.y <= 0.0:
		return 0.0
	return maxf(absf(here.x) / half.x, absf(here.y) / half.y)


## A stable number in 0..1 for a spot on the plane.
func _hash(x: float, y: float) -> float:
	var h := sin(x * 127.1 + y * 311.7 + float(SEED) * 0.0001) * 43758.5453
	return h - floor(h)
