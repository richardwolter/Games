class_name Hero
extends Combatant
## Placeholder party hero (e.g. Thundaar, Artemis).
##
## Spawned by BattleManager from the prep-screen party config at the field's
## hero-spawn funnel. Behavior follows the assigned battlefield priority
## (GDD §11), moving freely across the open field (steering around obstacles):
##  - CAPTURE_OBJECTIVES — head to the nearest uncaptured objective's general
##    area (fuzzed — exact spot unknown until within view range), search
##    until spotted, hold until captured, then repeat for any remaining
##    uncaptured objectives; once all are captured, fall through to the
##    villain push (Designer decision, see DECISIONS.md).
##  - ATTACK_VILLAIN   — default: push straight for the villain, staying
##    locked onto him even as he kites (detect range widened past his flee
##    distance), only trading blows with minions that wander into that
##    same range.
## Purchased upgrades (GameState) apply on spawn.

@export var hero_name := "HERO"
## Small offset so party members stand side by side, not overlapping.
@export var lateral := Vector2.ZERO
@export var priority := "ATTACK_VILLAIN"
## SUPPORT_ALLIES targeting: which specific ally to shadow ("" = nearest living
## ally, the default). Set by BattleManager at spawn from
## GameState.party_of(hero_name).support_target. Ignored by every other
## priority.
@export var support_target := ""

## Formation bonuses (proximity-based role interactions)
const FORMATION_SAME_ROLE_DIST := 150.0
const FORMATION_SAME_ROLE_DAMAGE := 1.1
const FORMATION_OPPOSITE_ROLE_DIST := 200.0
const FORMATION_OPPOSITE_ROLE_TANK_HP := 1.15
const FORMATION_OPPOSITE_ROLE_BURST_DAMAGE := 1.15
const FORMATION_OPPOSITE_ROLE_MULT := 1.15
## Symmetric opposite-role pairings so no comp is structurally denied a pair
## bonus (was TANK+BURST only, which forced a Thundaar pick). Each entry maps a
## role to its partner role and which stat ("hp"/"damage") the pair grants THIS
## role: the durable/utility side takes HP, the damage side takes damage, all
## ×FORMATION_OPPOSITE_ROLE_MULT. Pairs are mutual (both sides listed).
const FORMATION_PAIRS := {
	"TANK": {"BURST": "hp"},
	"BURST": {"TANK": "damage", "SUPPORT": "damage"},
	"CONTROL": {"SUPPORT": "damage"},
	"SUPPORT": {"CONTROL": "hp", "BURST": "hp"},
}
const FORMATION_MIXED_TRIO_DIST := 180.0
const FORMATION_MIXED_TRIO_COOLDOWN := 0.05

## Thundaar's Stomp: auto-casts on cooldown whenever an enemy is in range,
## hitting everything within STOMP_RADIUS for damage + knockback.
const STOMP_COOLDOWN := 3.5
const STOMP_RADIUS := 70.0
const STOMP_DAMAGE := 26.0
const STOMP_KNOCKBACK := 100.0
## Ring VFX: how long the expanding-shockwave draw lasts after a landed stomp.
const STOMP_FLASH_TIME := 0.25
const STOMP_FLASH_COLOR := Color(1.0, 0.85, 0.3, 0.9)

## Artemis's Clone: auto-casts on cooldown, spawning a temporary copy of
## herself (see HeroClone) that taunts and fights back for CLONE_DURATION.
const CLONE_SCENE := preload("res://scenes/heroes/hero_clone.tscn")
const CLONE_COOLDOWN := 8.0
const CLONE_DURATION := 3.5
const CLONE_TAUNT_RADIUS := 90.0
## Spawn offset so the clone appears beside Artemis (toward her facing) instead
## of stacked exactly on top of her, where it's indistinguishable at a glance.
const CLONE_SPAWN_OFFSET := 40.0

## WARDEN's Ensnare (Controller signature): auto-casts on cooldown, rooting
## every enemy in a radius around the nearest threat (the current target,
## used as a cluster proxy) so the DPS can focus the locked pack. First-pass
## values — tune in BALANCE.md.
const ENSNARE_COOLDOWN := 4.5
const ENSNARE_RADIUS := 95.0
const ENSNARE_STUN_DURATION := 1.2
## Ring VFX reused from Stomp's flash treatment (see _draw).
const ENSNARE_FLASH_TIME := 0.3
const ENSNARE_FLASH_COLOR := Color(0.4, 0.85, 0.8, 0.9)

## BEACON's Rally (Support signature): auto-casts on cooldown, granting every
## nearby ally (self included) a timed damage + attack-speed boost. Reuses the
## objective-reward buff primitives (Combatant.apply_damage_boost /
## apply_atk_speed_boost), so the buffed allies show DMG+/ATK SPD+ chips for
## free via active_buffs(). First-pass values — tune in BALANCE.md.
const RALLY_COOLDOWN := 7.0
const RALLY_RADIUS := 180.0
const RALLY_DURATION := 4.0
const RALLY_DMG_MULT := 1.15
const RALLY_ATK_MULT := 1.20

## Max contribution `lateral` makes to the villain-chase goal (keeps heroes
## from clumping on his exact point without dragging that goal way off him
## when deployment spread them far apart — see _villain_goal).
const VILLAIN_GOAL_LATERAL_CAP := 60.0

## How often (seconds) the villain push-goal is refreshed while chasing him,
## so heroes follow his kiting/teleports instead of beelining a stale point.
const VILLAIN_TRACK_INTERVAL := 0.3
## Once the villain has entered detect/attack range at least once, heroes
## get more aggressive about following him — re-aiming this much more often
## so he can't shake them by kiting/teleporting just past the old interval's
## staleness window.
const VILLAIN_SPOTTED_TRACK_INTERVAL := 0.1

## SUPPORT_ALLIES priority: how often the support re-checks its distance to the
## party (so Rally lands). Solo fallback pushes the villain.
const SUPPORT_TRACK_INTERVAL := 0.3
## SUPPORT_ALLIES leash band: the support only re-paths toward its partner when
## it has drifted past this far — inside the band it fights as a free individual
## (its own target selection + the SCORE_SUPPORT_GUARD bias keep it useful near
## the party). Set to the loose end of the range (past SYNERGY_DISTANCE 200 and
## RALLY_RADIUS 180) so it ranges to clear minions and reads as a peer, not a
## shadow — accepting that at the band's edge it can briefly drop synergy/Rally.
const SUPPORT_LEASH_DIST := 260.0

## When following an ally/support target, stop this far off its body instead of
## aiming at its exact position — parking on top of it just feeds the
## separation push and makes the follower jitter. Kept small (well inside
## RALLY_RADIUS 180) so the aura still covers, but past the two bodies' radii
## so they don't overlap.
const FOLLOW_STANDOFF := 46.0
## Chip-display threshold for SUPPORT_ALLIES's "FOLLOWING" buff chip — close
## enough to the chosen support target that Rally's aura is realistically
## landing. Kept inside SYNERGY_DISTANCE (200).
const FOLLOW_CHIP_DIST := 140.0

## Rally-to-ally: while on objective duty (not yet pushing the villain) with
## no threat in sight, a hero heads toward the nearest ally that IS currently
## fighting something, instead of wandering its own objective search pattern.
## Never applies to the villain push itself (ATTACK_VILLAIN, or CAPTURE_OBJECTIVES
## once _pushed_on) — that priority already has its own live-tracked goal.
const RALLY_CHECK_INTERVAL := 0.5
var _rally_cd := 0.0
## True while the current goal is a rally toward a fighting ally rather than
## the objective search pattern, so _on_goal_reached doesn't overwrite it with
## a fresh random search point the instant it's reached.
var _rallying := false

## Detect range while actively pushing the villain (ATTACK_VILLAIN, and
## CAPTURE_OBJECTIVES once its objectives are done). Must clear the villain's
## own flee_distance (see villain.gd) with margin, otherwise he kites just
## outside detect range and _acquire_target keeps dropping him as _target
## before a hero ever gets close enough to land a hit.
const VILLAIN_ENGAGE_RANGE := 320.0

## V2 lane structure only: destructible minion spawn points ("spawn_points"
## group) are empty in V1, so this is a no-op there. Killing a spawn point
## permanently stops its waves, which matters more than any single minion or
## even the still-dormant villain — locked at a wide range like the villain
## push, and outscores everything else in _target_score, so heroes go destroy
## the swarm's source instead of just farming whatever wanders past.
const SPAWN_POINT_ENGAGE_RANGE := 500.0
const SCORE_SPAWN_POINT_PRIORITY := 400.0

## CAPTURE_OBJECTIVES search behavior: the hero only knows the objective's
## general area (a point randomized within this radius of the true spot) and
## must wander within view range of it before locking onto the exact position.
## Fuzz is kept <= view radius so any picked search point already lies within
## spotting range — otherwise a re-pick can land outside view range of the
## last one, sending the hero on an unbounded random walk that never closes in.
const OBJECTIVE_SEARCH_FUZZ := 120.0
const OBJECTIVE_VIEW_RADIUS := 150.0

## Abilities are intrinsic hero kit (Milestone 2: no more persistent
## skill-tree gating) — every hero has its full ability set from the start
## of every run; see _configure's unconditional _base/_passive/_active_unlocked.
const STOMP_STUN_DURATION := 0.5
const CLONE_DAMAGE_BOOST := 1.5  ## +50%, passive tree node.

## Thundaar's Shockwave (LV20 unlock): auto-casts on its own cooldown,
## a wide line in front of him hitting everything within its reach.
const SHOCKWAVE_COOLDOWN := 5.0
const SHOCKWAVE_RANGE := 180.0
const SHOCKWAVE_HALF_WIDTH := 60.0
const SHOCKWAVE_DAMAGE := 40.0
const SHOCKWAVE_KNOCKBACK := 80.0

## Artemis's Multishot (LV20 unlock): auto-casts on its own cooldown, firing
## a simultaneous volley of arrows (the same Projectile as her basic attack)
## at up to MULTISHOT_MAX_TARGETS nearby enemies. Replaces the old Dash —
## stationary by design (Designer call: movement-type abilities inbalance the
## game), so it keeps Dash's cooldown/target-count budget without the reposition.
const MULTISHOT_COOLDOWN := 6.0
const MULTISHOT_RANGE := 220.0
const MULTISHOT_MAX_TARGETS := 5
## Each arrow deals less than a full hit since up to 5 land at once (a full-
## damage 5-target volley would out-damage every other ultimate in the kit).
const MULTISHOT_DAMAGE_MULT := 0.6

## BEACON's Confuse (ultimate / second-ability slot): auto-casts on its own
## cooldown, projecting a cone of light toward the nearest minion cluster.
## Minions caught in the cone turn on each other for CONFUSE_DURATION seconds.
## Villains are immune (see _try_confuse). Fires only when the cone catches
## at least CONFUSE_MIN_TARGETS enemies, so a solo stray doesn't waste it.
const CONFUSE_COOLDOWN := 12.0
const CONFUSE_RANGE := 200.0
const CONFUSE_HALF_WIDTH := 90.0
const CONFUSE_DURATION := 3.0
const CONFUSE_MIN_TARGETS := 2

## Synergy system: two-hero bonuses when both alive and within this distance.
const SYNERGY_DISTANCE := 200.0
const SYNERGY_DAMAGE_MULT := 1.15
const SYNERGY_COOLDOWN_REDUCTION := 0.3
const SYNERGY_XP_MULT := 1.25

## Target-scoring weights (Hero._target_score). The base score is the raw
## distance to a candidate in pixels (nearer = preferred, matching the old
## nearest-target behavior); each bonus below is subtracted, so it reads as
## "treat this target as N pixels closer." That keeps every weight in one
## intuitive, sweepable unit rather than squared-distance space.
##
## Focus fire: per ally already targeting this candidate (party is ≤3 + clones,
## so this caps around 3× in practice) — the single biggest lever for making
## the party kill one thing instead of spraying across the swarm.
const SCORE_FOCUS_FIRE := 120.0
## Execute: full bonus for a candidate finishable within SCORE_EXECUTE_HITS of
## this hero's own hits, fading to zero at that HP threshold — so near-dead
## enemies actually get put down instead of everyone leaving them at 20%.
const SCORE_EXECUTE := 150.0
const SCORE_EXECUTE_HITS := 2.0
## Threat: per point of the candidate's damage (minions sit ~2–3.5), plus a flat
## bump for anything that out-ranges this hero (the ranged minions that pure
## nearest-targeting ignores forever while they plink from safety).
const SCORE_THREAT_PER_DAMAGE := 25.0
const SCORE_THREAT_OUTRANGE := 90.0

## Role-tactics weights (Phase 3, folded into _target_score via _role_bonus).
## TANK peels: bonus for a candidate near the most-endangered ally (lowest HP
## fraction), scaled by how close it is to that ally (full within PEEL_RADIUS).
const SCORE_TANK_PEEL := 200.0
const TANK_PEEL_RADIUS := 130.0
## BURST leans harder on executes and less on tanky threats (it should delete
## squishies/low targets, not brawl brutes) — multipliers on the shared weights.
const BURST_EXECUTE_MULT := 1.8
const BURST_THREAT_MULT := 0.4
## CONTROL prefers a candidate sitting in the densest enemy cluster, so it also
## makes the best Ensnare anchor (Ensnare roots everything within ENSNARE_RADIUS
## of _target). Bonus per additional enemy neighbor within that radius.
const SCORE_CONTROL_CLUSTER := 45.0
## SUPPORT is low-aggression: it only meaningfully prefers whatever is attacking
## the ally it's pledged to protect (its support_target, else nearest ally).
const SCORE_SUPPORT_GUARD := 220.0
## Focus ping (player command): strong target-selection pull toward enemies near
## an active ping, fading with distance to the ping (see _focus_ping_bonus). Sized
## above the other tactical bonuses so a deliberate ping wins the target choice.
const SCORE_FOCUS_PING := 260.0

## Hero-specific flat base stats (Milestone 2: no more persistent per-purchase
## scaling — a hero always starts a run here; growth comes only from in-run
## boons, see Hero.apply_run_boon / RunState).
##
## Optional ranged keys (Milestone 5): `is_ranged` + `attack_range` make a hero
## fire a Projectile instead of meleeing — read generically in _configure (no
## per-hero special-casing). `attack_interval` overrides the hero.tscn default.
## Heroes start significantly weaker than the old V1 tuned baseline. The
## grindier redeploy-lane loop assumes a slow climb via boons/mods, not day-one
## power level. Applied on top of HERO_STATS in _configure — the table itself
## is untouched.
const V2_HP_MULT := 0.5
const V2_DAMAGE_MULT := 0.5

const HERO_STATS: Dictionary = {
	"THUNDAAR": {
		"base_hp": 110,
		"base_damage": 10,
		"attack_interval": 0.7,
		"move_speed": 90,
	},
	"ARTEMIS": {
		"base_hp": 80,
		"base_damage": 6,
		"move_speed": 100,
		"is_ranged": true,
		"attack_interval": ARTEMIS_ATTACK_INTERVAL,
		"attack_range": ARTEMIS_ATTACK_RANGE,
	},
	# WARDEN — Controller (ranged): roots enemy clusters with Ensnare. Squishier
	# than the DPS, medium range so it controls from the mid-line.
	"WARDEN": {
		"base_hp": 90,
		"base_damage": 6,
		"move_speed": 90,
		"is_ranged": true,
		"attack_interval": 0.6,
		"attack_range": 120.0,
	},
	# BEACON — Support (melee-ish): low personal damage; its value is Rally
	# buffing the party. Modest HP so it can hold the mid-line near allies.
	"BEACON": {
		"base_hp": 100,
		"base_damage": 8,
		"attack_interval": 0.6,
		"move_speed": 90,
	},
}

## Artemis: ranged attacker — fires an arrow (Projectile) instead of melee,
## with a much longer attack_range and faster base attack_interval than the
## shared hero.tscn default (0.5s / 26px), traded for lower HP/damage above.
const ARTEMIS_PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")
const ARTEMIS_ATTACK_INTERVAL := 0.4
const ARTEMIS_ATTACK_RANGE := 160.0

## Fixed role per hero (TANK, BURST, CONTROL) — set in _configure based on hero_name.
var role := "CONTROL"

## Ability-mod scalars (Phase 5 gold shop). Default identity; owned mods adjust
## these in _apply_ability_mod(), and the ability code reads them in place of the
## raw constants. Permanent per-hero tradeoffs, applied once at _configure.
var stomp_radius_mult := 1.0
var stomp_cooldown_add := 0.0
var clone_count := 1
var clone_hp_mult := 1.0
var ensnare_radius_mult := 1.0
var ensnare_stun_mult := 1.0
var rally_radius_mult := 1.0
var rally_cooldown_add := 0.0

var _objective: Node2D = null
var _objective_spotted := false
var _pushed_on := false
var _ability_cd := 0.0
var _stomp_flash_t := 0.0
## Ensnare ring VFX: timer + the world-space cluster anchor it played on (the
## root lands around the target, not the caster, so the ring is drawn there).
var _ensnare_flash_t := 0.0
var _ensnare_flash_center := Vector2.ZERO
var _villain_track_cd := 0.0
var _support_track_cd := 0.0
## ATTACK_MINIONS: re-aim cadence at the nearest live hostile (same one-shot-goal
## pattern as the villain/support tracking timers).
var _minion_track_cd := 0.0
## Set once the villain has come within detect range at least once (i.e. the
## hero has actually seen/engaged him), so tracking can get more aggressive.
var _villain_spotted := false
var _synergy_damage_mult := 1.0
var _synergy_cooldown_reduction := 0.0
## Run-scoped ability cooldown reduction from signature boons (RunState). Stacks
## additively with the synergy/formation reductions at every ability recast.
var _boon_cooldown_reduction := 0.0
## Run-scoped XP multiplier from the "Fortune" boon (RunState). Permanent for
## the current run; stacks multiplicatively with the timed objective XP boost.
var _run_xp_mult := 1.0
## Formation bonuses (recomputed each frame based on nearby hero roles)
var _formation_hp_mult := 1.0
var _formation_damage_mult := 1.0
var _formation_cooldown_reduction := 0.0
## Which specific formation bonus is active (for HUD display; multiple mults
## above can come from different sources, so these disambiguate for the panel).
var _formation_same_role_active := false
var _formation_opposite_tank_active := false
var _formation_opposite_burst_active := false
## Generic pair-bonus flag for HUD display of the non-TANK/BURST pairs
## (CONTROL+SUPPORT, BURST+SUPPORT); the two flags above stay for their
## existing GUARD+/BURST+ labels and any TANK/BURST-specific reads.
var _formation_opposite_active := false
var _formation_trio_active := false
## Max HP before the opposite-role GUARD+ bonus, captured once at spawn so the
## proximity-driven bonus has a stable amount to add/remove from as allies
## move in and out of range (rather than compounding off a moving target).
var _base_max_hp := 0.0
## Extra max HP currently granted by GUARD+; tracked so entering/leaving range
## adjusts both max_hp and hp by exactly this amount, preserving true damage
## taken instead of free-healing or hard-clamping HP away.
var _formation_bonus_hp := 0.0
## Level gates cached at spawn (level doesn't change mid-battle).
var _base_unlocked := false
var _passive_unlocked := false
var _active_unlocked := false
var _second_ability_cd := 0.0

## Per-hero ability descriptor for the HUD — the display name + full cooldown of
## the primary (auto) ability and the LV20 second ability (empty when the hero
## has none). Single source so adding a hero is one entry, matching the same
## data/effect split used by Boons/AbilityMods.
const ABILITY_INFO := {
	"THUNDAAR": {"name": "STOMP", "cd": STOMP_COOLDOWN, "name2": "SHOCKWAVE", "cd2": SHOCKWAVE_COOLDOWN},
	"ARTEMIS": {"name": "CLONE", "cd": CLONE_COOLDOWN, "name2": "MULTISHOT", "cd2": MULTISHOT_COOLDOWN},
	"WARDEN": {"name": "ENSNARE", "cd": ENSNARE_COOLDOWN, "name2": "", "cd2": 0.0},
	"BEACON": {"name": "RALLY", "cd": RALLY_COOLDOWN, "name2": "CONFUSE", "cd2": CONFUSE_COOLDOWN},
}

## Seconds until the hero's special ability (Stomp/Clone) is ready; 0 = ready.
var ability_cooldown: float:
	get:
		return maxf(_ability_cd, 0.0)

## Seconds until the hero's LV20 second ability (Shockwave/Multishot) is ready; 0 =
## ready. Meaningless for heroes with no second ability (see second_ability_name).
var second_ability_cooldown: float:
	get:
		return maxf(_second_ability_cd, 0.0)

## Display name of the hero's primary auto ability (STOMP/CLONE/…) for the HUD.
func ability_name() -> String:
	return ABILITY_INFO.get(hero_name, {}).get("name", "ABILITY")

## Display name of the hero's LV20 second ability, or "" if it has none.
func second_ability_name() -> String:
	return ABILITY_INFO.get(hero_name, {}).get("name2", "")

## Full cooldown duration for this hero's ability (HUD fill-fraction display).
func ability_cooldown_max() -> float:
	return ABILITY_INFO.get(hero_name, {}).get("cd", 1.0)

## Full cooldown duration for the hero's second ability (HUD fill-fraction).
func second_ability_cooldown_max() -> float:
	return maxf(ABILITY_INFO.get(hero_name, {}).get("cd2", 1.0), 0.001)

## Currently active synergy/formation buffs, for the hero panel's buff row.
## Each entry is {text: String, color: Color}; empty when nothing is active.
func active_buffs() -> Array:
	var buffs: Array = []
	if _synergy_damage_mult > 1.0:
		buffs.append({"text": "SYNERGY", "color": Color("6fa8dc")})
	# Distinct chip when actually near the chosen support target (vs. the
	# generic SYNERGY that any nearby ally grants), so the bond reads at a glance.
	if priority == "SUPPORT_ALLIES" and support_target != "":
		var target := _support_target_node()
		if target != null and global_position.distance_to(target.global_position) <= FOLLOW_CHIP_DIST:
			buffs.append({"text": "FOLLOWING", "color": Color("5cc98a")})
	if _formation_same_role_active:
		buffs.append({"text": "ROLE DMG+", "color": Color("e08a3e")})
	if _formation_opposite_tank_active:
		buffs.append({"text": "GUARD+", "color": Color("5c9a5c")})
	if _formation_opposite_burst_active:
		buffs.append({"text": "BURST+", "color": Color("c0392b")})
	if _formation_opposite_active:
		buffs.append({"text": "PAIR+", "color": Color("5c9ac9")})
	if _formation_trio_active:
		buffs.append({"text": "TRIO CD", "color": Color("d4c04a")})
	if _dmg_boost_t > 0.0:
		buffs.append({"text": "DMG+", "color": Color("c0392b")})
	if _speed_boost_t > 0.0:
		buffs.append({"text": "SPD+", "color": Color("4aa3df")})
	if _atk_speed_boost_t > 0.0:
		buffs.append({"text": "ATK SPD+", "color": Color("e0b03e")})
	if _xp_boost_t > 0.0:
		buffs.append({"text": "XP+", "color": Color("6fcf6f")})
	if shield_charges > 0:
		buffs.append({"text": "SHIELD x%d" % shield_charges, "color": Color("9bd1e5")})
	return buffs

## Short human-readable label of what this hero is doing right now, for the HUD
## panel — so the pre-battle priority/pairing choices are legible while the
## battle plays out. Derived entirely from existing state (no new bookkeeping).
func current_intent() -> String:
	match priority:
		"SUPPORT_ALLIES":
			# Buffing the party while an ally is alive; solo it falls back to the
			# villain push (see the SUPPORT_ALLIES block in _process).
			return "SUPPORTING" if _nearest_ally() != null else "PUSHING"
		"CAPTURE_OBJECTIVES":
			if not _pushed_on and _objective != null:
				return "CAPTURING" if _objective_spotted else "SEARCHING"
			return "PUSHING"
		"ATTACK_MINIONS":
			# Trading blows with a minion vs. moving to the next one to farm.
			return "FARMING" if _target != null and is_instance_valid(_target) else "HUNTING"
		_:  # ATTACK_VILLAIN (and any default)
			if _target != null and is_instance_valid(_target) and _target.is_in_group("villains"):
				return "ATTACKING"
			return "PUSHING"

func _configure() -> void:
	self_group = "heroes"
	enemy_group = "hostiles"
	label_text = hero_name
	# Heroes recompute separation every frame (there are only ≤3) so they settle
	# at a stable spacing instead of bouncing off a stale push — matters most for
	# a support hero trying to hold beside its target ally (see Combatant).
	separation_per_frame = true
	# Set fixed role based on hero name.
	match hero_name:
		"THUNDAAR": role = "TANK"
		"ARTEMIS": role = "BURST"
		"WARDEN": role = "CONTROL"
		"BEACON": role = "SUPPORT"
	# Apply hero-specific flat base stats (Milestone 2: no persistent scaling —
	# a run always starts here; growth comes only from in-run boons).
	if hero_name in HERO_STATS:
		var stats: Dictionary = HERO_STATS[hero_name] as Dictionary
		max_hp = float(stats.get("base_hp", 100.0))
		damage = float(stats.get("base_damage", 10.0))
		if stats.has("attack_interval"):
			attack_interval = stats["attack_interval"] as float
		if stats.has("move_speed"):
			move_speed = stats["move_speed"] as float
		# Ranged is data-driven now (Milestone 5): any hero with is_ranged fires
		# the shared projectile instead of meleeing — no per-hero special-case.
		if stats.get("is_ranged", false):
			is_ranged = true
			attack_range = float(stats.get("attack_range", attack_range))
			projectile_scene = ARTEMIS_PROJECTILE_SCENE
	max_hp *= V2_HP_MULT
	damage *= V2_DAMAGE_MULT
	# Permanent ability mods bought with gold (Phase 5). Applied here, before
	# Combatant sets hp = max_hp, so HP-changing mods land at full HP; run boons
	# (in-run, reset each run) still stack on top of this via apply_run_boon.
	_apply_owned_ability_mods()
	# Permanent raw-stat upgrades bought with banked XP (grind progression).
	_apply_stat_upgrades()
	_base_max_hp = max_hp
	# Tier-gates the passive upgrade and the LV20 ultimate behind gold
	# purchases (AbilityTiers); tier 1 (the signature ability) is always
	# free the moment a hero is unlocked.
	_base_unlocked = true
	_passive_unlocked = GameState.has_tier(hero_name, 2)
	_active_unlocked = GameState.has_tier(hero_name, 3)
	# Spawn at the funnel; default goal is the villain's corner.
	global_position = _field.hero_spawn + lateral
	set_goal(_villain_goal())
	# Priority-specific behavior.
	match priority:
		"ATTACK_VILLAIN":
			# Push straight for the villain and stay locked on regardless of
			# his kiting — the villain lock is handled in _acquire_target via
			# VILLAIN_ENGAGE_RANGE, NOT via detect_range. Keep detect_range a
			# tight minion leash (attack_range * 1.3, per DECISIONS.md
			# 2026-07-14) so this priority "only fights what blocks the way"
			# instead of aggroing every minion within the wide villain range.
			detect_range = attack_range * 1.3
		"ATTACK_MINIONS":
			# Hunt the swarm for XP — the farm priority (GDD's "Attack Minions").
			# Full-reach detect range (a ranged hero should aggro out to its own
			# attack_range, not the tighter melee default) and a live re-goal onto
			# the nearest hostile (see the ATTACK_MINIONS tracking block in
			# _process). Never pushes the villain or takes objectives.
			detect_range = maxf(detect_range, attack_range * 1.1)
		"SUPPORT_ALLIES":
			# Range with the party (see the _process tracking block): a wide detect
			# range so a support inside the leash band actively engages minions
			# ("importantly killing minions"), not just orbiting its partner.
			# Falls back to the villain push when solo.
			detect_range = attack_range * 2.0
		"CAPTURE_OBJECTIVES":
			# Tight engagement range while on objective duty: this hero is on a
			# mission to the objective, not free to get dragged off chasing
			# every minion that wanders within normal detect range.
			detect_range = attack_range * 1.3
			_objective = _nearest_uncaptured_objective(global_position)
			if _objective != null:
				# The hero only knows the objective's general area until it's
				# close enough to spot it — head to a fuzzed point nearby and
				# search from there rather than beelining the exact spot.
				_pick_objective_search_point()
			else:
				# No objectives left uncaptured at spawn: skip straight to the
				# villain push with the same tight minion leash as ATTACK_VILLAIN
				# (villain lock lives in _acquire_target, not detect_range).
				_pushed_on = true
				detect_range = attack_range * 1.3

func _process(delta: float) -> void:
	# Update synergy state before calling super (which applies combat).
	_update_synergy()
	_update_formation()
	super(delta)
	if _dying:
		return
	_stomp_flash_t = maxf(_stomp_flash_t - delta, 0.0)
	_ensnare_flash_t = maxf(_ensnare_flash_t - delta, 0.0)

	# Ranged heroes (Artemis) can lock onto a minion from well outside melee
	# range and then never move again — super() only calls _advance_goal when
	# there's no target, so a stationary ranged hero would snipe that minion
	# forever and never close in enough to bring the villain within
	# detect_range. While actively pushing the villain, keep closing toward
	# him even mid-fight, same as a melee hero is forced to by walking up to
	# its target.
	#
	# Only fires while the current target is already IN attack range (i.e.
	# super()'s _engage this frame just attacked and didn't move her) — when
	# the target is still out of range, _engage already advances her toward it
	# every frame, and calling _advance_goal here too stacked a second full
	# move_speed*delta step on top of that one, visibly speeding her up
	# whenever she spotted something (e.g. a spawn point) still out of range.
	#
	# Also excludes spawn_points: `goal` gets set to the spawn point's exact
	# center (below, once one's within SPAWN_POINT_ENGAGE_RANGE) rather than a
	# general villain-ward direction, so _advance_goal walked a ranged hero
	# straight onto the gate's center — right past the attack_range she'd
	# correctly stopped at in _engage — instead of holding at range.
	if is_ranged and _stun_t <= 0.0 and _target != null and not _target.is_in_group("villains") \
			and not _target.is_in_group("spawn_points") and (_objective == null or _pushed_on) \
			and not _is_capturing() and global_position.distance_to(_target.global_position) <= attack_range:
		_advance_goal(delta)

	# Capture priority: still searching for the objective (hasn't spotted the
	# exact spot yet) — check whether it's now within view.
	if _objective != null and not _objective_spotted and not _pushed_on:
		if global_position.distance_to(_objective.global_position) <= OBJECTIVE_VIEW_RADIUS:
			_objective_spotted = true
			# No lateral offset here: lateral spaces heroes out for the long
			# villain push, but the objective is a small fixed point — adding
			# it can push the goal outside capture_radius, parking the hero
			# beside the marker instead of on it.
			set_goal(_objective.global_position)

	# Capture priority: once the current objective is taken, move on to the
	# next uncaptured one (if any); only push to the villain once none remain.
	if not _pushed_on and _objective != null and _objective.is_captured:
		var next_objective := _nearest_uncaptured_objective(global_position)
		if next_objective != null:
			_objective = next_objective
			_objective_spotted = false
			_pick_objective_search_point()
		else:
			_pushed_on = true
			detect_range = attack_range * 1.3
			set_goal(_villain_goal())

	# Capture commitment: once the objective is spotted, finish it before doing
	# anything else. Re-assert the objective as the goal whenever the hero has
	# strayed past capture_radius (combat drift can walk it off the point — it
	# still ATTACKS what's in range, which is needed to clear the `contested`
	# state, it just won't wander away). The focus-ping override below still
	# supersedes this ("unless overwritten by player command").
	if _is_capturing() and global_position.distance_to(_objective.global_position) > _objective.capture_radius:
		set_goal(_objective.global_position)

	# Rally-to-ally: still SEARCHING for an objective (not yet committed to
	# capturing a spotted one) with no threat currently in sight — head toward
	# whichever ally is actively fighting something instead of wandering alone.
	if priority == "CAPTURE_OBJECTIVES" and not _pushed_on and not _is_capturing() and _target == null:
		_rally_cd -= delta
		if _rally_cd <= 0.0:
			_rally_cd = RALLY_CHECK_INTERVAL
			var ally := _find_engaged_ally()
			if ally != null:
				_rallying = true
				set_goal(ally.global_position)
			elif _rallying:
				# The ally we were rallying to stopped fighting (or died) —
				# resume the normal objective search pattern.
				_rallying = false
				if _objective != null and not _objective_spotted:
					_pick_objective_search_point()
				elif _objective != null:
					set_goal(_objective.global_position)
	elif _rallying:
		_rallying = false

	# SUPPORT_ALLIES: fight alongside the party as an individual, not glued to
	# its hip. Re-path toward the chosen support target (or, absent one / if it's
	# dead, the nearest living ally) ONLY when drifted past SUPPORT_LEASH_DIST;
	# inside that band, let normal target selection / _advance_goal drive it (the
	# SCORE_SUPPORT_GUARD bias already pulls its fire toward whatever is hitting
	# its partner) and, with nothing to fight, drift toward the ally's actual
	# fight via _find_engaged_ally so it doesn't idle. No allies at all (solo) →
	# fall through to the villain push below so the support still contributes.
	if priority == "SUPPORT_ALLIES":
		_support_track_cd -= delta
		if _support_track_cd <= 0.0:
			_support_track_cd = SUPPORT_TRACK_INTERVAL
			var ally: Combatant = _support_target_node() if support_target != "" else null
			if ally == null:
				ally = _nearest_ally()
			if ally == null:
				set_goal(_villain_goal())
			elif global_position.distance_to(ally.global_position) > SUPPORT_LEASH_DIST:
				# Drifted too far — close the gap back into the band.
				set_goal(_standoff_point(ally))
			elif _target == null:
				# In-band and idle: move toward the ally's fight, else hold near it.
				var engaged := _find_engaged_ally()
				set_goal((engaged if engaged != null else ally).global_position)

	# ATTACK_MINIONS (farm): keep walking into the swarm by re-goaling onto the
	# nearest live minion so the hero always has something to chase and farm,
	# rather than beelining a stale point. When the field is momentarily clear of
	# minions, drift toward the villain goal so the battle can still resolve (the
	# hero never actually engages him — the leash detect_range keeps him off).
	if priority == "ATTACK_MINIONS":
		_minion_track_cd -= delta
		if _minion_track_cd <= 0.0:
			_minion_track_cd = VILLAIN_TRACK_INTERVAL
			var prey := _nearest_hostile()
			if prey != null:
				set_goal(prey.global_position)
			else:
				set_goal(_villain_goal())

	# While pushing toward the villain (not holding at an uncaptured
	# objective, not shadowing the party as support, and not farming the
	# swarm), keep re-aiming at his live position so kiting/teleports don't
	# leave heroes marching on his original spawn point.
	if (_objective == null or _pushed_on) and priority != "SUPPORT_ALLIES" \
			and priority != "ATTACK_MINIONS":
		# Arms aggressive re-tracking at the villain-lock range (the range at
		# which _acquire_target will actually grab him), not detect_range —
		# detect_range is now just the tight minion leash.
		if not _villain_spotted and global_position.distance_to(_field.villain_pos) <= VILLAIN_ENGAGE_RANGE:
			_villain_spotted = true
		_villain_track_cd -= delta
		if _villain_track_cd <= 0.0:
			_villain_track_cd = VILLAIN_SPOTTED_TRACK_INTERVAL if _villain_spotted else VILLAIN_TRACK_INTERVAL
			# V2 lane structure: keep pushing forward toward the villain by
			# default — only divert onto a spawn point once it's within view
			# (SPAWN_POINT_ENGAGE_RANGE, same radius _acquire_target uses to
			# actually attack one), so heroes don't beeline across the whole
			# lane for a gate nowhere near their path. (No-op in V1 —
			# _nearest_spawn_point() is always null there.)
			var spawn_point := _nearest_spawn_point()
			if spawn_point != null and global_position.distance_squared_to(spawn_point.global_position) \
					<= SPAWN_POINT_ENGAGE_RANGE * SPAWN_POINT_ENGAGE_RANGE:
				set_goal(spawn_point.global_position)
			else:
				set_goal(_villain_goal())

	# Focus ping (player command) overrides the wandering goal set by the priority
	# blocks above: while a ping is live, head toward it. Combatant only advances
	# `goal` when this hero has no combat target, so this rallies FREE heroes to
	# the pinged spot without yanking anyone out of a fight — and _target_score
	# already pulls target choice toward pinged enemies.
	var focus_ping := get_tree().get_first_node_in_group("focus_ping")
	if focus_ping != null and focus_ping.has_active_ping():
		# A ping dropped ON the villain is a "commit to the villain" order: chase
		# his LIVE position (tracking teleports) rather than the static ping spot,
		# and arm the aggressive re-track cadence. _acquire_target locks him as
		# the target on the same condition. Otherwise, rally to the pinged spot.
		if _ping_targets_villain() != null:
			_villain_spotted = true
			set_goal(_villain_goal())
		else:
			set_goal(focus_ping.ping_pos())

	if _base_unlocked:
		_ability_cd -= delta
		if _ability_cd <= 0.0:
			match hero_name:
				"THUNDAAR":
					_try_stomp()
				"ARTEMIS":
					_try_clone()
				"WARDEN":
					_try_ensnare()
				"BEACON":
					_try_rally()

	if _active_unlocked:
		_second_ability_cd -= delta
		if _second_ability_cd <= 0.0:
			match hero_name:
				"THUNDAAR":
					_try_shockwave()
				"ARTEMIS":
					_try_multishot()
				"BEACON":
					_try_confuse()

## Closest uncaptured objective to `from` (e.g. this hero's spawn point).
func _nearest_uncaptured_objective(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for o in get_tree().get_nodes_in_group("objectives"):
		if o.is_captured:
			continue
		var d := from.distance_squared_to(o.global_position)
		if d < best_d:
			best_d = d
			best = o
	return best

## Heads toward a random point within OBJECTIVE_SEARCH_FUZZ of the (not yet
## spotted) objective's true position, so the hero searches its general area
## instead of beelining the exact spot.
func _pick_objective_search_point() -> void:
	if _objective == null:
		return
	var offset := Vector2(
		randf_range(-OBJECTIVE_SEARCH_FUZZ, OBJECTIVE_SEARCH_FUZZ),
		randf_range(-OBJECTIVE_SEARCH_FUZZ, OBJECTIVE_SEARCH_FUZZ))
	set_goal(_objective.global_position + offset)

## Subclass hook (Combatant): reached the current goal. While still searching
## for an unspotted objective, keep wandering with a fresh nearby point.
func _on_goal_reached() -> void:
	if _rallying:
		return
	if _objective != null and not _objective_spotted and not _pushed_on:
		_pick_objective_search_point()

## The villain-chase goal: his live position plus a formation nudge from
## `lateral`, capped so a hero deployed far from the party centroid (the open
## deploy zone allows spreading heroes across the whole field) still chases
## his actual position instead of a phantom point offset by the full deploy
## spread — see VILLAIN_GOAL_LATERAL_CAP.
func _villain_goal() -> Vector2:
	return _field.villain_pos + lateral.limit_length(VILLAIN_GOAL_LATERAL_CAP)

## A point FOLLOW_STANDOFF away from `ally`, on this hero's side of it, so the
## follower stops just off the body instead of ramming into it (which would
## only feed the separation push and cause jitter). Falls back to a fixed
## offset when the two happen to be exactly stacked.
func _standoff_point(ally: Combatant) -> Vector2:
	var away := global_position - ally.global_position
	if away.length() < 0.01:
		away = Vector2(_facing_x, 0.0)
	return ally.global_position + away.normalized() * FOLLOW_STANDOFF

## This hero's live support-target node (by name), or null if unset / dead.
func _support_target_node() -> Hero:
	if support_target == "":
		return null
	for node in get_tree().get_nodes_in_group("heroes"):
		if node is Hero and not node._dying and node.hero_name == support_target:
			return node
	return null

## Nearest live real party member (excludes temporary HeroClone summons), for
## the SUPPORT_ALLIES follow behavior. Null when this is the only hero left.
func _nearest_ally() -> Combatant:
	var best: Combatant = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("heroes"):
		if node == self or not (node is Hero) or not is_instance_valid(node) or node._dying:
			continue
		var d := global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

## Nearest live minion (enemy_group — excludes the villain, who lives in the
## "villains" group), for the ATTACK_MINIONS farm re-goal. Null when the swarm
## is momentarily clear.
## Nearest living V2 spawn point ("spawn_points" group; empty/no-op in V1).
func _nearest_spawn_point() -> Combatant:
	var best: Combatant = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("spawn_points"):
		if not is_instance_valid(node) or node._dying:
			continue
		var d := global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

func _nearest_hostile() -> Combatant:
	var best: Combatant = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying:
			continue
		var d := global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

## Nearest live ally hero currently engaged with an enemy (has a target),
## for the rally-to-ally mechanic. Null if no ally is fighting anything.
func _find_engaged_ally() -> Combatant:
	var best: Combatant = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("heroes"):
		if node == self or not is_instance_valid(node) or node._dying:
			continue
		if node._target == null or not is_instance_valid(node._target) or node._target._dying:
			continue
		var d := global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

## True while this hero is committed to capturing an objective it has already
## spotted (not still searching, not yet captured, not pushed on to the villain).
## Once true, the hero holds the point and won't be pulled off by rally-to-ally
## or combat drift — only a focus ping (player command) overrides it.
func _is_capturing() -> bool:
	return _objective != null and not _pushed_on and _objective_spotted \
			and is_instance_valid(_objective) and not _objective.is_captured


## True while this hero is actively pushing the villain, so _acquire_target
## keeps its villain lock out to the wide VILLAIN_ENGAGE_RANGE (past his flee
## distance) instead of the tight minion leash detect_range now holds. A farming
## or party-shadowing hero returns false, so it isn't yanked onto the villain
## from across the field. (CAPTURE_OBJECTIVES sets _pushed_on true both mid-run
## and at spawn when no objectives remain; SUPPORT falls back to the push solo.)
func _is_pushing_villain() -> bool:
	match priority:
		"ATTACK_MINIONS": return false
		"SUPPORT_ALLIES": return _nearest_ally() == null
		"CAPTURE_OBJECTIVES": return _pushed_on
		_: return true  # ATTACK_VILLAIN (and any default)

## Heroes target the villain over any minion whenever he's within range, so a
## hero standing on top of him doesn't get pulled off onto whichever minion
## happens to be a step closer. Pushers lock him out to VILLAIN_ENGAGE_RANGE
## (past his flee distance); everyone else only grabs him within detect_range.
func _acquire_target() -> void:
	# Player command: a ping on the villain locks him as the target regardless of
	# range — the party commits to him even from across the field (see item 6).
	var pinged_villain := _ping_targets_villain()
	if pinged_villain != null:
		_target = pinged_villain
		return
	# V2 lane structure: a live spawn point within engage range beats both the
	# villain and any ordinary minion (see SPAWN_POINT_ENGAGE_RANGE doc comment).
	var spawn_point := _nearest_spawn_point()
	if spawn_point != null and global_position.distance_squared_to(spawn_point.global_position) \
			<= SPAWN_POINT_ENGAGE_RANGE * SPAWN_POINT_ENGAGE_RANGE:
		_target = spawn_point
		return
	var villain_range := VILLAIN_ENGAGE_RANGE if _is_pushing_villain() else detect_range
	for node in get_tree().get_nodes_in_group("villains"):
		if not is_instance_valid(node) or node._dying:
			continue
		if global_position.distance_squared_to(node.global_position) <= villain_range * villain_range:
			_target = node
			return
	super()

## Player command: the live villain when an active focus ping was dropped on him
## (its point within PING_RADIUS of a villain body), else null. Drives both the
## target lock in _acquire_target and the chase goal in _process — a pinged
## villain is chased/attacked regardless of range, for the ping's lifetime.
func _ping_targets_villain() -> Combatant:
	var ping := get_tree().get_first_node_in_group("focus_ping")
	if ping == null or not ping.has_active_ping():
		return null
	var p: Vector2 = ping.ping_pos()
	for node in get_tree().get_nodes_in_group("villains"):
		if not is_instance_valid(node) or node._dying:
			continue
		if node.global_position.distance_to(p) <= FocusPing.PING_RADIUS:
			return node
	return null

## Hero target preference among the minions within detect_range (the villain is
## handled above, before this ever runs). Base is raw distance in px (nearest
## preferred — the old behavior); each bonus is subtracted so a preferred target
## scores lower. See the SCORE_* constants for what each lever means. Runs on
## the shared RETARGET_INTERVAL tick, not per frame, and the party is tiny, so
## the per-candidate ally scan is cheap.
func _target_score(node: Combatant, dist_sq: float) -> float:
	var score := sqrt(dist_sq)
	score -= _focus_fire_bonus(node)
	score -= _execute_bonus(node) * (BURST_EXECUTE_MULT if role == "BURST" else 1.0)
	score -= _threat_bonus(node) * (BURST_THREAT_MULT if role == "BURST" else 1.0)
	score -= _role_bonus(node)
	score -= _focus_ping_bonus(node)
	if node.is_in_group("spawn_points"):
		score -= SCORE_SPAWN_POINT_PRIORITY
	return score

## Focus ping (player command): bias target choice toward enemies near an active
## ping, full bonus at the ping fading to 0 at its influence radius. Lets the
## player commit the party's fire to a spot without micromanaging each hero.
func _focus_ping_bonus(node: Combatant) -> float:
	var ping := get_tree().get_first_node_in_group("focus_ping")
	if ping == null or not ping.has_active_ping():
		return 0.0
	var influence: float = ping.influence_radius()
	var d := node.global_position.distance_to(ping.ping_pos())
	if d >= influence:
		return 0.0
	return SCORE_FOCUS_PING * (1.0 - d / influence)

## Focus fire: SCORE_FOCUS_FIRE per living ally (real heroes + clones share the
## "heroes" group and both carry _target) already locked onto this candidate.
func _focus_fire_bonus(node: Combatant) -> float:
	var allies_on_it := 0
	for ally in get_tree().get_nodes_in_group("heroes"):
		if ally == self or not is_instance_valid(ally) or ally._dying:
			continue
		if ally._target == node:
			allies_on_it += 1
	return SCORE_FOCUS_FIRE * allies_on_it

## Execute: full SCORE_EXECUTE for a candidate this hero could finish within
## SCORE_EXECUTE_HITS of its own hits, fading linearly to 0 at that HP threshold.
## Uses this hero's effective (synergy/formation/boon-scaled) damage so the
## judgement matches the damage it will actually deal.
func _execute_bonus(node: Combatant) -> float:
	var per_hit := damage * _synergy_damage_mult * _formation_damage_mult * damage_mult()
	if per_hit <= 0.0:
		return 0.0
	var threshold := per_hit * SCORE_EXECUTE_HITS
	if node.hp >= threshold:
		return 0.0
	return SCORE_EXECUTE * (1.0 - node.hp / threshold)

## Threat: reward attacking things that hurt (per-damage weight) and things that
## out-range this hero (they plink from outside our reach if left alone).
func _threat_bonus(node: Combatant) -> float:
	var bonus := SCORE_THREAT_PER_DAMAGE * node.damage
	if node.attack_range > attack_range:
		bonus += SCORE_THREAT_OUTRANGE
	return bonus

## Role tactics layer: each role nudges targeting toward what that role should
## do. BURST needs no term here — its bias is the execute/threat multipliers
## applied in _target_score. TANK peels onto the endangered ally's attacker,
## CONTROL seeks the densest cluster (best Ensnare anchor), SUPPORT guards the
## ally it's pledged to.
func _role_bonus(node: Combatant) -> float:
	match role:
		"TANK":
			# Peel: prefer whatever is near the most-endangered ally (lowest HP
			# fraction), scaled by proximity to that ally — so Thundaar bodies up
			# what's beating on Artemis instead of his own nearest minion.
			var ally := _weakest_ally()
			if ally == null:
				return 0.0
			var d := node.global_position.distance_to(ally.global_position)
			if d >= TANK_PEEL_RADIUS:
				return 0.0
			return SCORE_TANK_PEEL * (1.0 - d / TANK_PEEL_RADIUS)
		"CONTROL":
			# Prefer the candidate with the most enemy neighbors within
			# ENSNARE_RADIUS, so _target (Ensnare's anchor) roots a full pack.
			return SCORE_CONTROL_CLUSTER * _enemy_neighbors(node)
		"SUPPORT":
			# Low aggression: only really cares about whatever is attacking the
			# ally it's protecting (its support_target, else nearest ally).
			var guarded: Combatant = _support_target_node()
			if guarded == null:
				guarded = _nearest_ally()
			if guarded != null and node._target == guarded:
				return SCORE_SUPPORT_GUARD
			return 0.0
		_:
			return 0.0

## Living real party member (not a clone) with the lowest HP fraction, for the
## TANK peel. Null when this tank is the only real hero left.
func _weakest_ally() -> Hero:
	var best: Hero = null
	var best_frac := INF
	for node in get_tree().get_nodes_in_group("heroes"):
		if node == self or not (node is Hero) or not is_instance_valid(node) or node._dying:
			continue
		var frac: float = node.hp / node.max_hp if node.max_hp > 0.0 else 1.0
		if frac < best_frac:
			best_frac = frac
			best = node
	return best

## How many other live enemies sit within ENSNARE_RADIUS of `node` — the size of
## the cluster Ensnare would catch if this candidate were the anchor.
func _enemy_neighbors(node: Combatant) -> int:
	var count := 0
	for e in get_tree().get_nodes_in_group(enemy_group):
		if e == node or not is_instance_valid(e) or e._dying:
			continue
		if e.global_position.distance_to(node.global_position) <= ENSNARE_RADIUS:
			count += 1
	return count

## Apply synergy damage multiplier to actual damage dealt. Also widens melee
## reach against a spawn point: LaneSpawnPoint (V2 only) is a hard obstacle
## (see LaneField.dynamic_obstacles), so the field's collision clamp already
## pins every unit's center at `target.body_radius + _collision_radius()` away
## from it — for a melee hero that floor (~73px) sits past the base 26px
## attack_range, so without this a melee hero gets walked up to the gate and
## pinned there, unable to ever land a hit (ranged heroes clear the gap fine
## already). Widening attack_range to match the forced stand-off distance lets
## melee heroes hit from the ring they're already standing at, not "inside" it.
func _engage(delta: float) -> void:
	var scaled_damage := damage * _synergy_damage_mult * _formation_damage_mult * damage_mult()
	var original_damage := damage
	var original_range := attack_range
	damage = scaled_damage
	if _target != null and _target.is_in_group("spawn_points"):
		attack_range = maxf(attack_range, _target.body_radius + _collision_radius() + 6.0)
	super(delta)
	damage = original_damage
	attack_range = original_range

## Floating ability-name callout above the caster — direct visual confirmation
## that an ability just fired, for abilities like Rally that leave no other
## world-space trace (a buff has no shape of its own) and to make every
## ability's proc timing legible in fast real-time play, not just inferable
## from the HUD cooldown bar. Only called from each ability's success branch,
## same gating as the cooldown itself.
func _show_cast_label(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.z_index = 60
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(-24.0, -body_radius - 28.0)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position:y", label.global_position.y - 26.0, 0.7)
	tw.tween_property(label, "modulate:a", 0.0, 0.7)
	tw.set_parallel(false)
	tw.tween_callback(label.queue_free)

## Stomp: hits every enemy within STOMP_RADIUS for damage + knockback.
## Only starts its cooldown once it actually lands (an enemy was in range),
## so it fires the moment one wanders close rather than on a fixed timer.
func _try_stomp() -> void:
	if _target == null:
		return
	var stomp_r := STOMP_RADIUS * stomp_radius_mult  # Seismic Stomp mod widens this
	var hit := false
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying:
			continue
		var to_node: Vector2 = node.global_position - global_position
		if to_node.length() <= stomp_r:
			hit = true
			node.take_damage(STOMP_DAMAGE * _synergy_damage_mult * _formation_damage_mult * damage_mult(), self)
			if is_instance_valid(node) and not node._dying:
				node.apply_knockback(to_node.normalized(), STOMP_KNOCKBACK, 0.0, self)
				if _passive_unlocked:
					node.apply_stun(STOMP_STUN_DURATION)
	if hit:
		var cooldown := STOMP_COOLDOWN + stomp_cooldown_add - _synergy_cooldown_reduction - _formation_cooldown_reduction - _boon_cooldown_reduction
		_ability_cd = maxf(cooldown, 0.1)
		_stomp_flash_t = STOMP_FLASH_TIME
		_show_cast_label("STOMP!", STOMP_FLASH_COLOR)

## Ensnare (WARDEN): roots every enemy within ENSNARE_RADIUS of the nearest
## threat (the current target, used as a cluster anchor) so the party can focus
## the locked pack. Only starts its cooldown once it actually catches something,
## so it fires the moment a cluster forms rather than on a fixed timer.
func _try_ensnare() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var anchor: Vector2 = _target.global_position
	var ensnare_r := ENSNARE_RADIUS * ensnare_radius_mult  # Wide Snare mod widens this
	var hit := false
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying:
			continue
		if node.global_position.distance_to(anchor) <= ensnare_r:
			node.apply_stun(ENSNARE_STUN_DURATION * ensnare_stun_mult)
			hit = true
	if hit:
		_ability_cd = maxf(ENSNARE_COOLDOWN - _synergy_cooldown_reduction - _formation_cooldown_reduction - _boon_cooldown_reduction, 0.1)
		_ensnare_flash_t = ENSNARE_FLASH_TIME
		_ensnare_flash_center = anchor
		_show_cast_label("ENSNARE!", ENSNARE_FLASH_COLOR)

## Rally (BEACON): grants every nearby ally (self included) a timed damage +
## attack-speed boost. Reuses the objective-reward buff primitives, so buffed
## allies surface DMG+/ATK SPD+ chips via active_buffs() for free.
##
## Gated on the party actually being in a fight — at least one hero within
## RALLY_RADIUS has a live target (self counts). Rally still fires proactively
## the instant contact starts, but no longer burns its cooldown buffing an
## empty field while the party marches, so it's genuinely ready when a fight
## breaks out. Without this gate the caster's self-buff made it fire on cooldown
## forever regardless of whether anything was happening.
func _try_rally() -> void:
	if not _party_in_combat():
		return
	var rally_r := RALLY_RADIUS * rally_radius_mult  # Mass Rally mod widens this
	var buffed := false
	for node in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(node) or node._dying:
			continue
		if global_position.distance_to(node.global_position) <= rally_r:
			node.apply_damage_boost(RALLY_DURATION, RALLY_DMG_MULT)
			node.apply_atk_speed_boost(RALLY_DURATION, RALLY_ATK_MULT)
			buffed = true
	if buffed:
		_ability_cd = maxf(RALLY_COOLDOWN + rally_cooldown_add - _synergy_cooldown_reduction - _formation_cooldown_reduction - _boon_cooldown_reduction, 0.1)
		_show_cast_label("RALLY!", STATUS_BUFF_COLOR)

## True when any hero within RALLY_RADIUS (self included) currently has a live
## enemy target — i.e. the cluster Rally would buff is actually fighting.
func _party_in_combat() -> bool:
	var rally_r := RALLY_RADIUS * rally_radius_mult
	for node in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(node) or node._dying:
			continue
		if global_position.distance_to(node.global_position) > rally_r:
			continue
		if node._target != null and is_instance_valid(node._target) and not node._target._dying:
			return true
	return false

## Draws ability rings on top of the base Combatant art: Stomp's expanding
## shockwave (caster-centered) and Ensnare's root pulse (drawn at the cluster
## anchor, converted to this node's local space), each while its flash runs.
func _draw() -> void:
	super()
	if _stomp_flash_t > 0.0:
		var p := 1.0 - _stomp_flash_t / STOMP_FLASH_TIME
		var ring_color := STOMP_FLASH_COLOR
		ring_color.a *= 1.0 - p
		draw_arc(Vector2.ZERO, STOMP_RADIUS * stomp_radius_mult * p, 0.0, TAU, 32, ring_color, 4.0, true)
	if _ensnare_flash_t > 0.0:
		var p := 1.0 - _ensnare_flash_t / ENSNARE_FLASH_TIME
		var ring_color := ENSNARE_FLASH_COLOR
		ring_color.a *= 1.0 - p
		draw_arc(_ensnare_flash_center - global_position, ENSNARE_RADIUS * ensnare_radius_mult * (0.4 + 0.6 * p), 0.0, TAU, 32, ring_color, 4.0, true)

## Clone: spawns clone_count temporary copies of Artemis's current stats that
## taunt and fight back for CLONE_DURATION, then expire (see HeroClone). Twin
## Clone mod raises clone_count to 2 (each at clone_hp_mult HP).
func _try_clone() -> void:
	if _target == null:
		return
	for i in clone_count:
		# Fan multiple clones to alternating sides so they don't stack on one spot.
		var side := 1.0 if i % 2 == 0 else -1.0
		_spawn_clone(side * (1.0 + float(i / 2)))
	var cooldown := CLONE_COOLDOWN - _synergy_cooldown_reduction - _formation_cooldown_reduction - _boon_cooldown_reduction
	_ability_cd = maxf(cooldown, 0.1)
	_show_cast_label("CLONE!", body_color)

## Builds one clone offset to `spread` (in CLONE_SPAWN_OFFSET units, signed left/right).
func _spawn_clone(spread: float) -> void:
	var clone := CLONE_SCENE.instantiate()
	clone.label_text = hero_name + " Clone"
	clone.max_hp = max_hp * clone_hp_mult
	var clone_damage_mult := _synergy_damage_mult * _formation_damage_mult * damage_mult() * (CLONE_DAMAGE_BOOST if _passive_unlocked else 1.0)
	clone.damage = damage * clone_damage_mult
	clone.attack_interval = attack_interval
	clone.attack_range = attack_range
	clone.is_ranged = is_ranged
	clone.projectile_scene = projectile_scene
	clone.projectile_speed = projectile_speed
	clone.detect_range = detect_range
	clone.knockback_chance = knockback_chance
	clone.knockback_distance = knockback_distance
	clone.knockback_splash_damage = knockback_splash_damage
	clone.move_speed = move_speed
	clone.body_radius = body_radius
	clone.sprite_texture = sprite_texture
	clone.sprite_scale = sprite_scale
	clone.body_color = body_color
	clone.is_taunting = true
	clone.taunt_radius = CLONE_TAUNT_RADIUS
	clone.life_span = CLONE_DURATION
	clone.caster = self
	clone.role = role
	clone.follow_offset = Vector2(_facing_x * spread, 0.0) * CLONE_SPAWN_OFFSET
	get_parent().add_child(clone)
	clone.global_position = global_position + clone.follow_offset

## Shockwave (LV20 unlock, Thundaar): a wide line in front of him, hitting
## everything within SHOCKWAVE_RANGE / SHOCKWAVE_HALF_WIDTH for heavy damage
## and knockback. Auto-casts toward the current target's direction.
func _try_shockwave() -> void:
	if _target == null:
		return
	var dir := (_target.global_position - global_position).normalized()
	var hit := false
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying:
			continue
		var to_node: Vector2 = node.global_position - global_position
		var forward := to_node.dot(dir)
		if forward < 0.0 or forward > SHOCKWAVE_RANGE:
			continue
		var lateral_dist := (to_node - dir * forward).length()
		if lateral_dist > SHOCKWAVE_HALF_WIDTH:
			continue
		hit = true
		node.take_damage(SHOCKWAVE_DAMAGE * _synergy_damage_mult * _formation_damage_mult * damage_mult(), self)
		if is_instance_valid(node) and not node._dying:
			node.apply_knockback(dir, SHOCKWAVE_KNOCKBACK, 0.0, self)
	if hit:
		_second_ability_cd = maxf(SHOCKWAVE_COOLDOWN - _synergy_cooldown_reduction - _formation_cooldown_reduction, 0.1)
		_show_cast_label("SHOCKWAVE!", Color(1.0, 0.6, 0.2))

## Confuse (ultimate, BEACON): projects a cone of light toward the nearest
## enemy cluster. Every minion caught in the cone is confused for
## CONFUSE_DURATION — it turns on its own kind. Villains are immune (a boss
## can't be trivially neutralized). Fires only when the cone catches at least
## CONFUSE_MIN_TARGETS eligible minions, and starts its cooldown only on a
## landed cast (same pattern as Stomp). No damage — pure control.
func _try_confuse() -> void:
	# Aim at the current combat target, or the nearest enemy if idle, so the
	# cone points into the swarm rather than off into empty space.
	var aim: Combatant = _target
	if aim == null or not is_instance_valid(aim):
		aim = _nearest_in_group(enemy_group)
	if aim == null:
		return
	var dir := (aim.global_position - global_position).normalized()
	var caught: Array[Combatant] = []
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying:
			continue
		if node.is_in_group("villains"):
			continue  # Bosses are immune to Confuse.
		var to_node: Vector2 = node.global_position - global_position
		var forward := to_node.dot(dir)
		if forward < 0.0 or forward > CONFUSE_RANGE:
			continue
		var lateral_dist := (to_node - dir * forward).length()
		if lateral_dist > CONFUSE_HALF_WIDTH:
			continue
		caught.append(node)
	if caught.size() < CONFUSE_MIN_TARGETS:
		return
	for node in caught:
		node.apply_confusion(CONFUSE_DURATION)
	_second_ability_cd = maxf(CONFUSE_COOLDOWN - _synergy_cooldown_reduction - _formation_cooldown_reduction, 0.1)
	_show_cast_label("CONFUSE!", STATUS_CONFUSE_COLOR)

## Nearest living member of `group` to this hero, at any distance (unlike the
## detect-range _acquire_target). Used to aim Confuse when BEACON is idle.
func _nearest_in_group(group: String) -> Combatant:
	var nearest: Combatant = null
	var best := INF
	for node in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(node) or node._dying:
			continue
		var dist: float = global_position.distance_squared_to(node.global_position)
		if dist < best:
			best = dist
			nearest = node
	return nearest

## Multishot (LV20 unlock, Artemis): fires a simultaneous volley of arrows —
## the same Projectile her basic attack uses — at up to MULTISHOT_MAX_TARGETS
## nearby enemies. Stationary (Designer call: no movement-type abilities), so
## unlike the old Dash it never repositions the hero; range/target-count carry
## over from Dash's budget, with each arrow doing reduced damage since several
## can land at once.
func _try_multishot() -> void:
	if _target == null:
		return
	var to_target := _target.global_position - global_position
	if to_target.length() > MULTISHOT_RANGE:
		return
	var candidates: Array[Combatant] = []
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying:
			continue
		if global_position.distance_squared_to(node.global_position) <= MULTISHOT_RANGE * MULTISHOT_RANGE:
			candidates.append(node)
	candidates.sort_custom(func(a, b):
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	var hit_count := 0
	for node in candidates:
		if hit_count >= MULTISHOT_MAX_TARGETS:
			break
		_fire_multishot_arrow(node)
		hit_count += 1
	if hit_count > 0:
		_second_ability_cd = maxf(MULTISHOT_COOLDOWN - _synergy_cooldown_reduction - _formation_cooldown_reduction, 0.1)
		_show_cast_label("MULTISHOT!", Color(0.9, 0.5, 0.8))

## Spawns one Multishot arrow at `victim` — same Projectile scene/behavior as
## Combatant._fire_projectile, but with the volley's reduced per-shot damage
## instead of a full attack hit.
func _fire_multishot_arrow(victim: Combatant) -> void:
	var proj: Projectile = ARTEMIS_PROJECTILE_SCENE.instantiate()
	proj.damage = damage * MULTISHOT_DAMAGE_MULT * _synergy_damage_mult * _formation_damage_mult * damage_mult()
	proj.attacker = self
	proj.target = victim
	proj.enemy_group = _effective_enemy_group()
	proj.speed = projectile_speed
	proj.max_range = MULTISHOT_RANGE
	proj.color = body_color
	proj.global_position = global_position
	get_parent().add_child(proj)

## Check synergy: if another living hero is nearby, apply bonuses.
func _update_synergy() -> void:
	var has_ally := false
	for node in get_tree().get_nodes_in_group("heroes"):
		if node != self and is_instance_valid(node) and not node._dying:
			if global_position.distance_to(node.global_position) <= SYNERGY_DISTANCE:
				has_ally = true
				break
	if has_ally:
		_synergy_damage_mult = SYNERGY_DAMAGE_MULT
		_synergy_cooldown_reduction = SYNERGY_COOLDOWN_REDUCTION
	else:
		_synergy_damage_mult = 1.0
		_synergy_cooldown_reduction = 0.0

## Check formation bonuses: calculate role-based bonuses based on nearby heroes.
func _update_formation() -> void:
	_formation_hp_mult = 1.0
	_formation_damage_mult = 1.0
	_formation_cooldown_reduction = 0.0
	_formation_same_role_active = false
	_formation_opposite_tank_active = false
	_formation_opposite_burst_active = false
	_formation_opposite_active = false
	_formation_trio_active = false

	var nearby_heroes = []
	var same_role_count = 0

	for node in get_tree().get_nodes_in_group("heroes"):
		if node != self and is_instance_valid(node) and not node._dying:
			nearby_heroes.append(node)

	# Check for same-role cluster (2+ of same role within 150px)
	for hero in nearby_heroes:
		if global_position.distance_to(hero.global_position) <= FORMATION_SAME_ROLE_DIST:
			if hero.role == role:
				same_role_count += 1

	if same_role_count >= 1:  # At least one other of same role nearby
		_formation_damage_mult = FORMATION_SAME_ROLE_DAMAGE
		_formation_same_role_active = true

	# Check for opposite-role pairing within 200px. Data-driven via
	# FORMATION_PAIRS so every role has a partner (not just TANK+BURST); first
	# match wins (break) so a hero never stacks two pair bonuses.
	var my_pairs: Dictionary = FORMATION_PAIRS.get(role, {})
	for hero in nearby_heroes:
		if global_position.distance_to(hero.global_position) <= FORMATION_OPPOSITE_ROLE_DIST:
			if my_pairs.has(hero.role):
				var stat: String = my_pairs[hero.role]
				if stat == "hp":
					_formation_hp_mult = FORMATION_OPPOSITE_ROLE_MULT
				else:
					_formation_damage_mult = FORMATION_OPPOSITE_ROLE_MULT
				# Keep the TANK/BURST-specific flags for their existing HUD
				# labels; other pairs use the generic flag.
				if role == "TANK":
					_formation_opposite_tank_active = true
				elif role == "BURST" and hero.role == "TANK":
					_formation_opposite_burst_active = true
				else:
					_formation_opposite_active = true
				break

	# Check for mixed trio (3+ heroes with different roles within 180px)
	if nearby_heroes.size() >= 2:
		var role_set: Array[String] = [role]
		var mixed_in_range = 1
		for hero in nearby_heroes:
			if global_position.distance_to(hero.global_position) <= FORMATION_MIXED_TRIO_DIST:
				if not role_set.has(hero.role):
					role_set.append(hero.role)
				mixed_in_range += 1
		if role_set.size() >= 3 and mixed_in_range >= 3:
			_formation_cooldown_reduction = FORMATION_MIXED_TRIO_COOLDOWN
			_formation_trio_active = true

	# Apply GUARD+ to max_hp/hp by the exact delta so entering/leaving range
	# adds or removes only the bonus amount, never touching real damage taken.
	var target_bonus_hp := _base_max_hp * (_formation_hp_mult - 1.0)
	if not is_equal_approx(target_bonus_hp, _formation_bonus_hp):
		var delta := target_bonus_hp - _formation_bonus_hp
		_formation_bonus_hp = target_bonus_hp
		max_hp += delta
		hp = clampf(hp + delta, 1.0, max_hp)

## Killing blows earn XP (banked immediately — kept even on a wipe); the rest
## of the party banks an assist share so tanks/screeners progress too.
## Synergy multiplier: both heroes earn bonus XP when in range.
func _on_kill(victim: Combatant) -> void:
	var xp_amount := victim.xp_value
	# Synergy multiplier.
	if _synergy_damage_mult > 1.0:
		xp_amount = int(xp_amount * SYNERGY_XP_MULT)
	xp_amount = int(xp_amount * xp_mult() * _run_xp_mult)
	GameState.award_kill_xp(self, xp_amount)

## Run-scoped XP multiplier (Fortune boon): applied to kill XP in _on_kill and
## to objective shares in BattleManager._on_objective_captured.
func run_xp_mult() -> float:
	return _run_xp_mult

## Applies every permanent ability mod this hero owns (GameState.owned_mods,
## bought with gold — see AbilityMods). Called once from _configure. Each mod is
## a bought-once, owned-forever tradeoff (upside + downside).
func _apply_owned_ability_mods() -> void:
	for id in GameState.owned_mods:
		if AbilityMods.def(id).get("hero", "") == hero_name:
			_apply_ability_mod(id)

## Permanent raw-stat upgrades bought with banked XP (V2 grind, StatUpgrades
## catalog) — flat stacking per purchase (1.0 + effect * purchases), applied on
## top of the V2 base multipliers/ability mods, before _base_max_hp is captured.
## Attack Speed reduces attack_interval (lower = faster) rather than scaling it up.
func _apply_stat_upgrades() -> void:
	var hp_n := GameState.stat_purchase_count(hero_name, "hp")
	var dmg_n := GameState.stat_purchase_count(hero_name, "damage")
	var aspd_n := GameState.stat_purchase_count(hero_name, "attack_speed")
	max_hp *= 1.0 + float(StatUpgrades.def("hp").get("effect_per_purchase", 0.0)) * hp_n
	damage *= 1.0 + float(StatUpgrades.def("damage").get("effect_per_purchase", 0.0)) * dmg_n
	if aspd_n > 0:
		attack_interval /= 1.0 + float(StatUpgrades.def("attack_speed").get("effect_per_purchase", 0.0)) * aspd_n

## Effect of one ability mod. Stat tradeoffs touch base stats directly (like
## boons); ability-geometry tradeoffs set the scalar vars the ability code reads.
func _apply_ability_mod(id: String) -> void:
	# Downsides disabled for now (Designer, 2026-07-18) — commented out, not
	# deleted, so the tradeoff design can return once Level 1 tuning settles.
	match id:
		"seismic_stomp":
			stomp_radius_mult *= 1.6
			# stomp_cooldown_add += 1.5
		"iron_skin":
			max_hp *= 1.25
			# move_speed *= 0.85
		"twin_clone":
			clone_count += 1
			# clone_hp_mult *= 0.6
		"glass_arrows":
			damage *= 1.30
			# max_hp *= 0.80
		"wide_snare":
			ensnare_radius_mult *= 1.5
			# ensnare_stun_mult *= 0.7
		"overcharge":
			attack_interval *= 0.80
			# move_speed *= 0.85
		"mass_rally":
			rally_radius_mult *= 1.5
			# rally_cooldown_add += 2.0
		"zealot":
			damage *= 1.40
			# max_hp *= 0.75

## Applies a run boon (RunState / Boons catalog) live to this hero. Boons are
## direct base-stat changes so they compose with the synergy/formation
## multipliers already applied in _engage and the ability functions. Permanent
## for the current run; reset when the next run spawns a fresh hero.
func apply_run_boon(id: String) -> void:
	var d := Boons.def(id)
	if d.is_empty():
		return
	match d.get("kind", ""):
		"damage_mult":
			damage *= float(d.value)
		"max_hp_mult":
			# Multiply the formation-free base (not max_hp, which may include a
			# live GUARD+ bonus — scaling that would permanently bake part of a
			# temporary proximity buff into the base) and grant/heal the same
			# absolute gain; _update_formation re-derives its bonus off the new
			# base on the next frame.
			var gain: float = _base_max_hp * (float(d.value) - 1.0)
			_base_max_hp *= float(d.value)
			max_hp += gain
			hp = minf(hp + gain, max_hp)
		"atk_interval_mult":
			attack_interval *= float(d.value)
		"move_speed_mult":
			move_speed *= float(d.value)
		"xp_mult":
			_run_xp_mult *= float(d.value)
		"ferocity":
			damage *= float(d.get("dmg", 1.0))
			attack_interval *= float(d.get("atk", 1.0))
		# Signature (hero-specific) boon kinds — reuse the same scalar vars the
		# gold ability mods drive, so the ability code needs no new plumbing.
		"stomp_radius_mult":
			stomp_radius_mult *= float(d.value)
		"ensnare_radius_mult":
			ensnare_radius_mult *= float(d.value)
		"rally_radius_mult":
			rally_radius_mult *= float(d.value)
		"clone_count_add":
			clone_count += int(d.value)
		"ability_cooldown_reduction":
			_boon_cooldown_reduction += float(d.value)
