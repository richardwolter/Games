class_name Pedestal
extends Area2D

## Holds one Item and hands it over on touch. Deliberately not a menu:
## no compare screen, no confirm, no pause. Walking into it IS the choice.
##
## A cache puts two of these on the floor and lets the player have one. This
## script does not know that -- it only knows how to be taken and how to be
## `retract()`ed by whoever is arbitrating.

signal taken(item: Item)

const RADIUS: float = 18.0
## The drawn sphere. The pickup test and the artwork read the same number, so
## the thing you can touch is exactly the thing you can see.
const ITEM_RADIUS: float = RADIUS * 0.75
## Slack around it, in pixels. Small on purpose: brushing past must not pick
## anything up, and with a choice on offer the player has to commit to one.
const PICKUP_SLACK: float = 6.0
const PICKUP_RADIUS: float = ITEM_RADIUS + PICKUP_SLACK
## How long the losing pedestal takes to sink away. Long enough to be SEEN
## going, so the player registers what the choice cost them.
const RETRACT_TIME: float = 0.35

## --- Info plate ------------------------------------------------------------
## The card only exists because there are two pedestals now: with one item there
## was nothing to compare and the name in the pickup banner was enough. A choice
## you cannot read is a coin flip.
##
## Shown on APPROACH rather than always, so a room with two caches is not two
## blocks of text competing with the fight for attention.
const PLATE_RANGE: float = 150.0
const PLATE_WIDTH: float = 230.0
## Clearance above the pedestal's bob, so the card never sits on the item.
const PLATE_LIFT: float = 46.0
const PLATE_FADE_SPEED: float = 8.0

var item: Item

var _bob: float = 0.0
var _consumed: bool = false
var _plate: PanelContainer
var _plate_shown: float = 0.0


func _ready() -> void:
	# No collision at all any more. The player's hurtbox wraps his whole drawn
	# body, which is far wider than the item, and with two pedestals in a room an
	# overlap-triggered pickup meant walking PAST one could take it. The pickup is
	# a distance test between the item and his centre instead -- see _try_pickup.
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	_build_plate()


## Name and effect, on a dark card above the item. Built in code like the rest of
## the pedestal, so a cache is still one `Pedestal.new()` and nothing else.
func _build_plate() -> void:
	if item == null:
		return

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.07, 0.88)
	style.border_color = Color(item.pedestal_color, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)

	_plate = PanelContainer.new()
	_plate.add_theme_stylebox_override(&"panel", style)
	_plate.custom_minimum_size.x = PLATE_WIDTH
	# The card is UI hanging off a world node: it must not eat the click that the
	# player is aiming with, and it must draw over everything on the floor.
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.z_index = 10
	_plate.modulate.a = 0.0

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	_plate.add_child(box)

	var title := Label.new()
	title.text = item.display_name
	title.add_theme_color_override(&"font_color", item.pedestal_color.lightened(0.35))
	title.add_theme_font_size_override(&"font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)

	if item.description != "":
		var body := Label.new()
		body.text = item.description
		body.add_theme_color_override(&"font_color", Color(0.78, 0.78, 0.82))
		body.add_theme_font_size_override(&"font_size", 12)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(body)

	add_child(_plate)


func _process(delta: float) -> void:
	if _consumed:
		return
	_bob += delta
	queue_redraw()
	_update_plate(delta)
	_try_pickup()


## Fades the card in while the player is near it and out again when they leave.
## Distance rather than a second Area2D: the reveal range is much wider than the
## pickup range, and two overlapping trigger shapes on one pedestal is a thing to
## get wrong later.
func _update_plate(delta: float) -> void:
	if _plate == null:
		return
	var player := get_tree().get_first_node_in_group(&"player_body") as Node2D
	var near := player != null \
		and global_position.distance_to(player.global_position) < PLATE_RANGE
	_plate_shown = move_toward(_plate_shown, 1.0 if near else 0.0, delta * PLATE_FADE_SPEED)
	_plate.modulate.a = _plate_shown
	_plate.visible = _plate_shown > 0.001
	# Re-centred every frame rather than once: the card's height is not known
	# until the labels have wrapped, which happens after the first layout pass.
	_plate.position = Vector2(-_plate.size.x * 0.5, -PLATE_LIFT - _plate.size.y)


## Taken only when the player's CENTRE reaches the item itself -- the drawn
## sphere, at the height the bob has it, not the plinth and not the sprite's
## outer edges. With two items on offer, "which one did I mean" must be decided
## by where he is standing, never by which capsule happened to graze first.
func _try_pickup() -> void:
	if item == null:
		return
	var player := get_tree().get_first_node_in_group(&"player_body") as Node2D
	if player == null:
		return
	if player.global_position.distance_to(global_position + _item_center()) > PICKUP_RADIUS:
		return
	_consumed = true
	taken.emit(item)
	queue_free()


## The offer was spent elsewhere. Stops accepting touches immediately -- a
## player mid-stride between the two must not be able to collect both during the
## fade -- and then sinks out of sight.
func retract() -> void:
	if _consumed:
		return
	_consumed = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, ^"modulate:a", 0.0, RETRACT_TIME)
	tween.tween_property(self, ^"position:y", position.y + 14.0, RETRACT_TIME)
	tween.chain().tween_callback(queue_free)


## Where the sphere actually is this frame, bob included. One function for both
## the drawing and the pickup test, or the hitbox drifts off the art by whatever
## the bob is doing.
func _item_center() -> Vector2:
	return Vector2(0.0, sin(_bob * 2.2) * 4.0 - 8.0)


func _draw() -> void:
	if item == null:
		return
	var centre := _item_center()
	# Base plinth, so the pickup reads as placed rather than dropped.
	draw_circle(Vector2(0.0, 10.0), RADIUS * 0.9, Color(0.25, 0.2, 0.24))
	draw_circle(centre, ITEM_RADIUS, item.pedestal_color)
	draw_arc(centre, ITEM_RADIUS, 0.0, TAU, 20, item.pedestal_color.lightened(0.5), 2.0)
