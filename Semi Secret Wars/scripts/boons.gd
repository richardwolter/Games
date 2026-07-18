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
}

## All boon ids (a fresh Array each call — safe for the caller to shuffle).
static func ids() -> Array:
	return CATALOG.keys()

## The definition dict for a boon id, or {} if unknown.
static func def(id: String) -> Dictionary:
	return CATALOG.get(id, {})
