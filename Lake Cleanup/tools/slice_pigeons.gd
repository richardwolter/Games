## Cuts the pigeon sheet into cells and writes down where each one is.
##
## The sheet is laid out as a grid — rows of birds, each row holding a few blocks of three
## frames — but the grid is not stated anywhere and the three blocks are drawn at two
## different sprite sizes. So it is measured rather than assumed: rows are the bands of the
## sheet with anything in them, cells are the runs of pixels inside a band, and a gap wider
## than a bird's own width starts a new block.
##
## Writes assets/pigeons.json. tools/pigeon_contact.gd turns that into a labelled picture
## to choose birds from, and scripts/flock.gd flies the ones that are chosen.
##
##   godot --headless --path . --script res://tools/slice_pigeons.gd
extends SceneTree

const SHEET := "res://assets/pigeons/Original Diminsions/Pigeon Sprite Sheet.png"
const OUT_JSON := "res://assets/pigeons.json"

## Anything at or under this alpha is background.
const CLEAR_ALPHA := 0.35

## A band or a cell has to hold at least this many drawn pixels to be a bird rather than
## dust. The sheet's title is dropped by its own rule below.
const MIN_PIXELS := 12

## A horizontal gap this wide between cells is the space between blocks rather than the
## space between two frames of one animation.
const BLOCK_GAP := 6

## The sheet's title is wider than any bird and sits alone at the top. Bands wider than
## this are lettering, not pigeons.
const TITLE_WIDTH := 60


func _init() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if image == null:
		printerr("could not read %s" % SHEET)
		quit(1)
		return

	var cells: Array = []
	var rows := 0
	for band: Vector2i in _bands(image):
		var found := _cells(image, band)
		if found.is_empty():
			continue
		# The title: one very wide run of lettering across the top.
		if found.size() == 1 and (found[0] as Rect2i).size.x > TITLE_WIDTH:
			continue
		var blocks := _blocks(found)
		for block_index in blocks.size():
			var block: Array = blocks[block_index]
			for frame in block.size():
				var box: Rect2i = block[frame]
				cells.append({
					"name": "pigeon_r%02d_b%d_f%d" % [rows, block_index, frame],
					"row": rows,
					"block": block_index,
					"frame": frame,
					"region": [box.position.x, box.position.y, box.size.x, box.size.y],
				})
		rows += 1

	var file := FileAccess.open(OUT_JSON, FileAccess.WRITE)
	if file == null:
		printerr("could not write %s" % OUT_JSON)
		quit(1)
		return
	file.store_string(JSON.stringify({
		"sheet": SHEET,
		"size": [image.get_width(), image.get_height()],
		"rows": rows,
		"cells": cells,
	}, "\t"))
	file.close()
	printerr("wrote %s: %d rows, %d cells" % [OUT_JSON, rows, cells.size()])
	quit(0)


## The horizontal bands of the sheet that have anything drawn in them.
func _bands(image: Image) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var start := -1
	for y in image.get_height():
		var used := _row_used(image, y)
		if used and start < 0:
			start = y
		elif not used and start >= 0:
			out.append(Vector2i(start, y - start))
			start = -1
	if start >= 0:
		out.append(Vector2i(start, image.get_height() - start))
	return out


func _row_used(image: Image, y: int) -> bool:
	for x in image.get_width():
		if image.get_pixel(x, y).a > CLEAR_ALPHA:
			return true
	return false


## The cells inside one band, each shrunk onto its own pixels.
func _cells(image: Image, band: Vector2i) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var start := -1
	for x in image.get_width():
		var used := _column_used(image, x, band)
		if used and start < 0:
			start = x
		elif not used and start >= 0:
			out.append(Rect2i(start, band.x, x - start, band.y))
			start = -1
	if start >= 0:
		out.append(Rect2i(start, band.x, image.get_width() - start, band.y))

	var kept: Array[Rect2i] = []
	for box: Rect2i in out:
		if _pixels_in(image, box) >= MIN_PIXELS:
			kept.append(box)
	return kept


func _column_used(image: Image, x: int, band: Vector2i) -> bool:
	for y in range(band.x, band.x + band.y):
		if image.get_pixel(x, y).a > CLEAR_ALPHA:
			return true
	return false


func _pixels_in(image: Image, box: Rect2i) -> int:
	var count := 0
	for y in range(box.position.y, box.position.y + box.size.y):
		for x in range(box.position.x, box.position.x + box.size.x):
			if image.get_pixel(x, y).a > CLEAR_ALPHA:
				count += 1
	return count


## Split a row of cells into blocks. Frames of one animation sit a pixel or two apart; the
## blocks on this sheet are separated by a clear margin.
func _blocks(cells: Array[Rect2i]) -> Array:
	var out: Array = []
	var block: Array = []
	var last_end := -1000
	for box: Rect2i in cells:
		if not block.is_empty() and box.position.x - last_end > BLOCK_GAP:
			out.append(block)
			block = []
		block.append(box)
		last_end = box.position.x + box.size.x
	if not block.is_empty():
		out.append(block)
	return out
