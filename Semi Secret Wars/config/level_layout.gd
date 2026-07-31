class_name LevelLayout
extends Resource
## Authored, fixed geometry for one level: a narrow horizontal lane.
##
## Heroes deploy from a fixed band at the LEFT end and push RIGHT toward the
## villain's lair. Minion spawn points are distributed ALONG the lane and are
## destructible — killing one permanently stops its waves.
##
## Coordinates are CENTERED ON THE ORIGIN (x in [-lane_length/2, +lane_length/2],
## y in [-lane_half_height, +lane_half_height]) so the reused fog-of-war and the
## page/backdrop draw — both of which assume a field centered at (0,0) — cover
## the lane without change. LaneField.apply_lane_layout() copies these in.

@export var level_id: String = "lane_1"

## Lane dimensions. A wide, short rectangle — the whole point of the lane structure.
@export var lane_length: float = 6000.0
@export var lane_half_height: float = 450.0

## Fixed deploy band at the lane's left end (x range; full height). Heroes may
## only be (re)deployed inside this band — it never advances (Designer call).
@export var deploy_band_x_min: float = -2900.0
@export var deploy_band_x_max: float = -2300.0

## Fixed villain lair near the far end of the lane — the learnable destination,
## and the last thing standing once every spawn point on the way is destroyed.
##
## Moved IN from x2700 to x2250 on all three levels (Designer, 2026-07-30: "I
## cant see berserk lair at all, bring it closer to the end of lane division").
## It was never off-screen by camera limits — the camera can pan past it — but
## nothing ever took the player there: the villain walks out to meet the party
## (villain_pos is his LIVE position and drives lane_merge_x), so the fight
## resolves short of his lair, the level ends on his death, and the fog over the
## far end never lifts. Pulling the lair toward where the fight actually happens
## puts it inside the revealed area.
##
## Note this also moves the villain's START, since LaneField seeds villain_pos at
## lair_pos - VILLAIN_LAIR_OFFSET: the approach is ~450px shorter than it was.
@export var villain_lair: Vector2 = Vector2(2900.0, 0.0)

## Destructible minion spawn points: (x, y) center + z = HP. Each becomes a
## LaneSpawnPoint the heroes can destroy to permanently stop its waves.
@export var spawn_points: Array[Vector3] = []
## Lane each spawn point above belongs to ("top"/"bottom"), index-aligned with
## spawn_points — lets a level deliberately differ top vs bottom (minion mix,
## pacing) while total difficulty stays designer-balanced across both. Falls
## back to sign-of-y if an index is missing/empty (see LaneField.lane_of).
@export var spawn_point_lanes: Array[String] = []

## Blocking obstacles: (x, y) center + z = radius. Index-aligned with obstacle_kinds.
@export var obstacles: Array[Vector3] = []
## Sprite kind per obstacle (e.g. "rock1"/"rock2"/"sword"); "" falls back to blob+label.
@export var obstacle_kinds: Array[String] = []
## Poison Lakes: (x, y) center + z = x-radius (y-radius = z * lake_radius_ratio).
@export var lakes: Array[Vector3] = []
## Spike pits (Designer, 2026-07-25): (x, y) center + z = radius. Circular
## entry-hazards — same one-hit-per-entry rule as a lake (see
## Combatant._physics_process), just rounder, smaller and nastier, and they
## carry real art instead of a hatched blob. NOT blockers: a unit can walk
## through one and pay for it, which is the point.
@export var spike_pits: Array[Vector3] = []
## Decorative props: (x, y) center + z = radius. No gameplay effect.
@export var scenery: Array[Vector3] = []
## Sprite kind per scenery entry above (index-aligned): e.g. "smudge".
@export var scenery_kinds: Array[String] = []
## Objective points (index-aligned with CaptureObjective.objective_index).
## Authored sparsely for now — whether hold-to-capture suits a lane is TBD.
## (The HUD hides its objective panel on levels that author none.)
@export var objective_positions: Array[Vector2] = []
## Lane each objective above belongs to ("top"/"bottom"/"" = both lanes may
## capture it), index-aligned with objective_positions.
@export var objective_lanes: Array[String] = []

## Hand-placed EXTRAS dressing OUTSIDE the lane rect, layered on top of
## LaneField's procedural tree band (LaneField._build_border_band()) — the
## continuous border itself is generated at load, not authored here. Use this
## only for a deliberate one-off prop. No gameplay effect, not steered around,
## not clamped against. (x, y) center + z = radius. Index-aligned with
## border_decor_kinds.
@export var border_decor: Array[Vector3] = []
## Sprite kind per border_decor entry above: "tree_bushy", "alien_tree",
## "alien_tree_thin", or "plant".
@export var border_decor_kinds: Array[String] = []
