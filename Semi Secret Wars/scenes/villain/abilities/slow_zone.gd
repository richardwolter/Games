extends Node2D
## Stage 3 Mech Robot ability: a timed AoE that slows any hero caught inside
## it (movement + attack rate, via Combatant.apply_slow). Self-contained and
## self-freeing — spawned as a sibling by MechRobot, not owned by it, so it
## keeps ticking even if the mech is mid-death-fade.

var radius := 60.0
var duration := 4.0
var slow_factor := 0.7

## Slow re-applies faster than it decays so heroes lingering in the zone
## stay slowed continuously rather than flickering in and out.
const TICK_INTERVAL := 0.3

var _t := 0.0
var _tick_cd := 0.0

func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	_tick_cd -= delta
	if _tick_cd <= 0.0:
		_tick_cd = TICK_INTERVAL
		for node in get_tree().get_nodes_in_group("heroes"):
			if is_instance_valid(node) and not node._dying \
					and global_position.distance_to(node.global_position) <= radius:
				node.apply_slow(TICK_INTERVAL + 0.05, slow_factor)
	queue_redraw()

func _draw() -> void:
	# A villain ability, so it reads in the enemy pigment rather than the blue
	# it used to share with friendly UI accents.
	draw_circle(Vector2.ZERO, radius, Color(UIStyle.VIOLET, 0.18))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(UIStyle.VIOLET, 0.5), 2.0, true)
