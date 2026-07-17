class_name MatchFlowEngine
extends RefCounted

## Manages match time progression, half-time pause, and injury time.
## Emits signals when key match events occur (half-time, injury time, full time).

signal half_time_reached
signal injury_time_announced(minutes: int)
signal match_ended

const MATCH_MINUTES := 90
const INJURY_TIME_FIRST_HALF_MIN := 2
const INJURY_TIME_FIRST_HALF_MAX := 5
const INJURY_TIME_SECOND_HALF_MIN := 3
const INJURY_TIME_SECOND_HALF_MAX := 6

var minute: int = 0
var injury_time_minutes: int = 0
var is_first_half: bool = true
var at_half_time: bool = false
var finished: bool = false

func _init() -> void:
	minute = 0
	injury_time_minutes = 0
	is_first_half = true
	at_half_time = false
	finished = false

## Advance one simulated minute. Returns true if match is still ongoing.
func advance_minute() -> bool:
	if finished:
		return false

	minute += 1

	## Check for half-time.
	if minute == 45 and is_first_half:
		at_half_time = true
		_generate_first_half_injury_time()
		half_time_reached.emit()
		return true

	## If resuming from half-time, transition to second half.
	if at_half_time and is_first_half:
		at_half_time = false
		is_first_half = false
		minute = 45  # Will increment to 46 on next call

	## Check for full time.
	if minute >= MATCH_MINUTES + injury_time_minutes:
		finished = true
		match_ended.emit()
		return false

	return true

## Pause at half-time — caller should wait for player to click Continue.
func pause_at_half_time() -> void:
	at_half_time = true

## Resume from half-time pause.
func resume_from_half_time() -> void:
	if at_half_time and is_first_half:
		_generate_first_half_injury_time()
		at_half_time = false
		is_first_half = false

## Announce second-half injury time when approaching minute 90.
func check_announce_second_half_injury_time() -> void:
	if minute == MATCH_MINUTES and not is_first_half and injury_time_minutes == 0:
		_generate_second_half_injury_time()

func get_display_minute() -> String:
	if at_half_time:
		return "HT"
	var base: int = minute if is_first_half else (minute - 45)
	if base > MATCH_MINUTES:
		return "%d+%d" % [MATCH_MINUTES, base - MATCH_MINUTES]
	return str(base)

func _generate_first_half_injury_time() -> void:
	injury_time_minutes = randi_range(INJURY_TIME_FIRST_HALF_MIN, INJURY_TIME_FIRST_HALF_MAX)
	injury_time_announced.emit(injury_time_minutes)

func _generate_second_half_injury_time() -> void:
	injury_time_minutes = randi_range(INJURY_TIME_SECOND_HALF_MIN, INJURY_TIME_SECOND_HALF_MAX)
	injury_time_announced.emit(injury_time_minutes)
