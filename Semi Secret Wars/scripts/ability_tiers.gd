class_name AbilityTiers
extends RefCounted
## Permanent ability-tier unlocks bought with gold (V2 grind progression).
##
## Maps onto the three flags Hero._configure already reads (_base_unlocked,
## _passive_unlocked, _active_unlocked) — V1 sets all three unconditionally;
## V2 gates tiers 2-3 behind these purchases (tier 1, the signature ability,
## is free — see GameState.has_tier). Same owned-forever pattern as
## AbilityMods, but sequential: tier 3 requires tier 2 already owned.
##
## NOTE (flag for Designer calibration): WARDEN has no coded LV20 second
## ability (ABILITY_INFO["WARDEN"].name2 == "" in hero.gd) and neither Ensnare
## nor Rally read _passive_unlocked today — only THUNDAAR's Stomp-stun and
## ARTEMIS's Clone-damage-boost are wired to tier 2. WARDEN_2/WARDEN_3 and
## BEACON_3 are included here for shop/economy symmetry but currently buy no
## observable effect. Not fixed here — inventing the missing mechanic is out
## of scope (CLAUDE.md: never invent mechanics, mark unknowns TBD).
##
## First-pass costs — flag for tuning in BALANCE.md.

const CATALOG := {
	"THUNDAAR_2": {
		"hero": "THUNDAAR", "tier": 2, "name": "Aftershock", "cost": 40,
		"desc": "Stomp stuns enemies briefly",
	},
	"THUNDAAR_3": {
		"hero": "THUNDAAR", "tier": 3, "name": "Shockwave", "cost": 70,
		"desc": "Unlocks Shockwave (LV20 ultimate)",
	},
	"ARTEMIS_2": {
		"hero": "ARTEMIS", "tier": 2, "name": "Mirror Image", "cost": 40,
		"desc": "Clone deals +50% damage",
	},
	"ARTEMIS_3": {
		"hero": "ARTEMIS", "tier": 3, "name": "Multishot", "cost": 70,
		"desc": "Unlocks Multishot (LV20 ultimate)",
	},
	"WARDEN_2": {
		"hero": "WARDEN", "tier": 2, "name": "Binding", "cost": 40,
		"desc": "Passive upgrade (TBD)",
	},
	"WARDEN_3": {
		"hero": "WARDEN", "tier": 3, "name": "Overwhelm", "cost": 70,
		"desc": "Ultimate ability (TBD)",
	},
	"BEACON_2": {
		"hero": "BEACON", "tier": 2, "name": "Empower", "cost": 40,
		"desc": "Passive upgrade (TBD)",
	},
	"BEACON_3": {
		"hero": "BEACON", "tier": 3, "name": "Zeal", "cost": 70,
		"desc": "Unlocks Confuse (LV20 ultimate)",
	},
}

## All ability-tier ids.
static func ids() -> Array:
	return CATALOG.keys()

## Definition dict for a tier id, or {} if unknown.
static func def(id: String) -> Dictionary:
	return CATALOG.get(id, {})

## Tier ids belonging to a given hero, in tier order (2, then 3).
static func for_hero(hero_name: String) -> Array:
	return CATALOG.keys().filter(func(id: String) -> bool:
		return CATALOG[id].get("hero", "") == hero_name)

## True if `id`'s prerequisite (the previous tier) is owned. Tier 2's
## prerequisite is the always-free tier 1; tier 3 requires tier 2 owned.
static func prereq_met(id: String) -> bool:
	var d := def(id)
	if d.is_empty():
		return false
	var tier: int = d.get("tier", 2)
	if tier <= 2:
		return true
	var prev_id := "%s_%d" % [d.get("hero", ""), tier - 1]
	return prev_id in GameState.owned_ability_tiers
