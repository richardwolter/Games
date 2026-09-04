extends SceneTree

## Headless check of the modifier pipeline. Run:
##   godot --headless --script res://tools/test_pipeline.gd
## Asserts the property the whole design rests on: pickup order does not
## change the resolved build.

const ITEM_PATHS: PackedStringArray = [
	"res://items/rusty_needle.tres",
	"res://items/adrenaline_shot.tres",
	"res://items/hollow_point.tres",
	"res://items/split_dose.tres",
	"res://items/scalpel_grind.tres",
	"res://items/shrink_serum.tres",
]


func _initialize() -> void:
	var items: Array[Item] = []
	for p in ITEM_PATHS:
		var it := load(p) as Item
		_check(it != null, "failed to load %s" % p)
		items.append(it)

	var base_ranged := load("res://config/base_ranged.tres") as AttackStats
	var base_melee := load("res://config/base_melee.tres") as AttackStats
	var base_player := load("res://config/base_player.tres") as PlayerStats

	var forward := _resolve(items, base_ranged, base_melee, base_player)
	var reversed_items := items.duplicate()
	reversed_items.reverse()
	var backward := _resolve(reversed_items, base_ranged, base_melee, base_player)

	print("--- forward pickup order ---\n", forward)
	print("--- reverse pickup order ---\n", backward)
	_check(forward == backward, "ORDER DEPENDENCE: same items, different build")

	# Base resources must survive resolution untouched.
	_check(is_equal_approx(base_ranged.damage, 3.0), "base_ranged was mutated")
	_check(base_ranged.statuses.is_empty(), "base_ranged.statuses was mutated")

	# APPEND must be refused outside the whitelist.
	var bad := StatModifier.new()
	bad.stat = &"damage"
	bad.op = StatModifier.Op.APPEND
	bad.id = &"illegal"
	var probe := base_ranged.duplicate_stats()
	bad.apply(probe)
	_check(is_equal_approx(probe.damage, base_ranged.damage), "illegal APPEND changed a stat")

	_finish("OK: pipeline is order-independent, bases intact, APPEND fenced.")


func _resolve(items: Array[Item], br: AttackStats, bm: AttackStats, bp: PlayerStats) -> String:
	var all: Array[StatModifier] = []
	for it in items:
		all.append_array(it.modifiers)

	var ranged := StatModifier.apply_all(br, _filter(all, StatModifier.Target.RANGED)) as AttackStats
	var melee := StatModifier.apply_all(bm, _filter(all, StatModifier.Target.MELEE)) as AttackStats
	var player := StatModifier.apply_all(bp, _filter(all, StatModifier.Target.PLAYER)) as PlayerStats

	return "ranged dmg %.3f rate %.3f shots %d pierce %d spread %.1f scale %.3f tint %s statuses %s\nmelee  dmg %.3f reach %.1f rate %.3f tint %s\nplayer hp %d speed %.2f size %.3f" % [
		ranged.damage, ranged.attack_rate, ranged.shot_count, ranged.pierce_count,
		ranged.spread_degrees, ranged.scale_mult, ranged.tint, ranged.statuses,
		melee.damage, melee.reach, melee.attack_rate, melee.tint,
		player.max_health, player.move_speed, player.size_scale,
	]


func _filter(all: Array[StatModifier], t: StatModifier.Target) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	for m in all:
		if m.applies_to(t):
			out.append(m)
	return out


## assert() prints and keeps going in this context, which would let a red run
## still end on "OK". Count failures and set the exit code instead.
var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


func _finish(summary: String) -> void:
	if _failures > 0:
		printerr("%d FAILURE(S)" % _failures)
		quit(1)
	else:
		print(summary)
		quit()
