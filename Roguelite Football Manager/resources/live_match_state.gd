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

## Team match states (momentum, possession %, territory %, etc.)
var home_state: TeamMatchState = null
var away_state: TeamMatchState = null

## Systems for momentum/pressure calculation
var momentum_system: MomentumSystem = null
var tactical_system: TacticalSystem = null
var pressure_system: PressureSystem = null

## Chance generation and resolution systems
var chance_generator: ChanceGenerator = null
var chance_resolver: ChanceResolver = null

## Event system (fouls, cards, injuries — Phase 4)
var event_system: EventSystem = null

## Player movement system reference (used for territory calculation)
var movement_system_ref: PlayerMovementSystem = null

## Time tracking for chance resolution (in seconds)
var match_time_seconds: float = 0.0

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

	## Milestone 18: Initialize team match states and systems
	home_state = TeamMatchState.new()
	away_state = TeamMatchState.new()
	momentum_system = MomentumSystem.new()
	tactical_system = TacticalSystem.new()
	pressure_system = PressureSystem.new()

	## Milestone 18 Phase 3: Initialize chance systems
	chance_generator = ChanceGenerator.new()
	chance_resolver = ChanceResolver.new()

	## Milestone 18 Phase 4: Initialize event system
	event_system = EventSystem.new()

## Called once per simulated minute by the real-time match clock (live_match.gd)
## — advances the minute counter, drains condition, and checks for full time.
## Score/events now come from record_shot_result(), driven by
## MatchDecisionEngine's real-time shot events, not from this tick.
func advance_minute() -> void:
	if finished:
		return
	minute += 1
	match_time_seconds = minute * 60.0  # Update total match time
	_decay(home_lineup)
	_decay(away_lineup)

	if minute >= MATCH_MINUTES:
		finished = true
		events.append("Full time: %s %d - %d %s" % [home_name, home_score, away_score, away_name])
		## Clear any remaining chances at full-time
		if chance_generator:
			chance_generator.clear_chances(true)
			chance_generator.clear_chances(false)

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

## Called by live_match.gd to set the player movement system reference (needed for territory calculation).
func set_movement_system(movement_system: PlayerMovementSystem) -> void:
	movement_system_ref = movement_system

## Called periodically (every 2-5 real-time seconds) to update team states, momentum, and pressure.
func update_team_states(delta_seconds: float) -> void:
	if not momentum_system or not home_state or not away_state:
		return

	## Track possession time: whoever has the ball gets possession time added
	if ball_state != null and ball_state.possession_player != null:
		var is_home = home_lineup.has(ball_state.possession_player)
		if is_home:
			home_state.add_possession_time(delta_seconds)
		else:
			away_state.add_possession_time(delta_seconds)

	## Update possession percentages based on accumulated time
	home_state.update_possession_pct(home_state.possession_time_seconds, away_state.possession_time_seconds)
	away_state.update_possession_pct(home_state.possession_time_seconds, away_state.possession_time_seconds)

	## Apply natural momentum decay
	momentum_system.apply_decay(home_state)
	momentum_system.apply_decay(away_state)

	## Update team characteristics based on momentum and match state
	momentum_system.update_confidence(home_state)
	momentum_system.update_confidence(away_state)
	momentum_system.update_organization(home_state)
	momentum_system.update_organization(away_state)
	momentum_system.update_physical_energy(home_state, delta_seconds, minute * 60.0)
	momentum_system.update_physical_energy(away_state, delta_seconds, minute * 60.0)

	## Apply tactical modifiers to team states
	if tactical_system:
		tactical_system.apply_modifiers(home_state, home_formation, away_formation, true)
		tactical_system.apply_modifiers(away_state, home_formation, away_formation, false)

	## Calculate pressure for each team (uses territory calculation if movement_system available)
	if pressure_system and movement_system_ref:
		var home_pressure = pressure_system.calculate_pressure(home_state, movement_system_ref, true)
		var away_pressure = pressure_system.calculate_pressure(away_state, movement_system_ref, false)
		# Store pressure for later use by chance generator (Phase 3)
		home_state.pressure_level = home_pressure
		away_state.pressure_level = away_pressure

		## Milestone 18 Phase 3: Generate chances based on pressure
		if chance_generator:
			chance_generator.update(home_pressure, away_pressure, home_lineup, away_lineup, match_time_seconds, delta_seconds)

	## Auto-resolve chances that have expired (per Designer decision: chances stay live 10-30s)
	_auto_resolve_expired_chances()

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
			momentum_system.apply_event(home_state, "goal_scored")
			momentum_system.apply_event(away_state, "goal_conceded")
			momentum_system.reset_pass_chain(away_state)
		else:
			away_score += 1
			momentum_system.apply_event(away_state, "goal_scored")
			momentum_system.apply_event(home_state, "goal_conceded")
			momentum_system.reset_pass_chain(home_state)
		var scorer_text: String = " — %s" % shooter.player_name if shooter != null else ""
		events.append("%d' GOAL! %s%s (%d-%d)" % [minute, team_name, scorer_text, home_score, away_score])
		goal_scored.emit(is_home, shooter)
	elif outcome == "SAVED":
		if is_home:
			momentum_system.apply_event(away_state, "save")
			momentum_system.reset_pass_chain(home_state)
		else:
			momentum_system.apply_event(home_state, "save")
			momentum_system.reset_pass_chain(away_state)
		events.append("%d' Chance for %s — %s's shot is saved!" % [minute, team_name, shooter.player_name])
	else:
		events.append("%d' Chance for %s — %s shoots wide!" % [minute, team_name, shooter.player_name])

	shot_attempt.emit(is_home, shooter, outcome)

## Called when an event occurs (fouls, cards, injuries) to apply momentum penalties and event logging.
func apply_match_event(event_type: String, is_home: bool, player: Player, severity: String) -> void:
	var team_state = home_state if is_home else away_state
	var team_name = home_name if is_home else away_name

	match event_type:
		"yellow_card":
			events.append("%d' YELLOW CARD: %s (%s)" % [minute, player.player_name, team_name])
			momentum_system.apply_event(team_state, "yellow_card")
		"red_card":
			events.append("%d' RED CARD: %s (%s) — sent off!" % [minute, player.player_name, team_name])
			momentum_system.apply_event(team_state, "red_card")
		"injury":
			events.append("%d' INJURY: %s (%s) needs attention" % [minute, player.player_name, team_name])
			momentum_system.apply_event(team_state, "injury_own_player")

## Auto-resolve chances that have expired (duration exceeded without being taken).
func _auto_resolve_expired_chances() -> void:
	if not chance_generator or not chance_resolver:
		return

	## Check home team chances
	var home_chances = chance_generator.get_active_chances(true)
	var expired_home: Array[Chance] = []
	for chance in home_chances:
		if chance.is_expired(match_time_seconds) and not chance.taken:
			var outcome = chance_resolver.resolve_chance(chance, self)
			record_shot_result(true, chance.striker, outcome)
			chance.take()
			expired_home.append(chance)

	for chance in expired_home:
		home_chances.erase(chance)

	## Check away team chances
	var away_chances = chance_generator.get_active_chances(false)
	var expired_away: Array[Chance] = []
	for chance in away_chances:
		if chance.is_expired(match_time_seconds) and not chance.taken:
			var outcome = chance_resolver.resolve_chance(chance, self)
			record_shot_result(false, chance.striker, outcome)
			chance.take()
			expired_away.append(chance)

	for chance in expired_away:
		away_chances.erase(chance)
