## Shadows cast by the sun, for everything that draws itself with a sprite.
##
## There is no engine lighting here and there are no shadow nodes. A shadow is the caster's
## own frame, drawn a second time under a transform that lays it out on the ground, in flat
## ink: `draw_texture_rect_region` multiplies by the colour it is given, so a modulate of
## black with an alpha is the sprite's silhouette and nothing else. That means the same
## `stamp` call every caster already makes draws its own shadow, correct to the frame it is
## on, without a second copy of the art or a polygon anybody has to author.
##
## The old shadows were ellipses: a dark patch that sat under a walking figure without ever
## being the shape of it. This is the replacement.
class_name Shade
extends RefCounted

## The colour a shadow is drawn in before the day's own ink is applied. Not pure black —
## a shadow on grass in daylight is a darker, bluer grass, and black over a bright lake
## reads as a hole in it.
const INK := Color(0.04, 0.06, 0.09, 1.0)


## The transform that lays a sprite down on the ground, about the point it stands on.
##
## The sprite's own upright axis is mapped to a direction going away from the caster: over
## by `lean` per unit of height, and flattened by `stretch`. Because that axis is flipped in
## the process, the picture lies head-away-from-feet, which is what a cast shadow does.
##
## `at` is the caster's contact point in its own drawing space, so a caller stamps at
## Vector2.ZERO inside this and gets its shadow where its feet are.
static func lying(at: Vector2, lean: float, stretch: float) -> Transform2D:
	return Transform2D(
		Vector2(1.0, 0.0), Vector2(-lean, -maxf(stretch, 0.02) * 0.5), at
	)


## The ink a shadow is drawn in, at the strength the day says.
static func tint(ink: float) -> Color:
	return Color(INK.r, INK.g, INK.b, clampf(ink, 0.0, 1.0))


## How far the sun has to move before a swept shadow is rebuilt. The sweep is geometry, not a
## transform, so it costs something to lay out; this is the same bargain `Ground._sun_baked`
## strikes with the props' shadows.
const SWEEP_STEP := 0.02


## The silhouette dragged along the sun, as triangles.
##
## Not a shear. `lying` maps every pixel sideways in proportion to its height, which is right
## for a billboard standing on a flat edge — a figure, whose feet are a straight line — and
## comes apart on a front-on painting of a solid. The hut and the recycle box end in the near
## corner of the diamond their walls stand on, a V, so under a shear exactly one pixel of the
## picture touches the anchor and every other column's shadow starts below its own base. What
## that draws is a slab of shade lying on the grass a little way off the building, which is
## the bug this replaces. Moving the anchor cannot fix it: no single horizontal line is the
## contact line of a V.
##
## A sweep is what a solid actually casts. The ground a box hides from the sun is its
## footprint smeared along the light, and that region touches the box's own base everywhere
## by construction — there is nowhere for a gap to open. Here the *silhouette* stands in for
## the footprint, since a front-on painting is all the depth there is, so the shadow comes out
## the shape of the picture rather than of the floor plan. On a thatched hut that reads: the
## eaves are the widest part of it and the ground round a hut is shaded by its roof.
##
## **Only the columns that reach the ground cast.** An overhang is up in the air, and this has
## no idea there is a wall under it: dragged with the rest, the hut's right-hand eaves threw
## shade straight down onto open grass beside the wall — on the lit side of the building,
## where the sun is. A real eave shades the wall below it, not the ground out to the side. So a
## column casts only if its lowest opaque pixel is within `ground` of the picture's deepest
## row, which is the same rule `Skirt.hem` uses to decide where a blade of grass may stand and
## is there for the same reason. The columns that do cast carry their whole height, roof
## included, so the shadow is still as tall as the building — it is only as *wide* as what
## stands on the ground.
##
## `box` is where the picture is drawn, in the caster's own space. `ground` is how much of the
## picture's height is below the walls' ground line: it measures the drag off what actually
## stands up, and doubles as the band above the deepest row that counts as touching down.
##
## Per column, and per opaque run within it, so a gap in the art is a gap in the shadow. The
## swept region of one run is the convex hull of its corners and those corners moved along the
## drag — six points, fanned into four triangles.
static func sweep(
	art: Image, box: Rect2, lean: float, stretch: float, ground: float
) -> PackedVector2Array:
	var out := PackedVector2Array()
	if art == null or art.is_empty() or box.size.x <= 0.0 or box.size.y <= 0.0:
		return out
	var wide := art.get_width()
	var tall := art.get_height()
	if wide <= 0 or tall <= 0:
		return out
	var step := Vector2(box.size.x / float(wide), box.size.y / float(tall))
	# What stands up, and so how far its shadow is dragged. The same two numbers `lying` uses,
	# against the object's height instead of against each pixel's own.
	var rise := box.size.y * clampf(1.0 - ground, 0.0, 1.0)
	var drag := Vector2(lean, maxf(stretch, 0.02) * 0.5) * rise
	if drag.is_zero_approx():
		return out

	# Where each column ends, and the deepest of them: the row the picture stands on.
	var foot := PackedInt32Array()
	foot.resize(wide)
	var deepest := -1
	for col in wide:
		foot[col] = -1
		for row in range(tall - 1, -1, -1):
			if art.get_pixel(col, row).a > 0.5:
				foot[col] = row
				deepest = maxi(deepest, row)
				break
	if deepest < 0:
		return out
	# How far above that a column may end and still be counted as standing on the ground.
	# Anything ending higher is an overhang, and an overhang casts onto what is under it.
	var band := maxf(float(tall) * clampf(ground, 0.0, 1.0), 1.0)

	for col in wide:
		if foot[col] < 0 or float(deepest - foot[col]) > band:
			continue
		var run := -1
		for row in tall + 1:
			var solid := row < tall and art.get_pixel(col, row).a > 0.5
			if solid and run < 0:
				run = row
			elif not solid and run >= 0:
				_smear(
					out,
					Rect2(
						box.position + Vector2(float(col) * step.x, float(run) * step.y),
						Vector2(step.x, float(row - run) * step.y)
					),
					drag
				)
				run = -1
	return out


## One run of solid pixels, swept. The hull of the run's own corners and the same four moved
## along the drag: a hexagon when the drag has both a sideways and a downward half, which it
## always does. Fanned from its first point, which is sound because the hull is convex.
static func _smear(into: PackedVector2Array, cell: Rect2, drag: Vector2) -> void:
	var corners := PackedVector2Array([
		cell.position,
		cell.position + Vector2(cell.size.x, 0.0),
		cell.position + cell.size,
		cell.position + Vector2(0.0, cell.size.y),
	])
	var both := corners.duplicate()
	for point in corners:
		both.append(point + drag)
	var hull := Geometry2D.convex_hull(both)
	# `convex_hull` closes the ring by repeating the first point; the fan must not.
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)
	for i in range(1, hull.size() - 1):
		into.append(hull[0])
		into.append(hull[i])
		into.append(hull[i + 1])


## A swept shadow as a node, so the overlaps inside it are composited once instead of stacking.
##
## Every column's smear overlaps its neighbours' — they are parallel and a pixel apart — and a
## few hundred translucent triangles laid over each other come out as a black core with a pale
## fringe. A `CanvasGroup` draws its children into a buffer first and then draws that buffer
## once under its own `self_modulate`, so the shadow is one flat ink whatever it overlaps.
## `self_modulate` rather than `modulate`, which would reach the child and put the stacking
## back.
##
## Behind its parent's own drawing, so the caster covers the half of the sweep that is under
## it, and still at the parent's z, so it lies over the ground rather than under it.
class Cast extends CanvasGroup:
	var _face: Face
	var _lean := INF
	var _stretch := INF
	var _key := ""

	func _init() -> void:
		show_behind_parent = true
		_face = Face.new()
		add_child(_face)

	## The shadow for this picture at this hour. Cheap to call every frame: the geometry is
	## only rebuilt when the sun has actually moved, or when the picture or its box changes.
	func lay(
		art: Image, box: Rect2, lean: float, stretch: float, ground: float, ink: float
	) -> void:
		self_modulate = Shade.tint(ink)
		var key := "%s|%.2f" % [box, ground]
		if key == _key 				and absf(lean - _lean) < Shade.SWEEP_STEP 				and absf(stretch - _stretch) < Shade.SWEEP_STEP:
			return
		_key = key
		_lean = lean
		_stretch = stretch
		_face.points = Shade.sweep(art, box, lean, stretch, ground)
		_face.queue_redraw()


## The triangles themselves. One `canvas_item_add_triangle_array`, the same batching the
## ground's props and the shed's grass use — a loop of `draw_colored_polygon` at this count is
## the cost that put the forest at 15 ms.
class Face extends Node2D:
	var points := PackedVector2Array()

	var _order := PackedInt32Array()
	var _ink := PackedColorArray()

	func _draw() -> void:
		if points.is_empty():
			return
		# White, and flat: the colour is the group's, applied once over the whole buffer.
		if _order.size() != points.size():
			_order.resize(points.size())
			_ink.resize(points.size())
			for i in points.size():
				_order[i] = i
				_ink[i] = Color.WHITE
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(), _order, points, _ink
		)
