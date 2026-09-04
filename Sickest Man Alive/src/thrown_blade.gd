class_name ThrownBlade
extends Area2D

## The scalpel once Scalpelrang has been picked up. Flies out, stops, comes
## back to whoever threw it. Not a Projectile: a projectile is fire-and-forget
## and dies on its own timer, and everything interesting about a boomerang is
## the return leg, which needs a thrower to home on.

const BLADE_ART: Texture2D = preload("res://art/weapons/scalpel_sword.png")

## Multiplier on the melee reach to get the throw distance. Melee reach is
## measured in "arm's length"; a thrown blade that only travelled that far
## would be a worse version of the swing it replaced.
const RANGE_MULT: float = 4.2
const SPIN_SPEED: float = 18.0
## How close to the thrower counts as caught.
const CATCH_DISTANCE: float = 22.0

## The walls layer, as a mask. Same layer carries room walls, cover and locked
## door plugs, so all three turn a blade around without a case each.
const WALL_MASK: int = 1 << 4

var stats: AttackStats
var target_group: StringName = &"enemies"

var _thrower: Node2D
var _direction: Vector2 = Vector2.RIGHT
var _travelled: float = 0.0
var _range: float = 240.0
var _returning: bool = false
## Reset on the turnaround, so a blade can cut the same enemy going out and
## again coming back -- but never twice on one leg.
var _hit_ids: Array[int] = []

var _sprite: Sprite2D


func setup(p_stats: AttackStats, p_direction: Vector2, p_thrower: Node2D,
		p_target_group: StringName = &"enemies") -> void:
	stats = p_stats
	_direction = p_direction.normalized()
	_thrower = p_thrower
	target_group = p_target_group
	_range = maxf(stats.reach, 40.0) * RANGE_MULT


func _ready() -> void:
	if stats == null or _thrower == null:
		queue_free()
		return

	collision_layer = 8
	collision_mask = 2   ## enemy hurtboxes only
	add_to_group(&"projectiles")

	_sprite = Sprite2D.new()
	_sprite.texture = BLADE_ART
	_sprite.self_modulate = stats.tint
	# Scaled so the blade is as LONG as the reach it cuts at. The art runs along
	# its X axis (451x52), so dividing by the height made it forty times too big.
	_sprite.scale = Vector2.ONE * (stats.reach / float(BLADE_ART.get_width()))
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(stats.reach * 0.3, 14.0)
	shape.shape = circle
	add_child(shape)

	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	# Nothing to come home to. Do not leave a blade orbiting a dead room.
	if not is_instance_valid(_thrower):
		queue_free()
		return

	var step := stats.speed * 0.65 * delta

	if not _returning:
		# Ease off at the far end so the turnaround reads as a throw reaching
		# its limit, not as a shot bouncing off nothing.
		var t := clampf(_travelled / _range, 0.0, 1.0)
		step *= 1.0 - t * 0.75
		var from := global_position
		global_position += _direction * step
		_travelled += step
		# A wall ends the outward leg early. Turning around rather than dying:
		# the blade IS the melee weapon while it is in the air, so despawning it
		# on a wall would leave the player unarmed for having thrown at cover,
		# and letting it fly on left it sailing out of the room entirely.
		if _turn_at_wall(from, global_position):
			return
		if t >= 1.0:
			_turn_around()
	else:
		var to_thrower := _thrower.global_position - global_position
		if to_thrower.length() <= CATCH_DISTANCE:
			queue_free()
			return
		# Accelerating on the way back: a slow return is dead time in which the
		# melee weapon does not exist.
		global_position += to_thrower.normalized() * step * 1.6

	_sprite.rotation += SPIN_SPEED * delta


## Starts the return leg. The hit list is cleared with it, so a blade can cut the
## same enemy on the way out and again on the way home.
func _turn_around() -> void:
	_returning = true
	_hit_ids.clear()


## Turns the blade at the first wall in this step, if there is one.
##
## Only the OUTWARD leg is tested. The return leg homes straight at the thrower
## and is deliberately allowed through cover: a blade thrown over a crate would
## otherwise grind against the far side of it forever, and the player would have
## no melee weapon until they walked around to fetch it.
##
## Returns whether it turned, so the caller stops advancing this frame.
func _turn_at_wall(from: Vector2, to: Vector2) -> bool:
	if from.is_equal_approx(to):
		return false
	var query := PhysicsRayQueryParameters2D.create(from, to, WALL_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	# Backed off the surface rather than left touching it, or the next frame's
	# ray starts inside the wall, finds nothing, and the blade walks through.
	global_position = (hit["position"] as Vector2) + (hit["normal"] as Vector2) * 4.0
	_turn_around()
	return true


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group(target_group):
		return
	var id := area.get_instance_id()
	if id in _hit_ids:
		return
	_hit_ids.append(id)

	var dmg := stats.damage
	var is_crit := randf() < stats.crit_chance
	if is_crit:
		dmg *= stats.crit_multiplier

	if area.has_method(&"take_damage"):
		var dir := (area.global_position - global_position).normalized()
		area.take_damage(dmg, dir * stats.knockback, stats.statuses, is_crit)
