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
## Roll speed along `direction`. Faster than any unit's move_speed, so it
## always arrives rather than being outrun.
var speed := 260.0
var damage := 18.0
## Rolls until it passes this x, then frees itself. Only consulted for the
## lane-length environmental roll (direction still LEFT) — an aimed throw uses
## max_travel instead, since "past this x" is meaningless off the -x axis.
var despawn_x := -3000.0

## -- Aimed throw support (Designer, 2026-07-26) -------------------------------
## The Berserker hurls smaller boulders at heroes, which is the same object
## with three things varied rather than a second class: which way it goes, how
## far it survives, and who it can hit.
##
## Note that piercing needs no flag — this thing was ALWAYS piercing. It has no
## on-hit destruction, it just keeps rolling and `_hit` stops it re-hitting the
## same victim, so every unit along its path takes the damage exactly once.
## That is precisely the "piercing damage" behaviour the throw wants, so the
## thrown variant is a retune, not a new mechanic.
var direction := Vector2.LEFT
## Distance travelled before it frees itself. <= 0 falls back to the despawn_x
## rule above, which is what the lane roll keeps using.
var max_travel := 0.0
## Groups whose members it damages. The environmental roll deliberately mows
## down the swarm too; an aimed throw is the Berserker's own attack, so it is
## narrowed to heroes at the call site.
var hit_groups: Array = ["heroes", "hostiles"]
## Credited as the damage source when set — so a hero killed by a thrown rock
## records the Berserker as the killer. Left null by the environmental roll,
## which is nobody's attack (see _damage_overlaps).
var attacker: Combatant = null

var _travelled := 0.0

## Each victim is hit ONCE per boulder — without this a unit that can't get out
## of the way (stunned, blocked, or simply slower) would take a hit every frame
## the boulder overlapped it and die instantly. One boulder = one hit.
var _hit: Dictionary = {}

func _process(delta: float) -> void:
	var step := speed * delta
	global_position += direction.normalized() * step
	_travelled += step
	# Visual roll: arc length / radius is the honest angular speed, so the
	# rock's spin matches how fast it's actually travelling. Signed by which way
	# it's heading, so a boulder thrown rightward doesn't spin backwards.
	rotation += (speed / radius * delta) * (-1.0 if direction.x <= 0.0 else 1.0)
	_damage_overlaps()
	if max_travel > 0.0:
		if _travelled >= max_travel:
			queue_free()
	elif global_position.x <= despawn_x:
		queue_free()

func _damage_overlaps() -> void:
	for group in hit_groups:
		for node in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node) or node._dying:
				continue
			if _hit.has(node.get_instance_id()):
				continue
			if global_position.distance_to(node.global_position) > radius + node.body_radius:
				continue
			_hit[node.get_instance_id()] = true
			# `attacker` is null for the environmental roll — nobody gets kill
			# credit or XP for a rock, same as the lake/spike hazards (see
			# Combatant._take_hazard_damage). A thrown one names its thrower.
			node.take_damage(damage, attacker)

func _draw() -> void:
	var tex_size := SPRITE.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var draw_size := tex_size * (radius * 2.0 / maxf(tex_size.x, tex_size.y))
	draw_texture_rect(SPRITE, Rect2(-draw_size * 0.5, draw_size), false)
