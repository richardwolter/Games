@tool
class_name BattleMarker
extends Node2D
## A distinguishable placeholder pin on the battlefield (e.g. the hero spawn).
##
## Each role is readable at a glance during the prototype via a different color,
## size and shape, plus a text label. Positioned directly in the scene.

enum Shape { CIRCLE, DIAMOND, SQUARE }

@export var label := "": set = _set_label
@export var color := Color("cccccc"): set = _set_color
@export var marker_size := 24.0: set = _set_size
@export var shape := Shape.CIRCLE: set = _set_shape
@export var outline_color := Color("2c2c2c")
@export var outline_width := 3.0

func _ready() -> void:
	queue_redraw()

func _set_label(v: String) -> void:
	label = v
	queue_redraw()

func _set_color(v: Color) -> void:
	color = v
	queue_redraw()

func _set_size(v: float) -> void:
	marker_size = v
	queue_redraw()

func _set_shape(v: Shape) -> void:
	shape = v
	queue_redraw()

func _draw() -> void:
	match shape:
		Shape.CIRCLE:
			draw_circle(Vector2.ZERO, marker_size, color)
			draw_arc(Vector2.ZERO, marker_size, 0.0, TAU, 32, outline_color, outline_width, true)
		Shape.DIAMOND:
			var d := PackedVector2Array([
				Vector2(0.0, -marker_size), Vector2(marker_size, 0.0),
				Vector2(0.0, marker_size), Vector2(-marker_size, 0.0)])
			draw_colored_polygon(d, color)
			var o := d.duplicate()
			o.append(d[0])
			draw_polyline(o, outline_color, outline_width, true)
		Shape.SQUARE:
			var r := Rect2(-marker_size, -marker_size, marker_size * 2.0, marker_size * 2.0)
			draw_rect(r, color, true)
			draw_rect(r, outline_color, false, outline_width)
	if label != "":
		var font := ThemeDB.fallback_font
		var fs := 16
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(-tw * 0.5, -marker_size - 8.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline_color)
