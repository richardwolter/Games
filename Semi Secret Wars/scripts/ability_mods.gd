class_name AbilityMods
extends RefCounted
## Permanent per-hero SIGNATURE-ABILITY upgrades, bought with gold at the prep
## screen and owned FOREVER (GameState.owned_mods).
##
## Scope rework (Designer, 2026-07-25): this catalog used to be half raw stats
## — Iron Skin (+30 HP), Glass Arrows (+2 damage), Overcharge (-0.15s attack
## interval) and Zealot (+3 damage). Those are exactly what the XP-funded
## STATS page sells (StatUpgrades: hp / damage / attack_speed), so the shop
## called "ABILITIES" was half a duplicate of the other shop. They are gone.
## Every entry here now touches the hero's signature ability (Stomp / Clone /
## Ensnare / Rally) and nothing else. The three money sinks are now cleanly
## separated:
##     STATS page  (banked XP) -> raw stats
##     ABILITIES   (gold)      -> this file + AbilityTiers + DuoUltimateMods
##     level start (free pick) -> DuoUltimateBoons
##
## Two per hero: a geometry/count upgrade and a cooldown reduction. The
## cooldown half replaces the deleted per-hero run boons, whose only
## non-duplicate effect was "ability cooldown -1.0s" — see the class doc on
## duo_ultimate_boons.gd for why those were dropped.
##
## Each mod was originally designed with a real DOWNSIDE next to its upside;
## the downsides are switched off for now (Designer, 2026-07-18: "remove
## negative effects from ability upgrades for now") — see
## Hero._apply_ability_mod, where each downside line is commented out rather
## than deleted so the tradeoff design can come back later. Data
## (name/cost/desc/hero) lives here; the actual effect lives in
## Hero._apply_ability_mod, matched by id.
##
## Descriptions are flat additive numbers, not percentages (Designer,
## 2026-07-21: "avoid using % for upgrades and abilities, use added numbers
## for better understanding") — they must match the applied values in
## hero.gd's _apply_ability_mod.
##
## First-pass values — flag for tuning in BALANCE.md.

const CATALOG := {
	# THUNDAAR (TANK — Stomp) ------------------------------------------------
	"seismic_stomp": {
		"hero": "THUNDAAR", "name": "Seismic Stomp", "cost": 45,
		"desc": "Stomp radius +45",
	},
	"rolling_quake": {
		"hero": "THUNDAAR", "name": "Rolling Quake", "cost": 50,
		"desc": "Stomp cooldown -1.0s",
	},
	# ARTEMIS (BURST — Clone) ------------------------------------------------
	"twin_clone": {
		"hero": "ARTEMIS", "name": "Twin Clone", "cost": 60,
		"desc": "Clone count +1",
	},
	"fleetfoot": {
		"hero": "ARTEMIS", "name": "Fleetfoot", "cost": 50,
		"desc": "Clone cooldown -1.0s",
	},
	# WARDEN (CONTROL — Ensnare) ---------------------------------------------
	"wide_snare": {
		"hero": "WARDEN", "name": "Wide Snare", "cost": 50,
		"desc": "Ensnare radius +50",
	},
	"rapid_snare": {
		"hero": "WARDEN", "name": "Rapid Snare", "cost": 50,
		"desc": "Ensnare cooldown -1.0s",
	},
	# BEACON (SUPPORT — Rally) -----------------------------------------------
	"mass_rally": {
		"hero": "BEACON", "name": "Mass Rally", "cost": 55,
		"desc": "Rally radius +90",
	},
	"quick_rally": {
		"hero": "BEACON", "name": "Quick Rally", "cost": 50,
		"desc": "Rally cooldown -1.0s",
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
