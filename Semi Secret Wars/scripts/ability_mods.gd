class_name AbilityMods
extends RefCounted
## Permanent per-hero ability tradeoff nodes (gameplay-loop rework "gold shop").
##
## Unlike run-scoped boons (Boons/RunState, reset every run), these are bought
## once with GOLD at the prep screen and owned FOREVER (GameState.owned_mods).
## Each carries a real DOWNSIDE next to its upside — the growing, quirky,
## permanently-owned kit the Designer asked for. Data (name/cost/desc/hero)
## lives here; the actual stat/ability effect lives in Hero._apply_ability_mod
## (matched by id), where the tunable fields are — same split as Boons vs.
## Hero.apply_run_boon.
##
## First-pass values — flag for tuning in BALANCE.md.

const CATALOG := {
	# THUNDAAR (TANK) --------------------------------------------------------
	"seismic_stomp": {
		"hero": "THUNDAAR", "name": "Seismic Stomp", "cost": 45,
		"desc": "Stomp radius +60%\nbut cooldown +1.5s",
	},
	"iron_skin": {
		"hero": "THUNDAAR", "name": "Iron Skin", "cost": 50,
		"desc": "+25% Max HP\nbut -15% Move speed",
	},
	# ARTEMIS (BURST) --------------------------------------------------------
	"twin_clone": {
		"hero": "ARTEMIS", "name": "Twin Clone", "cost": 60,
		"desc": "Clone spawns 2 copies\nbut each at 60% HP",
	},
	"glass_arrows": {
		"hero": "ARTEMIS", "name": "Glass Arrows", "cost": 45,
		"desc": "+30% Damage\nbut -20% Max HP",
	},
	# WARDEN (CONTROL) -------------------------------------------------------
	"wide_snare": {
		"hero": "WARDEN", "name": "Wide Snare", "cost": 50,
		"desc": "Ensnare radius +50%\nbut stun -30%",
	},
	"overcharge": {
		"hero": "WARDEN", "name": "Overcharge", "cost": 45,
		"desc": "+25% Attack speed\nbut -15% Move speed",
	},
	# BEACON (SUPPORT) -------------------------------------------------------
	"mass_rally": {
		"hero": "BEACON", "name": "Mass Rally", "cost": 55,
		"desc": "Rally radius +50%\nbut cooldown +2s",
	},
	"zealot": {
		"hero": "BEACON", "name": "Zealot", "cost": 45,
		"desc": "+40% Damage\nbut -25% Max HP",
	},
}

## All mod ids.
static func ids() -> Array:
	return CATALOG.keys()

## Definition dict for a mod id, or {} if unknown.
static func def(id: String) -> Dictionary:
	return CATALOG.get(id, {})

## Mod ids belonging to a given hero, in catalog order.
static func for_hero(hero_name: String) -> Array:
	return CATALOG.keys().filter(func(id: String) -> bool:
		return CATALOG[id].get("hero", "") == hero_name)
