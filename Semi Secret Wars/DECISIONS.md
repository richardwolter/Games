# Semi-Secret Wars — Decisions

Records important project decisions and why they were made.

## 2026-07-20 — balance-qa pass 1 on the Duo system: Thundaar's leader bonus de-stacked, bodyguard reordered

**Decision:** First `balance-qa` skill pass on the new Duo setup (arithmetic/inspection only — no lane-shaped sweep harness exists yet). Three findings, two acted on:

1. **Thundaar's leader bonus was ~10x every other hero's leader/follower swing** (+44% personal DPS vs. ~+4.5% for Artemis/Warden/Beacon) because his per-hero damage mult compounded multiplicatively with the generic Duo Bonus's own leader damage mult, on top of a separate attack-speed mult. Cut to attack-speed only (`THUNDAAR_LEADER_DAMAGE_MULT` deleted) — leading now roughly +20-25% DPS over following, a real but no longer dominant identity trait.
2. **Bodyguard (Thundaar following) had no range cap and was checked before the nearby-swarm-interrupt** added the same session — a following Thundaar could ignore an adjacent spawn point/minion to intercept whatever was hitting a leader clear across the map, reintroducing the exact tunnel-vision bug just fixed via a different lock. Reordered so the interrupt runs first.
3. **Warden/Beacon still have no per-hero leader/follower layer**, compounding the pre-existing no-tank-comp weakness. Left open — needs a Designer call between giving them a comparable layer vs. explicitly accepting the no-tank comp stays weakest.

**Reason:** Finding 1 risked collapsing "who should lead" into "always Thundaar if available," directly against the stated goal that leader choice should be genuinely experimentable. Finding 2 was a straightforward regression of the previous session's own fix. Both approved for immediate action ("go ahead"); Finding 3 explicitly deferred since it's a comp-viability call, not a number to pick unilaterally.

**Impact:** Still **first-pass, unswept** — see BALANCE.md's Duo Bonus System section for the updated table and the full finding writeups. No lane-shaped sweep harness exists (deleted with V1 — Part C6 planned work); everything here is arithmetic on live constants, not observed combat.

## 2026-07-20 — Duo system: Synergy+Formation unified, leader/follower is a player choice, per-partner-role tweaks removed

**Decision (four related changes, same session):**

1. **Synergy (any nearby ally) and Formation (role-based proximity auras) unified into one "Duo Bonus"** that only fires for a *confirmed* Duo pairing (set at the prep screen), not any two heroes standing near each other. Leader gets +15% damage/−0.3s cooldown/+25% XP; follower gets +10%/−0.2s/+15%.
2. **Leader/follower is a pure player choice, not derived from role.** Originally the lower-ranked role always led (TANK > BURST > CONTROL > SUPPORT, so Thundaar always led any pairing he was in). Replaced with `GameState.is_duo_leader()`: whichever hero is dropped in a Duo's left/A prep-menu slot leads.
3. **A small per-hero leader/follower behavior layer added on top**, keyed only on `(hero_name, leader-vs-follower)`: THUNDAAR leading gains attack speed + damage, following he bodyguards the leader (hard target override); ARTEMIS leading gains HP + faster Clone, following she focus-fires the leader's target (soft nudge). WARDEN/BEACON have none yet.
4. **An earlier, broader version of (3) was built and then removed the same session.** It keyed behavior on the *partner's* role instead (e.g. Warden's Ensnare anchor switched depending on whether her partner was TANK/BURST/SUPPORT, and her cluster-search separately biased toward a SUPPORT partner's position) — this caused Warden's targeting to visibly conflict with itself. Ripped out entirely rather than patched.

**Reason:** Direct Designer feedback across the session. On (1)/(2): "tank always leads does not work anymore ... this should be a player decision, even when it does not seem to make sense, experimentation is good." On (3)/(4): "It is fixing leader and follower to specific heroes... It should not have a specific behavior for each hero, It should be a behavior that matches other heroes without having to completely adapt individually. This should be the norm for DUO synergy, to reduce scope creep on project" — followed by an explicit reversal once the per-hero *leader/follower* layer (not per-*partner*) was proposed: "Per-hero seems interesting and strategy driven. But it should not conflict with DUO generic behavior... Everything should feel cohesive and implementable." The distinction that survived: per-hero behavior keyed on this hero's own leader/follower status is fine; per-hero behavior keyed on the *partner's* identity/role is not — the latter is what caused the conflict.

**Implementation:** `hero.gd` — `_update_duo_bonus()` replaces the old `_update_synergy()`/`_update_formation()`; `DUO_LEADER_*`/`DUO_FOLLOWER_*` consts replace `SYNERGY_*`/`FORMATION_*`; `FORMATION_PAIRS` deleted. `_apply_duo_partner_tweaks()`, the Ensnare partner-anchor switch, and Warden's cluster-search partner bias all deleted. New: `THUNDAAR_LEADER_*`/`ARTEMIS_LEADER_*` consts, `_bodyguard_target()`, `_role_bonus`'s BURST follower case. `game_state.gd` — new `is_duo_leader()`. `prep_menu.gd` — Duo slots now show LEADER/FOLLOWER before a hero is dropped (slot position, not computed after fill). See BALANCE.md (Duo Bonus System section, first-pass numbers) and PRODUCTION.md (current milestone) for full detail.

**Impact:** No numbers here have been through a balance sweep — flagged as the very next piece of work (`balance-qa` skill pass).

## 2026-07-20 — Hero targeting: minions "on the way" now interrupt a locked spawn point/villain

**Decision:** The spawn-point (`SPAWN_POINT_ENGAGE_RANGE` 500px) and villain (`VILLAIN_ENGAGE_RANGE`) target locks were absolute distance checks — a hero within range would beeline the lock regardless of what it walked past. Added two checks in `Hero._acquire_target()`, both ahead of the locks: (a) a tight "already adjacent" bubble (`attack_range × 1.5`, floored at 90px) that always wins; (b) a broader "on the way" check — an ordinary minion (excluding spawn points/villains) closer to the hero than the currently-locked gate/villain wins instead.

**Reason:** Direct Designer report — "heroes are just ignoring some minions and taking unnecessary damage" because of over-focus on spawn points, then specifically flagged after a first (bubble-only) fix that Warden was still beelining a gate. The bubble-only fix caught adjacent minions but not ones still closing distance — the "on the way" comparison closed that gap. Designer-confirmed working after the second fix.

**Implementation:** `hero.gd` — new `_nearby_threat()` and `_nearest_minion()` (the latter explicitly excludes `spawn_points`/`villains` groups, so a hero already standing at a lock target doesn't "prefer" re-targeting the thing it's already on).

**Impact:** Not yet balance-swept — may change spawn-point clear times and effective swarm damage taken en route; flagged for the same upcoming `balance-qa` pass as the Duo Bonus numbers.

## 2026-07-19 — Party cap removed: players can deploy every unlocked hero

**Decision:** Removed `RunState.PARTY_CAP` (was 3) entirely. Every unlocked hero can now be drafted and deployed in the same run — no "leave one out" constraint.

**Reason:** Direct Designer request. This reverses the 2026-07-18 "party cap set to 3-of-4" decision (below) — the composition-tension goal that motivated that cap no longer holds for what's wanted from this build.

**Implementation:** `run_state.gd` — deleted `PARTY_CAP`; `roll_draft_offer()` now offers and auto-selects every unlocked hero instead of a random `PARTY_CAP+1` subset; `toggle_selected()` no longer caps additions. `prep_menu.gd` (V1) and `lane_prep_menu.gd` (V2) — checkbox disable logic dropped its cap clause. `balance_sweep.gd`'s `PARTY_COMPS` (a hardcoded trio list, not driven by the constant) was left as-is, but its stale "what a real player drafts" comment was corrected — it's a partial-roster coverage set now, not the default composition; a full 4-hero comp isn't in the sweep yet.

**Impact:** Every existing balance-sweep result, and the "3-of-4 forces a real choice" framing in the 2026-07-18 entry below, is superseded for what a real player actually fields. No sweep re-run this pass — flagged as a follow-up.

## 2026-07-19 — Artemis: Dash replaced with Multishot; no movement-type abilities going forward

**Decision:** Swapped Artemis's LV20 ultimate from **Dash** (a short reposition that hits enemies along the way) to **Multishot** — a stationary volley of up to 5 arrows at the nearest enemies within range, reusing the same `Projectile` her basic attack fires. Kept Dash's cooldown/target-count budget; each arrow deals 0.6× a normal hit since several can land at once.

**Reason:** Direct Designer request — movement-type abilities are ruled out as a standing constraint on future ability design ("it inbalances the game"), not just a one-off swap.

**Impact:** `hero.gd` — `DASH_*` constants replaced by `MULTISHOT_*`; `_try_dash()`/its hit logic replaced by `_try_multishot()`/`_fire_multishot_arrow()`; `ABILITY_INFO`/cast label updated. `ability_tiers.gd` — the `ARTEMIS_3` shop entry renamed Dash→Multishot. Not yet balance-swept.

## 2026-07-19 — V2: mid-battle respawn removed, one-shot deploy phase added

**Decision:** V2's persistent live-redeploy verb (each hero on its own timer, up to `MAX_LIVES 3` deploys per level, `RESPAWN_COOLDOWN 20s` after a death) is retired. In its place: a one-shot pre-battle phase — click every drafted hero into the fixed deploy band, then press a **START BATTLE** button — after which the swarm releases and there is no more redeploy. A hero that dies mid-battle is down for good (permadeath), same finality as V1.

**Reason:** Direct Designer request, immediately following the grind-progression pass (see the entry below). Live-redeploy and the new "grindy, high-stakes run" direction were pulling in opposite directions — a respawn safety net softens exactly the stakes the achievement/tier grind is trying to create.

**Implementation:** `v2/battle/lane_deploy_controller.gd` rewritten in place (same class slot) from the timer/lives controller into a placement controller modeled on V1's `scenes/battle/deploy_controller.gd`, constrained to `LaneField`'s authored deploy band instead of the whole open field, with an explicit START BATTLE button (V1 auto-commits on the last hero placed; V2 doesn't, since the Designer specifically asked for a deliberate confirm step). `LaneBattleManager` no longer starts the spawner in `_ready()` — it waits for the button's `deploy_chosen` signal. Hero death now calls the existing `_on_hero_exhausted` directly (no lives bookkeeping in between), which already fed into `RunState.mark_dead` — so permadeath was already run-scoped, not level-scoped, with zero new code needed for that part.

**Impact:** `MAX_LIVES`/`RESPAWN_COOLDOWN`/`INITIAL_STAGGER` and the `_first_deploy_done` carried-HP-on-first-deploy tracking are gone (every deploy is now the only deploy, so the carried-HP logic always applies unconditionally). Verified headless against the real `lane_battlefield.tscn`: swarm frozen pre-start, no hero spawned before commit, whole party spawns together on START, and a killed hero is immediately exhausted with the level ending in a loss the instant the last hero falls. V1 untouched — scoped entirely to `v2/battle/`.

## 2026-07-19 — V2 grind progression: hero unlocks, ability tiers, drip economy, Lone Wolf removed for V2

**Decision:** Implemented the approved plan turning V2 from "a shorter V1" into the deliberately grindy build: a fresh V2 save starts with only THUNDAAR unlocked (was the full 4-hero roster, same as V1); the rest unlock via cumulative career achievements (kills/gates/villain-damage%) that persist across every run, win or lose. The three intrinsic ability flags V1 grants for free are now gold-gated per hero in V2 (tier 1/signature free, tier 2/passive 40g, tier 3/ultimate 70g, sequential). Gold now drips per-kill (0.5g) and per-gate (15g) in addition to the existing run-end payout. **Lone Wolf (the solo-hero ×1.8 HP/×1.75 dmg/−0.4s cooldown compensation buff) is removed entirely for V2** — gated at `hero.gd:518` on `not GameState.v2_mode` — since every early V2 run *is* solo Thundaar and the buff directly fought the new "Level 1 needs ~3 upgraded heroes" design goal.

**Reason:** Direct Designer request (this session) — V2 needed its own progression shape, not V1's loop with bigger numbers. Lone Wolf specifically: "it does not make sense anymore" once V2 starts every player at solo-THUNDAAR-only — a buff designed to make solo viable was actively undermining the intended early-game difficulty wall.

**Knock-on effect (flagged, not separately tuned):** `Hero._on_kill` grants `SYNERGY_XP_MULT` (1.25×) whenever `_synergy_damage_mult > 1.0`, which Lone Wolf previously satisfied for a solo hero. Removing Lone Wolf therefore also removes the solo XP bonus in V2 — consistent with the grindier direction, but it makes early solo runs slower to level, which sits underneath the achievement thresholds below. Not addressed this pass; needs a real playtest before the thresholds are trusted.

**Everything stays additive/gated, per the established V2 pattern:** new `StageConfig.villain_hp_mult` field defaults to 1.0 (V1 `.tres` files never set it); new `v2/config/lane_*_stage_config.tres` mean V1's shared `config/stage_*_config.tres` were never touched; `Hero._configure()`'s tier-gating and Lone Wolf gating both branch on `GameState.v2_mode`, so V1 keeps its unconditional `_base/_passive/_active_unlocked = true` and its original `_is_lone_wolf` condition byte-for-byte.

**Known gaps surfaced, not invented away:** WARDEN has no coded LV20 ultimate at all today (`ABILITY_INFO["WARDEN"].name2 == ""` in `hero.gd`), and neither Ensnare nor Rally read `_passive_unlocked` — so `WARDEN_2`/`WARDEN_3`/`BEACON_2` currently sell tiers with no observable in-game effect. This predates this pass (same gap exists dormant in V1) but is now a real gold purchase in the new shop; flagged rather than patched, since inventing the missing mechanic wasn't part of the approved plan.

**Impact:** Save schema → **v5** (adds `career`, `owned_ability_tiers`; old saves wipe clean, consistent with every prior schema break). New files: `scripts/achievements.gd`, `scripts/ability_tiers.gd`, `v2/prep/ability_tier_page.gd`, `v2/config/lane_{1,2,3}_stage_config.tres`. See PRODUCTION.md (current milestone) and BALANCE.md for the specific tuning numbers (achievement thresholds, tier costs, gold drip rates, L1 villain HP/gate HP raise).

## 2026-07-19 — Difficulty pass: hero stat rebase + BEACON ultimate + harder swarm/villains

**Decision:** Game played too easy after the MVP pass. (1) Rebased all four heroes onto a Designer-authored stat table (see BALANCE.md "Difficulty pass"). (2) Gave BEACON its first second-ability — **Confuse**, a cone of light that makes caught minions attack each other for 3s (villains immune). (3) Raised swarm density (`swarm_max_cap` +30%, `spawn_batch` 2→3) and bumped villains ~+20-25% HP/dmg.

**Reason:** Direct Designer request. Confuse was wired into the existing second-ability slot (auto-cast, like Shockwave/Dash) rather than a new player verb, keeping the "one in-battle verb = focus ping" constraint intact and requiring zero HUD/input changes. Confusion is a new systemic `Combatant` status (`_confused_t`/`apply_confusion`/`_effective_enemy_group`), so any future confusion source reuses it; the status ring shows it for free. Villain immunity prevents trivializing a boss.

**Accepted tradeoff — WARDEN DMG 9→6:** the Designer's table reverses the same-day WARDEN buff (see next entry) that fixed the no-burst comp on L3. Applied verbatim as instructed. Consequence confirmed in the re-sweep: the no-burst THUNDAAR+WARDEN+BEACON comp collapses to ~0% full-run even with mods. **Flagged for a Designer call** (revisit WARDEN, or accept that a no-hard-burst trio isn't meant to clear). Tank comps with mods land at ~37-50% full-run (at/above the 20-30% target); the no-tank comp stays correctly locked out.

## 2026-07-19 — WARDEN damage buff to fix L3 flatline for low-DPS comps

**Decision:** Raised WARDEN's base damage 7 → 9 (`HERO_STATS` in `scenes/heroes/hero.gd`) rather than retargeting Ensnare onto villains or cutting Mech Robot HP further.

**Reason:** The whole-run sweep showed THUNDAAR+WARDEN+BEACON — a comp with no burst hero — clearing L2 fine (62%) but flatlining at L3 (0/5): a zero-damage-output comp can't beat a raw HP check like the Mech Robot regardless of survivability. Two other candidate fixes were investigated and ruled out first: a previously-documented travel-time gap for Warden comps through L2's chokepoint (re-probed, no longer present — that finding predates later tuning), and Ensnare providing indirect DPS by locking the villain down (checked the code — Ensnare anchors on Warden's current attack target, usually a minion, so it rarely reaches the villain). Villain-HP cuts were rejected as the fix because L2/L3 are already cleared 50–100% by the higher-DPS trios; cutting further risks trivializing those. Designer chose the direct stat buff over a targeting-logic change (keeps the fix scoped to numbers, not new mechanics).

**Impact:** Re-swept 8 trials/comp: THUNDAAR+WARDEN+BEACON L3 0%→66%, full-run 0%→50%. No other comp regressed outside the already-documented L2 noise band (±30pts/8 trials). See BALANCE.md "L2/L3 centering for low-DPS comps."

## 2026-07-19 — Tank is no longer a mandatory pick

**Decision:** The tankless trio (Artemis+WARDEN+BEACON) must be viable, not a guaranteed loss. Fixed via **ability cadence + formation symmetry**, not flat stat buffs: `CLONE_DURATION` 2.0→3.5s and `ENSNARE_COOLDOWN` 6.0→4.5s (both in `scenes/heroes/hero.gd`), plus generalizing the formation opposite-role bonus from a hardcoded TANK+BURST branch into a data-driven `FORMATION_PAIRS` table that also grants CONTROL+SUPPORT and BURST+SUPPORT pairs.

**Reason:** Every sweep locked the no-tank comp at 0% Level-1 clear, so Thundaar was effectively required and the GDD's "draft 3-of-4" decision was fake. Diagnosis showed the barrier was structural, not stats — party HP was already comparable (245 vs 270). Three systems denied the comp a frontline: the swarm hunts nearest-hero (nobody holds the line without a tank), the only role-pair formation bonus was TANK+BURST (unfireable without a tank), and the sole taunt (Artemis's Clone) held only 25% uptime. The fix targets those three directly rather than inflating squishy HP, which would have blurred the role identities.

**Alternatives considered:** giving BEACON's Rally a taunt (rejected — invents a mechanic not in the design docs); changing minion targeting (rejected — ripples into every comp and level at once); flat stat buffs (rejected — erodes role differentiation). Designer chose the Clone+Ensnare+formation route.

**Impact:** Re-sweep put tankless Level-1 clear at 62–87% (from 0%) with no Thundaar-trio regression. Level 2/3 tankless clears stay gated by the separate stale-numbers pass. See BALANCE.md "No-tank viability pass (2026-07-19)."

## 2026-07-18 — On-clear heal (partially reverses "no heal" from the rework)

**Decision:** When a party clears a level, each surviving hero recovers **50% of its missing HP** before that HP carries into the next level (`CLEAR_HEAL_MISSING_FRACTION = 0.5` in `scenes/battle/battle_manager.gd`, applied in `_record_carryover()`). The dead still stay dead — permadeath is unchanged; only survivors heal.

**Reason:** The Level 2 balance pass found that pure stage/villain/layout tuning could not give Level 2 the same clear-curve as Level 1. Unlike Level 1 (always entered fresh at full HP), Level 2 is entered **depleted**: the chained-probe diagnosis showed survivors reaching Level 2 at ~36% HP, and trios often arriving as a lone survivor (squishies die during Level 1). With raw HP carryover and no heal, the only way to make Level 2 winnable was to trivialize the Berserker for a fresh fight the run never actually sees. A partial heal fixes the root cause and scales to Level 3.

**This revises rework decision #7** ("Raw HP carryover + permadeath, *no heal/revive yet*") — the "yet" is now partially resolved: heal for survivors is in; revive for the fallen remains deferred.

**Alternatives considered (Designer chose the heal):** (a) tune Level 2 for the depleted reality (would make a fresh Berserker a pushover); (b) accept low Level 2 clear rates as a hard gate. Heal form also chosen by Designer from: restore-to-60%-max, flat +40%-max, and the selected 50%-of-missing (scales with how hurt a hero is, never fully tops off).

**Impact:** Load-bearing change for the Level 2 pass — the Berserker/swarm cuts only work because a healed party can act on them. Safe against the spawn path, which already re-clamps carried HP to `[1, max_hp]`. See BALANCE.md "Level 2 (Berserker) findings."

## 2026-07-18 — Gameplay-loop rework: the run is a chain of fixed levels

**Decision:** Reworked the core loop around seven ratified choices (Designer). The **run** (a chain of levels), not a single battle, is the unit of play.

1. **Fixed authored layouts** (not per-battle randomization) — a level is the same field every time so it becomes familiar; randomization is deleted from `StageField`, geometry lives in `LevelLayout` resources.
2. **Persistent fog, permanent per level** — explored ground stays revealed forever (`user://fog/level_N.png`). This *is* the "progress is knowledge" pillar.
3. **Fixed lair + reactive villain** — the villain sits dormant at an authored lair until the party closes in, then runs its existing per-villain behavior. Location is learnable; the fight stays dynamic.
4. **Fixed gates, timed escalating waves** — swarm pours from authored edges (learnable direction), keeping the swarm feel while tying it to map knowledge.
5. **Focus ping** — the one in-battle player verb: 3 charges, click to bias the party toward a spot for 5s, refunds on objective capture. Deliberately minimal so the battle stays "off the player's hands."
6. **Permanent per-hero ability tradeoff nodes** — gold buys upgrades that are owned forever, each with a real downside. Two currencies: XP (in-run boons, reset) and gold (permanent mods).
7. **Raw HP carryover + permadeath, no heal/revive yet** — survivors carry HP into the next level, the dead stay dead; relief mechanics deferred until the attrition is felt in play.

**Reason:** The prior single-battle roguelite had nothing that made a level *familiar* and nothing to spend meta-currency on. The rework makes replay meaningful through map mastery + a growing permanent kit, and every run restarts at level 1 (progress is knowledge + gold, not stage unlocks).

**Alternatives considered:** nest-based aggro spawning (vs. timed gates); permanent-terrain-only fog (vs. everything); roaming villain (vs. fixed lair); re-issue-priority verb (vs. ping); consumable per-run loadout (vs. permanent mods). All recorded in the plan.

**Impact:** Sequenced as a 6-phase vertical slice validated in-engine per phase. Retired: `StageField.randomize_*`, `GameState.stage_1_won`/`stage_override`, prep stage-select, `meta_currency` (→ `gold`). Save schema → v4. See PRODUCTION.md current milestone.

## 2026-07-14 — PRODUCTION.md as top-priority source of truth

**Decision:** Use `PRODUCTION.md` (not `PROJECT_STATE.md`) as the top-priority document for current project state.

**Reason:** The AI Development Prompt named `PROJECT_STATE.md` as the top-priority document, but the Documentation Structure spec never defines that file. `PRODUCTION.md` already covers the same purpose (current milestone, roadmap, release/prototype goals, production notes).

**Alternatives considered:** Create a separate `PROJECT_STATE.md`; or keep `PROJECT_STATE.md` as a thin pointer to `PRODUCTION.md`.

**Impact:** Source-of-truth priority order is now `PRODUCTION.md` > `AI_Development_Guide.md` > `Game_Design_Bible.md`.

## 2026-07-14 — Slim CLAUDE.md to avoid duplication

**Decision:** Slim `CLAUDE.md` down to a role summary and repo-specific tooling notes; move all development-process rules to `AI_Development_Guide.md` and all gameplay truth to `Game_Design_Bible.md`.

**Reason:** `CLAUDE.md` was duplicating the AI Development Guide almost verbatim, which the Documentation Structure spec explicitly warns against ("never duplicate information across documents").

**Alternatives considered:** Leave `CLAUDE.md` as the full duplicated ruleset.

**Impact:** `CLAUDE.md` now points to `AI_Development_Guide.md` / `Game_Design_Bible.md` / `PRODUCTION.md` instead of restating their content. Future rule changes should be made in the source doc only.

## 2026-07-14 — Converted source PDFs into living .md docs

**Decision:** Converted the four source PDFs (AI Development Guide, AI Development Prompt, Documentation Structure, GDD) into the living `.md` doc set defined by the Documentation Structure spec.

**Reason:** PDFs are static and can't be incrementally edited as the project evolves; the Documentation Structure spec explicitly calls for editable living documents.

**Alternatives considered:** Keep working directly from the PDFs.

**Impact:** The PDFs remain in the repo root as historical/original source material; the `.md` files are now the actively maintained source of truth.

## 2026-07-14 — Battle camera: 2D isometric with zoom

**Decision:** Battles are presented in 2D isometric projection (sprites on an isometric grid, `Node2D`-based) with player-controlled zoom, rather than a 2D side view or a true 3D scene.

**Reason:** Designer wants players able to zoom out to see the scope of the whole battle, or zoom in to watch it unfold in detail. No source doc specified a camera perspective, so this was an open gap.

**Alternatives considered:** 2D side view (comic-panel framing, simplest to build); true 3D with an orthogonal isometric `Camera3D` (would have made use of the `3d/physics_engine="Jolt Physics"` setting already present in `project.godot`).

**Impact:** Battlefield/Hero/Enemy scenes are built as `Node2D` with isometric sprite placement, not `Node3D`. The pre-configured Jolt Physics 3D setting is now unused — flagged in `BACKLOG.md` as low-priority cleanup, not removed yet.

## 2026-07-14 — Combat movement: simple lane

**Decision:** Hero/minion movement in the demo uses simple lane movement — heroes advance along a path toward the villain, minions occupy and block the lane — rather than full open-field pathing or an abstracted, non-spatial resolution.

**Reason:** Matches the GDD's existing combat wording ("heroes progress toward the villain, minions attempt to stop them") while keeping the first Combat implementation minimal, per the AI Development Guide's "smallest possible feature" philosophy.

**Alternatives considered:** full open 2D pathing (bigger first build, more tactical feel); abstracted/progress-bar resolution (faster to build, but departs from the GDD's description of physical movement).

**Impact:** The Battlefield only needs to define a lane/path plus spawn, objective, and villain points along it — not open terrain.

## 2026-07-14 — Demo finish line: one loop, one villain

**Decision:** The playable demo's scope is one full gameplay loop (roster select → priorities → auto-battle → reward → level up → repeat) against a single villain, not both named villains or deep progression systems.

**Reason:** GDD §25 — "the prototype should prove the game is fun before expanding content or increasing production quality."

**Alternatives considered:** both villains playable (roughly double build cost); full skill-tree progression included (adds significant design work before the loop is even validated).

**Impact:** Enemy/Combat/Objectives/Rewards/Progression milestones scope to one battlefield and one villain. Which villain (Dark Mage or Berserker) is still open — deferred to the Enemy milestone. Berserker, the second battlefield, and skill trees are post-demo expansion.

## 2026-07-14 — Demo progression: XP/level only, no skill tree

**Decision:** Hero progression in the demo is XP plus level-based flat stat increases only; skill trees are deferred past the demo.

**Reason:** Skill tree node layout, costs, and unlock conditions are all currently TBD in the GDD and would require significant design work before Combat is even built. Validating the core loop doesn't require them.

**Alternatives considered:** a minimal 3–5 node skill tree included in the demo.

**Impact:** The Progression milestone implements an XP curve and level-based stat bump only. Skill Trees (GDD §14) remains an open design area for after the demo.

## 2026-07-14 — Dark Mage is the first demo villain

**Decision:** The Dark Mage is the first villain implemented, anchoring the demo battlefield and gameplay loop. Berserker is deferred to post-demo.

**Reason:** Designer choice. Keeps the one-villain demo scope focused (see the "one loop, one villain" decision above).

**Impact:** The demo battlefield, summon mechanic, and swarm test are built around the Dark Mage. BALANCE.md tracks Dark Mage as the active villain.

## 2026-07-14 — Swarm scaling ambition & enemy architecture

**Decision:** The game's core fantasy includes battlefields and enemy swarms that scale up dramatically over levels — a long-term target of thousands of enemies on screen. The enemy/minion system must therefore be designed to be lightweight and scalable from the outset, even though the first swarm test is small.

**Reason:** Designer direction: "the battlefield should feel bigger and bigger as the player progresses, with thousands of enemies." Building the enemy system in a way that can't scale would force a costly rewrite later.

**Approach (to balance against "avoid premature optimization"):** The initial concept-test swarm uses simple, individual `Node2D` minions for clarity and fast iteration. Movement/state is kept simple and self-contained so it can later be lifted into a bulk, data-oriented system (e.g. a single manager updating enemy state in arrays, rendered via `MultiMeshInstance2D`) once the concept is validated. We do NOT build the bulk system now — it is tracked in BACKLOG.md ("Scalable swarm rendering/simulation") and triggered when the small version is proven and enemy counts start to hurt.

**Alternatives considered:** Build the full data-oriented/MultiMesh system immediately (premature — over-engineers an unvalidated concept); ignore scale and use per-enemy nodes with heavy per-frame logic (would not scale to thousands, forcing a rewrite).

**Impact:** Enemy milestones start small but are structured for a clean migration path to bulk simulation. This is a known, deliberate future refactor, not accidental debt.

## 2026-07-14 — PC display specs: 1920×1080 base, fullscreen

**Decision:** Configure the project for PC publishing: base viewport 1920×1080, window mode fullscreen, resizable, keeping stretch mode `canvas_items` + aspect `expand`. Default battle camera zoom bumped 0.7 → 1.2 so the field frames well at 1080p.

**Reason:** Designer wants the game to be publishable for PC with correct graphic size and specifications (fullscreen).

**Alternatives considered:** Windowed dev default (less disruptive during MCP test runs, but doesn't match the requested shipping spec); `keep` aspect / letterboxing (rejected — `expand` with a controllable camera lets wider monitors see more).

**Impact:** 1920×1080 is the base design resolution; fullscreen is the intended shipping default (applied at export / a Settings milestone). Battle camera default zoom is 1.2 for good 1080p framing. See the "Dev runs windowed" entry below for the current development window setting.

## 2026-07-14 — Combat: shared Combatant base class

**Decision:** Heroes and minions share a single `Combatant` base script (`scenes/combat/combatant.gd`) that owns health, target acquisition, melee attacks, death, path movement and drawing. `Hero` and `Minion` are thin subclasses that set config (groups, path, stats, visuals).

**Reason:** Heroes and minions have near-identical combat/movement behavior; a shared base avoids duplicating it (AI Development Guide: no duplicate logic). Keeping each unit a *single* node (rather than multi-node components) keeps minions light for the future large-swarm system.

**Trade-off vs. "composition over inheritance":** The AI Development Guide prefers composition, but here a single shallow base for "mobile combat unit" is cleaner than per-unit component nodes and better for the scaling goal. This is a deliberate, documented exception — not a deep hierarchy.

**Impact:** New unit types extend `Combatant`. When the bulk swarm system arrives, the combat *rules* in `Combatant` (hp/damage/targeting) carry over to the data-oriented version.

## 2026-07-14 — Finding: endless swarm has no win condition (expected)

**Finding (not a bug):** With the Dark Mage's swarm refilling endlessly and no win/lose logic yet, heroes always eventually die. Confirmed in-engine (heroes overwhelmed in ~10s at placeholder balance).

**Impact:** A fair, winnable fight needs the win/lose + wave/finite-swarm systems, which belong to the Objectives/Rewards milestones (backlogged). Combat balance tuning is deferred until then, since "fair" depends on those systems.

## 2026-07-14 — Open-field movement (resolves the deferred movement model)

**Decision:** The battlefield is an **open field**: heroes and the swarm move freely toward goal points, steering around blocking obstacles. This resolves the movement-model question deferred at the Stage-1-sketch capture and supersedes the lane system from the swarm concept test.

**Reason:** Designer direction — "an open field for the swarm and heroes to move around," matching the sketch.

**Implementation:** `StageField` (scenes/battlefield/stage_field.gd) is the single source of field truth — named points (hero spawn funnel, villain corner, objective), blocking obstacles, scenery, Poison Lake — and renders the organic hand-drawn field. `Combatant` movement changed from waypoint paths to goal-point steering with obstacle avoidance (`StageField.steer_around`: radial pushback + tangential slide — pushback alone cancels on head-on approaches, a bug caught and fixed in-engine). Simple circle-avoidance was chosen over Godot navigation (NavigationAgent2D per unit) to keep minions light for the thousands-of-enemies target.

**Impact:** `iso.gd` (grid math) and `battlefield_ground.gd` (tile lane renderer) deleted; minions spawn spread around the villain and flow toward the hero funnel with per-minion goal offsets (loose clusters, per the sketch). Poison Lake is drawn but inert — hazard effect remains TBD in BACKLOG.

## 2026-07-14 — Prep screen combines roster, priorities, and upgrades

**Decision:** A single pre-battle **preparation screen** (now the main scene) is where the player prepares the whole run: per-hero party toggle, battlefield priority, and XP upgrade purchases, then START BATTLE. The post-run screen slims to a results overlay (outcome + XP gained) that returns to prep.

**Reason:** Designer direction — "the player prepares the next run as a whole." Matches the GDD loop (select roster → assign priorities → battle → rewards → upgrade → repeat) with prep as one place.

**Priority behaviors (decided):** *Attack Minions* = default engage-in-detect-range behavior; *Capture Objectives* = go to the objective, hold until captured, **then advance** (no garrison); *Attack Villain* = push to the villain, **fighting only what blocks the way** (engagement range = attack range × 1.3, not full ignore). *Support Allies* is **skipped** (not shown) until support abilities exist.

**Implementation:** `PrepMenu` (scenes/prep/, main scene) + `GameState.party` (selected + priority per hero, persisted in the save); `BattleManager` spawns the selected party from config (heroes no longer hardcoded in battlefield.tscn); `ResultsScreen` replaces the old post-run upgrade screen.

**Impact:** The full GDD gameplay loop is now playable end-to-end. Party/priority choices persist between sessions.

## 2026-07-14 — Progression is player-directed (supersedes flat auto-bumps)

**Decision:** Players **choose where to allocate XP on each hero** — no automatic stat increases on leveling. Heroes are customizable; the player defines which attributes each hero upgrades.

**Reason:** Designer direction. Player agency over hero growth is core to the upgrade loop; automatic bumps would flatten it. This partially supersedes the earlier "XP/level only, flat stat bump" demo-scope decision — the *no skill trees* part still stands; the *automatic* part does not.

**Impact:** The Progression milestone needs an upgrade/allocation UI between runs, not just background math.

**Allocation model (decided same day):** XP is spent **directly** on upgrades (no level/point abstraction — a hero's "level" is just total purchases); all four stats are upgradable in the demo (Max HP, Damage, Attack Speed, Move Speed); allocation happens on a **post-run upgrade screen** (after VICTORY/DEFEAT, before R restarts). Kill XP goes to the killer; objective XP splits among living heroes; all farmed XP is kept on death; progression persists to disk (`user://save.json`). Costs/effects in [BALANCE.md](BALANCE.md).

## 2026-07-14 — Objectives: hold-to-capture, grants farm/XP

**Decision:** Objectives are **hold-to-capture** — a hero within range fills progress over time; a nearby enemy contests (pauses, no reset). Completing an objective grants a one-time **farm / XP bonus** (GDD §11's TBD resolved). The first build ships **one** objective on the lane.

**Reason:** Designer choices. The bonus feeds the incremental farming loop without directly enabling the villain kill (kept separate from the win condition).

**Alternatives considered:** effect = weaken the villain (rejected for now — would tie objectives to the win); reach/touch capture (rejected — less strategic); two objectives (deferred — one first).

**Impact:** `CaptureObjective` (`scenes/objectives/`) handles capture; `BattleManager` sums objective bonuses into the run's farm and shows objective % in the HUD. Real XP wiring waits on Progression. Pre-battle priority assignment ("tell a hero to capture") is a separate later milestone — heroes auto-capture by proximity for now.

## 2026-07-14 — Win model: farm + defeat-villain (supersedes survive-waves)

**Decision:** The battle uses the incremental farm-and-grow model (GDD §16). The swarm is a **continuous, escalating XP farm**; **win = defeat the Dark Mage** (you've out-leveled the stage and advance); **lose = all heroes die** (the run ends; heroes keep the run's farm once Progression exists, and retry stronger). Base (un-upgraded) heroes are **not** expected to win — they farm and are overwhelmed.

**Supersedes:** the earlier "survive finite waves = win" decision. On the designer clarifying the core loop (swarm = XP farm every run; defeating the villain = proof you've out-leveled the stage), the finite-wave survival win no longer fit and was replaced.

**Villain:** a **summoner + HP target** — stationary, high HP (2000), does not attack yet (partial step back from "defer villain combat": it now has HP and is killable, but is not an attacking boss).

**Implementation:** `MinionSpawner` maintains a continuous swarm up to a cap that escalates over time; `BattleManager` wins on villain death, loses on no heroes, and shows a placeholder banner + R-to-retry. Villain reuses the `Combatant` base.

**Impact:** Combat matches the incremental loop. It is intentionally unwinnable at base stats; real winnability arrives with Progression (XP/upgrades). Full villain boss behavior and capturable objectives remain later milestones. Balance values in [BALANCE.md](BALANCE.md).

## 2026-07-14 — Stage 1 battlefield & HUD vision (designer sketch)

**Reference:** Designer provided a hand sketch of the zoomed-out Stage 1 (Dark Mage) battlefield and in-battle HUD. Captured in [Game_Design_Bible.md](Game_Design_Bible.md) §8/§10/§11/§12 and [ART_BIBLE.md](ART_BIBLE.md).

**Implication:** The target battlefield is an open, organic field (not a grid) with obstacles, hazard terrain (Poison Lake), scenery props, capturable objectives with progress, spread minion swarms, and a boss villain with an HP bar — plus a battle HUD (villain HP, per-hero HP + attack cooldown, objectives tracker). This evolves beyond the current placeholder straight lane.

**Resolved (2026-07-14):**
- Sequencing: finish **win/lose + objectives on the current simple setup first**, then reshape the battlefield toward the sketch.
- Movement model: **deferred** — decide when the battlefield is actually rebuilt (open-field is the likely target per the sketch, but not yet locked).

**Still open:** Poison Lake effect, objective capture mechanic / rewards — all TBD.

## 2026-07-15 — Poison Lake: damage-over-time only, affects everyone

**Decision:** The Poison Lake drains HP over time (8 HP/s placeholder) from **any** unit inside — heroes and minions alike; no movement slow. Units softly steer around it (extra shore margin), but pursuit of a target in or behind the lake can still drag them through. Poison kills grant no killer XP.

**Reason:** Designer choices (2026-07-15), resolving the hazard-effect TBD from the battlefield reshape. Everyone-affected keeps the lake a neutral terrain feature the player can exploit by kiting.

**Alternatives considered:** DoT + slow (rejected for now — may revisit in the balance pass); slow only; heroes-only or minions-only immunity (rejected — asymmetric versions cut both tactical directions).

**Impact:** `StageField` owns `lake_dps` + `in_lake()`; `Combatant` applies hazard drain with a green tint. Same session hardened movement: a per-frame hard clamp guarantees units never clip obstacle cores, and steering was smoothed (smoothstep ramp + heading easing).

## 2026-07-15 — Berserker stays post-demo (reaffirmed)

**Decision:** A request to build the second level + Berserker villain now was reviewed against the demo scope and **deferred back to post-demo** — Designer chose to stay on plan (Battle HUD / hazard / balance first).

**Impact:** No change to the one-loop-one-villain demo scope. The open design questions for that expansion (Berserker behavior, its minion identity, second battlefield theme) remain TBD and were captured in conversation as the starting point when it is picked up.

## 2026-07-14 — Dev runs windowed

**Decision:** During development the game runs windowed at 1280×720 (`window mode` = windowed, `window_width/height_override` = 1280×720) so runs don't take over the screen; the base design resolution stays 1920×1080. Fullscreen remains the intended shipping default and will be applied at export / a Settings milestone (backlogged), not the current dev config. Two polish follow-ups logged in BACKLOG: the engine-gray area outside the notebook page is visible at some zooms (needs a proper backdrop/clear color), and an in-game fullscreen/windowed toggle + resolution options belong in a later Settings milestone.

## 2026-07-18 — Design direction: hybrid roguelite + light-touch agency

**Decision:** Following a genre-research design report (autobattler/swarm/MOBA/roguelite design space), the project's north star is **hybrid roguelite progression** — per-run builds that RESET each run, plus meta-progression that unlocks new *heroes/relics/options* into the pool rather than flat permanent power — and **light-touch in-battle agency** (mostly watch-it-unfold, with a few timed manual inputs).

**Reason:** The shipped build (pre-this-session) was structurally an incremental farm-and-grow game (persistent per-hero stat purchases saved to disk), not a roguelite, despite the pitch. Richard reviewed the report and ratified this direction to close that gap.

**Alternatives considered:** True run-based roguelite (everything resets, no meta layer) — rejected, throws away the unlock-progression hook. Keep the persistent-grow model and reframe the pitch around it — rejected, doesn't match the intended fantasy.

**Impact:** `IMPLEMENTATION_PLAN.md` (new) lays out the milestone sequence (M1–M10) this drives. Supersedes the "Demo progression: XP/level only, no skill tree" and "Progression is player-directed" decisions above for anything persistent — those still describe how progression *felt* pre-M2, but the persistence model they describe is retired (see the M2 entry below).

## 2026-07-18 — M1: RunState split from GameState (in-run vs. persistent)

**Decision:** New `RunState` autoload (`scenes/run/run_state.gd`) owns everything that resets every run: per-hero in-run level/XP and picked boons. `GameState` (unchanged name) keeps only what persists across runs.

**Reason:** Cleanest way to implement the hybrid-roguelite split without conflating "this run's power" with "the account's unlocks" in one dictionary.

**Implementation:** XP flows through the existing single chokepoint `GameState.add_xp()` into `RunState.record_xp()`. On a level crossing, `RunState.hero_leveled` fires; `BattleManager` pauses the tree and shows a 1-of-3 boon pick (`scenes/battle/level_up_screen.gd`), applied live via `Hero.apply_run_boon()`. A `RunState.headless` flag (set by `balance_sweep.gd`) suppresses the pause/emit for automated runs.

**Impact:** Boon catalog lives in `scripts/boons.gd` (~6 boons: Power/Vitality/Haste/Swiftness/Fortune/Ferocity), all direct base-stat multipliers so they compose with existing synergy/formation multipliers without new combat call sites.

## 2026-07-18 — M2: Persistent stat grind retired → meta-currency + unlock shop

**Decision:** Removed the old XP-bought permanent stat upgrades and skill-tree ability nodes entirely. A hero always spawns at flat `HERO_STATS` base values (see BALANCE.md); all growth is in-run boons (M1). Run end awards **meta-currency** (win 15 / loss 5) toward unlocking new heroes/relics into the pool — nothing to unlock yet (all 2-then-4 heroes were always available; content arrives with future milestones). Save schema bumped to **v3**, and any save below v3 is **discarded on load**, not migrated (Designer-approved clean wipe).

**Reason:** The persistent stat grind was the core thing preventing the game from reading as a roguelite (see the 2026-07-18 direction decision above). The skill-tree UI was repurposed into `scenes/prep/unlock_shop_page.gd` (`UnlockShopPage`) rather than deleted outright — same "spend currency on a page" shape, new content.

**Balance-relevant call made during implementation (flagged, not separately confirmed with Designer):** hero abilities became **intrinsic** — every hero has its full ability kit (both auto-cast tiers) from the start of every run, since the old base/passive/active unlock gating was itself part of the persistent grind being removed. This is a real power increase vs. the pre-M2 "LV0" hero.

**Impact:** `Hero._configure()` no longer reads any `GameState.bonus_*`/`owned()`/`ability_owned()` — those methods no longer exist. `balance_sweep.gd`'s methodology changed from "seed persistent stats before spawn" to "grant `RunState` boon picks to the spawned hero" (`_grant_power`); **old `BALANCE_SWEEP_RESULTS.json` numbers are stale** and not comparable post-M2. A fresh sweep + tuning pass is an open follow-up, not yet done.

## 2026-07-18 — M5 sequenced before M3; party cap set to 3-of-4

**Decision:** Milestone 5 (add a Controller and Support hero, growing the roster to 4) was done *before* Milestone 3 (draft a subset of the roster each run), reversing the original plan order. The party cap for the future draft is **3 of 4** heroes fielded per run.

**Reason:** A draft is a hollow, untestable choice with only 2 heroes — there's nothing to leave out. Doing M5 first makes M3's draft an immediate, real "which role do I sacrifice this run" decision. Party cap of 3 (vs. 2 or 4) was chosen to force that genuine composition tension rather than "just take everyone."

**Impact:** `IMPLEMENTATION_PLAN.md`'s milestone order is amended accordingly. M3 (draft step) is next up and will enforce the 3-hero cap; it is not enforced anywhere yet (today's prep screen still lets all 4 be selected).

## 2026-07-18 — WARDEN (Controller) + BEACON (Support) added, placeholder names

**Decision:** Two new heroes were added to reach the 4-hero roster: **WARDEN** (CONTROL role, ranged) auto-casts **Ensnare** (roots the nearest enemy cluster, reusing `Combatant.apply_stun`); **BEACON** (SUPPORT role) auto-casts **Rally** (timed damage + attack-speed buff to nearby allies, reusing `apply_damage_boost`/`apply_atk_speed_boost`) and defaults to the newly un-deferred `SUPPORT_ALLIES` priority. **WARDEN/BEACON are working/placeholder names** — Richard has not locked final hero names yet; renaming is a cheap catalog-key change whenever he decides.

**Reason:** Designer-selected abilities from a shortlist grounded in primitives already in the codebase (see the two AskUserQuestion rounds in-session). Un-deferring `SUPPORT_ALLIES` (previously blocked on "no support abilities exist" — see the 2026-07-14 Prep screen decision) was a direct consequence of BEACON existing.

**Impact:** Ranged-hero configuration was generalized from an `if hero_name == "ARTEMIS"` special-case into data (`HERO_STATS` `is_ranged`/`attack_range` keys), read generically in `Hero._configure()` — the deeper fix rather than stacking a second special-case for WARDEN. Formation/synergy bonuses were *not* extended to reward CONTROL/SUPPORT pairings this pass (only same-role and mixed-trio bonuses apply to them) — real 4-role named synergies are Milestone 6.

## 2026-07-18 — Design-testing playtest fixes (six items)

**Decision:** A Designer playtest of the run-as-a-chain loop surfaced six behavioral/feel problems, all fixed in the same pass:
1. **Support-ally leash band.** `SUPPORT_ALLIES` previously re-goaled onto a fixed 46px standoff point every 0.3s — an unconditional hard tether. Replaced with a **260px leash band** (`Hero.SUPPORT_LEASH_DIST`): the support only re-paths toward its partner when it drifts past that distance; inside the band it fights as a free individual (own target selection + the existing `SCORE_SUPPORT_GUARD` bias). Its `detect_range` was also widened (`attack_range * 1.5` → `* 2.0`) so it meaningfully clears minions rather than just orbiting.
2. **Objective-capture commitment.** A hero that had spotted an objective could still be pulled off it — the rally-to-ally block didn't check whether a capture was in progress, and combat drift (chasing a target that wandered into range) could walk it off the point, silently stranding `Objective.progress` (which never decays). Added `Hero._is_capturing()`; gated rally-to-ally on it and added a re-assert-goal anchor while inside `capture_radius`. The hero still fights whatever's in range (needed to clear `contested`), it just won't wander off. Focus ping still overrides, unchanged — "unless overwritten by player command" was an explicit part of the ask.
3. **Move speed compression.** 75/90/95/115 (Thundaar/WARDEN/BEACON/Artemis, 1.53× spread) → 88/95/98/102 (1.16×). The wide spread was stringing the party out across the field instead of fighting together.
4. **Poison Lake: one damage instance, not a drain.** Was 8 HP/s continuous (`lake_dps`) while inside; now a single **6-damage hit on entry** (`lake_damage`, edge-triggered off `Combatant._in_lake`'s false→true transition), silent until the unit fully exits and re-enters. Avoidance steering was also strengthened (clearance +50px/1.3 strength → +90px/1.6) so units skirt the shore rather than clip it as often.
5. **Deploy-phase readability.** The placement ghost cursor was a generic green/red ring with hero identity only in a far-off top-center hint label. Now tinted the current hero's own catalog color (when legal) with the hero's name drawn at the cursor.
6. **Focus ping on the villain = commit order.** A ping dropped on the villain previously only nudged *target selection* toward minions near it — `_acquire_target`'s villain branch never consulted the ping, and the movement override chased the ping's *static* point, so a party pinged onto a teleporting villain marched to a stale spot. Added `Hero._ping_targets_villain()`: when the ping lands within `FocusPing.PING_RADIUS` of a live villain, every hero **locks him as target regardless of range** and re-goals to his **live** position (`_villain_goal()`, tracking teleports) for the ping's lifetime — deliberately overriding `_is_pushing_villain()` gating, so even a farming/support hero commits when pinged on the villain.

**Reason:** Direct Designer feedback from playtesting, not derived balance work. Items 3 and 4 double as real balance levers (move speed and hazard cost both feed the run-sweep math), so a full whole-run re-sweep was run to confirm neither regressed — see BALANCE.md "Design-testing fixes" section for the before/after table. Result: no comp regressed; every Thundaar-anchored trio moved from a coin-flip or 0% to 75–100%, and the no-tank trio picked up its first win.

**Impact:** `scenes/heroes/hero.gd` (items 1/2/3/6), `scenes/combat/combatant.gd` + `scenes/battlefield/stage_field.gd` (item 4, `lake_dps` renamed `lake_damage`), `scenes/battle/deploy_controller.gd` (item 5). Verified: a clean headless project boot (no compile errors), a temporary probe scene exercising the support-leash/capture-commit/ping-lock paths end-to-end (deleted after verification, per the existing `behavior_probe.gd`/`death_curve_probe.gd` convention), and the full balance re-sweep above.

## 2026-07-18 — Ability visual feedback: status ring + cast-name callout

**Decision:** Added two visual-feedback mechanisms so ability procs are trackable in real-time play (Designer feedback: couldn't keep up with what fired during a normal-speed run). (1) A floating "ABILITY NAME!" text callout above the caster on every hero-ability proc (Stomp/Clone/Shockwave/Dash/Ensnare/Rally). (2) A colored status ring on **any** `Combatant` (not just heroes) affected by a stun/slow/buff/shield — cyan/violet/gold/light-blue respectively.

**Reason:** Direct Designer request after playtesting M5. The status ring was deliberately built into the shared `Combatant` base rather than per-ability, so it's a systemic fix, not six bespoke ones.

**Impact (bonus, unplanned):** because the ring lives on `Combatant`, it retroactively made the Stage 3 Mech Robot's slow-zone ability and the existing objective party-wide reward buffs visible for the first time — both previously had zero per-unit visual feedback beyond a HUD chip/banner.
