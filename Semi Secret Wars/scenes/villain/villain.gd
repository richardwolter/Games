class_name Villain
extends Combatant
## The stage villain (Stage 1: Dark Mage), as a beatable HP target.
##
## Reuses Combatant for health, health bar, damage and death; never attacks
## (summoner + HP target — see DECISIONS.md). Kites slowly away from the
## nearest hero, and every teleport_interval seconds blinks to a nearby clear
## spot and summons a fresh burst of minions around himself — turns him from
## a passive HP bag into a moving target that punishes standing still near
## him. Stats come from villain.tscn.

@export var villain_name := "DARK MAGE"
## Kiting: he retreats from the nearest hero until this far away, then stops.
@export var flee_distance := 260.0
## How often (seconds) he blinks to a nearby spot and resummons minions.
@export var teleport_interval := 20.0
## Max distance a teleport can jump.
@export var teleport_range := 400.0
## Minions summoned around him on each teleport.
@export var teleport_minion_count := 4
## Max distance a teleport destination may end up from the nearest hero —
## keeps him "in view" instead of vanishing off to some empty corner.
@export var teleport_fov_radius := 700.0
## Radius of the ring minions are placed on around him after a teleport.
@export var summon_radius := 90.0
@export var summon_minion_speed := 90.0

## How often (seconds) the flee goal is re-evaluated. Cheap, throttled like
## Minion/Berserker's hunt ticks.
const FLEE_INTERVAL := 0.3
const MINION_SCENE_PATH := "res://scenes/enemies/minion.tscn"

var _flee_cd := 0.0
var _teleport_cd := 0.0
var _minion_scene: PackedScene = null

func _configure() -> void:
	self_group = "hostiles"
	enemy_group = ""  # does not attack this milestone
	add_to_group("villains")
	label_text = villain_name
	if _field != null:
		global_position = _field.villain_pos
	_teleport_cd = teleport_interval
	_minion_scene = load(MINION_SCENE_PATH)

func _process(delta: float) -> void:
	super(delta)
	if _dying:
		return

	_teleport_cd -= delta
	if _teleport_cd <= 0.0:
		_teleport_cd = teleport_interval
		_teleport_and_summon()

	_flee_cd -= delta
	if _flee_cd <= 0.0:
		_flee_cd = FLEE_INTERVAL
		_update_flee_goal()

## Sets a retreat goal directly away from the nearest hero, once it's closer
## than flee_distance. _advance_goal (Combatant) handles the actual slow
## movement and obstacle steering; clears the goal once far enough away.
func _update_flee_goal() -> void:
	var hero := _nearest_hero()
	if hero == null:
		goal = Vector2.INF
		return
	var away := global_position - hero.global_position
	if away.length() >= flee_distance:
		goal = Vector2.INF
		return
	if away.length() < 1.0:
		away = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	set_goal(global_position + away.normalized() * flee_distance)

## Blinks to a nearby clear spot and resummons a fresh burst of minions there.
func _teleport_and_summon() -> void:
	if _field == null:
		return
	var dest := _find_teleport_spot()
	global_position = dest
	goal = Vector2.INF
	_summon_minions(dest)

## Samples candidate points: inside the field ellipse, clear of obstacles and
## the Poison Lake, within teleport_fov_radius of the nearest hero (so he
## stays visible rather than vanishing to an empty corner). Among the valid
## candidates, picks the one farthest from the nearest hero — as far away as
## he can get while staying in view. Falls back to the closest-to-in-view
## valid candidate if none satisfy the FOV bound, then to the current
## position (no jump) if nothing valid turns up at all.
func _find_teleport_spot() -> Vector2:
	var hero := _nearest_hero()
	var best_in_fov: Vector2 = global_position
	var best_in_fov_dist := -1.0
	var best_fallback: Vector2 = global_position
	var best_fallback_dist := INF
	var found_any := false
	for attempt in 20:
		var d := randf_range(teleport_range * 0.3, teleport_range)
		var a := randf() * TAU
		var p := global_position + Vector2(cos(a), sin(a)) * d
		if (p / (_field.field_radius - Vector2(body_radius, body_radius))).length_squared() > 1.0:
			continue
		if _field.in_lake(p):
			continue
		var clear := true
		for o in _field.obstacles:
			if p.distance_to(Vector2(o.x, o.y)) < o.z + body_radius + 20.0:
				clear = false
				break
		if not clear:
			continue
		found_any = true
		var hero_dist := p.distance_to(hero.global_position) if hero != null else 0.0
		if hero_dist <= teleport_fov_radius:
			if hero_dist > best_in_fov_dist:
				best_in_fov_dist = hero_dist
				best_in_fov = p
		elif hero_dist < best_fallback_dist:
			best_fallback_dist = hero_dist
			best_fallback = p
	if best_in_fov_dist >= 0.0:
		return best_in_fov
	if found_any:
		return best_fallback
	return global_position

## Spawns teleport_minion_count minions in a ring around `at`, same setup()
## contract MinionSpawner uses. Added as siblings (battlefield root), not
## children of the villain, so they aren't affected by his own transform.
func _summon_minions(at: Vector2) -> void:
	if _minion_scene == null or _field == null:
		return
	for i in teleport_minion_count:
		var m := _minion_scene.instantiate()
		var a := TAU * i / teleport_minion_count
		var offset := Vector2(cos(a), sin(a)) * summon_radius
		m.setup(at + offset, _field.hero_spawn + offset, offset * 0.6, summon_minion_speed)
		get_parent().add_child(m)

## Nearest living hero at any distance (kiting is field-wide, unlike detect).
func _nearest_hero() -> Combatant:
	var nearest: Combatant = null
	var best := INF
	for node in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(node) or node._dying:
			continue
		var dist := global_position.distance_squared_to(node.global_position)
		if dist < best:
			best = dist
			nearest = node
	return nearest
