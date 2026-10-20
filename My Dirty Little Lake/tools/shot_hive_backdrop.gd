extends Node
## The hive room's backdrop (2026-10-18, the hive overhaul: option A, the low hedge, off
## `tools/hive_look/last_backdrop.png`), photographed behind two steps, and the wash room's
## view beside it to show it unchanged but for the far wood's bark. A probe, not a test. Run
## with the desktop build, not --headless:
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_hive_backdrop.tscn --log-file <path>
##
## Saves `tools/hive_look/_bd_work/shot_{wash,catch,smoke,uncap,pour}.png`, crops at 3x of
## the hedge's corners and the far bank, and `shot_hive_backdrop.log` beside them. The steps
## are not driven, only skipped (`HiveRoom.skip_step`), so the probe does not lean on any
## step's hooks. On a save of its own, under its own node, out on a wall clock.

const Style := preload("res://scripts/style.gd")

const SAVE := "user://probe_hive_backdrop.save"
const OUT := "res://tools/hive_look/_bd_work/"
const QUIT_AFTER_MS := 120000

var _lake: Node2D
var _age := 0.0
var _step := 0
var _log: FileAccess


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	_log = FileAccess.open(OUT + "shot_hive_backdrop.log", FileAccess.WRITE)
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


func _hive() -> Hive:
	return _lake.get(&"_hive")


func _room() -> HiveRoom:
	return _lake.get(&"_hive_room")


func _shot(called: String, crops := true) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(OUT + "shot_%s.png" % called)
	if not crops:
		return
	var w := image.get_width()
	var h := image.get_height()
	var cuts := {
		"left": Rect2i(0, h - 150, 420, 150), "right": Rect2i(w - 420, h - 150, 420, 150),
		"bank": Rect2i(300, int(h * 0.3), 600, int(h * 0.3)),
	}
	for key: String in cuts:
		var cut := image.get_region(cuts[key])
		cut.resize(cut.get_width() * 3, cut.get_height() * 3, Image.INTERPOLATE_NEAREST)
		cut.save_png(OUT + "shot_%s_%s3x.png" % [called, key])


func _physics_process(delta: float) -> void:
	_age += delta
	if Time.get_ticks_msec() > QUIT_AFTER_MS:
		_say("wall clock: quit at step %d" % _step)
		get_tree().quit(1)
		return
	match _step:
		0:
			if _age < 2.0:
				return
			var sheets: Sheets = _lake.get(&"_sheets")
			var waiting: Array = _lake.get(&"unwashed")
			for name: String in sheets.names:
				if WashRoom.is_find(sheets, name) and name.begins_with("decor_pk_") and waiting.size() < 3:
					waiting.append(name)
			_lake.call(&"_set_wash", true)
			var wash: WashRoom = _lake.get(&"_wash")
			for name: String in waiting:
				if wash.pick(StringName(name)):
					break
			_next()
		1:
			if _age < 1.5:
				return
			var wash: WashRoom = _lake.get(&"_wash")
			_shot("wash")
			_say("wash: bare %s, veil %.2f, hulls %d, dogs %d, flotsam %d" % [
				wash.backdrop().bare, wash.backdrop().veil, wash.backdrop().hulls().size(),
				wash.backdrop().dogs().size(), wash.backdrop().flotsam_shown()
			])
			_lake.call(&"_set_wash", false)
			var hive := _hive()
			hive.moment_seen = true
			hive.set_stage(Hive.Stage.SWARM)
			_lake.call(&"_open_hive_room")
			_next()
		2:
			if _age < 1.5:
				return
			_shot("catch")
			var room := _room()
			var back := room.backdrop()
			_say("hive: plan %s, bare %s, veil %.2f, hulls %d, dogs %d, flotsam %d, birds %d" % [
				room.plan(), back.bare, back.veil, back.hulls().size(), back.dogs().size(),
				back.flotsam_shown(), back.birds().size()
			])
			_say("hedge painted %s, bees %d, top %.1f, origin %s, size %s" % [
				room.hedge().is_painted(), room.hedge().bees().size(), room.hedge().top(),
				room.origin(), room.size
			])
			room.skip_step()
			_next()
		3:
			if _age < 2.0:
				return
			_shot("smoke", false)
			_say("smoke: step %s" % _room().step_name())
			_lake.call(&"_set_hive_room", false)
			var hive := _hive()
			hive.jars = 0
			hive.harvests = 1
			hive.first_done = true
			hive.ready_seen = true
			hive.set_stage(Hive.Stage.READY)
			_lake.call(&"_open_hive_room")
			_next()
		4:
			if _age < 1.5:
				return
			_shot("uncap", false)
			_say("harvest plan %s, step %s" % [_room().plan(), _room().step_name()])
			_room().skip_step()
			_next()
		5:
			if _age < 2.0:
				return
			_shot("pour")
			_say("pour: step %s, bees %d" % [_room().step_name(), _room().hedge().bees().size()])
			get_tree().quit()


func _next() -> void:
	_step += 1
	_age = 0.0
