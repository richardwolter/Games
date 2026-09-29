extends "res://scripts/ui/board.gd"
## Settings: Sound (four buses, each a mute toggle beside a power-law slider),
## Screen (window mode, windowed resolution, vsync, frame cap, city), and the
## door to the Controls board. Writes Prefs; Prefs sets the buses and the window.
## Exclusive fullscreen asks to be kept and goes back by itself after
## KEEP_SECONDS if nobody answers.

const Text = preload("res://scripts/text.gd")
const Envs = preload("res://scripts/environments.gd")
const ConfirmBoard = preload("res://scripts/ui/confirm.gd")
const BindsBoard = preload("res://scripts/ui/binds_board.gd")

const KEEP_SECONDS := 10.0
const LABEL_WIDE := 110.0

var prefs: Node
var _window: OptionButton
var _size: OptionButton
var _sizes: Array[Vector2i] = []


func _init() -> void:
	super(Text.SET_TITLE, 520.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prefs = get_node_or_null("/root/Prefs")
	if prefs == null:
		return
	body.add_child(Ink.heading(Text.SET_SOUND))
	var names := {&"Master": Text.BUS_MASTER, &"Music": Text.BUS_MUSIC, &"SFX": Text.BUS_SFX, &"Ambience": Text.BUS_AMBIENCE}
	for bus in prefs.BUSES:
		body.add_child(_sound_row(bus, names[bus]))
	body.add_child(Ink.heading(Text.SET_SCREEN))
	_window = _choice(Text.SET_WINDOW, [Text.WIN_WINDOWED, Text.WIN_BORDERLESS, Text.WIN_EXCLUSIVE], prefs.window_mode, _on_window)
	_size = _choice(Text.SET_RESOLUTION, [], 0, _on_size)
	_fill_sizes()
	_choice(Text.SET_VSYNC, [Text.VSYNC_OFF, Text.VSYNC_ON, Text.VSYNC_ADAPTIVE], prefs.VSYNCS.find(prefs.vsync),
		func(i: int) -> void: prefs.set_vsync(prefs.VSYNCS[i]))
	var caps: Array = []
	for c in prefs.FPS_CAPS:
		caps.append(Text.FPS_NONE if c == 0 else str(c))
	_choice(Text.SET_FPS, caps, prefs.FPS_CAPS.find(prefs.fps_cap), func(i: int) -> void: prefs.set_fps_cap(prefs.FPS_CAPS[i]))
	var cities: Array = []
	for id in Envs.IDS:
		cities.append(Envs.NAMES[id])
	_choice(Text.SET_CITY, cities, Envs.IDS.find(prefs.environment), func(i: int) -> void: prefs.set_environment(Envs.IDS[i]))
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 16)
	var controls := Button.new()
	controls.text = Text.SET_CONTROLS
	controls.pressed.connect(_open_controls)
	foot.add_child(controls)
	var back := Button.new()
	back.text = Text.BACK
	back.pressed.connect(close)
	foot.add_child(back)
	body.add_child(foot)
	back.grab_focus.call_deferred()


func _open_controls() -> void:
	if push_board.is_valid():
		push_board.call(BindsBoard.new())


func _row(label: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Ink.label(label)
	l.custom_minimum_size = Vector2(LABEL_WIDE, 0)
	row.add_child(l)
	body.add_child(row)
	return row


func _sound_row(bus: StringName, label: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Ink.label(label)
	l.custom_minimum_size = Vector2(LABEL_WIDE, 0)
	row.add_child(l)
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = not prefs.mutes[bus]
	toggle.text = Text.SET_ON if toggle.button_pressed else Text.SET_OFF
	toggle.custom_minimum_size = Vector2(52, 0)
	toggle.toggled.connect(_on_toggle.bind(toggle, bus))
	row.add_child(toggle)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = prefs.levels[bus]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# heard while dragged, written on release
	slider.value_changed.connect(func(v: float) -> void: prefs.set_level(bus, v, false))
	slider.drag_ended.connect(func(_c: bool) -> void: prefs.set_level(bus, slider.value, true))
	row.add_child(slider)
	return row


func _on_toggle(on: bool, toggle: Button, bus: StringName) -> void:
	toggle.text = Text.SET_ON if on else Text.SET_OFF
	prefs.set_mute(bus, not on)


func _choice(label: String, items: Array, at: int, picked: Callable) -> OptionButton:
	var row := _row(label)
	var pick := OptionButton.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		pick.add_item(str(item))
	if at >= 0 and at < items.size():
		pick.select(at)
	pick.item_selected.connect(picked)
	pick.get_popup().theme = Ink.theme()
	row.add_child(pick)
	return pick


## The resolution is a windowed-mode setting: in either fullscreen the row is
## dead and says so.
func _fill_sizes() -> void:
	_size.clear()
	_sizes = prefs.window_sizes()
	if prefs.window_mode != prefs.WindowMode.WINDOWED:
		_size.add_item(Text.SET_RES_FULL)
		_size.disabled = true
		return
	_size.disabled = false
	for s in _sizes:
		_size.add_item("%d x %d" % [s.x, s.y])
	_size.select(maxi(0, _sizes.find(prefs.window_size)))


func _on_size(i: int) -> void:
	if i >= 0 and i < _sizes.size():
		prefs.set_window_size(_sizes[i])


func _on_window(i: int) -> void:
	var was: int = prefs.window_mode
	if i == prefs.WindowMode.EXCLUSIVE and was != i:
		prefs.set_window_mode(i, false)
		var ask := ConfirmBoard.new(Text.KEEP_TITLE, Text.KEEP_WORDS, Text.KEEP_YES, Text.KEEP_NO, KEEP_SECONDS)
		ask.answered.connect(_on_keep.bind(was))
		if push_board.is_valid():
			push_board.call(ask)
		return
	prefs.set_window_mode(i)
	_fill_sizes()


func _on_keep(yes: bool, was: int) -> void:
	if yes:
		prefs.save()
	else:
		prefs.set_window_mode(was)
		_window.select(was)
	_fill_sizes()
