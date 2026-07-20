class_name LaneSpawner
extends Node2D
## Lane swarm spawner: an escalating cap/batch loop whose waves pour from
## DESTRUCTIBLE spawn points distributed along the lane.
## Destroying a point permanently stops its waves;
## all points destroyed is half the level-clear condition (villain dead is the
## other half — see BattleManager).

signal points_cleared  ## Emitted the moment the last spawn point is destroyed.

## Gold drip — banked immediately via GameState.bank_gold,
## which does NOT save to disk (per-kill saves would thrash file I/O against a
## 50-minion swarm). Flushed by the save_game() inside the eventual
## award_gold() call at BattleManager._end(). First-pass values — flag for
## tuning in BALANCE.md.
const GOLD_PER_KILL := 0.5
const GOLD_PER_GATE := 15
var _gold_accum := 0.0

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
		sp.setup(Vector2(p.x, p.y), p.z)
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
		# own _collision_radius() (Combatant) adds clearance for oversized
		# sprite art on their end.
		_field.register_dynamic_obstacle(sp.global_position, sp.body_radius)

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
	var blood := get_tree().get_first_node_in_group("blood")
	if blood != null and blood.has_method("stain"):
		blood.stain(who.global_position)

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
