## The settings board: the drawn settings panel.
##
## One oak board in the pollution meter's wood, the same as the upgrades boards, drawn here
## from `Style` rather than built out of stock Controls — a CheckButton in a theme override
## is a grey engine default wearing a plank, and the switch and the slider are a rectangle
## and a line. The lake owns what each setting does; this owns where it sits, what it looks
## like, and what the player has set it to.
##
## No save or load buttons, by decision (2026-09-11): the lake autosaves every
## `Lake.AUTOSAVE_EVERY` seconds, on the window's close request and on "Save and quit",
## and loads on start. A save button on top of that was a promise the game was already
## keeping. The section headings went at the same time: the board is short enough to read
## without them, and the gap between sections says what the plank used to.
class_name SettingsSkin
extends Control

const Style := preload("res://scripts/style.gd")

const TITLE := "Settings"

## The board, in rows. Widths in the 1280-wide design frame.
const BOARD_WIDE := 460.0
const BOARD_PAD := 14.0
const FRAME := 12.0
const RIBBON_TALL := 36.0
const RIBBON_OVERHANG := 10.0
const CHIPS := 3

## How tall each kind of line is, and the gaps between lines and between sections. A sound
## row is two lines on one plate: the label and its switch, and the volume groove under.
const ROW_TALL := 40.0
const SOUND_TALL := 58.0
const ROW_GAP := 6.0
const SECTION_GAP := 12.0

## The switch: a sunken track with a plank thumb pushed to one side.
const SWITCH_WIDE := 44.0
const SWITCH_TALL := 20.0

## The slider: a sunken groove with clean water filling the played part, a plank thumb
## riding it. `GROOVE_LINE` is how tall the groove's line of the row is; the thumb stands
## the whole of it.
const GROOVE_TALL := 8.0
const GROOVE_LINE := 20.0
const THUMB_WIDE := 12.0
const ROW_INSET := 10.0

const CLOSE_SIZE := 44.0

## What the player has set. Setters redraw, so a key press that flips one shows at once.
var music_on: bool = true:
	set(v):
		music_on = v
		queue_redraw()
var music_level: float = 0.75:
	set(v):
		music_level = clampf(v, 0.0, 1.0)
		queue_redraw()
var sfx_on: bool = true:
	set(v):
		sfx_on = v
		queue_redraw()
var sfx_level: float = 0.8:
	set(v):
		sfx_level = clampf(v, 0.0, 1.0)
		queue_redraw()
var fullscreen: bool = false:
	set(v):
		fullscreen = v
		queue_redraw()

## What the level-swap button says; the lake names the other level.
var swap_label: String = "Go to the siege":
	set(v):
		swap_label = v
		queue_redraw()

## The lake-over button is not shown, as it was not on the old panel; the F6 key still
## does it.
var wipe_shown: bool = false

signal music_toggled(on: bool)
signal music_level_changed(level: float)
signal sfx_toggled(on: bool)
signal sfx_level_changed(level: float)
signal fullscreen_toggled(on: bool)
signal wipe_pressed
signal swap_pressed
signal quit_pressed
signal close_asked

var _board := Rect2()
## Every clickable box this frame: `{kind, key, box}` (and `groove` for a slider).
var _lines: Array = []
var _hovered: StringName = &""
## The slider being dragged, if any.
var _dragging: StringName = &""
var _close: CloseButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_close = CloseButton.new()
	_close.pressed.connect(func() -> void: close_asked.emit())
	add_child(_close)
	resized.connect(_lay_out)
	_lay_out()


## The lines, top to bottom, in sections.
func _plan() -> Array:
	var plan := [
		{"kind": &"sound", "key": &"music", "level": &"music_level", "label": "Music  (M)"},
		{"kind": &"sound", "key": &"sfx", "level": &"sfx_level", "label": "Sound effects"},
		{"kind": &"gap"},
		{"kind": &"switch", "key": &"fullscreen", "label": "Fullscreen  (F11)"},
		{"kind": &"gap"},
	]
	if wipe_shown:
		plan.append({"kind": &"button", "key": &"wipe", "label": "Start the lake over  (F6)", "warn": true})
	plan.append({"kind": &"button", "key": &"swap", "label": swap_label})
	plan.append({"kind": &"gap"})
	plan.append({"kind": &"button", "key": &"quit", "label": "Save and quit", "warn": true})
	return plan


func _tall_of(kind: StringName) -> float:
	match kind:
		&"sound":
			return SOUND_TALL
		&"gap":
			return SECTION_GAP - ROW_GAP
		_:
			return ROW_TALL


func _lay_out() -> void:
	var tall := Style.board_wood_tall(BOARD_WIDE, FRAME) + RIBBON_TALL * 0.5 + BOARD_PAD
	for line: Dictionary in _plan():
		tall += _tall_of(line["kind"]) + ROW_GAP
	tall += BOARD_PAD - ROW_GAP
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	tall = minf(tall, size.y - 40.0)
	_board = Rect2(floorf((size.x - wide) * 0.5), floorf((size.y - tall) * 0.5), wide, tall)
	if _close != null:
		# Nailed to the title plank's right end, as the shed's shelf has it, rather than hung
		# in the air above the board's corner.
		var at := Style.close_on(_ribbon(), CLOSE_SIZE)
		_close.position = at.position
		_close.size = at.size
	queue_redraw()


## The title plank hung across the board's top edge, a little wider than the board.
func _ribbon() -> Rect2:
	return Rect2(
		Vector2(_board.position.x - RIBBON_OVERHANG, _board.position.y - RIBBON_TALL * 0.5),
		Vector2(_board.size.x + RIBBON_OVERHANG * 2.0, RIBBON_TALL)
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var at := (event as InputEventMouseMotion).position
		if _dragging != &"":
			_drag_to(at)
			accept_event()
			return
		var was := _hovered
		_hovered = _key_under(at)
		if was != _hovered:
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not click.pressed:
		if _dragging != &"":
			_dragging = &""
			accept_event()
		return
	var key := _key_under(click.position)
	if key == &"":
		# The table round the board is the way out.
		if not _board.grow(RIBBON_OVERHANG).has_point(click.position):
			accept_event()
			close_asked.emit()
		return
	accept_event()
	match key:
		&"music":
			music_on = not music_on
			music_toggled.emit(music_on)
		&"sfx":
			sfx_on = not sfx_on
			sfx_toggled.emit(sfx_on)
		&"fullscreen":
			fullscreen = not fullscreen
			fullscreen_toggled.emit(fullscreen)
		&"music_level", &"sfx_level":
			_dragging = key
			_drag_to(click.position)
		&"wipe":
			wipe_pressed.emit()
		&"swap":
			swap_pressed.emit()
		&"quit":
			quit_pressed.emit()


func _drag_to(at: Vector2) -> void:
	for line: Dictionary in _lines:
		if line["key"] != _dragging:
			continue
		var groove: Rect2 = line["groove"]
		var level := clampf((at.x - groove.position.x) / groove.size.x, 0.0, 1.0)
		level = roundf(level * 100.0) / 100.0
		if _dragging == &"music_level":
			if not is_equal_approx(level, music_level):
				music_level = level
				music_level_changed.emit(level)
		else:
			if not is_equal_approx(level, sfx_level):
				sfx_level = level
				sfx_level_changed.emit(level)
		return


func _key_under(at: Vector2) -> StringName:
	for line: Dictionary in _lines:
		if (line["box"] as Rect2).has_point(at):
			return line["key"]
	return &""


## The plate a sound row's hover lands on: the whole plate, whichever line the pointer is
## on, so the row lights as one thing.
func _row_hovered(line: Dictionary) -> bool:
	return _hovered == line["key"] or _hovered == line.get("level", &"")


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

	_lines.clear()
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
			&"sound":
				_draw_sound(box, line)
			&"switch":
				_draw_switch(box, line)
			&"button":
				_draw_button(box, line)


## The plate a row sits on, by which section it is in. A row that cannot be used is drawn
## back towards the board rather than in a colour of its own.
func _row_face(key: StringName, hovered: bool, live: bool) -> Color:
	var face := Style.ROW_SOUND
	match key:
		&"fullscreen":
			face = Style.ROW_SCREEN
		&"wipe", &"swap", &"quit":
			# The quit is the same oak as the swap; its warning is in the ink alone.
			face = Style.ROW_SAVE
	if not live:
		face = face.lerp(Style.BOARD, 0.55)
	if hovered and live:
		face = Color(face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b)
	return face


## A label on the left of a line and a switch on its right. Returns the switch's track,
## which is what the label line is hit-tested by for a sound row.
func _draw_label_and_switch(line_box: Rect2, key: StringName, label: String) -> void:
	var on := _state_of(key)
	Style.write(
		self, label, Style.TEXT_BODY,
		Vector2(line_box.position.x + ROW_INSET, line_box.position.y + (line_box.size.y + float(Style.TEXT_BODY) * 0.62) * 0.5),
		Style.BOARD_INK
	)
	var track := Rect2(
		Vector2(line_box.end.x - SWITCH_WIDE - ROW_INSET, line_box.position.y + (line_box.size.y - SWITCH_TALL) * 0.5),
		Vector2(SWITCH_WIDE, SWITCH_TALL)
	)
	draw_rect(track.grow(1.0), Style.SEAM, true)
	draw_rect(track, Style.ON_GOLD if on else Style.BOARD, true)
	var thumb_wide := SWITCH_TALL - 2.0
	var thumb := Rect2(
		Vector2(track.end.x - thumb_wide - 1.0 if on else track.position.x + 1.0, track.position.y + 1.0),
		Vector2(thumb_wide, SWITCH_TALL - 2.0)
	)
	Style.plank(self, thumb, int(track.position.y), Style.FRAME, 2.0)


## A row with a label and a switch on its right.
func _draw_switch(box: Rect2, line: Dictionary) -> void:
	var key: StringName = line["key"]
	_lines.append({"kind": &"switch", "key": key, "box": box})
	Style.plate(self, box, _row_face(key, _hovered == key, true))
	_draw_label_and_switch(box, key, String(line["label"]))


## A sound row: one plate, the label and switch on its top line, the volume groove along
## its bottom line. The top line toggles, the bottom line drags.
func _draw_sound(box: Rect2, line: Dictionary) -> void:
	var key: StringName = line["key"]
	var level_key: StringName = line["level"]
	var on := _state_of(key)
	var level := music_level if level_key == &"music_level" else sfx_level
	var top := Rect2(box.position, Vector2(box.size.x, box.size.y - GROOVE_LINE))
	var under := Rect2(Vector2(box.position.x, top.end.y), Vector2(box.size.x, GROOVE_LINE))
	var groove := Rect2(
		Vector2(under.position.x + ROW_INSET, under.position.y + (under.size.y - GROOVE_TALL) * 0.5 - 2.0),
		Vector2(under.size.x - ROW_INSET * 2.0, GROOVE_TALL)
	)
	_lines.append({"kind": &"switch", "key": key, "box": top})
	_lines.append({"kind": &"slider", "key": level_key, "box": under, "groove": groove})
	Style.plate(self, box, _row_face(key, _row_hovered(line), true))
	_draw_label_and_switch(top, key, String(line["label"]))
	draw_rect(groove.grow(1.0), Style.SEAM, true)
	draw_rect(groove, Style.FRAME_SHADOW, true)
	var fill := Style.ON_WATER if on else Style.BOARD_ROW_OFF
	draw_rect(Rect2(groove.position, Vector2(groove.size.x * level, groove.size.y)), fill, true)
	var thumb_tall := GROOVE_LINE - 6.0
	var thumb := Rect2(
		Vector2(groove.position.x + groove.size.x * level - THUMB_WIDE * 0.5, groove.position.y + (groove.size.y - thumb_tall) * 0.5),
		Vector2(THUMB_WIDE, thumb_tall)
	)
	Style.plank(self, thumb, int(groove.position.y) + level_key.hash() % 97, Style.FRAME, 2.0)


func _state_of(key: StringName) -> bool:
	match key:
		&"music":
			return music_on
		&"sfx":
			return sfx_on
		&"fullscreen":
			return fullscreen
	return false


## A button row: a plank like the frame, grained, lit along the top, a bite or two out of
## its edge.
func _draw_button(box: Rect2, line: Dictionary) -> void:
	var key: StringName = line["key"]
	_lines.append({"kind": &"button", "key": key, "box": box})
	var face := _row_face(key, _hovered == key, true)
	var seed := int(box.position.y) + key.hash() % 31
	Style.plank(self, box, int(box.position.y) * 13 + key.hash() % 89, face, Style.CLIP, Style.button_bites(box, seed))
	var ink := Style.RIBBON_INK
	if bool(line.get("warn", false)):
		ink = Style.DANGER.lerp(Style.INK, 0.35)
	Style.write(
		self, String(line["label"]), Style.TEXT_BODY,
		Vector2(0.0, box.position.y + (box.size.y + float(Style.TEXT_BODY) * 0.62) * 0.5),
		ink, HORIZONTAL_ALIGNMENT_CENTER, box
	)
