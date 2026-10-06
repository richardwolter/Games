## The language chooser: a small board of flags, opened from the flag in the main menu's top
## right corner (2026-09-26, `/grill-me` with Richard).
##
## **Its own door, not a settings row**: the language is the one setting a player who cannot
## read the current one has to find, so it wears a picture and stands alone in a corner of
## the menu. This supersedes the Language row issue #28 planned for the settings board.
##
## Two columns of plates, each a flag and the language's name **in that language, in that
## language's face** — a Japanese player looks for 日本語, not for "Japanese" — so every name
## is drawn with `Style` switched to its own locale for the one call. A pick applies at once
## through `Prefs.set_language` and closes the board.
class_name LanguageBoard
extends Control

const Style := preload("res://scripts/style.gd")
const FLAGS := "res://assets/ui/flags/%s.png"

const BOARD_WIDE := 460.0
const BOARD_PAD := 16.0
const FRAME := 12.0
const RIBBON_TALL := 36.0
const RIBBON_OVERHANG := 10.0
const CHIPS := 3
const ROW_TALL := 44.0
const ROW_GAP := 8.0
const FLAG_BOX := Vector2(56.0, 36.0)
## Room over the first row for the title plank's bitten foot, as `MenuConfirm` leaves.
const TOP_AIR := 10.0

signal close_asked
signal picked(locale: String)

var _board := Rect2()
## `{locale, box}` per plate, as last drawn.
var _rows: Array = []
var _hovered: String = ""
var _flags: Dictionary = {}


func _ready() -> void:
	# Walked with the pad's stick (scripts/pad.gd, `pad_focus` below).
	add_to_group(Pad.FOCUS_GROUP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_lay_out)
	_lay_out()


static func flag_of(entry: Dictionary) -> Texture2D:
	var path: String = FLAGS % entry["flag"]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _flag(entry: Dictionary) -> Texture2D:
	var key: String = entry["flag"]
	if not _flags.has(key):
		_flags[key] = flag_of(entry)
	return _flags[key]


func _lay_out() -> void:
	if not is_node_ready():
		return
	var rows := ceili(Prefs.languages().size() / 2.0)
	var tall := Style.board_wood_tall(BOARD_WIDE, FRAME) + TOP_AIR + BOARD_PAD * 2.0
	tall += rows * ROW_TALL + (rows - 1) * ROW_GAP
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	_board = Rect2(floorf((size.x - wide) * 0.5), floorf((size.y - tall) * 0.5), wide, tall)
	queue_redraw()


func _ribbon() -> Rect2:
	return Rect2(
		Vector2(_board.position.x - RIBBON_OVERHANG, _board.position.y - RIBBON_TALL * 0.5),
		Vector2(_board.size.x + RIBBON_OVERHANG * 2.0, RIBBON_TALL)
	)


func row_box_of(locale: String) -> Rect2:
	for row: Dictionary in _rows:
		if row["locale"] == locale:
			return row["box"]
	return Rect2()


func _row_under(at: Vector2) -> String:
	for row: Dictionary in _rows:
		if (row["box"] as Rect2).has_point(at):
			return row["locale"]
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was := _hovered
		_hovered = _row_under((event as InputEventMouseMotion).position)
		if was != _hovered:
			if _hovered != "":
				Sfx.ui(&"ui_hover")
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	var at := _row_under(click.position)
	if at != "":
		pick(at)
	elif not _board.grow(RIBBON_OVERHANG).has_point(click.position):
		close_asked.emit()


## Choose a language: applied and written at once, and the board closes.
func pick(locale: String) -> void:
	Sfx.ui(&"ui_click")
	Prefs.set_language(locale)
	picked.emit(locale)
	queue_redraw()


func _draw() -> void:
	if _board.size.x <= 0.0:
		return
	Style.dim(self, Rect2(Vector2.ZERO, size), Style.SCRIM)
	var face := Style.board_wood(self, _board, FRAME, CHIPS)
	draw_rect(face, Style.PAPER, true)
	Style.board_ribbon(self, _ribbon(), Text.LANGUAGE_TITLE, CHIPS, Style.TEXT_HEAD)

	_rows.clear()
	var current := Prefs.current_language()
	var wide := (face.size.x - BOARD_PAD * 2.0 - ROW_GAP) * 0.5
	var top := face.position.y + BOARD_PAD + TOP_AIR
	var entries := Prefs.languages()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var box := Rect2(
			face.position.x + BOARD_PAD + (i % 2) * (wide + ROW_GAP),
			top + (i / 2) * (ROW_TALL + ROW_GAP), wide, ROW_TALL
		)
		_draw_row(box, entry, entry["locale"] == current)


## A plate: the flag at the left, the name beside it in its own face. The language in play
## is lit the shop's way — the lighter face and the lit edge, two channels.
func _draw_row(box: Rect2, entry: Dictionary, on: bool) -> void:
	var locale: String = entry["locale"]
	_rows.append({"locale": locale, "box": box})
	var face := Style.BOARD_ROW_LIT if on else Style.BOARD_ROW
	if _hovered == locale:
		face = Color(face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b)
	Style.plate(self, box, face)
	if on:
		Style.lit_edge(self, box, face)
	var flag_box := Rect2(box.position + Vector2(6.0, (box.size.y - FLAG_BOX.y) * 0.5), FLAG_BOX)
	PlankButton.draw_flag(self, flag_box, _flag(entry), 1.0)
	var text_box := Rect2(
		Vector2(flag_box.end.x + 8.0, box.position.y),
		Vector2(box.end.x - flag_box.end.x - 14.0, box.size.y)
	)
	# The name in its own language's face, then the face put back.
	var was := Style.locale()
	Style.set_locale(locale)
	Style.write(
		self, entry["name"], Style.TEXT_BODY,
		Vector2(text_box.position.x, box.position.y + (box.size.y + float(Style.TEXT_BODY) * 0.62) * 0.5),
		Style.INK, HORIZONTAL_ALIGNMENT_LEFT, text_box
	)
	Style.set_locale(String(was))


## One stop a language for the pad's stick, the one in use picked first.
func pad_focus() -> Array:
	var out: Array = []
	for row: Dictionary in _rows:
		out.append({
			"box": row["box"], "key": row["locale"],
			"first": row["locale"] == TranslationServer.get_locale(),
		})
	return out
