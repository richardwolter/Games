## The settings board: the drawn settings panel.
##
## One oak board in the pollution meter's wood, the same as the upgrades boards, drawn here
## from `Style` rather than built out of stock Controls — a CheckButton in a theme override
## is a grey engine default wearing a plank, and the switch and the slider are a rectangle
## and a line. The lake owns what each setting does; this owns where it sits, what it looks
## like, and what the player has set it to.
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

## How tall each kind of line is, and the gaps between lines and between sections.
const HEAD_TALL := 24.0
const ROW_TALL := 40.0
const SLIDER_TALL := 26.0
const ROW_GAP := 6.0
const SECTION_GAP := 12.0

## The switch: a sunken track with a plank thumb pushed to one side.
const SWITCH_WIDE := 44.0
const SWITCH_TALL := 20.0

## The slider: a sunken groove with clean water filling the played part, a plank thumb
## riding it.
const GROOVE_TALL := 8.0
const THUMB_WIDE := 12.0

const CLOSE_SIZE := 34.0

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

## Whether there is a save to load: the load button is drawn back when there is not.
var can_load: bool = true:
	set(v):
		can_load = v
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
signal save_pressed
signal load_pressed
signal wipe_pressed
signal swap_pressed
signal quit_pressed
signal close_asked

var _board := Rect2()
## Every drawn line this frame: `{kind, key, box}`.
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
		{"kind": &"head", "label": "Sound"},
		{"kind": &"switch", "key": &"music", "label": "Music  (M)"},
		{"kind": &"slider", "key": &"music_level"},
		{"kind": &"switch", "key": &"sfx", "label": "Sound effects"},
		{"kind": &"slider", "key": &"sfx_level"},
		{"kind": &"gap"},
		{"kind": &"head", "label": "Screen"},
		{"kind": &"switch", "key": &"fullscreen", "label": "Fullscreen  (F11)"},
		{"kind": &"gap"},
		{"kind": &"head", "label": "Save"},
		{"kind": &"button", "key": &"save", "label": "Save the run  (F5)"},
		{"kind": &"button", "key": &"load", "label": "Load the last save  (F9)"},
	]
	if wipe_shown:
		plan.append({"kind": &"button", "key": &"wipe", "label": "Start the lake over  (F6)", "warn": true})
	plan.append({"kind": &"button", "key": &"swap", "label": swap_label})
	plan.append({"kind": &"gap"})
	plan.append({"kind": &"button", "key": &"quit", "label": "Save and quit", "warn": true})
	return plan


func _tall_of(kind: StringName) -> float:
	match kind:
		&"head":
			return HEAD_TALL
		&"slider":
			return SLIDER_TALL
		&"gap":
			return SECTION_GAP - ROW_GAP
		_:
			return ROW_TALL


func _lay_out() -> void:
	var tall := FRAME + RIBBON_TALL * 0.5 + BOARD_PAD
	for line: Dictionary in _plan():
		tall += _tall_of(line["kind"]) + ROW_GAP
	tall += BOARD_PAD + FRAME - ROW_GAP
	var wide := minf(BOARD_WIDE, size.x - 40.0)
	tall = minf(tall, size.y - 40.0)
	_board = Rect2(floorf((size.x - wide) * 0.5), floorf((size.y - tall) * 0.5), wide, tall)
	if _close != null:
		_close.position = Vector2(_board.end.x - CLOSE_SIZE, _board.position.y - CLOSE_SIZE - 4.0)
		_close.size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	queue_redraw()


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
		&"save":
			save_pressed.emit()
		&"load":
			if can_load:
				load_pressed.emit()
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


func _draw() -> void:
	if _board.size.x <= 0.0:
		return
	Style.dim(self, Rect2(Vector2.ZERO, size), Style.SCRIM)
	_draw_frame(_board)
	var face := _board.grow(-FRAME)
	draw_rect(face.grow(1.0), Style.SEAM, true)
	draw_rect(face, Style.BOARD, true)
	_draw_inset(face)

	var ribbon := Rect2(
		Vector2(_board.position.x - RIBBON_OVERHANG, _board.position.y - RIBBON_TALL * 0.5),
		Vector2(_board.size.x + RIBBON_OVERHANG * 2.0, RIBBON_TALL)
	)
	_draw_ribbon(ribbon, TITLE)

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
			&"head":
				_draw_head(box, String(line["label"]))
			&"switch":
				_draw_switch(box, line)
			&"slider":
				_draw_slider(box, line)
			&"button":
				_draw_button(box, line)


func _draw_frame(box: Rect2) -> void:
	draw_rect(box.grow(1.0), Style.SEAM, true)
	draw_rect(box, Style.FRAME, true)
	draw_rect(
		Rect2(Vector2(box.position.x, box.end.y - FRAME), Vector2(box.size.x, FRAME)),
		Style.FRAME_LOW, true
	)
	var seed := int(box.position.x) * 31 + int(box.position.y) * 17 + 11
	Style.grain(self, Rect2(box.position, Vector2(box.size.x, FRAME)), true, seed)
	Style.grain(self, Rect2(Vector2(box.position.x, box.end.y - FRAME), Vector2(box.size.x, FRAME)), true, seed + 1)
	Style.grain(self, Rect2(box.position, Vector2(FRAME, box.size.y)), false, seed + 2)
	Style.grain(self, Rect2(Vector2(box.end.x - FRAME, box.position.y), Vector2(FRAME, box.size.y)), false, seed + 3)
	Style.highlight(self, box.position, Vector2(box.size.x, 0.0), seed + 4)
	Style.highlight(self, box.position, Vector2(0.0, box.size.y), seed + 5)
	draw_rect(Rect2(Vector2(box.position.x, box.end.y - 1.0), Vector2(box.size.x, 1.0)), Style.FRAME_DEEP, true)
	draw_rect(Rect2(Vector2(box.end.x - 1.0, box.position.y), Vector2(1.0, box.size.y)), Style.FRAME_DEEP, true)
	for i in CHIPS:
		var along := (float(i) + 0.5 + 0.3 * float(hash(seed + i) % 5) / 5.0) / float(CHIPS)
		var chip_wide := 6.0 + 2.0 * float(hash(seed * 3 + i) % 3)
		var deep := 3.0 + float(hash(seed * 5 + i) % 3)
		var cy := box.position.y + box.size.y * along
		var cx := box.position.x + box.size.x * (1.0 - along)
		Style.chip(self, Rect2(box.position.x - 1.0, cy, deep, chip_wide))
		Style.chip(self, Rect2(box.end.x + 1.0 - deep, cy - chip_wide * 0.4, deep, chip_wide))
		if i % 2 == 0:
			Style.chip(self, Rect2(cx, box.position.y - 1.0, chip_wide, deep))
			Style.chip(self, Rect2(cx - chip_wide * 0.6, box.end.y + 1.0 - deep, chip_wide, deep))


## The inset shadow where the wood meets the board face.
func _draw_inset(face: Rect2) -> void:
	draw_rect(Rect2(face.position - Vector2(2.0, 2.0), Vector2(face.size.x + 4.0, 2.0)), Style.FRAME_SHADOW, true)
	draw_rect(Rect2(face.position - Vector2(2.0, 2.0), Vector2(2.0, face.size.y + 4.0)), Style.FRAME_SHADOW, true)
	draw_rect(Rect2(Vector2(face.position.x - 2.0, face.end.y + 1.0), Vector2(face.size.x + 4.0, 1.0)), Style.FRAME_SHADOW, true)
	draw_rect(Rect2(Vector2(face.end.x + 1.0, face.position.y - 2.0), Vector2(1.0, face.size.y + 4.0)), Style.FRAME_SHADOW, true)


func _draw_ribbon(box: Rect2, title: String) -> void:
	var seed := int(box.position.x) * 53 + int(box.position.y) * 29 + 9
	Style.plank(self, box, seed)
	for i in CHIPS:
		var along := (float(i) + 0.5 + 0.3 * float(hash(seed + i) % 5) / 5.0) / float(CHIPS)
		var chip_wide := 6.0 + 2.0 * float(hash(seed * 3 + i) % 3)
		var deep := 3.0 + float(hash(seed * 5 + i) % 3)
		var x := box.position.x + box.size.x * along
		Style.chip(self, Rect2(x, box.position.y - 1.0, chip_wide, deep))
		Style.chip(self, Rect2(box.end.x - box.size.x * along - chip_wide * 0.6, box.end.y + 1.0 - deep, chip_wide, deep))
	var y := box.position.y + box.size.y * 0.4
	Style.chip(self, Rect2(box.position.x - 1.0, y, 4.0, 8.0))
	Style.chip(self, Rect2(box.end.x - 3.0, y + 6.0, 4.0, 8.0))
	Style.write(
		self, title, Style.TEXT_HEAD,
		Vector2(0.0, box.position.y + (box.size.y + float(Style.TEXT_HEAD) * 0.62) * 0.5),
		Style.RIBBON_INK, HORIZONTAL_ALIGNMENT_CENTER, box
	)


## A section heading: a small plank with the word on it, left of the line.
func _draw_head(box: Rect2, label: String) -> void:
	var span := Style.measure(label, Style.TEXT_SMALL)
	var plank := Rect2(box.position, Vector2(span.x + 20.0, box.size.y))
	Style.plank(self, plank, int(box.position.y) * 3)
	Style.write(
		self, label, Style.TEXT_SMALL,
		Vector2(0.0, plank.position.y + (plank.size.y + float(Style.TEXT_SMALL) * 0.62) * 0.5),
		Style.RIBBON_INK, HORIZONTAL_ALIGNMENT_CENTER, plank
	)
	# A seam line running on from the plank across the board.
	draw_rect(
		Rect2(Vector2(plank.end.x + 6.0, box.position.y + box.size.y * 0.5), Vector2(box.end.x - plank.end.x - 6.0, 1.0)),
		Style.FRAME_DEEP, true
	)


## The plate a row sits on, by which section it is in. A row that cannot be used is drawn
## back towards the board rather than in a colour of its own.
func _row_face(key: StringName, hovered: bool, live: bool) -> Color:
	var face := Style.ROW_SOUND
	match key:
		&"fullscreen":
			face = Style.ROW_SCREEN
		&"save", &"load", &"wipe", &"swap":
			face = Style.ROW_SAVE
		&"quit":
			face = Style.ROW_QUIT
	if not live:
		face = face.lerp(Style.BOARD, 0.55)
	if hovered and live:
		face = Color(face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b)
	return face


## A row with a label and a switch on its right.
func _draw_switch(box: Rect2, line: Dictionary) -> void:
	var key: StringName = line["key"]
	var on := _state_of(key)
	_lines.append({"kind": &"switch", "key": key, "box": box})
	Style.plate(self, box, _row_face(key, _hovered == key, true))
	Style.write(
		self, String(line["label"]), Style.TEXT_BODY,
		Vector2(box.position.x + 10.0, box.position.y + (box.size.y + float(Style.TEXT_BODY) * 0.62) * 0.5),
		Style.BOARD_INK
	)
	var track := Rect2(
		Vector2(box.end.x - SWITCH_WIDE - 10.0, box.position.y + (box.size.y - SWITCH_TALL) * 0.5),
		Vector2(SWITCH_WIDE, SWITCH_TALL)
	)
	draw_rect(track.grow(1.0), Style.SEAM, true)
	draw_rect(track, Style.ON_GOLD if on else Style.BOARD, true)
	var thumb_wide := SWITCH_TALL - 2.0
	var thumb := Rect2(
		Vector2(track.end.x - thumb_wide - 1.0 if on else track.position.x + 1.0, track.position.y + 1.0),
		Vector2(thumb_wide, SWITCH_TALL - 2.0)
	)
	Style.plank(self, thumb, int(track.position.y))


func _state_of(key: StringName) -> bool:
	match key:
		&"music":
			return music_on
		&"sfx":
			return sfx_on
		&"fullscreen":
			return fullscreen
	return false


## A slider under its switch: a sunken groove, clean water up to the level, a plank thumb.
func _draw_slider(box: Rect2, line: Dictionary) -> void:
	var key: StringName = line["key"]
	var level := music_level if key == &"music_level" else sfx_level
	var on := music_on if key == &"music_level" else sfx_on
	var groove := Rect2(
		Vector2(box.position.x + 10.0, box.position.y + (box.size.y - GROOVE_TALL) * 0.5),
		Vector2(box.size.x - 20.0, GROOVE_TALL)
	)
	_lines.append({"kind": &"slider", "key": key, "box": box, "groove": groove})
	draw_rect(groove.grow(1.0), Style.SEAM, true)
	draw_rect(groove, Style.FRAME_SHADOW, true)
	var fill := Style.ON_GOLD if on else Style.BOARD_ROW_OFF
	draw_rect(Rect2(groove.position, Vector2(groove.size.x * level, groove.size.y)), fill, true)
	var thumb := Rect2(
		Vector2(groove.position.x + groove.size.x * level - THUMB_WIDE * 0.5, box.position.y + 2.0),
		Vector2(THUMB_WIDE, box.size.y - 4.0)
	)
	Style.plank(self, thumb, int(groove.position.y) + key.hash() % 97)


## A button row: the plate is the button.
func _draw_button(box: Rect2, line: Dictionary) -> void:
	var key: StringName = line["key"]
	var live := can_load if key == &"load" else true
	_lines.append({"kind": &"button", "key": key, "box": box})
	Style.plate(self, box, _row_face(key, _hovered == key, live))
	# Oak rows take the frame's cream, the rest the board's pale ink.
	var ink := Style.RIBBON_INK if key in [&"save", &"load", &"wipe", &"swap", &"quit"] else Style.BOARD_INK
	if not live:
		ink = Style.BOARD_INK_DIM
	if bool(line.get("warn", false)):
		ink = Style.DANGER.lerp(Style.INK, 0.35)
	Style.write(
		self, String(line["label"]), Style.TEXT_BODY,
		Vector2(0.0, box.position.y + (box.size.y + float(Style.TEXT_BODY) * 0.62) * 0.5),
		ink, HORIZONTAL_ALIGNMENT_CENTER, box
	)
