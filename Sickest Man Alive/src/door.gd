class_name Door
extends Area2D

## A door is a trigger, not a transition. It tells the run manager which way
## the player walked and forgets about it. No scene loading, no pause, no
## await -- the room swap happens inside one frame on a node that outlives
## every room.

signal used(link_id: String)

const GAP: float = 140.0

## Which connection this doorway is, from either side. A direction no longer
## identifies a door: two doors can share a wall and lead to different rooms.
var link_id: String = ""
var dir: String = "n"
var locked: bool = false

## Where this door goes, written on the wall. Left empty on ordinary doors:
## signposting all hundred of them turns every wall into a sign and makes the
## two that are actually a choice invisible.
var label: String = ""
var hint: BodyPlan.Hint = BodyPlan.Hint.NONE

## How far from the doorway the sign sits, inside the room.
const SIGN_INSET: float = 30.0

var _plug_shape: CollisionShape2D
var _font: Font

## Stops the door firing the instant the player is placed on top of it after
## arriving in a new room.
var _arm_timer: float = 0.35


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # player hurtbox
	monitoring = true
	area_entered.connect(_on_area_entered)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(GAP, 44.0) if dir in ["n", "s"] else Vector2(44.0, GAP)
	var cs := CollisionShape2D.new()
	cs.shape = rect
	add_child(cs)

	_font = ThemeDB.fallback_font
	queue_redraw()


## Takes ownership of the solid that fills this doorway while the door is locked.
##
## The plug is built by the ROOM and lives on the room's wall body -- see
## Room._build_plug. It was built here once, from Door.GAP and a fixed depth, and
## both numbers were wrong: the hole the wall actually leaves is wider than GAP,
## and the wall is deeper than the plug was. What is left here is the switch,
## which is the only part of it that is the door's business.
##
## Null is accepted and means this doorway has no wall around it to plug, which
## makes it a door that is simply always open.
func attach_plug(shape: CollisionShape2D) -> void:
	_plug_shape = shape
	if _plug_shape != null:
		_plug_shape.disabled = not locked


func _process(delta: float) -> void:
	if _arm_timer > 0.0:
		_arm_timer -= delta


func set_locked(value: bool) -> void:
	locked = value
	if _plug_shape != null:
		# Deferred: locking happens from inside a physics callback (a wave
		# starting, the last enemy dying), and changing a shape mid-flush is
		# the classic "Can't change this state while flushing queries" error.
		_plug_shape.set_deferred(&"disabled", not locked)
	queue_redraw()


func _on_area_entered(area: Area2D) -> void:
	if locked or _arm_timer > 0.0:
		return
	if area.is_in_group(&"player"):
		used.emit(link_id)


func _draw() -> void:
	var half := GAP * 0.5
	var color := Color(0.85, 0.35, 0.35, 0.9) if locked else Color(0.4, 0.9, 0.6, 0.9)
	var a: Vector2
	var b: Vector2
	if dir in ["n", "s"]:
		a = Vector2(-half, 0.0)
		b = Vector2(half, 0.0)
	else:
		a = Vector2(0.0, -half)
		b = Vector2(0.0, half)
	draw_line(a, b, color, 6.0)
	if locked:
		# A locked door has to read as "kill things", not "wrong way".
		draw_line(a * 0.4, b * 0.4, color.darkened(0.3), 12.0)
	if label != "":
		_draw_sign()


## Colour of the pip that says, roughly, what is through there. Cache blue is
## the blue the minimap already uses for cache rooms: one concept, one colour.
static func hint_color(value: BodyPlan.Hint) -> Color:
	match value:
		BodyPlan.Hint.COMBAT:
			return Color(0.90, 0.35, 0.30)
		BodyPlan.Hint.CACHE:
			return Color(0.50, 0.85, 1.00)
		BodyPlan.Hint.HAZARD:
			return Color(0.95, 0.80, 0.25)
		_:
			return Color(0.70, 0.70, 0.70)


## Destination name and hint pip, laid along the wall and pushed inward so the
## text sits in the room rather than through the wall.
func _draw_sign() -> void:
	if _font == null:
		return
	var text := label.to_upper()
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x

	# Side doors get the text turned to run along their wall; unrotated it would
	# spill sideways through the wall it is labelling.
	var inward := SIGN_INSET
	match dir:
		"n":
			draw_set_transform(Vector2(0.0, inward))
		"s":
			draw_set_transform(Vector2(0.0, -inward))
		"w":
			draw_set_transform(Vector2(inward, 0.0), PI * 0.5)
		_:
			draw_set_transform(Vector2(-inward, 0.0), -PI * 0.5)

	var tint := hint_color(hint)
	draw_string(_font, Vector2(-width * 0.5, 6.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tint)
	if hint != BodyPlan.Hint.NONE:
		draw_circle(Vector2(0.0, -8.0), 5.0, tint)
	draw_set_transform(Vector2.ZERO)
