## Cuts the four merchant yards out of the piers sheet.
##
## The sheet is four finished dockside scenes on near-white paper, one per material, laid
## out in quadrants: plastic top left, metal top right, timber bottom left, rubber bottom
## right — the layout Richard drew them in.
##
## Three things make this harder than it looks.
##
## It is a JPEG, so the paper is not one value and every edge carries ringing. A threshold
## on brightness either leaves a grey rectangle round each pier or bites into the art's own
## highlights, so the paper is taken by a flood fill from the borders the way slice_ui.gd
## does it — white the border can reach is paper, white with art all round it is paint.
##
## The quadrants are only roughly where the scenes are. Three of the four hang past the
## halfway line, so cutting on the geometric boundary saws the legs off two of the piers, and
## the metal and rubber yards touch each other, so grouping by connected ink runs them into
## one. The cut is made where the sheet is emptiest instead — a real gutter of eighty clear
## columns down the middle, and the quietest row across — and the quadrants only name what
## comes out.
##
## And each scene is painted standing on a soft grey shadow. That goes with the page. It was
## kept once, as a ramped contact shadow, and on the bank it read as a grey slab under the
## posts: the shadow was painted for a scene lit from the front on white paper, and this lake
## is drawn on a plane seen at an angle, where nothing else casts anything like it. What the
## fill walks through it now clears outright, which is why `_paper_alpha` is only asked where
## the page stops rather than how dark it has got.
##
##   godot --headless --path . --script res://tools/slice_piers.gd
extends SceneTree

const SHEET := "res://assets/Piers_Asset_Sheet.jpg"
const OUT_PNG := "res://assets/piers.png"
const OUT_JSON := "res://assets/piers.json"
const DEBUG_PNG := "res://assets/sliced_piers.png"

## Which quadrant holds which yard, as [column, row] with the origin top left. The names are
## TrashDef.KIND_NAMES lowercased, so Dropoff can look itself up by the kind it buys rather
## than by an index that can fall out of step with the enum.
const QUADRANTS := {
	"plastic": Vector2i(0, 0),
	"metal": Vector2i(1, 0),
	"timber": Vector2i(0, 1),
	"rubber": Vector2i(1, 1),
}

## What counts as paper. Higher than the UI sheet's 0.82: these are painted scenes on a
## near-white ground rather than flat panels on true white, and the JPEG has pulled the
## paper down a little everywhere.
const PAPER_LIGHT := 0.86
const PAPER_FLAT := 0.10

## The band under the paper where the ground shadow lives, and how far the page has to
## darken before the shadow is at full weight.
const SHADOW_DEPTH := 0.16
const SHADOW_FLAT := 0.09

## What is left of the ground under a scene once the page has gone, and how deep a band of
## it to sweep.
##
## The shadow was not one flat grey: its darkest core is a cool purple slab, dark enough and
## just coloured enough that the page fill reads it as picture and stops on it. So one pier
## kept a purple plank hanging under its middle post, and the rest kept pale smudges at the
## feet of theirs. Everything the yards themselves are painted in down there is wood, and
## wood is warm — more red than blue — so what is swept is the cool stuff: anything in the
## bottom band whose blue is not clearly under its red.
##
## The band is measured up from the lowest ink in the quadrant rather than from the sheet, so
## it follows the pier that is actually there.
const GROUND_ROWS := 14
const GROUND_COOL := -0.02

## The page left in pockets the edge fill cannot reach, and the biggest such pocket worth
## clearing.
##
## The fill walks in from the border, so page enclosed by art stays: the gap under each
## PLASTIC sign, between its two legs and the bins below it, and the loop of the mooring
## rope. Those came into the game as white blocks hanging off the piers.
##
## Clearing them needs a tighter test than the fill uses, because the signs themselves are
## painted a pale blue-white and a loose one would punch the faces out of them. The page is
## brighter and far flatter than that paint — about 0.93 across all three channels against a
## sign face's 0.82 red to 0.92 blue — so brightness plus flatness tells them apart, and the
## size cap keeps the big sign plaques out of it whatever the paint does.
## The page is also not the brightest thing on the sheet: the highlights on the bottles and
## the gloss on the sign are painted at very nearly pure white, and without a ceiling this
## ate small holes in both of them.
const PAGE_LIGHT := 0.90
const PAGE_MOST := 0.99
const PAGE_FLAT := 0.045
const POCKET_MOST := 700

## And the smallest. The page pools in gaps a sign or a rope leaves; a handful of pixels the
## same colour in the middle of a painting is shading, and clearing those left the bottles on
## the sign speckled with holes.
const POCKET_LEAST := 60

## Anything at or over this alpha is art when the boxes are measured.
const INK_ALPHA := 0.35

## The smallest island of ink worth keeping, in pixels, and how far apart two islands may be
## and still be the same yard. A yard's sign hangs over its deck without touching it; the
## tips of the neighbour's posts are neither near enough nor big enough.
const ISLAND_LEAST := 1200
const ISLAND_REACH := 40

func _init() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if image == null:
		printerr("could not read %s" % SHEET)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	_key(image)
	_clear_pockets(image)

	var profiles := _profiles(image)
	var wide_all := image.get_width()
	var tall_all := image.get_height()
	var split := Vector2i(
		_gutter(profiles[0], int(wide_all * 0.38), int(wide_all * 0.62)),
		_gutter(profiles[1], int(tall_all * 0.38), int(tall_all * 0.62))
	)
	print("cut at ", split)

	var boxes := {}
	for name: String in QUADRANTS:
		var cell: Vector2i = QUADRANTS[name]
		var quad := Rect2i(
			0 if cell.x == 0 else split.x,
			0 if cell.y == 0 else split.y,
			split.x if cell.x == 0 else wide_all - split.x,
			split.y if cell.y == 0 else tall_all - split.y
		)
		_sweep_ground(image, quad)
		var box := _yard(image, quad)
		if box.size.x <= 0 or box.size.y <= 0:
			printerr("nothing left in the %s quadrant" % name)
			quit(1)
			return
		boxes[name] = box

	# Packed side by side into one strip, so the four yards are one texture and one draw
	# call whichever of them is asked for.
	var pieces := {}
	var wide := 0
	var tall := 0
	for name: String in boxes:
		var box: Rect2i = boxes[name]
		wide += box.size.x
		tall = maxi(tall, box.size.y)
	var out := Image.create_empty(wide, tall, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.0, 0.0, 0.0, 0.0))
	var at := 0
	for name: String in boxes:
		var box: Rect2i = boxes[name]
		out.blit_rect(image, box, Vector2i(at, 0))
		pieces[name] = [at, 0, box.size.x, box.size.y]
		at += box.size.x

	out.save_png(ProjectSettings.globalize_path(OUT_PNG))
	var book := {"sheet": OUT_PNG, "size": [wide, tall], "pieces": pieces}
	var file := FileAccess.open(OUT_JSON, FileAccess.WRITE)
	file.store_string(JSON.stringify(book, "\t"))
	file.close()

	_proof(image, boxes)

	for name: String in pieces:
		print("%s %s" % [name, pieces[name]])
	print("wrote %s and %s" % [OUT_PNG, OUT_JSON])
	quit(0)


## Clear the paper off the sheet, seeded from its borders.
func _key(image: Image) -> void:
	var wide := image.get_width()
	var tall := image.get_height()
	var seen := PackedByteArray()
	seen.resize(wide * tall)

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
		if seen[index] == 1:
			continue
		var pixel := image.get_pixel(at.x, at.y)
		var keep := _paper_alpha(pixel)
		if keep >= 1.0:
			continue
		seen[index] = 1
		# The shadow is paper the fill can walk through — it is part of the page, not part
		# of the pier — so it goes with the rest of the page.
		image.set_pixel(at.x, at.y, Color(0.0, 0.0, 0.0, 0.0))
		stack.append(Vector2i(at.x + 1, at.y))
		stack.append(Vector2i(at.x - 1, at.y))
		stack.append(Vector2i(at.x, at.y + 1))
		stack.append(Vector2i(at.x, at.y - 1))


## Whether the fill has run out of page here: one means "this is not page at all, stop", and
## anything under one is page — clean or shadowed — and is cleared. The ramp in between is
## what keeps the fill from stopping on the soft edge of a shadow and leaving a grey fringe
## round the feet of a pier.
func _paper_alpha(pixel: Color) -> float:
	var high := maxf(pixel.r, maxf(pixel.g, pixel.b))
	var low := minf(pixel.r, minf(pixel.g, pixel.b))
	if high - low > PAPER_FLAT:
		return 1.0
	if high >= PAPER_LIGHT:
		return 0.0
	if high < PAPER_LIGHT - SHADOW_DEPTH:
		return 1.0
	return clampf((PAPER_LIGHT - high) / SHADOW_FLAT, 0.0, 1.0) * 0.55


## Where the sheet actually divides, rather than where half of it is.
##
## Three of the four scenes hang past the geometric midline, so cutting there saws the legs
## off two of the piers. But there is a real gutter between them — eighty clear columns down
## the middle, and a row near the bottom of the top pair with almost nothing in it — so the
## cut is put wherever the sheet is emptiest within a band around the middle.
func _gutter(counts: PackedInt32Array, from: int, to: int) -> int:
	var best := from
	var least := counts[from]
	for i in range(from, to):
		if counts[i] < least:
			least = counts[i]
			best = i
	return best


## How much ink there is down each column and across each row.
func _profiles(image: Image) -> Array:
	var wide := image.get_width()
	var tall := image.get_height()
	var cols := PackedInt32Array()
	cols.resize(wide)
	var rows := PackedInt32Array()
	rows.resize(tall)
	for y in tall:
		for x in wide:
			if image.get_pixel(x, y).a < INK_ALPHA:
				continue
			cols[x] += 1
			rows[y] += 1
	return [cols, rows]


## The box round one yard, and only that yard.
##
## A plain bounding box over the half is not enough: the cut runs through the tips of the
## metal yard's posts, and their few surviving pixels sit at the top of the timber half,
## which dragged the timber box up over a strip of somebody else's pier. So the ink is
## grouped into islands first, the biggest island is the yard, and anything close enough to
## be part of it — its sign, hanging over the deck without touching it — joins it. Stray
## fragments from the neighbour are neither, and are dropped.
func _yard(image: Image, quad: Rect2i) -> Rect2i:
	var islands := _islands(image, quad)
	if islands.is_empty():
		return Rect2i()
	var best := 0
	for i in islands.size():
		var box: Rect2i = islands[i][0]
		var most: Rect2i = islands[best][0]
		if box.size.x * box.size.y > most.size.x * most.size.y:
			best = i
	var yard: Rect2i = islands[best][0]
	var joined := true
	while joined:
		joined = false
		for i in islands.size():
			var box: Rect2i = islands[i][0]
			if yard.encloses(box):
				continue
			if not yard.grow(ISLAND_REACH).intersects(box):
				continue
			yard = yard.merge(box)
			joined = true
	return yard


## Clear the page out of the pockets the fill could not walk into. See PAGE_LIGHT.
func _clear_pockets(image: Image) -> void:
	var wide := image.get_width()
	var tall := image.get_height()
	var seen := PackedByteArray()
	seen.resize(wide * tall)

	for y in tall:
		for x in wide:
			if seen[y * wide + x] == 1 or not _is_page(image.get_pixel(x, y)):
				continue
			# The whole pocket first, then a decision about it: its size is not known until
			# it has been walked, and a sign plaque is a pocket too.
			var pocket: Array[Vector2i] = []
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			while not stack.is_empty():
				var at: Vector2i = stack.pop_back()
				if at.x < 0 or at.y < 0 or at.x >= wide or at.y >= tall:
					continue
				if seen[at.y * wide + at.x] == 1:
					continue
				if not _is_page(image.get_pixel(at.x, at.y)):
					continue
				seen[at.y * wide + at.x] = 1
				pocket.append(at)
				stack.append(Vector2i(at.x + 1, at.y))
				stack.append(Vector2i(at.x - 1, at.y))
				stack.append(Vector2i(at.x, at.y + 1))
				stack.append(Vector2i(at.x, at.y - 1))
			if pocket.size() > POCKET_MOST or pocket.size() < POCKET_LEAST:
				continue
			for at: Vector2i in pocket:
				image.set_pixel(at.x, at.y, Color(0.0, 0.0, 0.0, 0.0))


## Page rather than paint: bright, and flat enough across the channels that a pale blue sign
## face does not pass for it.
func _is_page(pixel: Color) -> bool:
	if pixel.a < INK_ALPHA:
		return false
	var high := maxf(pixel.r, maxf(pixel.g, pixel.b))
	var low := minf(pixel.r, minf(pixel.g, pixel.b))
	return high >= PAGE_LIGHT and high <= PAGE_MOST and high - low <= PAGE_FLAT


## Clear whatever the shadow left lying on the ground under one yard. See GROUND_ROWS.
func _sweep_ground(image: Image, quad: Rect2i) -> void:
	var floor_y := -1
	for y in range(quad.position.y, quad.position.y + quad.size.y):
		for x in range(quad.position.x, quad.position.x + quad.size.x):
			if image.get_pixel(x, y).a >= INK_ALPHA:
				floor_y = y
				break
	if floor_y < 0:
		return
	for y in range(maxi(floor_y - GROUND_ROWS, quad.position.y), floor_y + 1):
		for x in range(quad.position.x, quad.position.x + quad.size.x):
			var pixel := image.get_pixel(x, y)
			if pixel.a < INK_ALPHA:
				continue
			# Wood is warm. Anything down here that is not is the ground it stood on.
			if pixel.b - pixel.r > GROUND_COOL:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))


## The islands of ink inside a quadrant, as [box, pixels], with anything too small to be
## part of a pier thrown away.
func _islands(image: Image, quad: Rect2i) -> Array:
	var seen := PackedByteArray()
	seen.resize(quad.size.x * quad.size.y)
	var out: Array = []
	for start_y in quad.size.y:
		for start_x in quad.size.x:
			if seen[start_y * quad.size.x + start_x] == 1:
				continue
			var from := quad.position + Vector2i(start_x, start_y)
			if image.get_pixelv(from).a < INK_ALPHA:
				seen[start_y * quad.size.x + start_x] = 1
				continue
			var box := Rect2i(from, Vector2i.ONE)
			var count := 0
			var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]
			while not stack.is_empty():
				var at: Vector2i = stack.pop_back()
				if at.x < 0 or at.y < 0 or at.x >= quad.size.x or at.y >= quad.size.y:
					continue
				var index := at.y * quad.size.x + at.x
				if seen[index] == 1:
					continue
				if image.get_pixelv(quad.position + at).a < INK_ALPHA:
					continue
				seen[index] = 1
				count += 1
				box = box.expand(quad.position + at + Vector2i.ONE)
				stack.append(Vector2i(at.x + 1, at.y))
				stack.append(Vector2i(at.x - 1, at.y))
				stack.append(Vector2i(at.x, at.y + 1))
				stack.append(Vector2i(at.x, at.y - 1))
			if count >= ISLAND_LEAST:
				out.append([box, count])
	return out


## The box round the ink inside one quadrant.
func _box(image: Image, quad: Rect2i) -> Rect2i:
	var min_x := quad.end.x
	var min_y := quad.end.y
	var max_x := -1
	var max_y := -1
	for y in range(quad.position.y, quad.end.y):
		for x in range(quad.position.x, quad.end.x):
			if image.get_pixel(x, y).a < INK_ALPHA:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## The sheet with the boxes drawn on it. Cutting art by rule is a thing you look at.
func _proof(image: Image, boxes: Dictionary) -> void:
	var proof := image.duplicate() as Image
	for name: String in boxes:
		var box: Rect2i = boxes[name]
		for x in box.size.x:
			proof.set_pixel(box.position.x + x, box.position.y, Color(1.0, 0.2, 0.4))
			proof.set_pixel(box.position.x + x, box.end.y - 1, Color(1.0, 0.2, 0.4))
		for y in box.size.y:
			proof.set_pixel(box.position.x, box.position.y + y, Color(1.0, 0.2, 0.4))
			proof.set_pixel(box.end.x - 1, box.position.y + y, Color(1.0, 0.2, 0.4))
	proof.save_png(ProjectSettings.globalize_path(DEBUG_PNG))
