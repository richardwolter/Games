## The painted grass and sand that hide the bottom edge of a thing standing on the island.
##
## The shed and the recycle box are front-on pictures set down on a lawn, and the row of
## pixels where each one ends is a straight line no plant ever drew. This grows small tufts
## up over that line — some behind the picture, some in front of it — so the base is bitten
## into rather than cut off, and the box spills a little sand out from its foot on top.
##
## Everything here is **baked once and drawn as one triangle array**, the same bargain
## `Ground._lay_props` strikes: the island redraws every frame, and a few hundred
## `draw_rect` calls a frame is exactly the cost that put the forest at 15 ms. A skirt is
## static (no sway, by decision), so the mesh it bakes to never has to be built twice.
##
## Blades are drawn as columns of whole art pixels, not as tapered polygons: this is a
## pixel-art game, and a 3-pixel-tall blade with smooth edges is a smudge.
class_name Skirt
extends RefCounted

## One art pixel, in world pixels. The same number `Lake.ART_PIXEL` uses — every vertex is
## snapped to this grid so a blade lines up with the ground the shader draws under it.
const PX := 2.0

## How tall a blade stands, in art pixels. Deliberately short: the point is to break the
## line where the wall meets the ground, not to plant a hedge in front of the door.
const BLADE_LOW := 2
const BLADE_HIGH := 4

## How many blades a tuft has, and how far across they are spread, in art pixels.
const BLADES_LOW := 2
const BLADES_HIGH := 4
const SPREAD := 2.6

## How far a blade leans off vertical over its whole height, in art pixels. Half a pixel a
## row at most — anything more and a blade reads as a fallen twig.
const LEAN := 1.2

## How far apart the tufts stand along the bottom line, in art pixels, how often one is
## skipped, and how far up into the picture a tuft's foot is rolled.
##
## Close together and rarely skipped: the line is meant to be filled, not dotted. The gap is
## only there so the row is not a comb, and the bite is what stops the feet forming a second
## straight line under the first one.
const HEM_STEP := 0.9
const HEM_GAP := 0.05
const HEM_BITE := 2.0

## How far above the picture's deepest row a column's own lowest row may be and still be
## planted, as a fraction of the picture's height.
##
## Not everything hanging over the bottom of a sprite is near the ground: the shed's eaves
## overhang its walls, so the outermost columns of `shed.png` end at row 52 of 127 — seventy
## pixels up in the air. Grass planted on those grows out of the roof. Only the band along
## the deepest part of the silhouette is ground.
const HEM_BAND := 0.3

## The shortest a blade is ever cut down to at the far ends of the bottom line, as a share of
## its rolled height, and how sharply it is cut down on the way there.
##
## Measured against the base's **own** rise — the deepest row of the picture against the
## highest row the hem plants on — rather than against `HEM_BAND`, because those two are not
## the same shape: the crate's base rises seven rows over its whole width and the shed's
## rises thirty-three. Squared, so the cut is nearly nothing over most of the line and bites
## only at the corners; a flat taper left the shed's left wall bare.
##
## Not zero at the ends: a corner with no grass at all reads as a gap in the hem.
const HEM_SHORTEST := 0.4
const HEM_TAPER := 3.0

## The grass, if the master palette is missing. Measured off the pack's own lawn.
const GRASS_DARK := Color(0.20, 0.36, 0.18)
const GRASS_LIGHT := Color(0.38, 0.58, 0.27)

## The sand, for the same reason.
const SAND := Color(0.80, 0.72, 0.52)

## How much darker the shaded blades are than the lit ones, and how much a single blade's
## tone is allowed to wander, so a tuft is not one flat colour.
const SHADE_WANDER := 0.10


## A baked skirt: the triangles behind the thing and the triangles in front of it, each with
## its own per-vertex colours. Drawn with `draw_polygon`, which is one call per half.
## Drawn through `RenderingServer.canvas_item_add_triangle_array`, the way `Ground._lay_props`
## lays the forest, and **not** through `draw_polygon`: that one triangulates the points as a
## single outline, and a few hundred loose pixel quads handed to it is not a polygon at all —
## it fails triangulation and draws nothing.
class Patch extends RefCounted:
	var back := PackedVector2Array()
	var back_ink := PackedColorArray()
	var front := PackedVector2Array()
	var front_ink := PackedColorArray()

	var _back_order := PackedInt32Array()
	var _front_order := PackedInt32Array()

	## Draw the half that goes under the picture. Call before stamping the shed or the box.
	func behind(canvas: CanvasItem) -> void:
		if back.is_empty():
			return
		if _back_order.size() != back.size():
			_back_order = _order(back.size())
		_lay(canvas, _back_order, back, back_ink)

	## Draw the half that goes over it — the blades that hide the hard bottom edge.
	func over(canvas: CanvasItem) -> void:
		if front.is_empty():
			return
		if _front_order.size() != front.size():
			_front_order = _order(front.size())
		_lay(canvas, _front_order, front, front_ink)

	## The vertices are already in triangle order, so the index list is simply 0..n-1.
	static func _order(count: int) -> PackedInt32Array:
		var order := PackedInt32Array()
		order.resize(count)
		for i in count:
			order[i] = i
		return order

	static func _lay(
		canvas: CanvasItem,
		order: PackedInt32Array,
		points: PackedVector2Array,
		inks: PackedColorArray
	) -> void:
		RenderingServer.canvas_item_add_triangle_array(
			canvas.get_canvas_item(), order, points, inks
		)


## Grass along the bottom border of a picture: the line where the drawing stops.
##
## Not a ring round the base, by decision (2026-09-12). A ring is an ellipse on the ground
## and the thing standing on it is a front-on painting — so round the sides the blades stood
## clear of the picture's edge with lawn showing between, and the hard bottom line the grass
## is there to hide ran on uncovered. This walks the sprite's own silhouette instead: for
## every art pixel across `box`, the lowest opaque row of `image` in that column is where a
## tuft stands. The grass therefore follows the shed's diamond and the crate's V exactly,
## and fills the line rather than dotting it.
##
## Every blade is drawn **over** the picture: covering that last row is the whole job.
static func hem(
	image: Image,
	box: Rect2,
	seed_at: int,
	clear: PackedVector2Array = PackedVector2Array(),
	height := Vector2i(BLADE_LOW, BLADE_HIGH)
) -> Patch:
	var mesh := Patch.new()
	if image == null or box.size.x <= 0.0 or box.size.y <= 0.0:
		return mesh
	var greens := _greens()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_at
	var wide := image.get_width()
	var tall := image.get_height()
	# The deepest row anywhere in the picture is what "the ground" means for it; anything
	# ending well above that is overhanging, not standing.
	var deepest := -1
	for column in wide:
		deepest = maxi(deepest, _lowest(image, column, tall))
	if deepest < 0:
		return mesh
	var band := maxf(float(tall) * HEM_BAND, 1.0)
	var floor_row := deepest - int(band)
	# How far the base itself rises from its lowest point to the highest row the hem will
	# plant on. The taper is measured against this, so it means the same thing on a crate
	# and on a building.
	var rise := 1.0
	for column in wide:
		var row := _lowest(image, column, tall)
		if row >= floor_row:
			rise = maxf(rise, float(deepest - row))

	# Walked in world pixels and read back into the picture, so the spacing is the spacing on
	# screen whatever size the art happens to be drawn at.
	var step := PX * HEM_STEP
	var across := box.position.x
	while across < box.end.x:
		var share := (across - box.position.x) / box.size.x
		var column := int(share * float(wide))
		var found := _lowest(image, clampi(column, 0, wide - 1), tall)
		across += step
		if found < floor_row:
			continue
		if _inside(share, clear):
			continue
		if rng.randf() < HEM_GAP:
			continue
		# How far up the silhouette this foot stands, as a share of the band. The blades are
		# cut down by it: an edge running away from the viewer is further off than the near
		# corner is, and a full-height tuft on it stands up the side of the picture rather
		# than along its bottom. On the crate that was grass over the recycle mark.
		var lift := pow(clampf(float(deepest - found) / rise, 0.0, 1.0), HEM_TAPER)
		var short := lerpf(1.0, HEM_SHORTEST, lift)
		var foot := Vector2(
			across - step * 0.5,
			box.position.y + (float(found) + 1.0) / float(tall) * box.size.y
		)
		# Rolled a little up into the picture, so the blades bite the edge rather than
		# hanging off the bottom of it in a straight row of their own. Cut down with the
		# blades, or a one-pixel tuft on a receding edge floats clear of it.
		foot.y -= rng.randf_range(0.0, HEM_BITE) * short * PX
		_tuft(mesh, foot, greens, rng, true, short, height)
	return mesh


## Whether `share` (a fraction across the picture) falls in any of the cleared spans, each
## given as a `from`/`to` pair of the same fractions.
static func _inside(share: float, spans: PackedVector2Array) -> bool:
	for span: Vector2 in spans:
		if share >= span.x and share <= span.y:
			return true
	return false


## The lowest row of `column` with any ink in it, or -1 for an empty column.
static func _lowest(image: Image, column: int, tall: int) -> int:
	var row := tall - 1
	while row >= 0:
		if image.get_pixel(column, row).a > 0.0:
			return row
		row -= 1
	return -1


## Sand spilling out from a base standing at `at`, over an isometric patch `radius` tiles
## across. Loose grains, not a patch: single art pixels, thinning outwards, all of them in
## front of the thing they fall from.
static func spill(at: Vector2, radius: Vector2, count: int, seed_at: int) -> Patch:
	var mesh := Patch.new()
	var sand := SAND
	var palette := Palette.master()
	if palette != null:
		sand = palette.sand
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_at
	for i in count:
		var angle := rng.randf_range(0.0, TAU)
		# Square-rooted so the grains bunch at the foot and thin out, rather than ringing it.
		var reach := sqrt(rng.randf())
		var grain := at + Iso.tile_to_world(
			cos(angle) * radius.x * reach, sin(angle) * radius.y * reach
		)
		var tone := sand.lightened(rng.randf_range(0.0, 0.18))
		tone.a = 1.0 - reach * 0.35
		_pixel(mesh, grain, tone, true)
	return mesh


## Sand banked over the foot of a post standing on the beach: a low heap of art pixels
## across the post's bottom rows, widest at the ground and narrowing upwards, plus loose
## grains spilling out round it. Drawn **over** the post — covering the row where the wood
## meets the sand is the whole job, the same bargain `hem` strikes for the hut with grass.
## `at` is the post's foot in world px, `wide` the post's width on screen.
static func mound(at: Vector2, wide: float, seed_at: int) -> Patch:
	var mesh := spill(at, Vector2(0.35, 0.3), 10, seed_at)
	var sand := SAND
	var palette := Palette.master()
	if palette != null:
		sand = palette.sand
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_at + 7
	# Three rows: the ground row reaches a pixel past the wood either side, the next covers
	# the wood, the top is a few grains left on it.
	var rows := [wide + 2.0 * PX, wide, wide - 2.0 * PX]
	for row in rows.size():
		var span: float = rows[row]
		var count := maxi(int(round(span / PX)), 1)
		for i in count:
			if row == 2 and rng.randf() < 0.45:
				continue
			var x := at.x - span * 0.5 + (float(i) + 0.5) * PX
			var tone := sand.lightened(rng.randf_range(0.0, 0.14))
			if row == 0:
				tone = sand.darkened(rng.randf_range(0.0, 0.08))
			_pixel(mesh, Vector2(x, at.y - float(row) * PX), tone, true)
	return mesh


## One tuft: a few blades standing side by side out of the same spot.
static func _tuft(
	mesh: Patch,
	at: Vector2,
	greens: Array,
	rng: RandomNumberGenerator,
	front: bool,
	short: float = 1.0,
	height := Vector2i(BLADE_LOW, BLADE_HIGH)
) -> void:
	var blades := rng.randi_range(BLADES_LOW, BLADES_HIGH)
	for b in blades:
		var off := rng.randf_range(-SPREAD, SPREAD) * 0.5 * PX * short
		var tall := maxi(int(round(float(rng.randi_range(height.x, height.y)) * short)), 1)
		var lean := rng.randf_range(-LEAN, LEAN) * PX / float(maxi(tall, 1))
		var wander := rng.randf_range(-SHADE_WANDER, SHADE_WANDER)
		for row in tall:
			# The tip catches the light, the rest of the blade is in the tuft's own shade.
			var tone: Color = greens[1] if row == tall - 1 else greens[0]
			_pixel(
				mesh,
				Vector2(at.x + off + lean * float(row), at.y - float(row) * PX),
				tone.lightened(wander) if wander > 0.0 else tone.darkened(-wander),
				front
			)


## One art pixel, as the two triangles that fill it. Snapped to the art grid, so the blade
## sits on the same lattice as the ground under it.
static func _pixel(mesh: Patch, at: Vector2, ink: Color, front: bool) -> void:
	var top := Vector2(round(at.x / PX) * PX, round(at.y / PX) * PX)
	var points := mesh.front if front else mesh.back
	var inks := mesh.front_ink if front else mesh.back_ink
	var corner := [
		top, top + Vector2(PX, 0.0), top + Vector2(PX, PX), top + Vector2(0.0, PX)
	]
	for index: int in [0, 1, 2, 0, 2, 3]:
		points.append(corner[index])
		inks.append(ink)
	if front:
		mesh.front = points
		mesh.front_ink = inks
	else:
		mesh.back = points
		mesh.back_ink = inks


## The two greens a blade is drawn in: the palette's own lawn, or the pack's if the palette
## file is missing.
static func _greens() -> Array:
	var palette := Palette.master()
	if palette == null:
		return [GRASS_DARK, GRASS_LIGHT]
	return [palette.grass_dark.darkened(0.12), palette.grass_light]
