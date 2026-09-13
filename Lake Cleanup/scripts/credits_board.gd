## The credits: one board in the shop's wood, a title plank, and the names.
##
## Drawn from `Style` like the settings board, so it is the same board with different words
## on it. The words are placeholder lines (2026-09-12) in one constant: the maker, and the
## asset packs already cleared in `docs/CREDITS.md`. Rewrite `LINES` when the list is final;
## nothing else here knows what they say. An empty string is a gap.
class_name CreditsBoard
extends Control

const Style := preload("res://scripts/style.gd")

const TITLE := "Credits"

const LINES := [
	"My Dirty Little Lake",
	"",
	"Design and programming",
	"Richard Wolter",
	"",
	"Pigeons — Pop Shop Packs",
	"Boat — @Pixel_Salvaje",
	"",
	"Thanks for playing.",
]

## Which lines are headings: set a size up, in the ribbon's ink.
const HEADS := ["My Dirty Little Lake", "Design and programming"]

## The board, in the 1280-wide design frame. The settings board's numbers.
const BOARD_WIDE := 460.0
const BOARD_PAD := 18.0
const FRAME := 12.0
const RIBBON_TALL := 36.0
const RIBBON_OVERHANG := 10.0
const CHIPS := 3
const CLOSE_SIZE := 44.0
const LINE_GAP := 8.0
const BLANK := 12.0

signal close_asked

var _board := Rect2()
var _close: CloseButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_close = CloseButton.new()
	_close.pressed.connect(func() -> void: close_asked.emit())
	add_child(_close)
	resized.connect(_lay_out)
	_lay_out()


func _line_tall(text: String) -> float:
	if text.is_empty():
		return BLANK
	return float(Style.TEXT_HEAD if text in HEADS else Style.TEXT_BODY) + LINE_GAP


func _lay_out() -> void:
	if not is_node_ready():
		return
	# The rows start at the face's top, under the frame's wood, so the words sit centred
	# in the board rather than crowding its title.
	var tall := Style.board_wood_tall(BOARD_WIDE, FRAME) + BOARD_PAD
	for text: String in LINES:
		tall += _line_tall(text)
	tall += BOARD_PAD
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	tall = minf(tall, size.y - 40.0)
	_board = Rect2(floorf((size.x - wide) * 0.5), floorf((size.y - tall) * 0.5), wide, tall)
	var at := Style.close_on(_ribbon(), CLOSE_SIZE)
	_close.position = at.position
	_close.size = at.size
	queue_redraw()


func _ribbon() -> Rect2:
	return Rect2(
		Vector2(_board.position.x - RIBBON_OVERHANG, _board.position.y - RIBBON_TALL * 0.5),
		Vector2(_board.size.x + RIBBON_OVERHANG * 2.0, RIBBON_TALL)
	)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	# The table round the board is the way out.
	if not _board.grow(RIBBON_OVERHANG).has_point(click.position):
		accept_event()
		close_asked.emit()


func _draw() -> void:
	if _board.size.x <= 0.0:
		return
	Style.dim(self, Rect2(Vector2.ZERO, size), Style.SCRIM)
	var face := Style.board_wood(self, _board, FRAME, CHIPS)
	draw_rect(face, Style.BOARD, true)
	var ribbon := _ribbon()
	Style.board_ribbon(
		self, ribbon, TITLE, CHIPS, Style.TEXT_HEAD, Style.title_room(ribbon, CLOSE_SIZE)
	)
	var y := face.position.y + BOARD_PAD
	for text: String in LINES:
		var tall := _line_tall(text)
		if not text.is_empty():
			var head := text in HEADS
			var px := Style.TEXT_HEAD if head else Style.TEXT_BODY
			Style.write(
				self, text, px, Vector2(0.0, y + float(px) * 0.82),
				Style.RIBBON_INK if head else Style.BOARD_INK, HORIZONTAL_ALIGNMENT_CENTER, face
			)
		y += tall
		if y > face.end.y - BOARD_PAD:
			break
