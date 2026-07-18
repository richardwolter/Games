@tool
class_name StageField
extends Node2D
## The Stage 1 (Dark Mage) open battlefield: layout data + placeholder rendering.
##
## Single source of truth for field geometry — named locations (hero spawn,
## villain, objective), blocking obstacles, decorative scenery, and the Poison
## Lake (drawn only; hazard effect TBD, see BACKLOG). Units query this node (group
## "field") for spawn/goal points and steer around its obstacles.
##
## Rendering follows the designer sketch + ART_BIBLE: a notebook page with an
## organic, hand-drawn field blob (2:1 ellipse ratio suggests the iso view),
## a funnel entrance at the hero spawn, and labeled placeholder features.

## Half-extents of the field blob (2:1 keeps the isometric feel).
## Sized so the camera can never frame the whole battle at once (zoom_min shows
## roughly a quarter of the field) — the war is bigger than the window.
@export var field_radius := Vector2(2000.0, 1000.0)
@export var hero_spawn := Vector2(-1500.0, -600.0)
@export var villain_pos := Vector2(1420.0, 640.0)
## Minimum distance the villain must spawn from every hero, so he lands just
## outside each hero's vision bubble (fog_of_war.gd vision_radius = 400) rather
## than deep in fog or in plain sight.
@export var villain_min_clearance := 450.0
## Editor-preview fallback only; overwritten at runtime by randomize_objectives().
@export var objective_pos := Vector2(-1200.0, 560.0)
## How many objectives to place on the field.
@export var objective_count := 2
## Minimum clearance an objective point must keep from obstacles/lake.
@export var objective_obstacle_margin := 60.0
## Minimum distance an objective must keep from hero_spawn and villain_pos,
## so it's never trivially on top of either.
@export var objective_endpoint_clearance := 500.0
## Minimum distance between objectives, so two rolls don't land on top of each other.
@export var objective_min_spacing := 400.0
## Blocking obstacles: (x, y) center + z = radius. Units steer around these.
## Editor-preview fallback only; positions overwritten at runtime by
## randomize_obstacles() (radius and obstacle_kinds stay index-aligned).
@export var obstacles: Array[Vector3] = [
	Vector3(-310.0, -240.0, 130.0),
	Vector3(400.0, 130.0, 110.0),
	Vector3(-900.0, 200.0, 120.0),
	Vector3(900.0, -350.0, 140.0),
	Vector3(100.0, 620.0, 100.0),
]
## Minimum clearance an obstacle must keep from hero_spawn/villain_pos and
## from every other obstacle, when rerolled each run.
@export var obstacle_endpoint_clearance := 300.0
@export var obstacle_min_spacing := 250.0
## Sprite kind per obstacle above (index-aligned): "mountain" or "forest".
## Falls back to the placeholder blob+label for any index without a match.
@export var obstacle_kinds: Array[String] = ["mountain", "forest", "mountain", "forest", "mountain"]
@export var mountain_texture: Texture2D
@export var forest_texture: Texture2D
## Decorative only — no gameplay effect.
@export var scenery: Array[Vector3] = [
	Vector3(130.0, -570.0, 95.0),
	Vector3(-450.0, 450.0, 90.0),
	Vector3(1250.0, -100.0, 110.0),
	Vector3(-1300.0, -350.0, 100.0),
]
## Poison Lakes: damage-over-time hazard for all units inside (heroes and
## minions). (x, y) center + z = x-radius; y-radius is z * lake_radius_ratio.
## Editor-preview fallback only; positions overwritten at runtime by
## randomize_lakes().
@export var lakes: Array[Vector3] = [
	Vector3(840.0, 420.0, 260.0),
	Vector3(-500.0, -450.0, 220.0),
]
@export var lake_radius_ratio := 0.5
## Minimum clearance a lake must keep from hero_spawn/villain_pos/obstacles
## and from every other lake, when rerolled each run.
@export var lake_endpoint_clearance := 400.0
@export var lake_min_spacing := 350.0
## HP drained per second while a unit is inside a lake (provisional, see BALANCE.md).
@export var lake_dps := 8.0

@export_group("Deployment")
## Obstacle clearance for deployment: the party spreads ±~72px side by side.
@export var deploy_obstacle_margin := 80.0

## The scene-authored spawn, captured before the player moves hero_spawn.
## The deploy zone is anchored here.
var default_hero_spawn := Vector2.ZERO

## Rolled fresh each battle by randomize_objectives(); Objective nodes read
## their position from here by index. Falls back to objective_pos (editor
## preview / before the first roll) if empty.
var objective_positions: Array[Vector2] = []

@export_group("Notebook Page")
@export var page_color := Color("f4efe1")
@export var rule_color := Color("aac4dd")
@export var margin_color := Color("d98f8f")
@export var rule_spacing := 40.0
## Extra page margin beyond the field blob. Sized to comfortably cover the
## deploy-phase camera (which recenters on hero_spawn, near the field's
## edge) plus normal zoom-out, so panning never runs past the drawn page
## into the engine's default background color.
@export var page_margin := Vector2(900.0, 900.0)

@export_group("Field Style")
## All field shapes render fully transparent (no fill) with black pen
## outlines, so the notebook page's ruled lines show through — matching the
## hand-inked sprite art where identification is by outline shape + label,
## not color.
@export var field_color := Color("f4efe1", 0.0)
@export var obstacle_color := Color("f4efe1", 0.0)
@export var scenery_color := Color("f4efe1", 0.0)
@export var lake_color := Color("f4efe1", 0.0)
@export var outline_color := Color("161412")
@export var outline_width := 4.0

func _ready() -> void:
	add_to_group("field")
	default_hero_spawn = hero_spawn
	if not Engine.is_editor_hint():
		randomize_obstacles()
		randomize_lakes()
		randomize_objectives()
	queue_redraw()

## Rerolls each obstacle's (x, y) in place, keeping its radius and
## obstacle_kinds index-aligned. Clear of hero_spawn/villain_pos and of every
## other obstacle already placed, so every battle's terrain is new.
func randomize_obstacles() -> void:
	var placed: Array[Vector2] = []
	for i in obstacles.size():
		var radius := obstacles[i].z
		var p := _random_ring_point(radius, obstacle_endpoint_clearance, obstacle_min_spacing, placed, [])
		obstacles[i] = Vector3(p.x, p.y, radius)
		placed.append(p)

## Rerolls each lake's (x, y) in place, keeping its radius. Clear of
## hero_spawn/villain_pos, of obstacles, and of every other lake already
## placed, so the hazard layout is new each battle.
func randomize_lakes() -> void:
	var placed: Array[Vector2] = []
	for i in lakes.size():
		var radius := lakes[i].z
		var p := _random_ring_point(radius, lake_endpoint_clearance, lake_min_spacing, placed, obstacles)
		lakes[i] = Vector3(p.x, p.y, radius)
		placed.append(p)

## Rejection-samples a point inside the field ellipse, clear of hero_spawn/
## villain_pos (by `endpoint_clearance`), of every point in `placed` (by
## `spacing`), and of every obstacle in `avoid_obstacles` (by radius + spacing).
func _random_ring_point(radius: float, endpoint_clearance: float, spacing: float, placed: Array[Vector2], avoid_obstacles: Array[Vector3]) -> Vector2:
	for _attempt in 200:
		var p := Vector2(
			randf_range(-field_radius.x, field_radius.x),
			randf_range(-field_radius.y, field_radius.y))
		if (p / (field_radius - Vector2(radius, radius))).length_squared() > 0.85:
			continue
		if p.distance_to(hero_spawn) < endpoint_clearance + radius:
			continue
		if p.distance_to(villain_pos) < endpoint_clearance + radius:
			continue
		var blocked := false
		for a in placed:
			if p.distance_to(a) < spacing + radius:
				blocked = true
				break
		if not blocked:
			for o in avoid_obstacles:
				if p.distance_to(Vector2(o.x, o.y)) < o.z + radius + spacing * 0.5:
					blocked = true
					break
		if blocked:
			continue
		return p
	return Vector2.ZERO

## Rolls objective_count viable points, clear of obstacles/lake, apart from
## hero_spawn/villain_pos, and apart from each other, so every battle places
## the objectives somewhere new instead of the same authored spot.
func randomize_objectives() -> void:
	objective_positions.clear()
	var anchors: Array[Vector2] = [hero_spawn, villain_pos]
	for i in objective_count:
		var p := _random_viable_point(anchors)
		objective_positions.append(p)
		anchors.append(p)

## Rejection-samples a point inside the field ellipse that clears every
## obstacle/lake margin and keeps its distance from `anchors`.
func _random_viable_point(anchors: Array[Vector2]) -> Vector2:
	for _attempt in 200:
		var p := Vector2(
			randf_range(-field_radius.x, field_radius.x),
			randf_range(-field_radius.y, field_radius.y))
		if (p / field_radius).length_squared() > 0.85:
			continue
		if in_lake(p):
			continue
		var blocked := false
		for o in obstacles:
			if p.distance_to(Vector2(o.x, o.y)) < o.z + objective_obstacle_margin:
				blocked = true
				break
		if blocked:
			continue
		if p.distance_to(hero_spawn) < objective_endpoint_clearance:
			continue
		if p.distance_to(villain_pos) < objective_endpoint_clearance:
			continue
		var too_close := false
		for a in anchors:
			if a == hero_spawn or a == villain_pos:
				continue
			if p.distance_to(a) < objective_min_spacing:
				too_close = true
				break
		if too_close:
			continue
		return p
	return objective_pos

## Rolls villain_pos fresh each battle: a uniformly random point on the field
## (clear of obstacles/lake) that sits just outside every hero's initial
## vision bubble (villain_min_clearance), rather than always the single
## farthest point from the party. Called once deploy positions are known.
## Falls back to the farthest-point search if no point clears every hero by
## villain_min_clearance (e.g. a tiny field or a tightly packed party).
func randomize_villain_pos(hero_positions: Array[Vector2]) -> void:
	if hero_positions.is_empty():
		return
	var candidates: Array[Vector2] = []
	var best := villain_pos
	var best_score := -1.0
	for _attempt in 200:
		var p := Vector2(
			randf_range(-field_radius.x, field_radius.x),
			randf_range(-field_radius.y, field_radius.y))
		if (p / field_radius).length_squared() > 0.85:
			continue
		if in_lake(p):
			continue
		var blocked := false
		for o in obstacles:
			if p.distance_to(Vector2(o.x, o.y)) < o.z + objective_obstacle_margin:
				blocked = true
				break
		if blocked:
			continue
		var score := INF
		for h in hero_positions:
			score = minf(score, p.distance_to(h))
		if score > best_score:
			best_score = score
			best = p
		if score >= villain_min_clearance:
			candidates.append(p)
	villain_pos = candidates.pick_random() if not candidates.is_empty() else best

## Deployment: move the run's hero spawn to the player-chosen point.
## Units read hero_spawn live (heroes spawn there; the swarm marches on it),
## so the whole battle re-anchors to the chosen point. Redraw moves the funnel.
func set_hero_spawn(p: Vector2) -> void:
	hero_spawn = p
	queue_redraw()

## Is `p` a legal hero deploy point? Anywhere inside the field ellipse, clear
## of obstacles and the Poison Lake — the player may deploy wherever they like.
func is_valid_deploy_point(p: Vector2) -> bool:
	if (p / field_radius).length_squared() > 1.0:
		return false
	if in_lake(p):
		return false
	for o in obstacles:
		if p.distance_to(Vector2(o.x, o.y)) < o.z + deploy_obstacle_margin:
			return false
	return true

## Steering helper: adjust a desired direction to avoid blocking obstacles.
## Combines radial pushback (don't penetrate) with a tangential slide (go
## around) — pure pushback alone cancels out on head-on approaches.
func steer_around(pos: Vector2, desired: Vector2, clearance: float) -> Vector2:
	for o in obstacles:
		desired = _avoid(pos, desired, Vector2(o.x, o.y), o.z, clearance, 1.5)
	# Avoid the Poison Lakes: extra margin so units start skirting well before
	# the shore. Slightly weaker than hard obstacles — combat pursuit of a
	# target inside a lake can still drag a unit in.
	for l in lakes:
		var lake_pos := Vector2(l.x, l.y)
		var lake_radius := Vector2(l.z, l.z * lake_radius_ratio)
		desired = _avoid(pos, desired, lake_pos, _lake_radius_toward(pos, lake_pos, lake_radius), clearance + 50.0, 1.3)
	return desired.normalized() if desired.length() > 0.01 else desired

## Push `desired` around one circular blocker. `strength` scales the avoidance
## (>=1 hard obstacle, <1 soft/hazard). Smoothstepped so the correction ramps
## in gradually instead of kicking at the avoidance boundary (less jitter).
func _avoid(pos: Vector2, desired: Vector2, center: Vector2, radius: float, clearance: float, strength: float) -> Vector2:
	var avoid_r := radius + clearance
	var to_obs := center - pos
	var dist := to_obs.length()
	if dist >= avoid_r:
		return desired
	# Ignore blockers behind us unless we're already inside the core.
	if to_obs.dot(desired) <= 0.0 and dist > radius:
		return desired
	var away := -to_obs.normalized()
	var tangent := away.orthogonal()
	if tangent.dot(desired) < 0.0:
		tangent = -tangent
	var push := smoothstep(0.0, 1.0, (avoid_r - dist) / avoid_r)
	return desired + (away + tangent) * push * strength

## Is a point inside any Poison Lake ellipse?
func in_lake(pos: Vector2) -> bool:
	for l in lakes:
		var d := (pos - Vector2(l.x, l.y)) / Vector2(l.z, l.z * lake_radius_ratio)
		if d.length_squared() <= 1.0:
			return true
	return false

## Effective lake radius along the direction from `lake_pos` toward `pos`, so
## the elliptical lake can reuse the circular avoidance math.
func _lake_radius_toward(pos: Vector2, lake_pos: Vector2, lake_radius: Vector2) -> float:
	var dir := pos - lake_pos
	if dir.length_squared() < 0.001:
		return lake_radius.x
	var a := dir.angle()
	var rx := lake_radius.x
	var ry := lake_radius.y
	return (rx * ry) / sqrt(pow(ry * cos(a), 2.0) + pow(rx * sin(a), 2.0))

## Hard collision: push a unit center out of any obstacle core it overlaps.
## Steering is only a hint; this guarantees units never clip through obstacles.
func clamp_out_of_obstacles(pos: Vector2, body_radius: float) -> Vector2:
	for o in obstacles:
		var center := Vector2(o.x, o.y)
		var min_d := o.z + body_radius
		var to_pos := pos - center
		var dist := to_pos.length()
		if dist < min_d:
			pos = center + (to_pos / dist if dist > 0.001 else Vector2.RIGHT) * min_d
	return pos

## Hard collision: push a unit center back inside the field ellipse if it
## has crossed the boundary. Steering never targets the edge directly, so
## this only fires when combat/knockback drags a unit out past it.
func clamp_inside_field(pos: Vector2, body_radius: float) -> Vector2:
	var inset := field_radius - Vector2(body_radius, body_radius)
	var d := pos / inset
	var len_sq := d.length_squared()
	if len_sq > 1.0:
		pos = pos / sqrt(len_sq)
	return pos

func _draw() -> void:
	_draw_page()
	_draw_blob(Vector2.ZERO, field_radius, field_color, 40, 7.0, 0.05)
	_draw_funnel()
	for o in scenery:
		_draw_blob(Vector2(o.x, o.y), Vector2(o.z, o.z * 0.55), scenery_color, 18, 5.0, 0.10)
		_draw_label(Vector2(o.x, o.y), "SCENERY")
	for i in obstacles.size():
		var o := obstacles[i]
		var kind := obstacle_kinds[i] if i < obstacle_kinds.size() else ""
		var tex := _obstacle_texture(kind)
		if tex != null:
			_draw_obstacle_sprite(Vector2(o.x, o.y), o.z, tex)
		else:
			_draw_blob(Vector2(o.x, o.y), Vector2(o.z, o.z * 0.6), obstacle_color, 18, 5.0, 0.12)
			_draw_label(Vector2(o.x, o.y), "OBSTACLE")
	for l in lakes:
		var lake_pos := Vector2(l.x, l.y)
		var lake_radius := Vector2(l.z, l.z * lake_radius_ratio)
		_draw_blob(lake_pos, lake_radius, lake_color, 24, 6.0, 0.10)
		_draw_hatch(lake_pos, lake_radius)
		_draw_label(lake_pos, "POISON LAKE")

func _draw_page() -> void:
	var half := field_radius + page_margin
	var rect := Rect2(-half, half * 2.0)
	draw_rect(rect, page_color, true)
	var y := rect.position.y + rule_spacing
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), rule_color, 1.5, true)
		y += rule_spacing
	var mx := rect.position.x + 56.0
	draw_line(Vector2(mx, rect.position.y), Vector2(mx, rect.end.y), margin_color, 2.0, true)

## Organic hand-drawn blob: ellipse with stable per-vertex wobble, inked with
## two overlapping outline passes (like a pen retracing its own line) so it
## reads as a hand-drawn stroke rather than a clean vector outline.
func _draw_blob(center: Vector2, radius: Vector2, fill: Color, steps: int, wobble: float, wobble_freq: float) -> void:
	var pts := _wobbled_points(center, radius, steps, wobble, wobble_freq, 0.0)
	draw_colored_polygon(pts, fill)
	_draw_ink_outline(pts)
	var sketch := _wobbled_points(center, radius, steps, wobble * 1.6, wobble_freq * 1.7, 1.7)
	sketch.append(sketch[0])
	draw_polyline(sketch, Color(outline_color, 0.5), outline_width * 0.45, true)

func _wobbled_points(center: Vector2, radius: Vector2, steps: int, wobble: float, wobble_freq: float, phase: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		var w := 1.0 + sin(a * 5.0 + phase + center.x * wobble_freq) * (wobble / 100.0) + cos(a * 3.0 + phase + center.y * wobble_freq) * (wobble / 140.0)
		pts.append(center + Vector2(cos(a) * radius.x * w, sin(a) * radius.y * w))
	return pts

func _draw_ink_outline(pts: PackedVector2Array) -> void:
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, outline_color, outline_width, true)

## Poison Lake hazard marking: black cross-hatch strokes over the paper fill
## (comic-ink water texture), clipped to the lake's ellipse.
func _draw_hatch(center: Vector2, radius: Vector2) -> void:
	var step := 26.0
	var hatch := Color(outline_color, 0.55)
	var x := -radius.x
	while x <= radius.x:
		var h := sqrt(max(0.0, 1.0 - (x / radius.x) ** 2)) * radius.y
		if h > 1.0:
			draw_line(center + Vector2(x, -h), center + Vector2(x + h * 0.9, h * 0.1), hatch, 2.0, true)
		x += step

## Funnel entrance at the hero spawn: a short paper-colored path opening into the field.
func _draw_funnel() -> void:
	var dir := (Vector2.ZERO - hero_spawn).normalized()
	var perp := dir.orthogonal()
	var mouth := hero_spawn - dir * 280.0
	var pts := PackedVector2Array([
		mouth + perp * 40.0, mouth - perp * 40.0,
		hero_spawn - perp * 115.0, hero_spawn + perp * 115.0])
	draw_colored_polygon(pts, page_color)
	draw_polyline(PackedVector2Array([pts[0], pts[3]]), outline_color, outline_width, true)
	draw_polyline(PackedVector2Array([pts[1], pts[2]]), outline_color, outline_width, true)

func _obstacle_texture(kind: String) -> Texture2D:
	match kind:
		"mountain":
			return mountain_texture
		"forest":
			return forest_texture
		_:
			return null

## Draws an obstacle's paper-cutout sprite centered on `center`, scaled so its
## longest edge matches the obstacle's blocking diameter (2 * radius) —
## same convention as Combatant's sprite_texture sizing.
func _draw_obstacle_sprite(center: Vector2, radius: float, tex: Texture2D) -> void:
	var diameter := radius * 2.0
	var tex_size := tex.get_size()
	var scale_factor := diameter / maxf(tex_size.x, tex_size.y)
	var draw_size := tex_size * scale_factor
	draw_texture_rect(tex, Rect2(center - draw_size * 0.5, draw_size), false)

func _draw_label(at: Vector2, text: String) -> void:
	var font := ThemeDB.fallback_font
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, at + Vector2(-tw * 0.5, 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, outline_color)
