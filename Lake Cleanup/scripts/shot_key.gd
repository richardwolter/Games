## F12 in a debug build saves what is on screen, HUD and all, as a PNG, for picking the Steam
## store screenshots by hand (2026-10-02, Richard: "take several and pick the best").
##
## Saved to `Games/Marketing/My Dirty Little Lake/screenshots/raw/` beside the project when
## running from the editor or the desktop build on this machine; anywhere `res://` is not a
## folder (an export) it falls back to `user://screenshots/`. Taken at the window's own size,
## so a 1920x1080 window gives Steam's 1920x1080. The mouse pointer is a hardware cursor and
## is never in the picture.
##
## **Shift+F12 takes it bare**: every CanvasLayer (the HUD, boards, coins, curtain) is hidden
## for one drawn frame and put back, so only the world is in the picture — for key art and
## the page background.
##
## Hung under the `Pad` autoload rather than made an autoload of its own, so `project.godot`
## is not touched. Debug builds only: nothing here ships.
extends CanvasLayer

const KEY := KEY_F12
const MARKETING := "../Marketing/My Dirty Little Lake/screenshots/raw"
const FALLBACK := "user://screenshots"
## A faint white blink after the picture is taken, so the press is seen. Drawn only after the
## frame was grabbed, so it is never in the shot it answers.
const BLINK_TIME := 0.15
const BLINK_ALPHA := 0.25

var _blink := 0.0
var _rect: ColorRect
var _busy := false
## Layers hidden for a bare shot, put back once it is taken.
var _hidden: Array[CanvasLayer] = []


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	set_process(false)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY or _busy:
		return
	get_viewport().set_input_as_handled()
	_busy = true
	if key.shift_pressed:
		_hide_layers(get_tree().root)
	RenderingServer.frame_post_draw.connect(_grab, CONNECT_ONE_SHOT)


func _hide_layers(node: Node) -> void:
	for child in node.get_children():
		var layer := child as CanvasLayer
		if layer != null and layer != self and layer.visible:
			layer.visible = false
			_hidden.append(layer)
		_hide_layers(child)


func _grab() -> void:
	var image := get_viewport().get_texture().get_image()
	var dir := folder()
	DirAccess.make_dir_recursive_absolute(dir)
	var now := Time.get_datetime_dict_from_system()
	var name := "mdll_%04d%02d%02d_%02d%02d%02d_%03d.png" % [
		now.year, now.month, now.day, now.hour, now.minute, now.second,
		Time.get_ticks_msec() % 1000]
	if not _hidden.is_empty():
		name = name.replace(".png", "_bare.png")
	for layer in _hidden:
		if is_instance_valid(layer):
			layer.visible = true
	_hidden.clear()
	var path := dir.path_join(name)
	var err := image.save_png(path)
	print("shot_key: %s %dx%d -> %s" % [error_string(err), image.get_width(), image.get_height(), path])
	_busy = false
	_blink = BLINK_TIME
	set_process.call_deferred(true)


func _process(delta: float) -> void:
	_blink = maxf(_blink - delta, 0.0)
	_rect.color.a = BLINK_ALPHA * _blink / BLINK_TIME
	if _blink <= 0.0:
		set_process(false)


## Where the pictures go, as an absolute path.
static func folder() -> String:
	var project := ProjectSettings.globalize_path("res://")
	if DirAccess.dir_exists_absolute(project):
		return project.path_join(MARKETING).simplify_path()
	return ProjectSettings.globalize_path(FALLBACK)
