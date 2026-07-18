extends Node
class_name BalanceSweep
## Automated verification sweep: solo/duo heroes at LV 0-30 across every
## stage, run to win/loss/timeout at accelerated time scale.
##
## Dev/CI tool, not part of the shipped game loop. Drives the real
## BattleManager/battlefield scene the same way a player would (deploy,
## fight, resolve), just headless and fast. Results are appended to
## `res://BALANCE_SWEEP_RESULTS.json` after every run (so a partial sweep
## still leaves usable data on disk) and emitted via signals for a caller
## to summarize once the whole sweep finishes.

signal run_complete(entry: Dictionary)
signal sweep_complete(results: Array)

const BATTLEFIELD := "res://scenes/battlefield/battlefield.tscn"
const RESULTS_PATH := "res://BALANCE_SWEEP_RESULTS.json"
const STAGES := ["stage_1", "stage_2", "stage_3"]
const MODES := ["solo", "duo"]
const MAX_LEVEL := 30
const TIME_SCALE := 8.0
## Run stops (recorded as "timeout") if neither side has won by this many
## simulated seconds — matches the designer-approved per-run cap.
const RUN_CAP_SIM_SECONDS := 60.0

var results: Array = []
var _running := false

func start() -> void:
	if _running:
		return
	_running = true
	# Headless: the in-run level-up draft (Milestone 1) must never pause/emit
	# during the sweep, or the paused tree deadlocks this loop and boons would
	# skew results away from the pre-M1 balance baseline.
	RunState.headless = true
	results.clear()
	_clear_results_file()
	_run_all()

func _run_all() -> void:
	for stage_id in STAGES:
		for mode in MODES:
			for level in range(0, MAX_LEVEL + 1):
				var entry := await _run_one(stage_id, mode, level)
				results.append(entry)
				_append_result_to_file(entry)
				run_complete.emit(entry)
	_running = false
	sweep_complete.emit(results)

## Splits `level` upgrades evenly across the 4 stats (remainder to the
## earlier stats), same methodology as the manually-verified BALANCE.md
## gates (e.g. "LV 20 (5/5/5/5 split)").
func _distribute_level(hero_name: String, level: int) -> void:
	var stats := ["max_hp", "damage", "attack_speed", "move_speed"]
	var per := level / 4
	var rem := level % 4
	var upgrades := {}
	for i in stats.size():
		upgrades[stats[i]] = per + (1 if i < rem else 0)
	# Grant ability tree nodes at the same point milestones the old automatic
	# LV gates used, so sweep results stay comparable across the tree change.
	var abilities := []
	for id in GameState.ABILITY_NODES:
		if level >= int(GameState.ABILITY_NODES[id].requires_points):
			abilities.append(id)
	GameState.heroes[hero_name] = {"xp": 0, "upgrades": upgrades, "abilities": abilities}

func _run_one(stage_id: String, mode: String, level: int) -> Dictionary:
	GameState.heroes.clear()
	GameState.party.clear()
	GameState.run_xp.clear()
	# Stage select/unlock gating is a prep-menu concern only; the sweep drives
	# BattleManager directly via stage_override, bypassing unlock state.
	GameState.stage_override = stage_id

	var heroes_in_run: Array = ["THUNDAAR"] if mode == "solo" else ["THUNDAAR", "ARTEMIS"]
	for h in ["THUNDAAR", "ARTEMIS"]:
		GameState.set_selected(h, h in heroes_in_run)
	for h in heroes_in_run:
		_distribute_level(h, level)

	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(BATTLEFIELD)
	# Battlefield's villain/deploy-controller adds are call_deferred (same
	# reason as their own comments: root is still assembling children when
	# _ready runs) — a couple frames plus a short real-time settle covers it.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout

	var field := get_tree().get_first_node_in_group("field")
	if field == null:
		return {"stage": stage_id, "mode": mode, "level": level, "outcome": "error", "reason": "no_field"}
	var bm := field.get_parent().get_node_or_null("BattleManager")
	if bm == null:
		return {"stage": stage_id, "mode": mode, "level": level, "outcome": "error", "reason": "no_battle_manager"}
	# Skip the deployment clicks — deploy every hero immediately at the
	# default hero spawn (clustered, matching the old single-click behavior).
	var positions: Array = []
	for i in GameState.selected_heroes().size():
		positions.append(field.hero_spawn)
	bm._on_deploy_chosen(positions)

	Engine.time_scale = TIME_SCALE
	var elapsed_sim := 0.0
	var outcome := "timeout"
	while elapsed_sim < RUN_CAP_SIM_SECONDS:
		await get_tree().process_frame
		elapsed_sim += get_process_delta_time()
		var villain := get_tree().get_first_node_in_group("villains")
		if villain == null or not is_instance_valid(villain):
			outcome = "win"
			break
		var alive_heroes := 0
		for hh in get_tree().get_nodes_in_group("heroes"):
			if hh is Hero and is_instance_valid(hh) and not hh._dying:
				alive_heroes += 1
		if alive_heroes == 0:
			outcome = "loss"
			break

	var hero_hp := {}
	for hh in get_tree().get_nodes_in_group("heroes"):
		if hh is Hero:
			hero_hp[hh.hero_name] = {"hp": hh.hp, "max_hp": hh.max_hp}
	var villain_hp := -1.0
	var villain_max_hp := -1.0
	var villain := get_tree().get_first_node_in_group("villains")
	if villain != null and is_instance_valid(villain):
		villain_hp = villain.hp
		villain_max_hp = villain.max_hp

	Engine.time_scale = 1.0
	return {
		"stage": stage_id,
		"mode": mode,
		"level": level,
		"outcome": outcome,
		"sim_seconds": snappedf(elapsed_sim, 0.1),
		"hero_hp": hero_hp,
		"villain_hp": snappedf(villain_hp, 0.1),
		"villain_max_hp": villain_max_hp,
	}

func _clear_results_file() -> void:
	var f := FileAccess.open(RESULTS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("[\n")

## Appends one JSON object per line (not valid JSON array syntax mid-sweep,
## but trivially parseable) so results survive even if the sweep is
## interrupted partway through — closed into a real array in _run_all's
## caller once sweep_complete fires, via finalize_results_file().
func _append_result_to_file(entry: Dictionary) -> void:
	var f := FileAccess.open(RESULTS_PATH, FileAccess.READ_WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_string(JSON.stringify(entry) + ",\n")

func finalize_results_file() -> void:
	var f := FileAccess.open(RESULTS_PATH, FileAccess.READ_WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_string("null\n]\n")
