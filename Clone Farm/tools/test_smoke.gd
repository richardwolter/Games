## Headless smoke check: the farm builds, the farmer walks, and a bed goes through its
## whole cycle (plant, water, grow, harvest) both called directly and by the farmer, who
## steps to a spot beside the bed, is locked there while the work time runs, and cancels
## with E again. Then the machine: it costs produção, makes a clone, and a clone given a
## role works beds on its own.
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
## Long enough to walk from a bed's centre to its work spot.
const STEP_FRAMES := 30
const LOCK_FRAMES := 2
const WORK_FRAMES := 40
const CLONE_FRAMES := 40
const CLONE_WORK_FRAMES := 150

var _locked_at: Vector3

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
	_check(_main.machine != null, "machine built")
	_check(_main.stock == 5, "the farm starts with 5 produção (got %d)" % _main.stock)


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
		_check(_main.farmer.work_left == Bed.WORK_TIME[Bed.PLANT],
				"the clock waits until the farmer reaches the bed")
	elif _frame == 10 + WALK_FRAMES + GROW_FRAMES + STEP_FRAMES:
		_check_at_spot()
		_main.farmer.work_left = 0.5
		_locked_at = _main.farmer.global_position
		Input.action_press("move_right")
	elif _frame == 10 + WALK_FRAMES + GROW_FRAMES + STEP_FRAMES + LOCK_FRAMES:
		Input.action_release("move_right")
		_check(_main.farmer.is_working(), "walking keys don't cancel the task")
		_check(_main.farmer.global_position.distance_to(_locked_at) < 0.01,
				"the farmer stays put while working")
	elif _frame == 10 + WALK_FRAMES + GROW_FRAMES + STEP_FRAMES + WORK_FRAMES:
		_finish_farmer_work()
		_start_cloning()
	elif _frame == 10 + WALK_FRAMES + GROW_FRAMES + STEP_FRAMES + WORK_FRAMES + CLONE_FRAMES:
		_check_clone_made()
	elif _frame == 10 + WALK_FRAMES + GROW_FRAMES + STEP_FRAMES + WORK_FRAMES + CLONE_FRAMES \
			+ CLONE_WORK_FRAMES:
		_check_clone_worked()
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
	_check(farmer.nearest_workplace() == null and not farmer.work(), "no bed in reach, no work")
	farmer.global_position = Vector3(bed.global_position.x, farmer.global_position.y,
			bed.global_position.z)
	_check(farmer.nearest_workplace() == bed, "farmer finds the bed underfoot")
	_check(farmer.work() and farmer.work_task == Bed.PLANT, "farmer starts planting")
	_check(not farmer.work(), "a second start while working starts nothing")
	_check(not farmer.is_at_spot(), "from the bed's middle the farmer must step aside first")


## The farmer stands just outside the bed's edge, facing it.
func _check_at_spot() -> void:
	var farmer: Farmer = _main.farmer
	var bed: Bed = _main.beds[1]
	_check(farmer.is_at_spot(), "farmer reached the work spot")
	var off := farmer.global_position - bed.global_position
	off.y = 0.0
	var want := Bed.SIZE / 2.0 + Worker.SPOT_GAP
	_check(absf(off.length() - want) < 0.06,
			"work spot is beside the bed (%.2f from its centre, want %.2f)" % [off.length(), want])
	var facing := -farmer.global_basis.z
	facing.y = 0.0
	_check(facing.normalized().dot(-off.normalized()) > 0.95, "farmer faces the bed")


## Planting finished once its work ran out; then E starts watering and E again cancels it.
func _finish_farmer_work() -> void:
	var farmer: Farmer = _main.farmer
	var bed: Bed = _main.beds[1]
	_check(bed.state == Bed.State.PLANTED and not farmer.is_working(),
			"bed planted when the work time runs out")
	farmer.interact()
	_check(farmer.is_working() and farmer.work_task == Bed.WATER, "E starts watering")
	farmer.interact()
	_check(not farmer.is_working(), "E again cancels the task")
	_check(bed.state == Bed.State.PLANTED, "a cancelled task leaves the bed as it was")


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



## The machine won't clone short of COST; with enough, the farmer works it and pays.
func _start_cloning() -> void:
	var farmer: Farmer = _main.farmer
	var machine: Machine = _main.machine
	_main.stock = Machine.COST - 1
	_check(machine.next_task() == &"", "machine won't clone below %d produção" % Machine.COST)
	_main.stock = Machine.COST
	farmer.global_position = machine.global_position + Vector3(0.0, 0.0, 1.4)
	_check(farmer.nearest_target() == machine, "E by the machine picks the machine")
	farmer.interact()
	_check(farmer.is_working() and farmer.work_task == Machine.CLONE, "farmer starts cloning")
	_check(_main.clones.is_empty(), "the clone takes work time, not instant")
	farmer.work_left = 0.05


## The new clone stands idle with no role; E by it opens the choice, 1 gives it Plantar.
func _check_clone_made() -> void:
	var farmer: Farmer = _main.farmer
	_check(_main.clones.size() == 1, "machine made a clone")
	_check(_main.stock == 0, "the clone cost %d produção (left %d)" % [Machine.COST, _main.stock])
	if _main.clones.is_empty():
		return
	var clone: Clone = _main.clones[0]
	_check(clone.role == &"" and not clone.is_working(), "a new clone has no role and idles")
	farmer.global_position = clone.global_position + Vector3(0.5, 0.0, 0.0)
	_check(farmer.nearest_target() == clone, "E by a clone picks the clone")
	farmer.interact()
	_check(farmer.choosing == clone, "E opens the clone's role choice")
	farmer.pick_role(1)
	_check(clone.role == Bed.PLANT and farmer.choosing == null, "1 gives it Plantar")
	clone.work_speed = 10.0
	farmer.global_position = Vector3(50.0, farmer.global_position.y, 50.0)


## The clone planted empty beds by itself, standing at each, and left the others alone.
func _check_clone_worked() -> void:
	var planted := 0
	for bed: Bed in _main.beds:
		if bed.state == Bed.State.PLANTED:
			planted += 1
	# Bed 1 was planted by the farmer; any other planted bed is the clone's work.
	_check(planted >= 3, "the clone planted beds on its own (%d planted)" % planted)
	var clone: Clone = _main.clones[0] if not _main.clones.is_empty() else null
	_check(clone != null and (not clone.is_working() or clone.work_task == Bed.PLANT),
			"the clone only does its role")

func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	_say(("ok   " if ok else "FAIL ") + what)


func _say(line: String) -> void:
	print(line)
	_log.store_line(line)
	_log.flush()
