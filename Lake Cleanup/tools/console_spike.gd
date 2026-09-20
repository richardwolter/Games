extends Control
## The console shelf on its own, for judging the look before any of it is wired up.
##
## Not a test and not the feature: nothing in the lake, the fill, the save or the pump is
## touched, and nothing in `user://` is read or written. One board, twenty slots, the
## consoles cut by `tools/build_consoles.py`.
##
## Run it with the desktop build, not --headless — the point is to look at it:
##
##   <godot> --path . res://tools/console_spike.tscn
##
## Drag a console onto another slot to swap them. F: half the collection found, so the gaps
## can be judged. A: all of it. Escape: out.
##
## `SHELF_AUTO=1` saves `tools/last_consoles_{full,half}.png` and quits.

const Style := preload("res://scripts/style.gd")

var _shelf: ConsoleShelf
var _auto := false
var _clock := 0.0
var _step := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shelf = ConsoleShelf.new()
	_shelf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shelf)
	_shelf.fill_all()
	_auto = OS.get_environment("SHELF_AUTO") == "1"


func _draw() -> void:
	# The lake behind a board is a dark blue-green; the spike stands in for it so the wood
	# is judged against roughly what it will sit on.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.15, 0.16), true)


func _half() -> void:
	var names: Array = []
	for i in _shelf.consoles.size():
		if i % 2 == 0:
			names.append(_shelf.consoles[i]["name"])
	_shelf.found_only(names)


func _physics_process(delta: float) -> void:
	if not _auto:
		return
	_clock += delta
	if _step == 0 and _clock > 0.4:
		get_viewport().get_texture().get_image().save_png("res://tools/last_consoles_full.png")
		_shelf.report()
		_half()
		_step = 1
		_clock = 0.0
	elif _step == 1 and _clock > 0.4:
		get_viewport().get_texture().get_image().save_png("res://tools/last_consoles_half.png")
		get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif key.keycode == KEY_F:
		_half()
	elif key.keycode == KEY_A:
		_shelf.fill_all()
