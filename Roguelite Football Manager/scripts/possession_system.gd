class_name PossessionSystem
extends RefCounted

## Per-frame ball physics: follows whoever holds the ball, interpolates a
## pass in flight, and resolves loose-ball pickups. Decision-making (who
## passes to whom, tackles, shots) lives in MatchDecisionEngine — this class
## only owns what the ball itself is doing each frame, driven by BallState.

## How fast the ball closes the gap to its carrier each frame — an
## exponential-smoothing rate (per second), so following is framerate
## independent and reads as a smooth glide rather than a per-minute snap.
const BALL_FOLLOW_RATE := 10.0

## Loose-ball (nobody in control) rolling friction — fraction of velocity
## retained per second, so a rebound/turnover ball visibly rolls a little
## before someone picks it up instead of freezing in place.
const LOOSE_BALL_FRICTION := 0.85

## Ambient drift speed (world units/second) used to nudge a completely
## stationary loose ball toward the team judged to be "in control" (e.g.
## right after a kickoff placement), so it doesn't sit dead center forever
## if nobody is within pickup range yet.
const LOOSE_BALL_DRIFT_SPEED := 25.0

## How close (world units) a player must be to a loose ball to win it.
const PICKUP_RADIUS := 34.0

## Loose-ball 50/50 contest weighting — physical duel blend used only when
## 2+ players from both sides reach the ball at once (a single nearby player
## just wins it uncontested; no need to roll dice against nobody).
const CONTEST_STRENGTH_WEIGHT := 0.5
const CONTEST_SPEED_WEIGHT := 0.5

var _ball_state: BallState
var _match_state: LiveMatchState
var _movement_system: PlayerMovementSystem

func _init(ball_state: BallState, match_state: LiveMatchState, movement_system: PlayerMovementSystem) -> void:
	_ball_state = ball_state
	_match_state = match_state
	_movement_system = movement_system

## Per-frame ball movement — called every rendered frame (not just once per
## simulated minute) so the ball visibly glides between players, flies on a
## pass, and rolls when loose, instead of snapping in discrete jumps.
func update(delta: float) -> void:
	if _ball_state.pass_in_flight:
		_update_pass_flight(delta)
	elif _ball_state.possession_player != null:
		_follow_carrier(delta)
	else:
		_update_loose_ball(delta)
		_check_loose_ball_pickup()

## Smoothly glide the ball toward whoever currently carries it.
func _follow_carrier(delta: float) -> void:
	@warning_ignore("untyped_declaration")
	var is_home = _ball_state.possession_team
	var lineup: Array = _match_state.home_lineup if is_home else _match_state.away_lineup
	var idx: int = lineup.find(_ball_state.possession_player)
	if idx == -1:
		return
	var carrier_pos: Vector2 = _movement_system.get_player_position(is_home, idx)
	## Exponential smoothing: framerate-independent, always converges without
	## ever fully "catching up" in one frame — reads as a smooth glide.
	var t: float = 1.0 - exp(-BALL_FOLLOW_RATE * delta)
	_ball_state.position = _ball_state.position.lerp(carrier_pos, t)

## Interpolate the ball along its pass flight (set up by
## MatchDecisionEngine.start_pass) and resolve the outcome on arrival —
## completion hands possession to the intended receiver, interception hands
## it to whoever cut it out (both already decided at pass-start time, based
## on real player positions).
func _update_pass_flight(delta: float) -> void:
	_ball_state.pass_elapsed += delta
	var duration: float = max(_ball_state.pass_duration, 0.01)
	var t: float = clamp(_ball_state.pass_elapsed / duration, 0.0, 1.0)
	_ball_state.position = _ball_state.pass_start_pos.lerp(_ball_state.pass_end_pos, t)
	if t >= 1.0:
		_resolve_pass_arrival()

func _resolve_pass_arrival() -> void:
	if _ball_state.pass_success:
		_ball_state.set_possession(_ball_state.pass_is_home, _ball_state.pass_target_player)
	else:
		_ball_state.loose_ball()
		_ball_state.velocity = Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))

## Roll a loose ball with friction (rebounds, turnovers, kickoffs) so it
## visibly travels before anyone reaches it, rather than teleporting.
func _update_loose_ball(delta: float) -> void:
	if _ball_state.velocity.length() > 1.0:
		_ball_state.position += _ball_state.velocity * delta
		_ball_state.velocity *= pow(LOOSE_BALL_FRICTION, delta * 60.0)
	elif _ball_state.possession_team != null:
		## No pace left but a team is still "in control" territorially (e.g.
		## goalkeeper's side) — gentle drift so it isn't perfectly frozen.
		var direction: float = 1.0 if _ball_state.possession_team else -1.0
		_ball_state.position += Vector2(direction * LOOSE_BALL_DRIFT_SPEED * delta, 0.0)
		_ball_state.velocity = Vector2.ZERO
	else:
		_ball_state.velocity = Vector2.ZERO

## Any fielded player from either side close enough to a loose ball can win
## it. A single nearby player just picks it up; two or more (a genuine
## 50/50) resolve via a physical-duel weighted roll instead of always going
## to whoever's a half-step closer.
func _check_loose_ball_pickup() -> void:
	var candidates: Array = _find_players_near_ball()
	if candidates.is_empty():
		return
	if candidates.size() == 1:
		_win_loose_ball(candidates[0])
		return

	var weights: Array = []
	var total_weight: float = 0.0
	for c in candidates:
		var proximity: float = 1.0 - clamp(c["dist"] / PICKUP_RADIUS, 0.0, 1.0)
		var physical: float = c["player"].strength * CONTEST_STRENGTH_WEIGHT + c["player"].speed * CONTEST_SPEED_WEIGHT
		var weight: float = max(physical, 1.0) * (0.5 + proximity)
		weights.append(weight)
		total_weight += weight

	var roll: float = randf() * total_weight
	var running: float = 0.0
	for i in candidates.size():
		running += weights[i]
		if roll <= running:
			_win_loose_ball(candidates[i])
			return
	_win_loose_ball(candidates[candidates.size() - 1])

func _win_loose_ball(winner: Dictionary) -> void:
	_ball_state.set_possession(winner["is_home"], winner["player"])
	_ball_state.velocity = Vector2.ZERO

## Returns {is_home, player, dist} for every fielded player within
## PICKUP_RADIUS of the ball, across both sides.
func _find_players_near_ball() -> Array:
	var found: Array = []
	for is_home in [true, false]:
		var lineup: Array = _match_state.home_lineup if is_home else _match_state.away_lineup
		for i in lineup.size():
			var player: Player = lineup[i]
			if player == null:
				continue
			var pos: Vector2 = _movement_system.get_player_position(is_home, i)
			var dist: float = pos.distance_to(_ball_state.position)
			if dist < PICKUP_RADIUS:
				found.append({"is_home": is_home, "player": player, "dist": dist})
	return found

## Handle a shot attempt from MatchDecisionEngine. Sends the ball toward
## goal and leaves it as a loose ball near the goalmouth for either side to
## contest — a save/miss doesn't hand possession to a fixed team, it creates
## a scramble.
func on_shot_attempt(is_home: bool, shooter: Player, _outcome: String) -> void:
	if shooter == null:
		return

	var lineup: Array = _match_state.home_lineup if is_home else _match_state.away_lineup
	var shooter_index: int = lineup.find(shooter)
	if shooter_index == -1:
		return

	var target_pos: Vector2
	if is_home:
		target_pos = Vector2(_ball_state.position.x + 400, _ball_state.position.y)  ## Right side goal.
	else:
		target_pos = Vector2(_ball_state.position.x - 400, _ball_state.position.y)  ## Left side goal.

	## The ball travels toward goal with the shot (the pitch view's own kick
	## tween handles the visual flight); once it lands, it's a loose ball
	## near the goalmouth for either side to contest.
	_ball_state.position = target_pos
	_ball_state.set_in_air(true)
	_ball_state.loose_ball()
	_ball_state.velocity = Vector2(randf_range(-40.0, 40.0), randf_range(-60.0, 60.0))
