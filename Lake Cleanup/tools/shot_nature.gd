extends Node
## Opens the lake on a real window and saves what nature coming back looks like at three
## stages: the lake as it starts, half cleared (the west half emptied), and nearly done
## (everything but a few pools). The view is put on the island's south-west shore, where
## lawn, beach, water's edge and open water are all in the frame. A probe, not a test:
## the flora, the fish shadows and rings and the glints are things to look at.
##
## Runs on a save of its own and never writes the player's. Desktop build, not --headless:
##
##   godot --path . --fixed-fps 60 res://tools/shot_nature.tscn

const SHOT := "res://tools/last_nature_%s.png"
const LOG := "res://tools/last_nature.log"
const SAVE_PATH := "user://shot_nature.save"
## Frames each stage is given to grow in and swim before its picture.
const HOLD := 420
const STAGES := ["fresh", "half", "clean"]

var _main: Node
var _frames := 0
var _stage := 0
var _due := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	if FileAccess.file_exists(LOG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
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
		_look()
		_set_stage(0)
		_due = _frames + HOLD
	if _frames < 6:
		return
	if _frames == _due:
		_write(STAGES[_stage])
		_stage += 1
		if _stage >= STAGES.size():
			get_tree().quit()
			return
		_set_stage(_stage)
		_due = _frames + HOLD


func _look() -> void:
	var angler: Node2D = _main.get(&"_angler")
	var spot := Iso.tile_to_world(Iso.ISLAND_CENTRE.x - 4.0, Iso.ISLAND_CENTRE.y + 5.0)
	_main.set(&"_pan", spot - angler.position)
	_main.set(&"_panning", true)
	# The aim ring off the lake, so the picture is the water and not the marker.
	get_viewport().warp_mouse(Vector2(8.0, 8.0))


## Empty the water down to the stage: none, the west half, or all but a few pools.
func _set_stage(stage: int) -> void:
	var grid: LakeGrid = _main.get(&"_grid")
	if stage == 0:
		return
	for index in grid.stacks.size():
		if grid.stacks[index].is_empty():
			continue
		var tile := grid.tile_of(index)
		var keep := false
		if stage == 1:
			keep = tile.x >= int(Iso.CENTRE.x)
		else:
			# A few pools of soup left, hashed by tile, so grime shows next to the clean.
			var h := sin(float(tile.x) * 12.9898 + float(tile.y) * 78.233) * 43758.5453
			keep = (h - floor(h)) < 0.04
		if not keep:
			grid.stacks[index].resize(0)
	grid._rebuild()
	_main._build_filth_map()
	# Broods arrive one at a time a few seconds apart; the picture wants a few of them in.
	var wild: Wildlife = _main.get(&"_wildlife")
	wild.set(&"_brood_in", 0.0)


func _write(name: String) -> void:
	var flora: Flora = _main.get(&"_flora")
	var fish: Fish = _main.get(&"_fish")
	var wild: Wildlife = _main.get(&"_wildlife")
	var water: ShaderMaterial = _main.get(&"_water_material")
	var log := FileAccess.open(LOG, FileAccess.WRITE if _stage == 0 else FileAccess.READ_WRITE)
	log.seek_end()
	log.store_line("%s: clean share %.3f glint %.3f plants %d of %d schools %d bees %d" % [
		name, _main.clean_share(), float(water.get_shader_parameter(&"glint")),
		flora.alive_count(), flora.candidate_count(), fish.school_count(), flora.bee_count()])
	log.store_line("  wildlife: shore %d frogs %d turtles %d broods %d dragonflies %d pads %d" % [
		wild.shore_count(), wild.frog_count(), wild.turtle_count(), wild.brood_count(),
		wild.dragonfly_count(), flora.pad_spots().size()])
	log.close()
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(SHOT % name))
	# And the middle of it at twice the size, where the animals can be made out.
	var w := shot.get_width()
	var h := shot.get_height()
	var near := shot.get_region(Rect2i(w / 4, h / 4, w / 2, h / 2))
	near.resize(w, h, Image.INTERPOLATE_NEAREST)
	near.save_png(ProjectSettings.globalize_path(SHOT % (name + "_near")))
