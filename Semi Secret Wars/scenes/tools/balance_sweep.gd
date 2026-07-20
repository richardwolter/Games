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
## worst case, + every 3-of-4 trio — PARTY_COMPS below; the 3-of-4 cap was
## removed from the live game 2026-07-19, so these trios are now a coverage
## subset rather than "what a real player drafts," which is the full 4),
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
## Overridable so a runner comparing multiple mod loadouts can keep each
## pass's raw data instead of the later pass clobbering the earlier one.
var results_path := "res://BALANCE_SWEEP_RESULTS.json"
## Levels currently authored (config/level_N_layout.tres + stage_N_config.tres).
const MAX_LEVELS := 3
## Trials per party comp — averages out spawn-point/teleport RNG. Bumped 4->8
## (2026-07-18 MVP pass): trio clear rates read an unreliable 0-50% at 4 trials;
## 8 halves that sampling noise so the ~90/60/40 per-level target is legible.
const TRIALS := 8
const TIME_SCALE := 10.0
## A level's simulated time budget. Generous: villains are now dormant until
## approached, so travel + swarm time adds to what the old per-battle cap
## covered — and a real player has no such cap at all. 150s comfortably covers
## the longer trio grinds observed in tuning (up to ~90s to resolve).
const LEVEL_CAP_SIM_SECONDS := 150.0

## Every 3-of-4 trio — left over from when RunState.PARTY_CAP capped a real
## draft at 3 heroes; the cap was removed 2026-07-19 (players now field every
## unlocked hero), so this is a partial-roster coverage set, not the default
## comp. A full 4-hero comp is not yet in this list — flag for a follow-up
## sweep pass if trio-vs-full-roster balance needs checking.
## Solo comps were DROPPED for the 2026-07-18 MVP pass (Designer call): the
## Lone Wolf standing buff makes solo Thundaar stronger than a trio Thundaar
## (216 vs 120 HP), which inverts the party fantasy — so we tune and feel the
## game as obligatory trios FIRST, then decide whether Lone Wolf/solo stays.
## Lone Wolf code is untouched, just untested here. Re-add solos only once that
## decision is made; do not silently restore them for "completeness".
const PARTY_COMPS: Array = [
	["THUNDAAR", "ARTEMIS", "WARDEN"],
	["THUNDAAR", "ARTEMIS", "BEACON"],
	["THUNDAAR", "WARDEN", "BEACON"],
	["ARTEMIS", "WARDEN", "BEACON"],
]

## Permanent gold-bought ability mods (GameState.owned_mods) to force for every
## trial in this sweep instance. Deliberately explicit rather than reading
## whatever's in user://save.json — GameState loads that save on _ready(), so
## an un-set sweep silently rides on the sweep-runner's OWN dev save state
## (empty on a clean profile, but not guaranteed, and not what a "does the mod
## shop matter" comparison needs). Empty = the zero-mod floor a fresh player
## starts at.
var mod_loadout: Array = []

## hero_name -> priority string (GameState.PRIORITIES keys) to force for every
## trial in this sweep instance. Empty (default) = GameState.party_of()'s
## fallback (DEFAULT_PRIORITY: BEACON=SUPPORT_ALLIES, everyone else=ATTACK_VILLAIN),
## exactly what a fresh player who never visits the priority picker gets.
## Priority variation was previously never swept (BALANCE.md 2026-07-19 flag) —
## this lets a runner pass compare priority profiles the same way mod_loadout
## compares gold spend.
var priority_overrides: Dictionary = {}

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
	GameState.owned_mods = mod_loadout.duplicate()
	for hero_name in priority_overrides:
		if hero_name in hero_names:
			GameState.party_of(hero_name).priority = priority_overrides[hero_name]
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

	# Entry HP: what each hero actually spawned at THIS level (carried HP + the
	# on-clear heal already applied into hero.hp by _spawn_party). Level 1 = full.
	# This is the number that exposed the L2 "depleted entry" failure — a level
	# can be untunable simply because survivors arrive too low, independent of
	# its own swarm/villain numbers.
	var entry_hp := {}
	for h in bm._living_real_heroes():
		entry_hp[h.hero_name] = snappedf(float(h.hp), 0.1)

	# NOTE: focus-ping usage is deliberately NOT recorded — the sweep is headless
	# with no player input, so no ping is ever placed (charges stay full). It's a
	# real-play-only lever; measuring it here would always read zero and mislead.

	Engine.time_scale = TIME_SCALE
	var elapsed := 0.0
	# time_to_villain_alert isolates travel/approach time from actual villain
	# combat — the single diagnostic that pinned the L1/L2 "die in transit before
	# reaching the lair" structural failure. -1 = never woke within the cap.
	var alert_at := -1.0
	# Peak simultaneous minions: how hard the swarm actually got, vs. the config
	# ceiling (a fight that ends early may never approach swarm_max_cap).
	var peak_minions := 0
	while elapsed < LEVEL_CAP_SIM_SECONDS and not bm._over:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if alert_at < 0.0 and bm._villain != null and is_instance_valid(bm._villain) \
				and bm._villain.is_alerted():
			alert_at = snappedf(elapsed, 0.1)
		if bm._spawner != null and is_instance_valid(bm._spawner):
			peak_minions = maxi(peak_minions, bm._spawner._active)
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

	# End-of-level progression per living hero: in-run level reached and boons
	# picked. Reveals whether a losing comp was under-leveled (too little XP) or
	# simply out-fought at a fine level — different fixes (swarm/XP vs. difficulty).
	var hero_levels := {}
	var hero_boons := {}
	for h in living:
		hero_levels[h] = RunState.level_of(h)
		hero_boons[h] = RunState.boons.get(h, []).duplicate()

	var objectives_captured := 0
	for o in get_tree().get_nodes_in_group("objectives"):
		if o.get("is_captured"):
			objectives_captured += 1

	var kills := 0
	if bm._spawner != null and is_instance_valid(bm._spawner):
		kills = bm._spawner.kills

	return {
		"level": level,
		"outcome": outcome,
		"advance": bm._advance_to_next,
		"sim_seconds": snappedf(elapsed, 0.1),
		"party_in": living,
		"entry_hp": entry_hp,
		"survivor_hp": survivor_hp,
		"dead_so_far": RunState.dead.duplicate(),
		"time_to_villain_alert": alert_at,
		"peak_minions": peak_minions,
		"kills": kills,
		"objectives_captured": objectives_captured,
		"hero_levels": hero_levels,
		"hero_boons": hero_boons,
	}

func _clear_results_file() -> void:
	var f := FileAccess.open(results_path, FileAccess.WRITE)
	if f != null:
		f.store_string("[\n")

## Appends one JSON object per line (not valid JSON array syntax mid-sweep,
## but trivially parseable) so results survive even if the sweep is
## interrupted partway through — closed into a real array via
## finalize_results_file() once sweep_complete fires.
func _append_result_to_file(entry: Dictionary) -> void:
	var f := FileAccess.open(results_path, FileAccess.READ_WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_string(JSON.stringify(entry) + ",\n")

func finalize_results_file() -> void:
	var f := FileAccess.open(results_path, FileAccess.READ_WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_string("null\n]\n")
