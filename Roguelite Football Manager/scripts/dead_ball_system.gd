class_name DeadBallSystem
extends RefCounted

## Dead Ball Rules milestone: throw-ins, corners, goal kicks. Watches the
## ball every frame for leaving the pitch (BallState/PossessionSystem never
## clamp a loose ball to the grass rect — only player movement targets are
## clamped), classifies the restart from which line it crossed and
## BallState.last_touch_team (the real out-of-bounds rule), then owns the
## ball/taker until the restart is actually played: PossessionSystem's normal
## loose-ball physics and MatchDecisionEngine's carrier decisions both no-op
## while BallState.dead_ball_active is true (see possession_system.gd and
## match_decision_engine.gd's early-return checks), so this class is the sole
## source of truth for the ball during a restart. Off-ball players are NOT
## frozen — PlayerMovementSystem treats the awarded side as "attacking" for
## shape purposes the moment the restart is triggered (see its
## `_dead_ball_awarded_home` handling), per Designer sign-off that everyone
## but the taker should keep reacting live.
## First-pass placeholder — not designer-reviewed for feel/timing.

enum RestartType { THROW_IN, CORNER, GOAL_KICK }

## Fixed taker role per restart type (Designer sign-off: role-based, not
## pure proximity) — goal kicks are always the GK.
const THROW_IN_TAKER_SLOT: Formation.SlotCategory = Formation.SlotCategory.DEF
const CORNER_TAKER_SLOT: Formation.SlotCategory = Formation.SlotCategory.FWD

## How far in from the touchline/goal-line edge a corner flag sits, so the
## taker/ball aren't placed exactly on the boundary line itself.
const CORNER_EDGE_MARGIN := 14.0
## Goal kick restart spot: a fixed depth inside the 6-yard area from the
## defending team's own goal line, centered — no keeper side-choice modeled.
const GOAL_KICK_DEPTH_RATIO := 0.08
## Minimum distance kept from the pitch's vertical edges when clamping a
## throw-in's exact exit point to a legal in-bounds spot on the touchline.
const THROW_IN_EDGE_MARGIN := 10.0

## Where each restart aims the outgoing pass, so a throw-in reads as a short
## toss down the line, a corner as a cross into the box, and a goal kick as
## a long punt upfield — reusing MatchDecisionEngine's own pass-flight speed/
## duration constants rather than inventing new ones.
const THROW_IN_AIM_FORWARD := 120.0
const CORNER_AIM_DEPTH := 90.0

## Emitted once the taker has walked to the spot and actually played the
## restart, so live_match.gd can trigger the same Kick flourish used for
## shots/passes (the asset pack has no distinct throw/corner/goal-kick
## animation — Designer sign-off: reuse the kick anim, vary only the ball's
## flight).
signal restart_taken(is_home: bool, taker: Player)

var _active: bool = false
var _type: RestartType = RestartType.THROW_IN
var _awarded_home: bool = true
var _taker: Player = null
var _restart_pos: Vector2 = Vector2.ZERO

## Called every frame. While idle, watches for the ball leaving the grass
## rect; while a restart is in progress, waits for the taker to arrive and
## then plays it.
func update(ball_state: BallState, match_state: LiveMatchState, movement_system: PlayerMovementSystem) -> void:
	if match_state.finished:
		return
	if _active:
		if movement_system.dead_ball_taker_arrived(_awarded_home):
			_play_restart(ball_state, match_state, movement_system)
		return

	if not ball_state.is_loose():
		return
	var grass_rect: Rect2 = movement_system.get_grass_rect()
	if grass_rect.has_point(ball_state.position):
		return
	_trigger_restart(ball_state, match_state, movement_system, grass_rect)

func _trigger_restart(ball_state: BallState, match_state: LiveMatchState, movement_system: PlayerMovementSystem, grass_rect: Rect2) -> void:
	var pos: Vector2 = ball_state.position
	var last_home = ball_state.last_touch_team

	if pos.x < grass_rect.position.x or pos.x > grass_rect.end.x:
		_classify_byline(pos, last_home, movement_system, grass_rect)
	else:
		_classify_touchline(pos, last_home, grass_rect)

	var taker_info: Dictionary = _pick_taker(match_state, movement_system)
	_taker = taker_info.get("player")
	if _taker == null:
		## No eligible fielded player at all (shouldn't happen with a full
		## squad) — bail out rather than lock the match in a dead state.
		return

	ball_state.loose_ball()
	ball_state.position = _restart_pos
	ball_state.velocity = Vector2.ZERO
	ball_state.set_in_air(false)
	ball_state.dead_ball_active = true
	_active = true
	movement_system.set_dead_ball_taker(_taker, _restart_pos, _awarded_home)

## Ball went out over a touchline (top/bottom) — a throw-in for whichever
## side did NOT touch it last, taken from the exact exit point on the line.
func _classify_touchline(pos: Vector2, last_home, grass_rect: Rect2) -> void:
	_type = RestartType.THROW_IN
	_awarded_home = true if last_home == null else not last_home
	var x: float = clamp(pos.x, grass_rect.position.x + THROW_IN_EDGE_MARGIN, grass_rect.end.x - THROW_IN_EDGE_MARGIN)
	var y: float = grass_rect.position.y if pos.y < grass_rect.position.y else grass_rect.end.y
	_restart_pos = Vector2(x, y)

## Ball went out over a goal line (left/right) — a corner if the last touch
## belonged to the team defending that end, a goal kick if it belonged to
## the team attacking it (the real out-of-bounds rule), both taken from the
## end the ball actually left.
func _classify_byline(pos: Vector2, last_home, movement_system: PlayerMovementSystem, grass_rect: Rect2) -> void:
	var exit_right: bool = pos.x > grass_rect.end.x
	var home_attacks_right: bool = movement_system.home_attacks_right()
	var attacking_is_home: bool = exit_right == home_attacks_right
	var last_is_attacking: bool = last_home != null and last_home == attacking_is_home

	var line_x: float = grass_rect.end.x if exit_right else grass_rect.position.x
	var center_y: float = grass_rect.get_center().y

	if last_is_attacking:
		_type = RestartType.GOAL_KICK
		_awarded_home = not attacking_is_home
		var depth: float = GOAL_KICK_DEPTH_RATIO * grass_rect.size.x
		var inward_x: float = line_x - depth if exit_right else line_x + depth
		_restart_pos = Vector2(inward_x, center_y)
	else:
		_type = RestartType.CORNER
		_awarded_home = attacking_is_home
		var corner_y: float = grass_rect.position.y + CORNER_EDGE_MARGIN if pos.y < center_y else grass_rect.end.y - CORNER_EDGE_MARGIN
		var corner_x: float = line_x - CORNER_EDGE_MARGIN if exit_right else line_x + CORNER_EDGE_MARGIN
		_restart_pos = Vector2(corner_x, corner_y)

## Nearest fielded player of the awarded team, in the fixed role for this
## restart type (DEF for throw-ins, FWD for corners, GK for goal kicks) —
## falls back to the nearest fielded outfield player if that slot category
## isn't on the pitch (e.g. a 3-at-the-back shape with no spare DEF nearby).
func _pick_taker(match_state: LiveMatchState, movement_system: PlayerMovementSystem) -> Dictionary:
	var formation: Formation = match_state.home_formation if _awarded_home else match_state.away_formation
	var lineup: Array = match_state.home_lineup if _awarded_home else match_state.away_lineup
	var wanted_slot: Formation.SlotCategory = Formation.SlotCategory.GK if _type == RestartType.GOAL_KICK \
		else (THROW_IN_TAKER_SLOT if _type == RestartType.THROW_IN else CORNER_TAKER_SLOT)

	var best_wanted: Dictionary = {}
	var best_wanted_dist: float = INF
	var best_any: Dictionary = {}
	var best_any_dist: float = INF
	for i in lineup.size():
		var player: Player = lineup[i]
		if player == null:
			continue
		var dist: float = movement_system.get_player_position(_awarded_home, i).distance_to(_restart_pos)
		if dist < best_any_dist:
			best_any_dist = dist
			best_any = {"player": player, "idx": i}
		if formation.slots[i] == wanted_slot and dist < best_wanted_dist:
			best_wanted_dist = dist
			best_wanted = {"player": player, "idx": i}

	return best_wanted if not best_wanted.is_empty() else best_any

## Taker has reached the spot — play the restart as an instantly-completing
## pass to the nearest suitable teammate (no interception risk modeled for
## restarts, a first-pass simplification), then hand control back to normal
## play.
func _play_restart(ball_state: BallState, match_state: LiveMatchState, movement_system: PlayerMovementSystem) -> void:
	var lineup: Array = match_state.home_lineup if _awarded_home else match_state.away_lineup
	var taker_idx: int = lineup.find(_taker)
	var taker_pos: Vector2 = movement_system.get_player_position(_awarded_home, taker_idx)

	var receiver: Player = _pick_receiver(match_state, movement_system)
	if receiver == null:
		## Nobody else fielded to receive it (extreme edge case) — leave it
		## loose at the spot for a scramble rather than stalling forever.
		ball_state.dead_ball_active = false
		movement_system.clear_dead_ball_taker()
		restart_taken.emit(_awarded_home, _taker)
		_active = false
		return

	var receiver_idx: int = lineup.find(receiver)
	var receiver_pos: Vector2 = movement_system.get_player_position(_awarded_home, receiver_idx)
	var distance: float = taker_pos.distance_to(receiver_pos)
	var duration: float = clamp(distance / MatchDecisionEngine.PASS_SPEED, MatchDecisionEngine.PASS_MIN_DURATION_SEC, MatchDecisionEngine.PASS_MAX_DURATION_SEC)

	ball_state.start_pass(_awarded_home, receiver, taker_pos, receiver_pos, receiver_pos, duration, true, null)
	restart_taken.emit(_awarded_home, _taker)
	movement_system.clear_dead_ball_taker()
	ball_state.dead_ball_active = false
	_active = false

## Aim point differs by restart type (down the line / into the box / long
## upfield); the actual receiver is whichever fielded teammate (excluding
## the taker and the GK) sits nearest to that aim point.
func _pick_receiver(match_state: LiveMatchState, movement_system: PlayerMovementSystem) -> Player:
	var grass_rect: Rect2 = movement_system.get_grass_rect()
	var attacks_right: bool = movement_system.home_attacks_right() if _awarded_home else not movement_system.home_attacks_right()
	var attack_dir: float = 1.0 if attacks_right else -1.0

	var aim: Vector2
	match _type:
		RestartType.THROW_IN:
			aim = _restart_pos + Vector2(attack_dir * THROW_IN_AIM_FORWARD, 0.0)
		RestartType.CORNER:
			var goal_x: float = grass_rect.end.x if attacks_right else grass_rect.position.x
			aim = Vector2(goal_x - attack_dir * CORNER_AIM_DEPTH, grass_rect.get_center().y)
		RestartType.GOAL_KICK:
			aim = grass_rect.get_center()

	var formation: Formation = match_state.home_formation if _awarded_home else match_state.away_formation
	var lineup: Array = match_state.home_lineup if _awarded_home else match_state.away_lineup
	var best: Player = null
	var best_dist: float = INF
	for i in lineup.size():
		var player: Player = lineup[i]
		if player == null or player == _taker or formation.slots[i] == Formation.SlotCategory.GK:
			continue
		var dist: float = movement_system.get_player_position(_awarded_home, i).distance_to(aim)
		if dist < best_dist:
			best_dist = dist
			best = player
	return best
