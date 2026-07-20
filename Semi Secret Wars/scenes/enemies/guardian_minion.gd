class_name GuardianMinion
extends Combatant
## Stationary minion that anchors itself on a field objective (GDD placeholder).
##
## Never moves (no goal, zero chase) — it just sits on its objective and fights
## whatever wanders into range. Since it never leaves, it's permanently within
## CaptureObjective's contest_radius, so the objective can't be captured until
## this dies (reusing CaptureObjective's existing contest logic, no changes
## needed there).

## Index into LaneField.objective_positions — which objective this guards.
@export var objective_index := 0

func _configure() -> void:
	self_group = "hostiles"
	enemy_group = "heroes"
	label_text = "GUARDIAN"
	var field: LaneField = get_tree().get_first_node_in_group("field")
	if field != null:
		if objective_index < field.objective_positions.size():
			global_position = field.objective_positions[objective_index]
		else:
			global_position = field.objective_pos

## Anchored: knockback would otherwise shove it off the objective it's
## guarding, and since it never has a goal to walk back with, it would just
## sit wherever it landed instead of contesting. Absorb the splash damage
## but skip the actual displacement.
func apply_knockback(direction: Vector2, _distance: float, splash_damage: float, source: Combatant) -> void:
	super(direction, 0.0, splash_damage, source)
