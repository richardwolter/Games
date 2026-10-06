extends Node
## The outer bank's beach litter and strand up close: whether the pieces lying on the sand
## throw shadows and sit in it. Saves tools/last_beach_{dry,strand}.png. Own save, under its
## own node. Desktop build, not --headless:
##
##   godot --path . --fixed-fps 60 res://tools/shot_beach.tscn

const SHOT := "res://tools/last_beach_%s.png"
const SAVE_PATH := "user://shot_beach.save"
const HOLD := 120

var _main: Node
var _grid: LakeGrid
var _camera: Camera2D
var _frames := 0
var _stage := 0
var _due := 0
var _spots: Array[Vector2] = []


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	add_child.call_deferred(_main)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > 3000:
		get_tree().quit()
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 6:
		_grid = _main.get(&"_grid")
		_camera = _main.get_node(^"Camera") as Camera2D
		get_viewport().warp_mouse(Vector2(8.0, 8.0))
		_spots = [_find(true), _find(false)]
		_look(_spots[0])
		_due = _frames + HOLD
	if _frames < 6 or _frames != _due:
		return
	var img := get_viewport().get_texture().get_image()
	var mid := img.get_size() / 2
	img.get_region(Rect2i(mid - Vector2i(360, 200), Vector2i(720, 400))).save_png(SHOT % ["dry", "strand"][_stage])
	_stage += 1
	if _stage >= 2:
		get_tree().quit()
		return
	_look(_spots[1])
	_due = _frames + HOLD


## A shore tile holding two pieces, on the sand or on the strand, south of the lake so the
## view is not across the island.
func _find(sand: bool) -> Vector2:
	for index in _grid.stacks.size():
		if _grid.shore[index] != 1 or _grid.stacks[index].size() < 2:
			continue
		if (_grid.dry[index] == 1) != sand:
			continue
		var at := _grid.surface_still(index)
		if at.y > 300.0:
			return at
	return Vector2.ZERO


func _look(spot: Vector2) -> void:
	var angler: Node2D = _main.get(&"_angler")
	_main.set(&"_pan", spot - angler.position)
	_main.set(&"_panning", true)
	_main.set(&"_view_zoom", _main.call(&"_zoom_level", 4))
	_main.call(&"_push_zoom")
