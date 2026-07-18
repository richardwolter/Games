class_name MinionSpawner
extends Node2D
## Continuous escalating swarm spawner, configured per-stage.
##
## Maintains up to `swarm_cap` active minions, refilling as they die or despawn;
## the cap grows over time so the farm intensifies until the heroes are eventually
## overwhelmed and the run ends (they retry stronger). Minion type and stats come
## from a StageConfig applied at runtime (e.g., "minion" vs. "elite_minion").

@export var minion_scene: PackedScene  ## Fallback if no config is applied.
## Starting maximum number of simultaneously active minions.
@export var swarm_cap := 6
@export var spawn_interval := 0.5
## Minions spawned per spawn tick; >1 lets large caps refill as fast as they drain.
@export var spawn_batch := 1
@export var minion_speed := 90.0
## Radius of the random spread around each spawn point.
@export var spawn_spread := 160.0
## Number of spawn points randomly placed on the villain half at battle start.
@export var spawn_point_count := 6
## Minimum distance between spawn points, so they spread across the half.
@export var spawn_point_separation := 350.0
## Radius of the random spread around the swarm's far-side goal.
@export var goal_spread := 360.0
## The active cap grows by escalate_step every escalate_every seconds, up to max_cap.
@export var escalate_every := 12.0
@export var escalate_step := 1
@export var max_cap := 24

## Minions killed in combat this run (the run's farm / XP proxy).
var kills := 0

## Spawning is held until the deployment phase ends (BattleManager calls
## begin_battle), so the player places heroes on a quiet field.
var battle_started := false

var _field: StageField
var _active := 0
var _cap := 0.0
var _spawn_timer := 0.0
var _escalate_timer := 0.0
var _minion_scene_override: PackedScene = null
## Second scene for hybrid stages (e.g. Stage 3's ranged+brute mix); null
## means the stage spawns a single minion type via _minion_scene_override.
var _minion_scene_override_b: PackedScene = null
var _spawn_points: Array[Vector2] = []

func _ready() -> void:
	_field = get_tree().get_first_node_in_group("field")
	_cap = float(swarm_cap)
	_generate_spawn_points()

## Randomly place spawn points anywhere on the field, inside the field
## ellipse and clear of obstacles and the Poison Lake. Rejection-sampled;
## falls back to villain_pos so spawning never breaks on a crowded field.
func _generate_spawn_points() -> void:
	_spawn_points.clear()
	if _field == null:
		return
	for i in spawn_point_count:
		var placed := false
		for attempt in 40:
			var p := Vector2(
				randf_range(-_field.field_radius.x * 0.85, _field.field_radius.x * 0.85),
				randf_range(-_field.field_radius.y * 0.85, _field.field_radius.y * 0.85))
			if (p / _field.field_radius).length_squared() > 1.0:
				continue
			if _field.in_lake(p) or not _clear_of_obstacles(p):
				continue
			if not _clear_of_other_points(p):
				continue
			_spawn_points.append(p)
			placed = true
			break
		if not placed:
			_spawn_points.append(_field.villain_pos)

func _clear_of_obstacles(p: Vector2) -> bool:
	for o in _field.obstacles:
		if p.distance_to(Vector2(o.x, o.y)) < o.z + spawn_spread:
			return false
	return true

func _clear_of_other_points(p: Vector2) -> bool:
	for existing in _spawn_points:
		if p.distance_to(existing) < spawn_point_separation:
			return false
	return true

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

## Second minion type for hybrid stages; null keeps _pick_minion_scene on the
## single-scene path used by every stage before Stage 3.
func _load_minion_scene_b(minion_type: String) -> PackedScene:
	match minion_type:
		"hybrid_stage3":
			return load("res://scenes/enemies/brute_minion.tscn")
		_:
			return null

## Deployment planning: where the swarm will pour from (read-only).
func spawn_points() -> Array[Vector2]:
	return _spawn_points

func begin_battle() -> void:
	battle_started = true

func _process(delta: float) -> void:
	if not battle_started or minion_scene == null or _field == null:
		return
	_escalate_timer += delta
	if _escalate_timer >= escalate_every:
		_escalate_timer = 0.0
		# Ceiling respects a hand-raised starting cap (e.g. big-swarm tests).
		_cap = minf(_cap + escalate_step, maxf(float(max_cap), float(swarm_cap)))
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _active < int(_cap):
		_spawn_timer = spawn_interval
		for i in mini(spawn_batch, int(_cap) - _active):
			_spawn_one()

func _spawn_one() -> void:
	var scene = _pick_minion_scene()
	if scene == null:
		return
	var m := scene.instantiate()
	var offset := _random_disc(goal_spread)
	# setup() before add_child so position/goal are ready when _ready runs.
	# The per-minion offset doubles as its swarm-cluster offset while hunting.
	var spawn_point: Vector2 = _spawn_points.pick_random() if not _spawn_points.is_empty() else _field.villain_pos
	m.setup(
		spawn_point + _random_disc(spawn_spread),
		_field.hero_spawn + offset,
		offset * 0.6,
		minion_speed)
	add_child(m)
	# tree_exited covers both combat death and reaching the far side.
	m.tree_exited.connect(_on_minion_removed)
	# died fires only on combat death -> counts as farmed.
	m.died.connect(_on_minion_killed)
	_active += 1

## Hybrid stages alternate 50/50 between the two override scenes; everything
## before Stage 3 has _minion_scene_override_b == null and keeps spawning
## the single configured (or fallback) scene.
func _pick_minion_scene() -> PackedScene:
	if _minion_scene_override_b != null:
		return _minion_scene_override if randf() < 0.5 else _minion_scene_override_b
	return _minion_scene_override if _minion_scene_override != null else minion_scene

func _on_minion_removed() -> void:
	_active -= 1

func _on_minion_killed(_who: Combatant) -> void:
	kills += 1

func current_cap() -> int:
	return int(_cap)

func _random_disc(r: float) -> Vector2:
	var a := randf() * TAU
	var d := sqrt(randf()) * r
	return Vector2(cos(a), sin(a)) * d
