class_name PositionCompatibility
extends RefCounted

## Stat multiplier per detailed position -> formation slot category.
## See BALANCE.md "Position Compatibility" table. Missing entries = 0.0 (ineligible).
const MULTIPLIERS := {
	Player.Position.GK: {
		Formation.SlotCategory.GK: 1.0,
	},
	Player.Position.CB: {
		Formation.SlotCategory.DEF: 1.0,
		Formation.SlotCategory.MID: 0.8,
		Formation.SlotCategory.FWD: 0.5,
	},
	Player.Position.FB: {
		Formation.SlotCategory.DEF: 1.0,
		Formation.SlotCategory.MID: 0.9,
		Formation.SlotCategory.FWD: 0.4,
	},
	Player.Position.DM: {
		Formation.SlotCategory.DEF: 0.8,
		Formation.SlotCategory.MID: 1.0,
		Formation.SlotCategory.FWD: 0.6,
	},
	Player.Position.CM: {
		Formation.SlotCategory.DEF: 0.5,
		Formation.SlotCategory.MID: 1.0,
		Formation.SlotCategory.FWD: 0.85,
	},
	Player.Position.CAM: {
		Formation.SlotCategory.DEF: 0.3,
		Formation.SlotCategory.MID: 1.0,
		Formation.SlotCategory.FWD: 0.95,
	},
	Player.Position.WING: {
		Formation.SlotCategory.DEF: 0.2,
		Formation.SlotCategory.MID: 0.95,
		Formation.SlotCategory.FWD: 1.0,
	},
	Player.Position.ST: {
		Formation.SlotCategory.DEF: 0.1,
		Formation.SlotCategory.MID: 0.7,
		Formation.SlotCategory.FWD: 1.0,
	},
}

static func get_multiplier(position: Player.Position, slot: Formation.SlotCategory) -> float:
	return MULTIPLIERS.get(position, {}).get(slot, 0.0)

## Best multiplier across all of the player's natural positions (primary + secondary).
static func get_best_multiplier(player: Player, slot: Formation.SlotCategory) -> float:
	var best: float = 0.0
	for position in player.positions:
		best = max(best, get_multiplier(position, slot))
	return best

static func is_eligible(player: Player, slot: Formation.SlotCategory) -> bool:
	return get_best_multiplier(player, slot) > 0.0

## Broad category (GK/DEF/MID/FWD) the player is best suited to, used to group
## bench listings. Falls back to DEF if a player somehow has no positions.
static func get_natural_category(player: Player) -> Formation.SlotCategory:
	var best_category: Formation.SlotCategory = Formation.SlotCategory.DEF
	var best_value: float = -1.0
	for category in [Formation.SlotCategory.GK, Formation.SlotCategory.DEF, Formation.SlotCategory.MID, Formation.SlotCategory.FWD]:
		var value: float = get_best_multiplier(player, category)
		if value > best_value:
			best_value = value
			best_category = category
	return best_category

static func get_effective_stats(player: Player, slot: Formation.SlotCategory) -> Dictionary:
	var multiplier: float = get_best_multiplier(player, slot)
	return {
		"speed": player.speed * multiplier,
		"strength": player.strength * multiplier,
		"kick": player.kick * multiplier,
		"passing": player.passing * multiplier,
		"stamina": player.stamina * multiplier,
	}
