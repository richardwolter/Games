extends Node

signal battery_changed(percent: float)
signal battery_critical()
signal speed_changed(mps: float)
signal charging_started(station_id: String)
signal charging_completed()
signal charge_progress(percent: float)
signal course_finished(success: bool, time_elapsed: float, distance: float, stars: int)
signal checkpoint_reached(index: int)
signal crash_detected()

var current_car_id: String = "default"
var current_track_id: String = ""
var current_course_id: String = ""

var battery_percent: float = 100.0
var speed_mps: float = 0.0
var distance_traveled: float = 0.0
var time_elapsed: float = 0.0
var checkpoints_passed: int = 0
var total_checkpoints: int = 0

var charging_station_id: String = ""
var is_charging: bool = false
var charging_progress: float = 0.0

var course_complete: bool = false
var crash_flag: bool = false

var target_time: float = 0.0    # <= this = 3 stars
var time_limit: float = 0.0     # > this = fail; the countdown deadline
var stars_earned: int = 0
var last_spark_awarded: int = 0

var _was_critical: bool = false

func reset_course(car_id: String, track_id: String, course_id: String, checkpoint_count: int, p_target_time: float, p_time_limit: float):
	current_car_id = car_id
	current_track_id = track_id
	current_course_id = course_id

	battery_percent = 100.0
	speed_mps = 0.0
	distance_traveled = 0.0
	time_elapsed = 0.0
	checkpoints_passed = 0
	total_checkpoints = checkpoint_count

	charging_station_id = ""
	is_charging = false
	charging_progress = 0.0

	course_complete = false
	crash_flag = false
	_was_critical = false

	target_time = p_target_time
	time_limit = p_time_limit
	stars_earned = 0
	last_spark_awarded = 0

	battery_changed.emit(battery_percent)

func update_battery(new_percent: float):
	battery_percent = clampf(new_percent, 0.0, 100.0)
	battery_changed.emit(battery_percent)

	if battery_percent <= 20.0 and not _was_critical:
		_was_critical = true
		battery_critical.emit()
	elif battery_percent > 20.0:
		_was_critical = false

func update_speed(new_speed: float):
	speed_mps = new_speed
	speed_changed.emit(speed_mps)

func update_distance(delta_distance: float):
	distance_traveled += delta_distance

func update_time(delta: float):
	time_elapsed += delta

func start_charging(station_id: String):
	is_charging = true
	charging_station_id = station_id
	charging_progress = 0.0
	charging_started.emit(station_id)

func update_charging(progress: float):
	charging_progress = clampf(progress, 0.0, 1.0)
	charge_progress.emit(charging_progress)

func stop_charging():
	is_charging = false
	charging_station_id = ""
	charging_completed.emit()

func record_checkpoint_hit(index: int):
	checkpoints_passed += 1
	checkpoint_reached.emit(index)

## 3 stars at/under target_time, tapering to 1 star at time_limit, 0 on failure.
func compute_stars() -> int:
	if time_elapsed <= target_time:
		return 3
	var silver_cutoff := target_time + (time_limit - target_time) * 0.5
	if time_elapsed <= silver_cutoff:
		return 2
	if time_elapsed <= time_limit:
		return 1
	return 0

func complete_course(success: bool, stars: int, spark_awarded: int = 0):
	course_complete = true
	stars_earned = stars
	last_spark_awarded = spark_awarded
	course_finished.emit(success, time_elapsed, distance_traveled, stars)

func trigger_crash():
	crash_flag = true
	crash_detected.emit()
