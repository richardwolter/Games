## The Donation Bank's board (2026-10-22, `/grill-me` with Richard): every player's gifts on
## one bar, the pledge they unlock, and this player's own gift.
##
## One board in the credits' wood: a title plank, two sentences, the HUD meter's own bar
## filling with clean water as the bank fills (`MeterBar`, the lake's progress bar turned to
## the bank's), the figure and how many gave, and under a rule what this player can do: clean
## the lake first, give the purse (a door, asked once more on `MenuConfirm` because it cannot
## be undone), or a thank-you for a gift already made.
##
## Opened from the main menu's corner plank (by every player, from the first launch) and from
## a door on the farewell. It reads the lake it is given (`lake`) and that lake's ledger
## (`Lake.bank`); with no lake it shows the bar only.
##
## The pledge's real money is written in words ("100 US dollars"), never with the money mark:
## `Style.write` paints every "$" in the game's money green, and the game's money and a real
## donation must not read as the same thing.
class_name DonationBoard
extends Control

const Style := preload("res://scripts/style.gd")

## The board, in the 1280-wide design frame.
const BOARD_WIDE := 540.0
const BOARD_PAD := 18.0
const FRAME := 12.0
const RIBBON_TALL := 36.0
const RIBBON_OVERHANG := 10.0
const CHIPS := 3
const CLOSE_SIZE := 44.0
## Between the rows of one wrapped sentence, and between two sentences.
const LINE_GAP := 6.0
const PARA_GAP := 10.0
## The bar's width, and the gaps above and below it.
const BAR_WIDE := 300.0
const BAR_GAP := 12.0
## The rule over the player's own part, and the gap either side of it.
const RULE_GAP := 14.0
## The door that gives the purse.
const DOOR := Vector2(320.0, 44.0)

signal close_asked

## The lake whose purse this board gives. Set before the board is added.
var lake: Lake = null

## Rows that did not fit in the window and were not drawn. Nothing in the game reads it: the
## harness lays the board out at 1280x720 in every language and asks for zero.
var dropped_lines: int = 0

var _board := Rect2()
var _close: CloseButton
var _bar: MeterBar
var _confirm: MenuConfirm
var _bank: DonationBank
var _door := Rect2()
var _door_hot := false
## The two sentences as wrapped rows, and where each part of the board starts.
var _lead: Array[String] = []
var _pledge: Array[String] = []
var _at := {}


func _ready() -> void:
	# Walked with the pad's stick (scripts/pad.gd, `pad_focus` below).
	add_to_group(Pad.FOCUS_GROUP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Prefs.language_changed.connect(_lay_out)
	_close = CloseButton.new()
	_close.pressed.connect(func() -> void: close_asked.emit())
	add_child(_close)
	_bar = MeterBar.new()
	_bar.name = &"Bar"
	_bar.wide = BAR_WIDE
	add_child(_bar)
	_confirm = MenuConfirm.new()
	_confirm.name = &"Confirm"
	_confirm.visible = false
	_confirm.yes_warns = false
	_confirm.confirmed.connect(_give)
	_confirm.cancelled.connect(_keep)
	add_child(_confirm)
	resized.connect(_lay_out)
	# Hung off a CanvasLayer (the farewell's door) it has no Control to size it, and covers the
	# window itself, as the farewell does.
	if not get_parent() is Control:
		get_viewport().size_changed.connect(_fill)
		_fill()
	_lay_out()


func _fill() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_confirm.position = Vector2.ZERO
	_confirm.size = size


## The board coming up: the question put away, Steam asked for the latest total, the ledger
## listened to while the board is up.
func open() -> void:
	_listen(_ledger())
	_confirm.visible = false
	if lake != null:
		lake.bank_refresh()
	_lay_out()


## The ledger shown: the lake's, or one of its own with nothing in it.
func _ledger() -> DonationBank:
	if lake != null:
		return lake.bank()
	if _bank == null:
		_bank = DonationBank.new()
	return _bank


func _listen(ledger: DonationBank) -> void:
	if _bank == ledger:
		return
	if _bank != null and _bank.changed.is_connected(_lay_out):
		_bank.changed.disconnect(_lay_out)
	_bank = ledger
	_bank.changed.connect(_lay_out)


## What the player's own part of the board is: a thank-you, the door, an empty purse, or the
## lake still to clean.
func part() -> StringName:
	var ledger := _ledger()
	if ledger.has_given():
		return &"done"
	if lake == null or not lake.lake_ended():
		return &"locked"
	if lake.can_donate():
		return &"door"
	return &"empty"


## The line about the total under the figure: the goal reached, the total being asked for, or
## why the figure shown may be old. Empty when Steam has just answered.
func status() -> String:
	var ledger := _ledger()
	if ledger.reached():
		return Text.BANK_REACHED
	if ledger.live:
		return ""
	if ledger.asking:
		return Text.BANK_ASKING
	return Text.BANK_OFFLINE if ledger.seen_at > 0 else Text.BANK_NEVER


func _pledge_text() -> String:
	return Text.BANK_PLEDGE % [DonationBank.figure(DonationBank.GOAL), Text.BANK_CHARITY]


## The player's part as a line of words (every part but the door).
func _part_line() -> String:
	match part():
		&"done":
			return Text.BANK_DONE % DonationBank.figure(_ledger().given)
		&"empty":
			return Text.BANK_EMPTY
		&"locked":
			return Text.BANK_LOCKED
	return ""


func _door_label() -> String:
	return Text.BANK_DONATE % DonationBank.figure(floori(lake.sludge) if lake != null else 0)


## A sentence broken into rows no wider than `wide`, the asterisks that mark words not counted.
func _wrap(text: String, px: int, wide: float) -> Array[String]:
	return Wrap.lines(text, func(s: String) -> float: return Style.measure(s.replace("*", ""), px).x, wide)


func _text_wide() -> float:
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	return Style.board_face(Rect2(Vector2.ZERO, Vector2(wide, 1000.0)), FRAME).size.x - BOARD_PAD * 2.0


func _row_step(px: int) -> float:
	return float(px) + LINE_GAP


## How tall the board would like to be, in design pixels: its wood, the two sentences, the
## bar, the figures, the rule and the player's part.
func wanted_tall() -> float:
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	var text_wide := _text_wide()
	var tall := Style.board_wood_tall(wide, FRAME) + BOARD_PAD * 2.0
	tall += _wrap(Text.BANK_LEAD, Style.TEXT_BODY, text_wide).size() * _row_step(Style.TEXT_BODY)
	tall += PARA_GAP
	tall += _wrap(_pledge_text(), Style.TEXT_BODY, text_wide).size() * _row_step(Style.TEXT_BODY)
	tall += BAR_GAP + _bar_box().y + BAR_GAP
	tall += _row_step(Style.TEXT_HEAD) + _row_step(Style.TEXT_SMALL)
	if not status().is_empty():
		tall += _wrap(status(), Style.TEXT_SMALL, text_wide).size() * _row_step(Style.TEXT_SMALL)
	tall += RULE_GAP * 2.0
	if part() == &"door":
		tall += DOOR.y
	else:
		tall += _wrap(_part_line(), Style.TEXT_BODY, text_wide).size() * _row_step(Style.TEXT_BODY)
	return tall


func _bar_box() -> Vector2:
	var probe := (BAR_WIDE / HudSkin.METER_FRAME.size.x) * HudSkin.METER_FRAME.size
	return probe.floor()


func _lay_out() -> void:
	if not is_node_ready():
		return
	var ledger := _ledger()
	_listen(ledger)
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	var text_wide := _text_wide()
	var tall := minf(wanted_tall(), size.y - 40.0)
	_board = Rect2(floorf((size.x - wide) * 0.5), floorf((size.y - tall) * 0.5), wide, tall)
	var face := Style.board_face(_board, FRAME)
	_lead = _wrap(Text.BANK_LEAD, Style.TEXT_BODY, text_wide)
	_pledge = _wrap(_pledge_text(), Style.TEXT_BODY, text_wide)
	var y := face.position.y + BOARD_PAD
	_at["lead"] = y
	y += _lead.size() * _row_step(Style.TEXT_BODY) + PARA_GAP
	_at["pledge"] = y
	y += _pledge.size() * _row_step(Style.TEXT_BODY) + BAR_GAP
	var bar := _bar_box()
	_bar.wide = BAR_WIDE
	_bar.position = Vector2(floorf(face.position.x + (face.size.x - bar.x) * 0.5), floorf(y))
	_bar.share = ledger.share()
	y += bar.y + BAR_GAP
	_at["figure"] = y
	y += _row_step(Style.TEXT_HEAD)
	_at["donors"] = y
	y += _row_step(Style.TEXT_SMALL)
	_at["status"] = y
	if not status().is_empty():
		y += _wrap(status(), Style.TEXT_SMALL, text_wide).size() * _row_step(Style.TEXT_SMALL)
	_at["rule"] = y + RULE_GAP * 0.5
	y += RULE_GAP * 2.0
	_at["part"] = y
	_door = Rect2()
	if part() == &"door":
		_door = Rect2(Vector2(floorf(face.position.x + (face.size.x - DOOR.x) * 0.5), floorf(y)), DOOR)
	var at := Style.close_on(_ribbon(), CLOSE_SIZE)
	_close.position = at.position
	_close.size = at.size
	queue_redraw()


func _ribbon() -> Rect2:
	return Rect2(
		Vector2(_board.position.x - RIBBON_OVERHANG, _board.position.y - RIBBON_TALL * 0.5),
		Vector2(_board.size.x + RIBBON_OVERHANG * 2.0, RIBBON_TALL)
	)


## Escape, and the pad's B with it, closes the board. The question on it answers its own
## Escape first (`MenuConfirm`), as "not yet".
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _confirm.visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	close_asked.emit()


func _gui_input(event: InputEvent) -> void:
	var moved := event as InputEventMouseMotion
	if moved != null:
		var hot := _door.has_point(moved.position)
		if hot != _door_hot:
			if hot:
				Sfx.ui(&"ui_hover")
			_door_hot = hot
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if _door.has_point(click.position):
		Sfx.ui(&"ui_click")
		ask()
		return
	# The table round the board is the way out.
	if not _board.grow(RIBBON_OVERHANG).has_point(click.position):
		close_asked.emit()


## The door taken: asked once more, since a gift cannot be taken back.
func ask() -> void:
	if part() != &"door":
		return
	_confirm.title = Text.BANK_SURE % DonationBank.figure(floori(lake.sludge))
	_confirm.words = "BANK_ONCE"
	_confirm.yes_label = "BANK_YES"
	_confirm.no_label = "BANK_NOT_YET"
	_confirm.visible = true


func _give() -> void:
	_confirm.visible = false
	if lake != null and lake.donate() > 0:
		var sound := Sfx.main()
		if sound != null:
			sound.play_bought()
	_lay_out()


func _keep() -> void:
	Sfx.ui(&"ui_close")
	_confirm.visible = false


func _draw() -> void:
	if _board.size.x <= 0.0:
		return
	var ledger := _ledger()
	Style.dim(self, Rect2(Vector2.ZERO, size), Style.SCRIM)
	var face := Style.board_wood(self, _board, FRAME, CHIPS)
	draw_rect(face, Style.PAPER, true)
	var ribbon := _ribbon()
	Style.board_ribbon(
		self, ribbon, Text.BANK_TITLE, CHIPS, Style.TEXT_HEAD, Style.title_room(ribbon, CLOSE_SIZE)
	)
	dropped_lines = 0
	var across := Rect2(face.position.x + BOARD_PAD, 0.0, face.size.x - BOARD_PAD * 2.0, 1.0)
	var body := Style.TEXT_BODY
	_rows(_lead, body, float(_at["lead"]), across, Style.PAPER_INK, face)
	_rows(_pledge, body, float(_at["pledge"]), across, Style.PAPER_INK, face)
	var figure := Text.BANK_PROGRESS % [
		DonationBank.figure(ledger.shown_total()), DonationBank.figure(DonationBank.GOAL)
	]
	_line(figure, Style.TEXT_HEAD, float(_at["figure"]), Style.PAPER_INK, face)
	_line(
		Text.BANK_DONORS % DonationBank.grouped(ledger.shown_donors()), Style.TEXT_SMALL,
		float(_at["donors"]), Style.PAPER_SOFT, face
	)
	var said := status()
	if not said.is_empty():
		var ink := Style.PAPER_HEAD if ledger.reached() else Style.PAPER_SOFT
		_rows(_wrap(said, Style.TEXT_SMALL, across.size.x), Style.TEXT_SMALL, float(_at["status"]), across, ink, face)
	var rule := float(_at["rule"])
	draw_line(
		Vector2(face.position.x + BOARD_PAD, rule), Vector2(face.end.x - BOARD_PAD, rule),
		Style.PAPER_RULE, 2.0
	)
	if _door.size != Vector2.ZERO:
		_draw_door()
	else:
		var ink := Style.PAPER_HEAD if part() == &"done" else Style.PAPER_INK
		_rows(_wrap(_part_line(), body, across.size.x), body, float(_at["part"]), across, ink, face)


## Wrapped rows centred across the face, a word between asterisks in the head's ink. Drawn in
## one call, so a mark carries on from one row to the next. A row that would fall off the face
## is counted rather than drawn.
func _rows(rows: Array[String], px: int, top: float, across: Rect2, ink: Color, face: Rect2) -> void:
	var fit := 0
	while fit < rows.size() and top + fit * _row_step(px) + float(px) <= face.end.y:
		fit += 1
	dropped_lines += rows.size() - fit
	if fit > 0:
		Wrap.draw_marked(
			self, Style.font(), rows.slice(0, fit), px, across, top + float(px) * 0.82,
			_row_step(px), ink, Style.PAPER_HEAD
		)


## One line centred on the face, through `Style.write` so the money mark wears its green.
func _line(text: String, px: int, top: float, ink: Color, face: Rect2) -> void:
	if top + float(px) > face.end.y:
		dropped_lines += 1
		return
	Style.write(
		self, text, MenuConfirm.fitted_to(text, face.size.x - BOARD_PAD * 2.0, px),
		Vector2(0.0, top + float(px) * 0.82), ink, HORIZONTAL_ALIGNMENT_CENTER, face
	)


## The door: the confirm board's dark plate, ringed in the seam and lit along the top.
func _draw_door() -> void:
	var face := Style.BOARD
	if _door_hot:
		face = Color(face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b)
	draw_rect(_door.grow(1.0), Style.SEAM, true)
	Style.plate(self, _door, face)
	Style.lit_edge(self, _door, face)
	var label := _door_label()
	Style.write(
		self, label, MenuConfirm.fitted(label, _door.size.x - 8.0),
		Vector2(0.0, _door.position.y + (_door.size.y + float(Style.TEXT_BODY) * 0.62) * 0.5),
		Style.INK, HORIZONTAL_ALIGNMENT_CENTER, _door
	)


## The door, picked first, and the close cross. None while the question is up: it walks itself.
func pad_focus() -> Array:
	if not is_visible_in_tree() or _confirm.visible:
		return []
	var out: Array = []
	if _door.size != Vector2.ZERO:
		out.append({"box": _door, "key": &"donate", "first": true})
	if _close != null and _close.visible:
		out.append({"box": _close.get_rect(), "key": &"close", "first": _door.size == Vector2.ZERO})
	return out
