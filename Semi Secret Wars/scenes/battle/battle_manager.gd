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
const HERO_PANEL_SCENE := "res://scenes/battle/hero_panel_ui.tscn"

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
var _over := false
## False during the pre-battle deployment phase (no heroes on the field yet).
var _deployed := false
## Heroes waiting for a level-up boon pick (Milestone 1). Processed one at a
## time; a hero can appear more than once if it gained several levels at once.
var _levelup_queue: Array[String] = []
## The boon-pick overlay currently shown (tree paused behind it), or null.
var _levelup_screen: LevelUpScreen = null

func _ready() -> void:
	# Keeps _process (R-key restart) alive once _end() pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.start_run()
	# Roguelite run state (Milestone 1): reset per-run levels/boons and listen
	# for level-ups so we can pause and offer the 1-of-3 boon pick.
	RunState.start_run()
	RunState.hero_leveled.connect(_on_hero_leveled)
	if GameState.stage_override != "":
		stage_id = GameState.stage_override
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
	dc.hero_names = GameState.selected_heroes()
	dc.deploy_chosen.connect(_on_deploy_chosen)
	# Same deferred-add dance as the villain: the battlefield root is still
	# setting up its children while this _ready runs.
	get_parent().add_child.call_deferred(dc)

func _on_deploy_chosen(positions: Array) -> void:
	_deployed = true
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
	_hud.setup_heroes(GameState.selected_heroes())
	# Roll the villain's spawn now that we know where every hero landed, so
	# he always starts as far from the party as the field allows.
	var hero_positions: Array[Vector2] = []
	for p in positions:
		hero_positions.append(p)
	_field.randomize_villain_pos(hero_positions)
	_spawn_villain(_stage_config)
	_spawner.begin_battle()

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

## Instantiate the party chosen on the prep screen, each at its own
## player-picked deployment spot (positions, same order as selected_heroes).
func _spawn_party(positions: Array) -> void:
	var root := get_node(heroes_root_path)
	var names := GameState.selected_heroes()
	for i in names.size():
		var hero_name: String = names[i]
		var h := hero_scene.instantiate()
		h.hero_name = hero_name
		h.body_color = GameState.HERO_CATALOG[hero_name].color
		h.lateral = positions[i] - _field.hero_spawn
		h.priority = GameState.party_of(hero_name).priority
		root.add_child(h)

func _process(_delta: float) -> void:
	if _over:
		if Input.is_key_pressed(KEY_R):
			get_tree().paused = false
			get_tree().change_scene_to_file(PREP_MENU)
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
		GameState.add_xp(h.hero_name, int(share * h.xp_mult()))
	_apply_random_objective_bonus(heroes)

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
		screen.setup(hero_name, RunState.roll_offer())
		screen.picked.connect(_on_boon_picked.bind(hero_name))
		get_tree().paused = true
		return

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
	var newly_unlocked := win and stage_id == "stage_1" and not GameState.stage_1_won
	if win and stage_id == "stage_1":
		GameState.stage_1_won = true
	GameState.save_game()
	_results.show_results(win, newly_unlocked)
	# Freezes the whole battlefield (heroes, minions, spawner) so nothing keeps
	# fighting/spawning behind the results overlay and banking extra kill XP.
	get_tree().paused = true
