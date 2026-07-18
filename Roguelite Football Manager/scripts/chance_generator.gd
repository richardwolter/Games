class_name ChanceGenerator
extends RefCounted

## Generates chances when pressure crosses thresholds or is sustained high.
## Per Designer decision: Option C - one chance per threshold crossing + bonus if sustained >80%.

signal chance_generated(chance: Chance)

## Threshold tracking (to detect crossings)
var home_last_pressure: float = 0.0
var away_last_pressure: float = 0.0

## Active chances per team
var home_active_chances: Array[Chance] = []
var away_active_chances: Array[Chance] = []

## Bonus chance logic
var home_sustained_high_pressure_time: float = 0.0  # How long has home pressure been >80%?
var away_sustained_high_pressure_time: float = 0.0
const HIGH_PRESSURE_BONUS_THRESHOLD := 80.0
const HIGH_PRESSURE_BONUS_INTERVAL := 15.0  # Spawn bonus chance every 15s of sustained high pressure

func update(home_pressure: float, away_pressure: float, home_lineup: Array, away_lineup: Array, current_time: float, delta_seconds: float) -> void:
	## Called each periodic update to check for threshold crossings and spawn chances.
	## Note: actual resolution of expired chances happens in LiveMatchState._auto_resolve_expired_chances()
	## so we do NOT remove them here — we only track them for expiry detection.

	## Check for home team threshold crossing
	_check_threshold_crossing(true, home_pressure, home_lineup, current_time)

	## Check for away team threshold crossing
	_check_threshold_crossing(false, away_pressure, away_lineup, current_time)

	## Check for high-pressure bonus chances
	_check_high_pressure_bonus(true, home_pressure, home_lineup, current_time, delta_seconds)
	_check_high_pressure_bonus(false, away_pressure, away_lineup, current_time, delta_seconds)

	## Update tracking
	home_last_pressure = home_pressure
	away_last_pressure = away_pressure

func _check_threshold_crossing(is_home: bool, current_pressure: float, lineup: Array, current_time: float) -> void:
	## Check if pressure has crossed a threshold (spawning a new chance).
	var last_pressure = home_last_pressure if is_home else away_last_pressure
	var active_chances = home_active_chances if is_home else away_active_chances

	# Check each threshold
	var thresholds = [
		{"pressure": 40.0, "type": "Small", "xg_range": [0.05, 0.20]},
		{"pressure": 60.0, "type": "Good", "xg_range": [0.20, 0.45]},
		{"pressure": 80.0, "type": "Big", "xg_range": [0.45, 0.65]},
		{"pressure": 90.0, "type": "Clear-Cut", "xg_range": [0.65, 0.95]},
	]

	for threshold_data in thresholds:
		var threshold_pressure = threshold_data["pressure"]
		# Detect crossing: was below, now at or above (or was above, now at or above at higher quality)
		if last_pressure < threshold_pressure and current_pressure >= threshold_pressure:
			var chance_type = threshold_data["type"]
			var xg_range = threshold_data["xg_range"]
			var xg = randf_range(xg_range[0], xg_range[1])
			_spawn_chance(is_home, chance_type, xg, lineup, current_time, active_chances)

func _check_high_pressure_bonus(is_home: bool, current_pressure: float, lineup: Array, current_time: float, delta_seconds: float) -> void:
	## If pressure sustained >80%, spawn bonus chance every 15 seconds.
	if current_pressure >= HIGH_PRESSURE_BONUS_THRESHOLD:
		if is_home:
			home_sustained_high_pressure_time += delta_seconds
			if home_sustained_high_pressure_time >= HIGH_PRESSURE_BONUS_INTERVAL:
				home_sustained_high_pressure_time -= HIGH_PRESSURE_BONUS_INTERVAL
				var xg = randf_range(0.45, 0.65)  # Big/Clear-cut quality
				_spawn_chance(is_home, "Big", xg, lineup, current_time, home_active_chances)
		else:
			away_sustained_high_pressure_time += delta_seconds
			if away_sustained_high_pressure_time >= HIGH_PRESSURE_BONUS_INTERVAL:
				away_sustained_high_pressure_time -= HIGH_PRESSURE_BONUS_INTERVAL
				var xg = randf_range(0.45, 0.65)
				_spawn_chance(is_home, "Big", xg, lineup, current_time, away_active_chances)
	else:
		# Reset timer when pressure drops below threshold
		if is_home:
			home_sustained_high_pressure_time = 0.0
		else:
			away_sustained_high_pressure_time = 0.0

func _spawn_chance(is_home: bool, chance_type: String, xg: float, lineup: Array, current_time: float, active_chances: Array[Chance]) -> void:
	## Spawn a chance with a pre-selected striker (highest-rated forward available).
	var striker = _select_striker(lineup)
	if striker == null:
		return  # No eligible players

	var chance = Chance.new(chance_type, xg, is_home, striker, current_time)
	active_chances.append(chance)
	chance_generated.emit(chance)

func _select_striker(lineup: Array) -> Player:
	## Select the highest-rated forward/attacker in the lineup.
	## Prioritize strikers (ST), then wings, then attacking midfielders.
	var candidates: Array[Player] = []

	for player in lineup:
		if player == null:
			continue
		# Prefer ST, then WING, then CAM
		var position = player.position
		if position == "ST":
			candidates.append(player)

	if candidates.is_empty():
		# Fallback to WING
		for player in lineup:
			if player != null and player.position == "WING":
				candidates.append(player)

	if candidates.is_empty():
		# Fallback to CAM
		for player in lineup:
			if player != null and player.position == "CAM":
				candidates.append(player)

	if candidates.is_empty():
		# No attackers, try CM
		for player in lineup:
			if player != null and player.position == "CM":
				candidates.append(player)

	if candidates.is_empty():
		return null

	# Return the highest-rated candidate
	var best = candidates[0]
	for candidate in candidates:
		if candidate.get_overall() > best.get_overall():
			best = candidate
	return best

func get_active_chances(is_home: bool) -> Array[Chance]:
	## Get all active chances for a team.
	return home_active_chances if is_home else away_active_chances

func clear_chances(is_home: bool) -> void:
	## Clear all chances for a team (e.g., on half-time).
	if is_home:
		home_active_chances.clear()
		home_sustained_high_pressure_time = 0.0
	else:
		away_active_chances.clear()
		away_sustained_high_pressure_time = 0.0
