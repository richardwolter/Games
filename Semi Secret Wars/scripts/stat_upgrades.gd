class_name StatUpgrades
extends RefCounted
## Permanent, repeatable per-hero stat upgrades bought with banked XP (V2 grind
## progression) — the "raw stats" track, separate from AbilityMods/AbilityTiers
## (which both spend gold). Unlike those catalogs (bought once), each of these
## can be bought repeatedly per hero; cost rises with how many times that hero
## has already bought it — see GameState.stat_purchase_count/buy_stat_upgrade.
##
## First-pass values — flag for tuning in BALANCE.md.

const STATS := {
	"hp": {
		"label": "Max HP", "base_cost": 20, "cost_growth": 1.15,
		"effect_per_purchase": 0.08,
	},
	"damage": {
		"label": "Damage", "base_cost": 25, "cost_growth": 1.15,
		"effect_per_purchase": 0.08,
	},
	"attack_speed": {
		"label": "Attack Speed", "base_cost": 30, "cost_growth": 1.15,
		"effect_per_purchase": 0.05,
	},
}

## All stat ids, in catalog order.
static func ids() -> Array:
	return STATS.keys()

## Definition dict for a stat id, or {} if unknown.
static func def(id: String) -> Dictionary:
	return STATS.get(id, {})

## Cost of the NEXT purchase, given how many times this stat has already been
## bought for one hero — rises geometrically so the sink stays meaningful.
static func cost_for(id: String, purchases: int) -> int:
	var d := def(id)
	if d.is_empty():
		return 0
	return int(round(float(d.get("base_cost", 0)) * pow(float(d.get("cost_growth", 1.0)), purchases)))
