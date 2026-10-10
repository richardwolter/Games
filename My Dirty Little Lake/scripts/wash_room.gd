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
## The hose plank was pressed with the purse able to cover it: the level bought, and its cost.
signal hose_bought(level: int, cost: int)

## The hose upgrade's price for levels 2 and 3 (2026-10-01, Richard: "mid", about the first
## Strength buy and then mid-run). See `WashStand.HOSE_GROW` for what a level does.
const HOSE_PRICES := [1500, 6000]
const HOSE_MOST := 3


## The hose's top level: two in the Steam demo (2026-10-09, Richard).
static func hose_most() -> int:
	return 2 if Demo.on() else HOSE_MOST
## The plank under the tray, and the gap over it.
const HOSE_TALL := 52.0
const HOSE_GAP := 22.0

const SOAP := [5, 10, 15]

## Down under the HUD's money and Waiting plates, which stay up in the room (2026-10-01).
const TRAY_AT := Vector2(28.0, 172.0)
const TRAY_WIDE := 268.0
const TRAY_FRAME := 10.0
const TRAY_RIBBON := 36.0
const ROW_TALL := 50.0
const ROW_GAP := 5.0
const ROW_PAD := 8.0
const ROWS_MOST := 7
const ICON := 40.0
const CLOSE_SIDE := 44.0
static var TITLE: String:
	get: return Text.WASH_TITLE
static var EMPTY_LINES: Array:
	get: return [Text.WASH_EMPTY_1, Text.WASH_EMPTY_2, Text.WASH_EMPTY_3]

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
## Finds washed for nothing: the new game's bed (the decoration tour, 2026-09-22).
var free: Array[String] = []
## The hose's level, the lake's, pushed in each time the room comes up and after a buy.
var hose_level := 1:
	set(value):
		hose_level = clampi(value, 1, HOSE_MOST)
		if _stand != null:
			_stand.hose_level = hose_level

var _backdrop: WashBackdrop
var _stand: WashStand
var _tray: Tray
var _close: CloseButton
var _hose: HoseRow
var _on_stand := &""
var _scroll := 0
var _thirds := Vector2.ZERO


func _ready() -> void:
	# Walked with the pad's stick (scripts/pad.gd, `pad_focus` below).
	add_to_group(Pad.FOCUS_GROUP)
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
	_hose = HoseRow.new()
	_hose.name = &"Hose"
	_hose.room = self
	add_child(_hose)
	_stand.hose_level = hose_level
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
	if free.has(String(piece)):
		return 0
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
	# The pad's hidden pointer starts the nozzle from the find, not from the tray's row.
	if Pad.is_pad() and is_inside_tree():
		var middle := _stand.piece_box().get_center()
		get_viewport().warp_mouse(_stand.get_global_transform_with_canvas() * middle)
	return true


func _on_washed(piece: StringName) -> void:
	washed.emit(piece, soap_of(piece))


func _process(delta: float) -> void:
	if not visible:
		return
	_pad_aim(delta)
	if day != null:
		if absf(_backdrop.sun - day.sun) > 0.002:
			_backdrop.sun = day.sun
		if not _backdrop.tint.is_equal_approx(day.tint):
			_backdrop.tint = day.tint
		_stand.shade = Vector3(day.lean, day.stretch, day.ink)
		_backdrop.shade = _stand.shade
	_stand.ground_tone = _backdrop.modulate
	# The dogs keep behind the pallet or go round it.
	_backdrop.keep_out = _stand.pallet_rect()
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
	# The wood's real thickness, not TRAY_FRAME twice (2026-09-24, Richard: the row ran into
	# the tray's foot): the built border is 16 over and 14 under, so a board sized on 10 and
	# 10 left its face ten pixels short and the last row sat on the frame.
	var wood := Style.board_wood_tall(TRAY_WIDE, TRAY_FRAME)
	var tall := _ribbon_lip() + ROW_PAD * 2.0 + wood \
			+ rows * ROW_TALL + (rows - 1) * ROW_GAP
	if waiting.is_empty():
		tall = _ribbon_lip() + wood + 96.0
	return Rect2(TRAY_AT, Vector2(TRAY_WIDE, tall))


## How far the title plank's lower half reaches onto the face: it straddles the board's top
## edge, and the frame's own top plank already hides most of that half, so only what is
## left over pushes the rows down. Counted as the whole half, the first row stood twice as
## far from the plank as the last did from the foot.
func _ribbon_lip() -> float:
	var box := Rect2(TRAY_AT, Vector2(TRAY_WIDE, 200.0))
	var frame_top := Style.board_face(box, TRAY_FRAME).position.y - box.position.y
	return maxf(TRAY_RIBBON * 0.5 - frame_top, 0.0)


func _ribbon_box() -> Rect2:
	var box := tray_box()
	return Rect2(box.position.x, box.position.y - TRAY_RIBBON * 0.5, box.size.x, TRAY_RIBBON)


## The rows' rectangles, in the room's coordinates, in step with `waiting` from `_scroll`.
func row_boxes() -> Array[Rect2]:
	var face := Style.board_face(tray_box(), TRAY_FRAME)
	var top := face.position.y + _ribbon_lip() + ROW_PAD
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
	# The stage stands in the middle of what the tray leaves, not of the window.
	if _stand != null:
		_stand.centre_x = (tray_box().end.x + size.x) * 0.5
	var cross := Style.close_on(_ribbon_box(), CLOSE_SIDE)
	_close.position = cross.position
	_close.size = cross.size
	if _hose != null:
		var plank := hose_box()
		_hose.position = plank.position
		_hose.size = plank.size
		_hose.queue_redraw()


## The hose plank: under the tray, its width.
func hose_box() -> Rect2:
	var tray := tray_box()
	return Rect2(tray.position.x, tray.end.y + HOSE_GAP, tray.size.x, HOSE_TALL)


func hose_price() -> int:
	return int(HOSE_PRICES[hose_level - 1]) if hose_level < hose_most() else 0


## The hose row's second line: the level now and the next, or the level alone at the top.
func hose_value() -> String:
	if hose_level >= hose_most():
		return "%d" % hose_level
	return "%d %s %d" % [hose_level, Lake.ARROW, hose_level + 1]


## The hose row's tag: the price, or MAX at the top.
func hose_cost() -> String:
	return Text.SHOP_MAX if hose_level >= hose_most() else "$%d" % hose_price()


## What the hose row says, as one line: for logs and the harness.
func hose_label() -> String:
	return "%s %s %s" % [Text.HOSE_NAME, hose_value(), hose_cost()]


## Where a tray row's price tag may stand: the shop's slot, a share of the row's width at its
## right end, inset as the shop's rows are. The tag itself shrinks onto the figure inside it.
static func price_slot(box: Rect2) -> Rect2:
	var wide := box.size.x * ShopSkin.TAG_SHARE
	return Rect2(
		Vector2(box.end.x - wide - 6.0, box.position.y + 8.0), Vector2(wide, box.size.y - 16.0)
	)


## The hose row's price tag, in the room's coordinates: the one part of the row that buys.
func hose_tag_box() -> Rect2:
	var box := hose_box()
	return ShopSkin.tag_box_of(box, box.size.x * ShopSkin.TAG_SHARE, hose_cost(), Style.TEXT_BODY)


func can_buy_hose() -> bool:
	if hose_level >= hose_most():
		return false
	var held := float(purse.call()) if purse.is_valid() else 0.0
	return held >= float(hose_price())


## Buy the next level, if the purse covers it. The lake takes the money and saves.
func buy_hose() -> bool:
	if not can_buy_hose():
		return false
	var cost := hose_price()
	hose_level += 1
	hose_bought.emit(hose_level, cost)
	return true


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
		var title: String = WashRoom.TITLE if count == 0 else Text.WASH_TITLE_N % count
		Style.board_ribbon(
			self, ribbon, title, 2, Style.TEXT_BODY, Style.title_room(ribbon, CLOSE_SIDE)
		)
		if count == 0:
			var face := Style.board_face(board, TRAY_FRAME)
			for k in WashRoom.EMPTY_LINES.size():
				Style.write(
					self, WashRoom.EMPTY_LINES[k], Style.TEXT_SMALL,
					Vector2(0.0, face.position.y + room._ribbon_lip() + 30.0 + k * 20.0),
					Style.PAPER_SOFT, HORIZONTAL_ALIGNMENT_CENTER, face
				)
			return
		var boxes := room.row_boxes()
		for k in boxes.size():
			var box := boxes[k]
			box.position += off
			_draw_row(box, StringName(room.waiting[room._scroll + k]), k == _hover)

	## A row in the shelf's own plate and the shop's price tag (2026-10-09, `/grill-me` with
	## Richard: the flat boxes were "square and ugly"). The whole row still picks: putting a
	## find on the stand is not paying for it, the soap is taken when it comes clean. A row
	## the purse cannot cover is greyed the shop's way, plate and tag.
	func _draw_row(box: Rect2, piece: StringName, hovered: bool) -> void:
		var can := room.can_afford(piece)
		var standing := piece == room.on_stand()
		var face := Style.BOARD_ROW if can else ShopSkin.drawn_back(Style.BOARD_ROW_OFF)
		if standing:
			face = Style.ON_WATER
		elif hovered and can:
			face = Color(
				face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b
			)
		Style.plate(self, box, face)
		if can and (hovered or standing):
			Style.lit_edge(self, box, face)
		var ink := Style.BOARD_INK if can else ShopSkin.INK_DIM
		# The find as the lake showed it: grimy. What it looks like clean is the reward.
		var cut := room.sheets.region_of(piece)
		var fit := minf(ICON / cut.size.x, ICON / cut.size.y)
		var drawn := cut.size * fit
		var slot := Rect2(box.position + Vector2(6.0, (box.size.y - ICON) * 0.5), Vector2(ICON, ICON))
		draw_texture_rect_region(
			room.sheets.atlas, Rect2(slot.get_center() - drawn * 0.5, drawn), cut
		)
		var soap := room.soap_of(piece)
		var price := "$%d" % soap if soap > 0 else Text.WASH_FREE
		var tag_slot := WashRoom.price_slot(box)
		var tag := ShopSkin.tag_box_of(box, tag_slot.size.x, price, Style.TEXT_BODY)
		var words := Rect2(
			slot.end.x + 8.0, box.position.y, tag.position.x - 6.0 - (slot.end.x + 8.0), box.size.y
		)
		# A long name drops a size before it is cut (2026-10-02, Richard: "Kitchen Coun…"),
		# the shop's own ladder.
		var title := room.sheets.title_of(piece)
		var name_px := Style.TEXT_SMALL
		if Style.measure(title, name_px).x > words.size.x:
			name_px = Style.TEXT_TINY
		var name_y := box.position.y + (box.size.y + float(name_px) * 0.62) * 0.5
		if standing:
			name_y = box.position.y + 22.0
		Style.write(
			self, _cut_to(title, name_px, words.size.x), name_px,
			Vector2(0.0, name_y), ink, HORIZONTAL_ALIGNMENT_LEFT, words
		)
		if standing:
			Style.write(
				self, Text.WASH_WASHING, Style.TEXT_TINY,
				Vector2(0.0, box.position.y + 39.0), ink, HORIZONTAL_ALIGNMENT_LEFT, words
			)
		ShopSkin.draw_tag_on(self, tag_slot, price, Style.TEXT_BODY, can, hovered and can)

	## A name that does not fit is cut with an ellipsis: `Style.write` has no clip box.
	func _cut_to(text: String, size_px: int, room_wide: float) -> String:
		if Style.measure(text, size_px).x <= room_wide:
			return text
		var cut := text
		while cut.length() > 1 and Style.measure(cut + "…", size_px).x > room_wide:
			cut = cut.left(cut.length() - 1)
		return cut.strip_edges() + "…"


## The hose upgrade as a row of the upgrades shop (2026-10-02, Richard: "match visual style
## from upgrade buttons on upgrade menu"): the net board's blue plate, a rail with the level,
## the name over "now → next", and the shop's own price tag, which is the only part that buys
## (the shop's What Is Drawn Is What Clicks). At the top it is the shop's maxed row: the deep
## green plate and a MAX badge.
class HoseRow:
	extends Control
	const Style := preload("res://scripts/style.gd")

	var room: WashRoom
	var _over_tag := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_exited.connect(func() -> void:
			_over_tag = false
			queue_redraw())

	func _tag() -> Rect2:
		var box := room.hose_tag_box()
		box.position -= position
		return box

	func _gui_input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		if motion != null:
			var over := _tag().has_point(motion.position) and room.can_buy_hose()
			if over != _over_tag:
				_over_tag = over
				if over:
					Sfx.ui(&"ui_hover")
				queue_redraw()
			return
		var press := event as InputEventMouseButton
		if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
			if _tag().has_point(press.position) and room.buy_hose():
				accept_event()
				queue_redraw()

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		var maxed := room.hose_level >= WashRoom.hose_most()
		var afford := room.can_buy_hose()
		var tones := ShopSkin.tones_of(&"net")
		var face: Color = tones[0] if afford else tones[1]
		var ink := Style.BOARD_INK if afford else ShopSkin.INK_DIM
		if maxed:
			face = ShopSkin.MAX_FACE
			ink = Style.BOARD_INK
		Style.plate(self, box, face)
		if afford:
			Style.lit_edge(self, box, face)
		# The rail, with the level and no "?": the wash room has no blurb to show.
		var rail := ShopSkin.rail_of(box)
		Style.plate(self, rail, Style.BOARD.lerp(Style.SEAM, 0.25), 2.0)
		Style.write(
			self, "%d" % room.hose_level, Style.TEXT_SMALL,
			Vector2(0.0, rail.position.y + rail.size.y * 0.5 + float(Style.TEXT_SMALL) * 0.36),
			Style.LEVEL_INK, HORIZONTAL_ALIGNMENT_CENTER, rail
		)
		var text_at := box.position.x + ShopSkin.RAIL_WIDE + ShopSkin.RAIL_GAP
		var tag := _tag()
		var words := tag.position.x - 8.0 - text_at
		var stack := float(Style.TEXT_BODY) * 0.62 + float(Style.TEXT_SMALL) * 0.62 + 6.0
		var first := (box.size.y - stack) * 0.5 + float(Style.TEXT_BODY) * 0.62
		Style.write(
			self, ShopSkin._cut_to(Text.HOSE_NAME, Style.TEXT_BODY, words), Style.TEXT_BODY,
			Vector2(text_at, first), ink
		)
		Style.write(
			self, ShopSkin._cut_to(room.hose_value(), Style.TEXT_SMALL, words), Style.TEXT_SMALL,
			Vector2(text_at, first + 6.0 + float(Style.TEXT_SMALL) * 0.62), ink
		)
		var tag_wide := box.size.x * ShopSkin.TAG_SHARE
		ShopSkin.draw_tag_on(
			self,
			Rect2(
				Vector2(box.end.x - tag_wide - 6.0, box.position.y + 8.0),
				Vector2(tag_wide, box.size.y - 16.0)
			),
			room.hose_cost(), Style.TEXT_BODY, afford, _over_tag and afford, maxed
		)


## The pad in the wash room (2026-09-26, `/grill-me` with Richard). With nothing on the
## stand the tray is a list the stick walks and A picks from. **With a find on it the right
## stick is the nozzle's** (2026-10-06, Richard: aiming is the right stick's, as the cast
## reticle is on the lake; the left still works for a hand that reaches for it): it carries
## the pointer the jet follows, and RT or a held A sprays. B puts the find back on the tray,
## the way walking away from it does: nothing paid, coat and all.
func _pad_aim(delta: float) -> void:
	if not Pad.is_pad() or _on_stand == &"" or not _stand.awake():
		return
	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
	if stick == Vector2.ZERO:
		stick = Input.get_vector(&"walk_left", &"walk_right", &"walk_up", &"walk_down")
	Pad.move_cursor(stick, delta)
	var at := _stand.get_local_mouse_position()
	var firing := Input.is_action_pressed(&"cast") or Input.is_action_pressed(&"interact")
	_stand.spray(at, firing)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE and Pad.is_pad() and _on_stand != &"" 			and _stand.state != WashStand.State.CLEAN:
		_on_stand = &""
		_stand.clear()
		Sfx.ui(&"ui_close")
		get_viewport().set_input_as_handled()


func pad_free() -> bool:
	return _on_stand != &""


## The tray's rows and the close cross.
func pad_focus() -> Array:
	if _on_stand != &"":
		return []
	var out: Array = []
	var boxes := row_boxes()
	for k in boxes.size():
		out.append({"box": boxes[k], "key": waiting[_scroll + k], "first": k == 0})
	if _hose != null:
		out.append({"box": hose_tag_box(), "key": &"hose", "first": out.is_empty()})
	if _close != null and _close.visible:
		out.append({"box": _close.get_rect(), "key": &"close", "first": out.is_empty()})
	return out


func pad_scroll(step: int) -> bool:
	var was := _scroll
	_scroll_by(step)
	return was != _scroll
