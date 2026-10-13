extends Node
## Why a basking turtle reads as standing still (2026-10-13, Richard: "turtles just standing,
## no bobbing"). Opens a nearly cleaned lake, lets the turtles in, and for 240 frames logs
## each turtle's state, pose and the frame it is drawn with, beside the music's beat clock;
## every 4th frame it saves a crop round the first basking turtle at the play zoom.
##
## Desktop build, `--fixed-fps 60`, under its own node and on a save of its own.
## `tools/last_turtle_bob.log`, crops in `tools/film/turtle_bob/`.

const SAVE := "user://probe_turtle_bob.save"
const LOG := "res://tools/last_turtle_bob.log"
const DIR := "res://tools/film/turtle_bob"
const START := 40
const FRAMES := 240

var _main: Node
var _frames := 0
var _log: FileAccess
var _target: Dictionary = {}


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	add_child.call_deferred(_main)
	_log = FileAccess.open(LOG, FileAccess.WRITE)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > START + FRAMES + 30:
		_log.close()
		get_tree().quit()
		return
	if _main == null or not _main.is_inside_tree():
		return
	var wild: Wildlife = _main.get(&"_wildlife")
	if _frames == 6:
		_clean()
	if _frames == START:
		var turtles: Array = wild.turtles()
		_log.store_line("turtles %d" % turtles.size())
		for t: Dictionary in turtles:
			if int(t["state"]) == Wildlife.Turtle.BASK:
				_target = t
				break
		if _target.is_empty() and not turtles.is_empty():
			_target = turtles[0]
			wild._turtle_rest(_target)
		if not _target.is_empty():
			var cam: Camera2D = _main.get(&"_camera")
			if cam != null:
				cam.zoom = Vector2(1.0, 1.0)
	if _frames < START or _target.is_empty():
		return
	var music: MusicStation = wild.music
	var line := "f %d beat %.3f music %s heard %s" % [
		_frames, wild.beat(), music != null, music._heard() if music != null else []
	]
	for t: Dictionary in wild.turtles():
		line += " | st %d pose %s fr %s fade %.2f" % [
			int(t["state"]), String(t.get("pose", "")), wild._turtle_frame(t), float(t["fade"])
		]
	_log.store_line(line)
	if (_frames - START) % 4 == 0:
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var at: Vector2 = _target["at"]
		var screen := get_viewport().get_canvas_transform() * at
		var scale := float(image.get_width()) / get_viewport().get_visible_rect().size.x
		var c := Vector2i(screen * scale)
		var crop := image.get_region(Rect2i(c - Vector2i(60, 60), Vector2i(120, 120)))
		crop.resize(480, 480, Image.INTERPOLATE_NEAREST)
		crop.save_png(ProjectSettings.globalize_path("%s/f_%04d.png" % [DIR, _frames - START]))


func _clean() -> void:
	var grid: LakeGrid = _main.get(&"_grid")
	for index in grid.stacks.size():
		if grid.stacks[index].is_empty():
			continue
		var tile := grid.tile_of(index)
		var h := sin(float(tile.x) * 12.9898 + float(tile.y) * 78.233) * 43758.5453
		if (h - floor(h)) >= 0.03:
			grid.stacks[index] = PackedInt32Array()
	grid._rebuild()
	grid.queue_redraw()
	_main._build_filth_map()
	var wild: Wildlife = _main.get(&"_wildlife")
	wild.refresh(_main.clean_share(), _main.get(&"_clean_tiles"), 0.95)
	wild._reckon()
