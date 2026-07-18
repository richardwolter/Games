class_name EliteMinion
extends Minion
## Stage 2 minion variant: stronger, faster, more threatening than base minions.
##
## Reuses the Minion AI (hunt, intercept targeting, goal-based fallback) but with
## higher stats to make Stage 2 feel harder. Future stages can extend this with
## new abilities or behavior.

func _configure() -> void:
	super()
	# Base Minion _configure already sets self_group and enemy_group.
	# Stats are tuned in the scene (elite_minion.tscn).
