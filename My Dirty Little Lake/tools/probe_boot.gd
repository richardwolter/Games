## Where the lake's load goes: how much of it a loader can animate through, and how much is
## the main thread standing still.
##
## The boot scene (`scenes/boot.tscn`) loads `main.tscn` on a thread and slides a meter while
## it does. Only the threaded part can move: `instantiate()`, `Lake._ready` and the first
## frames' shader compiles all run on the main thread, and a meter frozen for a second reads
## as a hang however honest its number was. This measures each part so the meter's share for
## the frozen stretch is a number rather than a guess.
##
## Desktop build, not `--headless` (no renderer, so no shader compile and no first-frame cost):
##   <exe> --path . res://tools/probe_boot.tscn --log-file tools/last_boot_engine.log
## Writes `tools/last_boot.log`.
##
## Loads a **copy** of the player's save, never the save itself: finishing or closing a lake
## writes its file, and a probe may not hand the player back a changed run.
extends Node

const LAKE := "res://scenes/main.tscn"
const LOG_PATH := "res://tools/last_boot.log"
const SAVE_COPY := "user://probe_boot.save"
## Frames timed after the lake is in the tree: the first carries the shader compiles.
const FRAMES_AFTER := 8

var _log: FileAccess
var _asked_at: int = 0
var _loaded_at: int = 0
var _load_frames: int = 0
var _load_worst: int = 0
var _last_tick: int = 0
var _main: Node
var _after: PackedInt32Array = PackedInt32Array()
var _progress: Array = []


func _ready() -> void:
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_say("engine start to this scene's _ready: %d ms" % Time.get_ticks_msec())
	if FileAccess.file_exists(Lake.SAVE_PATH):
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(Lake.SAVE_PATH),
			ProjectSettings.globalize_path(SAVE_COPY)
		)
		_say("loading a copy of the player's save")
	else:
		if FileAccess.file_exists(SAVE_COPY):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_COPY))
		_say("no save: a fresh lake")
	_asked_at = Time.get_ticks_usec()
	_last_tick = _asked_at
	ResourceLoader.load_threaded_request(LAKE)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var took := now - _last_tick
	_last_tick = now
	if _main == null:
		_load_frames += 1
		_load_worst = maxi(_load_worst, took)
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(LAKE, progress)
		if _progress.is_empty() or float(progress[0]) - float(_progress[-1]) >= 0.1:
			_progress.append(float(progress[0]))
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_put_in()
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_say("FAIL the threaded load ended in status %d" % status)
			get_tree().quit(1)
		return
	_after.append(took)
	if _after.size() >= FRAMES_AFTER:
		_report()
		get_tree().quit()


func _put_in() -> void:
	_loaded_at = Time.get_ticks_usec()
	_say("threaded load: %d ms over %d frames, worst frame %d ms" % [
		(_loaded_at - _asked_at) / 1000, _load_frames, _load_worst / 1000,
	])
	_say("progress as reported: %s" % str(_progress))
	var packed := ResourceLoader.load_threaded_get(LAKE) as PackedScene
	var got := Time.get_ticks_usec()
	_main = packed.instantiate()
	var made := Time.get_ticks_usec()
	_main.set(&"save_path", SAVE_COPY)
	Lake.boot_marks = []
	add_child(_main)
	var ready := Time.get_ticks_usec()
	# Each mark is the end of its stretch, so a stretch is a mark less the one before it.
	var before := made
	for mark: Array in Lake.boot_marks as Array:
		_say("  %5d ms  %s" % [(int(mark[1]) - before) / 1000, String(mark[0])])
		before = int(mark[1])
	Lake.boot_marks = null
	_say("load_threaded_get: %d ms" % ((got - _loaded_at) / 1000))
	_say("instantiate: %d ms" % ((made - got) / 1000))
	_say("add_child (Lake._ready and every child's): %d ms" % ((ready - made) / 1000))
	_last_tick = ready


func _report() -> void:
	var frames: Array = []
	for took in _after:
		frames.append(took / 1000)
	# The first two frames are the ones that compile and upload; the rest are the lake running.
	var frozen := (_after[0] + _after[1]) / 1000
	_say("frames after the lake went in, ms: %s" % str(frames))
	_say("main thread frozen, instantiate to the second frame out: about %d ms" % (
		(_last_tick - _loaded_at) / 1000 - _sum_from(2)
	))
	_say("of which the first two frames: %d ms" % frozen)
	_say("whole load, ask to running: %d ms" % ((_last_tick - _asked_at) / 1000 - _sum_from(2)))
	_say("done")


func _sum_from(index: int) -> int:
	var total := 0
	for at in range(index, _after.size()):
		total += _after[at]
	return total / 1000


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()
