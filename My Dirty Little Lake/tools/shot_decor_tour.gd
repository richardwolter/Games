extends Node
## The decoration tour (`scripts/tour_card.gd`, `Lake._decor_tour_step`), card by card.
##
## Desktop build, not `--headless`: `<exe> --path . --fixed-fps 60 tools/shot_decor_tour.tscn`.
## Saves `tools/last_decor_tour_{hint,1,2,3,3pad,4,4pad,5}.png` and `last_decor_tour.log`. Its
## own save, deleted first and after, the lake under this node (see `tools/shot_letter.gd`).
## A borrowed lake has done its tours and has its bed in the shed, so the probe undoes both
## the way a new game's arrival does.

const SHOT := "res://tools/last_decor_tour_%s.png"
const LOG := "res://tools/last_decor_tour.log"
const SAVE := "user://lake_cleanup_shot_decor_tour.save"
const SETTLE := 60
const LOOK := 12
const QUIT_AFTER_MS := 90000

var _main: Node
var _log: FileAccess
var _frames := 0
var _at := 0
var _stage := 0
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
		_say("wall clock ran out at stage %d" % _stage)
		_finish()
		return
	if _busy or _frames < SETTLE:
		return
	var wait := _frames - _at
	match _stage:
		0:
			_log = FileAccess.open(LOG, FileAccess.WRITE)
			_main.call(&"_bed_to_the_pump")
			_main.set(&"_decor_tour_done", false)
			_main.set(&"_decor_tour", Lake.DecorTour.HINT)
			_next()
		1:
			if wait < LOOK:
				return
			_shoot("hint")
		2:
			if wait == 1:
				_main.call(&"_set_shed", true)
			if wait < LOOK:
				return
			_shoot("1")
		3:
			if wait == 1:
				_main.call(&"_decor_tour_next")
				_main.call(&"_shed_to_wash")
			if wait < LOOK:
				return
			_shoot("2")
		4:
			if wait == 1:
				_main.call(&"_decor_tour_next")
			if wait < LOOK:
				return
			_shoot("3")
		5:
			if wait == 1:
				Pad.set_mode(Pad.Mode.PAD)
			if wait < LOOK:
				return
			_shoot("3pad")
		6:
			if wait == 1:
				Pad.set_mode(Pad.Mode.MOUSE)
				_main.call(&"_decor_tour_next")
				_main.call(&"_on_find_washed", StringName(Lake.STARTER_BED), 0)
			if wait < 150:
				return
			_say("shed open %s, wash open %s, state %d" % [
				str(_main.get(&"_shed_open")), str(_main.get(&"_wash_open")), int(_main.get(&"_decor_tour"))])
			_shoot("4")
		7:
			if wait == 1:
				Pad.set_mode(Pad.Mode.PAD)
			if wait < LOOK:
				return
			_shoot("4pad")
		8:
			if wait == 1:
				Pad.set_mode(Pad.Mode.MOUSE)
				_main.call(&"_decor_tour_next")
			if wait < LOOK:
				return
			_shoot("5")
		9:
			_main.call(&"_decor_tour_next")
			_say("done %s" % str(_main.get(&"_decor_tour_done")))
			_finish()


func _next() -> void:
	_stage += 1
	_at = _frames


func _shoot(name_of: String) -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT % name_of)
	_say("shot %s" % name_of)
	_busy = false
	_next()


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _finish() -> void:
	set_physics_process(false)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()
