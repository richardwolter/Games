## The settings board: the drawn settings panel.
##
## One oak board in the pollution meter's wood, the same as the upgrades boards, drawn here
## from `Style` rather than built out of stock Controls — a CheckButton in a theme override
## is a grey engine default wearing a plank, and the switch and the slider are a rectangle
## and a line. The lake owns what each setting does; this owns where it sits, what it looks
## like, and what the player has set it to.
##
## No save or load buttons, by decision (2026-09-11): the lake autosaves every
## `Lake.AUTOSAVE_EVERY` seconds, on the window's close request and on "Save and go to
## menu", and loads on start. A save button on top of that was a promise the game was
## already keeping. The section headings went at the same time: the board was short enough
## to read without them.
##
## The values themselves are `Prefs`' (2026-09-12): the board reads them on its way in and
## stores every press, so the menu's board and the lake's are one set of settings, kept
## across scenes and sessions. In `menu_mode` the lake's own rows — the wipe, the level
## swap, the way out — are left off: the menu is already outside the lake.
##
## **The sound rows are four now and the screen rows four** (2026-09-16, issue #26, decided
## with `/grill-me`): a Master slider over the three, and Window / Resolution / VSync /
## Frame cap. The binds did not come with them — **two boards, by Richard's call**: a table
## of sixteen verbs on two devices does not belong under a volume slider, so the Controls row
## opens `ControlsSkin` instead.
##
## **A choice row is arrows, except the resolution** (same call): `◂ Borderless ▸` reads at a
## glance and costs no second layer, but a dozen window sizes behind a pair of arrows is a
## lot of clicking, so that one value opens a short list over the board.
##
## **The resolution is a windowed-mode setting**: in either fullscreen the row is dimmed and
## reads the monitor's own size. Nothing about picking a size can therefore leave a player
## staring at a screen that cannot display what the game asked for.
##
## **The board reads in the shop's language** (2026-09-17, `/grill-me` with Richard): one
## plate face for every row and a carved heading over each group, in place of the three
## section colours that had been doing that job alone since the headings were cut. Layout,
## wording and ink only — no row was added or removed and nothing any row does moved.
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
## A sound row came in 4 px (2026-09-17) to pay for the headings. With them at 58 the board
## wanted 678 of the 680 the smallest frame leaves, which is not a margin — one longer label
## or one more group and a row drops off the foot. The 4 come off the label line, not off the
## groove: the groove is a target.
const SOUND_TALL := 54.0
const ROW_GAP := 6.0
const SECTION_GAP := 12.0

## A group's heading, the shop's own (`ShopSkin.GROUP_TALL`): the words in the clean water's
## blue with a carved rule running from them to the board's far edge.
##
## **It stands in the section gap rather than over it.** The board is 638 design pixels tall
## and the smallest frame — height never goes under 720 — leaves it 680, so headings drawn
## above the gaps they separate (24 px each) would not fit and `_draw` would quietly drop the
## bottom of the board. Standing in the gap each costs 14 px net and the board lands at 666.
const GROUP_TALL := 20.0

## What a row that cannot be used reads in. `Style.BOARD_INK_DIM` on a dimmed plate is
## 2.19:1; this is 6.22:1, and the dimmed plate is what says the row is dead.
const INK_SOFT := Style.BOARD_INK_SOFT

## A chooser's value. `Style.LEVEL_INK` is 3.42:1 on the rows' one face — it was picked to
## sit on the shop's plate, which is a different plate — so the settings board lifts it to
## 4.76:1 here rather than moving a swatch the shop is using.
const VALUE_INK := Color(0.78, 0.88, 0.95)

## A button's plate and the two inks it carries. **A dark face, by decision** (2026-09-17):
## on the frame's oak these two words read 2.97:1 and 1.37:1, and no ink clears 4.5:1 on that
## face at all — white itself reaches 4.06:1. On this one the word is 11.8:1 and the warning
## 5.30:1, and the warning is still plainly red.
const BUTTON_FACE := Style.BOARD
const WARN_INK := Style.WARN_INK

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

## The chooser: a plank arrow each side of the value, and the room the value stands in
## between them.
const ARROW_WIDE := 22.0
const VALUE_WIDE := 150.0
const ARROW_GAP := 4.0

## What a dead Resolution row says instead of its arrows, and the gap between it and the
## figure it explains.
const DEAD_SIZE_NOTE := "set by Window"
const NOTE_GAP := 8.0

## The dropped list the resolution opens: a row each, over the board. The one it is standing
## on is a pale plate written in dark, not cream on the clean water — that read 2.82:1, the
## last word on the board that did not clear the bar.
const LIST_ROW := 28.0
const LIST_PAD := 6.0
const PICKED_FACE := Style.LEVEL_INK

const CLOSE_SIZE := 44.0

## How long the player has to keep an exclusive-fullscreen change before it puts itself back
## (2026-09-16, Richard asked for the safeguard). Exclusive is the one display row that can
## hand a monitor a mode it will not show, and a black screen cannot answer a question.
const REVERT_AFTER := 10.0

## What the player has set. Setters redraw, so a key press that flips one shows at once.
var master_on: bool = true:
	set(v):
		master_on = v
		queue_redraw()
var master_level: float = 1.0:
	set(v):
		master_level = clampf(v, 0.0, 1.0)
		queue_redraw()
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
var ambience_on: bool = true:
	set(v):
		ambience_on = v
		queue_redraw()
var ambience_level: float = 0.7:
	set(v):
		ambience_level = clampf(v, 0.0, 1.0)
		queue_redraw()

## What the level-swap button says; the lake names the other level.
var swap_label: String = "Go to the siege":
	set(v):
		swap_label = v
		queue_redraw()

## The lake-over button is not shown, as it was not on the old panel; the F6 key still
## does it.
var wipe_shown: bool = false

## The level swap is not shown either (2026-09-12): the siege is set aside for now.
var swap_shown: bool = false

## The board as the main menu shows it: sound, screen and controls. No way out of a lake the
## player is not in.
var menu_mode: bool = false:
	set(v):
		menu_mode = v
		_lay_out()

const QUIT_LABEL := "Save and go to menu"
const CONTROLS_LABEL := "Controls"

signal controls_asked
signal wipe_pressed
signal swap_pressed
signal quit_pressed
signal close_asked

var _board := Rect2()
## Every clickable box this frame: `{kind, key, box}` (and `groove` for a slider, `step` for
## an arrow).
var _lines: Array = []
var _hovered: StringName = &""
## The slider being dragged, if any.
var _dragging: StringName = &""
var _close: CloseButton
## The row whose list is dropped, or `&""`. Only the resolution has one.
var _listing: StringName = &""
var _list_boxes: Array = []

## Set by `_draw` when a line did not fit in the board and was not drawn. A board too tall
## for its window used to drop its bottom rows in silence — at the smallest frame that is
## "Save and go to menu" gone — so the fact is recorded and `test_lake` asks for it. Nothing
## in the game reads it: it is there to be a failure rather than a surprise.
var dropped_lines: int = 0

## The window mode the player was on before the one being tried, while the safeguard's
## question is up. -1 when nothing is being tried.
var _trying_from: int = -1
var _trying_size := Vector2i.ZERO
var _revert_at: float = 0.0
var _confirm: MenuConfirm


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	pull_prefs()
	_close = CloseButton.new()
	_close.pressed.connect(func() -> void: close_asked.emit())
	add_child(_close)
	resized.connect(_lay_out)
	set_process(false)
	_lay_out()


## Read what the player has set. The window's own mode is the truth for the screen rows —
## the player may have pressed F11 — and is what the board shows.
func pull_prefs() -> void:
	master_on = Prefs.master_on
	master_level = Prefs.master_level
	music_on = Prefs.music_on
	music_level = Prefs.music_level
	sfx_on = Prefs.sfx_on
	sfx_level = Prefs.sfx_level
	ambience_on = Prefs.ambience_on
	ambience_level = Prefs.ambience_level
	queue_redraw()


## Every press goes to the file at once, so nothing is lost to a crash or a scene change.
func _store(key: StringName, value: Variant) -> void:
	Prefs.store(key, value)


## The lines, top to bottom, in groups.
##
## **Master leads and carries no heading.** It is the bus the three under it feed, so what
## says it governs them is the rule the "Mix" heading draws over those three — a lid on what
## is under it, which is the shop's own reading of a heading. An indent, or dimming the three
## while Master is off, were the other two ways and were not taken.
##
## **No key name is written into a label.** "Music  (M)" and "Window  (F11)" put a key a
## translation has to carry into the middle of a name, on the only two rows that had one, for
## two keys the Controls board will never list because neither is rebindable.
func _plan() -> Array:
	var plan := [
		{"kind": &"sound", "key": &"master", "level": &"master_level", "label": "Master"},
		{"kind": &"head", "label": "Mix"},
		{"kind": &"sound", "key": &"music", "level": &"music_level", "label": "Music"},
		{"kind": &"sound", "key": &"sfx", "level": &"sfx_level", "label": "Sound effects"},
		{"kind": &"sound", "key": &"ambience", "level": &"ambience_level", "label": "Ambience"},
		{"kind": &"head", "label": "Screen"},
		{"kind": &"choice", "key": &"window_mode", "label": "Window"},
		{"kind": &"choice", "key": &"window_size", "label": "Resolution", "list": true},
		{"kind": &"choice", "key": &"vsync", "label": "VSync"},
		{"kind": &"choice", "key": &"fps_cap", "label": "Frame cap"},
		{"kind": &"gap"},
		{"kind": &"button", "key": &"controls", "label": CONTROLS_LABEL},
	]
	if menu_mode:
		return plan
	plan.append({"kind": &"gap"})
	if wipe_shown:
		plan.append({"kind": &"button", "key": &"wipe", "label": "Start the lake over", "warn": true})
	if swap_shown:
		plan.append({"kind": &"button", "key": &"swap", "label": swap_label})
	plan.append({"kind": &"button", "key": &"quit", "label": QUIT_LABEL, "warn": true})
	return plan


func _tall_of(kind: StringName) -> float:
	match kind:
		&"sound":
			return SOUND_TALL
		&"head":
			return GROUP_TALL
		&"gap":
			return SECTION_GAP - ROW_GAP
		_:
			return ROW_TALL


## How tall the board wants to be with the plan it has. Asked by `_lay_out` and by the
## harness, which checks it against the room the smallest frame leaves.
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
		# Nailed to the title plank's right end, as the shed's shelf has it, rather than hung
		# in the air above the board's corner.
		var at := Style.close_on(_ribbon(), CLOSE_SIZE)
		_close.position = at.position
		_close.size = at.size
	if _confirm != null:
		_confirm.size = size
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
			if _hovered != &"" and _row_of(_hovered) != _row_of(was):
				Sfx.ui(&"ui_hover")
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not click.pressed:
		if _dragging != &"":
			# Written once, on the release, rather than on every pixel of the drag.
			_store(_dragging, _level_of(_dragging))
			_dragging = &""
			accept_event()
		return
	if _listing != &"":
		accept_event()
		_pick_from_list(click.position)
		return
	var key := _key_under(click.position)
	if key == &"":
		# The table round the board is the way out.
		if not _board.grow(RIBBON_OVERHANG).has_point(click.position):
			accept_event()
			close_asked.emit()
		return
	accept_event()
	Sfx.ui(&"ui_click")
	match key:
		&"master", &"music", &"sfx", &"ambience":
			var on := not _state_of(key)
			_set_state(key, on)
			_store(StringName(String(key) + "_on"), on)
		&"master_level", &"music_level", &"sfx_level", &"ambience_level":
			_dragging = key
			_drag_to(click.position)
		&"controls":
			controls_asked.emit()
		&"wipe":
			wipe_pressed.emit()
		&"swap":
			swap_pressed.emit()
		&"quit":
			quit_pressed.emit()
		_:
			_choice_click(key)


## A click on a chooser: an arrow steps the value, the resolution's own value drops its list.
func _choice_click(key: StringName) -> void:
	for line: Dictionary in _lines:
		if line["key"] != key:
			continue
		match line["kind"]:
			&"arrow":
				_step_choice(line["row"], int(line["step"]))
			&"value":
				if line["row"] == &"window_size" and _screen_row_live(&"window_size"):
					_listing = &"window_size"
					queue_redraw()
		return


## Step a choice row by one, wrapping at the ends.
func _step_choice(row: StringName, step: int) -> void:
	if not _screen_row_live(row):
		return
	var values := _choices_of(row)
	if values.is_empty():
		return
	var at := values.find(_choice_of(row))
	if at < 0:
		at = 0
	_take_choice(row, values[posmod(at + step, values.size())])


## Apply a chosen value. The window mode is the one that asks first, and only into exclusive
## fullscreen: that is the mode a monitor can refuse to show.
func _take_choice(row: StringName, value: Variant) -> void:
	if row == &"window_mode" and int(value) == Prefs.WindowMode.EXCLUSIVE:
		_try_window_mode(int(value))
		return
	_store(row, value)
	match row:
		&"window_mode":
			Prefs.apply_window()
		&"window_size":
			Prefs.apply_window_size()
		&"vsync", &"fps_cap":
			Prefs.apply_frames()
	queue_redraw()


## Go into exclusive fullscreen and ask whether it worked. Nothing answering inside
## `REVERT_AFTER` puts the window back where it was — a player looking at a black screen
## cannot click "no".
func _try_window_mode(mode: int) -> void:
	_trying_from = Prefs.window_mode
	_trying_size = Prefs.window_size
	_store(&"window_mode", mode)
	Prefs.apply_window()
	_revert_at = REVERT_AFTER
	if _confirm == null:
		_confirm = MenuConfirm.new()
		_confirm.title = "Keep this?"
		_confirm.yes_label = "Keep it"
		_confirm.no_label = "Put it back"
		_confirm.confirmed.connect(_keep_window_mode)
		_confirm.cancelled.connect(_revert_window_mode)
		add_child(_confirm)
	_confirm.size = size
	_confirm.words = _revert_words()
	_confirm.visible = true
	set_process(true)


func _revert_words() -> String:
	return "Putting it back in %d seconds." % maxi(1, ceili(_revert_at))


func _keep_window_mode() -> void:
	_trying_from = -1
	if _confirm != null:
		_confirm.visible = false
	set_process(false)
	queue_redraw()


func _revert_window_mode() -> void:
	if _trying_from >= 0:
		_store(&"window_mode", _trying_from)
		_store(&"window_size", _trying_size)
		Prefs.apply_window()
	_keep_window_mode()


func _process(delta: float) -> void:
	if _trying_from < 0:
		set_process(false)
		return
	var was := ceili(_revert_at)
	_revert_at -= delta
	if _revert_at <= 0.0:
		_revert_window_mode()
		return
	if _confirm != null and ceili(_revert_at) != was:
		_confirm.words = _revert_words()


## A click while the resolution's list is dropped.
func _pick_from_list(at: Vector2) -> void:
	for entry: Dictionary in _list_boxes:
		if (entry["box"] as Rect2).has_point(at):
			Sfx.ui(&"ui_click")
			_listing = &""
			_take_choice(&"window_size", entry["value"])
			return
	_listing = &""
	queue_redraw()


## Whether a screen row can be used at all. The resolution is a windowed-mode setting, by
## decision: in fullscreen it reads the monitor's size and does nothing.
func _screen_row_live(row: StringName) -> bool:
	if row != &"window_size":
		return true
	return Prefs.live_window_mode() == Prefs.WindowMode.WINDOWED


func _choice_of(row: StringName) -> Variant:
	match row:
		&"window_mode":
			return Prefs.live_window_mode()
		&"window_size":
			return Prefs.window_size
		&"vsync":
			return Prefs.vsync
	return Prefs.fps_cap


func _choices_of(row: StringName) -> Array:
	match row:
		&"window_mode":
			return [Prefs.WindowMode.WINDOWED, Prefs.WindowMode.BORDERLESS, Prefs.WindowMode.EXCLUSIVE]
		&"window_size":
			var sizes: Array = []
			sizes.assign(Prefs.window_sizes())
			return sizes
		&"vsync":
			return [
				DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED,
				DisplayServer.VSYNC_ADAPTIVE,
			]
	return Prefs.FPS_CAPS


## What a choice reads as on the board.
func _choice_text(row: StringName, value: Variant) -> String:
	match row:
		&"window_mode":
			match int(value):
				Prefs.WindowMode.WINDOWED:
					return "Windowed"
				Prefs.WindowMode.EXCLUSIVE:
					return "Exclusive"
			return "Borderless"
		&"window_size":
			var size: Vector2i = value
			return "%d x %d" % [size.x, size.y]
		&"vsync":
			match int(value):
				DisplayServer.VSYNC_DISABLED:
					return "Off"
				DisplayServer.VSYNC_ADAPTIVE:
					return "Adaptive"
			return "On"
	return "Uncapped" if int(value) == 0 else str(int(value))


## What the resolution row shows while it is dead: the screen the window is filling.
func _shown_choice(row: StringName) -> String:
	if row == &"window_size" and not _screen_row_live(row):
		var screen := DisplayServer.window_get_current_screen()
		var on := DisplayServer.screen_get_size(screen)
		return "%d x %d" % [on.x, on.y]
	return _choice_text(row, _choice_of(row))


func _drag_to(at: Vector2) -> void:
	for line: Dictionary in _lines:
		if line["key"] != _dragging:
			continue
		var groove: Rect2 = line["groove"]
		var level := clampf((at.x - groove.position.x) / groove.size.x, 0.0, 1.0)
		level = roundf(level * 100.0) / 100.0
		var row := _row_of(_dragging)
		# Dragging the slider is a request to hear it: the switch comes on with it.
		if not _state_of(row):
			_set_state(row, true)
			_store(StringName(String(row) + "_on"), true)
		if not is_equal_approx(level, _level_of(_dragging)):
			_set_level(_dragging, level)
			# Heard while the thumb moves; written to the file when it is let go.
			Prefs.preview(_dragging, level)
		return


func _level_of(key: StringName) -> float:
	match key:
		&"master_level":
			return master_level
		&"music_level":
			return music_level
		&"ambience_level":
			return ambience_level
	return sfx_level


func _set_level(key: StringName, level: float) -> void:
	match key:
		&"master_level":
			master_level = level
		&"music_level":
			music_level = level
		&"ambience_level":
			ambience_level = level
		_:
			sfx_level = level


## A sound row's two lines are one row to the ear: moving from the switch down to the groove
## does not say hello again.
func _row_of(key: StringName) -> StringName:
	return StringName(String(key).trim_suffix("_level"))


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
	draw_rect(face, Style.PAPER, true)

	var ribbon := _ribbon()
	Style.board_ribbon(
		self, ribbon, TITLE, CHIPS, Style.TEXT_HEAD, Style.title_room(ribbon, CLOSE_SIZE)
	)

	_lines.clear()
	dropped_lines = 0
	var left := face.position.x + BOARD_PAD
	var wide := face.size.x - BOARD_PAD * 2.0
	var y := _board.position.y + RIBBON_TALL * 0.5 + BOARD_PAD
	var listed := Rect2()
	for line: Dictionary in _plan():
		var kind: StringName = line["kind"]
		var tall := _tall_of(kind)
		var box := Rect2(left, y, wide, tall)
		y += tall + ROW_GAP
		if box.end.y > face.end.y - BOARD_PAD + 1.0:
			if kind != &"gap":
				dropped_lines += 1
			continue
		match kind:
			&"head":
				_draw_group(String(line["label"]), box)
			&"sound":
				_draw_sound(box, line)
			&"choice":
				_draw_choice(box, line)
				if line["key"] == _listing:
					listed = box
			&"button":
				_draw_button(box, line)
	_list_boxes.clear()
	if _listing != &"" and listed.size.x > 0.0 and _screen_row_live(_listing):
		_draw_list(listed, _listing)


## The plate a row sits on. **One face for every row** (2026-09-17): the board used to carry
## three — the murky water for sound, the scum green for the screen, the frame's oak for the
## buttons — and with the section headings cut in September those colours were the only thing
## saying where one section ended. Headings say it now, the way the shop's do, and a colour
## on this board is free to mean something again.
##
## A row that cannot be used is drawn back towards the board, which is the one thing a face
## still says.
func _row_face(hovered: bool, live: bool) -> Color:
	var face := Style.BOARD_ROW
	if not live:
		return face.lerp(Style.BOARD, 0.55)
	if hovered:
		face = Color(face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b)
	return face


## A group's heading: the words in the clean water's blue and a carved rule running from them
## to the board's far edge. `ShopSkin._draw_group`'s own drawing, so the two boards cannot
## end up with two kinds of heading.
func _draw_group(heading: String, box: Rect2) -> void:
	var base := box.position.y + box.size.y * 0.5 + float(Style.TEXT_SMALL) * 0.36
	var took := Style.write(
		self, heading, Style.TEXT_SMALL, Vector2(box.position.x, base), Style.PAPER_HEAD
	)
	var from := box.position.x + took.x + 8.0
	if from >= box.end.x - 4.0:
		return
	var mid := box.position.y + box.size.y * 0.5
	draw_line(Vector2(from, mid), Vector2(box.end.x, mid), Style.PAPER_RULE, 2.0)
	draw_line(Vector2(from, mid + 1.0), Vector2(box.end.x, mid + 1.0), Style.PAPER_EDGE, 1.0)


## A label on the left of a line and a switch on its right.
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
	# The clean water, not the money's gold: the groove under this switch already fills in
	# `ON_WATER` when the row is on, so one row said "on" in two colours — and gold on the
	# shop's board is a price.
	draw_rect(track, Style.ON_WATER if on else Style.BOARD, true)
	var thumb_wide := SWITCH_TALL - 2.0
	var thumb := Rect2(
		Vector2(track.end.x - thumb_wide - 1.0 if on else track.position.x + 1.0, track.position.y + 1.0),
		Vector2(thumb_wide, SWITCH_TALL - 2.0)
	)
	Style.plank(self, thumb, int(track.position.y), Style.FRAME, 2.0)


## A row with a label and a chooser on its right: `◂ value ▸`. The arrows are their own
## little planks and the value between them is a box of its own, because on the resolution
## row that box is what opens the list.
func _draw_choice(box: Rect2, line: Dictionary) -> void:
	var row: StringName = line["key"]
	var live := _screen_row_live(row)
	var hovered := (
		_hovered == StringName(String(row) + "_less")
		or _hovered == StringName(String(row) + "_more")
		or _hovered == row
	)
	Style.plate(self, box, _row_face(hovered, live))
	Style.write(
		self, String(line["label"]), Style.TEXT_BODY,
		Vector2(box.position.x + ROW_INSET, box.position.y + (box.size.y + float(Style.TEXT_BODY) * 0.62) * 0.5),
		Style.BOARD_INK if live else INK_SOFT
	)
	var right := box.end.x - ROW_INSET
	var mid := box.position.y + (box.size.y - SWITCH_TALL) * 0.5
	if not live:
		_draw_dead_choice(row, Rect2(
			Vector2(right - VALUE_WIDE - (ARROW_WIDE + ARROW_GAP) * 2.0, mid),
			Vector2(VALUE_WIDE + (ARROW_WIDE + ARROW_GAP) * 2.0, SWITCH_TALL)
		))
		return
	var more := Rect2(Vector2(right - ARROW_WIDE, mid), Vector2(ARROW_WIDE, SWITCH_TALL))
	var value := Rect2(
		Vector2(more.position.x - ARROW_GAP - VALUE_WIDE, mid), Vector2(VALUE_WIDE, SWITCH_TALL)
	)
	var less := Rect2(
		Vector2(value.position.x - ARROW_GAP - ARROW_WIDE, mid), Vector2(ARROW_WIDE, SWITCH_TALL)
	)
	_lines.append({
		"kind": &"arrow", "key": StringName(String(row) + "_less"), "row": row,
		"step": -1, "box": less,
	})
	_lines.append({
		"kind": &"arrow", "key": StringName(String(row) + "_more"), "row": row,
		"step": 1, "box": more,
	})
	_lines.append({"kind": &"value", "key": row, "row": row, "box": value})
	_draw_arrow(less, -1)
	_draw_arrow(more, 1)
	Style.write(
		self, _shown_choice(row), Style.TEXT_SMALL,
		Vector2(0.0, value.position.y + (value.size.y + float(Style.TEXT_SMALL) * 0.62) * 0.5),
		VALUE_INK, HORIZONTAL_ALIGNMENT_CENTER, value
	)


## A chooser that cannot be used **draws no arrows at all** (2026-09-17). Dimmed, they were a
## pair of controls that would not answer, on the row most players meet first — an old
## `fullscreen: true` migrates to borderless, and Resolution is dead in either fullscreen. So
## what is left is a reading of the screen the window is filling, with the row that decides
## it named, right-aligned where the chooser stood.
func _draw_dead_choice(row: StringName, box: Rect2) -> void:
	var text := _shown_choice(row)
	var took := Style.measure(text, Style.TEXT_SMALL)
	var base := box.position.y + (box.size.y + float(Style.TEXT_SMALL) * 0.62) * 0.5
	Style.write(
		self, text, Style.TEXT_SMALL, Vector2(box.end.x - took.x, base), INK_SOFT
	)
	if row != &"window_size":
		return
	var why := DEAD_SIZE_NOTE
	var wants := Style.measure(why, Style.TEXT_TINY)
	var at := box.end.x - took.x - NOTE_GAP - wants.x
	# Said only where it fits whole: a reason cut in half is worse than no reason.
	if at < box.position.x:
		return
	Style.write(
		self, why, Style.TEXT_TINY,
		Vector2(at, box.position.y + (box.size.y + float(Style.TEXT_TINY) * 0.62) * 0.5),
		INK_SOFT
	)


func _draw_arrow(box: Rect2, step: int) -> void:
	Style.plank(self, box, int(box.position.y) * 7 + step, Style.FRAME, 2.0)
	var ink := Style.RIBBON_INK
	# The point goes the way the arrow steps: the left one points left.
	var mid := box.get_center()
	var reach := Vector2(4.0, 6.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(mid.x + reach.x * step, mid.y),
			Vector2(mid.x - reach.x * step, mid.y - reach.y),
			Vector2(mid.x - reach.x * step, mid.y + reach.y),
		]),
		ink
	)


## The resolution's list, dropped under its row and over whatever is beneath it.
func _draw_list(row_box: Rect2, row: StringName) -> void:
	var values := _choices_of(row)
	var wide := VALUE_WIDE + ARROW_WIDE * 2.0 + ARROW_GAP * 2.0
	var tall := LIST_ROW * values.size() + LIST_PAD * 2.0
	var at := Vector2(row_box.end.x - ROW_INSET - wide, row_box.end.y + 2.0)
	# A list that would run off the board's foot is hung above its row instead.
	if at.y + tall > _board.end.y:
		at.y = maxf(_board.position.y, row_box.position.y - tall - 2.0)
	var box := Rect2(at, Vector2(wide, tall))
	draw_rect(box.grow(1.0), Style.SEAM, true)
	draw_rect(box, Style.BOARD, true)
	var y := at.y + LIST_PAD
	for value: Variant in values:
		var entry := Rect2(Vector2(at.x + LIST_PAD, y), Vector2(wide - LIST_PAD * 2.0, LIST_ROW))
		_list_boxes.append({"box": entry, "value": value})
		var picked: bool = _choice_text(row, value) == _choice_text(row, _choice_of(row))
		if picked:
			draw_rect(entry, PICKED_FACE, true)
		Style.write(
			self, _choice_text(row, value), Style.TEXT_SMALL,
			Vector2(0.0, y + (LIST_ROW + float(Style.TEXT_SMALL) * 0.62) * 0.5),
			Style.INK_DARK if picked else Style.BOARD_INK,
			HORIZONTAL_ALIGNMENT_CENTER, entry
		)
		y += LIST_ROW


## A sound row: one plate, the label and switch on its top line, the volume groove along
## its bottom line. The top line toggles, the bottom line drags.
func _draw_sound(box: Rect2, line: Dictionary) -> void:
	var key: StringName = line["key"]
	var level_key: StringName = line["level"]
	var on := _state_of(key)
	var level := _level_of(level_key)
	var top := Rect2(box.position, Vector2(box.size.x, box.size.y - GROOVE_LINE))
	var under := Rect2(Vector2(box.position.x, top.end.y), Vector2(box.size.x, GROOVE_LINE))
	var groove := Rect2(
		Vector2(under.position.x + ROW_INSET, under.position.y + (under.size.y - GROOVE_TALL) * 0.5 - 2.0),
		Vector2(under.size.x - ROW_INSET * 2.0, GROOVE_TALL)
	)
	_lines.append({"kind": &"switch", "key": key, "box": top})
	_lines.append({"kind": &"slider", "key": level_key, "box": under, "groove": groove})
	Style.plate(self, box, _row_face(_row_hovered(line), true))
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
		&"master":
			return master_on
		&"music":
			return music_on
		&"sfx":
			return sfx_on
		&"ambience":
			return ambience_on
	return false


func _set_state(key: StringName, on: bool) -> void:
	match key:
		&"master":
			master_on = on
		&"music":
			music_on = on
		&"sfx":
			sfx_on = on
		&"ambience":
			ambience_on = on


## A button row: a dark plate, ringed in the seam and lit along its top edge — the two marks
## a `PlankButton` on the main menu wears, which is what tells it from the board it stands on
## when the two are one colour.
##
## **It used to be a plank of the frame's oak** and could not be read: measured on that face,
## "Controls" was 2.97:1 and "Save and go to menu" 1.37:1, and nothing could have fixed
## either, because white itself only reaches 4.06:1 on it. A warning wants a dark face to be
## red against.
##
## **Not `Style.highlight` for the lit edge**: that is the wood's, in a warm oak tone, and
## this face is paint.
func _draw_button(box: Rect2, line: Dictionary) -> void:
	var key: StringName = line["key"]
	_lines.append({"kind": &"button", "key": key, "box": box})
	var face := BUTTON_FACE
	if _hovered == key:
		face = Color(face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b)
	draw_rect(box.grow(1.0), Style.SEAM, true)
	Style.plate(self, box, face)
	Style.lit_edge(self, box, face)
	var ink := WARN_INK if bool(line.get("warn", false)) else Style.INK
	Style.write(
		self, String(line["label"]), Style.TEXT_BODY,
		Vector2(0.0, box.position.y + (box.size.y + float(Style.TEXT_BODY) * 0.62) * 0.5),
		ink, HORIZONTAL_ALIGNMENT_CENTER, box
	)
