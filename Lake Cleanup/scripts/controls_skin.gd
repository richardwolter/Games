## The bind board: every verb, on the keyboard and on the pad.
##
## Issue #26, decided with `/grill-me` (2026-09-16). **Its own board, by Richard's call**: the
## settings board is a panel of short rows and this is a table of fifteen verbs on two
## devices, so the settings' Controls row opens this instead of growing that. Same wood, same
## frame, same close cross on the title plank.
##
## What is bound, and what a binding is worth, is `Binds`'. This is where it is drawn and
## how it is changed: **click a cell and press the thing you want** — a key or a mouse button
## in the left column, a pad button or a trigger in the right. Escape cancels the capture
## rather than being bound, which is what makes it the one key nothing can take.
##
## **A new binding swaps with whatever held it** (Richard's call over refusing it or allowing
## duplicates), so no verb is ever left with nothing on it. The swap is inside the context
## only — the lake and the shed each have their own set of verbs, and E working the thing in
## front of you out there while it works a switch in here is the design.
##
## **Right-click a cell to put it back to its default.** That is also the only way back to a
## binding the capture will not take: `open_settings` is on Escape, and Escape is the key
## that cancels a capture.
class_name ControlsSkin
extends Control

const Style := preload("res://scripts/style.gd")

const TITLE := "Controls"

const BOARD_WIDE := 560.0
const BOARD_PAD := 14.0
const FRAME := 12.0
const RIBBON_TALL := 36.0
const RIBBON_OVERHANG := 10.0
const CHIPS := 3

## Fifteen verbs, five headings and the way back have to stand inside the 720-line design
## frame with the board's own wood round them, so the rows are shorter than the settings
## board's: at 28 and a 3 px gap the last plank fell off the bottom.
const ROW_TALL := 26.0
const HEAD_TALL := 20.0
const ROW_GAP := 2.0
const ROW_INSET := 10.0
const FOOT_GAP := 6.0
const BUTTON_TALL := 32.0

## The two cells, hard against the row's right edge.
const KEY_WIDE := 150.0
const PAD_WIDE := 96.0
const CELL_GAP := 6.0
const CELL_TALL := 22.0

const CLOSE_SIZE := 44.0

const RESET_LABEL := "Put every key back"
const CAPTURE_WORDS := "Press…"

signal close_asked

var _board := Rect2()
## `{kind, action, column, box}` for every cell and the reset plank, as last drawn.
var _cells: Array = []
var _hovered: int = -1
var _close: CloseButton

## The cell being captured into, or empty.
var _capture_action: StringName = &""
var _capture_column: String = ""
## The action a binding was just taken from, and how long its row still says so.
var _swapped: StringName = &""
var _swapped_for: float = 0.0
const SWAP_SHOWN := 2.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_close = CloseButton.new()
	_close.pressed.connect(func() -> void: close_asked.emit())
	add_child(_close)
	resized.connect(_lay_out)
	set_process(false)
	_lay_out()


## The rows, top to bottom: a heading wherever the group changes, then a row a verb.
func _plan() -> Array:
	var plan: Array = []
	var group := ""
	for row: Dictionary in Binds.rows():
		if String(row["group"]) != group:
			group = String(row["group"])
			plan.append({"kind": &"head", "label": group})
		plan.append({"kind": &"bind", "row": row})
	plan.append({"kind": &"foot"})
	return plan


func _lay_out() -> void:
	if not is_node_ready():
		return
	var tall := Style.board_wood_tall(BOARD_WIDE, FRAME) + RIBBON_TALL * 0.5 + BOARD_PAD
	for line: Dictionary in _plan():
		tall += _tall_of(line["kind"]) + ROW_GAP
	tall += BOARD_PAD - ROW_GAP
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	tall = minf(tall, size.y - 40.0)
	_board = Rect2(floorf((size.x - wide) * 0.5), floorf((size.y - tall) * 0.5), wide, tall)
	if _close != null:
		var at := Style.close_on(_ribbon(), CLOSE_SIZE)
		_close.position = at.position
		_close.size = at.size
	queue_redraw()


func _tall_of(kind: StringName) -> float:
	match kind:
		&"head":
			return HEAD_TALL
		&"foot":
			return BUTTON_TALL + FOOT_GAP
	return ROW_TALL


func _ribbon() -> Rect2:
	return Rect2(
		Vector2(_board.position.x - RIBBON_OVERHANG, _board.position.y - RIBBON_TALL * 0.5),
		Vector2(_board.size.x + RIBBON_OVERHANG * 2.0, RIBBON_TALL)
	)


## The capture takes the raw event, before the boards or the lake see it — that is the whole
## point of it. Handled at once, so a key pressed into a cell never also does what it is
## bound to.
func _input(event: InputEvent) -> void:
	if not visible or _capture_action == &"":
		return
	if event is InputEventMouseMotion:
		return
	var stick := event as InputEventJoypadMotion
	if stick != null and absf(stick.axis_value) < 0.5:
		return
	var key := event as InputEventKey
	if key != null and not key.pressed:
		return
	if key != null and key.physical_keycode == KEY_ESCAPE:
		_stop_capture()
		get_viewport().set_input_as_handled()
		return
	var click := event as InputEventMouseButton
	if click != null and not click.pressed:
		get_viewport().set_input_as_handled()
		return
	var button := event as InputEventJoypadButton
	if button != null and not button.pressed:
		return
	if not Binds.bindable(event, _capture_column):
		return
	var written := Binds.write(event)
	if not written.is_empty():
		_swapped = Binds.bind(_capture_action, _capture_column, written)
		_swapped_for = SWAP_SHOWN if _swapped != &"" else 0.0
		set_process(_swapped_for > 0.0)
		Prefs.save_binds()
		Sfx.ui(&"ui_click")
	_stop_capture()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_swapped_for -= delta
	if _swapped_for <= 0.0:
		_swapped = &""
		set_process(false)
	queue_redraw()


func _start_capture(action: StringName, column: String) -> void:
	_capture_action = action
	_capture_column = column
	_swapped = &""
	queue_redraw()


func _stop_capture() -> void:
	_capture_action = &""
	_capture_column = ""
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was := _hovered
		_hovered = _cell_under((event as InputEventMouseMotion).position)
		if was != _hovered:
			if _hovered >= 0:
				Sfx.ui(&"ui_hover")
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_RIGHT:
		var at := _cell_under(click.position)
		if at >= 0 and _cells[at]["kind"] == &"cell":
			accept_event()
			Binds.restore(_cells[at]["action"], _cells[at]["column"])
			Prefs.save_binds()
			Sfx.ui(&"ui_click")
			queue_redraw()
		return
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	var under := _cell_under(click.position)
	if under < 0:
		accept_event()
		if _capture_action != &"":
			_stop_capture()
		elif not _board.grow(RIBBON_OVERHANG).has_point(click.position):
			close_asked.emit()
		return
	accept_event()
	Sfx.ui(&"ui_click")
	var cell: Dictionary = _cells[under]
	if cell["kind"] == &"reset":
		Binds.reset()
		Prefs.save_binds()
		_stop_capture()
		return
	_start_capture(cell["action"], cell["column"])


func _cell_under(at: Vector2) -> int:
	for i in _cells.size():
		if (_cells[i]["box"] as Rect2).has_point(at):
			return i
	return -1


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

	_cells.clear()
	var left := face.position.x + BOARD_PAD
	var wide := face.size.x - BOARD_PAD * 2.0
	var y := _board.position.y + RIBBON_TALL * 0.5 + BOARD_PAD
	for line: Dictionary in _plan():
		var kind: StringName = line["kind"]
		var tall := _tall_of(kind)
		var box := Rect2(left, y, wide, tall)
		y += tall + ROW_GAP
		if box.end.y > face.end.y - BOARD_PAD + 1.0:
			break
		match kind:
			&"head":
				_draw_head(box, String(line["label"]))
			&"bind":
				_draw_bind(box, line["row"])
			&"foot":
				_draw_foot(box)


func _draw_head(box: Rect2, label: String) -> void:
	Style.write(
		self, label, Style.TEXT_SMALL,
		Vector2(box.position.x, box.end.y - 4.0), Style.LEVEL_INK
	)
	draw_rect(
		Rect2(Vector2(box.position.x, box.end.y - 2.0), Vector2(box.size.x, 1.0)),
		Style.SEAM, true
	)


func _draw_bind(box: Rect2, row: Dictionary) -> void:
	var action: StringName = row["action"]
	var over := action == _swapped
	Style.plate(self, box, Style.ROW_SOUND if not over else Style.ROW_SAVE)
	var label := String(row["label"])
	if over:
		label += "  — moved here"
	Style.write(
		self, label, Style.TEXT_SMALL,
		Vector2(box.position.x + ROW_INSET, box.position.y + (box.size.y + float(Style.TEXT_SMALL) * 0.62) * 0.5),
		Style.BOARD_INK
	)
	var mid := box.position.y + (box.size.y - CELL_TALL) * 0.5
	var pad_box := Rect2(Vector2(box.end.x - ROW_INSET - PAD_WIDE, mid), Vector2(PAD_WIDE, CELL_TALL))
	var key_box := Rect2(
		Vector2(pad_box.position.x - CELL_GAP - KEY_WIDE, mid), Vector2(KEY_WIDE, CELL_TALL)
	)
	_draw_cell(key_box, action, "key")
	_draw_cell(pad_box, action, "pad")


## One binding: a sunken cell with what it is bound to written in it, or the capture's own
## word while it is waiting to be pressed.
func _draw_cell(box: Rect2, action: StringName, column: String) -> void:
	var at := _cells.size()
	_cells.append({"kind": &"cell", "action": action, "column": column, "box": box})
	var taking := _capture_action == action and _capture_column == column
	draw_rect(box.grow(1.0), Style.SEAM, true)
	var face := Style.FRAME_SHADOW
	if taking:
		face = Style.ON_GOLD
	elif _hovered == at:
		face = Style.FRAME_SHADOW.lerp(Style.ON_WATER, 0.4)
	draw_rect(box, face, true)
	var written := Binds.bound(action, column)
	var words := CAPTURE_WORDS if taking else Binds.label_of(written)
	var ink := Style.RIBBON_INK if taking else Style.BOARD_INK
	if not taking and written.is_empty():
		ink = Style.BOARD_INK.lerp(Style.BOARD, 0.5)
	Style.write(
		self, words, Style.TEXT_TINY,
		Vector2(0.0, box.position.y + (box.size.y + float(Style.TEXT_TINY) * 0.62) * 0.5),
		ink, HORIZONTAL_ALIGNMENT_CENTER, box
	)


## The way back: one plank across the foot.
func _draw_foot(box: Rect2) -> void:
	var plank := Rect2(
		Vector2(box.position.x, box.position.y + FOOT_GAP),
		Vector2(box.size.x, BUTTON_TALL)
	)
	var at := _cells.size()
	_cells.append({"kind": &"reset", "action": &"", "column": "", "box": plank})
	var face := Style.ROW_SAVE
	if _hovered == at:
		face = Color(face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b)
	if not Binds.changed():
		face = face.lerp(Style.BOARD, 0.55)
	Style.plank(
		self, plank, int(plank.position.y) * 13, face, Style.CLIP,
		Style.button_bites(plank, int(plank.position.y))
	)
	Style.write(
		self, RESET_LABEL, Style.TEXT_BODY,
		Vector2(0.0, plank.position.y + (plank.size.y + float(Style.TEXT_BODY) * 0.62) * 0.5),
		Style.RIBBON_INK, HORIZONTAL_ALIGNMENT_CENTER, plank
	)
