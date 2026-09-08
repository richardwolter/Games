## Cuts the angler's sprite sheets into a catalogue.
##
## Easier than the others: these arrived as PNGs with a real alpha channel and on an honest
## grid, so there is nothing to key and nothing to measure a boundary for. What is left is
## worth doing anyway — checking the grid divides evenly, finding each frame's ink so the
## figure can be scaled by how tall it actually draws rather than by its cell, and writing a
## magnified picture to look at.
##
## The rows are the three views the sheets are drawn in: the angler seen from the front, from
## behind, and from the side facing left. There is no right-facing row — the side is mirrored
## for that, which is why the catalogue names the row rather than a compass direction.
##
##   godot --headless --path . --script res://tools/slice_character.gd
extends SceneTree

## Each sheet, and how many frames across it runs. Three rows apiece, in the order below.
const SHEETS := [
	{"name": "idle", "path": "res://assets/Character/Idle.png", "frames": 4},
	{"name": "walk", "path": "res://assets/Character/Walk.png", "frames": 6},
]

## Top to bottom on both sheets.
const ROWS := ["front", "back", "side"]

const CELL := 32

const OUT_PNG := "res://assets/character.png"
const OUT_JSON := "res://assets/character.json"
const DEBUG_PNG := "res://assets/sliced_character.png"

## How much the check-my-work picture is blown up. These are thirty-two pixel sprites and
## nothing about them can be judged at that size.
const ZOOM := 5

## Anything at or over this alpha counts as the figure when its box is measured.
const INK_ALPHA := 0.5


func _init() -> void:
	var sheets: Array = []
	var packed_wide := 0
	var packed_tall := 0
	for sheet: Dictionary in SHEETS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(sheet["path"]))
		if image == null:
			printerr("could not read %s" % sheet["path"])
			quit(1)
			return
		image.convert(Image.FORMAT_RGBA8)
		var across := int(sheet["frames"])
		if image.get_width() != across * CELL or image.get_height() != ROWS.size() * CELL:
			printerr(
				"%s is %dx%d, expected %dx%d"
				% [
					sheet["path"], image.get_width(), image.get_height(),
					across * CELL, ROWS.size() * CELL
				]
			)
			quit(1)
			return
		sheets.append({"art": image, "of": sheet})
		packed_wide = maxi(packed_wide, image.get_width())
		packed_tall += image.get_height()

	var atlas := Image.create(packed_wide, packed_tall, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0.0, 0.0, 0.0, 0.0))

	var poses := {}
	var y := 0
	for entry: Dictionary in sheets:
		var image: Image = entry["art"]
		var of: Dictionary = entry["of"]
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(0, y))
		for row in ROWS.size():
			var frames: Array = []
			for column in int(of["frames"]):
				var box := Rect2i(column * CELL, y + row * CELL, CELL, CELL)
				var ink := _ink(atlas, box)
				if ink.size.x <= 0:
					printerr("%s row %d frame %d is empty" % [of["path"], row, column])
					quit(1)
					return
				frames.append({
					"region": [box.position.x, box.position.y, box.size.x, box.size.y],
					# Where the figure is inside its cell: how tall it draws, and where its
					# feet are. The game stands it on its feet and scales it by its height,
					# neither of which the cell knows.
					"ink": [
						ink.position.x - box.position.x, ink.position.y - box.position.y,
						ink.size.x, ink.size.y
					],
					# And where the head is across the cell, which is not the same question.
					# The angler wears a hat the game draws on rather than a hat painted into
					# the sheet, and the hat has to sit on the head: the figure is centred in
					# its cell from the front and stands a pixel right of centre from the back
					# and the side, so a hat hung on one number is wrong in two views out of
					# three. See `_head_middle`.
					"head": _head_middle(atlas, box, ink),
				})
			poses["%s_%s" % [of["name"], ROWS[row]]] = frames
		y += image.get_height()

	if atlas.save_png(ProjectSettings.globalize_path(OUT_PNG)) != OK:
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
		"size": [atlas.get_width(), atlas.get_height()],
		"poses": poses,
	}, "\t"))
	file.close()

	_debug_picture(atlas, poses)
	printerr("wrote %s: %s" % [OUT_JSON, ", ".join(PackedStringArray(poses.keys()))])
	quit(0)


## The box the drawing actually fills inside its cell.
func _ink(atlas: Image, cell: Rect2i) -> Rect2i:
	var low := Vector2i(cell.position.x + cell.size.x, cell.position.y + cell.size.y)
	var high := Vector2i(cell.position.x - 1, cell.position.y - 1)
	for y in range(cell.position.y, cell.position.y + cell.size.y):
		for x in range(cell.position.x, cell.position.x + cell.size.x):
			if atlas.get_pixel(x, y).a < INK_ALPHA:
				continue
			low.x = mini(low.x, x)
			low.y = mini(low.y, y)
			high.x = maxi(high.x, x)
			high.y = maxi(high.y, y)
	if high.x < low.x or high.y < low.y:
		return Rect2i()
	return Rect2i(low, high - low + Vector2i.ONE)


## How far the head sits from the middle of its cell, in source pixels, right being positive.
##
## Measured off the top third of the figure rather than off the whole of it: the ink box is
## pulled about by an outstretched arm or a leg mid-stride, and what a hat has to agree with
## is the head. A third is enough to be all head and no shoulders on a twenty-pixel figure.
func _head_middle(atlas: Image, cell: Rect2i, ink: Rect2i) -> float:
	var deep := maxi(ink.size.y / 3, 3)
	var low := cell.position.x + cell.size.x
	var high := cell.position.x - 1
	for y in range(ink.position.y, mini(ink.position.y + deep, cell.position.y + cell.size.y)):
		for x in range(cell.position.x, cell.position.x + cell.size.x):
			if atlas.get_pixel(x, y).a < INK_ALPHA:
				continue
			low = mini(low, x)
			high = maxi(high, x)
	if high < low:
		return 0.0
	return (float(low) + float(high) + 1.0) * 0.5 - (float(cell.position.x) + float(cell.size.x) * 0.5)


## The atlas blown up over a grey, with the cell grid on it and every measured ink box.
func _debug_picture(atlas: Image, poses: Dictionary) -> void:
	var shown := Image.create(
		atlas.get_width() * ZOOM, atlas.get_height() * ZOOM, false, Image.FORMAT_RGBA8
	)
	shown.fill(Color(0.4, 0.42, 0.45, 1.0))
	for y in atlas.get_height():
		for x in atlas.get_width():
			var pixel := atlas.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			for dy in ZOOM:
				for dx in ZOOM:
					shown.set_pixel(x * ZOOM + dx, y * ZOOM + dy, pixel)
	for y in shown.get_height():
		for x in shown.get_width():
			if x % (CELL * ZOOM) == 0 or y % (CELL * ZOOM) == 0:
				shown.set_pixel(x, y, Color(0.35, 0.6, 1.0))
	for name: String in poses:
		for frame: Dictionary in poses[name]:
			var region: Array = frame["region"]
			var ink: Array = frame["ink"]
			_outline(
				shown,
				Rect2i(
					(region[0] + ink[0]) * ZOOM, (region[1] + ink[1]) * ZOOM,
					ink[2] * ZOOM, ink[3] * ZOOM
				),
				Color(1.0, 0.45, 0.2)
			)
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
