extends Node
## The last few pieces on a cleaned lake, for judging the two things the one-sun pass's second
## round changed (2026-10-02): the part of a floating piece under its waterline, seen through
## clean and hazy water (`LakeGrid.SUNK_FLAG`), and the crescents tucked in under the pieces
## (`LakeGrid.SHADOW_DROP`, `SHADOW_SUN_SHARE`). Saves `tools/last_sunk.png` (the whole frame)
## and `tools/last_sunk_near.png` (its middle, for a closer look).
##
## Runs on a save of its own and never writes the player's. Desktop build, not --headless:
##
##   godot --path . --fixed-fps 60 res://tools/shot_sunk.tscn

const SHOT := "res://tools/last_sunk.png"
const NEAR := "res://tools/last_sunk_near.png"
const SAVE_PATH := "user://shot_sunk.save"
## One tile in this many keeps a single piece; the rest of the lake is emptied.
const KEEP_ONE_IN := 7
const HOLD := 180

var _main: Node
var _frames := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	# Under this node, not the root: a lake hung off the root is the game and wears the menu.
	add_child.call_deferred(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 6:
		_thin()
	if _frames == 6 + HOLD:
		var shot := get_viewport().get_texture().get_image()
		shot.save_png(ProjectSettings.globalize_path(SHOT))
		var w := shot.get_width()
		var h := shot.get_height()
		var middle := shot.get_region(Rect2i(w * 3 / 8, h * 3 / 8, w / 4, h / 4))
		middle.resize(w, h, Image.INTERPOLATE_NEAREST)
		middle.save_png(ProjectSettings.globalize_path(NEAR))
		get_tree().quit()


## Everything out but a scatter of single pieces, so most tiles read clean or hazy, and the
## view on the water off the island's south-west shore.
func _thin() -> void:
	var grid: LakeGrid = _main.get(&"_grid")
	for index in grid.stacks.size():
		var stack := grid.stacks[index]
		if stack.is_empty():
			continue
		var tile := grid.tile_of(index)
		var h := sin(float(tile.x) * 12.9898 + float(tile.y) * 78.233) * 43758.5453
		if int(floor((h - floor(h)) * KEEP_ONE_IN)) == 0 and grid.dry[index] == 0:
			grid.stacks[index] = PackedInt32Array([stack[stack.size() - 1]])
		else:
			grid.stacks[index] = PackedInt32Array()
	grid._rebuild()
	grid.queue_redraw()
	_main._build_filth_map()
	var angler: Node2D = _main.get(&"_angler")
	var spot := Iso.tile_to_world(Iso.ISLAND_CENTRE.x - 7.0, Iso.ISLAND_CENTRE.y + 8.0)
	_main.set(&"_pan", spot - angler.position)
	_main.set(&"_panning", true)
	get_viewport().warp_mouse(Vector2(8.0, 8.0))
