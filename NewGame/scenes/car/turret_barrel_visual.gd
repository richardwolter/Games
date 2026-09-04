extends Node2D

## Turret logic (targeting/firing) stays in real world space on the Car node.
## This just mirrors the turret's aim rotation, counter-rotated against the
## car body's own rotation since this node is nested inside CarVisual.
var turret_source: Node2D
var car_source: Node2D

func _process(_delta: float) -> void:
	if is_instance_valid(turret_source) and is_instance_valid(car_source):
		rotation = turret_source.rotation - car_source.rotation
