## The inside of the shed: where everything pulled out of the lake and kept ends up.
##
## The lake is the work and this is what the work is for. Furniture is the one thing in the
## game that is not spent — a find is not sold, it is carried up the beach and put down
## somewhere, and this is the room it is put down in.
##
## One Control draws the whole screen and handles all of its input. That is deliberate: a
## drag that starts on a list and ends on a floor is one gesture, and splitting it across
## two nodes turns it into an exercise in forwarding events. The room is drawn, not built
## out of scene nodes, for the same reason the lake is.
class_name ShedRoom
extends Control

## The grid things are placed on, in source pixels, and how far the room is blown up.
##
## Half the 16 px grid the art was drawn on. Furniture is not drawn to whole cells — a
## chair is twenty-seven pixels across, a stool nineteen — and snapping those to a
## sixteen-pixel grid leaves a margin of dead floor around everything. Eight is fine enough
## that a piece lands where it looks like it should and coarse enough to still snap.
const CELL := 8
const ZOOM := 3

## The floor, in cells.
const COLS := 30
const ROWS := 20

## How wide the inventory column down the right is, in pixels, and how tall one row of it
## is. A row holds one find: its picture and its name.
const LIST_WIDTH := 260
const ROW_HEIGHT := 56

## Gap between the room and the list.
const GUTTER := 24

## How wide a floorboard is, in source pixels. The boards are the room, not the grid: the
## grid is half this and drawing a line every four screen pixels reads as corduroy.
const BOARD := 16

signal changed

## The art, and the two arrays this screen is a view of. Both are owned by lake.gd — the
## room edits `decor` in place rather than keeping a copy, so what is on screen and what
## gets saved cannot drift apart.
var sheets: Sheets
var unlocked: Array[String] = []

## Piece name -> what to call it on screen. Filled in by lake.gd from the defs.
var titles := {}
var decor: Array = []

## What is being dragged, as a piece name, and where it came from: the index it had in
## `decor`, or -1 when it was picked up off the inventory list.
var carrying: StringName = &""
var _carried_from: int = -1
var _pointer := Vector2.ZERO
var _scroll: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(false)


## Everything unlocked that is not already standing in the room.
func in_store() -> Array[String]:
	var placed: Array[String] = []
	for row: Dictionary in decor:
		placed.append(String(row["piece"]))
	var left: Array[String] = []
	for name: String in unlocked:
		if not placed.has(name) and (carrying.is_empty() or String(carrying) != name):
			left.append(name)
	return left


## Where a piece would stand, in cells, if it were dropped at this point on screen.
func cell_at(where: Vector2) -> Vector2i:
	var floor_at := where - _floor_origin()
	return Vector2i(
		int(floor(floor_at.x / float(CELL * ZOOM))), int(floor(floor_at.y / float(CELL * ZOOM)))
	)


## How many cells a piece takes up, on this room's grid.
func span_of(piece: StringName) -> Vector2i:
	return sheets.footprint(piece, CELL) if sheets != null else Vector2i.ONE


## Can this piece stand with its top-left corner in this cell?
##
## The only rule is that it has to be on the floor. Things are deliberately allowed to
## overlap: an armchair belongs on a rug, a lamp belongs beside a table with its base
## tucked under the edge, and a room where nothing may touch anything is a spreadsheet.
## What stops a pile of junk is the drawing order, not a refusal — rugs go down first, and
## everything else is stacked up the room from the back wall.
func can_place(piece: StringName, cell: Vector2i, _ignore: int = -1) -> bool:
	if sheets == null:
		return false
	var span := span_of(piece)
	return cell.x >= 0 and cell.y >= 0 and cell.x + span.x <= COLS and cell.y + span.y <= ROWS


## Put a piece down, if it fits. The one way anything enters `decor`.
func place(piece: StringName, cell: Vector2i) -> bool:
	if not can_place(piece, cell):
		return false
	decor.append({"piece": String(piece), "cell": [cell.x, cell.y]})
	changed.emit()
	return true


## Take a piece back off the floor and into the store.
func take_back(index: int) -> void:
	if index < 0 or index >= decor.size():
		return
	decor.remove_at(index)
	changed.emit()


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_pointer = motion.position
		if not carrying.is_empty():
			queue_redraw()
		return

	var wheel := event as InputEventMouseButton
	if wheel == null:
		return
	if wheel.pressed and wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_by(ROW_HEIGHT)
		return
	if wheel.pressed and wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_by(-ROW_HEIGHT)
		return
	if wheel.button_index != MOUSE_BUTTON_LEFT:
		return

	_pointer = wheel.position
	if wheel.pressed:
		_pick_up()
	else:
		_put_down()
	queue_redraw()


## Press: lift whatever is under the cursor, off the floor or out of the list.
func _pick_up() -> void:
	if not carrying.is_empty():
		return
	var on_floor := _placed_at(_pointer)
	if on_floor >= 0:
		var row: Dictionary = decor[on_floor]
		carrying = StringName(row["piece"])
		_carried_from = on_floor
		decor.remove_at(on_floor)
		changed.emit()
		return
	var from_list := _listed_at(_pointer)
	if not from_list.is_empty():
		carrying = StringName(from_list)
		_carried_from = -1


## Release: stand it where the cursor is, or put it back in the store. A drop that does not
## fit is not an error — the piece simply goes back on the shelf, and the player tries
## somewhere else.
func _put_down() -> void:
	if carrying.is_empty():
		return
	var piece := carrying
	carrying = &""
	_carried_from = -1
	if _over_floor(_pointer):
		place(piece, _drop_cell(piece))
	else:
		# Back to the store, which is where anything not on the floor already is.
		changed.emit()


## The cell a dragged piece would land in: the piece is carried by its middle, which is
## where the cursor holds it, so the corner is half its span up and left of that.
func _drop_cell(piece: StringName) -> Vector2i:
	var span := span_of(piece)
	var middle := cell_at(_pointer)
	return middle - Vector2i(span.x / 2, span.y / 2)


func _scroll_by(amount: float) -> void:
	var rows := in_store().size()
	var span := maxf(float(rows * ROW_HEIGHT) - (size.y - 96.0), 0.0)
	_scroll = clampf(_scroll + amount, 0.0, span)
	queue_redraw()


## Which placed item is under a point, as an index into `decor`, or -1. Walked backwards so
## the item drawn on top is the one picked up.
func _placed_at(where: Vector2) -> int:
	if sheets == null or not _over_floor(where):
		return -1
	# Topmost first, which is the order they are drawn in reverse: what the player can see
	# is what they get hold of, and a rug under a table is not what they are pointing at.
	var cell := cell_at(where)
	var order := _stacking()
	for at_index in range(order.size() - 1, -1, -1):
		var i: int = order[at_index]
		var row: Dictionary = decor[i]
		var at := Vector2i(int(row["cell"][0]), int(row["cell"][1]))
		if Rect2i(at, span_of(StringName(row["piece"]))).has_point(cell):
			return i
	return -1


## The order things are drawn in: rugs and mats first, then everything else from the back
## of the room forward, so a chair standing in front of a table overlaps it.
func _stacking() -> Array:
	var order := range(decor.size())
	order.sort_custom(
		func(a: int, b: int) -> bool:
			var piece_a := StringName(decor[a]["piece"])
			var piece_b := StringName(decor[b]["piece"])
			var flat_a := sheets.lies_flat(piece_a)
			var flat_b := sheets.lies_flat(piece_b)
			if flat_a != flat_b:
				return flat_a
			var foot_a: int = int(decor[a]["cell"][1]) + span_of(piece_a).y
			var foot_b: int = int(decor[b]["cell"][1]) + span_of(piece_b).y
			return foot_a < foot_b
	)
	return order


## Which stored piece is under a point, or "" for none.
func _listed_at(where: Vector2) -> String:
	var list := _list_rect()
	if not list.has_point(where):
		return ""
	var index := int((where.y - list.position.y + _scroll) / float(ROW_HEIGHT))
	var store := in_store()
	if index < 0 or index >= store.size():
		return ""
	return store[index]


## What a find is called, falling back to its catalogue key.
func title_of(piece: String) -> String:
	return String(titles.get(piece, piece))


func _over_floor(where: Vector2) -> bool:
	return _floor_rect().has_point(where)


func _floor_origin() -> Vector2:
	return _floor_rect().position


func _floor_rect() -> Rect2:
	var span := Vector2(float(COLS * CELL * ZOOM), float(ROWS * CELL * ZOOM))
	var room := Vector2(size.x - float(LIST_WIDTH + GUTTER), size.y)
	return Rect2(((room - span) * 0.5).floor().max(Vector2(16.0, 16.0)), span)


func _list_rect() -> Rect2:
	return Rect2(
		Vector2(size.x - float(LIST_WIDTH), 72.0),
		Vector2(float(LIST_WIDTH), maxf(size.y - 96.0, 0.0))
	)


func _draw() -> void:
	if sheets == null:
		return
	var ink := Color(0.11, 0.09, 0.1)
	var floor_box := _floor_rect()

	# The room: a back wall standing above the floor, so the space has a direction and the
	# furniture has something to be against.
	var wall := Rect2(
		floor_box.position - Vector2(0.0, float(BOARD * ZOOM)),
		Vector2(floor_box.size.x, float(BOARD * ZOOM))
	)
	draw_rect(wall, Color(0.30, 0.26, 0.24))
	draw_rect(wall, ink, false, 2.0)

	# Floorboards, run the long way, with a seam every other cell. Drawn rather than
	# authored, like everything else in this game.
	draw_rect(floor_box, Color(0.47, 0.36, 0.26))
	var board := float(BOARD * ZOOM)
	var boards := int(ceil(floor_box.size.y / board))
	for row in boards:
		var y := floor_box.position.y + float(row) * board
		draw_rect(
			Rect2(floor_box.position.x, y, floor_box.size.x, minf(board, floor_box.end.y - y)),
			Color(0.50, 0.39, 0.28) if row % 2 == 0 else Color(0.44, 0.34, 0.25)
		)
		draw_line(
			Vector2(floor_box.position.x, y), Vector2(floor_box.end.x, y),
			Color(0.0, 0.0, 0.0, 0.14), 1.0
		)
	draw_rect(floor_box, ink, false, 2.0)

	# The cells, faintly, while something is being carried: the drop is snapped, and the
	# player should be able to see what it is snapping to.
	if not carrying.is_empty():
		for col in range(1, COLS):
			var x := floor_box.position.x + float(col * CELL * ZOOM)
			draw_line(
				Vector2(x, floor_box.position.y), Vector2(x, floor_box.end.y),
				Color(1.0, 1.0, 1.0, 0.05), 1.0
			)
		for row_line in range(1, ROWS):
			var y := floor_box.position.y + float(row_line * CELL * ZOOM)
			draw_line(
				Vector2(floor_box.position.x, y), Vector2(floor_box.end.x, y),
				Color(1.0, 1.0, 1.0, 0.05), 1.0
			)

	# What is in the room, laid down before it is stood on.
	for i: int in _stacking():
		var row: Dictionary = decor[i]
		_stamp_piece(
			StringName(row["piece"]),
			floor_box.position + Vector2(
				float(int(row["cell"][0]) * CELL * ZOOM), float(int(row["cell"][1]) * CELL * ZOOM)
			)
		)

	_draw_list(ink)

	# The piece in hand, under the cursor, tinted by whether it can go where it is.
	if not carrying.is_empty():
		var span := span_of(carrying)
		if _over_floor(_pointer):
			var cell := _drop_cell(carrying)
			var fits := can_place(carrying, cell)
			var at := floor_box.position + Vector2(
				float(cell.x * CELL * ZOOM), float(cell.y * CELL * ZOOM)
			)
			draw_rect(
				Rect2(at, Vector2(span) * float(CELL * ZOOM)),
				Color(0.4, 0.9, 0.5, 0.20) if fits else Color(0.9, 0.3, 0.3, 0.20)
			)
			_stamp_piece(carrying, at, Color(1.0, 1.0, 1.0, 0.85 if fits else 0.5))
		else:
			_stamp_piece(
				carrying, _pointer - sheets.region_of(carrying).size * float(ZOOM) * 0.5,
				Color(1.0, 1.0, 1.0, 0.75)
			)


## The store down the right: everything found and not yet standing anywhere.
func _draw_list(ink: Color) -> void:
	var list := _list_rect()
	draw_rect(list.grow(8.0), Color(0.10, 0.12, 0.11, 0.65))
	draw_rect(list.grow(8.0), ink, false, 1.5)

	var store := in_store()
	var font := ThemeDB.fallback_font
	draw_string(
		font, list.position + Vector2(4.0, -18.0),
		"Shed inventory  (%d)" % store.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18
	)
	if store.is_empty():
		draw_string(
			font, list.position + Vector2(8.0, 28.0), "Nothing kept yet.",
			HORIZONTAL_ALIGNMENT_LEFT, int(list.size.x) - 16, 15, Color(0.8, 0.8, 0.8, 0.7)
		)
		return

	for i in store.size():
		var top := list.position.y + float(i * ROW_HEIGHT) - _scroll
		if top + float(ROW_HEIGHT) < list.position.y or top > list.end.y:
			continue
		var box := Rect2(list.position.x, top, list.size.x, float(ROW_HEIGHT) - 4.0)
		draw_rect(box, Color(1.0, 1.0, 1.0, 0.05))
		var region := sheets.alt_region_of(StringName(store[i]))
		# Fitted into the row rather than drawn at its own size: a wardrobe and a mug both
		# have to read as one line of a list.
		var fit := minf(
			(float(ROW_HEIGHT) - 12.0) / maxf(region.size.x, region.size.y), float(ZOOM)
		)
		draw_texture_rect_region(
			sheets.atlas,
			Rect2(box.position + Vector2(8.0, 6.0), region.size * fit), region, Color.WHITE
		)
		draw_string(
			font, box.position + Vector2(64.0, 30.0), title_of(store[i]),
			HORIZONTAL_ALIGNMENT_LEFT, int(box.size.x) - 72, 15
		)


## One piece of furniture, in its cleaned-up palette, standing with its corner at a point.
func _stamp_piece(piece: StringName, at: Vector2, tint: Color = Color.WHITE) -> void:
	var region := sheets.alt_region_of(piece)
	draw_texture_rect_region(
		sheets.atlas, Rect2(at, region.size * float(ZOOM)), region, tint
	)
