## The wash room: what opens when the angler works the pump (issue #37).
##
## A `WashBackdrop` — the view from the pump — with the `WashStand` over the whole window on
## top of it, and a tray of what is waiting to be washed down its
## left side, in the shed shelf's own wood. Click a find on the tray and it goes on the stand;
## wash it and it goes to the shed. **Must wash to place**: a netted find waits here, not on
## the shed's shelf, until it has been through this room.
##
## **Soap is flavour, not a sink** (Richard, 2026-09-18): 5, 10 or 15 by how big the find's
## picture is, in thirds of the catalogue — about 400 over a whole run against the 870k the
## lake holds. **Checked when a find is picked, charged when it comes clean**: walking away
## from a half-washed find costs nothing and puts its whole coat back, the same coat, and the
## save knows only washed or not. A purse that cannot cover a find's soap leaves its row
## drawn back and deaf, and the find waits.
##
## Holds no state of the lake's: it is lent the waiting list and asks the purse through a
## callable, and says `washed` when there is something to pay for and keep.
class_name WashRoom
extends Control

const Style := preload("res://scripts/style.gd")

## A find came clean: `piece`, and what its soap cost.
signal washed(piece: StringName, soap: int)
signal close_asked

const SOAP := [5, 10, 15]

const TRAY_AT := Vector2(28.0, 132.0)
const TRAY_WIDE := 268.0
const TRAY_FRAME := 10.0
const TRAY_RIBBON := 36.0
const ROW_TALL := 50.0
const ROW_GAP := 5.0
const ROW_PAD := 8.0
const ROWS_MOST := 9
const ICON := 40.0
const CLOSE_SIDE := 44.0
const TITLE := "To wash"
const EMPTY_LINES := ["Nothing waiting.", "Net a find and", "bring it here."]

var sheets: Sheets
## The lake's own list of what waits, oldest first. Read, never written.
var waiting: Array[String] = []
## How much is in the purse right now.
var purse := Callable()

## The lake's day, for the backdrop's sky and tint, and how much of the lake's filth is
## left, asked once each time the room comes up. Both optional: without them it is a late
## morning over a filthy lake.
var day: DayCycle
var filth_left := Callable()
## How many dogs the pack holds, asked each time the room comes up, and the lake's flock,
## for its sheet and its birds: the backdrop's own dogs and pigeons. Optional too.
var pack_size := Callable()
var flock: Flock
## How many ferries the fleet holds, and the lake's rubbish as `{sheet, region}` rows: what
## is on the backdrop's water.
var fleet_size := Callable()
var rubbish: Array = []

var _backdrop: WashBackdrop
var _stand: WashStand
var _tray: Tray
var _close: CloseButton
var _on_stand := &""
var _scroll := 0
var _thirds := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = WashBackdrop.new()
	_backdrop.name = &"Backdrop"
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stand = WashStand.new()
	_stand.name = &"Stand"
	_stand.bare_room = not _backdrop.is_painted()
	_stand.sheets = sheets
	_stand.washed.connect(_on_washed)
	add_child(_stand)
	_stand.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tray = Tray.new()
	_tray.name = &"Tray"
	_tray.room = self
	add_child(_tray)
	_close = CloseButton.new()
	_close.name = &"Close"
	_close.pressed.connect(func() -> void: close_asked.emit())
	add_child(_close)
	resized.connect(_lay_out)
	_lay_out()


## The room coming up, or going away. Going away takes whatever is on the stand off it,
## unwashed and unpaid for.
func open(up: bool) -> void:
	visible = up
	if _backdrop != null:
		if up and filth_left.is_valid():
			_backdrop.filth = float(filth_left.call())
		if up and pack_size.is_valid():
			_backdrop.pack = int(pack_size.call())
		if up and fleet_size.is_valid():
			_backdrop.fleet = int(fleet_size.call())
		if up:
			_backdrop.rubbish = rubbish
		if up and flock != null:
			_backdrop.bird_sheet = flock.sheet()
			_backdrop.bird_kinds = flock.kinds()
		_backdrop.reset()
	_on_stand = &""
	_scroll = 0
	if _stand != null:
		_stand.clear()
	_lay_out()


## What is on the stand, or empty.
func on_stand() -> StringName:
	return _on_stand


func backdrop() -> WashBackdrop:
	return _backdrop


## The stand itself, for a harness to spray with.
func stand() -> WashStand:
	return _stand


## Whether a catalogue name is a find at all. Every piece has a `views` entry, the rubbish's
## empty, and the sheets still carry a few nameless offcuts with pictures and no title — so
## a find is what has both a restored picture and a name.
static func is_find(book: Sheets, name: String) -> bool:
	if book == null or (book.views.get(name, []) as Array).is_empty():
		return false
	return not book.title_of(StringName(name)).is_empty()


## What a find's soap costs: the catalogue's restored pictures sorted by area and cut in
## thirds. Worked out once, off the art, so a find added later prices itself.
func soap_of(piece: StringName) -> int:
	if sheets == null:
		return SOAP[0]
	if _thirds == Vector2.ZERO:
		var areas: Array[float] = []
		for name: String in sheets.names:
			if is_find(sheets, name):
				areas.append(sheets.view_region_of(StringName(name), 0).get_area())
		areas.sort()
		if areas.is_empty():
			return SOAP[0]
		_thirds = Vector2(areas[areas.size() / 3], areas[areas.size() * 2 / 3])
	var area := sheets.view_region_of(piece, 0).get_area()
	if area < _thirds.x:
		return SOAP[0]
	return SOAP[1] if area < _thirds.y else SOAP[2]


func can_afford(piece: StringName) -> bool:
	var held := float(purse.call()) if purse.is_valid() else 0.0
	return held >= float(soap_of(piece))


## Put one of the waiting finds on the stand. False when it is not waiting or the purse
## cannot cover its soap. A find already on the stand goes back on the tray, coat and all.
func pick(piece: StringName) -> bool:
	if not waiting.has(String(piece)) or not can_afford(piece):
		return false
	_on_stand = piece
	_stand.put(piece)
	return true


func _on_washed(piece: StringName) -> void:
	washed.emit(piece, soap_of(piece))


func _process(_delta: float) -> void:
	if not visible:
		return
	if day != null:
		if absf(_backdrop.sun - day.sun) > 0.002:
			_backdrop.sun = day.sun
		if not _backdrop.tint.is_equal_approx(day.tint):
			_backdrop.tint = day.tint
		_stand.shade = Vector3(day.lean, day.stretch, day.ink)
		_backdrop.shade = _stand.shade
	_stand.ground_tone = _backdrop.modulate
	# The jet off the find is the backdrop's to answer: its birds and dogs take fright.
	var wet := _stand.jet_past_piece()
	if wet != Vector2.INF:
		_backdrop.sprayed_at(wet)
	# The shine has run: the stand is cleared for the next one.
	if _on_stand != &"" and _stand.state == WashStand.State.CLEAN:
		_on_stand = &""
		_stand.clear()
	_lay_out()
	_tray.queue_redraw()


func _rows_shown() -> int:
	return clampi(waiting.size(), 1, ROWS_MOST)


func tray_box() -> Rect2:
	var rows := _rows_shown()
	var tall := TRAY_RIBBON * 0.5 + ROW_PAD * 2.0 + TRAY_FRAME * 2.0 \
			+ rows * ROW_TALL + (rows - 1) * ROW_GAP
	if waiting.is_empty():
		tall = TRAY_RIBBON * 0.5 + TRAY_FRAME * 2.0 + 96.0
	return Rect2(TRAY_AT, Vector2(TRAY_WIDE, tall))


func _ribbon_box() -> Rect2:
	var box := tray_box()
	return Rect2(box.position.x, box.position.y - TRAY_RIBBON * 0.5, box.size.x, TRAY_RIBBON)


## The rows' rectangles, in the room's coordinates, in step with `waiting` from `_scroll`.
func row_boxes() -> Array[Rect2]:
	var face := Style.board_face(tray_box(), TRAY_FRAME)
	var top := face.position.y + TRAY_RIBBON * 0.5 + ROW_PAD
	var out: Array[Rect2] = []
	for k in mini(waiting.size() - _scroll, ROWS_MOST):
		out.append(Rect2(
			face.position.x + ROW_PAD, top + k * (ROW_TALL + ROW_GAP),
			face.size.x - ROW_PAD * 2.0, ROW_TALL
		))
	return out


func _lay_out() -> void:
	if _tray == null:
		return
	_scroll = clampi(_scroll, 0, maxi(waiting.size() - ROWS_MOST, 0))
	var box := tray_box().merge(_ribbon_box())
	_tray.position = box.position
	_tray.size = box.size
	var cross := Style.close_on(_ribbon_box(), CLOSE_SIDE)
	_close.position = cross.position
	_close.size = cross.size


func _scroll_by(rows: int) -> void:
	_scroll = clampi(_scroll + rows, 0, maxi(waiting.size() - ROWS_MOST, 0))


## The tray: its own control only so it takes the clicks that land on it and the stand takes
## the rest. It draws off the room's own rectangles, so drawn rows and clicked rows are one.
class Tray:
	extends Control

	const Style := preload("res://scripts/style.gd")

	var room: WashRoom
	var _hover := -1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_exited.connect(func() -> void: _hover = -1)

	func _row_at(at: Vector2) -> int:
		var boxes := room.row_boxes()
		for k in boxes.size():
			if boxes[k].has_point(at + position):
				return k
		return -1

	func _gui_input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		if motion != null:
			var over := _row_at(motion.position)
			if over != _hover and over != -1:
				Sfx.ui(&"ui_hover")
			_hover = over
			return
		var button := event as InputEventMouseButton
		if button == null or not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			room._scroll_by(1)
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP:
			room._scroll_by(-1)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			var row := _row_at(button.position)
			if row == -1:
				return
			var piece := StringName(room.waiting[room._scroll + row])
			if room.pick(piece):
				Sfx.ui(&"ui_click")
		accept_event()

	func _draw() -> void:
		var off := -position
		var board := room.tray_box()
		board.position += off
		var ribbon := room._ribbon_box()
		ribbon.position += off
		Style.board_wood(self, board, TRAY_FRAME, 3)
		var count := room.waiting.size()
		var title := TITLE if count == 0 else "%s  %d" % [TITLE, count]
		Style.board_ribbon(
			self, ribbon, title, 2, Style.TEXT_BODY, Style.title_room(ribbon, CLOSE_SIDE)
		)
		if count == 0:
			var face := Style.board_face(board, TRAY_FRAME)
			for k in EMPTY_LINES.size():
				Style.write(
					self, EMPTY_LINES[k], Style.TEXT_SMALL,
					Vector2(0.0, face.position.y + TRAY_RIBBON * 0.5 + 30.0 + k * 20.0),
					Style.BOARD_INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, face
				)
			return
		var boxes := room.row_boxes()
		for k in boxes.size():
			var box := boxes[k]
			box.position += off
			_draw_row(box, StringName(room.waiting[room._scroll + k]), k == _hover)

	func _draw_row(box: Rect2, piece: StringName, hovered: bool) -> void:
		var can := room.can_afford(piece)
		var standing := piece == room.on_stand()
		var face := Style.BOARD_ROW if can else Style.BOARD_ROW_OFF
		if standing:
			face = Style.ON_WATER
		draw_rect(box, face)
		if can and (hovered or standing):
			Style.lit_edge(self, box, face)
		var ink := Style.BOARD_INK if can else Style.BOARD_INK_SOFT
		# The find as the lake showed it: grimy. What it looks like clean is the reward.
		var cut := room.sheets.region_of(piece)
		var fit := minf(ICON / cut.size.x, ICON / cut.size.y)
		var drawn := cut.size * fit
		var slot := Rect2(box.position + Vector2(6.0, (box.size.y - ICON) * 0.5), Vector2(ICON, ICON))
		draw_texture_rect_region(
			room.sheets.atlas, Rect2(slot.get_center() - drawn * 0.5, drawn), cut
		)
		var price := "$%d" % room.soap_of(piece)
		var price_wide := Style.measure(price, Style.TEXT_BODY).x
		var words := Rect2(
			slot.end.x + 8.0, box.position.y, box.size.x - ICON - 30.0 - price_wide, box.size.y
		)
		var name := _cut_to(room.sheets.title_of(piece), Style.TEXT_SMALL, words.size.x)
		Style.write(
			self, name, Style.TEXT_SMALL, Vector2(0.0, box.position.y + 22.0), ink,
			HORIZONTAL_ALIGNMENT_LEFT, words
		)
		Style.write(
			self, "soap" if not standing else "washing", Style.TEXT_TINY,
			Vector2(0.0, box.position.y + 39.0), ink, HORIZONTAL_ALIGNMENT_LEFT, words
		)
		Style.write(
			self, price, Style.TEXT_BODY,
			Vector2(box.end.x - price_wide - 8.0, box.position.y + 31.0),
			Style.PRICE_INK if can else ink
		)

	## A name that does not fit is cut with an ellipsis: `Style.write` has no clip box.
	func _cut_to(text: String, size_px: int, room_wide: float) -> String:
		if Style.measure(text, size_px).x <= room_wide:
			return text
		var cut := text
		while cut.length() > 1 and Style.measure(cut + "…", size_px).x > room_wide:
			cut = cut.left(cut.length() - 1)
		return cut.strip_edges() + "…"
