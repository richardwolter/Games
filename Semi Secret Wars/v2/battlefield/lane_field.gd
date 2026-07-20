@tool
class_name LaneField
extends StageField
## V2 lane battlefield: a narrow horizontal lane (LaneLayout) rather than V1's
## open ellipse. Subclasses StageField so every Combatant — which types its
## field as StageField and touches it only through the public steering/collision
## API (steer_around, clamp_out_of_obstacles, in_lake, lake_damage, hero_spawn,
## villain_pos) — works unchanged inside the lane. Only geometry, deploy validity,
## the field-boundary clamp, and the draw are overridden.

## Lane dimensions (copied from the LaneLayout at runtime).
var lane_length: float = 6000.0
var lane_half_height: float = 450.0
## Fixed deploy band at the lane's left end.
var deploy_band_x_min: float = -2900.0
var deploy_band_x_max: float = -2300.0
## Authored destructible spawn points ((x,y)=pos, z=HP), read by LaneSpawner.
var lane_spawn_points: Array[Vector3] = []
## Purely decorative dressing outside the lane rect — not steered around, not
## clamped against. (x, y) center + z = radius. Index-aligned with border_decor_kinds.
## Hand-placed EXTRAS layered on top of the procedural band below (e.g. a hero
## prop the designer wants at a specific spot) — the band itself is generated,
## not authored.
var border_decor: Array[Vector3] = []
var border_decor_kinds: Array[String] = []

@export_group("Border Decor")
@export var tree_bushy_texture: Texture2D
@export var alien_tree_texture: Texture2D
@export var alien_tree_thin_texture: Texture2D
@export var plant_texture: Texture2D
## mushroom_texture is inherited from StageField (shared with scenery's
## "mushroom" kind — see _scenery_texture()) rather than redeclared here.

@export_subgroup("Procedural Band")
## Average spacing between generated props along the band (before jitter) —
## smaller means denser.
@export var band_spacing := 120.0
## Rows per side: row 0 hugs the lane, later rows sit progressively further out
## (smaller + darker-tinted), so the band overlaps into a continuous silhouette.
@export var band_row_count := 3
@export var band_jitter := Vector2(35.0, 25.0)
## Near-row (row 0) tree height in px. Scaled to sit near the same visual
## weight as the largest in-lane obstacles (mountain/forest, ~200-300px
## diameter) rather than dwarfing the lane itself — the lane is only
## lane_half_height*2 (900px) tall, so a 600px tree read as absurdly oversized.
@export var band_height_range := Vector2(160.0, 260.0)
## Height multiplier applied to every row after the first (depth cue).
@export var band_far_height_scale := 0.65
@export var band_far_tint := Color(0.74, 0.78, 0.70, 1.0)
## Bump to reroll the band's look without changing gameplay data.
@export var band_seed_salt := 0
## Depth multiplier for the top (far) long edge only — see _build_border_band().
## Kept low so tall canopies stay inside the camera's pannable area instead of
## getting clipped at the top of the screen when panned/zoomed all the way out.
@export var top_depth_scale := 0.3

@export_subgroup("Ground Scatter")
## Sparse mushrooms/smudges dressing the page beyond the tree band. Purely
## decorative, same seeded/deterministic generation as the band.
@export var scatter_spacing := 220.0
## Kept well under the smallest band tree so mushrooms/plants read as ground
## clutter, not a second tier of trees.
@export var scatter_size_range := Vector2(40.0, 80.0)

## Procedurally generated band entries, built by _build_border_band(). Each
## entry: {pos: Vector2 (ground base), height: float, tex: Texture2D,
## flip: bool, tint: Color}. Top = negative-y edge (always background).
## Bottom = positive-y edge (drawn in the foreground layer, in front of units).
## Left/right are the lane's short ends (background — heroes pass through the
## deploy/lair areas but don't linger flush against either end the way they
## hug the long edges, so these don't need the foreground occlusion treatment
## bottom gets).
var _band_top: Array[Dictionary] = []
var _band_bottom: Array[Dictionary] = []
var _band_left: Array[Dictionary] = []
var _band_right: Array[Dictionary] = []
var _scatter: Array[Dictionary] = []

## Overrides StageField._ready (which would load a V1 LevelLayout). Loads this
## level's LaneLayout instead, then does the same group/redraw bookkeeping.
func _ready() -> void:
	add_to_group("field")
	if not Engine.is_editor_hint():
		_load_lane_layout()
	default_hero_spawn = hero_spawn
	_build_border_band()
	queue_redraw()

func _load_lane_layout() -> void:
	var path := "res://v2/config/lane_%d_layout.tres" % RunState.current_level
	if not ResourceLoader.exists(path):
		push_warning("No LaneLayout at %s — using LaneField defaults." % path)
		return
	var layout: LaneLayout = load(path)
	if layout != null:
		apply_lane_layout(layout)

## Copies an authored lane into this field's live geometry. hero_spawn anchors at
## the deploy band center (the shared point the swarm marches on); villain_pos is
## the lair. field_radius is sized to the lane so the reused fog/page cover it.
func apply_lane_layout(layout: LaneLayout) -> void:
	lane_length = layout.lane_length
	lane_half_height = layout.lane_half_height
	deploy_band_x_min = layout.deploy_band_x_min
	deploy_band_x_max = layout.deploy_band_x_max
	hero_spawn = Vector2((deploy_band_x_min + deploy_band_x_max) * 0.5, 0.0)
	villain_pos = layout.villain_lair
	obstacles = layout.obstacles.duplicate()
	obstacle_kinds = layout.obstacle_kinds.duplicate()
	lakes = layout.lakes.duplicate()
	scenery = layout.scenery.duplicate()
	scenery_kinds = layout.scenery_kinds.duplicate()
	objective_positions = layout.objective_positions.duplicate()
	lane_spawn_points = layout.spawn_points.duplicate()
	border_decor = layout.border_decor.duplicate()
	border_decor_kinds = layout.border_decor_kinds.duplicate()
	# The lane is centered on the origin; field_radius is its half-extents so the
	# reused FogOfWar grid spans the whole lane (V2 no longer draws a page off
	# this — see _draw()).
	field_radius = Vector2(lane_length * 0.5, lane_half_height)
	_build_border_band()
	queue_redraw()

## Generates the continuous tree band (both sides) and the sparse ground
## scatter, deterministically from the level id so the same lane always looks
## the same (consistent with the fixed-layout / persistent-fog thesis — see
## LaneLayout's header comment). Rebuilt whenever the lane geometry changes.
func _build_border_band() -> void:
	_band_top.clear()
	_band_bottom.clear()
	_band_left.clear()
	_band_right.clear()
	_scatter.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("lane_band_%d_%d_%d" % [RunState.current_level, int(lane_length), band_seed_salt])
	# The top (far, background) edge sits noticeably further from the lane than
	# the bottom (near, foreground) edge once camera framing is factored in —
	# pull it in with a depth_scale < 1 so it doesn't read as floating way off
	# in the page margin (Designer call). Bottom keeps the full depth spread.
	_build_band_side(rng, _band_top, -1.0, top_depth_scale)
	_build_band_side(rng, _band_bottom, 1.0)
	_build_end_cap(rng, _band_left, -1.0)
	_build_end_cap(rng, _band_right, 1.0)
	_build_scatter(rng, -1.0, top_depth_scale)
	_build_scatter(rng, 1.0)
	_build_end_cap_scatter(rng, -1.0)
	_build_end_cap_scatter(rng, 1.0)

const _BAND_SPECIES := ["tree_bushy", "tree_bushy", "alien_tree", "alien_tree_thin", "plant"]

## Builds one long-edge side's band (top: sign -1, bottom: sign +1) as a set
## of rows marching along x with jitter, so consecutive props overlap into a
## continuous silhouette instead of tiling. Row 0 hugs the lane; later rows
## sit further out, smaller and darker-tinted (depth cue). `depth_scale`
## pulls the whole row closer to the lane without changing tree size/tint.
func _build_band_side(rng: RandomNumberGenerator, out: Array[Dictionary], side_sign: float, depth_scale := 1.0) -> void:
	var overhang := 260.0
	var along := -lane_length * 0.5 - overhang
	var along_max := lane_length * 0.5 + overhang
	while along < along_max:
		for row in band_row_count:
			var entry: Dictionary = _band_row_entry(rng, row, depth_scale)
			if not entry.is_empty():
				entry["pos"] = Vector2(along + entry["pos"].x, side_sign * (lane_half_height + entry["pos"].y))
				out.append(entry)
		along += band_spacing + rng.randf_range(-band_jitter.x * 0.3, band_jitter.x * 0.3)

## Builds one lateral end-cap's band (left: sign -1, right: sign +1) — the
## same continuous-overlap pattern as _build_band_side, rotated 90° to march
## along y instead of x, so the short ends of the lane get the same tree
## coverage as the long top/bottom edges.
func _build_end_cap(rng: RandomNumberGenerator, out: Array[Dictionary], side_sign: float) -> void:
	var overhang := 260.0
	var along := -lane_half_height - overhang
	var along_max := lane_half_height + overhang
	while along < along_max:
		for row in band_row_count:
			var entry: Dictionary = _band_row_entry(rng, row)
			if not entry.is_empty():
				entry["pos"] = Vector2(side_sign * (lane_length * 0.5 + entry["pos"].y), along + entry["pos"].x)
				out.append(entry)
		along += band_spacing + rng.randf_range(-band_jitter.x * 0.3, band_jitter.x * 0.3)

## One band prop, in row-local space: pos.x = jittered position along the
## edge, pos.y = depth out from the lane (both callers above translate this
## into world space for their own axis/side). Empty if this row's random
## species has no assigned texture (silently skipped, same as border_decor).
## `depth_scale` shrinks pos.y only, so a scaled-down edge pulls its trees
## closer without shrinking the trees themselves.
func _band_row_entry(rng: RandomNumberGenerator, row: int, depth_scale := 1.0) -> Dictionary:
	var is_far := row > 0
	var kind: String = _BAND_SPECIES[rng.randi() % _BAND_SPECIES.size()]
	var tex := _border_decor_texture(kind)
	if tex == null:
		return {}
	var height: float = rng.randf_range(band_height_range.x, band_height_range.y)
	if is_far:
		height *= lerpf(1.0, band_far_height_scale, float(row) / maxf(1.0, band_row_count - 1.0))
	var row_depth: float = lerpf(30.0, 140.0, float(row) / maxf(1.0, band_row_count - 1.0))
	var jitter_along: float = rng.randf_range(-band_jitter.x, band_jitter.x)
	var jitter_depth: float = rng.randf_range(0.0, band_jitter.y)
	return {
		"pos": Vector2(jitter_along, (row_depth + jitter_depth) * depth_scale),
		"height": height,
		"tex": tex,
		"flip": rng.randf() < 0.5,
		"tint": band_far_tint if is_far else Color.WHITE,
	}

const _SCATTER_KINDS := [["mushroom", "mushroom_texture"], ["smudge", "smudge_texture"], ["plant", "plant_texture"]]

## One scatter prop in row-local space (same pos.x=along/pos.y=depth
## convention as _band_row_entry). Empty if the picked kind has no texture.
## `depth_scale` shrinks pos.y only, same as _band_row_entry.
func _scatter_row_entry(rng: RandomNumberGenerator, depth_scale := 1.0) -> Dictionary:
	var pick: Array = _SCATTER_KINDS[rng.randi() % _SCATTER_KINDS.size()]
	var tex: Texture2D = get(pick[1])
	if tex == null:
		return {}
	return {
		"pos": Vector2(rng.randf_range(-scatter_spacing * 0.4, scatter_spacing * 0.4), rng.randf_range(160.0, 260.0) * depth_scale),
		"height": rng.randf_range(scatter_size_range.x, scatter_size_range.y),
		"tex": tex,
		"flip": rng.randf() < 0.5,
		"tint": Color.WHITE,
	}

## Sparse mushrooms/smudges dressing the page beyond a long-edge tree band —
## pure decoration, drawn behind the band (background only, both sides).
func _build_scatter(rng: RandomNumberGenerator, side_sign: float, depth_scale := 1.0) -> void:
	var overhang := 300.0
	var x := -lane_length * 0.5 - overhang
	var x_max := lane_length * 0.5 + overhang
	while x < x_max:
		var entry: Dictionary = _scatter_row_entry(rng, depth_scale)
		if not entry.is_empty():
			entry["pos"] = Vector2(x + entry["pos"].x, side_sign * (lane_half_height + entry["pos"].y))
			_scatter.append(entry)
		x += scatter_spacing + rng.randf_range(-scatter_spacing * 0.3, scatter_spacing * 0.3)

## Same scatter dressing along a lateral end-cap (left: sign -1, right: sign
## +1), rotated 90° like _build_end_cap.
func _build_end_cap_scatter(rng: RandomNumberGenerator, side_sign: float) -> void:
	var overhang := 340.0
	var y := -lane_half_height - overhang
	var y_max := lane_half_height + overhang
	while y < y_max:
		var entry: Dictionary = _scatter_row_entry(rng)
		if not entry.is_empty():
			entry["pos"] = Vector2(side_sign * (lane_length * 0.5 + entry["pos"].y), y + entry["pos"].x)
			_scatter.append(entry)
		y += scatter_spacing + rng.randf_range(-scatter_spacing * 0.3, scatter_spacing * 0.3)

## Read-only accessors for LaneForeground, which draws ALL border decor
## (bands, scatter, hand-placed extras) on its own canvas item, above both
## units and FogOfWar (see LaneForeground) — Godot's immediate-mode draw_*
## calls only affect whichever node is currently inside its own _draw(), so
## the entries have to be handed over rather than drawn directly from here.
func get_bottom_band() -> Array[Dictionary]:
	return _band_bottom

func get_top_band() -> Array[Dictionary]:
	return _band_top

func get_left_band() -> Array[Dictionary]:
	return _band_left

func get_right_band() -> Array[Dictionary]:
	return _band_right

func get_scatter() -> Array[Dictionary]:
	return _scatter

## Hand-placed border_decor extras, pre-resolved to the same {pos, radius,
## tex} shape LaneForeground's own center-anchored draw helper expects.
func get_border_decor_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in border_decor.size():
		var d := border_decor[i]
		var kind := border_decor_kinds[i] if i < border_decor_kinds.size() else ""
		var tex := _border_decor_texture(kind)
		if tex != null:
			out.append({"pos": Vector2(d.x, d.y), "radius": d.z, "tex": tex})
	return out

## Legal deploy point? Inside the fixed left-end band, clear of obstacles/lakes.
## Reuses the parent's obstacle/lake checks; only the band + rect bounds differ.
func is_valid_deploy_point(p: Vector2) -> bool:
	if p.x < deploy_band_x_min or p.x > deploy_band_x_max:
		return false
	if absf(p.y) > lane_half_height - deploy_obstacle_margin:
		return false
	if in_lake(p):
		return false
	for o in obstacles:
		if p.distance_to(Vector2(o.x, o.y)) < o.z + deploy_obstacle_margin:
			return false
	for o in dynamic_obstacles:
		if p.distance_to(Vector2(o.x, o.y)) < o.z + deploy_obstacle_margin:
			return false
	return true

## Rectangular field-boundary clamp (overrides StageField's ellipse clamp).
func clamp_inside_field(pos: Vector2, body_radius: float) -> Vector2:
	var hx := lane_length * 0.5 - body_radius
	var hy := lane_half_height - body_radius
	pos.x = clampf(pos.x, -hx, hx)
	pos.y = clampf(pos.y, -hy, hy)
	return pos

func _draw() -> void:
	# Notebook-page backdrop (V1's _draw_page): a cream, ruled-paper rect sized
	# to field_radius + page_margin, covering the lane and its surround alike
	# with the same fill + ruled lines — no separate lane floor is drawn on
	# top, so the ground blends seamlessly and the lane's boundary is defined
	# only by the tree band framing it (There Are No Orcs reference), not by
	# a color seam or outline.
	#
	# The border band/scatter/hand-placed decor are drawn in LaneForeground
	# instead of here — that node sits above FogOfWar (Designer, 2026-07-19:
	# lane-border scenery should read through the fog even in unexplored
	# territory, unlike obstacles/spawn points/in-lane scenery below, which
	# stay hidden under this node's own z_index until a hero has actually
	# been there).
	_draw_page()
	_draw_deploy_band()
	for i in scenery.size():
		var s := scenery[i]
		var skind := scenery_kinds[i] if i < scenery_kinds.size() else ""
		var stex := _scenery_texture(skind)
		if stex != null:
			_draw_obstacle_sprite(Vector2(s.x, s.y), s.z, stex)
		# No placeholder fallback — see StageField._draw() for why.
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
	_draw_lair()

## Tinted left-end band where heroes may (re)deploy.
func _draw_deploy_band() -> void:
	var rect := Rect2(
		Vector2(deploy_band_x_min, -lane_half_height),
		Vector2(deploy_band_x_max - deploy_band_x_min, lane_half_height * 2.0))
	draw_rect(rect, Color(0.353, 0.659, 0.353, 0.12), true)
	draw_line(Vector2(deploy_band_x_max, -lane_half_height),
			Vector2(deploy_band_x_max, lane_half_height),
			Color(0.30, 0.55, 0.30, 0.7), 3.0, true)
	_draw_label(Vector2((deploy_band_x_min + deploy_band_x_max) * 0.5, -lane_half_height + 30.0), "DEPLOY")

func _draw_lair() -> void:
	draw_arc(villain_pos, 70.0, 0.0, TAU, 28, Color(0.55, 0.2, 0.55, 0.9), 4.0, true)
	_draw_label(villain_pos + Vector2(0.0, -84.0), "VILLAIN LAIR")

## Border decor is no longer drawn here — see get_top_band()/get_left_band()/
## get_right_band()/get_bottom_band()/get_scatter()/get_border_decor_entries()
## and LaneForeground, which draws all of it above FogOfWar.

func _border_decor_texture(kind: String) -> Texture2D:
	match kind:
		"tree_bushy":
			return tree_bushy_texture
		"alien_tree":
			return alien_tree_texture
		"alien_tree_thin":
			return alien_tree_thin_texture
		"plant":
			return plant_texture
		_:
			return null
