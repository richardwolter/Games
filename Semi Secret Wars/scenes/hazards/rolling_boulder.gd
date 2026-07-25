class_name RollingBoulder
extends Node2D
## A boulder the Berserker hurls down a lane (Designer, 2026-07-25): it enters
## from the villain's end and rolls straight toward the deploy end, damaging
## EVERYTHING it touches on the way — heroes and his own swarm alike. Replaces
## the old static "boulder" obstacle kind, which just sat there as one more
## rock (the layouts now spell those out as rock1/rock2).
##
## Not a Combatant: it has no HP, can't be targeted, and isn't in any faction
## group — it's moving terrain, closer to a Poison Lake that walks.

const SPRITE := preload("res://assets/sprites/Boulder.png")

## Collision + art radius. Big enough that a lane can't be casually sidestepped
## without committing to one half of it (Designer, 2026-07-25: bigger — at 46
## it read as a pebble against the swarm).
var radius := 95.0
## Roll speed in -x (toward the party). Faster than any unit's move_speed, so
## it always arrives rather than being outrun.
var speed := 260.0
var damage := 18.0
## Rolls until it passes this x, then frees itself.
var despawn_x := -3000.0

## Each victim is hit ONCE per boulder — without this a unit that can't get out
## of the way (stunned, blocked, or simply slower) would take a hit every frame
## the boulder overlapped it and die instantly. One boulder = one hit.
var _hit: Dictionary = {}

func _process(delta: float) -> void:
	global_position.x -= speed * delta
	# Visual roll: arc length / radius is the honest angular speed, so the
	# rock's spin matches how fast it's actually travelling.
	rotation -= speed / radius * delta
	_damage_overlaps()
	if global_position.x <= despawn_x:
		queue_free()

func _damage_overlaps() -> void:
	for group in ["heroes", "hostiles"]:
		for node in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node) or node._dying:
				continue
			if _hit.has(node.get_instance_id()):
				continue
			if global_position.distance_to(node.global_position) > radius + node.body_radius:
				continue
			_hit[node.get_instance_id()] = true
			# No attacker: nobody gets kill credit or XP for a rock, same as
			# the lake/spike hazards (see Combatant._take_hazard_damage).
			node.take_damage(damage)

func _draw() -> void:
	var tex_size := SPRITE.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var draw_size := tex_size * (radius * 2.0 / maxf(tex_size.x, tex_size.y))
	draw_texture_rect(SPRITE, Rect2(-draw_size * 0.5, draw_size), false)
