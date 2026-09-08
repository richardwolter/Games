## Cuts the repainted money and upgrades plaques out of Buttons_Fixed.png.
##
## The original UI sheet (tools/slice_ui.gd, assets/ui.json) carries four pieces: the meter,
## the money plate, the shed sign and the upgrades sign. Two of those have been repainted on
## a sheet of their own, so this cuts those two and writes a second book beside the first.
## The HUD reads both and lets this one win, which is why this does not have to reproduce
## the meter's measurements or the shed.
##
## The sheet is white paper with the art on it, the same as the first one, so the background
## is taken the same way: a flood fill from the edges, which leaves white that has paint all
## the way round it — the word UPGRADES, the shine on the coin — alone.
##
## The money plaque also carries a blank panel along its bottom for the live figure to be
## written on. Where that panel is is measured here rather than written down in the HUD: it
## is a property of the picture, and the last time it was a pair of constants they were
## measured against a different painting.
##
##   godot --headless --path . --script res://tools/slice_buttons.gd
extends SceneTree

const SHEET := "res://assets/Buttons_Fixed.png"
const OUT_PNG := "res://assets/buttons.png"
const OUT_JSON := "res://assets/buttons.json"
const DEBUG_PNG := "res://assets/sliced_buttons.png"

## What counts as paper for the flood fill: bright, and near enough to grey that a warm
## highlight inside the art is not mistaken for the page behind it.
const PAPER_LIGHT := 0.82
const PAPER_FLAT := 0.10

## Anything at or over this alpha is art when boxes are being measured.
const INK_ALPHA := 0.5

## The smallest side, in pixels, a run has to have to be a plaque rather than a speck.
const MIN_SIDE := 40

## The pieces, top to bottom, one band each.
const NAMED := ["money", "upgrades"]

## Which piece has a blank panel to be measured, and where to look for it: the bottom
## fraction of the plaque, and how far in from its sides the reading is taken so the wooden
## frame is not part of it.
const PLATED := "money"
const PLATE_BAND := 0.45
const PLATE_INSET := 0.2

## How much a row of the panel may vary across its width and still count as blank. The panel
## is flat colour with a little grain; the coin above it is not close.
const PLATE_FLAT := 0.10


func _init() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if image == null:
		printerr("could not read %s" % SHEET)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	_key(image)

	var boxes: Array[Rect2i] = []
	for band: Vector2i in _bands(image):
		for box: Rect2i in _runs(image, band):
			boxes.append(box)
	if boxes.size() != NAMED.size():
		printerr("found %d plaques, expected %d" % [boxes.size(), NAMED.size()])
		quit(1)
		return

	var pieces := {}
	for i in NAMED.size():
		var box: Rect2i = boxes[i]
		pieces[NAMED[i]] = {
			"region": [box.position.x, box.position.y, box.size.x, box.size.y]
		}
	if not _measure_plate(image, pieces):
		quit(1)
		return

	if image.save_png(ProjectSettings.globalize_path(OUT_PNG)) != OK:
		printerr("could not write %s" % OUT_PNG)
		quit(1)
		return
	var file := FileAccess.open(OUT_JSON, FileAccess.WRITE)
	if file == null:
		printerr("could not write %s" % OUT_JSON)
		quit(1)
		return
	file.store_string(JSON.stringify({
		"sheet": OUT_PNG,
		"size": [image.get_width(), image.get_height()],
		"pieces": pieces,
	}, "\t"))
	file.close()

	_debug_picture(image, pieces)
	printerr("wrote %s: %s" % [OUT_JSON, ", ".join(PackedStringArray(pieces.keys()))])
	quit(0)


## Clear the paper and keep the paint. An explicit stack rather than recursion: the
## background is most of a million pixels.
func _key(image: Image) -> void:
	var wide := image.get_width()
	var tall := image.get_height()
	var paper := PackedByteArray()
	paper.resize(wide * tall)

	var stack: Array[Vector2i] = []
	for x in wide:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, tall - 1))
	for y in tall:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(wide - 1, y))

	while not stack.is_empty():
		var at: Vector2i = stack.pop_back()
		if at.x < 0 or at.y < 0 or at.x >= wide or at.y >= tall:
			continue
		var index := at.y * wide + at.x
		if paper[index] == 1:
			continue
		if not _is_paper(image.get_pixel(at.x, at.y)):
			continue
		paper[index] = 1
		stack.append(Vector2i(at.x + 1, at.y))
		stack.append(Vector2i(at.x - 1, at.y))
		stack.append(Vector2i(at.x, at.y + 1))
		stack.append(Vector2i(at.x, at.y - 1))

	for y in tall:
		for x in wide:
			if paper[y * wide + x] == 1:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))


## Bright and colourless enough to be the page rather than a light part of the picture.
func _is_paper(pixel: Color) -> bool:
	var high := maxf(pixel.r, maxf(pixel.g, pixel.b))
	var low := minf(pixel.r, minf(pixel.g, pixel.b))
	return high >= PAPER_LIGHT and high - low <= PAPER_FLAT


## The horizontal bands of the sheet with anything left in them.
func _bands(image: Image) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var start := -1
	for y in image.get_height():
		var used := false
		for x in image.get_width():
			if image.get_pixel(x, y).a >= INK_ALPHA:
				used = true
				break
		if used and start < 0:
			start = y
		elif not used and start >= 0:
			out.append(Vector2i(start, y - start))
			start = -1
	if start >= 0:
		out.append(Vector2i(start, image.get_height() - start))
	return out


## The runs of art across one band, shrunk onto themselves.
func _runs(image: Image, band: Vector2i) -> Array[Rect2i]:
	var spans: Array[Vector2i] = []
	var start := -1
	for x in image.get_width():
		var used := false
		for y in range(band.x, band.x + band.y):
			if image.get_pixel(x, y).a >= INK_ALPHA:
				used = true
				break
		if used and start < 0:
			start = x
		elif not used and start >= 0:
			spans.append(Vector2i(start, x - start))
			start = -1
	if start >= 0:
		spans.append(Vector2i(start, image.get_width() - start))

	var out: Array[Rect2i] = []
	for span: Vector2i in spans:
		var box := _shrink(image, Rect2i(span.x, band.x, span.y, band.y))
		if box.size.x >= MIN_SIDE and box.size.y >= MIN_SIDE:
			out.append(box)
	return out


## Where the money plaque's blank panel is, as fractions of the plaque itself.
##
## The longest run of near-flat rows in the bottom of it, measured across the middle of its
## width so the wooden frame either side is out of the reading. Fractions rather than pixels
## because the HUD draws the plaque at whatever size the screen gives it.
func _measure_plate(image: Image, pieces: Dictionary) -> bool:
	if not pieces.has(PLATED):
		printerr("no %s plaque to measure a panel in" % PLATED)
		return false
	var region: Array = pieces[PLATED]["region"]
	var box := Rect2i(region[0], region[1], region[2], region[3])
	var left := box.position.x + int(box.size.x * PLATE_INSET)
	var right := box.position.x + box.size.x - int(box.size.x * PLATE_INSET)
	var from := box.position.y + int(box.size.y * (1.0 - PLATE_BAND))

	var best := Vector2i(-1, 0)
	var start := -1
	for y in range(from, box.position.y + box.size.y):
		var flat := _is_flat(image, y, left, right)
		if flat and start < 0:
			start = y
		elif not flat and start >= 0:
			if y - start > best.y:
				best = Vector2i(start, y - start)
			start = -1
	if start >= 0 and box.position.y + box.size.y - start > best.y:
		best = Vector2i(start, box.position.y + box.size.y - start)
	if best.x < 0 or best.y < 4:
		printerr("no blank panel found in the %s plaque" % PLATED)
		return false

	# Trimmed to the flat part of its own width as well, so the figure written on it is
	# centred on the panel rather than on the plaque.
	var span := _flat_span(image, best.x + best.y / 2, box)
	pieces[PLATED]["plate"] = [
		float(span.x - box.position.x) / float(box.size.x),
		float(best.x - box.position.y) / float(box.size.y),
		float(span.y) / float(box.size.x),
		float(best.y) / float(box.size.y),
	]
	return true


## Is this row of the plaque one flat colour across the middle of it?
func _is_flat(image: Image, y: int, left: int, right: int) -> bool:
	var low := Color(1.0, 1.0, 1.0)
	var high := Color(0.0, 0.0, 0.0)
	for x in range(left, right):
		var pixel := image.get_pixel(x, y)
		if pixel.a < INK_ALPHA:
			return false
		low = Color(minf(low.r, pixel.r), minf(low.g, pixel.g), minf(low.b, pixel.b))
		high = Color(maxf(high.r, pixel.r), maxf(high.g, pixel.g), maxf(high.b, pixel.b))
	return (
		high.r - low.r <= PLATE_FLAT
		and high.g - low.g <= PLATE_FLAT
		and high.b - low.b <= PLATE_FLAT
	)


## How far the flat colour on one row of the panel reaches, as a start and a width. Walked
## out from the middle in both directions against the colour found there.
func _flat_span(image: Image, y: int, box: Rect2i) -> Vector2i:
	var middle := box.position.x + box.size.x / 2
	var face := image.get_pixel(middle, y)
	var left := middle
	while left > box.position.x and _near(image.get_pixel(left - 1, y), face):
		left -= 1
	var right := middle
	while right < box.position.x + box.size.x - 1 and _near(image.get_pixel(right + 1, y), face):
		right += 1
	return Vector2i(left, right - left + 1)


func _near(pixel: Color, face: Color) -> bool:
	return (
		pixel.a >= INK_ALPHA
		and absf(pixel.r - face.r) <= PLATE_FLAT
		and absf(pixel.g - face.g) <= PLATE_FLAT
		and absf(pixel.b - face.b) <= PLATE_FLAT
	)


func _shrink(image: Image, box: Rect2i) -> Rect2i:
	var low := Vector2i(box.position.x + box.size.x, box.position.y + box.size.y)
	var high := Vector2i(box.position.x - 1, box.position.y - 1)
	for y in range(box.position.y, box.position.y + box.size.y):
		for x in range(box.position.x, box.position.x + box.size.x):
			if image.get_pixel(x, y).a < INK_ALPHA:
				continue
			low.x = mini(low.x, x)
			low.y = mini(low.y, y)
			high.x = maxi(high.x, x)
			high.y = maxi(high.y, y)
	if high.x < low.x or high.y < low.y:
		return Rect2i()
	return Rect2i(low, high - low + Vector2i.ONE)


## The check-my-work picture: both plaques boxed, and the money panel boxed inside its own.
func _debug_picture(image: Image, pieces: Dictionary) -> void:
	var shown := Image.create(
		image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8
	)
	shown.fill(Color(0.35, 0.37, 0.4, 1.0))
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.0:
				shown.set_pixel(x, y, shown.get_pixel(x, y).lerp(pixel, pixel.a))

	for name: String in pieces:
		var region: Array = pieces[name]["region"]
		var box := Rect2i(region[0], region[1], region[2], region[3])
		_outline(shown, box, Color(0.35, 0.6, 1.0))
		if not (pieces[name] as Dictionary).has("plate"):
			continue
		var plate: Array = pieces[name]["plate"]
		_outline(shown, Rect2i(
			box.position.x + int(float(plate[0]) * box.size.x),
			box.position.y + int(float(plate[1]) * box.size.y),
			int(float(plate[2]) * box.size.x),
			int(float(plate[3]) * box.size.y)
		), Color(0.3, 1.0, 0.4))
	shown.save_png(ProjectSettings.globalize_path(DEBUG_PNG))


func _outline(image: Image, box: Rect2i, tint: Color) -> void:
	var right := mini(box.position.x + box.size.x - 1, image.get_width() - 1)
	var bottom := mini(box.position.y + box.size.y - 1, image.get_height() - 1)
	for x in range(box.position.x, right + 1):
		image.set_pixel(x, box.position.y, tint)
		image.set_pixel(x, bottom, tint)
	for y in range(box.position.y, bottom + 1):
		image.set_pixel(box.position.x, y, tint)
		image.set_pixel(right, y, tint)
