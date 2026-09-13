extends Node
## Opens the lake on a real window, pans the view to each of the four yards in turn, and
## saves a close crop of each: the pier, its shadow, the foam at its posts and the sand at
## its platform, with the boat wherever it happens to be. A probe, not a test: whether the
## built sheet's anchor puts the jetty on the water and the platform on the sand is a thing
## to look at, and `tools/last_piers.log` says what sun it was drawn under.
##
## Run it with the desktop build, not --headless: nothing renders under the dummy driver.
##
##   godot --path . res://tools/shot_piers.tscn

const SHOT := "res://tools/last_pier_%s.png"
const LOG := "res://tools/last_piers.log"
const CROP := Vector2i(520, 360)
const ZOOM := 2
## Frames the view is given to settle on each yard before the picture is taken.
const HOLD := 40
## How many of its own material each box is given before its picture: a heap is the case
## worth looking at, as the boat probe loads the hold (shot_boat.gd HOLD_SHOWN). Put in as
## the view arrives, well inside the drain's hold.
const HEAPED := 8

var _main: Node
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
	var stops: Array = _main.get(&"_dropoffs")
	if _frames == 8:
		_look_at(stops[0])
	if _frames < 8:
		return
	var due := 8 + (_shot + 1) * HOLD
	if _frames == due:
		_write(stops[_shot])
		_shot += 1
		if _shot >= stops.size():
			get_tree().quit()
			return
		_look_at(stops[_shot])


## Pan the view onto a yard the way a hand on the mouse would, so the camera snaps there
## rather than easing over several seconds.
func _look_at(stop: Dropoff) -> void:
	var angler: Node2D = _main.get(&"_angler")
	_main.set(&"_pan", stop.place() - angler.position)
	_main.set(&"_panning", true)
	var grid: LakeGrid = _main.get(&"_grid")
	var put := 0
	for i in grid.defs.size():
		if put >= HEAPED:
			break
		if (grid.defs[i] as TrashDef).material == stop.kind and not (grid.defs[i] as TrashDef).keepsake:
			stop.put(i)
			put += 1
	# And a few coins off the box for the plate, so the flight is drawn under a real
	# renderer once per run: they have landed by the time the picture is taken, and what
	# this buys is an error in their drawing reaching the engine log.
	var coins: CoinFly = _main.get(&"_coins")
	if coins != null:
		for i in 3:
			coins.fly(stop.drop_point())


func _write(stop: Dropoff) -> void:
	var log := FileAccess.open(LOG, FileAccess.WRITE if _shot == 0 else FileAccess.READ_WRITE)
	log.seek_end()
	var day: DayCycle = stop.day
	log.store_line("%s: foot %s berth %s collars %d mounds %d heap %d front %s sign '%s' day %s" % [
		stop.kind_name(), str(stop.foot), str(stop.berth),
		(stop.get(&"_collars") as Array).size(), (stop.get(&"_mounds") as Array).size(),
		stop.held_count(), "cut" if stop.get(&"_front") != null else "none", stop.sign_text(),
		"none" if day == null else "lean %.2f stretch %.2f ink %.2f" % [
			day.lean, day.stretch, day.ink],
	])
	log.close()
	# The near walls cut off the sheet for the heap, saved beside the pictures: if the box
	# looks empty with a heap in it, this is the first thing to look at.
	var front: Texture2D = stop.get(&"_front")
	if front != null and front.get_image() != null:
		front.get_image().save_png(
			ProjectSettings.globalize_path("res://tools/last_pier_front_%s.png" % stop.kind_name().to_lower())
		)
	var shot := get_viewport().get_texture().get_image()
	var at := stop.get_global_transform_with_canvas() * stop.place()
	var to_shot := float(shot.get_width()) / get_viewport().get_visible_rect().size.x
	var centre := Vector2i(at * to_shot)
	var box := Rect2i(centre - CROP / 2, CROP)
	box = box.intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	var crop := shot.get_region(box)
	crop.resize(crop.get_width() * ZOOM, crop.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path(SHOT % stop.kind_name().to_lower()))
