class_name IsoSync
extends Node2D

const IsoProjector = preload("res://scenes/iso/iso_projector.gd")

## Purely visual proxy: mirrors a logical (physics) node's world position into
## isometric screen space every frame. Lives in the IsoWorld y-sorted layer,
## NOT parented under the logical node, so physics stays untouched.
@export var sync_rotation: bool = false
@export var auto_free_with_source: bool = true

var source: Node2D:
	set(value):
		source = value
		visible = is_instance_valid(source)

func _ready() -> void:
	top_level = true

func _process(_delta: float) -> void:
	if not is_instance_valid(source):
		if auto_free_with_source:
			queue_free()
		return

	global_position = IsoProjector.to_screen(source.global_position)
	if sync_rotation:
		rotation = source.rotation
	if source is CanvasItem:
		modulate = (source as CanvasItem).modulate
