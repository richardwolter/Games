## Headless checks for tree test mode (`Lake.tree_mode`): the tree file loads, a tree run
## starts net-only with the file's money, nodes are bought by the tree's rules, the ferries and
## the dog appear when they are bought, the tree screen lays the whole tree out, and the tree
## slot saves and loads — and is refused by an ordinary run.
##
## Run: <godot> --headless --path . res://tools/test_tree.tscn --log-file tools/last_tree_engine.log
## Results in tools/last_tree_test.log, flushed per line. Stepped by _physics_process, like
## test_lake, because the `await` form stalls on this build.
extends Node

const LOG_PATH := "res://tools/last_tree_test.log"
const SAVE_PATH := "user://test_tree.save"
const PLAYTEST_LOG := "user://test_tree_playtest.log"

var _main: Node
var _stage: int = 0
var _frames: int = 0
var _ran: int = 0
var _failed: int = 0
var _kept := {}


func _ready() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_PATH))
	for path in [SAVE_PATH, PLAYTEST_LOG]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	TreeLog.path = PLAYTEST_LOG
	_log("--- test_tree start")
	_main = _make(true)


func _make(tree: bool) -> Node:
	var lake: Node = load("res://scenes/main.tscn").instantiate()
	lake.set(&"save_path", SAVE_PATH)
	lake.set(&"autoload_save", true)
	lake.set(&"tree_mode", tree)
	add_child(lake)
	return lake


func _physics_process(_delta: float) -> void:
	_frames += 1
	match _stage:
		0:
			if _frames >= 3:
				_stage_fresh_run()
		1:
			if _frames >= 3:
				_main = _make(true)
				_next()
		2:
			if _frames >= 3:
				_stage_reloaded()
		3:
			if _frames >= 3:
				_main = _make(false)
				_next()
		4:
			if _frames >= 3:
				_stage_other_mode()
		_:
			pass


func _next() -> void:
	_stage += 1
	_frames = 0


func _stage_fresh_run() -> void:
	var tree: UpgradeTree = _main.get(&"_tree")
	_check(tree != null and tree.error.is_empty(), "the tree file loads", "" if tree == null else tree.error)
	if tree == null:
		_finish()
		return
	_check(bool(_main.get(&"tree_mode")), "the run is in tree mode", "")
	_check(tree.nodes.size() > 10, "the tree has its nodes", "%d nodes" % tree.nodes.size())
	_check(is_equal_approx(float(_main.get(&"sludge")), tree.start_money), "a tree run starts with the file's money",
		"%.0f of %.0f" % [float(_main.get(&"sludge")), tree.start_money])

	var boats: Array = _main.get(&"_boats")
	var dog: Dog = _main.get(&"_dog")
	_check(not (boats[0] as Boat).visible and not (boats[0] as Boat).is_processing(),
		"there is no ferry before one is bought", "")
	_check(not dog.visible and not dog.is_processing(), "there is no dog before it is adopted", "")
	_check(int(_main.call(&"skim_radius")) < 0, "no skimmer is fitted", "")
	_check(int(_main.call(&"_affordable")) == 1, "only the first ferry can be bought at the start",
		"%d affordable" % int(_main.call(&"_affordable")))

	var owned: Dictionary = _main.get(&"_tree_owned")
	_main.call(&"buy_node", "line_1")
	_check(not owned.has("line_1"), "a node whose parent is not owned cannot be bought", "")
	_main.call(&"buy_node", "ferry_1")
	_check(owned.has("ferry_1"), "the first ferry is bought", "")
	_check(is_zero_approx(float(_main.get(&"sludge"))), "and costs the starting money exactly", "%.1f left" % float(_main.get(&"sludge")))
	_check((boats[0] as Boat).visible and (boats[0] as Boat).is_processing(), "the ferry appears once bought", "")
	_check(int(_main.call(&"fleet_size")) == 1, "one ferry in the fleet", "")
	_main.call(&"buy_node", "line_1")
	_check(not owned.has("line_1"), "a node that cannot be paid for is not bought", "")

	_main.set(&"sludge", 1000000.0)
	var range_was := float(_main.call(&"net_range"))
	var reel_was := float(_main.call(&"reel_speed"))
	_main.call(&"buy_node", "line_1")
	var net: CastNet = _main.get(&"_net")
	_check(is_equal_approx(float(_main.call(&"net_range")), range_was + 2.2) and is_equal_approx(net.range_tiles, range_was + 2.2),
		"Longer Line I reaches the net", "range %.2f -> %.2f, net %.2f" % [range_was, float(_main.call(&"net_range")), net.range_tiles])
	_check(is_equal_approx(float(_main.call(&"reel_speed")), reel_was + 1.0), "and speeds the reel", "")

	_main.call(&"buy_node", "bag_3")
	_check(not owned.has("bag_3"), "Bigger Bag III waits for Bigger Bag II and the Second Ferry", "")
	for id in ["bag_1", "bag_2", "dog"]:
		_main.call(&"buy_node", id)
	_check(dog.visible and dog.is_processing(), "the dog appears once adopted", "")
	_check(is_equal_approx(dog.reach, Dog.REACH) and is_zero_approx(dog.strand_first), "an untrained dog is today's dog", "")
	for id in ["hull_1", "ferry_2"]:
		_main.call(&"buy_node", id)
	boats = _main.get(&"_boats")
	_check(boats.size() == 2 and (boats[1] as Boat).visible, "the Second Ferry is a second hull in the water", "%d hulls" % boats.size())
	_main.call(&"buy_node", "bag_3")
	_check(owned.has("bag_3"), "and with both owned, Bigger Bag III can be bought", "")
	for id in ["fetch_1", "fetch_2", "beachcomber", "nose", "leash"]:
		_main.call(&"buy_node", id)
	_check(dog.strand_first > 0.5 and is_equal_approx(dog.strand_speed, 1.6), "Beachcomber sends the dog to the strand, quicker",
		"first %.2f, speed %.2f" % [dog.strand_first, dog.strand_speed])
	_check(dog.reach > Dog.REACH * 1.5, "Long Leash lets the dog range further", "%.1f tiles" % dog.reach)

	_main.call(&"_set_menu", true)
	var screen: TreeScreen = _main.get(&"_tree_screen")
	var skin: Control = _main.get(&"_shop_skin")
	_check(screen != null and screen.visible and not skin.visible, "the upgrades button opens the tree, not the shop", "")
	_check(screen.positions().size() == tree.nodes.size(), "the tree screen lays out every node",
		"%d of %d" % [screen.positions().size(), tree.nodes.size()])
	var spread := true
	var at: Dictionary = screen.positions()
	for a: String in at:
		for b: String in at:
			if a < b and (at[a] as Vector2).distance_to(at[b]) < 40.0:
				spread = false
	_check(spread, "no two nodes sit on top of each other", "")
	_main.call(&"_set_menu", false)
	_check(not screen.visible, "and closes", "")

	_kept["owned"] = owned.duplicate()
	_kept["sludge"] = float(_main.get(&"sludge"))
	_main.set(&"_tree_play", 123.0)
	_check(bool(_main.call(&"save_game")), "the tree run saves", "")
	_check(FileAccess.file_exists(SAVE_PATH), "to its own slot", SAVE_PATH)
	_main.queue_free()
	_main = null
	_next()


func _stage_reloaded() -> void:
	var owned: Dictionary = _main.get(&"_tree_owned")
	var kept: Dictionary = _kept["owned"]
	_check(owned.size() == kept.size() and owned.has("beachcomber"), "the owned nodes come back", "%d of %d" % [owned.size(), kept.size()])
	_check(is_equal_approx(float(_main.get(&"sludge")), float(_kept["sludge"])), "so does the purse", "")
	var boats: Array = _main.get(&"_boats")
	_check(boats.size() == 2 and (boats[0] as Boat).visible and (boats[1] as Boat).visible, "both ferries are rebuilt", "%d hulls" % boats.size())
	var dog: Dog = _main.get(&"_dog")
	_check(dog.visible and dog.strand_first > 0.5, "the trained dog is back", "")
	var clock := float(_main.get(&"_tree_play"))
	_check(clock >= 123.0 and clock < 124.0, "the run's play clock carries on from the save", "%.2f" % clock)
	var text := FileAccess.get_file_as_string(PLAYTEST_LOG)
	_check(text.contains("\"kind\":\"purchase\"") and text.contains("\"kind\":\"session\""), "the playtest log records purchases and sessions", PLAYTEST_LOG)
	_main.queue_free()
	_main = null
	_next()


func _stage_other_mode() -> void:
	_check(not bool(_main.get(&"tree_mode")), "an ordinary run is not in tree mode", "")
	_check(not bool(_main.call(&"load_game")), "and refuses a tree run's save", "")
	var boats: Array = _main.get(&"_boats")
	_check((boats[0] as Boat).visible, "an ordinary run still starts with its ferry", "")
	_main.queue_free()
	_main = null
	_finish()


func _finish() -> void:
	for path in [SAVE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_log("--- test_tree done: %d checks, %d failed" % [_ran, _failed])
	_stage = 99
	get_tree().quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String, detail: String) -> void:
	_ran += 1
	if not ok:
		_failed += 1
	_log("%s %s%s" % ["ok  " if ok else "FAIL", what, "" if detail.is_empty() else "  (%s)" % detail])


func _log(line: String) -> void:
	printerr(line)
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.flush()
	f.close()
