class_name StatUpgrades
extends RefCounted
## Permanent, repeatable per-hero stat upgrades bought with banked XP —
## the "raw stats" track, separate from AbilityMods/AbilityTiers
## (which both spend gold). Unlike those catalogs (bought once), each of these
## can be bought repeatedly per hero; cost rises with how many times that hero
## has already bought it — see GameState.stat_purchase_count/buy_stat_upgrade.
##
## Flat additive effects (Designer, 2026-07-21: no percentages on upgrades —
## a player buying "Damage Lv3" should read "+3 Damage total", not do %-of-
## current-stat math). `effect_add` is a flat amount per purchase, applied in
## Hero._apply_stat_upgrades() as `stat += effect_add * purchases` (or, for
## attack_speed, `attack_interval -= effect_add * purchases`, floored). Chosen
## to land close to the old %-of-base-stat magnitudes (hp/damage were 8%,
## attack_speed 5%, against average hero stats ~95 HP / ~7.5 dmg / ~0.6s).
##
## First-pass values — flag for tuning in BALANCE.md.

const STATS := {
	"hp": {
		"label": "Max HP", "base_cost": 20, "cost_growth": 1.15,
		"effect_add": 8.0, "hero_stat_key": "base_hp",
	},
	"damage": {
		"label": "Damage", "base_cost": 25, "cost_growth": 1.15,
		"effect_add": 1.0, "hero_stat_key": "base_damage",
	},
	"attack_speed": {
		"label": "Attack Speed", "base_cost": 30, "cost_growth": 1.15,
		"effect_add": 0.03, "hero_stat_key": "attack_interval",
	},
}

## Reference values the flat effects/base_costs above were tuned against (see
## doc comment) — the same "~95 HP / ~7.5 dmg / ~0.6s" the file already cites.
## A hero sitting exactly at one of these pays exactly base_cost; a hero below
## it (a flat add is a BIGGER % of a smaller stat) pays more, one above it
## pays less — see hero_cost_mult.
const REFERENCE := {
	"base_hp": 95.0,
	"base_damage": 7.5,
	"attack_interval": 0.6,
}

## All stat ids, in catalog order.
static func ids() -> Array:
	return STATS.keys()

## Definition dict for a stat id, or {} if unknown.
static func def(id: String) -> Dictionary:
	return STATS.get(id, {})

## Ability-pass finding (2026-07-24, BALANCE.md): a flat effect_add is a
## bigger relative gain on a hero with a lower base stat — Artemis's 40 eff.
## HP / 3 eff. damage / 0.4s interval meant she got the single biggest %
## payoff of any hero on EVERY stat axis, for the same gold cost as everyone
## else, and Clone then copies that inflated live damage/HP wholesale into a
## second unit. Rather than touch the flat, no-% effects (locked house rule,
## see doc comment above), the GOLD cost is indexed to each hero's own base
## stat instead: below-reference stats cost more, above-reference cost less.
## Returns 1.0 for an unknown hero/stat (falls back to the flat base_cost).
static func hero_cost_mult(hero_name: String, id: String) -> float:
	var d := def(id)
	var key: String = d.get("hero_stat_key", "")
	if key == "":
		return 1.0
	var stats: Dictionary = Hero.HERO_STATS.get(hero_name, {})
	var hero_val := float(stats.get(key, 0.0))
	var ref := float(REFERENCE.get(key, 0.0))
	if hero_val <= 0.0 or ref <= 0.0:
		return 1.0
	return ref / hero_val

## Cost of the NEXT purchase, given how many times `hero_name` has already
## bought this stat — rises geometrically so the sink stays meaningful, and
## is scaled by hero_cost_mult so every hero's Nth purchase costs roughly the
## same SHARE of their own kit instead of the same flat number regardless of
## how much stat it's landing on.
static func cost_for(hero_name: String, id: String, purchases: int) -> int:
	var d := def(id)
	if d.is_empty():
		return 0
	var base := float(d.get("base_cost", 0)) * hero_cost_mult(hero_name, id)
	return int(round(base * pow(float(d.get("cost_growth", 1.0)), purchases)))
