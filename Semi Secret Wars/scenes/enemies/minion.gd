class_name Minion
extends Combatant
## Placeholder swarm minion (a Dark Mage summon).
##
## Minions prioritize heroes (GDD §9): each hunts the nearest living hero,
## steering toward an intercept point slightly *ahead* of the hero on its route
## to the villain — the swarm places itself in the party's way rather than
## tail-chasing. On contact, normal Combatant engagement (attack) takes over.
## With no heroes alive, minions fall back to flowing toward the hero funnel
## and despawn there. Per-minion swarm offsets keep the pack loose (clusters,
## not a stack). The spawner supplies positions via setup() before add_child().

## How often (seconds) hunt goals are re-evaluated. Cheap, throttled.
const HUNT_INTERVAL := 0.3

## How far ahead of the hero (toward the villain) the intercept point sits.
@export var intercept_lead := 160.0

var _spawn_pos := Vector2.ZERO
var _exit_pos := Vector2.ZERO
var _swarm_offset := Vector2.ZERO
var _hunting := false
var _hunt_cd := 0.0

## Called by the spawner right after instantiation, before add_child().
func setup(spawn_pos: Vector2, exit_pos: Vector2, swarm_offset: Vector2, move_speed_value: float) -> void:
	_spawn_pos = spawn_pos
	_exit_pos = exit_pos
	_swarm_offset = swarm_offset
	move_speed = move_speed_value

func _configure() -> void:
	self_group = "hostiles"
	enemy_group = "heroes"
	global_position = _spawn_pos
	set_goal(_exit_pos)
	# Desync hunt ticks across the swarm (same idea as _retarget_cd stagger).
	_hunt_cd = randf() * HUNT_INTERVAL

func _process(delta: float) -> void:
	super(delta)
	if _dying:
		return
	_hunt_cd -= delta
	if _hunt_cd > 0.0:
		return
	_hunt_cd = HUNT_INTERVAL
	var hero := _nearest_hero()
	if hero != null:
		_hunting = true
		var dist := global_position.distance_to(hero.global_position)
		# Far away: aim ahead of the hero (block its route to the villain).
		# Close in: the lead shrinks to zero so the goal converges on the hero
		# itself — minions charge straight in and engagement takes over.
		var lead := Vector2.ZERO
		var lead_len := minf(intercept_lead, dist * 0.4)
		var to_villain := _field.villain_pos - hero.global_position
		if to_villain.length() > 1.0:
			lead = to_villain.normalized() * minf(lead_len, to_villain.length())
		var offset := _swarm_offset * clampf(dist / 300.0, 0.25, 1.0)
		set_goal(hero.global_position + lead + offset)
	elif _hunting:
		_hunting = false
		set_goal(_exit_pos)

## Nearest living hero at any distance (hunting is field-wide, unlike detect).
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

## Only the no-heroes fallback flow despawns at its goal (the funnel exit).
func _on_goal_reached() -> void:
	if not _hunting:
		queue_free()
