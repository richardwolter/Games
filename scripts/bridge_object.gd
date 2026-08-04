## One piece of junk in the water. Shape, mass and visuals all come from an
## ObjectDef, so there is a single object scene rather than one per type.
class_name BridgeObject
extends RigidBody2D

## Physics layers, mirrored from project settings.
const LAYER_WORLD := 1
const MASK_PLACED := 3  # world + build bounds
const MASK_HELD := 2    # build bounds only, so a ghost still can't leave the shaft
## How far the artwork is drawn past the collision shape, to cover its outline.
const SPRITE_OVERSCALE := 1.08

var def: ObjectDef

## Kept so the manipulator can test whether there's room to put this down.
var shape: Shape2D

## Local-space points sampled by the water for buoyancy. Spreading them out
## means a half-submerged plank gets torque and rights itself, instead of the
## whole body bobbing as a single point.
var buoyancy_points: PackedVector2Array = PackedVector2Array()

var is_held: bool = false

## Which of the def's drawings this piece wears. Rolled once when the piece is
## made and then kept, so a bridge doesn't reshuffle its own artwork every time
## it's put back after an attempt.
var variant: int = -1


func setup(d: ObjectDef, art_variant: int = -1) -> void:
	def = d
	variant = art_variant if art_variant >= 0 else d.roll_variant()
	mass = d.mass
	add_to_group(&"bridge_objects")

	var shared := _shared_for(d)
	physics_material_override = shared[0]
	shape = shared[1]
	buoyancy_points = shared[2]

	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

	queue_redraw()


## The material, collision shape and buoyancy points for one def, built once and
## handed to every piece of that kind.
##
## Every plank in the strait used to build its own identical PhysicsMaterial, its
## own identical RectangleShape2D and its own identical four-point array. At the
## 140 cap that is 420 resources describing about ten distinct things, all of it
## allocated during restore() — which happens on every level load, every blueprint
## load and after every crossing attempt.
##
## Sharing is safe because none of the three is ever written after setup(): the
## manipulator only reads `shape` into a query, and the water only iterates
## `buoyancy_points`. The physics server holds shapes by RID and sharing one
## across bodies is the normal Godot pattern.
##
## IF YOU EVER NEED A PER-PIECE SHAPE — a piece that shrinks, deforms or is
## resized at runtime — it must stop coming from here, or every piece of that kind
## changes with it.
static var _shared: Dictionary[ObjectDef, Array] = {}


static func _shared_for(d: ObjectDef) -> Array:
	var cached: Variant = _shared.get(d)
	if cached != null:
		return cached as Array

	var pm := PhysicsMaterial.new()
	pm.friction = d.friction
	pm.bounce = d.bounce

	var made: Shape2D
	if d.shape == "circle":
		var circle := CircleShape2D.new()
		circle.radius = d.size.x * 0.5
		made = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = d.size
		made = rect

	# Spread to the quarter-extents rather than the corners: four points inside the
	# body give a half-submerged plank righting torque without the ends popping.
	var hw: float = d.size.x * 0.25
	var hh: float = d.get_height() * 0.25
	var points := PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh),
		Vector2(-hw, hh), Vector2(hw, hh),
	])

	var entry: Array = [pm, made, points]
	_shared[d] = entry
	return entry


## While held a piece passes through everything except the build bounds, so the
## player can thread it into position without shoving the bridge apart. It only
## becomes solid again where there's actually room for it.
func set_ghost(enabled: bool) -> void:
	if enabled:
		collision_layer = 0
		collision_mask = MASK_HELD
	else:
		collision_layer = LAYER_WORLD
		collision_mask = MASK_PLACED
		modulate = Color.WHITE


func _draw() -> void:
	if def == null:
		return
	var texture := def.get_texture(variant)
	if texture != null:
		# The art is drawn with a soft outline and a little padding, so it reads
		# slightly small if fitted exactly to the collision shape.
		var art := def.size * SPRITE_OVERSCALE
		if def.shape == "circle":
			art = Vector2(def.size.x, def.size.x) * SPRITE_OVERSCALE
		draw_texture_rect(texture, Rect2(-art * 0.5, art), false)
		return

	var outline := def.color.darkened(0.45)
	if def.shape == "circle":
		var r: float = def.size.x * 0.5
		draw_circle(Vector2.ZERO, r, def.color)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, outline, 2.0)
		# Spoke, so rotation is readable at a glance.
		draw_line(Vector2.ZERO, Vector2(r, 0), outline, 2.0)
	else:
		var rect := Rect2(-def.size * 0.5, def.size)
		draw_rect(rect, def.color)
		draw_rect(rect, outline, false, 2.0)
