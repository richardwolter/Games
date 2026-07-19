class_name LevelLayout
extends Resource
## Authored, fixed geometry for one level of a run (gameplay-loop rework).
##
## Replaces StageField's per-battle randomization: a level is now the SAME field
## every time it's played, so it becomes familiar and the persistent fog of war
## (progress-is-knowledge) has a stable map to reveal. StageField.apply_layout()
## copies these into its live geometry fields before objectives/guardians/villain
## read them.
##
## Villain LAIR and minion GATES are authored here too (consumed in Phase 3):
## the villain sits dormant at its lair until a hero closes in, and every swarm
## wave pours from these known edge gates instead of random points.

@export var level_id: String = "level_1"

## Where the deploy zone anchors (the old StageField.hero_spawn default).
@export var deploy_anchor: Vector2 = Vector2(-1500.0, -600.0)
## Fixed villain lair — never rerolled. The learnable destination.
@export var villain_lair: Vector2 = Vector2(1420.0, 640.0)

## Blocking obstacles: (x, y) center + z = radius. Index-aligned with obstacle_kinds.
@export var obstacles: Array[Vector3] = []
## Sprite kind per obstacle ("mountain"/"forest"); "" falls back to blob+label.
@export var obstacle_kinds: Array[String] = []
## Poison Lakes: (x, y) center + z = x-radius (y-radius = z * lake_radius_ratio).
@export var lakes: Array[Vector3] = []
## Decorative props: (x, y) center + z = radius. No gameplay effect.
@export var scenery: Array[Vector3] = []
## Objective points (index-aligned with CaptureObjective.objective_index).
@export var objective_positions: Array[Vector2] = []
## Fixed minion spawn gates — swarm waves originate here (Phase 3).
@export var spawn_gates: Array[Vector2] = []
