## The letter: the game's four-card onboarding, on one board in the shop's wood.
##
## A new game lands the angler and his dog by boat, walks him to the shed and opens this
## (see the arrival section of `lake.gd`). It is the whole of the tutorial, by decision
## (2026-09-19, `/grill-me` with Richard, issue #24): no contextual prompts, no unlock
## pacing, no checklist. Four cards, read once, then the player is on their own.
##
## **Every card's picture is the game's own drawing, built in code.** The net card draws the
## three real aim-ring colours off `CastNet`, the upgrades card draws the upgrades button
## through `HudButtons.draw_upgrades`, the tier card draws five real rubbish sprites out of
## the lake's own def list, and the decoration card draws the shed button. Nothing here is
## painted art, and nothing here can drift from the game it is explaining — a repainted
## ring or a retuned button moves the card with it. What the board is handed is what the
## HUD is already handed (`Lake._lend_button_art` -> `UiButton.sprites`).
##
## **One card at a time**, `◂ ▸` and a row of dots, the close cross up from the first card so
## nobody is trapped, and the last card's door reading "Start cleaning" as the intended way
## out. All four read the same way once the intro is over: the main menu's "How to play"
## plank, above Credits, opens this same board.
##
## The board is **one height whatever card is up**: the sentence's rows and the door's plank
## are reserved on every card. A board that resized as it was paged through would jump under
## the pointer that is paging it.
class_name Letter
extends Control

const Style := preload("res://scripts/style.gd")
# Preloaded rather than reached for by name, for the reason its own header gives: it has no
# `class_name`, so the global class is not in scope on a headless tool run.
const HudButtons := preload("res://scripts/hud_buttons.gd")

const TITLE := "A letter"

## The line above the cards, said once and on every card: what the letter is actually for.
const GREETING := "Congratulations, you are the new owner of My Dirty Little Lake."

## The cards, in order. `art` names the drawing `_draw_art` puts in the picture box.
const CARDS := [
	{
		"art": &"net",
		"head": "Net",
		"lines": [
			"Cast your net to catch what floats.",
			"Green catches. Red has nothing to lift. White is out of range.",
		],
	},
	{
		"art": &"upgrades",
		"head": "Upgrades",
		"lines": [
			"Upgrade your net, your boats and your dogs",
			"to clean and recycle faster.",
		],
	},
	{
		"art": &"tiers",
		"head": "Weight",
		"lines": [
			"Heavier things sit in five tiers.",
			"Strength is the upgrade that opens the next one.",
		],
	},
	{
		"art": &"decor",
		"head": "Decoration",
		"lines": [
			"Some catches are furniture.",
			"Wash it at the pump, then stand it in your shed.",
		],
	},
]

## The last card's door. The only labelled way out; the cross is the other one.
const DOOR_LABEL := "Start cleaning"
const DOOR := Vector2(196.0, 48.0)

## The board, in the 1280-wide design frame. The credits board's numbers, wider for the
## pictures.
const BOARD_WIDE := 540.0
const BOARD_PAD := 20.0
const FRAME := 12.0
const RIBBON_TALL := 36.0
const RIBBON_OVERHANG := 10.0
const CHIPS := 3
const CLOSE_SIZE := 44.0

## The picture box, and the gaps between the blocks under it.
const ART_TALL := 118.0
const GAP := 12.0
## Rows reserved for a card's sentence, whatever this card says. Two lines is what the
## longest card wants; the shortest reserves them anyway (see the header).
const SENTENCE_ROWS := 2
const LINE_STEP := 6.0

## The pager: the arrow planks either side and the dots between them.
const ARROW := Vector2(26.0, 30.0)
const DOT := 5.0
const DOT_GAP := 14.0
const PAGER_TALL := 30.0

## The net card's three rings, as fractions of the picture box's width, and the 2:1 of every
## ellipse in this game.
const RING_WIDE := 0.24
const RING_STEPS := 40
const RING_LINE := 2.0
const RING_BACK := 4.0
const RING_LABELS := ["Catch", "Nothing", "Too far"]

## The tier card: how much of the picture box's height the tallest piece fills, and how far
## a piece may ever be blown up. The lake draws its rubbish at 2; three is as far as a small
## sprite can be pushed before it reads as a blown-up picture rather than a piece.
const TIER_FILL := 0.62
const TIER_MOST := 3

signal close_asked

## The lake's lent art, the HUD's own dictionary (`boat`, `net`, `shed`, `decor`). Set by
## `Lake._dress_letter`, which dresses this board and the menu's copy from one place.
var sprites: Dictionary = {}
## One rubbish def per tier, lightest first, for the weight card. Empty draws nothing.
var tiers: Array = []

## Which card is up.
var page: int = 0

## Set by `_draw` when a row did not fit in the face: the settings, bind and credits boards'
## own counter, and `test_lake` asks it for zero at 1280x720.
var dropped_lines: int = 0

var _board := Rect2()
var _close: CloseButton
var _door: PlankButton
var _back := Rect2()
var _on := Rect2()
var _dots: Array[Rect2] = []
var _hovered: StringName = &""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The pieces on the weight card are the lake's own sprites blown up, and this is pixel
	# art: filtered, they come out as smudges.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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


## Open it at the first card. Paging is not remembered between openings: the board is short
## and somebody opening it has come to read it, not to resume it.
func open() -> void:
	page = 0
	visible = true
	_lay_out()


## How tall the board wants to be. One number whatever card is up, by construction.
func wanted_tall() -> float:
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	var face_wide := Style.board_face(Rect2(Vector2.ZERO, Vector2(wide, 1000.0)), FRAME).size.x
	var tall := Style.board_wood_tall(wide, FRAME) + BOARD_PAD * 2.0
	for row in _wrap(GREETING, Style.TEXT_BODY, face_wide):
		tall += float(Style.TEXT_BODY) + LINE_STEP
	tall += GAP + ART_TALL + GAP
	tall += float(Style.TEXT_HEAD) + GAP
	tall += float(SENTENCE_ROWS) * (float(Style.TEXT_BODY) + LINE_STEP) + GAP
	tall += PAGER_TALL + GAP + DOOR.y
	return tall


## Greedy wrap on spaces. `Style.write` has no wrap, and the greeting is one long sentence
## that has to survive a narrow board.
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
	var face := Style.board_face(_board, FRAME)
	_door.size = DOOR
	_door.position = Vector2(
		face.position.x + (face.size.x - DOOR.x) * 0.5, face.end.y - BOARD_PAD - DOOR.y
	).floor()
	# The door is the last card's alone: on the others there is still something to read.
	_door.visible = page >= CARDS.size() - 1
	var pager := _door.position.y - GAP - PAGER_TALL
	_back = Rect2(Vector2(face.position.x, pager), ARROW)
	_on = Rect2(Vector2(face.end.x - ARROW.x, pager), ARROW)
	_dots.clear()
	var span := float(CARDS.size() - 1) * DOT_GAP
	var mid := face.position.x + face.size.x * 0.5
	for i in CARDS.size():
		_dots.append(Rect2(
			Vector2(mid - span * 0.5 + float(i) * DOT_GAP - DOT, pager + PAGER_TALL * 0.5 - DOT),
			Vector2(DOT * 2.0, DOT * 2.0)
		))
	queue_redraw()


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


func _gui_input(event: InputEvent) -> void:
	var move := event as InputEventMouseMotion
	if move != null:
		var was := _hovered
		_hovered = &""
		if _back.has_point(move.position):
			_hovered = &"back"
		elif _on.has_point(move.position):
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
	if _on.has_point(click.position):
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


func _draw() -> void:
	if _board.size.x <= 0.0:
		return
	dropped_lines = 0
	Style.dim(self, Rect2(Vector2.ZERO, size), Style.SCRIM)
	var face := Style.board_wood(self, _board, FRAME, CHIPS)
	draw_rect(face, Style.BOARD, true)
	var ribbon := _ribbon()
	Style.board_ribbon(
		self, ribbon, TITLE, CHIPS, Style.TEXT_HEAD, Style.title_room(ribbon, CLOSE_SIZE)
	)
	var inside := face.grow(-BOARD_PAD)
	var y := inside.position.y
	for row in _wrap(GREETING, Style.TEXT_BODY, inside.size.x):
		y += float(Style.TEXT_BODY)
		Style.write(
			self, row, Style.TEXT_BODY, Vector2(0.0, y), Style.BOARD_INK,
			HORIZONTAL_ALIGNMENT_CENTER, inside
		)
		y += LINE_STEP
	y += GAP
	var card: Dictionary = CARDS[clampi(page, 0, CARDS.size() - 1)]
	_draw_art(card["art"] as StringName, Rect2(inside.position.x, y, inside.size.x, ART_TALL))
	y += ART_TALL + GAP
	y += float(Style.TEXT_HEAD)
	Style.write(
		self, String(card["head"]), Style.TEXT_HEAD, Vector2(0.0, y), Style.RIBBON_INK,
		HORIZONTAL_ALIGNMENT_CENTER, inside
	)
	y += GAP
	var lines: Array = card["lines"]
	for i in SENTENCE_ROWS:
		y += float(Style.TEXT_BODY)
		if i < lines.size():
			Style.write(
				self, String(lines[i]), Style.TEXT_BODY, Vector2(0.0, y), Style.BOARD_INK,
				HORIZONTAL_ALIGNMENT_CENTER, inside
			)
		y += LINE_STEP
	if lines.size() > SENTENCE_ROWS:
		dropped_lines += lines.size() - SENTENCE_ROWS
	if y > _door.position.y:
		dropped_lines += 1
	_draw_pager()


func _draw_pager() -> void:
	_draw_arrow(_back, -1, page > 0)
	_draw_arrow(_on, 1, page < CARDS.size() - 1)
	for i in _dots.size():
		var mid := _dots[i].get_center()
		var lit := i == page
		draw_circle(mid, DOT + 1.0, Style.HOLE_RIM)
		draw_circle(mid, DOT, Style.ON_WATER if lit else Style.BOARD_INK_SOFT)


## The settings board's own arrow plank, drawn back rather than hidden at either end: a
## pager whose arrows come and go is a pager that moves under the hand using it.
func _draw_arrow(box: Rect2, step: int, live: bool) -> void:
	Style.plank(self, box, int(box.position.y) * 7 + step, Style.FRAME, 2.0)
	var mid := box.get_center()
	var reach := Vector2(5.0, 7.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(mid.x + reach.x * float(step), mid.y),
			Vector2(mid.x - reach.x * float(step), mid.y - reach.y),
			Vector2(mid.x - reach.x * float(step), mid.y + reach.y),
		]),
		Style.RIBBON_INK if live else Style.BOARD_INK_SOFT
	)


func _draw_art(which: StringName, box: Rect2) -> void:
	match which:
		&"net":
			_draw_rings(box)
		&"upgrades":
			_draw_button(box, true)
		&"tiers":
			_draw_tiers(box)
		&"decor":
			_draw_button(box, false)


## The three aim rings, in the marker's own colours and its own backing line, side by side
## with what each one means under it. Read off `CastNet` rather than written down here, so
## a repainted ring repaints the card.
func _draw_rings(box: Rect2) -> void:
	var tints := [CastNet.AIM_OK, CastNet.AIM_NO, CastNet.AIM_FAR]
	var alphas := [CastNet.AIM_ALPHA, CastNet.AIM_ALPHA, CastNet.AIM_FAR_ALPHA]
	var wide := box.size.x * RING_WIDE
	var step := box.size.x / 3.0
	var mid := box.position.y + box.size.y * 0.40
	for i in 3:
		var at := Vector2(box.position.x + step * (float(i) + 0.5), mid)
		var ring := PackedVector2Array()
		for s in RING_STEPS + 1:
			var a := TAU * float(s) / float(RING_STEPS)
			ring.append(at + Vector2(cos(a) * wide * 0.5, sin(a) * wide * 0.25))
		var alpha: float = alphas[i]
		var back := Color(
			CastNet.AIM_BACK.r, CastNet.AIM_BACK.g, CastNet.AIM_BACK.b,
			CastNet.AIM_BACK_SHARE * alpha / CastNet.AIM_ALPHA
		)
		draw_polyline(ring, back, RING_BACK)
		var tint: Color = tints[i]
		draw_polyline(ring, Color(tint.r, tint.g, tint.b, alpha), RING_LINE)
		Style.write(
			self, RING_LABELS[i], Style.TEXT_SMALL,
			Vector2(0.0, box.end.y - 2.0), Style.BOARD_INK, HORIZONTAL_ALIGNMENT_CENTER,
			Rect2(Vector2(box.position.x + step * float(i), box.position.y), Vector2(step, 1.0))
		)


## The HUD's own button, drawn at the size it is drawn in the corner of the screen: the card
## is a picture of the thing the player is about to press.
func _draw_button(box: Rect2, upgrades: bool) -> void:
	var span := Vector2(120.0, 100.0)
	var at := Rect2(
		Vector2(box.position.x + (box.size.x - span.x) * 0.5,
			box.position.y + (box.size.y - span.y) * 0.5).floor(),
		span
	)
	if upgrades:
		HudButtons.draw_upgrades(self, at, false, sprites)
		HudButtons.label(self, HudButtons.face_of(at), "Upgrades")
	else:
		HudButtons.draw_shed(self, at, false, sprites)


## Five real pieces, one per tier, lightest on the left, each with its tier under it. Drawn
## off the lake's own def list, so a repainted piece or a retuned sprite scale moves the card.
##
## **One scale for all five, and a whole number of pixels.** One scale because the card is
## about weight and the sizes are half of what says it — scaled to fill its own column each,
## a bottle cap would stand as tall as a sofa. A whole number because this is pixel art: the
## pieces are the lake's own sprites and a fractional blow-up is a smudge.
func _draw_tiers(box: Rect2) -> void:
	if tiers.is_empty():
		return
	var step := box.size.x / float(tiers.size())
	var room := box.size.y * TIER_FILL
	var fit := float(TIER_MOST)
	for def: TrashDef in tiers:
		if def == null:
			continue
		fit = minf(fit, minf(room / maxf(def.size.y, 1.0), step * 0.8 / maxf(def.size.x, 1.0)))
	fit = maxf(floorf(fit), 1.0)
	for i in tiers.size():
		var def: TrashDef = tiers[i]
		if def == null:
			continue
		draw_set_transform(
			Vector2(box.position.x + step * (float(i) + 0.5), box.position.y + box.size.y * 0.40),
			0.0, Vector2(fit, fit)
		)
		def.stamp(self)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Style.write(
			self, str(i + 1), Style.TEXT_SMALL, Vector2(0.0, box.end.y - 2.0),
			Style.BOARD_INK, HORIZONTAL_ALIGNMENT_CENTER,
			Rect2(Vector2(box.position.x + step * float(i), box.position.y), Vector2(step, 1.0))
		)
