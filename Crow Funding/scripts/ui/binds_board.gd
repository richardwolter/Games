extends "res://scripts/ui/board.gd"
## Controls: one row a verb, its key on a button. Click a key and press another
## to rebind (a key already in use swaps over, so nothing is left unbound);
## right-click puts that row back to default; Escape cancels a capture and is
## itself never bindable. "Set to default" asks first.

const Text = preload("res://scripts/text.gd")
const Binds = preload("res://scripts/binds.gd")
const ConfirmBoard = preload("res://scripts/ui/confirm.gd")

var prefs: Node
var _keys := {}
var _capturing: StringName = &""


func _init() -> void:
	super(Text.BINDS_TITLE, 440.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prefs = get_node_or_null("/root/Prefs")
	for action in Binds.ORDER:
		var row := HBoxContainer.new()
		var l := Ink.label(Binds.label_of(action))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var key := Button.new()
		key.custom_minimum_size = Vector2(150, 0)
		key.pressed.connect(_capture.bind(action))
		key.gui_input.connect(_on_key_input.bind(action))
		row.add_child(key)
		_keys[action] = key
		body.add_child(row)
	var fixed := HBoxContainer.new()
	var fl := Ink.label(Text.BIND_PAUSE, Ink.TEXT_BODY, true)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fixed.add_child(fl)
	var fk := Ink.label(Text.KEY_ESC, Ink.TEXT_BODY, true)
	fk.custom_minimum_size = Vector2(150, 0)
	fk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fixed.add_child(fk)
	body.add_child(fixed)
	var hint := Ink.label(Text.BINDS_HINT, Ink.TEXT_SMALL, true)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 16)
	var reset := Button.new()
	reset.text = Text.BINDS_RESET
	reset.pressed.connect(_ask_reset)
	foot.add_child(reset)
	var back := Button.new()
	back.text = Text.BACK
	back.pressed.connect(close)
	foot.add_child(back)
	body.add_child(foot)
	_show()
	back.grab_focus.call_deferred()


func holds_escape() -> bool:
	return _capturing != &""


func _show() -> void:
	for action in _keys:
		var b: Button = _keys[action]
		b.text = Text.BINDS_PRESS if action == _capturing else Binds.key_name(Binds.key_of(action))
		b.theme_type_variation = &"InkAccent" if action == _capturing else &""


func _capture(action: StringName) -> void:
	_capturing = action
	_show()


func _on_key_input(event: InputEvent, action: StringName) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_apply(Binds.restore(_overrides(), action))
		accept_event()


func _input(event: InputEvent) -> void:
	if _capturing == &"" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var k := int((event as InputEventKey).physical_keycode)
	if k == 0:
		k = int((event as InputEventKey).keycode)
	var action := _capturing
	_capturing = &""
	if Binds.RESERVED.has(k):
		_show()
		return
	_apply(Binds.rebind(_overrides(), action, k))


func _overrides() -> Dictionary:
	return prefs.binds if prefs != null else {}


func _apply(overrides: Dictionary) -> void:
	if prefs != null:
		prefs.set_binds(overrides)
	else:
		Binds.install(overrides)
	_show()


func _ask_reset() -> void:
	var ask := ConfirmBoard.new(Text.BINDS_RESET_TITLE, "", Text.BINDS_RESET, Text.BINDS_RESET_NO)
	ask.answered.connect(_on_reset)
	if push_board.is_valid():
		push_board.call(ask)


func _on_reset(yes: bool) -> void:
	if yes:
		_apply({})
