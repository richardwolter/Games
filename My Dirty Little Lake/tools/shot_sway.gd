extends Node
## The plants moving with the water (2026-10-02): every plant grown at once, the view on the
## island at the nearest zoom, and `FRAMES` crops a beat apart, side by side in
## `tools/last_sway.png`, plus one on the shore water for the pads. Desktop build:
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_sway.tscn
##
## Own save, own node.

const SAVE := "user://probe_sway.save"
const CROP := Vector2i(360, 260)
const FRAMES := 6
const GAP := 1.2

var _lake: Node2D
var _age := 0.0
var _step := 0
var _shots: Array[Image] = []


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
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
	if _step == 0:
		if _age < 2.0:
			return
		var flora: Flora = _lake.get(&"_flora")
		var ages: PackedFloat32Array = flora.get(&"_age")
		var delay: PackedFloat32Array = flora.get(&"_delay")
		for k in ages.size():
			ages[k] = delay[k] + Flora.GROW_TIME + 1.0
		flora.set(&"_age", ages)
		flora.set(&"_dirty", true)
		flora.queue_redraw()
		var stops: Array[float] = _lake.call(&"_zoom_stops")
		_lake.set(&"_view_zoom", stops[stops.size() - 1])
		_lake.call(&"_push_zoom")
		var angler: Angler = _lake.get(&"_angler")
		angler.stand_at(Iso.ISLAND_CENTRE + Vector2(1.5, 2.5))
		_step = 1
		_age = 0.0
		return
	if _age < GAP:
		return
	_age = 0.0
	var shot := get_viewport().get_texture().get_image()
	var mid := shot.get_size() / 2
	_shots.append(shot.get_region(Rect2i(mid - CROP / 2, CROP)))
	if _shots.size() < FRAMES:
		return
	var sheet := Image.create_empty(CROP.x * FRAMES, CROP.y, false, Image.FORMAT_RGBA8)
	for i in FRAMES:
		sheet.blit_rect(_shots[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(i * CROP.x, 0))
	sheet.save_png("res://tools/last_sway.png")
	get_tree().quit()
