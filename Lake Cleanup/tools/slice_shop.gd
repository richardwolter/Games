## Cuts the upgrades menu into the pieces the shop is drawn from.
##
## The sheet is one board with a banner over it and five rows on it, and the shop needs more
## rows than five — so it cannot be used as a picture. It is used as a kit: the board and the
## banner get stretched to whatever the panel is, one row plate and one price tag are taken
## as patterns and repeated, and the five icons are kept as themselves.
##
## Keying is the flood fill from tools/slice_ui.gd for the same reason: this is colour art
## with white lettering inside it, and a threshold on whiteness eats the words.
##
## What is measured, and how:
##   panel   the whole board, banner included — the bounding box of everything
##   board   the board without the banner, so a stretched panel does not stretch the ribbon
##   banner  the ribbon across the top
##   row     one of the dark plates, found as the wide dark bands down the middle
##   price   the tan tag at a row's right end, found as the warm block inside a row
##   icon    the bordered squares to the left of the rows, one per row
##
##   godot --headless --path . --script res://tools/slice_shop.gd
extends SceneTree

const SHEET := "res://assets/Net_Upgrades_Menu.jpg"
const OUT_PNG := "res://assets/shop.png"
const OUT_JSON := "res://assets/shop.json"
const DEBUG_PNG := "res://assets/sliced_shop.png"

## What counts as paper for the flood fill.
const PAPER_LIGHT := 0.82
const PAPER_FLAT := 0.10

const INK_ALPHA := 0.5

## What tells a row plate from the board it sits on.
##
## Not darkness. The board is already dark — every part of this sheet reads under a third of
## full brightness, and a threshold there marks the whole panel. What separates them is
## warmth: the board is brown and the plates are all but neutral, so red minus blue splits
## them where light never could.
const PLATE_WARM := 0.06
const PLATE_SHARE := 0.75

## The part of the panel a row is looked for across: past the frame and the icon tiles on the
## left, and short of the frame on the right.
const PLATE_FROM := 0.30
const PLATE_TO := 0.85

## The shortest a band can be and still be a row rather than a seam in the woodwork.
const PLATE_TALL := 30

## How a plate and a tag are cut into three so they can be drawn at any width: an end cap
## kept whole at each side, and a slab of the middle stretched between them.
##
## The slab has to come from somewhere with nothing written on it, which on this sheet means
## just inside the left cap — everywhere else carries the label, the value or the price the
## art was drawn with, and stretching any of those writes a wrong and unmoving word across
## every row.
const ROW_CAP := 20
const ROW_SLAB := 8
const TAG_CAP := 12
const TAG_SLAB := 5

## How far above and below its own row an icon tile may reach. They stand a little taller
## than the plates they label; more than this and the search picks up the tile next door.
const ICON_REACH := 12

## How far in from the panel's edge the icons are looked for, past the board's frame — the
## frame's dark outline is as cool as a tile is.
const ICON_FROM := 0.05

## The part of the panel's width the banner is looked for across. The corner brackets are up
## at the same height and would stretch its box to the full width of the board.
const BANNER_FROM := 0.15
const BANNER_TO := 0.85
## How far past the board's top edge the ribbon hangs, as a multiple of its height above it.
const BANNER_DROP := 1.7

## A price tag is warm and light against the plate it sits on — and against the board, which
## is the harder test. The frame's lit edges are warm and fairly light too, so both numbers
## sit above them: the tag is a pale tan and the wood never gets near it.
const TAG_WARM := 0.30
const TAG_LIGHT := 0.55

## The part of the panel the tag is looked for in. It lives at the right-hand end of its row,
## and starting further left finds the icon tile's own lit border.
const TAG_FROM := 0.55

## How many upgrade rows the sheet is drawn with.
const ROWS := 5


func _init() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if image == null:
		printerr("could not read %s" % SHEET)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	_key(image)

	var panel := _art_box(image)
	if panel.size.x <= 0:
		printerr("nothing left after keying")
		quit(1)
		return

	var plates := _plates(image, panel)
	if plates.size() != ROWS:
		printerr("found %d row plates, expected %d" % [plates.size(), ROWS])
		quit(1)
		return

	# The board proper starts where the rows' own left edge does, less the icons. Its top is
	# taken as where the banner stops overhanging: the first row of the panel that runs the
	# full width of it.
	var first: Rect2i = plates[0]
	var last: Rect2i = plates[plates.size() - 1]
	var tag := _price(image, first, panel)
	var icons := _icons(image, panel, plates)

	var board_top := _board_top(image, panel)
	# How far the frame reaches in, taken from where the icon tiles start: they sit hard
	# against the board's inner edge with a little air, and nothing else on the sheet marks
	# that edge as plainly.
	var inset := int(float((icons[0] as Rect2i).position.x - panel.position.x) * 0.62)

	var pieces := {
		"panel": _as_array(panel),
		"board": _as_array(Rect2i(
			panel.position.x, board_top,
			panel.size.x, panel.position.y + panel.size.y - board_top
		)),
		"banner": _as_array(_banner(image, panel, board_top)),
		# The board's bare interior, and a patch of it. The board is painted with five rows
		# and their prices, so a board stretched behind live ones shows the artist's numbers
		# ghosting under every line — the interior gets papered over with its own empty wood
		# before anything is drawn on it.
		"inner": _as_array(Rect2i(
			panel.position.x + inset, board_top + inset,
			panel.size.x - inset * 2,
			panel.position.y + panel.size.y - board_top - inset * 2
		)),
		"board_fill": _as_array(Rect2i(
			panel.position.x + panel.size.x / 2 - 20,
			last.position.y + last.size.y + (panel.position.y + panel.size.y
				- last.position.y - last.size.y) / 2,
			40, 40
		)),
		"row": _as_array(first),
		"row_cap_l": _as_array(Rect2i(first.position, Vector2i(ROW_CAP, first.size.y))),
		# From the bare plate just before the price tag. The obvious place — inside the left
		# cap — is where the word "Width" starts, and a slab of the letter W stretched the
		# length of every row is a smear across the whole board.
		"row_fill": _as_array(Rect2i(
			mini(tag.position.x, first.position.x + first.size.x) - ROW_SLAB - 6,
			first.position.y, ROW_SLAB, first.size.y
		)),
		"row_cap_r": _as_array(Rect2i(
			first.position + Vector2i(first.size.x - ROW_CAP, 0),
			Vector2i(ROW_CAP, first.size.y)
		)),
		"price": _as_array(tag),
		"price_cap_l": _as_array(Rect2i(tag.position, Vector2i(TAG_CAP, tag.size.y))),
		"price_fill": _as_array(Rect2i(
			tag.position + Vector2i(TAG_CAP + 1, 0), Vector2i(TAG_SLAB, tag.size.y)
		)),
		"price_cap_r": _as_array(Rect2i(
			tag.position + Vector2i(tag.size.x - TAG_CAP, 0),
			Vector2i(TAG_CAP, tag.size.y)
		)),
		# Where a row sits inside the board, as fractions, so the shop can lay its own out
		# in the same places rather than by numbers typed twice.
		"row_step": float((plates[1] as Rect2i).position.y - first.position.y)
			/ float(panel.size.y),
		"row_left": float(first.position.x - panel.position.x) / float(panel.size.x),
		"row_top": float(first.position.y - panel.position.y) / float(panel.size.y),
	}
	for i in icons.size():
		pieces["icon%d" % i] = _as_array(icons[i])

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
	printerr("wrote %s: %d pieces" % [OUT_JSON, pieces.size()])
	quit(0)


func _as_array(box: Rect2i) -> Array:
	return [box.position.x, box.position.y, box.size.x, box.size.y]


## Clear the paper and keep the paint. A flood from every edge, so only white joined to the
## outside goes and the lettering inside the art stays.
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
		var pixel := image.get_pixel(at.x, at.y)
		var high := maxf(pixel.r, maxf(pixel.g, pixel.b))
		var low := minf(pixel.r, minf(pixel.g, pixel.b))
		if high < PAPER_LIGHT or high - low > PAPER_FLAT:
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


## The bounding box of everything that survived the keying.
func _art_box(image: Image) -> Rect2i:
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
	if high.x < low.x:
		return Rect2i()
	return Rect2i(low, high - low + Vector2i.ONE)


## The row plates: the bands of the panel that are cool rather than brown across the middle.
func _plates(image: Image, panel: Rect2i) -> Array[Rect2i]:
	var bands: Array[Vector2i] = []
	var start := -1
	var from := panel.position.x + int(float(panel.size.x) * PLATE_FROM)
	var to := panel.position.x + int(float(panel.size.x) * PLATE_TO)
	for y in range(panel.position.y, panel.position.y + panel.size.y):
		var cool := 0
		for i in 32:
			var x := from + (to - from) * i / 31
			if _is_plate(image.get_pixel(x, y)):
				cool += 1
		var plated := float(cool) / 32.0 >= PLATE_SHARE
		if plated and start < 0:
			start = y
		elif not plated and start >= 0:
			bands.append(Vector2i(start, y - start))
			start = -1
	if start >= 0:
		bands.append(Vector2i(start, panel.position.y + panel.size.y - start))

	var out: Array[Rect2i] = []
	for band: Vector2i in bands:
		if band.y < PLATE_TALL:
			continue
		out.append(_plate_run(image, band, panel))
	return out


## One plate's own left and right edge, spread out from the middle of the panel rather than
## walked in from its sides: the icon tiles are as cool as the plates are, so a walk from the
## left finds an icon and calls it the row.
func _plate_run(image: Image, band: Vector2i, panel: Rect2i) -> Rect2i:
	var middle := band.x + band.y / 2
	var centre := panel.position.x + panel.size.x / 2
	var left := centre
	while left > panel.position.x and _on_plate(image.get_pixel(left - 1, middle)):
		left -= 1
	var right := centre
	while right < panel.position.x + panel.size.x - 1 and _on_plate(
		image.get_pixel(right + 1, middle)
	):
		right += 1
	return Rect2i(left, band.x, right - left + 1, band.y)


## Part of a row, either the plate itself or the price tag sitting on it.
##
## The tag has to be included or the row stops at it: the plate is cool and the tag is warm,
## so spreading out on coolness alone finds the tag's left edge and calls that the end of the
## row — which leaves the tag outside the row that contains it, and nothing to find when the
## tag is looked for inside.
func _on_plate(pixel: Color) -> bool:
	return _is_plate(pixel) or _is_tag(pixel)


func _is_plate(pixel: Color) -> bool:
	return pixel.a >= INK_ALPHA and pixel.r - pixel.b < PLATE_WARM


## The icon tiles: the cool blocks sitting to the left of each plate.
##
## Kept to its own row and to the strip between the frame and the plates. Reaching further
## up and down finds the tile above or below, and starting at the panel's edge finds the
## frame's own dark outline, which is as cool as a tile is.
func _icons(image: Image, panel: Rect2i, plates: Array[Rect2i]) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var from := panel.position.x + int(float(panel.size.x) * ICON_FROM)
	for plate: Rect2i in plates:
		var top := maxi(plate.position.y - ICON_REACH, panel.position.y)
		var bottom := mini(
			plate.position.y + plate.size.y + ICON_REACH,
			panel.position.y + panel.size.y
		)
		var low := Vector2i(plate.position.x, bottom)
		var high := Vector2i(from, top)
		for y in range(top, bottom):
			for x in range(from, plate.position.x):
				if not _is_plate(image.get_pixel(x, y)):
					continue
				low.x = mini(low.x, x)
				low.y = mini(low.y, y)
				high.x = maxi(high.x, x)
				high.y = maxi(high.y, y)
		if high.x < low.x or high.y < low.y:
			out.append(Rect2i())
			continue
		out.append(Rect2i(low, high - low + Vector2i.ONE))
	return out


## The price tag on a row: the warm, light block at the right-hand end of it.
##
## Looked for across the whole band rather than inside the plate, because it is not inside
## the plate. The plate is the dark bar and the tag butts up against its right edge, outside
## it — so every version of this that searched within the plate's own box found nothing and
## reported a tag one pixel square. Warm and light is unique to the tag on this band, so its
## bounding box needs no walking at all.
func _price(image: Image, plate: Rect2i, panel: Rect2i) -> Rect2i:
	var low := Vector2i(panel.position.x + panel.size.x, plate.position.y + plate.size.y)
	var high := Vector2i(panel.position.x, plate.position.y)
	for y in range(plate.position.y, plate.position.y + plate.size.y):
		for x in range(
			panel.position.x + int(float(panel.size.x) * TAG_FROM),
			panel.position.x + panel.size.x
		):
			if not _is_tag(image.get_pixel(x, y)):
				continue
			low.x = mini(low.x, x)
			low.y = mini(low.y, y)
			high.x = maxi(high.x, x)
			high.y = maxi(high.y, y)
	if high.x < low.x or high.y < low.y:
		return Rect2i()

	# The strict test finds the tag's bright middle. Its own border is a darker tan that
	# fails it, so the box is grown outwards along the row while the wood is still warm, and
	# its height taken from the plate it sits on — the tag is inset from that by a hair and
	# measuring the inset is more trouble than assuming it.
	var middle := (low.y + high.y) / 2
	while low.x > panel.position.x and _warm(image.get_pixel(low.x - 1, middle)):
		low.x -= 1
	while high.x < panel.position.x + panel.size.x - 1 and _warm(
		image.get_pixel(high.x + 1, middle)
	):
		high.x += 1
	var inset := maxi(int(float(plate.size.y) * 0.08), 1)
	return Rect2i(
		low.x, plate.position.y + inset,
		high.x - low.x + 1, plate.size.y - inset * 2
	)


## Warm enough to still be the tag rather than the plate under it or the board beside it.
func _warm(pixel: Color) -> bool:
	return pixel.a >= INK_ALPHA and pixel.r - pixel.b > 0.16 and _light(pixel) > 0.28


## Is this column, around this row, part of the tag? Voted, so the lettering on it does not
## end the walk early.
func _near_tag(image: Image, x: int, middle: int) -> bool:
	var warm := 0
	for i in range(-6, 7):
		if _is_tag(image.get_pixel(x, middle + i)):
			warm += 1
	return warm >= 5


func _is_tag(pixel: Color) -> bool:
	return (
		pixel.a >= INK_ALPHA and _light(pixel) > TAG_LIGHT
		and pixel.r - pixel.b > TAG_WARM
	)


## Where the board's own top edge is: the first row with the frame's left-hand upright in
## it. The ribbon hangs above and across the board but never reaches its sides, so asking
## the sides is asking about the board alone.
func _board_top(image: Image, panel: Rect2i) -> int:
	var at := panel.position.x + int(float(panel.size.x) * 0.02)
	for y in range(panel.position.y, panel.position.y + panel.size.y):
		if image.get_pixel(at, y).a >= INK_ALPHA:
			return y
	return panel.position.y


## The ribbon: the art above the board's top edge and a way past it, taken across the middle
## of the panel only. The metal corner brackets sit at the same height out at the sides, and
## including them stretches the ribbon's box across the whole board.
func _banner(image: Image, panel: Rect2i, board_top: int) -> Rect2i:
	var above := maxi(board_top - panel.position.y, 1)
	var bottom := mini(
		board_top + int(float(above) * BANNER_DROP), panel.position.y + panel.size.y
	)
	var from := panel.position.x + int(float(panel.size.x) * BANNER_FROM)
	var to := panel.position.x + int(float(panel.size.x) * BANNER_TO)
	var low := Vector2i(to, bottom)
	var high := Vector2i(from, panel.position.y)
	for y in range(panel.position.y, bottom):
		for x in range(from, to):
			if image.get_pixel(x, y).a < INK_ALPHA:
				continue
			low.x = mini(low.x, x)
			low.y = mini(low.y, y)
			high.x = maxi(high.x, x)
			high.y = maxi(high.y, y)
	if high.x < low.x:
		return Rect2i()
	return Rect2i(low, high - low + Vector2i.ONE)


func _light(pixel: Color) -> float:
	return pixel.r * 0.3 + pixel.g * 0.59 + pixel.b * 0.11


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
	var tints := {
		"panel": Color(0.35, 0.6, 1.0), "board": Color(0.5, 0.9, 1.0),
		"banner": Color(1.0, 0.9, 0.3), "row": Color(0.3, 1.0, 0.4),
		"price": Color(1.0, 0.4, 0.2),
	}
	for name: String in pieces:
		if not (pieces[name] is Array):
			continue
		var box: Array = pieces[name]
		_outline(
			shown, Rect2i(box[0], box[1], box[2], box[3]),
			tints.get(name, Color(1.0, 0.5, 1.0))
		)
	shown.save_png(ProjectSettings.globalize_path(DEBUG_PNG))


func _outline(image: Image, box: Rect2i, tint: Color) -> void:
	if box.size.x <= 0 or box.size.y <= 0:
		return
	var right := mini(box.position.x + box.size.x - 1, image.get_width() - 1)
	var bottom := mini(box.position.y + box.size.y - 1, image.get_height() - 1)
	for x in range(box.position.x, right + 1):
		image.set_pixel(x, box.position.y, tint)
		image.set_pixel(x, bottom, tint)
	for y in range(box.position.y, bottom + 1):
		image.set_pixel(box.position.x, y, tint)
		image.set_pixel(right, y, tint)
