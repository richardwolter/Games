extends Node
## Round 3 of the staged shop's test branch (2026-10-28), photographed: the boats' boost icon
## over the hulls, and the lake's buttons wearing their pad glyphs in pad mode.
##
## Desktop build: `<exe> --path . --fixed-fps 60 tools/shot_round3.tscn`. Saves
## `tools/last_round3_{boost,pad}.png` and `tools/last_round3.log`. Its own save, deleted first
## and after, the lake under this node.

const SHOT := "res://tools/last_round3_%s.png"
const LOG := "res://tools/last_round3.log"
const SAVE := "user://probe_round3.save"
const SETTLE := 90
const QUIT_AFTER_MS := 60000

var _main: Node
var _log: FileAccess
var _frames := 0
var _step := 0
var _busy := false
var _started_ms := 0


func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE)
	add_child(_main)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _started_ms > QUIT_AFTER_MS:
		_finish()
		return
	if _busy or _frames < SETTLE:
		return
	match _step:
		0:
			_log = FileAccess.open(LOG, FileAccess.WRITE)
			_main.set(&"_boost_left", 40.0)
			_main.call(&"_push_boat_numbers")
			var boats: Array = _main.get(&"_boats")
			for boat: Boat in boats:
				boat.moored = true
			_say("boats %d, first at %s, speed %.2f" % [boats.size(),
				str((boats[0] as Node2D).global_position) if not boats.is_empty() else "-",
				(boats[0] as Boat).speed if not boats.is_empty() else 0.0])
			_step += 1
			_frames = SETTLE - 20
		1:
			_shoot("boost")
		2:
			Pad.set_mode(Pad.Mode.PAD)
			_step += 1
			_frames = SETTLE - 10
		3:
			_shoot("pad")
		_:
			Pad.set_mode(Pad.Mode.MOUSE)
			_finish()


func _shoot(name_of: String) -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT % name_of)
	_say("shot %s" % name_of)
	_step += 1
	_busy = false


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _finish() -> void:
	set_physics_process(false)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()
