extends Node2D
## The four care stations on the balcony rail, drawn in code as flat ink-on-paper
## placeholders with labels, and the mouse drag that puts a crow on one. Mornings
## only: press on a crow, drag it over a station, let go. The rules live in
## scripts/care.gd; game.gd's assign_station applies them.

const Care = preload("res://scripts/care.gd")

const INK := Color(0.1, 0.1, 0.11)
const PAPER := Color(0.97, 0.95, 0.9)
const PAPER_LIT := Color(1.0, 0.98, 0.9)

## Rail the stations stand on (game.gd RAIL_PERCH_Y + crow FEET_Y).
const RAIL_Y := 495.0
## Station centres along the rail and their widths, in design pixels (1152 wide).
## Trip is the middle of the rail, where the crew always perched. First guesses.
const LAYOUT := {
	Care.Station.TRAINING: {"x": 250.0, "w": 150.0},
	Care.Station.TRIP: {"x": 576.0, "w": 440.0},
	Care.Station.NEST: {"x": 885.0, "w": 130.0},
	Care.Station.FIRST_AID: {"x": 1040.0, "w": 130.0},
}
const TALL := 64.0
## Crows sharing a small station stand this far apart.
const SLOT_GAP := 30.0
## How close (px) a press must be to a crow's middle to pick it up.
const PICK_REACH := 30.0

var game = null
var _drag = null
var _hover := -1


static func label_of(station: int) -> String:
	match station:
		Care.Station.TRIP: return "Trip"
		Care.Station.TRAINING: return "Training post"
		Care.Station.NEST: return "Nest"
		Care.Station.FIRST_AID: return "First-aid box"
	return "?"


func setup(game_node) -> void:
	game = game_node
	queue_redraw()


func rect_of(station: int) -> Rect2:
	var l: Dictionary = LAYOUT[station]
	return Rect2(l.x - l.w * 0.5, RAIL_Y - TALL, l.w, TALL)


func slot_x(station: int, i: int, n: int) -> float:
	return float(LAYOUT[station].x) + (i - (n - 1) * 0.5) * SLOT_GAP


func station_at(p: Vector2) -> int:
	for st in LAYOUT:
		if rect_of(st).grow(12.0).has_point(p):
			return st
	return -1


func _can_drag() -> bool:
	return game != null and game.day_state == game.DayState.MORNING


func _unhandled_input(event: InputEvent) -> void:
	if not _can_drag():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p := get_global_mouse_position()
		if event.pressed and _drag == null:
			_drag = _crow_at(p)
			if _drag != null:
				_drag.set_loiter(false)
				_drag.z_index = 5
				get_viewport().set_input_as_handled()
		elif not event.pressed and _drag != null:
			var crow = _drag
			_drag = null
			crow.z_index = 0
			var st := station_at(p)
			if st < 0:
				st = crow.station
			game.assign_station(crow, st)
			_hover = -1
			queue_redraw()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag != null:
		_drag.position = get_global_mouse_position() + Vector2(0, 10)
		var h := station_at(get_global_mouse_position())
		if h != _hover:
			_hover = h
			queue_redraw()


func _crow_at(p: Vector2):
	var best = null
	var best_d := PICK_REACH
	for crow in game._crows():
		if crow.is_out:
			continue
		var d: float = (crow.position + Vector2(0, -12)).distance_to(p)
		if d < best_d:
			best_d = d
			best = crow
	return best


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for st in LAYOUT:
		var r := rect_of(st)
		var lit: bool = _drag != null and st == _hover
		var refused: bool = lit and _drag != null and not Care.can_assign(_drag.injury_days, st)
		if st == Care.Station.TRIP:
			# the open rail: only a dashed outline and its word, so the city shows
			_dashed(r, INK, 2.0 if lit else 1.0)
		else:
			_draw_prop(st, r, lit, refused)
		if refused:
			# ink only (one spot colour): a refused drop is struck through
			draw_line(r.position, r.end, INK, 3.0)
			draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), INK, 3.0)
		var word := label_of(st)
		var tw := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		# above the prop: the Pantry and Upgrades panels cover the deck under the rail
		var tag := Rect2(r.position.x + (r.size.x - tw) * 0.5 - 5, RAIL_Y - TALL - 20, tw + 10, 17)
		draw_rect(tag, PAPER)
		draw_rect(tag, INK, false, 1.0)
		draw_string(font, Vector2(tag.position.x + 5, tag.position.y + 13), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)


func _dashed(r: Rect2, col: Color, width: float) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(a.distance_to(b) / 10.0)
		for k in n:
			if k % 2 == 0:
				draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, width)


# Flat placeholder props: a post with a dummy, a twig nest, a box with a cross.
func _draw_prop(st: int, r: Rect2, lit: bool, refused: bool) -> void:
	var ink := INK
	var face := PAPER_LIT if lit else PAPER
	var w := 2.0 if lit else 1.5
	var foot := Vector2(r.get_center().x, RAIL_Y)
	match st:
		Care.Station.TRAINING:
			var post := Rect2(foot.x - 44, RAIL_Y - 46, 8, 46)
			draw_rect(post, face)
			draw_rect(post, ink, false, w)
			draw_line(Vector2(foot.x - 60, RAIL_Y - 36), Vector2(foot.x - 20, RAIL_Y - 36), ink, w)
			var ring := Vector2(foot.x + 40, RAIL_Y - 30)
			draw_circle(ring, 12, face)
			draw_arc(ring, 12, 0, TAU, 24, ink, w)
			draw_arc(ring, 6, 0, TAU, 16, ink, w)
			draw_line(Vector2(ring.x, RAIL_Y - 18), Vector2(ring.x, RAIL_Y), ink, w)
		Care.Station.NEST:
			var bowl := PackedVector2Array()
			for i in 17:
				var a := PI * i / 16.0
				bowl.append(foot + Vector2(-cos(a) * 52, -14 + sin(a) * 14))
			draw_colored_polygon(bowl, face)
			draw_polyline(bowl, ink, w)
			for i in 7:
				var x := foot.x - 46 + i * 15
				draw_line(Vector2(x, RAIL_Y - 16), Vector2(x + 14, RAIL_Y - 4), ink, 1.0)
		Care.Station.FIRST_AID:
			var box := Rect2(foot.x - 40, RAIL_Y - 32, 80, 32)
			draw_rect(box, face)
			draw_rect(box, ink, false, w)
			var c := box.get_center()
			draw_rect(Rect2(c.x - 3, c.y - 10, 6, 20), INK)
			draw_rect(Rect2(c.x - 10, c.y - 3, 20, 6), INK)
			draw_line(Vector2(box.position.x + 30, box.position.y), Vector2(box.position.x + 30, box.position.y - 6), ink, w)
			draw_line(Vector2(box.end.x - 30, box.position.y), Vector2(box.end.x - 30, box.position.y - 6), ink, w)
			draw_line(Vector2(box.position.x + 30, box.position.y - 6), Vector2(box.end.x - 30, box.position.y - 6), ink, w)
