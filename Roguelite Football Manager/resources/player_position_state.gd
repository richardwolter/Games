class_name PlayerPositionState
extends RefCounted

## Per-player, frame-by-frame positional state during a live match.
## Updated by player_movement_system.gd and rendered by pitch_prototype.gd.

enum Role { DEFENDING, TRANSITIONING, ATTACKING, CELEBRATING }

var player: Player
var world_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var role: Role = Role.DEFENDING

## Current velocity (world units/sec) — steered toward the desired direction
## with an acceleration cap each frame (see PlayerMovementSystem) instead of
## snapping straight to a new heading whenever the target changes, so a
## flip-flopping heuristic target reads as a natural turn, not a jitter.
var velocity: Vector2 = Vector2.ZERO

## How fast this player is moving (0-1 scale, affects animation speed).
var movement_speed: float = 0.0

func _init(p_player: Player, start_pos: Vector2) -> void:
	player = p_player
	world_position = start_pos
	target_position = start_pos
	role = Role.DEFENDING
	velocity = Vector2.ZERO
	movement_speed = 0.0

func set_target(pos: Vector2, new_role: Role) -> void:
	target_position = pos
	role = new_role
