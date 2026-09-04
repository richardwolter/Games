class_name GoalZone
extends Area2D

signal car_reached_goal()

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Car:
		car_reached_goal.emit()
