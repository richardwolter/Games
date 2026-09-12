extends Node
## Opens the lake on a real window, points the ferry three ways under way, and saves a close
## crop of it each time: hull, bow foam and wake together, at three times size;
## then opens the shop and saves its ferry board. A probe, not a test: whether the sheet's
## anchor puts the hull on the water and the foam on the hull is a thing to look at.
##
## Run it with the desktop build, not --headless: nothing renders under the dummy driver.

const SHOT := "res://tools/last_boat_%d.png"
const CROP := 340
const ZOOM := 2

## Tile headings to shoot, each held still under way long enough for the bow wave to build.
const HEADINGS: Array[Vector2] = [Vector2(-1.0, 1.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)]
const HOLD := 70

var _main: Node
var _boat: Boat
var _frames := 0
var _shot := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 8:
		_boat = _main.get_node(^"Boat") as Boat
		_boat.auto_ferry = false
		_point(0)
	if _frames < 8:
		return
	var due := 8 + (_shot + 1) * HOLD
	if _frames == due:
		if _shot < HEADINGS.size():
			_write(_shot)
		else:
			_write_board()
			get_tree().quit()
			return
		_shot += 1
		if _shot < HEADINGS.size():
			_point(_shot)
		else:
			_main.call(&"_set_menu", true)


## Under way, pointed, and going nowhere: a boat with no speed keeps its heading and still
## lays its foam. Loaded to the brim, because a full hold is the case worth looking at — an
## empty one shows nothing and a half one hides whether the heap clears the sail.
func _point(which: int) -> void:
	_boat.speed = 0.0
	_boat.patrol = true
	_boat.state = Boat.State.PATROL
	_boat.heading = HEADINGS[which].normalized()
	_boat.patrol_at = _boat.tile_pos + _boat.heading * 10.0
	_boat.target = 0
	var load := PackedInt32Array()
	for i in Boat.HOLD_SHOWN:
		load.append(i % 6)
	_boat.cargo = load


## The ferry's board in the shop, at window size: the hull should sit whole-pixelled over
## its wake.
func _write_board() -> void:
	var shot := get_viewport().get_texture().get_image()
	var skin: Control = _main.get_node(^"%ShopSkin")
	var board: Rect2 = (skin.get(&"_boards") as Dictionary)[&"boat"]
	var to_shot := float(shot.get_width()) / get_viewport().get_visible_rect().size.x
	var at := skin.get_global_transform_with_canvas() * board.position
	var box := Rect2i(Vector2i(at * to_shot) - Vector2i(20, 40), Vector2i(board.size * to_shot) + Vector2i(40, 60))
	box = box.intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	shot.get_region(box).save_png(ProjectSettings.globalize_path(SHOT % HEADINGS.size()))


func _write(which: int) -> void:
	# What the shadow is being cast by, beside the picture: a shadow that is not there is
	# either a sun that is not or a node that is not, and the picture cannot say which.
	var log := FileAccess.open("res://tools/last_boat.log", FileAccess.WRITE if which == 0 else FileAccess.READ_WRITE)
	log.seek_end()
	var shade: Node2D = _boat.get_node(^"Shade")
	log.store_line("shot %d: heading %s frame %d day %s shade %s" % [
		which, str(_boat.heading), _boat.heading_frame(),
		"none" if _boat.day == null else "lean %.2f stretch %.2f ink %.2f" % [
			_boat.day.lean, _boat.day.stretch, _boat.day.ink],
		"visible" if shade.visible else "hidden",
	])
	log.close()
	var shot := get_viewport().get_texture().get_image()
	var at := _boat.get_global_transform_with_canvas().origin
	var to_shot := float(shot.get_width()) / get_viewport().get_visible_rect().size.x
	var centre := Vector2i(at * to_shot)
	var box := Rect2i(centre - Vector2i(CROP, CROP) / 2, Vector2i(CROP, CROP))
	box = box.intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	var crop := shot.get_region(box)
	crop.resize(crop.get_width() * ZOOM, crop.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path(SHOT % which))
