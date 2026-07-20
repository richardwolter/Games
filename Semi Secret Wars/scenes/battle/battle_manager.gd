class_name BattleManager
extends Node
## Owns battle resolution for the incremental loop.
##
## Win: defeat the Dark Mage (you've out-leveled the stage and may advance).
## Lose: all heroes die. Either way the run's farmed XP is already banked in
## GameState (credited live on each kill/capture), so every run contributes.
## On end, shows the post-run upgrade screen where the player allocates XP,
## then R starts the next run with the new build. See GDD §16.

const PREP_MENU := "res://scenes/prep/prep_menu.tscn"
const BATTLEFIELD := "res://scenes/battlefield/battlefield.tscn"
const HERO_PANEL_SCENE := "res://scenes/battle/hero_panel_ui.tscn"

## Fraction of MISSING HP a survivor recovers when clearing a level, applied to
## the HP that carries into the next level (Designer decision 2026-07-18 — the
## chained-run rework left survivors entering each level too depleted to fight,
## since there was no heal). Dead heroes stay dead (permadeath). 0.5 = a
## 36%-HP survivor resumes the next level at ~68%.
const CLEAR_HEAL_MISSING_FRACTION := 0.5

## A hero deployed at least this far from EVERY ally is "going in alone" and
## gets a free boon (it's dangerous to go alone). Solo rosters are excluded —
## they already carry the standing Lone Wolf buff (see Hero), so it never stacks.
const LONE_DEPLOY_DISTANCE := 550.0

## Random party-wide reward granted alongside the farm/XP bonus on objective
## capture (GDD: one of five, picked uniformly). Timed boosts share BOOST_DURATION;
## the shield instead blocks a fixed number of hits regardless of time.
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
@export var villain_path: NodePath
## The "HERO SPAWN" marker node — moved to the player's chosen deploy point.
@export var hero_spawn_marker_path: NodePath
## Stage ID: "stage_1", "stage_2", etc. Read from GameState if not hardcoded.
@export var stage_id: String = "stage_1"

var _spawner: MinionSpawner
var _results: ResultsScreen
var _hud: BattleHUD
var _villain: Combatant
var _field: StageField
var _stage_config: StageConfig
var _focus_ping: FocusPing
var _over := false
## Set on a win that has a further level to play: the R-key then reloads the
## battlefield (which reads the now-incremented RunState.current_level) instead
## of returning to the prep menu.
var _advance_to_next := false
## False during the pre-battle deployment phase (no heroes on the field yet).
var _deployed := false
## The live deploy-phase overlay, if any. Normally frees ITSELF (see
## DeployController._unhandled_input) once the player's final click emits
## deploy_chosen — but a caller that drives _on_deploy_chosen directly instead
## of through real input (balance_sweep.gd, which skips the deploy clicks
## entirely) never fires that input path, leaving it a zombie that keeps
## _process-ing (and holding a `field` reference) into the NEXT level, after
## that field is freed — the source of the sweep's "previously freed"
## script errors. BattleManager owns the free here so both paths are covered;
## freeing an already-freeing node is a harmless no-op in Godot.
var _deploy_controller: DeployController = null
## Heroes waiting for a level-up boon pick (Milestone 1). Processed one at a
## time; a hero can appear more than once if it gained several levels at once.
var _levelup_queue: Array[String] = []
## The boon-pick overlay currently shown (tree paused behind it), or null.
var _levelup_screen: LevelUpScreen = null

func _ready() -> void:
	# Keeps _process (R-key restart) alive once _end() pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Per-battle DISPLAY reset only (run_xp). The RUN itself — levels, boons, HP
	# carryover, the fallen — is started from the prep menu on a fresh run and
	# PRESERVED across chained levels; resetting it here would wipe carryover
	# every level (gameplay-loop rework). Listen for level-ups for the boon pick.
	GameState.start_run()
	RunState.hero_leveled.connect(_on_hero_leveled)
	# The current level selects both its authored layout (StageField) and its
	# stage config (villain/minion/swarm). level N -> stage_N_config.tres.
	stage_id = "stage_%d" % RunState.current_level
	_spawner = get_node(spawner_path)
	_results = get_node(results_screen_path)
	_hud = get_node(hud_path)
	_hud.hero_panel_scene = load(HERO_PANEL_SCENE)

	_field = get_tree().get_first_node_in_group("field")

	## Load and apply stage config.
	_apply_stage_config(stage_id)

	for o in get_tree().get_nodes_in_group("objectives"):
		o.captured.connect(_on_objective_captured)

	## Deployment phase: the party spawns only once the player picks a point.
	_begin_deployment()

## Pre-battle deployment: show the deploy zone and wait for the player's click.
## The spawner holds its swarm (battle_started false) until the point is chosen.
func _begin_deployment() -> void:
	var dc := DeployController.new()
	dc.field = _field
	dc.spawner = _spawner
	# living_party() = drafted party minus heroes who fell earlier this run
	# (permadeath). On level 1 it equals the full draft.
	dc.hero_names = RunState.living_party()
	dc.deploy_chosen.connect(_on_deploy_chosen)
	_deploy_controller = dc
	# Same deferred-add dance as the villain: the battlefield root is still
	# setting up its children while this _ready runs.
	get_parent().add_child.call_deferred(dc)

func _on_deploy_chosen(positions: Array) -> void:
	_deployed = true
	# See _deploy_controller's doc comment: guarantee it's gone the moment
	# deployment resolves, regardless of whether the caller was a real click
	# (which already queues its own free right after this signal fires) or a
	# direct call that skips input entirely.
	if _deploy_controller != null and is_instance_valid(_deploy_controller):
		_deploy_controller.queue_free()
	_deploy_controller = null
	# hero_spawn becomes the centroid of the individually placed heroes: the
	# swarm and villain summons still march on a single shared point
	# (StageField.hero_spawn is read game-wide), while each hero spawns at
	# their own exact spot via a lateral offset from that centroid.
	var centroid := Vector2.ZERO
	for p in positions:
		centroid += p
	centroid /= positions.size()
	_field.set_hero_spawn(centroid)
	if hero_spawn_marker_path != NodePath():
		var marker := get_node_or_null(hero_spawn_marker_path)
		if marker != null:
			marker.position = centroid
	_spawn_party(positions)
	_hud.setup_heroes(RunState.living_party())
	# Villain spawns at its fixed authored lair (StageField.villain_pos, set by
	# apply_layout) — no longer rolled from deploy positions. The lair is a
	# learnable destination for the player who has mapped this level.
	_spawn_villain(_stage_config)
	_spawner.begin_battle()
	# Focus ping: the player's in-battle command verb, live for the whole battle.
	_focus_ping = FocusPing.new()
	get_parent().add_child(_focus_ping)

func _apply_stage_config(stage: String) -> void:
	var config_path := "res://config/%s_config.tres" % stage
	var config = load(config_path)
	if config == null:
		push_error("Failed to load stage config: %s" % config_path)
		return
	_spawner.apply_stage_config(config)
	# Villain spawns later, once deploy positions are known (see
	# _on_deploy_chosen) so his position can be rolled far from the party.
	_stage_config = config

## Instantiate this level's living party, each at its own player-picked spot
## (positions, same order as living_party). Restores accumulated run power
## (boons) and carried HP, then grants the lone-deploy boon to any isolated hero.
func _spawn_party(positions: Array) -> void:
	var root := get_node(heroes_root_path)
	var names := RunState.living_party()
	var spawned: Array = []
	for i in names.size():
		var hero_name: String = names[i]
		var h := hero_scene.instantiate()
		h.hero_name = hero_name
		h.body_color = GameState.HERO_CATALOG[hero_name].color
		h.lateral = positions[i] - _field.hero_spawn
		h.priority = GameState.party_of(hero_name).priority
		h.support_target = GameState.party_of(hero_name).get("support_target", "")
		root.add_child(h)  # _ready -> _configure -> hp = max_hp (flat base)
		# Re-apply boons picked earlier this run. Abilities are intrinsic, so
		# boons are the ONLY accumulated power, and each level spawns a fresh
		# Hero node — without this, a hero would reset to base every level.
		for boon_id in RunState.boons.get(hero_name, []):
			h.apply_run_boon(boon_id)
		# Raw HP carryover: a survivor resumes at the HP it finished the previous
		# level with (clamped into its post-boon max). Fresh heroes stay at full.
		var carried: float = RunState.carried_hp(hero_name)
		if carried >= 0.0:
			h.hp = clampf(carried, 1.0, h.max_hp)
		spawned.append(h)
	_grant_lone_deploy_boons(names, positions, spawned)

## Grants a free boon to any hero deployed far from every ally ("it's dangerous
## to go alone"). Skipped for solo rosters, which already have the Lone Wolf buff.
func _grant_lone_deploy_boons(names: Array, positions: Array, spawned: Array) -> void:
	if names.size() < 2:
		return
	for i in names.size():
		var nearest := INF
		for j in names.size():
			if i != j:
				nearest = minf(nearest, positions[i].distance_to(positions[j]))
		if nearest <= LONE_DEPLOY_DISTANCE:
			continue
		var offer := RunState.roll_offer(names[i])
		if offer.is_empty():
			continue
		var id: String = offer[0]
		RunState.add_boon(names[i], id)
		spawned[i].apply_run_boon(id)
		if spawned[i].has_method("_show_cast_label"):
			spawned[i]._show_cast_label("SOLO BOON!", Color("d9a441"))

func _process(_delta: float) -> void:
	if _over:
		if Input.is_key_pressed(KEY_R):
			get_tree().paused = false
			# A chaining win reloads the battlefield (it reads the incremented
			# RunState.current_level, loading the next level's layout/config);
			# otherwise the run is over and we return to prep.
			get_tree().change_scene_to_file(BATTLEFIELD if _advance_to_next else PREP_MENU)
		return

	# Level-up boon pick (Milestone 1). A pick is showing → tree is paused,
	# skip the rest of the battle tick. Otherwise, if any hero is queued (and
	# the party is on the field), show the next pick. Runs here because this
	# node is PROCESS_MODE_ALWAYS, so it keeps ticking while paused.
	if _levelup_screen != null:
		return
	if _deployed and not _levelup_queue.is_empty():
		_show_next_levelup()
		return

	# Single source of truth for the villain's live position (StageField.villain_pos
	# is shared/read game-wide — heroes, minions, and the spawner). Owning the sync
	# here covers every villain type (Villain, Berserker, future ones) without each
	# subclass having to remember to write it back itself.
	if _villain != null and is_instance_valid(_villain) and not _villain._dying:
		_field.villain_pos = _villain.global_position

	# No wipe check during deployment — the party hasn't spawned yet.
	if not _deployed:
		return
	var heroes := _living_real_heroes()
	if heroes.is_empty():
		_end(false)

## Objective bonus splits evenly among living heroes (banked immediately), plus
## a random party-wide reward (one of five, picked uniformly; see GDD).
func _on_objective_captured(bonus: int) -> void:
	var heroes := _living_real_heroes()
	if heroes.is_empty():
		return
	var share := int(ceil(float(bonus) / heroes.size()))
	for h in heroes:
		# Both XP multipliers apply here, same as kill XP (Hero._on_kill): the
		# timed objective boost (xp_mult) and the run-scoped Fortune boon.
		GameState.add_xp(h.hero_name, int(share * h.xp_mult() * h.run_xp_mult()))
	_apply_random_objective_bonus(heroes)
	# Capturing an objective refunds a focus-ping charge.
	if _focus_ping != null and is_instance_valid(_focus_ping):
		_focus_ping.add_charge()

## Grants one randomly-picked party-wide reward to every living hero.
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

## Party heroes (excludes temporary summons like HeroClone, which share the
## "heroes" group for targeting/capture purposes but aren't real party slots).
func _living_real_heroes() -> Array:
	var out := []
	for h in get_tree().get_nodes_in_group("heroes"):
		if h is Hero:
			out.append(h)
	return out

func _on_villain_died(_who: Combatant) -> void:
	if not _over:
		_end(true)

func _spawn_villain(config: StageConfig) -> void:
	# Remove existing villain node from the scene.
	for v in get_tree().get_nodes_in_group("villains"):
		v.queue_free()

	var villain_scene: PackedScene
	match config.villain_type:
		"berserker":
			villain_scene = load("res://scenes/villain/berserker.tscn")
		"mech_robot":
			villain_scene = load("res://scenes/villain/mech_robot.tscn")
		_:
			villain_scene = load("res://scenes/villain/villain.tscn")

	if villain_scene != null:
		# Instantiate and add to battlefield (sibling of MinionSpawner).
		var v = villain_scene.instantiate()
		_villain = v
		v.died.connect(_on_villain_died)
		# _ready runs while the battlefield root is still setting up its
		# children, so a direct add_child on it fails — defer the add.
		get_tree().get_first_node_in_group("field").get_parent().add_child.call_deferred(v)

## RunState signalled a level-up: queue the hero for a boon pick (shown from
## _process so the pause/overlay lifecycle stays in one place).
func _on_hero_leveled(hero_name: String) -> void:
	_levelup_queue.append(hero_name)

## Pop queued heroes until one is still alive, then pause and show its boon
## pick. Dead heroes are skipped (no pick for a hero that won't benefit).
func _show_next_levelup() -> void:
	while not _levelup_queue.is_empty():
		var hero_name: String = _levelup_queue.pop_front()
		if _find_living_hero(hero_name) == null:
			continue
		var screen := LevelUpScreen.new()
		_levelup_screen = screen
		add_child(screen)
		screen.setup(hero_name, RunState.roll_offer(hero_name))
		screen.picked.connect(_on_boon_picked.bind(hero_name))
		get_tree().paused = true
		return
	# Queue exhausted with no pick shown (every queued hero died before its
	# turn came up). If a previous pick left the tree paused waiting on this
	# one, unpausing here is the only way the battle resumes — without it the
	# game would be frozen forever with no overlay and no recovery input.
	get_tree().paused = false

## The player chose a boon: record it, apply it live to the hero, tear the
## overlay down, and unpause once no more picks are queued (_process shows the
## next one while still paused if the queue isn't empty).
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
	# Persist this level's explored ground so the map stays revealed next run
	# (progress-is-knowledge). Saved on win and loss alike.
	var fog := get_tree().get_first_node_in_group("fog")
	if fog != null and fog.has_method("save_explored"):
		fog.save_explored()

	# A win that has a further authored level: record HP carryover + the fallen,
	# advance the run, and offer to chain straight into the next level (no prep,
	# no payout yet — gold is a run-end reward).
	if win:
		_record_carryover()
		var next_level := RunState.current_level + 1
		if _level_exists(next_level):
			RunState.current_level = next_level
			_advance_to_next = true
			_results.show_results(true, 0, next_level)
			get_tree().paused = true
			return

	# Run over — a loss, or a win with no further level (run complete). Pay out
	# gold scaled by levels cleared (a run-complete win counts the level just won;
	# a loss counts levels beaten before it) and return to prep; the next START
	# resets the run to level 1 (see PrepMenu._on_start / RunState.start_run).
	var levels_cleared := RunState.current_level if win else RunState.current_level - 1
	var gold := GameState.gold_for_run(win, levels_cleared)
	GameState.award_gold(gold)
	_results.show_results(win, gold, 0)
	# Freezes the whole battlefield (heroes, minions, spawner) so nothing keeps
	# fighting/spawning behind the results overlay and banking extra kill XP.
	get_tree().paused = true

## Records, at a level's win, which living-party heroes survived (with their HP)
## and which fell — so the next level spawns survivors at their carried HP and
## skips the dead (permadeath). See RunState.hp_carry / dead.
func _record_carryover() -> void:
	var survivors := {}
	for h in _living_real_heroes():
		if is_instance_valid(h) and not h._dying:
			# On-clear recovery: restore a fraction of missing HP before carry.
			var healed: float = h.hp + (h.max_hp - h.hp) * CLEAR_HEAL_MISSING_FRACTION
			survivors[h.hero_name] = minf(healed, h.max_hp)
	for hero_name in RunState.living_party():
		if survivors.has(hero_name):
			RunState.carry_hp(hero_name, survivors[hero_name])
		else:
			RunState.mark_dead(hero_name)

## Is level `n` fully authored (both its layout and its stage config exist)?
## Guards the chain so an unauthored level ends the run instead of erroring.
func _level_exists(n: int) -> bool:
	return ResourceLoader.exists("res://config/level_%d_layout.tres" % n) \
			and ResourceLoader.exists("res://config/stage_%d_config.tres" % n)
