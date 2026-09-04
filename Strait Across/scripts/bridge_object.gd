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

## Kept so the manipulator can test whether there's room to put this down. On a
## polygon piece this is the outline's convex hull rather than the outline
## itself — one shape is all a room query can take, and a hull only ever claims
## MORE space than the piece needs, so the answer stays conservative in the
## direction that cannot shove the bridge apart.
var shape: Shape2D

## Every shape the body actually collides with. One entry for a box or a circle;
## for a polygon, the convex parts the outline decomposes into.
var shapes: Array[Shape2D] = []

## Local-space points sampled by the water for buoyancy. Spreading them out
## means a half-submerged plank gets torque and rights itself, instead of the
## whole body bobbing as a single point.
var buoyancy_points: PackedVector2Array = PackedVector2Array()

var is_held: bool = false

## Identity that survives the pre-crossing snapshot, where every body is freed
## and rebuilt. Only ropes need it: a rope holds two pieces, and a node reference
## across that cycle is a reference to something that no longer exists. Assigned
## by ObjectSpawner; zero means nothing has claimed one.
var uid: int = 0

## Which of the def's drawings this piece wears. Rolled once when the piece is
## made and then kept, so a bridge doesn't reshuffle its own artwork every time
## it's put back after an attempt.
var variant: int = -1

## Mirrored left-to-right, artwork and collision together.
##
## A rotation cannot do this. A ramp turned 180 degrees is upside down — the deck
## faces the sky and the flat base is what the truck meets — so a piece with a
## handedness needs the mirror as its own operation, or half of what it is for is
## unreachable. Kept as a property of the piece rather than a scale on the node
## because the collision has to mirror with the picture.
var flipped: bool = false


func setup(d: ObjectDef, art_variant: int = -1, mirrored: bool = false) -> void:
	def = d
	variant = art_variant if art_variant >= 0 else d.roll_variant()
	flipped = mirrored
	mass = d.mass
	add_to_group(&"bridge_objects")

	var shared := _shared_for(d, flipped)
	physics_material_override = shared[0]
	shape = shared[1]
	buoyancy_points = shared[2]
	shapes = shared[3]

	for part: Shape2D in shapes:
		var cs := CollisionShape2D.new()
		cs.shape = part
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
## Keyed by def, then by whether the piece is mirrored — a flipped polygon is a
## different shape and needs its own entry, while a box or a circle simply shares
## the one it already had.
static var _shared: Dictionary[ObjectDef, Dictionary] = {}


static func _shared_for(d: ObjectDef, mirrored: bool = false) -> Array:
	var by_flip: Dictionary = _shared.get(d, {})
	# Only a polygon has a handedness. Flipping anything else would allocate a
	# second identical set of shapes for no difference.
	var key := mirrored and d.shape == "polygon"
	var cached: Variant = by_flip.get(key)
	if cached != null:
		return cached as Array

	var pm := PhysicsMaterial.new()
	pm.friction = d.friction
	pm.bounce = d.bounce

	var made: Shape2D
	var parts: Array[Shape2D] = []
	var points := PackedVector2Array()

	if d.shape == "polygon" and d.polygon.size() >= 3:
		var outline := d.polygon_points(key)
		# The outline may be concave — the ramp's deck is — and the physics server
		# only takes convex shapes, so it is cut into convex parts and the body
		# wears all of them.
		for piece: PackedVector2Array in Geometry2D.decompose_polygon_in_convex(outline):
			if piece.size() < 3:
				continue
			var convex := ConvexPolygonShape2D.new()
			convex.points = piece
			parts.append(convex)
			# Each part's centroid is a point guaranteed to be INSIDE the piece.
			# The quarter-extents grid below cannot be used here: on a ramp its
			# top corners are in the open air beside the deck, and buoyancy
			# applied out there would lever the piece over rather than lift it.
			points.append(_centroid(piece))
		var hull := ConvexPolygonShape2D.new()
		hull.points = Geometry2D.convex_hull(outline)
		made = hull
	elif d.shape == "circle":
		var circle := CircleShape2D.new()
		circle.radius = d.size.x * 0.5
		made = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = d.size
		made = rect

	if parts.is_empty():
		parts.append(made)
	if points.is_empty():
		# Spread to the quarter-extents rather than the corners: four points inside
		# the body give a half-submerged plank righting torque without the ends
		# popping.
		var hw: float = d.size.x * 0.25
		var hh: float = d.get_height() * 0.25
		points = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh),
			Vector2(-hw, hh), Vector2(hw, hh),
		])

	var entry: Array = [pm, made, points, parts]
	by_flip[key] = entry
	_shared[d] = by_flip
	return entry


## Mirror this piece left-to-right, in place.
##
## The collision children are rebuilt rather than scaled: a RigidBody2D with a
## negative scale is a body the physics server has to invert every step, and the
## shapes here are shared between every piece of the same kind, so scaling the
## node would be the only way to do it without corrupting the ones it shares
## with. Rebuilding costs one allocation the first time a def is flipped and
## nothing after that — the mirrored set is cached beside the original.
func set_flipped(mirrored: bool) -> void:
	if def == null or mirrored == flipped:
		return
	flipped = mirrored

	var shared := _shared_for(def, flipped)
	shape = shared[1]
	buoyancy_points = shared[2]
	shapes = shared[3]

	# Collected first, then removed. Removing children while walking
	# get_children() shifts the list under the loop and leaves half the old
	# shapes on the body — which is a piece colliding as both facings at once.
	var old: Array[Node] = []
	for child: Node in get_children():
		if child is CollisionShape2D:
			old.append(child)
	for child: Node in old:
		# Off the body now, not on the next idle frame: freeing is deferred, and
		# the new shapes are being added on this one.
		remove_child(child)
		child.queue_free()

	for part: Shape2D in shapes:
		var cs := CollisionShape2D.new()
		cs.shape = part
		add_child(cs)

	queue_redraw()


static func _centroid(polygon: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for point: Vector2 in polygon:
		total += point
	return total / float(polygon.size())


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
		elif def.shape == "polygon":
			# Drawn at exactly its own size. The padding exists to hide a collision
			# box poking out from under artwork it only approximates; here the
			# collision was traced FROM this artwork, so growing the picture past
			# it would put a rim of wood outside the shape the truck drives on.
			art = def.size
		# Mirrored by flipping the canvas, NOT by handing draw_texture_rect a
		# negative width — a Rect2 with negative size draws nothing at all, which
		# is an invisible piece rather than a backwards one.
		if flipped:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect(texture, Rect2(-art * 0.5, art), false)
		if flipped:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	var outline := def.color.darkened(0.45)
	if def.shape == "polygon" and def.polygon.size() >= 3:
		# Only ever seen if the artwork is missing, but a piece drawn as a
		# rectangle it does not collide like would be worse than no drawing.
		var points := def.polygon_points(flipped)
		draw_colored_polygon(points, def.color)
		draw_polyline(points + PackedVector2Array([points[0]]), outline, 2.0)
	elif def.shape == "circle":
		var r: float = def.size.x * 0.5
		draw_circle(Vector2.ZERO, r, def.color)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, outline, 2.0)
		# Spoke, so rotation is readable at a glance.
		draw_line(Vector2.ZERO, Vector2(r, 0), outline, 2.0)
	else:
		var rect := Rect2(-def.size * 0.5, def.size)
		draw_rect(rect, def.color)
		draw_rect(rect, outline, false, 2.0)
