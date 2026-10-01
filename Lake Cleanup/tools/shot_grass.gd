extends Node
## The lawn with one grass everywhere, for picking which grass and how much tone. A probe,
## not a test. Desktop build, not --headless:
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_grass.tscn
##
## Saves `tools/film/grass/now_{isle,bank}.png`, the lawn as the game draws it, and
## `tools/last_grass.log`. The picks (2026-09-28: which pack grass's greens, the tone, and
## the drawn blades over sampled tiles) were made off sheets this probe shot. On a save of its own, under its own node.

const SAVE := "user://probe_grass.save"
const CROP := Vector2i(760, 420)


var _lake: Node2D
var _age := 0.0
var _step := 0
var _log: FileAccess
var _jobs: Array = []


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/film/grass"))
	_log = FileAccess.open("res://tools/last_grass.log", FileAccess.WRITE)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_lake = load("res://scenes/main.tscn").instantiate()
	_lake.set(&"save_path", SAVE)
	_lake.set(&"autoload_save", false)
	add_child(_lake)
	_jobs.append([-1])


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _spots() -> Array:
	var isle := Iso.tile_to_world(Iso.ISLAND_CENTRE.x - 2.5, Iso.ISLAND_CENTRE.y + 3.5)
	var t := Iso.CENTRE
	while Ground.out_of_water(t.x, t.y) < Ground.SAND_OUT * 0.75:
		t -= Vector2(0.25, 0.25)
	return [["isle", isle], ["bank", Iso.tile_to_world(t.x, t.y)]]


func _apply(job: Array) -> void:
	for g: Ground in _lake.get(&"_grounds"):
		g.retune(false)


func _physics_process(delta: float) -> void:
	_age += delta
	if Time.get_ticks_msec() > 240000:
		get_tree().quit(1)
		return
	if _step == 0:
		if _age < 2.0:
			return
		_lake.set(&"_view_zoom", 1.0)
		_lake.call(&"_push_zoom")
		_lake.set(&"_free_view", true)
		_step = 1
		_age = 0.0
		return
	if _jobs.is_empty():
		get_tree().quit()
		return
	var job: Array = _jobs[0]
	var spot: Array = _spots()[_step - 1]
	if _age < 0.02:
		_apply(job)
		if bool(_lake.get(&"_shed_open")):
			_lake.call(&"_set_shed", false)
		_lake.set(&"_free_at", spot[1])
		_lake.get(&"_camera").position = spot[1]
	if _age < 0.5:
		return
	var shot := get_viewport().get_texture().get_image()
	var scale := float(shot.get_width()) / get_viewport().get_visible_rect().size.x
	var cam: Camera2D = _lake.get(&"_camera")
	var p := (cam.get_canvas_transform() * (spot[1] as Vector2)) * scale
	var corner := (Vector2i(p) - CROP / 2).clamp(Vector2i.ZERO, shot.get_size() - CROP)
	var name := "now"
	shot.get_region(Rect2i(corner, CROP)).save_png("res://tools/film/grass/%s_%s.png" % [name, spot[0]])
	_say("%s %s" % [name, spot[0]])
	_age = 0.0
	_step += 1
	if _step > 2:
		_step = 1
		_jobs.pop_front()
