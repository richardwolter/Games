class_name StageConfig
extends Resource
## Configuration for a stage: villain type, minion types, swarm escalation, field preset.
##
## Each stage (Stage 1: Dark Mage, Stage 2: Berserker, etc.) is a StageConfig instance.
## MinionSpawner and BattleManager read these at runtime to tune difficulty and spawn
## the correct villain/minion types.

@export var stage_id: String = "stage_1"
@export var stage_name: String = "Stage 1"

## Villain: either "dark_mage" or "berserker" (or future types).
@export var villain_type: String = "dark_mage"

## Minion type: "minion" or "elite_minion" (or future variants).
@export var minion_type: String = "minion"

## Swarm escalation config.
@export var swarm_cap_start: int = 6
@export var escalate_every: float = 12.0
@export var escalate_step: int = 1
@export var swarm_max_cap: int = 24
@export var minion_speed: float = 90.0
@export var spawn_interval: float = 0.5
## Minions spawned per spawn tick — bursts keep big swarms topped up.
@export var spawn_batch: int = 1

## For future: field preset (stage-specific obstacles, layouts, etc.).
@export var field_preset: String = "default"

## Multiplier applied to the villain's authored max_hp (villain.tscn) at spawn.
## Additive field (default 1.0 = untouched) — V1 stage configs never set this,
## so V1 behavior is unaffected. Used by V2's stage configs to raise villain HP
## without editing the shared villain.tscn (see BattleManager._spawn_villain).
@export var villain_hp_mult: float = 1.0
