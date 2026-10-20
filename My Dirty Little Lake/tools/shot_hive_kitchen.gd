extends Node
## The harvest's two steps photographed for the kitchen look (2026-10-18, the hive's visual
## overhaul: the uncap sheet's and the pour sheet's option B). A copy of `shot_hive.gd` cut down
## to the harvest, on a save of its own, so it can run while that probe runs.
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_hive_kitchen.tscn --log-file tools/last_kitchen_engine.log
##
## Saves `tools/last_kitchen_{uncap,uncap_drip,pour,pour_crown,done}.png` (the window) and zoomed
## crops of where the honey meets things: `last_kitchen_{join,low,bucket,jar,stand}.png`, plus
## `tools/last_kitchen.log`.

const Style := preload("res://scripts/style.gd")

const SAVE := "user://probe_hive_kitchen.save"
const QUIT_AFTER_MS := 90000
const ZOOM := 6

var _lake: Node2D
var _age := 0.0
var _step := 0
var _log: FileAccess


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	_log = FileAccess.open("res://tools/last_kitchen.log", FileAccess.WRITE)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Lake.force_hive = true
	_lake = load("res://scenes/main.tscn").instantiate()
	_lake.set(&"save_path", SAVE)
	_lake.set(&"autoload_save", false)
	add_child(_lake)


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _room() -> HiveRoom:
	return _lake.get(&"_hive_room")


func _whole(called: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://tools/last_kitchen_%s.png" % called)


## A crop of the window round a box on the room's art grid, blown up `ZOOM` times, nearest.
func _art_crop(called: String, art: Rect2) -> void:
	var room := _room()
	var shot := get_viewport().get_texture().get_image()
	var scale := float(shot.get_width()) / get_viewport().get_visible_rect().size.x
	var tl := (room.get_global_transform_with_canvas() * (room.origin() + art.position * HiveArt.PIXEL)) * scale
	var sz := art.size * HiveArt.PIXEL * scale
	var r := Rect2i(Vector2i(tl), Vector2i(sz)).intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	var cut := shot.get_region(r)
	cut.resize(r.size.x * ZOOM / 2, r.size.y * ZOOM / 2, Image.INTERPOLATE_NEAREST)
	cut.save_png("res://tools/last_kitchen_%s.png" % called)


func _physics_process(delta: float) -> void:
	_age += delta
	if Time.get_ticks_msec() > QUIT_AFTER_MS:
		_say("wall clock: quit at step %d" % _step)
		get_tree().quit(1)
		return
	var room := _room()
	match _step:
		0:
			if _age < 2.0:
				return
			var hive: Hive = _lake.get(&"_hive")
			hive.jars = 0
			hive.harvests = 1
			hive.first_done = true
			hive.moment_seen = true
			hive.ready_seen = true
			hive.set_stage(Hive.Stage.READY)
			_lake.call(&"_open_hive_room")
			_say("harvest room: plan %s" % [_room().plan() if _room() != null else []])
			_next()
		1:
			if room == null or room.step_name() != &"uncap" or _age < 1.0:
				return
			room.step().call(&"cut_to", 0.55)
			_next()
		2:
			if _age < 2.6:
				return
			_whole("uncap")
			_art_crop("join", Rect2(250, 205, 120, 60))
			_art_crop("low", Rect2(470, 230, 110, 120))
			_art_crop("knife", Rect2(150, 120, 340, 60))
			var st := room.step()
			_say("uncap: level %.2f streaming %s" % [st.call(&"bucket_level"), st.call(&"streaming")])
			room.step().call(&"cut_to", 1.0)
			_next()
		3:
			if _age < 2.5:
				return
			_whole("uncap_full")
			_art_crop("bucket", Rect2(500, 250, 95, 100))
			_art_crop("low_full", Rect2(470, 230, 110, 120))
			_art_crop("join_full", Rect2(300, 215, 100, 45))
			_say("uncap later: level %.2f streaming %s" % [room.step().call(&"bucket_level"), room.step().call(&"streaming")])
			_next()
		4:
			if room.step_name() == &"uncap" and bool(room.step().call(&"streaming")) and _age < 4.0:
				return
			if _age < 0.6:
				return
			_whole("uncap_drip")
			_art_crop("bucket_drip", Rect2(470, 230, 125, 120))
			_say("drip shot in step %s" % room.step_name())
			if room.step_name() == &"uncap":
				room.step().call(&"settle")
			_next()
		5:
			if room == null or not is_instance_valid(room):
				_say("room gone")
				get_tree().quit(1)
				return
			if room.step_name() != &"pour" or _age < 1.0:
				return
			_whole("pour_start")
			room.step().call(&"pour", 1.1)
			_next()
		6:
			if _age < 0.45:
				return
			_whole("pour")
			_art_crop("jar", Rect2(225, 190, 70, 100))
			_art_crop("stand", Rect2(190, 120, 270, 185))
			var st := room.step()
			st.call(&"release")
			st.call(&"pour", 2.6)
			st.call(&"release")
			st.call(&"pour", 2.65)
			_next()
		7:
			if _age < 0.5:
				return
			_whole("pour_crown")
			_art_crop("jar_crown", Rect2(225, 190, 70, 100))
			room.step().call(&"release")
			room.step().call(&"pour", 2.6)
			room.step().call(&"release")
			_next()
		8:
			if _age < 0.9:
				return
			_whole("done")
			_art_crop("bench", Rect2(310, 150, 150, 150))
			_say("pour jars %d" % room.step().call(&"jars_done"))
			_next()
		9:
			if _age < 1.0:
				return
			get_tree().quit()


func _next() -> void:
	_step += 1
	_age = 0.0
