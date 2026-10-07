## Headless smoke check: the farm builds and the farmer walks.
##
## Run: Godot --headless --path <project> res://tools/test_smoke.tscn --quit-after 600
##
## A scene stepped by _physics_process, not a `--script` SceneTree with `await` (that form
## stalls on Richard's build; see the root CLAUDE.md). Results go to tools/last_test.log,
## flushed per line, because the GUI build's stdout reaches no shell.
extends Node

const LOG_PATH := "res://tools/last_test.log"
const WALK_FRAMES := 30

var _log: FileAccess
var _main: Node3D
var _frame := 0
var _start: Vector3
var _failed := 0


func _ready() -> void:
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_say("smoke: start")
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_check(_main.get_node_or_null("Ground") != null, "ground built")
	_check(_main.get_node_or_null("Camera") != null, "camera built")
	_check(_main.farmer != null, "farmer built")


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 10:
		_start = _main.farmer.global_position
		Input.action_press("move_right")
	elif _frame == 10 + WALK_FRAMES:
		Input.action_release("move_right")
		var moved: float = _main.farmer.global_position.distance_to(_start)
		_check(moved > 1.0, "farmer walks (moved %.2f)" % moved)
		_check(absf(_main.farmer.global_position.y - _start.y) < 0.2, "farmer stays on the ground")
		_say("smoke: %s, %d failed" % ["PASS" if _failed == 0 else "FAIL", _failed])
		get_tree().quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	_say(("ok   " if ok else "FAIL ") + what)


func _say(line: String) -> void:
	print(line)
	_log.store_line(line)
	_log.flush()
