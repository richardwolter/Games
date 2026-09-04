@tool
class_name AttackStats
extends Resource

## The single source of truth for what an attack IS -- melee swing or syringe shot.
## Combat numbers AND visual channels live together on purpose: items write to
## both, and one renderer reads both. An item never spawns its own visual; it
## writes a channel here.
##
## Both weapons share one class rather than two. Melee ignores the projectile
## channels (speed, pierce, homing...) and ranged ignores the melee ones (arc,
## reach). The dead fields are the price of letting one modifier pipeline,
## one HUD, and one debug printout serve both weapons.

# --- Shared combat channels ---
@export var damage: float = 3.0
@export var knockback: float = 60.0
@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 2.0
@export var attack_rate: float = 4.0   ## attacks per second

# --- Ranged-only channels ---
@export var speed: float = 420.0
@export var lifetime: float = 1.2
@export var pierce_count: int = 0
@export var homing_strength: float = 0.0   ## 0 = none, 1 = aggressive
@export var shot_count: int = 1
@export var spread_degrees: float = 0.0
## Random error added to every shot, in degrees, drawn fresh per projectile.
## Separate from `spread_degrees`, which is a fixed fan and therefore does
## nothing at all on a single-shot weapon -- an item that means "less accurate"
## has to have somewhere to write that is not the shotgun channel.
@export var spread_random: float = 0.0

# --- Melee-only channels ---
@export var arc_degrees: float = 100.0
@export var reach: float = 56.0
@export var swing_time: float = 0.12       ## how long the arc hitbox stays live
## 0 = the blade stays in his hand and the melee weapon is an arc query. Above 0
## it is thrown instead, this many blades at once, and the arc never runs. A
## channel rather than a bool so the item stacks into more blades.
@export var boomerang_count: int = 0

# --- Status payload (what the syringe injects) ---
## Keyed by status id -> potency. e.g. {"poison": 1.5}
@export var statuses: Dictionary = {}

# --- Visual channels (Isaac-style: items TINT and MODIFY, not replace) ---
@export var tint: Color = Color(0.55, 0.9, 1.0)
@export var scale_mult: float = 1.0
@export var trail_enabled: bool = false
@export var trail_length: int = 0
@export var wobble_amplitude: float = 0.0
@export var wobble_frequency: float = 0.0
@export var glow_energy: float = 0.0
@export var sprite_override: Texture2D = null       ## rare, top-priority items only
@export var impact_effects: Array[PackedScene] = [] ## additive, dedup on apply
@export var shader_flags: Array[StringName] = []    ## e.g. &"dissolve", &"chromatic"


func duplicate_stats() -> AttackStats:
	# duplicate(true) so Dictionary/Array channels are not shared by reference.
	# Without deep copy, one item's poison bleeds into the base weapon resource
	# on disk and survives into the next run.
	return duplicate(true) as AttackStats
