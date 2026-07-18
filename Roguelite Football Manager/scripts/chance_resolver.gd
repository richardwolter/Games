class_name ChanceResolver
extends RefCounted

## Resolves a chance into a goal/save/off-target outcome.
## Uses xG + striker quality + goalkeeper defense in the calculation.

signal chance_resolved(is_home: bool, shooter: Player, outcome: String, xg: float)

func resolve_chance(chance: Chance, match_state: LiveMatchState) -> String:
	## Resolve a chance to GOAL, SAVED, or OFF_TARGET.
	## Returns the outcome string.

	if chance.striker == null:
		return "OFF_TARGET"

	# Get the goalkeeper for the defending side
	var defending_lineup = match_state.away_lineup if chance.is_home else match_state.home_lineup
	var goalkeeper = _get_goalkeeper(defending_lineup)

	# Calculate shot success probability
	var base_xg = chance.xg
	var striker_quality = _get_striker_quality(chance.striker, match_state)
	var goalkeeper_defense = _get_goalkeeper_defense(goalkeeper, match_state) if goalkeeper else 1.0

	# Final probability: xG × striker quality × (1 / goalkeeper defense)
	# High xG + good striker + weak goalkeeper → high goal chance
	# Low xG + weak striker + great goalkeeper → low goal chance
	var goal_probability = base_xg * striker_quality / goalkeeper_defense
	goal_probability = clamp(goal_probability, 0.01, 0.99)  # Never 0% or 100%

	# Roll the dice
	var outcome: String
	if randf() < goal_probability:
		outcome = "GOAL"
	else:
		# Distinguish between saved and off-target
		# Better strikers are more likely to at least hit the target
		var target_probability = 0.6 + (chance.striker.kick / 100.0) * 0.2  # 60-80%
		if randf() < target_probability:
			outcome = "SAVED"
		else:
			outcome = "OFF_TARGET"

	chance_resolved.emit(chance.is_home, chance.striker, outcome, base_xg)
	return outcome

func _get_goalkeeper(lineup: Array) -> Player:
	## Get the first (and only) goalkeeper in a lineup.
	for player in lineup:
		if player != null and player.position == "GK":
			return player
	return null

func _get_striker_quality(striker: Player, match_state: LiveMatchState) -> float:
	## Striker quality multiplier (1.0 = average, <1.0 = weaker, >1.0 = better).
	## Based on Kick stat + current condition.
	if striker == null:
		return 1.0

	var kick_stat = striker.kick / 100.0  # Normalize to 0-1
	var condition = match_state.get_condition(striker) / 100.0  # 0-1
	var quality = 0.7 + (kick_stat * 0.4)  # 0.7 (70-Kick player) to 1.1 (100-Kick player)
	quality *= (0.5 + condition * 0.5)  # Condition modifies: 50% effective when exhausted, 100% when fresh
	return clamp(quality, 0.3, 1.5)

func _get_goalkeeper_defense(goalkeeper: Player, match_state: LiveMatchState) -> float:
	## Goalkeeper defense multiplier (1.0 = average).
	## Higher multiplier = harder to score (goalkeeper is better).
	if goalkeeper == null:
		return 1.0

	var strength_stat = goalkeeper.strength / 100.0
	var condition = match_state.get_condition(goalkeeper) / 100.0
	var defense = 0.85 + (strength_stat * 0.3)  # 0.85 (70-Strength keeper) to 1.15 (100-Strength keeper)
	defense *= (0.5 + condition * 0.5)
	return clamp(defense, 0.5, 1.5)
