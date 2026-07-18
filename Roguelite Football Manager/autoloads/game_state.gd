extends Node

signal club_created(club_data: ClubData)
signal squad_generated(squad: Array[Player])
signal lineup_changed

var club: ClubData = null
var squad: Array[Player] = []

## Pre-match setup state.
var formation: Formation = null
var lineup: Array[Player] = []  # Player or null, index-aligned with formation.slots
var captain: Player = null

## Result of the most recently played match (transient, not persisted in saves).
var last_match_result: MatchResult = null

## Opponent generated for the upcoming live match (transient, not persisted in saves).
## Dictionary with keys: name, formation, lineup (see OpponentLineupBuilder.build()).
var pending_opponent: Dictionary = {}

## Persistent condition recovered per match cycle for the whole squad — see
## BALANCE.md "Persistent Condition (Fatigue)".
const PERSISTENT_CONDITION_RECOVERY := 25.0

## Applies end-of-match persistent condition changes to the whole squad:
## every squad player recovers PERSISTENT_CONDITION_RECOVERY (simulating one
## match cycle of rest), then anyone who actually appeared in this match has
## their persistent condition overwritten with their final in-match Condition.
func finish_match(live_match_state: LiveMatchState) -> void:
	for player in squad:
		player.persistent_condition = min(100.0, player.persistent_condition + PERSISTENT_CONDITION_RECOVERY)
	for player in live_match_state.conditions:
		if squad.has(player):
			player.persistent_condition = live_match_state.conditions[player]

func create_club(club_name: String, primary_color: Color, secondary_color: Color, badge_shape: ClubData.BadgeShape) -> ClubData:
	var data := ClubData.new()
	data.club_name = club_name
	data.primary_color = primary_color
	data.secondary_color = secondary_color
	data.badge_shape = badge_shape
	club = data
	# A new club discards any prior squad, so pre-match setup state referencing
	# the old squad's players would otherwise dangle.
	formation = null
	lineup = []
	captain = null
	pending_opponent = {}
	last_match_result = null
	club_created.emit(club)
	return club

func generate_squad() -> Array[Player]:
	squad = SquadGenerator.generate_squad()
	squad_generated.emit(squad)
	return squad

func set_formation(new_formation: Formation) -> void:
	formation = new_formation
	var previous_lineup := lineup
	lineup = []
	lineup.resize(formation.slots.size())
	# Carry over players who are still eligible for their slot's category under the new formation.
	for i in lineup.size():
		if i < previous_lineup.size() and previous_lineup[i] != null:
			var player: Player = previous_lineup[i]
			if PositionCompatibility.is_eligible(player, formation.slots[i]):
				lineup[i] = player
	if captain != null and not lineup.has(captain):
		captain = null
	lineup_changed.emit()

func assign_to_slot(slot_index: int, player: Player) -> void:
	# Remove the player from any other slot first (a player can only occupy one slot).
	for i in lineup.size():
		if lineup[i] == player:
			lineup[i] = null
	lineup[slot_index] = player
	lineup_changed.emit()

func clear_slot(slot_index: int) -> void:
	lineup[slot_index] = null
	if captain != null and not lineup.has(captain):
		captain = null
	lineup_changed.emit()

func set_captain(player: Player) -> void:
	captain = player
	lineup_changed.emit()

func get_bench() -> Array[Player]:
	var bench: Array[Player] = []
	for player in squad:
		if not lineup.has(player):
			bench.append(player)
	return bench
