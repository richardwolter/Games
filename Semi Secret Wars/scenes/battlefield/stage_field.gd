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
## Editor-preview fallback only; overwritten at runtime by apply_layout().
@export var objective_pos := Vector2(-1200.0, 560.0)
## Blocking obstacles: (x, y) center + z = radius. Units steer around these.
## Editor-preview fallback only; positions come from the LevelLayout at runtime
## (apply_layout keeps radius and obstacle_kinds index-aligned).
@export var obstacles: Array[Vector3] = [
	Vector3(-310.0, -240.0, 130.0),
	Vector3(400.0, 130.0, 110.0),
	Vector3(-900.0, 200.0, 120.0),
	Vector3(900.0, -350.0, 140.0),
	Vector3(100.0, 620.0, 100.0),
]
## Sprite kind per obstacle above (index-aligned): "mountain" or "forest".
## Falls back to the placeholder blob+label for any index without a match.
@export var obstacle_kinds: Array[String] = ["mountain", "forest", "mountain", "forest", "mountain"]
@export var mountain_texture: Texture2D
@export var forest_texture: Texture2D
@export var spaceship_texture: Texture2D
@export var rock1_texture: Texture2D
@export var rock2_texture: Texture2D
@export var sword_texture: Texture2D
## Decorative only — no gameplay effect.
@export var scenery: Array[Vector3] = [
	Vector3(130.0, -570.0, 95.0),
	Vector3(-450.0, 450.0, 90.0),
	Vector3(1250.0, -100.0, 110.0),
	Vector3(-1300.0, -350.0, 100.0),
]
## Sprite kind per scenery entry above (index-aligned): "smudge". Falls back to
## the placeholder blob+label for any index without a match.
@export var scenery_kinds: Array[String] = []
@export var smudge_texture: Texture2D
@export var mushroom_texture: Texture2D
## Poison Lakes: entry-hazard for all units inside (heroes and minions). (x, y)
## center + z = x-radius; y-radius is z * lake_radius_ratio.
## Editor-preview fallback only; positions come from the LevelLayout at runtime.
@export var lakes: Array[Vector3] = [
	Vector3(840.0, 420.0, 260.0),
	Vector3(-500.0, -450.0, 220.0),
]
@export var lake_radius_ratio := 0.5
## HP lost per lake ENTRY — a single hit on crossing the shore, not a per-second
## drain (Combatant edge-triggers this on the outside→inside transition). Light
## enough that briefly clipping a lake is a minor cost, not lethal.
@export var lake_damage := 6.0

@export_group("Deployment")
## Obstacle clearance for deployment: the party spreads ±~72px side by side.
@export var deploy_obstacle_margin := 80.0

## The scene-authored spawn, captured before the player moves hero_spawn.
## The deploy zone is anchored here.
var default_hero_spawn := Vector2.ZERO

## Objective points for this level; Objective/Guardian nodes read their position
## from here by index. Populated by apply_layout() (editor-preview fallback:
## objective_pos) — no longer rolled per battle.
var objective_positions: Array[Vector2] = []
## Minion spawn gates for this level (authored in the LevelLayout). Read by the
## MinionSpawner in Phase 3; empty until a layout is applied.
var spawn_gates: Array[Vector2] = []
## Spawn gates are unmovable structures, not just points: blocked like obstacles
## so heroes can't stand on top of (or walk straight over) the swarm's source.
@export var spawn_gate_radius := 70.0

## Runtime-registered blockers with the same collision treatment as `obstacles`
## (steer_around, clamp_out_of_obstacles) but not authored/drawn like them —
## for units that exist only at runtime, e.g. V2's LaneSpawnPoint gates
## (LaneSpawner registers/unregisters as points spawn in and die). (x, y)
## center + z = radius, same convention as `obstacles`.
var dynamic_obstacles: Array[Vector3] = []

func register_dynamic_obstacle(pos: Vector2, radius: float) -> void:
	dynamic_obstacles.append(Vector3(pos.x, pos.y, radius))

func unregister_dynamic_obstacle(pos: Vector2, radius: float) -> void:
	for i in dynamic_obstacles.size():
		var o := dynamic_obstacles[i]
		if o.x == pos.x and o.y == pos.y and o.z == radius:
			dynamic_obstacles.remove_at(i)
			return

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
	if not Engine.is_editor_hint():
		_load_layout_for_current_level()
	default_hero_spawn = hero_spawn
	queue_redraw()

## Loads the authored LevelLayout for RunState.current_level and applies it.
## Keeps the exported editor-preview fallbacks if no layout file exists for the
## level (so an unauthored level or the editor still renders something).
func _load_layout_for_current_level() -> void:
	var path := "res://config/level_%d_layout.tres" % RunState.current_level
	if not ResourceLoader.exists(path):
		push_warning("No LevelLayout at %s — using StageField editor fallbacks." % path)
		return
	var layout: LevelLayout = load(path)
	if layout != null:
		apply_layout(layout)

## Copies an authored layout into this field's live geometry. Called before any
## objective/guardian/villain reads a position (all resolve in their own _ready,
## which runs after this node's _ready in tree order — Field is the first child).
func apply_layout(layout: LevelLayout) -> void:
	hero_spawn = layout.deploy_anchor
	villain_pos = layout.villain_lair
	obstacles = layout.obstacles.duplicate()
	obstacle_kinds = layout.obstacle_kinds.duplicate()
	lakes = layout.lakes.duplicate()
	scenery = layout.scenery.duplicate()
	objective_positions = layout.objective_positions.duplicate()
	spawn_gates = layout.spawn_gates.duplicate()
	queue_redraw()

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
	for g in spawn_gates:
		if p.distance_to(g) < spawn_gate_radius + deploy_obstacle_margin:
			return false
	for o in dynamic_obstacles:
		if p.distance_to(Vector2(o.x, o.y)) < o.z + deploy_obstacle_margin:
			return false
	return true

## Steering helper: adjust a desired direction to avoid blocking obstacles.
## Combines radial pushback (don't penetrate) with a tangential slide (go
## around) — pure pushback alone cancels out on head-on approaches.
func steer_around(pos: Vector2, desired: Vector2, clearance: float) -> Vector2:
	for o in obstacles:
		desired = _avoid(pos, desired, Vector2(o.x, o.y), o.z, clearance, 1.5)
	for g in spawn_gates:
		desired = _avoid(pos, desired, g, spawn_gate_radius, clearance, 1.5)
	for o in dynamic_obstacles:
		desired = _avoid(pos, desired, Vector2(o.x, o.y), o.z, clearance, 1.5)
	# Avoid the Poison Lakes: wide margin + near-obstacle strength so units skirt
	# well before the shore and only rarely clip in. A combat pursuit can still
	# drag a unit in, but that now costs a single ~6 HP entry hit, not a drain —
	# a cheap, acceptable price for chasing a target across the water.
	for l in lakes:
		var lake_pos := Vector2(l.x, l.y)
		var lake_radius := Vector2(l.z, l.z * lake_radius_ratio)
		desired = _avoid(pos, desired, lake_pos, _lake_radius_toward(pos, lake_pos, lake_radius), clearance + 90.0, 1.6)
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
	for g in spawn_gates:
		var min_d2 := spawn_gate_radius + body_radius
		var to_pos2 := pos - g
		var dist2 := to_pos2.length()
		if dist2 < min_d2:
			pos = g + (to_pos2 / dist2 if dist2 > 0.001 else Vector2.RIGHT) * min_d2
	for o in dynamic_obstacles:
		var center3 := Vector2(o.x, o.y)
		var min_d3 := o.z + body_radius
		var to_pos3 := pos - center3
		var dist3 := to_pos3.length()
		if dist3 < min_d3:
			pos = center3 + (to_pos3 / dist3 if dist3 > 0.001 else Vector2.RIGHT) * min_d3
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
	for i in scenery.size():
		var s := scenery[i]
		var skind := scenery_kinds[i] if i < scenery_kinds.size() else ""
		var stex := _scenery_texture(skind)
		if stex != null:
			_draw_obstacle_sprite(Vector2(s.x, s.y), s.z, stex)
		# No placeholder fallback — scenery is purely decorative (unlike
		# obstacles/lakes/gates below, which block movement and so always need
		# to be visible); an entry with no assigned sprite kind just draws
		# nothing, same as border_decor/the procedural tree band.
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
	for g in spawn_gates:
		_draw_blob(g, Vector2(spawn_gate_radius, spawn_gate_radius * 0.6), obstacle_color, 14, 5.0, 0.12)
		_draw_label(g, "SPAWN GATE")

func _draw_page() -> void:
	var half := field_radius + page_margin
	var rect := Rect2(-half, half * 2.0)
	draw_rect(rect, page_color, true)
	_draw_ruled_lines(rect, rect, rule_color, 1.5)
	var mx := rect.position.x + 56.0
	draw_line(Vector2(mx, rect.position.y), Vector2(mx, rect.end.y), margin_color, 2.0, true)

## Draws ruled-notebook horizontal lines clipped to `rect`, phased from
## `page_rect`'s own grid (not `rect`'s position) so the pattern lines up
## seamlessly whether it's drawn over the plain page or a filled area painted
## on top of it later — e.g. V2's lane floor, which redraws these over its own
## opaque fill so the ruled page shows through the lane, not just around it.
func _draw_ruled_lines(rect: Rect2, page_rect: Rect2, color: Color, width: float) -> void:
	var y := page_rect.position.y + rule_spacing
	while y < rect.end.y:
		if y >= rect.position.y:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), color, width, true)
		y += rule_spacing

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
		"spaceship":
			return spaceship_texture
		"rock1":
			return rock1_texture
		"rock2":
			return rock2_texture
		"sword":
			return sword_texture
		_:
			return null

## Scenery is non-blocking (no gameplay effect) but may still carry sprite art.
func _scenery_texture(kind: String) -> Texture2D:
	match kind:
		"smudge":
			return smudge_texture
		"mushroom":
			return mushroom_texture
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

## Draws a prop standing on the ground: scaled to `height` (aspect preserved),
## horizontally centered on `base.x` with its BOTTOM edge at `base.y`. Unlike
## _draw_obstacle_sprite (center-anchored, sized off the blocking radius), this
## gives tall art — trees, plants — a real ground line instead of floating it
## around a center point. `tint` modulates for depth shading; `flip_h` mirrors.
func _draw_prop_sprite(base: Vector2, height: float, tex: Texture2D, flip_h := false, tint := Color.WHITE) -> void:
	var tex_size := tex.get_size()
	if tex_size.y <= 0.0:
		return
	var draw_size := Vector2(tex_size.x * (height / tex_size.y), height)
	var rect := Rect2(base - Vector2(draw_size.x * 0.5, draw_size.y), draw_size)
	if flip_h:
		# Negative width mirrors the texture in place (Godot flips on a negative extent).
		rect = Rect2(rect.position + Vector2(draw_size.x, 0.0), Vector2(-draw_size.x, draw_size.y))
	draw_texture_rect(tex, rect, false, tint)

func _draw_label(at: Vector2, text: String) -> void:
	var font := ThemeDB.fallback_font
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, at + Vector2(-tw * 0.5, 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, outline_color)
