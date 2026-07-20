@tool
class_name LaneField
extends Node2D
## The lane battlefield: a narrow horizontal lane (LevelLayout) — layout data +
## rendering. Single source of truth for field geometry — named locations
## (hero spawn, villain, destructible spawn points), blocking obstacles,
## decorative scenery, and the Poison Lake. Units query this node (group
## "field") for spawn/goal points and steer around its obstacles.

## Lane dimensions (copied from the LevelLayout at runtime).
var lane_length: float = 6000.0
var lane_half_height: float = 450.0
## Fixed deploy band at the lane's left end.
var deploy_band_x_min: float = -2900.0
var deploy_band_x_max: float = -2300.0
## Authored destructible spawn points ((x,y)=pos, z=HP), read by LaneSpawner.
var lane_spawn_points: Array[Vector3] = []
## Lane ("top"/"bottom") each spawn point above belongs to, index-aligned —
## see LevelLayout.spawn_point_lanes.
var lane_spawn_point_lanes: Array[String] = []
## Lane each objective belongs to ("top"/"bottom"/"" = both), index-aligned
## with objective_positions — see LevelLayout.objective_lanes.
var lane_objective_lanes: Array[String] = []
## Purely decorative dressing outside the lane rect — not steered around, not
## clamped against. (x, y) center + z = radius. Index-aligned with border_decor_kinds.
## Hand-placed EXTRAS layered on top of the procedural band below (e.g. a hero
## prop the designer wants at a specific spot) — the band itself is generated,
## not authored.
var border_decor: Array[Vector3] = []
var border_decor_kinds: Array[String] = []

var hero_spawn := Vector2(-1500.0, -600.0)
var villain_pos := Vector2(1420.0, 640.0)
## The dividing line between the top and bottom lanes (Designer, 2026-07-20:
## split the lane in two so heroes/minions spread instead of clustering on one
## spot). Fixed at lane center — lanes are a behavioral zone, not a hard wall,
## so this never needs to vary per level.
const LANE_SPLIT_Y := 0.0
## How close to the villain (in x) the lane split actually ends — inside this
## band a unit's y is left unclamped so top and bottom can converge on one
## villain fight; everywhere else (Designer, 2026-07-20: "merge should be
## right before the villain, not in the middle of the lane") a unit is held
## hard to its own lane's half.
const LANE_MERGE_ZONE_WIDTH := 500.0
## Small buffer past the split line so a clamped unit doesn't ride the exact
## boundary and jitter across it every frame as steering nudges it back and forth.
const LANE_CLAMP_MARGIN := 20.0

## Which lane a point belongs to — "top" (y < split) or "bottom" (y >= split).
## Used both for deploy-position lane assignment (Hero._configure) and as the
## fallback for spawn points/objectives with no explicit lane tag.
func lane_of(pos: Vector2) -> String:
	return "top" if pos.y < LANE_SPLIT_Y else "bottom"

## X coordinate where the lane split ends and top/bottom are free to converge.
func lane_merge_x() -> float:
	return villain_pos.x - LANE_MERGE_ZONE_WIDTH

## True when at least one living real Hero (HeroClone excluded — it has no
## `lane` of its own) is currently assigned to `lane_value`. Used to detect a
## collapsed lane (its whole Duo wiped out).
func lane_has_living_hero(lane_value: String) -> bool:
	for node in get_tree().get_nodes_in_group("heroes"):
		if node is Hero and is_instance_valid(node) and not node._dying and (node as Hero).lane == lane_value:
			return true
	return false

## Which lanes have EVER had a hero deploy into them this battle — set by
## Hero._configure via mark_lane_populated. Distinguishes "this lane's
## defenders died" (should merge) from "nobody was ever deployed here"
## (an uneven/one-sided deploy — should NOT merge, or every hero would read
## the un-deployed lane as instantly collapsed and every lane restriction
## would silently turn off from the opening frame).
var _lane_populated := {"top": false, "bottom": false}

func mark_lane_populated(lane_value: String) -> void:
	_lane_populated[lane_value] = true

## True once a lane that DID have heroes assigned to it has since lost all of
## them (Designer, 2026-07-20: "lane separation breaks because of the
## assigned duo's death") — at that point the two lanes are effectively one
## battlefield: both the movement clamp (clamp_to_lane) and hero target-lane
## filtering (Hero._lane_ok) stand down everywhere, not just near the villain.
## A lane nobody was ever deployed to does NOT trigger this on its own.
func lanes_merged() -> bool:
	for lane_value in _lane_populated:
		if _lane_populated[lane_value] and not lane_has_living_hero(lane_value):
			return true
	return false

## Hard-clamps `pos` to stay on `lane_value`'s own side of the split, UNLESS
## pos.x has already reached the merge zone near the villain, or the lanes
## have collapsed (lanes_merged()) — called every frame by any lane-restricted
## unit (Hero, Minion) after its normal movement step, so steering/goals can
## never walk it across into the other lane's territory before the merge
## point/collapse. `lane_value` == "" (unrestricted units, e.g. HeroClone) is
## a no-op.
func clamp_to_lane(pos: Vector2, lane_value: String) -> Vector2:
	if lane_value == "" or pos.x >= lane_merge_x() or lanes_merged():
		return pos
	if lane_value == "top":
		pos.y = minf(pos.y, -LANE_CLAMP_MARGIN)
	else:
		pos.y = maxf(pos.y, LANE_CLAMP_MARGIN)
	return pos

## Derived from lane_length/lane_half_height (see apply_lane_layout) — sizes
## the reused FogOfWar/page grids, not an authored ellipse.
var field_radius := Vector2(2000.0, 1000.0)
## Blocking obstacles: (x, y) center + z = radius. Units steer around these.
## Positions come from the LevelLayout at runtime (apply_lane_layout keeps
## radius and obstacle_kinds index-aligned).
var obstacles: Array[Vector3] = []
## Sprite kind per obstacle above (index-aligned): "mountain" or "forest".
## Falls back to the placeholder blob+label for any index without a match.
var obstacle_kinds: Array[String] = []
@export var mountain_texture: Texture2D
@export var forest_texture: Texture2D
@export var spaceship_texture: Texture2D
@export var rock1_texture: Texture2D
@export var rock2_texture: Texture2D
@export var sword_texture: Texture2D
## Decorative only — no gameplay effect.
var scenery: Array[Vector3] = []
## Sprite kind per scenery entry above (index-aligned): "smudge". Falls back to
## the placeholder blob+label for any index without a match.
var scenery_kinds: Array[String] = []
@export var smudge_texture: Texture2D
@export var mushroom_texture: Texture2D
## Poison Lakes: entry-hazard for all units inside (heroes and minions). (x, y)
## center + z = x-radius; y-radius is z * lake_radius_ratio.
var lakes: Array[Vector3] = []
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
## from here by index. Dormant — no LevelLayout currently authors these.
var objective_positions: Array[Vector2] = []

## Runtime-registered blockers with the same collision treatment as `obstacles`
## (steer_around, clamp_out_of_obstacles) but not authored/drawn like them —
## for units that exist only at runtime, e.g. LaneSpawnPoint gates
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
## Extra page margin beyond the field. Sized to comfortably cover the
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

@export_group("Border Decor")
@export var tree_bushy_texture: Texture2D
@export var alien_tree_texture: Texture2D
@export var alien_tree_thin_texture: Texture2D
@export var plant_texture: Texture2D
## mushroom_texture (above) is shared with scenery's "mushroom" kind — see
## _scenery_texture().

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

func _ready() -> void:
	add_to_group("field")
	if not Engine.is_editor_hint():
		_load_lane_layout()
	default_hero_spawn = hero_spawn
	_build_border_band()
	queue_redraw()

func _load_lane_layout() -> void:
	var path := "res://config/level_%d_layout.tres" % RunState.current_level
	if not ResourceLoader.exists(path):
		push_warning("No LevelLayout at %s — using LaneField defaults." % path)
		return
	var layout: LevelLayout = load(path)
	if layout != null:
		apply_lane_layout(layout)

## Copies an authored lane into this field's live geometry. hero_spawn anchors at
## the deploy band center (the shared point the swarm marches on); villain_pos is
## the lair. field_radius is sized to the lane so the reused fog/page cover it.
func apply_lane_layout(layout: LevelLayout) -> void:
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
	lane_objective_lanes = layout.objective_lanes.duplicate()
	lane_spawn_points = layout.spawn_points.duplicate()
	lane_spawn_point_lanes = layout.spawn_point_lanes.duplicate()
	border_decor = layout.border_decor.duplicate()
	border_decor_kinds = layout.border_decor_kinds.duplicate()
	# The lane is centered on the origin; field_radius is its half-extents so the
	# reused FogOfWar grid spans the whole lane (the lane no longer draws a
	# page off this — see _draw()).
	field_radius = Vector2(lane_length * 0.5, lane_half_height)
	_build_border_band()
	queue_redraw()

## Generates the continuous tree band (both sides) and the sparse ground
## scatter, deterministically from the level id so the same lane always looks
## the same (consistent with the fixed-layout / persistent-fog thesis — see
## LevelLayout's header comment). Rebuilt whenever the lane geometry changes.
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

## Steering helper: adjust a desired direction to avoid blocking obstacles.
## Combines radial pushback (don't penetrate) with a tangential slide (go
## around) — pure pushback alone cancels out on head-on approaches.
func steer_around(pos: Vector2, desired: Vector2, clearance: float) -> Vector2:
	for o in obstacles:
		desired = _avoid(pos, desired, Vector2(o.x, o.y), o.z, clearance, 1.5)
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
	for o in dynamic_obstacles:
		var center3 := Vector2(o.x, o.y)
		var min_d3 := o.z + body_radius
		var to_pos3 := pos - center3
		var dist3 := to_pos3.length()
		if dist3 < min_d3:
			pos = center3 + (to_pos3 / dist3 if dist3 > 0.001 else Vector2.RIGHT) * min_d3
	return pos

## Rectangular field-boundary clamp.
func clamp_inside_field(pos: Vector2, body_radius: float) -> Vector2:
	var hx := lane_length * 0.5 - body_radius
	var hy := lane_half_height - body_radius
	pos.x = clampf(pos.x, -hx, hx)
	pos.y = clampf(pos.y, -hy, hy)
	return pos

func _draw() -> void:
	# Notebook-page backdrop: a cream, ruled-paper rect sized to field_radius +
	# page_margin, covering the lane and its surround alike with the same fill
	# + ruled lines — no separate lane floor is drawn on top, so the ground
	# blends seamlessly and the lane's boundary is defined only by the tree
	# band framing it (There Are No Orcs reference), not by a color seam or
	# outline.
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
		# No placeholder fallback — scenery is purely decorative (unlike
		# obstacles/lakes below, which block movement and so always need to
		# be visible); an entry with no assigned sprite kind just draws
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
	_draw_lair()

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
## on top of it later.
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
	_draw_lane_divider()

## Dashed centerline marking the top/bottom lane split — drawn across the
## deploy band (so it's clear which half a hero is being dropped into) and all
## the way up to the merge zone right before the villain lair, matching the
## actual movement clamp in clamp_to_lane (Designer, 2026-07-20: "merge should
## be right before the villain, not in the middle of the lane").
func _draw_lane_divider() -> void:
	var x_start := deploy_band_x_min
	var x_end := lane_merge_x()
	var dash := 24.0
	var gap := 16.0
	var x := x_start
	while x < x_end:
		var seg_end: float = minf(x + dash, x_end)
		draw_line(Vector2(x, LANE_SPLIT_Y), Vector2(seg_end, LANE_SPLIT_Y),
				Color(outline_color, 0.45), 2.5, true)
		x += dash + gap
	_draw_label(Vector2(deploy_band_x_min + 40.0, LANE_SPLIT_Y - 12.0), "TOP LANE")
	_draw_label(Vector2(deploy_band_x_min + 40.0, LANE_SPLIT_Y + 22.0), "BOTTOM LANE")

func _draw_lair() -> void:
	draw_arc(villain_pos, 70.0, 0.0, TAU, 28, Color(0.55, 0.2, 0.55, 0.9), 4.0, true)
	_draw_label(villain_pos + Vector2(0.0, -84.0), "VILLAIN LAIR")

## Border decor is no longer drawn here — see get_top_band()/get_left_band()/
## get_right_band()/get_bottom_band()/get_scatter()/get_border_decor_entries()
## and LaneForeground, which draws all of it above FogOfWar.

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
