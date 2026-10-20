extends Node
## The hive room's catch, smoke and queen steps photographed mid-move, for checking the
## 2026-10-18 overhaul against its mockups (tools/hive_look/last_{catch,smoke,queen}.png).
## A probe, not a test. Desktop build, not --headless:
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_hive_steps.tscn --log-file tools/hive_look/_mine/engine.log
##
## Saves tools/hive_look/_mine/shot_<name>.png and steps.log. **On a save of its own, under
## its own node**; out on a wall clock whatever happens.

const Style := preload("res://scripts/style.gd")

const SAVE := "user://probe_hive_steps.save"
const OUT := "res://tools/hive_look/_mine/"
const QUIT_AFTER_MS := 120000

var _lake: Node2D
var _age := 0.0
var _step := 0
var _log: FileAccess
var _shots: Array = []
var _shot_at := 0


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	_log = FileAccess.open(OUT + "steps.log", FileAccess.WRITE)
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


func _shot(called: String) -> void:
	get_viewport().get_texture().get_image().save_png(OUT + "shot_%s.png" % called)
	_say("shot %s" % called)


func _physics_process(delta: float) -> void:
	_age += delta
	if Time.get_ticks_msec() > QUIT_AFTER_MS:
		_say("wall clock")
		get_tree().quit(1)
		return
	match _step:
		0:
			if _age < 2.0:
				return
			var hive: Hive = _lake.get(&"_hive")
			hive.jars = 0
			hive.harvests = 0
			hive.first_done = false
			hive.moment_seen = true
			hive.set_stage(Hive.Stage.SWARM)
			_lake.call(&"_open_hive_room")
			_say("plan %s" % [_room().plan()])
			_step = 1
			_age = 0.0
		1:
			_run()


## A script per step: [wait seconds, callable] pairs run in order once the step is up.
func _script(name: StringName, step: HiveStep) -> Array:
	match name:
		&"catch":
			return [
				[1.0, func() -> void: _shot("catch_start")],
				[0.1, func() -> void:
					step.call(&"box_clump", 0)
					step.call(&"box_clump", 1)
					step.call(&"grab_at", step.call(&"clump_pos", 3))
					step.call(&"drag_to", Vector2(404.0, 176.0))],
				[0.35, func() -> void: _shot("catch_drag")],
				[0.1, func() -> void: step.call(&"drag_to", Vector2(318.0, 207.0))],
				[1.2, func() -> void: _shot("catch_over")],
				[0.1, func() -> void: step.call(&"let_go")],
				[0.3, func() -> void: _shot("catch_pour")],
				[1.5, func() -> void: _shot("catch_after")],
				[0.1, func() -> void:
					step.call(&"box_clump", 2)
					step.call(&"box_clump", 4)],
				[0.8, func() -> void: _shot("catch_done")],
				[0.1, func() -> void: step.call(&"settle")],
			]
		&"smoke":
			return [
				[1.0, func() -> void: _shot("smoke_start")],
				[0.1, func() -> void:
					step.call(&"aim", Vector2(345.0, 165.0))
					step.call(&"hold", 1.3)],
				[1.25, func() -> void: _shot("smoke_top")],
				[0.1, func() -> void:
					step.call(&"smoke_ring", 0, 3.0)
					step.call(&"aim", Vector2(350.0, 205.0))
					step.call(&"hold", 1.4)],
				[1.35, func() -> void: _shot("smoke_mid")],
				[2.5, func() -> void: _shot("smoke_crowd")],
				[0.1, func() -> void: step.call(&"settle")],
			]
		&"queen":
			return [
				[1.2, func() -> void: step.call(&"aim", Vector2(412.0, 128.0))],
				[0.8, func() -> void: _shot("queen_search")],
				[0.1, func() -> void: step.call(&"aim", (step.call(&"queen_pos") as Vector2) + Vector2(6.0, -3.0))],
				[0.8, func() -> void: _shot("queen_lens")],
				[0.1, func() -> void: step.call(&"find_at", step.call(&"queen_pos"))],
				[0.7, func() -> void: _shot("queen_found")],
				[0.1, func() -> void:
					step.call(&"settle")
					_say("done, quitting")
					get_tree().quit()],
			]
	return []


func _run() -> void:
	var room := _room()
	if room == null:
		get_tree().quit(1)
		return
	var name := room.step_name()
	var step := room.step()
	if step == null:
		return
	if not step.has_meta(&"probe_script"):
		if _age < 0.6:
			return
		step.set_meta(&"probe_script", true)
		_shots = _script(name, step)
		_shot_at = 0
		_age = 0.0
		_say("step %s up" % name)
	if _shot_at >= _shots.size():
		_age = 0.0
		return
	var item: Array = _shots[_shot_at]
	if _age < float(item[0]):
		return
	(item[1] as Callable).call()
	_shot_at += 1
	_age = 0.0
