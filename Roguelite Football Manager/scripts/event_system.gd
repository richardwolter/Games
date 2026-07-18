class_name EventSystem
extends RefCounted

## Event system for match disruptions: fouls, yellow/red cards, injuries.
## Events are triggered probabilistically based on tackle intensity, aggression, and pressure.
## First-pass placeholder — not designer-reviewed.

signal event_occurred(event_type: String, is_home: bool, player: Player, severity: String)

## Foul/card triggers
const FOUL_BASE_CHANCE := 0.15  # 15% base foul chance on tackle
const AGGRESSION_MULTIPLIER := 0.005  # Each point of aggression adds 0.5% to foul chance
const PRESSURE_MULTIPLIER := 0.002  # Each point of pressure adds 0.2% to foul chance
const YELLOW_CARD_THRESHOLD := 1  # Earn yellow on first foul
const RED_CARD_THRESHOLD := 2  # Earn red on second foul (or straight red on very aggressive play)

## Injury triggers
const INJURY_BASE_CHANCE := 0.02  # 2% base injury chance on tackle
const INJURY_INTENSITY_MULTIPLIER := 0.01  # High-intensity play increases injury risk

## Discipline tracking per player (fouls accumulated)
var player_discipline: Dictionary = {}  # Player -> foul_count

## Recent events for narrative/commentary (not implemented yet)
var recent_match_events: Array = []

func reset() -> void:
	player_discipline.clear()
	recent_match_events.clear()

## Called when a tackle/collision occurs (from MatchDecisionEngine).
## is_defender: true if the defending player is the one making the tackle.
func check_tackle_event(is_home: bool, defender: Player, attacker: Player,
		team_state: TeamMatchState, delta_seconds: float) -> void:
	if defender == null or attacker == null:
		return

	## Check for foul (defending player at fault)
	var foul_chance = FOUL_BASE_CHANCE
	foul_chance += (team_state.aggression * AGGRESSION_MULTIPLIER)
	foul_chance += (team_state.pressure_level * PRESSURE_MULTIPLIER)
	foul_chance = clamp(foul_chance, 0.05, 0.6)  # Clamp to 5-60% range

	if randf() < foul_chance:
		_apply_foul(is_home, defender, attacker)

	## Check for injury (higher chance on rough challenges)
	var injury_chance = INJURY_BASE_CHANCE
	if team_state.aggression > 70.0:
		injury_chance += INJURY_INTENSITY_MULTIPLIER * (team_state.aggression - 70.0)
	injury_chance = clamp(injury_chance, 0.01, 0.15)

	if randf() < injury_chance:
		var injured_player = attacker if randf() < 0.6 else defender  # 60% chance attacker, 40% defender
		_apply_injury(is_home, injured_player)

func _apply_foul(is_home: bool, fouling_player: Player, fouled_player: Player) -> void:
	## Apply foul consequences: card escalation and momentum penalty.
	var current_fouls = player_discipline.get(fouling_player, 0)
	player_discipline[fouling_player] = current_fouls + 1

	if current_fouls == 0:
		## First foul → Yellow Card
		recent_match_events.append({
			"type": "yellow_card",
			"player": fouling_player,
			"is_home": is_home
		})
		event_occurred.emit("yellow_card", is_home, fouling_player, "yellow")
	elif current_fouls >= YELLOW_CARD_THRESHOLD:
		## Second foul → Red Card (ejection)
		recent_match_events.append({
			"type": "red_card",
			"player": fouling_player,
			"is_home": is_home
		})
		event_occurred.emit("red_card", is_home, fouling_player, "red")

func _apply_injury(is_home: bool, injured_player: Player) -> void:
	## Apply injury: player becomes unavailable (removed from pitch).
	## In Phase 4, injury is tracked but actual pitch removal happens in Phase 5 UI wiring.
	recent_match_events.append({
		"type": "injury",
		"player": injured_player,
		"is_home": is_home
	})
	event_occurred.emit("injury", is_home, injured_player, "injury")

func get_player_fouls(player: Player) -> int:
	## Get foul count for a player (0, 1, or 2+).
	return player_discipline.get(player, 0)

func is_player_sent_off(player: Player) -> bool:
	## Check if player has been red-carded (fouls >= 2).
	return player_discipline.get(player, 0) >= RED_CARD_THRESHOLD
