class_name BallState
extends RefCounted

## Ball state during a live match — position, possession, air/ground state.
## Synced with possession_system.gd and rendered by pitch_prototype.gd.

var position: Vector2 = Vector2.ZERO
var in_air: bool = false

## Which team (true=home, false=away) has possession. null=loose ball.
## Untyped (not `bool`) so it can hold null for the loose-ball state.
var possession_team = null

## Which player currently has the ball (null if loose or in-air).
var possession_player: Player = null

## Velocity (world units per second), used for ball trajectory.
var velocity: Vector2 = Vector2.ZERO

## Pass-in-flight state (Milestone 17 unified engine) — while true, nobody
## "has" the ball (possession_player is null) and PossessionSystem.update()
## interpolates position from pass_start_pos to pass_end_pos over
## pass_duration instead of following a carrier or drifting loose. Set by
## MatchDecisionEngine when a pass is attempted; resolved by PossessionSystem
## when pass_elapsed reaches pass_duration.
var pass_in_flight: bool = false
## Which side is passing (for possession-role continuity during flight — the
## passing team keeps making attacking-shaped support runs while it's in the
## air, same as PlayerMovementSystem already does via possession_team).
var pass_is_home: bool = false
## Intended receiver, used only so PlayerMovementSystem can send them to meet
## the ball at pass_receiver_aim_pos — resolution (success/intercepted) is
## independent of whether they actually get there in time.
var pass_target_player: Player = null
var pass_receiver_aim_pos: Vector2 = Vector2.ZERO
## Actual ball-flight endpoints/timing. pass_end_pos is the receiver's
## position on a completed pass, or the interception point on a failed one.
var pass_start_pos: Vector2 = Vector2.ZERO
var pass_end_pos: Vector2 = Vector2.ZERO
var pass_elapsed: float = 0.0
var pass_duration: float = 0.0
var pass_success: bool = false
var pass_interceptor: Player = null

func _init(start_pos: Vector2 = Vector2.ZERO) -> void:
	position = start_pos
	in_air = false
	possession_team = null
	possession_player = null
	velocity = Vector2.ZERO

func set_possession(team_is_home: bool, player: Player) -> void:
	possession_team = team_is_home
	possession_player = player
	in_air = false
	pass_in_flight = false

func loose_ball() -> void:
	possession_team = null
	possession_player = null
	in_air = false
	pass_in_flight = false

func set_in_air(is_air: bool) -> void:
	in_air = is_air

## True when nobody has control of the ball (open for any player to win it).
## A ball mid-pass-flight is not "loose" — it's a targeted event, not open
## for a 50/50 pickup until it actually resolves.
func is_loose() -> bool:
	return possession_player == null and not pass_in_flight

## Start a pass-flight: called by MatchDecisionEngine once it has resolved
## whether the pass succeeds or gets intercepted. `end_pos` is the ball's
## actual flight target (receiver's spot on success, interception point on
## failure); `receiver_aim_pos` is always the intended receiver's spot, used
## purely so they visibly run to meet the ball regardless of outcome.
func start_pass(is_home: bool, target_player: Player, start_pos: Vector2, end_pos: Vector2,
		receiver_aim_pos: Vector2, duration: float, success: bool, interceptor: Player) -> void:
	possession_player = null
	in_air = false
	pass_in_flight = true
	pass_is_home = is_home
	pass_target_player = target_player
	pass_receiver_aim_pos = receiver_aim_pos
	pass_start_pos = start_pos
	pass_end_pos = end_pos
	pass_elapsed = 0.0
	pass_duration = duration
	pass_success = success
	pass_interceptor = interceptor
	position = start_pos
