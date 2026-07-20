class_name Boons
extends RefCounted
## Run-scoped boon catalog for the in-run level-up draft (Milestone 1).
##
## Boons are permanent for the CURRENT run only — they live in RunState (never
## saved) and are applied live to the hero that just levelled up (see
## Hero.apply_run_boon). This is the roguelite "pick 1 of 3 on level-up" layer;
## persistent progression is separate (GameState / future MetaState).
##
## First-pass values — flagged for tuning in BALANCE.md. Keep every boon a
## direct base-stat change so it composes with the existing synergy/formation
## multipliers without touching combat call sites.

const CATALOG := {
	"power": {
		"name": "Power", "desc": "+15% Damage",
		"kind": "damage_mult", "value": 1.15,
	},
	"vitality": {
		"name": "Vitality", "desc": "+15% Max HP",
		"kind": "max_hp_mult", "value": 1.15,
	},
	"haste": {
		"name": "Haste", "desc": "-10% Attack time",
		"kind": "atk_interval_mult", "value": 0.90,
	},
	"swiftness": {
		"name": "Swiftness", "desc": "+12% Move speed",
		"kind": "move_speed_mult", "value": 1.12,
	},
	"fortune": {
		"name": "Fortune", "desc": "+20% XP gained",
		"kind": "xp_mult", "value": 1.20,
	},
	"ferocity": {
		"name": "Ferocity", "desc": "+8% Dmg & atk speed",
		"kind": "ferocity", "dmg": 1.08, "atk": 0.92,
	},
	# Signature boons — one guaranteed slot per level-up is drawn from the
	# hero's own set (see RunState.roll_offer). Each carries a "hero" key
	# (absent = generic, above) and is named for that hero's own ability. New
	# kinds are handled in Hero.apply_run_boon, reusing the ability-mod scalars.
	# THUNDAAR (TANK — Stomp) ------------------------------------------------
	"seismic_focus": {
		"hero": "THUNDAAR", "name": "Seismic Focus", "desc": "+40% Stomp radius",
		"kind": "stomp_radius_mult", "value": 1.40,
	},
	"juggernaut": {
		"hero": "THUNDAAR", "name": "Juggernaut", "desc": "+25% Max HP",
		"kind": "max_hp_mult", "value": 1.25,
	},
	"aftershock": {
		"hero": "THUNDAAR", "name": "Aftershock", "desc": "-1.0s Ability cooldown",
		"kind": "ability_cooldown_reduction", "value": 1.0,
	},
	# ARTEMIS (BURST — Clone) ------------------------------------------------
	"twin_focus": {
		"hero": "ARTEMIS", "name": "Twin Focus", "desc": "Clone spawns +1 copy",
		"kind": "clone_count_add", "value": 1,
	},
	"deadeye": {
		"hero": "ARTEMIS", "name": "Deadeye", "desc": "+25% Damage",
		"kind": "damage_mult", "value": 1.25,
	},
	"fleetfoot": {
		"hero": "ARTEMIS", "name": "Fleetfoot", "desc": "-1.0s Ability cooldown",
		"kind": "ability_cooldown_reduction", "value": 1.0,
	},
	# WARDEN (CONTROL — Ensnare) ---------------------------------------------
	"wide_net": {
		"hero": "WARDEN", "name": "Wide Net", "desc": "+40% Ensnare radius",
		"kind": "ensnare_radius_mult", "value": 1.40,
	},
	"marksman": {
		"hero": "WARDEN", "name": "Marksman", "desc": "+20% Damage",
		"kind": "damage_mult", "value": 1.20,
	},
	"rapid_snare": {
		"hero": "WARDEN", "name": "Rapid Snare", "desc": "-1.0s Ability cooldown",
		"kind": "ability_cooldown_reduction", "value": 1.0,
	},
	# BEACON (SUPPORT — Rally) -----------------------------------------------
	"broad_rally": {
		"hero": "BEACON", "name": "Broad Rally", "desc": "+40% Rally radius",
		"kind": "rally_radius_mult", "value": 1.40,
	},
	"inspire": {
		"hero": "BEACON", "name": "Inspire", "desc": "+20% Damage",
		"kind": "damage_mult", "value": 1.20,
	},
	"quick_rally": {
		"hero": "BEACON", "name": "Quick Rally", "desc": "-1.0s Ability cooldown",
		"kind": "ability_cooldown_reduction", "value": 1.0,
	},
}

## All boon ids (a fresh Array each call — safe for the caller to shuffle).
static func ids() -> Array:
	return CATALOG.keys()

## The definition dict for a boon id, or {} if unknown.
static func def(id: String) -> Dictionary:
	return CATALOG.get(id, {})

## Generic (hero-agnostic) boon ids — the base pool every hero can draw.
static func generic_ids() -> Array:
	return CATALOG.keys().filter(func(id: String) -> bool:
		return not CATALOG[id].has("hero"))

## Signature boon ids for a given hero, in catalog order (mirrors
## AbilityMods.for_hero). Empty if the hero has no signature boons.
static func for_hero(hero_name: String) -> Array:
	return CATALOG.keys().filter(func(id: String) -> bool:
		return CATALOG[id].get("hero", "") == hero_name)
