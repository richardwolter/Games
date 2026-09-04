class_name TrackCamera
extends Camera2D

const IsoProjector = preload("res://scenes/iso/iso_projector.gd")

## Follows the car's projected iso position but never rotates with it —
## isometric games use a fixed camera angle, unlike our old flat top-down
## camera that spun with the car's steering.
var target: Node2D

func _physics_process(_delta: float) -> void:
	if is_instance_valid(target):
		global_position = IsoProjector.to_screen(target.global_position)
