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

const Style := preload("res://scripts/style.gd")

const ART := "res://assets/shop.json"

## The board, in rows rather than in fractions of the sheet's own painting.
##
## It used to be sized to the proportions of the picture it was cut from, so its width came
## out of an artwork and its rows out of that width — a row's text size was a fraction of a
## board size that was a fraction of a window. Three multiplications between "how big is this
## writing" and any number anyone chose. Now the row is the unit: one row is as tall as it
## needs to be for its text and its icon, and the board is however tall its rows come to.
## How tall a row is drawn, and how short it may be squeezed to before the board gives up
## and drops one. The board grows a row at a time until it is as tall as the window allows,
## and then the rows themselves have to give: a shop that quietly stops drawing its last two
## upgrades — which is what a fixed row height did the day the dog got two of its own — is
## worse than a shop drawn slightly tighter.
const ROW_TALL := 56.0
const ROW_LEAST := 40.0
const ROW_GAP := 6.0
const BOARD_WIDE := 720.0
const BOARD_PAD := 22.0

## The columns, left to right: the icon tile, the name, the value tablet, the price tag. The
## three after the icon are given fixed shares of what is left, so every row breaks in the
## same place down the board instead of each one breaking where its own words end.
const NAME_SHARE := 0.46
const VALUE_SHARE := 0.30
const PRICE_SHARE := 0.24

## How much of an icon slot a lent picture fills, before its own `fill` adjusts it. Over one,
## because the lent pictures are sprites with their own margin baked in — a ferry sits in the
## middle of a square frame with air all round it — and fitted to the slot they come out half
## the size of the drawn icons beside them.
const ICON_INSET := 1.3

## How far in from a tile's edge its picture is kept, as a fraction of the tile.
const TILE_BORDER := 0.075

## The tile a picture is set into, and the price tag it is sold by. Both are the game's own
## wood and the game's own tag colour; the board is no longer a photograph of a shop.
const TILE_FACE := Style.WOOD_DEEP
const TILE_EDGE := Style.WOOD_LIT
const TILE_INK := Style.SEAM
const TAG_FACE := Style.TAG
const TAG_LIT := Style.TAG_LIT
const TAG_EDGE := Style.GOLD_DEEP
const TAG_INK := Style.INK_DARK
const TAG_OFF := Style.TAG_OFF

## The heading over the rows, and the corner cross.
const TITLE := "Upgrades"
const CLOSE_SIZE := 34.0

## Emitted when a row is clicked and the player can afford it. The lake decides what
## happens; this does not know what an upgrade is.
## How long the sparkle over a bought upgrade's icon lasts, how far above the icon it
## reaches, and how many points it is made of. Short and small on purpose: it is a receipt
## for a click the player already made, not an event.
const SPARKLE_TIME := 0.7
const SPARKLE_RISE := 34.0
const SPARKLE_POINTS := 7


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

## How tall a row is on the board as it stands, which is ROW_TALL until there are more rows
## than the window has height for. Every measurement down a row is taken off this.
var _row_tall: float = ROW_TALL
var _board_rows: int = -1
var _row_boxes: Array[Rect2] = []
var _hovered: int = -1

## The row whose upgrade has just been bought, and how long the sparkle over its icon has
## left to run. -1 is nobody.
var _sparkling: StringName = &""
var _sparkle: float = 0.0

## What the last painted board was made of: the rows' own contents and whatever the mouse
## is over.
var _painted: int = 0

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


## Light up the icon of a row that has just been bought. Called by the lake when a purchase
## actually lands, so a click that could not be afforded sparkles at nobody.
func cheer(key: StringName) -> void:
	_sparkling = key
	_sparkle = SPARKLE_TIME
	set_process(true)
	queue_redraw()


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


## The board, centred, as big as its rows come to.
##
## Sized to the content rather than to the window: nine upgrades make a board of a certain
## height and that is the height it is. The row that used to fall off the bottom — the extra
## ferry, the most expensive thing in the game, simply not for sale — cannot, because the
## board is built downwards from the rows rather than the rows crammed into a board.
func _lay_out() -> void:
	var count := maxi(rows.size(), 1)
	var head := float(Style.TEXT_TITLE) + BOARD_PAD
	var spare := head + float(count - 1) * ROW_GAP + BOARD_PAD * 2.0
	# What is left for the rows themselves once the heading and the padding have had theirs,
	# shared out and held between the two heights a row may be drawn at.
	var room := (size.y - 40.0 - spare) / float(count)
	_row_tall = clampf(room, ROW_LEAST, ROW_TALL)
	var tall := spare + float(count) * _row_tall
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	tall = minf(tall, size.y - 40.0)
	_board = Rect2(
		floorf((size.x - wide) * 0.5), floorf((size.y - tall) * 0.5), wide, tall
	)
	if _close != null:
		# Just inside the top right corner of the board, where a window's close is.
		_close.position = Vector2(
			_board.end.x - CLOSE_SIZE - BOARD_PAD * 0.5, _board.position.y + BOARD_PAD * 0.5
		)
		_close.size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	queue_redraw()


func _process(delta: float) -> void:
	if _sparkle > 0.0:
		_sparkle = maxf(_sparkle - delta, 0.0)
		if _sparkle <= 0.0:
			_sparkling = &""
		queue_redraw()
	# The rows are set from outside, and how many there are is what the board is sized by.
	if _board_rows != rows.size():
		_board_rows = rows.size()
		_lay_out()
	# Only when the board would come out different. The lake hands over a fresh `rows`
	# every frame the menu is open, but its contents only change when a level or the purse
	# does — and repainting a board of nine priced rows to put back the same nine prices is
	# the most expensive way to do nothing.
	if _painted != _paint_key():
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


func _paint_key() -> int:
	return hash([rows.hash(), _hovered, roundi(_sparkle * 120.0)])


func _draw() -> void:
	_painted = _paint_key()
	if _board.size.x <= 0.0:
		return
	# Everything behind the board dimmed, so the board is a thing in front of the lake
	# rather than a sticker on it.
	Style.dim(self, Rect2(Vector2.ZERO, size), Style.SCRIM)

	# A plank panel, the same one the settings and the shed stand on. The painted board this
	# replaces was a picture of a shop with five rows and a title on it, so every live row
	# had to be papered over the top of a drawn one.
	Style.plaque(self, _board, Style.WOOD)
	Style.write(
		self,
		TITLE,
		Style.TEXT_TITLE,
		Vector2(0.0, _board.position.y + BOARD_PAD + float(Style.TEXT_TITLE) * 0.8),
		Style.INK,
		HORIZONTAL_ALIGNMENT_CENTER,
		_board
	)
	_draw_rows()


func _draw_rows() -> void:
	_row_boxes.clear()
	var left := _board.position.x + BOARD_PAD
	var wide := _board.size.x - BOARD_PAD * 2.0
	var top := _board.position.y + BOARD_PAD * 2.0 + float(Style.TEXT_TITLE)

	for i in rows.size():
		var row: Dictionary = rows[i]
		var box := Rect2(left, top + (_row_tall + ROW_GAP) * float(i), wide, _row_tall)
		if box.end.y > _board.end.y - BOARD_PAD:
			break
		_row_boxes.append(box)

		var afford := bool(row.get("afford", false))
		var lit := _hovered == i and afford
		# A row the player cannot afford is drawn back rather than hidden: the point of a
		# shop is knowing what is coming.
		var tint := Color.WHITE if afford else Style.INK_DIM
		if lit:
			tint = Style.HOVER_WASH
		var ink := Style.INK if afford else Style.INK_DIM

		# The row's own plate, so a row reads as one thing and the gap between two of them
		# reads as the gap between two things.
		Style.plaque(self, box, Style.WOOD_LIT if lit else Style.WOOD_DEEP)

		# The icon, in a tile as tall as the row.
		var slot := Rect2(
			box.position + Vector2(4.0, 4.0), Vector2(_row_tall - 8.0, _row_tall - 8.0)
		)
		var icon := int(row.get("icon", -1))
		if icon >= 0 and _pieces.has(StringName("icon%d" % icon)):
			_draw_tile(slot, tint)
			draw_texture_rect_region(
				_sheet, slot.grow(-slot.size.x * TILE_BORDER * 1.4),
				_pieces[StringName("icon%d" % icon)], tint
			)
		elif icons.has(StringName(row.get("key", ""))):
			_draw_lent_icon(icons[StringName(row["key"])], slot, tint)

		if _sparkle > 0.0 and StringName(row.get("key", "")) == _sparkling:
			_draw_sparkle(slot)

		# The three columns, each starting where it starts on every other row.
		var rest := box.size.x - _row_tall - 8.0
		var name_at := box.position.x + _row_tall + 4.0
		var value_at := name_at + rest * NAME_SHARE
		var price_at := value_at + rest * VALUE_SHARE
		var middle := box.position.y + (_row_tall + float(Style.TEXT_BODY) * 0.62) * 0.5

		Style.write(
			self, String(row.get("name", "")), Style.TEXT_BODY, Vector2(name_at, middle), ink
		)

		# The value on a slab of its own: the plank behind it is grained, and a figure laid
		# straight onto that is a figure you squint at.
		var value := String(row.get("value", ""))
		if not value.is_empty():
			var span := Style.measure(value, Style.TEXT_SMALL)
			var tablet := Rect2(
				Vector2(value_at, box.position.y + 10.0),
				Vector2(minf(span.x + 20.0, rest * VALUE_SHARE - 10.0), _row_tall - 20.0)
			)
			draw_rect(tablet, Style.scrim(Style.SCRIM_LIGHT))
			Style.write(
				self, value, Style.TEXT_SMALL,
				Vector2(0.0, box.position.y + (_row_tall + float(Style.TEXT_SMALL) * 0.62) * 0.5),
				ink, HORIZONTAL_ALIGNMENT_CENTER, tablet
			)

		_draw_tag(
			Rect2(
				Vector2(price_at, box.position.y + 8.0),
				Vector2(rest * PRICE_SHARE, _row_tall - 16.0)
			),
			String(row.get("cost", "")), Style.TEXT_BODY, afford, lit
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


## The bordered square the board's own icons sit in — the same plaque as every other piece
## of wood in the game, sunk rather than raised so a picture reads as set into the board.
## A handful of four-pointed stars rising off a bought upgrade's icon and fading out.
##
## Drawn from the icon's own square rather than from a fixed point, so it sits over whichever
## row was bought wherever that row happens to be on the board. The stars are the same shape
## the game draws everywhere else: two crossed spindles, which read as a sparkle at eight
## pixels where a circle reads as a dot.
func _draw_sparkle(slot: Rect2) -> void:
	var through := 1.0 - clampf(_sparkle / SPARKLE_TIME, 0.0, 1.0)
	var out := smoothstep(0.0, 1.0, through)
	var fade := 1.0 - smoothstep(0.5, 1.0, through)
	var middle := slot.position + slot.size * 0.5
	for i in SPARKLE_POINTS:
		# Thrown out of the icon on its own bearing rather than laid out in a row: a line of
		# identical stars reads as a border, which is what the first pass looked like.
		var turn := PI * (0.12 + 0.76 * float(i) / float(SPARKLE_POINTS - 1))
		var reach := SPARKLE_RISE * (0.55 + 0.45 * float((i * 3) % SPARKLE_POINTS)
			/ float(SPARKLE_POINTS - 1))
		var at := middle + Vector2(-cos(turn), -sin(turn)) * reach * out
		# Biggest halfway out, so each one flares and goes rather than simply shrinking.
		var flare := sin(clampf(through, 0.0, 1.0) * PI)
		var side := (3.0 + 4.0 * float(i % 3) * 0.5) * (0.45 + 0.55 * flare)
		_star(at, side, Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, fade))


## One four-pointed star: a tall spindle and a wide one, crossed.
func _star(at: Vector2, side: float, tint: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			at + Vector2(0.0, -side), at + Vector2(side * 0.34, 0.0),
			at + Vector2(0.0, side), at + Vector2(-side * 0.34, 0.0)
		]),
		tint
	)
	draw_colored_polygon(
		PackedVector2Array([
			at + Vector2(-side, 0.0), at + Vector2(0.0, -side * 0.34),
			at + Vector2(side, 0.0), at + Vector2(0.0, side * 0.34)
		]),
		tint
	)


func _draw_tile(slot: Rect2, tint: Color) -> void:
	Style.plaque(self, slot, TILE_FACE, tint.a)


## The mark that says what a picture of a ferry means: an arrow up for going faster, a plus
## for carrying more. Drawn in the corner rather than over the boat, so the boat stays the
## thing being described.
func _draw_glyph(glyph: StringName, slot: Rect2, tint: Color) -> void:
	var side := slot.size.x * 0.3
	var at := slot.position + slot.size - Vector2(side * 0.85, side * 0.85)
	var gold := Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, tint.a)
	match glyph:
		&"arrow":
			var green := Color(Style.SAFE.r, Style.SAFE.g, Style.SAFE.b, tint.a)
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
func _draw_tag(box: Rect2, cost: String, height: int, afford: bool, lit: bool) -> void:
	if cost.is_empty():
		return
	var span := Style.measure(cost, height)
	# Shrunk onto the number with a margin, so a four-figure price and a two-figure one both
	# sit in the middle of their own tag rather than one rattling around a fixed box.
	var wide := minf(span.x + float(height) * 1.2, box.size.x)
	var tag := Rect2(
		box.position + Vector2((box.size.x - wide) * 0.5, 0.0), Vector2(wide, box.size.y)
	)
	Style.plaque(self, tag, (TAG_LIT if lit else TAG_FACE) if afford else TAG_OFF)
	Style.write(
		self,
		cost,
		height,
		Vector2(0.0, tag.position.y + tag.size.y * 0.5 + float(height) * 0.34),
		TAG_INK if afford else Style.INK_DARK.lerp(TAG_OFF, 0.45),
		HORIZONTAL_ALIGNMENT_CENTER,
		tag
	)
