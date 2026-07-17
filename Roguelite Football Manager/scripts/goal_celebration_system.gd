class_name GoalCelebrationSystem
extends RefCounted

## Manages goal celebration sequences — pause match, move players toward goal, resume.

signal celebration_started(is_home: bool, duration: float)
signal celebration_finished

const CELEBRATION_DURATION: float = 2.5

var is_home: bool = false
var scorer: Player = null
var duration: float = CELEBRATION_DURATION
var elapsed: float = 0.0
var active: bool = false

func _init(p_is_home: bool, p_scorer: Player) -> void:
	is_home = p_is_home
	scorer = p_scorer
	active = true
	elapsed = 0.0

## Advance celebration timer. Returns true if still active, false if finished.
func update(delta: float) -> bool:
	if not active:
		return false
	elapsed += delta
	if elapsed >= duration:
		active = false
		celebration_finished.emit()
		return false
	return true

## Check if celebration is still running.
func is_active() -> bool:
	return active

## Get progress (0.0 to 1.0).
func get_progress() -> float:
	if duration <= 0.0:
		return 1.0
	return clamp(elapsed / duration, 0.0, 1.0)
