class_name Car
extends CharacterBody2D

## Base stats (before upgrades applied)
@export var base_max_speed: float = 220.0          # px/sec
@export var base_acceleration: float = 500.0        # px/sec^2
@export var base_turn_speed: float = 3.5            # rad/sec
@export var friction: float = 300.0                 # px/sec^2 (deceleration when no input)

@export var base_max_battery: float = 100.0
@export var base_drain_idle: float = 2.0            # % per second, always draining while driving
@export var base_drain_per_speed_unit: float = 0.012 # % per second, scaled by current speed

var driving: bool = false

var max_speed: float
var acceleration: float
var max_battery: float
var drain_idle: float
var drain_per_speed_unit: float
var chassis_efficiency: float = 1.0                 # 1.0 = no reduction; lower tiers reduce drain
var charger_multiplier: float = 1.0

var battery_percent: float = 100.0
var current_speed: float = 0.0

func _ready() -> void:
	_apply_base_stats()

func _apply_base_stats() -> void:
	max_speed = base_max_speed
	acceleration = base_acceleration
	max_battery = base_max_battery
	drain_idle = base_drain_idle
	drain_per_speed_unit = base_drain_per_speed_unit

## Apply upgrade tiers from GameState. Tiers are 1-based (tier 1 = no bonus).
func apply_upgrades(battery_tier: int, motor_tier: int, chassis_tier: int, charger_tier: int) -> void:
	max_battery = base_max_battery * pow(1.5, battery_tier - 1)
	max_speed = base_max_speed * pow(1.25, motor_tier - 1)
	acceleration = base_acceleration * pow(1.25, motor_tier - 1)
	chassis_efficiency = 1.0 - (0.1 * (chassis_tier - 1))
	charger_multiplier = pow(1.5, charger_tier - 1)

func start() -> void:
	driving = true
	battery_percent = 100.0

func stop() -> void:
	driving = false
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not driving:
		return

	if battery_percent <= 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	var steer := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")

	if throttle != 0.0:
		rotation += steer * base_turn_speed * delta * sign(throttle)
	else:
		rotation += steer * base_turn_speed * delta * 0.5

	var forward := Vector2.RIGHT.rotated(rotation)

	if throttle != 0.0:
		velocity += forward * throttle * acceleration * delta
		velocity = velocity.limit_length(max_speed)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

	current_speed = velocity.length()
	_drain_battery(delta)

	TrackState.update_speed(current_speed)
	TrackState.update_distance(current_speed * delta)

func _drain_battery(delta: float) -> void:
	var speed_drain := current_speed * drain_per_speed_unit
	var total_drain := (drain_idle + speed_drain) * chassis_efficiency * delta
	battery_percent = clampf(battery_percent - total_drain, 0.0, 100.0)
	TrackState.update_battery(battery_percent)

func charge(delta: float, base_rate_per_sec: float) -> void:
	var rate := base_rate_per_sec * charger_multiplier
	battery_percent = clampf(battery_percent + rate * delta, 0.0, 100.0)
	TrackState.update_battery(battery_percent)

## Called by Zombie on collision: cuts current velocity and drains battery.
func apply_bump_penalty(slow_factor: float, energy_drain: float) -> void:
	velocity *= slow_factor
	battery_percent = clampf(battery_percent - energy_drain, 0.0, 100.0)
	TrackState.update_battery(battery_percent)
	_flash_hit()

func _flash_hit() -> void:
	modulate = Color(2.2, 0.6, 0.6, 1)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.2)

func is_low_battery() -> bool:
	return battery_percent <= 20.0

func get_battery_percent() -> float:
	return battery_percent

func get_current_speed() -> float:
	return current_speed
