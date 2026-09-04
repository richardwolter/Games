class_name IsoGround
extends Node2D

const IsoProjector = preload("res://scenes/iso/iso_projector.gd")

## Tiles a diamond road texture along a straight world-space corridor,
## projecting each tile center to isometric screen space. Assumes the
## corridor runs along world X, centered on world Y = 0.
@export var tile_texture: Texture2D
@export var track_start_x: float = 0.0
@export var track_end_x: float = 2400.0
@export var corridor_half_width: float = 110.0

func _ready() -> void:
	top_level = true
	_build_tiles()

func _build_tiles() -> void:
	if tile_texture == null:
		return

	var tile_world_size := corridor_half_width * 2.0
	var target_w := tile_world_size * IsoProjector.SCALE_X * 2.0
	var target_h := tile_world_size * IsoProjector.SCALE_Y * 2.0

	var x := track_start_x
	while x < track_end_x:
		var center_world := Vector2(x + tile_world_size * 0.5, 0.0)
		var spr := Sprite2D.new()
		spr.texture = tile_texture
		spr.position = IsoProjector.to_screen(center_world)
		spr.scale = Vector2(target_w / tile_texture.get_width(), target_h / tile_texture.get_height())
		add_child(spr)
		x += tile_world_size
