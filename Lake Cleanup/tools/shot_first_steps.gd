extends Node
## The first steps (`scripts/first_steps.gd`), photographed step by step.
##
## Run it with the **desktop build, not `--headless`**, at a fixed step:
## `<exe> --path . --fixed-fps 60 tools/shot_first_steps.tscn`. Saves
## `tools/last_steps_{move,move_azerty,move_pad,cast,cast_pad,note}.png` and
## `tools/last_steps.log`.
##
## Its own save path, deleted first, and the lake under this node rather than the tree root
## (see `tools/shot_letter.gd`). A borrowed lake is marked as having done the steps, so the
## probe takes the flag back off by hand, the way a new game's arrival does.

const SHOT := "res://tools/last_steps_%s.png"
const LOG := "res://tools/last_steps.log"
const SAVE := "user://lake_cleanup_shot_steps.save"
## Frames to let the lake build, and to let the view settle after each change.
const SETTLE := 60
const LOOK := 40
const WALK := 120
## Frames before giving up on the catch, and a wall clock under all of it.
const PATIENCE := 1200
const QUIT_AFTER_MS := 90000

var _main: Node
var _log: FileAccess
var _frames := 0
var _stage := 0
var _at := 0
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
	if _busy or _main == null or not _main.is_inside_tree():
		return
	var steps: FirstSteps = _main.get(&"_steps")
	var wait := _frames - _at
	match _stage:
		0:
			if _frames < SETTLE:
				return
			_log = FileAccess.open(LOG, FileAccess.WRITE)
			_main.set(&"_steps_done", false)
			_next()
		1:
			if wait < LOOK or steps == null:
				return
			_say("found in %d ms" % int(_main.get(&"_steps_found_ms")))
			_say("beach tile %s, water %s, angler %s, keys %s" % [
				str(_main.get(&"_steps_beach")), str(_main.get(&"_steps_water")),
				str((_main.get(&"_angler") as Node).get(&"tile_pos")), str(steps.keys)
			])
			_shoot("move")
		2:
			if wait == 1:
				steps.keys = ["Z", "Q", "S", "D"]
			if wait < 6:
				return
			_shoot("move_azerty")
		3:
			if wait == 1:
				steps.keys = ["W", "A", "S", "D"]
				Pad.set_mode(Pad.Mode.PAD)
			if wait < 6:
				return
			_shoot("move_pad")
		4:
			if wait == 1:
				Pad.set_mode(Pad.Mode.MOUSE)
				# Walk him there the led walk's way, so the step ends on its own rule.
				(_main.get(&"_angler") as Node).set(&"walk_to", _main.get(&"_steps_beach"))
			if steps.step != FirstSteps.Step.CAST or wait < WALK:
				if wait > PATIENCE:
					_say("never reached the beach spot")
					_finish()
				return
			_shoot("cast")
		5:
			if wait == 1:
				Pad.set_mode(Pad.Mode.PAD)
			if wait < 6:
				return
			_shoot("cast_pad")
		6:
			if wait == 1:
				Pad.set_mode(Pad.Mode.MOUSE)
				# Near the ring's edge, not its middle: the ring promises a catch anywhere in it.
				var edge := Vector2(-0.9 * float(_main.call(&"_steps_ring")), 0.0)
				_main.call(&"_cast_at", (_main.get(&"_steps_water") as Vector2) + edge)
			if steps.step != FirstSteps.Step.NOTE or not bool(_main.get(&"_steps_landed")):
				if wait > PATIENCE:
					_say("no catch landed: step %d" % steps.step)
					_finish()
				return
			if wait < 20:
				return
			_shoot("note")
		7:
			if steps.step != FirstSteps.Step.OFF:
				if wait > PATIENCE:
					_say("the note never closed")
					_finish()
				return
			_say("done: saved flag %s" % str(_main.get(&"_steps_done")))
			_finish()


func _next() -> void:
	_stage += 1
	_at = _frames


func _shoot(name_of: String) -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(SHOT % name_of)
	_say("shot %s" % name_of)
	_busy = false
	_next()


func _say(line: String) -> void:
	if _log == null:
		return
	_log.store_line(line)
	_log.flush()


func _finish() -> void:
	set_physics_process(false)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()
