class_name Zombie
extends Area2D

@export var health: int = 2
@export var wander_speed: float = 30.0
@export var wander_range: float = 60.0
@export var slow_factor: float = 0.35   ## velocity multiplier applied to the car on hit
@export var energy_drain: float = 8.0   ## % battery drained on hit
@export var bump_cooldown_time: float = 1.0

var _spawn_y: float
var _dir: float = 1.0
var _bump_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("zombies")
	_spawn_y = position.y
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _bump_cooldown > 0.0:
		_bump_cooldown -= delta

	position.y += _dir * wander_speed * delta
	if absf(position.y - _spawn_y) > wander_range:
		_dir *= -1.0

func _on_body_entered(body: Node2D) -> void:
	if body is Car and _bump_cooldown <= 0.0:
		_bump_cooldown = bump_cooldown_time
		body.apply_bump_penalty(slow_factor, energy_drain)

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()
	else:
		_flash()

func _flash() -> void:
	modulate = Color(2.2, 2.2, 2.2, 1)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.15)
