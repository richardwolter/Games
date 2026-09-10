## The lake's rubbish: one stack of pieces per tile of the basin floor.
##
## Isometric, so the lake is a surface rather than a cross-section. Each tile still holds
## a stack — deep water holds more rubbish than the shallows, and the tiers underneath are
## still what the upgrades buy their way down to — but only the top piece of a stack is
## ever drawn, floating on the water above its tile. Nothing underwater is rendered at
## all, which is both what the view can honestly show and a draw budget that no longer
## scales with how full the lake is.
##
## What that buys, beyond the pixels:
##
##   - One draw per non-empty visible tile, whatever the stack depth. A full basin and a
##     nearly-clear one cost the same.
##   - Only the top of a stack can be taken, and now that is also all you can see. "Skim
##     the light stuff, upgrade to reach the heavy stuff under it" is the shape of the
##     data, not a rule checked somewhere.
##   - Open water spreading across the basin is the progress bar.
##
## Kept from the side-on version: packed arrays rather than nodes, and drawing culled
## against a view rect the camera sets.
class_name LakeGrid
extends Node2D

## How fast a newly exposed piece rises to the surface after the one above it is taken,
## in pixels per second. Fast enough to read as a consequence, slow enough to see.
const EMERGE_SPEED := 90.0

## How far under the waterline a freshly exposed piece starts.
const EMERGE_DROP := 16.0

## How many slots below the top of a stack a keepsake still shows through, and how bright
## its glitter is at the top of a stack against the deepest slot that shows.
##
## The finds stay buried — see `_hide_treasures` in lake.gd, which plants them a couple of
## slots down on purpose — so the glitter is not a map of where they are. It is the last
## bit of the dig: a shimmer through the muck when one is nearly up, and the full glint
## once the piece above it comes off. A player who has learnt to read it is digging with a
## reason rather than skimming at random, which is the difference between a lake and a
## progress bar.
const GLINT_REACH := 3
const GLINT_BRIGHT := 0.55
const GLINT_FAINT := 0.10

## The colour a find glitters, how far the glitter spreads past the piece, how fast it
## breathes, and how many specks turn around an uncovered one.
const GLINT_TINT := Color(1.0, 0.84, 0.35)
const GLINT_SPAN := 1.45
const GLINT_BREATH := 2.3
const GLINT_SPECKS := 5

## How far a floating piece may be turned, in radians, how far it may drift off the middle
## of its own tile, as a fraction of a tile, and how much bigger or smaller than its drawn
## size it may ride. Rubbish in water lies every which way, and this is what stops eight
## thousand pictures reading as wallpaper.
const TURN := 0.55
const DRIFT := 0.3
const SIZE_SPREAD := 0.18

## How wide a span of world the packed anchor covers, centred on zero. Mirrors
## `anchor_span` in rubbish.gdshader. The basin is a few thousand pixels across, so this is
## roomy; sixteen bits over it lands each anchor within an eighth of a pixel.
const ANCHOR_SPAN := 8192.0

## Bob of the floating rubbish, matched to the water shader's swell.
const WAVE_AMPLITUDE := 5.0
const WAVE_SPEED := 1.0

## How far a floating piece wanders off its anchor, in pixels. Mirrors `sway` in
## rubbish.gdshader, which is where the movement actually happens — this side of it exists
## so the game can still say where a piece is.
const SWAY := 3.2

## The ring of disturbed water around a floating piece: how wide it is against the piece,
## how far it breathes in and out, how long one breath takes in seconds, and how dark it is
## drawn against the water.
##
## Something floating displaces water, and without this every piece in the lake sits on the
## surface like a sticker on glass.
const RIPPLE_SPAN := 1.30
const RIPPLE_BREATH := 0.24
const RIPPLE_TIME := 2.6
const RIPPLE_ALPHA := 0.26

## The second ring, further out and fainter, a beat behind the first. One ring is an
## outline drawn round a piece; two rings arriving in sequence is water leaving it.
const RIPPLE_OUTER := 1.55
const RIPPLE_OUTER_FADE := 0.55
const RIPPLE_OUTER_LAG := PI * 0.6

## The shadow under a floating piece: how wide against the piece, how dark, and how far
## down the plane it is pushed so it shows past the near edge of the art.
##
## There used to be a plate under each piece and it was taken out. This is not that plate:
## that one was *pale*, cut from the atlas's white block, so it lightened the water into a
## grey box. A shadow darkens towards the deep water, never towards grey — and it is pushed
## down the plane, so what the eye actually sees is a crescent past the near edge of the
## art rather than a disc the art is sitting in the middle of.
const SHADOW_SPAN := 1.0
const SHADOW_ALPHA := 0.15
const SHADOW_DROP := 0.22
const SHADOW_COLOUR := Color(0.03, 0.08, 0.11, 1.0)

## How many shadows there is room for. Everything on screen gets one — unlike the rings,
## which are sampled — so this is the worst case the view cull can hand over rather than a
## budget. The geometry for it is taken once at startup and written over every rebuild.
const SHADOW_MOST := 6000

## How far behind itself a piece trails its outer ring, against the ring's own width. Taken
## from which way the sway is carrying it, so the two rings go out of true in the direction
## of travel and read as a wake rather than as a target.
const RIPPLE_WAKE := 0.18
const RIPPLE_WAKE_LOOK := 0.35

## Most rings drawn at once. The rest of the lake goes without: past a hundred or so the
## water is a mass of them and the cost is real, so the ones near the middle of the view
## carry the effect for everybody.
const RIPPLE_MOST := 110

## What the basin's fill draws on for a slot, once depth has decided how many slots a tile
## gets. See `build`.
##
## `MATERIAL_QUOTA` is not tuned by feel: it is `Plastic, Timber, Metal, Rubber`, measured
## off the lake this replaced (`tools/measure_fill.gd`, one run, logged) so the four yards
## keep the mix of work they had before this changed what fills a stack. Changing which
## piece lands where should not quietly change which yard gets the traffic.
const MATERIAL_QUOTA := [0.24, 0.21, 0.42, 0.13]

## How wide a band of the lightness range is drawn from at one depth, as a fraction of the
## full range end to end.
##
## This is what replaced sorting the whole basin into one line from lightest to heaviest.
## A tile's depth still points at a rough weight class — see `up` in `build` — but the
## band is wide enough that which piece within it turns up is not the same piece every
## time, and not obviously the next one down from its neighbour either. Narrower and every
## tile at a depth reads as the same again; wider and the band stops meaning anything, which
## is `FRINGE_BAIT` below rather than the general case.
const FILL_BAND := 0.55

## How often a slot ignores its depth's band entirely and draws from the material's whole
## range instead.
##
## Without this, nothing heavy ever floats near the surface, which is exactly the
## in-sequence read this was meant to break: skim long enough and the shape of what is
## left still gives away the schedule. A rare heavy piece sitting where a tool cannot yet
## reach it is a landmark instead — something to want the upgrade for — as long as it stays
## rare enough that it reads as a find and not as the new normal.
const FILL_BAIT_CHANCE := 0.06

## Def index per slot, bottom-first. One entry per tile, indexed ty * Iso.COLS + tx; dry
## land is an empty stack.
var stacks: Array[PackedInt32Array] = []

## The pose of whatever is currently on top of each tile, so a field of tiles does not read
## as a grid: how far it is turned, how far it has drifted off the middle of its tile, how
## big it rides, and which way round it is facing. Rerolled when the top changes — only one
## piece per tile is visible, so only one piece per tile needs a pose.
##
## Turn and drift alone were not enough once the art landed. Sixteen-pixel pictures all
## sitting square at the same size read as a tiled pattern however far they are nudged, and
## a lake is not a pattern.
var tilt := PackedFloat32Array()
var nudge := PackedVector2Array()
var swing := PackedFloat32Array()
var facing := PackedByteArray()

## Pixels the exposed piece of each tile is still rising. One float per tile.
var emerge := PackedFloat32Array()

var defs: Array[TrashDef] = []

## The non-keepsake defs, split by material and each sorted by lightness. What `build`
## draws a slot's piece from: the quota picks one of these four, the band narrows it, and
## sorted order is what makes "narrows it" a contiguous slice rather than a filter over
## the whole list every slot.
var _by_material: Array = [[], [], [], []]

## The lightest and heaviest a slot can ask for, across every material together, so a
## depth's band means the same weight class whichever material the quota happens to draw.
var _lightness_span := Vector2(0.0, 1.0)

## The art. With no atlas every piece falls back to the blocked-in quad it used to be, so
## the lake still runs with assets/ missing.
var sheets: Sheets

## Only tiles inside this rectangle are drawn. Set by lake.gd from the camera.
var view := Rect2()

## How many pieces the last rebuild put on screen, and how many rebuilds have happened.
## Both are read by the test harness: the second one is the guard that stops the per-frame
## rebuild creeping back in.
var drawn_pieces: int = 0
var rebuilds: int = 0

## What asked for those rebuilds. Only the perf overlay reads these, and they are here
## because the first guess at why the lake was hitching was wrong: the cost was obvious
## and the cause was not, and a counter per reason is cheaper than another guess.
var from_view: int = 0
var from_detail: int = 0
var from_patch: int = 0

## How long the last rebuild took, in milliseconds, and how many tiles it walked to do it.
## The overlay's, same as the counters above: what a rebuild costs is the number the whole
## question turns on, and inferring it from frame time is how the last guess went wrong.
var rebuild_ms: float = 0.0
var walked: int = 0

## The triangle soup every visible piece lives in. Rebuilt only when something that is not
## the bob has changed.
var _mesh_points := PackedVector2Array()
var _mesh_uvs := PackedVector2Array()
var _mesh_colors := PackedColorArray()
var _mesh_indices := PackedInt32Array()
var _dirty: bool = true

## How far into the mesh arrays a rebuild has written: vertices, and indices. The arrays
## are sized to the worst case up front and written into by index, then cut back to what
## was used — the same trick the shadow layer already plays, and for the same reason.
## Appending grew three Packed arrays a few thousand times per rebuild, and that was most
## of what a rebuild cost.
var _fill: int = 0
var _tri: int = 0

## The most vertices one piece can take. Mirrors the branches in `_stamp`: four for a piece
## with art on it, and four quads for the blocked-in fallback at full detail.
const PIECE_VERTS := 16

## Where each tile's vertices sit in the soup, and how many it has. -1 for a tile the last
## rebuild did not stamp — empty, culled, or drawn by the sprite layer instead.
##
## This is what lets a piece being taken, or one rising into place, rewrite its own corner
## of the soup instead of forcing the whole thing to be laid out again. The net takes a
## handful of pieces a second and a rising piece moves every frame; before this, each of
## those re-stamped every visible piece in the lake, which is a few thousand of them for
## the sake of one.
var _slot_base := PackedInt32Array()
var _slot_len := PackedInt32Array()

## Which shadow in the shadow layer belongs to each tile, so a patch can move a piece's
## shadow with it. -1 for a tile that has none.
var _shadow_at := PackedInt32Array()

## Where `_quad` writes. -1 to append, which is what a rebuild does; anything else is a
## patch overwriting one tile's vertices in place. The winding never changes, so a patch
## leaves `_mesh_indices` alone.
var _write_at: int = -1

## False when the view is zoomed far enough out that a piece is a few pixels across. Drops
## the two parts of a piece that are then invisible anyway.
var _detailed: bool = true

## Tiles with something still rising into place. Kept as a list rather than found by
## scanning the whole field: at eight thousand tiles that scan was costing more per frame
## than the handful of pieces it was looking for.
var _emerging := PackedInt32Array()

## Pieces with a real sprite, which cannot go in the soup. Drawn the old way, one at a
## time, on a layer of their own.
var _sprites: SpriteLayer
## The ring layer, and the pieces it is currently drawing rings for.
var _ripples: RippleLayer
var _shadows: ShadowLayer
var _glints: GlintLayer

## The atlas's solid-white block, as texture coordinates. Cached: every untextured quad in
## the soup samples it, and it never moves.
var _white_uv := Rect2()

var _rng := RandomNumberGenerator.new()
var _time: float = 0.0


## The fallback layer for textured pieces. One triangle array carries one texture, so a
## piece with a sprite cannot join the batch — and it also cannot use the bob shader,
## whose UVs are carrying anchor positions instead of texture coordinates. Both problems
## have the same answer: draw those the old way, over here, with the swell on the CPU.
##
## Nothing has a sprite yet. This layer exists so that the day one does, it appears in the
## right place rather than as a smear.
class SpriteLayer extends Node2D:
	var grid: LakeGrid
	var pieces: Array[int] = []

	func set_pieces(list: Array[int]) -> void:
		pieces = list
		set_process(not pieces.is_empty())
		queue_redraw()

	func _process(_delta: float) -> void:
		# These bob on the CPU, so they do have to be redrawn. There are never many.
		queue_redraw()

	func _draw() -> void:
		for index: int in pieces:
			var stack := grid.stacks[index]
			if stack.is_empty():
				continue
			draw_set_transform(grid.surface_pos(index), grid.tilt[index], Vector2.ONE)
			grid.defs[stack[stack.size() - 1]].stamp_iso(self)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The golden glitter round a find.
##
## Above the rubbish rather than under it, because it has to be visible while the find
## itself is not: a piece three slots down is behind whatever is sitting on top of it, and
## a glow drawn underneath that is a glow nobody sees. Faint enough at depth that it reads
## as light coming up through the water rather than as an outline.
##
## Fed one entry per find on screen: the tile it is on, and how many slots down it is.
class GlintLayer extends Node2D:
	var grid: LakeGrid
	var finds: Array[Vector2i] = []
	var age: float = 0.0

	func set_finds(list: Array[Vector2i]) -> void:
		finds = list
		set_process(not finds.is_empty())
		queue_redraw()

	func _process(delta: float) -> void:
		age += delta
		queue_redraw()

	func _draw() -> void:
		for find: Vector2i in finds:
			var index := find.x
			var sunk := find.y
			var stack := grid.stacks[index]
			if stack.is_empty():
				continue
			var at := grid.surface_pos(index)
			# The piece it belongs to when it is up, and whatever is covering it when it is
			# not: either way the glitter is sized off what is drawn on that tile, so it
			# never spills across the neighbours.
			var def := grid.defs[stack[stack.size() - 1]]
			var span := maxf(def.size.x, def.size.y) * grid.swing[index] * GLINT_SPAN
			var lit := lerpf(
				GLINT_BRIGHT, GLINT_FAINT,
				clampf(float(sunk) / float(GLINT_REACH), 0.0, 1.0)
			)
			# Out of step tile by tile, so a basin with several finds in it does not pulse
			# like a set of indicator lights.
			var beat := 0.5 + 0.5 * sin(age * GLINT_BREATH + float(index) * 0.7)
			var glow := GLINT_TINT
			glow.a = lit * (0.55 + 0.45 * beat)
			draw_circle(at, span * 0.5, glow)

			if sunk > 0:
				continue
			# Specks, on the uncovered one only. A buried find shimmers; an uncovered one
			# is the thing the net is for, and the specks are what says so.
			var speck := GLINT_TINT
			speck.a = lit * (0.35 + 0.65 * beat)
			for n in GLINT_SPECKS:
				var turn := age * 0.8 + TAU * float(n) / float(GLINT_SPECKS)
				draw_circle(
					at + Vector2(cos(turn), sin(turn) * 0.5) * span * 0.55,
					maxf(span * 0.06, 1.0), speck
				)


## The rings of disturbed water round the floating rubbish.
##
## Its own layer, under the junk, because it is the one thing about a floating piece that
## has to be redrawn every frame: the geometry of the lake is static and rocked by the
## vertex shader, and a ring that breathes cannot be. Bounded rather than complete — a lake
## of eighteen thousand rings is both unreadable and not free — so it draws a spread of what
## is on screen and lets the rest of the water carry the idea.
## The shadows every floating piece throws on the water.
##
## Its own layer, under both the rings and the rubbish, and built once per rebuild out of the
## same view-culled list the soup uses — one triangle array, every piece on screen, not the
## hundred-odd the rings can afford.
##
## What moves it is shaders/shadow.gdshader, which takes the wander and leaves the bob. A
## shadow that rises and falls with the thing casting it is the exact tell that the thing is
## a sticker rather than something floating; a shadow that sits still while its mug drifts
## off it is the same tell from the other side. So the geometry stays static and the GPU
## slides each shadow along its piece's own sway, off the anchor packed into its vertices.
class ShadowLayer extends Node2D:
	var grid: LakeGrid

	var _points := PackedVector2Array()
	var _colors := PackedColorArray()
	var _indices := PackedInt32Array()
	var _count: int = 0

	## Six points to a shadow: a hexagon flattened into the plane's own 2:1. Six rather than
	## a diamond because a diamond has a visible point on it at this size, and rather than
	## the twelve the rings use because there are one of those for every hundred of these.
	const CORNERS := 6

	## The corner offsets, worked out once. `cos` and `sin` per corner per piece per rebuild
	## is a few hundred thousand calls on a full screen, and the answer is always the same
	## six numbers.
	static var _ring: PackedVector2Array = _build_ring()

	static func _build_ring() -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in CORNERS:
			var angle := TAU * float(i) / float(CORNERS)
			out.append(Vector2(cos(angle) * 0.5, sin(angle) * 0.25))
		return out

	## Room for `most` shadows, taken once. The arrays are sized to the worst case and then
	## written into by index: this runs for every piece on screen on every rebuild, and
	## appending to three Packed arrays that many times is the difference between the lake
	## drawing itself and the lake being rebuilt.
	func reserve(most: int) -> void:
		var verts := most * (CORNERS + 1)
		_points.resize(verts)
		_colors.resize(verts)
		_indices.resize(most * CORNERS * 3)
		_dress()
		for piece in most:
			var middle := piece * (CORNERS + 1)
			var at := piece * CORNERS * 3
			for i in CORNERS:
				_indices[at + i * 3] = middle
				_indices[at + i * 3 + 1] = middle + 1 + i
				_indices[at + i * 3 + 2] = middle + 1 + (i + 1) % CORNERS

	## The shader that does the moving, and the colour it draws in. Taken once: a material
	## per rebuild would be a new resource sixty times a second in a lake being cleared.
	func _dress() -> void:
		var shade := LakeGrid.SHADOW_COLOUR
		shade.a = LakeGrid.SHADOW_ALPHA
		var skin := ShaderMaterial.new()
		skin.shader = load("res://shaders/shadow.gdshader") as Shader
		skin.set_shader_parameter("sway", LakeGrid.SWAY)
		skin.set_shader_parameter("wave_speed", LakeGrid.WAVE_SPEED)
		skin.set_shader_parameter("anchor_span", LakeGrid.ANCHOR_SPAN)
		skin.set_shader_parameter("shade", shade)
		material = skin

	## One shadow, written in place. Called from the rebuild's own walk over the lake, so
	## the pieces are visited once rather than once for the soup and again for this.
	##
	## The vertex colour is not a colour here: it carries the piece's anchor for the shader
	## to read, the same packing the rubbish soup uses, and what a shadow is actually drawn
	## in is a uniform. Written per corner rather than once at startup because the anchor
	## belongs to the piece, and which piece sits in which slot changes every rebuild.
	func add(at: Vector2, size: Vector2, swing: float) -> int:
		var slot := _count
		if not write(slot, at, size, swing):
			return -1
		_count += 1
		return slot

	## One shadow written into a slot that already exists, so a piece taken or rising can
	## move its own shadow without the whole layer being laid out again. Mirrors the soup's
	## `_restamp`: the two have to move together, or a piece parts company with its shadow.
	func write(slot: int, at: Vector2, size: Vector2, swing: float) -> bool:
		var middle := slot * (CORNERS + 1)
		if slot < 0 or middle + CORNERS >= _points.size():
			return false
		var centre := Vector2(at.x, at.y + size.y * LakeGrid.SHADOW_DROP)
		var wide := size.x * swing * LakeGrid.SHADOW_SPAN
		var anchor := LakeGrid.pack_anchor(at.x, 0.0, 1.0)
		_points[middle] = centre
		_colors[middle] = anchor
		for i in CORNERS:
			_points[middle + 1 + i] = centre + _ring[i] * wide
			_colors[middle + 1 + i] = anchor
		return true

	## Collapse a shadow to a point. Its slot stays where it is — the ones after it are in
	## use — and its triangles come out with no area, so nothing is drawn.
	func blank(slot: int) -> void:
		var middle := slot * (CORNERS + 1)
		if slot < 0 or middle + CORNERS >= _points.size():
			return
		for i in CORNERS + 1:
			_points[middle + i] = Vector2.ZERO

	func begin() -> void:
		_count = 0

	func finish() -> void:
		queue_redraw()

	func _draw() -> void:
		if _count <= 0:
			return
		# Only the part that was written this rebuild. The arrays keep their full length so
		# nothing is reallocated; the slice is what gets submitted.
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(),
			_indices.slice(0, _count * CORNERS * 3),
			_points.slice(0, _count * (CORNERS + 1)),
			_colors.slice(0, _count * (CORNERS + 1))
		)


## The rings the floating junk sits in.
##
## Every ring moves every frame — it breathes on its own phase and rides the same drift the
## piece does — so there is nothing here to cache between frames. What there was to fix is
## how the movement got onto the screen: a ring used to be a fresh thirteen-point array with
## a cosine and a sine per point, handed to its own `draw_polyline`. At a hundred and ten
## pieces that was two hundred and twenty allocations, near three thousand trig calls and
## two hundred and twenty draw commands, sixty times a second, and it cost more frames than
## anything else in the game.
##
## Now the ring shape is worked out once (`UNIT`, a unit circle in the tile's own 2:1) and
## every ring is that shape moved and scaled; the segments all go into two buffers that are
## allocated once and rewritten in place; and each buffer goes to the screen in a single
## multiline call. Same picture, two draw commands.
class RippleLayer extends Node2D:
	## The ring, as offsets from its middle at width 1. Twelve segments, so thirteen points
	## with the last one back on the first.
	const RING_POINTS := 13
	const RING_SEGMENTS := RING_POINTS - 1

	## The inner ring is drawn heavier than the wake behind it, and a multiline carries one
	## width for the whole call — which is why there are two buffers rather than one.
	const INNER_WIDE := 1.4
	const OUTER_WIDE := 1.0

	static var UNIT: PackedVector2Array = _unit_ring()

	var grid: LakeGrid
	var pieces: PackedInt32Array = PackedInt32Array()
	var _time: float = 0.0

	## Segment endpoints and their colours: two points per segment and one colour per
	## segment, which is the shape a multiline wants. Sized to the piece list, then written
	## over every frame.
	var _inner: PackedVector2Array = PackedVector2Array()
	var _inner_ink: PackedColorArray = PackedColorArray()
	var _outer: PackedVector2Array = PackedVector2Array()
	var _outer_ink: PackedColorArray = PackedColorArray()

	static func _unit_ring() -> PackedVector2Array:
		var ring := PackedVector2Array()
		ring.resize(RING_POINTS)
		for i in RING_POINTS:
			var angle := TAU * float(i) / float(RING_SEGMENTS)
			ring[i] = Vector2(cos(angle) * 0.5, sin(angle) * 0.25)
		return ring

	func set_pieces(list: PackedInt32Array) -> void:
		pieces = list
		set_process(not pieces.is_empty())
		# Room for every piece to draw both its rings. Resized only when the float set
		# changes size, which is what a rebuild is for.
		var room := pieces.size() * RING_SEGMENTS * 2
		if _inner.size() != room:
			_inner.resize(room)
			_inner_ink.resize(room / 2)
			_outer.resize(room)
			_outer_ink.resize(room / 2)
		queue_redraw()

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	## One ring into a buffer: twelve segments, each written as its two endpoints so the
	## whole field can go out as one disconnected multiline.
	static func _lay(
		into: PackedVector2Array, ink: PackedColorArray, at: int,
		middle: Vector2, wide: float, tint: Color
	) -> void:
		var span := Vector2(wide, wide)
		for i in RING_SEGMENTS:
			var a := at + i * 2
			into[a] = middle + UNIT[i] * span
			into[a + 1] = middle + UNIT[i + 1] * span
			ink[at / 2 + i] = tint

	func _draw() -> void:
		var clock := grid.wave_time()
		var laid := 0
		for index: int in pieces:
			var stack := grid.stacks[index]
			if stack.is_empty():
				continue
			# Still water plus the drift, and deliberately *not* the bob. `surface_pos`
			# includes the swell, so the ring used to heave up and down with the piece it
			# was drawn around — a disturbance in the water that rises with the thing
			# floating in it is the whole reason the lake read as stickers on glass.
			var still := grid.surface_still(index)
			var at := still + LakeGrid._sway(still.x, clock)
			var def := grid.defs[stack[stack.size() - 1]]
			# Off the piece's own place on the water, so no two rings breathe together —
			# in step, a field of them pulses like a warning light.
			var phase := _time * TAU / LakeGrid.RIPPLE_TIME + at.x * 0.02 + at.y * 0.013
			var breath := 1.0 + sin(phase) * LakeGrid.RIPPLE_BREATH
			var wide := def.size.x * grid.swing[index] * LakeGrid.RIPPLE_SPAN * breath

			# Faintest at the top of the breath: a ring spreading is a ring going.
			var fade := LakeGrid.RIPPLE_ALPHA * (1.0 - sin(phase) * 0.35)
			_lay(_inner, _inner_ink, laid, at, wide, Color(0.86, 0.94, 0.96, fade))

			# And the one behind it, pushed back along the drift so the pair reads as a
			# wake rather than as a pair of circles round a target.
			var drift := (
				LakeGrid._sway(still.x, clock)
				- LakeGrid._sway(still.x, clock - LakeGrid.RIPPLE_WAKE_LOOK)
			)
			var trail := at
			if drift.length() > 0.05:
				trail -= drift.normalized() * wide * LakeGrid.RIPPLE_WAKE
			var out_phase := phase + LakeGrid.RIPPLE_OUTER_LAG
			var out_wide := (
				def.size.x * grid.swing[index] * LakeGrid.RIPPLE_SPAN * LakeGrid.RIPPLE_OUTER
				* (1.0 + sin(out_phase) * LakeGrid.RIPPLE_BREATH)
			)
			var out_fade := (
				LakeGrid.RIPPLE_ALPHA * LakeGrid.RIPPLE_OUTER_FADE
				* (1.0 - sin(out_phase) * 0.35)
			)
			_lay(
				_outer, _outer_ink, laid, trail, out_wide,
				Color(0.86, 0.94, 0.96, out_fade)
			)
			laid += RING_SEGMENTS * 2

		if laid <= 0:
			return
		# Only the part written this frame. The buffers keep their length so nothing is
		# reallocated; the slice is what gets submitted — the same bargain the shadow
		# layer above strikes.
		if laid == _inner.size():
			draw_multiline_colors(_inner, _inner_ink, INNER_WIDE)
			draw_multiline_colors(_outer, _outer_ink, OUTER_WIDE)
			return
		draw_multiline_colors(
			_inner.slice(0, laid), _inner_ink.slice(0, laid / 2), INNER_WIDE
		)
		draw_multiline_colors(
			_outer.slice(0, laid), _outer_ink.slice(0, laid / 2), OUTER_WIDE
		)


func _ready() -> void:
	_shadows = ShadowLayer.new()
	_shadows.name = &"Shadows"
	_shadows.grid = self
	# Under the rings, which are under the rubbish.
	_shadows.z_index = -2
	_shadows.reserve(SHADOW_MOST)
	add_child(_shadows)

	_ripples = RippleLayer.new()
	_ripples.name = &"Ripples"
	_ripples.grid = self
	# Under the rubbish: the ring is the water the piece is sitting in.
	_ripples.z_index = -1
	_ripples.set_process(false)
	add_child(_ripples)

	_sprites = SpriteLayer.new()
	_sprites.name = &"Sprites"
	_sprites.grid = self
	_sprites.set_process(false)
	add_child(_sprites)

	_glints = GlintLayer.new()
	_glints.name = &"Glints"
	_glints.grid = self
	# Over the rubbish: a find under two mugs still has to catch the eye.
	_glints.z_index = 1
	_glints.set_process(false)
	add_child(_glints)


## How coarsely the view rectangle is rounded before it counts as having moved, in world
## pixels.
##
## The camera eases toward the angler, so it is never exactly still — without this, the
## rectangle would differ by a fraction of a pixel every frame and force a rebuild every
## frame, which is the thing all of this is here to avoid. Rounding to a couple of tiles
## and padding by the same amount means the view only counts as moved once it has really
## moved, and the extra margin is already inside the cull.
const VIEW_SNAP := 160.0


func set_view(to: Rect2) -> void:
	var snap := Vector2(VIEW_SNAP, VIEW_SNAP)
	var coarse := Rect2(
		(to.position / VIEW_SNAP).floor() * VIEW_SNAP - snap,
		(to.size / VIEW_SNAP).ceil() * VIEW_SNAP + snap * 2.0
	)
	if coarse == view:
		return
	view = coarse
	_dirty = true
	from_view += 1
	queue_redraw()


## Whether pieces are drawn with their footprint and outline. lake.gd sets this from the
## camera: below a certain zoom both are smaller than a pixel, and skipping them halves
## the geometry for no visible difference.
func set_detailed(on: bool) -> void:
	if on == _detailed:
		return
	_detailed = on
	_dirty = true
	from_detail += 1
	queue_redraw()


func index_of(tx: int, ty: int) -> int:
	return ty * Iso.COLS + tx


func tile_of(index: int) -> Vector2i:
	return Vector2i(index % Iso.COLS, index / Iso.COLS)


## The tiles within `radius` of one, itself included. A diamond rather than a square, so
## the worked area is a circle on the plane rather than a screen-space rhombus.
##
## Lives here rather than on any one tool: the net and the boat's skimmer take their bite
## out of the lake the same way, and the shape of that bite is a property of the tile
## field.
func tiles_around(index: int, radius: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var centre := tile_of(index)
	for dy in range(-radius, radius + 1):
		var span := radius - absi(dy)
		for dx in range(-span, span + 1):
			var tx := centre.x + dx
			var ty := centre.y + dy
			if tx < 0 or ty < 0 or tx >= Iso.COLS or ty >= Iso.ROWS:
				continue
			out.append(index_of(tx, ty))
	return out


## The tiles whose centres are within `radius` tiles of one, itself included.
##
## A circle in tile space, which is an ellipse on screen — and the net draws that same
## ellipse from the same number, so what the player is shown is what is swept. `tiles_around`
## is the older diamond; it survives because the boat's skimmer is a bite out of the water
## with nothing drawn round it, and a diamond is cheaper.
func tiles_within(index: int, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var centre := tile_of(index)
	var span := int(ceil(radius))
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			if float(dx * dx + dy * dy) > radius * radius:
				continue
			var tx := centre.x + dx
			var ty := centre.y + dy
			if tx < 0 or ty < 0 or tx >= Iso.COLS or ty >= Iso.ROWS:
				continue
			out.append(index_of(tx, ty))
	return out


## The tile a world point falls on, or -1 if it is off the field.
func tile_at(where: Vector2) -> int:
	var tile := Iso.world_to_tile(where)
	var tx := int(floor(tile.x))
	var ty := int(floor(tile.y))
	if tx < 0 or ty < 0 or tx >= Iso.COLS or ty >= Iso.ROWS:
		return -1
	return index_of(tx, ty)


## Fill the basin, once, from a fixed seed. Same seed, same lake, every run.
##
## A tile's stack is as deep as the water under it, and its depth still points a slot at a
## rough weight class — heavier towards the floor, lighter towards the surface — but no
## longer at one piece off one sorted line. That line was a schedule: clear the surface and
## what came up next was always the next entry down it, so a run of skimming told you
## exactly what tier was coming before you got there. See `_roll_piece` for what replaced
## it and `MATERIAL_QUOTA`/`FILL_BAND`/`FILL_BAIT_CHANCE` for the numbers it turns on.
##
## Lay the field out.
##
## `fill` says whether to put anything in it. A lake with nothing floating on it is a real
## thing to want — the second level's water carries only what its yards make, and a basin
## seeded with muck it can never sell would be eight thousand tiles of scenery the player
## is invited to fish out of a fight.
func build(from_defs: Array[TrashDef], lake_seed: int, fill: bool = true) -> void:
	defs = from_defs
	if sheets != null:
		_white_uv = sheets.uv_of(sheets.white)
	_rng.seed = lake_seed

	var count := Iso.COLS * Iso.ROWS
	stacks.clear()
	stacks.resize(count)
	tilt.resize(count)
	nudge.resize(count)
	swing.resize(count)
	facing.resize(count)
	emerge.resize(count)

	# The one-off finds are not part of the fill. They are planted afterwards, one of each,
	# and a fill that dealt them out would put a wardrobe on every third tile.
	_by_material = [[], [], [], []]
	var lightest := INF
	var heaviest := -INF
	for i in defs.size():
		if defs[i].keepsake:
			continue
		_by_material[defs[i].material].append(i)
		lightest = minf(lightest, defs[i].lightness)
		heaviest = maxf(heaviest, defs[i].lightness)
	for pool: Array in _by_material:
		pool.sort_custom(func(a: int, b: int) -> bool: return defs[a].lightness < defs[b].lightness)
	_lightness_span = Vector2(heaviest, lightest)  # x: floor end, y: surface end

	for ty in Iso.ROWS:
		for tx in Iso.COLS:
			var index := index_of(tx, ty)
			var stack := PackedInt32Array()
			emerge[index] = 0.0
			_reroll_pose(index)
			if not fill or not Iso.floats_here(tx, ty):
				stacks[index] = stack
				continue
			var slots := maxi(int(Iso.depth_at(tx, ty) * float(Iso.MAX_SLOTS)), 1)
			for k in slots:
				# 0 at the floor, 1 at the surface.
				var up := float(k) / maxf(float(slots - 1), 1.0)
				stack.append(_roll_piece(up))
			stacks[index] = stack

	_emerging.resize(0)
	_dirty = true
	queue_redraw()


## One slot's piece: a material by `MATERIAL_QUOTA`, then a weight within it by `up` and
## `FILL_BAND` — or, `FILL_BAIT_CHANCE` of the time, any weight the material has at all.
##
## Quota first, band second, deliberately not the other way round. Banding first and then
## asking which materials are actually in that band would answer "what's heavy here" before
## "how much metal does the whole lake need", and a band with only one material in it would
## silently spend that tile's quota-share regardless — plastic has nothing heavier than a
## jug, so every deep slot would starve it. Asking the quota first and then narrowing what
## it drew keeps the four yards' traffic what `MATERIAL_QUOTA` says even where a material's
## whole range sits at one end of the lake.
func _roll_piece(up: float) -> int:
	var roll := _rng.randf()
	var material := MATERIAL_QUOTA.size() - 1
	var at := 0.0
	for m in MATERIAL_QUOTA.size():
		at += MATERIAL_QUOTA[m]
		if roll < at and not _by_material[m].is_empty():
			material = m
			break
	var pool: Array = _by_material[material]
	if pool.is_empty():
		pool = _by_material.filter(func(p: Array) -> bool: return not p.is_empty())[0]
	if _rng.randf() < FILL_BAIT_CHANCE:
		return pool[_rng.randi_range(0, pool.size() - 1)]

	# `up` runs floor (0) to surface (1); `_lightness_span` runs the same way, heaviest
	# first. A band this wide either end of the target simply clips against the pool's own
	# ends rather than wrapping, which is what keeps the deepest slots from occasionally
	# fishing up the lightest thing the material has.
	var span := _lightness_span.y - _lightness_span.x
	var target := _lightness_span.x + up * span
	var half := FILL_BAND * span * 0.5
	var lo := target - half
	var hi := target + half
	var band: Array[int] = []
	for idx: int in pool:
		if defs[idx].lightness >= lo and defs[idx].lightness <= hi:
			band.append(idx)
	if band.is_empty():
		return pool[_rng.randi_range(0, pool.size() - 1)]
	return band[_rng.randi_range(0, band.size() - 1)]


## Put a saved field back. The stacks are the only part of the lake that is not implied by
## the seed — the poses under them are cosmetic and are left as the fresh build rolled
## them, because a save that remembered which way a bottle was leaning would be storing
## twice as much for nothing.
func restore(saved: Array) -> bool:
	if saved.size() != stacks.size():
		return false
	for index in saved.size():
		stacks[index] = PackedInt32Array(saved[index])
		emerge[index] = 0.0
	_emerging.resize(0)
	_dirty = true
	queue_redraw()
	return true


## How a tile's visible piece lies on the water: turned, drifted, sized and facing. One
## roll, in one place, so the fill and a piece newly uncovered pose the same way.
func _reroll_pose(index: int) -> void:
	tilt[index] = _rng.randf_range(-TURN, TURN)
	nudge[index] = Vector2(
		_rng.randf_range(-Iso.TILE_W * DRIFT, Iso.TILE_W * DRIFT),
		_rng.randf_range(-Iso.TILE_H * DRIFT, Iso.TILE_H * DRIFT)
	)
	swing[index] = _rng.randf_range(1.0 - SIZE_SPREAD, 1.0 + SIZE_SPREAD)
	facing[index] = 1 if _rng.randf() < 0.5 else 0


func tile_count() -> int:
	return stacks.size()


func height_of(index: int) -> int:
	return stacks[index].size()


## The top of the stack on this tile, or -1 if it has been cleared.
func top_slot(index: int) -> int:
	return stacks[index].size() - 1


## The highest slot that can actually be taken: within `depth` slots of the top, and of a
## tier the tool can lift. -1 when there is nothing there the tool can shift — which is
## what "you can see it but you cannot lift it" looks like in code.
##
## `material` narrows it to one of TrashDef.Kind; -1 takes whatever is there. The ferry's
## skimmer is the only caller that narrows: it is sweeping for the cargo it is already
## carrying to one particular yard, and hauling in a tyre on the way to the timber merchant
## would just ride around the lake unsold.
func reachable_slot(
	index: int, depth: int, max_tier: int, material: int = -1, keepsakes: bool = true
) -> int:
	var top := top_slot(index)
	var k := top
	while k >= 0 and k > top - depth:
		var def := defs[stacks[index][k]]
		# A find is the net's to make. A boat quietly hoovering the collection up on its
		# way past would be the game playing itself.
		var allowed := keepsakes or not def.keepsake
		if allowed and def.tier <= max_tier and (material < 0 or def.material == material):
			return k
		k -= 1
	return -1


## Where a tile's piece sits before the swell is applied: the tile's surface point,
## nudged, and still rising if it was only just exposed.
##
## This is what goes into the geometry, because the bob is added by the vertex shader.
func surface_still(index: int) -> Vector2:
	var tile := tile_of(index)
	var at := Iso.tile_to_world(float(tile.x) + 0.5, float(tile.y) + 0.5) + nudge[index]
	at.y += emerge[index]
	return at


## Where a tile's floating piece actually is, bob included. What gameplay asks — where to
## put a splash, where the net found something — because the piece on screen is at the
## bobbing position even though the geometry submitted for it is not.
func surface_pos(index: int) -> Vector2:
	var at := surface_still(index)
	at.y += _swell(at.x, _time * WAVE_SPEED) * WAVE_AMPLITUDE
	return at + _sway(at.x, _time * WAVE_SPEED)


## Take a piece out. Whatever is under it becomes the tile's visible piece, and rises into
## place rather than appearing.
func take(index: int, k: int) -> int:
	var def_index := stacks[index][k]
	stacks[index].remove_at(k)
	if not stacks[index].is_empty():
		emerge[index] = EMERGE_DROP
		if not _emerging.has(index):
			_emerging.append(index)
		_reroll_pose(index)
	_restamp(index)
	return def_index


## Put a piece into a stack at a given depth, or as deep as the stack goes if it is
## shorter than that. Used to hide the one-off finds after the lake is built: they are not
## part of the depth-sorted fill, they are planted in it.
func insert(index: int, k: int, def_index: int) -> void:
	var stack := stacks[index]
	stack.insert(clampi(k, 0, stack.size()), def_index)
	stacks[index] = stack
	_restamp(index)


## How far down the nearest find is in a stack, or -1 for a stack with none near the top.
##
## Only the top GLINT_REACH slots are looked at: a find at the bottom of a full stack is
## not something the player can do anything about yet, and a lake that glitters everywhere
## says nothing. Walked from the top down, so a stack with two finds in it reports the one
## that is closer to being dug out.
func _glint_at(stack: PackedInt32Array) -> int:
	var top := stack.size() - 1
	var k := top
	while k >= 0 and k > top - 1 - GLINT_REACH:
		if defs[stack[k]].keepsake:
			return top - k
		k -= 1
	return -1


func def_at(index: int, k: int) -> TrashDef:
	return defs[stacks[index][k]]


## Total filth still in the lake. Walked rather than tracked, and only ever asked for at
## build time — lake.gd decrements its own running total as pieces are banked.
func filth_left() -> float:
	var total := 0.0
	for index in stacks.size():
		for k in stacks[index].size():
			total += defs[stacks[index][k]].pollution
	return total


func piece_count() -> int:
	var total := 0
	for index in stacks.size():
		total += stacks[index].size()
	return total


## The clock the wave terms are read at. The ripple layer needs the same one the geometry
## is rocked with, and `_time` is this object's own business.
func wave_time() -> float:
	return _time * WAVE_SPEED


static func _swell(x: float, t: float) -> float:
	return sin(x * 0.011 + t) * 0.62 + sin(x * 0.029 - t * 1.7) * 0.38


## The wander of a floating piece, in pixels off its anchor. Mirrors the vertex shader's
## `sway` term exactly: if the two drift apart, the ripple around a piece and the splash
## when it is netted stop happening where the piece is drawn.
static func _sway(x: float, t: float) -> Vector2:
	return Vector2(sin(t * 0.53 + x * 0.017), cos(t * 0.41 + x * 0.023) * 0.5) * SWAY


func _process(delta: float) -> void:
	_time += delta
	if _emerging.is_empty():
		# Nothing is moving that the GPU is not already moving on its own. This is the
		# common case in a big lake, and it costs a float add.
		return
	var step := EMERGE_SPEED * delta
	var still_rising := PackedInt32Array()
	for index: int in _emerging:
		emerge[index] = maxf(emerge[index] - step, 0.0)
		if emerge[index] > 0.0:
			still_rising.append(index)
		# A rising piece is the one thing whose geometry actually changes between frames —
		# and it is one tile's worth of it, so it rewrites its own corner of the soup
		# rather than asking for the whole lake to be laid out again.
		_restamp(index)
	_emerging = still_rising


## The visible tiles, as a range of the tile field. The cull is arithmetic: the view
## rectangle's corners are projected back into tile space and the box around them is what
## gets walked, so an empty screen costs nothing to skip.
func _visible_tile_box() -> Rect2i:
	var pad := Vector2(Iso.TILE_W, Iso.TILE_H * 4.0)
	var lo := view.position - pad
	var hi := view.position + view.size + pad
	# The four corners, because a screen-aligned rectangle is a diamond in tile space and
	# its extremes are corners, not edges.
	var corners := [
		Iso.world_to_tile(lo), Iso.world_to_tile(Vector2(hi.x, lo.y)),
		Iso.world_to_tile(Vector2(lo.x, hi.y)), Iso.world_to_tile(hi)
	]
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for corner: Vector2 in corners:
		min_x = minf(min_x, corner.x)
		max_x = maxf(max_x, corner.x)
		min_y = minf(min_y, corner.y)
		max_y = maxf(max_y, corner.y)

	var first_x := clampi(int(min_x) - 1, 0, Iso.COLS - 1)
	var last_x := clampi(int(max_x) + 1, 0, Iso.COLS - 1)
	var first_y := clampi(int(min_y) - 1, 0, Iso.ROWS - 1)
	var last_y := clampi(int(max_y) + 1, 0, Iso.ROWS - 1)
	return Rect2i(first_x, first_y, last_x - first_x + 1, last_y - first_y + 1)


## Only the surface layer, in one draw call.
##
## Everything visible goes into a single triangle array rather than a few commands per
## piece. That is the whole performance story of this file: at four thousand visible
## pieces the old path issued twenty thousand canvas commands a frame, and this issues
## one. The soup is rebuilt only when the view moves, a piece is taken, or something is
## still rising — the bob that used to force a rebuild every frame is a vertex shader now.
func _draw() -> void:
	if stacks.is_empty():
		return
	if _dirty:
		_rebuild()
	if _mesh_indices.is_empty():
		return
	# One texture for the whole surface, which is why the art had to go into one atlas: a
	# triangle array carries exactly one, and a second would be a second draw call.
	RenderingServer.canvas_item_add_triangle_array(
		get_canvas_item(), _mesh_indices, _mesh_points, _mesh_colors, _mesh_uvs,
		PackedInt32Array(), PackedFloat32Array(), atlas_rid()
	)


func atlas_rid() -> RID:
	return sheets.atlas.get_rid() if sheets != null and sheets.atlas != null else RID()


## Walk the visible tiles and lay their top pieces out as triangles.
##
## Pieces with a real sprite cannot join the soup — one triangle array carries one texture
## — so they are handed to the fallback layer instead. Nothing has a sprite yet, and this
## is what keeps that true without becoming a trap when the generated art lands.
func _rebuild() -> void:
	_dirty = false
	_write_at = -1
	rebuilds += 1
	var began := Time.get_ticks_usec()
	_fill = 0
	_tri = 0
	if _slot_base.size() != stacks.size():
		_slot_base.resize(stacks.size())
		_slot_len.resize(stacks.size())
		_shadow_at.resize(stacks.size())
	_slot_base.fill(-1)
	_slot_len.fill(0)
	_shadow_at.fill(-1)
	drawn_pieces = 0
	var textured: Array[int] = []
	var afloat := PackedInt32Array()
	var glinting: Array[Vector2i] = []
	_shadows.begin()

	var pad := Vector2(Iso.TILE_W, Iso.TILE_H * 4.0)
	var lo := view.position - pad
	var hi := view.position + view.size + pad
	var box := _visible_tile_box()

	# Room for the worst the walk below could ask for, taken in one go. The walk then
	# writes by index and the arrays are cut back to what was actually used, so a rebuild
	# costs two resizes rather than one allocation per piece.
	_reserve(box.size.x * box.size.y * PIECE_VERTS)

	# Row by row, near-tile last: tile-confined pieces come out in painter's order, and a
	# triangle array keeps the order it was given.
	for ty in range(box.position.y, box.position.y + box.size.y):
		for tx in range(box.position.x, box.position.x + box.size.x):
			var index := index_of(tx, ty)
			var stack := stacks[index]
			if stack.is_empty():
				continue
			var at := surface_still(index)
			if at.x < lo.x or at.x > hi.x or at.y < lo.y or at.y > hi.y:
				continue
			afloat.append(index)
			var glint := _glint_at(stack)
			if glint >= 0:
				glinting.append(Vector2i(index, glint))
			var def := defs[stack[stack.size() - 1]]
			_shadow_at[index] = _shadows.add(at, def.size, swing[index])
			if def.sprite != null:
				textured.append(index)
				continue
			var base := _fill
			_stamp(def, at, index)
			_slot_base[index] = base
			_slot_len[index] = _fill - base
			drawn_pieces += 1

	# Down to what was used. What is submitted has to be exactly the geometry that was
	# laid down — the tail of the reservation is uninitialised, and drawing it would be a
	# spray of triangles through the origin.
	_mesh_points.resize(_fill)
	_mesh_uvs.resize(_fill)
	_mesh_colors.resize(_fill)
	_mesh_indices.resize(_tri)

	_sprites.set_pieces(textured)
	_glints.set_finds(glinting)
	_shadows.finish()
	_ripples.set_pieces(_spread_over(afloat, RIPPLE_MOST))
	walked = box.size.x * box.size.y
	rebuild_ms = float(Time.get_ticks_usec() - began) / 1000.0


## Room for `verts` vertices in the soup, and the indices that many needs. Grown only —
## the arrays are cut back to the used length at the end of every rebuild, so this is
## where they get their size back.
func _reserve(verts: int) -> void:
	_mesh_points.resize(verts)
	_mesh_uvs.resize(verts)
	_mesh_colors.resize(verts)
	_mesh_indices.resize(verts / 4 * 6)


## A bounded sample of a list, taken evenly across it rather than off the front. Off the
## front would put every ring in one corner of the screen, which is worse than none: what
## is wanted is rubbish sitting in water everywhere the eye lands.
func _spread_over(list: PackedInt32Array, most: int) -> PackedInt32Array:
	if list.size() <= most:
		return list
	var out := PackedInt32Array()
	var stride := float(list.size()) / float(most)
	for i in most:
		out.append(list[int(float(i) * stride)])
	return out


## One piece, as triangles. Mirrors TrashDef.stamp_iso — the same footprint, body and top
## face — with the stroked outline traded for a slightly larger quad behind the body,
## which reads the same at every zoom this game is played at and costs two triangles
## instead of eight.
##
## The anchor goes into every vertex's UV, which is what the bob shader reads. It is not a
## texture coordinate and nothing samples it.
## Rewrite one tile's vertices where they already sit, instead of laying the whole soup
## out again.
##
## The two things that change during play — a piece taken, and the piece under it rising
## into place — touch one tile each and leave every other piece exactly where it was. A
## full rebuild for either of those was re-stamping a few thousand pieces to move one, and
## that is what the net's cast and drag were hitching on.
##
## Falls back to a full rebuild whenever the tile's new contents will not fit the space
## the old ones were given: a different vertex count means the whole soup after this tile
## shifts, and shifting it is a rebuild by another name.
func _restamp(index: int) -> void:
	# A rebuild is already coming this frame; it will draw the new state anyway.
	if _dirty:
		return
	if index < 0 or index >= _slot_base.size():
		return
	queue_redraw()

	var stack: PackedInt32Array = stacks[index]
	var base := _slot_base[index]
	if base < 0:
		# Not in the soup: culled, or drawn by the sprite layer. Nothing to patch, and if
		# it now has something to show it needs room made for it.
		if not stack.is_empty():
			_dirty = true
			from_patch += 1
		return

	var span := _slot_len[index]
	if stack.is_empty():
		_blank_slot(base, span)
		_shadows.blank(_shadow_at[index])
		_shadows.queue_redraw()
		_slot_base[index] = -1
		_slot_len[index] = 0
		_shadow_at[index] = -1
		drawn_pieces -= 1
		return

	var def := defs[stack[stack.size() - 1]]
	if def.sprite != null or _stamp_len(def) != span:
		_dirty = true
		from_patch += 1
		return

	var at := surface_still(index)
	_write_at = base
	_stamp(def, at, index)
	_write_at = -1

	# The shadow moves with the piece. A rising piece whose shadow stayed put would look
	# like it had come off its own footing.
	if _shadows.write(_shadow_at[index], at, def.size, swing[index]):
		_shadows.queue_redraw()


## How many vertices `_stamp` will lay down for a piece. Mirrors the branches in `_stamp`
## — if a shape is added there, its corners have to be counted here or a patch will write
## past the space the tile was given.
func _stamp_len(def: TrashDef) -> int:
	if def.atlas != null:
		return 4
	return 16 if _detailed else 8


## Collapse a tile's vertices to a point, so its triangles have no area and nothing is
## rasterised. Cheaper and safer than cutting them out of the arrays, which would shift
## every index after them.
func _blank_slot(base: int, span: int) -> void:
	for i in span:
		_mesh_points[base + i] = Vector2.ZERO
		_mesh_colors[base + i] = Color(0.0, 0.0, 0.0, 0.0)


func _stamp(def: TrashDef, at: Vector2, index: int) -> void:
	var lean := tilt[index]
	if def.atlas != null:
		# The art is the whole of the piece. There is no plate of pale water under it any
		# more: at the size these are drawn it read as a grey square behind every single
		# thing in the lake, which is worse than no ripple at all.
		_sprite(
			at, def.size * swing[index], lean, sheets.uv_of(def.region),
			facing[index] == 1
		)
		return

	# No art loaded. The old blocked-in placeholder, in grey: the vertex colour is carrying
	# the piece's anchor now, and only its brightness survives.
	var body := Vector2(def.size.x, def.size.y * 0.72)
	if _detailed:
		var span := def.size.x * 1.15
		var foot := at + Vector2(0.0, def.size.y * 0.30)
		_quad(
			foot + Vector2(0.0, -span * 0.25), foot + Vector2(span * 0.5, 0.0),
			foot + Vector2(0.0, span * 0.25), foot + Vector2(-span * 0.5, 0.0),
			1.0, 0.14, at, _white_uv
		)
	if _detailed:
		_rect(at, body + Vector2(3.2, 3.2), lean, 0.1, 1.0, at)
	_rect(at, body, lean, def.block_color.get_luminance(), 1.0, at)
	_rect(
		at - Vector2(0.0, body.y * 0.325).rotated(lean),
		Vector2(body.x, body.y * 0.35), lean,
		minf(def.block_color.get_luminance() + 0.18, 1.0), 1.0, at
	)


## One piece of art, as a leaning quad with its atlas region mapped onto it. Mirrored by
## running the texture across it the other way, which costs nothing and doubles how many
## different things a field of the same picture looks like.
func _sprite(at: Vector2, size: Vector2, lean: float, uv: Rect2, mirrored: bool) -> void:
	var half := size * 0.5
	var box := uv
	if mirrored:
		box = Rect2(uv.position + Vector2(uv.size.x, 0.0), Vector2(-uv.size.x, uv.size.y))
	_quad(
		at + Vector2(-half.x, -half.y).rotated(lean), at + Vector2(half.x, -half.y).rotated(lean),
		at + Vector2(half.x, half.y).rotated(lean), at + Vector2(-half.x, half.y).rotated(lean),
		1.0, 1.0, at, box
	)


## An axis-aligned rectangle centred on a point, leaned by `lean`, in a flat grey.
func _rect(
	at: Vector2, size: Vector2, lean: float, grey: float, alpha: float, anchor: Vector2
) -> void:
	var half := size * 0.5
	_quad(
		at + Vector2(-half.x, -half.y).rotated(lean), at + Vector2(half.x, -half.y).rotated(lean),
		at + Vector2(half.x, half.y).rotated(lean), at + Vector2(-half.x, half.y).rotated(lean),
		grey, alpha, anchor, _white_uv
	)


## Four corners, wound as two triangles, appended to the soup.
##
## The vertex colour is not a colour here. Red and green carry the piece's anchor, packed
## as one sixteen-bit number, because the bob shader needs a per-piece position and UV is a
## real texture coordinate now that the lake is drawn from an atlas. Blue carries the grey
## the piece should end up and alpha its alpha, and rubbish.gdshader puts the two back
## together before anything downstream sees them.
func _quad(
	a: Vector2, b: Vector2, c: Vector2, d: Vector2, grey: float, alpha: float,
	anchor: Vector2, uv: Rect2
) -> void:
	var packed := pack_anchor(anchor.x, grey, alpha)
	# Where this quad goes: over one tile's own vertices when patching, on the end of what
	# the rebuild has laid down so far otherwise. Written element by element rather than
	# through a temporary array, because a temporary here is one heap allocation per piece
	# per rebuild and there are thousands of pieces.
	var base := _write_at if _write_at >= 0 else _fill

	_mesh_points[base] = a
	_mesh_points[base + 1] = b
	_mesh_points[base + 2] = c
	_mesh_points[base + 3] = d

	_mesh_uvs[base] = uv.position
	_mesh_uvs[base + 1] = uv.position + Vector2(uv.size.x, 0.0)
	_mesh_uvs[base + 2] = uv.position + uv.size
	_mesh_uvs[base + 3] = uv.position + Vector2(0.0, uv.size.y)

	for i in 4:
		_mesh_colors[base + i] = packed

	# Patching one tile in place. The vertices it is overwriting were wound by an earlier
	# rebuild and the winding has not changed, so the indices are already right.
	if _write_at >= 0:
		_write_at += 4
		return

	_mesh_indices[_tri] = base
	_mesh_indices[_tri + 1] = base + 1
	_mesh_indices[_tri + 2] = base + 2
	_mesh_indices[_tri + 3] = base
	_mesh_indices[_tri + 4] = base + 2
	_mesh_indices[_tri + 5] = base + 3
	_fill += 4
	_tri += 6


## The anchor's x, the grey and the alpha, folded into one vertex colour. Mirrors the
## unpacking in rubbish.gdshader — the two are one format and have to move together.
static func pack_anchor(x: float, grey: float, alpha: float) -> Color:
	var unit := clampf((x + ANCHOR_SPAN * 0.5) / ANCHOR_SPAN, 0.0, 1.0)
	var whole := int(round(unit * 65535.0))
	return Color(
		float(whole >> 8) / 255.0, float(whole & 255) / 255.0,
		clampf(grey, 0.0, 1.0), clampf(alpha, 0.0, 1.0)
	)


## What the shader will make of a packed colour's x. Only the harness calls this; it is
## here so the round trip is checked against the packing rather than against a copy of it.
static func unpack_anchor_x(packed: Color) -> float:
	var high := float(round(packed.r * 255.0))
	var low := float(round(packed.g * 255.0))
	return (high * 256.0 + low) / 65535.0 * ANCHOR_SPAN - ANCHOR_SPAN * 0.5
