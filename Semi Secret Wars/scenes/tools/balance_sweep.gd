extends Node
class_name BalanceSweep
## Automated whole-RUN balance sweep (gameplay-loop rework, 2026-07-18).
##
## The old sweep measured single-battle win/loss at an INJECTED power level
## (boons granted directly to a hero right after spawn, standing in for the
## pre-M1 persistent-stat axis). That model doesn't fit the new loop: there is
## no external power dial anymore — a run starts fresh at Level 1 and power
## emerges from actual play (kills/objectives -> XP -> boons) across a CHAIN of
## authored levels, carrying HP and the fallen forward. What matters now is
## "how far does a run get, and how" — so this sweep plays whole run ATTEMPTS,
## exactly the way BattleManager chains levels for a real player (reload the
## battlefield scene on a chaining win, same as pressing R).
##
## For each party composition (every solo, for the "down to one survivor"
## worst case, + every 3-of-4 trio — PARTY_CAP, what a real player drafts),
## plays TRIALS full attempts headlessly at accelerated time scale. Records,
## per level: outcome (win/loss/timeout), sim seconds, and survivor HP —
## then rolls that up into levels-reached / clear-rate stats per comp.
##
## Dev/CI tool, not part of the shipped game loop. Results are appended to
## `res://BALANCE_SWEEP_RESULTS.json` after every trial (so a partial sweep
## still leaves usable data on disk) and emitted via signals for a caller to
## summarize once the whole sweep finishes.

signal run_complete(entry: Dictionary)
signal sweep_complete(results: Array)

const BATTLEFIELD := "res://scenes/battlefield/battlefield.tscn"
const RESULTS_PATH := "res://BALANCE_SWEEP_RESULTS.json"
## Levels currently authored (config/level_N_layout.tres + stage_N_config.tres).
const MAX_LEVELS := 3
## Trials per party comp — averages out spawn-point/teleport RNG.
const TRIALS := 4
const TIME_SCALE := 10.0
## A level's simulated time budget. Generous: villains are now dormant until
## approached, so travel + swarm time adds to what the old per-battle cap
## covered — and a real player has no such cap at all. 150s comfortably covers
## the longer trio grinds observed in tuning (up to ~90s to resolve).
const LEVEL_CAP_SIM_SECONDS := 150.0

## Every solo (the worst case once a run is down to one survivor) + every
## 3-of-4 trio (RunState.PARTY_CAP — what a real player actually drafts).
const PARTY_COMPS: Array = [
	["THUNDAAR"], ["ARTEMIS"], ["WARDEN"], ["BEACON"],
	["THUNDAAR", "ARTEMIS", "WARDEN"],
	["THUNDAAR", "ARTEMIS", "BEACON"],
	["THUNDAAR", "WARDEN", "BEACON"],
	["ARTEMIS", "WARDEN", "BEACON"],
]

var results: Array = []
var _running := false
## The current level's battlefield instance. Deliberately NOT loaded via
## `get_tree().change_scene_to_file()` — that frees `current_scene`, and since
## this sweep script is typically itself a descendant of `current_scene`, its
## OWN running coroutine gets silently killed the first time it does that
## (Godot cancels a coroutine whose Node is freed, with no error — the freshly
## loaded battlefield keeps simulating forever in the background while this
## script never resumes, which looked like a hang burning CPU with zero
## progress). Instead: instantiate the battlefield as a plain child of
## `get_tree().root` and queue_free() it between levels, exactly the pattern
## validated by the Phase 2/6 rework e2e tests.
var _bf: Node = null

func start() -> void:
	if _running:
		return
	_running = true
	# Headless: the in-run level-up draft must never pause/emit during the
	# sweep, or the paused tree deadlocks this loop; also skips fog disk I/O
	# (irrelevant here — fog is visual-only, never read by AI/combat).
	RunState.headless = true
	results.clear()
	_clear_results_file()
	await _run_all()

func _run_all() -> void:
	for comp in PARTY_COMPS:
		for trial in TRIALS:
			var entry := await _run_full_run(comp, trial)
			results.append(entry)
			_append_result_to_file(entry)
			run_complete.emit(entry)
			print("SWEEP: %s trial %d -> %s (levels_cleared=%d)" % [
				comp, trial, entry.final_outcome, entry.levels_cleared])
	if _bf != null:
		_bf.queue_free()
		_bf = null
	_running = false
	# RunState is a persistent autoload: leaving headless set would silently
	# disable level-up boon picks for any normal play later this session.
	RunState.headless = false
	sweep_complete.emit(results)
	finalize_results_file()

## Plays one full run attempt for `hero_names`: Level 1 through a loss, a
## timeout, or clearing every authored level. Mirrors real play exactly —
## BattleManager itself advances RunState.current_level and RunState.dead/
## hp_carry on each chaining win; this just keeps rebooting the battlefield
## scene the way pressing R would.
func _run_full_run(hero_names: Array, trial: int) -> Dictionary:
	GameState.party.clear()
	GameState.run_xp.clear()
	RunState.start_run()
	RunState.party = hero_names.duplicate()

	var level_results: Array = []
	while true:
		var entry := await _run_one_level()
		level_results.append(entry)
		if entry.outcome != "win" or not entry.advance:
			break
		# BattleManager already incremented RunState.current_level on a
		# chaining win — the next loop iteration boots that level directly.

	# A "win" final entry can only mean the run is fully complete: the loop
	# above only continues past a win when entry.advance is true, so the only
	# way to reach `final.outcome == "win"` is a win with advance == false
	# (no further authored level).
	var final: Dictionary = level_results.back()
	var won_final: bool = final.outcome == "win"
	return {
		"party": hero_names,
		"trial": trial,
		"levels_cleared": level_results.size() if won_final else level_results.size() - 1,
		"run_complete": won_final,
		"final_outcome": final.outcome,
		"levels": level_results,
	}

## Boots RunState.current_level as a fresh battlefield instance (deploy
## immediately, clustered at the level's spawn point) and simulates at
## TIME_SCALE until BattleManager resolves the battle or the level's time
## budget runs out. See _bf's doc comment for why this doesn't use
## change_scene_to_file.
func _run_one_level() -> Dictionary:
	var level := RunState.current_level
	get_tree().paused = false  # BattleManager pauses on _end(); tear down clean
	if _bf != null:
		_bf.queue_free()
		_bf = null
		await get_tree().process_frame
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_bf = load(BATTLEFIELD).instantiate()
	get_tree().root.add_child(_bf)
	# Battlefield's villain/deploy-controller adds are call_deferred (the
	# battlefield root is still assembling children when _ready runs) — a
	# couple frames plus a short real-time settle covers it. On a cold process
	# (the sweep's very first level ever) one-time shader/resource loading can
	# occasionally overrun this budget, so retry the settle a couple times
	# before giving up rather than failing the whole trial on a timing fluke.
	var field: Node = null
	var bm: Node = null
	for attempt in 3:
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		field = get_tree().get_first_node_in_group("field")
		if field == null:
			continue
		bm = field.get_parent().get_node_or_null("BattleManager")
		if bm != null:
			break
	if field == null:
		return {"level": level, "outcome": "error", "reason": "no_field", "advance": false}
	if bm == null:
		return {"level": level, "outcome": "error", "reason": "no_battle_manager", "advance": false}

	# Skip the deployment clicks — deploy the living party clustered at the
	# level's spawn point with a small lateral spread (real deploy always
	# spreads heroes slightly too; a single shared point stacks knockback oddly).
	var living: Array = RunState.living_party()
	var positions: Array = []
	for i in living.size():
		var spread := i * 50.0 - (living.size() - 1) * 25.0
		positions.append(field.hero_spawn + Vector2(spread, 0.0))
	bm._on_deploy_chosen(positions)
	await get_tree().process_frame

	Engine.time_scale = TIME_SCALE
	var elapsed := 0.0
	while elapsed < LEVEL_CAP_SIM_SECONDS and not bm._over:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	Engine.time_scale = 1.0

	# _end(true) only fires from the villain's death signal, _end(false) only
	# from the all-heroes-dead wipe check — so once _over is true, whichever
	# heroes are left standing tells us which one happened without needing to
	# race a signal against node teardown.
	var outcome := "timeout"
	if bm._over:
		outcome = "loss" if bm._living_real_heroes().is_empty() else "win"

	var survivor_hp := {}
	for h in living:
		if RunState.hp_carry.has(h):
			survivor_hp[h] = snappedf(float(RunState.hp_carry[h]), 0.1)

	return {
		"level": level,
		"outcome": outcome,
		"advance": bm._advance_to_next,
		"sim_seconds": snappedf(elapsed, 0.1),
		"party_in": living,
		"survivor_hp": survivor_hp,
		"dead_so_far": RunState.dead.duplicate(),
	}

func _clear_results_file() -> void:
	var f := FileAccess.open(RESULTS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("[\n")

## Appends one JSON object per line (not valid JSON array syntax mid-sweep,
## but trivially parseable) so results survive even if the sweep is
## interrupted partway through — closed into a real array via
## finalize_results_file() once sweep_complete fires.
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
