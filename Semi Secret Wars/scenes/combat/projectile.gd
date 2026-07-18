class_name Projectile
extends Node2D
## Fired by ranged Combatants (see Combatant.is_ranged). Aimed at the target's
## position at cast time, but travels in a straight line and can connect with
## any live enemy it touches along the way (the original target moving out of
## the path is a miss, not a magic homing correction). If nothing is hit
## within max_range, it vanishes without dealing damage.

var damage := 0.0
var attacker: Combatant = null
var target: Combatant = null
var enemy_group := ""
var speed := 500.0
var max_range := 600.0
var color := Color.WHITE

const RADIUS := 4.0
const LENGTH := 14.0
const HIT_MARGIN := 6.0

var _dir := Vector2.RIGHT
var _traveled := 0.0

func _ready() -> void:
	var aim_point := global_position + Vector2.RIGHT
	if target != null and is_instance_valid(target):
		aim_point = target.global_position
	_dir = (aim_point - global_position)
	if _dir.length() < 0.01:
		_dir = Vector2.RIGHT
	else:
		_dir = _dir.normalized()
	rotation = _dir.angle()

func _process(delta: float) -> void:
	var step := speed * delta
	global_position += _dir * step
	_traveled += step
	var victim := _find_hit()
	if victim != null:
		if attacker != null and is_instance_valid(attacker):
			victim.take_damage(damage, attacker)
		queue_free()
		return
	if _traveled >= max_range:
		queue_free()

func _find_hit() -> Combatant:
	if enemy_group == "":
		return null
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying:
			continue
		if global_position.distance_to(node.global_position) <= node.body_radius + HIT_MARGIN:
			return node
	return null

func _draw() -> void:
	draw_line(Vector2(-LENGTH * 0.5, 0.0), Vector2(LENGTH * 0.5, 0.0), color, RADIUS)
	draw_circle(Vector2(LENGTH * 0.5, 0.0), RADIUS, color)
