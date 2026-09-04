class_name LaneSpawner
extends Node2D
## Lane swarm spawner: an escalating cap/batch loop whose waves pour from
## DESTRUCTIBLE spawn points distributed along the lane.
## Destroying a point permanently stops its waves.
## Clearing every point USED to be half the level-clear condition; as of
## 2026-07-25 killing the villain alone ends the level (see
## BattleManager._check_win) and gates are an optional gold/stat objective.

signal points_cleared  ## Emitted the moment the last spawn point is destroyed.

## Gold drip — banked immediately via GameState.bank_gold,
## which does NOT save to disk (per-kill saves would thrash file I/O against a
## 50-minion swarm). Flushed by the save_game() inside the eventual
## award_gold() call at BattleManager._end(). First-pass values — flag for
## tuning in BALANCE.md.
const GOLD_PER_KILL := 0.5
const GOLD_PER_GATE := 15
var _gold_accum := 0.0

## Fraction of its max HP the tutorial gate can never be pushed below, so level
## 0 stays the scripted loss it is written as. Low enough that the bar reads as
## "almost" rather than as an obviously invincible target.
const TUTORIAL_GATE_FLOOR := 0.06

@export var minion_scene: PackedScene  ## Fallback if no config is applied.
@export var swarm_cap := 6
@export var spawn_interval := 0.5
@export var spawn_batch := 1
@export var minion_speed := 90.0
@export var spawn_spread := 30.0
## Spread around the swarm's leftward goal (the deploy band the heroes hold).
@export var goal_spread := 300.0
@export var escalate_every := 12.0
@export var escalate_step := 1
@export var max_cap := 24

## Spawn-point destruction SFX (Designer, 2026-07-25): only the 1.55-3.211
## slice of the source file is the collapse we want, so it plays with an
## explicit start + duration rather than the whole clip.
const POINT_DESTROYED_SOUND := preload("res://assets/Sounds/Spawn_Point_Destruction.wav")
const POINT_DESTROYED_START := 1.55
const POINT_DESTROYED_DURATION := 3.211 - 1.55

var kills := 0
var battle_started := false

var _field: LaneField
var _points: Array[LaneSpawnPoint] = []
## Lane ("top"/"bottom") each entry in _points belongs to, index-aligned —
## resolved once at spawn-point creation from LaneField's authored tags
## (falls back to sign-of-y for an untagged point). Kept in lockstep with
## _points (both erased together in _on_point_died) so a point's lane can be
## looked up by its index without a second lookup pass at every minion spawn.
var _point_lanes: Array[String] = []
var _active := 0
var _cap := 0.0
var _spawn_timer := 0.0
var _escalate_timer := 0.0
var _minion_scene_override: PackedScene = null
var _minion_scene_override_b: PackedScene = null
## Stage stat scaling (StageConfig). Gates are built in _ready, which can run
## before BattleManager calls apply_stage_config, so the gate multiplier is
## also applied retroactively there rather than only at construction.
var _minion_hp_mult := 1.0
var _minion_damage_mult := 1.0
var _point_hp_mult := 1.0

func _ready() -> void:
	_field = get_tree().get_first_node_in_group("field") as LaneField
	_cap = float(swarm_cap)
	_spawn_spawn_points()

## Instantiate one destructible LaneSpawnPoint per authored point and hold it.
func _spawn_spawn_points() -> void:
	_points.clear()
	_point_lanes.clear()
	if _field == null:
		return
	for i in _field.lane_spawn_points.size():
		var p: Vector3 = _field.lane_spawn_points[i]
		var sp := LaneSpawnPoint.new()
		sp.setup(Vector2(p.x, p.y), p.z * _point_hp_mult)
		# The tutorial's one gate cannot be destroyed — see LaneSpawnPoint.hp_floor.
		if Tutorial.in_battle():
			sp.hp_floor = sp.max_hp * TUTORIAL_GATE_FLOOR
		# Use the authored (x,y), not sp.global_position — _configure() (which
		# sets global_position from _spawn_at) doesn't run until add_child below.
		var tag := _field.lane_spawn_point_lanes[i] if i < _field.lane_spawn_point_lanes.size() else ""
		sp.lane = tag if tag != "" else _field.lane_of(Vector2(p.x, p.y))
		add_child(sp)
		sp.died.connect(_on_point_died.bind(sp))
		_points.append(sp)
		_point_lanes.append(sp.lane)
		# Register as a hard blocker so heroes steer around / can't stand on the
		# gate — Combatant separation only applies within the same self_group,
		# so a hero would otherwise walk straight into it. Approaching units'
		# own _collision_radii() (Combatant) adds clearance for oversized
		# sprite art on their end.
		#
		# The oval is derived from the AUTHORED body_radius, not from the gate's
		# much larger drawn size — the layouts were validated against gates
		# blocking at radius 44 (ART_BIBLE), so reshaping that radius is safe
		# while growing it could re-block a corridor.
		_field.register_dynamic_obstacle(sp.global_position, sp.body_radius,
				SpriteFootprint.radii_for(sp.sprite_texture, sp.body_radius * 2.0))

func apply_stage_config(config: StageConfig) -> void:
	swarm_cap = config.swarm_cap_start
	escalate_every = config.escalate_every
	escalate_step = config.escalate_step
	max_cap = config.swarm_max_cap
	minion_speed = config.minion_speed
	spawn_interval = config.spawn_interval
	spawn_batch = maxi(config.spawn_batch, 1)
	_cap = float(swarm_cap)
	_minion_scene_override = _load_minion_scene(config.minion_type)
	_minion_scene_override_b = _load_minion_scene_b(config.minion_type)
	_minion_hp_mult = config.minion_hp_mult
	_minion_damage_mult = config.minion_damage_mult
	# Gates built by an earlier _ready() already banked their HP — rescale them
	# (max and current alike, they're untouched at this point) so the multiplier
	# lands regardless of which node's _ready ran first.
	if not is_equal_approx(_point_hp_mult, config.spawn_point_hp_mult):
		var rescale := config.spawn_point_hp_mult / _point_hp_mult
		for p in _points:
			p.max_hp *= rescale
			p.hp *= rescale
	_point_hp_mult = config.spawn_point_hp_mult

func _load_minion_scene(minion_type: String) -> PackedScene:
	match minion_type:
		"elite_minion":
			return load("res://scenes/enemies/elite_minion.tscn")
		"hybrid_stage3":
			return load("res://scenes/enemies/ranged_minion.tscn")
		_:
			return load("res://scenes/enemies/minion.tscn")

func _load_minion_scene_b(minion_type: String) -> PackedScene:
	match minion_type:
		"hybrid_stage3":
			return load("res://scenes/enemies/brute_minion.tscn")
		# Stage 2 mixes in a shooter alongside its elites (Designer,
		# 2026-07-25) — the berserk swarm shipped with two minion sprites and
		# a projectile, which needs a ranged unit in the mix to appear at all.
		# _pick_minion_scene rolls 50/50 between the two.
		"elite_minion":
			return load("res://scenes/enemies/ranged_minion.tscn")
		_:
			return null

func begin_battle() -> void:
	battle_started = true

## Living spawn points remaining (0 = the swarm source is fully cleared).
func points_remaining() -> int:
	return _points.size()

func _process(delta: float) -> void:
	if not battle_started or minion_scene == null or _field == null:
		return
	_tick_ambush(delta)
	# No living spawn point can produce minions — the swarm source is dead.
	if _points.is_empty():
		return
	_escalate_timer += delta
	if _escalate_timer >= escalate_every:
		_escalate_timer = 0.0
		_cap = minf(_cap + escalate_step, maxf(float(max_cap), float(swarm_cap)))
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _active < int(_cap):
		_spawn_timer = spawn_interval
		for i in mini(spawn_batch, int(_cap) - _active):
			_spawn_one()

func _spawn_one() -> void:
	var scene = _pick_minion_scene()
	if scene == null or _points.is_empty():
		return
	var m := scene.instantiate()
	var offset := _random_disc(goal_spread)
	# Spawn from a living point; march LEFT onto the deploy band the heroes hold.
	var point_index := randi() % _points.size()
	var point: LaneSpawnPoint = _points[point_index]
	# Spawn just outside the gate's own hard-collision radius, not inside it —
	# spawn_spread (30) is smaller than the gate's body_radius (44), so a plain
	# disc offset would land every minion inside the gate's collision, which
	# the shared obstacle clamp (LaneField.clamp_out_of_obstacles) then force-
	# ejects the very next frame: a visible "collision pop" against its own
	# spawn point every single spawn. A ring starting past that clamp floor
	# keeps the crowd tight against the edge without ever needing correction.
	var min_r: float = point.body_radius + m._collision_radius() + 2.0
	m.stat_hp_mult = _minion_hp_mult
	m.stat_damage_mult = _minion_damage_mult
	m.setup(
		point.global_position + _random_ring(min_r, min_r + spawn_spread),
		_field.hero_spawn + offset,
		offset * 0.6,
		minion_speed,
		_point_lanes[point_index])
	add_child(m)
	m.tree_exited.connect(_on_minion_removed)
	m.died.connect(_on_minion_killed)
	_active += 1

## -- Tutorial rear ambush (Designer, 2026-07-31) ------------------------------
##
## "Send some minions from the back of the lane so they feel swarmed and can't
## control the spawn point." Waves that enter BEHIND the deploy band and march
## right, straight through the party, while the gate keeps pushing from the
## front — the pincer is what makes the scripted loss land as being overwhelmed
## rather than as slowly losing a fair fight.
##
## Deliberately NOT counted against `_cap`/`_active`: the swarm cap governs how
## much the GATE may have on the field, and an ambusher stealing one of those
## slots would relieve the front-line pressure it is supposed to add to.
## The first wave is late enough that the Duo gets to reach the gate and put
## real damage into it (the fight the tutorial promises) before the lane closes
## behind them.
const AMBUSH_FIRST_DELAY := 6.0
const AMBUSH_INTERVAL := 5.0
const AMBUSH_COUNT := 5
## Fraction of the lane's half-height ambushers may enter across, so they arrive
## spread out instead of single file.
const AMBUSH_SPREAD := 0.8

var _ambush_live := false
var _ambush_cd := 0.0

## Starts the ambush. Called once, when the tutorial's last explanation closes
## and the fight is finally the player's to lose (BattleManager).
func begin_tutorial_ambush() -> void:
	_ambush_live = true
	_ambush_cd = AMBUSH_FIRST_DELAY

func _tick_ambush(delta: float) -> void:
	if not _ambush_live or _field == null or _points.is_empty():
		return
	_ambush_cd -= delta
	if _ambush_cd > 0.0:
		return
	_ambush_cd = AMBUSH_INTERVAL
	for i in AMBUSH_COUNT:
		_spawn_behind()

## One ambusher, entering at the lane's left edge and marching toward the gate —
## so its path runs straight over the party rather than stopping where they were
## deployed.
func _spawn_behind() -> void:
	var scene := _pick_minion_scene()
	if scene == null:
		return
	var m := scene.instantiate()
	var y := randf_range(-_field.lane_half_height * AMBUSH_SPREAD,
			_field.lane_half_height * AMBUSH_SPREAD)
	# Inside the lane rect, not past it: units outside get clamped back in, which
	# would bunch the whole wave onto the boundary.
	var from := Vector2(-_field.field_radius.x + 40.0, y)
	var offset := _random_disc(goal_spread)
	m.stat_hp_mult = _minion_hp_mult
	m.stat_damage_mult = _minion_damage_mult
	m.setup(from, _points[0].global_position + offset, offset * 0.6, minion_speed, "")
	add_child(m)
	m.died.connect(_on_minion_killed)
	# No tree_exited hookup on purpose — see the _active note above.

func _pick_minion_scene() -> PackedScene:
	if _minion_scene_override_b != null:
		return _minion_scene_override if randf() < 0.5 else _minion_scene_override_b
	return _minion_scene_override if _minion_scene_override != null else minion_scene

## A spawn point was destroyed — retire it permanently; fire points_cleared when
## the last one falls.
func _on_point_died(_who: Combatant, point: LaneSpawnPoint) -> void:
	var idx := _points.find(point)
	if idx != -1:
		_point_lanes.remove_at(idx)
	_points.erase(point)
	if _field != null:
		_field.unregister_dynamic_obstacle(point.global_position, point.body_radius)
	BattleSfx.play_clip(self, POINT_DESTROYED_SOUND, POINT_DESTROYED_START,
			POINT_DESTROYED_DURATION)
	GameState.record_career("gates_destroyed", 1)
	GameState.bank_gold(GOLD_PER_GATE)
	if _points.is_empty():
		points_cleared.emit()

func _on_minion_removed() -> void:
	_active -= 1

func _on_minion_killed(who: Combatant) -> void:
	kills += 1
	GameState.record_career("minions_killed", 1)
	_gold_accum += GOLD_PER_KILL
	if _gold_accum >= 1.0:
		var whole := int(_gold_accum)
		GameState.bank_gold(whole)
		_gold_accum -= whole
	# Blood stain now applied by Combatant._spawn_death_particles for every
	# unit (minions, gates, villains alike) — see scripts/battle_fx.gd.

func current_cap() -> int:
	return int(_cap)

func _random_disc(r: float) -> Vector2:
	var a := randf() * TAU
	var d := sqrt(randf()) * r
	return Vector2(cos(a), sin(a)) * d

## Uniform-area random point in the annulus between `inner` and `outer` radii.
func _random_ring(inner: float, outer: float) -> Vector2:
	var a := randf() * TAU
	var r := sqrt(lerpf(inner * inner, outer * outer, randf()))
	return Vector2(cos(a), sin(a)) * r
