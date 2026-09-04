class_name Checkpoint
extends Area2D

@export var checkpoint_index: int = 0

var _triggered: bool = false

func _ready() -> void:
	add_to_group("checkpoints")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body is Car:
		_triggered = true
		TrackState.record_checkpoint_hit(checkpoint_index)
		modulate = Color(0.4, 1.0, 0.4, 1.0)
