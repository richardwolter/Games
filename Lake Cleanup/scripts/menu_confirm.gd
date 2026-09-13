## "Start over?" — the one question the menu asks.
##
## New game over a saved lake throws the save away, and that is the only thing the menu can
## do that cannot be undone, so it asks. A small board in the shop's wood: a title plank, a
## line of what will happen, and two button planks drawn as the settings board draws its own
## — the warning one in the danger ink, the safe one plain. Drawn, not a ConfirmationDialog:
## a grey engine popup over the capsule art would be the one thing on the screen from a
## different game.
class_name MenuConfirm
extends Control

const Style := preload("res://scripts/style.gd")

const TITLE := "Start over?"
const WORDS := "The saved lake will be thrown away."
const YES := "Start over"
const NO := "Keep it"

const BOARD_WIDE := 400.0
const BOARD_PAD := 16.0
const FRAME := 12.0
const RIBBON_TALL := 36.0
const RIBBON_OVERHANG := 10.0
const CHIPS := 3
const ROW_TALL := 40.0
const ROW_GAP := 10.0
const WORDS_TALL := 30.0

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
	var tall := (
		Style.board_wood_tall(BOARD_WIDE, FRAME) + BOARD_PAD
		+ WORDS_TALL + ROW_GAP + ROW_TALL + BOARD_PAD
	)
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
	Style.board_ribbon(self, _ribbon(), TITLE, CHIPS, Style.TEXT_HEAD)

	var y := face.position.y + BOARD_PAD
	Style.write(
		self, WORDS, Style.TEXT_BODY, Vector2(0.0, y + float(Style.TEXT_BODY) * 0.9),
		Style.BOARD_INK, HORIZONTAL_ALIGNMENT_CENTER, face
	)
	y += WORDS_TALL + ROW_GAP

	_doors.clear()
	var left := face.position.x + BOARD_PAD
	var wide := (face.size.x - BOARD_PAD * 2.0 - ROW_GAP) * 0.5
	_draw_door(Rect2(left, y, wide, ROW_TALL), &"yes", YES, true)
	_draw_door(Rect2(left + wide + ROW_GAP, y, wide, ROW_TALL), &"no", NO, false)


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
