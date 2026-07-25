class_name ArrowBarrage
extends Node2D
## ARTEMIS+BEACON Duo Ultimate ("Piercing Volley", see DuoUltimates/
## Hero.cast_duo_ultimate): instantly resolves a burst of up to arrow_count
## hits on the nearest enemies within hit_range, each chaining onward to up
## to chain_count further nearby enemies at chain_damage_mult of the
## original arrow's damage. Resolves instantly on spawn — same "instant
## burst + brief flash" style every other hero ability in this game uses
## (Stomp/Ensnare/Shockwave never simulated real projectile travel either);
## only the flash lines are timed, purely visual.
##
## NOT named `range` — that shadows GDScript's builtin range() and would
## break every `for i in range(...)` loop in this very script.
##
## Ability-cadence pass (2026-07-24): per-arrow damage used to be
## caster.damage (Artemis's live attack damage, ~3 effective) instead of a
## flat catalog constant like every other Duo Ultimate — the whole
## once-per-level cast dealt roughly 36 total. Now `arrow_damage`, still
## scaled by the same Duo/objective mults every other ultimate uses.

var caster: Hero = null
var arrow_count := 6
var chain_count := 2
var chain_damage_mult := 0.5
var hit_range := 260.0
var arrow_damage := 55.0

## How far a chain hop may reach from its previous link to find its next,
## not-yet-hit victim.
const CHAIN_RADIUS := 140.0
const VISUAL_LIFETIME := 0.35
const LINE_COLOR := Color(0.9, 0.85, 0.3, 0.85)

var _hit_lines: Array[Vector2] = []  # local-space (from, to) pairs, flattened
var _life_t := VISUAL_LIFETIME

func _ready() -> void:
	_resolve()
	queue_redraw()

func _process(delta: float) -> void:
	_life_t -= delta
	if _life_t <= 0.0:
		queue_free()
		return
	queue_redraw()

func _resolve() -> void:
	if caster == null or not is_instance_valid(caster):
		return
	var candidates: Array[Combatant] = []
	for node in get_tree().get_nodes_in_group(caster.enemy_group):
		if not is_instance_valid(node) or node._dying or not caster._lane_ok(node):
			continue
		if global_position.distance_to(node.global_position) <= hit_range:
			candidates.append(node)
	candidates.sort_custom(func(a, b) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))

	var per_arrow_damage: float = arrow_damage * caster._duo_damage_mult * caster.damage_mult()
	var hit_already: Array[Combatant] = []
	var arrows_fired := 0
	for primary in candidates:
		if arrows_fired >= arrow_count:
			break
		if primary in hit_already:
			continue
		arrows_fired += 1
		primary.take_damage(per_arrow_damage, caster)
		hit_already.append(primary)
		_hit_lines.append(to_local(global_position))
		_hit_lines.append(to_local(primary.global_position))

		var chain_from: Combatant = primary
		for _c in chain_count:
			var next_hit := _nearest_unhit(chain_from.global_position, hit_already)
			if next_hit == null:
				break
			next_hit.take_damage(per_arrow_damage * chain_damage_mult, caster)
			hit_already.append(next_hit)
			_hit_lines.append(to_local(chain_from.global_position))
			_hit_lines.append(to_local(next_hit.global_position))
			chain_from = next_hit

func _nearest_unhit(from: Vector2, exclude: Array) -> Combatant:
	var best: Combatant = null
	var best_d := CHAIN_RADIUS * CHAIN_RADIUS
	for node in get_tree().get_nodes_in_group(caster.enemy_group):
		if not is_instance_valid(node) or node._dying or node in exclude or not caster._lane_ok(node):
			continue
		var d := from.distance_squared_to(node.global_position)
		if d <= best_d:
			best_d = d
			best = node
	return best

func _draw() -> void:
	var alpha_mult := clampf(_life_t / VISUAL_LIFETIME, 0.0, 1.0)
	var c := LINE_COLOR
	c.a *= alpha_mult
	var i := 0
	while i + 1 < _hit_lines.size():
		draw_line(_hit_lines[i], _hit_lines[i + 1], c, 2.5)
		i += 2
