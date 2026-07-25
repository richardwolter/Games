class_name DuoUltimateMods
extends RefCounted
## Permanent, gold-bought Duo Ultimate upgrades (Designer, 2026-07-25) — the
## Ultimate half of the reworked ABILITIES shop.
##
## Before this existed, Ultimates had no permanent progression at all: since
## they went Duo-exclusive, the only thing that scaled them was
## DuoUltimateBoons, which is run-scoped and resets every run. Gold never
## touched them, while the gold shop instead sold raw stats that duplicated
## the XP-funded STATS page. This catalog is where gold now goes.
##
## Owned forever in GameState.owned_duo_ultimate_mods (saved), exactly like
## AbilityMods/AbilityTiers. Read at cast time by Hero._ultimate_param, which
## sums three layers onto one params key and never mutates any of them:
##     DuoUltimates.def(pair).params[key]   — flat catalog baseline
##   + RunState.duo_boon_total(pair, key)   — this run's picks
##   + GameState.duo_mod_total(pair, key)   — these permanent purchases
##
## One per Duo (6 total). Each deliberately targets a params key that Duo's
## three run boons do NOT use, so a permanent purchase and a level-start pick
## always upgrade different facets of the same Ultimate — the duplication that
## motivated this whole rework is not recreated here. The reserved key is
## noted in duo_ultimate_boons.gd next to each Duo's block.
##
## Flat additive like everything else, with ONE documented exception:
## ARTEMIS|WARDEN's "Lethal Hunters" targets `clone_damage_mult`, which is a
## multiplier by design in duo_ultimates.gd (Hunting Duplicates is the only
## Ultimate whose four params leave no additive key free). Flagged for the
## Designer — if the no-percentages rule should hold absolutely here, this
## entry needs a new additive param plumbed into _cast_roaming_clones.
##
## First-pass costs/values — flagged for tuning in BALANCE.md.

const CATALOG := {
	"BEACON|THUNDAAR": {
		"duo": "BEACON|THUNDAAR", "name": "Concussive Wave", "cost": 75,
		"desc": "Seismic Advance: +0.5s stun per stomp",
		"kind": "step_stun", "value": 0.5,
	},
	"THUNDAAR|WARDEN": {
		"duo": "THUNDAAR|WARDEN", "name": "Deep Roots", "cost": 75,
		"desc": "Verdant Path: trail lasts +4s",
		"kind": "trail_lifetime", "value": 4.0,
	},
	"ARTEMIS|THUNDAAR": {
		"duo": "ARTEMIS|THUNDAAR", "name": "Long Fuse", "cost": 75,
		"desc": "Volatile Duplicates: clones last +3s before detonating",
		"kind": "clone_life_span", "value": 3.0,
	},
	"ARTEMIS|BEACON": {
		"duo": "ARTEMIS|BEACON", "name": "Far Shot", "cost": 75,
		"desc": "Piercing Volley: +120 barrage range",
		"kind": "range", "value": 120.0,
	},
	"ARTEMIS|WARDEN": {
		"duo": "ARTEMIS|WARDEN", "name": "Lethal Hunters", "cost": 75,
		"desc": "Hunting Duplicates: clones deal +1x their base damage",
		"kind": "clone_damage_mult", "value": 1.0,
	},
	"BEACON|WARDEN": {
		"duo": "BEACON|WARDEN", "name": "Iron Bindings", "cost": 75,
		"desc": "Searing Bind: +1.5s root duration",
		"kind": "ensnare_duration", "value": 1.5,
	},
}

## All mod ids (the id IS the pair id — one entry per Duo).
static func ids() -> Array:
	return CATALOG.keys()

## Definition dict for a mod id, or {} if unknown.
static func def(id: String) -> Dictionary:
	return CATALOG.get(id, {})

## Mod ids belonging to a given Duo pair id. Returns 0 or 1 entries today, but
## stays an Array so a second upgrade per Duo can be added without touching
## the shop UI (AbilitiesPage iterates this).
static func for_duo(pair_id: String) -> Array:
	return CATALOG.keys().filter(func(id: String) -> bool:
		return CATALOG[id].get("duo", "") == pair_id)
