## Traces the SOLID CORE of a cut-out prop, as a polygon to paste into a .tres.
##
##   godot --headless --script tools/trace_prop.gd -- --in=art/dead_tree.png \
##       --bands=22 --min-run=26
##
## Prints the outline in unit-box coordinates — (-0.5, -0.5) is the top-left of
## the image — and writes a preview beside it so the trace can be looked at.
##
## WHY NOT THE ALPHA OUTLINE. tools/make_ramp.gd traces the silhouette, which is
## right for a ramp: it is one solid object and every part of it is meant to be
## stood on. A dead tree is mostly twigs. Tracing its silhouette gives a polygon
## of several hundred points, a convex decomposition to match, and — worse — a
## bridge piece that catches on a branch two pixels thick and hangs there. What
## the physics wants from this prop is the trunk and the rock it stands on.
##
## So the default trace is by ROW: at each height, the widest continuous run of
## opaque pixels wider than `min-run`. Twigs are narrower than the threshold and
## vanish; the trunk is not and survives. The result is a left profile and a
## right profile, which is exactly the shape of a tree seen from the side.
##
##   --mode=envelope --close=18 --epsilon=9
##
## The other mode, for when the whole thing IS the obstacle — a tree in the
## middle of the strait that pieces are meant to catch in, branches and all. It
## traces the silhouette instead, after a morphological CLOSE: the mask is grown
## by `close` pixels and shrunk by the same amount again, which welds neighbouring
## branches into one mass and fills the gaps between them without fattening the
## outside edge. Tracing the raw silhouette instead gives several hundred points
## of individual twig, and a convex decomposition to match.
extends SceneTree

const PREVIEW_DIR := "res://art/_preview"


func _initialize() -> void:
	var args := _parse_args()
	if not args.has("in"):
		printerr("usage: --in=<path> [--bands=22] [--min-run=26] [--alpha=0.5]")
		quit(1)
		return

	var source: String = _res(args["in"])
	var image := Image.load_from_file(ProjectSettings.globalize_path(source))
	if image == null:
		printerr("could not load ", source)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)

	# How many heights are sampled. Each one costs two points in the polygon, so
	# this is the size of the result: enough to follow the trunk's taper and the
	# spread of the base, not so many that the collision is a staircase.
	var bands: int = maxi(int(args.get("bands", 22)), 3)
	# Narrower than this at a given height is a branch, not the trunk.
	var min_run: int = maxi(int(args.get("min-run", 26)), 1)
	var alpha: float = float(args.get("alpha", 0.5))
	# How far wider than the row below a row is allowed to get, as a fraction of
	# that row's width, per side.
	var max_grow: float = float(args.get("max-grow", 0.35))

	var width := image.get_width()
	var height := image.get_height()

	if str(args.get("mode", "trunk")) == "envelope":
		var envelope := _envelope(image, alpha,
			maxi(int(args.get("close", 18)), 0),
			maxf(float(args.get("epsilon", 9.0)), 1.0))
		if envelope.size() < 3:
			printerr("no envelope found — is the image empty?")
			quit(1)
			return
		_save_preview(image, envelope, source)
		print("envelope points: %d" % envelope.size())
		print(_as_resource_line(envelope, width, height))
		quit()
		return

	var left: Array[Vector2] = []
	var right: Array[Vector2] = []

	# Climbed from the BASE UP, each row taking the run that overlaps the one
	# below it. Taking the widest run on every row independently was the first
	# attempt and it does not describe a tree: high up, the widest solid thing on
	# a row is a horizontal branch two feet to the side of the trunk, so the
	# profile jumped left and right across the picture and the polygon crossed
	# itself. Following the trunk is the whole point — it is the part that is
	# continuous from the ground.
	var span := Vector2i.ZERO
	for b in range(bands - 1, -1, -1):
		# Sampled at the middle of each band rather than its edge, so the top and
		# bottom rows — which are the thinnest and the widest — are not what the
		# whole shape is measured from.
		var y := int((float(b) + 0.5) / float(bands) * float(height))
		var run := _run_above(image, y, width, alpha, min_run, span)
		if run == Vector2i.ZERO:
			break
		# A row may not be much wider than the one below it. Where a limb leaves
		# the trunk, the run at that height reaches all the way out along the
		# limb, and the polygon then fills the open water underneath it — a piece
		# dropped there would land on nothing. Growth is capped so the trace
		# stays on the trunk; the limb keeps its picture and loses its collision,
		# which is the right way round for a branch.
		if span != Vector2i.ZERO:
			var grow := int(float(span.y - span.x + 1) * max_grow)
			run = Vector2i(maxi(run.x, span.x - grow), mini(run.y, span.y + grow))
		span = run
		left.push_front(Vector2(float(run.x), float(y)))
		right.push_front(Vector2(float(run.y + 1), float(y)))

	if left.size() < 2:
		printerr("nothing solid enough found — lower --min-run")
		quit(1)
		return

	# Down the left side and back up the right, which closes the ring in the
	# winding a convex decomposition expects.
	var outline := PackedVector2Array()
	for point: Vector2 in left:
		outline.append(point)
	for i in range(right.size() - 1, -1, -1):
		outline.append(right[i])

	_save_preview(image, outline, source)
	print("bands used: %d of %d  points: %d" % [left.size(), bands, outline.size()])
	print(_as_resource_line(outline, width, height))
	quit()


## The whole silhouette as one closed outline, branches included.
##
## grow_mask does the morphology: +close welds neighbours together, -close takes
## the padding back off. Both passes are the engine's, which matters — the same
## thing written in GDScript over a million pixels is seconds per run.
func _envelope(image: Image, alpha: float, close: int,
		epsilon: float) -> PackedVector2Array:
	# Worked at a quarter size. grow_mask costs the square of its radius per
	# pixel, and at full resolution a radius wide enough to bridge the gaps
	# between branches does not finish in any time worth waiting for — the first
	# attempt ran past five minutes on a 940x704 mask. A quarter of the pixels
	# with a quarter of the radius is the same shape for a sixteenth of the work,
	# and the result is a collision outline, not artwork: it is about to be
	# simplified to a few dozen points anyway.
	const WORK_SCALE := 0.25
	var small := image.duplicate() as Image
	var size := Vector2i(
		maxi(int(float(image.get_width()) * WORK_SCALE), 8),
		maxi(int(float(image.get_height()) * WORK_SCALE), 8)
	)
	small.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)

	var rect := Rect2i(0, 0, size.x, size.y)
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(small, alpha)
	var radius := maxi(int(float(close) * WORK_SCALE), 0)
	if radius > 0:
		# Both passes are bounded by the bitmap's own rect. A grown rect is what
		# the documentation reads like it wants and it indexes outside the mask,
		# which errors on every row. The cost of staying inside is that growth is
		# clipped at the very edge of the image, which moves the outline by a few
		# pixels on a shape that is about to be simplified by far more than that.
		bitmap.grow_mask(radius, rect)
		bitmap.grow_mask(-radius, rect)

	var best := PackedVector2Array()
	for polygon: PackedVector2Array in bitmap.opaque_to_polygons(
			rect, epsilon * WORK_SCALE):
		if _area(polygon) > _area(best):
			best = polygon

	# Back to the full image's pixels, which is what the caller normalises with.
	var out := PackedVector2Array()
	for point: Vector2 in best:
		out.append(point / WORK_SCALE)
	return out


## The run this row continues the trunk with, as (from_x, to_x), or zero when the
## row has nothing solid enough to carry on with.
##
## With no span below it yet — the bottom row — that is simply the widest run,
## which is the base. Above that it is the run overlapping the one below by the
## most, so the trace climbs the trunk rather than stepping sideways onto
## whatever happens to be widest at that height.
func _run_above(image: Image, y: int, width: int, alpha: float, min_run: int,
		below: Vector2i) -> Vector2i:
	var best := Vector2i.ZERO
	var best_score := 0
	var start := -1
	for x in width + 1:
		var solid := x < width and image.get_pixel(x, y).a >= alpha
		if solid and start < 0:
			start = x
		elif not solid and start >= 0:
			var run := Vector2i(start, x - 1)
			start = -1
			var length := run.y - run.x + 1
			if length < min_run:
				continue
			var score := length
			if below != Vector2i.ZERO:
				score = mini(run.y, below.y) - maxi(run.x, below.x) + 1
			if score > best_score:
				best_score = score
				best = run
	return best


func _save_preview(image: Image, polygon: PackedVector2Array, source: String) -> void:
	var out := Image.create(image.get_width(), image.get_height(), false,
		Image.FORMAT_RGBA8)
	out.fill(Color(0.13, 0.14, 0.17))
	out.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	for i in polygon.size():
		_line(out, polygon[i], polygon[(i + 1) % polygon.size()],
			Color(1.0, 0.25, 0.35))
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(PREVIEW_DIR))
	var path := "%s/%s_trace.png" % [PREVIEW_DIR, source.get_file().get_basename()]
	out.save_png(ProjectSettings.globalize_path(path))
	print("preview: %s" % path)


func _line(image: Image, from: Vector2, to: Vector2, color: Color) -> void:
	var steps := int(maxf(absf(to.x - from.x), absf(to.y - from.y))) + 1
	for i in steps + 1:
		var at := from.lerp(to, float(i) / float(steps))
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


func _as_resource_line(polygon: PackedVector2Array, width: int, height: int) -> String:
	var parts := PackedStringArray()
	for point: Vector2 in polygon:
		parts.append("%.4f, %.4f" % [
			point.x / float(width) - 0.5,
			point.y / float(height) - 0.5,
		])
	return "polygon = PackedVector2Array(%s)" % ", ".join(parts)


func _res(path: String) -> String:
	return path if path.begins_with("res://") else "res://" + path


func _parse_args() -> Dictionary:
	var out := {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--") or not arg.contains("="):
			continue
		var pair := arg.substr(2).split("=", true, 1)
		out[pair[0]] = pair[1]
	return out
