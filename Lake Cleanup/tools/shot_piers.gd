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


func _write(stop: Dropoff) -> void:
	var log := FileAccess.open(LOG, FileAccess.WRITE if _shot == 0 else FileAccess.READ_WRITE)
	log.seek_end()
	var day: DayCycle = stop.day
	log.store_line("%s: foot %s berth %s collars %d mounds %d day %s" % [
		stop.kind_name(), str(stop.foot), str(stop.berth),
		(stop.get(&"_collars") as Array).size(), (stop.get(&"_mounds") as Array).size(),
		"none" if day == null else "lean %.2f stretch %.2f ink %.2f" % [
			day.lean, day.stretch, day.ink],
	])
	log.close()
	var shot := get_viewport().get_texture().get_image()
	var at := stop.get_global_transform_with_canvas() * stop.place()
	var to_shot := float(shot.get_width()) / get_viewport().get_visible_rect().size.x
	var centre := Vector2i(at * to_shot)
	var box := Rect2i(centre - CROP / 2, CROP)
	box = box.intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	var crop := shot.get_region(box)
	crop.resize(crop.get_width() * ZOOM, crop.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path(SHOT % stop.kind_name().to_lower()))
