extends Node
const DogArt := preload("res://scripts/dog_art.gd")
## The pack, close up: the three breeds running home with a piece in their jaws, and each
## sitting, laid and asleep — a strip of crops at several frames of the gait, so the carry
## can be judged mid-stride (2026-09-22). A probe, not a test: where a bottle sits against
## a nose is a thing to look at.
##
## Run it with the desktop build, not --headless: nothing renders under the dummy driver.
##
##   <exe> --path . --fixed-fps 60 res://tools/shot_dogs.tscn
##
## Saves tools/last_dogs.png (the strip) and tools/last_dogs.log. Its own save path, and
## the lake under this node rather than the root, so it is not the game and wears no menu.

const SAVE_PATH := "user://shot_dogs.save"
const SHOT := "res://tools/last_dogs.png"
const LOG := "res://tools/last_dogs.log"

## The crop round each dog, in screen pixels, and how far up the crop the foot stands.
const CROP := Vector2i(120, 100)
const FOOT_AT := 0.72
## Screen pixels an art pixel, held on the lake's own zoom.
const ZOOM := 4.0
## How many gait frames to photograph, and the poses beside them.
const STRIDES := 6
const POSES: Array[StringName] = [&"sit", &"laid", &"sleep"]

var _main: Node
var _frames := 0
var _dogs: Array = []
var _strip: Image
var _column := 0
var _log: FileAccess


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	add_child(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 6:
		_pose()
		return
	# Zoomed right in on the pack, held every frame: the lake's own view drive writes the
	# camera's zoom from this each frame, past the wheel's stops.
	_main.set(&"_view_zoom", ZOOM)
	if _frames < 12:
		return
	# One column of the strip every three frames, so the gait is caught at several points.
	if (_frames - 12) % 3 == 0 and _column < STRIDES + POSES.size():
		_snap(_column)
		_column += 1
		return
	if _column >= STRIDES + POSES.size():
		_strip.save_png(ProjectSettings.globalize_path(SHOT))
		_log.store_line("wrote %s" % SHOT)
		_log.close()
		get_tree().quit()


func _pose() -> void:
	_log = FileAccess.open(LOG, FileAccess.WRITE)
	_main.set(&"sludge", 1000000.0)
	for i in 3:
		_main.call(&"_buy", &"dog_count")
	_dogs = _main.get(&"_dogs")
	var grid: LakeGrid = _main.get(&"_grid")
	# Three pieces of three sizes, the first liftable kinds of tiers 0, 1 and 2 that have art.
	var picks: Array[int] = []
	for tier in [0, 1, 1, 2]:
		for i in grid.defs.size():
			var def: TrashDef = grid.defs[i]
			if def.tier == tier and not def.keepsake and not i in picks:
				picks.append(i)
				break
	var angler: Angler = _main.get(&"_angler")
	# Round the angler, who the camera follows, a stride apart along one tile row.
	var stand := angler.tile_pos + Vector2(-2.0, 1.4)
	for i in _dogs.size():
		var dog: Dog = _dogs[i]
		dog.tile_pos = stand + Vector2(1.4, -0.2) * float(i)
		dog.facing_left = false
		dog.set(&"_state", Dog.State.CARRY_BACK)
		dog.set(&"_age", 0.0)
		var carried := PackedInt32Array()
		if not picks.is_empty():
			carried.append(picks[i % picks.size()])
		dog.set(&"_carried", carried)
		_log.store_line("dog %d slot %d breed %d carries %s" % [
			i, dog.slot, dog.breed, grid.defs[carried[0]].display_name if carried.size() > 0 else "-"
		])
	_strip = Image.create(CROP.x * (STRIDES + POSES.size()), CROP.y * _dogs.size(), false, Image.FORMAT_RGBA8)
	_strip.fill(Color(0.16, 0.16, 0.16))


func _snap(column: int) -> void:
	if column >= STRIDES:
		var pose := POSES[column - STRIDES]
		for dog: Dog in _dogs:
			dog.set(&"_carried", PackedInt32Array())
			dog.set(&"_state", {&"sit": Dog.State.SIT, &"laid": Dog.State.LOUNGE, &"sleep": Dog.State.NAP}[pose])
			dog.set(&"_mood_left", 100.0)
			dog.queue_redraw()
	var shot := get_viewport().get_texture().get_image()
	# Canvas coordinates are the 1280x720 design frame; the picture is the window.
	var stretch := Vector2(shot.get_size()) / get_viewport().get_visible_rect().size
	for i in _dogs.size():
		var dog: Dog = _dogs[i]
		var at := dog.get_global_transform_with_canvas().origin * stretch
		var corner := Vector2i(int(at.x) - CROP.x / 2, int(at.y) - int(CROP.y * FOOT_AT))
		var name: StringName = dog.call(&"_showing")
		var frame := DogArt.frame_at(name, float(dog.get(&"_age")), dog.breed)
		var mouth: Vector2 = DogArt.mouth(name, Dog.HEIGHT, dog.facing_left, frame, dog.breed)
		_log.store_line("column %d dog %d %s frame %d mouth %s drop %.1f at %s" % [
			column, i, name, frame, mouth, float(dog.get(&"_carry_drop")), at
		])
		var crop := Rect2i(corner, CROP).intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
		if crop.size.x <= 0 or crop.size.y <= 0:
			continue
		_strip.blit_rect(shot, crop, Vector2i(column * CROP.x, i * CROP.y) + (crop.position - corner))
