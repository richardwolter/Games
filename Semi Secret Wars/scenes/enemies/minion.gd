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

## Cosmetic variety only (same stats/behavior) — each spawned minion picks one
## of its stage's variants at random so the swarm doesn't read as one repeated
## sprite. Keyed by RunState.current_level so a stage's swarm looks like it
## belongs to that stage's villain (Designer, 2026-07-25: Berserk minion art).
## A level with no entry falls back to LEVEL 1's set rather than drawing
## nothing — stage 3 has no swarm art of its own yet.
const SPRITE_VARIANTS_BY_LEVEL: Dictionary = {
	1: [
		preload("res://assets/sprites/Minion-Dark-Mage.png"),
		preload("res://assets/sprites/MinionDarkMage2.png"),
	],
	# Stage 2's second variant (Minion2_Berserk) is NOT here: it's the syringe
	# shooter and RangedMinion claims it exclusively, so the unit holding the
	# needle is the one firing droplets (Designer, 2026-07-25).
	2: [
		preload("res://assets/sprites/Berserk_Minion_1.png"),
	],
}

## Draw scale per level, applied alongside the sprite. Level 1 matches
## minion.tscn.s long-standing 1.8; the Berserk swarm runs bigger because its
## art reads smaller at the same scale (Designer, 2026-07-25).
##
## NOTE: this also widens collision — Combatant._collision_radius() is
## body_radius * sprite_scale. At body_radius 10-13 and the level-2 scale that
## is ~72-94px — the level-2 swarm now takes up real space and separates/pushes
## accordingly. Worth watching if the lane starts feeling clogged; the fix
## would be to decouple art scale from _collision_radius rather than shrink
## the art back.
const SPRITE_SCALE_BY_LEVEL: Dictionary = {
	1: 1.8,
	# Doubled again on 2026-07-25 (Designer: "2x bigger than current size") —
	# 3.6 still read small next to the heroes.
	2: 7.2,
}

## The variant list for the level currently being played.
static func sprite_variants_for_level(level: int) -> Array:
	return SPRITE_VARIANTS_BY_LEVEL.get(level, SPRITE_VARIANTS_BY_LEVEL[1])

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
	# Any minion that hasn't been given art of its own takes its stage's swarm
	# variant. This used to be gated to the base Minion class, which left every
	# Elite/Brute/Ranged rendering as a placeholder circle — i.e. the ENTIRE
	# swarm on stages 2 and 3, since those stages spawn only subclasses. The
	# null check preserves the original intent (a subclass with real art of its
	# own is never silently reskinned) without the collateral damage.
	if sprite_texture == null:
		var variants := sprite_variants_for_level(RunState.current_level)
		sprite_texture = variants[randi() % variants.size()]
		# Scale comes with the art. Only minion.tscn ever set sprite_scale
		# (1.8); every subclass left it at the 1.0 default, so the stage-2/3
		# swarm drew at barely half the size of a stage-1 minion using the
		# same body_radius — that is why the Berserk minions read as too small
		# (Designer, 2026-07-25). Setting it here keeps art and scale together
		# so a new stage can't reintroduce the mismatch.
		sprite_scale = SPRITE_SCALE_BY_LEVEL.get(RunState.current_level, 1.8)
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
