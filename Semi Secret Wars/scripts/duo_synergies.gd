class_name DuoSynergies
extends RefCounted
## Named identity for each of the 6 possible Duo role-pairs, mirroring the
## Achievements/AbilityMods static-catalog pattern. Purely presentational — the
## actual mechanics live in Hero: the generic Duo Bonus (DUO_* consts,
## _update_duo_bonus — a damage/cooldown-reduction/XP multiplier while paired,
## alive, and within DUO_DISTANCE) applies identically to every pair, plus an
## optional per-hero leader/follower behavior layer (THUNDAAR_LEADER_*/
## ARTEMIS_LEADER_*, keyed only on hero_name + leader-vs-follower — never on
## the specific partner, to avoid the Warden targeting conflict that pattern
## caused before). Leader-vs-follower is a pure player choice (which Duo slot
## the hero was dropped in — see GameState.is_duo_leader), not role-derived.
## Names/flavor below are placeholders pending Designer naming; the desc is
## identical boilerplate across all 6 since the catalog only names the
## generic Duo Bonus, not the per-hero layer.

const _GENERIC_DESC := "Paired Duo bonus: bonus damage, cooldown reduction, and XP while both are alive and within range — stronger for whichever hero leads the pairing."

const CATALOG := {
	"BURST_TANK": {"name": "VANGUARD STRIKE", "desc": _GENERIC_DESC},
	"CONTROL_TANK": {"name": "IRON ANCHOR", "desc": _GENERIC_DESC},
	"SUPPORT_TANK": {"name": "GUARDIAN'S OATH", "desc": _GENERIC_DESC},
	"BURST_CONTROL": {"name": "MARKED PREY", "desc": _GENERIC_DESC},
	"BURST_SUPPORT": {"name": "COVERING LIGHT", "desc": _GENERIC_DESC},
	"CONTROL_SUPPORT": {"name": "BOUND LIGHT", "desc": _GENERIC_DESC},
}

## Deterministic id for an unordered role pair ("" if either role is unknown
## or they're the same role — no hero shares a role with another today).
static func id_for_roles(role_a: String, role_b: String) -> String:
	if role_a == "" or role_b == "" or role_a == role_b:
		return ""
	var pair := [role_a, role_b]
	pair.sort()
	return "%s_%s" % [pair[0], pair[1]]

## Definition dict for a role-pair id, or {} if unknown.
static func def(id: String) -> Dictionary:
	return CATALOG.get(id, {})

## Definition dict for a Duo of two hero names (any order), or {} if either
## name is unrecognized or they share a role.
static func def_for_heroes(hero_a: String, hero_b: String) -> Dictionary:
	var role_a: String = Hero.ROLE_BY_HERO.get(hero_a, "")
	var role_b: String = Hero.ROLE_BY_HERO.get(hero_b, "")
	return def(id_for_roles(role_a, role_b))
