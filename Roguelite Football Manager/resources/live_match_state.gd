class_name LiveMatchState
extends RefCounted

## Match data holder — score, events, conditions, subs, formation. See
## BALANCE.md "Live Match Simulation". First-pass placeholder — not
## designer-reviewed. Only the home side can substitute this milestone; the
## opponent lineup is fixed for the full match.
##
## Milestone 17: no longer decides match events itself — MatchDecisionEngine
## (real-time, position-driven) owns that now and calls record_shot_result()
## here to update score/events. This class only tracks state and the clock.

## Emitted for UI/visual layers (e.g. the live match pitch view) to react to
## without parsing the `events` text log. Purely additive — no gameplay effect.
signal goal_scored(is_home: bool, scorer: Player)
## Emitted for every shot attempt (including goals) so a visual layer can
## play a kick/ball-flight animation on near-misses too, not just goals.
signal shot_attempt(is_home: bool, shooter: Player, outcome: String)
signal substitution_made(slot_index: int, incoming: Player, outgoing: Player)
signal formation_changed

const MATCH_MINUTES := 90
const MAX_SUBS := 5
const STARTING_CONDITION := 100.0
const BASE_CONDITION_DRAIN := 0.6
const CONDITION_DRAIN_STAMINA_MITIGATION := 0.5
const CONDITION_FLOOR_MULTIPLIER := 0.5

var home_name: String = ""
var away_name: String = ""
var home_formation: Formation
var away_formation: Formation
var home_lineup: Array
var away_lineup: Array
var home_bench: Array

var conditions: Dictionary = {}  # Player -> float
var minute: int = 0
var home_score: int = 0
var away_score: int = 0
var events: Array[String] = []
var subs_used: int = 0
var finished: bool = false

## Ball state for possession/movement/decision systems.
var ball_state: BallState = null

func _init(p_home_name: String, p_home_formation: Formation, p_home_lineup: Array, p_home_bench: Array,
		p_away_name: String, p_away_formation: Formation, p_away_lineup: Array) -> void:
	home_name = p_home_name
	home_formation = p_home_formation
	home_lineup = p_home_lineup.duplicate()
	home_bench = p_home_bench.duplicate()
	away_name = p_away_name
	away_formation = p_away_formation
	away_lineup = p_away_lineup.duplicate()
	for player in home_lineup:
		if player != null:
			conditions[player] = player.persistent_condition
	for player in away_lineup:
		if player != null:
			conditions[player] = player.persistent_condition
	for player in home_bench:
		if player != null and not conditions.has(player):
			conditions[player] = player.persistent_condition
	## Milestone 14: Initialize ball state at center of pitch.
	## Pitch dimensions: 1280px wide, grass from y=64 to y=896 (center ~480).
	ball_state = BallState.new(Vector2(640, 480))

## Called once per simulated minute by the real-time match clock (live_match.gd)
## — advances the minute counter, drains condition, and checks for full time.
## Score/events now come from record_shot_result(), driven by
## MatchDecisionEngine's real-time shot events, not from this tick.
func advance_minute() -> void:
	if finished:
		return
	minute += 1
	_decay(home_lineup)
	_decay(away_lineup)

	if minute >= MATCH_MINUTES:
		finished = true
		events.append("Full time: %s %d - %d %s" % [home_name, home_score, away_score, away_name])

func can_substitute() -> bool:
	return subs_used < MAX_SUBS and not finished

func substitute(slot_index: int, incoming: Player) -> bool:
	if not can_substitute():
		return false
	if slot_index < 0 or slot_index >= home_lineup.size():
		return false
	if not home_bench.has(incoming):
		return false
	var outgoing: Player = home_lineup[slot_index]
	if outgoing == null:
		return false
	home_lineup[slot_index] = incoming
	home_bench.erase(incoming)
	home_bench.append(outgoing)
	conditions[incoming] = incoming.persistent_condition
	subs_used += 1
	events.append("%d' SUB (%s): %s off, %s on" % [minute, home_name, outgoing.player_name, incoming.player_name])
	substitution_made.emit(slot_index, incoming, outgoing)
	return true

## Reassigns the current 11 starters into a new formation's slots (same
## players, new slot categories/order) — no subs, no condition reset.
func change_formation(new_formation: Formation, new_lineup: Array) -> void:
	home_formation = new_formation
	home_lineup = new_lineup.duplicate()
	events.append("%d' Formation change (%s): now playing %s" % [minute, home_name, new_formation.formation_name])
	formation_changed.emit()

func get_condition(player: Player) -> float:
	return conditions.get(player, STARTING_CONDITION)

func _decay(lineup: Array) -> void:
	for player in lineup:
		if player == null:
			continue
		var drain: float = BASE_CONDITION_DRAIN * (1.0 - (player.stamina / 100.0) * CONDITION_DRAIN_STAMINA_MITIGATION)
		conditions[player] = max(conditions[player] - drain, 0.0)

## Called by live_match.gd when MatchDecisionEngine resolves a shot: updates
## score/events on GOAL, always emits shot_attempt (so a visual layer can
## animate every attempt), and additionally emits goal_scored only for GOAL
## (unchanged contract from Milestone 12's pitch-view wiring).
func record_shot_result(is_home: bool, shooter: Player, outcome: String) -> void:
	var team_name: String = home_name if is_home else away_name

	if outcome == "GOAL":
		if is_home:
			home_score += 1
		else:
			away_score += 1
		var scorer_text: String = " — %s" % shooter.player_name if shooter != null else ""
		events.append("%d' GOAL! %s%s (%d-%d)" % [minute, team_name, scorer_text, home_score, away_score])
		goal_scored.emit(is_home, shooter)
	elif outcome == "SAVED":
		events.append("%d' Chance for %s — %s's shot is saved!" % [minute, team_name, shooter.player_name])
	else:
		events.append("%d' Chance for %s — %s shoots wide!" % [minute, team_name, shooter.player_name])

	shot_attempt.emit(is_home, shooter, outcome)
