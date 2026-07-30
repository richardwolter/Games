class_name DuoUltimates
extends RefCounted
## Duo Ultimate catalog (Designer, 2026-07-22): "each DUO have an exclusive
## Ultimate, and Heroes will no longer have an Ultimate by themselves, only
## DUO." Replaces the old solo LV20 second-ability system (Shockwave/
## Multishot/Confuse — see hero.gd's 2026-07-22 removal notes).
##
## One entry per unordered hero pair (6 total — every possible Duo), keyed by
## id_for_heroes(a, b). Each entry is:
##   name / desc  — HUD/Duo-ultimate-bar display text.
##   kind         — dispatch key read by Hero.cast_duo_ultimate (matches one
##                  of the effect methods there / a scenes/combat/duo/*.gd).
##   params       — base tunables for that effect; DuoUltimateBoons adds on
##                  top of these at cast time via RunState.duo_boon_total
##                  (never mutated here — this catalog is the flat baseline).
##   buff         — flat, level-long stat buff granted to BOTH Duo members on
##                  activation (Hero.apply_permanent_buff): dmg_add,
##                  atk_reduction (seconds shaved off attack_interval),
##                  hp_add. Any key can be omitted (treated as 0).
##
## Manually activated once per level from the Duo Ultimate bar (BattleHUD) —
## see BattleManager.activate_ultimate. Intrinsic: no gold/tier gate, unlike
## the old solo ultimates.
##
## Ability-cadence pass (Designer, 2026-07-24: "the ultimate has to be really
## meaningful on the battlefield action"): damage figures scaled ~5x from the
## first-pass values below, on top of three real bugs fixed alongside this
## retune — see BALANCE.md for the before/after table and the arithmetic that
## motivated it. Verified by inspection only; no automated sweep exists yet
## for the lane build (see .claude/skills/balance-qa).
##   - Piercing Volley used to scale off caster.damage (Artemis's live attack
##     damage, ~3) instead of a flat constant like every other ultimate here —
##     the entire once-per-level cast dealt roughly 36 total. Now `arrow_damage`.
##   - Volatile Duplicates dealt zero if its clones were never attacked
##     (explode_on_hit only fired on take_damage) — see HeroClone._process,
##     now also detonates on life_span expiry.
##   - explode_damage/burn_dps used to bypass _duo_damage_mult/damage_mult()
##     (every other ultimate routes through both) — fixed at the cast sites in
##     hero.gd's _cast_exploding_clones/_cast_ensnare_burn.
const CATALOG := {
	# THUNDAAR + BEACON -------------------------------------------------------
	"BEACON|THUNDAAR": {
		"name": "Seismic Advance",
		"desc": "March forward stomping — damages and stuns everything the sequence hits.",
		"kind": "stomp_wave",
		"params": {
			"step_count": 5, "step_interval": 0.35, "step_distance": 80.0,
			"step_radius": 100.0, "step_damage": 90.0, "step_stun": 0.8,
		},
		"buff": {"dmg_add": 2.0, "atk_reduction": 0.1},
	},
	# THUNDAAR + WARDEN -------------------------------------------------------
	"THUNDAAR|WARDEN": {
		"name": "Verdant Path",
		"desc": "Lay a trail of plants down the lane that damage and ensnare minions & villains.",
		"kind": "plant_trail",
		"params": {
			# plant_radius 50 -> 75: the plants got 1.5x bigger art AND hitbox
			# (Designer, 2026-07-25). Spacing is unchanged, so adjacent plants
			# now overlap — the trail bites as a continuous strip rather than
			# five separate pockets.
			"plant_count": 5, "plant_spacing": 60.0, "plant_radius": 75.0,
			"tick_damage": 16.0, "tick_interval": 1.0,
			"ensnare_duration": 1.0, "trail_lifetime": 8.0,
		},
		"buff": {"hp_add": 30.0, "dmg_add": 2.0},
	},
	# THUNDAAR + ARTEMIS ------------------------------------------------------
	"ARTEMIS|THUNDAAR": {
		"name": "Volatile Duplicates",
		"desc": "Summon Artemis clones that detonate in an AoE blast on contact — or after a 2s fuse if nothing reaches them.",
		"kind": "exploding_clones",
		"params": {
			# clone_life_span is the FUSE, not a taunt window: 6.0 -> 2.0
			# (Designer, 2026-07-26). Now that a clone detonates on contact
			# rather than waiting to be attacked, the timer is only what
			# happens when nothing comes — and six seconds of a bomb sitting
			# inert is a once-per-level Ultimate spending most of its life
			# doing nothing. The "Long Fuse" mod (+3s) still applies on top for
			# players who want the clone to hold position longer.
			"clone_count": 2, "clone_life_span": 2.0,
			"explode_radius": 90.0, "explode_damage": 130.0,
		},
		"buff": {"atk_reduction": 0.3, "dmg_add": 2.0},
	},
	# ARTEMIS + BEACON --------------------------------------------------------
	"ARTEMIS|BEACON": {
		"name": "Piercing Volley",
		"desc": "Fire a barrage of arrows that each chain to 2 more enemies at half damage.",
		"kind": "arrow_barrage",
		"params": {
			"arrow_count": 6, "chain_count": 2, "chain_damage_mult": 0.5,
			"range": 260.0, "arrow_damage": 55.0,
			# The barrage fires waves across `duration` instead of resolving
			# instantly (Designer, 2026-07-25). arrow_damage is the TOTAL per
			# arrow across the whole barrage — ArrowBarrage divides it by the
			# wave count — so this stays balance-neutral.
			"duration": 10.0, "wave_interval": 0.5,
		},
		"buff": {"atk_reduction": 0.3, "dmg_add": 2.0},
	},
	# ARTEMIS + WARDEN --------------------------------------------------------
	"ARTEMIS|WARDEN": {
		"name": "Hunting Duplicates",
		"desc": "Summon aggressive Artemis clones that roam toward minions — their shots ensnare too.",
		"kind": "roaming_clones",
		"params": {
			"clone_count": 2, "clone_life_span": 12.0, "ensnare_stun_duration": 1.0,
			"clone_damage_mult": 2.0,
		},
		"buff": {"atk_reduction": 0.3, "hp_add": 30.0},
	},
	# WARDEN + BEACON ---------------------------------------------------------
	"BEACON|WARDEN": {
		"name": "Searing Bind",
		"desc": "Burning ground for 3s: everything that enters is rooted and set ablaze for 5s.",
		"kind": "ensnare_burn",
		# Reworked 2026-07-26 (Designer) from a one-frame snapshot into a 3s
		# field — see Hero._cast_ensnare_burn. The burn went 30s -> 5s and the
		# dps up to match, so a bound enemy takes a comparable total (~225) but
		# takes it NOW, inside the fight the cast was meant to swing, instead of
		# ticking away for half a level. Radius up 140 -> 210 for the same
		# reason the field exists: the ultimate should catch a swarm, not a
		# huddle.
		"params": {
			"radius": 210.0, "ensnare_duration": 1.5,
			"burn_duration": 5.0, "burn_dps": 45.0,
		},
		"buff": {"dmg_add": 4.0, "hp_add": 30.0},
	},
}

## Deterministic id for an unordered hero pair.
static func id_for_heroes(hero_a: String, hero_b: String) -> String:
	var pair := [hero_a, hero_b]
	pair.sort()
	return "%s|%s" % [pair[0], pair[1]]

## Definition dict for a pair id, or {} if unknown.
static func def(id: String) -> Dictionary:
	return CATALOG.get(id, {})

## All catalog ids.
static func ids() -> Array:
	return CATALOG.keys()
