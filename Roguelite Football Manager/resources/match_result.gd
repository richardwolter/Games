class_name MatchResult
extends Resource

@export var home_name: String = ""
@export var away_name: String = ""
@export var home_score: int = 0
@export var away_score: int = 0

## Milestone 20: match statistics for the result screen. Transient (not part
## of a persisted save — last_match_result is a handoff), so defaults are fine
## when loading an older save that never set them.
@export var home_shots: int = 0
@export var away_shots: int = 0
@export var home_shots_on_target: int = 0
@export var away_shots_on_target: int = 0
@export var home_xg: float = 0.0
@export var away_xg: float = 0.0
@export var home_possession: int = 50
@export var away_possession: int = 50
