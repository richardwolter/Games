## One rope between two pieces.
##
## A DampedSpringJoint2D and a drawn line, and nothing else. The rope has no
## collision body of its own: it cannot be driven on and the truck passes straight
## through it. What it does is stop two pieces drifting apart — a plank laid across
## two barrels stays laid across them instead of sliding off the moment the first
## wheel touches it.
##
## Being a spring rather than a cable is the honest description: it resists
## separation with a force proportional to stiffness and CAN be pulled past its
## rest length under real load. That is a deliberate trade for the prototype —
## a proper inextensible rope is a chain of bodies, which is a physics body every
## twenty pixels and a different feature.
##
## ## How the anchors work
##
## Joint2D exposes only node_a and node_b. There is no anchor_a/anchor_b: Godot
## derives both from the JOINT NODE'S OWN TRANSFORM — anchor A is its origin, and
## anchor B is `length` units along its local +Y axis. Two arbitrary points on two
## pieces are therefore perfectly expressible, they just have to be written as a
## position and a rotation. rebuild() is that conversion, and it is the one piece
## of arithmetic in this file worth reading twice.
##
## The joint node must never move afterwards, which is why the rope is parented to
## the RopeManager (fixed at the world origin) rather than to either piece: a joint
## parented to a body re-derives its anchors from that body's transform every tick
## and quietly drags itself along behind it.
class_name Rope
extends Node2D

## How much the line bows when the two ends are closer than the rope is long.
## Cosmetic only — the joint knows nothing about it.
const SLACK_SAG := 0.22
## Thicker than a rope of this length would really be. It is drawn UNDER the
## water overlay so that a submerged rope is tinted along with everything else,
## and at three pixels the overlay all but erased it.
const THICKNESS := 5.0
const COLOR := Color(0.86, 0.78, 0.56)
const COLOR_TAUT := Color(0.94, 0.62, 0.38)

## Stiff enough to hold a plank on a barrel, soft enough not to fight the solver
## at 60 Hz — the rate the web build runs at, and the one a spring goes unstable
## at first. Tune against --pfps=60, never against the desktop's 120.
const STIFFNESS := 220.0
const DAMPING := 14.0

var a: BridgeObject = null
var b: BridgeObject = null
## Where each end is tied, in that piece's local space. Local so a rope stays tied
## to the same corner when the piece rolls over.
var a_offset: Vector2 = Vector2.ZERO
var b_offset: Vector2 = Vector2.ZERO
## Length at placement, which is both the spring's rest length and what was paid
## for. Kept so a restored rope is the rope that was bought, not one re-measured
## from wherever the pieces have since settled.
var rest: float = 0.0
## What it cost. Kept for the refund when it's cut and for the bridge's price.
var cost: int = 0

var joint: DampedSpringJoint2D = null


func setup(
	from: BridgeObject,
	to: BridgeObject,
	from_offset: Vector2,
	to_offset: Vector2,
	length: float,
	paid: int
) -> void:
	a = from
	b = to
	a_offset = from_offset
	b_offset = to_offset
	rest = length
	cost = paid
	# Under the water overlay (z 10) so a submerged rope is tinted with everything
	# else, and over the pieces (z 0) so it isn't hidden inside the plank it ties.
	z_index = 5


func _ready() -> void:
	rebuild()


## Build the joint from the two anchor points. See the class note above for why
## this is a transform rather than two properties.
func rebuild() -> void:
	if joint != null:
		joint.queue_free()
		joint = null
	if not alive():
		return

	var pa := a.to_global(a_offset)
	var pb := b.to_global(b_offset)
	var span := pb - pa
	if not (is_finite(span.x) and is_finite(span.y)) or span.length() < 0.5:
		return

	joint = DampedSpringJoint2D.new()
	# Transform FIRST, paths last. The joint builds itself in the physics server
	# the moment both paths resolve, and it reads the anchors off its transform at
	# that instant — setting the paths first creates a joint at the origin.
	joint.global_position = pa
	joint.global_rotation = span.angle() - PI * 0.5
	joint.length = span.length()
	joint.rest_length = maxf(rest, 1.0)
	joint.stiffness = STIFFNESS
	joint.damping = DAMPING
	# Defaults to TRUE, which would make the two roped pieces fall through each
	# other — read by a player as the physics breaking, not as the rope working.
	joint.disable_collision = false
	add_child(joint)
	joint.node_a = joint.get_path_to(a)
	joint.node_b = joint.get_path_to(b)


## Both ends still exist. A piece can be recalled out from under a rope at any
## moment, and the manager prunes on that.
func alive() -> bool:
	return (
		is_instance_valid(a) and not a.is_queued_for_deletion()
		and is_instance_valid(b) and not b.is_queued_for_deletion()
	)


func endpoints() -> PackedVector2Array:
	if not alive():
		return PackedVector2Array()
	return PackedVector2Array([a.to_global(a_offset), b.to_global(b_offset)])


## Drawn on the render clock, not the physics one: the joint is the physics, the
## line is decoration. Same split the truck's wheel drips use.
func _process(_delta: float) -> void:
	if alive():
		queue_redraw()


func _draw() -> void:
	var ends := endpoints()
	if ends.is_empty():
		return
	var pa := to_local(ends[0])
	var pb := to_local(ends[1])
	var span := pb - pa
	var stretch := span.length() / maxf(rest, 1.0)

	# Slack hangs, taut goes straight and changes colour. The bow is the only way
	# the rope can say it is doing nothing at the moment, and the colour is the
	# only warning that it is about to be the thing that breaks.
	var slack := clampf(1.0 - stretch, 0.0, 1.0)
	var mid := pa.lerp(pb, 0.5) + Vector2(0, rest * SLACK_SAG * slack)
	var tint := COLOR if stretch <= 1.02 else COLOR.lerp(COLOR_TAUT, minf((stretch - 1.02) * 4.0, 1.0))

	var points := PackedVector2Array()
	var steps := 10
	for i: int in steps + 1:
		var t := float(i) / float(steps)
		# One quadratic bezier through the sag point.
		points.append(pa.lerp(mid, t).lerp(mid.lerp(pb, t), t))
	draw_polyline(points, tint, THICKNESS, true)
	# Knots, so the player can see exactly which part of which piece it is tied to.
	draw_circle(pa, THICKNESS * 1.4, tint)
	draw_circle(pb, THICKNESS * 1.4, tint)
