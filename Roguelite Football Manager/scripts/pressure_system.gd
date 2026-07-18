class_name PressureSystem
extends RefCounted

## Calculates team pressure from momentum, possession, territory, and tactical style.
## Pressure drives chance generation — higher pressure → more/better chances.

## Territory calculation constants
const PITCH_WIDTH := 1280.0
const PITCH_LEFT := 0.0
const PITCH_RIGHT := 1280.0
const OPPONENT_HALF_THRESHOLD := PITCH_WIDTH / 2.0  # 640px

## Weights for pressure calculation
const MOMENTUM_WEIGHT := 0.30  # Momentum contributes 30% of pressure
const POSSESSION_WEIGHT := 0.25  # Possession contributes 25%
const TERRITORY_WEIGHT := 0.25  # Territory contributes 25%
const TACTICAL_WEIGHT := 0.20  # Tactical style contributes 20%

## Pressure thresholds for chance generation (Designer-approved)
const SMALL_CHANCE_THRESHOLD := 40.0
const GOOD_CHANCE_THRESHOLD := 60.0
const BIG_CHANCE_THRESHOLD := 80.0
const CLEAR_CHANCE_THRESHOLD := 90.0

func calculate_pressure(team_state: TeamMatchState, movement_system: PlayerMovementSystem, is_home: bool) -> float:
	## Returns pressure (0-100) for a team based on momentum, possession, territory, and tactics.

	if team_state == null or movement_system == null:
		return 50.0

	## Momentum contribution: normalize to 0-100 range
	var momentum_contribution = (team_state.momentum + 100.0) * 0.5  # -100→0, +100→100

	## Possession contribution: already 0-100
	var possession_contribution = team_state.possession_pct

	## Territory contribution: calculate from current player positions
	var territory_contribution = _calculate_territory(movement_system, is_home)
	team_state.territory_pct = territory_contribution  # Update state

	## Tactical contribution: some styles are naturally more/less pressuring
	var tactical_contribution = _get_tactical_pressure_modifier(team_state.tactical_style)

	## Weighted average
	var pressure = (momentum_contribution * MOMENTUM_WEIGHT +
		possession_contribution * POSSESSION_WEIGHT +
		territory_contribution * TERRITORY_WEIGHT +
		tactical_contribution * TACTICAL_WEIGHT)

	return clamp(pressure, 0.0, 100.0)

func get_chance_type(pressure: float) -> String:
	## Returns the type of chance generated at this pressure level.
	if pressure >= CLEAR_CHANCE_THRESHOLD:
		return "Clear-Cut"
	elif pressure >= BIG_CHANCE_THRESHOLD:
		return "Big"
	elif pressure >= GOOD_CHANCE_THRESHOLD:
		return "Good"
	elif pressure >= SMALL_CHANCE_THRESHOLD:
		return "Small"
	else:
		return "None"

func get_xg_for_chance(chance_type: String) -> float:
	## Returns expected goal value for each chance type.
	match chance_type:
		"Clear-Cut":
			return randf_range(0.65, 0.95)
		"Big":
			return randf_range(0.45, 0.65)
		"Good":
			return randf_range(0.20, 0.45)
		"Small":
			return randf_range(0.05, 0.20)
		_:
			return 0.0

func _calculate_territory(movement_system: PlayerMovementSystem, is_home: bool) -> float:
	## Territory % based on:
	## - Count of players in opponent's half
	## - Average x-position of all fielded players
	## Returns 0-100 representing dominance in opponent territory.

	var home_lineup = movement_system.home_lineup
	var away_lineup = movement_system.away_lineup
	var attacking_lineup = home_lineup if is_home else away_lineup
	var defending_lineup = away_lineup if is_home else home_lineup

	if attacking_lineup == null or attacking_lineup.size() == 0:
		return 50.0

	## Count attacking players in opponent's half
	var attacking_in_opponent_half = 0
	var defending_in_opponent_half = 0
	var total_attacking_x = 0.0

	## Attacking team players in opponent's half (pushed forward)
	for i in range(attacking_lineup.size()):
		if attacking_lineup[i] == null:
			continue
		var pos = movement_system.get_player_position(is_home, i)
		if pos == Vector2.ZERO:
			continue
		total_attacking_x += pos.x

		var is_in_opponent_half = (is_home and pos.x > OPPONENT_HALF_THRESHOLD) or (not is_home and pos.x < OPPONENT_HALF_THRESHOLD)
		if is_in_opponent_half:
			attacking_in_opponent_half += 1

	## Defending team players in their own half (retreated)
	for i in range(defending_lineup.size()):
		if defending_lineup[i] == null:
			continue
		var pos = movement_system.get_player_position(not is_home, i)
		if pos == Vector2.ZERO:
			continue

		var is_in_own_half = (is_home and pos.x < OPPONENT_HALF_THRESHOLD) or (not is_home and pos.x > OPPONENT_HALF_THRESHOLD)
		if is_in_own_half:
			defending_in_opponent_half += 1

	## Territory calculation:
	## - Attacking players in opponent half: 0-11 → 0-55 contribution
	## - Defending players NOT in opponent half (retreat): 0-11 → 0-45 contribution
	var territory = (attacking_in_opponent_half * 5.0) + ((11 - defending_in_opponent_half) * 4.0)
	territory = clamp(territory, 0.0, 100.0)

	return territory

func _get_tactical_pressure_modifier(tactical_style: String) -> float:
	## Some tactical styles naturally apply more or less pressure.
	## Returns a 0-100 base for tactical contribution.
	match tactical_style:
		"High Press":
			return 75.0  # Aggressive pressing = high base pressure
		"Possession":
			return 60.0  # Control-oriented, moderate pressure
		"Counter Attack":
			return 40.0  # Defensive waiting, lower base pressure
		"Park The Bus":
			return 30.0  # Ultra-defensive, minimal pressure
		"Long Ball":
			return 50.0  # Balanced, direct approach
		_:
			return 50.0  # Default middle ground
