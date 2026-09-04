extends Node

const SAVE_PATH = "user://charge_save.json"

var total_spark: int = 0
var unlocked_courses: Array[String] = []
var car_upgrades: Dictionary = {}  # car_id -> {battery_tier, motor_tier, chassis_tier, charger_tier}
var best_times: Dictionary = {}    # course_id -> float seconds
var best_stars: Dictionary = {}    # course_id -> int (0-3)
var total_distance: float = 0.0
var total_time: float = 0.0
var achievements: Array[String] = []

func _ready():
	load_game()
	if not unlocked_courses.has("track_1/course_1"):
		unlock_course("track_1/course_1")
	_ensure_car_upgrades("default")

func _ensure_car_upgrades(car_id: String):
	if not car_upgrades.has(car_id):
		car_upgrades[car_id] = {
			"battery_tier": 1,
			"motor_tier": 1,
			"chassis_tier": 1,
			"charger_tier": 1
		}

func add_spark(amount: int):
	total_spark += amount
	save_game()

## Spark payout scales with stars earned (1-3). Returns the amount awarded.
func award_spark_for_course(course_id: String, time_taken: float, spark_reward: int, stars: int) -> int:
	var awarded := int(round(spark_reward * clampi(stars, 0, 3) / 3.0))
	total_spark += awarded
	total_time += time_taken

	if not best_times.has(course_id) or time_taken < best_times[course_id]:
		best_times[course_id] = time_taken

	if not best_stars.has(course_id) or stars > best_stars[course_id]:
		best_stars[course_id] = stars

	save_game()
	return awarded

func unlock_course(course_id: String):
	if not unlocked_courses.has(course_id):
		unlocked_courses.append(course_id)
		save_game()

func can_afford_upgrade(car_id: String, stat_type: String, tier: int) -> bool:
	var cost = get_upgrade_cost(stat_type, tier)
	return total_spark >= cost

func upgrade_car_stat(car_id: String, stat_type: String, tier: int) -> bool:
	_ensure_car_upgrades(car_id)
	var cost = get_upgrade_cost(stat_type, tier)

	if total_spark < cost:
		return false

	total_spark -= cost
	car_upgrades[car_id][stat_type] = tier
	save_game()
	return true

func get_upgrade_cost(stat_type: String, tier: int) -> int:
	var base_costs = {
		"battery_tier": 50,
		"motor_tier": 75,
		"chassis_tier": 60,
		"charger_tier": 80
	}
	return base_costs.get(stat_type, 50) * tier

func get_car_config(car_id: String) -> Dictionary:
	_ensure_car_upgrades(car_id)
	return car_upgrades[car_id]

func reset_game():
	total_spark = 0
	unlocked_courses = ["track_1/course_1"]
	car_upgrades = {}
	best_times = {}
	best_stars = {}
	total_distance = 0.0
	total_time = 0.0
	achievements = []
	_ensure_car_upgrades("default")
	save_game()

func save_game():
	var data = {
		"total_spark": total_spark,
		"unlocked_courses": unlocked_courses,
		"car_upgrades": car_upgrades,
		"best_times": best_times,
		"best_stars": best_stars,
		"total_distance": total_distance,
		"total_time": total_time,
		"achievements": achievements
	}
	var json_str = JSON.stringify(data)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_str)

		if error == OK:
			var data = json.data
			total_spark = data.get("total_spark", 0)
			unlocked_courses.assign(data.get("unlocked_courses", ["track_1/course_1"]))
			car_upgrades = data.get("car_upgrades", {})
			best_times = data.get("best_times", {})
			best_stars = data.get("best_stars", {})
			total_distance = data.get("total_distance", 0.0)
			total_time = data.get("total_time", 0.0)
			achievements.assign(data.get("achievements", []))
