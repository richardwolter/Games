extends Node
## Headless check of the crow care rules (scripts/care.gd) and how game.gd applies
## them. Run: <godot> --headless --path . tools/test_care.tscn --log-file tools/_care.log
## Writes tools/last_care_test.log; exits 1 on any failure.

const Care = preload("res://scripts/care.gd")

var _frames := 0
var _game: Node
var _fails := 0
var _log: FileAccess

func _ready() -> void:
	_log = FileAccess.open("res://tools/last_care_test.log", FileAccess.WRITE)
	_game = load("res://main.tscn").instantiate()
	add_child(_game)

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	_log.store_line(("PASS " if ok else "FAIL ") + what)
	_log.flush()

func _physics_process(_d: float) -> void:
	_frames += 1
	if _frames != 5:
		return
	_rules()
	_in_game()
	_log.store_line("DONE fails=%d" % _fails)
	_log.flush()
	get_tree().quit(1 if _fails > 0 else 0)

func _rules() -> void:
	_check(Care.loot_mult(Care.STAMINA_MAX) == 1.0, "rested crow loots in full")
	_check(Care.loot_mult(0.0) < Care.loot_mult(Care.LOW_STAMINA * 0.5), "loot falls as stamina falls")
	_check(Care.loot_mult(0.0) == Care.LOOT_MULT_SPENT, "spent crow loots at LOOT_MULT_SPENT")
	_check(Care.injury_chance(10.0) > Care.injury_chance(90.0), "low stamina raises injury chance")
	_check(is_equal_approx(Care.injury_chance(Care.STAMINA_MAX), Care.INJURY_CHANCE_RESTED), "rested injury chance")
	_check(is_equal_approx(Care.injury_chance(0.0), Care.INJURY_CHANCE_SPENT), "spent injury chance")
	_check(Care.after_trip(50.0) == 50.0 - Care.TRIP_STAMINA_COST, "a trip drains stamina")
	_check(Care.after_trip(1.0) == 0.0, "stamina floors at 0")
	_check(Care.after_home_day(20.0, Care.Station.NEST) == 20.0 + Care.NEST_RESTORE, "nest restores")
	_check(Care.after_home_day(95.0, Care.Station.NEST) == Care.STAMINA_MAX, "stamina caps")
	_check(Care.after_home_day(20.0, Care.Station.TRAINING) < Care.after_home_day(20.0, Care.Station.NEST), "nest beats training for rest")
	_check(Care.after_heal(2, Care.Station.FIRST_AID) == 1, "first aid heals a day")
	_check(Care.after_heal(2, Care.Station.NEST) == 2, "only first aid heals")
	_check(not Care.can_assign(1, Care.Station.TRIP), "injured crow cannot trip")
	_check(Care.can_assign(1, Care.Station.NEST), "injured crow can rest")

func _in_game() -> void:
	var crew: Array = _game._crows()
	_check(crew.size() >= 3, "three crows to test with")
	var a = crew[0]
	var b = crew[1]
	var c = crew[2]
	_check(a.station == Care.Station.TRIP, "crows start on Trip")
	a.injury_days = 2
	_check(not _game.assign_station(a, Care.Station.TRIP), "game refuses an injured crow on Trip")
	_check(_game.assign_station(a, Care.Station.FIRST_AID), "injured crow to First aid")
	_check(not _game._trip_crew().has(a), "first-aid crow is off the trip crew")
	_game._care_day(a)
	_check(a.injury_days == 1, "one day on first aid")
	_game._care_day(a)
	_check(a.injury_days == 0, "healed after two days")
	b.stamina = 20.0
	_game.assign_station(b, Care.Station.NEST)
	_game._care_day(b)
	_check(b.stamina == 20.0 + Care.NEST_RESTORE, "nest day restores in game")
	var xp0: int = c.xp
	var money0: int = _game.money
	_game.assign_station(c, Care.Station.TRAINING)
	_game._care_day(c)
	_check(c.xp > xp0, "training grants XP")
	_check(_game.money == money0, "kept home earns nothing")
	_game.assign_station(c, Care.Station.TRIP)
	c.stamina = 100.0
	c.injury_days = 0
	_game._on_crow_landed(c)
	_check(c.stamina == 100.0 - Care.TRIP_STAMINA_COST, "a landed trip drains stamina in game")
	# the stations are placed where the rail is: every station's crows at its slots
	_game._place_crows()
	_check(absf(a.position.x - 1040.0) < 1.0, "first-aid crow perches at its box")
	_game.day_state = _game.DayState.RUNNING
	_check(not _game.assign_station(b, Care.Station.TRIP), "no reassigning once the day runs")
