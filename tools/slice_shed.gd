## Cuts the shed out of the shed button, for the one standing on the island.
##
## The button is a wooden plaque with a shed drawn on it and the word SHED under it, and the
## island wants the shed alone. There is no boundary written down for that, but there is one
## drawn: the shed carries a solid black outline all the way round, and the plaque behind it
## does not have anything nearly that dark in it.
##
## So the plaque is flooded away from the button's own border. The fill spreads through
## anything that is not outline and stops dead at the shed's, which leaves the shed, the
## lettering, and nothing else — and the lettering is thrown away by keeping only the largest
## island of what survives. A shed is a great deal bigger than a D.
##
## Writes assets/shed.png, cropped to the shed and transparent everywhere else.
##
##   godot --headless --path . --script res://tools/slice_shed.gd
extends SceneTree

const UI := "res://assets/ui.json"
const OUT_PNG := "res://assets/shed.png"
const DEBUG_PNG := "res://assets/sliced_shed.png"

## How dark a pixel has to be to be the outline the fill must not cross. The plaque's darkest
## grain is a long way lighter than this; the outline is very nearly black.
const EDGE_DARK := 0.13

## How far the outline is thickened before the flood is let loose, in pixels.
##
## The outline is drawn solid but the sheet is a JPEG, and a few pixels along the top of the
## roof came out of it pale enough to read as plaque — so the flood walked in through them
## and took the roof with it. Raising the threshold instead closes those gaps and turns the
## plaque's own plank seams into barriers at the same time, which keeps half the plaque and
## leaves stripes cut through everything. Thickening what is already dark closes the gaps
## without promoting anything that was not an outline to begin with.
const EDGE_GROW := 2

## How much bigger than the lettering the shed has to be for "keep the largest" to be a safe
## rule rather than a lucky one. Only checked, not relied on.
const SHED_SHARE := 3.0

## How far inside the button the flood starts, in pixels.
##
## Not at its edge. The button has a drawn outline of its own all the way round, and a flood
## seeded on that is stopped on its first pixel — which is exactly what happened, and it
## came back with the whole plaque as the shed. Everything outside this inset is written off
## as plaque without asking, since the frame is never part of the shed.
const FRAME_INSET := 45

const ZOOM := 2


func _init() -> void:
	var book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UI))
	if book == null or not book.has("pieces") or not (book["pieces"] as Dictionary).has("shed"):
		printerr("no shed in %s — run slice_ui.gd first" % UI)
		quit(1)
		return
	var image := Image.load_from_file(ProjectSettings.globalize_path(book["sheet"]))
	if image == null:
		printerr("could not read %s" % book["sheet"])
		quit(1)
		return
	var r: Array = book["pieces"]["shed"]["region"]
	var button := Rect2i(r[0], r[1], r[2], r[3])

	# The button on its own, so everything below counts in its coordinates.
	var cut := Image.create(button.size.x, button.size.y, false, Image.FORMAT_RGBA8)
	cut.blit_rect(image, button, Vector2i.ZERO)

	var wide := cut.get_width()
	var tall := cut.get_height()
	var plaque := _flood(cut)

	# What the flood could not reach: the shed, the word, and any speck of grain the outline
	# happened to enclose. Grouped, and the biggest group kept.
	var blobs := _blobs(cut, plaque)
	if blobs.is_empty():
		printerr("nothing survived the flood")
		quit(1)
		return
	var best := 0
	var second := 0
	var keep := -1
	for i in blobs.size():
		var size: int = (blobs[i] as Dictionary)["size"]
		if size > best:
			second = best
			best = size
			keep = i
		elif size > second:
			second = size
	if second > 0 and float(best) / float(second) < SHED_SHARE:
		printerr(
			"the two biggest pieces are %d and %d — too close to be sure which is the shed"
			% [best, second]
		)
		quit(1)
		return

	var mine: PackedByteArray = (blobs[keep] as Dictionary)["mask"]
	for y in tall:
		for x in wide:
			if mine[y * wide + x] == 0:
				cut.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))

	var box: Rect2i = (blobs[keep] as Dictionary)["box"]
	var shed := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	shed.blit_rect(cut, box, Vector2i.ZERO)
	if shed.save_png(ProjectSettings.globalize_path(OUT_PNG)) != OK:
		printerr("could not write %s" % OUT_PNG)
		quit(1)
		return

	_debug_picture(shed)
	printerr("wrote %s: %dx%d, %d pixels of shed" % [OUT_PNG, box.size.x, box.size.y, best])
	quit(0)


## Everything the plaque reaches from the button's border, spreading through whatever is not
## outline. Returns a mask, one byte a pixel.
func _flood(cut: Image) -> PackedByteArray:
	var wide := cut.get_width()
	var tall := cut.get_height()
	var edge := _edges(cut)
	var seen := PackedByteArray()
	seen.resize(wide * tall)

	# The frame is plaque by definition, and the flood starts on the plank just inside it.
	var inner := Rect2i(
		FRAME_INSET, FRAME_INSET, wide - FRAME_INSET * 2, tall - FRAME_INSET * 2
	)
	for y in tall:
		for x in wide:
			if not inner.has_point(Vector2i(x, y)):
				seen[y * wide + x] = 1

	var stack: Array[Vector2i] = []
	for x in range(inner.position.x, inner.position.x + inner.size.x):
		stack.append(Vector2i(x, inner.position.y))
		stack.append(Vector2i(x, inner.position.y + inner.size.y - 1))
	for y in range(inner.position.y, inner.position.y + inner.size.y):
		stack.append(Vector2i(inner.position.x, y))
		stack.append(Vector2i(inner.position.x + inner.size.x - 1, y))

	while not stack.is_empty():
		var at: Vector2i = stack.pop_back()
		if at.x < 0 or at.y < 0 or at.x >= wide or at.y >= tall:
			continue
		var index := at.y * wide + at.x
		if seen[index] == 1:
			continue
		if edge[index] == 1:
			continue
		seen[index] = 1
		stack.append(Vector2i(at.x + 1, at.y))
		stack.append(Vector2i(at.x - 1, at.y))
		stack.append(Vector2i(at.x, at.y + 1))
		stack.append(Vector2i(at.x, at.y - 1))
	return seen


## The outline, thickened. Everything dark enough to be drawn line rather than wood, plus
## everything within `EDGE_GROW` of it.
func _edges(cut: Image) -> PackedByteArray:
	var wide := cut.get_width()
	var tall := cut.get_height()
	var dark := PackedByteArray()
	dark.resize(wide * tall)
	for y in tall:
		for x in wide:
			var pixel := cut.get_pixel(x, y)
			if pixel.a < 0.5:
				continue
			if pixel.r * 0.3 + pixel.g * 0.59 + pixel.b * 0.11 < EDGE_DARK:
				dark[y * wide + x] = 1

	var grown := dark.duplicate()
	for step in EDGE_GROW:
		var next := grown.duplicate()
		for y in tall:
			for x in wide:
				if grown[y * wide + x] == 0:
					continue
				for d: Vector2i in [
					Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
				]:
					var to := Vector2i(x, y) + d
					if to.x < 0 or to.y < 0 or to.x >= wide or to.y >= tall:
						continue
					next[to.y * wide + to.x] = 1
		grown = next
	return grown


## The separate islands of everything the flood did not reach, each with its own mask, its
## bounding box and how many pixels it holds.
func _blobs(cut: Image, plaque: PackedByteArray) -> Array:
	var wide := cut.get_width()
	var tall := cut.get_height()
	var taken := PackedByteArray()
	taken.resize(wide * tall)
	var out: Array = []

	for start_y in tall:
		for start_x in wide:
			var first := start_y * wide + start_x
			if plaque[first] == 1 or taken[first] == 1:
				continue
			if cut.get_pixel(start_x, start_y).a < 0.5:
				taken[first] = 1
				continue
			var mask := PackedByteArray()
			mask.resize(wide * tall)
			var low := Vector2i(start_x, start_y)
			var high := Vector2i(start_x, start_y)
			var count := 0
			var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]
			while not stack.is_empty():
				var at: Vector2i = stack.pop_back()
				if at.x < 0 or at.y < 0 or at.x >= wide or at.y >= tall:
					continue
				var index := at.y * wide + at.x
				if taken[index] == 1 or plaque[index] == 1:
					continue
				if cut.get_pixel(at.x, at.y).a < 0.5:
					continue
				taken[index] = 1
				mask[index] = 1
				count += 1
				low.x = mini(low.x, at.x)
				low.y = mini(low.y, at.y)
				high.x = maxi(high.x, at.x)
				high.y = maxi(high.y, at.y)
				stack.append(Vector2i(at.x + 1, at.y))
				stack.append(Vector2i(at.x - 1, at.y))
				stack.append(Vector2i(at.x, at.y + 1))
				stack.append(Vector2i(at.x, at.y - 1))
			out.append({
				"mask": mask, "size": count,
				"box": Rect2i(low, high - low + Vector2i.ONE),
			})
	return out


## The cut-out over a colour nothing in it is, blown up: the only way to see whether the
## outline held is to look at what came through it.
func _debug_picture(shed: Image) -> void:
	var big := Image.create(
		shed.get_width() * ZOOM, shed.get_height() * ZOOM, false, Image.FORMAT_RGBA8
	)
	big.fill(Color(0.15, 0.85, 0.35, 1.0))
	for y in shed.get_height():
		for x in shed.get_width():
			var pixel := shed.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			for dy in ZOOM:
				for dx in ZOOM:
					big.set_pixel(x * ZOOM + dx, y * ZOOM + dy, pixel)
	big.save_png(ProjectSettings.globalize_path(DEBUG_PNG))
