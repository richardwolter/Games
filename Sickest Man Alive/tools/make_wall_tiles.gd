extends SceneTree

## Cuts the wall tiles out of the reference sheet and writes them to
## art/rooms/. Run once, by hand, when the sheet changes:
##
##   godot --headless --script tools/make_wall_tiles.gd
##
## The sheet (art_ref/Side_walls_Grid.png) is a scatter of muscle bundles,
## vessels and bone ends on a transparent field. It does NOT tile: pieces run off
## the edges mid-fibre, so butting two copies together shows a hard seam through
## every bundle.
##
## So the tiles are not simply cropped out. Each crop is made to wrap along the
## axis it will REPEAT on, by cross-fading its tail back over its head: the last
## `BLEND` pixels are mixed with the first `BLEND`, weighted so the join is
## exactly half and half. The result's left edge and right edge are then the same
## pixels, and any number of copies laid side by side has no seam.
##
## The other axis is left alone -- a wall tile repeats along the wall and never
## across it.
##
## Cross-fading rather than mirroring on purpose: a mirrored tile is seamless too,
## but it puts an axis of symmetry down the middle of every copy, and a corridor
## lined with butterflies reads as wallpaper instead of as tissue.

const SHEET: String = "res://art_ref/Side_walls_Grid.png"
const OUT_DIR: String = "res://art/rooms"

## Pixels of overlap in the wrap. Wide enough to hide a fibre running off the
## edge, narrow enough to leave most of the crop untouched.
const BLEND: int = 56

## Behind the cut-out anatomy. The sheet is transparent between the bundles, and
## a wall with holes in it reads as a hole in the world -- this is the meat the
## bundles are embedded in.
const BACKING: Color = Color(0.28, 0.16, 0.16, 1.0)
## Deepest shade, used at the tile edges to sink the wall into shadow along its
## length. Keeps a long wall from reading as one flat strip.
const BACKING_DEEP: Color = Color(0.13, 0.07, 0.08, 1.0)

## Where each tile is cut from, and which way it repeats. Chosen by eye off the
## sheet: the horizontal tile takes a run of side-on bundles, the vertical one
## takes a column of them, so the fibres already run the length of the wall they
## will end up on.
## Several of each, cut from different corners of the sheet, so neighbouring
## rooms are not lined with the same repeat. One tile everywhere is what makes a
## body built out of forty rooms read as forty copies of one room.
const CUTS: Array[Dictionary] = [
	{"name": "wall_h_0", "rect": Rect2i(512, 380, 384, 160), "axis": "x"},
	{"name": "wall_h_1", "rect": Rect2i(960, 700, 384, 160), "axis": "x"},
	{"name": "wall_h_2", "rect": Rect2i(1408, 400, 384, 160), "axis": "x"},
	{"name": "wall_v_0", "rect": Rect2i(1180, 356, 160, 384), "axis": "y"},
	{"name": "wall_v_1", "rect": Rect2i(176, 8, 160, 384), "axis": "y"},
	{"name": "wall_v_2", "rect": Rect2i(848, 24, 160, 384), "axis": "y"},
]


func _init() -> void:
	var sheet := Image.load_from_file(SHEET)
	if sheet == null:
		push_error("Could not load %s" % SHEET)
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for cut: Dictionary in CUTS:
		var img := _cut_tile(sheet, cut["rect"], cut["axis"])
		var path := "%s/%s.png" % [OUT_DIR, cut["name"]]
		var err := img.save_png(path)
		print("%s  %s  %s" % [
			path, img.get_size(), "ok" if err == OK else "FAILED %d" % err])
	quit()


func _cut_tile(sheet: Image, rect: Rect2i, axis: String) -> Image:
	var crop := sheet.get_region(rect)
	crop.convert(Image.FORMAT_RGBA8)
	var solid := _flatten(crop)
	var wrapped := _wrap(solid, axis)
	_shade_edges(wrapped, axis)
	return wrapped


## Lays the cut-out anatomy over opaque meat, so the tile has no transparency
## left in it. The backing is not flat: a slow gradient across the tile gives the
## wall some depth before any of the drawn bundles are considered.
func _flatten(src: Image) -> Image:
	var size := src.get_size()
	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var t := float(x + y) / float(size.x + size.y)
			var base := BACKING.lerp(BACKING_DEEP, 0.35 + 0.3 * sin(t * TAU))
			var px := src.get_pixel(x, y)
			out.set_pixel(x, y, base.lerp(Color(px.r, px.g, px.b), px.a))
	return out


## Makes the image repeat along `axis` by cross-fading its far end back over its
## near end.
##
## The weight is 1 at the tile's leading edge and ramps to 0 over BLEND pixels.
## That first pixel is therefore not a mix at all -- it IS src[kept], the pixel
## that came immediately after src[kept-1], which is the tile's trailing edge. So
## the join between two copies is a join between two pixels that were neighbours
## in the source, and the fade only spreads the leftover difference inward where
## nothing lines up on it. Meeting the two ends half way instead leaves half the
## discontinuity sitting exactly on the seam, which is the visible one.
##
## The tile loses BLEND pixels of length in the process: the overlap is consumed,
## not appended.
func _wrap(src: Image, axis: String) -> Image:
	var size := src.get_size()
	var horizontal := axis == "x"
	var length := size.x if horizontal else size.y
	var kept := length - BLEND
	var out := Image.create(
		kept if horizontal else size.x,
		size.y if horizontal else kept,
		false, Image.FORMAT_RGBA8)

	var out_size := out.get_size()
	for y in out_size.y:
		for x in out_size.x:
			var along := x if horizontal else y
			var px := src.get_pixel(x, y)
			if along < BLEND:
				# All tail at the edge, none of it by the end of the overlap.
				var w := 1.0 - float(along) / float(BLEND)
				var tail := src.get_pixel(
					kept + x if horizontal else x,
					y if horizontal else kept + y)
				px = px.lerp(tail, w)
			out.set_pixel(x, y, px)
	return out


## Darkens the two long edges of the tile. A wall drawn as one bright band reads
## as a stripe of art laid on the floor; sinking the edges gives it a lip, and
## the lip is what makes it read as something the room is enclosed by.
##
## Applied across the tile, never along it -- shading the repeating axis would
## put a visible dark bar at every tile boundary.
func _shade_edges(img: Image, axis: String) -> void:
	var size := img.get_size()
	var across := size.y if axis == "x" else size.x
	var lip := maxf(float(across) * 0.28, 1.0)
	for y in size.y:
		for x in size.x:
			var d := float(y if axis == "x" else x)
			var edge := minf(d, float(across - 1) - d)
			if edge >= lip:
				continue
			var k := 1.0 - edge / lip
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color.BLACK, 0.75 * k * k))
