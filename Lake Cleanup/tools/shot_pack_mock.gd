extends Node
## The lake twice per view, with its rubbish and with the rubbish hidden, plus where every
## visible piece sits on the screen, its material, tier and drawn size. Feeds
## tools/hd_rubbish/pack_mock.py, which lays another asset pack's objects on the empty water
## at the game's own grain. Own save, under its own node. Desktop build, not --headless:
##
##   godot --path . --fixed-fps 60 res://tools/shot_pack_mock.tscn

const SHOT := "res://tools/hd_rubbish/mock_%s_%s.png"
const LOG := "res://tools/hd_rubbish/mock_%s.json"
const SAVE_PATH := "user://shot_pack_mock.save"
const HOLD := 300
const VIEWS := [["near", 4], ["far", 2]]
const SOUP := [^"Shadows", ^"Foam", ^"Sprites", ^"Glints"]

var _main: Node
var _grid: LakeGrid
var _frames := 0
var _view := 0
var _bare := false
var _due := 0


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
	if _frames > 4000:
		get_tree().quit()
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 6:
		_grid = _main.get(&"_grid")
		get_viewport().warp_mouse(Vector2(8.0, 8.0))
		_look()
	if _frames < 6 or _frames != _due:
		return
	var name: String = VIEWS[_view][0]
	if not _main.is_processing():
		# frozen: the view cannot move between the two shots
		get_viewport().get_texture().get_image().save_png(SHOT % [name, "bare" if _bare else "soup"])
	else:
		_main.set_process(false)
		(_main.get_node(^"Camera") as Node).process_mode = Node.PROCESS_MODE_DISABLED
		_due = _frames + 6
		return
	if not _bare:
		_log(name)
		_show_soup(false)
		_bare = true
		_due = _frames + 6
		return
	_show_soup(true)
	_main.set_process(true)
	(_main.get_node(^"Camera") as Node).process_mode = Node.PROCESS_MODE_INHERIT
	_bare = false
	_view += 1
	if _view >= VIEWS.size():
		get_tree().quit()
		return
	_look()


## Out over the south water from the island, at the view's zoom stop.
func _look() -> void:
	var angler: Node2D = _main.get(&"_angler")
	_main.set(&"_pan", Vector2(-220.0, 260.0))
	_main.set(&"_panning", true)
	_main.set(&"_view_zoom", _main.call(&"_zoom_level", VIEWS[_view][1]))
	_main.call(&"_push_zoom")
	_due = _frames + HOLD
	angler.get_parent()


func _show_soup(on: bool) -> void:
	_grid.self_modulate.a = 1.0 if on else 0.0
	for path in SOUP:
		var node := _grid.get_node_or_null(path) as CanvasItem
		if node:
			node.visible = on


## Every stack's top piece on screen: where, what material and tier, how big it is drawn.
func _log(name: String) -> void:
	# surface_still is in the grid's own space: the grid's transform goes in with the camera's
	var xf := get_viewport().get_screen_transform() * _grid.get_global_transform_with_canvas()
	var scale := xf.get_scale().x
	# the screen transform takes the canvas to window pixels, so bounds are the window's
	var size := Vector2(get_viewport().get_texture().get_size())
	var pieces := []
	for index in _grid.stacks.size():
		var stack: Array = _grid.stacks[index]
		if stack.is_empty():
			continue
		var at: Vector2 = xf * _grid.surface_still(index)
		if at.x < -40.0 or at.y < -40.0 or at.x > size.x + 40.0 or at.y > size.y + 40.0:
			continue
		var def: TrashDef = _grid.defs[stack[-1]]
		pieces.append({"x": at.x, "y": at.y, "kind": TrashDef.KIND_NAMES[def.material],
			"tier": def.tier, "piece": String(def.piece),
			"dry": _grid.dry[index] == 1, "keepsake": def.keepsake})
	var out := {"screen_per_world": scale, "size": [size.x, size.y], "pieces": pieces}
	var file := FileAccess.open(LOG % name, FileAccess.WRITE)
	file.store_string(JSON.stringify(out))
	file.close()
