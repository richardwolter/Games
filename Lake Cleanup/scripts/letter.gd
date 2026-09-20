## The letter: the game's four-card onboarding, a sheet of paper nailed to the game's oak.
##
## A new game lands the angler and his dog by boat, walks him to the shed and opens this
## (see the arrival section of `lake.gd`). It is the whole of the tutorial, by decision
## (2026-09-19, `/grill-me` with Richard, issue #24): no contextual prompts, no unlock
## pacing, no checklist. Four cards, read once, then the player is on their own. The main
## menu's "How to play" plank opens this same board again.
##
## **A paper letter on the wood, not a fourth settings board** (second `/grill-me` the same
## day, a UI pass over the first cut). The frame, the title plank and the close cross are the
## carpentry every board in the game wears; the face is a sheet in the sand's tones with torn
## edges and dark ink, and the pictures are **pinned to it like photographs**, each a little
## crooked. The first cut was the shop's dark face with three ellipses on it, and it read as
## a menu with nothing to set.
##
## **The pictures are the game photographing itself** (`tools/shot_letter_art.tscn` ->
## `assets/letter/*.png`). This **supersedes the first cut's "every picture is drawn in code,
## so nothing can drift"**: a ring drawn on a flat face explained nothing, because what a
## ring means is what is under it. The cost, taken knowingly: a repainted ring, lake, shop or
## HUD means re-running the probe, and the stills carry the game's English UI as it stands.
##
## **The greeting is the first card's alone**, and the other three give its room to their
## pictures. **One height whatever card is up**: the board is laid out from the bottom —
## pager, sentence, heading — and the pictures take what is left, so nothing jumps under the
## pointer that is paging it.
##
## **Every line is measured against the paper before it is drawn** (`_fitted`, `overruns`).
## `Style.write` neither wraps nor clips, and the first cut's net card ran its second line
## clean over both stiles of the frame. A line too wide drops a size; one still too wide is
## counted, and `test_lake` asks for none.
class_name Letter
extends Control

const Style := preload("res://scripts/style.gd")

const TITLE := "A letter"

## The opening line, on the first card only.
const GREETING := "Congratulations, you are the new owner of My Dirty Little Lake."

## Where the stills live. One PNG a snapshot, named as the cards name them.
const ART := "res://assets/letter/%s.png"

## The cards, in order. `snaps` are [still, caption] pairs pinned in a row, left to right;
## a caption may be empty. `lines` are the sentence, at most `SENTENCE_ROWS` of them.
const CARDS := [
	{
		"head": "Net",
		"lines": ["Cast your net to catch what floats."],
		"snaps": [
			["net_catch", "Green: a catch"],
			["net_nothing", "Red: nothing to lift"],
			["net_far", "White: out of range"],
		],
	},
	{
		"head": "Upgrades",
		"lines": [
			"Upgrade your net, your boats and your dogs",
			"to clean and recycle faster.",
		],
		"snaps": [["upgrades_button", ""], ["upgrades_shop", ""]],
	},
	{
		"head": "Weight",
		"lines": [
			"Heavier things sit in five tiers.",
			"Strength is the upgrade that lifts the next one.",
		],
		"snaps": [["weight_heavy", "Too heavy"], ["weight_strength", "Buy Strength"]],
	},
	{
		"head": "Decoration",
		"lines": ["Some catches are furniture for your shed."],
		"snaps": [["decor_find", "Catch it"], ["decor_wash", "Wash it"], ["decor_button", "Place it"]],
	},
]

## The last card's way out. It stands at the pager's right end in place of the forward arrow
## — there is nothing further to turn to — so no card reserves a row for a door it does not
## have. The first cut hung it under the pager and left a hundred pixels bare on three cards.
const DOOR_LABEL := "Start cleaning"
const DOOR := Vector2(196.0, 48.0)

## The board, in the 1280-wide design frame.
const BOARD_WIDE := 620.0
const FRAME := 12.0
const RIBBON_TALL := 36.0
const RIBBON_OVERHANG := 10.0
const CHIPS := 3
const CLOSE_SIZE := 44.0

## The sheet: how far inside the wood's face it lies, the margin its writing keeps, how many
## bites its edges take, and its colours. The paper is the sand lifted; the ink is the box's
## darkest brown; the headings are the pack's red-brown wood. Every pairing clears 4.5:1
## with room to spare — dark on pale is the easy way round.
const SHEET_INSET := 8.0
const SHEET_PAD := 18.0
const SHEET_BITES := 4
const PAPER := Style.PAPER
const PAPER_EDGE := Style.PAPER_EDGE
const PAPER_RULE := Style.PAPER_RULE
const INK := Style.PAPER_INK
const HEAD_INK := Style.PAPER_HEAD
const SOFT_INK := Style.PAPER_SOFT

## The blocks, bottom up, and the gaps between them.
const PAGER_TALL := 48.0
const SENTENCE_ROWS := 2
const LINE_STEP := 6.0
const GAP := 10.0
## The least the pictures are given on the greeting's card; the other cards get this plus
## the greeting's room.
const ART_LEAST := 150.0

## The pager: the arrow planks and the dots between them.
const ARROW := Vector2(30.0, 34.0)
const DOT := 4.0
const DOT_GAP := 16.0

## A pinned snapshot: the white border a photograph has, the gap between neighbours, the
## room a caption takes under it, and how far off level it may hang, in degrees. The tilt is
## hashed off the still's name, so a card looks the same every time it is turned to.
const SNAP_BORDER := 4.0
const SNAP_GAP := 18.0
const CAPTION_TALL := 20.0
const SNAP_TILT := 1.6
const SNAPS_MOST := 3

signal close_asked

## Which card is up.
var page: int = 0

## Lines that did not fit the paper even a size down, counted by `_draw`. The settings, bind
## and credits boards' own counter; `test_lake` asks `overruns()` for the same answer without
## a renderer.
var dropped_lines: int = 0

var _board := Rect2()
var _sheet := Rect2()
var _close: CloseButton
var _door: PlankButton
var _back := Rect2()
var _on := Rect2()
var _dots: Array[Rect2] = []
var _hovered: StringName = &""
var _snaps: Array[Snap] = []
var _captions: Array = []
var _art := {}


## One photograph. Its own node so it can hang crooked and be filtered as a photograph —
## smooth, scaled to fit — without the board's own pixel wood going soft with it.
class Snap extends Control:
	var picture: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		# A shadow down and to the left, where every shadow in this game falls.
		draw_rect(Rect2(box.position + Vector2(-2.0, 3.0), box.size), Color(0.0, 0.0, 0.0, 0.28))
		draw_rect(box, Color(0.976, 0.961, 0.914))
		var inner := box.grow(-Letter.SNAP_BORDER)
		if picture != null:
			draw_texture_rect(picture, inner, false)
		else:
			draw_rect(inner, Letter.PAPER_EDGE)
		draw_rect(inner, Color(0.0, 0.0, 0.0, 0.35), false, 1.0)
		# The pin: a dark head with a lit pixel, top middle.
		var pin := Vector2(box.size.x * 0.5, 3.0)
		draw_circle(pin, 3.5, Color(0.25, 0.08, 0.06))
		draw_circle(pin + Vector2(-1.0, -1.0), 1.2, Color(0.85, 0.45, 0.35))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in SNAPS_MOST:
		var snap := Snap.new()
		snap.visible = false
		add_child(snap)
		_snaps.append(snap)
	_close = CloseButton.new()
	_close.pressed.connect(func() -> void: close_asked.emit())
	add_child(_close)
	_door = PlankButton.new()
	_door.label = DOOR_LABEL
	_door.accent = true
	_door.size = DOOR
	_door.pressed.connect(func() -> void: close_asked.emit())
	add_child(_door)
	resized.connect(_lay_out)
	_lay_out()


## A still, loaded once. Null when the probe has not been run or its output not imported,
## and the snapshot draws a blank print rather than nothing.
func _still(name: String) -> Texture2D:
	if not _art.has(name):
		var path := ART % name
		_art[name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _art[name]


## Every still the cards name, and whether it is there. For the harness: a card with a
## blank print on it is a probe nobody re-ran.
func missing_stills() -> PackedStringArray:
	var out := PackedStringArray()
	for card: Dictionary in CARDS:
		for snap: Array in card["snaps"]:
			if _still(String(snap[0])) == null:
				out.append(String(snap[0]))
	return out


## Open it at the first card. Paging is not remembered between openings: the board is short
## and somebody opening it has come to read it, not to resume it.
func open() -> void:
	page = 0
	visible = true
	_lay_out()


## How wide the writing may be: the sheet less its margins.
func text_wide() -> float:
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	var face := Style.board_face(Rect2(Vector2.ZERO, Vector2(wide, 1000.0)), FRAME)
	return face.size.x - SHEET_INSET * 2.0 - SHEET_PAD * 2.0


func _greeting_tall() -> float:
	return float(_wrap_even(GREETING, Style.TEXT_BODY, text_wide()).size()) \
		* (float(Style.TEXT_BODY) + LINE_STEP) + GAP


## How tall the board wants to be. One number whatever card is up, by construction.
func wanted_tall() -> float:
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	var tall := Style.board_wood_tall(wide, FRAME) + SHEET_INSET * 2.0 + SHEET_PAD * 2.0
	tall += _greeting_tall() + ART_LEAST + GAP
	tall += float(Style.TEXT_HEAD) + GAP
	tall += float(SENTENCE_ROWS) * (float(Style.TEXT_BODY) + LINE_STEP) + GAP
	tall += PAGER_TALL
	return tall


## Greedy wrap on spaces. `Style.write` has no wrap, and the greeting is one long sentence.
func _wrap(text: String, px: int, wide: float) -> PackedStringArray:
	var rows := PackedStringArray()
	var row := ""
	for word in text.split(" ", false):
		var tried := word if row.is_empty() else row + " " + word
		if not row.is_empty() and Style.measure(tried, px).x > wide:
			rows.append(row)
			row = word
		else:
			row = tried
	rows.append(row)
	return rows


## The same rows, evened out: wrapped again at the narrowest width that still makes as many
## rows, so a sentence that breaks does not leave two words alone on its last line.
func _wrap_even(text: String, px: int, wide: float) -> PackedStringArray:
	var rows := _wrap(text, px, wide)
	if rows.size() < 2:
		return rows
	var narrow := wide
	while narrow > wide * 0.5:
		var tried := _wrap(text, px, narrow - 8.0)
		if tried.size() != rows.size():
			break
		narrow -= 8.0
		rows = tried
	return rows


## The size a line is written at: its own, or one rung down when its own is too wide. Zero
## when neither fits, which is a line the card may not carry.
static func _fitted(text: String, px: int, wide: float) -> int:
	if Style.measure(text, px).x <= wide:
		return px
	var down := Style.TEXT_SMALL if px > Style.TEXT_SMALL else Style.TEXT_TINY
	return down if Style.measure(text, down).x <= wide else 0


## Every line on every card that the paper cannot hold, as "card: line". The harness's
## question, asked of the arithmetic because headless never calls `_draw`.
func overruns() -> PackedStringArray:
	var out := PackedStringArray()
	var wide := text_wide()
	for card: Dictionary in CARDS:
		var lines: Array = card["lines"]
		if lines.size() > SENTENCE_ROWS:
			out.append("%s: %d lines" % [card["head"], lines.size()])
		for line: String in lines:
			if _fitted(line, Style.TEXT_BODY, wide) == 0:
				out.append("%s: %s" % [card["head"], line])
		var snaps: Array = card["snaps"]
		var each := (wide - SNAP_GAP * float(snaps.size() - 1)) / float(maxi(snaps.size(), 1))
		for snap: Array in snaps:
			# A caption has its snapshot's width and no more: its neighbour's starts there.
			if _fitted(String(snap[1]), Style.TEXT_SMALL, maxf(each, 60.0)) == 0:
				out.append("%s: %s" % [card["head"], snap[1]])
	return out


func _lay_out() -> void:
	if not is_node_ready():
		return
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	var tall := minf(wanted_tall(), size.y - 40.0)
	_board = Rect2(
		floorf((size.x - wide) * 0.5), floorf((size.y - tall) * 0.5), floorf(wide), floorf(tall)
	)
	var at := Style.close_on(_ribbon(), CLOSE_SIZE)
	_close.position = at.position
	_close.size = at.size
	_sheet = Style.board_face(_board, FRAME).grow(-SHEET_INSET)
	var inside := _sheet.grow(-SHEET_PAD)
	var last := page >= CARDS.size() - 1
	var row := inside.end.y - PAGER_TALL
	_back = Rect2(Vector2(inside.position.x, row + (PAGER_TALL - ARROW.y) * 0.5), ARROW)
	_on = Rect2(Vector2(inside.end.x - ARROW.x, _back.position.y), ARROW)
	_door.size = DOOR
	_door.position = Vector2(inside.end.x - DOOR.x, row).floor()
	_door.visible = last
	_dots.clear()
	var span := float(CARDS.size() - 1) * DOT_GAP
	# Centred on the sheet on every card, the last included: dots that slid aside to make
	# room for the door would be a pager that moves under the hand using it.
	var mid := inside.position.x + inside.size.x * 0.5
	for i in CARDS.size():
		_dots.append(Rect2(
			Vector2(mid - span * 0.5 + float(i) * DOT_GAP - DOT, row + PAGER_TALL * 0.5 - DOT),
			Vector2(DOT * 2.0, DOT * 2.0)
		))
	_pin_snaps(_art_box(inside))
	queue_redraw()


## What the pictures get: from the top of the writing room — under the greeting on the first
## card — down to the heading.
func _art_box(inside: Rect2) -> Rect2:
	var top := inside.position.y + (_greeting_tall() if page == 0 else 0.0)
	var foot := inside.end.y - PAGER_TALL - GAP \
		- float(SENTENCE_ROWS) * (float(Style.TEXT_BODY) + LINE_STEP) - GAP \
		- float(Style.TEXT_HEAD) - GAP
	return Rect2(inside.position.x, top, inside.size.x, maxf(foot - top, 40.0))


## Pin this card's photographs in a row: one height for all of them, each as wide as its own
## shape makes it, and the whole row scaled down together if it is wider than the sheet.
func _pin_snaps(box: Rect2) -> void:
	var card: Dictionary = CARDS[clampi(page, 0, CARDS.size() - 1)]
	var snaps: Array = card["snaps"]
	var captioned := false
	for snap: Array in snaps:
		captioned = captioned or not String(snap[1]).is_empty()
	var tall := box.size.y - (CAPTION_TALL if captioned else 0.0) - 6.0
	var shapes: Array[float] = []
	var total := 0.0
	for snap: Array in snaps:
		var still := _still(String(snap[0]))
		var shape := 1.4 if still == null else float(still.get_width()) / float(still.get_height())
		shapes.append(shape)
		total += shape * tall
	var room := box.size.x - SNAP_GAP * float(snaps.size() - 1)
	if total > room:
		tall *= room / total
		total = room
	_captions.clear()
	var x := box.position.x + (box.size.x - total - SNAP_GAP * float(snaps.size() - 1)) * 0.5
	var y := box.position.y + 4.0 \
		+ (box.size.y - (CAPTION_TALL if captioned else 0.0) - 6.0 - tall) * 0.5
	for i in _snaps.size():
		var node := _snaps[i]
		node.visible = i < snaps.size()
		if not node.visible:
			continue
		var name := String(snaps[i][0])
		var span := Vector2(shapes[i] * tall, tall).floor()
		node.picture = _still(name)
		node.size = span
		node.pivot_offset = span * 0.5
		node.position = Vector2(x, y).floor()
		node.rotation_degrees = (float(hash(name) % 200) / 100.0 - 1.0) * SNAP_TILT
		node.queue_redraw()
		_captions.append({
			"text": String(snaps[i][1]),
			"box": Rect2(Vector2(x, y + tall + 4.0), Vector2(span.x, CAPTION_TALL)),
		})
		x += span.x + SNAP_GAP


func _ribbon() -> Rect2:
	return Rect2(
		Vector2(_board.position.x - RIBBON_OVERHANG, _board.position.y - RIBBON_TALL * 0.5),
		Vector2(_board.size.x + RIBBON_OVERHANG * 2.0, RIBBON_TALL)
	)


## Turn to a card. Clamped rather than wrapped: the dots say how many there are, and a
## board that jumps from the last card back to the first loses the player's place.
func turn(step: int) -> void:
	var to := clampi(page + step, 0, CARDS.size() - 1)
	if to == page:
		return
	page = to
	Sfx.ui(&"ui_click")
	_lay_out()


func _forward_live() -> bool:
	return page < CARDS.size() - 1


func _gui_input(event: InputEvent) -> void:
	var move := event as InputEventMouseMotion
	if move != null:
		var was := _hovered
		_hovered = &""
		if _back.has_point(move.position) and page > 0:
			_hovered = &"back"
		elif _on.has_point(move.position) and _forward_live():
			_hovered = &"on"
		if _hovered != was:
			if _hovered != &"":
				Sfx.ui(&"ui_hover")
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if _back.has_point(click.position):
		accept_event()
		turn(-1)
		return
	if _on.has_point(click.position) and _forward_live():
		accept_event()
		turn(1)
		return
	for i in _dots.size():
		if not _dots[i].grow(DOT).has_point(click.position):
			continue
		accept_event()
		turn(i - page)
		return
	# The table round the board is the way out, as on every other board.
	if not _board.grow(RIBBON_OVERHANG).has_point(click.position):
		accept_event()
		close_asked.emit()


## Left and right page it. Escape is the owner's — the lake and the menu each back out of
## whatever they have open, and this board is one of those things.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_LEFT:
		turn(-1)
	elif key.keycode == KEY_RIGHT:
		turn(1)
	else:
		return
	get_viewport().set_input_as_handled()


## Ink on paper: no drop shadow. `Style.write` shades every label for standing on dark wood
## or open water, and under dark ink on a pale sheet that shade is a smudge.
func _ink(text: String, px: int, base: float, within: Rect2, ink: Color) -> void:
	var sized := _fitted(text, px, within.size.x)
	if sized == 0:
		dropped_lines += 1
		sized = Style.TEXT_TINY
	var span := Style.measure(text, sized).x
	draw_string(
		Style.font(), Vector2(floorf(within.position.x + (within.size.x - span) * 0.5), base),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, sized, ink
	)


func _draw() -> void:
	if _board.size.x <= 0.0:
		return
	dropped_lines = 0
	Style.dim(self, Rect2(Vector2.ZERO, size), Style.SCRIM)
	var face := Style.board_wood(self, _board, FRAME, CHIPS)
	draw_rect(face, Style.BOARD, true)
	var ribbon := _ribbon()
	Style.board_ribbon(
		self, ribbon, TITLE, CHIPS, Style.TEXT_HEAD, Style.title_room(ribbon, CLOSE_SIZE),
		Style.BOARD
	)
	_draw_sheet()
	var inside := _sheet.grow(-SHEET_PAD)
	var card: Dictionary = CARDS[clampi(page, 0, CARDS.size() - 1)]
	if page == 0:
		var y := inside.position.y
		for row in _wrap_even(GREETING, Style.TEXT_BODY, inside.size.x):
			y += float(Style.TEXT_BODY)
			_ink(row, Style.TEXT_BODY, y, inside, INK)
			y += LINE_STEP
	for caption: Dictionary in _captions:
		var text := String(caption["text"])
		if text.is_empty():
			continue
		var box: Rect2 = caption["box"]
		_ink(text, Style.TEXT_SMALL, box.position.y + float(Style.TEXT_SMALL), box, SOFT_INK)
	# Bottom up from the pager, the way the layout was measured.
	var lines: Array = card["lines"]
	var row_tall := float(Style.TEXT_BODY) + LINE_STEP
	var text_top := inside.end.y - PAGER_TALL - GAP - float(SENTENCE_ROWS) * row_tall
	# A short sentence stands in the middle of the room two rows leave, not at its top.
	var y_text := text_top + (float(SENTENCE_ROWS - mini(lines.size(), SENTENCE_ROWS)) * row_tall) * 0.5
	for i in mini(lines.size(), SENTENCE_ROWS):
		y_text += float(Style.TEXT_BODY)
		_ink(String(lines[i]), Style.TEXT_BODY, y_text, inside, INK)
		y_text += LINE_STEP
	if lines.size() > SENTENCE_ROWS:
		dropped_lines += lines.size() - SENTENCE_ROWS
	var head_base := text_top - GAP
	_ink(String(card["head"]), Style.TEXT_HEAD, head_base, inside, HEAD_INK)
	# A ruled line either side of the heading, the way a letter's sections are set off.
	var head_wide := Style.measure(String(card["head"]), Style.TEXT_HEAD).x
	var rule_y := floorf(head_base - float(Style.TEXT_HEAD) * 0.36)
	var mid := inside.position.x + inside.size.x * 0.5
	draw_line(Vector2(inside.position.x + 24.0, rule_y),
		Vector2(mid - head_wide * 0.5 - 12.0, rule_y), PAPER_RULE, 1.0)
	draw_line(Vector2(mid + head_wide * 0.5 + 12.0, rule_y),
		Vector2(inside.end.x - 24.0, rule_y), PAPER_RULE, 1.0)
	_draw_pager()


## The sheet: paper with bites torn out of its edges in the planks' own V, a darker line
## just inside the edge, and no black rim round the tears — that rim is what a hole in wood
## wears, and this is not wood.
func _draw_sheet() -> void:
	var seed := 2409
	var bites := Style.v_all(Style.frame_bites(_sheet, seed, SHEET_BITES), _sheet)
	draw_rect(Rect2(_sheet.position + Vector2(-2.0, 3.0), _sheet.size), Color(0.0, 0.0, 0.0, 0.3))
	Style.fill_carved(self, Style.rect_poly(_sheet), bites, PAPER_EDGE)
	Style.fill_carved(self, Style.rect_poly(_sheet.grow(-2.0)), bites, PAPER, 1.0)


func _draw_pager() -> void:
	_draw_arrow(_back, -1, page > 0, _hovered == &"back")
	if _forward_live():
		_draw_arrow(_on, 1, true, _hovered == &"on")
	for i in _dots.size():
		var mid := _dots[i].get_center()
		draw_circle(mid, DOT + 1.0, INK)
		draw_circle(mid, DOT, HEAD_INK if i == page else PAPER)


## The settings board's own arrow plank. The back arrow is drawn back rather than hidden on
## the first card, so the pager's left end does not come and go; the forward one gives its
## place to the door on the last.
func _draw_arrow(box: Rect2, step: int, live: bool, hovered: bool) -> void:
	Style.plank(self, box, int(box.position.y) * 7 + step,
		Style.FRAME.lightened(0.12) if hovered else Style.FRAME, 2.0)
	var mid := box.get_center()
	var reach := Vector2(5.0, 7.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(mid.x + reach.x * float(step), mid.y),
			Vector2(mid.x - reach.x * float(step), mid.y - reach.y),
			Vector2(mid.x - reach.x * float(step), mid.y + reach.y),
		]),
		Style.RIBBON_INK if live else Style.FRAME.darkened(0.25)
	)
