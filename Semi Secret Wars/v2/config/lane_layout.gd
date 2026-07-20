class_name LaneLayout
extends Resource
## Authored, fixed geometry for one V2 LANE level (parallel testing build).
##
## V2's structural thesis: the battlefield is a narrow horizontal lane instead of
## V1's wide open ellipse (see config/level_layout.gd for the V1 equivalent).
## Heroes deploy from a fixed band at the LEFT end and push RIGHT toward the
## villain's lair. Minion spawn points are distributed ALONG the lane and are
## destructible — killing one permanently stops its waves.
##
## Coordinates are CENTERED ON THE ORIGIN (x in [-lane_length/2, +lane_length/2],
## y in [-lane_half_height, +lane_half_height]) so the reused fog-of-war and the
## page/backdrop draw — both of which assume a field centered at (0,0) — cover
## the lane without change. LaneField.apply_lane_layout() copies these in.

@export var level_id: String = "lane_1"

## Lane dimensions. A wide, short rectangle — the whole point of V2.
@export var lane_length: float = 6000.0
@export var lane_half_height: float = 450.0

## Fixed deploy band at the lane's left end (x range; full height). Heroes may
## only be (re)deployed inside this band — it never advances (Designer call).
@export var deploy_band_x_min: float = -2900.0
@export var deploy_band_x_max: float = -2300.0

## Fixed villain lair at the very end of the lane (near lane_length/2) — the
## learnable destination, and the last thing standing once every spawn point
## on the way is destroyed.
@export var villain_lair: Vector2 = Vector2(2900.0, 0.0)

## Destructible minion spawn points: (x, y) center + z = HP. Each becomes a
## LaneSpawnPoint the heroes can destroy to permanently stop its waves.
@export var spawn_points: Array[Vector3] = []

## Blocking obstacles: (x, y) center + z = radius. Index-aligned with obstacle_kinds.
@export var obstacles: Array[Vector3] = []
## Sprite kind per obstacle ("mountain"/"forest"); "" falls back to blob+label.
@export var obstacle_kinds: Array[String] = []
## Poison Lakes: (x, y) center + z = x-radius (y-radius = z * lake_radius_ratio).
@export var lakes: Array[Vector3] = []
## Decorative props: (x, y) center + z = radius. No gameplay effect.
@export var scenery: Array[Vector3] = []
## Sprite kind per scenery entry above (index-aligned): e.g. "smudge".
@export var scenery_kinds: Array[String] = []
## Objective points (index-aligned with CaptureObjective.objective_index).
## Authored sparsely in V2 — whether hold-to-capture suits a lane is TBD.
@export var objective_positions: Array[Vector2] = []

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
