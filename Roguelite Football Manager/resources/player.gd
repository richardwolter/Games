class_name Player
extends Resource

enum Position { GK, CB, FB, DM, CM, CAM, WING, ST }

## First entry is the primary position; any further entries are secondary
## natural positions. See BALANCE.md for OFF_POSITION_PENALTY.
@export var positions: Array = []
@export var player_name: String = ""
@export var speed: int = 0
@export var strength: int = 0
@export var kick: int = 0
@export var passing: int = 0
@export var stamina: int = 0

## Persistent condition (0-100), carried between matches — see BALANCE.md
## "Persistent Condition (Fatigue)". Distinct from LiveMatchState's in-match
## Condition, which this value seeds at the start of each match.
@export var persistent_condition: float = 100.0

const OFF_POSITION_PENALTY := 0.8

func get_overall() -> float:
	return (speed + strength + kick + passing + stamina) / 5.0
