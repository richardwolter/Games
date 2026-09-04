class_name Bullet
extends Area2D

@export var speed: float = 500.0
@export var damage: int = 1
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT

var _age: float = 0.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("zombies") and area.has_method("take_damage"):
		area.take_damage(damage)
		queue_free()
