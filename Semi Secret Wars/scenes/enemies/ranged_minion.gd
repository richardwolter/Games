class_name RangedMinion
extends Minion
## Stage 3 minion variant (placeholder): long attack_range simulates a
## ranged/projectile attacker (no projectile visual yet — hits on range
## like every other Combatant). Low HP, fast — a glass cannon in the swarm.
##
## Reuses the Minion AI (hunt, intercept targeting, goal-based fallback);
## stats are tuned in ranged_minion.tscn.

func _configure() -> void:
	super()
