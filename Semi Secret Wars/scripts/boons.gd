class_name Boons
extends RefCounted
## Run-scoped boon catalog — one pick per hero at the start of each level
## (Designer, 2026-07-21: "boons only at the start of a level" + "ability
## focused boons" — replaces the old mid-battle XP-level-up draft that also
## offered generic stat boosts alongside signature ones).
##
## Boons are permanent for the CURRENT run only — they live in RunState (never
## saved) and are applied to the hero at spawn (Hero.apply_run_boon, called
## from BattleManager._spawn_hero for every boon already owned this run).
## persistent progression is separate (GameState / future MetaState).
##
## Every boon here is ability-focused — it changes that hero's own signature
## ability (Stomp/Clone/Ensnare/Rally), never a raw stat — so a hero always
## picks between "bigger/more" or "faster" for the ability that defines them.
## Two per hero: an ability-geometry boost (radius/count) and a flat ability
## cooldown reduction, both flat additive (Designer, 2026-07-21: no % on
## upgrades/abilities) reusing the same `_add` scalar vars the gold ability
## mods use (see hero.gd) — a boon and a mod stack additively on the same var.
##
## First-pass values — flagged for tuning in BALANCE.md.

const CATALOG := {
	# THUNDAAR (TANK — Stomp) ------------------------------------------------
	"seismic_focus": {
		"hero": "THUNDAAR", "name": "Seismic Focus", "desc": "Stomp radius +45",
		"kind": "stomp_radius_add", "value": 45.0,
	},
	"aftershock": {
		"hero": "THUNDAAR", "name": "Aftershock", "desc": "Ability cooldown -1.0s",
		"kind": "ability_cooldown_reduction", "value": 1.0,
	},
	# ARTEMIS (BURST — Clone) ------------------------------------------------
	"twin_focus": {
		"hero": "ARTEMIS", "name": "Twin Focus", "desc": "Clone count +1",
		"kind": "clone_count_add", "value": 1,
	},
	"fleetfoot": {
		"hero": "ARTEMIS", "name": "Fleetfoot", "desc": "Ability cooldown -1.0s",
		"kind": "ability_cooldown_reduction", "value": 1.0,
	},
	# WARDEN (CONTROL — Ensnare) ---------------------------------------------
	"wide_net": {
		"hero": "WARDEN", "name": "Wide Net", "desc": "Ensnare radius +50",
		"kind": "ensnare_radius_add", "value": 50.0,
	},
	"rapid_snare": {
		"hero": "WARDEN", "name": "Rapid Snare", "desc": "Ability cooldown -1.0s",
		"kind": "ability_cooldown_reduction", "value": 1.0,
	},
	# BEACON (SUPPORT — Rally) -----------------------------------------------
	"broad_rally": {
		"hero": "BEACON", "name": "Broad Rally", "desc": "Rally radius +90",
		"kind": "rally_radius_add", "value": 90.0,
	},
	"quick_rally": {
		"hero": "BEACON", "name": "Quick Rally", "desc": "Ability cooldown -1.0s",
		"kind": "ability_cooldown_reduction", "value": 1.0,
	},
}

## All boon ids (a fresh Array each call — safe for the caller to shuffle).
static func ids() -> Array:
	return CATALOG.keys()

## The definition dict for a boon id, or {} if unknown.
static func def(id: String) -> Dictionary:
	return CATALOG.get(id, {})

## Boon ids for a given hero, in catalog order (mirrors AbilityMods.for_hero).
## Every boon is hero-specific now — there is no generic/hero-agnostic pool.
static func for_hero(hero_name: String) -> Array:
	return CATALOG.keys().filter(func(id: String) -> bool:
		return CATALOG[id].get("hero", "") == hero_name)
