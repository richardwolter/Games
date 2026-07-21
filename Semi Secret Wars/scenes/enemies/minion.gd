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

## Designer feedback 2026-07-19, "minions should be more aggressive": commit
## to melee from farther out instead of only engaging once very close, and cut
## most of the intercept-ahead lead so the swarm beelines at heroes rather than
## reading as evasive/flanking.
const DETECT_RANGE_MULT := 2.2
const INTERCEPT_LEAD_MULT := 0.35

var _spawn_pos := Vector2.ZERO
var _exit_pos := Vector2.ZERO
var _swarm_offset := Vector2.ZERO
var _hunting := false
var _hunt_cd := 0.0
## Lane ("top"/"bottom") this minion's spawn point belongs to (Designer,
## 2026-07-20: lane split) — set by LaneSpawner via setup(). Restricts
## _nearest_hero() to that lane's heroes so the swarm doesn't drain across to
## whichever lane happens to be softer; falls back to any living hero once
## this lane has none left (the "lanes merge" collapse behavior).
var _lane := ""

## Called by the spawner right after instantiation, before add_child().
func setup(spawn_pos: Vector2, exit_pos: Vector2, swarm_offset: Vector2, move_speed_value: float, lane_value := "") -> void:
	_spawn_pos = spawn_pos
	_exit_pos = exit_pos
	_swarm_offset = swarm_offset
	move_speed = move_speed_value
	_lane = lane_value

func _configure() -> void:
	self_group = "hostiles"
	enemy_group = "heroes"
	global_position = _spawn_pos
	set_goal(_exit_pos)
	detect_range *= DETECT_RANGE_MULT
	# Desync hunt ticks across the swarm (same idea as _retarget_cd stagger).
	_hunt_cd = randf() * HUNT_INTERVAL

func _process(delta: float) -> void:
	super(delta)
	if _dying:
		return
	# Hold to this minion's own spawn lane until the merge zone right before
	# the villain, same rule and boundary as Hero (Designer, 2026-07-20) — a
	# minion chasing a hero across the split just holds at the boundary
	# instead of crossing into the other lane's territory.
	if _lane != "":
		global_position = _field.clamp_to_lane(global_position, _lane)
	_hunt_cd -= delta
	if _hunt_cd > 0.0:
		return
	_hunt_cd = HUNT_INTERVAL
	# Confused (BEACON's Confuse ultimate): walk at the nearest fellow minion
	# instead of hunting heroes, so the body physically turns on its own kind.
	if _confused_t > 0.0:
		var mate := _nearest_confused_mate()
		if mate != null:
			_hunting = true
			set_goal(mate.global_position)
		return
	var hero := _nearest_hero()
	if hero != null:
		_hunting = true
		var dist := global_position.distance_to(hero.global_position)
		# Far away: aim ahead of the hero (block its route to the villain).
		# Close in: the lead shrinks to zero so the goal converges on the hero
		# itself — minions charge straight in and engagement takes over.
		var lead := Vector2.ZERO
		var lead_len := minf(intercept_lead * INTERCEPT_LEAD_MULT, dist * 0.4)
		var to_villain := _field.villain_pos - hero.global_position
		if to_villain.length() > 1.0:
			lead = to_villain.normalized() * minf(lead_len, to_villain.length())
		var offset := _swarm_offset * clampf(dist / 300.0, 0.25, 1.0)
		set_goal(hero.global_position + lead + offset)
	elif _hunting:
		_hunting = false
		set_goal(_exit_pos)

## Lane filter for detect-range engagement (Combatant._acquire_target) —
## mirrors Hero._lane_ok so a minion can't lock onto a hero across the
## boundary gap either, not just fail to hunt toward one at long range.
func _lane_ok(node: Combatant) -> bool:
	if _lane == "" or _field == null:
		return true
	if global_position.x >= _field.lane_merge_x() or _field.lanes_merged():
		return true
	if not ("lane" in node):
		return true
	var node_lane: String = node.lane
	return node_lane == "" or node_lane == _lane

## Nearest living same-group minion (a confused minion's walk-toward victim).
func _nearest_confused_mate() -> Combatant:
	var nearest: Combatant = null
	var best := INF
	for node in get_tree().get_nodes_in_group(self_group):
		if node == self or not is_instance_valid(node) or node._dying:
			continue
		var dist := global_position.distance_squared_to(node.global_position)
		if dist < best:
			best = dist
			nearest = node
	return nearest

## Nearest living hero at any distance (hunting is field-wide, unlike detect).
## Restricted to this minion's own lane UNLESS either lane's Duo has been
## wiped (LaneField.lanes_merged — Designer, 2026-07-20: lane separation
## breaks with the assigned duo's death). Deliberately does NOT fall back to
## the other lane just because this minion's own lane currently has no living
## hero — a lane the player never deployed anyone into isn't "collapsed", and
## falling back there would pull minions across the (still-held) boundary
## toward a hero they can't actually reach until the merge zone, reading as
## "focusing on the wrong lane". Returns null in that case — same as a hero
## with no live target, the minion just idles/drifts to the funnel exit.
func _nearest_hero() -> Combatant:
	if _lane == "" or (_field != null and _field.lanes_merged()):
		return _nearest_hero_in_lane("")
	return _nearest_hero_in_lane(_lane)

func _nearest_hero_in_lane(lane_filter: String) -> Combatant:
	var nearest: Combatant = null
	var best := INF
	for node in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(node) or node._dying:
			continue
		# HeroClone now carries its caster's lane too (see HeroClone.lane) —
		# lane-filter it the same as a real Hero so minions don't hunt/path
		# toward a clone stuck on the other side of the lane split.
		if lane_filter != "":
			var node_lane := ""
			if node is Hero:
				node_lane = (node as Hero).lane
			elif node is HeroClone:
				node_lane = (node as HeroClone).lane
			if node_lane != "" and node_lane != lane_filter:
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
