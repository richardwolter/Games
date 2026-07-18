class_name Chance
extends Resource

## Represents a live chance in the match.
## Spawned when pressure crosses a threshold, expires if not taken in time.

## Chance properties
var chance_type: String = "Small"  # Small, Good, Big, Clear-Cut
var xg: float = 0.3  # Expected goal value (0.05-0.95)
var is_home: bool = true
var striker: Player = null  # Pre-selected player who will shoot
var time_spawned: float = 0.0  # Match time (seconds) when spawned
var duration_seconds: float = 20.0  # How long the chance stays live (10-30s)
var taken: bool = false  # Has this chance been resolved yet?

func _init(p_type: String = "Small", p_xg: float = 0.3, p_home: bool = true, p_striker: Player = null, p_time: float = 0.0) -> void:
	chance_type = p_type
	xg = p_xg
	is_home = p_home
	striker = p_striker
	time_spawned = p_time
	# Random duration between 10-30 seconds
	duration_seconds = randf_range(10.0, 30.0)

func is_expired(current_time: float) -> bool:
	## Check if the chance has expired (time limit reached).
	return current_time - time_spawned >= duration_seconds

func take() -> void:
	## Mark this chance as taken (resolving it to goal/save/miss).
	taken = true
