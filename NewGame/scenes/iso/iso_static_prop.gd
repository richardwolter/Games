class_name IsoStaticProp
extends Node2D

const IsoProjector = preload("res://scenes/iso/iso_projector.gd")

## Decorative, non-gameplay prop with no logical counterpart node. Projects
## once at startup since it never moves.
@export var world_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	top_level = true
	global_position = IsoProjector.to_screen(world_position)
