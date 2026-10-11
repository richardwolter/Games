extends "res://tools/film_trailer.gd"
## Films the angler casting and hauling home in the four directions, close up, for judging the
## line coiling in the hands (2026-10-11): frames to `tools/film/coils/<dir>_NNN.png`. Desktop
## build, not --headless; the camera holds still on the angler, so the net runs out of shot
## and the hands are what is watched.
##
##   godot --path . --fixed-fps 60 res://tools/shot_coils.tscn

const CROP := Vector2i(300, 300)
const COIL_OUT := "res://tools/film/coils/"
## Frames kept after the net is home, for the tuck.
const AFTER := 40

var _home_at := -1


func _init() -> void:
	SAVE_PATH = "user://shot_coils.save"
	LOG_PATH = "res://tools/film/coils/last_coils.log"


func _plan() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(COIL_OUT))
	_shots = []
	for row: Array in [["east", Vector2(3.9, -3.3), ACROSS], ["west", Vector2(-3.3, 3.9), LEFT],
			["south", Vector2(4.6, 4.6), DOWN], ["north", Vector2(-4.4, -4.4), UP]]:
		_shots.append([row[0], 0.0, _pose.bind(row[1], row[2]), _run.bind(row[2])])


func _pose(off: Vector2, dir: Vector2) -> void:
	_hide_boats()
	_unpack()
	(_main.get(&"_dogs")[0] as Node2D).visible = false
	_stand(off, dir)
	_zoom(5)
	_hold = Iso.tile_to_world(_angler.tile_pos.x, _angler.tile_pos.y) + Vector2(0.0, -20.0)
	_home_at = -1


func _run(f: int, dir: Vector2) -> void:
	if f == SETTLE:
		_cast(dir, 7.0)
	if f < SETTLE:
		return
	var image := get_viewport().get_texture().get_image()
	var middle := image.get_size() / 2
	image.get_region(Rect2i(middle - CROP / 2, CROP)).save_png(
		ProjectSettings.globalize_path(COIL_OUT + "%s_%03d.png" % [_shots[_shot][0], f - SETTLE]))
	if _home_at < 0 and f > SETTLE + 5 and _net.state == CastNet.State.IDLE:
		_home_at = f
	if _home_at >= 0 and f >= _home_at + AFTER or f > SETTLE + 900:
		_next()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 3:
		_setup()
		_plan()
		_next()
		return
	if _frames < 4 or _shot >= _shots.size():
		return
	(_shots[_shot][3] as Callable).call(_shot_frame)
	_aim()
	_shot_frame += 1
