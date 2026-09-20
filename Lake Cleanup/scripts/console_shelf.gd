extends Control
class_name ConsoleShelf

const Style := preload("res://scripts/style.gd")

## The console collection, as a shelf the player arranges.
##
## A console is a find like the furniture (Richard, 2026-09-19): netted out of the lake,
## washed at the pump, and then it lives here. The shed gets a shelf piece and working it
## opens this screen — one state, two views, so what is drawn small in the room is what is
## arranged here.
##
## Twenty slots for twenty consoles, so the choosing is arrangement rather than curation:
## every console has somewhere to go, and which shelf and which end is the player's.
##
## Drawn in code out of `Style`'s oak, like every other board in the game.
##
## A spike. Nothing here is wired into the lake, the save or the pump yet.

const BOOK_PATH := "res://assets/consoles.json"

## Slots across. Twenty consoles over four shelves of five, which is the sheet's own
## layout and reads as one generation a shelf.
const ACROSS := 5

## The shelves are evenly spaced and a console taller than one pitch overlaps the shelf
## above it, by decision. Laid out to the tallest console in each row the four shelves want
## 711 design pixels against the 613 a 1280x720 board leaves, and the art cannot be scaled
## down to fit: halving pixel art at this grain destroys the drawing, and a fractional scale
## is not something this game does anywhere. A crammed shelf is what a collection looks like.

## The wood, in the numbers the other boards use.
const FRAME_THICK := 14.0
const CHIPS := 7
const RIBBON_TALL := 34.0

## The gap between a slot's art and the next, and the lip a console stands on.
const SLOT_GAP := 10.0
const LIP_TALL := 7.0
const ROW_GAP := 8.0

## A slot with nothing in it: the boards' own sunken face, so an empty shelf reads as
## shelf rather than as a hole in the board.
const EMPTY_FACE := Style.BUTTON_SUNK

## How far a held console is lifted off the pointer, so the hand is not on top of it.
const CARRY_LIFT := 16.0

## Every console, in the sheet's order: {name, title, region, dirty_region}.
var consoles: Array = []

## Which console is in which slot, by name. "" is an empty slot.
var slots: PackedStringArray = []

## What the player has found. A console not in here is not on the shelf and not in the tray.
var found := {}

var _clean: Texture2D = null
var _dirty: Texture2D = null
var _boxes: Array[Rect2] = []
var _held := -1
var _held_from := -1
var _at := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_book()
	set_process_input(true)


func _load_book() -> void:
	var text := FileAccess.get_file_as_string(BOOK_PATH)
	if text.is_empty():
		push_error("no console book at " + BOOK_PATH)
		return
	var book: Dictionary = JSON.parse_string(text)
	consoles = book.get("consoles", [])
	var sheets: Dictionary = book.get("sheets", {})
	_clean = load(sheets.get("consoles", {}).get("file", ""))
	_dirty = load(sheets.get("consoles_dirty", {}).get("file", ""))
	slots = PackedStringArray()
	for entry in consoles:
		slots.append(entry["name"])


## Everything found, in the sheet's order. The spike's starting state.
func fill_all() -> void:
	found.clear()
	for entry in consoles:
		found[entry["name"]] = true
	queue_redraw()


## Only these names found; the rest leave their slots empty.
func found_only(names: Array) -> void:
	found.clear()
	for n in names:
		found[n] = true
	queue_redraw()


func _entry(name: String) -> Dictionary:
	for e in consoles:
		if e["name"] == name:
			return e
	return {}


func _region_of(name: String) -> Rect2:
	var e := _entry(name)
	if e.is_empty():
		return Rect2()
	var r: Array = e["region"]
	return Rect2(r[0], r[1], r[2], r[3])


## The board, and the face inside its wood.
func _board() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-18.0)


func _face() -> Rect2:
	return Style.board_face(_board(), FRAME_THICK)


## Every slot's box, laid out row by row.
##
## A row is only as tall as the tallest console standing in it, so the handhelds' shelf is
## a short one and the whole collection fits on screen at one art pixel to one. Scaling the
## art to make four even rows fit would be a fractional scale on pixel art, which this game
## does not do anywhere.
func _lay_out() -> void:
	_boxes.clear()
	var face := _face()
	var top := face.position.y + RIBBON_TALL * 0.5 + 12.0
	var wide := face.size.x / float(ACROSS)
	var rows := int(ceil(float(slots.size()) / float(ACROSS)))
	var pitch := (face.end.y - 12.0 - top) / float(maxi(rows, 1))
	for row in rows:
		for col in ACROSS:
			var i := row * ACROSS + col
			if i >= slots.size():
				continue
			_boxes.append(Rect2(
				Vector2(face.position.x + wide * float(col), top + pitch * float(row)),
				Vector2(wide, pitch)
			))


## What the layout came out as, for the probe's log.
func report() -> void:
	_lay_out()
	print("face ", _face(), " board ", _board())
	for i in _boxes.size():
		if i % ACROSS == 0:
			print("  row ", i / ACROSS, " ", _boxes[i])


func _slot_at(point: Vector2) -> int:
	for i in _boxes.size():
		if _boxes[i].has_point(point):
			return i
	return -1


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_at = (event as InputEventMouseMotion).position
		if _held >= 0:
			queue_redraw()
		return
	if event is InputEventMouseButton:
		var press := event as InputEventMouseButton
		if press.button_index != MOUSE_BUTTON_LEFT:
			return
		_at = press.position
		if press.pressed:
			_take(_slot_at(_at))
		else:
			_drop(_slot_at(_at))
		queue_redraw()


func _take(slot: int) -> void:
	if slot < 0 or slot >= slots.size():
		return
	var name := slots[slot]
	if name.is_empty() or not found.has(name):
		return
	_held = slot
	_held_from = slot


func _drop(slot: int) -> void:
	if _held < 0:
		return
	if slot >= 0 and slot < slots.size() and slot != _held_from:
		var moving := slots[_held_from]
		slots[_held_from] = slots[slot]
		slots[slot] = moving
	_held = -1
	_held_from = -1


func _draw() -> void:
	_lay_out()
	var board := _board()
	Style.board_wood(self, board, FRAME_THICK, CHIPS)
	var caught := 0
	for entry in consoles:
		if found.has(entry["name"]):
			caught += 1
	Style.board_ribbon(
		self,
		Rect2(Vector2(board.position.x, board.position.y - RIBBON_TALL * 0.5),
			Vector2(board.size.x, RIBBON_TALL)),
		"CONSOLES   %d / %d" % [caught, consoles.size()],
		CHIPS
	)
	for i in _boxes.size():
		_draw_slot(i)
	if _held >= 0:
		_draw_carried()


func _draw_slot(i: int) -> void:
	var box := _boxes[i]
	var lip := Rect2(
		Vector2(box.position.x + SLOT_GAP * 0.5, box.end.y - LIP_TALL - ROW_GAP),
		Vector2(box.size.x - SLOT_GAP, LIP_TALL)
	)
	var name := slots[i]
	var shown := found.has(name) and _held != i
	if not shown:
		# The empty slot is drawn back rather than hidden: a gap on a shelf is what says
		# there is another console out there.
		Style.plate(
			self,
			Rect2(lip.position - Vector2(0.0, 20.0), Vector2(lip.size.x, 20.0 + lip.size.y)),
			EMPTY_FACE
		)
	if shown:
		_stamp(name, Vector2(box.position.x + box.size.x * 0.5, lip.position.y), 1.0)
	# The shelf itself, over the console's foot, so a console stands on the plank rather
	# than floating in front of it.
	var seed := i * 37 + 11
	Style.plank(self, lip, seed, Style.FRAME, 0.0, Style.v_all(Style.button_bites(lip, seed), lip))


## One console, its bottom middle at `foot`.
func _stamp(name: String, foot: Vector2, alpha: float) -> void:
	if _clean == null:
		return
	var region := _region_of(name)
	if region.size == Vector2.ZERO:
		return
	var at := Vector2(foot.x - region.size.x * 0.5, foot.y - region.size.y).floor()
	draw_texture_rect_region(
		_clean, Rect2(at, region.size), region, Color(1.0, 1.0, 1.0, alpha)
	)


func _draw_carried() -> void:
	var name := slots[_held_from]
	var region := _region_of(name)
	var foot := _at + Vector2(0.0, region.size.y * 0.5 - CARRY_LIFT)
	_stamp(name, foot, 0.92)
