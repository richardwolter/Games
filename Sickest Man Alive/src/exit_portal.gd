class_name ExitPortal
extends Area2D

## The way out. Appears only during the rampage, only in a room the body can
## actually be left through, and ends the run on touch.
##
## Same contract as Pedestal: walking into it IS the choice. There is no prompt
## and no confirm, because the interesting decision was which exit to run for,
## and that one was made several rooms ago.

signal entered

const RADIUS: float = 34.0

## Shown on the portal so the player can tell at a glance which exit they found.
var label: String = "exit"
var tint: Color = Color(0.65, 0.95, 0.8)

var _pulse: float = 0.0
var _used: bool = false
var _font: Font


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  ## player hurtbox
	monitoring = true
	z_index = 1

	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	cs.shape = circle
	add_child(cs)
	area_entered.connect(_on_area_entered)

	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _on_area_entered(area: Area2D) -> void:
	if _used or not area.is_in_group(&"player"):
		return
	_used = true
	entered.emit()


func _draw() -> void:
	# Two counter-rotating rings, so it reads as an opening rather than as
	# another pickup on the floor.
	var breathe := 1.0 + sin(_pulse * 3.0) * 0.08
	draw_circle(Vector2.ZERO, RADIUS * breathe, Color(tint.r, tint.g, tint.b, 0.18))
	draw_arc(Vector2.ZERO, RADIUS * breathe, 0.0, TAU, 40, tint, 4.0, true)
	draw_arc(Vector2.ZERO, RADIUS * 0.6 / breathe, _pulse * 2.0, _pulse * 2.0 + TAU * 0.7,
		24, Color(tint.r, tint.g, tint.b, 0.8), 3.0, true)

	if _font != null:
		var text := label.to_upper()
		var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(_font, Vector2(-width * 0.5, -RADIUS - 14.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tint)
