## Cuts the packed art sheets in assets/ into a catalogue of individual pieces.
##
## The sheets are pixel art on a 16 px grid with the items butted up against each other,
## so "which pixels are one object" is not written down anywhere — it has to be found. The
## finding is done here, once, offline, and written out as assets/pieces.json: the game
## reads the catalogue and never runs this.
##
## The method is a join count over the 16 px grid the art was drawn on. Two neighbouring
## cells belong to the same item when the boundary between them is solid most of the way
## across; where two items merely touch, only a few pixels cross. Each group of joined
## cells is one item, and its box is then shrunk back onto its own pixels.
##
## A plain flood fill does not work here, which is what the first two attempts were: the
## items are packed edge to edge, so the fill welds a row of sofas into one blob, and
## snapping boxes out to the grid welds even more. Two passes afterwards take apart what
## the cell grouping over-joined — one cutting at lines of empty pixels, one guessing a
## boundary where two items genuinely touch.
##
## The catalogue in assets/pieces.json has been corrected by hand since it was last cut:
## the pieces nobody wanted are gone, and the toilet region was narrowed onto the one bowl
## the slicer had welded to its neighbour. Re-running this overwrites all of that, and the
## piece names are positional, so a re-slice also renumbers every save keyed on them. Cut a
## fresh sheet with it; do not re-cut the ones already in the game.
##
## It also owns only its own half of the catalogue's contents and writes the whole file, so
## a re-run drops the decoration pieces and the lake_objects sheet, neither of which is cut
## here. Run tools/build_decor.py afterwards to put the decoration half back.
##
## Run it with:
##   godot --headless --path . --script res://tools/slice_sheets.gd
extends SceneTree

## The grid the art is drawn on.
const CELL := 16

## Cells and boxes with less drawn in them than this are anti-aliasing crumbs and stray
## shadow pixels, not items.
const MIN_AREA := 12

## How many pixels of a cell boundary have to be solid on both sides for the two cells to
## be parts of one item. A sixteen-pixel boundary, so this is "most of the way across":
## two items that touch brush along a few pixels, and the inside of one item does not.
const JOIN_PIXELS := 7

## A box this thin in either direction is an offcut of something bigger — a lamp stem, a
## stove flue — rather than an item, and is welded back onto whatever it stands against.
const SLIVER_SIDE := 13

## How much bigger than a sliver its neighbour has to be before the sliver is welded onto it.
##
## Without it, a row of small things that touch each other welds itself into one long piece:
## four frying pans hung handle to handle came out as a single sixty-four pixel item, and the
## lake floated it as one enormous pan. A sliver is an offcut of something — a pole, a stem,
## a flue — so what it belongs to is properly bigger than it is. Two of anything the same
## size are two things.
const WELD_BIGGER := 2.0

## Anything at or under this alpha is background. Not zero: these sheets have a few pixels
## of near-transparent fringe, and treating those as solid welds neighbouring items.
const CLEAR_ALPHA := 0.35

const OUT_PATH := "res://assets/pieces.json"

## Where the check-my-work picture goes: the sheet with every region it found outlined on
## it. Cutting art by rule is a thing you have to look at, not a thing you assert.
const DEBUG_PATH := "res://assets/sliced_%s.png"

## A region wider or taller than this many cells is assumed to be two items that touch, and
## is offered to the seam finder. Most things on these sheets are one to three cells; the
## kitchen run is longer, and splitting it into its cabinets is what we want anyway.
const MAX_CELLS := 3

## How many solid pixels may cross a cut line for it to count as a seam between two items
## rather than the middle of one. Also allowed as a fraction of the cut's own length, so a
## tall seam is judged by how clear it is rather than by an absolute count.
const SEAM_PIXELS := 4

## The narrowest an item is allowed to be, in pixels. A cut that would leave a sliver
## thinner than this is cutting through something rather than between two things.
const MIN_SIDE := 5
const SEAM_FRACTION := 0.5

## Past this many cells a region is not an item at any reading — the sheets have nothing
## that big — so it is cut at its thinnest boundary whether or not that boundary looks like
## a seam. This is what takes the kitchen run apart into its cabinets.
const FORCE_CELLS := 5

## The sheets, and the prefix their pieces are named with.
##
## The TopDownHouse furniture pair is gone from here. Those two sheets were the collection —
## one grimy layout and the same layout in a clean palette — and the decoration art
## replaced both: it draws its finds twice at different sizes, packs them offline, and is
## authored piece by piece rather than guessed at by a slicer. See tools/build_decor.py.
const SHEETS := [
	{"file": "res://assets/TopDownHouse_SmallItems.png", "key": "small"},
]


func _init() -> void:
	var out := {"cell": CELL, "sheets": {}, "pieces": []}
	for sheet: Dictionary in SHEETS:
		var image := _load(String(sheet["file"]))
		if image == null:
			printerr("could not read %s" % sheet["file"])
			quit(1)
			return
		out["sheets"][sheet["key"]] = {
			"file": sheet["file"], "size": [image.get_width(), image.get_height()]
		}
		var boxes := _find_pieces(image)
		printerr("%s: %d pieces in %dx%d" % [
			sheet["key"], boxes.size(), image.get_width(), image.get_height()
		])
		_write_debug(image, boxes, String(sheet["key"]))
		var n := 0
		for box: Rect2i in boxes:
			out["pieces"].append({
				"name": "%s_%02d" % [sheet["key"], n],
				"sheet": sheet["key"],
				"region": [box.position.x, box.position.y, box.size.x, box.size.y],
				"cells": [
					int(ceil(float(box.size.x) / float(CELL))),
					int(ceil(float(box.size.y) / float(CELL))),
				],
				# How much of its own box the piece actually covers. A rug is a solid
				# rectangle and fills nearly all of it; a chair is mostly the gaps between
				# its legs. That one number is what tells the shed which things are laid on
				# the floor and which stand on top of them.
				"fill": snappedf(_fill_of(image, box), 0.001),
			})
			n += 1

	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("could not write %s" % OUT_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(out, "\t"))
	file.close()
	printerr("wrote %s: %d pieces" % [OUT_PATH, (out["pieces"] as Array).size()])
	quit(0)


## The sheet with every region outlined on it, at 3x, so the cut can be looked at rather
## than trusted.
func _write_debug(image: Image, boxes: Array[Rect2i], key: String) -> void:
	var shot := image.duplicate() as Image
	shot.convert(Image.FORMAT_RGBA8)
	var mark := Color(1.0, 0.0, 0.9, 1.0)
	for box: Rect2i in boxes:
		for x in range(box.position.x, box.position.x + box.size.x):
			shot.set_pixel(x, box.position.y, mark)
			shot.set_pixel(x, box.position.y + box.size.y - 1, mark)
		for y in range(box.position.y, box.position.y + box.size.y):
			shot.set_pixel(box.position.x, y, mark)
			shot.set_pixel(box.position.x + box.size.x - 1, y, mark)
	shot.resize(shot.get_width() * 3, shot.get_height() * 3, Image.INTERPOLATE_NEAREST)
	shot.save_png(ProjectSettings.globalize_path(DEBUG_PATH % key))


## The fraction of a box's pixels that are drawn on.
func _fill_of(image: Image, box: Rect2i) -> float:
	var solid := 0
	for y in range(box.position.y, box.position.y + box.size.y):
		for x in range(box.position.x, box.position.x + box.size.x):
			if image.get_pixel(x, y).a > CLEAR_ALPHA:
				solid += 1
	return float(solid) / maxf(float(box.size.x * box.size.y), 1.0)


## The image, read straight off disk rather than through the import pipeline: this runs
## before anything is imported, and Image.load_from_file does not need a .import file.
func _load(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


## Every item on a sheet, as a box on the 16 px grid.
##
## One flood fill per unvisited solid pixel gives one blob per item, and blobs whose boxes
## overlap are folded together: an item drawn as two disconnected parts — a lamp and its
## shade, a chair back and its legs — comes out of the fill as two blobs standing in the
## same box, and is one item.
func _find_pieces(image: Image) -> Array[Rect2i]:
	var boxes := _cell_groups(image)
	# The grouping works on whole cells, so anything drawn across a cell line comes back
	# as one lump; these two passes take a lump apart where the pixels prove it is two.
	boxes = _split_gaps(image, boxes)
	boxes = _split_seams(image, boxes)
	boxes = _merge(boxes)
	boxes = _weld_slivers(boxes)
	# Reading order, so a piece's number in the catalogue is where it sits on the sheet.
	boxes.sort_custom(
		func(a: Rect2i, b: Rect2i) -> bool:
			if a.position.y != b.position.y:
				return a.position.y < b.position.y
			return a.position.x < b.position.x
	)
	return boxes


## The items on a sheet, found by asking how strongly each cell of the drawing grid is
## joined to the cell next to it.
##
## This is the part that took a few tries. The art is packed edge to edge, so a flood fill
## over the pixels welds a whole row of sofas into one blob, and growing pixel boxes out to
## the grid welds even more. But two items that merely touch only ever touch along a few
## pixels of their shared cell boundary, while the inside of one item runs the whole way
## across it. Counting those crossings separates the two cases: cells are joined only where
## the join is wide, and each group of joined cells is an item.
func _cell_groups(image: Image) -> Array[Rect2i]:
	var cols := int(ceil(float(image.get_width()) / float(CELL)))
	var rows := int(ceil(float(image.get_height()) / float(CELL)))

	# Which cells have anything in them at all.
	var used := PackedByteArray()
	used.resize(cols * rows)
	for cy in rows:
		for cx in cols:
			used[cy * cols + cx] = 1 if _cell_pixels(image, cx, cy) >= MIN_AREA else 0

	# Union-find over the cells, joined where the boundary between them is solid.
	var parent := PackedInt32Array()
	parent.resize(cols * rows)
	for i in parent.size():
		parent[i] = i
	for cy in rows:
		for cx in cols:
			var here := cy * cols + cx
			if used[here] == 0:
				continue
			if cx + 1 < cols and used[here + 1] == 1 \
					and _column_crossings(image, cx * CELL + CELL, cy * CELL, CELL) >= JOIN_PIXELS:
				_join(parent, here, here + 1)
			if cy + 1 < rows and used[here + cols] == 1 \
					and _row_crossings(image, cy * CELL + CELL, cx * CELL, CELL) >= JOIN_PIXELS:
				_join(parent, here, here + cols)

	# One box per group, shrunk onto its own pixels.
	var found := {}
	for cy in rows:
		for cx in cols:
			var here := cy * cols + cx
			if used[here] == 0:
				continue
			var root := _root(parent, here)
			var cell := Rect2i(cx * CELL, cy * CELL, CELL, CELL)
			found[root] = (found[root] as Rect2i).merge(cell) if found.has(root) else cell

	var boxes: Array[Rect2i] = []
	for key: int in found:
		var box := _trim(image, found[key] as Rect2i)
		if box.size.x * box.size.y >= MIN_AREA:
			boxes.append(box)
	return boxes


## Join thin offcuts back onto whatever they are part of.
##
## The cell grouping asks for a wide join, and some things are not wide: a coat rack is a
## pole two pixels across, a standard lamp is a stem, a stove has a flue. Those come out of
## the grouping as separate slivers standing right against the item they belong to. Nothing
## in this art is a two-pixel-wide item in its own right, so a sliver touching something
## bigger is part of it.
func _weld_slivers(boxes: Array[Rect2i]) -> Array[Rect2i]:
	var out := boxes.duplicate()
	var welded := true
	while welded:
		welded = false
		for i in out.size():
			var thin: bool = mini(out[i].size.x, out[i].size.y) <= SLIVER_SIDE
			if not thin:
				continue
			var best := -1
			var best_area := 0
			var own: int = out[i].size.x * out[i].size.y
			for j in out.size():
				if i == j or not out[i].grow(1).intersects(out[j]):
					continue
				var area: int = out[j].size.x * out[j].size.y
				if float(area) < float(own) * WELD_BIGGER:
					continue
				if area > best_area:
					best_area = area
					best = j
			if best < 0:
				continue
			# A weld that swallows ground belonging to a third item is the wrong weld: two
			# regions sharing pixels means one of them is drawing part of something else.
			var grown: Rect2i = out[best].merge(out[i])
			var trespass := false
			for k in out.size():
				if k != i and k != best and grown.intersects(out[k]):
					trespass = true
					break
			if trespass:
				continue
			out[best] = grown
			out.remove_at(i)
			welded = true
			break
	return out


## How many pixels of a cell are drawn on.
func _cell_pixels(image: Image, cx: int, cy: int) -> int:
	var count := 0
	for y in range(cy * CELL, mini(cy * CELL + CELL, image.get_height())):
		for x in range(cx * CELL, mini(cx * CELL + CELL, image.get_width())):
			if image.get_pixel(x, y).a > CLEAR_ALPHA:
				count += 1
	return count


## Solid pixels running across a vertical line, over a span of rows.
func _column_crossings(image: Image, x: int, from_y: int, span: int) -> int:
	if x <= 0 or x >= image.get_width():
		return 0
	var count := 0
	for y in range(from_y, mini(from_y + span, image.get_height())):
		if image.get_pixel(x - 1, y).a > CLEAR_ALPHA and image.get_pixel(x, y).a > CLEAR_ALPHA:
			count += 1
	return count


## The same across a horizontal line, over a span of columns.
func _row_crossings(image: Image, y: int, from_x: int, span: int) -> int:
	if y <= 0 or y >= image.get_height():
		return 0
	var count := 0
	for x in range(from_x, mini(from_x + span, image.get_width())):
		if image.get_pixel(x, y - 1).a > CLEAR_ALPHA and image.get_pixel(x, y).a > CLEAR_ALPHA:
			count += 1
	return count


func _root(parent: PackedInt32Array, at: int) -> int:
	var node := at
	while parent[node] != node:
		parent[node] = parent[parent[node]]
		node = parent[node]
	return node


func _join(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _root(parent, a)
	var rb := _root(parent, b)
	if ra != rb:
		parent[rb] = ra


## Cut every box apart at any line of empty pixels running right through it.
##
## The flood fill already separates items that do not touch, but the merge step that
## rejoins a lamp with its shade also rejoins things that merely overlap on one axis. This
## undoes that where it can be proved wrong: a column or row with nothing in it is not the
## middle of an object, whatever the boxes say.
func _split_gaps(image: Image, boxes: Array[Rect2i]) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for box: Rect2i in boxes:
		out.append_array(_split_gap(image, box, 0))
	return out


func _split_gap(image: Image, box: Rect2i, depth: int) -> Array[Rect2i]:
	if depth >= 8 or box.size.x < MIN_SIDE * 2 and box.size.y < MIN_SIDE * 2:
		return [box]

	var cut_x := _empty_column(image, box)
	if cut_x >= 0:
		return (
			_split_gap(image, _trim(image, Rect2i(
				box.position, Vector2i(cut_x - box.position.x, box.size.y)
			)), depth + 1)
			+ _split_gap(image, _trim(image, Rect2i(
				Vector2i(cut_x, box.position.y),
				Vector2i(box.position.x + box.size.x - cut_x, box.size.y)
			)), depth + 1)
		)

	var cut_y := _empty_row(image, box)
	if cut_y >= 0:
		return (
			_split_gap(image, _trim(image, Rect2i(
				box.position, Vector2i(box.size.x, cut_y - box.position.y)
			)), depth + 1)
			+ _split_gap(image, _trim(image, Rect2i(
				Vector2i(box.position.x, cut_y),
				Vector2i(box.size.x, box.position.y + box.size.y - cut_y)
			)), depth + 1)
		)
	return [box]


## The first column inside a box with no solid pixel in it, leaving something worth keeping
## on both sides. -1 when the box is solid all the way across.
func _empty_column(image: Image, box: Rect2i) -> int:
	for x in range(box.position.x + MIN_SIDE, box.position.x + box.size.x - MIN_SIDE):
		var clear := true
		for y in range(box.position.y, box.position.y + box.size.y):
			if image.get_pixel(x, y).a > CLEAR_ALPHA:
				clear = false
				break
		if clear:
			return x
	return -1


func _empty_row(image: Image, box: Rect2i) -> int:
	for y in range(box.position.y + MIN_SIDE, box.position.y + box.size.y - MIN_SIDE):
		var clear := true
		for x in range(box.position.x, box.position.x + box.size.x):
			if image.get_pixel(x, y).a > CLEAR_ALPHA:
				clear = false
				break
		if clear:
			return y
	return -1


## Cut oversized boxes apart along the emptiest cell boundary inside them.
##
## The items on these sheets are packed edge to edge, and some of them touch — a run of
## sofas comes out of the flood fill as one blob. Where two items meet there is still a
## near-empty column or row of pixels on the drawing grid, and that is what this looks for:
## the cell boundary crossed by the fewest solid pixels. Nothing is cut unless that count
## is low enough to be a seam rather than the middle of a wardrobe.
func _split_seams(image: Image, boxes: Array[Rect2i]) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for box: Rect2i in boxes:
		out.append_array(_split_one(image, box, 0))
	return out


func _split_one(image: Image, box: Rect2i, depth: int) -> Array[Rect2i]:
	if depth >= 6 or (box.size.x <= MAX_CELLS * CELL and box.size.y <= MAX_CELLS * CELL):
		return [box]

	var best_x := _thinnest_column(image, box)
	var best_y := _thinnest_row(image, box)
	# Split the long way first: a wide box is more likely to be a row of items than a
	# column of them, and cutting across the grain leaves halves that cut again cleanly.
	var down_limit := _seam_limit(box.size.y)
	var across_limit := _seam_limit(box.size.x)
	if box.size.x > FORCE_CELLS * CELL:
		down_limit = 1 << 30
	if box.size.y > FORCE_CELLS * CELL:
		across_limit = 1 << 30
	var cut_x: bool = box.size.x >= box.size.y
	if cut_x and (best_x.x < 0 or best_x.y > down_limit):
		cut_x = false
	elif not cut_x and (best_y.x < 0 or best_y.y > across_limit):
		cut_x = true

	if cut_x and best_x.x >= 0 and best_x.y <= down_limit:
		var left := Rect2i(box.position, Vector2i(best_x.x - box.position.x, box.size.y))
		var right := Rect2i(
			Vector2i(best_x.x, box.position.y),
			Vector2i(box.position.x + box.size.x - best_x.x, box.size.y)
		)
		return _tight(image, left, depth) + _tight(image, right, depth)
	if not cut_x and best_y.x >= 0 and best_y.y <= across_limit:
		var top := Rect2i(box.position, Vector2i(box.size.x, best_y.x - box.position.y))
		var bottom := Rect2i(
			Vector2i(box.position.x, best_y.x),
			Vector2i(box.size.x, box.position.y + box.size.y - best_y.x)
		)
		return _tight(image, top, depth) + _tight(image, bottom, depth)
	return [box]


## How many crossings still count as a seam, for a cut of this length.
func _seam_limit(span: int) -> int:
	return maxi(SEAM_PIXELS, int(float(span) * SEAM_FRACTION))


## Shrink a cut half back onto its own pixels, then see whether it too wants cutting.
func _tight(image: Image, box: Rect2i, depth: int) -> Array[Rect2i]:
	var trimmed := _trim(image, box)
	if trimmed.size.x <= 0 or trimmed.size.y <= 0:
		return []
	return _split_one(image, trimmed, depth + 1)


## The box with its empty margins taken off.
func _trim(image: Image, box: Rect2i) -> Rect2i:
	var min_x := box.position.x + box.size.x
	var max_x := box.position.x - 1
	var min_y := box.position.y + box.size.y
	var max_y := box.position.y - 1
	for y in range(box.position.y, box.position.y + box.size.y):
		for x in range(box.position.x, box.position.x + box.size.x):
			if image.get_pixel(x, y).a <= CLEAR_ALPHA:
				continue
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i(box.position, Vector2i.ZERO)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## The cell boundary inside a box crossed by the fewest solid pixels, as (x, crossings).
## x is -1 when there is no boundary to try.
func _thinnest_column(image: Image, box: Rect2i) -> Vector2i:
	var best := Vector2i(-1, 1 << 30)
	var first := ((box.position.x / CELL) + 1) * CELL
	for x in range(first, box.position.x + box.size.x, CELL):
		# A cut has to leave something on both sides worth calling an item.
		if x - box.position.x < CELL or box.position.x + box.size.x - x < CELL:
			continue
		var crossings := 0
		for y in range(box.position.y, box.position.y + box.size.y):
			if image.get_pixel(x - 1, y).a > CLEAR_ALPHA and image.get_pixel(x, y).a > CLEAR_ALPHA:
				crossings += 1
		if crossings < best.y:
			best = Vector2i(x, crossings)
	return best


func _thinnest_row(image: Image, box: Rect2i) -> Vector2i:
	var best := Vector2i(-1, 1 << 30)
	var first := ((box.position.y / CELL) + 1) * CELL
	for y in range(first, box.position.y + box.size.y, CELL):
		if y - box.position.y < CELL or box.position.y + box.size.y - y < CELL:
			continue
		var crossings := 0
		for x in range(box.position.x, box.position.x + box.size.x):
			if image.get_pixel(x, y - 1).a > CLEAR_ALPHA and image.get_pixel(x, y).a > CLEAR_ALPHA:
				crossings += 1
		if crossings < best.y:
			best = Vector2i(y, crossings)
	return best


## Fold overlapping boxes together until nothing overlaps. Quadratic, on a few dozen boxes,
## run once offline.
func _merge(boxes: Array[Rect2i]) -> Array[Rect2i]:
	var out := boxes.duplicate()
	var merged := true
	while merged:
		merged = false
		for i in out.size():
			for j in range(i + 1, out.size()):
				if not out[i].intersects(out[j]):
					continue
				out[i] = out[i].merge(out[j])
				out.remove_at(j)
				merged = true
				break
			if merged:
				break
	return out
