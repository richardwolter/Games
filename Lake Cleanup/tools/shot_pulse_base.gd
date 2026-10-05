extends Node
## Photographs the HUD's two picture buttons at rest over the lake, for the pulse mockup
## (2026-10-05, `tools/pulse_mockup.py`): `tools/last_pulse_base.png`, the whole window, and
## `tools/last_pulse_base.log`, the two buttons' boxes in window pixels. Desktop build, own
## save, under its own node.
##
##   godot --path . --fixed-fps 60 res://tools/shot_pulse_base.tscn
##
## `PULSE_FILM=1` films the real pulse instead: both buttons' counts rise at frame 60 and the
## top right corner is saved every other frame for nine seconds into `tools/film/pulse/`
## (`f_0000.png` on), the burst and the first idle hops.

const SHOT := "res://tools/last_pulse_base.png"
const LOG := "res://tools/last_pulse_base.log"
const SAVE_PATH := "user://probe_pulse_base.save"

var _main: Node
var _frames := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	add_child.call_deferred(_main)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if OS.get_environment("PULSE_FILM") == "1":
		_film()
		return
	if _frames > 600:
		get_tree().quit()
		return
	if _main == null or not _main.is_inside_tree():
		return
	var skin: HudSkin = _main.get(&"_skin")
	if skin == null:
		return
	if _frames >= 60:
		for name: StringName in [&"upgrades", &"shed"]:
			skin._pulses[name] = 0.0
			skin._unseen[name] = false
		skin.queue_redraw()
	if _frames == 150:
		var shot := get_viewport().get_texture().get_image()
		shot.save_png(ProjectSettings.globalize_path(SHOT))
		var scale := float(shot.get_width()) / skin.get_viewport_rect().size.x
		var out := FileAccess.open(LOG, FileAccess.WRITE)
		for name: StringName in [&"upgrades", &"shed"]:
			var box: Rect2 = skin.get(&"_upgrades_box" if name == &"upgrades" else &"_shed_box")
			box = Rect2(skin.get_global_transform() * box.position * scale, box.size * scale)
			out.store_line("%s %d %d %d %d" % [name, box.position.x, box.position.y,
				box.size.x, box.size.y])
		out.store_line("scale %.3f" % scale)
		out.close()
	if _frames >= 154:
		get_tree().quit()


func _film() -> void:
	if _frames > 800:
		get_tree().quit()
		return
	if _main == null or not _main.is_inside_tree():
		return
	var skin: HudSkin = _main.get(&"_skin")
	if skin == null:
		return
	if _frames == 50:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/film/pulse"))
	if _frames == 60:
		skin.available = skin.available + 1
		skin.waiting = skin.waiting + 1
	if _frames >= 60 and _frames % 2 == 0:
		var shot := get_viewport().get_texture().get_image()
		var crop := shot.get_region(Rect2i(shot.get_width() - 540, 0, 540, 260))
		crop.save_png(ProjectSettings.globalize_path("res://tools/film/pulse/f_%04d.png" % ((_frames - 60) / 2)))
