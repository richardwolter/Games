class_name Loadout
extends Node

## Owns the item list and is the ONLY place stats get resolved.
## Nothing else in the game is allowed to read the item list -- weapons and the
## player read the resolved blocks and nothing more. That is what keeps a new
## item from needing a new code path anywhere.

signal resolved(ranged: AttackStats, melee: AttackStats, player: PlayerStats)

@export var base_ranged: AttackStats
@export var base_melee: AttackStats
@export var base_player: PlayerStats

var items: Array[Item] = []

var ranged: AttackStats
var melee: AttackStats
var player: PlayerStats


func _ready() -> void:
	if base_ranged == null:
		base_ranged = AttackStats.new()
	if base_melee == null:
		base_melee = AttackStats.new()
	if base_player == null:
		base_player = PlayerStats.new()
	resolve()


func add_item(item: Item) -> void:
	items.append(item)
	resolve()


## Full recompute from base every time. Incremental application is the bug
## factory here -- removing an item or reordering would need an inverse for
## every Op, and MULTIPLY/BLEND do not have clean ones.
func resolve() -> void:
	var all: Array[StatModifier] = []
	for it in items:
		all.append_array(it.modifiers)

	ranged = StatModifier.apply_all(base_ranged, _filter(all, StatModifier.Target.RANGED)) as AttackStats
	melee = StatModifier.apply_all(base_melee, _filter(all, StatModifier.Target.MELEE)) as AttackStats
	player = StatModifier.apply_all(base_player, _filter(all, StatModifier.Target.PLAYER)) as PlayerStats

	resolved.emit(ranged, melee, player)


func _filter(all: Array[StatModifier], t: StatModifier.Target) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	for m in all:
		if m.applies_to(t):
			out.append(m)
	return out


## Debug readout -- this is the fastest way to tell whether a build "reads".
func describe() -> String:
	var names: PackedStringArray = []
	for it in items:
		names.append(it.display_name)
	return "items: %s\ndmg %.1f  rate %.2f/s  shots %d  pierce %d  scatter %.0f\ninjects %s\nmelee %.1f  reach %.0f  %s\nsize %.2f  speed %.0f  hp %d  arms %d" % [
		", ".join(names) if names.size() > 0 else "(none)",
		ranged.damage, ranged.attack_rate, ranged.shot_count, ranged.pierce_count,
		ranged.spread_random,
		ranged.statuses if not ranged.statuses.is_empty() else "-",
		melee.damage, melee.reach,
		"thrown x%d" % melee.boomerang_count if melee.boomerang_count > 0 else "held",
		player.size_scale, player.move_speed, player.max_health,
		2 + player.extra_arms,
	]
