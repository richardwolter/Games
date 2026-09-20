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
## that cancels a capture. Which is why the board **says so** once the player has changed
## anything (`HINT`): a gesture that is the only way out of somewhere is not one to leave in a
## code comment. It is said only when there is something to go back from, and its room is
## reserved either way, so the board does not jump the first time somebody rebinds.
##
## **The two columns are named** (2026-09-17, `/grill-me` with Richard): a table of cells with
## nothing over it left the player to work out which half was the keyboard.
class_name ControlsSkin
extends Control

const Style := preload("res://scripts/style.gd")

const TITLE := "Controls"

## The board went 560 to 640 wide on 2026-09-17, to pay for the hint. It is short of room
## down the screen — 666 of the 680 the smallest frame leaves — and has plenty across it, and
## the hint stands beside the column names in a band that already exists. At 560 the left
## half of that band was 234 px and nothing that said the whole gesture fitted; at 640 it is
## 314 against the hint's 296.
const BOARD_WIDE := 640.0
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

const RESET_LABEL := "Set to default"
const CAPTURE_WORDS := "Press…"

## What the two columns are, and the gesture the board would otherwise never mention. The
## hint stands in the left half of the same band, which is empty — so naming the columns and
## saying how to change one cost one row between them, not two.
const KEY_HEAD := "Keyboard"
const PAD_HEAD := "Gamepad"
const HINT := "Click a cell and press · right-click resets"

## Putting every key back throws away fifteen rows of somebody's own arrangement, so it asks
## (Richard, 2026-09-17). The board next door's own question board.
const CONFIRM_TITLE := "Are you sure?"
## No line under the title: "Set to default" and "Keep current" each say what they do, and a
## sentence saying it a third time is a sentence nobody reads.
const CONFIRM_WORDS := ""
const CONFIRM_YES := "Set to default"
const CONFIRM_NO := "Keep current"

## A row that has just had a binding moved into it: the plate a step lighter with a lit edge
## along its top, which is how the shop says "this one". It was the frame's oak, a swatch
## that has left this board with the foot plank.
const SWAP_FACE := Style.BOARD_ROW_LIT

## The foot plank's face. **Dark, by decision** (2026-09-17): on the frame's oak the word
## read 2.97:1 and nothing pale clears 4.5:1 on that face at all. The same plate the settings
## board's own foot buttons wear.
const BUTTON_FACE := Style.BOARD

signal close_asked

var _board := Rect2()
## `{kind, action, column, box}` for every cell and the reset plank, as last drawn.
var _cells: Array = []
var _hovered: int = -1
var _close: CloseButton

## Set by `_draw` when a line did not fit and was not drawn. A board too tall for its window
## dropped its bottom rows in silence, and the bottom row here is the way back out.
var dropped_lines: int = 0
## Whether the last pass drew the hint. Set by the drawing itself, so the harness asks the
## board what it did rather than working the rule out a second time.
var hint_shown: bool = false
## The question the foot plank asks before it throws fifteen bindings away.
var _confirm: MenuConfirm

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


## The rows, top to bottom: the two columns named, then a heading wherever the group changes
## and a row a verb, then the way back.
func _plan() -> Array:
	var plan: Array = [{"kind": &"columns"}]
	var group := ""
	for row: Dictionary in Binds.rows():
		if String(row["group"]) != group:
			group = String(row["group"])
			plan.append({"kind": &"head", "label": group})
		plan.append({"kind": &"bind", "row": row})
	plan.append({"kind": &"foot"})
	return plan


## How tall the board wants to be. Asked by `_lay_out` and by the harness, which checks it
## against the room the smallest frame leaves.
func wanted_tall() -> float:
	var tall := Style.board_wood_tall(BOARD_WIDE, FRAME) + RIBBON_TALL * 0.5 + BOARD_PAD
	for line: Dictionary in _plan():
		tall += _tall_of(line["kind"]) + ROW_GAP
	return tall + BOARD_PAD - ROW_GAP


func _lay_out() -> void:
	if not is_node_ready():
		return
	var tall := wanted_tall()
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	tall = minf(tall, size.y - 40.0)
	_board = Rect2(floorf((size.x - wide) * 0.5), floorf((size.y - tall) * 0.5), wide, tall)
	if _close != null:
		var at := Style.close_on(_ribbon(), CLOSE_SIZE)
		_close.position = at.position
		_close.size = at.size
	if _confirm != null:
		_confirm.size = size
	queue_redraw()


func _tall_of(kind: StringName) -> float:
	match kind:
		&"head", &"columns":
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
		_stop_capture()
		if Binds.changed():
			_ask_reset()
		return
	_start_capture(cell["action"], cell["column"])


## Fifteen rows of somebody's own arrangement is not nothing, so the foot plank asks first
## (Richard, 2026-09-17). The settings board's own question board, with this board's words.
func _ask_reset() -> void:
	if _confirm == null:
		_confirm = MenuConfirm.new()
		_confirm.title = CONFIRM_TITLE
		_confirm.words = CONFIRM_WORDS
		_confirm.yes_label = CONFIRM_YES
		_confirm.no_label = CONFIRM_NO
		_confirm.confirmed.connect(_do_reset)
		_confirm.cancelled.connect(func() -> void: _confirm.visible = false)
		add_child(_confirm)
	_confirm.size = size
	_confirm.visible = true


func _do_reset() -> void:
	Binds.reset()
	Prefs.save_binds()
	if _confirm != null:
		_confirm.visible = false
	queue_redraw()


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
	draw_rect(face, Style.PAPER, true)
	var ribbon := _ribbon()
	Style.board_ribbon(
		self, ribbon, TITLE, CHIPS, Style.TEXT_HEAD, Style.title_room(ribbon, CLOSE_SIZE)
	)

	_cells.clear()
	dropped_lines = 0
	hint_shown = false
	var left := face.position.x + BOARD_PAD
	var wide := face.size.x - BOARD_PAD * 2.0
	var y := _board.position.y + RIBBON_TALL * 0.5 + BOARD_PAD
	for line: Dictionary in _plan():
		var kind: StringName = line["kind"]
		var tall := _tall_of(kind)
		var box := Rect2(left, y, wide, tall)
		y += tall + ROW_GAP
		if box.end.y > face.end.y - BOARD_PAD + 1.0:
			dropped_lines += 1
			continue
		match kind:
			&"columns":
				_draw_columns(box)
			&"head":
				_draw_head(box, String(line["label"]))
			&"bind":
				_draw_bind(box, line["row"])
			&"foot":
				_draw_foot(box)


## The band that names the two columns, and — once the player has changed anything — says
## how a cell is worked. The room is reserved either way, so the board does not grow the
## first time somebody rebinds; only the words come and go.
func _draw_columns(box: Rect2) -> void:
	var base := box.end.y - 4.0
	var mid := box.position.y + (box.size.y - CELL_TALL) * 0.5
	var pad_box := Rect2(Vector2(box.end.x - ROW_INSET - PAD_WIDE, mid), Vector2(PAD_WIDE, CELL_TALL))
	var key_box := Rect2(
		Vector2(pad_box.position.x - CELL_GAP - KEY_WIDE, mid), Vector2(KEY_WIDE, CELL_TALL)
	)
	for pair: Array in [[key_box, KEY_HEAD], [pad_box, PAD_HEAD]]:
		Style.write(
			self, String(pair[1]), Style.TEXT_SMALL, Vector2(0.0, base), Style.PAPER_HEAD,
			HORIZONTAL_ALIGNMENT_CENTER, pair[0]
		)
	if not Binds.changed():
		return
	# Said only where it fits whole: a gesture explained halfway is not explained.
	var room := key_box.position.x - CELL_GAP - box.position.x
	if Style.measure(HINT, Style.TEXT_TINY).x > room:
		return
	Style.write(
		self, HINT, Style.TEXT_TINY, Vector2(box.position.x, base), Style.PAPER_SOFT
	)
	hint_shown = true


func _draw_head(box: Rect2, label: String) -> void:
	Style.write(
		self, label, Style.TEXT_SMALL,
		Vector2(box.position.x, box.end.y - 4.0), Style.PAPER_HEAD
	)
	draw_rect(
		Rect2(Vector2(box.position.x, box.end.y - 2.0), Vector2(box.size.x, 1.0)),
		Style.PAPER_RULE, true
	)


func _draw_bind(box: Rect2, row: Dictionary) -> void:
	var action: StringName = row["action"]
	var over := action == _swapped
	# One face, and the row that just took a moved binding lifted a step with a lit edge over
	# it — the shop's way of saying "this one". **Not `Style.highlight`**: that is the wood's
	# own edge, in a warm oak tone, and this face is paint.
	var plate := SWAP_FACE if over else Style.BOARD_ROW
	Style.plate(self, box, plate)
	if over:
		Style.lit_edge(self, box, plate)
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
	# Dark on the lit cell: cream on that gold read 2.40:1, which is the least legible thing
	# on the board at the one moment the player is looking straight at it.
	var ink := Style.INK_DARK if taking else Style.BOARD_INK
	if not taking and written.is_empty():
		# Nothing editable on this column — but the walking rows have the left stick standing
		# behind them, and a bare dash said the verb had no gamepad control at all.
		var standing := Binds.standing_label(action, column)
		words = standing if not standing.is_empty() else words
		ink = Style.BOARD_INK_SOFT
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
	var live := Binds.changed()
	var face := BUTTON_FACE
	if _hovered == at and live:
		face = Color(face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b)
	draw_rect(plank.grow(1.0), Style.SEAM, true)
	Style.plate(self, plank, face)
	# The lit edge is what says a button can be pressed, so a plank with nothing to undo does
	# not draw one. The face cannot be dimmed to say it — it is already the board's own.
	if live:
		Style.lit_edge(self, plank, face)
	Style.write(
		self, RESET_LABEL, Style.TEXT_BODY,
		Vector2(0.0, plank.position.y + (plank.size.y + float(Style.TEXT_BODY) * 0.62) * 0.5),
		Style.INK if live else Style.BOARD_INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, plank
	)
