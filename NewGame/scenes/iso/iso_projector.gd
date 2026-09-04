class_name IsoProjector
extends RefCounted

## Classic 2:1 isometric projection. Gameplay (physics, collision, distances)
## stays in plain Cartesian world space always — only rendering position is
## projected, via IsoSync/IsoStaticProp. This avoids skewing Godot's physics
## transforms, which behave badly with non-uniform scale/shear.
const SCALE_X: float = 0.5
const SCALE_Y: float = 0.25

static func to_screen(world_pos: Vector2) -> Vector2:
	return Vector2(
		(world_pos.x - world_pos.y) * SCALE_X,
		(world_pos.x + world_pos.y) * SCALE_Y
	)
