## Cuts the UI sheet into the pieces the HUD is built from.
##
## Unlike the net sheets this one is colour, so the keying keeps it. And unlike them it has
## white *inside* the art — the money plate's figures, the word SHED — so a threshold on
## whiteness would eat the lettering along with the paper. The background is taken by a
## flood fill from the edges instead: white that a run of white connects to the border is
## paper, and white with art all the way round it is paint.
##
## The sheet also carries a title, two section headings and a column of pixel measurements
## down the left margin. None of that is a sprite. They are dropped by size — a caption is
## a short band of small runs and every piece worth keeping is enormous next to one.
##
## The meter is measured further, because it has to move. Three numbers come off it: the
## box inside the wooden frame, and where along that box the dirty water gives way to the
## clean. With those the HUD can draw the same bar at any reading rather than at the
## seventy-five per cent it happens to be drawn at.
##
##   godot --headless --path . --script res://tools/slice_ui.gd
extends SceneTree

const SHEET := "res://assets/UI_Buttons.jpg"
const OUT_PNG := "res://assets/ui.png"
const OUT_JSON := "res://assets/ui.json"
const DEBUG_PNG := "res://assets/sliced_ui.png"

## What counts as paper for the flood fill: bright, and near enough to grey that a pale
## yellow highlight inside the art is not mistaken for the page behind it.
const PAPER_LIGHT := 0.82
const PAPER_FLAT := 0.10

## Anything at or over this alpha is art when boxes are being measured.
const INK_ALPHA := 0.5

## The smallest side, in pixels, a run has to have to be a sprite rather than lettering.
const MIN_SIDE := 90

## How much more blue than red a column has to average to be the clean lake. Set above the
## top of the dirty half's teal ramp, which reaches about +0.33, and well under the lake's
## own +0.47.
const CLEAN_BLUE := 0.40

## How many points down each column are read, and how many columns of lake may be drawn over
## before the walk decides the water has run out.
const COLUMN_READS := 24
const BOAT_GAP := 200

## Names for the runs of each band that survives, in the order they sit on the sheet.
const NAMED := [["meter"], ["money", "shed", "upgrades"]]

func _init() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if image == null:
		printerr("could not read %s" % SHEET)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	_key(image)

	var pieces := {}
	var bands := _bands(image)
	var kept: Array = []
	for band: Vector2i in bands:
		var runs := _runs(image, band)
		if not runs.is_empty():
			kept.append(runs)
	if kept.size() != NAMED.size():
		printerr("found %d bands of sprites, expected %d" % [kept.size(), NAMED.size()])
		quit(1)
		return

	for row in kept.size():
		var runs: Array = kept[row]
		var names: Array = NAMED[row]
		if runs.size() != names.size():
			printerr(
				"band %d holds %d sprites, expected %d" % [row, runs.size(), names.size()]
			)
			quit(1)
			return
		for i in names.size():
			var box: Rect2i = runs[i]
			pieces[names[i]] = {
				"region": [box.position.x, box.position.y, box.size.x, box.size.y]
			}

	_measure_meter(image, pieces)

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


## Clear the paper and keep the paint.
##
## A flood from every edge pixel, so only white joined to the outside goes. Written as an
## explicit stack rather than recursion: the background of this sheet is most of a million
## pixels and a recursive fill would go through the stack long before it went through them.
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


## The runs of art across one band, shrunk onto themselves and with the lettering dropped.
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


## The two things about the meter that let it be drawn at a reading other than its own: the
## water box inside the wooden frame, and how far along that box the dirt currently reaches.
##
## All of it comes off one measurement — the bounding box of the clean blue water. That box
## is the full height of the water, it ends where the frame begins, and it starts exactly at
## the divider, so it gives the interior's top, bottom and right edge and the dirt line all
## at once. The left edge is the same inset mirrored, the frame being symmetrical.
##
## Everything earlier tried walking in from an edge asking "is this water", and every such
## walk stops on the first bevel, letter or icon it meets: one of them reported a bar three
## pixels tall running the whole length of the frame. Blue is the one thing on this sheet
## nothing else on it is.
func _measure_meter(image: Image, pieces: Dictionary) -> void:
	if not pieces.has("meter"):
		return
	var box: Array = pieces["meter"]["region"]
	var meter := Rect2i(box[0], box[1], box[2], box[3])

	var low := Vector2i(meter.position.x + meter.size.x, meter.position.y + meter.size.y)
	var high := Vector2i(meter.position.x - 1, meter.position.y - 1)
	for y in range(meter.position.y, meter.position.y + meter.size.y):
		for x in range(meter.position.x, meter.position.x + meter.size.x):
			if not _is_clean(image.get_pixel(x, y)):
				continue
			low.x = mini(low.x, x)
			low.y = mini(low.y, y)
			high.x = maxi(high.x, x)
			high.y = maxi(high.y, y)
	if high.x < low.x or high.y < low.y:
		printerr("no clean water found in the meter")
		quit(1)
		return

	var inset := meter.position.x + meter.size.x - 1 - high.x
	var left := meter.position.x + inset
	var wide := high.x - left + 1
	pieces["meter"]["water"] = [left, low.y, wide, high.y - low.y + 1]
	pieces["meter"]["shown"] = float(
		_dirt_line(image, left, low.y, wide, high.y - low.y + 1) - left
	) / maxf(float(wide), 1.0)


## Where the dirty water ends, as a column.
##
## Walked in from the clean end, on the average blueness of each whole column rather than on
## any single pixel, and allowed to cross the boat.
##
## It took four goes to get here and the failures are the argument for the shape of it. The
## dirty half is not a flat olive: it grades through teal, so column blueness climbs steadily
## from negative to about +0.33 before the divider and then jumps to +0.47 in the lake. Any
## loose threshold stops partway up that ramp; any per-pixel test is thrown by the algae
## specks in the dirt, or the pale bottle drawn in it. Reading the whole column at once
## smooths the decorations away, and a threshold set above the ramp's top rather than
## somewhere in the middle of it lands on the divider.
func _dirt_line(image: Image, left: int, top: int, wide: int, tall: int) -> int:
	var last := left + wide - 1
	var missing := 0
	for step in wide:
		var x := left + wide - 1 - step
		var blue := 0.0
		for i in COLUMN_READS:
			var pixel := image.get_pixel(x, top + (tall - 1) * i / (COLUMN_READS - 1))
			blue += pixel.b - pixel.r
		if blue / float(COLUMN_READS) >= CLEAN_BLUE:
			last = x
			missing = 0
			continue
		# The boat and its wake block about eighty columns of otherwise clean water, and a
		# rule that wants them unbroken stops at it and puts the waterline out in the lake.
		missing += 1
		if missing > BOAT_GAP:
			break
	return last


## The clean end of the bar. Measured as blue against red rather than against green: the
## dirty water is olive and the frame is brown, and both have more red in them than blue,
## while lake water has a great deal more blue than red. The pale bottle drawn in the dirty
## half is near enough white to fail it, which is the point — an earlier version walked in
## from the left, stopped at the first blue thing, and called that bottle the lake.
func _is_clean(pixel: Color) -> bool:
	return pixel.a >= INK_ALPHA and pixel.b - pixel.r > CLEAN_BLUE


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


## The check-my-work picture: every piece boxed, and the meter's water box and dirt line
## drawn on it, over a grey so the transparency shows.
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
		var box: Array = pieces[name]["region"]
		_outline(shown, Rect2i(box[0], box[1], box[2], box[3]), Color(0.35, 0.6, 1.0))
		if not (pieces[name] as Dictionary).has("water"):
			continue
		var water: Array = pieces[name]["water"]
		var inner := Rect2i(water[0], water[1], water[2], water[3])
		_outline(shown, inner, Color(0.3, 1.0, 0.4))
		var split := inner.position.x + int(
			float(inner.size.x) * float(pieces[name]["shown"])
		)
		for y in range(inner.position.y, inner.position.y + inner.size.y):
			shown.set_pixel(split, y, Color(1.0, 0.35, 0.2))
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
