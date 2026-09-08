## Cuts the straw hat off its page, and puts it back on its own pixel grid.
##
## The drawing is pixel art enlarged: every "pixel" of it is a solid block a dozen or so
## screen pixels across, saved as a JPEG on white. Two things have to happen before the game
## can wear it. The page has to go, which is the flood fill every sheet in this project is
## keyed with. And the blocks have to come back down to one pixel each — otherwise the hat is
## a photograph of pixel art, and drawn at thirty pixels wide next to a figure that is honestly
## two screen pixels per pixel, it would be the soft thing on screen instead of the character.
##
## The block size is measured rather than written down: see `_block_size`.
##
##   godot --headless --path . --script res://tools/slice_hat.gd
extends SceneTree

const SHEET := "res://assets/Straw_Hat.jpg"
const OUT_PNG := "res://assets/straw_hat.png"

## What counts as the page: bright, and near enough to grey that the palest straw is not
## mistaken for it. The straw is a warm tan — its lightest tone is around 0.93 red against
## 0.78 blue — so the flatness test is what separates them rather than the brightness one.
const PAPER_LIGHT := 0.88
const PAPER_FLAT := 0.06

## Anything at or over this alpha is art when the box is measured.
const INK_ALPHA := 0.5

## How different two pixels have to be to end a run, and the shortest run that is allowed to
## count as one block. The JPEG softens every block edge into a two or three pixel ramp, so a
## run of four is a ramp and not a block.
const RUN_STEP := 0.06
const RUN_LEAST := 5


func _init() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if image == null:
		printerr("could not read %s" % SHEET)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	_key(image)

	var box := _shrink(image)
	if box.size.x <= 0 or box.size.y <= 0:
		printerr("nothing left in %s once the page had gone" % SHEET)
		quit(1)
		return
	var hat := image.get_region(box)

	var block := _block_size(hat)
	printerr("block measured at %d px" % block)
	if block > 1:
		# Nearest, and by an exact whole number, so one block becomes one pixel. Anything
		# smoother would average the blocks' own dithering into mush.
		hat.resize(
			maxi(hat.get_width() / block, 1), maxi(hat.get_height() / block, 1),
			Image.INTERPOLATE_NEAREST
		)

	if hat.save_png(ProjectSettings.globalize_path(OUT_PNG)) != OK:
		printerr("could not write %s" % OUT_PNG)
		quit(1)
		return
	printerr("wrote %s: %dx%d" % [OUT_PNG, hat.get_width(), hat.get_height()])
	quit(0)


## How many screen pixels one pixel of the drawing takes.
##
## Measured off the runs of one colour along rows through the hat: the commonest run there is
## is one block, because most of a drawing is single pixels of one colour next to a different
## one, and the runs that are not are two and three of them in a row.
##
## The commonest rather than the shortest. Shortest was the first go and it came back with
## five against a real block of eleven — a JPEG turns every block edge into a ramp, and a ramp
## read as a run of its own. A histogram does not care: the ramps are all different lengths and
## the blocks are all the same one.
func _block_size(art: Image) -> int:
	var counts := {}
	var tall := art.get_height()
	for step in 9:
		var y := tall * (step + 1) / 10
		var run := 0
		var was := art.get_pixel(0, y)
		for x in art.get_width():
			var pixel := art.get_pixel(x, y)
			if pixel.a < INK_ALPHA:
				run = 0
				was = pixel
				continue
			if _near(pixel, was):
				run += 1
				continue
			if run >= RUN_LEAST:
				counts[run] = int(counts.get(run, 0)) + 1
			run = 1
			was = pixel
		if run >= RUN_LEAST:
			counts[run] = int(counts.get(run, 0)) + 1

	var block := 1
	var most := 0
	for run: int in counts:
		var seen := int(counts[run])
		# Ties go to the shorter run: two blocks side by side are as common as one in some
		# drawings, and half the true block is never a block.
		if seen > most or (seen == most and run < block):
			most = seen
			block = run
	return maxi(block, 1)


func _near(a: Color, b: Color) -> bool:
	return (
		absf(a.r - b.r) <= RUN_STEP
		and absf(a.g - b.g) <= RUN_STEP
		and absf(a.b - b.b) <= RUN_STEP
	)


## Clear the page and keep the paint. An explicit stack rather than recursion: the background
## is most of a million pixels.
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


## Bright and colourless enough to be the page rather than the palest straw.
func _is_paper(pixel: Color) -> bool:
	var high := maxf(pixel.r, maxf(pixel.g, pixel.b))
	var low := minf(pixel.r, minf(pixel.g, pixel.b))
	return high >= PAPER_LIGHT and high - low <= PAPER_FLAT


## The box the hat actually occupies.
func _shrink(image: Image) -> Rect2i:
	var low := Vector2i(image.get_width(), image.get_height())
	var high := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < INK_ALPHA:
				continue
			low.x = mini(low.x, x)
			low.y = mini(low.y, y)
			high.x = maxi(high.x, x)
			high.y = maxi(high.y, y)
	if high.x < low.x or high.y < low.y:
		return Rect2i()
	return Rect2i(low, high - low + Vector2i.ONE)
