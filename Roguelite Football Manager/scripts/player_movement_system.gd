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
const DRIBBLE_ADVANCE_STEP := 75.0
## Lateral wander amplitude (world units) layered on the carrier's dribble.
const DRIBBLE_WANDER := 12.0
## Minimum distance (world units) any player's target is kept from the
## pitch boundary, so a dribbling run doesn't clamp exactly on the line.
const PITCH_EDGE_MARGIN := 20.0

## Off-ball attacking spacing: teammates within this radius of each other
## push apart, so support runners spread into open passing lanes instead of
## clumping around the ball carrier.
const SEPARATION_RADIUS := 110.0
const SEPARATION_STRENGTH := 55.0

## How far an off-ball attacker pushes forward (toward the opponent's goal)
## from their formation slot while their team has the ball, by slot category
## — bigger for further-forward roles so the team commits real numbers into
## the attacking third to create chances, not just a uniform nudge. This is
## the team's attacking shape and applies regardless of where the ball
## currently is (see ATTACK_BALL_PULL below for the small ball-side nudge
## layered on top).
const ATTACK_PUSH_BY_CATEGORY: Dictionary = {
	Formation.SlotCategory.DEF: 200.0,
	Formation.SlotCategory.MID: 280.0,
	Formation.SlotCategory.FWD: 310.0,
}
## How much support runners lean toward the ball's side of the pitch on top
## of their attacking-shape target — kept small so the team occupies the
## whole width/depth of the attacking third instead of the whole shape
## collapsing onto wherever the ball happens to be. Trimmed further (and
## width stretch tightened) so the team reads as organized lines/blocks
## moving together rather than everyone drifting individually and leaving
## gaps in the shape.
const ATTACK_BALL_PULL := 0.06
## Off-ball attackers stretch wider from the pitch's vertical center than
## their formation slot would alone, so wide players hug the touchlines and
## open up the pitch instead of everyone bunching toward the middle. Kept
## modest so the line stays a coherent block rather than spreading thin.
const ATTACK_WIDTH_STRETCH := 1.15

## Box-crashing: once the carrier is both deep in the final third and out
## wide (a crossing position), other attacking (MID/FWD) teammates abandon
## the normal width-stretched shape and instead crowd the six-yard/penalty
## area to be there for a cutback or cross — the actual chance-creation
## moment, not just general attacking shape.
const CROSS_ZONE_DEPTH := 320.0
const CROSS_ZONE_WIDE_Y := 140.0
## How far in front of the goal line the crowding attackers aim for, and
## the lateral spread between them (near post / center / far post) so they
## don't all converge on the exact same spot.
const BOX_CRASH_DEPTH := 90.0
const BOX_CRASH_WIDTH_SPREAD := 110.0
## Collective advance: on top of the fixed per-category push above, the
## whole team (defenders included) steps further forward as their own
## carrier gets deeper into the attacking half — attacking is a team-wide
## commitment, not just the forwards holding a fixed high line while
## everyone else stays home. Mirrors DEFENSIVE_LINE_MAX_PUSH's shape but for
## the side that has the ball.
const ATTACK_LINE_MAX_PUSH := 170.0

## Defending: a marker only picks up an opposing attacker within this range
## of their own formation slot — keeps markers from abandoning their zone
## for an opponent on the far side of the pitch.
const MARKING_RADIUS := 320.0
## How much a marker leans from their formation slot toward their mark
## (0 = ignore mark and hold shape, 1 = stand exactly on the mark).
const MARKING_BLEND := 0.5
## Only the single nearest (non-GK) defender presses the ball/carrier
## tightly within this range; everyone else covers a mark or a passing
## lane instead of swarming the ball (see _update_team / _update_presser).
## The range itself grows (up to PRESSING_RADIUS_ATTACK_BONUS extra) the
## further forward the team's press line has already pushed, so a team
## already pressing high commits to actually closing the ball down out in
## the opponent's half instead of only engaging once it drifts back deep.
const PRESSING_RADIUS := 260.0
const PRESSING_RADIUS_ATTACK_BONUS := 160.0

## How far a marker sits toward its own goal from a straight man-mark, so
## non-pressing defenders shade goal-side of their opponent (cutting the
## direct pass/run) instead of standing exactly on top of them.
const MARK_GOAL_SIDE_BIAS := 35.0

## Defensive block push: how far (world units) the whole out-of-possession
## team's reference shape shifts toward the opponent's goal as the ball
## moves further into the team's own attacking half — encourages winning
## the ball back high up the pitch (pressing) rather than only engaging
## once play reaches deep inside the team's own half.
const DEFENSIVE_LINE_MAX_PUSH := 160.0

## Goalkeeper containment: GK never leaves this radius of their own goal
## line/box, and is excluded from pressing/marking entirely. Lateral
## tracking is scaled by how close the ball is to goal (GK_ACTIVE_RANGE) —
## a keeper stays centered/goal-protective while the ball is out in
## midfield or the opponent's half, and only actively shifts across the
## line once the ball is genuinely dangerous, near their own box.
const GK_BOX_DEPTH := 90.0
const GK_LATERAL_RANGE := 140.0
const GK_ACTIVE_RANGE := 320.0
## Minimum lateral tracking even when the ball is far away, so the keeper
## still leans very slightly rather than standing dead-still on the spot.
const GK_MIN_TRACKING := 0.15

## Press-assignment stickiness: once a defender is pressing, another
## teammate only takes over once they're this much closer to the ball, and
## not before PRESS_MIN_HOLD_TIME has passed — without this, two similarly-
## placed defenders could swap the presser role every frame, reading as
## indecisive jitter instead of one player committing to close the ball down.
const PRESS_STICKINESS_MARGIN := 40.0
const PRESS_MIN_HOLD_TIME := 0.6

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

## Sticky press-assignment state, per side (see PRESS_STICKINESS_MARGIN).
var _home_presser: Player = null
var _away_presser: Player = null
var _home_press_hold: float = 0.0
var _away_press_hold: float = 0.0

## Dead-ball restart override (see DeadBallSystem): while set, the taker
## walks straight to the restart spot instead of following their normal
## role logic; every other player keeps reacting normally (marking/support
## runs), per Designer's call that only the taker should be scripted.
var _dead_ball_taker: Player = null
var _dead_ball_target: Vector2 = Vector2.ZERO
var _dead_ball_awarded_home: bool = true

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

## The pitch's world-space grass bounds, for callers (e.g. DeadBallSystem,
## PossessionSystem's byline placement) that need the same boundary this
## system already clamps movement targets to.
func get_grass_rect() -> Rect2:
	return _grass_rect

## Called by DeadBallSystem once a taker is chosen for a throw-in/corner/
## goal-kick: that single player heads straight for the restart spot every
## frame instead of their normal role target, until `clear_dead_ball_taker`
## is called (restart played, or a new one overrides it).
func set_dead_ball_taker(taker: Player, target_pos: Vector2, awarded_home: bool) -> void:
	_dead_ball_taker = taker
	_dead_ball_target = target_pos
	_dead_ball_awarded_home = awarded_home

func clear_dead_ball_taker() -> void:
	_dead_ball_taker = null

## True once the current taker has actually reached the restart spot, so
## DeadBallSystem knows when to move from "walking" to "playing it".
func dead_ball_taker_arrived(is_home: bool) -> bool:
	if _dead_ball_taker == null:
		return false
	var positions: Dictionary = _home_positions if is_home else _away_positions
	if not positions.has(_dead_ball_taker):
		return true
	return positions[_dead_ball_taker].world_position.distance_to(_dead_ball_target) <= ARRIVAL_RADIUS

## Return current velocity (world units/sec) for a given player, used to
## offset the ball toward the direction the carrier is actually moving.
func get_player_velocity(is_home: bool, slot_index: int) -> Vector2:
	var positions: Dictionary = _home_positions if is_home else _away_positions
	var lineup: Array = _home_lineup if is_home else _away_lineup
	if slot_index >= 0 and slot_index < lineup.size():
		var player: Player = lineup[slot_index]
		if player != null and positions.has(player):
			return positions[player].velocity
	return Vector2.ZERO

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
	var formation: Formation = _home_formation if is_home else _away_formation

	## Check if celebrating.
	var team_celebrating: bool = is_celebrating(is_home)

	## Determine team role based on ball possession or celebration state.
	## While a dead-ball restart is pending, nobody technically "possesses"
	## the ball (BallState.possession_team is null) — treat the side it's
	## being awarded to as the attacking team anyway, so their off-ball
	## players push into support-run shape and the other side drops into a
	## defensive shape ahead of the restart, instead of both sides freezing
	## in a neutral stance until the ball is actually kicked.
	var team_has_ball: bool
	if _ball_state.dead_ball_active:
		team_has_ball = _dead_ball_awarded_home == is_home
	else:
		team_has_ball = _ball_state.possession_team == is_home if _ball_state.possession_team != null else false
	var team_role: PlayerPositionState.Role
	if team_celebrating:
		team_role = PlayerPositionState.Role.CELEBRATING
	else:
		team_role = PlayerPositionState.Role.ATTACKING if team_has_ball else PlayerPositionState.Role.DEFENDING
	var carrier: Player = _ball_state.possession_player
	## Nobody has the ball and it's not a pass in flight — a genuine loose
	## ball both sides should actively chase down, not just hold a pressing
	## stand-off distance from (see the defending branch below).
	var ball_loose: bool = _ball_state.is_loose()
	var presser: Player = null
	## How far the defensive block pushes toward the opponent's goal this
	## frame — more push the further the ball already is into this team's
	## own attacking half, so the team engages/presses high rather than
	## only when the ball reaches deep inside their own half.
	var press_shift: float = 0.0
	## Collective forward advance while attacking — the whole team (not just
	## forwards) steps up together as their own carrier progresses upfield.
	var attack_shift: float = 0.0
	## True once the carrier is deep in the final third and out wide — a
	## crossing position where the priority shifts from holding attacking
	## shape to crowding the box for the actual chance.
	var is_crossing_situation: bool = false
	if not team_celebrating and not team_has_ball:
		presser = _update_presser(is_home, positions, formation, delta)
		press_shift = _line_shift(is_home, DEFENSIVE_LINE_MAX_PUSH)
	elif not team_celebrating and team_has_ball:
		attack_shift = _line_shift(is_home, ATTACK_LINE_MAX_PUSH)
		if carrier != null and positions.has(carrier):
			var carrier_pos: Vector2 = positions[carrier].world_position
			var goal_dist: float = carrier_pos.distance_to(_opponent_goal_pos(is_home))
			var wide_offset: float = absf(carrier_pos.y - _grass_rect.get_center().y)
			is_crossing_situation = goal_dist < CROSS_ZONE_DEPTH and wide_offset > CROSS_ZONE_WIDE_Y

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
		var is_gk: bool = formation.slots[i] == Formation.SlotCategory.GK
		if player == _dead_ball_taker:
			## Taking a throw-in/corner/goal-kick: walk straight to the
			## restart spot, overriding every other role (GK included — a
			## goal kick's taker IS the GK). DeadBallSystem clears this once
			## the restart is played.
			target = _dead_ball_target
		elif is_gk and not team_celebrating:
			## Goalkeeper never joins pressing/marking/support-run logic —
			## stays in the box, tracking the ball laterally with a small
			## forward creep for shots/crosses, and never leaves the goal area.
			target = _gk_target(is_home, formation_pos)
		elif team_celebrating:
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
		elif team_has_ball and is_crossing_situation and formation.slots[i] in [Formation.SlotCategory.MID, Formation.SlotCategory.FWD]:
			## The carrier is in a wide, deep crossing position — the priority
			## shifts from holding attacking shape to crowding the box for
			## the actual chance. Spread candidates across near post /
			## center / far post instead of everyone converging on the same
			## spot.
			var opp_goal_pos: Vector2 = _opponent_goal_pos(is_home)
			var team_attacks_right_box: bool = _home_attacks_right if is_home else not _home_attacks_right
			var attack_dir_box: float = 1.0 if team_attacks_right_box else -1.0
			var lane: float = float(i % 3) - 1.0  ## -1, 0, 1 across the box.
			var box_target: Vector2 = Vector2(opp_goal_pos.x - attack_dir_box * BOX_CRASH_DEPTH, opp_goal_pos.y + lane * BOX_CRASH_WIDTH_SPREAD)
			target = box_target + _separation_offset(is_home, player, state.world_position)
		elif team_has_ball:
			## Support runs: the team occupies an attacking shape — pushed
			## forward by category (defenders creep up, forwards commit into
			## the box) and stretched wider than formation-flat so the whole
			## width of the pitch is used to create chances, with only a
			## small lean toward the ball's side layered on top instead of
			## the whole team collapsing onto wherever the ball currently is.
			var team_attacks_right: bool = _home_attacks_right if is_home else not _home_attacks_right
			var attack_dir: float = 1.0 if team_attacks_right else -1.0
			var push: float = ATTACK_PUSH_BY_CATEGORY.get(formation.slots[i], 90.0)
			var center_y: float = _grass_rect.get_center().y
			var stretched_y: float = center_y + (formation_pos.y - center_y) * ATTACK_WIDTH_STRETCH
			var support_anchor: Vector2 = Vector2(formation_pos.x + attack_dir * push + attack_shift, stretched_y)
			support_anchor = support_anchor.lerp(_ball_state.position, ATTACK_BALL_PULL)
			if player == _ball_state.likely_receiver:
				support_anchor = _ball_state.position.lerp(support_anchor, 0.6)
			target = support_anchor + _separation_offset(is_home, player, state.world_position)
			target.x = clamp(target.x, _grass_rect.position.x + PITCH_EDGE_MARGIN, _grass_rect.end.x - PITCH_EDGE_MARGIN)
			target.y = clamp(target.y, _grass_rect.position.y + PITCH_EDGE_MARGIN, _grass_rect.end.y - PITCH_EDGE_MARGIN)
		else:
			## Defending: only the nearest teammate to the ball presses it
			## tightly; everyone else marks the nearest dangerous opponent
			## near their own zone, or holds formation shape if no one's
			## close enough to be a threat yet.
			var pressed_formation_pos: Vector2 = formation_pos + Vector2(press_shift, 0.0)
			var ball_distance: float = state.world_position.distance_to(_ball_state.position)
			var is_closest_defender: bool = player == presser
			## A team already pressing high (press_shift near its cap) gets a
			## longer pressing leash, so the presser actually chases the ball
			## down out in the opponent's half instead of only engaging once
			## it comes back within a fixed short radius.
			var pressing_radius: float = PRESSING_RADIUS + (absf(press_shift) / DEFENSIVE_LINE_MAX_PUSH) * PRESSING_RADIUS_ATTACK_BONUS
			if is_closest_defender and ball_loose:
				## A genuine loose ball (rebound, turnover, miscontrol) is a
				## real 50/50 to win, not a shaped press on a moving carrier
				## — go straight at it at full effort instead of holding a
				## pressing stand-off distance or waiting for it to enter
				## pressing_radius, which otherwise left loose balls with
				## nobody actually closing in from either side.
				target = _ball_state.position
			elif is_closest_defender and ball_distance < pressing_radius:
				target = _ball_state.position.lerp(pressed_formation_pos, 0.35)
			else:
				var mark_pos: Vector2 = _nearest_opponent_position(is_home, pressed_formation_pos)
				if mark_pos != Vector2.INF and pressed_formation_pos.distance_to(mark_pos) < MARKING_RADIUS:
					var own_goal_pos: Vector2 = _own_goal_pos(is_home)
					var goal_side_mark: Vector2 = mark_pos + (own_goal_pos - mark_pos).normalized() * MARK_GOAL_SIDE_BIAS
					target = pressed_formation_pos.lerp(goal_side_mark, MARKING_BLEND)
				elif ball_distance < BALL_TRACKING_RADIUS:
					target = _ball_state.position.lerp(pressed_formation_pos, 0.2)
				else:
					target = pressed_formation_pos
				target += _separation_offset(is_home, player, state.world_position)

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

## This team's own goal-mouth position — used to shade markers goal-side of
## their opponent rather than standing exactly on top of them.
func _own_goal_pos(is_home: bool) -> Vector2:
	var team_attacks_right: bool = _home_attacks_right if is_home else not _home_attacks_right
	var goal_x: float = _grass_rect.position.x if team_attacks_right else _grass_rect.end.x
	return Vector2(goal_x, _grass_rect.get_center().y)

## The goal this team is attacking — used to detect a crossing situation
## (carrier close to and wide of this goal) so teammates know to crowd the
## box rather than hold general attacking shape.
func _opponent_goal_pos(is_home: bool) -> Vector2:
	var team_attacks_right: bool = _home_attacks_right if is_home else not _home_attacks_right
	var goal_x: float = _grass_rect.end.x if team_attacks_right else _grass_rect.position.x
	return Vector2(goal_x, _grass_rect.get_center().y)

## Goalkeeper target: stays anchored to their formation slot (already close
## to their own goal line), only creeping toward the ball laterally and a
## short distance forward, clamped to a small box around the goal line so
## they never join outfield pressing/marking/dribbling.
func _gk_target(is_home: bool, formation_pos: Vector2) -> Vector2:
	var team_attacks_right: bool = _home_attacks_right if is_home else not _home_attacks_right
	var goal_x: float = _grass_rect.position.x if team_attacks_right else _grass_rect.end.x
	var forward_dir: float = 1.0 if team_attacks_right else -1.0
	var ball_depth: float = absf(_ball_state.position.x - goal_x)
	## Danger scales from GK_MIN_TRACKING (ball far away — stay centered) up
	## to 1.0 (ball right on top of the box — track it closely).
	var danger: float = lerp(1.0, GK_MIN_TRACKING, clamp(ball_depth / GK_ACTIVE_RANGE, 0.0, 1.0))
	var target_y: float = lerp(formation_pos.y, clamp(_ball_state.position.y, formation_pos.y - GK_LATERAL_RANGE, formation_pos.y + GK_LATERAL_RANGE), danger)
	var forward_creep: float = clamp(ball_depth * 0.08, 0.0, GK_BOX_DEPTH)
	return Vector2(goal_x + forward_dir * forward_creep, target_y)

## How far (world units, signed toward the opponent's goal) this team's whole
## shape should push up the pitch this frame — scales with how deep the ball
## already is into the team's own attacking half, capped at `max_push`, and
## zero once the ball is in the team's own defensive half. Shared by both
## sides of the ball: the defending team uses it to press higher once the
## ball is already advanced (DEFENSIVE_LINE_MAX_PUSH), and the attacking
## team uses it so the whole side — defenders included — steps forward
## together as their own carrier advances (ATTACK_LINE_MAX_PUSH), instead of
## only the forwards holding a fixed high line.
func _line_shift(is_home: bool, max_push: float) -> float:
	var team_attacks_right: bool = _home_attacks_right if is_home else not _home_attacks_right
	var attack_dir: float = 1.0 if team_attacks_right else -1.0
	var center_x: float = _grass_rect.get_center().x
	var ball_progress: float = ((_ball_state.position.x - center_x) / (_grass_rect.size.x / 2.0)) * attack_dir
	return clamp(ball_progress, 0.0, 1.0) * max_push * attack_dir

## Sticky version of "nearest teammate to the ball": keeps the current
## presser unless a teammate is now closer by more than
## PRESS_STICKINESS_MARGIN, or the current presser has held the role for at
## least PRESS_MIN_HOLD_TIME. Prevents two similarly-placed defenders from
## swapping the pressing role every frame.
func _update_presser(is_home: bool, positions: Dictionary, formation: Formation, delta: float) -> Player:
	var lineup: Array = _home_lineup if is_home else _away_lineup
	var current: Player = _home_presser if is_home else _away_presser
	var hold: float = _home_press_hold if is_home else _away_press_hold

	var nearest: Player = null
	var nearest_dist: float = INF
	var current_dist: float = INF
	for i in lineup.size():
		var player: Player = lineup[i]
		if player == null or not positions.has(player) or formation.slots[i] == Formation.SlotCategory.GK:
			continue
		var dist: float = positions[player].world_position.distance_to(_ball_state.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = player
		if player == current:
			current_dist = dist

	if current == null or not positions.has(current):
		current = nearest
		hold = 0.0
	elif hold >= PRESS_MIN_HOLD_TIME and current_dist > nearest_dist + PRESS_STICKINESS_MARGIN:
		current = nearest
		hold = 0.0
	else:
		hold += delta

	if is_home:
		_home_presser = current
		_home_press_hold = hold
	else:
		_away_presser = current
		_away_press_hold = hold
	return current

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
