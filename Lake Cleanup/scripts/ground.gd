## The ground the lake sits in, drawn as pixel-art tiles instead of flat fills.
##
## Everything that is not water is a picture from the Forest Isometric pack: the island, the
## beach around the waterline, and a wide ring of lawn past it that covers the ground out to
## well beyond what the camera can pull back to see.
##
## The ground is not laid tile by tile any more. Each layer is one polygon with
## `shaders/ground.gdshader` on it, and every pixel of that polygon works out for itself
## which tile of the plane it lies on, whether that spot is lawn or beach, and so which
## texel of the pack's own top faces to show. The pictures
## are still the pack's, at their own size, on the same grid the rubbish uses; what is per
## pixel is the *line* between lawn and beach, which is a
## curve stepped only at art pixels rather than staircases of whole diamonds. The water
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
var _stretch_baked: float = INF
## The shadows' ink last pushed to the batch's material (see `_process`).
var _ink_pushed := Color(-1.0, -1.0, -1.0, -1.0)

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
## Grass. The lawn is drawn by the shader in these slices' own greens (`lawn_greens`), not
## sampled from them (2026-09-28, Richard: the tiles showed their seams and repeated). The
## island takes slice 18's greens flat; the bank slice 21's, its darker neighbour, under
## tone blotches.
const GRASS_ISLAND := 18
const GRASS_BANK := 21
const TONE_ISLAND := 0
const TONE_BANK := 3

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

## The strip the shader reads: the sand slab alone.
const SHEET := [SAND]

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

## The blades hanging off the lawn's cut edge over the beach, drawn per pixel by the shader.
## Mode 1 hangs them straight down the screen where the beach is below the lawn; mode 2
## points them along the edge's normal wherever it faces. Depth in art pixels, share of
## columns carrying one. The island wears them too since 2026-09-28 (Richard: its south edge showed a hard line).
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

## The ground's volume (2026-10-01, picked off tools/last_ground_volume_mockup3.png, 1b): the
## lawn in clumps that sway, the beach in bands along the shore. Shader-side, all of it; these
## are the numbers the F4 tuner moves, and the shader's own defaults are the same picks.
## `CLUMP_CUT`/`CLUMP_SHARE` how much of the lawn is clumps and how thick; `GUST_CUT` how much
## of it a gust tips at once; `TIDE_AT` how far up the beach the wrack lies, in tiles;
## `RIPPLE_FIELD` how few patches of ripples (higher is fewer) and `RIPPLE_GAP` their spacing in
## art pixels; `WET_STEP` the seconds between the wave's remembered reaches, so six of them is
## how long sand the wave left takes to dry.
const CLUMP_CUT := 0.7
const CLUMP_SHARE := 0.42
const GUST_CUT := 0.68
const TIDE_AT := 0.55
const RIPPLE_FIELD := 0.66
const RIPPLE_GAP := 5.0
const WET_STEP := 0.6

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
## The whole forest thinned 25% (2026-10-01, Richard, two passes), over every share above.
const WOOD_DENSITY := 0.75

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
## what `retune` pushes to the shader (`tools/shot_grass.gd` moves them).
var beach_width: float = SAND_OUT
var wander_amp: float = WANDER_AMP
var wander_scale: float = WANDER_SCALE
var wander_fine: float = WANDER_FINE
## This layer's tone blotches; -1 takes the layer's own.
var tone_levels: int = -1
var fringe_mode: int = FRINGE_MODE
var fringe_depth: float = FRINGE_DEPTH
var fringe_share: float = FRINGE_SHARE
var lip: bool = LIP
var tuft_share: float = TUFT_SHARE
var tuft_reach: float = TUFT_REACH
var clump_cut: float = CLUMP_CUT
var clump_share: float = CLUMP_SHARE
var gust_cut: float = GUST_CUT
var tide_at: float = TIDE_AT
var ripple_field: float = RIPPLE_FIELD
var ripple_gap: float = RIPPLE_GAP
var wet_step: float = WET_STEP

## How wet the sand is, 0 to 1 (`Puddles`, while it rains). The shader darkens sand by it.
func set_wet(amount: float) -> void:
	if _material != null:
		_material.set_shader_parameter(&"wet_sand", amount)


## How stormy it is, 0 to 1 (the day's overcast, pushed by `Lake._push_daylight`): the lawn's
## clumps sway harder and faster under it. Only sent when it moves, since it is every frame.
func set_storm(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if _material == null or is_equal_approx(amount, _storm):
		return
	_storm = amount
	_material.set_shader_parameter(&"storm", amount)


var _storm := 0.0


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
## Per picture, the transparent rows under its lowest opaque one, in art pixels. The pack
## pads its rocks by up to seven: hinged on the picture's bottom edge, a shadow started that
## far below the stone and read as lying apart from it.
var _prop_pad: Dictionary = {}
var _placed: Array = []
var _prop_points := PackedVector2Array()
var _prop_uvs := PackedVector2Array()
var _prop_colors := PackedColorArray()
var _prop_indices := PackedInt32Array()
## The south bank's wood drawn a second time, over the animals and the bees (2026-09-25,
## Richard: "a rabbit and bees over the trees"). The ground is one layer under everything
## on the land, so a canopy on the near side of the lake could not hide what stands behind
## it. Only forest trees (`COVER_FROM` tiles out of the water and on) south of the lake's
## middle: there the canopy rises up the screen over the lawn behind it; on the north bank
## it rises away from the lawn and covers nothing, and redrawn there it would be drawn over
## an animal standing in front of it. Under the walkers (9) and the hulls: nobody walks there.
const COVER_LAYER := 7
const COVER_FROM := WOOD_FROM - 1.0
var _cover: Node2D
var _cover_points := PackedVector2Array()
var _cover_uvs := PackedVector2Array()
var _cover_colors := PackedColorArray()
var _cover_indices := PackedInt32Array()

## Half the basin's box on the screen's axes, measured once. See `_boxed`.
var _basin_half := Vector2.ZERO

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
	# The island's tufts lean with the water (2026-10-02). Its props are only tufts, so the
	# whole batch wears the sway shader, and their shadows lean with them through it.
	#
	# Both layers wear it since the one-sun pass (2026-10-02): the shader is what draws a
	# shadow in the day's ink, pushed every frame as a uniform, so the overcast and the
	# lightning reach a batch that is only baked again when the sun moves. The outside
	# layer's trees, rocks and tufts are packed standing still (`_corner_colours`), so the
	# shader moves nothing there; it only inks the shadows.
	material = Flora.sway_material()
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
	# The wet edge the coast wave leaves is the water's own wave, read the same way.
	_material.set_shader_parameter(&"coast_wave", Lake.COAST_WAVE)
	_material.set_shader_parameter(&"coast_waves", Lake.COAST_WAVES)
	_material.set_shader_parameter(&"coast_wave_speed", Lake.COAST_WAVE_SPEED)
	var palette := Palette.master()
	if palette != null:
		_material.set_shader_parameter(&"fringe_dark", palette.grass_dark)
		_material.set_shader_parameter(&"lip_color", palette.grass_dark.darkened(0.25))
	_push_tunables()
	_sheet.material = _material
	add_child(_sheet)


## The tunables to the shader. The island keeps its own edge whatever the sliders say: a kept
## yard has a decided edge, so the mainland's wander is not its; the blades are shared.
func _push_tunables() -> void:
	var island := layer == Layer.ISLAND
	_material.set_shader_parameter(&"beach_width", beach_width)
	_material.set_shader_parameter(&"wander_amp", 0.0 if island else wander_amp)
	_material.set_shader_parameter(&"wander_scale", wander_scale)
	_material.set_shader_parameter(&"wander_fine", wander_fine)
	var tone := tone_levels if tone_levels >= 0 else (TONE_ISLAND if island else TONE_BANK)
	_material.set_shader_parameter(&"tone_levels", tone)
	var shades := lawn_shades(GRASS_ISLAND if island else GRASS_BANK)
	for key: StringName in shades:
		_material.set_shader_parameter(key, shades[key])
	_material.set_shader_parameter(&"fringe_mode", fringe_mode)
	_material.set_shader_parameter(&"fringe_depth", fringe_depth)
	_material.set_shader_parameter(&"fringe_share", fringe_share)
	_material.set_shader_parameter(&"lip", lip)
	for key: StringName in [&"clump_cut", &"clump_share", &"gust_cut", &"tide_at",
			&"ripple_field", &"ripple_gap", &"wet_step"]:
		_material.set_shader_parameter(key, get(key))


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
			if out < WOOD_FROM or _hash(at.x * 3.1, at.y * 2.7) > share * WOOD_DENSITY:
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
	# The ink every frame, cheaply: a uniform, not a bake. The day's ink carries the overcast
	# and the flash, which change far faster than the sun moves.
	var ink := Shade.tint_on(day, Shade.On.LAND)
	if ink != _ink_pushed:
		_ink_pushed = ink
		Flora.shade_skin(material as ShaderMaterial, day)
	if absf(day.lean - _sun_baked) < SUN_STEP and absf(day.stretch - _stretch_baked) < SUN_STEP:
		return
	queue_redraw()


## The props, all of them in one batch: every tree, rock and tuft and every shadow they
## throw, in painter's order, off one atlas. They used to be a draw call each — two with the
## shadow — and a wood of a few thousand was nearly six thousand draw calls a frame, which
## was most of what a frame cost. The ground itself is the `Sheet` child, drawn behind this.
func _draw() -> void:
	_lay_props()
	if _cover == null and layer == Layer.OUTSIDE:
		_cover = Node2D.new()
		_cover.name = &"Cover"
		_cover.z_index = COVER_LAYER
		_cover.z_as_relative = false
		_cover.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_cover.draw.connect(_draw_cover)
		add_child(_cover)
	if _cover != null:
		_cover.queue_redraw()
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


func _draw_cover() -> void:
	if _cover_indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(
		_cover.get_canvas_item(), _cover_indices, _cover_points, _cover_colors, _cover_uvs,
		PackedInt32Array(), PackedFloat32Array(), _prop_atlas.get_rid()
	)


## The trees, rocks and tufts on one tile, standing on `mid`.
##
## Sat on the plane by their feet, not their middles: everything in the pack is drawn as a
## thing standing on the ground, and hanging it by the centre would bury half of every trunk.
func _plant(mid: Vector2, art: Texture2D) -> void:
	var size := Vector2(art.get_width(), art.get_height()) * SCALE
	var uv: Rect2 = _prop_uv[art]
	_lay_shadow(mid, size, uv, float(_prop_pad.get(art, 0)) * SCALE)
	var box := Rect2(mid - Vector2(size.x * 0.5, size.y - Iso.TILE_H * 0.5), size)
	# The island's tufts lean with the water, like Flora's plants (2026-10-02): this layer's
	# batch wears Flora's sway shader, and a tuft's top corners carry its foot packed in.
	_prop_quad(
		Transform2D.IDENTITY,
		[box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)],
		uv, Color.WHITE, _corner_colours(mid.x, 1.0)
	)
	if covers_at(mid):
		var base := _cover_points.size()
		for k in 4:
			_cover_points.append(_prop_points[_prop_points.size() - 4 + k])
			_cover_uvs.append(_prop_uvs[_prop_uvs.size() - 4 + k])
			_cover_colors.append(Color.WHITE)
		_cover_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


## A prop's four corners, packed for the sway shader (`Flora.sway_material`): its foot's x,
## and what each corner does — on the island the top two lean with the water, out on the bank
## nothing moves. `flag` is the alpha: 1 for the prop itself, `Flora.SHADE_LAND` for its
## shadow, which the shader then draws in the land's ink. The shadow carries the prop's own
## roles, so its far end, which is the picture's top laid along the sun, leans as the top does.
func _corner_colours(x: float, flag: float) -> PackedColorArray:
	var top := LakeGrid.pack_anchor(x, Flora.TOP if layer == Layer.ISLAND else Flora.FOOT, flag)
	var foot := LakeGrid.pack_anchor(x, Flora.FOOT, flag)
	return PackedColorArray([top, top, foot, foot])


## Is a prop standing here one of the south wood's, drawn again over the animals.
func covers_at(foot: Vector2) -> bool:
	if layer != Layer.OUTSIDE:
		return false
	var t := Iso.world_to_tile(foot)
	var middle := Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)
	return foot.y > middle.y and out_of_water(t.x, t.y) >= COVER_FROM



## A tree's or a rock's shadow: the same picture again, laid out on the ground away from the
## sun in flat ink. See Shade.
##
## The ground is baked rather than drawn per frame — a wood of several hundred trees is laid
## out once and left alone — so these move in steps rather than continuously: `_process`
## above asks for a fresh bake when the sun has moved enough to be worth one. Over a ten
## minute day that is a handful of rebuilds, against sixty a second for a shadow nobody can
## see moving anyway.
##
## **The ink is not baked** (2026-10-02, one sun): the corners carry the prop's packed foot
## with `Flora.SHADE_LAND` in the alpha, and the sway shader draws them in the land's ink
## (`Shade.tint_on`), a uniform `_process` pushes every frame. Baked in, the ink only moved
## with the sun, so a shower's grey and a lightning flash never reached the wood's shadows.
## Overlapping shadows still stack, as they always have: each is its own translucent quad.
##
## Hinged at the prop's own foot, `mid` plus half a tile down, which is where `_plant` stands
## the picture. It was hinged at the layer's origin once, and every shadow in the wood came
## out stacked on top of each other in one black streak at the corner of the tile field.
##
## And hinged on the lowest opaque row, not the picture's bottom edge: `pad` is the empty
## band under the ink, in world px, so the shadow's foot meets the trunk's or the stone's.
func _lay_shadow(mid: Vector2, size: Vector2, uv: Rect2, pad: float = 0.0) -> void:
	if day == null:
		return
	var foot := mid + Vector2(0.0, Iso.TILE_H * 0.5 - pad)
	var lie := Shade.cast(foot, day.lean, day.stretch)
	var box := Rect2(Vector2(-size.x * 0.5, -size.y + pad), size)
	_prop_quad(
		lie,
		[box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)],
		uv, Color.WHITE, _corner_colours(mid.x, Flora.SHADE_LAND)
	)


## One picture into the prop batch: four corners (top-left, top-right, bottom-right,
## bottom-left) put through `xform`, the atlas rectangle, and the colour it is multiplied by.
func _prop_quad(
	xform: Transform2D, corners: Array, uv: Rect2, tint: Color,
	per_corner: PackedColorArray = PackedColorArray()
) -> void:
	var base := _prop_points.size()
	for i in corners.size():
		_prop_points.append(xform * (corners[i] as Vector2))
		_prop_colors.append(per_corner[i] if per_corner.size() == corners.size() else tint)
	_prop_uvs.append(uv.position)
	_prop_uvs.append(Vector2(uv.end.x, uv.position.y))
	_prop_uvs.append(uv.end)
	_prop_uvs.append(Vector2(uv.position.x, uv.end.y))
	_prop_indices.append_array(
		PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3])
	)


## Lay every prop and its shadow into the batch, for the sun as it is now, and tell the
## shader which way a picture's width lies under that sun, so a leaning tuft's shadow moves
## along the shadow and not across it.
func _lay_props() -> void:
	if day != null:
		_sun_baked = day.lean
		_stretch_baked = day.stretch
		Flora.shade_across(material as ShaderMaterial, day.lean, day.stretch)
	_prop_points.resize(0)
	_prop_uvs.resize(0)
	_prop_colors.resize(0)
	_prop_indices.resize(0)
	_cover_points.resize(0)
	_cover_uvs.resize(0)
	_cover_colors.resize(0)
	_cover_indices.resize(0)
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
		if not arts[i].resource_path.contains("/Tree"):
			var shades := lawn_shades(GRASS_ISLAND if layer == Layer.ISLAND else GRASS_BANK)
			var ramp: Array[Color] = [shades[&"lawn_low"], shades[&"lawn_mid"], shades[&"lawn_light"]]
			_green_to_lawn(img, ramp)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), spots[i])
		_prop_pad[arts[i]] = _pad_under(img)
		_prop_uv[arts[i]] = Rect2(
			Vector2(spots[i]) / Vector2(sheet.get_size()),
			Vector2(img.get_size()) / Vector2(sheet.get_size())
		)
	_prop_atlas = ImageTexture.create_from_image(sheet)


## The greens of a grass slice's top face, darkest first: every colour at least
## `LAWN_LEAST` of its pixels wear. What the props' tufts and the buildings' hems are
## recoloured onto, so they are the lawn they stand in (2026-09-28: they were the old pools'
## greens and stood out lighter on the one-grass lawn).
const LAWN_LEAST := 0.004
static var _lawn_cache := {}


## What the drawn lawn is painted in: the slice's commonest green as the ground, the next
## one down its ramp for the blades and speckle, the next one up for the blade tips.
static func lawn_shades(slice: int) -> Dictionary:
	var greens := lawn_greens(slice)
	var base: Color = _lawn_base[slice]
	var at := greens.find(base)
	return {
		&"lawn_mid": base,
		&"lawn_low": greens[maxi(at - 1, 0)],
		&"lawn_light": greens[mini(at + 1, greens.size() - 1)],
		# The clumps' sunward tips: one step further up the same ramp.
		&"lawn_hi": greens[mini(at + 2, greens.size() - 1)],
	}


static var _lawn_base := {}


static func lawn_greens(slice: int) -> Array[Color]:
	if _lawn_cache.has(slice):
		return _lawn_cache[slice]
	var img := (load(TILES % slice) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var counts := {}
	var total := 0
	for y in range(GRASS_FACE_ROW, GRASS_FACE_ROW + int(FACE)):
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			counts[c] = int(counts.get(c, 0)) + 1
			total += 1
	var out: Array[Color] = []
	for c: Color in counts:
		if float(counts[c]) >= total * LAWN_LEAST:
			out.append(c)
	out.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	var most := 0
	for c: Color in counts:
		if int(counts[c]) > most:
			most = counts[c]
			_lawn_base[slice] = c
	_lawn_cache[slice] = out
	return out


## Every green pixel of `img` moved onto `lawn` by where its brightness falls among the
## picture's own greens: the darkest of them to the lawn's darkest, the lightest to its
## lightest. A rank, not a tint, so the tuft keeps its shading.
static func _green_to_lawn(img: Image, lawn: Array[Color]) -> void:
	if lawn.is_empty():
		return
	var low := 1.0
	var high := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a >= 0.5 and _is_green(c):
				low = minf(low, c.get_luminance())
				high = maxf(high, c.get_luminance())
	if high < low:
		return
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5 or not _is_green(c):
				continue
			var t := 0.5 if high - low < 0.001 else (c.get_luminance() - low) / (high - low)
			var pick := lawn[clampi(roundi(t * (lawn.size() - 1)), 0, lawn.size() - 1)]
			img.set_pixel(x, y, Color(pick.r, pick.g, pick.b, c.a))


static func _is_green(c: Color) -> bool:
	return c.s > 0.3 and c.h > 0.17 and c.h < 0.45


## How far up from the picture's bottom edge the shadow is hinged, in art pixels: the
## transparent rows under the ink, plus how deep the thing's own base runs into the picture.
## A rock is drawn in three-quarter view, so its lowest pixel is the near edge of what it
## stands on, and a shadow hinged there starts in front of the stone with grass between.
## The base's depth is a quarter of the ink's width across its bottom few rows (a 2:1
## footprint, half of it in front of the middle), so a thin trunk moves by a pixel and a
## broad rock by several, and the prop is drawn over the part tucked under it.
static func _pad_under(img: Image) -> int:
	var low := -1
	for y in range(img.get_height() - 1, -1, -1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				low = y
				break
		if low >= 0:
			break
	if low < 0:
		return 0
	var wide := 0
	for y in range(maxi(low - BASE_ROWS + 1, 0), low + 1):
		var first := -1
		var last := -1
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				if first < 0:
					first = x
				last = x
		if first >= 0:
			wide = maxi(wide, last - first + 1)
	return img.get_height() - 1 - low + int(round(float(wide) * 0.25))


## The rows at the bottom of a prop's ink measured for the width of its base.
const BASE_ROWS := 4


## Whether a world point is under any tree's or rock's drawn ink on this ground, grown by
## `grow` px. Flora is drawn over the ground layer, so a flower on the forest floor has to
## stand where no prop's picture is, or it is painted on the trunk. Tiles on the screen below
## the point are searched too, since a picture rises from its foot.
var _prop_images: Dictionary = {}


func hidden_by_prop(world: Vector2, grow: float = 2.0) -> bool:
	var tile := Iso.world_to_tile(world)
	var cx := int(floor(tile.x))
	var cy := int(floor(tile.y))
	for dx in range(-2, 7):
		for dy in range(-2, 7):
			var cell := Vector2i(cx + dx, cy + dy)
			if not _props.has(cell):
				continue
			for entry: Array in _props[cell]:
				var art: Texture2D = entry[0]
				var foot: Vector2 = entry[1]
				var size := Vector2(art.get_width(), art.get_height()) * SCALE
				var box := Rect2(foot - Vector2(size.x * 0.5, size.y - Iso.TILE_H * 0.5), size)
				if not box.grow(grow).has_point(world):
					continue
				if not _prop_images.has(art):
					var img := art.get_image()
					if img.is_compressed():
						img.decompress()
					_prop_images[art] = img
				var img: Image = _prop_images[art]
				var r := int(ceil(grow / SCALE))
				var px := Vector2i(((world - box.position) / SCALE).floor())
				for ox in range(-r, r + 1):
					for oy in range(-r, r + 1):
						var q := px + Vector2i(ox, oy)
						if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() \
								and img.get_pixel(q.x, q.y).a > 0.0:
							return true
	return false


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
##
## The basin's box is asked for once and kept. `Iso.basin_extent` walks the whole shore
## outline to answer, and this is called for every lawn tile of the ring: asked afresh each
## time it was 2.2 s of the lake's 2.6 s load (`tools/probe_boot.gd`, 2026-09-17), all of it
## re-measuring a lake that does not change shape.
func _boxed(at: Vector2) -> float:
	if _basin_half == Vector2.ZERO:
		_basin_half = Iso.basin_extent() * 0.5
	var half := _basin_half
	var here := Iso.tile_to_world(at.x, at.y) - Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)
	if half.x <= 0.0 or half.y <= 0.0:
		return 0.0
	return maxf(absf(here.x) / half.x, absf(here.y) / half.y)


## A stable number in 0..1 for a spot on the plane.
func _hash(x: float, y: float) -> float:
	var h := sin(x * 127.1 + y * 311.7 + float(SEED) * 0.0001) * 43758.5453
	return h - floor(h)
