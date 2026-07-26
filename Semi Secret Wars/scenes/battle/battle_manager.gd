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
##  - Duo Ultimates (2026-07-22): activate_ultimate(pair_id), called from the
##    Duo Ultimate bar's button (BattleHUD), manually casts that Duo's
##    exclusive Ultimate once per level — see DuoUltimates/
##    Hero.cast_duo_ultimate. Replaces the old solo LV20 second abilities.

## Carryover heal: a survivor recovers this fraction of missing HP before it
## carries into the next level; dead stay dead.
const CLEAR_HEAL_MISSING_FRACTION := 0.5

const OBJECTIVE_BOOST_DURATION := 10.0
const OBJECTIVE_XP_BOOST_MULT := 1.15
const OBJECTIVE_DAMAGE_BOOST_MULT := 1.10
const OBJECTIVE_SPEED_BOOST_MULT := 1.10
const OBJECTIVE_ATK_SPEED_BOOST_MULT := 1.10
const OBJECTIVE_SHIELD_CHARGES := 5

## Plays when a hero teleports onto the field (Designer, 2026-07-25: moved
## off the deploy-click in favor of the actual arrival, so the sound lines
## up with the teleport FX instead of firing at placement time).
const DEPLOY_SOUND := preload("res://assets/Sounds/Deploy.wav")

## End-of-level stingers (Designer, 2026-07-26). Played from _end(), which is
## the single point BOTH outcomes pass through — including the mid-run level
## clear that rolls straight into the next stage, so clearing level 1 on the
## way to level 2 still gets its win sound.
##
## Full volume, unlike the in-fight callouts: _end() stops the battle music
## first, so there is nothing left for these to compete with.
const LEVEL_WIN_SOUND: AudioStream = preload("res://assets/Sounds/Level_Win.mp3")
const LEVEL_DEFEAT_SOUND: AudioStream = preload("res://assets/Sounds/Level_Defeat.wav")

@export var spawner_path: NodePath
@export var results_screen_path: NodePath
@export var heroes_root_path: NodePath
@export var hero_scene: PackedScene
@export var hud_path: NodePath
@export var music_path: NodePath
@export var stage_id: String = "stage_1"

var _spawner: LaneSpawner
var _results: ResultsScreen
var _hud: BattleHUD
var _music: AudioStreamPlayer
var _villain: Combatant
var _field: LaneField
var _stage_config: StageConfig
var _deploy: DeployController
var _over := false
## The win/defeat stinger, held so leaving the results screen can cut it off
## (Designer, 2026-07-26) — see _end and _stop_end_stinger.
var _end_stinger: AudioStreamPlayer = null
var _advance_to_next := false
var _villain_dead := false
var _points_cleared := false
## Party heroes who have fallen this level (permadeath — no mid-battle respawn).
var _exhausted: Dictionary = {}
## Start-of-level pick queue (2026-07-22, generalized from the old hero-only
## _levelup_queue): one entry per pending pick, {"kind": "hero"|"duo",
## "key": <hero_name or DuoUltimates pair id>} — see _ready (populates it),
## _show_next_pick (drains it one at a time, pausing on each), _process
## (drives the drain).
var _pick_queue: Array[Dictionary] = []
var _pick_screen: LevelUpScreen = null
## Duos already offered their pick this level — the two spawn waves each queue
## for whoever landed, and this stops a Duo split across both waves (or a
## re-entrant call) from being asked twice.
var _picked_this_level: Array[String] = []
## Duo Ultimates activated this level (pair id -> true). Resets naturally
## every level since BattleManager itself is a fresh instance each scene
## load — see activate_ultimate/can_activate_ultimate.
var _ultimate_used: Dictionary = {}

## Second-deploy-wave state (Duo staggered arrival). -1.0 = no wave pending
## (either it already landed or there was only ever one wave); >= 0.0 counts
## down in _process. BattleHUD reads duo_b_seconds_remaining() to show the
## countdown so the player can watch it and correlate with how the fight
## unfolds — see DeployController's stepper for where the delay is chosen.
var _second_wave_names: Array = []
var _second_wave_positions: Array = []
var _second_wave_remaining := -1.0

## A wave that has been placed and is waiting on its boon pick before it
## actually spawns — see _on_deploy_chosen / _flush_pending_deploy.
var _pending_names: Array = []
var _pending_positions: Array = []
## Set the first time a wave lands; gates the one-shot battle start (swarm
## release, boulders) so a delayed second wave doesn't re-trigger it.
var _battle_started := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("battle_manager")
	GameState.start_run()
	stage_id = "stage_%d" % RunState.current_level
	_spawner = get_node(spawner_path)
	_results = get_node(results_screen_path)
	_hud = get_node(hud_path)
	_hud.hero_panel_scene = load("res://scenes/battle/hero_panel_ui.tscn")
	_music = get_node(music_path)
	# Pick screens (below) and the results screen both pause the tree; an
	# AudioStreamPlayer's default PAUSABLE process_mode would mute it the
	# instant that happens, so it needs to stay unaffected by pause.
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	# Onto the Music bus so the Music slider trims it independently of combat
	# SFX. Set here rather than in battlefield.tscn's inspector: the bus is
	# created at runtime by AudioSettings, so the editor doesn't know its name.
	_music.bus = AudioSettings.BUS_MUSIC
	# Deferred: starting playback immediately here was getting silently
	# killed by the engine partway through this function's heavy synchronous
	# setup work below (villain/hero spawning) on some machines — deferring
	# to the start of the next frame, after all of that has settled, avoids it.
	_start_music.call_deferred()
	_field = get_tree().get_first_node_in_group("field") as LaneField

	_apply_stage_config(stage_id)
	for o in get_tree().get_nodes_in_group("objectives"):
		o.captured.connect(_on_objective_captured)

	_spawner.points_cleared.connect(_on_points_cleared)
	if _spawner.points_remaining() == 0:
		_points_cleared = true

	_hud.setup_heroes(RunState.living_party())
	_spawn_villain(_stage_config)
	# NOTE: boon picks are NOT queued here any more (Designer, 2026-07-26).
	# Deploy now runs FIRST and each Duo's pick follows its own arrival on the
	# field — see _on_deploy_chosen and _spawn_second_wave. Previously every
	# pick was drained before deploy became interactive, which asked the player
	# to choose Ultimate upgrades for Duos they hadn't placed yet, against a
	# battlefield they hadn't seen.
	_roll_monster()
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
	# Per-stage music override (StageConfig.music). Safe to assign here even
	# though playback is deferred: _ready() calls _start_music.call_deferred()
	# BEFORE this function runs synchronously, so the stream is already swapped
	# by the time the deferred call fires. Assigning it also means _start_music
	# applies its loop fix-up to the RIGHT stream.
	if config.music != null and _music != null:
		_music.stream = config.music

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
	# Nothing spawns yet. The boon pick for this wave's Duo comes first and the
	# teleport-in only fires once it's answered (Designer, 2026-07-26) — while
	# the pick is up, DeployController keeps drawing the placed hero sprites, so
	# the player chooses upgrades looking at their real formation rather than
	# watching heroes materialise behind a modal they haven't dismissed.
	_pending_names = payload.get("first_names", [])
	_pending_positions = payload.get("first_positions", [])

	_second_wave_names = payload.get("second_names", [])
	_second_wave_positions = payload.get("second_positions", [])
	_second_wave_remaining = float(payload.get("delay", 0.0)) if not _second_wave_names.is_empty() else -1.0

	_queue_picks_for(_pending_names)
	# No picks to make (every Duo here already picked this level) — deploy now
	# rather than waiting for a queue that will never drain.
	if _pick_queue.is_empty():
		_flush_pending_deploy()

func _spawn_second_wave() -> void:
	# Same rule as the first wave: pick first, arrive after. A boon chosen for
	# heroes who won't exist for another 10 seconds is a decision made blind.
	_pending_names = _second_wave_names.duplicate()
	_pending_positions = _second_wave_positions.duplicate()
	_second_wave_names = []
	_second_wave_positions = []
	_second_wave_remaining = -1.0
	_queue_picks_for(_pending_names)
	if _pick_queue.is_empty():
		_flush_pending_deploy()

## Actually puts the pending wave on the field — the teleport-in FX, the sound,
## and (on the first wave) releasing the swarm. Called once the wave's boon
## picks have all been answered.
func _flush_pending_deploy() -> void:
	if _pending_names.is_empty():
		return
	var names := _pending_names
	var positions := _pending_positions
	_pending_names = []
	_pending_positions = []
	for i in names.size():
		_spawn_hero(names[i], positions[i])
	# Drop the placement markers for the heroes that just materialised, and
	# retire the controller entirely once nothing is still pending.
	if _deploy != null and is_instance_valid(_deploy):
		_deploy.mark_spawned(names)
		if _second_wave_names.is_empty():
			_deploy.finish()
	if not _battle_started:
		_battle_started = true
		_spawner.begin_battle()
		# Boulders only start rolling once the party is actually on the field —
		# during deploy the swarm is frozen and nothing should be taking hits.
		_boulder_cd = randf_range(BOULDER_INTERVAL_RANGE.x, BOULDER_INTERVAL_RANGE.y)
		_boulders_live = true

## Queues one Ultimate-boon pick per Duo represented in `hero_names`, skipping
## any Duo that already picked this level. Picks record into RunState.duo_boons
## and are read live at cast time (Hero._ultimate_param), never applied to a
## Hero instance — so queueing them after the spawn is equivalent to before.
func _queue_picks_for(hero_names: Array) -> void:
	for duo in GameState.duo_pairings:
		if not (duo is Array) or (duo as Array).size() != 2:
			continue
		var a: String = duo[0]
		var b: String = duo[1]
		if a not in hero_names and b not in hero_names:
			continue
		var pair_id := DuoUltimates.id_for_heroes(a, b)
		if pair_id in _picked_this_level:
			continue
		_picked_this_level.append(pair_id)
		_pick_queue.append({"kind": "duo", "key": pair_id})

## Seconds left until the second Duo lands, or -1.0 if none is pending —
## BattleHUD polls this every frame to show the countdown.
func duo_b_seconds_remaining() -> float:
	return _second_wave_remaining

## True until the first wave actually lands — placement, plus the boon pick that
## now sits between START BATTLE and the spawn. BattleHUD uses it to show each
## hero's real card instead of a row of DOWN panels.
##
## Keyed off _battle_started rather than the DeployController's existence: that
## node outlives the commit (it keeps drawing placement markers for a delayed
## second wave), and while it's alive a held-back hero should read as "ARRIVES
## IN Xs", not as still-being-placed.
func is_deploy_phase() -> bool:
	return not _battle_started

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
	# No run-boon replay here any more (2026-07-25): the per-hero boon pool is
	# gone, and the Duo Ultimate boons that replaced it are read at cast time
	# rather than applied to the instance. Permanent gold/XP purchases still
	# apply at spawn, inside Hero._configure.
	var carried: float = RunState.carried_hp(hero_name)
	if carried >= 0.0:
		h.hp = clampf(carried, 1.0, h.max_hp)
	h.died.connect(_on_hero_died.bind(hero_name))
	_play_teleport_in(h, pos)

## Deploy should read as the hero teleporting onto the field, not just
## appearing — beam/ring/sparks (BattleFX) plus the hero itself materializing
## in rather than popping fully-formed.
func _play_teleport_in(h: Hero, pos: Vector2) -> void:
	BattleFX.teleport_in(get_node(heroes_root_path), pos, GameState.HERO_CATALOG[h.hero_name].color)
	var player := AudioStreamPlayer.new()
	player.stream = DEPLOY_SOUND
	player.bus = AudioSettings.BUS_SFX
	# Same root-persists-across-pause bug as Hero._on_died — see its doc.
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	h.modulate.a = 0.0
	h.scale = Vector2(1.4, 1.4)
	var tw := h.create_tween()
	tw.set_parallel(true)
	tw.tween_property(h, "modulate:a", 1.0, 0.2)
	tw.tween_property(h, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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

## The villain alone decides the level (Designer, 2026-07-25). Clearing every
## spawn point used to be a second requirement, which meant a party that killed
## the villain still had to go mop up gates before the level would end.
##
## _points_cleared is still tracked, just no longer part of this condition —
## destroying gates keeps paying its career stat and gold (see
## LaneSpawner._on_point_died), it simply isn't mandatory anymore.
func _check_win() -> void:
	if not _over and _villain_dead:
		_end(true)

## Cuts the win/defeat clip. Its player lives on the scene root (BattleSfx
## parents there so effects outlive the node that fired them), which is exactly
## why it needs an explicit stop: the root survives change_scene_to_file, so an
## unstopped stinger keeps playing over the prep menu.
func _stop_end_stinger() -> void:
	if _end_stinger != null and is_instance_valid(_end_stinger):
		_end_stinger.stop()
		_end_stinger.queue_free()
	_end_stinger = null

## Covers every other way this scene can go away — BACK TO MENU from the HUD,
## or a full reset — not just the R keypress on the results screen.
func _exit_tree() -> void:
	_stop_end_stinger()

func _process(delta: float) -> void:
	if _over:
		if Input.is_key_pressed(KEY_R):
			_stop_end_stinger()
			get_tree().paused = false
			get_tree().change_scene_to_file(GameState.BATTLEFIELD if _advance_to_next else GameState.PREP_MENU)
		return
	if _pick_screen != null:
		return
	if not _pick_queue.is_empty():
		_show_next_pick()
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
	if _monster_countdown > 0.0:
		_monster_countdown -= delta
		if _monster_countdown <= 0.0:
			_spawn_monster()
	_tick_boulders(delta)

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
			# Banner colours come from the shared palette rather than five
			# one-off hexes, so a buff chip matches the status ring the same
			# buff draws on the hero.
			_hud.show_objective_buff("XP+", UIStyle.GOOD, OBJECTIVE_BOOST_DURATION)
		1:
			for h in heroes:
				h.apply_damage_boost(OBJECTIVE_BOOST_DURATION, OBJECTIVE_DAMAGE_BOOST_MULT)
			_hud.show_objective_buff("DMG+", UIStyle.DANGER, OBJECTIVE_BOOST_DURATION)
		2:
			for h in heroes:
				h.apply_speed_boost(OBJECTIVE_BOOST_DURATION, OBJECTIVE_SPEED_BOOST_MULT)
			_hud.show_objective_buff("SPD+", UIStyle.INFO, OBJECTIVE_BOOST_DURATION)
		3:
			for h in heroes:
				h.apply_atk_speed_boost(OBJECTIVE_BOOST_DURATION, OBJECTIVE_ATK_SPEED_BOOST_MULT)
			_hud.show_objective_buff("ATK SPD+", UIStyle.GOLD, OBJECTIVE_BOOST_DURATION)
		4:
			for h in heroes:
				h.apply_shield(OBJECTIVE_SHIELD_CHARGES)
			_hud.show_objective_buff("SHIELD x%d" % OBJECTIVE_SHIELD_CHARGES, Combatant.STATUS_SHIELD_COLOR, OBJECTIVE_BOOST_DURATION)

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

## Drains _pick_queue one entry at a time, pausing on each pick. The queue is
## filled by _queue_picks_for as each wave lands (2026-07-26) rather than up
## front in _ready — every entry is a Duo Ultimate-boon pick now that the
## per-hero round is gone. RunState.duo_boons is the source of truth and
## Hero._ultimate_param reads it live at cast time, so a pick made after the
## Duo spawned needs no replaying onto the instance.
func _show_next_pick() -> void:
	if _pick_queue.is_empty():
		get_tree().paused = false
		return
	var entry: Dictionary = _pick_queue.pop_front()
	var screen := LevelUpScreen.new()
	_pick_screen = screen
	add_child(screen)
	var pair_id: String = entry.get("key", "")
	var names := pair_id.split("|")
	var ult_name: String = DuoUltimates.def(pair_id).get("name", "ULTIMATE")
	screen.setup(
		"%s — %s" % [" + ".join(names), ult_name],
		"Choose an Ultimate boon (this run only)",
		RunState.roll_duo_offer(pair_id), DuoUltimateBoons.def)
	screen.picked.connect(_on_pick_chosen.bind(entry))
	get_tree().paused = true

func _on_pick_chosen(id: String, entry: Dictionary) -> void:
	RunState.add_duo_boon(entry.get("key", ""), id)
	if _pick_screen != null:
		_pick_screen.queue_free()
		_pick_screen = null
	if _pick_queue.is_empty():
		get_tree().paused = false
		# Every pick for this wave is answered — NOW the heroes arrive. Unpause
		# first so the teleport-in FX and its tween actually run.
		_flush_pending_deploy()

# _find_living_hero() was removed 2026-07-25: its only caller was the per-hero
# boon pick, which applied the chosen boon to an already-spawned hero. With
# that round gone nothing needs to resolve a name to a live Hero here — the
# Duo Ultimate path resolves its caster through _spawned_duo_members instead.

## -- Duo Ultimates (2026-07-22) ----------------------------------------------

## Manually activates `pair_id`'s Duo Ultimate — called by the Duo Ultimate
## bar's ACTIVATE button (BattleHUD/DuoUltimateBar). Picks whichever Duo
## member is alive and spawned to be the caster (the confirmed leader if
## they're among the living, else whoever else is alive), casts the effect,
## then applies the level-long buff (DuoUltimates.def's "buff") to every
## living, spawned member. Once-per-level: returns false (no-op) if already
## used or nobody from the Duo is currently on the field. Returns true on a
## successful activation so the caller (button handler) knows to refresh.
func activate_ultimate(pair_id: String) -> bool:
	if not can_activate_ultimate(pair_id):
		return false
	var members := _spawned_duo_members(pair_id)
	var caster: Hero = members[0]
	for h in members:
		if GameState.is_duo_leader(h.hero_name):
			caster = h
			break
	caster.cast_duo_ultimate(pair_id)
	var buff: Dictionary = DuoUltimates.def(pair_id).get("buff", {})
	for h in members:
		h.apply_permanent_buff(
			float(buff.get("dmg_add", 0.0)),
			float(buff.get("atk_reduction", 0.0)),
			float(buff.get("hp_add", 0.0)))
	_ultimate_used[pair_id] = true
	return true

## True while pair_id's Ultimate is still available this level (not yet used
## AND at least one member is currently spawned+alive) — read every frame by
## the Duo Ultimate bar to enable/grey its button.
func can_activate_ultimate(pair_id: String) -> bool:
	if _ultimate_used.get(pair_id, false):
		return false
	return not _spawned_duo_members(pair_id).is_empty()

## Whether pair_id's Ultimate has already been used this level — distinct
## from can_activate_ultimate, which also folds in "nobody from the Duo is
## alive right now"; the Duo Ultimate bar uses both to tell "USED" apart from
## a plain unavailable state.
func is_ultimate_used(pair_id: String) -> bool:
	return _ultimate_used.get(pair_id, false)

## Living, currently-spawned Hero nodes whose hero_name is one of pair_id's
## two (pair_id is always a sorted "NAME_A|NAME_B" — see
## DuoUltimates.id_for_heroes — so this needs no GameState.duo_pairings
## lookup of its own).
func _spawned_duo_members(pair_id: String) -> Array[Hero]:
	var names := pair_id.split("|")
	var out: Array[Hero] = []
	for h in get_tree().get_nodes_in_group("heroes"):
		if h is Hero and is_instance_valid(h) and not h._dying and h.hero_name in names:
			out.append(h)
	return out

## Forces the stream to loop regardless of its import-time loop setting, then
## starts playback. AudioStreamPlayer.finished doesn't fire for a looping
## stream, so this is the only place loop needs to be configured.
func _start_music() -> void:
	if _music == null or _music.stream == null:
		return
	var stream := _music.stream
	if stream is AudioStreamWAV:
		# Godot 4.7.1: setting loop_mode without also fixing up loop_end (which
		# defaults to -1 on a stream imported with looping disabled) corrupts
		# the mixer for this stream — and takes down ALL audio process-wide
		# from that point on, silently, with no error. loop_end must be an
		# explicit sample count. Confirmed via Godot AI live-process bisection.
		var wav := stream as AudioStreamWAV
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	_music.play()

func _end(win: bool) -> void:
	_over = true
	if _music != null and is_instance_valid(_music):
		_music.stop()
	# Both show_results() branches below pause the tree; BattleSfx's players are
	# PROCESS_MODE_ALWAYS (see its doc), so the stinger plays over the paused
	# results screen instead of being cut off the moment it appears. Kept in a
	# field because the player is parented to the scene ROOT and would otherwise
	# survive the scene change and bleed into the next screen — see
	# _stop_end_stinger.
	_end_stinger = BattleSfx.play_clip(self, LEVEL_WIN_SOUND if win else LEVEL_DEFEAT_SOUND)
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
			# The one checkpoint: a cleared level is written to disk, so closing
			# the game here and pressing CONTINUE resumes at next_level with
			# this run's boons, XP, carried HP and casualties intact. Saved
			# AFTER current_level advances and _record_carryover() runs, so the
			# file describes the level about to be played, not the one just won.
			RunState.save_run()
			_results.show_results(true, 0, next_level)
			get_tree().paused = true
			return
	# Terminal outcome — the run is over either way (final level cleared, or the
	# party wiped), so the resumable file goes. Crucially this happens BEFORE
	# the results screen is even readable, so a defeat can't be undone by
	# quitting and pressing CONTINUE.
	RunState.clear_run()
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
			RunState.carry_hp(hero_name, minf(healed, h.max_hp), h.max_hp)

func _level_exists(n: int) -> bool:
	var has_stage_config := ResourceLoader.exists("res://config/stage_%d_config.tres" % n)
	return ResourceLoader.exists("res://config/level_%d_layout.tres" % n) and has_stage_config

## -- Wandering Monster (2026-07-25) ------------------------------------------

## The level it can crash. Designer: "a surprise enemy at level 2".
const MONSTER_LEVEL := 2
## Chance per visit to that level that it shows up at all. Designer: "spawns
## randomly in a FEW runs" — rare enough that meeting it is an event, not a
## mechanic the player plans around. First pass; tune in BALANCE.md.
const MONSTER_CHANCE := 0.3
## When it arrives, in seconds after the battle starts. Late enough that the
## party is already committed to a fight, early enough to matter.
const MONSTER_DELAY_RANGE := Vector2(25.0, 70.0)
## Spawns this far ahead of the party (+x, toward the villain) so it comes at
## them rather than materialising on top of them.
const MONSTER_SPAWN_LEAD := 900.0

const MONSTER_SCENE_PATH := "res://scenes/enemies/monster.tscn"

## Seconds until the monster arrives; <= 0 means "not coming / already came".
var _monster_countdown := 0.0

## Rolls for the wandering monster. Called once from _ready.
func _roll_monster() -> void:
	if RunState.current_level != MONSTER_LEVEL or RunState.headless:
		return
	if randf() >= MONSTER_CHANCE:
		return
	_monster_countdown = randf_range(MONSTER_DELAY_RANGE.x, MONSTER_DELAY_RANGE.y)

func _spawn_monster() -> void:
	_monster_countdown = 0.0
	if _over or _field == null:
		return
	var monster: Combatant = load(MONSTER_SCENE_PATH).instantiate()
	# Arrive ahead of whichever hero is furthest along the lane, on that hero's
	# side of the field — it should walk INTO the party, not spawn behind them
	# where it would spend its whole 10s window catching up.
	var front := _field.hero_spawn
	for h in _living_real_heroes():
		if h.global_position.x > front.x:
			front = h.global_position
	var x: float = minf(front.x + MONSTER_SPAWN_LEAD, _field.lane_length * 0.5 - 200.0)
	var y: float = clampf(front.y, -_field.lane_half_height + 80.0, _field.lane_half_height - 80.0)
	monster.global_position = Vector2(x, y)
	_field.get_parent().add_child(monster)

## -- Rolling Boulders (2026-07-25) -------------------------------------------

## The level the Berserker hurls boulders down (Designer: "like berserk is
## throwing them"). Same stage his lair sits on; every other level is unchanged.
const BOULDER_LEVEL := 2
const BOULDER_SCRIPT := preload("res://scenes/hazards/rolling_boulder.gd")
## Seconds between throws — constant pressure, but with enough gap that a lane
## is crossable between rocks.
const BOULDER_INTERVAL_RANGE := Vector2(5.0, 9.0)
## Random y offset inside the chosen lane half, so successive boulders don't
## all track the same groove.
const BOULDER_LANE_JITTER := 140.0

var _boulder_cd := 0.0
var _boulders_live := false

func _tick_boulders(delta: float) -> void:
	if not _boulders_live or RunState.current_level != BOULDER_LEVEL \
			or RunState.headless or _field == null:
		return
	_boulder_cd -= delta
	if _boulder_cd > 0.0:
		return
	_boulder_cd = randf_range(BOULDER_INTERVAL_RANGE.x, BOULDER_INTERVAL_RANGE.y)
	_spawn_boulder()

func _spawn_boulder() -> void:
	var boulder: Node2D = BOULDER_SCRIPT.new()
	# Enters from the villain's end of the lane and rolls the full length past
	# the deploy band before freeing itself.
	var half_len := _field.lane_length * 0.5
	# Centre of one lane half (top = -y, bottom = +y), jittered.
	var lane_center := _field.lane_half_height * 0.5
	var y: float = (-lane_center if randf() < 0.5 else lane_center) \
			+ randf_range(-BOULDER_LANE_JITTER, BOULDER_LANE_JITTER)
	boulder.despawn_x = -half_len - 200.0
	_field.get_parent().add_child(boulder)
	boulder.global_position = Vector2(half_len + 100.0, y)
