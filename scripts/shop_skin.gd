## The upgrades board: the drawn shop.
##
## Built as a kit rather than used as a picture. The sheet is one board with five rows on
## it, the shop has nine upgrades and will have more, so tools/slice_shop.gd takes the board,
## the ribbon, one row plate and one price tag out of it and this repeats them. The five
## icons are kept as themselves and handed to the rows that have one.
##
## The lake owns what an upgrade is and what it costs; this owns where it sits and what it
## looks like, and says which one was clicked. Same split as the HUD skin.
class_name ShopSkin
extends Control

const ART := "res://assets/shop.json"

## How much of the window the board takes, and the largest it may be drawn. It is a tall
## board and the window is wide, so its height is what is fitted and its width follows.
const BOARD_SHARE := 0.86
const BOARD_WIDEST := 620.0

## A row's height as a fraction of the board's width, and the gap between two of them. Taken
## off the art's own proportions rather than its pixels, so the board can be any size.
##
## Sized to fit every upgrade rather than to match the five the board is painted with. At the
## drawn size only eight fitted, and the ninth — the extra ferry, the most expensive thing in
## the game — fell off the bottom and simply was not for sale.
const ROW_TALL := 0.064
const ROW_GAP := 0.010

## Where the rows start down the board, and how far in from its sides they sit.
const ROWS_TOP := 0.155
const ROWS_LEFT := 0.055
const ROWS_RIGHT := 0.055

## How wide the icon tile and the price tag are, as fractions of a row's height and of the
## rows' full width.
const ICON_WIDE := 1.08

## How much of an icon slot a lent picture fills, before its own `fill` adjusts it. Over one,
## because the lent pictures are sprites with their own margin baked in — a ferry sits in the
## middle of a square frame with air all round it — and fitted to the slot they come out half
## the size of the drawn icons beside them.
const ICON_INSET := 1.3

## The tile a lent picture is set into, matched to the ones the board is painted with: a dark
## panel, a warm border, and an outline round the outside.
const TILE_FACE := Color(0.17, 0.13, 0.10)
const TILE_EDGE := Color(0.56, 0.40, 0.25)
const TILE_INK := Color(0.10, 0.08, 0.06)
const TILE_BORDER := 0.075

## The price tag, drawn rather than stretched out of the sheet. The art's own tag carries a
## price painted on it and its ends carry brackets, and no amount of slicing that gets a
## readable number onto it at this size — so it is rebuilt in the board's own colours, where
## the contrast between the face and the ink can simply be chosen.
const TAG_FACE := Color(0.85, 0.70, 0.47)
const TAG_LIT := Color(0.93, 0.81, 0.60)
const TAG_EDGE := Color(0.42, 0.28, 0.17)
const TAG_INK := Color(0.16, 0.10, 0.05)
const TAG_OFF := Color(0.55, 0.46, 0.36)
const PRICE_WIDE := 0.24

## Where the value column starts, as a fraction of the plate's width.
const VALUE_AT := 0.45

## The corner cross, as a fraction of the board's height.
const CLOSE_SIZE := 0.062

## Text sizes, as fractions of a row's height.
const NAME_TEXT := 0.34
const VALUE_TEXT := 0.30
const PRICE_TEXT := 0.34

## Emitted when a row is clicked and the player can afford it. The lake decides what
## happens; this does not know what an upgrade is.
signal bought(key: StringName)

## The player asking to be out of here: the corner cross, or a click on the wood around the
## board. Both mean the same thing and the lake decides what to do about it.
signal close_asked

## The rows to draw, newest set every frame by the lake. Each is
## `{key, icon, name, value, cost, afford}` — `icon` is an index into the sheet's five, or
## -1 for a row the sheet has no picture for.
var rows: Array = []

## Pictures for the rows the sheet does not cover, by upgrade key, each `{sheet, region}`.
##
## The board was drawn with five icons and they are all net parts, so every ferry upgrade sat
## against an empty square — which reads as "coming soon" rather than as "no icon". The lake
## hands over what it already has: the ferry's own baked sprite for the boat rows, and the
## net for the skimmer, which is a net.
var icons := {}
var _sheet: Texture2D
var _pieces := {}
var _board := Rect2()
var _row_boxes: Array[Rect2] = []
var _hovered: int = -1

## The cross in the board's top corner. Made here rather than put in the scene because it is
## hung off the board's own rectangle, and only this knows where that is.
var _close: CloseButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_art()
	_close = CloseButton.new()
	_close.pressed.connect(func() -> void: close_asked.emit())
	add_child(_close)
	resized.connect(_lay_out)
	_lay_out()


func _load_art() -> bool:
	var text := FileAccess.get_file_as_string(ART)
	if text.is_empty():
		return false
	var book: Dictionary = JSON.parse_string(text)
	if book == null or not book.has("pieces"):
		return false
	_sheet = Art.texture(book["sheet"])
	if _sheet == null:
		return false
	for name: String in book["pieces"]:
		var piece: Variant = book["pieces"][name]
		if piece is Array:
			_pieces[StringName(name)] = Rect2(piece[0], piece[1], piece[2], piece[3])
	return true


## The board, centred, as tall as it can be and shaped as the art is.
func _lay_out() -> void:
	if not _pieces.has(&"panel"):
		return
	var art: Rect2 = _pieces[&"panel"]
	var tall := minf(size.y * BOARD_SHARE, BOARD_WIDEST * art.size.y / art.size.x)
	var wide := tall * art.size.x / art.size.y
	_board = Rect2((size.x - wide) * 0.5, (size.y - tall) * 0.5, wide, tall)
	if _close != null:
		var box := tall * CLOSE_SIZE
		# Just inside the top right corner of the board, where a window's close is.
		_close.position = Vector2(_board.end.x - box * 1.35, _board.position.y + box * 0.35)
		_close.size = Vector2(box, box)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was := _hovered
		_hovered = _row_under((event as InputEventMouseMotion).position)
		if was != _hovered:
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var index := _row_under(click.position)
	if index < 0 or index >= rows.size():
		# Anywhere off the board is the way out: the board is a thing on a table, and
		# clicking the table puts it down.
		if not _board.has_point(click.position):
			accept_event()
			close_asked.emit()
		return
	accept_event()
	var row: Dictionary = rows[index]
	if bool(row.get("afford", false)):
		bought.emit(StringName(row["key"]))


func _row_under(at: Vector2) -> int:
	for i in _row_boxes.size():
		if _row_boxes[i].has_point(at):
			return i
	return -1


func _draw() -> void:
	if _sheet == null or _board.size.x <= 0.0:
		return
	# Everything behind the board dimmed, so the board is a thing in front of the lake
	# rather than a sticker on it.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.05, 0.55))

	var art: Rect2 = _pieces[&"panel"]
	var scale := _board.size.x / art.size.x
	if _pieces.has(&"board"):
		var board: Rect2 = _pieces[&"board"]
		draw_texture_rect_region(
			_sheet,
			Rect2(
				_board.position + Vector2(0.0, (board.position.y - art.position.y) * scale),
				board.size * scale
			),
			board
		)
	else:
		draw_texture_rect_region(_sheet, _board, art)

	# The interior papered over with bare wood, so the five rows the board is painted with
	# do not ghost under the ones actually being offered.
	if _pieces.has(&"inner") and _pieces.has(&"board_fill"):
		var inner: Rect2 = _pieces[&"inner"]
		draw_texture_rect_region(
			_sheet,
			Rect2(
				_board.position + (inner.position - art.position) * scale,
				inner.size * scale
			),
			_pieces[&"board_fill"]
		)

	_draw_rows(scale)
	_draw_banner(scale)


## The ribbon, drawn last so it hangs over the board's top edge as it does on the sheet.
func _draw_banner(scale: float) -> void:
	if not _pieces.has(&"banner"):
		return
	var art: Rect2 = _pieces[&"panel"]
	var banner: Rect2 = _pieces[&"banner"]
	var box := Rect2(
		_board.position + (banner.position - art.position) * scale, banner.size * scale
	)
	# No title written over it: the ribbon is painted with one, and this board is the shed.
	draw_texture_rect_region(_sheet, box, banner)


func _draw_rows(scale: float) -> void:
	_row_boxes.clear()
	var left := _board.position.x + _board.size.x * ROWS_LEFT
	var wide := _board.size.x * (1.0 - ROWS_LEFT - ROWS_RIGHT)
	var tall := _board.size.x * ROW_TALL
	var step := tall + _board.size.x * ROW_GAP
	var top := _board.position.y + _board.size.y * ROWS_TOP

	var font := get_theme_default_font()
	for i in rows.size():
		var row: Dictionary = rows[i]
		var box := Rect2(left, top + step * float(i), wide, tall)
		if box.position.y + box.size.y > _board.position.y + _board.size.y:
			break
		_row_boxes.append(box)

		var icon_wide := tall * ICON_WIDE
		var plate := Rect2(
			box.position.x + icon_wide, box.position.y, box.size.x - icon_wide, box.size.y
		)
		# A row the player cannot afford is drawn back rather than hidden: the point of a
		# shop is knowing what is coming.
		var tint := Color.WHITE if bool(row.get("afford", false)) else Color(0.62, 0.6, 0.58)
		if _hovered == i and bool(row.get("afford", false)):
			tint = Color(1.15, 1.15, 1.12)

		_draw_slice(plate, &"row_cap_l", &"row_fill", &"row_cap_r", tint)
		# Square, and as tall as the tile is drawn on the sheet against its row.
		var side := tall * ICON_WIDE
		var slot := Rect2(box.position + Vector2(0.0, (tall - side) * 0.5), Vector2(side, side))
		var icon := int(row.get("icon", -1))
		if icon >= 0 and _pieces.has(StringName("icon%d" % icon)):
			draw_texture_rect_region(
				_sheet, slot, _pieces[StringName("icon%d" % icon)], tint
			)
		elif icons.has(StringName(row.get("key", ""))):
			_draw_lent_icon(icons[StringName(row["key"])], slot, tint)

		var price := Rect2(
			plate.position.x + plate.size.x * (1.0 - PRICE_WIDE),
			plate.position.y + plate.size.y * 0.15,
			plate.size.x * PRICE_WIDE, plate.size.y * 0.7
		)

		var pale := Color(0.96, 0.94, 0.90) if bool(row.get("afford", false)) 			else Color(0.72, 0.70, 0.67)
		var pad := plate.size.x * 0.035
		_write(
			font, String(row.get("name", "")), int(tall * NAME_TEXT),
			plate.position + Vector2(pad, plate.size.y * 0.5), pale
		)
		# The value on a slab of its own. The plate's middle is stretched wood with a
		# gradient across it, and pale text laid straight onto that came out smeared —
		# a flat panel behind the figure is the difference between a number you read and
		# one you squint at.
		var value := String(row.get("value", ""))
		var value_high := int(tall * VALUE_TEXT)
		var value_span := font.get_string_size(
			value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, value_high
		)
		var tablet := Rect2(
			plate.position + Vector2(plate.size.x * VALUE_AT - pad, plate.size.y * 0.16),
			Vector2(value_span.x + pad * 2.0, plate.size.y * 0.68)
		)
		draw_rect(tablet, Color(0.06, 0.05, 0.05, 0.5))
		_write(
			font, value, value_high,
			plate.position + Vector2(plate.size.x * VALUE_AT, plate.size.y * 0.5), pale
		)
		_draw_tag(
			price, String(row.get("cost", "")), font, int(tall * PRICE_TEXT),
			bool(row.get("afford", false)), _hovered == i
		)


## One of the lent pictures, in a tile of its own.
##
## The board's five painted icons all sit in a bordered square, and a bare sprite next to
## them reads as a missing icon rather than as a different one. So the tile is drawn first,
## in the same colours, and the picture set into it — kept to its own proportions and centred
## rather than stretched to the square, because a ferry is long and thin and a net is flat
## and squaring either off makes it something else.
func _draw_lent_icon(lent: Dictionary, slot: Rect2, tint: Color) -> void:
	var sheet: Texture2D = lent.get("sheet")
	if sheet == null:
		return
	_draw_tile(slot, tint)

	var region: Rect2 = lent["region"]
	var fill := float(lent.get("fill", 1.0))
	var inner := slot.size.x * (1.0 - TILE_BORDER * 2.0)
	var scale := minf(
		inner * ICON_INSET * fill / region.size.x,
		inner * ICON_INSET * fill / region.size.y
	)
	var size := region.size * scale
	var middle := slot.position + slot.size * 0.5
	match StringName(lent.get("glyph", "")):
		&"pair":
			# Two of them, one behind the other, which is what an extra ferry is.
			var step := slot.size * 0.13
			draw_texture_rect_region(
				sheet, Rect2(middle - size * 0.5 - step, size), region,
				Color(tint.r * 0.7, tint.g * 0.7, tint.b * 0.7)
			)
			draw_texture_rect_region(sheet, Rect2(middle - size * 0.5 + step, size), region, tint)
		_:
			draw_texture_rect_region(sheet, Rect2(middle - size * 0.5, size), region, tint)
	_draw_glyph(StringName(lent.get("glyph", "")), slot, tint)


## The bordered square the board's own icons sit in.
func _draw_tile(slot: Rect2, tint: Color) -> void:
	var edge := slot.size.x * TILE_BORDER
	draw_rect(slot, Color(TILE_INK.r, TILE_INK.g, TILE_INK.b, tint.a))
	draw_rect(slot.grow(-edge * 0.4), TILE_EDGE * Color(tint.r, tint.g, tint.b, 1.0))
	draw_rect(slot.grow(-edge * 1.4), TILE_FACE)


## The mark that says what a picture of a ferry means: an arrow up for going faster, a plus
## for carrying more. Drawn in the corner rather than over the boat, so the boat stays the
## thing being described.
func _draw_glyph(glyph: StringName, slot: Rect2, tint: Color) -> void:
	var side := slot.size.x * 0.3
	var at := slot.position + slot.size - Vector2(side * 0.85, side * 0.85)
	var gold := Color(0.98, 0.82, 0.35, tint.a)
	match glyph:
		&"arrow":
			var green := Color(0.55, 0.86, 0.45, tint.a)
			draw_colored_polygon(
				PackedVector2Array([
					at + Vector2(0.0, -side * 0.5),
					at + Vector2(side * 0.42, 0.0),
					at + Vector2(-side * 0.42, 0.0)
				]),
				green
			)
			draw_rect(
				Rect2(at + Vector2(-side * 0.15, 0.0), Vector2(side * 0.3, side * 0.46)),
				green
			)
		&"plus":
			draw_rect(
				Rect2(at + Vector2(-side * 0.42, -side * 0.13), Vector2(side * 0.84, side * 0.26)),
				gold
			)
			draw_rect(
				Rect2(at + Vector2(-side * 0.13, -side * 0.42), Vector2(side * 0.26, side * 0.84)),
				gold
			)


## The price, on a tag built here rather than cut from the sheet.
func _draw_tag(
	box: Rect2, cost: String, font: Font, height: int, afford: bool, lit: bool
) -> void:
	if cost.is_empty():
		return
	var span := font.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1.0, height)
	# Shrunk onto the number with a margin, so a four-figure price and a two-figure one both
	# sit in the middle of their own tag rather than one rattling around a fixed box.
	var wide := minf(span.x + float(height) * 1.2, box.size.x)
	var tag := Rect2(
		box.position + Vector2((box.size.x - wide) * 0.5, 0.0), Vector2(wide, box.size.y)
	)
	draw_rect(tag.grow(1.0), TAG_EDGE)
	draw_rect(tag, (TAG_LIT if lit else TAG_FACE) if afford else TAG_OFF)
	draw_string(
		font,
		tag.position + Vector2(
			(tag.size.x - span.x) * 0.5, tag.size.y * 0.5 + float(height) * 0.34
		),
		cost, HORIZONTAL_ALIGNMENT_LEFT, -1.0, height,
		TAG_INK if afford else Color(0.25, 0.21, 0.17)
	)


## A plate or a tag drawn at any width: its two end caps at their own size, and a slab of
## its middle stretched between them.
##
## Drawn this way and not stretched whole because the art's own middle has words painted on
## it — the row it was drawn as says "Width (Lvl 12)" and the tag says a price from a game
## nobody is playing. Stretching those puts them under every live line on the board.
func _draw_slice(
	box: Rect2, left: StringName, fill: StringName, right: StringName, tint: Color
) -> void:
	if not _pieces.has(left) or not _pieces.has(fill) or not _pieces.has(right):
		return
	var cap_l: Rect2 = _pieces[left]
	var cap_r: Rect2 = _pieces[right]
	# The caps keep their proportions against the row's height, so a taller row has
	# proportionally wider ends rather than stretched ones.
	var scale := box.size.y / cap_l.size.y
	var wide_l := minf(cap_l.size.x * scale, box.size.x * 0.4)
	var wide_r := minf(cap_r.size.x * scale, box.size.x * 0.4)
	draw_texture_rect_region(
		_sheet, Rect2(box.position, Vector2(wide_l, box.size.y)), cap_l, tint
	)
	draw_texture_rect_region(
		_sheet,
		Rect2(
			box.position + Vector2(box.size.x - wide_r, 0.0), Vector2(wide_r, box.size.y)
		),
		cap_r, tint
	)
	var middle := box.size.x - wide_l - wide_r
	if middle > 0.0:
		draw_texture_rect_region(
			_sheet,
			Rect2(box.position + Vector2(wide_l, 0.0), Vector2(middle, box.size.y)),
			_pieces[fill], tint
		)


## One line of text, sitting on a point rather than hanging from it.
func _write(font: Font, text: String, height: int, at: Vector2, tint: Color) -> void:
	if text.is_empty():
		return
	draw_string(
		font, at + Vector2(0.0, float(height) * 0.34), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, height, tint
	)
