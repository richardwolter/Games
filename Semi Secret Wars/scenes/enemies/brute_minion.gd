class_name BruteMinion
extends Minion
## Stage 3 minion variant (placeholder): tanky melee bruiser — high HP and
## damage, slower than the base swarm, forces heroes to commit to a fight
## rather than kiting through.
##
## Reuses the Minion AI (hunt, intercept targeting, goal-based fallback);
## stats are tuned in brute_minion.tscn.

func _configure() -> void:
	super()
