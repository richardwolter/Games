## Runs the pollution meter from full to clean and saves every frame.
##
## The meter is animated — the seam slides and the water rocks — and a still cannot show
## that. This stands a HudSkin alone in a 1080-line viewport, walks `pollution` from 1 to 0
## over a few seconds with a hold at each end, and writes each frame, cropped to the meter,
## as a numbered PNG. ffmpeg turns the folder into a gif.
##
##   godot --path . res://tools/shot_meter.tscn -- out=C:/where/frames
extends Node

const VIEW := Vector2i(1920, 1080)
const FPS := 30
const HOLD_FULL := 1.0
const SWEEP := 6.0
const HOLD_CLEAN := 2.0
## Room round the meter in the crop, in pixels.
const MARGIN := 24

var _view: SubViewport
var _skin: HudSkin
var _out := "res://tools/meter_frames"
var _frame: int = 0
var _total: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	Engine.max_fps = FPS
	_view = SubViewport.new()
	_view.size = VIEW
	_view.transparent_bg = false
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var ground := ColorRect.new()
	ground.color = Color(0.24, 0.55, 0.66)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.size = Vector2(VIEW)
	_view.add_child(ground)
	_skin = HudSkin.new()
	_skin.size = Vector2(VIEW)
	_skin.pollution = 1.0
	_view.add_child(_skin)
	_total = int((HOLD_FULL + SWEEP + HOLD_CLEAN) * float(FPS))


func _process(_delta: float) -> void:
	var t := float(_frame) / float(FPS)
	var wanted := 1.0 - clampf((t - HOLD_FULL) / SWEEP, 0.0, 1.0)
	_skin.pollution = wanted
	# The skin eases towards its reading; over a sweep this slow the lag is a few frames,
	# but the last frames must read clean, so the hold at the end is where it catches up.
	if _frame >= 2:
		var image := _view.get_texture().get_image()
		var box: Rect2 = _skin.get(&"_meter_box")
		var crop := Rect2i(
			maxi(int(box.position.x) - MARGIN, 0),
			maxi(int(box.position.y) - MARGIN, 0),
			int(box.size.x) + MARGIN * 2,
			int(box.size.y) + MARGIN * 2
		)
		image = image.get_region(crop)
		image.save_png("%s/meter_%04d.png" % [_out, _frame])
	_frame += 1
	if _frame > _total:
		get_tree().quit()
