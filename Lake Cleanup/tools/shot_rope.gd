extends "res://tools/film_trailer.gd"
## Close crops of the angler mid-cast in the four directions, for judging where the rope
## leaves the body: `tools/last_rope_<dir>.png` (2026-10-02). Desktop build, not --headless.
##
##   godot --path . --fixed-fps 60 res://tools/shot_rope.tscn

const CROP := Vector2i(360, 260)

func _init() -> void:
	SAVE_PATH = "user://shot_rope.save"
	LOG_PATH = "res://tools/last_rope.log"


func _plan() -> void:
	_shots = []
	for row: Array in [["east", Vector2(3.9, -3.3), ACROSS], ["west", Vector2(-3.3, 3.9), LEFT],
			["south", Vector2(4.6, 4.6), DOWN], ["north", Vector2(-4.4, -4.4), UP]]:
		_shots.append([row[0], 0.0, _pose.bind(row[1], row[2]), _run.bind(row[2])])


func _pose(off: Vector2, dir: Vector2) -> void:
	_hide_boats()
	_unpack()
	(_main.get(&"_dogs")[0] as Node2D).visible = false
	_stand(off, dir)
	_zoom(6)
	_hold = Iso.tile_to_world(_angler.tile_pos.x, _angler.tile_pos.y) + Vector2(0.0, -20.0)


func _run(f: int, dir: Vector2) -> void:
	if f == SETTLE:
		_cast(dir, 6.0)
	if f == SETTLE + 14:
		var image := get_viewport().get_texture().get_image()
		var middle := image.get_size() / 2
		image.get_region(Rect2i(middle - CROP / 2, CROP)).save_png(
			ProjectSettings.globalize_path("res://tools/last_rope_%s.png" % _shots[_shot][0]))
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
