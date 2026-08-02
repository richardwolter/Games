## Drawn in code so wheel spin (and wheelspin) stays readable: a _draw() on the
## body is already in the body's rotating space, so everything here turns with
## the wheel.
extends RigidBody2D

## The tyre art is drawn edge to edge, so it needs almost no room beyond the
## collision circle — just enough to hide it behind the rubber.
const SPRITE_OVERSCALE := 1.02

@export var radius: float = 18.0
@export var color: Color = Color(0.14, 0.14, 0.16)
## Tyre art. Without it the wheel falls back to a circle and a spoke.
@export var texture: Texture2D
## A hub cap drawn over the tyre. Tread is radially symmetric, and at speed it
## turns far enough between frames to strobe — so without something asymmetric
## to follow, a wheel doing 24 rad/s looks like it's standing still.
@export var show_hub: bool = true
@export var hub_color: Color = Color(0.82, 0.83, 0.86)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if texture == null:
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, color.lightened(0.35), 2.0)
		draw_line(Vector2.ZERO, Vector2(radius, 0), color.lightened(0.5), 2.0)
		return

	var size := Vector2(radius, radius) * 2.0 * SPRITE_OVERSCALE
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
	if show_hub:
		_draw_hub()


## A capped centre with one spoke marked heavier than the rest: the odd spoke is
## what the eye actually tracks, and it stops the wheel reading as symmetric.
func _draw_hub() -> void:
	var cap: float = radius * 0.34
	draw_circle(Vector2.ZERO, cap, hub_color)
	draw_arc(Vector2.ZERO, cap, 0.0, TAU, 16, hub_color.darkened(0.5), maxf(radius * 0.05, 1.0))
	for i in 4:
		var angle: float = TAU * i / 4.0
		var thickness: float = radius * (0.14 if i == 0 else 0.08)
		draw_line(
			Vector2.from_angle(angle) * cap * 0.7,
			Vector2.from_angle(angle) * radius * 0.62,
			hub_color if i == 0 else hub_color.darkened(0.25),
			thickness
		)
