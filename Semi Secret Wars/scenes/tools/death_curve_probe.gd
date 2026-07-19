extends Node
## Dev-tool: instrumented single-run probe for diagnosing a level's difficulty
## curve. Boots a real level with a given party, deploys, and prints hero
## HP%/level/active-swarm-count/villain HP+alert-state every SAMPLE_INTERVAL
## sim seconds until the party wipes, the villain dies, or the cap runs out.
##
## Built during the 2026-07-18 gameplay-loop-rework balance pass to diagnose
## why Level 1's whole-run sweep showed a 0% clear rate across every party
## comp: this probe's HP-over-time trace showed heroes losing ~40% of their
## HP to ambient swarm chip damage purely from TRAVEL before ever reaching the
## (then far-away) villain lair, then dying mid-fight from the same escalating
## throughput. That reading drove the fix (shorter deploy-to-lair distance +
## eased swarm throughput/escalation, see BALANCE.md). Keep using this before
## reaching for BalanceSweep on any future level/villain — it shows WHERE a
## run dies, not just whether it did. Not shipped; mirrors behavior_probe.tscn.

const BATTLEFIELD := "res://scenes/battlefield/battlefield.tscn"
const TIME_SCALE := 6.0
const SAMPLE_INTERVAL := 4.0
const CAP_SIM_SECONDS := 150.0

@export var party: Array = ["THUNDAAR"]
## Which level to probe (1-based) — must have both an authored LevelLayout and
## StageConfig. Chain state (boons/hp_carry) starts fresh at this level, as if
## it were Level 1, for isolated per-level diagnosis.
@export var level: int = 1

func _ready() -> void:
	await get_tree().process_frame
	await _run()

func _run() -> void:
	RunState.headless = true
	GameState.party.clear()
	GameState.run_xp.clear()
	RunState.start_run()
	RunState.current_level = level
	RunState.party = party.duplicate()

	Engine.time_scale = 1.0
	var bf: Node = load(BATTLEFIELD).instantiate()
	get_tree().root.add_child(bf)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout

	var field := get_tree().get_first_node_in_group("field")
	var bm = field.get_parent().get_node_or_null("BattleManager")
	var living: Array = RunState.living_party()
	var positions: Array = []
	for i in living.size():
		positions.append(field.hero_spawn + Vector2(i * 50.0 - (living.size() - 1) * 25.0, 0.0))
	bm._on_deploy_chosen(positions)
	await get_tree().process_frame

	print("=== level %d, party=%s ===" % [level, party])
	Engine.time_scale = TIME_SCALE
	var elapsed := 0.0
	var next_sample := 0.0
	while elapsed < CAP_SIM_SECONDS and not bm._over:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if elapsed >= next_sample:
			next_sample += SAMPLE_INTERVAL
			_sample(elapsed, bm)
	Engine.time_scale = 1.0

	var outcome := "timeout"
	if bm._over:
		outcome = "loss" if bm._living_real_heroes().is_empty() else "win"
	print("=== outcome: %s at %.1fs ===" % [outcome, elapsed])
	get_tree().quit(0)

func _sample(elapsed: float, bm) -> void:
	var hero_bits: Array = []
	for h in get_tree().get_nodes_in_group("heroes"):
		if h is Hero and is_instance_valid(h):
			var status := "dead" if h._dying else "%.0f%%" % (100.0 * h.hp / h.max_hp)
			hero_bits.append("%s(L%d,%s)" % [h.hero_name, RunState.level_of(h.hero_name), status])
	var alive_heroes: int = bm._living_real_heroes().size()
	var swarm := get_tree().get_nodes_in_group("hostiles").size()
	var villain := get_tree().get_first_node_in_group("villains")
	var v_status := "n/a"
	if villain != null and is_instance_valid(villain):
		v_status = "%.0f%% alerted=%s" % [100.0 * villain.hp / villain.max_hp, villain._alerted]
	print("t=%5.1fs  alive=%d  swarm=%d  villain=%s  %s" % [
		elapsed, alive_heroes, swarm, v_status, " ".join(hero_bits)])
