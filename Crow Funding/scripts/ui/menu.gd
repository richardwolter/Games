extends CanvasLayer
## The main menu, an overlay on the live balcony (the crows go on loitering
## behind the doors), and the pause menu Escape opens in play: the same doors
## with Continue lit. Boards (settings, controls, credits, confirms) stack over
## it; Escape closes the top one, then the menu.
##
## Boot: New game is the lit door and there is no Continue (the game keeps no
## save yet, so there is nothing to continue). Pause stops the tree; this layer
## and its boards run through it.
##
## Pattern after Lake Cleanup's menu.gd (doors, stack, one accented door); not
## its look.

const Ink = preload("res://scripts/ink.gd")
const Text = preload("res://scripts/text.gd")
const Board = preload("res://scripts/ui/board.gd")
const ConfirmBoard = preload("res://scripts/ui/confirm.gd")
const SettingsBoard = preload("res://scripts/ui/settings_board.gd")
const CreditsBoard = preload("res://scripts/ui/credits_board.gd")

const LAYER := 20
## Doors column, in design pixels from the left edge. First guess.
const DOORS_AT := Vector2(90, 210)
const DOOR_SIZE := Vector2(210, 40)
## The paper wash behind the doors, full at the left edge, gone by this share.
const WASH_TO := 0.42

enum Mode { CLOSED, BOOT, PAUSE }

## Set before a New-game reload so the fresh balcony starts without the doors.
static var skip_boot := false

var mode: int = Mode.CLOSED
var _front: Control
var _doors: VBoxContainer
var _title: Label
var _stack: Array = []
## The game's HUD, hidden while the doors are up (the lake is the picture).
var hud: CanvasLayer


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_front = Control.new()
	_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	_front.mouse_filter = Control.MOUSE_FILTER_STOP
	_front.theme = Ink.theme()
	add_child(_front)
	var wash := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(Ink.PAPER, 0.92))
	grad.set_color(1, Color(Ink.PAPER, 0.0))
	grad.set_offset(1, 1.0)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_to = Vector2(1, 0)
	tex.width = 64
	tex.height = 4
	wash.texture = tex
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.anchor_right = WASH_TO
	wash.anchor_bottom = 1.0
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.add_child(wash)
	_title = Ink.label(Text.MENU_TITLE, 44)
	_title.position = DOORS_AT + Vector2(0, -110)
	_front.add_child(_title)
	var rule := ColorRect.new()
	rule.color = Ink.INK
	rule.position = DOORS_AT + Vector2(0, -44)
	rule.size = Vector2(DOOR_SIZE.x + 60, 3)
	_front.add_child(rule)
	_doors = VBoxContainer.new()
	_doors.position = DOORS_AT
	_doors.add_theme_constant_override("separation", 14)
	_front.add_child(_doors)
	_front.visible = false


func open_boot() -> void:
	_open(Mode.BOOT)


func open_pause() -> void:
	get_tree().paused = true
	_open(Mode.PAUSE)


func _open(m: int) -> void:
	mode = m
	_title.text = Text.MENU_TITLE if m == Mode.BOOT else Text.MENU_PAUSED
	for child in _doors.get_children():
		_doors.remove_child(child)
		child.free()
	if m == Mode.PAUSE:
		_door(Text.MENU_CONTINUE, resume, true)
		_door(Text.MENU_NEW, _ask_new, false)
	else:
		_door(Text.MENU_NEW, resume, true)
	_door(Text.MENU_SETTINGS, _push.bind(SettingsBoard), false)
	_door(Text.MENU_CREDITS, _push.bind(CreditsBoard), false)
	_door(Text.MENU_QUIT, _ask_quit, false)
	_front.visible = true
	if hud != null:
		hud.visible = false
	(_doors.get_child(0) as Button).grab_focus.call_deferred()


func _door(words: String, act: Callable, lit: bool) -> Button:
	var b := Button.new()
	b.text = words
	b.custom_minimum_size = DOOR_SIZE
	b.add_theme_font_size_override("font_size", Ink.TEXT_HEAD)
	if lit:
		b.theme_type_variation = &"InkAccent"
	b.pressed.connect(func() -> void: act.call())
	_doors.add_child(b)
	return b


func resume() -> void:
	while not _stack.is_empty():
		_stack.back().close()
	_front.visible = false
	if hud != null:
		hud.visible = true
	mode = Mode.CLOSED
	get_tree().paused = false


func is_open() -> bool:
	return mode != Mode.CLOSED


## Opens a board over everything (a script to instance, or a board already made).
func push(board) -> void:
	if board is Script:
		board = board.new()
	board.push_board = push
	_stack.append(board)
	board.closed.connect(_on_closed.bind(board))
	add_child(board)


func _push(script: Script) -> void:
	push(script)


func _on_closed(board) -> void:
	_stack.erase(board)
	if _stack.is_empty() and _front.visible and _doors.get_child_count() > 0:
		(_doors.get_child(0) as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if (event as InputEventKey).keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if not _stack.is_empty():
		var top = _stack.back()
		if not top.holds_escape():
			top.close()
		return
	match mode:
		Mode.PAUSE:
			resume()
		Mode.CLOSED:
			open_pause()
		# the boot menu has nowhere to go back to: Escape does nothing there


func _ask_new() -> void:
	var ask := ConfirmBoard.new(Text.CONFIRM_NEW_TITLE, Text.CONFIRM_NEW_WORDS, Text.CONFIRM_NEW_YES, Text.CONFIRM_NEW_NO)
	ask.answered.connect(func(yes: bool) -> void:
		if yes:
			get_tree().paused = false
			skip_boot = true
			get_tree().reload_current_scene())
	push(ask)


func _ask_quit() -> void:
	if mode == Mode.BOOT:
		get_tree().quit()
		return
	var ask := ConfirmBoard.new(Text.CONFIRM_QUIT_TITLE, Text.CONFIRM_QUIT_WORDS, Text.CONFIRM_QUIT_YES, Text.CONFIRM_QUIT_NO)
	ask.answered.connect(func(yes: bool) -> void:
		if yes:
			get_tree().quit())
	push(ask)
