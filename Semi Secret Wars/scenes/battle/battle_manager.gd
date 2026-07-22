class_name BattleManager
extends Node
## Lane battle resolution: boon/level-up, objectives, gold, HP-carryover and
## level-chaining.
##
##  - One-shot deploy phase (DeployController), constrained to the fixed
##    deploy band. The swarm stays frozen until every hero is placed and
##    START BATTLE is pressed.
##  - No mid-battle respawn (Designer, 2026-07-19: removed) — a hero that
##    dies is down for the rest of the run.
##  - WIN = villain dead AND every destructible spawn point destroyed.
##  - LOSS = every party hero has fallen (permadeath).
##  - No focus ping, no priorities, no lone-deploy boon.

## Carryover heal: a survivor recovers this fraction of missing HP before it
## carries into the next level; dead stay dead.
const CLEAR_HEAL_MISSING_FRACTION := 0.5

const OBJECTIVE_BOOST_DURATION := 10.0
const OBJECTIVE_XP_BOOST_MULT := 1.15
const OBJECTIVE_DAMAGE_BOOST_MULT := 1.10
const OBJECTIVE_SPEED_BOOST_MULT := 1.10
const OBJECTIVE_ATK_SPEED_BOOST_MULT := 1.10
const OBJECTIVE_SHIELD_CHARGES := 5

@export var spawner_path: NodePath
@export var results_screen_path: NodePath
@export var heroes_root_path: NodePath
@export var hero_scene: PackedScene
@export var hud_path: NodePath
@export var stage_id: String = "stage_1"

var _spawner: LaneSpawner
var _results: ResultsScreen
var _hud: BattleHUD
var _villain: Combatant
var _field: LaneField
var _stage_config: StageConfig
var _deploy: DeployController
var _over := false
var _advance_to_next := false
var _villain_dead := false
var _points_cleared := false
## Party heroes who have fallen this level (permadeath — no mid-battle respawn).
var _exhausted: Dictionary = {}
var _levelup_queue: Array[String] = []
var _levelup_screen: LevelUpScreen = null

## Second-deploy-wave state (Duo staggered arrival). -1.0 = no wave pending
## (either it already landed or there was only ever one wave); >= 0.0 counts
## down in _process. BattleHUD reads duo_b_seconds_remaining() to show the
## countdown so the player can watch it and correlate with how the fight
## unfolds — see DeployController's stepper for where the delay is chosen.
var _second_wave_names: Array = []
var _second_wave_positions: Array = []
var _second_wave_remaining := -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("battle_manager")
	GameState.start_run()
	stage_id = "stage_%d" % RunState.current_level
	_spawner = get_node(spawner_path)
	_results = get_node(results_screen_path)
	_hud = get_node(hud_path)
	_hud.hero_panel_scene = load("res://scenes/battle/hero_panel_ui.tscn")
	_field = get_tree().get_first_node_in_group("field") as LaneField

	_apply_stage_config(stage_id)
	for o in get_tree().get_nodes_in_group("objectives"):
		o.captured.connect(_on_objective_captured)

	_spawner.points_cleared.connect(_on_points_cleared)
	if _spawner.points_remaining() == 0:
		_points_cleared = true

	_hud.setup_heroes(RunState.living_party())
	_spawn_villain(_stage_config)
	# Boons only at the start of a level now (Designer, 2026-07-21): every
	# living hero gets exactly one ability-boon pick here, queued through the
	# same LevelUpScreen pause-and-pick flow the old mid-battle XP-level-up
	# draft used. Drained by _process before the deploy phase becomes
	# interactive (the tree pauses while _levelup_screen is showing, so
	# DeployController — added below — can't be clicked until every hero has
	# picked). _on_boon_picked records into RunState.boons even though no Hero
	# node exists yet; _spawn_hero (below, via _on_deploy_chosen) replays every
	# boon a hero owns this run onto the freshly spawned instance.
	_levelup_queue.assign(RunState.living_party())
	# Swarm stays frozen (_spawner.begin_battle() deferred) until every hero is
	# placed and the player presses START BATTLE — see _on_deploy_chosen.

	_deploy = DeployController.new()
	_deploy.field = _field
	var duos := _compute_duos()
	_deploy.duo_a = duos.a
	_deploy.duo_b = duos.b
	_deploy.deploy_chosen.connect(_on_deploy_chosen)
	get_parent().add_child.call_deferred(_deploy)

func _apply_stage_config(stage: String) -> void:
	var config_path := "res://config/%s_config.tres" % stage
	var config = load(config_path)
	if config == null:
		push_error("Failed to load stage config: %s" % config_path)
		return
	_spawner.apply_stage_config(config)
	_stage_config = config

## Splits RunState.living_party() into the two authored Duos
## (GameState.duo_pairings), each filtered to living members only. A hero
## who isn't in either persisted Duo (stale/empty pairing data) falls back
## into Duo A so nobody silently drops from deploy — DeployController itself
## collapses to a single wave whenever one side ends up empty.
func _compute_duos() -> Dictionary:
	var living := RunState.living_party()
	var duo_a_names: Array = GameState.duo_pairings[0] if GameState.duo_pairings.size() > 0 else []
	var duo_b_names: Array = GameState.duo_pairings[1] if GameState.duo_pairings.size() > 1 else []
	var a: Array = []
	var b: Array = []
	for hero_name in living:
		if hero_name in duo_b_names and hero_name not in duo_a_names:
			b.append(hero_name)
		else:
			a.append(hero_name)
	return {"a": a, "b": b}

## First wave spawns immediately and releases the swarm; the second wave (if
## any) is held and counted down in _process, landing `delay` seconds later
## at its own chosen positions — see DeployController.
func _on_deploy_chosen(payload: Dictionary) -> void:
	var first_names: Array = payload.get("first_names", [])
	var first_positions: Array = payload.get("first_positions", [])
	for i in first_names.size():
		_spawn_hero(first_names[i], first_positions[i])

	_second_wave_names = payload.get("second_names", [])
	_second_wave_positions = payload.get("second_positions", [])
	_second_wave_remaining = float(payload.get("delay", 0.0)) if not _second_wave_names.is_empty() else -1.0

	_spawner.begin_battle()

func _spawn_second_wave() -> void:
	for i in _second_wave_names.size():
		_spawn_hero(_second_wave_names[i], _second_wave_positions[i])
	_second_wave_names = []
	_second_wave_positions = []
	_second_wave_remaining = -1.0

## Seconds left until the second Duo lands, or -1.0 if none is pending —
## BattleHUD polls this every frame to show the countdown.
func duo_b_seconds_remaining() -> float:
	return _second_wave_remaining

## True while `hero_name` is queued for the second wave but hasn't landed
## yet — BattleHUD uses this to show "ARRIVES IN Xs" instead of a false KO.
func is_hero_incoming(hero_name: String) -> bool:
	return hero_name in _second_wave_names

func _spawn_hero(hero_name: String, pos: Vector2) -> void:
	var root := get_node(heroes_root_path)
	var h := hero_scene.instantiate()
	h.hero_name = hero_name
	h.body_color = GameState.HERO_CATALOG[hero_name].color
	h.lateral = pos - _field.hero_spawn
	# No priority picker exists — every hero leaves `priority` at Hero's own
	# default (ATTACK_VILLAIN). SUPPORT_ALLIES/ATTACK_MINIONS and the old
	# GameState.party_of()/support_target picker were removed (2026-07-20):
	# hero-to-hero links are Duo-driven only now (see Hero class doc).
	root.add_child(h)
	for boon_id in RunState.boons.get(hero_name, []):
		h.apply_run_boon(boon_id)
	var carried: float = RunState.carried_hp(hero_name)
	if carried >= 0.0:
		h.hp = clampf(carried, 1.0, h.max_hp)
	h.died.connect(_on_hero_died.bind(hero_name))

## A hero fell: no mid-battle respawn (Designer, 2026-07-19) — it's down for
## good this level (and, via _record_carryover -> RunState.mark_dead, for the
## rest of the run). Loss the moment every party hero has fallen.
func _on_hero_died(_who: Combatant, hero_name: String) -> void:
	_on_hero_exhausted(hero_name)

func _on_hero_exhausted(hero_name: String) -> void:
	_exhausted[hero_name] = true
	for name in RunState.living_party():
		if not _exhausted.get(name, false):
			return
	_end(false)

func _on_points_cleared() -> void:
	_points_cleared = true
	_check_win()

func _on_villain_died(_who: Combatant) -> void:
	_villain_dead = true
	_check_win()

func _check_win() -> void:
	if not _over and _villain_dead and _points_cleared:
		_end(true)

func _process(delta: float) -> void:
	if _over:
		if Input.is_key_pressed(KEY_R):
			get_tree().paused = false
			get_tree().change_scene_to_file(GameState.BATTLEFIELD if _advance_to_next else GameState.PREP_MENU)
		return
	if _levelup_screen != null:
		return
	if not _levelup_queue.is_empty():
		_show_next_levelup()
		return
	# >= 0.0, not > 0.0: a Duo configured with a 0s delay starts
	# _second_wave_remaining already at exactly 0.0 (see the assignment above),
	# and the old `> 0.0` guard skipped this whole block forever in that case —
	# the strict-positive check was meant to gate the *decrement*, not the
	# one-time spawn check that must still fire when the delay is zero.
	if _second_wave_remaining >= 0.0:
		_second_wave_remaining = maxf(_second_wave_remaining - delta, 0.0)
		if _second_wave_remaining <= 0.0:
			_spawn_second_wave()
	# Single source of truth for the villain's live position (shared field state).
	if _villain != null and is_instance_valid(_villain) and not _villain._dying:
		_field.villain_pos = _villain.global_position

func _on_objective_captured(bonus: int) -> void:
	var heroes := _living_real_heroes()
	if heroes.is_empty():
		return
	var share := int(ceil(float(bonus) / heroes.size()))
	for h in heroes:
		GameState.add_xp(h.hero_name, int(share * h.xp_mult() * h.run_xp_mult()))
	_apply_random_objective_bonus(heroes)

func _apply_random_objective_bonus(heroes: Array) -> void:
	match randi() % 5:
		0:
			for h in heroes:
				h.apply_xp_boost(OBJECTIVE_BOOST_DURATION, OBJECTIVE_XP_BOOST_MULT)
			_hud.show_objective_buff("XP+", Color("6fcf6f"), OBJECTIVE_BOOST_DURATION)
		1:
			for h in heroes:
				h.apply_damage_boost(OBJECTIVE_BOOST_DURATION, OBJECTIVE_DAMAGE_BOOST_MULT)
			_hud.show_objective_buff("DMG+", Color("c0392b"), OBJECTIVE_BOOST_DURATION)
		2:
			for h in heroes:
				h.apply_speed_boost(OBJECTIVE_BOOST_DURATION, OBJECTIVE_SPEED_BOOST_MULT)
			_hud.show_objective_buff("SPD+", Color("4aa3df"), OBJECTIVE_BOOST_DURATION)
		3:
			for h in heroes:
				h.apply_atk_speed_boost(OBJECTIVE_BOOST_DURATION, OBJECTIVE_ATK_SPEED_BOOST_MULT)
			_hud.show_objective_buff("ATK SPD+", Color("e0b03e"), OBJECTIVE_BOOST_DURATION)
		4:
			for h in heroes:
				h.apply_shield(OBJECTIVE_SHIELD_CHARGES)
			_hud.show_objective_buff("SHIELD x%d" % OBJECTIVE_SHIELD_CHARGES, Color("9bd1e5"), OBJECTIVE_BOOST_DURATION)

func _living_real_heroes() -> Array:
	var out := []
	for h in get_tree().get_nodes_in_group("heroes"):
		if h is Hero:
			out.append(h)
	return out

func _spawn_villain(config: StageConfig) -> void:
	for v in get_tree().get_nodes_in_group("villains"):
		v.queue_free()
	var villain_scene: PackedScene
	match config.villain_type:
		"berserker":
			villain_scene = load("res://scenes/villain/berserker.tscn")
		"mech_robot":
			villain_scene = load("res://scenes/villain/mech_robot.tscn")
		_:
			villain_scene = load("res://scenes/villain/dark_mage.tscn")
	if villain_scene != null:
		var v = villain_scene.instantiate()
		# Set before add_child so Combatant._ready's `hp = max_hp` (which runs
		# once the deferred add_child below lands) sees the scaled value.
		v.max_hp *= config.villain_hp_mult
		_villain = v
		v.died.connect(_on_villain_died)
		get_tree().get_first_node_in_group("field").get_parent().add_child.call_deferred(v)

## Drains _levelup_queue one hero at a time, pausing on each pick. Queue is
## populated once in _ready() from RunState.living_party() (dead heroes are
## already excluded there) — unlike the old mid-battle version, no Hero node
## exists yet at this point (boons are picked before deploy/spawn), so this no
## longer re-checks _find_living_hero; RunState.boons is the source of truth
## and _spawn_hero replays it onto every hero as it's created.
func _show_next_levelup() -> void:
	if _levelup_queue.is_empty():
		get_tree().paused = false
		return
	var hero_name: String = _levelup_queue.pop_front()
	var screen := LevelUpScreen.new()
	_levelup_screen = screen
	add_child(screen)
	screen.setup(hero_name, RunState.roll_offer(hero_name))
	screen.picked.connect(_on_boon_picked.bind(hero_name))
	get_tree().paused = true

func _on_boon_picked(boon_id: String, hero_name: String) -> void:
	RunState.add_boon(hero_name, boon_id)
	var hero := _find_living_hero(hero_name)
	if hero != null:
		hero.apply_run_boon(boon_id)
	if _levelup_screen != null:
		_levelup_screen.queue_free()
		_levelup_screen = null
	if _levelup_queue.is_empty():
		get_tree().paused = false

func _find_living_hero(hero_name: String) -> Hero:
	for h in get_tree().get_nodes_in_group("heroes"):
		if h is Hero and h.hero_name == hero_name and is_instance_valid(h) and not h._dying:
			return h
	return null

func _end(win: bool) -> void:
	_over = true
	# Career stat (achievements): how much of this level's villain HP
	# got chipped away, win or lose. Recorded here (not just on the terminal
	# _end call) so a mid-run level clear's villain damage still counts toward
	# the running best.
	if _villain != null and is_instance_valid(_villain) and _villain.max_hp > 0.0:
		var damage_pct := clampf(1.0 - _villain.hp / _villain.max_hp, 0.0, 1.0)
		GameState.record_career_max("best_villain_damage_pct", damage_pct)
	var fog := get_tree().get_first_node_in_group("fog")
	if fog != null and fog.has_method("save_explored"):
		fog.save_explored()
	var blood := get_tree().get_first_node_in_group("blood")
	if blood != null and blood.has_method("save"):
		blood.save()
	if win:
		_record_carryover()
		var next_level := RunState.current_level + 1
		if _level_exists(next_level):
			RunState.current_level = next_level
			_advance_to_next = true
			_results.show_results(true, 0, next_level)
			get_tree().paused = true
			return
	var levels_cleared := RunState.current_level if win else RunState.current_level - 1
	var gold := GameState.gold_for_run(win, levels_cleared)
	GameState.record_career("runs_played", 1)
	GameState.award_gold(gold)  # single save_game() flush for this run's banked gold/xp + career stats
	_results.show_results(win, gold, 0)
	get_tree().paused = true

## Records survivors' carried HP + marks the fallen. With no mid-battle
## respawn, a party hero is either exhausted (dead, permanently) or still on
## the field alive at clear time — there's no third "between respawns" state.
func _record_carryover() -> void:
	var live_nodes := {}
	for h in _living_real_heroes():
		if is_instance_valid(h) and not h._dying:
			live_nodes[h.hero_name] = h
	for hero_name in RunState.living_party():
		if _exhausted.get(hero_name, false):
			RunState.mark_dead(hero_name)
			continue
		if hero_name in live_nodes:
			var h = live_nodes[hero_name]
			var healed: float = h.hp + (h.max_hp - h.hp) * CLEAR_HEAL_MISSING_FRACTION
			RunState.carry_hp(hero_name, minf(healed, h.max_hp))

func _level_exists(n: int) -> bool:
	var has_stage_config := ResourceLoader.exists("res://config/stage_%d_config.tres" % n)
	return ResourceLoader.exists("res://config/level_%d_layout.tres" % n) and has_stage_config
