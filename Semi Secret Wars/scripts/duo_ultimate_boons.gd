class_name DuoUltimateBoons
extends RefCounted
## Per-Duo Ultimate boon catalog (Designer, 2026-07-22): "a boon for each
## DUO's ultimate ability... selected at the start of the level, increasing
## the ability's power."
##
## As of 2026-07-25 this is the ONLY level-start pick round. The per-hero
## signature-ability boons (the old scripts/boons.gd) were deleted: four of
## their eight entries were verbatim copies of gold AbilityMods entries (same
## var, same number — e.g. boon "Stomp radius +45" vs. mod "Stomp radius +45")
## and the other four were one identical "ability cooldown -1.0s" cloned once
## per hero, so every hero's pick was the same binary choice with one dead
## option. Designer's call: drop hero boons, put all run-scoped picks on the
## Duo Ultimate, three options per Duo.
##
## Three per Duo (18 total), each targeting exactly one of that Duo's
## DuoUltimates.def(pair_id).params keys with a flat additive `value` — same
## additive-math rule as everywhere else (AbilityMods/StatUpgrades): no
## percentages, a picked boon reads as a concrete "+N" the player can reason
## about directly against the base params in duo_ultimates.gd.
##
## Applied at cast time, not spawn time: Hero._ultimate_param sums the base
## value from DuoUltimates.def(pair_id).params[key], this run's picks
## (RunState.duo_boon_total) and the permanent gold purchases
## (GameState.duo_mod_total) — no catalog ever mutates another.
##
## Keys here never collide with DuoUltimateMods (the permanent gold track):
## each Ultimate's params are split so the run pool and the shop upgrade
## different facets of the same ability. See duo_ultimate_mods.gd.
##
## First-pass values — flagged for tuning in BALANCE.md.

const CATALOG := {
	# BEACON+THUNDAAR — Seismic Advance (stomp_wave) -------------------------
	# params: step_count, step_interval, step_distance, step_radius,
	#         step_damage, step_stun (step_stun -> DuoUltimateMods)
	"extra_stomps": {
		"duo": "BEACON|THUNDAAR", "name": "Extra Stomps", "desc": "+2 stomps in the sequence",
		"kind": "step_count", "value": 2,
	},
	"heavier_stomps": {
		"duo": "BEACON|THUNDAAR", "name": "Heavier Stomps", "desc": "+15 damage per stomp",
		"kind": "step_damage", "value": 15.0,
	},
	"wider_stomps": {
		"duo": "BEACON|THUNDAAR", "name": "Wider Stomps", "desc": "+40 blast radius per stomp",
		"kind": "step_radius", "value": 40.0,
	},
	# THUNDAAR+WARDEN — Verdant Path (plant_trail) ----------------------------
	# params: plant_count, plant_spacing, plant_radius, tick_damage,
	#         tick_interval, ensnare_duration, trail_lifetime
	#         (trail_lifetime -> DuoUltimateMods)
	"longer_trail": {
		"duo": "THUNDAAR|WARDEN", "name": "Longer Trail", "desc": "+3 plants in the trail",
		"kind": "plant_count", "value": 3,
	},
	"potent_plants": {
		"duo": "THUNDAAR|WARDEN", "name": "Potent Plants", "desc": "+4 damage per plant tick",
		"kind": "tick_damage", "value": 4.0,
	},
	"clinging_roots": {
		"duo": "THUNDAAR|WARDEN", "name": "Clinging Roots", "desc": "+1.0s ensnare per plant",
		"kind": "ensnare_duration", "value": 1.0,
	},
	# ARTEMIS+THUNDAAR — Volatile Duplicates (exploding_clones) --------------
	# params: clone_count, clone_life_span, explode_radius, explode_damage
	#         (clone_life_span -> DuoUltimateMods)
	"extra_bomb": {
		"duo": "ARTEMIS|THUNDAAR", "name": "Extra Bomb", "desc": "+1 exploding clone",
		"kind": "clone_count", "value": 1,
	},
	"bigger_blast": {
		"duo": "ARTEMIS|THUNDAAR", "name": "Bigger Blast", "desc": "+20 explosion damage",
		"kind": "explode_damage", "value": 20.0,
	},
	"wider_blast": {
		"duo": "ARTEMIS|THUNDAAR", "name": "Wider Blast", "desc": "+35 explosion radius",
		"kind": "explode_radius", "value": 35.0,
	},
	# ARTEMIS+BEACON — Piercing Volley (arrow_barrage) ------------------------
	# params: arrow_count, chain_count, chain_damage_mult, range, arrow_damage
	#         (range -> DuoUltimateMods)
	"extra_chain": {
		"duo": "ARTEMIS|BEACON", "name": "Extra Chain", "desc": "+1 chain (3 total)",
		"kind": "chain_count", "value": 1,
	},
	"fuller_volley": {
		"duo": "ARTEMIS|BEACON", "name": "Fuller Volley", "desc": "+4 arrows in the barrage",
		"kind": "arrow_count", "value": 4,
	},
	"sharper_arrows": {
		"duo": "ARTEMIS|BEACON", "name": "Sharper Arrows", "desc": "+18 damage per arrow",
		"kind": "arrow_damage", "value": 18.0,
	},
	# ARTEMIS+WARDEN — Hunting Duplicates (roaming_clones) --------------------
	# params: clone_count, clone_life_span, ensnare_stun_duration,
	#         clone_damage_mult (clone_damage_mult -> DuoUltimateMods)
	"extra_hunter": {
		"duo": "ARTEMIS|WARDEN", "name": "Extra Hunter", "desc": "+1 roaming clone",
		"kind": "clone_count", "value": 1,
	},
	"longer_hunt": {
		"duo": "ARTEMIS|WARDEN", "name": "Longer Hunt", "desc": "+4s clone lifetime",
		"kind": "clone_life_span", "value": 4.0,
	},
	"tangling_shots": {
		"duo": "ARTEMIS|WARDEN", "name": "Tangling Shots", "desc": "+0.8s ensnare on clone shots",
		"kind": "ensnare_stun_duration", "value": 0.8,
	},
	# BEACON+WARDEN — Searing Bind (ensnare_burn) -----------------------------
	# params: radius, ensnare_duration, burn_duration, burn_dps
	#         (ensnare_duration -> DuoUltimateMods)
	"longer_burn": {
		"duo": "BEACON|WARDEN", "name": "Longer Burn", "desc": "+15s burn duration",
		"kind": "burn_duration", "value": 15.0,
	},
	"hotter_burn": {
		"duo": "BEACON|WARDEN", "name": "Hotter Burn", "desc": "+3 burn damage/sec",
		"kind": "burn_dps", "value": 3.0,
	},
	"wider_bind": {
		"duo": "BEACON|WARDEN", "name": "Wider Bind", "desc": "+45 bind radius",
		"kind": "radius", "value": 45.0,
	},
}

## All boon ids.
static func ids() -> Array:
	return CATALOG.keys()

## Definition dict for a boon id, or {} if unknown.
static func def(id: String) -> Dictionary:
	return CATALOG.get(id, {})

## Boon ids belonging to a given Duo pair id, in catalog order.
static func for_duo(pair_id: String) -> Array:
	return CATALOG.keys().filter(func(id: String) -> bool:
		return CATALOG[id].get("duo", "") == pair_id)
