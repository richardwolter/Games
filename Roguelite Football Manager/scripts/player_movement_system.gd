class_name PlayerMovementSystem
extends RefCounted

## Frame-by-frame player positioning AI. Updates each player's world position
## based on their role (attacking/defending/transitioning) and the ball state.
## Syncs with pitch_prototype.gd for rendering.

## Movement speed scaling (world units per second).
const BASE_MOVEMENT_SPEED := 200.0

## How far a player will stray from their formation position to track the
## ball. Pitch is ~1280x960 world units — 100 was too small for a player to
## ever notice the ball at realistic formation spacing, leaving most of the
## team glued to their static slot all match. Widened to cover a meaningful
## third of the pitch.
const BALL_TRACKING_RADIUS := 380.0

## Ball carrier's forward-dribble target: how far ahead (world units) of
## their current position to aim each frame, re-issued every frame so it
## acts as a continuous forward drive rather than a one-shot destination.
const DRIBBLE_ADVANCE_STEP := 60.0
## Lateral wander amplitude (world units) layered on the carrier's dribble.
const DRIBBLE_WANDER := 12.0
## Minimum distance (world units) any player's target is kept from the
## pitch boundary, so a dribbling run doesn't clamp exactly on the line.
const PITCH_EDGE_MARGIN := 20.0

## Off-ball attacking spacing: teammates within this radius of each other
## push apart, so support runners spread into open passing lanes instead of
## clumping around the ball carrier.
const SEPARATION_RADIUS := 90.0
const SEPARATION_STRENGTH := 40.0

## How far an off-ball attacker will bias forward (toward the opponent's
## goal) from their formation slot while their team has the ball, to offer
## a forward passing option rather than sitting flat.
const FORWARD_SUPPORT_BIAS := 50.0

## Defending: a marker only picks up an opposing attacker within this range
## of their own formation slot — keeps markers from abandoning their zone
## for an opponent on the far side of the pitch.
const MARKING_RADIUS := 260.0
## How much a marker leans from their formation slot toward their mark
## (0 = ignore mark and hold shape, 1 = stand exactly on the mark).
const MARKING_BLEND := 0.55
## Only the single nearest defender presses the ball/carrier tightly within
## this range; everyone else holds shape or marks (see _update_team).
const PRESSING_RADIUS := 220.0

## Steering acceleration cap (world units/sec^2) — velocity turns toward the
## desired heading at this rate each frame instead of snapping instantly, so
## a target that flip-flops between heuristics (e.g. marking vs pressing)
## reads as a natural change of direction rather than a jitter.
const ACCELERATION := 600.0
## Start easing speed down within this distance of the target so a player
## arrives and settles instead of overshooting and correcting back and forth.
const ARRIVAL_RADIUS := 24.0

## Formation base positions (computed once at init).
var _home_formation_positions: Array = []
var _away_formation_positions: Array = []

## Per-player state (Player -> PlayerPositionState).
var _home_positions: Dictionary = {}
var _away_positions: Dictionary = {}

## References to current game state.
var _home_formation: Formation
var _home_lineup: Array
var _away_formation: Formation
var _away_lineup: Array
var _ball_state: BallState

var _grass_rect: Rect2

## Which end the home side currently attacks. Flips at half-time — away
## always attacks the opposite end.
var _home_attacks_right: bool = true

## Celebration mode state.
var _celebrating_team: int = -1  # -1 = none, 0 = away, 1 = home
var _celebration_goal_pos: Vector2 = Vector2.ZERO

func _init(home_formation: Formation, home_lineup: Array, away_formation: Formation, away_lineup: Array, ball_state: BallState, grass_rect: Rect2) -> void:
	_home_formation = home_formation
	_home_lineup = home_lineup
	_away_formation = away_formation
	_away_lineup = away_lineup
	_ball_state = ball_state
	_grass_rect = grass_rect

	_home_formation_positions = _compute_formation_positions(home_formation, grass_rect, true)
	_away_formation_positions = _compute_formation_positions(away_formation, grass_rect, false)

	## Initialize position state for each player.
	for i in home_lineup.size():
		var player: Player = home_lineup[i]
		if player != null:
			_home_positions[player] = PlayerPositionState.new(player, _home_formation_positions[i])

	for i in away_lineup.size():
		var player: Player = away_lineup[i]
		if player != null:
			_away_positions[player] = PlayerPositionState.new(player, _away_formation_positions[i])

## Advance player positions by one frame (delta seconds).
func update(delta: float) -> void:
	_update_team(true, delta)
	_update_team(false, delta)

## Return position for a given player (lookup by index in lineup, not Player object).
func get_player_position(is_home: bool, slot_index: int) -> Vector2:
	var positions: Dictionary = _home_positions if is_home else _away_positions
	var lineup: Array = _home_lineup if is_home else _away_lineup
	if slot_index >= 0 and slot_index < lineup.size():
		var player: Player = lineup[slot_index]
		if player != null and positions.has(player):
			return positions[player].world_position
	return Vector2.ZERO

## True if the home side is currently attacking the right-hand goal (flips at
## half-time) — single source of truth so MatchDecisionEngine's goal-distance
## checks always agree with what's actually being rendered.
func home_attacks_right() -> bool:
	return _home_attacks_right

## Get movement speed for a player (0-1 normalized).
func get_player_movement_speed(is_home: bool, slot_index: int) -> float:
	var positions: Dictionary = _home_positions if is_home else _away_positions
	var lineup: Array = _home_lineup if is_home else _away_lineup
	if slot_index >= 0 and slot_index < lineup.size():
		var player: Player = lineup[slot_index]
		if player != null and positions.has(player):
			return positions[player].movement_speed
	return 0.0

## Call after a substitution to update position state.
func on_substitution(is_home: bool, slot_index: int, incoming: Player) -> void:
	var positions: Dictionary = _home_positions if is_home else _away_positions
	var formation_positions: Array = _home_formation_positions if is_home else _away_formation_positions
	if slot_index >= 0 and slot_index < formation_positions.size():
		positions[incoming] = PlayerPositionState.new(incoming, formation_positions[slot_index])

## Call when formation changes mid-match.
func on_formation_changed(is_home: bool, new_formation: Formation, new_lineup: Array) -> void:
	if is_home:
		_home_formation = new_formation
		_home_formation_positions = _compute_formation_positions(new_formation, _grass_rect, _home_attacks_right)
		_home_positions.clear()
		for i in new_lineup.size():
			var player: Player = new_lineup[i]
			if player != null:
				_home_positions[player] = PlayerPositionState.new(player, _home_formation_positions[i])
	else:
		_away_formation = new_formation
		_away_formation_positions = _compute_formation_positions(new_formation, _grass_rect, not _home_attacks_right)
		_away_positions.clear()
		for i in new_lineup.size():
			var player: Player = new_lineup[i]
			if player != null:
				_away_positions[player] = PlayerPositionState.new(player, _away_formation_positions[i])

## Half-time end swap: recomputes both sides' formation slot positions for
## their new attacking end and snaps every player straight there (the
## whistle restarts play from shape, no gradual walk-back — same treatment
## as reset_to_formation after a goal).
func on_half_time_side_switch(new_home_attacks_right: bool) -> void:
	_home_attacks_right = new_home_attacks_right
	_home_formation_positions = _compute_formation_positions(_home_formation, _grass_rect, _home_attacks_right)
	_away_formation_positions = _compute_formation_positions(_away_formation, _grass_rect, not _home_attacks_right)
	reset_to_formation()

## Start celebration mode for a goal.
func start_celebration(is_home: bool, goal_position: Vector2) -> void:
	_celebrating_team = 1 if is_home else 0
	_celebration_goal_pos = goal_position

## Stop celebration mode and return to normal play.
func stop_celebration() -> void:
	_celebrating_team = -1

## Check if a team is currently celebrating.
func is_celebrating(is_home: bool) -> bool:
	return _celebrating_team == (1 if is_home else 0)

## Snap every player on both sides back to their formation slot — used for
## a kickoff restart after a goal (no gradual walk-back, the whistle just
## restarts play from shape).
func reset_to_formation() -> void:
	for i in _home_lineup.size():
		var player: Player = _home_lineup[i]
		if player != null and _home_positions.has(player):
			var state: PlayerPositionState = _home_positions[player]
			state.world_position = _home_formation_positions[i]
			state.target_position = _home_formation_positions[i]
			state.velocity = Vector2.ZERO
			state.movement_speed = 0.0
	for i in _away_lineup.size():
		var player: Player = _away_lineup[i]
		if player != null and _away_positions.has(player):
			var state: PlayerPositionState = _away_positions[player]
			state.world_position = _away_formation_positions[i]
			state.target_position = _away_formation_positions[i]
			state.velocity = Vector2.ZERO
			state.movement_speed = 0.0

func _update_team(is_home: bool, delta: float) -> void:
	var positions: Dictionary = _home_positions if is_home else _away_positions
	var lineup: Array = _home_lineup if is_home else _away_lineup
	var formation_positions: Array = _home_formation_positions if is_home else _away_formation_positions

	## Check if celebrating.
	var team_celebrating: bool = is_celebrating(is_home)

	## Determine team role based on ball possession or celebration state.
	var team_has_ball: bool = _ball_state.possession_team == is_home if _ball_state.possession_team != null else false
	var team_role: PlayerPositionState.Role
	if team_celebrating:
		team_role = PlayerPositionState.Role.CELEBRATING
	else:
		team_role = PlayerPositionState.Role.ATTACKING if team_has_ball else PlayerPositionState.Role.DEFENDING
	var carrier: Player = _ball_state.possession_player

	for i in lineup.size():
		var player: Player = lineup[i]
		if player == null or not positions.has(player):
			continue

		var state: PlayerPositionState = positions[player]
		var formation_pos: Vector2 = formation_positions[i]

		## Assign role.
		state.role = team_role

		## Compute target position based on state.
		var target: Vector2 = formation_pos
		var is_receiving_pass: bool = _ball_state.pass_in_flight and _ball_state.pass_target_player == player and _ball_state.pass_is_home == is_home
		if team_celebrating:
			## During celebration, converge toward goal or stay compact.
			if _celebrating_team == (1 if is_home else 0):
				## Celebrating team: move toward attacking goal area.
				var goal_target: Vector2 = _celebration_goal_pos
				target = state.world_position.lerp(goal_target, 0.4)
			else:
				## Defending team: stay in defensive shape, slight retreat to goal.
				target = formation_pos.lerp(_celebration_goal_pos, 0.2)
		elif is_receiving_pass:
			## A pass is heading their way — run to meet it rather than
			## following generic support-run/marking logic. Resolution
			## (complete vs. intercepted) is decided independently by
			## MatchDecisionEngine; this is purely "go get the ball".
			target = _ball_state.pass_receiver_aim_pos
		elif team_has_ball and player == carrier:
			## The ball carrier dribbles forward toward the attacking goal.
			var team_attacks_right: bool = _home_attacks_right if is_home else not _home_attacks_right
			var attack_dir: float = 1.0 if team_attacks_right else -1.0
			var wander: float = sin(Time.get_ticks_msec() * 0.001 + i) * DRIBBLE_WANDER
			target = state.world_position + Vector2(attack_dir * DRIBBLE_ADVANCE_STEP, wander)
			target.x = clamp(target.x, _grass_rect.position.x + PITCH_EDGE_MARGIN, _grass_rect.end.x - PITCH_EDGE_MARGIN)
			target.y = clamp(target.y, _grass_rect.position.y + PITCH_EDGE_MARGIN, _grass_rect.end.y - PITCH_EDGE_MARGIN)
		elif team_has_ball:
			## Support runs: offer a passing option rather than clumping on
			## the carrier — bias forward from the formation slot (a lane
			## ahead of the ball) and separate from nearby teammates so the
			## team spreads into open space instead of bunching up.
			var team_attacks_right: bool = _home_attacks_right if is_home else not _home_attacks_right
			var attack_dir: float = 1.0 if team_attacks_right else -1.0
			var support_anchor: Vector2 = formation_pos + Vector2(attack_dir * FORWARD_SUPPORT_BIAS, 0.0)
			var ball_distance: float = state.world_position.distance_to(_ball_state.position)
			if ball_distance < BALL_TRACKING_RADIUS:
				support_anchor = _ball_state.position.lerp(support_anchor, 0.55)
			target = support_anchor + _separation_offset(is_home, player, state.world_position)
			target.x = clamp(target.x, _grass_rect.position.x + PITCH_EDGE_MARGIN, _grass_rect.end.x - PITCH_EDGE_MARGIN)
			target.y = clamp(target.y, _grass_rect.position.y + PITCH_EDGE_MARGIN, _grass_rect.end.y - PITCH_EDGE_MARGIN)
		else:
			## Defending: only the nearest teammate to the ball presses it
			## tightly; everyone else marks the nearest dangerous opponent
			## near their own zone, or holds formation shape if no one's
			## close enough to be a threat yet.
			var ball_distance: float = state.world_position.distance_to(_ball_state.position)
			var is_closest_defender: bool = _is_closest_teammate_to_ball(is_home, player, lineup, positions)
			if is_closest_defender and ball_distance < PRESSING_RADIUS:
				target = _ball_state.position.lerp(formation_pos, 0.35)
			else:
				var mark_pos: Vector2 = _nearest_opponent_position(is_home, formation_pos)
				if mark_pos != Vector2.INF and formation_pos.distance_to(mark_pos) < MARKING_RADIUS:
					target = formation_pos.lerp(mark_pos, MARKING_BLEND)
				elif ball_distance < BALL_TRACKING_RADIUS:
					target = _ball_state.position.lerp(formation_pos, 0.2)

		state.set_target(target, state.role)

		## Steer velocity toward the target with an acceleration cap, easing
		## down on arrival, instead of snapping straight to a fresh heading
		## every frame — a heuristic target that flip-flops frame-to-frame
		## (e.g. switching who's marking whom) now reads as a natural turn.
		var max_speed: float = BASE_MOVEMENT_SPEED * (player.speed / 100.0)  ## Speed stat affects movement.
		var to_target: Vector2 = target - state.world_position
		var distance: float = to_target.length()
		var desired_speed: float = max_speed if distance >= ARRIVAL_RADIUS else max_speed * (distance / ARRIVAL_RADIUS)
		var desired_velocity: Vector2 = to_target.normalized() * desired_speed if distance > 0.5 else Vector2.ZERO

		state.velocity = state.velocity.move_toward(desired_velocity, ACCELERATION * delta)
		state.world_position += state.velocity * delta
		state.movement_speed = clamp(state.velocity.length() / max_speed, 0.0, 1.0) if max_speed > 0.0 else 0.0

## Push a player's target away from any teammate within SEPARATION_RADIUS so
## off-ball runners spread out into open passing lanes instead of clustering
## around the same patch of grass.
func _separation_offset(is_home: bool, player: Player, from_pos: Vector2) -> Vector2:
	var positions: Dictionary = _home_positions if is_home else _away_positions
	var lineup: Array = _home_lineup if is_home else _away_lineup
	var offset: Vector2 = Vector2.ZERO
	for i in lineup.size():
		var other: Player = lineup[i]
		if other == null or other == player or not positions.has(other):
			continue
		var other_pos: Vector2 = positions[other].world_position
		var to_self: Vector2 = from_pos - other_pos
		var dist: float = to_self.length()
		if dist > 0.01 and dist < SEPARATION_RADIUS:
			offset += to_self.normalized() * (SEPARATION_RADIUS - dist) / SEPARATION_RADIUS * SEPARATION_STRENGTH
	return offset

## True if this player is the closest teammate (on their own side) to the
## ball — used so only one defender presses tightly while the rest mark or
## hold shape, instead of the whole team swarming the ball carrier.
func _is_closest_teammate_to_ball(is_home: bool, player: Player, lineup: Array, positions: Dictionary) -> bool:
	var self_dist: float = positions[player].world_position.distance_to(_ball_state.position)
	for i in lineup.size():
		var other: Player = lineup[i]
		if other == null or other == player or not positions.has(other):
			continue
		if positions[other].world_position.distance_to(_ball_state.position) < self_dist:
			return false
	return true

## Nearest opposing outfield player's current position to a given point, for
## man-marking — returns Vector2.INF if the opposing side has nobody fielded.
func _nearest_opponent_position(is_home: bool, from_pos: Vector2) -> Vector2:
	var opp_formation: Formation = _away_formation if is_home else _home_formation
	var opp_lineup: Array = _away_lineup if is_home else _home_lineup
	var opp_positions: Dictionary = _away_positions if is_home else _home_positions
	var best_dist: float = INF
	var best_pos: Vector2 = Vector2.INF
	for i in opp_lineup.size():
		var opponent: Player = opp_lineup[i]
		if opponent == null or opp_formation.slots[i] == Formation.SlotCategory.GK or not opp_positions.has(opponent):
			continue
		var pos: Vector2 = opp_positions[opponent].world_position
		var dist: float = from_pos.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best_pos = pos
	return best_pos

## Compute formation slot positions (world coords on the pitch).
## Reuses pitch_prototype's layout logic.
func _compute_formation_positions(formation: Formation, field_rect: Rect2, attacks_right: bool) -> Array:
	const CATEGORY_ORDER: Array = [Formation.SlotCategory.GK, Formation.SlotCategory.DEF, Formation.SlotCategory.MID, Formation.SlotCategory.FWD]
	const CATEGORY_DEPTH_FRACTION: Dictionary = {
		Formation.SlotCategory.GK: 0.06,
		Formation.SlotCategory.DEF: 0.28,
		Formation.SlotCategory.MID: 0.52,
		Formation.SlotCategory.FWD: 0.80,
	}
	const ROW_MARGIN_RATIO: float = 0.08

	var counts: Dictionary = {}
	var seen: Dictionary = {}
	for category in CATEGORY_ORDER:
		counts[category] = formation.get_count(category)
		seen[category] = 0

	var positions: Array = []
	positions.resize(formation.slots.size())
	for i in formation.slots.size():
		var category = formation.slots[i]
		var count: int = counts[category]
		var depth_fraction: float = CATEGORY_DEPTH_FRACTION[category]
		var x: float
		if attacks_right:
			x = field_rect.position.x + depth_fraction * (field_rect.size.x / 2.0)
		else:
			x = field_rect.end.x - depth_fraction * (field_rect.size.x / 2.0)
		var top: float = field_rect.position.y + field_rect.size.y * ROW_MARGIN_RATIO
		var usable_height: float = field_rect.size.y * (1.0 - 2.0 * ROW_MARGIN_RATIO)
		var idx_in_row: int = seen[category]
		seen[category] += 1
		var t: float = 0.5 if count <= 1 else (idx_in_row + 0.5) / float(count)
		positions[i] = Vector2(x, top + t * usable_height)
	return positions
