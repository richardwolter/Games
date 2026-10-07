## Headless smoke check: the farm builds, the farmer walks, and a bed goes through its
## whole cycle (plant, water, grow, harvest) both called directly and by the farmer, whose
## tasks take work time and are cancelled by walking away.
##
## Run: Godot --headless --path <project> res://tools/test_smoke.tscn --quit-after 600
##
## A scene stepped by _physics_process, not a `--script` SceneTree with `await` (that form
## stalls on Richard's build; see the root CLAUDE.md). Results go to tools/last_test.log,
## flushed per line, because the GUI build's stdout reaches no shell.
extends Node

const LOG_PATH := "res://tools/last_test.log"
const WALK_FRAMES := 30
const GROW_FRAMES := 15
const WORK_FRAMES := 15

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
	_check(_main.beds.size() == 6, "6 beds built (got %d)" % _main.beds.size())
	_check(_main.get_node_or_null("Hud") != null, "HUD built")


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
		_check_screen_directions()
		_start_bed_cycle()
	elif _frame == 10 + WALK_FRAMES + GROW_FRAMES:
		_finish_bed_cycle()
		_start_farmer_work()
	elif _frame == 10 + WALK_FRAMES + GROW_FRAMES + 1:
		_check(_main.beds[1].state == Bed.State.EMPTY, "planting takes time, not instant")
		_main.farmer.work_left = 0.05
	elif _frame == 10 + WALK_FRAMES + GROW_FRAMES + WORK_FRAMES:
		_finish_farmer_work()
		Input.action_press("move_right")
	elif _frame == 10 + WALK_FRAMES + GROW_FRAMES + WORK_FRAMES + 2:
		Input.action_release("move_right")
		_check(not _main.farmer.is_working(), "walking cancels the task")
		_check(_main.beds[1].state == Bed.State.PLANTED, "a cancelled task leaves the bed as it was")
		_say("smoke: %s, %d failed" % ["PASS" if _failed == 0 else "FAIL", _failed])
		get_tree().quit(1 if _failed > 0 else 0)


## Bed 0 by direct calls: tasks out of order do nothing, plant then water starts growth.
## The grow timer is cut short so the bed ripens within GROW_FRAMES.
func _start_bed_cycle() -> void:
	var bed: Bed = _main.beds[0]
	_check(bed.next_task() == Bed.PLANT, "empty bed wants planting")
	_check(bed.perform(Bed.WATER) == 0 and bed.state == Bed.State.EMPTY,
			"watering an empty bed does nothing")
	bed.perform(Bed.PLANT)
	_check(bed.state == Bed.State.PLANTED and bed.next_task() == Bed.WATER,
			"planted bed wants water")
	bed.perform(Bed.WATER)
	_check(bed.state == Bed.State.GROWING and bed.next_task() == &"",
			"watered bed grows on its own")
	_check(bed.perform(Bed.HARVEST) == 0, "a growing bed can't be harvested")
	bed.grow_left = 0.05


func _finish_bed_cycle() -> void:
	var bed: Bed = _main.beds[0]
	_check(bed.state == Bed.State.RIPE, "bed ripens when its timer runs out")
	var before: int = _main.stock
	_check(bed.perform(Bed.HARVEST) == Bed.YIELD, "harvest yields %d" % Bed.YIELD)
	_check(_main.stock == before + Bed.YIELD, "harvest goes into the stock")
	_check(bed.state == Bed.State.EMPTY, "harvested bed is empty again")


## The farmer starts work on the bed underfoot, and nothing when no bed is in reach.
func _start_farmer_work() -> void:
	var farmer: Farmer = _main.farmer
	var bed: Bed = _main.beds[1]
	farmer.global_position = Vector3(50.0, farmer.global_position.y, 50.0)
	_check(farmer.nearest_bed() == null and not farmer.work(), "no bed in reach, no work")
	farmer.global_position = Vector3(bed.global_position.x, farmer.global_position.y,
			bed.global_position.z)
	_check(farmer.nearest_bed() == bed, "farmer finds the bed underfoot")
	_check(farmer.work() and farmer.work_task == Bed.PLANT, "farmer starts planting")
	_check(not farmer.work(), "a second press while working starts nothing")


## Planting finished once its work ran out; then watering starts, to be walked away from.
func _finish_farmer_work() -> void:
	var farmer: Farmer = _main.farmer
	var bed: Bed = _main.beds[1]
	_check(bed.state == Bed.State.PLANTED and not farmer.is_working(),
			"bed planted when the work time runs out")
	_check(farmer.work() and farmer.work_task == Bed.WATER, "farmer starts watering")


## Each key must move the farmer the way it points on screen: project the step through the
## camera and compare with the key's screen direction.
func _check_screen_directions() -> void:
	var cam: Camera3D = _main.get_node("Camera")
	var farmer: Farmer = _main.farmer
	var keys := {
		"W": Vector2(0, -1), "S": Vector2(0, 1), "A": Vector2(-1, 0), "D": Vector2(1, 0),
	}
	for key: String in keys:
		var want: Vector2 = keys[key]
		var from := farmer.global_position
		var to := from + farmer.screen_to_ground(want)
		var on_screen := (cam.unproject_position(to) - cam.unproject_position(from)).normalized()
		_check(on_screen.dot(want) > 0.95, "%s moves %s on screen (got %s)" % [key, want, on_screen])


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	_say(("ok   " if ok else "FAIL ") + what)


func _say(line: String) -> void:
	print(line)
	_log.store_line(line)
	_log.flush()
