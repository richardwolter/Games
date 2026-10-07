## Headless smoke check: the farm builds, the farmer walks, and a bed goes through its
## whole cycle (plant, water, grow, harvest) both called directly and by the farmer, who
## steps to a spot beside the bed, is locked there while the work time runs, and cancels
## with E again. Then the machine: it costs produção, makes a clone, and a clone given a
## role works beds on its own. Then each trait's good and bad side, the role ratings, and
## last the crates: carried to each depot, by the farmer and by a Carregar clone, plus
## meals, hunger, naps and trampling.
##
## Run: Godot --headless --path <project> res://tools/test_smoke.tscn --quit-after 3000
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
const HAUL_FRAMES := 240

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
	_check(_main.machine.stock == 5, "the machine starts with 5 (got %d)" % _main.machine.stock)
	_check(_main.trough != null and _main.market != null, "trough and market built")


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
		_check_traits()
	elif _frame == 10 + WALK_FRAMES + GROW_FRAMES + STEP_FRAMES + WORK_FRAMES + CLONE_FRAMES \
			+ CLONE_WORK_FRAMES + 3:
		_check_chat()
		_start_hauling()
	elif _frame == 10 + WALK_FRAMES + GROW_FRAMES + STEP_FRAMES + WORK_FRAMES + CLONE_FRAMES \
			+ CLONE_WORK_FRAMES + 3 + 5:
		_feed_the_hungry()
	elif _frame == 10 + WALK_FRAMES + GROW_FRAMES + STEP_FRAMES + WORK_FRAMES + CLONE_FRAMES \
			+ CLONE_WORK_FRAMES + 3 + HAUL_FRAMES:
		_finish_hauling()
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
	var before := get_tree().get_nodes_in_group("crates").size()
	_check(bed.perform(Bed.HARVEST) == Bed.YIELD, "harvest yields %d" % Bed.YIELD)
	_check(get_tree().get_nodes_in_group("crates").size() == before + Bed.YIELD,
			"harvest drops a crate beside the bed")
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
	machine.stock = Machine.COST - 1
	_check(machine.next_task_for(farmer) == &"",
			"machine won't clone below %d in stock" % Machine.COST)
	machine.stock = Machine.COST
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
	_check(_main.machine.stock == 0, "the clone cost %d of the machine's stock (left %d)" % [
			Machine.COST, _main.machine.stock])
	if _main.clones.is_empty():
		return
	var clone: Clone = _main.clones[0]
	_check(clone.role == &"" and not clone.is_working(), "a new clone has no role and idles")
	_check(clone.traits.size() == 2 and clone.traits[0] != clone.traits[1],
			"a new clone has 2 different traits (%s)" % [clone.traits])
	farmer.global_position = clone.global_position + Vector3(0.5, 0.0, 0.0)
	_check(farmer.nearest_target() == clone, "E by a clone picks the clone")
	farmer.interact()
	_check(farmer.choosing == clone, "E opens the clone's role choice")
	farmer.pick_role(1)
	_check(clone.role == Bed.PLANT and farmer.choosing == null, "1 gives it Plantar")
	clone.work_speed = 10.0
	clone.set_traits([])
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


var _chatty: Clone


## A clone with the given traits, out of the way of the beds, with no role.
func _test_clone(names: Array[StringName], at: Vector3) -> Clone:
	var clone := Clone.new()
	clone.name = "Test" + "_".join(names)
	clone.set_traits(names)
	clone.position = at
	_main.add_child(clone)
	return clone


func _check_traits() -> void:
	for clone: Clone in _main.clones:
		clone.set_role(&"")
	var bed: Bed = _main.beds[2]
	var far := Vector3(-9.0, 1.0, 8.0)

	var quick := _test_clone([&"apressado"], far)
	_check(quick.move_mult() > 1.0 and quick.task_speed(Bed.PLANT) > 1.0,
			"Apressado walks and works faster")
	quick.roll = func() -> float: return 0.0
	bed.state = Bed.State.EMPTY
	quick.work_place = bed
	quick.work_task = Bed.PLANT
	quick._finish_task()
	quick.cancel_work()
	_check(bed.state == Bed.State.EMPTY and quick.pick_bed() != bed,
			"Apressado sometimes skips a bed and leaves it for a while")

	var careful := _test_clone([&"caprichoso"], far)
	_check(careful.task_speed(Bed.PLANT) < 1.0, "Caprichoso works slower")
	bed.state = Bed.State.RIPE
	_check(bed.perform(Bed.HARVEST, careful) == Bed.YIELD + 1, "Caprichoso's harvest yields more")
	var both := _test_clone([&"apressado", &"caprichoso"], far)
	_check(both.stats.skip == 0.0, "Caprichoso never errs, even when Apressado")

	var green := _test_clone([&"dedo_verde"], far)
	bed.state = Bed.State.EMPTY
	bed.perform(Bed.PLANT, green)
	bed.perform(Bed.WATER)
	_check(bed.grow_rate > 1.0, "a bed Dedo Verde planted grows faster")
	_check(green.task_speed(Bed.HARVEST) < 0.5 and green.task_speed(Bed.PLANT) == 1.0,
			"Dedo Verde harvests very slowly, only that")

	var cheery := _test_clone([&"animado"], far + Vector3(4.0, 0.0, 0.0))
	var buddy := _test_clone([], far + Vector3(5.0, 0.0, 0.0))
	var alone := _test_clone([], far)
	_check(buddy.task_speed(Bed.PLANT) > 1.0 and alone.task_speed(Bed.PLANT) == 1.0,
			"Animado speeds up clones near it, not far ones")
	_check(cheery.task_speed(Bed.PLANT) == 1.0, "Animado doesn't speed up itself")
	cheery._chat_wait = 0.0
	_chatty = cheery
	_check_panel()


## The role ratings follow the model in docs/decisoes/2026-10-07-painel-do-clone.md, checked
## against values worked out by hand: 6 beds; walk 3 m at 6 m/s = 0.5 s; 1 s per bed task,
## 0.5 s to pick up or deliver, 8 m to a depot (1.333 s); 8 s to grow; each clone eats 1/60
## per second. Plain bed roles: T = 1.5 s, bed cycle 12.5 s, 6/12.5 = 0.48 crates/s, net
## 0.48 - 1/60. Plain Carregar: 0.5 + 0.5 + 1.333 + 0.5 = 2.833 s a crate, net 1/2.833 - 1/60.
func _check_panel() -> void:
	var food := 1.0 / 60.0
	var bed_net := 0.48 - food
	var carry_net := 1.0 / (0.5 + 0.5 + 8.0 / 6.0 + 0.5) - food
	var cases := [
		# traits, role, hand-computed rating
		[[], Bed.PLANT, 1.0],
		[[], Traits.CARRY, 1.0],
		# T_plant = (0.5/1.5 + 1/1.5) / 0.75 = 1.333; cycle 12.333
		[[&"apressado"], Bed.PLANT, (6.0 / 12.33333 - food) / bed_net],
		# growth 2x: cycle 4.5 + 4 = 8.5 gives 0.706/s, but each stage caps at 1/1.5
		[[&"dedo_verde"], Bed.PLANT, (1.0 / 1.5 - food) / bed_net],
		# T_harvest = 0.5 + 1/0.33 = 3.5303 is the cap
		[[&"dedo_verde"], Bed.HARVEST, (1.0 / 3.530303 - food) / bed_net],
		# T_harvest = 0.5 + 1/0.6 = 2.1667; cycle 13.1667; x2 crates
		[[&"caprichoso"], Bed.HARVEST, (6.0 / 13.16667 * 2.0 - food) / bed_net],
		# pauses 2 s after every 8 s: share 0.2; T_water = 1.5/0.8 = 1.875; cycle 12.875
		[[&"animado"], Bed.WATER, (6.0 / 12.875 - food) / bed_net],
		# naps 4 s after every 15 s: share 4/19; T = 1.5/(15/19) = 1.9; cycle 12.9; eats half
		[[&"preguicoso"], Bed.PLANT, (6.0 / 12.9 - food / 2.0) / bed_net],
		# boosted 20 s in 60: work 1/3 * 1/1.5 + 2/3 * 1 = 0.8889; T = 1.3889; eats double
		[[&"glutao"], Bed.PLANT, (6.0 / (1.388889 + 3.0 + 8.0) - 2.0 * food) / bed_net],
		# carries 2: (2 * (0.5 + 0.5) + 1.333 + 0.5) / 2 = 1.9167 s a crate
		[[&"forte"], Traits.CARRY, (1.0 / 1.916667 - food) / carry_net],
		# loses 1 in 4, eats nothing from the trough
		[[&"beliscador"], Traits.CARRY, (1.0 / 2.833333 * 0.75) / carry_net],
	]
	for c: Array in cases:
		var names: Array[StringName] = []
		names.assign(c[0])
		var got := Traits.role_rating(Traits.combine(names), c[1], 6)
		_check(absf(got - c[2]) < 0.002, "%s in %s rates %.3f (hand: %.3f)" % [
				names, c[1], got, c[2]])
	var rows := Traits.stat_rows(Traits.combine([&"apressado"]), [&"apressado"])
	_check(rows.size() == 3 and rows[0].begins_with("Vel. de movimento")
			and rows[1].begins_with("Vel. de trabalho") and rows[2].begins_with("Chance de falha"),
			"Apressado's sheet: %s" % [rows])
	var mixed := _test_clone([&"caprichoso", &"dedo_verde"], Vector3(-9.0, 1.0, -8.0))
	var mixed_panel: String = _main.clone_panel(mixed, true)
	_say("panel example:\n" + mixed_panel)
	_check(mixed_panel.contains("Rendimento") and mixed_panel.contains("Crescimento")
			and mixed_panel.contains("Carregar"), "Caprichoso + Dedo Verde: sheet and 4 roles")
	var careful := _test_clone([&"caprichoso"], Vector3(-9.0, 1.0, -7.0))
	_check(_main.clone_panel(careful, true).contains("(melhor)"), "Caprichoso: a clear best")
	var plain := _test_clone([], Vector3(-9.0, 1.0, -6.0))
	_check(not _main.clone_panel(plain, true).contains("(melhor)"),
			"no recommendation when the roles are close")


## Animado stops to chat (even with a task going) and shows it.
func _check_chat() -> void:
	_check(_chatty.is_chatting() and _chatty.is_paused(), "Animado stops to chat with a clone near it")
	_check(_chatty._bubble.visible and _chatty._bubble.text.begins_with("conversando"),
			"the chat shows in a bubble")


var _hauler: Clone
var _hungry: Clone
var _napper: Clone
var _market_before := 0


## Crates by hand to each depot; a Carregar clone hauling to the market; a clone going
## hungry at an empty trough; Glutão, Beliscador, Preguiçoso and Forte.
func _start_hauling() -> void:
	var farmer: Farmer = _main.farmer
	farmer.cancel_work()
	farmer.global_position = Vector3(50.0, farmer.global_position.y, 50.0)
	for depot: Depot in [_main.machine, _main.trough, _main.market]:
		var crate := Crate.new()
		_main.add_child(crate)
		_check(crate.next_task_for(farmer) == Crate.PICK_UP, "empty hands can pick up a crate")
		crate.perform(Crate.PICK_UP, farmer)
		_check(farmer.carrying == 1 and crate.is_queued_for_deletion(), "the crate is in hand")
		_check(_main.machine.next_task_for(farmer) == Depot.DELIVER,
				"with a crate in hand the machine takes it instead of cloning")
		var before := depot.stock
		_check(depot.next_task_for(farmer) == Depot.DELIVER, "%s takes deliveries" % depot.label)
		depot.perform(Depot.DELIVER, farmer)
		_check(depot.stock == before + 1 and farmer.carrying == 0,
				"a crate delivered to %s adds 1" % depot.label)

	_market_before = _main.market.stock
	_hauler = _test_clone([], _main.MARKET_AT + Vector3(-2.0, 1.0, 0.0))
	_hauler.set_role(Traits.CARRY, _main.market)
	_hauler.work_speed = 5.0
	for i in 2:
		var crate := Crate.new()
		crate.position = _main.MARKET_AT + Vector3(-3.0 - i, 0.0, -1.5)
		_main.add_child(crate)

	_main.trough.stock = 0
	_hungry = _test_clone([], _main.TROUGH_AT + Vector3(0.0, 1.0, 2.5))
	_hungry._meal_clock = 0.01

	var glutton := _test_clone([&"glutao"], Vector3(9.0, 1.0, 8.0))
	glutton.eat(1)
	_check(is_equal_approx(glutton.task_speed(Bed.PLANT), 1.5), "Glutão works faster after eating")
	glutton._meal_clock = 0.0
	glutton._tick_meals(0.01)
	_check(glutton.meal_size() == 2, "Glutão eats double")

	var nibbler := _test_clone([&"beliscador"], Vector3(9.0, 1.0, 6.0))
	_check(nibbler.keep_of(4) == 3, "Beliscador eats 1 of every 4 crates")
	nibbler._meal_clock = 0.0
	nibbler._tick_meals(0.01)
	_check(not nibbler.wants_meal() and not nibbler.hungry, "Beliscador never uses the trough")

	_napper = _test_clone([&"preguicoso"], Vector3(9.0, 1.0, 4.0))
	_napper._meal_clock = 0.0
	_napper._tick_meals(0.01)
	_check(not _napper.wants_meal(), "Preguiçoso's half meal doesn't send it to the trough yet")
	_napper._nap_wait = 0.0

	var strong := _test_clone([&"forte"], Vector3(9.0, 1.0, 2.0))
	_check(strong.capacity() == 2, "Forte carries 2")
	var bed: Bed = _main.beds[5]
	bed.state = Bed.State.GROWING
	bed.grow_left = Bed.GROW_TIME
	strong.global_position = Vector3(bed.global_position.x, 1.0, bed.global_position.z)
	strong.velocity = Vector3(1.0, 0.0, 0.0)
	strong._after_move()
	strong.velocity = Vector3.ZERO
	strong.global_position = Vector3(9.0, 1.0, 2.0)
	_check(bed.state == Bed.State.TRAMPLED, "Forte tramples the plant it walks over")
	_check(bed.next_task_for(strong) == &"" and bed.next_task_for(farmer) == Bed.FIX,
			"only the farmer can fix a trampled bed")
	bed.perform(Bed.FIX, farmer)
	_check(bed.state == Bed.State.EMPTY, "fixing leaves the bed empty")


## The empty trough left the clone hungry and slow; now fill it and let it retry.
func _feed_the_hungry() -> void:
	_check(_hungry.hungry, "with the trough empty the clone goes hungry")
	_check(is_equal_approx(_hungry.task_speed(Bed.PLANT), Traits.HUNGRY_WORK),
			"a hungry clone works at half speed")
	_check(_napper.is_napping() and _napper.is_paused(), "Preguiçoso naps")
	_main.trough.stock = 5
	_hungry._retry_left = 0.01


func _finish_hauling() -> void:
	_check(_main.market.stock >= _market_before + 2,
			"the Carregar clone hauled the crates to the market (%d -> %d)" % [
			_market_before, _main.market.stock])
	_check(not _hungry.hungry and _main.trough.stock == 4,
			"the clone walked to the trough and ate 1 (trough %d)" % _main.trough.stock)

func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	_say(("ok   " if ok else "FAIL ") + what)


func _say(line: String) -> void:
	print(line)
	_log.store_line(line)
	_log.flush()
