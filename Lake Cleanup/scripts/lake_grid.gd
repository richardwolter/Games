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
## surface like a sticker on glass. It is a ring rather than a plate under the art: a filled
## shape at this size reads as a grey box behind everything, which is what the plate under
## each piece used to look like before it was taken out.
const RIPPLE_SPAN := 1.15
const RIPPLE_BREATH := 0.16
const RIPPLE_TIME := 2.6
const RIPPLE_ALPHA := 0.16

## Most rings drawn at once. The rest of the lake goes without: past a hundred or so the
## water is a mass of them and the cost is real, so the ones near the middle of the view
## carry the effect for everybody.
const RIPPLE_MOST := 140

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

## The triangle soup every visible piece lives in. Rebuilt only when something that is not
## the bob has changed.
var _mesh_points := PackedVector2Array()
var _mesh_uvs := PackedVector2Array()
var _mesh_colors := PackedColorArray()
var _mesh_indices := PackedInt32Array()
var _dirty: bool = true

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


## The rings of disturbed water round the floating rubbish.
##
## Its own layer, under the junk, because it is the one thing about a floating piece that
## has to be redrawn every frame: the geometry of the lake is static and rocked by the
## vertex shader, and a ring that breathes cannot be. Bounded rather than complete — a lake
## of eighteen thousand rings is both unreadable and not free — so it draws a spread of what
## is on screen and lets the rest of the water carry the idea.
class RippleLayer extends Node2D:
	var grid: LakeGrid
	var pieces: PackedInt32Array = PackedInt32Array()
	var _time: float = 0.0

	func set_pieces(list: PackedInt32Array) -> void:
		pieces = list
		set_process(not pieces.is_empty())
		queue_redraw()

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		for index: int in pieces:
			var stack := grid.stacks[index]
			if stack.is_empty():
				continue
			var at := grid.surface_pos(index)
			var def := grid.defs[stack[stack.size() - 1]]
			# Off the piece's own place on the water, so no two rings breathe together —
			# in step, a field of them pulses like a warning light.
			var phase := _time * TAU / LakeGrid.RIPPLE_TIME + at.x * 0.02 + at.y * 0.013
			var breath := 1.0 + sin(phase) * LakeGrid.RIPPLE_BREATH
			var wide := def.size.x * grid.swing[index] * LakeGrid.RIPPLE_SPAN * breath
			# Flat on the plane, in the tiles own 2:1, so the ring lies in the water rather
			# than standing up in it.
			var ring := PackedVector2Array()
			for i in 13:
				var angle := TAU * float(i) / 12.0
				ring.append(at + Vector2(cos(angle) * wide * 0.5, sin(angle) * wide * 0.25))
			# Faintest at the top of the breath: a ring spreading is a ring going.
			var fade := LakeGrid.RIPPLE_ALPHA * (1.0 - sin(phase) * 0.35)
			draw_polyline(ring, Color(0.86, 0.94, 0.96, fade), 1.0)


func _ready() -> void:
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


## How coarsely the view rectangle is rounded before it counts as having moved, in world
## pixels.
##
## The camera eases toward the angler, so it is never exactly still — without this, the
## rectangle would differ by a fraction of a pixel every frame and force a rebuild every
## frame, which is the thing all of this is here to avoid. Rounding to a couple of tiles
## and padding by the same amount means the view only counts as moved once it has really
## moved, and the extra margin is already inside the cull.
const VIEW_SNAP := 128.0


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
	queue_redraw()


## Whether pieces are drawn with their footprint and outline. lake.gd sets this from the
## camera: below a certain zoom both are smaller than a pixel, and skipping them halves
## the geometry for no visible difference.
func set_detailed(on: bool) -> void:
	if on == _detailed:
		return
	_detailed = on
	_dirty = true
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
## A tile's stack is as deep as the water under it, and the kinds are chosen by depth from
## a list sorted by lightness: light rubbish on top, heavy tiers underneath. That order is
## what makes the progression legible — you clear the surface layer, and what you find
## beneath it is the tier you cannot lift yet.
func build(from_defs: Array[TrashDef], lake_seed: int) -> void:
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
	var lightest_first: Array[int] = []
	for i in defs.size():
		if defs[i].keepsake:
			continue
		lightest_first.append(i)
	lightest_first.sort_custom(
		func(a: int, b: int) -> bool: return defs[a].lightness > defs[b].lightness
	)

	for ty in Iso.ROWS:
		for tx in Iso.COLS:
			var index := index_of(tx, ty)
			var stack := PackedInt32Array()
			emerge[index] = 0.0
			_reroll_pose(index)
			if not Iso.in_lake(tx, ty):
				stacks[index] = stack
				continue
			var slots := maxi(int(Iso.depth_at(tx, ty) * float(Iso.MAX_SLOTS)), 1)
			for k in slots:
				# 0 at the floor, 1 at the surface. Inverted against the list, which is
				# lightest-first, so the bottom of the stack gets the heaviest end of it.
				var up := float(k) / maxf(float(slots - 1), 1.0)
				# The jitter is wide on purpose. A tight one makes every tile at the same
				# depth show the same piece, and the lake reads as wallpaper rather than
				# as rubbish.
				var pick := int(
					(1.0 - up) * float(lightest_first.size() - 1)
					+ _rng.randf_range(-4.5, 4.5)
				)
				stack.append(lightest_first[clampi(pick, 0, lightest_first.size() - 1)])
			stacks[index] = stack

	_emerging.resize(0)
	_dirty = true
	queue_redraw()


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
	_dirty = true
	queue_redraw()
	return def_index


## Put a piece into a stack at a given depth, or as deep as the stack goes if it is
## shorter than that. Used to hide the one-off finds after the lake is built: they are not
## part of the depth-sorted fill, they are planted in it.
func insert(index: int, k: int, def_index: int) -> void:
	var stack := stacks[index]
	stack.insert(clampi(k, 0, stack.size()), def_index)
	stacks[index] = stack
	_dirty = true
	queue_redraw()


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
	_emerging = still_rising
	# A rising piece is the one thing whose geometry actually changes between frames.
	_dirty = true
	queue_redraw()


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
	rebuilds += 1
	_mesh_points.resize(0)
	_mesh_uvs.resize(0)
	_mesh_colors.resize(0)
	_mesh_indices.resize(0)
	drawn_pieces = 0
	var textured: Array[int] = []
	var afloat := PackedInt32Array()

	var pad := Vector2(Iso.TILE_W, Iso.TILE_H * 4.0)
	var lo := view.position - pad
	var hi := view.position + view.size + pad
	var box := _visible_tile_box()

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
			var def := defs[stack[stack.size() - 1]]
			if def.sprite != null:
				textured.append(index)
				continue
			_stamp(def, at, index)
			drawn_pieces += 1

	_sprites.set_pieces(textured)
	_ripples.set_pieces(_spread_over(afloat, RIPPLE_MOST))


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
	var base := _mesh_points.size()
	_mesh_points.append_array(PackedVector2Array([a, b, c, d]))
	_mesh_uvs.append_array(PackedVector2Array([
		uv.position, uv.position + Vector2(uv.size.x, 0.0),
		uv.position + uv.size, uv.position + Vector2(0.0, uv.size.y)
	]))
	var packed := pack_anchor(anchor.x, grey, alpha)
	for i in 4:
		_mesh_colors.append(packed)
	_mesh_indices.append_array(
		PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3])
	)


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
