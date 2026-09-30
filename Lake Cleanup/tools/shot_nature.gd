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
const STAGES := ["fresh", "half", "clean", "under"]

## "under" (2026-09-30, the lakebed pass): on the clean lake, every frog sent into the water,
## every turtle under it and a brood let in, and close crops of each saved as
## `last_nature_under_<what>.png`, since the full frame is too far out to judge them by.
const UNDER_HOLD := 90
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
		_due = _frames + (UNDER_HOLD if STAGES[_stage] == "under" else HOLD)


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
	if STAGES[stage] == "under":
		var wild: Wildlife = _main.get(&"_wildlife")
		for f: Dictionary in wild.frogs():
			wild.call(&"_frog_jump_in", f, (f["at"] as Vector2) + Vector2(0.0, -20.0))
		var k := 0
		for t: Dictionary in wild.turtles():
			if true:
				t["at"] = (t["spot"] as Dictionary)["water"]
				t["state"] = 4 if k % 2 == 0 else 3        # Turtle.UNDER, then SWIM by turns
				t["timer"] = 30.0
				t["then"] = 3
			k += 1
		wild.refresh(_main.clean_share(), _main.get(&"_clean_tiles"), 1.0)
		wild.set(&"_brood_in", 0.0)
		# The crayfish nearest the view, brought into it: they live out on the bed, and the
		# view is on the island's shore.
		var angler: Node2D = _main.get(&"_angler")
		var view: Vector2 = angler.position + (_main.get(&"_pan") as Vector2)
		var best: Dictionary = {}
		for c: Dictionary in wild.crayfish():
			if best.is_empty() or (c["at"] as Vector2).distance_to(view) < (best["at"] as Vector2).distance_to(view):
				best = c
		if not best.is_empty():
			_main.set(&"_pan", (best["at"] as Vector2) + Vector2(0.0, -60.0) - angler.position)
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
			grid.stacks[index] = PackedInt32Array()
	grid._rebuild()
	grid.queue_redraw()
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
	if name == "under":
		var picks := {}
		for f: Dictionary in wild.frogs():
			if int(f["state"]) == 4 and not picks.has("frog"):
				picks["frog"] = f["at"]
		for t: Dictionary in wild.turtles():
			var key := "turtle_under" if int(t["state"]) == 4 else ("turtle_swim" if int(t["state"]) == 3 else "")
			if key != "" and not picks.has(key):
				picks[key] = t["at"]
		for b: Dictionary in wild.broods():
			if float(b["alt"]) <= 0.5 and not picks.has("duck"):
				picks["duck"] = b["at"]
		for c: Dictionary in wild.crayfish():
			if not picks.has("crayfish"):
				picks["crayfish"] = c["at"]
		var vp := get_viewport()
		var to_screen := vp.get_final_transform() * vp.get_canvas_transform()
		var log2 := FileAccess.open(LOG, FileAccess.READ_WRITE)
		log2.seek_end()
		log2.store_line("  under crops: %s" % [picks.keys()])
		log2.close()
		for what: String in picks:
			var at: Vector2 = to_screen * (picks[what] as Vector2)
			var box := Rect2i(Vector2i(at) - Vector2i(80, 50), Vector2i(160, 100))
			box = box.intersection(Rect2i(0, 0, w, h))
			if box.size.x < 20 or box.size.y < 20:
				continue
			var crop := shot.get_region(box)
			crop.resize(box.size.x * 4, box.size.y * 4, Image.INTERPOLATE_NEAREST)
			crop.save_png(ProjectSettings.globalize_path(SHOT % ("under_" + what)))
