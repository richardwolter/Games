class_name AbilityMods
extends RefCounted
## Permanent per-hero ability tradeoff nodes (gameplay-loop rework "gold shop").
##
## Unlike run-scoped boons (Boons/RunState, reset every run), these are bought
## once with GOLD at the prep screen and owned FOREVER (GameState.owned_mods).
## Each was originally designed with a real DOWNSIDE next to its upside; the
## downsides are switched off for now (Designer, 2026-07-18: "remove negative
## effects from ability upgrades for now") while Level 1 tightening is the
## focus — see Hero._apply_ability_mod, where each downside line is commented
## out rather than deleted so the tradeoff design can come back later. Data
## (name/cost/desc/hero) lives here; the actual stat/ability effect lives in
## Hero._apply_ability_mod (matched by id) — same split as Boons vs.
## Hero.apply_run_boon.
##
## First-pass values — flag for tuning in BALANCE.md.

const CATALOG := {
	# THUNDAAR (TANK) --------------------------------------------------------
	"seismic_stomp": {
		"hero": "THUNDAAR", "name": "Seismic Stomp", "cost": 45,
		"desc": "Stomp radius +60%",
	},
	"iron_skin": {
		"hero": "THUNDAAR", "name": "Iron Skin", "cost": 50,
		"desc": "+25% Max HP",
	},
	# ARTEMIS (BURST) --------------------------------------------------------
	"twin_clone": {
		"hero": "ARTEMIS", "name": "Twin Clone", "cost": 60,
		"desc": "Clone spawns 2 copies",
	},
	"glass_arrows": {
		"hero": "ARTEMIS", "name": "Glass Arrows", "cost": 45,
		"desc": "+30% Damage",
	},
	# WARDEN (CONTROL) -------------------------------------------------------
	"wide_snare": {
		"hero": "WARDEN", "name": "Wide Snare", "cost": 50,
		"desc": "Ensnare radius +50%",
	},
	"overcharge": {
		"hero": "WARDEN", "name": "Overcharge", "cost": 45,
		"desc": "+25% Attack speed",
	},
	# BEACON (SUPPORT) -------------------------------------------------------
	"mass_rally": {
		"hero": "BEACON", "name": "Mass Rally", "cost": 55,
		"desc": "Rally radius +50%",
	},
	"zealot": {
		"hero": "BEACON", "name": "Zealot", "cost": 45,
		"desc": "+40% Damage",
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
