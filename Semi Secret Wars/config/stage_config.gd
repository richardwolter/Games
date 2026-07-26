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

## Battle music for this stage, overriding battlefield.tscn's BattleMusic
## stream (Designer, 2026-07-25: level 1 shares the start menu's song, so the
## opening of a run carries one continuous theme from title through the first
## fight). null = keep whatever the scene authored, which is what stages 2+ do.
## Applied in BattleManager._apply_stage_config, which runs before the deferred
## _start_music — see the comment there.
@export var music: AudioStream = null

## Multipliers applied to every swarm minion this stage spawns, on top of the
## unit scene's authored stats (LaneSpawner._spawn_one -> Combatant.stat_*_mult).
## Stage-level rather than per-scene because ranged_minion.tscn is shared
## between stages 2 and 3.
@export var minion_hp_mult: float = 1.0
@export var minion_damage_mult: float = 1.0

## Multiplier on each spawn gate's authored HP (the z of a LevelLayout
## spawn_points entry), applied in LaneSpawner._spawn_spawn_points.
@export var spawn_point_hp_mult: float = 1.0

## Multiplier applied to the villain's authored max_hp (e.g. dark_mage.tscn)
## at spawn, without editing the shared scene (see BattleManager._spawn_villain).
@export var villain_hp_mult: float = 1.0
