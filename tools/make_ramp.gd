## Cuts the painted ramp off its white sheet and traces the outline the physics
## should use.
##
##   godot --headless --script tools/make_ramp.gd
##
## Two outputs, both needed and both derived from the same alpha:
##
##   art/ramp.png            the piece, background gone, trimmed to its own edges
##   printed polygon         the outline, normalised, to paste into ramp.tres
##
## The background is removed by FLOOD FILL FROM THE EDGES, not by a colour test
## over the whole image. The ramp is pale sanded plywood and the sheet behind it
## is white; a global "near enough to white is background" test eats the lit top
## edge of the deck and punches holes through the middle of the plywood. A fill
## that can only reach pixels connected to the border cannot touch anything
## inside the drawn outline, whatever colour it is.
##
## The outline is then traced from the alpha rather than authored by hand. A ramp
## is the first piece in the game that is neither a box nor a circle, and the
## whole point of it — the truck runs UP the curved deck and off the steel lip —
## only happens if the collision follows that curve. A rectangle would make it a
## crate with a picture of a ramp on it.
extends SceneTree

const SOURCE := "res://art_source/Ramp.png"
const OUT := "res://art/ramp.png"

## How close to the sheet's own colour a pixel has to be to be flooded, as a
## per-channel distance. Generous enough to take the soft grey drop shadow with
## it, tight enough to stop at the drawn outline.
const KEY_TOLERANCE := 0.16
## Pixels at the edge of the cut are part sheet, part piece. Anything below this
## alpha is thrown away outright and the rest is pushed back to opaque, so the
## piece does not carry a pale halo of the sheet it was cut from.
const EDGE_CUT := 0.45

## How hard the traced outline is simplified, in pixels. The trace follows every
## step of the alpha staircase; left raw that is a polygon of several thousand
## points, which is both a waste and worse physics than a clean edge. High enough
## to swallow the staircase, low enough to keep the curve of the deck.
## Kept low on purpose. The deck is CONCAVE, so every chord the simplifier draws
## across it sits above the painted wood — and a truck driving on the collision
## rather than on the picture climbs an invisible ramp floating over the real
## one. Cutting the corner is cheap on a straight edge and a visible lie on this
## curve, so the curve gets the points it needs.
## Lowered again for the entrance. At 2.0 the simplifier was straightening the
## thin end of the steel coping into a blunt wedge, and a truck arriving at the
## low end of the ramp met a step rather than a lip — the one edge on this piece
## that has to be exact, since driving up it is what the piece is for.
const TRACE_EPSILON := 0.8
## Points to aim for in the final outline. The simplifier is re-run at a coarser
## epsilon until it fits — a convex decomposition of a 200-point outline is a lot
## of shapes for one piece of junk.
const MAX_POINTS := 120
## Points within this many pixels of the lowest one are pulled down onto a single
## flat line.
##
## The painted base is not straight — it has a soft outline, a few pixels of
## shadow and a ragged edge — and traced literally it becomes a row of steps a
## few pixels high. That is a ramp that rocks on its own base, catches its
## neighbours on the ledges, and turns into a dozen extra convex parts. The base
## of a ramp is flat; this says so.
const BASE_SNAP := 10.0
## Points whose removal moves the outline less than this are dropped. Run after
## the base is flattened, which creates long straight runs of points that were
## individually necessary before it.
const COLLINEAR := 1.2
## Where the traced outline is drawn back over the artwork to be looked at. The
## polygon is the one thing here with no way to check itself: a bad number in it
## is not a crash, it is a truck that drives through the deck.
const PREVIEW := "res://art/_preview/ramp_outline.png"


func _initialize() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if image == null:
		print("missing: %s" % SOURCE)
		quit()
		return
	image.convert(Image.FORMAT_RGBA8)

	_key_out_background(image)
	var bounds := image.get_used_rect()
	if bounds.size == Vector2i.ZERO:
		print("nothing left after keying — tolerance too high")
		quit()
		return

	var piece := image.get_region(bounds)
	piece.save_png(ProjectSettings.globalize_path(OUT))

	var outline := _trace(piece)
	_save_preview(piece, outline)
	print("%s  %dx%d  (trimmed from %dx%d)" % [
		OUT, piece.get_width(), piece.get_height(),
		image.get_width(), image.get_height()
	])
	print("outline points: %d" % outline.size())
	print(_as_resource_line(outline, piece.get_width(), piece.get_height()))
	quit()


## Flood the sheet away from the border inwards, leaving anything enclosed by the
## drawing alone.
func _key_out_background(image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	# The sheet's colour, taken from a corner rather than assumed to be pure
	# white — these are painted plates and the paper is rarely exactly 1,1,1.
	var sheet := image.get_pixel(0, 0)

	var seen := PackedByteArray()
	seen.resize(width * height)
	var queue: Array[Vector2i] = []

	for x in width:
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, height - 1))
	for y in height:
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(width - 1, y))

	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		if at.x < 0 or at.y < 0 or at.x >= width or at.y >= height:
			continue
		var index := at.y * width + at.x
		if seen[index] == 1:
			continue
		seen[index] = 1
		var pixel := image.get_pixel(at.x, at.y)
		if not _is_sheet(pixel, sheet):
			continue
		image.set_pixel(at.x, at.y, Color(pixel.r, pixel.g, pixel.b, 0.0))
		queue.append(Vector2i(at.x + 1, at.y))
		queue.append(Vector2i(at.x - 1, at.y))
		queue.append(Vector2i(at.x, at.y + 1))
		queue.append(Vector2i(at.x, at.y - 1))

	# Harden the cut edge. Partly-keyed pixels are half sheet by definition, and
	# left as they are they ring the piece in white where it meets the water.
	for y in height:
		for x in width:
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			if pixel.a < EDGE_CUT:
				image.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b, 0.0))
			elif pixel.a < 1.0:
				image.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b, 1.0))


## Is this pixel the sheet, or the soft grey shadow the piece casts on it?
func _is_sheet(pixel: Color, sheet: Color) -> bool:
	if absf(pixel.r - sheet.r) < KEY_TOLERANCE \
			and absf(pixel.g - sheet.g) < KEY_TOLERANCE \
			and absf(pixel.b - sheet.b) < KEY_TOLERANCE:
		return true
	# The drop shadow is grey: bright, and with no colour in it. The plywood is
	# just as bright but distinctly warm, so saturation is what separates them.
	var value: float = maxf(pixel.r, maxf(pixel.g, pixel.b))
	var chroma: float = value - minf(pixel.r, minf(pixel.g, pixel.b))
	return value > 0.72 and chroma < 0.045


## The piece's outline, in pixels, largest island only.
func _trace(piece: Image) -> PackedVector2Array:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(piece, 0.5)
	var rect := Rect2i(0, 0, piece.get_width(), piece.get_height())

	var epsilon := TRACE_EPSILON
	var best := PackedVector2Array()
	# Coarsen until the outline is a workable number of points. Simplification is
	# cheap and the alternative is guessing one epsilon that happens to suit.
	for attempt in 8:
		var polygons := bitmap.opaque_to_polygons(rect, epsilon)
		best = PackedVector2Array()
		for polygon: PackedVector2Array in polygons:
			if _area(polygon) > _area(best):
				best = polygon
		if best.size() <= MAX_POINTS:
			break
		epsilon *= 1.6
	return _drop_collinear(_flatten_base(best))


## Pulls everything close to the lowest point onto one flat line.
func _flatten_base(polygon: PackedVector2Array) -> PackedVector2Array:
	var bottom := -INF
	for point: Vector2 in polygon:
		bottom = maxf(bottom, point.y)
	var out := PackedVector2Array()
	for point: Vector2 in polygon:
		out.append(Vector2(point.x, bottom) if point.y > bottom - BASE_SNAP else point)
	return out


## Thins out the flat base, and only the flat base.
##
## A point is dropped when both its neighbours are on the base line with it —
## everything between the two ends of the base is redundant once it is straight.
## Nothing else is touched, deliberately: a general "drop the nearly collinear
## point" pass looks equivalent and is not. On a smooth curve every point is
## nearly collinear with its immediate neighbours, so the pass deletes the whole
## curve one point at a time and the deck comes back as two straight lines. That
## is exactly what happened — 78 points went to 8, and the ramp lost its ramp.
func _drop_collinear(polygon: PackedVector2Array) -> PackedVector2Array:
	if polygon.size() < 4:
		return polygon
	var bottom := -INF
	for point: Vector2 in polygon:
		bottom = maxf(bottom, point.y)

	var out := PackedVector2Array()
	for i in polygon.size():
		var previous := polygon[(i - 1 + polygon.size()) % polygon.size()]
		var current := polygon[i]
		var next := polygon[(i + 1) % polygon.size()]
		var on_base := func(p: Vector2) -> bool: return p.y >= bottom - COLLINEAR
		if on_base.call(current) and on_base.call(previous) and on_base.call(next):
			continue
		if not out.is_empty() and current.distance_to(out[out.size() - 1]) < 0.5:
			continue
		out.append(current)
	return out


## The outline drawn over the artwork on a flat background, so the trace can be
## eyeballed against the wood it is supposed to follow.
func _save_preview(piece: Image, polygon: PackedVector2Array) -> void:
	var out := Image.create(piece.get_width(), piece.get_height(), false,
		Image.FORMAT_RGBA8)
	out.fill(Color(0.13, 0.14, 0.17))
	# Alpha-aware, or the transparent margin paints a black rectangle over the
	# background and the silhouette cannot be judged.
	out.blend_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i.ZERO)
	for i in polygon.size():
		_line(out, polygon[i], polygon[(i + 1) % polygon.size()],
			Color(1.0, 0.25, 0.35))
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(PREVIEW).get_base_dir())
	out.save_png(ProjectSettings.globalize_path(PREVIEW))


func _line(image: Image, from: Vector2, to: Vector2, color: Color) -> void:
	var steps := int(maxf(absf(to.x - from.x), absf(to.y - from.y))) + 1
	for i in steps + 1:
		var at := from.lerp(to, float(i) / float(steps))
		# Two pixels wide, or the line disappears against the outline already
		# drawn on the artwork.
		for offset: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1)]:
			var x := int(at.x) + offset.x
			var y := int(at.y) + offset.y
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)


func _area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var total := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5


## The outline as it goes in the .tres: centred on the piece and scaled to a unit
## box, so the def's `size` alone decides how big the ramp is in the world and
## the outline does not have to be retraced to change it.
func _as_resource_line(polygon: PackedVector2Array, width: int, height: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for point in polygon:
		parts.append("%.4f, %.4f" % [
			point.x / float(width) - 0.5,
			point.y / float(height) - 0.5,
		])
	return "polygon = PackedVector2Array(%s)" % ", ".join(parts)
