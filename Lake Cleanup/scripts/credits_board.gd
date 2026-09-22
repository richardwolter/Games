## The credits: one board in the shop's wood, a title plank, and the names.
##
## Drawn from `Style` like the settings board, so it is the same board with different words
## on it. `LINES` is the whole of what it says; nothing else here knows. An empty string is
## a gap.
##
## Each art line is that pack's **own required credit wording** (2026-09-16, Richard's call),
## not a handle — Zato's licence names the exact string, Penzilla's licence names theirs. The
## in-game board never says what an asset is; `docs/CREDITS.md` keeps that mapping, and the
## licence status with it. AI-generated art is not credited, by decision.
##
## The **Tools** heading carries one line the licences do not ask for: Godot is MIT and needs
## no attribution (2026-09-19, Richard). It is here because a player who wants to know what
## the game is made with has nowhere else to look, and because a second heading costs the
## board 64 px of the 266 it has spare. The font is not listed for the same reason the AI art
## is not: Bungee's OFL asks for nothing, and a list of everything that asks for nothing has
## no end. Required credits are what the art heading is for.
##
## A line wider than the face **wraps** rather than being cut or shrunk: the required strings
## are long and none of them may be shortened. `Style.write` has no wrap, so `_wrap` does it
## here, greedily on spaces, and the rows of one line are set `WRAP_GAP` apart so a wrapped
## credit still reads as one entry.
class_name CreditsBoard
extends Control

## Retired, by decision (2026-09-16, Richard): the closing "Thanks for playing." line. The
## farewell's own second line says it, and on the board there is nobody to thank for having
## opened a list of credits. These are the credits and nothing else.

const Style := preload("res://scripts/style.gd")

const TITLE := "Credits"

const LINES := [
	"Design and programming",
	"Modern Daedalus Studio",
	"",
	"Music and sound",
	"Nuven",
	"",
	"Art and Assets",
	"Benvictus",
	"xStrax",
	"Graphics created by Penzilla Design",
	"limezu.itch.io",
	"Kipperfalcon",
	"Kenney",
	"Asset by Zato - https://zatoart.itch.io/",
	"Pop Shop Packs",
	"@Pixel_Salvaje",
	"",
	"Tools",
	"Made with Godot Engine",
]

## Which lines are headings: set a size up, in the ribbon's ink.
const HEADS := ["Design and programming", "Music and sound", "Art and Assets", "Tools"]

## The line the Spotify mark stands beside, and the mark itself.
##
## Spotify's brand guidelines forbid redrawing, recolouring or distorting the logo, so this is
## their own file, trimmed and resampled by `tools/build_spotify_icon.py` and nothing else. It
## is a smooth vector mark rather than pixel art, so it is drawn by a child `TextureRect` of
## its own at a **linear** filter — the board's wood keeps whatever filter it draws at.
## Decoration only, by decision (2026-09-16): no click, no hover.
const ICON_LINE := "Nuven"
const ICON_PATH := "res://assets/ui/spotify_icon.png"
const ICON_SIZE := 22.0
const ICON_GAP := 7.0

## The board, in the 1280-wide design frame. The settings board's numbers.
const BOARD_WIDE := 460.0
const BOARD_PAD := 18.0
const FRAME := 12.0
const RIBBON_TALL := 36.0
const RIBBON_OVERHANG := 10.0
const CHIPS := 3
const CLOSE_SIZE := 44.0
const LINE_GAP := 8.0
const WRAP_GAP := 2.0
const BLANK := 12.0

signal close_asked

## Set by `_draw` when a row did not fit in the board and was not drawn — the settings and
## bind boards' own counter, brought here because this board drops its bottom rows in
## silence too, and the bottom of this board is somebody's required credit. Nothing in the
## game reads it: it is there so a credit going missing is a failure rather than a surprise.
var dropped_lines: int = 0

var _board := Rect2()
var _rows: Array[Dictionary] = []
var _close: CloseButton
var _icon: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_close = CloseButton.new()
	_close.pressed.connect(func() -> void: close_asked.emit())
	add_child(_close)
	var art := load(ICON_PATH) as Texture2D
	if art != null:
		_icon = TextureRect.new()
		_icon.texture = art
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_SCALE
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)
	resized.connect(_lay_out)
	_lay_out()


## How wide the mark and its gap are on the line they stand beside — nothing, with no art.
##
## Asked of the **art**, not of the node: `_icon` is built in `_ready`, and a board measured
## before that (the probe, which lays rows out without waiting a frame) would reserve nothing
## for a mark the drawn board does reserve for. Static for the same reason.
static func icon_room() -> float:
	return 0.0 if load(ICON_PATH) == null else ICON_SIZE + ICON_GAP


func _icon_room() -> float:
	return icon_room()


## One line of `LINES` broken into the rows it is drawn as. Greedy on spaces; a single word
## too wide for the face is left long rather than cut, since none of these strings may be
## shortened.
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


## The rows the board draws, measured against a face of this width: the text, its size, its
## ink, how much room the mark wants on it, and how far down to step after it.
func _laid_out(face_wide: float) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for text: String in LINES:
		if text.is_empty():
			rows.append({"text": "", "px": 0, "head": false, "icon": 0.0, "step": BLANK})
			continue
		var head: bool = text in HEADS
		var px := Style.TEXT_HEAD if head else Style.TEXT_BODY
		var room := _icon_room() if text == ICON_LINE else 0.0
		var wrapped := _wrap(text, px, face_wide - room)
		for i in wrapped.size():
			var last := i == wrapped.size() - 1
			rows.append({
				"text": wrapped[i],
				"px": px,
				"head": head,
				"icon": room if i == 0 else 0.0,
				"step": float(px) + (LINE_GAP if last else WRAP_GAP),
			})
	return rows


## How tall the board would like to be, in design pixels, for the window it has been given.
## The settings and bind boards' own accessor: `test_lake` asks it at 1280x720, where the
## room is 680, because a board that wants more than that drops its bottom rows — and the
## bottom of this board is somebody's required credit.
func wanted_tall() -> float:
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	var tall := Style.board_wood_tall(wide, FRAME) + BOARD_PAD * 2.0
	for row in _laid_out(Style.board_face(Rect2(Vector2.ZERO, Vector2(wide, 1000.0)), FRAME).size.x):
		tall += float(row["step"])
	return tall


func _lay_out() -> void:
	if not is_node_ready():
		return
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	# The face's width does not depend on the board's height, so the rows can be wrapped
	# before the height they add up to is known.
	var face_wide := Style.board_face(Rect2(Vector2.ZERO, Vector2(wide, 1000.0)), FRAME).size.x
	_rows = _laid_out(face_wide)
	# The rows start at the face's top, under the frame's wood, so the words sit centred
	# in the board rather than crowding its title.
	var tall := Style.board_wood_tall(wide, FRAME) + BOARD_PAD * 2.0
	for row in _rows:
		tall += float(row["step"])
	tall = minf(tall, size.y - 40.0)
	_board = Rect2(floorf((size.x - wide) * 0.5), floorf((size.y - tall) * 0.5), wide, tall)
	var at := Style.close_on(_ribbon(), CLOSE_SIZE)
	_close.position = at.position
	_close.size = at.size
	_place_icon()
	queue_redraw()


## Where a row's text starts: the mark, its gap and the writing are centred on the face as
## one, so a line with the mark on it is not pushed off centre by it.
func _row_start(row: Dictionary, face: Rect2) -> float:
	var span := Style.measure(String(row["text"]), int(row["px"])).x
	return face.position.x + (face.size.x - span - float(row["icon"])) * 0.5 + float(row["icon"])


func _place_icon() -> void:
	if _icon == null:
		return
	_icon.visible = false
	if _board.size.x <= 0.0:
		return
	var face := Style.board_face(_board, FRAME)
	var y := face.position.y + BOARD_PAD
	for row in _rows:
		var step := float(row["step"])
		if float(row["icon"]) > 0.0:
			# Centred on the writing's own middle, so the mark sits with the name rather
			# than on its baseline.
			_icon.position = Vector2(
				_row_start(row, face) - _icon_room(),
				y + (float(row["px"]) - ICON_SIZE) * 0.5
			).floor()
			_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
			_icon.visible = y + step <= face.end.y - BOARD_PAD
			return
		y += step


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
	draw_rect(face, Style.PAPER, true)
	var ribbon := _ribbon()
	Style.board_ribbon(
		self, ribbon, TITLE, CHIPS, Style.TEXT_HEAD, Style.title_room(ribbon, CLOSE_SIZE)
	)
	var y := face.position.y + BOARD_PAD
	dropped_lines = 0
	var room := true
	for row in _rows:
		var text := String(row["text"])
		if not room:
			if not text.is_empty():
				dropped_lines += 1
			continue
		if not text.is_empty():
			var px := int(row["px"])
			Style.write(
				self, text, px,
				Vector2(_row_start(row, face), y + float(px) * 0.82),
				Style.PAPER_HEAD if bool(row["head"]) else Style.PAPER_INK
			)
		y += float(row["step"])
		if y > face.end.y - BOARD_PAD:
			# Out of face. The rest are counted rather than drawn, so the loss is a number
			# somebody can ask for instead of a credit nobody notices is gone.
			room = false
