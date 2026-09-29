extends Node2D
const Text = preload("res://scripts/text.gd")
## Main game: runs the daily trip loop, day/night cycle, food pantry, upgrades shop,
## crow recruiting, and the end-of-day daily report. The crew loiters on the balcony.

const CrowScript = preload("res://scripts/crow.gd")
const CityScript = preload("res://scripts/city.gd")
const Care = preload("res://scripts/care.gd")
const StationsScript = preload("res://scripts/stations.gd")
const MenuScript = preload("res://scripts/ui/menu.gd")

const LOOT_POOL: Array[Dictionary] = [
	{"name": Text.LOOT_BUTTON, "value": 3, "weight": 8},
	{"name": Text.LOOT_CHANGE, "value": 4, "weight": 8},
	{"name": Text.LOOT_FORK, "value": 5, "weight": 6},
	{"name": Text.LOOT_CAP, "value": 8, "weight": 5},
	{"name": Text.LOOT_SPOON, "value": 10, "weight": 4},
	{"name": Text.LOOT_WATCH, "value": 18, "weight": 3},
	{"name": Text.LOOT_EARRING, "value": 22, "weight": 2},
	{"name": Text.LOOT_RING, "value": 35, "weight": 1},
	{"name": Text.LOOT_PEARLS, "value": 60, "weight": 1},
]

const TRIPS_PER_DAY := 3
const FLY_OUT_DURATION := 1.2
const FLY_BACK_DURATION := 1.3
const COLLECT_DURATION := 0.6
const REST_BETWEEN_TRIPS := 1.0
const FOOD_BATCH := 5

const RAIL_PERCH_Y := 484.0

const FOODS: Array[Dictionary] = [
	{"key": "seeds", "name": Text.FOOD_SEEDS, "cost": 2, "effect": Text.FOOD_SEEDS_EFFECT, "start": 12},
	{"key": "berries", "name": Text.FOOD_BERRIES, "cost": 5, "effect": Text.FOOD_BERRIES_EFFECT, "start": 6, "speed": 0.75},
	{"key": "worms", "name": Text.FOOD_WORMS, "cost": 9, "effect": Text.FOOD_WORMS_EFFECT, "start": 3, "luck": 0.25},
]

const UPGRADES: Array[Dictionary] = [
	{"key": "training", "name": Text.UPGRADE_TRAINING, "costs": [50, 90, 150, 240, 380]},
	{"key": "bags", "name": Text.UPGRADE_BAGS, "costs": [75, 130, 210, 330, 500]},
	{"key": "speed", "name": Text.UPGRADE_SPEED, "costs": [100, 170, 270, 420, 650]},
]
const UPGRADE_MAX_LEVEL := 5
const ROSTER_CAP := 6
const RECRUIT_BASE_COST := 150
const RECRUIT_STEP_COST := 100
const CROW_SPACING := 76.0

const RECRUIT_NAMES: Array[String] = [
	"Miso", "Gizmo", "Clover", "Pickle", "Waffles", "Remy",
	"Taco", "Nugget", "Pepper", "Olive", "Biscuit", "Mochi",
]
const SCARF_PASTELS: Array[Color] = [
	Color(0.96, 0.85, 0.6), Color(0.85, 0.9, 0.97), Color(0.93, 0.8, 0.9),
	Color(0.82, 0.94, 0.84), Color(0.98, 0.88, 0.8), Color(0.88, 0.85, 0.96),
	Color(0.9, 0.94, 0.78), Color(0.97, 0.82, 0.75),
]

enum DayState { MORNING, RUNNING, NIGHT, REPORT }

var day := 1
var money := 0
var day_earned := 0
var log_lines: Array[String] = []
var day_state := DayState.MORNING
var _days_pending := 0
var food_stock: Dictionary = {}
var selected_food := "seeds"
var day_speed := 1.0
var day_luck_bonus := 0.0
var upgrade_levels: Dictionary = {"training": 0, "bags": 0, "speed": 0}
var recruit_count := 0

@onready var crows: Node2D = %Crows
@onready var city: CityScript = $City
@onready var balcony: Node2D = $Balcony
@onready var hud: CanvasLayer = %HUD
@onready var dispatch_button: Button = %DispatchButton
@onready var sky = %Sky

var stations: StationsScript
var menu: MenuScript
## Probes that photograph the menu set this; otherwise only the game's own
## scene (parented to the root) wears the boot menu.
static var force_front := false

func _ready() -> void:
	stations = StationsScript.new()
	stations.name = "Stations"
	add_child(stations)
	move_child(stations, crows.get_index())
	stations.setup(self)
	_place_crows()
	for food in FOODS:
		food_stock[food.key] = food.start
	dispatch_button.pressed.connect(_on_dispatch_pressed)
	hud.setup(self)
	_append_log(Text.LOG_INTRO)
	_append_log(Text.LOG_INTRO_TRIPS % TRIPS_PER_DAY)
	sky.phase_changed.connect(_on_sky_phase)
	city.set_night(sky.phase)
	balcony.set_night(sky.phase)
	_update_dispatch_state()
	menu = MenuScript.new()
	menu.name = "Menu"
	menu.hud = hud
	add_child(menu)
	var is_game := get_parent() == get_tree().root
	if (is_game or force_front) and not MenuScript.skip_boot:
		menu.open_boot()
	MenuScript.skip_boot = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dispatch") and not event.is_echo() and not dispatch_button.disabled:
		dispatch_button.pressed.emit()
		get_viewport().set_input_as_handled()

func _crows() -> Array[CrowScript]:
	var result: Array[CrowScript] = []
	for node in crows.get_children():
		if node is CrowScript:
			result.append(node)
	return result

func _place_crows() -> void:
	# Each crow perches on the rail at its care station; the Trip crew spreads
	# over the middle of the rail as before.
	var groups: Dictionary = {}
	for crow in _crows():
		if not groups.has(crow.station):
			groups[crow.station] = []
		groups[crow.station].append(crow)
	for st in groups:
		var members: Array = groups[st]
		for i in members.size():
			var crow: CrowScript = members[i]
			var x: float
			if st == Care.Station.TRIP:
				x = _perch_x_for_index(i, members.size())
			else:
				x = stations.slot_x(st, i, members.size())
			crow.position = Vector2(x, RAIL_PERCH_Y)
			crow.perch = crow.position
			crow.set_loiter(true)

func _trip_crew() -> Array[CrowScript]:
	var result: Array[CrowScript] = []
	for crow in _crows():
		if crow.station == Care.Station.TRIP and crow.injury_days <= 0:
			result.append(crow)
	return result

## Puts a crow on a care station. Mornings only; an injured crow cannot fly.
func assign_station(crow: CrowScript, station: int) -> bool:
	if day_state != DayState.MORNING:
		return false
	if not Care.can_assign(crow.injury_days, station):
		_append_log(Text.LOG_HURT_NO_TRIP % crow.crow_name)
		_place_crows()
		return false
	if crow.station != station:
		crow.station = station
		_append_log(Text.LOG_TO_STATION % [crow.crow_name, StationsScript.label_of(station)])
	_place_crows()
	hud.refresh(self)
	_update_dispatch_state()
	return true

func _perch_x_for_index(i: int, total: int) -> float:
	var view := get_viewport_rect().size
	return view.x * 0.5 + (i - (total - 1) * 0.5) * CROW_SPACING

func _on_sky_phase(p: float) -> void:
	city.set_night(p)
	balcony.set_night(p)

func _on_dispatch_pressed() -> void:
	if day_state == DayState.NIGHT:
		_open_report()
		return
	if day_state != DayState.MORNING:
		return
	var crew := _trip_crew()
	if food_stock[selected_food] < crew.size():
		_append_log(Text.LOG_NO_FOOD % _food_name(selected_food))
		return
	day_state = DayState.RUNNING
	# consume 1 selected food per crow
	for i in crew.size():
		food_stock[selected_food] -= 1
	_append_log(Text.LOG_ATE % [crew.size(), _food_name(selected_food)])
	# apply day effects from the chosen meal and the Fleet Speed upgrade
	day_speed = _fleet_mult()
	day_luck_bonus = 0.0
	var meal: Dictionary = _food(selected_food)
	if meal.has("speed"):
		day_speed *= float(meal.speed)
	if meal.has("luck"):
		day_luck_bonus = float(meal.luck)
	dispatch_button.disabled = true
	dispatch_button.text = Text.DISPATCH_WORKING
	day_earned = 0
	_append_log(Text.LOG_TAKE_OFF % day)
	sky.run_day(_planned_day_duration(crew.size()))
	_days_pending = crew.size()
	if crew.is_empty():
		_append_log(Text.LOG_NOBODY_FLIES)
		get_tree().create_timer(1.0).timeout.connect(_settle_day)
	for i in crew.size():
		var crow: CrowScript = crew[i]
		var offset := 0.4 + i * 0.15 + randf_range(0.0, 0.3)
		get_tree().create_timer(offset).timeout.connect(_run_crow_day.bind(crow, i))
	hud.refresh(self)

func _planned_day_duration(crew_size: int) -> float:
	var max_offset := 0.4 + maxf(0.0, float(crew_size) - 1.0) * 0.15 + 0.3
	var per_trip := (FLY_OUT_DURATION + COLLECT_DURATION + 0.3 + FLY_BACK_DURATION) * day_speed
	var rests := float(TRIPS_PER_DAY - 1) * (REST_BETWEEN_TRIPS + 0.5) * day_speed
	return max_offset + float(TRIPS_PER_DAY) * per_trip + rests

func _run_crow_day(crow: CrowScript, index: int) -> void:
	for trip in range(TRIPS_PER_DAY):
		if crow.injury_days > 0:
			break
		var target := _trip_target(crow, trip)
		var out_tween: Tween = crow.fly_out(target, FLY_OUT_DURATION * day_speed)
		await out_tween.finished
		await get_tree().create_timer((COLLECT_DURATION + randf_range(0.0, 0.3)) * day_speed).timeout
		var back_tween: Tween = crow.fly_back(crow.perch, FLY_BACK_DURATION * day_speed)
		await back_tween.finished
		_on_crow_landed(crow)
		if trip < TRIPS_PER_DAY - 1:
			await get_tree().create_timer((REST_BETWEEN_TRIPS + randf_range(0.0, 0.5)) * day_speed).timeout
	_on_crow_day_done()

func _on_crow_day_done() -> void:
	_days_pending -= 1
	if _days_pending <= 0:
		_settle_day()

func _trip_target(crow: CrowScript, trip: int) -> Vector2:
	var view := get_viewport_rect().size
	# a spot down among the rooftops: later trips reach deeper into the city
	var side := 1.0 if crow.position.x >= view.x * 0.5 else -1.0
	var x := view.x * 0.5 + side * randf_range(80.0, view.x * 0.4)
	var y := 420.0 - trip * 30.0 - randf_range(0.0, 30.0)
	return Vector2(x, y)

func _on_crow_landed(crow: CrowScript) -> void:
	var luck: float = crow.luck + day_luck_bonus
	# a tired crow brings back less (loot scaled by the stamina it left with)
	var tired_mult: float = Care.loot_mult(crow.stamina)
	var coin_gain := int(round((3.0 + randf_range(0.0, 5.0) + luck * 6.0) * tired_mult))
	money += coin_gain
	day_earned += coin_gain
	crow.day_value += coin_gain
	_append_log(Text.LOG_COINS % [crow.crow_name, coin_gain])
	if randf() < _loot_chance(luck) * tired_mult:
		var item: Dictionary = _roll_loot(luck)
		money += item.value
		day_earned += item.value
		crow.day_objects += 1
		crow.day_value += item.value
		_append_log(Text.LOG_LOOT % [crow.crow_name, item.name, item.value])
	if randf() < 0.18:
		var fkey: String = str(FOODS[randi() % FOODS.size()].key)
		var amount := 1 + randi() % 3
		food_stock[fkey] = int(food_stock[fkey]) + amount
		_append_log(Text.LOG_FOUND_FOOD % [crow.crow_name, _food_name(fkey), amount])
	# the trip wears the crow down, and a tired crow can get hurt
	var hurt_chance: float = Care.injury_chance(crow.stamina)
	crow.stamina = Care.after_trip(crow.stamina)
	if randf() < hurt_chance:
		_injure(crow)
	var xp_gain := int(round((4.0 + randf_range(0.0, 3.0) + crow.luck * 7.0) * _xp_mult()))
	var leveled: bool = crow.grant_xp(xp_gain)
	if leveled:
		_append_log(Text.LOG_LEVEL_UP % [crow.crow_name, crow.get_tier_name()])
	hud.refresh(self)
	hud.flash_money()
	_update_dispatch_state()

func _roll_loot(luck: float) -> Dictionary:
	var total := 0.0
	for item in LOOT_POOL:
		total += _loot_weight(item, luck)
	var roll := randf() * total
	for item in LOOT_POOL:
		roll -= _loot_weight(item, luck)
		if roll <= 0.0:
			return item
	return LOOT_POOL[0]

func _loot_weight(item: Dictionary, luck: float) -> float:
	return float(item.weight) * (1.0 + luck * 0.25 * float(item.value) / 5.0)

func _injure(crow: CrowScript) -> void:
	crow.injury_days = randi_range(Care.INJURY_DAYS_MIN, Care.INJURY_DAYS_MAX)
	crow.day_injured = true
	_append_log(Text.LOG_HURT % crow.crow_name)

## A day at home: the station's effect, and nothing earned.
func _care_day(crow: CrowScript) -> void:
	match crow.station:
		Care.Station.TRAINING:
			var leveled: bool = crow.grant_xp(int(round(Care.TRAINING_XP * _xp_mult())))
			if leveled:
				_append_log(Text.LOG_TRAINED_UP % [crow.crow_name, crow.get_tier_name()])
		Care.Station.FIRST_AID:
			var was := crow.injury_days
			crow.injury_days = Care.after_heal(crow.injury_days, crow.station)
			if was > 0 and crow.injury_days == 0:
				_append_log(Text.LOG_HEALED % crow.crow_name)
	crow.stamina = Care.after_home_day(crow.stamina, crow.station)

func _settle_day() -> void:
	for crow in _crows():
		if crow.station != Care.Station.TRIP:
			_care_day(crow)
		elif crow.day_injured:
			# hurt today: straight to the First-aid box for the night
			crow.station = Care.Station.FIRST_AID
	for crow in _trip_crew():
		var leveled: bool = crow.grant_xp(_day_end_xp(crow))
		if leveled:
			_append_log(Text.LOG_REACHED % [crow.crow_name, crow.get_tier_name()])
	_append_log(Text.LOG_DAY_DONE % [day, day_earned])
	day_speed = 1.0
	day_luck_bonus = 0.0
	sky.force_night()
	day_state = DayState.NIGHT
	_place_crows()
	hud.refresh(self)
	_update_dispatch_state()

func _day_end_xp(crow: CrowScript) -> int:
	return int(round((4.0 + crow.luck * 6.0) * _xp_mult()))

func _fleet_mult() -> float:
	return maxf(0.4, 1.0 - 0.06 * int(upgrade_levels["speed"]))

func _xp_mult() -> float:
	return 1.0 + 0.08 * int(upgrade_levels["training"])

func _loot_chance(luck: float) -> float:
	return minf(0.95, 0.5 + luck * 0.35 + 0.06 * int(upgrade_levels["bags"]))

func buy_food(key: String) -> void:
	if not can_shop():
		return
	var food: Dictionary = _food(key)
	var cost := int(food.cost) * FOOD_BATCH
	if money < cost:
		_append_log(Text.LOG_CANT_BUY_FOOD % food.name)
		return
	money -= cost
	food_stock[key] = int(food_stock[key]) + FOOD_BATCH
	_append_log(Text.LOG_BOUGHT_FOOD % [FOOD_BATCH, food.name, cost])
	hud.refresh(self)
	_update_dispatch_state()

func select_food(key: String) -> void:
	if not can_shop():
		return
	if selected_food != key:
		selected_food = key
		_append_log(Text.LOG_MEAL % _food_name(key))
		hud.refresh(self)
		_update_dispatch_state()

func _upgrade(key: String) -> Dictionary:
	for u in UPGRADES:
		if u.key == key:
			return u
	return UPGRADES[0]

func _upgrade_cost(key: String) -> int:
	var level := int(upgrade_levels[key])
	var costs: Array = _upgrade(key).costs
	if level >= costs.size():
		return -1
	return int(costs[level])

func buy_upgrade(key: String) -> void:
	if not can_shop():
		return
	var track: Dictionary = _upgrade(key)
	var level := int(upgrade_levels[key])
	if level >= UPGRADE_MAX_LEVEL:
		_append_log(Text.LOG_MAXED % track.name)
		return
	var cost := _upgrade_cost(key)
	if money < cost:
		_append_log(Text.LOG_CANT_UPGRADE % [track.name, level + 1, cost])
		return
	money -= cost
	upgrade_levels[key] = level + 1
	_append_log(Text.LOG_UPGRADED % [track.name, level + 1, UPGRADE_MAX_LEVEL, cost])
	hud.refresh(self)
	_update_dispatch_state()

func _recruit_cost() -> int:
	return RECRUIT_BASE_COST + RECRUIT_STEP_COST * recruit_count

func recruit_crow() -> void:
	if not can_shop():
		return
	var crew := _crows()
	if crew.size() >= ROSTER_CAP:
		_append_log(Text.LOG_ROSTER_FULL % ROSTER_CAP)
		return
	var cost := _recruit_cost()
	if money < cost:
		_append_log(Text.LOG_CANT_RECRUIT % cost)
		return
	money -= cost
	recruit_count += 1
	var crow: CrowScript = CrowScript.new()
	crow.crow_name = _fresh_recruit_name()
	crow.scarf_color = SCARF_PASTELS[randi() % SCARF_PASTELS.size()]
	crow.base_luck = randf_range(0.45, 0.75)
	crow.luck = crow.base_luck
	crows.add_child(crow)
	_place_crows()
	_append_log(Text.LOG_RECRUITED % [crow.crow_name, cost])
	hud.rebuild_roster()
	hud.refresh(self)
	_update_dispatch_state()

func _fresh_recruit_name() -> String:
	var used: Array[String] = []
	for c in _crows():
		used.append(str(c.crow_name))
	for candidate in RECRUIT_NAMES:
		if not used.has(candidate):
			return candidate
	return RECRUIT_NAMES[randi() % RECRUIT_NAMES.size()]

func _open_report() -> void:
	day_state = DayState.REPORT
	dispatch_button.disabled = true
	hud.show_report(day, _crows())
	_update_dispatch_state()

func start_new_day() -> void:
	day += 1
	day_speed = 1.0
	day_luck_bonus = 0.0
	day_earned = 0
	sky.reset_day()
	for crow in _crows():
		crow.begin_day()
	day_state = DayState.MORNING
	hud.hide_report()
	hud.refresh(self)
	_update_dispatch_state()
	_append_log(Text.LOG_DAY_BEGINS % day)

func can_shop() -> bool:
	return day_state == DayState.MORNING or day_state == DayState.NIGHT

func _food(key: String) -> Dictionary:
	for food in FOODS:
		if food.key == key:
			return food
	return FOODS[0]

func _food_name(key: String) -> String:
	return str(_food(key).name)

func _update_dispatch_state() -> void:
	match day_state:
		DayState.RUNNING:
			dispatch_button.disabled = true
			dispatch_button.text = Text.DISPATCH_WORKING
		DayState.NIGHT:
			dispatch_button.disabled = false
			dispatch_button.text = Text.DISPATCH_NEXT_DAY
		DayState.REPORT:
			dispatch_button.disabled = true
			dispatch_button.text = Text.DISPATCH_NEXT_DAY
		DayState.MORNING:
			var need := _trip_crew().size()
			if food_stock[selected_food] < need:
				dispatch_button.disabled = true
				dispatch_button.text = Text.DISPATCH_NO_FOOD % _food_name(selected_food)
			else:
				dispatch_button.disabled = false
				dispatch_button.text = Text.DISPATCH

func _append_log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 50:
		log_lines.pop_front()
	if hud != null:
		hud.render_log(log_lines)