extends SceneTree

## Headless check of the DNA economy and the item upgrades it buys. Run:
##   godot --headless --script res://tools/test_dna.gd
##
## Four things are worth testing here, and they are exactly the four that cannot
## be seen by playing:
##   1. upgrading an item never writes into the item on disk;
##   2. every modifier in an upgraded build still has a unique id, so the
##      pipeline's sort stays deterministic;
##   3. pickup order still does not matter once upgrades are in the build;
##   4. the payout lands in the right band for each of the three ways a run ends,
##      measured against REAL generated maps rather than assumed room counts.
##
## Nothing here is typed against RunManager or PrepMenu on purpose: under
## `--script` a class that names the MetaProgress autoload is compiled before the
## autoload exists, so a static reference to one fails to compile.

const MAPS: int = 8
## How much of what drops a player actually walks over. There is no magnet, so
## this varies a lot -- the bands have to hold across the whole spread.
const PICKUP_RATES: Array[float] = [0.5, 0.7, 0.9]

var _failures: int = 0
var _saved_dna: int = 0
var _saved_levels: Dictionary = {}


func _initialize() -> void:
	var meta := root.get_node("MetaProgress")
	# The tests write to the real save file. Put the player's progress back
	# afterwards -- running the suite must not cost anyone their DNA.
	_saved_dna = meta.dna
	_saved_levels = meta.levels.duplicate()

	_test_purity(meta)
	_test_ids(meta)
	_test_order_independence(meta)
	_test_bands(meta)
	_test_save(meta)

	meta.dna = _saved_dna
	meta.levels = _saved_levels
	meta.save_game()
	_finish("OK: upgrades are pure and uniquely identified, order still does not matter, payout bands hold.")


# --- 1. upgrades never touch the item on disk ---

func _test_purity(meta) -> void:
	var before := {}
	for path in _paths():
		before[path] = _fingerprint(load(path) as Item)

	var upgraded := _upgraded_items(meta, 99)
	_check(not upgraded.is_empty(), "no items to upgrade")

	for path in _paths():
		# load() is cached, so this is the very object the pool was built from.
		_check(_fingerprint(load(path) as Item) == before[path],
			"UPGRADE LEAKED into the item on disk: %s" % path)

	# And the bases, the same way test_pipeline does.
	var base_ranged := load("res://config/base_ranged.tres") as AttackStats
	_resolve(upgraded, base_ranged,
		load("res://config/base_melee.tres") as AttackStats,
		load("res://config/base_player.tres") as PlayerStats)
	_check(is_equal_approx(base_ranged.damage, 3.0), "base_ranged was mutated")
	_check(base_ranged.statuses.is_empty(), "base_ranged.statuses was mutated")


func _fingerprint(item: Item) -> String:
	var parts: Array[String] = [item.display_name]
	for m in item.modifiers:
		parts.append("%s|%s|%d|%d|%s" % [m.id, m.stat, m.op, m.phase, m.value])
	return "/".join(parts)


# --- 2. ids stay unique ---

func _test_ids(meta) -> void:
	var seen := {}
	for item in _upgraded_items(meta, 99):
		for m in item.modifiers:
			var key := "%s::%s" % [item.display_name, m.id]
			_check(not seen.has(key), "duplicate modifier id in one item: %s" % key)
			seen[key] = true

	# The authored ids in the table itself, which is what the dock guarantees on
	# save and what a hand-edit could break.
	var table = meta.table()
	if table == null:
		return
	var authored := {}
	for entry in table.entries:
		for n in entry.levels.size():
			for m in entry.level(n + 1).modifiers:
				_check(not authored.has(m.id),
					"config/upgrades.tres has two effects with the id %s" % m.id)
				authored[m.id] = true


# --- 3. order independence survives upgrades ---

func _test_order_independence(meta) -> void:
	var items := _upgraded_items(meta, 99)
	var br := load("res://config/base_ranged.tres") as AttackStats
	var bm := load("res://config/base_melee.tres") as AttackStats
	var bp := load("res://config/base_player.tres") as PlayerStats

	var forward := _resolve(items, br, bm, bp)
	var backwards := items.duplicate()
	backwards.reverse()
	_check(forward == _resolve(backwards, br, bm, bp),
		"ORDER DEPENDENCE once upgrades are in the build")


# --- 4. the three payout bands ---

func _test_bands(meta) -> void:
	var table = meta.table()
	var cost: int = table.cost_per_level if table != null else 375
	for rate in PICKUP_RATES:
		# Rooms cleared as a share of the floor, matching how each ending
		# actually happens: you cannot reach the infection without most of the
		# body, and the rampage does not start until 70% of it is cleared.
		var early := _band(0.45, false, false, rate, cost)
		var boss := _band(0.72, true, false, rate, cost)
		var swept := _band(0.95, true, false, rate, cost)
		var full := _band(0.85, true, true, rate, cost)
		print("pickup %.0f%%: early death %.2f | boss killed %.2f (swept %.2f) | got out %.2f"
			% [rate * 100.0, early, boss, swept, full])
		_check(early >= 1.0, "an early death buys less than one upgrade (%.2f)" % early)
		_check(early < 2.0, "an early death buys two upgrades (%.2f)" % early)
		_check(boss >= 2.0, "killing the infections buys less than two upgrades (%.2f)" % boss)
		# The ceiling that stops the middle band eating the escape band. If this
		# goes red after a payout change, the boss bonuses are too generous --
		# see DnaBalance.BOSS_KILL_BONUS / ALL_BOSSES_BONUS.
		_check(swept < 4.0, "killing the infections buys four upgrades (%.2f)" % swept)
		_check(full >= 4.0, "a finished run buys less than four upgrades (%.2f)" % full)


## Average upgrades bought by one kind of run, over several generated floors.
func _band(share: float, boss: bool, escaped: bool, rate: float, cost: int) -> float:
	var total := 0.0
	for s in MAPS:
		var map := MapData.generate(s + 1, 6)
		var cells: Array = []
		for cell: Vector2i in map.rooms:
			var kind := map.kind_of(cell)
			if kind == MapData.RoomKind.COMBAT or kind == MapData.RoomKind.BOSS:
				cells.append(cell)
		# Shallowest first, because that is the order a body gets taken apart.
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return map.distance_from_start(a) < map.distance_from_start(b))

		var cleared := int(round(cells.size() * share))
		var motes := 0.0
		for i in cleared:
			motes += _enemies_in(map, cells[i])
		motes *= rate
		# One drop per infection, not one per run: a floor now holds two or three
		# of them and each bursts for DnaBalance.BOSS.
		var bosses := map.boss_count() if boss else 0
		if boss:
			motes += DnaBalance.BOSS * rate * float(bosses)
		total += float(DnaPayout.total(int(motes), cleared, bosses, map.boss_count(),
			escaped, cost)) / float(cost)
	return total / float(MAPS)


## The enemy budget of one room, by the same formula Room._plan_waves uses. Kept
## in step by hand, which is worth a comment: if the wave maths changes, this is
## the second place to change, and the bands above are what will notice.
func _enemies_in(map: MapData, cell: Vector2i) -> int:
	var size := map.size_of(cell)
	var area := (size.x * size.y) / (MapData.CHAMBER_SIZE.x * MapData.CHAMBER_SIZE.y)
	return clampi(roundi((3 + map.distance_from_start(cell)) * area), 3, 20)


# --- 5. the save file ---

func _test_save(meta) -> void:
	var path := "res://items/hollow_point.tres"
	meta.reset_progress()
	meta.add_dna(10000)
	_check(meta.buy_upgrade(path), "could not buy an upgrade with 10000 DNA")
	var spent: int = meta.dna
	var level: int = meta.level_of(path)

	meta.dna = 0
	meta.levels = {}
	meta.load_game()
	_check(meta.dna == spent, "DNA did not survive a save/load (%d vs %d)" % [meta.dna, spent])
	_check(meta.level_of(path) == level, "an owned level did not survive a save/load")

	# A save from a future build, or a corrupt one, must be refused rather than
	# half-read.
	var f := FileAccess.open(meta.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 0, "dna": 999999, "levels": {}}))
	f.close()
	meta.dna = 0
	meta.levels = {}
	meta.load_game()
	_check(meta.dna == 0, "an unreadable save version was loaded anyway")


# --- helpers ---

## Every item as a run would see it at `level`, built through RunManager itself
## so the test cannot drift from the code it is checking.
func _upgraded_items(meta, level: int) -> Array[Item]:
	var out: Array[Item] = []
	var runner = load("res://src/run_manager.gd").new()
	var table = meta.table()
	for path in _paths():
		var src := load(path) as Item
		var want: int = mini(level, meta.max_level_of(path))
		out.append(runner._upgraded_copy(src, path, want, table))
	runner.free()
	return out


func _paths() -> PackedStringArray:
	return load("res://src/run_manager.gd").ITEM_PATHS


func _resolve(items: Array[Item], br: AttackStats, bm: AttackStats, bp: PlayerStats) -> String:
	var all: Array[StatModifier] = []
	for it in items:
		all.append_array(it.modifiers)
	var ranged := StatModifier.apply_all(br, _filter(all, StatModifier.Target.RANGED)) as AttackStats
	var melee := StatModifier.apply_all(bm, _filter(all, StatModifier.Target.MELEE)) as AttackStats
	var player := StatModifier.apply_all(bp, _filter(all, StatModifier.Target.PLAYER)) as PlayerStats
	return "%.4f %.4f %d %d %.3f %.4f %s %s | %.4f %.3f %.4f %s | %d %.3f %.4f" % [
		ranged.damage, ranged.attack_rate, ranged.shot_count, ranged.pierce_count,
		ranged.spread_degrees, ranged.scale_mult, ranged.tint, ranged.statuses,
		melee.damage, melee.reach, melee.attack_rate, melee.tint,
		player.max_health, player.move_speed, player.size_scale,
	]


func _filter(all: Array[StatModifier], target: int) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	for m in all:
		if m.applies_to(target):
			out.append(m)
	return out


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: ", message)


func _finish(ok_message: String) -> void:
	if _failures == 0:
		print(ok_message)
		quit()
	else:
		print("%d FAILURE(S)" % _failures)
		quit(1)
