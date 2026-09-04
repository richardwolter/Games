class_name ShockStrike
extends Node2D

## One bolt of the brain misfiring, from the warning on the floor to the flash.
##
## The whole hazard is the telegraph. A bolt that lands without one is damage the
## player could not have avoided, which is not difficulty -- it is a tax. So the
## mark goes down first, it is on the floor for long enough to walk out of, and
## it closes visibly so "how long have I got" is answerable by looking at it
## rather than by counting.
##
## Not an Area2D, for the same reason AcidPool is not: the player's hurtbox wraps
## his whole drawn body and would take a hit standing a body-width clear of the
## mark he can plainly see. The strike tests the point it actually hit.

## Seconds the mark is on the floor before the bolt lands.
const TELEGRAPH: float = 1.15
## How long the flash is drawn for afterwards. Short -- it is a flash.
const FLASH: float = 0.16

const DAMAGE: float = 1.0
## Enemies are in the blast too. The brain is not on anyone's side, and a hazard
## that only ever hurts the player is a hazard the player fights alone.
const ENEMY_DAMAGE: float = 14.0
const KNOCKBACK: float = 260.0

const COLOR_WARN: Color = Color(0.62, 0.80, 1.0)
const COLOR_BOLT: Color = Color(0.85, 0.93, 1.0)

## How far the bolt's zigzag wanders off a straight line, as a fraction of the
## radius, and how many segments it is drawn with.
const JAG: float = 0.42
const SEGMENTS: int = 7

var radius: float = 86.0

var _age: float = 0.0
var _struck: bool = false
var _bolt: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	# Over the floor and the pools. The mark is the one thing in the room the
	# player must not lose track of.
	z_index = 2


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()

	if not _struck and _age >= TELEGRAPH:
		_struck = true
		_build_bolt()
		_hit()
	if _age >= TELEGRAPH + FLASH:
		queue_free()


## Everything standing on the mark when it closes. Read at the moment of the
## strike and never again -- walking into the crater afterwards is free, which is
## what makes the telegraph a real answer rather than a suggestion.
func _hit() -> void:
	var player := get_tree().get_first_node_in_group(&"player_body") as Node2D
	if player != null and _covers(player.global_position):
		if player.has_method(&"take_damage"):
			var away := (player.global_position - global_position).normalized()
			player.take_damage(DAMAGE, away * KNOCKBACK, {}, false)

	# The enemy HURTBOXES, not the bodies: take_damage lives on the hurtbox, and
	# it is what the player's own shots talk to.
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var area := n as Node2D
		if area == null or not _covers(area.global_position):
			continue
		if area.has_method(&"take_damage"):
			var away := (area.global_position - global_position).normalized()
			area.take_damage(ENEMY_DAMAGE, away * KNOCKBACK, {}, false)


## Ellipse, not a circle. The floor is seen at an angle and the mark is drawn
## squashed to match, so the test has to be squashed the same way or the bolt
## hits a hand's width above and below a mark that clearly missed.
func _covers(world: Vector2) -> bool:
	var local := to_local(world)
	local.y /= 0.62
	return local.length() <= radius


func _build_bolt() -> void:
	_bolt = PackedVector2Array()
	# Drawn from above the room down into the mark, so it arrives from somewhere
	# rather than appearing in place.
	var from := Vector2(randf_range(-radius, radius), -radius * 6.0)
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var p := from.lerp(Vector2.ZERO, t)
		# The wander closes to nothing at the ground end, so however the jag
		# comes out the bolt still lands on the mark it advertised.
		p.x += randf_range(-1.0, 1.0) * radius * JAG * (1.0 - t)
		_bolt.append(p)


func _draw() -> void:
	if _struck:
		_draw_flash()
		return
	_draw_warning()


## The mark: a fixed outer ring that says where, and a filled disc closing inward
## that says when. Two separate reads, because "am I in it" and "how long" are
## two separate questions and one shrinking circle answers neither well.
func _draw_warning() -> void:
	var t := clampf(_age / TELEGRAPH, 0.0, 1.0)
	var squash := Vector2(1.0, 0.62)

	draw_set_transform(Vector2.ZERO, 0.0, squash)
	draw_circle(Vector2.ZERO, radius, Color(COLOR_WARN, 0.13))
	# Fills from the middle out as the clock runs down, so the mark is at its
	# most alarming in the last moment before it lands.
	draw_circle(Vector2.ZERO, radius * t, Color(COLOR_WARN, 0.22))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(COLOR_WARN, 0.9), 3.0)
	draw_set_transform(Vector2.ZERO)

	# A spark stuttering over the mark, brightening as the strike approaches. It
	# is what stops a ring on the floor reading as scenery.
	if fmod(_age, 0.14) < 0.07:
		var jitter := Vector2(randf_range(-radius, radius), randf_range(-radius, radius) * 0.62)
		draw_circle(jitter, 2.0 + 3.0 * t, Color(COLOR_BOLT, 0.35 + 0.5 * t))


func _draw_flash() -> void:
	var fade := 1.0 - clampf((_age - TELEGRAPH) / FLASH, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
	draw_circle(Vector2.ZERO, radius, Color(COLOR_BOLT, 0.45 * fade))
	draw_set_transform(Vector2.ZERO)
	if _bolt.size() >= 2:
		# Twice, wide and soft under narrow and bright: one stroke reads as a
		# drawn line, two read as something that is giving off light.
		draw_polyline(_bolt, Color(COLOR_WARN, 0.5 * fade), 11.0)
		draw_polyline(_bolt, Color(COLOR_BOLT, fade), 4.0)
