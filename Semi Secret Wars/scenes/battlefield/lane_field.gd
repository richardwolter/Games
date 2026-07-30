@tool
class_name LaneField
extends Node2D
## The lane battlefield: a narrow horizontal lane (LevelLayout) — layout data +
## rendering. Single source of truth for field geometry — named locations
## (hero spawn, villain, destructible spawn points), blocking obstacles,
## decorative scenery, and the Poison Lake. Units query this node (group
## "field") for spawn/goal points and steer around its obstacles.

## Lane dimensions (copied from the LevelLayout at runtime). These defaults are
## only the editor/no-layout fallback — every level's real values live in
## config/level_*_layout.tres, so change those, not these.
##
## lane_half_height 450 -> 400 on 2026-07-26 (Designer: narrower lanes top and
## bottom). It tightens the playable band by 100px total, so units crowd more
## and have less room to spread out around each other.
var lane_length: float = 6000.0
var lane_half_height: float = 400.0
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
## The villain's LIVE position — BattleManager overwrites this every frame
## while he's alive (see its _process), so it is a moving point, not the lair.
## Anything that needs the fixed structure must use `lair_pos` instead.
var villain_pos := Vector2(1420.0, 640.0)
## The authored lair anchor (LevelLayout.villain_lair) — static for the whole
## level. Split out from villain_pos on 2026-07-25: the wrecked-spaceship lair
## was being drawn at villain_pos, which meant the 300px wreck slid around the
## battlefield following the villain as he moved.
var lair_pos := Vector2(2900.0, 0.0)
## Collision radius of the wrecked-ship lair. Its art draws at 2x this (the
## shared _draw_obstacle_sprite convention), so 150 => a 300px wreck.
const LAIR_RADIUS := 150.0
## How far IN FRONT of the wreck (toward the incoming heroes, i.e. -x) the
## villain stands (Designer, 2026-07-25: "the villain should spawn outside of
## the spaceship"). Must clear the wreck's blocked zone for a hero
## (LAIR_RADIUS + hero clamp radius ~67 = 217) so the party can actually reach
## him rather than being held off by his own lair.
const VILLAIN_LAIR_OFFSET := 300.0
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

## Level-long single-lane mode: set at load from RunState.duo_wiped() when a
## whole Duo has already fallen earlier in the run (Designer, 2026-07-26 —
## "if an entire DUO dies, the next level should be a single lane for the
## remaining DUO"). It forces lanes_merged() true for the entire level, which
## is exactly the state a mid-battle Duo wipe already produces: no y-clamping
## to a half, no lane-filtered targeting, gates on both halves open to
## everyone. The field keeps its authored full height and props — "single
## lane" here is the behavioral split going away, not a narrower battlefield.
var single_lane := false

func mark_lane_populated(lane_value: String) -> void:
	_lane_populated[lane_value] = true

## True once a lane that DID have heroes assigned to it has since lost all of
## them (Designer, 2026-07-20: "lane separation breaks because of the
## assigned duo's death") — at that point the two lanes are effectively one
## battlefield: both the movement clamp (clamp_to_lane) and hero target-lane
## filtering (Hero._lane_ok) stand down everywhere, not just near the villain.
## A lane nobody was ever deployed to does NOT trigger this on its own.
func lanes_merged() -> bool:
	if single_lane:
		return true
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
## Sprite kind per obstacle above (index-aligned).
## Falls back to the placeholder blob+label for any index without a match.
var obstacle_kinds: Array[String] = []
## OVAL footprint per obstacle above (index-aligned), as semi-axes (rx, ry) —
## derived from the kind's art at load, never authored (Designer, 2026-07-25).
## The .tres still authors one radius: that stays the SIZE knob, and this only
## reshapes it, so the art/collision decoupling in ART_BIBLE is preserved.
var obstacle_radii: Array[Vector2] = []
@export var spaceship_texture: Texture2D
## Alternate lair art per level (Designer, 2026-07-25) — the Berserker holes up
## in a beast den, not a crashed ship. Picked by LAIR_TEXTURE_BY_LEVEL.
@export var berserk_lair_texture: Texture2D
## Obstacle kind "boulder" — a big collidable rock, heavier than rock1/rock2.
@export var boulder_texture: Texture2D
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
## Scenery kind "paw_print" (Designer, 2026-07-25) — animal tracks crossing the
## lane. Decorative only, like every other `scenery` entry.
@export var paw_print_texture: Texture2D
## Poison Lakes: entry-hazard for all units inside (heroes and minions). (x, y)
## center + z = x-radius; y-radius is z * lake_radius_ratio.
##
## Currently UNUSED: every level_*_layout.tres ships an empty `lakes` array
## (Designer, 2026-07-26 — "remove the poison lakes for now"). The machinery
## below (in_lake, the avoidance field, the purple hatched draw) is left intact
## so putting them back is a data change, not a code change.
var lakes: Array[Vector3] = []
@export var lake_radius_ratio := 0.5
## HP lost per lake ENTRY — a single hit on crossing the shore, not a per-second
## drain (Combatant edge-triggers this on the outside→inside transition). Light
## enough that briefly clipping a lake is a minor cost, not lethal.
@export var lake_damage := 6.0

## Spike pits: (x, y) center + z = radius. Circular entry-hazard, same
## one-hit-per-entry contract as a lake (Combatant edge-triggers both), but
## smaller, rounder and harder-hitting — a lake is a wide area you skirt, a
## spike pit is a nasty spot you step in. Not a blocker: units path over it.
##
## Level 2's hazard, and only level 2's (Designer, 2026-07-26): levels 1 and 3
## ship an empty array, so the pits are what makes level 2 read as the nastier
## ground rather than a hazard tax every level pays.
var spike_pits: Array[Vector3] = []
@export var spike_texture: Texture2D
@export var spike_damage := 14.0

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
## Oval footprint per dynamic obstacle (index-aligned), same contract as
## obstacle_radii. Callers that don't supply one get a circle.
var dynamic_obstacle_radii: Array[Vector2] = []

func register_dynamic_obstacle(pos: Vector2, radius: float,
		radii := Vector2.ZERO) -> void:
	dynamic_obstacles.append(Vector3(pos.x, pos.y, radius))
	dynamic_obstacle_radii.append(radii if radii.x > 0.0 else Vector2(radius, radius))

func unregister_dynamic_obstacle(pos: Vector2, radius: float) -> void:
	for i in dynamic_obstacles.size():
		var o := dynamic_obstacles[i]
		if o.x == pos.x and o.y == pos.y and o.z == radius:
			dynamic_obstacles.remove_at(i)
			# Index-aligned with the array above — must drop together.
			if i < dynamic_obstacle_radii.size():
				dynamic_obstacle_radii.remove_at(i)
			return

@export_group("Notebook Page")
## Page/rule/margin come straight from UIStyle rather than restating the hex
## here — these were three literals that had to be kept in sync with the menu
## screens by hand, and the notebook only works if the battlefield page and the
## prep page are the same sheet of paper.
@export var page_color := UIStyle.PAGE_SOLID
@export var rule_color := UIStyle.RULE
@export var margin_color := UIStyle.MARGIN
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
## The Poison Lake is the ONE field shape that carries real colour (Designer,
## 2026-07-25: "paint the poison lake purple, so it looks toxic"). Everything
## else stays transparent-with-ink-outline so the page shows through; the lake
## is a hazard that costs HP on entry, so it earns a colour the eye catches.
## Translucent, so the ruled page still reads underneath like a wash of ink.
## Purple because it's toxic, and specifically UIStyle.VIOLET because that is
## the pigment the enemy art is drawn in — the lake belongs to the enemy side
## of the palette, and now says so.
@export var lake_color := Color(UIStyle.VIOLET, 0.34)
## Outline + hatching for the lake, a darker/stronger version of the fill so
## the shape still reads as hand-inked rather than a flat digital blob.
@export var lake_ink_color := UIStyle.VIOLET.darkened(0.45)
## The pen every field shape is inked with — the sprites' own linework pigment,
## a touch deeper than UI ink so field outlines hold up against the page.
@export var outline_color := UIStyle.SOOT.darkened(0.15)
@export var outline_width := 4.0

@export_group("Border Decor")
@export var tree_bushy_texture: Texture2D
@export var alien_tree_texture: Texture2D
@export var alien_tree_thin_texture: Texture2D
@export var plant_texture: Texture2D
## Stage 2's spectator stands (Designer, 2026-07-25) — one wide strip, tiled
## along both long edges in place of the tree band. See _build_crowd_side.
@export var crowd_texture: Texture2D
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
		# Before anything spawns: heroes read it in _configure, minions and
		# clones every frame, so the flag must be settled while the field is
		# still empty.
		single_lane = RunState.duo_wiped()
	default_hero_spawn = hero_spawn
	# One roll per battlefield load — see _marks_seed.
	_marks_seed = randi()
	_ensure_page_backdrop()
	_build_border_band()
	_redraw_field()

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
	lair_pos = layout.villain_lair
	# The villain starts OUTSIDE his ship, in front of it. villain_pos is only
	# the SEED here — BattleManager takes it over as his live position once he
	# spawns (Villain._configure reads it for the initial placement).
	villain_pos = lair_pos + Vector2(-VILLAIN_LAIR_OFFSET, 0.0)
	obstacles = layout.obstacles.duplicate()
	obstacle_kinds = layout.obstacle_kinds.duplicate()
	# The lair wreck is a real blocking obstacle (Designer, 2026-07-25), not
	# scenery — appended here rather than authored into every layout so the
	# lair can never drift out of sync with villain_lair. Going through
	# `obstacles` means collision, steering, deploy validity and drawing all
	# come from the existing pipeline for free. Safe against re-entry: the two
	# arrays above are reassigned from the layout on every call, so repeated
	# apply_lane_layout calls can't stack duplicate wrecks.
	obstacles.append(Vector3(lair_pos.x, lair_pos.y, LAIR_RADIUS))
	obstacle_kinds.append(_lair_kind())
	_rebuild_obstacle_radii()
	lakes = layout.lakes.duplicate()
	spike_pits = layout.spike_pits.duplicate()
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
	_redraw_field()

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
	# Stage 2 is an arena, not a forest (Designer, 2026-07-25): its long edges
	# are lined with jeering spectator stands instead of the procedural tree
	# band. Only the two LONG edges change — the end caps and scatter still
	# come from the shared generator below, so the lane's ends still close off.
	var crowd_edges: bool = crowd_texture != null and RunState.current_level == CROWD_BORDER_LEVEL
	if crowd_edges:
		_build_crowd_side(_band_top, -1.0)
		_build_crowd_side(_band_bottom, 1.0)
	else:
		_build_band_side(rng, _band_top, -1.0, top_depth_scale)
		_build_band_side(rng, _band_bottom, 1.0)
	_build_end_cap(rng, _band_left, -1.0)
	_build_end_cap(rng, _band_right, 1.0)
	# Long-edge scatter is skipped under the stands (Designer, 2026-07-25:
	# watch for overlap) — mushrooms sit at exactly the depth the crowd strip
	# now occupies, so they'd render as litter stuck to the grandstand. The
	# end-cap scatter stays: those run past the lane's ends, clear of it.
	if not crowd_edges:
		_build_scatter(rng, -1.0, top_depth_scale)
		_build_scatter(rng, 1.0)
	_build_end_cap_scatter(rng, -1.0)
	_build_end_cap_scatter(rng, 1.0)

## Level whose long edges are spectator stands instead of trees.
const CROWD_BORDER_LEVEL := 2
## Preferred rendered height of one crowd strip, in world units. The strip is
## very wide and short, so it is sized by HEIGHT and tiled along x by its own
## aspect. Only a CAP: the real height is whatever fits between the lane edge
## and the furthest the camera can ever see (see _crowd_strip_height) — at 300
## the top stands ran past that and were clipped even at full zoom-out
## (Designer, 2026-07-25).
const CROWD_HEIGHT := 300.0
## Never squash the stands below this, even if the camera clearance is tiny —
## better to clip a sliver than to render an unreadable smear.
const CROWD_MIN_HEIGHT := 120.0
## Overlap between consecutive tiles, as a fraction of tile width — hides the
## seam where one hand-drawn strip meets the next.
const CROWD_TILE_OVERLAP := 0.04
## Transparent margin below the stands in Berserk_Level_Borders_Color1, as a
## fraction of the texture height (72px of 612). See _build_crowd_side.
const CROWD_ART_BASE_PAD := 0.118

## Tiles the crowd strip end to end along one long edge. Emits the same entry
## shape as _build_band_side so LaneForeground draws it with no special case;
## `flip` alternates so repeats do not read as one obviously repeated image.
func _build_crowd_side(into: Array[Dictionary], side_sign: float) -> void:
	var tex_size := crowd_texture.get_size()
	if tex_size.y <= 0.0:
		return
	# Compensation is applied AFTER the clamp on purpose: _crowd_strip_height
	# limits how tall the stands may LOOK (camera clearance), and with padded
	# art the drawn rect has to exceed that for the visible stands to land on
	# it. Tile width follows from the same drawn height, so the seam overlap
	# still lines up.
	var height := _crowd_strip_height() * art_pad_height(crowd_texture)
	var tile_w: float = tex_size.x * (height / tex_size.y)
	var step: float = tile_w * (1.0 - CROWD_TILE_OVERLAP)
	if step <= 1.0:
		return
	# Props are base-anchored and grow upward (see _draw_prop_sprite), so the
	# bottom edge needs its base pushed out by the strip height or the stands
	# would lean back over the lane. Both sides then occupy exactly `height`
	# outward of their lane edge — mirrored, not offset.
	var y: float = side_sign * lane_half_height
	if side_sign > 0.0:
		y += height
	# Color1 carries an even ~12% transparent margin above and below the
	# stands. Base-anchoring uses the texture's edge, not the drawing's, so
	# without this the stands would hover that far off the lane edge with a
	# visible gap. Pushed toward the lane on whichever side we're building.
	y += -side_sign * CROWD_ART_BASE_PAD * height
	# Start a full tile before the lane and run a full tile past its end, so
	# the stands are unbroken from one end cap to the other with no partial
	# tile visible at either extreme.
	var x: float = -lane_length * 0.5 - tile_w
	while x <= lane_length * 0.5 + tile_w:
		into.append({
			"pos": Vector2(x, y),
			"height": height,
			"tex": crowd_texture,
			# No alternating mirror: the stands are directional art, so every
			# other tile flipped read as "some right, some backwards"
			# (Designer, 2026-07-25). Uniform orientation along each edge.
			"flip": side_sign > 0.0,
			# The bottom edge is the top edge turned a full 180° (both axes),
			# so it mirrors across the lane instead of duplicating it.
			"flip_v": side_sign > 0.0,
			"tint": Color.WHITE,
		})
		x += step

## Tallest a crowd strip can be drawn and still fit entirely on screen at the
## widest view: half a viewport at zoom_min, plus how far the camera may pan
## off-center, minus the lane half-height the strip starts from. Read off the
## live BattleCamera so re-tuning zoom/pan can't silently re-clip the stands;
## falls back to the CROWD_HEIGHT cap when there's no camera (editor, tests).
func _crowd_strip_height() -> float:
	if get_parent() == null:
		return CROWD_HEIGHT
	var cam := get_parent().get_node_or_null("BattleCamera") as BattleCamera
	if cam == null or cam.zoom_min <= 0.0:
		return CROWD_HEIGHT
	var view_h := float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	var clearance := view_h * 0.5 / cam.zoom_min + absf(cam.pan_limits.y) - lane_half_height
	return clampf(clearance, CROWD_MIN_HEIGHT, CROWD_HEIGHT)

const _BAND_SPECIES := ["tree_bushy", "tree_bushy", "alien_tree", "alien_tree_thin", "plant"]

## Props render canopy-up (base-anchored, growing toward smaller y — see
## LaneForeground._draw_prop_sprite) regardless of which side of the lane
## they're on. On the bottom edge that means "up" points back toward the
## lane, so a tall canopy can loom well past the split line unless its base
## is pushed out to compensate; on the top edge "up" already points away
## from the lane, so no compensation is needed there (Designer, 2026-07-25:
## bottom lane read visually smaller/more cramped than top because of this).
const BOTTOM_CANOPY_CLEARANCE := 40.0

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
				var depth: float = entry["pos"].y
				if side_sign > 0.0:
					depth += maxf(0.0, entry["height"] - BOTTOM_CANOPY_CLEARANCE)
				entry["pos"] = Vector2(along + entry["pos"].x, side_sign * (lane_half_height + depth))
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
	var height: float = rng.randf_range(band_height_range.x, band_height_range.y) * art_pad_height(tex)
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
		"height": rng.randf_range(scatter_size_range.x, scatter_size_range.y) * art_pad_height(tex),
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
			out.append({"pos": Vector2(d.x, d.y), "radius": d.z * art_pad_long(tex), "tex": tex})
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
## `clearance` is the steering unit's own OVAL footprint; both it and each
## blocker resolve to a radius along the approach, matching the hard clamp.
func steer_around(pos: Vector2, desired: Vector2, clearance: Vector2) -> Vector2:
	for i in obstacles.size():
		var o := obstacles[i]
		var center := Vector2(o.x, o.y)
		var dir := pos - center
		var obs_radii: Vector2 = obstacle_radii[i] if i < obstacle_radii.size() \
				else Vector2(o.z, o.z)
		desired = _avoid(pos, desired, center,
				SpriteFootprint.radius_toward(obs_radii, dir),
				SpriteFootprint.radius_toward(clearance, dir), 1.5)
	for i in dynamic_obstacles.size():
		var d := dynamic_obstacles[i]
		var dcenter := Vector2(d.x, d.y)
		var ddir := pos - dcenter
		var dyn_radii: Vector2 = dynamic_obstacle_radii[i] \
				if i < dynamic_obstacle_radii.size() else Vector2(d.z, d.z)
		desired = _avoid(pos, desired, dcenter,
				SpriteFootprint.radius_toward(dyn_radii, ddir),
				SpriteFootprint.radius_toward(clearance, ddir), 1.5)
	# Avoid the Poison Lakes: wide margin + near-obstacle strength so units skirt
	# well before the shore and only rarely clip in. A combat pursuit can still
	# drag a unit in, but that now costs a single ~6 HP entry hit, not a drain —
	# a cheap, acceptable price for chasing a target across the water.
	for l in lakes:
		var lake_pos := Vector2(l.x, l.y)
		var lake_radius := Vector2(l.z, l.z * lake_radius_ratio)
		desired = _avoid(pos, desired, lake_pos,
				_lake_radius_toward(pos, lake_pos, lake_radius),
				SpriteFootprint.radius_toward(clearance, pos - lake_pos) + 90.0, 1.6)
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

## Spike pit containment — the pit equivalent of in_lake. Circular, so no
## radius-ratio math. Returns the DAMAGE of the pit the point is inside (0.0
## when clear), letting the caller edge-trigger it exactly like a lake.
func in_spike_pit(pos: Vector2) -> bool:
	for s in spike_pits:
		if pos.distance_to(Vector2(s.x, s.y)) <= s.z:
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
## `radii` is the moving unit's OVAL footprint (Combatant._collision_radii).
## Both sides are ellipses now, so each contributes its radius along the line
## between the two centres — the same directional-radius trick the Poison Lake
## already uses, rather than a new ellipse solver.
func clamp_out_of_obstacles(pos: Vector2, radii: Vector2) -> Vector2:
	for i in obstacles.size():
		var o := obstacles[i]
		var center := Vector2(o.x, o.y)
		var to_pos := pos - center
		var dist := to_pos.length()
		var dir := to_pos / dist if dist > 0.001 else Vector2.RIGHT
		var obs_radii: Vector2 = obstacle_radii[i] if i < obstacle_radii.size() \
				else Vector2(o.z, o.z)
		var min_d := SpriteFootprint.radius_toward(obs_radii, dir) \
				+ SpriteFootprint.radius_toward(radii, dir)
		if dist < min_d:
			pos = center + dir * min_d
	for i in dynamic_obstacles.size():
		var d := dynamic_obstacles[i]
		var center3 := Vector2(d.x, d.y)
		var to_pos3 := pos - center3
		var dist3 := to_pos3.length()
		var dir3 := to_pos3 / dist3 if dist3 > 0.001 else Vector2.RIGHT
		var dyn_radii: Vector2 = dynamic_obstacle_radii[i] \
				if i < dynamic_obstacle_radii.size() else Vector2(d.z, d.z)
		var min_d3 := SpriteFootprint.radius_toward(dyn_radii, dir3) \
				+ SpriteFootprint.radius_toward(radii, dir3)
		if dist3 < min_d3:
			pos = center3 + dir3 * min_d3
	return pos

## How far each end of a line-of-sight query is pulled in before testing
## (see has_line_of_sight). A shooter or its target standing right against a
## rock has its own centre-to-edge span clipping that rock, which without this
## reads as "permanently blocked" and sends the shooter walking forever.
const LOS_END_SLACK := 28.0

## Does a projectile at `pos` overlap a blocking obstacle? Covers authored
## `obstacles` and runtime `dynamic_obstacles` (Designer, 2026-07-28: shots are
## stopped by the same things units can't walk through). Decorative `scenery`
## and the flat hazards (lakes, spike pits) deliberately do NOT block — they're
## ground, not cover.
func blocks_projectile(pos: Vector2) -> bool:
	for i in obstacles.size():
		var o := obstacles[i]
		var center := Vector2(o.x, o.y)
		var radii: Vector2 = obstacle_radii[i] if i < obstacle_radii.size() \
				else Vector2(o.z, o.z)
		if _point_in_oval(pos, center, radii):
			return true
	for i in dynamic_obstacles.size():
		var d := dynamic_obstacles[i]
		var dcenter := Vector2(d.x, d.y)
		var dradii: Vector2 = dynamic_obstacle_radii[i] \
				if i < dynamic_obstacle_radii.size() else Vector2(d.z, d.z)
		if _point_in_oval(pos, dcenter, dradii):
			return true
	return false

## Can a straight shot from `from` reach `to` without crossing a blocker?
## Used by ranged Combatants to hold fire (and reposition) instead of plinking
## a rock. Same blocker set as blocks_projectile.
func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var seg := to - from
	var seg_len := seg.length()
	if seg_len <= LOS_END_SLACK * 2.0:
		return true
	var dir := seg / seg_len
	var a := from + dir * LOS_END_SLACK
	var b := to - dir * LOS_END_SLACK
	for i in obstacles.size():
		var o := obstacles[i]
		var radii: Vector2 = obstacle_radii[i] if i < obstacle_radii.size() \
				else Vector2(o.z, o.z)
		if _segment_hits_oval(a, b, Vector2(o.x, o.y), radii):
			return false
	for i in dynamic_obstacles.size():
		var d := dynamic_obstacles[i]
		var dradii: Vector2 = dynamic_obstacle_radii[i] \
				if i < dynamic_obstacle_radii.size() else Vector2(d.z, d.z)
		if _segment_hits_oval(a, b, Vector2(d.x, d.y), dradii):
			return false
	return true

## Same directional-radius approximation the collision/steering code uses
## (SpriteFootprint.radius_toward) rather than a separate ellipse solver, so a
## shot is blocked by exactly the shape a unit is pushed out of.
func _point_in_oval(pos: Vector2, center: Vector2, radii: Vector2) -> bool:
	var to_pos := pos - center
	var dist := to_pos.length()
	if dist < 0.001:
		return true
	return dist <= SpriteFootprint.radius_toward(radii, to_pos / dist)

func _segment_hits_oval(a: Vector2, b: Vector2, center: Vector2,
		radii: Vector2) -> bool:
	var closest := Geometry2D.get_closest_point_to_segment(center, a, b)
	return _point_in_oval(closest, center, radii)

## Rectangular field-boundary clamp. Axis-aligned, so the oval's own semi-axes
## apply exactly — no directional radius needed.
func clamp_inside_field(pos: Vector2, radii: Vector2) -> Vector2:
	var hx := lane_length * 0.5 - radii.x
	var hy := lane_half_height - radii.y
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
	# The page itself is NOT drawn here any more — PageBackdrop paints it a layer
	# below, so Ultimate effects can slot between paper and props. See _paint_page.
	# The deploy band stays: it is translucent (alpha 0.12) ground marking, so an
	# effect passing under it still reads through.
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
			_draw_obstacle_prop(kind, Vector2(o.x, o.y), o.z, tex)
		else:
			# Unlabelled placeholder blob (Designer, 2026-07-25 — no text on
			# lane props). An obstacle with no sprite kind still has to be
			# VISIBLE, since it blocks movement: the blob shape is the tell.
			_draw_blob(Vector2(o.x, o.y), Vector2(o.z, o.z * 0.6), obstacle_color, 18, 5.0, 0.12)
	for l in lakes:
		var lake_pos := Vector2(l.x, l.y)
		var lake_radius := Vector2(l.z, l.z * lake_radius_ratio)
		_draw_blob(lake_pos, lake_radius, lake_color, 24, 6.0, 0.10, lake_ink_color)
		_draw_hatch(lake_pos, lake_radius)
	# Spike pits carry real art, so unlike the lake they need no blob/hatch —
	# the drawing IS the hazard marker. Same centred sizing as any obstacle
	# sprite, so radius reads true to the damage zone.
	for s in spike_pits:
		if spike_texture != null:
			_draw_obstacle_sprite(Vector2(s.x, s.y), s.z, spike_texture)
	_draw_lair()

## The canvas item the notebook page is painted on, one layer below this node so
## Duo Ultimate effects can sit between the paper and the props — see
## _paint_page. Created in code rather than authored in battlefield.tscn so the
## layering travels with the script that depends on it.
class PageBackdrop extends Node2D:
	var field: LaneField

	func _draw() -> void:
		if field != null:
			field._paint_page(self)

## Absolute z of the three field layers. Children are z_as_relative by default
## and LaneField itself sits at 0, so this resolves to -2 on the canvas.
## Hero._add_ultimate_effect puts effects at PAGE_Z + 1.
const PAGE_Z := -2

var _page_backdrop: PageBackdrop = null

## Both this node and its page layer. Every existing queue_redraw() site inside
## LaneField goes through here — the page has to follow a layout change (a new
## level resizes field_radius) or it would keep painting the previous lane's
## paper under the new one.
func _redraw_field() -> void:
	queue_redraw()
	if _page_backdrop != null:
		_page_backdrop.queue_redraw()

func _ensure_page_backdrop() -> void:
	if _page_backdrop != null:
		return
	_page_backdrop = PageBackdrop.new()
	_page_backdrop.name = "PageBackdrop"
	_page_backdrop.field = self
	_page_backdrop.z_index = PAGE_Z
	add_child(_page_backdrop)

## Reseeded every time a battlefield loads, so each level reads as a different
## page out of the same notebook (Designer, 2026-07-26 — the menu's marks are
## deliberately fixed, this one is deliberately not). Stored rather than rolled
## inside _draw because _draw re-runs constantly; a fresh roll per frame would
## make the scribbles crawl.
var _marks_seed := 0
## Preloaded by path, not by class_name — see PrepPage.PageMarksLib for why.
const PageMarksLib := preload("res://scripts/page_marks.gd")

## The notebook page, painted onto `target` rather than onto this node.
##
## Split onto its own canvas item on 2026-07-28 so Duo Ultimate effects can draw
## BEHIND the obstacles (Designer: "its over everything now"). Everything on the
## field shares one z, so an effect pushed below the props was also pushed below
## the paper they sit on — the page and the props were the same layer. They are
## now two: PageBackdrop at z -2, effects at -1, props and units at 0.
##
## `target` is the PageBackdrop child. Godot's immediate-mode draw_* calls only
## affect the CanvasItem currently inside its own _draw(), so this cannot paint
## the child from LaneField._draw — the child calls this from ITS _draw and
## passes itself in. Same trick LaneForeground uses in reverse.
func _paint_page(target: CanvasItem) -> void:
	var half := field_radius + page_margin
	var rect := Rect2(-half, half * 2.0)
	target.draw_rect(rect, page_color, true)
	_draw_ruled_lines(target, rect, rect, rule_color, 1.5)
	var mx := rect.position.x + 56.0
	target.draw_line(Vector2(mx, rect.position.y), Vector2(mx, rect.end.y), margin_color, 2.0, true)
	# Scribbles/stains/smudges over the rules but under everything else, so the
	# page reads as used without ever sitting on top of a unit or a prop. No
	# keep-out: unlike the menus there is no text to protect here.
	#
	# Density scales with page AREA — the lane is several times the size of a
	# menu screen, and PageMarks' counts are authored per 1920x1080 page, so a
	# flat count would leave a big field looking untouched.
	var page_area := rect.size.x * rect.size.y
	var density := clampf(page_area / (1920.0 * 1080.0), 1.0, 6.0)
	PageMarksLib.draw_marks(target, rect, _marks_seed, 1.0, density)

## Draws ruled-notebook horizontal lines clipped to `rect`, phased from
## `page_rect`'s own grid (not `rect`'s position) so the pattern lines up
## seamlessly whether it's drawn over the plain page or a filled area painted
## on top of it later.
func _draw_ruled_lines(target: CanvasItem, rect: Rect2, page_rect: Rect2,
		color: Color, width: float) -> void:
	var y := page_rect.position.y + rule_spacing
	while y < rect.end.y:
		if y >= rect.position.y:
			target.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), color, width, true)
		y += rule_spacing

## Organic hand-drawn blob: ellipse with stable per-vertex wobble, inked with
## two overlapping outline passes (like a pen retracing its own line) so it
## reads as a hand-drawn stroke rather than a clean vector outline.
## `ink` overrides the pen colour for shapes that are not plain black-on-paper
## (the Poison Lake — see lake_ink_color); everything else passes nothing and
## keeps the shared outline_color.
func _draw_blob(center: Vector2, radius: Vector2, fill: Color, steps: int, wobble: float, wobble_freq: float, ink: Color = outline_color) -> void:
	var pts := _wobbled_points(center, radius, steps, wobble, wobble_freq, 0.0)
	draw_colored_polygon(pts, fill)
	_draw_ink_outline(pts, ink)
	var sketch := _wobbled_points(center, radius, steps, wobble * 1.6, wobble_freq * 1.7, 1.7)
	sketch.append(sketch[0])
	draw_polyline(sketch, Color(ink, 0.5), outline_width * 0.45, true)

func _wobbled_points(center: Vector2, radius: Vector2, steps: int, wobble: float, wobble_freq: float, phase: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		var w := 1.0 + sin(a * 5.0 + phase + center.x * wobble_freq) * (wobble / 100.0) + cos(a * 3.0 + phase + center.y * wobble_freq) * (wobble / 140.0)
		pts.append(center + Vector2(cos(a) * radius.x * w, sin(a) * radius.y * w))
	return pts

func _draw_ink_outline(pts: PackedVector2Array, ink: Color = outline_color) -> void:
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, ink, outline_width, true)

## Poison Lake hazard marking: cross-hatch strokes over the fill (comic-ink
## water texture), clipped to the lake.s ellipse. Inked in lake_ink_color so
## the hatching reads as part of the toxic wash rather than plain black.
func _draw_hatch(center: Vector2, radius: Vector2) -> void:
	var step := 26.0
	var hatch := Color(lake_ink_color, 0.6)
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
	# FOREST: the friendly end of the palette, opposite the lake's enemy violet.
	draw_rect(rect, Color(UIStyle.FOREST, 0.12), true)
	draw_line(Vector2(deploy_band_x_max, -lane_half_height),
			Vector2(deploy_band_x_max, lane_half_height),
			Color(UIStyle.FOREST, 0.7), 3.0, true)
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

## The villain's lair is the wrecked spaceship (Designer, 2026-07-25 — it used
## to be an unexplained prop in mid-lane, wasting the best piece of set-
## dressing art in the game on a spot that meant nothing). It is now a normal
## entry in `obstacles` (see apply_lane_layout), so it is drawn by the obstacle
## loop in _draw() and collides like any other blocker — no dedicated draw
## call, and no chance of the art and the collider disagreeing.
##
## Blocking the lair is safe because the villain stands in FRONT of it
## (VILLAIN_LAIR_OFFSET): the party still has a clear approach to him, they
## just can't walk through his ship to get there.
## Which lair art this level uses. Each villain gets his own structure
## (Designer, 2026-07-25): the crashed ship reads as Dark Mage's, the Berserker
## dens up in a beast lair. A level with no entry falls back to the wreck.
const LAIR_KIND_BY_LEVEL := {
	1: "spaceship",
	2: "berserk_lair",
}

func _lair_kind() -> String:
	return LAIR_KIND_BY_LEVEL.get(RunState.current_level, "spaceship")

func _draw_lair() -> void:
	# Only the no-texture fallback is left — without it a missing @export would
	# leave the lair's blocker invisible, since the obstacle loop draws nothing
	# for a kind whose texture is null.
	if _obstacle_texture(_lair_kind()) == null:
		# The lair is the villain's, so it wears the enemy pigment.
		draw_arc(lair_pos, LAIR_RADIUS, 0.0, TAU, 28, Color(UIStyle.VIOLET, 0.9), 4.0, true)

## Border decor is no longer drawn here — see get_top_band()/get_left_band()/
## get_right_band()/get_bottom_band()/get_scatter()/get_border_decor_entries()
## and LaneForeground, which draws all of it above FogOfWar.

## Obstacle kinds that are TALL — art whose height is its character (a tree
## reads wrong squashed into a circle the width of its own trunk). These draw
## standing on the ground, like the border band's props; everything else
## (rocks, wrecks, a sword stuck in the dirt) is squat and draws centred on
## its collision circle. See _draw_obstacle_prop.
const TALL_OBSTACLE_KINDS := ["tree_bushy", "alien_tree", "alien_tree_thin"]
## Height of a tall obstacle as a multiple of its collision radius. The trunk
## sits at the bottom of the collision circle, so the canopy overhangs — which
## is what you want: units path around the trunk, not the leaves.
const TALL_OBSTACLE_HEIGHT_MULT := 3.2

## Per-kind ART size multiplier. This scales the DRAWN sprite only — the
## collision circle stays exactly `radius`, so tuning how big something looks
## can never re-open a path the lane-walkability check already cleared.
## A sword stuck in the dirt is a slim thing and read oversized when drawn at
## the full width of its blocking circle (Designer, 2026-07-25).
## Padding compensation for the 2026-07-25 *_Color art batch.
##
## The colored art ships on a uniform 936x601 canvas, so the drawing occupies
## far less of its texture than the originals did (e.g. Rock-2 filled 92% of
## its old canvas, 36% of the new one). Both draw helpers size off the RAW
## texture — _draw_obstacle_sprite fits the longest edge, _draw_prop_sprite
## fits the height — so a 1:1 swap would have shrunk every prop by a different
## amount. These multipliers restore the on-screen size each prop had before
## the swap; they are measured (old opaque fraction / new opaque fraction), not
## eyeballed.
##
## "long" is for center-anchored sprites (_draw_obstacle_sprite), "height" for
## base-anchored props (_draw_prop_sprite). A texture only needs the entries
## for the paths it actually draws through; missing = 1.0 = no change. Trees
## are absent on purpose: their art fills the new canvas vertically, so the
## height-fit path already renders them unchanged.
const ART_PAD_COMPENSATION := {
	"res://assets/sprites/Rock-1_Color.png": {"long": 2.45, "height": 1.94},
	"res://assets/sprites/Rock-2_Color.png": {"long": 2.59, "height": 1.67},
	"res://assets/sprites/Sword_Ground_Color.png": {"long": 1.88, "height": 1.21},
	"res://assets/sprites/Destroyed-Spaceship_Color.png": {"long": 1.56},
	"res://assets/sprites/Berserk_Lair_Color.png": {"long": 1.38},
	"res://assets/sprites/Spike_Hazard_Color.png": {"long": 2.09},
	"res://assets/sprites/Mushroom_Color.png": {"long": 1.70, "height": 1.12},
	# Berserk_Level_Borders_Color1 (the Designer's re-proportioned second pass,
	# 2026-07-25): 2176x612 with the stands filling 76% of the height, against
	# the original's 97%. The first _Color attempt sat at 34% and was left
	# unwired for exactly that reason.
	"res://assets/sprites/Berserk_Level_Borders_Color1.png": {"height": 1.27},
	"res://assets/sprites/Plant_Color.png": {"long": 2.01, "height": 1.29},
}

## Compensation for a center-anchored (longest-edge) draw of `tex`.
static func art_pad_long(tex: Texture2D) -> float:
	if tex == null:
		return 1.0
	return float(ART_PAD_COMPENSATION.get(tex.resource_path, {}).get("long", 1.0))

## Compensation for a base-anchored (height-fit) draw of `tex`.
static func art_pad_height(tex: Texture2D) -> float:
	if tex == null:
		return 1.0
	return float(ART_PAD_COMPENSATION.get(tex.resource_path, {}).get("height", 1.0))

const OBSTACLE_ART_SCALE := {
	"sword": 0.72,
}

## Ground footprint of a TALL prop as a fraction of its collision radius.
## A tree is NOT wrapped by its drawn art: the canopy is meant to overhang so
## units path around the trunk (see TALL_OBSTACLE_HEIGHT_MULT above). So tall
## kinds get a shadow-shaped oval on the floor — narrow across, flatter still
## in depth — rather than an oval covering the leaves.
const TALL_FOOTPRINT := Vector2(0.62, 0.42)

## Rebuilds obstacle_radii from obstacle_kinds. Called after any edit to
## `obstacles`/`obstacle_kinds` — the three arrays are index-aligned and every
## collision path now reads the radii, so letting them drift would silently
## restore circle collision for the mismatched tail.
func _rebuild_obstacle_radii() -> void:
	obstacle_radii.clear()
	for i in obstacles.size():
		var kind := obstacle_kinds[i] if i < obstacle_kinds.size() else ""
		obstacle_radii.append(_footprint_for(kind, obstacles[i].z))

## Oval semi-axes for one obstacle, mirroring how its kind is DRAWN so
## collision and art agree (Designer, 2026-07-25).
func _footprint_for(kind: String, radius: float) -> Vector2:
	if kind in TALL_OBSTACLE_KINDS:
		return Vector2(radius, radius) * TALL_FOOTPRINT
	var tex := _obstacle_texture(kind)
	if tex == null:
		# No art: the drawn tell is _draw_blob's own squashed shape, so match it.
		return Vector2(radius, radius * 0.6)
	# Squat kinds draw centred with their longest edge spanning the diameter.
	# The same padding compensation _draw_obstacle_sprite applies has to be fed
	# in here: radii_for scales off the texture's OPAQUE fraction, so without
	# it the colored art's padding would quietly shrink every squat obstacle's
	# collision oval away from the art it's supposed to mirror.
	return SpriteFootprint.radii_for(tex, radius * 2.0 * art_pad_long(tex))

## Draws one obstacle with the anchoring its KIND deserves (Designer,
## 2026-07-25: "proportionalize obstacles by what they are"). Collision is a
## circle at `center` with `radius` either way — only the art changes.
func _draw_obstacle_prop(kind: String, center: Vector2, radius: float, tex: Texture2D) -> void:
	var art_radius: float = radius * float(OBSTACLE_ART_SCALE.get(kind, 1.0))
	if kind in TALL_OBSTACLE_KINDS:
		var height := art_radius * TALL_OBSTACLE_HEIGHT_MULT
		var tex_size := tex.get_size()
		if tex_size.y <= 0.0:
			return
		var draw_size := Vector2(tex_size.x * (height / tex_size.y), height)
		# Base at the BOTTOM of the collision circle so the trunk meets the
		# ground where the blocker actually is.
		var base := center + Vector2(0.0, radius)
		draw_texture_rect(tex, Rect2(base - Vector2(draw_size.x * 0.5, draw_size.y),
				draw_size), false)
	else:
		_draw_obstacle_sprite(center, art_radius, tex)

func _obstacle_texture(kind: String) -> Texture2D:
	match kind:
		"spaceship":
			return spaceship_texture
		"berserk_lair":
			return berserk_lair_texture
		"rock1":
			return rock1_texture
		"rock2":
			return rock2_texture
		"boulder":
			return boulder_texture
		# Trees are legitimate in-lane blockers, not just border dressing —
		# they reuse the border band's textures (Designer, 2026-07-25: more
		# variety in what an obstacle can be).
		"tree_bushy":
			return tree_bushy_texture
		"alien_tree":
			return alien_tree_texture
		"alien_tree_thin":
			return alien_tree_thin_texture
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
		"paw_print":
			return paw_print_texture
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
	# Padding compensation keeps the *drawing* spanning the diameter, rather
	# than the drawing plus the colored art's transparent margin.
	var diameter := radius * 2.0 * art_pad_long(tex)
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

## The only in-world text left (Designer, 2026-07-25): the DEPLOY band and the
## TOP/BOTTOM LANE markers. Those name ZONES, not entities — every hero,
## villain, minion and prop label is gone — and they're what makes the lane
## split legible, so they stayed. Handwritten font like the rest of the UI.
const LABEL_SIZE := 22

func _draw_label(at: Vector2, text: String) -> void:
	var font: Font = UIStyle.font() if UIStyle.font() != null else ThemeDB.fallback_font
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	draw_string(font, at + Vector2(-tw * 0.5, 5.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color(outline_color, 0.7))
