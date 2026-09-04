class_name ChargingStation
extends Area2D

@export var station_id: String = "station_1"
@export var charge_rate_base: float = 10.0  # % battery per second at charger tier 1

var _car_in_range: Car = null
var _charging: bool = false

func _ready() -> void:
	add_to_group("charging_stations")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Car:
		_car_in_range = body

func _on_body_exited(body: Node2D) -> void:
	if body == _car_in_range:
		if _charging:
			_stop_charging()
		_car_in_range = null

func _physics_process(delta: float) -> void:
	if _car_in_range == null:
		return

	var wants_charge := Input.is_action_pressed("interact")
	var car_stopped := _car_in_range.get_current_speed() < 5.0
	var battery_full := _car_in_range.get_battery_percent() >= 100.0

	if wants_charge and car_stopped and not battery_full:
		if not _charging:
			_start_charging()
		_car_in_range.charge(delta, charge_rate_base)
		TrackState.update_charging(_car_in_range.get_battery_percent() / 100.0)
	elif _charging:
		_stop_charging()

func _start_charging() -> void:
	_charging = true
	TrackState.start_charging(station_id)

func _stop_charging() -> void:
	_charging = false
	TrackState.stop_charging()
