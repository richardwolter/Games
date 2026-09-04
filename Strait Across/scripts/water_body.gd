## Simplified buoyancy. Not a fluid sim — just an upward force per sample point
## scaled by how deep that point is, plus heavy damping while submerged.
## The damping is what makes floating pieces settle down enough to build on.
class_name WaterBody
extends Area2D

@export var surface_y: float = 300.0
@export var linear_drag: float = 3.0
@export var angular_drag: float = 5.0

## Sideways jostle, so a fresh drop nudges its neighbours instead of the water
## feeling like glue. Kept small. Positive pushes towards the far shore.
@export var current_strength: float = 0.0

## Where that current comes from, and how far it carries. Zero reach — the
## default — makes the current uniform across the whole strait, which is what it
## has always been.
##
## With a reach set, the current instead radiates from `current_origin_x` and
## fades to nothing at the edge of its range, always pushing AWAY from that point.
## That is a waterfall: the water it dumps has to go somewhere, and where it goes
## is outwards, hardest right under the fall.
@export var current_origin_x: float = 0.0
@export var current_reach: float = 0.0

## Draws the splashes. A child node rather than something this file does itself:
## buoyancy is physics and runs on the physics clock, splashes are decoration and
## run on the render clock, and the two have nothing to say to each other beyond
## "that just hit the water".
##
## Built here rather than placed in world.tscn so the waterline is set from the
## one value that defines it, and a level that moves the surface cannot leave the
## splashes drawing along the old one.
var splash: WaterSplash

var _submerged: Array[BridgeObject] = []
## Read once. It was being fetched by string key every physics tick, which is a
## dictionary lookup and a String compare 60-120 times a second for a value that
## cannot change while the game is running.
var _gravity: float = 980.0


func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	splash = WaterSplash.new()
	splash.name = "Splash"
	splash.surface_y = surface_y
	# Above the water overlay, which is z_index 10 and is what makes anything
	# below the line look submerged. A splash is above the line by definition, and
	# drawn under the overlay it would be tinted like something underwater.
	splash.z_index = 11
	splash.z_as_relative = false
	# The splash draws in world coordinates, so it must not inherit this area's
	# own transform on top of them.
	splash.position = -position
	add_child(splash)


## A body has broken the surface. Everything that floats gets damped; everything
## at all, pieces and truck alike, gets a splash if it arrived fast enough.
##
## The truck is included deliberately. It is the thing the player is watching, it
## is the heaviest object in the game, and it going in is the single most
## important moment a splash can mark — a bridge that fails does so by putting
## that truck in the water.
func _on_body_entered(body: Node2D) -> void:
	if body is BridgeObject and not _submerged.has(body):
		_submerged.append(body)
		body.linear_damp = linear_drag
		body.angular_damp = angular_drag
	_splash_for(body, true)


func _on_body_exited(body: Node2D) -> void:
	if body is BridgeObject:
		_submerged.erase(body)
		body.linear_damp = 0.0
		body.angular_damp = 0.0
	# Coming back out throws water too — a wheel bouncing clear of a half-sunk
	# plank, a barrel popping up after being pushed under. Held to a higher bar
	# than going in, because a piece that merely bobs across the line is not
	# leaving the water in any sense the player would recognise.
	_splash_for(body, false)


## How wide something is taken to be when it has no ObjectDef to ask — the
## truck's chassis and its two wheels. Between a tyre and the cab; splitting them
## would mean naming car parts in the water's code.
const NOMINAL_WIDTH := 90.0
## Leaving the water needs to be this much faster than entering it to splash.
const EXIT_SPEED_FACTOR := 1.6


func _splash_for(body: Node2D, entering: bool) -> void:
	var rigid := body as RigidBody2D
	if rigid == null or splash == null:
		return
	# Vertical speed only, and only the direction that crosses the surface. A
	# piece sliding along the waterline is not hitting it.
	var speed := rigid.linear_velocity.y if entering else -rigid.linear_velocity.y
	if not entering:
		speed /= EXIT_SPEED_FACTOR
	var piece := body as BridgeObject
	var width := NOMINAL_WIDTH
	if piece != null and piece.def != null:
		# A plank going in end-first should not throw a plank-length sheet of
		# water, so the width is turned with the piece: flat on gives its full
		# length, on end gives its thickness.
		var facing := absf(cos(piece.global_rotation))
		width = lerpf(piece.def.get_height(), piece.def.size.x, facing)
	splash.splash_for(body, speed, width)


func _physics_process(_delta: float) -> void:
	# current_strength is 0 by default, and at 0 the horizontal term is a multiply
	# and a Vector2 build per sample point that can only ever produce zero. Decided
	# once per tick rather than per point.
	var has_current := not is_zero_approx(current_strength)
	var local_current := has_current and current_reach > 0.0

	for body: BridgeObject in _submerged:
		if not is_instance_valid(body) or body.is_held or body.def == null:
			continue

		var points := body.buoyancy_points
		var count := points.size()
		if count == 0:
			continue

		# Force at full submersion exactly cancels weight at buoyancy == 1.0.
		var full_force: float = body.mass * _gravity * body.def.buoyancy / float(count)
		var height: float = body.def.get_height()
		var origin := body.global_position

		# One push per body rather than per sample point: the falloff is over
		# hundreds of units and a plank is not long enough for its two ends to be
		# in meaningfully different water, so working it out per point would be the
		# same number computed a dozen times.
		var push := current_strength
		if local_current:
			var offset := origin.x - current_origin_x
			var near := 1.0 - clampf(absf(offset) / current_reach, 0.0, 1.0)
			# Squared, matching the churn the water shader draws, so what the player
			# sees on the surface is where the piece actually gets shoved.
			# A piece parked dead under the fall has no side to be pushed to, so it
			# is sent back down the strait — the fall is at a bank, and outwards
			# from a bank means away from it.
			var away := signf(offset) if not is_zero_approx(offset) else -1.0
			push = current_strength * near * near * away

		for local_point: Vector2 in points:
			var world_point := body.to_global(local_point)
			var depth := world_point.y - surface_y
			if depth <= 0.0:
				continue
			var submersion := clampf(depth / height, 0.0, 1.0)
			body.apply_force(
				Vector2(push * submersion, -full_force * submersion)
				if has_current
				else Vector2(0.0, -full_force * submersion),
				world_point - origin
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


## Is this point in the water — not just below the waterline?
##
## The shores are level with the surface, so depth alone says yes for the whole
## world below y = 300, dry land included. That was enough to have the truck's
## tyres dripping as it drove along the shore towards a strait it had not reached
## yet. The horizontal extent is what makes the answer mean anything.
##
## Read off this area's own rectangle, so a level that widens the strait widens
## this with it and there is no second idea of where the water is.
func contains_point(point: Vector2) -> bool:
	if point.y < surface_y:
		return false
	var shape := get_node_or_null(^"Shape") as CollisionShape2D
	var rect := shape.shape as RectangleShape2D if shape != null else null
	if rect == null:
		return false
	var half := rect.size.x * 0.5
	var centre_x := global_position.x + shape.position.x
	return absf(point.x - centre_x) <= half


func get_submerged_count() -> int:
	return _submerged.size()
