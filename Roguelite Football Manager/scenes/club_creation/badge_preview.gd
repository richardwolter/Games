extends Control

var primary_color: Color = Color.ROYAL_BLUE
var secondary_color: Color = Color.WHITE
var shape: ClubData.BadgeShape = ClubData.BadgeShape.SHIELD
var initials: String = ""

func set_badge(p_primary: Color, p_secondary: Color, p_shape: ClubData.BadgeShape, p_initials: String) -> void:
	primary_color = p_primary
	secondary_color = p_secondary
	shape = p_shape
	initials = p_initials
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var radius: float = min(size.x, size.y) / 2.0 - 4.0
	var outline_points := _shape_points(center, radius)
	draw_colored_polygon(outline_points, primary_color)
	var inner_points := _shape_points(center, radius * 0.55)
	draw_colored_polygon(inner_points, secondary_color)
	var closed_outline := outline_points.duplicate()
	closed_outline.append(outline_points[0])
	draw_polyline(closed_outline, Color.BLACK, 3.0, true)

	if initials != "":
		var font := ThemeDB.fallback_font
		var font_size := int(radius * 0.6)
		var text_size := font.get_string_size(initials, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := center - text_size / 2.0 + Vector2(0, text_size.y * 0.35)
		draw_string(font, text_pos, initials, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, primary_color)

func _shape_points(center: Vector2, radius: float) -> PackedVector2Array:
	match shape:
		ClubData.BadgeShape.CIRCLE:
			return _polygon_points(center, radius, 24, 0.0)
		ClubData.BadgeShape.DIAMOND:
			return _polygon_points(center, radius, 4, 0.0)
		ClubData.BadgeShape.STAR:
			return _star_points(center, radius, radius * 0.45, 5)
		ClubData.BadgeShape.SHIELD, _:
			return _shield_points(center, radius)

func _polygon_points(center: Vector2, radius: float, sides: int, rotation_offset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle: float = rotation_offset + TAU * i / sides - PI / 2.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _star_points(center: Vector2, outer_radius: float, inner_radius: float, spikes: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var total_points: int = spikes * 2
	for i in range(total_points):
		var radius: float = outer_radius if i % 2 == 0 else inner_radius
		var angle: float = TAU * i / total_points - PI / 2.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _shield_points(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-radius, -radius),
		center + Vector2(radius, -radius),
		center + Vector2(radius, radius * 0.3),
		center + Vector2(0, radius * 1.1),
		center + Vector2(-radius, radius * 0.3),
	])
