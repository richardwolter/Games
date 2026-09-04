class_name WeaponMelee
extends Node2D

## The scalpel. Swings automatically whenever something hostile is inside
## `reach`, in ANY direction -- it turns to whatever is closest rather than
## waiting for the player to be pointed at it. No input, no physics body: the arc
## is a query, which keeps the hitbox honest at any size_scale and costs nothing
## at prototype enemy counts.
##
## Automatic on purpose. It is what keeps the kid from being helpless while he is
## repositioning or reloading his aim, and putting it behind a button made the
## one weapon that covers his back into a second thing to point.

var stats: AttackStats
var target_group: StringName = &"enemies"

var _cooldown: float = 0.0
var _swing_left: float = 0.0
var _swing_dir: Vector2 = Vector2.RIGHT
## Blades currently in the air. The rig hides the held scalpel while this is
## non-empty, because a thrown knife that is also still in his hand is the kind
## of thing you only have to see once.
var _blades: Array[ThrownBlade] = []


func set_stats(s: AttackStats) -> void:
	stats = s


## True while a swing is in progress. The rig's melee arm rests at the kid's side
## and only moves for the duration of an actual attack, so it needs to know.
func is_swinging() -> bool:
	return _swing_left > 0.0


## How far through the current swing, 0 at the wind-up and 1 at the end.
func swing_t() -> float:
	if stats == null or _swing_left <= 0.0:
		return 1.0
	return clampf(1.0 - _swing_left / maxf(stats.swing_time, 0.001), 0.0, 1.0)


## The direction the current swing was aimed at.
func swing_direction() -> Vector2:
	return _swing_dir


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _swing_left > 0.0:
		_swing_left -= delta
		queue_redraw()
		if _swing_left <= 0.0:
			queue_redraw()


## True while at least one blade is out. Only ever true in throw mode.
func is_throwing() -> bool:
	# Built by hand rather than with filter(): Array.filter returns an UNTYPED
	# Array, and assigning that back to an Array[ThrownBlade] is a hard runtime
	# error, not a warning.
	var alive: Array[ThrownBlade] = []
	for b in _blades:
		if is_instance_valid(b):
			alive.append(b)
	_blades = alive
	return not _blades.is_empty()


## Whether the scalpel is currently a thrown weapon rather than a held one.
func is_thrown_mode() -> bool:
	return stats != null and stats.boomerang_count > 0


## Called by the owner every frame. `aim` is only a fallback: the swing points
## itself at the nearest thing in reach, whichever way that is, and the arc is
## struck around THAT. So a creature closing from behind is cut without the
## player having to turn round first.
func try_swing(aim: Vector2) -> void:
	if stats == null or _cooldown > 0.0:
		return

	if is_thrown_mode():
		_try_throw(aim)
		return

	var nearest := _nearest_target(stats.reach)
	if nearest == null:
		return
	var swing := (nearest.global_position - global_position)
	if swing.length_squared() < 0.0001:
		swing = aim
	var aim_at := swing.normalized()

	var victims := _targets_in_arc(aim_at)
	if victims.is_empty():
		return

	_cooldown = 1.0 / maxf(stats.attack_rate, 0.01)
	_swing_left = stats.swing_time
	_swing_dir = aim_at
	queue_redraw()

	for v in victims:
		var dmg := stats.damage
		var is_crit := randf() < stats.crit_chance
		if is_crit:
			dmg *= stats.crit_multiplier
		var dir := (v.global_position - global_position).normalized()
		if v.has_method(&"take_damage"):
			v.take_damage(dmg, dir * stats.knockback, stats.statuses, is_crit)


## Throws the whole set at once, fanned across the melee arc. Nothing is thrown
## while a previous set is still coming back -- the blade has to be caught before
## it can be thrown again, which is what stops the stack from becoming an
## unlimited knife fountain.
func _try_throw(aim: Vector2) -> void:
	if aim == Vector2.ZERO or is_throwing():
		return
	# Only throw at something. Melee fires on proximity rather than on input, and
	# a blade spinning off into an empty room every second is noise.
	if _nearest_target(stats.reach * ThrownBlade.RANGE_MULT) == null:
		return

	_cooldown = 1.0 / maxf(stats.attack_rate, 0.01)
	_swing_dir = aim.normalized()

	var count := stats.boomerang_count
	# Extra blades fan out across the arc the swing used to cover, so the item
	# keeps the weapon's shape instead of turning it into a single line.
	var half := deg_to_rad(stats.arc_degrees) * 0.5
	var base := _swing_dir.angle()

	for i in count:
		var angle := base
		if count > 1:
			angle = base - half + half * 2.0 * (float(i) / float(count - 1))
		var b := ThrownBlade.new()
		b.setup(stats.duplicate_stats(), Vector2.from_angle(angle), owner_body())
		b.global_position = global_position
		get_tree().current_scene.add_child(b)
		_blades.append(b)


## Closest hostile within `distance`, in any direction. The whole reason the
## swing is 360: it picks the target first and orients to it, rather than testing
## whether the player happened to already be facing one.
func _nearest_target(distance: float) -> Node2D:
	var best: Node2D = null
	var best_sq := distance * distance
	for n in get_tree().get_nodes_in_group(target_group):
		if n is not Node2D:
			continue
		var node := n as Node2D
		var d := global_position.distance_squared_to(node.global_position)
		if d <= best_sq:
			best_sq = d
			best = node
	return best


## Who the blades come home to. The weapon is a child of the player, so its own
## parent is the answer -- it is not given a reference, because a weapon that
## knows what a Player is stops being reusable by anything else.
func owner_body() -> Node2D:
	var p := get_parent()
	return p as Node2D if p is Node2D else self


func _targets_in_arc(aim: Vector2) -> Array[Node2D]:
	var out: Array[Node2D] = []
	if aim == Vector2.ZERO:
		return out
	var reach_sq := stats.reach * stats.reach
	var half_arc := deg_to_rad(stats.arc_degrees) * 0.5
	for n in get_tree().get_nodes_in_group(target_group):
		if n is not Node2D:
			continue
		var node := n as Node2D
		var to := node.global_position - global_position
		if to.length_squared() > reach_sq:
			continue
		if absf(aim.angle_to(to)) > half_arc:
			continue
		out.append(node)
	return out


func _draw() -> void:
	# Placeholder swing read: a wedge that fades over the swing window.
	if stats == null or _swing_left <= 0.0:
		return
	var t := _swing_left / maxf(stats.swing_time, 0.001)
	var half := deg_to_rad(stats.arc_degrees) * 0.5
	var base := _swing_dir.angle()
	var points: PackedVector2Array = [Vector2.ZERO]
	var steps := 12
	for i in steps + 1:
		var a := base - half + (half * 2.0) * (float(i) / steps)
		points.append(Vector2.from_angle(a) * stats.reach)
	draw_colored_polygon(points, Color(stats.tint, 0.35 * t))
