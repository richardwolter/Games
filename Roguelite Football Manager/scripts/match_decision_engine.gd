class_name MatchDecisionEngine
extends RefCounted

## Milestone 17: single source of truth for ball-affecting match events —
## replaces the old resources/match_engine.gd (abstract per-minute
## duel/zone dice roll) and scripts/pass_system.gd (independent per-minute
## pass RNG). Every decision here is driven by real player positions (from
## PlayerMovementSystem) and real stat contests between the specific players
## involved, so what's shown on the pitch is what decides the score — not a
## separate roll happening invisibly alongside decorative movement.
## See BALANCE.md "Live Match Simulation" for the formulas below.

## Emitted whenever a shot is resolved (including goals) — LiveMatchState
## listens to update score/events, matching the old shot_attempt contract so
## the rest of the UI (pitch kick animation, goal celebration) is unchanged.
signal shot_taken(is_home: bool, shooter: Player, outcome: String)
## Emitted when a pass is attempted (success or not known yet from the
## visual's perspective) so the pitch view can animate the ball flight.
signal pass_started(is_home: bool, passer: Player, receiver: Player, start_pos: Vector2, end_pos: Vector2, duration: float)

## How often (seconds, randomized in this range) a ball carrier re-evaluates
## shoot/pass/dribble — randomized so decisions don't fall into a metronomic
## rhythm.
const DECISION_INTERVAL_MIN := 0.8
const DECISION_INTERVAL_MAX := 1.6

## Real-distance shooting gate (world units from the goal mouth) and the
## continuous quality falloff across it (replaces the old 3-step Zone enum).
## Widened and made much more eager than the original pass-first tuning —
## players should take a shot whenever a real chance is on, not just as a
## last resort after every pass option is exhausted.
const SHOOTING_RANGE := 300.0
const SHOT_CHANCE_BASE := 0.14
const SHOT_CHANCE_PROXIMITY_BONUS := 0.55
## Extra shot chance when the carrier has a clear sight of goal (no
## defender within PRESSURE_RANGE) — a genuine chance should usually be
## taken, not passed up just because a shorter pass was also available.
const SHOT_CHANCE_OPEN_BONUS := 0.25
const SHOT_QUALITY_MIN := 1.0
const SHOT_QUALITY_MAX := 2.2

## Tackle contest: how close a defender must be to challenge, and how often
## they get to roll while they stay that close.
const TACKLE_RANGE := 45.0
const TACKLE_ATTEMPT_INTERVAL := 1.4

## A carrier within this distance of the nearest opponent is "under
## pressure" and more likely to look for a pass than hold the ball.
const PRESSURE_RANGE := 90.0
const PASS_CHANCE_BASE := 0.55
const PASS_CHANCE_PRESSURE_BONUS := 0.25
## Extra pass bias while the carrier is in their own half — real buildup
## goes through midfield via passing, not a solo run from the back; only
## the attacking third should realistically favor holding/dribbling.
const PASS_CHANCE_OWN_HALF_BONUS := 0.25
## When the nearest opponent is further than this, the carrier has a real
## lane open toward goal — cuts the pass chance so they actually drive into
## that space and carry it themselves instead of passing it away on sight
## of an open opponent's half, matching a player's instinct to run at goal
## when nobody's in front of them.
const OPEN_LANE_RANGE := 170.0
const OPEN_LANE_PASS_REDUCTION := 0.35

## Receiver candidate selection (ported from the old PassSystem, fixed to
## use the side's real current attack direction instead of assuming home
## always attacks right — that broke at half-time under the old system).
const PASS_MIN_DISTANCE := 60.0
## Trimmed from 750 — the old range let a far but slightly-more-forward
## option out-weigh a much closer, equally-open teammate. Realistic passes
## are mostly short-to-medium; a genuine long switch is now rare rather
## than routine.
const PASS_MAX_DISTANCE := 480.0
## Distance decay is now a steeper power curve (favors close options much
## more strongly than plain inverse-distance did) so proximity dominates
## the choice, and "how forward" is a *directness ratio*
## (forward_progress / distance, i.e. how directly ahead the candidate is,
## not raw world-unit progress) so it no longer scales up with distance and
## make far options look artificially better. A candidate level with or
## behind the passer is multiplied down hard instead, so a nearby covering
## teammate doesn't beat a close forward option just by being closer still.
const DISTANCE_DECAY_EXPONENT := 1.6
const FORWARD_DIRECTNESS_WEIGHT := 2.5
const BACKWARD_PASS_PENALTY := 0.12

## Ball-flight pacing for a completed/intercepted pass.
const PASS_SPEED := 550.0
const PASS_MIN_DURATION_SEC := 0.25
const PASS_MAX_DURATION_SEC := 1.6

## Interception: how close an opponent must be to the pass lane to have a
## shot at cutting it out, and how much extra weight the passer's own Pass
## stat gets against the interceptor's rating (>1 favors the passer).
const INTERCEPTION_RADIUS := 55.0
const PASS_LANE_SAFETY := 1.3

## Shared rating weights, reused across defender/interceptor/tackle contests
## and shot resolution — same blend as the old MatchEngine, now applied to
## the specific players involved instead of a whole-team average.
const DEFENSE_STRENGTH_WEIGHT := 0.6
const DEFENSE_SPEED_WEIGHT := 0.4
const RETENTION_STRENGTH_WEIGHT := 0.5
const RETENTION_SPEED_WEIGHT := 0.3
const RETENTION_PASSING_WEIGHT := 0.2
const DEFENSE_FACTOR := 1.1
const SAVED_FRACTION := 0.6

const CONDITION_FLOOR_MULTIPLIER := LiveMatchState.CONDITION_FLOOR_MULTIPLIER
const STARTING_CONDITION := LiveMatchState.STARTING_CONDITION

var _ball_state: BallState
var _match_state: LiveMatchState
var _movement_system: PlayerMovementSystem
var _possession_system: PossessionSystem
var _grass_rect: Rect2

var _last_carrier: Player = null
var _decision_timer: float = 0.0
var _decision_interval: float = DECISION_INTERVAL_MIN
var _tackle_timer: float = 0.0
var _processed_events: Array = []  # Track processed events to avoid duplicates

func _init(ball_state: BallState, match_state: LiveMatchState, movement_system: PlayerMovementSystem,
		possession_system: PossessionSystem, grass_rect: Rect2) -> void:
	_ball_state = ball_state
	_match_state = match_state
	_movement_system = movement_system
	_possession_system = possession_system
	_grass_rect = grass_rect

## Called every rendered frame. No-ops whenever nobody concretely holds the
## ball (loose ball, pass in flight) — those states resolve themselves via
## PossessionSystem; this only acts once someone is carrying.
func update(delta: float) -> void:
	if _match_state.finished or _ball_state.pass_in_flight or _ball_state.dead_ball_active:
		return

	var carrier: Player = _ball_state.possession_player
	if carrier == null:
		_last_carrier = null
		return

	if carrier != _last_carrier:
		_reset_decision_state()
		_last_carrier = carrier

	@warning_ignore("untyped_declaration")
	var is_home = _ball_state.possession_team
	var lineup: Array = _match_state.home_lineup if is_home else _match_state.away_lineup
	var carrier_idx: int = lineup.find(carrier)
	if carrier_idx == -1:
		return
	var carrier_pos: Vector2 = _movement_system.get_player_position(is_home, carrier_idx)

	_update_tackle_pressure(delta, is_home, carrier, carrier_pos)
	## A won tackle changes possession mid-frame — don't also let the now-
	## dispossessed player "decide" to pass or shoot this frame.
	if _ball_state.possession_player != carrier:
		return

	_decision_timer += delta
	if _decision_timer < _decision_interval:
		return
	_decision_timer = 0.0
	_decision_interval = randf_range(DECISION_INTERVAL_MIN, DECISION_INTERVAL_MAX)
	_make_decision(is_home, carrier, carrier_idx, carrier_pos, lineup)

func _reset_decision_state() -> void:
	_decision_timer = 0.0
	_decision_interval = randf_range(DECISION_INTERVAL_MIN, DECISION_INTERVAL_MAX)
	_tackle_timer = 0.0
	_ball_state.likely_receiver = null

## Nearest real opposing defender presses the carrier: while within
## TACKLE_RANGE, rolls a contest every TACKLE_ATTEMPT_INTERVAL. A win hands
## the ball straight to the defender (they're already right there — no need
## for a separate loose-ball phase at point-blank range).
func _update_tackle_pressure(delta: float, is_home: bool, carrier: Player, carrier_pos: Vector2) -> void:
	var opp_formation: Formation = _match_state.away_formation if is_home else _match_state.home_formation
	var opp_lineup: Array = _match_state.away_lineup if is_home else _match_state.home_lineup
	var nearest: Dictionary = _nearest_opponent(opp_lineup, not is_home, carrier_pos)
	if nearest.is_empty() or nearest["dist"] > TACKLE_RANGE:
		_tackle_timer = 0.0
		return

	_tackle_timer += delta
	if _tackle_timer < TACKLE_ATTEMPT_INTERVAL:
		return
	_tackle_timer = 0.0

	var carrier_formation: Formation = _match_state.home_formation if is_home else _match_state.away_formation
	var carrier_lineup: Array = _match_state.home_lineup if is_home else _match_state.away_lineup
	var carrier_idx: int = carrier_lineup.find(carrier)
	var carrier_slot: Formation.SlotCategory = carrier_formation.slots[carrier_idx] if carrier_idx != -1 else Formation.SlotCategory.MID

	var defender: Player = nearest["player"]
	var defender_slot: Formation.SlotCategory = opp_formation.slots[nearest["idx"]]

	var defender_rating: float = (_effective_stat(defender, defender_slot, "strength") * DEFENSE_STRENGTH_WEIGHT
		+ _effective_stat(defender, defender_slot, "speed") * DEFENSE_SPEED_WEIGHT) * _condition_multiplier(_match_state.get_condition(defender))
	var carrier_rating: float = (_effective_stat(carrier, carrier_slot, "strength") * RETENTION_STRENGTH_WEIGHT
		+ _effective_stat(carrier, carrier_slot, "speed") * RETENTION_SPEED_WEIGHT
		+ _effective_stat(carrier, carrier_slot, "passing") * RETENTION_PASSING_WEIGHT) * _condition_multiplier(_match_state.get_condition(carrier))

	var p_defender_wins: float = defender_rating / max(defender_rating + carrier_rating, 1.0)
	if randf() < p_defender_wins:
		_ball_state.set_possession(not is_home, defender)
		_reset_decision_state()

	## Phase 4: Check for tackle-related events (fouls, cards, injuries)
	if _match_state.event_system:
		var defending_team_state = _match_state.away_state if is_home else _match_state.home_state
		_match_state.event_system.check_tackle_event(not is_home, defender, carrier, defending_team_state, TACKLE_ATTEMPT_INTERVAL)
		## Wire up event consequences
		for event_dict in _match_state.event_system.recent_match_events:
			if event_dict not in _processed_events:
				var event_type = event_dict.get("type", "")
				var player = event_dict.get("player")
				var event_is_home = event_dict.get("is_home", false)
				if player and event_type:
					var severity = "yellow" if event_type == "yellow_card" else "red" if event_type == "red_card" else "injury"
					_match_state.apply_match_event(event_type, event_is_home, player, severity)
				_processed_events.append(event_dict)

## Evaluate shoot / pass / dribble for the current carrier. Doing nothing
## here means "keep dribbling" — PlayerMovementSystem already drives the
## carrier forward every frame by default.
func _make_decision(is_home: bool, carrier: Player, carrier_idx: int, carrier_pos: Vector2, lineup: Array) -> void:
	var formation: Formation = _match_state.home_formation if is_home else _match_state.away_formation
	var carrier_slot: Formation.SlotCategory = formation.slots[carrier_idx]
	var carrier_condition_mult: float = _condition_multiplier(_match_state.get_condition(carrier))

	var opp_lineup: Array = _match_state.away_lineup if is_home else _match_state.home_lineup
	var nearest_opp: Dictionary = _nearest_opponent(opp_lineup, not is_home, carrier_pos)
	var under_pressure: bool = not nearest_opp.is_empty() and nearest_opp["dist"] < PRESSURE_RANGE

	var goal_pos: Vector2 = _goal_target_pos(is_home)
	var dist_to_goal: float = carrier_pos.distance_to(goal_pos)
	if dist_to_goal <= SHOOTING_RANGE:
		var proximity: float = 1.0 - clamp(dist_to_goal / SHOOTING_RANGE, 0.0, 1.0)
		var shot_chance: float = SHOT_CHANCE_BASE + proximity * SHOT_CHANCE_PROXIMITY_BONUS + (SHOT_CHANCE_OPEN_BONUS if not under_pressure else 0.0)
		if randf() < shot_chance:
			_take_shot(is_home, carrier, carrier_slot, carrier_condition_mult, proximity)
			return

	var receiver: Player = _select_pass_candidate(is_home, lineup, formation, carrier, carrier_pos)
	## Keep the ball's "likely receiver" hint fresh every tick, even on ticks
	## that end up dribbling — lets off-ball movement anticipate the pass a
	## beat early instead of only reacting once the ball is actually in flight.
	_ball_state.likely_receiver = receiver
	if receiver == null:
		return

	var team_attacks_right: bool = _movement_system.home_attacks_right() if is_home else not _movement_system.home_attacks_right()
	var own_half: bool = (carrier_pos.x < _grass_rect.get_center().x) == team_attacks_right
	var has_open_lane: bool = nearest_opp.is_empty() or nearest_opp["dist"] > OPEN_LANE_RANGE
	var pass_bias: float = 0.5 + (carrier.passing / 100.0)
	var pass_chance: float = clamp((PASS_CHANCE_BASE + (PASS_CHANCE_PRESSURE_BONUS if under_pressure else 0.0)
		+ (PASS_CHANCE_OWN_HALF_BONUS if own_half else 0.0)
		- (OPEN_LANE_PASS_REDUCTION if has_open_lane else 0.0)) * pass_bias, 0.05, 0.92)
	if randf() < pass_chance:
		_attempt_pass(is_home, carrier, carrier_slot, receiver, carrier_pos, lineup)

func _take_shot(is_home: bool, shooter: Player, shooter_slot: Formation.SlotCategory, shooter_condition_mult: float, proximity: float) -> void:
	var keeper_formation: Formation = _match_state.away_formation if is_home else _match_state.home_formation
	var keeper_lineup: Array = _match_state.away_lineup if is_home else _match_state.home_lineup
	var keeper: Player = _pick_goalkeeper(keeper_formation, keeper_lineup)

	var quality: float = lerp(SHOT_QUALITY_MIN, SHOT_QUALITY_MAX, proximity)
	var shooter_kick: float = _effective_stat(shooter, shooter_slot, "kick") * shooter_condition_mult * quality
	var keeper_strength: float = 0.0
	if keeper != null:
		var keeper_idx: int = keeper_lineup.find(keeper)
		var keeper_slot: Formation.SlotCategory = keeper_formation.slots[keeper_idx]
		keeper_strength = _effective_stat(keeper, keeper_slot, "strength") * _condition_multiplier(_match_state.get_condition(keeper))

	var p_goal: float = shooter_kick / max(shooter_kick + keeper_strength * DEFENSE_FACTOR, 1.0)
	var outcome: String
	if randf() < p_goal:
		outcome = "GOAL"
	elif randf() < SAVED_FRACTION:
		outcome = "SAVED"
	else:
		outcome = "OFF_TARGET"

	_possession_system.on_shot_attempt(is_home, shooter, outcome, keeper)
	shot_taken.emit(is_home, shooter, outcome)
	_last_carrier = null

func _attempt_pass(is_home: bool, passer: Player, passer_slot: Formation.SlotCategory, receiver: Player, passer_pos: Vector2, lineup: Array) -> void:
	var receiver_idx: int = lineup.find(receiver)
	var receiver_pos: Vector2 = _movement_system.get_player_position(is_home, receiver_idx)
	var passer_condition_mult: float = _condition_multiplier(_match_state.get_condition(passer))

	var intercept_result: Dictionary = _check_interception(is_home, passer_pos, receiver_pos, passer, passer_slot, passer_condition_mult)
	var success: bool = intercept_result.get("success", true)
	var flight_end_pos: Vector2 = receiver_pos if success else intercept_result["intercept_pos"]
	var interceptor: Player = null if success else intercept_result["interceptor"]

	var distance: float = passer_pos.distance_to(flight_end_pos)
	var duration: float = clamp(distance / PASS_SPEED, PASS_MIN_DURATION_SEC, PASS_MAX_DURATION_SEC)

	_ball_state.start_pass(is_home, receiver, passer_pos, flight_end_pos, receiver_pos, duration, success, interceptor)
	pass_started.emit(is_home, passer, receiver, passer_pos, flight_end_pos, duration)
	_last_carrier = null

## Any real opponent within INTERCEPTION_RADIUS of the pass lane can cut it
## out — the nearest-to-the-lane, highest-rated candidate rolls against the
## passer's own (position-adjusted, condition-scaled) Pass stat.
func _check_interception(is_home: bool, start_pos: Vector2, end_pos: Vector2, passer: Player,
		passer_slot: Formation.SlotCategory, passer_condition_mult: float) -> Dictionary:
	var opp_formation: Formation = _match_state.away_formation if is_home else _match_state.home_formation
	var opp_lineup: Array = _match_state.away_lineup if is_home else _match_state.home_lineup

	var best_score: float = -1.0
	var best_interceptor: Player = null
	var best_t: float = 0.0
	for i in opp_lineup.size():
		var opponent: Player = opp_lineup[i]
		if opponent == null:
			continue
		var pos: Vector2 = _movement_system.get_player_position(not is_home, i)
		var projection: Dictionary = _point_segment_projection(pos, start_pos, end_pos)
		var lane_dist: float = projection["dist"]
		if lane_dist > INTERCEPTION_RADIUS:
			continue
		var closeness: float = 1.0 - (lane_dist / INTERCEPTION_RADIUS)
		var defender_rating: float = (_effective_stat(opponent, opp_formation.slots[i], "strength") * DEFENSE_STRENGTH_WEIGHT
			+ _effective_stat(opponent, opp_formation.slots[i], "speed") * DEFENSE_SPEED_WEIGHT) * _condition_multiplier(_match_state.get_condition(opponent))
		var score: float = defender_rating * closeness
		if score > best_score:
			best_score = score
			best_interceptor = opponent
			best_t = projection["t"]

	if best_interceptor == null:
		return {"success": true}

	var passer_rating: float = _effective_stat(passer, passer_slot, "passing") * passer_condition_mult
	var p_intercept: float = best_score / max(best_score + passer_rating * PASS_LANE_SAFETY, 1.0)
	if randf() < p_intercept:
		return {"success": false, "interceptor": best_interceptor, "intercept_pos": start_pos.lerp(end_pos, best_t)}
	return {"success": true}

## Weighted-random receiver among fielded teammates in a realistic passing
## window — forward-progress is measured relative to the passer's own
## position along the side's *current* attack direction (fixes a bug in the
## old PassSystem, which assumed home always attacks right and so
## mis-weighted every pass after half-time), so a teammate level with or
## behind the passer is heavily discounted rather than winning on proximity
## alone.
func _select_pass_candidate(is_home: bool, lineup: Array, formation: Formation, passer: Player, passer_pos: Vector2) -> Player:
	var team_attacks_right: bool = _movement_system.home_attacks_right() if is_home else not _movement_system.home_attacks_right()
	var candidates: Array = []
	var weights: Array = []
	for i in lineup.size():
		var candidate: Player = lineup[i]
		if candidate == null or candidate == passer:
			continue
		if formation.slots[i] == Formation.SlotCategory.GK:
			continue
		var candidate_pos: Vector2 = _movement_system.get_player_position(is_home, i)
		var distance: float = passer_pos.distance_to(candidate_pos)
		if distance < PASS_MIN_DISTANCE or distance > PASS_MAX_DISTANCE:
			continue
		var forward_progress: float = (candidate_pos.x - passer_pos.x) * (1.0 if team_attacks_right else -1.0)
		var weight: float = 1.0 / pow(distance + 1.0, DISTANCE_DECAY_EXPONENT)
		if forward_progress > 0.0:
			weight *= 1.0 + (forward_progress / distance) * FORWARD_DIRECTNESS_WEIGHT
		else:
			weight *= BACKWARD_PASS_PENALTY
		candidates.append(candidate)
		## No artificial floor here — weight is always strictly positive from
		## the formula above, and a floor large enough to matter at these
		## distance-decay magnitudes would flatten out the very distance/
		## direction differentiation this is meant to produce.
		weights.append(weight)

	if candidates.is_empty():
		return null
	var total_weight: float = 0.0
	for w in weights:
		total_weight += w
	var roll: float = randf() * total_weight
	var running: float = 0.0
	for i in candidates.size():
		running += weights[i]
		if roll <= running:
			return candidates[i]
	return candidates[candidates.size() - 1]

func _goal_target_pos(is_home: bool) -> Vector2:
	var team_attacks_right: bool = _movement_system.home_attacks_right() if is_home else not _movement_system.home_attacks_right()
	var target_x: float = _grass_rect.end.x if team_attacks_right else _grass_rect.position.x
	return Vector2(target_x, _grass_rect.get_center().y)

func _nearest_opponent(opp_lineup: Array, opp_is_home: bool, from_pos: Vector2) -> Dictionary:
	var best_dist: float = INF
	var best: Dictionary = {}
	for i in opp_lineup.size():
		var player: Player = opp_lineup[i]
		if player == null:
			continue
		var pos: Vector2 = _movement_system.get_player_position(opp_is_home, i)
		var dist: float = from_pos.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best = {"player": player, "idx": i, "dist": dist}
	return best

func _pick_goalkeeper(formation: Formation, lineup: Array) -> Player:
	for i in lineup.size():
		if formation.slots[i] == Formation.SlotCategory.GK and lineup[i] != null:
			return lineup[i]
	return null

func _effective_stat(player: Player, slot: Formation.SlotCategory, stat_name: String) -> float:
	return PositionCompatibility.get_effective_stats(player, slot).get(stat_name, 0.0)

func _condition_multiplier(condition: float) -> float:
	return CONDITION_FLOOR_MULTIPLIER + (1.0 - CONDITION_FLOOR_MULTIPLIER) * (condition / STARTING_CONDITION)

## Closest point on segment a-b to `point`; returns both the distance and
## the projection parameter t (0=a, 1=b) so callers can place a result along
## the segment (e.g. an interception point).
func _point_segment_projection(point: Vector2, a: Vector2, b: Vector2) -> Dictionary:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	var t: float = 0.5
	if len_sq > 0.0001:
		t = clamp((point - a).dot(ab) / len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return {"dist": point.distance_to(closest), "t": t}
