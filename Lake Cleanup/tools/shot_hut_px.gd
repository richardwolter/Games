extends Node
## The hut at every zoom stop, cropped at screen resolution, and the numbers that decide how its
## pixels land: the window, the stretch, the camera's zoom, screen pixels per world pixel and
## where the hut's picture starts in the world. A probe (2026-10-02): the hut and the box are
## drawn at one world px an art px, and the zoom stops are whole screen px per *two* world px,
## so a stop at 1.5 screen px per world px draws the art one and two pixels wide by turns.
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_hut_px.tscn
##
## Saves `tools/last_hut_px_<stop>.png` and `tools/last_hut_px.log`. Own save, own node.

const SAVE := "user://probe_hut_px.save"
const CROP := Vector2i(420, 320)

var _lake: Node2D
var _age := 0.0
var _stop := -1
var _log: FileAccess


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open("res://tools/last_hut_px.log", FileAccess.WRITE)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_lake = load("res://scenes/main.tscn").instantiate()
	_lake.set(&"save_path", SAVE)
	_lake.set(&"autoload_save", false)
	add_child(_lake)


func _physics_process(delta: float) -> void:
	_age += delta
	if Time.get_ticks_msec() > 90000:
		get_tree().quit(1)
		return
	if _age < 2.0:
		return
	var stops: Array[float] = _lake.call(&"_zoom_stops")
	if _stop == -1:
		var angler: Angler = _lake.get(&"_angler")
		var mid := Iso.shed_centre()
		angler.stand_at(mid + Vector2(1.6, 1.6))
		_log.store_line("window %s, stretch %.3f, stops %s" % [
			DisplayServer.window_get_size(), _lake.call(&"_stretch"), str(stops)])
		var feet: Vector2 = _lake.call(&"_shed_feet")
		var stand := feet + Vector2(0.0, Iso.SHED_TALL * Iso.SHED_ART_GROUND)
		_log.store_line("hut picture top-left (world) %s" % str(stand - Vector2(73.5, 144.0)))
		_go(0, stops)
		return
	if _age < 1.2:
		return
	var camera: Camera2D = _lake.get(&"_camera")
	var shot := get_viewport().get_texture().get_image()
	var scale := float(shot.get_width()) / get_viewport().get_visible_rect().size.x
	var feet: Vector2 = _lake.call(&"_shed_feet")
	var at := (_lake.get_global_transform_with_canvas() * feet) * scale
	var corner := (Vector2i(at) - Vector2i(CROP.x / 2, CROP.y * 3 / 4)).clamp(
		Vector2i.ZERO, shot.get_size() - CROP)
	shot.get_region(Rect2i(corner, CROP)).save_png("res://tools/last_hut_px_%d.png" % _stop)
	_log.store_line("stop %d zoom %.4f -> %.3f screen px per world px, image %s, canvas scale %.3f" % [
		_stop, camera.zoom.x, camera.zoom.x * float(_lake.call(&"_stretch")), shot.get_size(), scale])
	_log.flush()
	if _stop + 1 >= stops.size():
		get_tree().quit()
		return
	_go(_stop + 1, stops)


func _go(i: int, stops: Array[float]) -> void:
	_stop = i
	_age = 0.0
	_lake.set(&"_view_zoom", stops[i])
	_lake.call(&"_push_zoom")
