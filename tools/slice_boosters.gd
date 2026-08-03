## Cuts the booster pack sheet into one transparent PNG per tier.
##
##   godot --headless --script tools/slice_boosters.gd
##
## The sheet is four packs in a row on white, in tier order. Each column is cut
## out on its own — keyed against the white, then trimmed to what is left — so a
## pack that sits a little high or wide in its column still comes out centred in
## its own file.
##
## Same job as slice_buttons.gd, which is for the button sheet, and the same
## keying as cutout.gd. Kept separate rather than generalised: the sheets differ
## in how they are laid out, and one tool with a grid argument would be harder to
## read than three that each say what they cut.
extends SceneTree

const SHEET := "res://art_ref/Booster_Packs.png"
const OUT_DIR := "res://art/ui/"
## Left to right, matching the sheet.
const TIERS: Array[String] = ["bronze", "silver", "gold", "deluxe"]
## Colour distance from the sampled backdrop below which a pixel is backdrop.
const TOLERANCE := 0.30


func _initialize() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if image == null:
		printerr("could not load ", SHEET)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)

	var backdrop := image.get_pixel(0, 0)
	var w := image.get_width()
	var h := image.get_height()
	var column := w / TIERS.size()

	for i in TIERS.size():
		var slice := image.get_region(Rect2i(column * i, 0, column, h))
		_key(slice, backdrop)
		# The packs are not perfectly boxed by the column split — a neighbour's
		# edge leans into the cut and survives the key as a thin strip down the
		# side, which then sets the trim bounds and lands in the file. Keeping only
		# the largest connected shape drops it, and asks nothing of how precisely
		# the sheet was laid out.
		_keep_largest_blob(slice)
		var kept := _bounds(slice)
		if kept.position.x < 0:
			printerr("nothing left in column ", i)
			continue
		# A pixel of margin so a pack touching its own bounds isn't hard-clipped.
		kept = kept.grow(1).intersection(Rect2i(0, 0, column, h))
		var out := slice.get_region(kept)
		var path: String = OUT_DIR + "booster_" + TIERS[i] + ".png"
		out.save_png(ProjectSettings.globalize_path(path))
		print("%s   %dx%d" % [path, kept.size.x, kept.size.y])

	quit()


func _key(image: Image, backdrop: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var d := (
				absf(c.r - backdrop.r) + absf(c.g - backdrop.g) + absf(c.b - backdrop.b)
			)
			if d <= TOLERANCE:
				image.set_pixel(x, y, Color(0, 0, 0, 0))


## Clears every opaque region except the biggest one.
func _keep_largest_blob(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(0)

	var best_id := 0
	var best_size := 0
	var next_id := 0
	for start in w * h:
		if label[start] != 0 or image.get_pixel(start % w, start / w).a < 0.5:
			continue
		next_id += 1
		var size := 0
		var queue: Array[int] = [start]
		label[start] = next_id
		while not queue.is_empty():
			var index: int = queue.pop_back()
			size += 1
			var x := index % w
			var y := index / w
			for step: Vector2i in [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
			]:
				var nx: int = x + step.x
				var ny: int = y + step.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var n: int = ny * w + nx
				if label[n] != 0 or image.get_pixel(nx, ny).a < 0.5:
					continue
				label[n] = next_id
				queue.append(n)
		if size > best_size:
			best_size = size
			best_id = next_id

	for y in h:
		for x in w:
			if label[y * w + x] != best_id:
				image.set_pixel(x, y, Color(0, 0, 0, 0))


func _bounds(image: Image) -> Rect2i:
	var kept := Rect2i(-1, -1, 0, 0)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < 0.5:
				continue
			kept = Rect2i(Vector2i(x, y), Vector2i.ONE) if kept.position.x < 0 \
				else kept.expand(Vector2i(x, y))
	return kept
