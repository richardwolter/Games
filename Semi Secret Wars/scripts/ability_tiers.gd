class_name AbilityTiers
extends RefCounted
## Permanent ability-tier unlocks bought with gold.
##
## Maps onto the two flags Hero._configure still reads (_base_unlocked,
## _passive_unlocked) — tier 2 is gated behind this purchase (tier 1, the
## signature ability, is free — see GameState.has_tier). Same owned-forever
## pattern as AbilityMods.
##
## Tier 3 (the old LV20 solo "second ability" unlock — Shockwave/Multishot/
## Confuse) was retired 2026-07-22: ultimates moved from solo heroes to Duo
## Ultimates (intrinsic, no gold gate — see DuoUltimates/
## Hero.cast_duo_ultimate), so there is nothing left for a tier-3 purchase to
## unlock. Removed rather than left selling a dead entry.
##
## All four tier-2 entries are wired and observable. The note that used to sit
## here — claiming WARDEN_2/BEACON_2 bought nothing — went stale once hero.gd
## implemented them; corrected 2026-07-25 after re-checking every
## _passive_unlocked read site:
##   THUNDAAR  Stomp adds a brief stun
##   ARTEMIS   Clone deals +50% damage
##   WARDEN    Ensnare vulnerability +2 -> +3, radius +25
##             (ENSNARE_PASSIVE_VULN_DMG_ADD / ENSNARE_PASSIVE_RADIUS_ADD)
##   BEACON    Rally also heals each buffed ally (RALLY_PASSIVE_HEAL)
##
## First-pass costs — flag for tuning in BALANCE.md.

const CATALOG := {
	"THUNDAAR_2": {
		"hero": "THUNDAAR", "tier": 2, "name": "Aftershock", "cost": 40,
		"desc": "Stomp stuns enemies briefly",
	},
	"ARTEMIS_2": {
		"hero": "ARTEMIS", "tier": 2, "name": "Mirror Image", "cost": 40,
		"desc": "Clone deals +50% damage",
	},
	"WARDEN_2": {
		"hero": "WARDEN", "tier": 2, "name": "Binding", "cost": 40,
		"desc": "Ensnare vulnerability +3 and radius +25",
	},
	"BEACON_2": {
		"hero": "BEACON", "tier": 2, "name": "Empower", "cost": 40,
		"desc": "Rally also heals each ally +8 HP",
	},
}

## All ability-tier ids.
static func ids() -> Array:
	return CATALOG.keys()

## Definition dict for a tier id, or {} if unknown.
static func def(id: String) -> Dictionary:
	return CATALOG.get(id, {})

## Tier ids belonging to a given hero (tier 2 only, now that tier 3 is gone).
static func for_hero(hero_name: String) -> Array:
	return CATALOG.keys().filter(func(id: String) -> bool:
		return CATALOG[id].get("hero", "") == hero_name)

## True if `id`'s prerequisite is met. Tier 2's prerequisite is the
## always-free tier 1, so this is unconditionally true for every entry left
## in CATALOG — kept as a real check (not just `return true`) so a future
## tier addition above 2 doesn't silently skip prereq gating again.
static func prereq_met(id: String) -> bool:
	var d := def(id)
	if d.is_empty():
		return false
	var tier: int = d.get("tier", 2)
	if tier <= 2:
		return true
	var prev_id := "%s_%d" % [d.get("hero", ""), tier - 1]
	return prev_id in GameState.owned_ability_tiers
