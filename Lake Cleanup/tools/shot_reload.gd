extends Node
## Walks the one road the other probes cannot: New game over a run. The lake dims, the
## loading screen comes in over it with its bar filthy, the boot scene takes over on that
## same picture and sweeps the bar, the new lake comes up under it and the view glides down.
##
## That road ends in `change_scene_to_file`, which only the game's own lake takes — a
## borrowed one reloads whoever borrowed it — so this probe puts its lake under the root and
## makes it the tree's current scene, as the boot scene would have. The probe node itself
## stays under the root to take the pictures and to quit.
##
## **The player's save is never opened, let alone written** (`Lake.session_save_path`). The
## lake this starts is on a copy, and that copy is the file "Start over" deletes; the lake
## that comes up *after* the reload is built by the boot scene, which no probe can hand a
## path to, so the path is pinned for the whole session in a static instead. The first cut
## of this probe relied on quitting before the autosave — and then stopped stepping at the
## scene change (a freed node compares equal to null, and its guard was `_lake == null`), so
## it never quit, the game ran on over the player's real save, and the autosave wrote it. A
## probe's safety may not depend on the probe working. It also quits on a wall clock now.
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_reload.tscn --log-file tools/last_reload_engine.log

const SAVE_COPY := "user://probe_reload.save"
const LOG_PATH := "res://tools/last_reload.log"
## When New game is confirmed, in seconds after the lake goes in.
const RELOAD_AT := 2.6
## Pictures, in seconds after that.
const SHOTS := [
	[0.30, &"to_loading"],
	[1.05, &"sweep"],
	[2.10, &"under"],
	[2.90, &"going"],
	[4.60, &"playing"],
]
const QUIT_AT := 5.0
## Whatever else happens, the process is gone this long after it started, in seconds.
const HARD_QUIT := 25.0

var _lake: Node
var _age := 0.0
var _asked := false
var _next := 0
var _log: FileAccess


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if FileAccess.file_exists(Lake.SAVE_PATH):
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(Lake.SAVE_PATH),
			ProjectSettings.globalize_path(SAVE_COPY)
		)
	Lake.session_save_path = SAVE_COPY
	get_tree().create_timer(HARD_QUIT, true, false, true).timeout.connect(
		func() -> void: get_tree().quit(2)
	)
	_lake = load("res://scenes/main.tscn").instantiate()
	_put_in.call_deferred()


func _put_in() -> void:
	# The lake beside this node under the root, and the tree's current scene in its place:
	# the scene change frees the current scene, and this node is no longer it.
	get_tree().root.add_child(_lake)
	get_tree().current_scene = _lake


func _process(delta: float) -> void:
	# Not `_lake == null`: the first lake is freed by the scene change, and a freed node
	# compares equal to null — which is how this stopped stepping the first time.
	if not is_inside_tree():
		return
	_age += delta
	if not _asked:
		if _age < RELOAD_AT:
			return
		_asked = true
		_age = 0.0
		_say("start over asked; the copy exists: %s" % str(FileAccess.file_exists(SAVE_COPY)))
		_lake.call(&"_reload_as", true)
		return
	if _next < SHOTS.size() and _age >= float(SHOTS[_next][0]):
		var shot: StringName = SHOTS[_next][1]
		_next += 1
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://tools/last_reload_%s.png" % shot)
		)
		var scene := get_tree().current_scene
		_say("%-11s %4.2f s  scene %s  the copy exists: %s" % [
			shot, _age, "none" if scene == null else String(scene.name),
			str(FileAccess.file_exists(SAVE_COPY)),
		])
	if _age >= QUIT_AT:
		_say("done")
		get_tree().quit()


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()
