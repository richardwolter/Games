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
##
## Duo behavior (2026-07-20, unified 2026-07-20, leader/follower layer added
## 2026-07-20): each hero behaves identically regardless of WHICH hero it's
## paired with — no partner-role tweaks (that per-partner-role matrix caused
## Warden's targeting bug and was removed). A confirmed Duo pairing
## (GameState.duo_pairings) has exactly two effects: (1) the generic Duo Bonus
## (DUO_* consts, _update_duo_bonus) — a damage/cooldown/XP multiplier scaled
## by leader-vs-follower, a pure player choice (which Duo slot the hero was
## dropped in — see GameState.is_duo_leader, NOT role); (2) an optional per-hero
## leader/follower behavior (THUNDAAR_LEADER_*/ARTEMIS_LEADER_* consts,
## _bodyguard_target/_role_bonus's BURST case) keyed ONLY on (hero_name,
## leader-vs-follower) — never on the partner's identity, so this second layer
## can't grow into the same conflict. Currently: THUNDAAR leads = attack speed
## (balance-qa 2026-07-20: was also +damage, cut back — compounded with the
## generic Duo Bonus for a ~10x-everyone-else's DPS swing), follows =
## bodyguards the leader; ARTEMIS leads = HP + faster
## Clone, follows = focus-fires the leader's target. WARDEN/BEACON have no
## extra layer yet (generic Duo Bonus only).
##  THUNDAAR (TANK)    — walks toward the biggest threat and stomps everything close.
##  ARTEMIS  (BURST)   — kites at max range, focuses low-HP targets.
##  WARDEN   (CONTROL) — ensnares the densest cluster near the front line.
##  BEACON   (SUPPORT) — follows its partner and pulses Rally when both are engaged.

@export var hero_name := "HERO"
## Small offset so party members stand side by side, not overlapping.
@export var lateral := Vector2.ZERO
## Hero behavior mode: currently only ATTACK_VILLAIN (default, push the lane)
## or CAPTURE_OBJECTIVES (hold objectives, then push) are implemented.
## SUPPORT_ALLIES (Duo-driven leashing) and ATTACK_MINIONS (farm) were removed
## 2026-07-20 when Duo cohesion and lane splits made them redundant.
@export var priority := "ATTACK_VILLAIN"

## Duo Bonus (explicit pairing bonus, leader/follower scaled)
## Only applies when this hero is in a confirmed Duo pairing with a live partner
## within range. Replaces the old Synergy + Formation systems (which were
## opportunistic + role-based); now entirely deterministic on pairing status.
const DUO_DISTANCE := 200.0
const DUO_LEADER_DAMAGE_MULT := 1.15
const DUO_LEADER_COOLDOWN_REDUCTION := 0.3
const DUO_LEADER_XP_MULT := 1.25
const DUO_FOLLOWER_DAMAGE_MULT := 1.10
const DUO_FOLLOWER_COOLDOWN_REDUCTION := 0.2
const DUO_FOLLOWER_XP_MULT := 1.15

## Per-hero Duo leader/follower behavior (2026-07-20+): a second, additive
## layer on top of the generic Duo Bonus above. Keyed ONLY on (hero_name,
## leader-vs-follower) — never on the partner's specific identity/role — so
## the matrix stays small (4 heroes × 2 states, most left at "no extra
## behavior") and can't reintroduce the partner-role conflict matrix that
## caused Warden's targeting bug (see DECISIONS.md). Tunable independently of
## DUO_LEADER_*/DUO_FOLLOWER_* above. Undefined hero/state combos (currently
## WARDEN, BEACON) get the generic Duo Bonus only.
const THUNDAAR_LEADER_ATK_SPEED_MULT := 1.20
const ARTEMIS_LEADER_HP_MULT := 1.25
const ARTEMIS_LEADER_CLONE_COOLDOWN_MULT := 0.75
## Follower BURST (Artemis) target-score bonus for whatever the Duo leader is
## currently fighting — mirrors the SCORE_* weighting scale used elsewhere.
const SCORE_ARTEMIS_FOLLOWER_FOCUS_LEADER := 140.0

## Thundaar's Stomp: auto-casts on cooldown whenever an enemy is in range,
## hitting everything within STOMP_RADIUS for damage + knockback.
##
## Ability-cadence pass (Designer, 2026-07-24): STOMP_KNOCKBACK used to exceed
## STOMP_RADIUS (100 > 70), so a hit enemy was shoved OUTSIDE the stomp
## circle, walked back in, and got shoved again — a perpetual repel loop that
## was the real reason Thundaar "hardly gets swarmed," not the cooldown.
## Knockback now stays inside the radius; cooldown/damage trimmed alongside it
## since the old throughput (~44 power/sec, see BALANCE.md) was ~2.6x every
## other signature ability.
const STOMP_COOLDOWN := 5.0
const STOMP_RADIUS := 70.0
const STOMP_DAMAGE := 22.0
const STOMP_KNOCKBACK := 45.0
## Ring VFX: how long the expanding-shockwave draw lasts after a landed stomp.
## 0.25 -> 0.45 (Designer, 2026-07-26: the burst wasn't registering at all).
## A quarter second is under a fifth of the time the Stomp's own cooldown gives
## it, and in a busy swarm fight it passed as a flicker.
const STOMP_FLASH_TIME := 0.45
## CANARY, lifted — Thundaar's own accent pigment, drawn over the field.
const STOMP_FLASH_COLOR := Color(0.94, 0.90, 0.22, 0.9)
## Hand-drawn Stomp impact art, drawn by BattleFX.draw_burst in _draw.
const STOMP_BURST := preload("res://assets/sprites/Stomp_Circle_Color.png")
## draw_burst fits the whole texture, and the colored art carries much more
## transparent margin than the original — without this the impact ring would
## draw at 60% of the damage area it is supposed to match. Same reasoning as
## LaneField.ART_PAD_COMPENSATION; StompWave applies the identical factor.
const STOMP_BURST_PAD := 1.57
## BEACON+WARDEN "Searing Bind" Ultimate art. Held on the caster (like the
## Stomp/Ensnare flashes) rather than spawned as a node — the field is a few
## floats and a hit-list, not enough to own a scene.
const SEARING_BURST := preload("res://assets/sprites/Searing_Bind_Color.png")
## Padding compensation, same reason as STOMP_BURST_PAD above.
const SEARING_BURST_PAD := 2.48
## How long the bind stays LIVE on the ground after the cast (Designer,
## 2026-07-26). It was a single instantaneous snapshot of whoever happened to be
## in radius; now it lingers and catches anything that walks in during the
## window, which is what makes the bigger radius worth having.
const SEARING_FIELD_TIME := 3.0
## How long the art keeps blinking over a bound unit — the duration of the
## effect it is marking (see the burn_duration param), so the mark disappears
## when the burn does rather than on its own unrelated timer.
const SEARING_MARK_TIME := 5.0
## Blink cadence of that mark, in seconds per on/off cycle. Short on purpose
## (Designer, 2026-07-26: "blinking over targets more often") — the old single
## 0.6s fade read as one flash and was gone.
const SEARING_BLINK_PERIOD := 0.24
## Floor/ceiling of the blink so the mark never fully vanishes mid-effect (a
## bound unit must stay legibly bound) and never sits at full opacity long
## enough to hide the sprite under it.
const SEARING_BLINK_MIN_ALPHA := 0.25
const SEARING_BLINK_MAX_ALPHA := 0.95

## Searing Bind's cast SFX (Designer, 2026-07-26): the 3.551-4.542s slice of a
## 64.8s source file. The rest of that recording is a low-level sustained
## sizzle, so the explicit window is what makes this a cast rather than a
## minute of room tone.
##
## No negative volume offset here, unlike every other combat clip: this take
## measures far quieter than the rest of the SFX set, and trimming it further
## would put the cast under the fight instead of over it.
const SEARING_SOUND: AudioStream = preload("res://assets/Sounds/Searing_Burn.wav")
const SEARING_SOUND_START := 3.551
const SEARING_SOUND_DURATION := 4.542 - 3.551
const SEARING_SOUND_VOLUME_DB := 0.0
## Bind art size per bound unit, as a multiple of that unit's collision radius
## — big enough to wrap the body, small enough that a packed cluster still
## reads as several separate binds.
const SEARING_MARK_SIZE_MULT := 2.6

## Artemis's Clone: auto-casts on cooldown, spawning a temporary copy of
## herself (see HeroClone) that taunts and fights back for CLONE_DURATION.
##
## Ability-cadence pass (2026-07-24): base Clone throughput actually measured
## lowest of the four signatures — what makes it feel dominant is
## twin_focus (boon, +1) and twin_clone (mod, +1) BOTH stacking to 3
## simultaneous clones. See MAX_CLONE_COUNT below for the fix; duration/
## cooldown widened here so casts are rarer but each one is more present.
const CLONE_SCENE := preload("res://scenes/heroes/hero_clone.tscn")

## Clone art (Designer, 2026-07-26). The plain Clone ability uses the silhouette
## archer; the ARTEMIS+THUNDAAR Ultimate's clones carry a visible bomb, so a
## player can tell at a glance which kind is standing in front of them — the two
## behave completely differently (one taunts, one detonates).
##
## Both drawings sit smaller on their shared 936x601 canvas than the hero art
## does on its own, and draw fits the WHOLE canvas to the unit's size — hence a
## multiplier on top of the caster's sprite_scale rather than reusing it raw.
## Clone summon SFX (Designer, 2026-07-26). Played once per CAST, not once per
## clone — see _play_clone_creation. The source file has dead air either side
## of the take, hence the explicit slice.
const CLONE_CREATION_SOUND: AudioStream = preload("res://assets/Sounds/Clone_Creation.wav")
const CLONE_CREATION_START := 0.635
const CLONE_CREATION_DURATION := 1.6 - 0.635
const CLONE_CREATION_VOLUME_DB := -6.0

## Every clone ability summons through here so the sound fires exactly once
## however many bodies appear (Designer, 2026-07-26). Two clones spawning on
## the same frame each playing the clip would phase into one louder, muddier
## sound rather than reading as two summons — and the player already sees the
## count.
func _play_clone_creation() -> void:
	BattleSfx.play_clip(self, CLONE_CREATION_SOUND, CLONE_CREATION_START,
			CLONE_CREATION_DURATION, CLONE_CREATION_VOLUME_DB)

const CLONE_ART := preload("res://assets/sprites/Artemis_Clone.png")
const CLONE_ART_SCALE_MULT := 2.1
const VOLATILE_CLONE_ART := preload("res://assets/sprites/Volatile_Duplicates.png")
const VOLATILE_CLONE_ART_SCALE_MULT := 1.7
const CLONE_COOLDOWN := 9.0
## Halved 2026-07-26 (Designer: clones should last much less). The solo Clone's
## taunt window only — the two Ultimates that spawn clones pass their own
## clone_life_span through _build_clone and are deliberately untouched (the
## Volatile fuse and the Hunting Duplicates' long roam are what those Ultimates
## ARE). Clone uptime against its 9s cooldown drops from ~55% to ~28%, so the
## decoy is a moment of relief rather than a near-permanent extra body.
const CLONE_DURATION := 2.5
const CLONE_TAUNT_RADIUS := 90.0
## Spawn offset so the clone appears beside Artemis (toward her facing) instead
## of stacked exactly on top of her, where it's indistinguishable at a glance.
## Now applied around DuoAim's chosen anchor rather than around Artemis herself
## — see _place_clone.
const CLONE_SPAWN_OFFSET := 40.0
## How far from Artemis a clone may be placed when a better spot exists
## (Designer, 2026-07-26: clones should appear somewhere strategic — near
## minions, a spawn point or the villain — instead of always at her side).
##
## Deliberately shorter than her attack_range: a clone is a decoy that has to
## pull aggro off HER, so it must land between Artemis and the fight, not
## teleport across the lane into a pack she was never near. Also bounded by
## HeroClone's own leash back to its caster.
const CLONE_SPAWN_RANGE := 220.0
## Hard cap on simultaneous clones regardless of source (base 1 + twin_focus
## boon + twin_clone mod would otherwise reach 3) — applied where clone_count
## is consumed in _try_clone, not at the mod/boon sites, so both are covered
## by one guard.
const MAX_CLONE_COUNT := 2

## WARDEN's Ensnare (Controller signature): auto-casts on cooldown, rooting
## every enemy in a radius around the nearest threat (the current target,
## used as a cluster proxy) so the DPS can focus the locked pack.
##
## Ability-cadence pass (2026-07-24): Ensnare was the only signature ability
## dealing literally zero damage (pure CC), which measured as the weakest
## power/sec in the kit. Now also applies a flat vulnerability (Designer:
## "all damage deals 2 more damage" — additive, not a %, matching the house
## style set by RALLY_DMG_ADD) so Warden's contribution shows up in the
## party's damage numbers instead of only in prevented damage. Stun duration
## extended slightly so the party gets a real window to capitalize.
## 4.5 -> 5.2 -> 6.2 across two passes on 2026-07-26 (Designer, +0.7s then +1s):
## the longer the gap between roots, the more of the swarm's advance a Warden
## has to let through rather than holding the whole lane on permanent lockdown.
const ENSNARE_COOLDOWN := 6.2
const ENSNARE_RADIUS := 95.0
const ENSNARE_STUN_DURATION := 1.6
const ENSNARE_VULN_DMG_ADD := 2.0
## Tier-2 passive (previously unimplemented — see _passive_unlocked doc):
## a stronger vulnerability add plus a wider root.
const ENSNARE_PASSIVE_VULN_DMG_ADD := 3.0
const ENSNARE_PASSIVE_RADIUS_ADD := 25.0
## Ensnare's ground burst, drawn at the cluster anchor the same way Stomp's is
## drawn at the caster's feet (Designer, 2026-07-26) — replaces the plain
## expanding draw_arc this used to be.
const ENSNARE_BURST := preload("res://assets/sprites/Warden_Ensnare_Circle.png")
## Padding compensation, same idea as STOMP_BURST_PAD: the drawing covers a bit
## over half its canvas.
const ENSNARE_BURST_PAD := 1.8
const ENSNARE_FLASH_TIME := 0.45
## FOREST, lifted for visibility over sprites — Ensnare is roots and Warden is
## drawn in leaf green, so the ring matches what the ability actually is. (Was
## a teal that existed only because Warden's old identity colour was teal.)
const ENSNARE_FLASH_COLOR := Color(0.30, 0.76, 0.38, 0.9)

## BEACON's Rally (Support signature): auto-casts on cooldown, granting every
## nearby ally (self included) a timed damage + attack-speed boost. Reuses the
## objective-reward buff primitives (Combatant.apply_damage_boost /
## apply_atk_speed_boost), so the buffed allies show DMG+/ATK SPD+ chips for
## free via active_buffs().
##
## Ability-cadence pass (2026-07-24): the old gate (_party_in_combat, any ally
## with any live target) was true almost continuously in a swarm fight, so
## Rally was constantly spent on trash. See _rally_worth_casting for the
## stricter gate; duration/cooldown widened so a held cast pays off bigger.
const RALLY_COOLDOWN := 8.0
const RALLY_RADIUS := 180.0
const RALLY_DURATION := 5.0
## Flat additive Rally buff (Designer, 2026-07-21: no percentages on upgrades/
## abilities — a player should read "+2 damage" and know exactly what that
## means, regardless of which hero receives it). Converted to the underlying
## multiplicative boost API per-buffed-hero in _try_rally, since that API
## (Combatant.apply_damage_boost/apply_atk_speed_boost) is shared game-wide.
const RALLY_DMG_ADD := 2.0
const RALLY_ATK_INTERVAL_REDUCTION := 0.2
## Rally only fires when the party is in a fight worth buffing — see
## _rally_worth_casting. Any of: this many+ living enemies in radius, the
## villain alerted, or an ally below this HP fraction.
const RALLY_MIN_ENEMIES := 3
const RALLY_LOW_HP_FRAC := 0.6
## Tier-2 passive (previously unimplemented — see _passive_unlocked doc):
## Rally also top-ups each buffed ally's HP.
const RALLY_PASSIVE_HEAL := 8.0

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
## own flee_distance (see dark_mage.gd) with margin, otherwise he kites just
## outside detect range and _acquire_target keeps dropping him as _target
## before a hero ever gets close enough to land a hit.
const VILLAIN_ENGAGE_RANGE := 320.0

## Destructible minion spawn points ("spawn_points" group). Killing one
## permanently stops its waves, which matters more than any single minion or
## even the still-dormant villain — locked at a wide range like the villain
## push, and outscores everything else in _target_score, so heroes go destroy
## the swarm's source instead of just farming whatever wanders past. (Except
## something already in melee/firing range, or an ordinary minion that's
## simply closer than the gate right now — see the nearby-swarm interrupt and
## the "on the way" check in _acquire_target, both of which run first.)
const SPAWN_POINT_ENGAGE_RANGE := 500.0
const SCORE_SPAWN_POINT_PRIORITY := 400.0

## Nearby swarm interrupt (Designer, 2026-07-20: "heroes are ignoring minions
## and taking unnecessary damage" — the spawn-point/villain locks above were
## absolute, so a hero would walk right past an adjacent minion already
## hitting them to beeline a gate 480px away). A hostile within this bubble is
## already blocking the path or actively engaging, so it's swatted first; the
## long-range lock resumes on its own next retarget tick once it's dead (see
## _acquire_target). Scales off attack_range (floored) so a ranged hero's
## naturally wider engagement bubble also clears more of the swarm on the way,
## not just melee heroes standing on top of a minion.
const NEARBY_THREAT_INTERRUPT_MULT := 1.5
const NEARBY_THREAT_INTERRUPT_MIN := 90.0

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
## of every run; see _configure's unconditional _base/_passive_unlocked.
## (Solo LV20 "second abilities" — Shockwave/Multishot/Confuse — were retired
## 2026-07-22 in favor of Duo Ultimates; see DuoUltimates/cast_duo_ultimate.)
const STOMP_STUN_DURATION := 0.5
## NO LONGER APPLIED (2026-07-24, ability-cadence pass): _build_clone was
## explicitly changed to strip this from clone damage — a clone should deal
## Artemis's "regular" unbuffed damage, not an ability-boosted one. Left
## un-deleted only so ability_tiers.gd's ARTEMIS_2 ("Mirror Image", 40g,
## "Clone deals +50% damage") stays truthful about what it currently does —
## nothing. FLAGGED, not fixed: this purchase is now dead, same bug class as
## the WARDEN_2/BEACON_2 gap fixed earlier this pass. Needs a Designer call:
## repurpose (e.g. onto Artemis's own damage) or pull from sale.
const CLONE_DAMAGE_BOOST := 1.5  ## +50%, unused — see note above.

## Cooldown boons are flat-subtractive and stack unboundedly (aftershock/
## fleetfoot/rapid_snare/quick_rally, each -1.0s, re-pickable across levels)
## on top of the Duo leader/follower reduction, floored previously at only a
## flat 0.1s — three boon picks + Duo leader could crush Stomp to a 0.2s
## permanent damage aura. Ability-cadence pass (2026-07-24): floor every
## re-arm at a fraction of its OWN base cooldown instead, so heavier
## abilities can't be cooldown-boonstacked into a near-continuous aura while
## lighter ones keep a sane minimum too.
const ABILITY_COOLDOWN_FLOOR_FRAC := 0.4

## -- Duo partner behavior (2026-07-20) ----------------------------------------
## Static role-per-hero table (mirrors the hero_name match in _configure) so a
## partner's role can be looked up from GameState.duo_of() alone — no need for
## the partner to have spawned yet (staggered Duo deploy means it often hasn't).
const ROLE_BY_HERO := {
	"THUNDAAR": "TANK",
	"ARTEMIS": "BURST",
	"WARDEN": "CONTROL",
	"BEACON": "SUPPORT",
}
## One-sentence pitch per hero — surfaced on the prep screen's hero cards so the
## Duo-composition decision is informed without needing to read this file.
##
## Designer copy, 2026-07-26. These used to describe each hero's targeting RULE
## (who they walk at, who they focus); they now describe what the hero DOES,
## matching the card's new attack-mode/ability line above them. The old
## behavioural wording lives on in the class doc bullets, which is where it
## belongs — the card is a pitch, not a spec.
const ROLE_DESCRIPTIONS := {
	"THUNDAAR": "Stomps the ground dealing AoE damage.",
	"ARTEMIS": "Shoots fast and creates clones.",
	"WARDEN": "Traps enemies in vines.",
	"BEACON": "Rallies DUO to battle.",
}
## Duo cohesion (Designer, 2026-07-20): "DUOs should stick together and share
## a goal; heroes should not go solo, only after his DUO perished." Which of
## the pair leads a push vs. follows is a pure player choice now (see
## GameState.is_duo_leader — whichever hero was dropped in the Duo's left/A
## slot leads), not derived from role.
## How far the follower can drift from the leader before re-pathing back in —
## tighter than the old generic SUPPORT_LEASH_DIST (260) so pairing reads as
## visibly "together" on the field, not just loosely in the same area.
##
## Loosened 90 -> 180 (Designer, 2026-07-31: "extend leash between DUOs, they
## should stick together but have more freedom of movement for both heroes").
## Still well under the old 260, so a pair still reads as a pair, but each hero
## now has room to pick its own target and reposition without the hard snap-back
## in _process yanking it off mid-approach.
const DUO_LEASH_DIST := 180.0
const DUO_TRACK_INTERVAL := 0.3
## Extra distance a ranged SUPPORT follower hangs back behind its leader,
## beyond the leader's own body — Designer, 2026-07-21: a ranged support
## should stand behind whoever it's supporting, not glued flush against them
## like a melee follower.
##
## Absolute standoff, not "DUO_LEASH_DIST + 70" as it was written before — when
## the leash was loosened to 180 (2026-07-31) that formula would have pushed
## ranged supports to 250 behind the leader AND given them 180 of slack on top.
## 160 is exactly where they stood under the old 90 leash; only the slack grew.
const RANGED_SUPPORT_TRAIL_DIST := 160.0

## Role-identity colors for the battlefield ring + name-tag (see _draw and
## the label_text assignment in _configure) — lets a role be read at a
## glance without opening a hero panel.
## Role colours, kept as their own set rather than mirroring HERO_CATALOG: a
## role is a category a future hero can join, so it must not be locked to one
## hero's art. All four are still sprite pigments (UIStyle), just assigned by
## what the role reads as rather than by who currently fills it.
const ROLE_COLORS := {
	"TANK": UIStyle.NAVY,
	"BURST": UIStyle.CRIMSON,
	"CONTROL": UIStyle.FOREST,
	"SUPPORT": UIStyle.GOLD,
}

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
## its confirmed Duo partner (else nearest ally if unpaired).
const SCORE_SUPPORT_GUARD := 220.0
## Focus ping (player command): strong target-selection pull toward enemies near
## an active ping, fading with distance to the ping (see _focus_ping_bonus). Sized
## above the other tactical bonuses so a deliberate ping wins the target choice.
const SCORE_FOCUS_PING := 260.0

## Hero-specific flat base stats (Milestone 2: no more persistent per-purchase
## scaling — a hero always starts a run here; growth comes only from in-run
## permanent gold/XP purchases and the Duo Ultimate, not from per-hero boons
## (that catalog was removed 2026-07-25 — see duo_ultimate_boons.gd).
##
## Optional ranged keys (Milestone 5): `is_ranged` + `attack_range` make a hero
## fire a Projectile instead of meleeing — read generically in _configure (no
## per-hero special-casing). `attack_interval` overrides the hero.tscn default.
## Global hero-power tuning: the grindy lane loop assumes a slow climb via
## boons/mods/upgrades, not day-one power. Applied on top of HERO_STATS in
## _configure — the table itself is untouched. The prep and STATS pages mirror
## these so displayed stats match what actually spawns.
const BASE_HP_MULT := 0.5
const BASE_DAMAGE_MULT := 0.5

## All heroes move at the same speed (Designer, 2026-07-20) — previously
## per-hero speeds let Duo partners drift apart just from walking; a shared
## speed plus the shortened DUO_LEASH_DIST keeps pairs visibly together.
const HERO_MOVE_SPEED := 90.0

const HERO_STATS: Dictionary = {
	"THUNDAAR": {
		"base_hp": 110,
		"base_damage": 10,
		"attack_interval": 0.7,
		"move_speed": HERO_MOVE_SPEED,
	},
	"ARTEMIS": {
		"base_hp": 80,
		"base_damage": 6,
		"move_speed": HERO_MOVE_SPEED,
		"is_ranged": true,
		"attack_interval": ARTEMIS_ATTACK_INTERVAL,
		"attack_range": ARTEMIS_ATTACK_RANGE,
	},
	# WARDEN — Controller (ranged): roots enemy clusters with Ensnare. Squishier
	# than the DPS, medium range so it controls from the mid-line.
	"WARDEN": {
		"base_hp": 90,
		"base_damage": 6,
		"move_speed": HERO_MOVE_SPEED,
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
		"move_speed": HERO_MOVE_SPEED,
	},
}

## Per-hero sprite art, swapped in per hero_name in _configure(). hero.tscn
## sets Thundaar's art as its own sprite_texture default, so an unlisted
## hero_name renders as Thundaar rather than as nothing.
##
## All four are hand-drawn in the shared papercut style (cream torn-paper
## cutout, dark ink linework — see BALANCE.md/PRODUCTION.md for the pipeline).
## THUNDAAR_SPRITE below and hero.tscn's sprite_texture must always name the
## same file: the const is what DeployController's pre-spawn ghost reads.
const HERO_SPRITES: Dictionary = {
	"ARTEMIS": preload("res://assets/sprites/Artemis_Color.png"),
	"WARDEN": preload("res://assets/sprites/Warden_Color.png"),
	"BEACON": preload("res://assets/sprites/Beacon_Color.png"),
}
## hero.tscn's own sprite_texture default — the fallback for any hero_name not
## in HERO_SPRITES (currently only Thundaar). Preloaded explicitly here so
## DeployController's sprite ghost doesn't need a live Hero instance to know
## which texture a not-yet-spawned hero will use.
const THUNDAAR_SPRITE := preload("res://assets/sprites/Thundaar_Color.png")

## Per-hero multiplier on top of hero.tscn's base sprite_scale (1.8) — lets
## individual hero art run bigger without changing every hero's size
## (Designer, 2026-07-25: Thundaar 2x, Warden 1.5x).
## Every value here now carries a padding-compensation factor on top of the
## Designer's own size choice: the *_Color art (2026-07-25) sits on a uniform
## canvas with far more transparent margin, and Combatant._draw fits the WHOLE
## texture to body_radius * 2 * sprite_scale. Swapping the art 1:1 shrank the
## heroes on screen (Thundaar to 73% of his previous size, Artemis/Beacon to
## 64%); these restore the sizes that were already established.
##   THUNDAAR 1.7 x1.375, WARDEN 1.5 x1.381, ARTEMIS x1.554, BEACON x1.558.
const SPRITE_SCALE_MULT: Dictionary = {
	"THUNDAAR": 2.34,
	"WARDEN": 2.07,
	"ARTEMIS": 1.55,
	"BEACON": 1.56,
}

## Party-wide art boost on top of the per-hero table above (Designer,
## 2026-07-30: "make hero sprites 1.3x bigger than current"). Kept as its own
## factor rather than folded into SPRITE_SCALE_MULT's four numbers so the
## per-hero relative sizing stays readable as the Designer's own choice plus its
## documented padding compensation.
##
## PURELY visual: body_radius (the collision/footprint source — see
## SpriteFootprint and Combatant._draw) is untouched, so heroes draw bigger
## without changing how they collide, separate or get hit.
const ART_SCALE_BOOST := 1.3

## Which texture `hero_name` renders with once spawned — used by
## DeployController for the pre-battle sprite ghost/preview.
static func sprite_for(hero_name: String) -> Texture2D:
	return HERO_SPRITES.get(hero_name, THUNDAAR_SPRITE)

## Melee sword-hit SFX (Designer, 2026-07-24): the source file is 5 back-to-
## back sword-stab recordings; picking a random start each swing gives some
## variety instead of the exact same clip every hit. Playback is stopped
## after SWORD_HIT_DURATION — comfortably under the ~1.1s smallest gap
## between starts — so one hit's tail never bleeds into the next clip.
const SWORD_HIT_SOUND := preload("res://assets/Sounds/Sword_Stabbing.wav")
const SWORD_HIT_STARTS: Array[float] = [0.336, 1.79, 3.00, 4.19, 5.300]
const SWORD_HIT_DURATION := 1.0

## Plays once when a hero dies (Combatant._die -> _on_died). Ranged and melee
## heroes both get this — only the sword-hit sound above is melee-only.
const DEATH_SOUND := preload("res://assets/Sounds/Death_Hero.wav")
## Clip has dead air up front; starting here lines the audible hit up with
## the death FX instead of playing noticeably late (Designer, 2026-07-25).
const DEATH_SOUND_START := 0.55

## BEACON and ARTEMIS use their own death cry instead of the shared one above
## (Designer, 2026-07-26); THUNDAAR and WARDEN keep DEATH_SOUND. Played from
## 0.0 — unlike Death_Hero.wav, this clip has no dead air to skip past.
const FEMALE_DEATH_SOUND: AudioStream = preload("res://assets/Sounds/Female_Defeat.wav")
const FEMALE_DEATH_HEROES: Array[String] = ["BEACON", "ARTEMIS"]

## Thundaar's Stomp shout (Designer, 2026-07-25): the source file has other
## takes around it, so only the 0.893-2.709 slice is the shout we want — hence
## the explicit start + duration rather than playing the whole file. Fires on a
## LANDED stomp only (see _try_stomp), so it tracks the ability's real cadence
## instead of every attempted cast.
const STOMP_SHOUT_SOUND := preload("res://assets/Sounds/Stomp_Shout.wav")
const STOMP_SHOUT_START := 0.893
const STOMP_SHOUT_DURATION := 2.709 - 0.893
## Stomp fires far faster than this clip is long, so the shout is rate-limited
## on its own timer independent of the ability cooldown — a stomp inside the
## gap still lands and flashes, it just doesn't shout again (Designer,
## 2026-07-25). Deliberately NOT reduced by cooldown boons: the point is that
## the shout stays sparse however fast Stomp itself gets.
const STOMP_SHOUT_GAP := 10.0
## Quieter than the rest of the mix (Designer, 2026-07-25) — it's a recurring
## combat callout, not a one-off event like a hero death.
const STOMP_SHOUT_VOLUME_DB := -8.0

## The impact itself (Designer, 2026-07-26), separate from the shout above:
## Thundaar's own Stomp plays it on a 5s gap, and Seismic Advance plays one per
## landed step (see StompWave).
##
## The source file is 8.9s holding FOUR takes; a random one is picked per play
## so a marching sequence doesn't read as the same sample looped. The take at
## 5.00-6.25s is deliberately absent from this list — the Designer's shout sits
## at 5.081-6.181, inside it, so playing that take would fire a vocal in the
## middle of what should be a pure impact. Starts are the measured onsets of
## the other three.
const SEISMIC_POUND_SOUND: AudioStream = preload("res://assets/Sounds/Seismic_Pound.wav")
const SEISMIC_POUND_STARTS: Array[float] = [0.68, 2.78, 6.98]
## Each take runs ~1.1s before the next; cut just short of that so one pound
## never bleeds into the following take in the file.
const SEISMIC_POUND_DURATION := 1.05
const SEISMIC_POUND_VOLUME_DB := -6.0
## Thundaar's SOLO stomp pounds every Nth landed stomp (Designer, 2026-07-26).
##
## A COUNT, not a seconds gap like STOMP_SHOUT_GAP: the pound is the hit
## landing, so it should track the ability's real rhythm rather than wall-clock
## time. Under a 5s timer, a cooldown-boosted Thundaar stomping every ~2s went
## quiet for entire stretches of stomping — exactly backwards. Counting instead
## means the sound stays locked to a fixed share of hits however fast he swings.
##
## The shout stays on its own seconds-based gap: that one SHOULD stay sparse
## regardless of cadence, which is the whole reason the two are separate.
## Seismic Advance ignores both — every step of the Ultimate pounds.
const STOMP_POUND_EVERY := 2

## A random usable take's start offset. Static so StompWave can pull from the
## same three without duplicating the timestamps.
static func seismic_pound_start() -> float:
	return SEISMIC_POUND_STARTS[randi() % SEISMIC_POUND_STARTS.size()]

## WARDEN's Ensnare and BEACON's Rally callouts (Designer, 2026-07-26). Same
## treatment as the Stomp shout above: fires only on a LANDED cast (the `hit`/
## `buffed` branch), rate-limited on its own timer so cooldown boons can't turn
## either into a continuous loop, and mixed under the rest for the same reason
## — they're recurring combat sounds, not one-off events.
const ENSNARE_SOUND: AudioStream = preload("res://assets/Sounds/Plant_Ensnare.wav")
const ENSNARE_SOUND_GAP := 6.0
const ENSNARE_SOUND_VOLUME_DB := -8.0
const RALLY_SOUND: AudioStream = preload("res://assets/Sounds/RallyAura.wav")
const RALLY_SOUND_GAP := 9.0
const RALLY_SOUND_VOLUME_DB := -8.0

## Fires on every landed melee hit (see Combatant._on_melee_hit doc — ranged
## heroes never reach this since they take the projectile branch instead).
## One-shot player outlives this call and frees itself, same convention as
## Projectile._play_hit_sound.
func _on_melee_hit(_victim: Combatant) -> void:
	var start: float = SWORD_HIT_STARTS[randi() % SWORD_HIT_STARTS.size()]
	BattleSfx.play_clip(self, SWORD_HIT_SOUND, start, SWORD_HIT_DURATION)

func _on_died() -> void:
	# A hero's death is often what ends the battle, so this can start the same
	# frame the results popup pauses the tree — see BattleSfx's doc on why the
	# player it creates is PROCESS_MODE_ALWAYS (Designer, 2026-07-25: "death
	# sound flowing to prep menu").
	if hero_name in FEMALE_DEATH_HEROES:
		BattleSfx.play_clip(self, FEMALE_DEATH_SOUND)
	else:
		BattleSfx.play_clip(self, DEATH_SOUND, DEATH_SOUND_START)

## Artemis: ranged attacker — fires an arrow (Projectile) instead of melee,
## with a much longer attack_range and faster base attack_interval than the
## shared hero.tscn default (0.5s / 26px), traded for lower HP/damage above.
const ARTEMIS_PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")
const ARTEMIS_ATTACK_INTERVAL := 0.4
const ARTEMIS_ATTACK_RANGE := 160.0
## Pre-rotated in the source art so the tip points along the projectile's
## default travel axis (+X) — hence the _Right suffix. Anything replacing this
## file must keep that orientation or every arrow flies sideways.
const ARTEMIS_ARROW_SPRITE := preload("res://assets/sprites/Arrow_Right.png")

## WARDEN's shot art (Designer, 2026-07-25) — the Controller lobs a plant
## rather than firing a dart, which also reads as the source of the ensnare.
## Unlike the arrow this needs no pre-rotation: a plant has no tip, so it
## looks correct at whatever angle the projectile travels.
const WARDEN_PLANT_SPRITE := preload("res://assets/sprites/Plant_Color.png")

## Art size per hero, along the sprite's longest edge (Projectile.sprite_length).
## The arrow is a thin dart and the plant a squat blob, so they can't share one
## size and both look right — the plant runs smaller or it reads as a flying
## bush next to a 22px-radius hero.
const ARTEMIS_ARROW_LENGTH := 32.0
## 26 -> 52: Projectile.sprite_length fits the whole texture along its longest
## edge, and Plant_Color's drawing covers only half its canvas — doubling keeps
## the thrown plant the size it has always been on screen.
const WARDEN_PLANT_LENGTH := 52.0

## Only Artemis and Warden get sprite art on their shots — every other ranged
## Combatant (e.g. Dark Mage's bolt) keeps Projectile's plain line+circle
## placeholder.
##
## Also called by HeroClone._configure_projectile for a clone's own shots, so a
## clone fires the same art as the hero it was cloned from rather than the
## placeholder (Designer, 2026-07-25).
func _configure_projectile(proj: Projectile) -> void:
	if hero_name == "ARTEMIS":
		proj.sprite_texture = ARTEMIS_ARROW_SPRITE
		proj.sprite_length = ARTEMIS_ARROW_LENGTH
	elif hero_name == "WARDEN":
		proj.sprite_texture = WARDEN_PLANT_SPRITE
		proj.sprite_length = WARDEN_PLANT_LENGTH

## Fixed role per hero (TANK, BURST, CONTROL) — set in _configure based on hero_name.
var role := "CONTROL"

## Lane ("top"/"bottom") this hero is fighting in — set once at spawn from its
## deploy y-position (LaneField.lane_of), never recomputed (Designer,
## 2026-07-20: split the lane so heroes/minions spread across two fronts
## instead of clustering on one spot). Filters which spawn points/objectives
## this hero will path to (_nearest_spawn_point/_nearest_uncaptured_objective)
## — the villain push itself stays a single shared goal, so lanes naturally
## converge near the lair rather than needing a hard wall.
var lane := "top"

## Ability-mod scalars (gold shop). Default identity; owned mods adjust these
## in _apply_ability_mod() and the ability code reads them in place of the raw
## constants. Permanent per-hero, applied once at _configure. Run-scoped picks
## no longer write here at all — they target the Duo Ultimate instead
## (DuoUltimateBoons, read at cast time). Every radius/count bonus
## here is flat additive (Designer, 2026-07-21: no percentages on upgrades/
## abilities) — a mod and a boon on the same hero simply stack on the same
## `_add` var. `clone_hp_mult`/`ensnare_stun_mult` stay multiplicative: they're
## only ever touched by the currently-disabled ability-mod downsides (see
## _apply_ability_mod's commented-out lines) — kept at identity until that
## tradeoff design returns.
var stomp_radius_add := 0.0
var stomp_cooldown_add := 0.0
var clone_count := 1
var clone_hp_mult := 1.0
var ensnare_radius_add := 0.0
var ensnare_stun_mult := 1.0
var rally_radius_add := 0.0
var rally_cooldown_add := 0.0

## Duo partner state — _partner_role is the confirmed Duo partner's role ("" if
## unpaired), computed once at spawn from the static ROLE_BY_HERO table — cheap
## and available even before the partner itself has spawned (staggered
## deploy). Only ever checked for "" vs. not-"" (paired at all) — nothing
## branches on the partner's SPECIFIC role value (see class doc).
var _partner_role := ""
## True when this hero leads its Duo — a pure player choice (see
## GameState.is_duo_leader, read once at spawn) — or has no confirmed partner
## at all — the latter case makes leader status irrelevant (the cohesion block
## in _process is gated on _partner_role != "" anyway), so defaulting true
## here is just "don't follow anyone" for an unpaired hero.
var _duo_leader := true
## Re-check cadence for the Duo cohesion leash (see _process).
var _duo_track_cd := 0.0

var _objective: Node2D = null
var _objective_spotted := false
var _pushed_on := false
var _ability_cd := 0.0
var _stomp_flash_t := 0.0
## Rate limiter for the Stomp shout SFX only — see STOMP_SHOUT_GAP. Separate
## from _ability_cd so the ability's cadence and the shout's stay independent.
var _stomp_shout_cd := 0.0
## Landed stomps since this hero last pounded — see STOMP_POUND_EVERY. Starts
## at the threshold so the FIRST stomp of a battle always sounds; a hero whose
## opening stomp was silent reads as the ability not having a sound at all.
var _stomps_since_pound := STOMP_POUND_EVERY
## Same idea for the Ensnare / Rally callouts — see ENSNARE_SOUND_GAP.
var _ensnare_sound_cd := 0.0
var _rally_sound_cd := 0.0
## Ensnare ring VFX: timer + the world-space cluster anchor it played on (the
## root lands around the target, not the caster, so the ring is drawn there).
var _ensnare_flash_t := 0.0
var _ensnare_flash_center := Vector2.ZERO
## Live Searing Bind field: a stationary circle at the cast's aim point that
## keeps binding for SEARING_FIELD_TIME. Zero/negative _t means no field.
var _searing_field_t := 0.0
var _searing_field_center := Vector2.ZERO
var _searing_field_radius := 0.0
var _searing_field_ensnare := 0.0
var _searing_field_burn_dur := 0.0
var _searing_field_burn_dps := 0.0
## Instance ids already bound by the CURRENT field. The bind hits each enemy
## once and does not accumulate (Designer, 2026-07-26) — without this list a
## unit standing in the field would be re-rooted and re-burned every frame.
var _searing_field_hit: Dictionary = {}
## One entry per bound enemy: {"node": Combatant, "size": float, "t": float}.
## The art is stamped on EACH of them (Designer, 2026-07-25) instead of one big
## burst over the cluster, so the sprite reads as "these units are bound", and
## it tracks the node rather than a frozen position so the mark rides a unit
## that is still moving. "size" comes from that unit's own body, so a brute
## wears a bigger bind than a minion.
var _searing_marks: Array[Dictionary] = []
var _villain_track_cd := 0.0
## Set once the villain has come within detect range at least once (i.e. the
## hero has actually seen/engaged him), so tracking can get more aggressive.
var _villain_spotted := false
## Duo Bonus (recomputed each frame — see _update_duo_bonus): active only when
## paired with a live, confirmed Duo partner within DUO_DISTANCE. Replaces the
## old separate Synergy (opportunistic proximity) + Formation (role-based)
## systems with one deterministic, pairing-driven bonus.
var _duo_damage_mult := 1.0
var _duo_cooldown_reduction := 0.0
var _duo_xp_mult := 1.0
var _duo_bonus_active := false
## Permanent ability cooldown reduction from the gold shop's cooldown mods
## (AbilityMods: Rolling Quake / Fleetfoot / Rapid Snare / Quick Rally).
## Stacks additively with the Duo Bonus reduction at every ability recast, and
## is floored per-ability by ABILITY_COOLDOWN_FLOOR_FRAC.
##
## Was `_boon_cooldown_reduction`, driven by the per-hero run boons that were
## deleted 2026-07-25 (see duo_ultimate_boons.gd class doc). Repurposed rather
## than removed: all four signature abilities already subtracted it at their
## cast sites, so moving the effect from boons to the shop needed no new
## plumbing.
var _ability_cooldown_reduction := 0.0
## Run-scoped XP multiplier from the "Fortune" boon (RunState). Permanent for
## the current run; stacks multiplicatively with the timed objective XP boost.
var _run_xp_mult := 1.0
## Max HP captured once at spawn, before any Duo Ultimate buff lands — the
## stable baseline the Ultimate's hp_add is measured against.
var _base_max_hp := 0.0
## Permanent-build snapshots of damage/attack_interval — same "before any
## Duo Ultimate ever runs" guarantee as _base_max_hp (captured at the same
## point in _configure, right after mods/stat upgrades/leader mult land).
## Clone reads these instead of the live damage/attack_interval/max_hp vars
## so a clone is unaffected by Rally's temp boost, a Duo Ultimate's permanent
## buff, or the Mirror Image tier-2 passive — see _build_clone doc
## (ability-cadence pass, 2026-07-24: "clone should deal regular damage, not
## be affected by abilities/ultimate").
var _base_damage := 0.0
var _base_attack_interval := 0.0
## Level gates cached at spawn (level doesn't change mid-battle).
var _base_unlocked := false
var _passive_unlocked := false

## Per-hero ability descriptor for the HUD — the display name + full cooldown of
## the primary (auto) ability. Single source so adding a hero is one entry,
## matching the same data/effect split used by Boons/AbilityMods. The old LV20
## solo "second ability" (name2/cd2) was retired 2026-07-22 — see class doc;
## second_ability_name() now always returns "", which already hides the HUD's
## second-ability row (HeroPanelUI.update_display).
const ABILITY_INFO := {
	"THUNDAAR": {"name": "STOMP", "cd": STOMP_COOLDOWN},
	"ARTEMIS": {"name": "CLONE", "cd": CLONE_COOLDOWN},
	"WARDEN": {"name": "ENSNARE", "cd": ENSNARE_COOLDOWN},
	"BEACON": {"name": "RALLY", "cd": RALLY_COOLDOWN},
}

## Seconds until the hero's special ability (Stomp/Clone) is ready; 0 = ready.
var ability_cooldown: float:
	get:
		return maxf(_ability_cd, 0.0)

## Retired with the LV20 solo second ability (2026-07-22) — always "ready"
## (0.0). Kept only so battle_hud.gd's update_display call (which still takes
## these params) doesn't need touching; second_ability_name() returning ""
## already makes the HUD hide this row entirely.
var second_ability_cooldown: float:
	get:
		return 0.0

## Display name of the hero's primary auto ability (STOMP/CLONE/…) for the HUD.
func ability_name() -> String:
	return ability_name_for(hero_name)

## Same lookup without needing a live Hero — the deploy-phase card shows each
## hero's ability before any of them have spawned (HeroPanelUI.set_predeploy).
static func ability_name_for(hero: String) -> String:
	return ABILITY_INFO.get(hero, {}).get("name", "ABILITY")

## "RANGED"/"MELEE" for the prep roster cards (Designer, 2026-07-26: a card
## should say how a hero fights, not what role bucket they sit in). Reads the
## same HERO_STATS.is_ranged key _configure does, so the card can never claim
## a different attack mode than the hero actually spawns with.
static func attack_mode_for(hero: String) -> String:
	return "RANGED" if HERO_STATS.get(hero, {}).get("is_ranged", false) else "MELEE"

## Always "" — solo LV20 second abilities were retired for Duo Ultimates
## (2026-07-22). Kept as a stub so the HUD's existing has_second gate
## (battle_hud.gd / hero_panel_ui.gd) still works with zero changes there.
func second_ability_name() -> String:
	return ""

## Full cooldown duration for this hero's ability (HUD fill-fraction display).
func ability_cooldown_max() -> float:
	return ABILITY_INFO.get(hero_name, {}).get("cd", 1.0)

## Stub — see second_ability_name().
func second_ability_cooldown_max() -> float:
	return 1.0

## Currently active buffs (Duo Bonus + timed boosts), for the hero panel's buff row.
## Each entry is {text: String, color: Color}; empty when nothing is active.
func active_buffs() -> Array:
	var buffs: Array = []
	if _duo_bonus_active:
		buffs.append({"text": "DUO+", "color": Color("6fa8dc")})
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
		"CAPTURE_OBJECTIVES":
			if not _pushed_on and _objective != null:
				return "CAPTURING" if _objective_spotted else "SEARCHING"
			return "PUSHING"
		_:  # ATTACK_VILLAIN (and any default)
			if _target != null and is_instance_valid(_target) and _target.is_in_group("villains"):
				return "ATTACKING"
			return "PUSHING"

func _configure() -> void:
	self_group = "heroes"
	enemy_group = "hostiles"
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
	# Per-hero sprite art (see HERO_SPRITES doc) — hero.tscn's own
	# sprite_texture (Thundaar's) is the fallback for any hero_name not in
	# the dict.
	if hero_name in HERO_SPRITES:
		sprite_texture = HERO_SPRITES[hero_name]
	# NOTE: heroes are NOT pinned to a facing on the battlefield (Designer,
	# 2026-07-30: "do not lock character sprite direction on battle, I asked only
	# on HUD and menus"). A field unit turns to face where it is going and what it
	# is shooting, the same as every other Combatant. The always-east rule applies
	# to the STILL portraits only — HeroPanelUI.PORTRAIT_FACES_RIGHT and
	# UIStyle.hero_portrait.
	sprite_scale *= float(SPRITE_SCALE_MULT.get(hero_name, 1.0)) * ART_SCALE_BOOST
	# Role tag on the field name-tag (Designer, 2026-07-20: "roles should be
	# visually clear") — paired with the role-colored ring in _draw().
	label_text = "%s · %s" % [hero_name, role]
	# Duo partner role (see class doc + ROLE_BY_HERO) — computed before the
	# priority match block below since BEACON's tweak changes `priority`
	# itself, which that block reads.
	_partner_role = ROLE_BY_HERO.get(GameState.duo_of(hero_name), "")
	if _partner_role != "":
		# Leader/follower is a pure player choice now (Designer, 2026-07-20:
		# "tank always leads does not work anymore ... this should be a player
		# decision, even when it does not seem to make sense") — see
		# GameState.is_duo_leader (which slot the player dropped this hero
		# into) and the cohesion block in _process.
		_duo_leader = GameState.is_duo_leader(hero_name)
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
	max_hp *= BASE_HP_MULT
	damage *= BASE_DAMAGE_MULT
	# Permanent skill-tree ranks bought with gold. Applied here, before
	# Combatant sets hp = max_hp, so any HP-touching node lands at full HP.
	_apply_skill_tree()
	# Permanent raw-stat upgrades bought with banked XP (grind progression).
	_apply_stat_upgrades()
	# Duo leader/follower behavior, HP half (see THUNDAAR_LEADER_ATK_SPEED_MULT
	# doc comment for the full table): Artemis gets a flat HP bump while
	# leading her Duo, applied once here like a base stat (before _base_max_hp
	# is captured) rather than dynamically, since leader/follower is fixed for
	# the whole battle once spawned.
	if hero_name == "ARTEMIS" and _partner_role != "" and _duo_leader:
		max_hp *= ARTEMIS_LEADER_HP_MULT
	_base_max_hp = max_hp
	_base_damage = damage
	_base_attack_interval = attack_interval
	# Tier-gates the passive upgrade behind a gold purchase (AbilityTiers);
	# tier 1 (the signature ability) is always free the moment a hero is
	# unlocked. Tier 3 / solo LV20 ultimates were retired (Designer,
	# 2026-07-22: ultimates moved to Duo Ultimates — see DuoUltimates /
	# Hero.cast_duo_ultimate) — _active_unlocked no longer exists.
	_base_unlocked = true
	_passive_unlocked = GameState.has_tier(hero_name, 2)
	# Spawn at the funnel; default goal is the villain's corner.
	global_position = _field.hero_spawn + lateral
	lane = _field.lane_of(global_position)
	_field.mark_lane_populated(lane)
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
	# Update Duo Bonus state before calling super (which applies combat).
	_update_duo_bonus()
	super(delta)
	if _dying:
		return
	# Hold to this hero's own lane half until the merge zone right before the
	# villain (Designer, 2026-07-20: lanes shouldn't merge mid-lane) — runs
	# after super()'s own movement/steering step so nothing above (including
	# Duo cohesion following a partner in the other lane) can walk a hero
	# across the split before then; the follower just holds at the boundary
	# nearest its leader instead of crossing.
	if lane != "":
		global_position = _field.clamp_to_lane(global_position, lane)

	# Duo chain (Designer, 2026-07-21): the goal-based cohesion below only
	# repositions a follower when it's idle/wandering, so two Duo members each
	# absorbed in their own fight could still drift arbitrarily far apart —
	# reported as "Duos separate too much." This is a hard position clamp
	# instead: it runs every frame regardless of combat state and simply never
	# lets the follower end up more than DUO_LEASH_DIST from a live leader,
	# like a taut chain. Follower-only and position-only — the leader is never
	# touched (no mutual pull) and _target/goal are untouched (no yanking
	# either hero out of whatever it's doing; the follower just gets nudged
	# back onto the chain).
	if _partner_role != "" and not _duo_leader:
		var _leash_leader := _duo_partner_node()
		if _leash_leader != null:
			# Ranged SUPPORT clamps to a point trailing behind the leader
			# (see _duo_follow_anchor) instead of the leader's exact position,
			# so the leash doesn't drag it up to melee range.
			var _leash_anchor := _duo_follow_anchor(_leash_leader)
			var _to_leader := _leash_anchor - global_position
			var _leader_dist := _to_leader.length()
			if _leader_dist > DUO_LEASH_DIST:
				global_position += _to_leader / _leader_dist * (_leader_dist - DUO_LEASH_DIST)
				if lane != "":
					global_position = _field.clamp_to_lane(global_position, lane)

	_stomp_shout_cd = maxf(_stomp_shout_cd - delta, 0.0)
	_ensnare_sound_cd = maxf(_ensnare_sound_cd - delta, 0.0)
	_rally_sound_cd = maxf(_rally_sound_cd - delta, 0.0)
	_stomp_flash_t = maxf(_stomp_flash_t - delta, 0.0)
	_ensnare_flash_t = maxf(_ensnare_flash_t - delta, 0.0)
	_tick_searing_bind(delta)

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

	# While pushing toward the villain (not holding at an uncaptured
	# objective), keep re-aiming at his live position so kiting/teleports don't
	# leave heroes marching on his original spawn point.
	if _objective == null or _pushed_on:
		# Arms aggressive re-tracking at the villain-lock range (the range at
		# which _acquire_target will actually grab him), not detect_range —
		# detect_range is now just the tight minion leash.
		if not _villain_spotted and global_position.distance_to(_field.villain_pos) <= VILLAIN_ENGAGE_RANGE:
			_villain_spotted = true
		_villain_track_cd -= delta
		if _villain_track_cd <= 0.0:
			_villain_track_cd = VILLAIN_SPOTTED_TRACK_INTERVAL if _villain_spotted else VILLAIN_TRACK_INTERVAL
			# Keep pushing forward toward the villain by default — only divert
			# onto a spawn point once it's within view (SPAWN_POINT_ENGAGE_RANGE,
			# same radius _acquire_target uses to actually attack one), so heroes
			# don't beeline across the whole lane for a gate nowhere near their
			# path.
			var spawn_point := _nearest_spawn_point()
			if spawn_point != null and global_position.distance_squared_to(spawn_point.global_position) \
					<= SPAWN_POINT_ENGAGE_RANGE * SPAWN_POINT_ENGAGE_RANGE:
				set_goal(spawn_point.global_position)
			else:
				set_goal(_villain_goal())

	# Duo cohesion (2026-07-20, Designer): a paired hero is never really
	# "solo" while its Duo partner is alive — the follower (whichever hero the
	# player didn't drop in the Duo's leader slot — see GameState.is_duo_leader)
	# overrides every priority-driven wander goal set above with "stay near/on
	# the leader"
	# instead. The leader is untouched and still drives the push exactly as
	# before Duos existed. Neither this nor any block above ever touches
	# `goal` while the hero has a live combat target — Combatant only moves
	# toward `goal` when idle — so this never interrupts an actual fight,
	# only where a hero wanders when it has nothing to hit. The instant the
	# partner dies, _duo_partner_node() returns null and this block simply
	# stops firing — the hero falls straight back to its own priority's
	# solo behavior above with no extra bookkeeping needed.
	if _partner_role != "" and not _duo_leader and _target == null and not _is_capturing():
		var duo_partner := _duo_partner_node()
		if duo_partner != null:
			_duo_track_cd -= delta
			if _duo_track_cd <= 0.0:
				_duo_track_cd = DUO_TRACK_INTERVAL
				if global_position.distance_to(duo_partner.global_position) > DUO_LEASH_DIST:
					set_goal(_duo_follow_anchor(duo_partner))
				elif duo_partner._target != null and is_instance_valid(duo_partner._target) and not duo_partner._target._dying:
					# In leash range with nothing of our own to fight: pile onto
					# whatever the leader is fighting instead of standing idle.
					set_goal(duo_partner._target.global_position)
				else:
					# Both idle: share the leader's exact goal instead of each
					# independently computing a slightly different one.
					set_goal(duo_partner.goal)

	# Refocus marker (player command) overrides the wandering goal set by the
	# priority blocks above: while THIS hero's Duo has a marker down, head toward
	# it. Combatant only advances `goal` when this hero has no combat target, so
	# this rallies FREE heroes to the marked spot without yanking anyone out of a
	# fight — and _target_score already pulls target choice toward marked enemies.
	# The other Duo's marker is none of this hero's business (FocusPing keys
	# everything by pair_id).
	var focus_ping := get_tree().get_first_node_in_group("focus_ping")
	if focus_ping != null and focus_ping.has_active_ping(hero_name):
		# A ping dropped ON the villain is a "commit to the villain" order: chase
		# his LIVE position (tracking teleports) rather than the static ping spot,
		# and arm the aggressive re-track cadence. _acquire_target locks him as
		# the target on the same condition. Otherwise, rally to the pinged spot.
		if _ping_targets_villain() != null:
			_villain_spotted = true
			set_goal(_villain_goal())
		else:
			set_goal(focus_ping.ping_pos(hero_name))

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

## Closest uncaptured objective to `from` (e.g. this hero's spawn point) that
## this hero's lane may capture — untagged/unmatched objectives ("" in
## LevelLayout.objective_lanes) are open to either lane.
func _nearest_uncaptured_objective(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for o in get_tree().get_nodes_in_group("objectives"):
		if o.is_captured:
			continue
		var obj_lane := _objective_lane(o)
		if obj_lane != "" and obj_lane != lane:
			continue
		var d := from.distance_squared_to(o.global_position)
		if d < best_d:
			best_d = d
			best = o
	return best

## Lane an Objective node is restricted to ("" = open to both), read via its
## own objective_index (LaneField.objective_positions/objective_lanes).
func _objective_lane(o: Node2D) -> String:
	if _field == null or not ("objective_index" in o):
		return ""
	var i: int = o.objective_index
	return _field.lane_objective_lanes[i] if i < _field.lane_objective_lanes.size() else ""

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

## Where a Duo follower should sit relative to its leader. A ranged SUPPORT
## follower trails behind the leader — on the side away from the villain/push
## direction, at RANGED_SUPPORT_TRAIL_DIST — instead of being
## pulled flush against the leader's body like a melee follower (Designer,
## 2026-07-21: "ranged support should stand behind the supported hero").
## Falls back to the leader's exact position (the old behavior) for anyone
## else, or if there's no villain position yet to derive "behind" from.
func _duo_follow_anchor(leader: Hero) -> Vector2:
	if is_ranged and role == "SUPPORT" and _field != null:
		var away_dir := leader.global_position - _field.villain_pos
		if away_dir.length() > 0.01:
			return leader.global_position + away_dir.normalized() * RANGED_SUPPORT_TRAIL_DIST
	return leader.global_position

## Nearest live real party member (excludes temporary HeroClone summons) —
## used by the SUPPORT role's guard bonus and TANK's peel fallback. Null when
## this is the only hero left.
func _nearest_ally() -> Combatant:
	var best: Combatant = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("heroes"):
		if node == self or not (node is Hero) or not is_instance_valid(node) or node._dying:
			continue
		if not _ally_lane_ok(node as Hero):
			continue
		var d := global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

## Nearest living spawn point ("spawn_points" group) IN THIS HERO'S LANE (Designer,
## 2026-07-20: split the lane so heroes commit to their own half instead of
## dogpiling one spot). Uses the shared _lane_ok filter, so it opens up at the
## merge zone / once the lanes have collapsed, same as combat targeting.
## Otherwise returns null once this lane's own gates are all down even if the
## other lane still has some — a hero doesn't cross over to help clear the
## other lane's gates while both lanes are still separately held.
func _nearest_spawn_point() -> Combatant:
	var best: Combatant = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("spawn_points"):
		if not is_instance_valid(node) or node._dying or not _lane_ok(node):
			continue
		var d := global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

## Nearest hostile within the nearby-swarm-interrupt bubble (see
## NEARBY_THREAT_INTERRUPT_MULT doc comment), or null if the bubble is clear.
## Deliberately scans the same enemy_group as normal targeting (which already
## includes spawn points, since LaneSpawnPoint joins "hostiles") — if a spawn
## point itself is the closest thing in the bubble, returning it here is just
## the existing spawn-point lock re-affirmed, not a special case.
func _nearby_threat() -> Combatant:
	var radius := maxf(attack_range * NEARBY_THREAT_INTERRUPT_MULT, NEARBY_THREAT_INTERRUPT_MIN)
	var best: Combatant = null
	var best_d := radius * radius
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying or not _lane_ok(node):
			continue
		var d := global_position.distance_squared_to(node.global_position)
		if d <= best_d:
			best_d = d
			best = node
	return best

## Lane filter (see Combatant._lane_ok doc + LaneField.clamp_to_lane): a hero
## only aggros on hostiles in its own lane, UNLESS this hero has reached the
## merge zone right before the villain, the lanes have collapsed (either
## side's Duo wiped — LaneField.lanes_merged), or the candidate itself has no
## lane of its own (e.g. the villain — never in "hostiles"/enemy_group anyway,
## but a defensive no-op if that ever changes).
func _lane_ok(node: Combatant) -> bool:
	if lane == "" or _field == null:
		return true
	if global_position.x >= _field.lane_merge_x() or _field.lanes_merged():
		return true
	# LaneSpawnPoint exposes `lane`; Minion exposes `_lane` (private, since it
	# also drives its own hunt-target filtering) — check both rather than
	# unifying the name, so each class's existing property stays private
	# where it already was.
	var node_lane := ""
	if "lane" in node:
		node_lane = node.lane
	elif "_lane" in node:
		node_lane = node._lane
	else:
		return true
	return node_lane == "" or node_lane == lane

## Same lane rule as _lane_ok, but for another Hero (ally-facing behavior —
## Rally, peel, rally-to-ally) instead of a hostile: same lane, the merge
## zone, or a collapsed lane all clear it.
func _ally_lane_ok(node: Hero) -> bool:
	if lane == "" or _field == null:
		return true
	if global_position.x >= _field.lane_merge_x() or _field.lanes_merged():
		return true
	return node.lane == lane

## Nearest ORDINARY minion — enemy_group minus spawn points and the villain —
## for comparing against a locked spawn-point/villain distance (see
## _acquire_target's "on the way" check). Unlike _nearby_threat, deliberately
## excludes the very things it's being compared against, so a hero already
## standing at the gate/villain doesn't "prefer" re-targeting the thing it's
## already locked onto.
func _nearest_minion() -> Combatant:
	var best: Combatant = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying or not _lane_ok(node):
			continue
		if node.is_in_group("spawn_points") or node.is_in_group("villains"):
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
		if node is Hero and not _ally_lane_ok(node as Hero):
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
## and at spawn when no objectives remain.)
func _is_pushing_villain() -> bool:
	match priority:
		"CAPTURE_OBJECTIVES": return _pushed_on
		_: return true  # ATTACK_VILLAIN (and any default)

## Heroes target the villain over any minion whenever he's within range —
## UNLESS an ordinary minion sits genuinely closer than he does right now, in
## which case that minion wins instead (Designer, 2026-07-20: heroes were
## tunnel-visioning past minions "on the way" and eating free damage). Pushers
## lock him out to VILLAIN_ENGAGE_RANGE (past his flee distance); everyone
## else only grabs him within detect_range. (Also see the nearby-swarm
## interrupt above, which runs first and catches anything already adjacent
## regardless of any lock.)
func _acquire_target() -> void:
	# Player command: a ping on the villain locks him as the target regardless of
	# range — the party commits to him even from across the field (see item 6).
	var pinged_villain := _ping_targets_villain()
	if pinged_villain != null:
		_target = pinged_villain
		return
	# Nearby swarm interrupt — see NEARBY_THREAT_INTERRUPT_MULT doc comment.
	# Runs BEFORE bodyguard below (balance-qa finding, 2026-07-20): bodyguard
	# has no range cap, so without this a following Thundaar could walk past
	# something adjacent to go intercept whatever's hitting a leader clear
	# across the map — the exact tunnel-vision failure mode this bubble exists
	# to prevent, just via a different lock.
	var nearby_threat := _nearby_threat()
	if nearby_threat != null:
		_target = nearby_threat
		return
	# Duo follower bodyguard (Thundaar only) — see _bodyguard_target. No range
	# cap by design (defend the leader wherever they are), but only after the
	# adjacency check above has first claim on anything already in the way.
	var bodyguard_target := _bodyguard_target()
	if bodyguard_target != null:
		_target = bodyguard_target
		return
	# A live spawn point within engage range beats both the villain and any
	# ordinary minion (see SPAWN_POINT_ENGAGE_RANGE doc comment) — UNLESS an
	# ordinary minion sits closer than the gate itself, in which case it's
	# genuinely "on the way": swing at it in passing rather than marching past
	# it to a gate that's further off anyway (Designer, 2026-07-20 — the tight
	# NEARBY_THREAT bubble above alone wasn't catching minions still closing
	# distance, just ones already adjacent).
	var spawn_point := _nearest_spawn_point()
	if spawn_point != null:
		var d_gate := global_position.distance_squared_to(spawn_point.global_position)
		if d_gate <= SPAWN_POINT_ENGAGE_RANGE * SPAWN_POINT_ENGAGE_RANGE:
			var minion := _nearest_minion()
			if minion != null and global_position.distance_squared_to(minion.global_position) < d_gate:
				_target = minion
				return
			_target = spawn_point
			return
	var villain_range := VILLAIN_ENGAGE_RANGE if _is_pushing_villain() else detect_range
	for node in get_tree().get_nodes_in_group("villains"):
		if not is_instance_valid(node) or node._dying:
			continue
		var d_villain := global_position.distance_squared_to(node.global_position)
		if d_villain <= villain_range * villain_range:
			var minion := _nearest_minion()
			if minion != null and global_position.distance_squared_to(minion.global_position) < d_villain:
				_target = minion
			else:
				_target = node
			return
	super()

## Player command: the live villain when this hero's Duo dropped its refocus
## marker on him (its point within PING_RADIUS of a villain body), else null.
## Drives both the target lock in _acquire_target and the chase goal in _process
## — a marked villain is chased/attacked regardless of range, for the level.
func _ping_targets_villain() -> Combatant:
	var ping := get_tree().get_first_node_in_group("focus_ping")
	if ping == null or not ping.has_active_ping(hero_name):
		return null
	var p: Vector2 = ping.ping_pos(hero_name)
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

## Refocus marker (player command): bias target choice toward enemies near this
## hero's OWN Duo marker, full bonus at the marker fading to 0 at its influence
## radius. Lets the player commit one Duo's fire to a spot without micromanaging
## each hero.
func _focus_ping_bonus(node: Combatant) -> float:
	var ping := get_tree().get_first_node_in_group("focus_ping")
	if ping == null or not ping.has_active_ping(hero_name):
		return 0.0
	var influence: float = ping.influence_radius()
	var d := node.global_position.distance_to(ping.ping_pos(hero_name))
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
## Uses this hero's effective (Duo Bonus/mod/boon-scaled) damage so the
## judgement matches the damage it will actually deal.
func _execute_bonus(node: Combatant) -> float:
	var per_hit := damage * _duo_damage_mult * damage_mult()
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
## do. TANK peels onto the endangered ally's attacker, CONTROL seeks the
## densest cluster (best Ensnare anchor), SUPPORT guards the ally it's
## pledged to, BURST otherwise relies purely on the execute/threat multipliers
## applied in _target_score (its Duo-follower nudge below is the one exception).
func _role_bonus(node: Combatant) -> float:
	match role:
		"TANK":
			# Peel: prefer whatever is near the most-endangered ally (lowest HP
			# fraction), scaled by proximity to that ally — so Thundaar bodies up
			# what's beating on Artemis instead of his own nearest minion.
			var ally := _weakest_ally()
			if ally == null:
				return 0.0
			var peel_radius := TANK_PEEL_RADIUS
			var d := node.global_position.distance_to(ally.global_position)
			if d >= peel_radius:
				return 0.0
			return SCORE_TANK_PEEL * (1.0 - d / peel_radius)
		"CONTROL":
			# Prefer the candidate with the most enemy neighbors within
			# ENSNARE_RADIUS, so _target (Ensnare's anchor) roots a full pack.
			return SCORE_CONTROL_CLUSTER * _enemy_neighbors(node)
		"SUPPORT":
			# Low aggression: only really cares about whatever is attacking its
			# confirmed Duo partner (2026-07-20: hero-to-hero links are only ever
			# Duo-driven now, not a separate support_target field), falling back
			# to the nearest ally if unpaired.
			var guarded: Combatant = _duo_partner_node()
			if guarded == null:
				guarded = _nearest_ally()
			if guarded != null and node._target == guarded:
				return SCORE_SUPPORT_GUARD
			return 0.0
		"BURST":
			# Duo follower focus-fire (Artemis only, 2026-07-20): lean toward
			# whatever the Duo leader is currently fighting instead of picking
			# independently — see THUNDAAR_LEADER_ATK_SPEED_MULT doc comment
			# for the full leader/follower table. A nudge (not a hard override
			# like the TANK bodyguard), so execute/threat can still win out.
			if hero_name == "ARTEMIS" and _partner_role != "" and not _duo_leader:
				var leader := _duo_partner_node()
				if leader != null and leader._target == node:
					return SCORE_ARTEMIS_FOLLOWER_FOCUS_LEADER
			return 0.0
		_:
			return 0.0

## Live node of this hero's confirmed Duo partner (GameState.duo_pairings), or
## null if unpaired, the partner hasn't spawned yet (staggered deploy), or it
## has since died. Only used by the generic leader/follower cohesion goal (see
## _process) — no per-hero behavior reads the partner's live state.
func _duo_partner_node() -> Hero:
	var partner_name := GameState.duo_of(hero_name)
	if partner_name == "":
		return null
	for node in get_tree().get_nodes_in_group("heroes"):
		if node is Hero and node.hero_name == partner_name and is_instance_valid(node) and not node._dying:
			return node
	return null

## Living real party member (not a clone) with the lowest HP fraction, for the
## TANK peel. Null when this tank is the only real hero left.
func _weakest_ally() -> Hero:
	var best: Hero = null
	var best_frac := INF
	for node in get_tree().get_nodes_in_group("heroes"):
		if node == self or not (node is Hero) or not is_instance_valid(node) or node._dying:
			continue
		if not _ally_lane_ok(node as Hero):
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
		if e == node or not is_instance_valid(e) or e._dying or not _lane_ok(e):
			continue
		if e.global_position.distance_to(node.global_position) <= ENSNARE_RADIUS:
			count += 1
	return count

## Apply Duo Bonus damage multiplier to actual damage dealt. Also widens melee
## reach against a spawn point: LaneSpawnPoint is a hard obstacle
## (see LaneField.dynamic_obstacles), so the field's collision clamp already
## pins every unit's center at `target.body_radius + _collision_radius()` away
## from it — for a melee hero that floor (~73px) sits past the base 26px
## attack_range, so without this a melee hero gets walked up to the gate and
## pinned there, unable to ever land a hit (ranged heroes clear the gap fine
## already). Widening attack_range to match the forced stand-off distance lets
## melee heroes hit from the ring they're already standing at, not "inside" it.
func _engage(delta: float) -> void:
	var scaled_damage := damage * _duo_damage_mult * damage_mult()
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
	var stomp_r := STOMP_RADIUS + stomp_radius_add  # Seismic Stomp mod/boon widens this
	var hit := false
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying or not _lane_ok(node):
			continue
		var to_node: Vector2 = node.global_position - global_position
		if to_node.length() <= stomp_r:
			hit = true
			node.take_damage(STOMP_DAMAGE * _duo_damage_mult * damage_mult(), self)
			if is_instance_valid(node) and not node._dying:
				node.apply_knockback(to_node.normalized(), STOMP_KNOCKBACK, 0.0, self)
				if _passive_unlocked:
					node.apply_stun(STOMP_STUN_DURATION)
	if hit:
		var cooldown := STOMP_COOLDOWN + stomp_cooldown_add - _duo_cooldown_reduction - _ability_cooldown_reduction
		_ability_cd = maxf(cooldown, STOMP_COOLDOWN * ABILITY_COOLDOWN_FLOOR_FRAC)
		_stomp_flash_t = STOMP_FLASH_TIME
		_show_cast_label("STOMP!", STOMP_FLASH_COLOR)
		# Impact and shout are limited independently — every 2nd stomp vs a 10s
		# clock — so a stomp can land audibly without dragging the vocal along
		# with it every time.
		_stomps_since_pound += 1
		if _stomps_since_pound >= STOMP_POUND_EVERY:
			_stomps_since_pound = 0
			BattleSfx.play_clip(self, SEISMIC_POUND_SOUND, seismic_pound_start(),
					SEISMIC_POUND_DURATION, SEISMIC_POUND_VOLUME_DB)
		if _stomp_shout_cd <= 0.0:
			_stomp_shout_cd = STOMP_SHOUT_GAP
			BattleSfx.play_clip(self, STOMP_SHOUT_SOUND, STOMP_SHOUT_START,
					STOMP_SHOUT_DURATION, STOMP_SHOUT_VOLUME_DB)

## Ensnare (WARDEN): roots every enemy within ENSNARE_RADIUS of the nearest
## threat (the current target, used as a cluster anchor) so the party can focus
## the locked pack, and (2026-07-24) makes them take flat extra damage from
## everything while rooted — Ensnare's actual damage payoff, since roots alone
## measured as the only zero-damage signature ability in the kit. Only starts
## its cooldown once it actually catches something, so it fires the moment a
## cluster forms rather than on a fixed timer.
func _try_ensnare() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var anchor: Vector2 = _target.global_position
	var ensnare_r := ENSNARE_RADIUS + ensnare_radius_add  # Wide Snare mod/boon widens this
	if _passive_unlocked:
		ensnare_r += ENSNARE_PASSIVE_RADIUS_ADD
	var vuln_add := ENSNARE_PASSIVE_VULN_DMG_ADD if _passive_unlocked else ENSNARE_VULN_DMG_ADD
	var hit := false
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying or not _lane_ok(node):
			continue
		if node.global_position.distance_to(anchor) <= ensnare_r:
			var duration := ENSNARE_STUN_DURATION * ensnare_stun_mult
			node.apply_stun(duration)
			node.apply_vulnerability(duration, vuln_add)
			# Roots drawn on the caught unit itself, for exactly as long as the
			# root lasts — so "which of these is actually held" is readable off
			# the field instead of only off the stun timer.
			node.show_ensnare_art(duration)
			hit = true
	if hit:
		var cooldown := ENSNARE_COOLDOWN - _duo_cooldown_reduction - _ability_cooldown_reduction
		_ability_cd = maxf(cooldown, ENSNARE_COOLDOWN * ABILITY_COOLDOWN_FLOOR_FRAC)
		_ensnare_flash_t = ENSNARE_FLASH_TIME
		_ensnare_flash_center = anchor
		_show_cast_label("ENSNARE!", ENSNARE_FLASH_COLOR)
		if _ensnare_sound_cd <= 0.0:
			_ensnare_sound_cd = ENSNARE_SOUND_GAP
			BattleSfx.play_clip(self, ENSNARE_SOUND, 0.0, 0.0, ENSNARE_SOUND_VOLUME_DB)

## Rally (BEACON): grants every nearby ally (self included) a timed damage +
## attack-speed boost, and (2026-07-24 tier-2 passive) a flat heal. Reuses the
## objective-reward buff primitives, so buffed allies surface DMG+/ATK SPD+
## chips via active_buffs() for free.
##
## Gated on the fight actually being worth buffing — see
## _rally_worth_casting. Ability-cadence pass (2026-07-24): the old gate (any
## hero in radius has any live target) was true almost continuously in a
## swarm fight, so Rally was constantly spent on trash instead of held for
## moments that matter.
func _try_rally() -> void:
	if not _rally_worth_casting():
		return
	var rally_r := RALLY_RADIUS + rally_radius_add  # Mass Rally mod/boon widens this
	var buffed := false
	for node in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(node) or node._dying:
			continue
		# Clones take no outside help (see HeroClone's no-op boost overrides).
		# Skipped explicitly rather than relying on those: the passive heal
		# below writes node.hp directly, and a clone should not soak a Rally
		# marker either. Also keeps clones out of the `buffed` result, so
		# Rally's recorded hit-rate reflects real allies helped.
		if node is HeroClone:
			continue
		if node is Hero and not _ally_lane_ok(node as Hero):
			continue
		if global_position.distance_to(node.global_position) <= rally_r:
			# Flat +damage / +attack-speed, converted per-target to the boost
			# API's multiplier so every hero gains the same RAW amount
			# (RALLY_DMG_ADD/RALLY_ATK_INTERVAL_REDUCTION) instead of a %
			# that reads differently depending on the target's base stats.
			var node_damage: float = node.damage
			var node_atk_interval: float = node.attack_interval
			var dmg_mult: float = 1.0 + (RALLY_DMG_ADD / node_damage if node_damage > 0.0 else 0.0)
			var atk_mult: float = node_atk_interval / maxf(node_atk_interval - RALLY_ATK_INTERVAL_REDUCTION, 0.05)
			node.apply_damage_boost(RALLY_DURATION, dmg_mult)
			node.apply_atk_speed_boost(RALLY_DURATION, atk_mult)
			if _passive_unlocked:
				node.hp = minf(node.hp + RALLY_PASSIVE_HEAL, node.max_hp)
			# Marker over each buffed ally for the buff's own duration — Rally
			# had no field visual at all before this, so the one ability that
			# helps the whole party was invisible while it did it.
			node.show_rally_art(RALLY_DURATION)
			buffed = true
	if buffed:
		var cooldown := RALLY_COOLDOWN + rally_cooldown_add - _duo_cooldown_reduction - _ability_cooldown_reduction
		_ability_cd = maxf(cooldown, RALLY_COOLDOWN * ABILITY_COOLDOWN_FLOOR_FRAC)
		_show_cast_label("RALLY!", STATUS_BUFF_COLOR)
		if _rally_sound_cd <= 0.0:
			_rally_sound_cd = RALLY_SOUND_GAP
			BattleSfx.play_clip(self, RALLY_SOUND, 0.0, 0.0, RALLY_SOUND_VOLUME_DB)

## True when the fight within RALLY_RADIUS is worth burning Rally on: a real
## cluster (>= RALLY_MIN_ENEMIES live enemies), the villain alerted, or an
## ally low on HP — instead of the old "anyone has any target," which was
## true almost continuously in a swarm fight and spent Rally on trash.
func _rally_worth_casting() -> bool:
	var rally_r := RALLY_RADIUS + rally_radius_add
	var enemy_count := 0
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying or not _lane_ok(node):
			continue
		if global_position.distance_to(node.global_position) <= rally_r:
			enemy_count += 1
			if enemy_count >= RALLY_MIN_ENEMIES:
				return true
	for villain in get_tree().get_nodes_in_group("villains"):
		if is_instance_valid(villain) and not villain._dying and villain.is_alerted():
			return true
	for node in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(node) or node._dying:
			continue
		if node is Hero and not _ally_lane_ok(node as Hero):
			continue
		if global_position.distance_to(node.global_position) > rally_r:
			continue
		if node.max_hp > 0.0 and node.hp / node.max_hp <= RALLY_LOW_HP_FRAC:
			return true
	return false

## -- Duo Ultimates (2026-07-22) ----------------------------------------------
## Manually activated once per level from the Duo Ultimate bar (BattleHUD) —
## see BattleManager.activate_ultimate, which picks whichever Duo member is
## alive to be the caster (this method's `self`) and applies the level-long
## buff (apply_permanent_buff) to every living member after this returns.
## Replaces the old solo LV20 second abilities (Shockwave/Multishot/Confuse,
## removed 2026-07-22) — see DuoUltimates for the catalog this dispatches on.

const STOMP_WAVE_SCENE := preload("res://scenes/combat/duo/stomp_wave.tscn")
const PLANT_TRAIL_SCENE := preload("res://scenes/combat/duo/plant_trail.tscn")
const ARROW_BARRAGE_SCENE := preload("res://scenes/combat/duo/arrow_barrage.tscn")

## Dispatches on DuoUltimates.def(pair_id).kind to one of the effect methods
## below. `pair_id` is passed through to _ultimate_param so every effect can
## read this run's DuoUltimateBoons on top of the catalog's flat base values.
func cast_duo_ultimate(pair_id: String) -> void:
	var d := DuoUltimates.def(pair_id)
	if d.is_empty():
		return
	var params: Dictionary = d.get("params", {})
	match d.get("kind", ""):
		"stomp_wave":
			_cast_stomp_wave(pair_id, params)
		"plant_trail":
			_cast_plant_trail(pair_id, params)
		"exploding_clones":
			_cast_exploding_clones(pair_id, params)
		"arrow_barrage":
			_cast_arrow_barrage(pair_id, params)
		"roaming_clones":
			_cast_roaming_clones(pair_id, params)
		"ensnare_burn":
			_cast_ensnare_burn(pair_id, params)
	_show_cast_label("%s!" % d.get("name", "ULTIMATE").to_upper(), Color(0.95, 0.8, 0.3))

## Base catalog value for `key` (DuoUltimates.def(pair_id).params) plus every
## DuoUltimateBoons pick this run that targets it (RunState.duo_boon_total) —
## the one place every effect method below reads a boon-scalable number from.
## Neither catalog is ever mutated; this just sums the two at cast time.
## Three layers summed onto one Ultimate params key, none of which mutates
## another: the flat catalog baseline, this run's level-start picks, and the
## permanent gold purchases (Designer, 2026-07-25 — Ultimates had no permanent
## progression before DuoUltimateMods existed).
func _ultimate_param(pair_id: String, params: Dictionary, key: String, default: float = 0.0) -> float:
	return float(params.get(key, default)) \
			+ RunState.duo_boon_total(pair_id, key) \
			+ GameState.duo_ultimate_total(pair_id, key)

## Parents a Duo Ultimate effect so it draws UNDER every unit on the field
## (Designer, 2026-07-28: "its over everything now").
##
## The effects used to go into get_parent() — the caster's own container
## (Heroes) — which sits after MinionSpawner and BloodLayer in battlefield.tscn.
## Everything on the field shares z_index 0, so draw order is pure tree order and
## an effect added there landed on top of every minion and hero in the fight.
##
## One z above LaneField.PAGE_Z and one below the props/units at 0, so the effect
## lands between the paper and everything standing on it. LaneField splits the
## page onto its own canvas item precisely to open this gap — see its
## _paint_page. Tree order no longer matters, which is why this can keep the
## effect parented to the caster's own container.
func _add_ultimate_effect(node: Node2D) -> void:
	node.z_index = LaneField.PAGE_Z + 1
	get_parent().add_child(node)

## THUNDAAR+BEACON ("Seismic Advance"): a marching sequence of stomps — see
## scenes/combat/duo/stomp_wave.gd for the actual step/damage/stun loop.
func _cast_stomp_wave(pair_id: String, params: Dictionary) -> void:
	var wave: StompWave = STOMP_WAVE_SCENE.instantiate()
	wave.caster = self
	wave.step_count = int(_ultimate_param(pair_id, params, "step_count", 4))
	wave.step_interval = _ultimate_param(pair_id, params, "step_interval", 0.35)
	wave.step_distance = _ultimate_param(pair_id, params, "step_distance", 80.0)
	wave.step_radius = _ultimate_param(pair_id, params, "step_radius", 90.0)
	wave.step_damage = _ultimate_param(pair_id, params, "step_damage", 30.0)
	wave.step_stun = _ultimate_param(pair_id, params, "step_stun", 0.8)
	_add_ultimate_effect(wave)
	wave.global_position = global_position
	# Aim only once the wave is actually AT the cast point — DuoAim scores
	# directions relative to its origin, and add_child() alone leaves it at 0,0.
	wave._start()

## THUNDAAR+WARDEN ("Verdant Path"): a trail of damaging/ensnaring plants —
## see scenes/combat/duo/plant_trail.gd for the periodic tick loop.
func _cast_plant_trail(pair_id: String, params: Dictionary) -> void:
	var trail: PlantTrail = PLANT_TRAIL_SCENE.instantiate()
	trail.caster = self
	trail.plant_count = int(_ultimate_param(pair_id, params, "plant_count", 5))
	trail.plant_spacing = _ultimate_param(pair_id, params, "plant_spacing", 60.0)
	trail.plant_radius = _ultimate_param(pair_id, params, "plant_radius", 50.0)
	trail.tick_damage = _ultimate_param(pair_id, params, "tick_damage", 6.0)
	trail.tick_interval = _ultimate_param(pair_id, params, "tick_interval", 1.0)
	trail.ensnare_duration = _ultimate_param(pair_id, params, "ensnare_duration", 1.0)
	trail.trail_lifetime = _ultimate_param(pair_id, params, "trail_lifetime", 8.0)
	_add_ultimate_effect(trail)
	trail.global_position = global_position
	# Same ordering requirement as the stomp wave above — aim from the real
	# cast point, not from the origin.
	trail._start()

## THUNDAAR+ARTEMIS ("Volatile Duplicates"): taunting clones that explode the
## instant they're hit — see HeroClone.explode_on_hit. Reuses the normal
## Clone ability's own build/place helpers (_build_clone/_place_clone).
func _cast_exploding_clones(pair_id: String, params: Dictionary) -> void:
	var count := int(_ultimate_param(pair_id, params, "clone_count", 2))
	# Fallback fuse, matching the catalog's 2.0 — only used if the params dict
	# ever arrives without the key.
	var life_span := _ultimate_param(pair_id, params, "clone_life_span", 2.0)
	var radius := _ultimate_param(pair_id, params, "explode_radius", 90.0)
	# Ability-cadence pass (2026-07-24): explode_damage used to be applied raw
	# (HeroClone._explode -> take_damage), bypassing _duo_damage_mult/
	# damage_mult() that every other ultimate routes through — fixed here at
	# the cast site since HeroClone has no caster-independent access to them.
	var dmg := _ultimate_param(pair_id, params, "explode_damage", 40.0) * _duo_damage_mult * damage_mult()
	_play_clone_creation()
	for i in count:
		var side := 1.0 if i % 2 == 0 else -1.0
		var clone := _build_clone(side * (1.0 + float(i / 2)), life_span)
		clone.explode_on_hit = true
		clone.explode_radius = radius
		clone.explode_damage = dmg
		# Bomb-carrying variant, so a volatile clone doesn't look like a plain
		# taunting one — see CLONE_ART.
		clone.sprite_texture = VOLATILE_CLONE_ART
		clone.sprite_scale = sprite_scale * VOLATILE_CLONE_ART_SCALE_MULT
		_place_clone(clone)

## ARTEMIS+WARDEN ("Hunting Duplicates"): clones that roam/chase minions and
## ensnare on hit — see HeroClone.aggressive_roam/ensnare_on_hit.
func _cast_roaming_clones(pair_id: String, params: Dictionary) -> void:
	var count := int(_ultimate_param(pair_id, params, "clone_count", 2))
	var life_span := _ultimate_param(pair_id, params, "clone_life_span", 8.0)
	var ensnare_dur := _ultimate_param(pair_id, params, "ensnare_stun_duration", 1.0)
	# Ability-cadence pass (2026-07-24): this ultimate had no damage number of
	# its own — clone_damage_mult stacks on top of _build_clone's already-
	# mult'd damage so the roaming hunters actually hit harder than a plain
	# Clone cast, not just longer-lived.
	var clone_dmg_mult := _ultimate_param(pair_id, params, "clone_damage_mult", 1.0)
	_play_clone_creation()
	for i in count:
		var side := 1.0 if i % 2 == 0 else -1.0
		var clone := _build_clone(side * (1.0 + float(i / 2)), life_span)
		clone.damage *= clone_dmg_mult
		clone.aggressive_roam = true
		clone.ensnare_on_hit = true
		clone.ensnare_stun_duration = ensnare_dur
		_place_clone(clone)

## ARTEMIS+BEACON ("Piercing Volley"): a chaining arrow burst — see
## scenes/combat/duo/arrow_barrage.gd for the instant-resolve/chain logic.
func _cast_arrow_barrage(pair_id: String, params: Dictionary) -> void:
	var barrage: ArrowBarrage = ARROW_BARRAGE_SCENE.instantiate()
	barrage.caster = self
	barrage.arrow_count = int(_ultimate_param(pair_id, params, "arrow_count", 6))
	barrage.chain_count = int(_ultimate_param(pair_id, params, "chain_count", 2))
	barrage.chain_damage_mult = _ultimate_param(pair_id, params, "chain_damage_mult", 0.5)
	barrage.hit_range = _ultimate_param(pair_id, params, "range", 260.0)
	barrage.arrow_damage = _ultimate_param(pair_id, params, "arrow_damage", 55.0)
	barrage.duration = _ultimate_param(pair_id, params, "duration", 10.0)
	barrage.wave_interval = _ultimate_param(pair_id, params, "wave_interval", 0.5)
	_add_ultimate_effect(barrage)
	barrage.global_position = global_position

## WARDEN+BEACON ("Searing Bind"): drops a burning field around the current
## target (or nearest enemy if idle) — same aim-fallback idiom as the old
## Confuse ultimate. No separate scene: the field is state on the caster, like
## Ensnare's own flash.
##
## Reworked 2026-07-26 (Designer). It used to be one instantaneous snapshot:
## whoever stood in a small radius at the instant of the cast got rooted and
## burned, and anything that walked in a frame later was untouched. Now the
## cast only ARMS the field — _tick_searing_bind does the binding for the next
## SEARING_FIELD_TIME seconds, so the swarm marching into it gets caught too.
## Each enemy is still bound exactly once (_searing_field_hit).
func _cast_ensnare_burn(pair_id: String, params: Dictionary) -> void:
	var aim: Combatant = _target
	if aim == null or not is_instance_valid(aim):
		aim = _nearest_in_group(enemy_group)
	if aim == null:
		return
	# Fires on the cast itself, not per bound target: one cast is one event —
	# a dozen overlapping copies as the field catches units would just be
	# louder mush.
	BattleSfx.play_clip(self, SEARING_SOUND, SEARING_SOUND_START,
			SEARING_SOUND_DURATION, SEARING_SOUND_VOLUME_DB)
	_searing_field_center = aim.global_position
	_searing_field_radius = _ultimate_param(pair_id, params, "radius", 110.0)
	_searing_field_ensnare = _ultimate_param(pair_id, params, "ensnare_duration", 1.5)
	_searing_field_burn_dur = _ultimate_param(pair_id, params, "burn_duration", 5.0)
	# Ability-cadence pass (2026-07-24): burn_dps used to be applied raw,
	# bypassing _duo_damage_mult/damage_mult() that every other ultimate
	# routes through (stomp_wave/plant_trail/arrow_barrage all do).
	_searing_field_burn_dps = _ultimate_param(pair_id, params, "burn_dps", 4.0) \
			* _duo_damage_mult * damage_mult()
	# A fresh cast is a fresh field: the previous one's hit-list is dropped so a
	# unit that survived an earlier bind can be bound again by a later one.
	_searing_field_hit.clear()
	_searing_field_t = SEARING_FIELD_TIME
	_tick_searing_bind(0.0)

## Runs the live bind field and ages the blinking marks. Called every physics
## frame; returns immediately when neither is active, which is the usual case.
func _tick_searing_bind(delta: float) -> void:
	if _searing_field_t > 0.0:
		_searing_field_t -= delta
		for node in get_tree().get_nodes_in_group(enemy_group):
			if not is_instance_valid(node) or node._dying or not _lane_ok(node):
				continue
			if _searing_field_hit.has(node.get_instance_id()):
				continue
			if node.global_position.distance_to(_searing_field_center) > _searing_field_radius:
				continue
			_searing_field_hit[node.get_instance_id()] = true
			node.apply_stun(_searing_field_ensnare)
			node.apply_burn(_searing_field_burn_dur, _searing_field_burn_dps, self)
			# Until the 2026-07-25 pass this Ultimate had NO visual at all — it
			# silently applied stun + burn, so the only feedback was enemies
			# suddenly ticking down. Stamp the hand-drawn bind art on EVERY unit
			# it catches; one burst over the whole radius made it read as an
			# area blast rather than a per-target root.
			_searing_marks.append({
				"node": node,
				"size": node._collision_radius() * SEARING_MARK_SIZE_MULT,
				"t": SEARING_MARK_TIME,
			})

	if _searing_marks.is_empty():
		return
	# Age the marks and drop the expired ones (and any whose unit died wearing
	# one — the mark belongs to the body, not to the ground).
	var kept: Array[Dictionary] = []
	for mark in _searing_marks:
		mark["t"] = mark["t"] - delta
		if mark["t"] > 0.0 and is_instance_valid(mark["node"]):
			kept.append(mark)
	_searing_marks = kept
	queue_redraw()

## Flat, level-long stat buff granted to both Duo members on Ultimate
## activation (Designer, 2026-07-22). No timer/expiry needed: a fresh Hero
## spawns at the next level with none of this — a one-off mutation of the live
## instance's stats for the rest of THIS level.
func apply_permanent_buff(dmg_add: float, atk_reduction: float, hp_add: float) -> void:
	damage += dmg_add
	attack_interval = maxf(attack_interval - atk_reduction, 0.1)
	if hp_add != 0.0:
		max_hp += hp_add
		hp = minf(hp + hp_add, max_hp)

## Hand-drawn impact burst expanding to the real Stomp radius (Designer,
## 2026-07-25), centred on the hero's FEET rather than his origin — sprites are
## drawn centred on the origin, which is chest height on a humanoid, so a burst
## there floated at his waist instead of cratering the ground he just hit.
## Shares BattleFX's shadow drop, so the burst and the ground shadow sit on the
## same spot.
##
## Sized off (STOMP_RADIUS + stomp_radius_add) so the VFX reads as the true
## damage area rather than a decoration that drifts once mods widen it.
func _draw_stomp_burst() -> void:
	if _stomp_flash_t <= 0.0:
		return
	# Opens at 45% rather than from nothing, and fades on a curve rather than
	# linearly. The old version scaled 0 -> full while alpha went 1 -> 0, which
	# meant it was invisible at every size worth seeing: full opacity at zero
	# width, full width at zero opacity.
	var p := 1.0 - _stomp_flash_t / STOMP_FLASH_TIME
	var diameter := (STOMP_RADIUS + stomp_radius_add) * 2.0 * STOMP_BURST_PAD * lerpf(0.45, 1.0, p)
	BattleFX.draw_burst(self, STOMP_BURST, _feet_offset(), diameter, 1.0 - p * p)

## Ensnare's ground burst, at the cluster anchor rather than on the caster —
## Warden ensnares a pack somewhere out in front of him, so the mark belongs
## where the roots came up. Same open-big-and-fade curve as the Stomp burst;
## sized off the true (ENSNARE_RADIUS + ensnare_radius_add) so it keeps
## matching the real catch area when mods widen it.
func _draw_ensnare_burst() -> void:
	if _ensnare_flash_t <= 0.0:
		return
	var p := 1.0 - _ensnare_flash_t / ENSNARE_FLASH_TIME
	var diameter := (ENSNARE_RADIUS + ensnare_radius_add) * 2.0 * ENSNARE_BURST_PAD * lerpf(0.5, 1.0, p)
	BattleFX.draw_burst(self, ENSNARE_BURST, _ensnare_flash_center - global_position,
			diameter, 1.0 - p * p)

## The point directly under this unit's drawn feet, in local space — the same
## place BattleFX puts the ground shadow. Ground-plane only (no -_bob): an
## effect on the floor must not bounce with the body above it.
func _feet_offset() -> Vector2:
	var draw_size := BattleFX.unit_draw_size(sprite_texture, body_radius, sprite_scale)
	var drop := body_radius if draw_size == Vector2.ZERO \
			else draw_size.y * BattleFX.SHADOW_DROP_FRACTION
	return Vector2(_sway, 0.0) + _lunge + Vector2(0.0, drop)

## Draws ability rings on top of the base Combatant art: Ensnare's root pulse
## (drawn at the cluster anchor, converted to this node's local space) while
## its flash runs. Stomp's burst is drawn under the hero instead — see
## _draw_stomp_burst.
func _draw() -> void:
	# BEFORE super(), so the hero stands ON the shockwave instead of wearing it:
	# it's an impact in the dirt under his feet, and drawn after super() the
	# sprite it's supposed to be beneath was covering it (Designer, 2026-07-26).
	_draw_stomp_burst()
	# Ensnare's circle goes under the field too — it's roots erupting from the
	# ground at the cluster, not a ring hung in the air over it.
	_draw_ensnare_burst()
	super()
	# Duo link line: a faint line connecting live Duo partners so the pairing
	# — and the cohesion behavior it drives — reads at a glance on the field.
	# Only the leader draws it (both would just overlap the same segment).
	if _partner_role != "" and _duo_leader:
		var duo_partner := _duo_partner_node()
		if duo_partner != null:
			var role_color: Color = ROLE_COLORS.get(role, Color.WHITE)
			draw_line(Vector2.ZERO, to_local(duo_partner.global_position), Color(role_color, 0.35), 2.0, true)
	# Full size immediately, then BLINKS for as long as the effect lasts, unlike
	# the expanding Stomp burst — the bind lands on each target at once rather
	# than travelling outward, and it has to keep saying "still bound".
	for mark in _searing_marks:
		var node: Node2D = mark["node"]
		if not is_instance_valid(node):
			continue
		var life: float = mark["t"]
		# Blink between MIN and MAX, then scaled by an overall fade over the last
		# second so the mark leaves rather than being cut off mid-flash.
		var pulse := 0.5 + 0.5 * sin(TAU * (SEARING_MARK_TIME - life) / SEARING_BLINK_PERIOD)
		var bind_alpha: float = lerpf(SEARING_BLINK_MIN_ALPHA, SEARING_BLINK_MAX_ALPHA, pulse) \
				* minf(life, 1.0)
		BattleFX.draw_burst(self, SEARING_BURST,
				node.global_position - global_position,
				float(mark["size"]) * SEARING_BURST_PAD, bind_alpha)

## Clone: spawns clone_count temporary copies of Artemis's current stats that
## taunt and fight back for CLONE_DURATION, then expire (see HeroClone). Twin
## Clone mod raises clone_count to 2 (each at clone_hp_mult HP).
func _try_clone() -> void:
	if _target == null:
		return
	# Hard-capped regardless of how many sources raised clone_count (base 1 +
	# twin_focus boon + twin_clone mod would otherwise reach 3) — see
	# MAX_CLONE_COUNT doc.
	_play_clone_creation()
	for i in mini(clone_count, MAX_CLONE_COUNT):
		# Fan multiple clones to alternating sides so they don't stack on one spot.
		var side := 1.0 if i % 2 == 0 else -1.0
		_spawn_clone(side * (1.0 + float(i / 2)))
	var cooldown := CLONE_COOLDOWN - _duo_cooldown_reduction - _ability_cooldown_reduction
	# Duo leader/follower layer: Clone recharges faster while Artemis leads
	# her Duo (see THUNDAAR_LEADER_ATK_SPEED_MULT doc comment for the table).
	if _partner_role != "" and _duo_leader:
		cooldown *= ARTEMIS_LEADER_CLONE_COOLDOWN_MULT
	_ability_cd = maxf(cooldown, CLONE_COOLDOWN * ABILITY_COOLDOWN_FLOOR_FRAC)
	_show_cast_label("CLONE!", body_color)

## Shared field-copy for a temporary Artemis-clone instance — used by both
## the normal Clone ability (_spawn_clone below) and the Duo Ultimate variants
## that spawn clones (THUNDAAR+ARTEMIS/ARTEMIS+WARDEN, see
## cast_duo_ultimate). Returns the clone BEFORE add_child() so a caller can
## set extra flags (aggressive_roam/explode_on_hit/ensnare_on_hit) that
## HeroClone's own _configure() reads once it enters the tree — in
## particular is_pinned is NOT set here; HeroClone._configure() derives it
## from aggressive_roam, so a plain clone (that flag left false) still comes
## out pinned exactly as before.
## Ability-cadence pass (2026-07-24, Designer: "clones maybe should not be an
## exact copy, but one that only deals regular damage instead of having
## abilities and affected by ultimate"): builds off the PERMANENT-build
## snapshots (_base_max_hp/_base_damage/_base_attack_interval — base stats +
## owned ability mods + purchased stat upgrades, captured in _configure
## before any Duo Ultimate ever runs) rather than the live damage/
## attack_interval/max_hp vars, so a clone no longer inherits Rally's
## temporary boost, a Duo Ultimate's permanent buff, or the Mirror Image
## tier-2's +50% — it always hits like Artemis's plain, unbuffed auto-attack.
## _duo_damage_mult stays: that's the live Duo-partner mechanic (not an
## ability/ultimate), and it already scales her own regular attacks the same
## way, so a clone matching it reads as consistent rather than "special."
func _build_clone(spread: float, clone_life_span: float) -> HeroClone:
	var clone: HeroClone = CLONE_SCENE.instantiate()
	clone.label_text = hero_name + " Clone"
	clone.max_hp = _base_max_hp * clone_hp_mult
	clone.damage = _base_damage * _duo_damage_mult
	clone.attack_interval = _base_attack_interval
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
	# Clones get their OWN art rather than copying the caster's (Designer,
	# 2026-07-26) — a decoy that is pixel-identical to the hero it's decoying
	# for is unreadable in a fight. CLONE_ART_SCALE_MULT compensates for the
	# clone drawing covering roughly half its canvas where the hero art covers
	# nearly all of its own, so the two end up the same size on screen.
	clone.sprite_texture = CLONE_ART
	clone.sprite_scale = sprite_scale * CLONE_ART_SCALE_MULT
	clone.body_color = body_color
	clone.is_taunting = true
	clone.taunt_radius = CLONE_TAUNT_RADIUS
	clone.life_span = clone_life_span
	clone.caster = self
	clone.role = role
	clone.lane = lane
	clone.follow_offset = Vector2(_facing_x * spread, 0.0) * CLONE_SPAWN_OFFSET
	return clone

## Adds `clone` to the tree and places it beside this hero (its own
## follow_offset, clamped into this hero's lane) — shared tail end for every
## clone spawn path (_spawn_clone and the Duo Ultimate clone effects).
func _place_clone(clone: HeroClone) -> void:
	get_parent().add_child(clone)
	# Anchor where the clone is actually worth standing rather than beside the
	# caster (Designer, 2026-07-26). Every clone ability routes through here —
	# plain Clone, Volatile Duplicates and Hunting Duplicates — so all three
	# inherit this. The clone's own follow_offset is still added on top, which
	# is what keeps a pair of clones fanned apart instead of stacked on one
	# spot: DuoAim picks WHERE the group goes, the offset spreads its members.
	# Scored against the radius THIS clone actually acts over: a taunting decoy
	# wants bodies inside its taunt radius, an exploding one wants them inside
	# its blast. Reading it off the clone keeps the three variants honest
	# instead of scoring them all as if they were the plain one.
	var presence := maxf(clone.taunt_radius, clone.explode_radius)
	var anchor := DuoAim.best_spot(self, global_position, CLONE_SPAWN_RANGE, presence)
	var spawn_pos: Vector2 = anchor + clone.follow_offset
	if lane != "" and _field != null:
		spawn_pos = _field.clamp_to_lane(spawn_pos, lane)
	clone.global_position = spawn_pos

## Builds one clone offset to `spread` (in CLONE_SPAWN_OFFSET units, signed left/right).
func _spawn_clone(spread: float) -> void:
	_place_clone(_build_clone(spread, CLONE_DURATION))

## Nearest living member of `group` to this hero, at any distance (unlike the
## detect-range _acquire_target) — lane-filtered like every other enemy-facing
## scan (see _lane_ok). Reused by Duo Ultimate aiming (cast_duo_ultimate's
## effect methods) when the caster has no live combat _target to aim from.
func _nearest_in_group(group: String) -> Combatant:
	var nearest: Combatant = null
	var best := INF
	for node in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(node) or node._dying or not _lane_ok(node):
			continue
		var dist: float = global_position.distance_squared_to(node.global_position)
		if dist < best:
			best = dist
			nearest = node
	return nearest

## Duo Bonus: active only when this hero has a confirmed Duo partner
## (GameState.duo_pairings) who is alive and within DUO_DISTANCE — no
## opportunistic "any nearby hero" trigger and no role-based formation math,
## just pairing + proximity. Leader/follower (_duo_leader, a player choice set
## once at spawn) scales the bonus so the two Duo slots aren't perfectly
## symmetric, without introducing any per-hero special case.
func _update_duo_bonus() -> void:
	_duo_bonus_active = false
	if _partner_role != "":
		var partner := _duo_partner_node()
		if partner != null and global_position.distance_to(partner.global_position) <= DUO_DISTANCE:
			_duo_bonus_active = true

	if _duo_bonus_active:
		if _duo_leader:
			_duo_damage_mult = DUO_LEADER_DAMAGE_MULT
			_duo_cooldown_reduction = DUO_LEADER_COOLDOWN_REDUCTION
			_duo_xp_mult = DUO_LEADER_XP_MULT
		else:
			_duo_damage_mult = DUO_FOLLOWER_DAMAGE_MULT
			_duo_cooldown_reduction = DUO_FOLLOWER_COOLDOWN_REDUCTION
			_duo_xp_mult = DUO_FOLLOWER_XP_MULT
	else:
		_duo_damage_mult = 1.0
		_duo_cooldown_reduction = 0.0
		_duo_xp_mult = 1.0

## Duo leader/follower layer: Thundaar attacks faster while leading his Duo.
## An identity trait of leading (not proximity-gated like the generic Duo
## Bonus above) — stays on for the whole battle once paired, same as
## _duo_leader itself. Damage-only note (balance-qa pass, 2026-07-20): an
## earlier version also multiplied damage here, which compounded with the
## generic Duo Bonus's own leader damage mult (1.15×1.15=32%) for a personal
## DPS swing roughly 10x every other hero's leader/follower gap — cut back to
## attack-speed only so Thundaar's leading identity is still real (~+25% DPS
## swing) without dwarfing Artemis/Warden/Beacon's.
func _effective_atk_rate_mult() -> float:
	var m := super._effective_atk_rate_mult()
	if hero_name == "THUNDAAR" and _partner_role != "" and _duo_leader:
		m *= THUNDAAR_LEADER_ATK_SPEED_MULT
	return m

## Duo follower bodyguard (Thundaar only, 2026-07-20): while following,
## always defend the Duo leader over any other engagement — returns whatever
## is currently attacking the leader, or null if nothing is (callers fall
## through to normal target acquisition/scoring in that case).
func _bodyguard_target() -> Combatant:
	if hero_name != "THUNDAAR" or _partner_role == "" or _duo_leader:
		return null
	var leader := _duo_partner_node()
	if leader == null:
		return null
	for node in get_tree().get_nodes_in_group(enemy_group):
		if is_instance_valid(node) and not node._dying and node._target == leader:
			return node
	return null

## Killing blows earn XP (banked immediately — kept even on a wipe); the rest
## of the party banks an assist share so tanks/screeners progress too.
## Duo Bonus multiplier: both heroes earn bonus XP while paired and in range.
func _on_kill(victim: Combatant) -> void:
	var xp_amount := victim.xp_value
	xp_amount = int(xp_amount * _duo_xp_mult * xp_mult() * _run_xp_mult)
	GameState.award_kill_xp(self, xp_amount)
	GameState.record_hero_kill(hero_name)

## Run-scoped XP multiplier (Fortune boon): applied to kill XP in _on_kill and
## to objective shares in BattleManager._on_objective_captured.
func run_xp_mult() -> float:
	return _run_xp_mult

## Applies this hero's SKILL TREE (2026-07-26) — every ranked node's
## `value * rank`, summed per effect kind by GameState.skill_total and written
## into the same scalars the old one-shot AbilityMods wrote. Called once from
## _configure.
##
## Replaces _apply_owned_ability_mods/_apply_ability_mod, whose per-id `match`
## can't express ranks. Nothing downstream changed: the ability code still
## reads stomp_radius_add/clone_count/_ability_cooldown_reduction and doesn't
## know or care that a tree now feeds them. The per-ability floor
## (ABILITY_COOLDOWN_FLOOR_FRAC) still caps total cooldown reduction, which
## matters more now that a maxed tree stacks several cooldown nodes.
func _apply_skill_tree() -> void:
	stomp_radius_add += GameState.skill_total(hero_name, "stomp_radius")
	ensnare_radius_add += GameState.skill_total(hero_name, "ensnare_radius")
	rally_radius_add += GameState.skill_total(hero_name, "rally_radius")
	clone_count += int(GameState.skill_total(hero_name, "clone_count"))
	_ability_cooldown_reduction += GameState.skill_total(hero_name, "ability_cooldown")

## Permanent raw-stat upgrades bought with banked XP (StatUpgrades catalog) —
## flat additive stacking per purchase (effect_add * purchases), applied on
## top of the base multipliers/ability mods, before _base_max_hp is captured.
## Attack Speed subtracts from attack_interval (lower = faster) rather than
## dividing it, so "Lv3" always reads as "3 × the same flat amount faster".
func _apply_stat_upgrades() -> void:
	var hp_n := GameState.stat_purchase_count(hero_name, "hp")
	var dmg_n := GameState.stat_purchase_count(hero_name, "damage")
	var aspd_n := GameState.stat_purchase_count(hero_name, "attack_speed")
	max_hp += float(StatUpgrades.def("hp").get("effect_add", 0.0)) * hp_n
	damage += float(StatUpgrades.def("damage").get("effect_add", 0.0)) * dmg_n
	if aspd_n > 0:
		attack_interval = maxf(attack_interval - float(StatUpgrades.def("attack_speed").get("effect_add", 0.0)) * aspd_n, 0.1)

# _apply_ability_mod() was removed 2026-07-26 with the flat AbilityMods
# catalog it switched on. Its five branches wrote exactly the scalars
# _apply_skill_tree now sums ranks into — a per-id `match` cannot express "3
# ranks of +15", which is the whole point of the tree. The disabled downside
# lines (Designer, 2026-07-18) went with it; if that tradeoff design returns,
# it belongs in the node data as a second kind_b/value_b pair, not as another
# hardcoded branch.

# apply_run_boon() was removed 2026-07-25 along with the per-hero run-boon
# catalog (scripts/boons.gd). Its five effect branches all wrote the same
# scalars _apply_ability_mod already drives — which was the problem: four of
# the eight boons were verbatim duplicates of gold mods. Run-scoped picks are
# now Duo-Ultimate-only (DuoUltimateBoons), read at cast time via
# _ultimate_param rather than applied to a Hero instance at spawn, so nothing
# replaced this function.
