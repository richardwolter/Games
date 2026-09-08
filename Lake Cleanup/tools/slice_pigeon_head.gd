## Cuts the pigeon head out of the page Richard drew it on.
##
## The head is a portrait for the corner pop-up, drawn large and on white. It arrives as a
## JPEG, so the white is not one value and every edge carries ringing — the same problem the
## UI and pier sheets have — and the same answer works: a flood fill from the borders takes
## the page, and white that has paint all the way round it (the beak's highlight, the glint in
## the eye) is left alone.
##
## Then it is shrunk onto its own pixels and written out as a PNG with an alpha channel, which
## is what pigeon_pop.gd draws.
##
##   godot --headless --path . --script res://tools/slice_pigeon_head.gd
extends SceneTree

const SHEET := "res://assets/Pigeons/Pidgeon_head.jpg"
const OUT_PNG := "res://assets/pigeon_head.png"

## What counts as page: bright, and near enough to grey that a pale part of the bird is not
## mistaken for it. The head is grey, so this is the one that matters — its lightest feathers
## sit around 0.62, well under the threshold.
const PAPER_LIGHT := 0.86
const PAPER_FLAT := 0.10

## Anything at or over this alpha is art when the box is measured.
const INK_ALPHA := 0.5


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

	var head := image.get_region(box)
	if head.save_png(ProjectSettings.globalize_path(OUT_PNG)) != OK:
		printerr("could not write %s" % OUT_PNG)
		quit(1)
		return
	printerr("wrote %s: %dx%d" % [OUT_PNG, box.size.x, box.size.y])
	quit(0)


## Clear the page and keep the paint. An explicit stack rather than recursion: the background
## is most of a million pixels and a recursive fill would run out of stack first.
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


## Bright and colourless enough to be the page rather than a light part of the bird.
func _is_paper(pixel: Color) -> bool:
	var high := maxf(pixel.r, maxf(pixel.g, pixel.b))
	var low := minf(pixel.r, minf(pixel.g, pixel.b))
	return high >= PAPER_LIGHT and high - low <= PAPER_FLAT


## The box the head actually occupies.
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
