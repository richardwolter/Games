## A question with two answers, on a small board.
##
## "Start over?" is the one the menu asks: New game over a saved lake throws the save away,
## and that is the only thing the menu can do that cannot be undone. A small board in the
## shop's wood: a title plank, a line of what will happen, and two button planks drawn as the
## settings board draws its own — the warning one in the danger ink, the safe one plain.
## Drawn, not a ConfirmationDialog: a grey engine popup over the capsule art would be the one
## thing on the screen from a different game.
##
## **The words are the caller's** (2026-09-16, issue #26), with the menu's own as the
## defaults. The settings board asks the second question in the game — whether an exclusive
## fullscreen mode is one the monitor can actually show — and a board that could only say
## "Start over?" would have meant a second one of these beside it.
class_name MenuConfirm
extends Control

const Style := preload("res://scripts/style.gd")

const TITLE := "Start over?"
const WORDS := "The saved lake will be thrown away."
const YES := "Start over"
const NO := "Keep it"

var title: String = TITLE:
	set(v):
		title = v
		queue_redraw()
## The line under the title, or "" for a board that needs none — a question whose two doors
## already say what each of them does.
var words: String = WORDS:
	set(v):
		words = v
		_lay_out()
var yes_label: String = YES:
	set(v):
		yes_label = v
		queue_redraw()
var no_label: String = NO:
	set(v):
		no_label = v
		queue_redraw()

## The board's own width, and what a caller may ask for instead. **420, up from 400**
## (2026-09-17): the menu's own line, "The saved lake will be thrown away.", measures 348
## against the 338 a 400-wide board leaves it, and `Style.write` neither wraps nor clips — so
## it had been running ten pixels off its own face. Measured by `tools/probe_confirm.gd`.
##
## One width for every caller, and the caller's words are what have to fit it: a door is 174
## and the line 358. `test_lake` measures both for each caller, because `Style.write` will
## draw a word straight off the wood rather than wrap or cut it.
const BOARD_WIDE := 420.0
const BOARD_PAD := 16.0
const FRAME := 12.0
const RIBBON_TALL := 36.0
const RIBBON_OVERHANG := 10.0
const CHIPS := 3
const ROW_TALL := 40.0
const ROW_GAP := 10.0
const WORDS_TALL := 30.0
## What a board with no line puts above its doors instead. Not nothing: the title plank
## straddles the board's top edge and hangs into the face, so doors set straight against
## `BOARD_PAD` come up under the plank's bitten foot.
const WORDLESS_AIR := 10.0

signal confirmed
signal cancelled

var _board := Rect2()
## `{key, box}` for the two planks, as last drawn.
var _doors: Array = []
var _hovered: StringName = &""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_lay_out)
	_lay_out()


func _lay_out() -> void:
	if not is_node_ready():
		return
	# From the face's top, under the frame's wood, so the words and the doors sit centred.
	# A board given no line to say is a title and two doors. The band is not left standing
	# empty: a gap where a sentence used to be reads as a sentence that failed to draw.
	var tall := Style.board_wood_tall(BOARD_WIDE, FRAME) + BOARD_PAD + ROW_TALL + BOARD_PAD
	tall += WORDS_TALL + ROW_GAP if not words.is_empty() else WORDLESS_AIR
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	_board = Rect2(floorf((size.x - wide) * 0.5), floorf((size.y - tall) * 0.5), wide, tall)
	queue_redraw()


func _ribbon() -> Rect2:
	return Rect2(
		Vector2(_board.position.x - RIBBON_OVERHANG, _board.position.y - RIBBON_TALL * 0.5),
		Vector2(_board.size.x + RIBBON_OVERHANG * 2.0, RIBBON_TALL)
	)


func _door_under(at: Vector2) -> StringName:
	for door: Dictionary in _doors:
		if (door["box"] as Rect2).has_point(at):
			return door["key"]
	return &""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was := _hovered
		_hovered = _door_under((event as InputEventMouseMotion).position)
		if was != _hovered:
			if _hovered != &"":
				Sfx.ui(&"ui_hover")
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	match _door_under(click.position):
		&"yes":
			confirmed.emit()
		&"no":
			cancelled.emit()
		_:
			# Off the board is "keep it": the safe answer to a click that was not an answer.
			if not _board.grow(RIBBON_OVERHANG).has_point(click.position):
				cancelled.emit()


func _draw() -> void:
	if _board.size.x <= 0.0:
		return
	Style.dim(self, Rect2(Vector2.ZERO, size), Style.SCRIM)
	var face := Style.board_wood(self, _board, FRAME, CHIPS)
	draw_rect(face, Style.BOARD, true)
	Style.board_ribbon(self, _ribbon(), title, CHIPS, Style.TEXT_HEAD)

	var y := face.position.y + BOARD_PAD + (0.0 if not words.is_empty() else WORDLESS_AIR)
	if not words.is_empty():
		Style.write(
			self, words, Style.TEXT_BODY, Vector2(0.0, y + float(Style.TEXT_BODY) * 0.9),
			Style.BOARD_INK, HORIZONTAL_ALIGNMENT_CENTER, face
		)
		y += WORDS_TALL + ROW_GAP

	_doors.clear()
	var left := face.position.x + BOARD_PAD
	var wide := (face.size.x - BOARD_PAD * 2.0 - ROW_GAP) * 0.5
	_draw_door(Rect2(left, y, wide, ROW_TALL), &"yes", yes_label, true)
	_draw_door(Rect2(left + wide + ROW_GAP, y, wide, ROW_TALL), &"no", no_label, false)


## A button plank, as the settings board draws its rows.
func _draw_door(box: Rect2, key: StringName, label: String, warn: bool) -> void:
	_doors.append({"key": key, "box": box})
	var face := Style.ROW_SAVE
	if _hovered == key:
		face = Color(face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b)
	var seed := int(box.position.y) + key.hash() % 31
	Style.plank(self, box, int(box.position.y) * 13 + key.hash() % 89, face, Style.CLIP, Style.button_bites(box, seed))
	var ink := Style.DANGER.lerp(Style.INK, 0.35) if warn else Style.RIBBON_INK
	Style.write(
		self, label, Style.TEXT_BODY,
		Vector2(0.0, box.position.y + (box.size.y + float(Style.TEXT_BODY) * 0.62) * 0.5),
		ink, HORIZONTAL_ALIGNMENT_CENTER, box
	)
