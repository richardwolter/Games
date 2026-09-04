class_name Projectile
extends Area2D

## ONE projectile scene for the entire game -- player syringes and enemy spit
## both. It renders whatever the stat block tells it to. Adding a visually
## distinct item must never mean adding a new projectile scene.

const BASE_RADIUS: float = 6.0

## The walls layer, as a mask. Walls and cover are the same layer and the same
## StaticBody2D treatment, so "stops at a wall" and "stops at a crate" need no
## separate cases here.
const WALL_MASK: int = 1 << 4

var stats: AttackStats
var direction: Vector2 = Vector2.RIGHT
## Who this shot is looking for. Lets enemies reuse the same scene.
var target_group: StringName = &"enemies"

var _age: float = 0.0
var _pierced: int = 0
var _hit_ids: Array[int] = []
var _target: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var trail: Line2D = $Trail
@onready var shape: CollisionShape2D = $CollisionShape2D


func setup(p_stats: AttackStats, p_direction: Vector2, p_target_group: StringName = &"enemies") -> void:
	# Caller passes an already-resolved block. Projectile does no item logic.
	stats = p_stats
	direction = p_direction.normalized()
	target_group = p_target_group


func _ready() -> void:
	if stats == null:
		push_error("Projectile spawned without stats.")
		queue_free()
		return

	if stats.sprite_override:
		sprite.texture = stats.sprite_override
		sprite.self_modulate = stats.tint
		sprite.scale = Vector2.ONE * stats.scale_mult
	else:
		sprite.visible = false  # placeholder art comes from _draw()

	var circle := CircleShape2D.new()
	circle.radius = BASE_RADIUS * stats.scale_mult
	shape.shape = circle

	# Line2D must live in world space or every point collapses onto the
	# projectile's own origin and the trail renders as a single dot.
	trail.top_level = true
	trail.visible = stats.trail_enabled
	trail.default_color = Color(stats.tint, 0.55)
	trail.width = 3.0 * stats.scale_mult

	# Grouped so a room transition can sweep shots that are still in flight.
	add_to_group(&"projectiles")
	area_entered.connect(_on_area_entered)
	# Cover and walls stop a shot dead. Bodies, not areas: the room's geometry is
	# StaticBody2D, while everything that can be HIT is an Area2D hurtbox -- so
	# the two callbacks never see each other's traffic and neither needs to sort
	# out which it just got.
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _draw() -> void:
	if stats == null or stats.sprite_override:
		return
	var r := BASE_RADIUS * stats.scale_mult
	# Glow reads as a soft halo rather than a second colour channel.
	if stats.glow_energy > 0.0:
		draw_circle(Vector2.ZERO, r * (1.0 + stats.glow_energy), Color(stats.tint, 0.25))
	draw_circle(Vector2.ZERO, r, stats.tint)
	draw_circle(Vector2.ZERO, r * 0.45, stats.tint.lightened(0.6))


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= stats.lifetime:
		queue_free()
		return

	if stats.homing_strength > 0.0:
		_steer_toward_target(delta)

	var travel := direction
	if stats.wobble_amplitude > 0.0:
		var offset := sin(_age * stats.wobble_frequency * TAU) * stats.wobble_amplitude
		travel = direction.rotated(deg_to_rad(offset))

	var from := global_position
	global_position += travel * stats.speed * delta
	rotation = travel.angle()

	# Overlap alone is not enough to stop a shot at a wall. A fast build moves
	# the projectile further in one frame than the wall is thick, so it can start
	# the frame in front of the wall and end it behind, never overlapping on any
	# frame the physics server looks at. The step is swept instead, so speed can
	# be scaled by items without quietly turning shots into ghosts.
	if _sweep_into_wall(from, global_position):
		return

	if stats.trail_enabled:
		_update_trail()


## Stops the shot at the first wall between `from` and `to`, if there is one.
## Returns whether it died, so the caller stops touching a freed node.
##
## The impact is placed at the contact point rather than at wherever the step
## happened to land, or a shot into a wall puffs its impact effect inside it.
func _sweep_into_wall(from: Vector2, to: Vector2) -> bool:
	if from.is_equal_approx(to):
		return false
	var query := PhysicsRayQueryParameters2D.create(from, to, WALL_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	global_position = hit["position"]
	_spawn_impacts()
	queue_free()
	return true


## Ran into cover it was already inside of -- a shot fired from a muzzle that is
## itself in a wall, which the sweep cannot see because both ends of the step are
## behind the surface.
func _on_body_entered(_body: Node2D) -> void:
	_spawn_impacts()
	queue_free()


func _steer_toward_target(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = _find_nearest_target()
	if _target == null:
		return
	var desired := (_target.global_position - global_position).normalized()
	direction = direction.lerp(desired, stats.homing_strength * delta * 8.0).normalized()


func _find_nearest_target() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for e in get_tree().get_nodes_in_group(target_group):
		if e is not Node2D:
			continue
		var d := global_position.distance_squared_to((e as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best


func _update_trail() -> void:
	# top_level means trail points are already world coordinates.
	trail.add_point(global_position)
	while trail.get_point_count() > maxi(stats.trail_length, 2):
		trail.remove_point(0)


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group(target_group):
		return
	# Intangible right now (a dashing player). Not recorded as a hit either, so
	# the shot can still catch him on the way out of the dash.
	if area.has_method(&"is_intangible") and area.is_intangible():
		return
	# Pierce must not re-hit the same body every physics frame.
	var id := area.get_instance_id()
	if id in _hit_ids:
		return
	_hit_ids.append(id)

	var dmg := stats.damage
	var is_crit := randf() < stats.crit_chance
	if is_crit:
		dmg *= stats.crit_multiplier

	if area.has_method(&"take_damage"):
		area.take_damage(dmg, direction * stats.knockback, stats.statuses, is_crit)

	_spawn_impacts()

	_pierced += 1
	if _pierced > stats.pierce_count:
		queue_free()


func _spawn_impacts() -> void:
	for scene in stats.impact_effects:
		var fx := scene.instantiate() as Node2D
		get_tree().current_scene.add_child(fx)
		fx.global_position = global_position
		if fx is CanvasItem:
			(fx as CanvasItem).modulate = stats.tint  # impacts inherit the build's colour
