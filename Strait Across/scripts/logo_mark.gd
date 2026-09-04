## The round badge: a sunset disc with a junk bridge and a car across it, inside a
## mustard ring. The game's reusable mark — panel header, shop header, window
## icon, and a stamp on the title screen.
##
## Drawn rather than imported so it stays crisp at any size and tracks the
## palette in ui_theme.gd. It's built from circles and rectangles on purpose: at
## 30px in the HUD header nothing finer would survive anyway.
@tool
class_name LogoMark
extends Control

## Everything is laid out in a unit square and scaled, so one number changes the
## whole badge and the HUD and the title screen can share this file.
@export var diameter: float = 64.0:
	set(value):
		diameter = value
		custom_minimum_size = Vector2(value, value)
		queue_redraw()

const SKY_TOP := Color("f2705e")
const SKY_BOTTOM := Color("c0559b")
const SUN := Color("f7d46a")
const SEA := Color("3e5c8c")


func _ready() -> void:
	custom_minimum_size = Vector2(diameter, diameter)


func _draw() -> void:
	var r := diameter * 0.5
	var c := Vector2(r, r)
	# Ring: ink, mustard, ink. Three flat circles rather than arcs with widths,
	# which keeps the edges hard the way the sprite outlines are.
	draw_circle(c, r, UITheme.INK)
	draw_circle(c, r * 0.93, UITheme.MUSTARD)
	draw_circle(c, r * 0.85, UITheme.INK)

	# The scene is drawn into a square and clipped to the inner disc, so nothing
	# has to be described in polar coordinates.
	var inner := r * 0.79
	var scene := Rect2(c - Vector2(inner, inner), Vector2(inner * 2.0, inner * 2.0))
	_draw_scene(scene, inner)


func _draw_scene(rect: Rect2, radius: float) -> void:
	# Godot has no circular clip in _draw, so the disc is faked: draw the square
	# scene, then paint the corners back to ink with a ring of line segments.
	var unit := rect.size.x

	draw_rect(Rect2(rect.position, Vector2(unit, unit * 0.55)), SKY_TOP)
	draw_rect(
		Rect2(rect.position + Vector2(0, unit * 0.55), Vector2(unit, unit * 0.13)),
		SKY_BOTTOM
	)
	draw_circle(rect.position + Vector2(unit * 0.5, unit * 0.5), unit * 0.26, SUN)
	draw_rect(
		Rect2(rect.position + Vector2(0, unit * 0.68), Vector2(unit, unit * 0.32)),
		SEA
	)

	# The bridge: a plank, a tire and a beam at the waterline, left to right, in
	# the same three materials the shop actually sells.
	_piece(rect, 0.00, 0.62, 0.34, 0.07, UITheme.WOOD)
	_piece(rect, 0.36, 0.60, 0.16, 0.13, UITheme.STEEL)
	draw_circle(rect.position + Vector2(unit * 0.60, unit * 0.66), unit * 0.075, Color("2a2a2a"))
	_piece(rect, 0.68, 0.60, 0.34, 0.07, UITheme.MUSTARD)

	# The car, mid-span and slightly above the deck so it reads as travelling.
	_piece(rect, 0.30, 0.40, 0.30, 0.11, UITheme.MUSTARD)
	_piece(rect, 0.35, 0.33, 0.17, 0.08, UITheme.AMBER)
	draw_circle(rect.position + Vector2(unit * 0.36, unit * 0.52), unit * 0.045, Color("2a2a2a"))
	draw_circle(rect.position + Vector2(unit * 0.54, unit * 0.52), unit * 0.045, Color("2a2a2a"))

	_mask_corners(rect.get_center(), radius)


## One outlined rectangle, positioned in 0..1 scene coordinates.
func _piece(rect: Rect2, x: float, y: float, w: float, h: float, fill: Color) -> void:
	var unit := rect.size.x
	var r := Rect2(
		rect.position + Vector2(unit * x, unit * y), Vector2(unit * w, unit * h)
	)
	draw_rect(r, fill)
	draw_rect(r, UITheme.INK, false, maxf(unit * 0.022, 1.0))


## Paints everything outside `radius` back to ink, giving the square scene a
## circular edge that meets the ring cleanly.
func _mask_corners(center: Vector2, radius: float) -> void:
	const SEGMENTS := 64
	var width := radius * 0.5
	var points := PackedVector2Array()
	for i in SEGMENTS + 1:
		var angle := TAU * float(i) / float(SEGMENTS)
		points.append(center + Vector2.from_angle(angle) * (radius + width * 0.5))
	draw_polyline(points, UITheme.INK, width)
