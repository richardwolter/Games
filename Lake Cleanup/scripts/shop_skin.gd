## The upgrades boards: the drawn shop, three boards side by side.
##
## One board each for the net, the ferry and the dog, so the shop reads as three things
## with prices on them rather than one list of eleven buttons. Everything is drawn here
## from `Style` — the frames, the ribbons, the rows, the tags — in the pollution meter's own
## colours; the painted shop sheet this replaced was a picture of one board with five rows
## and had to be papered over for every row it was not drawn with.
##
## The lake owns what an upgrade is and what it costs; this owns where it sits and what it
## looks like, and says which one was clicked. Same split as the HUD skin.
class_name ShopSkin
extends Control

const Style := preload("res://scripts/style.gd")

## The boards, in the order they stand, and what each is called.
const BOARDS: Array[StringName] = [&"net", &"boat", &"dog"]
const TITLES := {&"net": "The net", &"boat": "The ferry", &"dog": "The dog"}

## How tall a row is drawn, and how short it may be squeezed to before a board gives up
## and drops one. A board grows a row at a time until it is as tall as the window allows,
## and then the rows themselves have to give: a shop that quietly stops drawing its last two
## upgrades — which is what a fixed row height did the day the dog got two of its own — is
## worse than a shop drawn slightly tighter. Two lines tall, because a row's name sits over
## its value: three boards across a window leave no room for them side by side.
const ROW_TALL := 56.0
const ROW_LEAST := 44.0
const ROW_GAP := 6.0

## The three boards together, and the gap between them. Sized in the 1280-wide design
## frame; a narrower window shrinks all three alike.
const BOARDS_WIDE := 1000.0
const BOARD_GAP := 18.0
const BOARD_PAD := 16.0

## The oak round each board, and the ribbon and sprite at the head of it. The sprite is the
## thing being sold — the net, the ferry, the dog — and the ribbon names it.
const FRAME := 10.0
const RIBBON_TALL := 36.0
const RIBBON_OVERHANG := 10.0
const SPRITE_TALL := 84.0
const HEAD_GAP := 8.0

## How much of a row the price tag may take.
const TAG_SHARE := 0.34

const CLOSE_SIZE := 34.0

## How long the sparkle over a bought board's sprite lasts, how far it reaches, and how
## many points it is made of. Short and small on purpose: it is a receipt for a click the
## player already made, not an event.
const SPARKLE_TIME := 0.7
const SPARKLE_RISE := 40.0
const SPARKLE_POINTS := 7


## Emitted when a row is clicked and the player can afford it. The lake decides what
## happens; this does not know what an upgrade is.
signal bought(key: StringName)

## The player asking to be out of here: the corner cross, or a click on the table around
## the boards. Both mean the same thing and the lake decides what to do about it.
signal close_asked

## The rows to draw, newest set every frame by the lake. Each is
## `{key, board, name, value, cost, afford}` — `board` is one of BOARDS.
var rows: Array = []

## The picture at the head of each board, by board name, each `{sheet, region}`. Lent by
## the lake, which already has the ferry's baked hull, the dog's idle frame and the net.
var sprites := {}

## Where each board stands this frame, by board name, and the whole span they cover.
var _boards := {}
var _table := Rect2()

## How tall a row is on the boards as they stand, which is ROW_TALL until the longest
## board has more rows than the window has height for.
var _row_tall: float = ROW_TALL
var _laid_rows: int = -1

## Every drawn row's box and which entry in `rows` it is.
var _row_boxes: Array[Rect2] = []
var _row_index: Array[int] = []
var _hovered: int = -1

## The board whose upgrade has just been bought, and how long the sparkle over its sprite
## has left to run.
var _sparkling: StringName = &""
var _sparkle: float = 0.0

## What the last painted boards were made of: the rows' own contents and whatever the
## mouse is over.
var _painted: int = 0

## The cross in the top corner. Made here rather than put in the scene because it is hung
## off the boards' own rectangle, and only this knows where that is.
var _close: CloseButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_close = CloseButton.new()
	_close.pressed.connect(func() -> void: close_asked.emit())
	add_child(_close)
	resized.connect(_lay_out)
	_lay_out()


## Light up the sprite of the board whose upgrade has just been bought. Called by the lake
## when a purchase actually lands, so a click that could not be afforded sparkles at nobody.
func cheer(key: StringName) -> void:
	_sparkling = _board_of(key)
	_sparkle = SPARKLE_TIME
	set_process(true)
	queue_redraw()


func _board_of(key: StringName) -> StringName:
	for row: Dictionary in rows:
		if StringName(row.get("key", "")) == key:
			return StringName(row.get("board", ""))
	return &""


func _count(board: StringName) -> int:
	var n := 0
	for row: Dictionary in rows:
		if StringName(row.get("board", "")) == board:
			n += 1
	return n


## The head of a board: frame, ribbon, sprite and their gaps, above the first row.
func _head_tall() -> float:
	return FRAME + RIBBON_TALL * 0.5 + BOARD_PAD + SPRITE_TALL + HEAD_GAP


## The three boards in a row, each as tall as its rows come to, tops aligned.
##
## Sized to the content rather than to the window: the dog's board has two rows and is
## two rows tall, the net's five and five. The tallest of them decides how tall a row may
## be, so a squeeze lands on all three alike and the rows still line up across them.
func _lay_out() -> void:
	var most := 1
	for board in BOARDS:
		most = maxi(most, _count(board))
	var spare := _head_tall() + float(most - 1) * ROW_GAP + BOARD_PAD + FRAME
	var room := (size.y - 40.0 - spare) / float(most)
	_row_tall = clampf(room, ROW_LEAST, ROW_TALL)
	var tallest := minf(spare + float(most) * _row_tall, size.y - 40.0)

	var wide := minf(BOARDS_WIDE, size.x - 40.0)
	var each := (wide - BOARD_GAP * float(BOARDS.size() - 1)) / float(BOARDS.size())
	var top := floorf((size.y - tallest) * 0.5)
	var left := floorf((size.x - wide) * 0.5)
	_table = Rect2(left, top, wide, tallest)
	_boards.clear()
	for i in BOARDS.size():
		var count := maxi(_count(BOARDS[i]), 1)
		var tall := minf(
			_head_tall() + float(count) * _row_tall + float(count - 1) * ROW_GAP
			+ BOARD_PAD + FRAME,
			tallest
		)
		_boards[BOARDS[i]] = Rect2(
			floorf(left + (each + BOARD_GAP) * float(i)), top, floorf(each), tall
		)
	if _close != null:
		# Just outside the top right corner of the last board, where a window's close is,
		# clear of that board's ribbon.
		_close.position = Vector2(_table.end.x - CLOSE_SIZE, _table.position.y - CLOSE_SIZE - 4.0)
		_close.size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	queue_redraw()


func _process(delta: float) -> void:
	if _sparkle > 0.0:
		_sparkle = maxf(_sparkle - delta, 0.0)
		if _sparkle <= 0.0:
			_sparkling = &""
		queue_redraw()
	# The rows are set from outside, and how many there are is what the boards are sized by.
	if _laid_rows != rows.size():
		_laid_rows = rows.size()
		_lay_out()
	# Only when the boards would come out different. The lake hands over a fresh `rows`
	# every frame the menu is open, but its contents only change when a level or the purse
	# does — and repainting eleven priced rows to put back the same eleven prices is the
	# most expensive way to do nothing.
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
		# Anywhere off the boards is the way out: the boards are things on a table, and
		# clicking the table puts them down.
		if not _on_a_board(click.position):
			accept_event()
			close_asked.emit()
		return
	accept_event()
	var row: Dictionary = rows[index]
	if bool(row.get("afford", false)):
		bought.emit(StringName(row["key"]))


func _on_a_board(at: Vector2) -> bool:
	for board: StringName in _boards:
		if (_boards[board] as Rect2).grow(RIBBON_OVERHANG).has_point(at):
			return true
	return false


## Which entry in `rows` is under the pointer, or -1.
func _row_under(at: Vector2) -> int:
	for i in _row_boxes.size():
		if _row_boxes[i].has_point(at):
			return _row_index[i]
	return -1


func _paint_key() -> int:
	return hash([rows.hash(), _hovered, roundi(_sparkle * 120.0)])


func _draw() -> void:
	_painted = _paint_key()
	if _table.size.x <= 0.0:
		return
	# Everything behind the boards dimmed, so they are things in front of the lake rather
	# than stickers on it.
	Style.dim(self, Rect2(Vector2.ZERO, size), Style.SCRIM)
	_row_boxes.clear()
	_row_index.clear()
	for board in BOARDS:
		_draw_board(board, _boards[board])


## One board: oak frame, clean-water face, ribbon over the top edge, the sprite, the rows.
func _draw_board(board: StringName, box: Rect2) -> void:
	# The frame is the meter's oak: a dark seam, the plank, a lit inner edge.
	draw_rect(box.grow(1.0), Style.SEAM, true)
	draw_rect(box, Style.FRAME, true)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 2.0)), Style.FRAME_LIT, true)
	draw_rect(Rect2(box.position, Vector2(2.0, box.size.y)), Style.FRAME_LIT, true)
	draw_rect(
		Rect2(Vector2(box.position.x, box.end.y - 2.0), Vector2(box.size.x, 2.0)),
		Style.FRAME_DEEP, true
	)
	draw_rect(
		Rect2(Vector2(box.end.x - 2.0, box.position.y), Vector2(2.0, box.size.y)),
		Style.FRAME_DEEP, true
	)
	var face := box.grow(-FRAME)
	draw_rect(face.grow(1.0), Style.SEAM, true)
	draw_rect(face, Style.BOARD, true)

	# The ribbon, hung over the top of the frame and a little wider than the board, the
	# way the old painted one was. Its ends are notched like the meter's frame.
	var ribbon := Rect2(
		Vector2(box.position.x - RIBBON_OVERHANG, box.position.y - RIBBON_TALL * 0.5),
		Vector2(box.size.x + RIBBON_OVERHANG * 2.0, RIBBON_TALL)
	)
	_draw_ribbon(ribbon, String(TITLES.get(board, "")))

	# The sprite, fitted into its slot at its own proportions.
	var slot := Rect2(
		Vector2(face.position.x, box.position.y + RIBBON_TALL * 0.5 + BOARD_PAD),
		Vector2(face.size.x, SPRITE_TALL)
	)
	_draw_sprite(board, slot)
	if _sparkle > 0.0 and board == _sparkling:
		_draw_sparkle(slot)

	# The rows.
	var left := face.position.x + BOARD_PAD
	var wide := face.size.x - BOARD_PAD * 2.0
	var top := slot.end.y + HEAD_GAP
	var n := 0
	for i in rows.size():
		var row: Dictionary = rows[i]
		if StringName(row.get("board", "")) != board:
			continue
		var line := Rect2(left, top + (_row_tall + ROW_GAP) * float(n), wide, _row_tall)
		n += 1
		if line.end.y > face.end.y - BOARD_PAD + 1.0:
			break
		_row_boxes.append(line)
		_row_index.append(i)
		_draw_row(row, line, _hovered == i)


func _draw_ribbon(box: Rect2, title: String) -> void:
	var notch := box.size.y * 0.35
	var face := Style.RIBBON
	var shade := Style.FRAME_DEEP
	# The band, with a swallowtail cut into each end.
	var shape := PackedVector2Array([
		box.position,
		Vector2(box.end.x, box.position.y),
		Vector2(box.end.x - notch, box.position.y + box.size.y * 0.5),
		box.end,
		Vector2(box.position.x, box.end.y),
		Vector2(box.position.x + notch, box.position.y + box.size.y * 0.5),
	])
	var outline := PackedVector2Array(shape)
	outline.append(shape[0])
	draw_colored_polygon(shape, face)
	draw_polyline(outline, Style.SEAM, 2.0)
	# A lit top edge and a shaded bottom one, so the ribbon reads as cloth over the frame.
	draw_rect(
		Rect2(box.position + Vector2(notch, 1.0), Vector2(box.size.x - notch * 2.0, 2.0)),
		Style.RIBBON_LIT, true
	)
	draw_rect(
		Rect2(
			Vector2(box.position.x + notch, box.end.y - 3.0),
			Vector2(box.size.x - notch * 2.0, 2.0)
		),
		Color(shade.r, shade.g, shade.b, 0.35), true
	)
	Style.write(
		self, title, Style.TEXT_HEAD,
		Vector2(0.0, box.position.y + (box.size.y + float(Style.TEXT_HEAD) * 0.62) * 0.5),
		Style.FRAME_DEEP, HORIZONTAL_ALIGNMENT_CENTER, box
	)


func _draw_sprite(board: StringName, slot: Rect2) -> void:
	var lent: Dictionary = sprites.get(board, {})
	var sheet: Texture2D = lent.get("sheet")
	if sheet == null:
		return
	var region: Rect2 = lent["region"]
	var scale := minf(slot.size.x / region.size.x, slot.size.y / region.size.y)
	var drawn := region.size * scale
	var middle := slot.position + slot.size * 0.5
	draw_texture_rect_region(sheet, Rect2(middle - drawn * 0.5, drawn), region)


## One row: a clean-water plate, the name over its value on the left, the price tag on the
## right. A row the player cannot afford is drawn back rather than hidden: the point of a
## shop is knowing what is coming.
func _draw_row(row: Dictionary, box: Rect2, hovered: bool) -> void:
	var afford := bool(row.get("afford", false))
	var lit := hovered and afford
	var face := Style.BOARD_ROW if afford else Style.BOARD_ROW_OFF
	if lit:
		face = Color(
			face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b
		)
	var ink := Style.BOARD_INK if afford else Style.BOARD_INK_DIM
	_plate(box, face)

	var tag_wide := box.size.x * TAG_SHARE
	var text_at := box.position.x + 10.0
	var name := String(row.get("name", ""))
	var value := String(row.get("value", ""))
	# Two lines, or one centred if there is no value to say.
	if value.is_empty():
		Style.write(
			self, name, Style.TEXT_BODY,
			Vector2(text_at, box.position.y + (box.size.y + float(Style.TEXT_BODY) * 0.62) * 0.5),
			ink
		)
	else:
		var stack := float(Style.TEXT_BODY) * 0.62 + float(Style.TEXT_SMALL) * 0.62 + 6.0
		var first := box.position.y + (box.size.y - stack) * 0.5 + float(Style.TEXT_BODY) * 0.62
		Style.write(self, name, Style.TEXT_BODY, Vector2(text_at, first), ink)
		Style.write(
			self, value, Style.TEXT_SMALL,
			Vector2(text_at, first + 6.0 + float(Style.TEXT_SMALL) * 0.62),
			ink.lerp(face, 0.25)
		)
	_draw_tag(
		Rect2(
			Vector2(box.end.x - tag_wide - 6.0, box.position.y + 8.0),
			Vector2(tag_wide, box.size.y - 16.0)
		),
		String(row.get("cost", "")), Style.TEXT_BODY, afford, lit
	)


## A plate in a colour of its own: a seam, the face, a lit edge top and left, a shaded one
## bottom and right. `Style.plaque` bevels in wood, which on clean water reads as a splinter.
func _plate(box: Rect2, face: Color) -> void:
	var bevel := Style.bevel_of(box)
	draw_rect(box.grow(1.0), Style.SEAM, true)
	draw_rect(box, face, true)
	var lit := face.lightened(0.22)
	var deep := face.darkened(0.28)
	draw_rect(Rect2(box.position, Vector2(box.size.x, bevel)), lit, true)
	draw_rect(Rect2(box.position, Vector2(bevel, box.size.y)), lit, true)
	draw_rect(
		Rect2(Vector2(box.position.x, box.end.y - bevel), Vector2(box.size.x, bevel)), deep, true
	)
	draw_rect(
		Rect2(Vector2(box.end.x - bevel, box.position.y), Vector2(bevel, box.size.y)), deep, true
	)


## The price, on a sand tag shrunk onto the number, so a five-figure price and a two-figure
## one both sit in the middle of their own tag rather than one rattling around a fixed box.
func _draw_tag(box: Rect2, cost: String, height: int, afford: bool, lit: bool) -> void:
	if cost.is_empty():
		return
	var span := Style.measure(cost, height)
	var wide := minf(span.x + float(height) * 1.2, box.size.x)
	var tag := Rect2(
		box.position + Vector2(box.size.x - wide, 0.0), Vector2(wide, box.size.y)
	)
	_plate(tag, (Style.RIBBON_LIT if lit else Style.RIBBON) if afford else Style.FRAME_LIT)
	Style.write(
		self, cost, height,
		Vector2(0.0, tag.position.y + tag.size.y * 0.5 + float(height) * 0.34),
		Style.FRAME_DEEP if afford else Style.FRAME_DEEP.lerp(Style.FRAME_LIT, 0.45),
		HORIZONTAL_ALIGNMENT_CENTER, tag
	)


## A handful of four-pointed stars rising off a bought board's sprite and fading out.
##
## The stars are the same shape the game draws everywhere else: two crossed spindles, which
## read as a sparkle at eight pixels where a circle reads as a dot.
func _draw_sparkle(slot: Rect2) -> void:
	var through := 1.0 - clampf(_sparkle / SPARKLE_TIME, 0.0, 1.0)
	var out := smoothstep(0.0, 1.0, through)
	var fade := 1.0 - smoothstep(0.5, 1.0, through)
	var middle := slot.position + slot.size * 0.5
	for i in SPARKLE_POINTS:
		# Thrown out on its own bearing rather than laid out in a row: a line of identical
		# stars reads as a border.
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
