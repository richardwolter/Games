class_name Monster
extends Combatant
## A wandering, faction-less beast that occasionally crashes the Berserker's
## level (Designer, 2026-07-25: "a surprise enemy at level 2, it spawns
## randomly in a few runs. He is strong and attacks anything on its way,
## heroes and enemies included. He runs away after 10s").
##
## Three things make it different from every other unit in the game:
##
## 1. NO SIDE. Its enemy_group is Combatant.TARGETABLE_GROUP — the group every
##    Combatant joins — so hero, minion and villain are all equally valid
##    targets. It still belongs to "hostiles" as well, which is what lets
##    HEROES fight back (their enemy_group is "hostiles"); minions have no
##    reason to retaliate and won't, which is deliberate: the monster is a
##    hazard that mauls the swarm on its way through, not a third army.
##
## 2. IT LEAVES. RAMPAGE_DURATION seconds after spawning it stops fighting,
##    turns for the nearest long edge of the lane and runs off the field, then
##    frees itself. It is an event, not an enemy to be cleared — the party
##    survives it rather than beating it.
##
## 3. IT IS NOT WORTH FARMING. xp_value/gold are left at zero in the scene, and
##    it never targets pinned structures (see _target_ok) so it can't chew
##    through spawn gates and hand the player free gold on a lucky roll.
##
## Spawning (chance, level, timing) lives in BattleManager — see MONSTER_CHANCE.
## First-pass stats are tuned in monster.tscn and flagged in BALANCE.md.

const SPRITE := preload("res://assets/sprites/Monster1.png")

## Seconds of rampage before it flees. Designer-specified.
const RAMPAGE_DURATION := 10.0
## Speed multiplier while fleeing — it bolts rather than strolling off.
const FLEE_SPEED_MULT := 1.6
## Extra distance past the lane edge before despawning, so it exits fully
## off-screen instead of popping out at the boundary.
const FLEE_OVERSHOOT := 400.0
## How often it re-picks a victim while rampaging. Very fast (Designer,
## 2026-07-25: "a lot faster and aggressive") — it re-evaluates almost every
## few frames, so it visibly lunges at whatever is nearest instead of
## committing to one victim and jogging past everything else.
const HUNT_INTERVAL := 0.15

var _rampage_t := RAMPAGE_DURATION
var _fleeing := false
var _hunt_cd := 0.0

func _configure() -> void:
	self_group = "monsters"
	# Also a "hostile" so heroes engage it (their enemy_group is "hostiles").
	# Its OWN targeting ignores this and uses the universal group below.
	add_to_group("hostiles")
	enemy_group = TARGETABLE_GROUP
	sprite_texture = SPRITE
	sprite_scale = 2.4

func _process(delta: float) -> void:
	if _dying:
		super(delta)
		return
	if _fleeing:
		_process_flee(delta)
		return

	_rampage_t -= delta
	if _rampage_t <= 0.0:
		_begin_flee()
		return

	# Field-wide hunt: without this it only ever engages whatever wanders
	# inside detect_range, and a beast that ignores a fight 200px away reads
	# as broken rather than dangerous. Re-goals even WITH a live target so it
	# keeps switching to whatever is closest — a rampage, not a duel.
	_hunt_cd -= delta
	if _hunt_cd <= 0.0:
		_hunt_cd = HUNT_INTERVAL
		var prey := _nearest_prey()
		if prey != null:
			set_goal(prey.global_position)
			# Re-point the CURRENT target too, not just the walk goal. Without
			# this it keeps swinging at whoever it first locked while walking
			# toward someone else, which reads as slow and confused rather
			# than aggressive.
			if prey != _target:
				_target = prey
	super(delta)

## Nearest living thing of any side, ignoring pinned structures. Deliberately
## not _nearest_in_group(enemy_group): that would happily return a spawn gate.
func _nearest_prey() -> Combatant:
	var best: Combatant = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(TARGETABLE_GROUP):
		if not _target_ok(node):
			continue
		var d: float = global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

func _target_ok(node) -> bool:
	if node == self or not is_instance_valid(node) or node._dying:
		return false
	# Structures (spawn gates) are skipped — see the class doc's point 3.
	if "is_pinned" in node and node.is_pinned:
		return false
	# Never turn on another monster; two of them brawling reads as a bug.
	return not node.is_in_group("monsters")

## Turns tail for the nearest long edge of the lane and stops fighting.
func _begin_flee() -> void:
	_fleeing = true
	_target = null
	is_taunting = false
	move_speed *= FLEE_SPEED_MULT
	var exit_y: float = -(_field.lane_half_height + FLEE_OVERSHOOT) if global_position.y < 0.0 \
			else _field.lane_half_height + FLEE_OVERSHOOT
	set_goal(Vector2(global_position.x, exit_y))

## Runs straight for the exit, ignoring targets entirely. Not super()'d: the
## base _process would re-acquire a target and drag it back into the fight,
## and the lane/field clamps would pin it inside the very boundary it is
## trying to cross.
func _process_flee(delta: float) -> void:
	var dir := (goal - global_position).normalized()
	global_position += dir * move_speed * delta
	_walking_this_frame = true
	_heading = dir
	if absf(global_position.y) >= _field.lane_half_height + FLEE_OVERSHOOT * 0.9:
		queue_free()
		return
	queue_redraw()
