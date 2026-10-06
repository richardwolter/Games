extends Control
## The wash stand on its own, for judging the feel (issue #37, step one).
##
## Not a test and not the feature: no pump on the island, no tray, no soap, no save. One find
## at a time on `WashStand`, every find in the catalogue a key press away. Nothing in the
## lake is touched and nothing in `user://` is read or written.
##
## Run it with the desktop build, not --headless — the point is to look at it and play it:
##
##   <godot> --path . res://tools/wash_spike.tscn
##
## Hold the left button to spray. Left / Right: another find. R: the same find, dirty again.
## F1: the figures. Escape: out.
##
## `WASH_AUTO=1` washes the find by itself in a raster, saves `tools/last_wash_{mid,done}.png`
## and quits: what proves the thing runs end to end, not a judge of how it feels.

const Style := preload("res://scripts/style.gd")

var _sheets := Sheets.new()
var _stand: WashStand
var _finds: Array[StringName] = []
var _at := 0
var _figures := true
var _began := 0.0
var _took := 0.0
var _auto := false
var _auto_clock := 0.0
var _auto_shot := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not _sheets.load_all():
		push_error("wash_spike: no art")
		get_tree().quit(1)
		return
	for name: String in _sheets.names:
		if name.begins_with("decor_") and _sheets.views.has(name):
			_finds.append(StringName(name))
	_stand = WashStand.new()
	_stand.sheets = _sheets
	_stand.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stand.washed.connect(_on_washed)
	add_child(_stand)
	var words := Words.new()
	words.host = self
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(words)
	var wanted := OS.get_environment("WASH_FIND")
	if not wanted.is_empty() and _finds.has(StringName(wanted)):
		_at = _finds.find(StringName(wanted))
	_auto = OS.get_environment("WASH_AUTO") == "1"
	_show()


func _physics_process(delta: float) -> void:
	if not _auto:
		return
	_auto_clock += delta
	var box := _stand.piece_box()
	# Down the piece in rows, back and forth, the way somebody careful would.
	var rows := 9.0
	var along := _auto_clock * 0.55
	var row := floorf(along)
	var across := along - row
	if int(row) % 2 == 1:
		across = 1.0 - across
	# Round again from the top once it has reached the bottom, half a row off the last pass.
	var lap := floorf(row / rows)
	var down := (fmod(row, rows) + 0.5 + 0.5 * fmod(lap, 2.0)) / rows
	var at := box.position + Vector2(across, down) * box.size
	_stand.spray(at, _stand.state == WashStand.State.WASHING)
	if not _auto_shot and _stand.share_clean() > 0.45:
		_auto_shot = true
		get_viewport().get_texture().get_image().save_png("res://tools/last_wash_mid.png")
	if _stand.state == WashStand.State.CLEAN or _auto_clock > 60.0:
		get_viewport().get_texture().get_image().save_png("res://tools/last_wash_done.png")
		print("wash_spike: state %d, clean %.2f, took %.1f s" % [
			_stand.state, _stand.share_clean(), _took
		])
		get_tree().quit()


func _show() -> void:
	_stand.put(_finds[_at])
	_began = 0.0
	_took = 0.0


func _on_washed(_piece: StringName) -> void:
	_took = _began


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_RIGHT:
			_at = posmod(_at + 1, _finds.size())
			_show()
		KEY_LEFT:
			_at = posmod(_at - 1, _finds.size())
			_show()
		KEY_R:
			_show()
		KEY_F1:
			_figures = not _figures
		KEY_ESCAPE:
			get_tree().quit()


## The game's own clock rather than the wall's, so a --fixed-fps run reads true.
func _process(delta: float) -> void:
	if _stand != null and _stand.state == WashStand.State.WASHING:
		_began += delta


## Drawn by a child, so the words land over the stand, which is a child too.
class Words:
	extends Control

	var host: Control

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		host.call(&"_write", self)


func _write(on: CanvasItem) -> void:
	if _stand == null or _finds.is_empty():
		return
	var title := _sheets.title_of(_finds[_at])
	Style.write(on, title, Style.TEXT_HEAD, Vector2(24.0, 40.0))
	Style.write(
		on, "Hold to spray   ·   Left / Right  another find   ·   R  again   ·   F1  figures",
		Style.TEXT_SMALL, Vector2(24.0, 62.0), Style.BOARD_INK
	)
	if not _figures:
		return
	var line := "%d / %d    clean %d%%    %d fps" % [
		_at + 1, _finds.size(), roundi(_stand.share_clean() * 100.0),
		Engine.get_frames_per_second(),
	]
	if _took > 0.0:
		line += "    took %.1f s" % _took
	Style.write(on, line, Style.TEXT_SMALL, Vector2(24.0, 84.0), Style.BOARD_INK)
