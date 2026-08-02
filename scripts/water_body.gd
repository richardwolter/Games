## Simplified buoyancy. Not a fluid sim — just an upward force per sample point
## scaled by how deep that point is, plus heavy damping while submerged.
## The damping is what makes floating pieces settle down enough to build on.
class_name WaterBody
extends Area2D

@export var surface_y: float = 300.0
@export var linear_drag: float = 3.0
@export var angular_drag: float = 5.0

## Sideways jostle, so a fresh drop nudges its neighbours instead of the water
## feeling like glue. Kept small.
@export var current_strength: float = 0.0

var _submerged: Array[BridgeObject] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is BridgeObject and not _submerged.has(body):
		_submerged.append(body)
		body.linear_damp = linear_drag
		body.angular_damp = angular_drag


func _on_body_exited(body: Node2D) -> void:
	if body is BridgeObject:
		_submerged.erase(body)
		body.linear_damp = 0.0
		body.angular_damp = 0.0


func _physics_process(_delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)

	for body: BridgeObject in _submerged:
		if not is_instance_valid(body) or body.is_held or body.def == null:
			continue

		var points := body.buoyancy_points
		var count := points.size()
		if count == 0:
			continue

		# Force at full submersion exactly cancels weight at buoyancy == 1.0.
		var full_force: float = body.mass * gravity * body.def.buoyancy / float(count)
		var height: float = body.def.get_height()

		for local_point: Vector2 in points:
			var world_point := body.to_global(local_point)
			var depth := world_point.y - surface_y
			if depth <= 0.0:
				continue
			var submersion := clampf(depth / height, 0.0, 1.0)
			body.apply_force(
				Vector2(current_strength * submersion, -full_force * submersion),
				world_point - body.global_position
			)


## Is any part of this piece in the water right now?
##
## Measured from the piece's own size rather than read off the submerged list,
## because a held piece has its collision layer zeroed and has therefore already
## left this Area2D — so at the moment of release, which is exactly when this
## gets asked, the list is stale by design.
##
## The bounding circle is deliberately generous: "touching" should include a
## plank whose end is dipping in, and being slightly early is a better error than
## a splash that fails to play for a piece visibly in the water.
func touches(body: BridgeObject) -> bool:
	if body == null or body.def == null:
		return false
	var reach: float = maxf(body.def.size.x, body.def.size.y) * 0.5
	return body.global_position.y + reach >= surface_y


func get_submerged_count() -> int:
	return _submerged.size()
