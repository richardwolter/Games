# Semi-Secret Wars — Production

**Status:** Living Document (current state, updated as work progresses)

## Current Milestone

**Gameplay-loop rework — a run is now a chain of fixed levels** — Complete, pending Designer review + playtest.
- **New north star (Designer, 2026-07-18):** the **run**, not the battle, is the unit of play. A run chains levels; a loss sends you back to level 1. Progression is **knowledge** (a persistent per-level map the fog reveals) + **gold** (permanent ability upgrades), not stage unlocks. See `DECISIONS.md` (7 ratified decisions) and the plan under `.claude/plans/`.
- **Phase 1 — Fixed layouts + persistent fog:** levels are authored, not randomized. New `LevelLayout` resource (`config/level_layout.gd`; `level_1/2/3_layout.tres`) holds obstacles/lakes/objectives/scenery + the villain lair + minion gates. `StageField` lost all its `randomize_*` methods and now `apply_layout()`s the level for `RunState.current_level`. Fog of war persists per level to `user://fog/level_N.png` (explored ground stays revealed forever). Save schema → **v4** (clean wipe). Verified in-engine: geometry byte-identical across runs; fog PNG round-trips.
- **Phase 2 — Run chaining + HP carryover + permadeath:** `RunState` gained `current_level`, `hp_carry`, `dead`. A win writes survivors' HP forward, marks the fallen, and chains straight into the next level (no prep); the dead stay dead; boons re-apply on each level's spawn (abilities are intrinsic, so boons are the only carried power). A loss/run-complete returns to prep, where START resets the run to level 1. Stage-select + `stage_1_won` retired. Lone-deploy boon: a hero placed far from every ally gets a free boon ("dangerous to go alone"). Verified in-engine end-to-end: win→L2 with a dead hero skipped and the survivor at carried HP; loss→L1 fresh.
- **Phase 3 — Fixed gates + lair villain:** minion waves pour from authored gates (swarm-cap escalation unchanged — swarm feel preserved). Villains sit **dormant at their lair** until a hero closes in (`Combatant.villain_aggro_radius`/`is_alerted()`) or they're hit, then run their existing per-villain behavior. Dark Mage gained a **leash** so it juke-teleports near its lair instead of fleeing across the map (fixes the BALANCE.md "un-catchable" flag). Verified in-engine.
- **Phase 4 — Focus ping:** the player's one in-battle verb — 3 charges, left-click drops a marker; for 5s free heroes converge on it and target selection prefers enemies near it (`Hero._focus_ping_bonus` + a goal override; no new movement mode). Refunds a charge on objective capture. Verified in-engine.
- **Phase 5 — Gold shop (ability tradeoff nodes):** `scripts/ability_mods.gd` — 8 permanent per-hero mods (2 each), every one an upside + a real downside (e.g. Seismic Stomp: radius +60% / cooldown +1.5s). Bought once with gold, owned forever (`GameState.owned_mods`), applied at spawn (`Hero._apply_owned_ability_mods`). `meta_currency` → `gold`, payout scales with levels cleared. `UnlockShopPage` repurposed into the mod grid. Verified in-engine: both up/down effects land, buy-gating + persistence work.
- **Phase 6 — Levels 2–3 authored + whole-run validation:** three levels authored; a full run (L1→L2→L3→complete, plus a loss) drives clean in-engine — gold paid only at run-end, scaled by depth.
- **Whole-run balance pass (2026-07-18, same session):** `balance_sweep.gd` reworked to play whole run *attempts* (every solo + every 3-of-4 trio, chaining battlefield loads on each win) instead of the old per-battle model. First result: **0% clear rate across all 8 party comps** — Level 1 was structurally unwinnable, since its swarm throughput was tuned assuming heroes arrive pre-buffed (the old model's methodology) rather than starting at zero and leveling up live. New diagnostic tool `death_curve_probe.gd/.tscn` traced the failure to ~42s of pure travel-and-chip-damage before the party could even reach the (newly fixed) villain lair, opposite corners of the field apart. Fix: shrank Level 1's deploy-to-lair distance (~3170px→~1945px) and eased its swarm throughput/escalation (see BALANCE.md for the full before/after table). Re-swept: Thundaar solo now 100% clears, a Thundaar-anchored trio hits a genuine 50% coin-flip, weaker comps come close but don't quite land it — a real, tense curve instead of a wall. **Level 2/3 confirmed still too hard** (0/4 even for a Thundaar arriving with real leftover HP) and need the identical treatment next.
- **Open follow-ups:** (a) **Level 2/3 balance pass** — same methodology (death_curve_probe → targeted layout/throughput tuning → re-sweep), not yet done. (b) The **value-proposition playtest** — does replaying a mapped level 1 feel like earned mastery or a chore? — is a human call for the Designer. (c) Partner-pairing deploy rule (proximity enforcement) deferred — needs a pairing UI/decision. (d) Between-level heal/revive deliberately deferred (raw attrition first).

## Previous Milestone

**Hybrid-roguelite conversion (M1/M2) + 4-hero roster (M5) + ability visual feedback** — Complete, pending Designer review.
- **Design direction ratified (2026-07-18):** a genre-research design report set the project's north star — hybrid roguelite progression (per-run builds that reset + meta-unlocks that add breadth) and light-touch in-battle agency. See `IMPLEMENTATION_PLAN.md` for the full milestone sequence this drives (M1–M10).
- **M1 — In-run leveling + boon draft:** new `RunState` autoload tracks per-hero in-run XP/level (separate from persistent state); on level-up, the battle pauses and offers a 1-of-3 boon pick (`scripts/boons.gd` catalog: Power/Vitality/Haste/Swiftness/Fortune/Ferocity) applied live and reset every run. Verified in-engine: leveling, pause/pick/apply/unpause, and multi-level-in-one-XP-grant all confirmed; `balance_sweep.gd` guarded with a `RunState.headless` flag so it never deadlocks on the pause.
- **M2 — Retired the persistent stat grind:** heroes now always spawn at flat base stats (see BALANCE.md); the old XP-bought stat upgrades and skill-tree ability nodes are gone. Run end awards **meta-currency** (win 15 / loss 5) toward a persistent unlock shop (currently nothing to unlock — 2 base heroes were always both available; real content arrives with M5's roster growth and a future relic system). Save schema bumped to v3 with a clean wipe of old saves (Designer-approved). **Balance-relevant call:** hero abilities became **intrinsic** (every hero has its full kit from run start) rather than gated behind the old skill-tree points — this is a real power increase versus the old "LV0" hero and needs a fresh balance sweep (see BALANCE.md flag).
- **M5 — Added WARDEN (Controller) and BEACON (Support), placeholder names:** roster is now 4. WARDEN auto-casts **Ensnare** (roots a nearby enemy cluster); BEACON auto-casts **Rally** (timed damage + attack-speed buff to nearby allies) and defaults to the newly un-deferred `SUPPORT_ALLIES` priority. Ranged-hero config was generalized into data (`HERO_STATS`) instead of an Artemis special-case, so WARDEN's ranged attack needed zero new branching. Verified in-engine: roles, ranged flag, ability effects, and the Artemis-ranged regression all confirmed.
- **Ability visual feedback (Designer-requested, same session):** abilities were hard to track by eye during real-time play. Added (a) a floating "ABILITY NAME!" callout above the caster on every hero ability proc, and (b) a shared `Combatant`-level colored status ring (stun=cyan, slow=violet, buff=gold, shield=light-blue) on any unit affected by a status effect — this also retroactively made the Mech Robot's slow-zone and the existing objective party-buffs visible for the first time. Designer-confirmed working.
- **Sequencing note:** M3 (draft — field 3 of 4 heroes) was deliberately done *after* M5, not before, since a draft is hollow with only 2 heroes. M3 is next.
- **Open follow-up:** balance is unverified post-M2 (see BALANCE.md) — a fresh `balance_sweep.gd` run + tuning pass is recommended before the numbers are trusted again.

## Previous Milestone

**Stage 3 (Mech Robot) + comprehensive balance sweep + Lone Wolf solo buff** — Complete, pending Designer review.
- **Stage 3 built (placeholder):** new villain (Mech Robot — stationary, melee-capable, periodic slow-zone AoE ability) and a hybrid Ranged/Brute minion swarm (50/50 mix). Verified in-engine: villain spawns, both minion types spawn, slow-zone ability fires and applies its movement/attack debuff. Stats are first-pass placeholders, not tuned. See [BALANCE.md](BALANCE.md).
- **Comprehensive automated sweep (186 runs):** solo + duo × LV 0–30 × Stage 1/2/3, each capped at 60 simulated seconds, run via a new in-engine test harness (`scenes/tools/balance_sweep.gd`), raw data in `BALANCE_SWEEP_RESULTS.json`. Found solo never won within the cap at any level on any stage; duo progression was coherent across all 3 stages (~LV 19–22 Stage 1, ~LV 15 Stage 2, ~LV 20–26 Stage 3).
- **Lone Wolf buff (solo wins now possible):** added a standing compensation buff for true 1-hero rosters (×1.8 HP / ×1.75 damage / −0.4s cooldown, mutually exclusive with the existing Synergy system so **duo balance is untouched**). Re-swept solo (93 runs): Stage 2 now wins consistently from LV 21. Stage 1 and Stage 3 still don't cross the win line within the 60s cap but trend hard toward one (villain down to 79%/85% damaged by LV 30, up from ~45%/31% pre-buff).
- **Open item for Designer:** Stage 1's Dark Mage (flees + teleports + resummons every 10s) resists pure stat buffs structurally — a lone hero's chase progress resets each teleport cycle, unlike Stage 2/3 villains that stand and fight. This means **solo can currently beat Stage 2 but not Stage 1**, the opposite of the intended difficulty curve, and since Stage 2 only unlocks after beating Stage 1, a solo player can't actually reach the stage they can win. Needs either a Stage-1-specific tweak (e.g. shorter resummon burst or teleport interval when solo) or a deliberate design call that solo isn't meant to clear Stage 1.

## Previous Milestone

**Balance pass: hero differentiation, synergy system, ability unlocks** — Complete, pending Designer approval.
- **Hero differentiation:** Thundaar (tank) and Artemis (DPS) now have distinct base stats and per-upgrade scaling instead of identical placeholder stats — see [BALANCE.md](BALANCE.md). Builds stay flexible (either hero can be leaned tankier or glassier via upgrade choice).
- **Synergy system:** both heroes alive within 200px grants +15% damage, −0.3s ability cooldown, +25% XP — makes the duo meaningfully stronger than either hero solo. Verified in-engine: LV 20 synergy duo cleared Stage 1 at near-full HP in ~26s (5× sim).
- **Ability unlocks:** LV 15 grants passive upgrades to the existing abilities (Stomp stuns, Clone hits harder); LV 20 unlocks a second active ability per hero (Thundaar's Shockwave, Artemis's Dash). Gives the player a visible power spike roughly every 2-3 runs instead of pure stat-line growth.
- **XP economy + swarm density retuned:** kill/capture XP up, upgrade costs down, swarm caps/escalation raised so early runs feel more "swarmy." Verified in-engine: solo LV 8 Thundaar now wins Stage 1 (razor-thin, 6/180 HP left) rather than the old narrow-loss baseline — the floor moved up; LV 25 duo clears Stage 2 comfortably with visible tank/DPS HP asymmetry.
- **Not yet re-verified:** LV 12–20 range (the gap between the LV 8 solo floor and the two confirmed comfortable-win points); minion variety (ranged/brute types) from the plan wasn't implemented this pass.
- **Swarmier spawns (2026-07-15):** Designer feedback that the swarm should feel denser — spawn throughput/caps raised ×1.5 across both stages, minion damage/XP cut ÷1.5 to hold the chip-damage and XP budgets constant. Re-verified in-engine: LV 20 synergy duo still clears Stage 1 comfortably (170/220, 114/145 final HP), matching the pre-existing gate within noise while active-minion/kill counts ran markedly higher. See [BALANCE.md](BALANCE.md).

## Previous Milestone

**Stage 2 Unlocked banner + HUD polish** — Complete, pending Designer approval.
- **Stage 2 Unlocked banner:** results screen shows a gold "STAGE 2 UNLOCKED!" line the moment Stage 1 is beaten for the first time (not on repeat wins). Verified in-engine via `game_eval`: fires on the unlock transition, stays hidden on a subsequent win with the flag already set.
- **HUD polish:** objective tracker gained a fill bar and a "CONTESTED" state (hostile actively blocking capture, distinct from just being nearby); hero panels gained a cooldown fill bar (0 = just used, full = ready) alongside the existing text, sized per hero's real ability cooldown (Stomp 3.5s, Clone 8.0s). Verified in-engine: bar nodes wired correctly, fraction math checked at mid-cooldown (0.5) and ready (1.0).

## Previous Milestone

**Deployment phase, hero abilities, fog of war, art pass** — Complete, pending Designer approval.
- **Deployment phase:** battle no longer auto-starts the party; the player sees a legal deploy zone (green) and minion-spawner standoff rings (red) and clicks to place the party before the swarm begins. Verified in-engine (legal-point placement spawns the party exactly there; swarm holds until deployed).
- **Hero abilities:** Thundaar auto-casts Stomp (AoE damage + knockback), Artemis auto-casts Clone (taunting stand-in). Verified firing in-engine (cooldown UI, Clone spawn/taunt); damage/cooldown values are a first pass, not yet tuned against the stage gates — see [BALANCE.md](BALANCE.md).
- **Fog of war:** explored-stays-revealed terrain fog + live hero-vision-bubble unit hiding, visual only (combat/targeting untouched). Verified rendering and revealing correctly in-engine.
- **Art pass:** Thundaar and Minion now use real sprites; obstacles render as Mountain/Forest art; field shapes went to a hand-inked notebook style (transparent fill + ink outline, cross-hatched lake).
- **Caught and fixed a balance regression:** an in-progress swarm-size experiment had left Stage 1/2 spawn throughput at ~22× the verified balance pass, wiping an over-leveled party instantly. Rescaled back to the original verified throughput (see BALANCE.md) — LV10/LV25 gates should be re-run through the full instrumented pass before trusting them exactly, since minion HP/damage/XP were also halved in the art pass.

## Completed Milestones

1. Project setup & scope alignment
2. Placeholder battlefield (isometric, zoom camera)
3. Hero characters (Thundaar + Artemis)
4. Combat system (Combatant base, HP, attacks, health bars)
5. Win/Lose conditions (farm swarm, defeat villain, placeholder banners)
6. Objectives (hold-to-capture, XP bonus)
7. Progression (persistent upgrades, post-run screen)
8. Minion AI (intercept targeting, field-wide hunt)
9. Battlefield reshape (Stage 1 open field — approved 2026-07-15)
10. Poison Lake hazard + steering hardening (approved 2026-07-15)
11. Balance & Pacing: 2-Level System (Stage 1 + Stage 2 Berserker, expandable architecture)
12. Stage-level balance targets (LV 10 / LV 25 gates) + hero-panel camera focus
13. Prep-menu stage select (progression unlock) + freed-follow crash fix
14. Deployment phase, hero abilities (Stomp/Clone), fog of war, art pass
15. Stage 2 Unlocked banner + HUD polish (objective tracker, hero cooldown bars)
16. Hybrid-roguelite conversion: in-run boon leveling (M1), meta-currency + retired persistent stat grind (M2)
17. 4-hero roster: WARDEN (Controller/Ensnare) + BEACON (Support/Rally) added (M5); ability visual feedback pass

## Demo Scope

**Run-as-a-chain loop (current direction):** prep (draft party + priorities, buy permanent ability mods with gold) → **Level 1**: deploy on a *fixed* field the persistent fog gradually maps → auto-battle authored gates' escalating swarm, leveling up in-run via boon picks, one focus-ping to command the party → find and beat the dormant-lair villain → **chain into the next level** carrying HP/boons/levels (the dead stay dead) → repeat until a wipe → back to prep at Level 1 with gold + a better-mapped world. Roster: Thundaar, Artemis, WARDEN, BEACON. Levels 1–3 (Dark Mage / Berserker / Mech Robot), all authored. 2D isometric, player zoom. Two currencies: **XP** (in-run boons, reset each run) and **gold** (permanent ability mods). Core loop proven end-to-end in-engine.

## Next Candidates

- **Balance whole-run sweep:** rework `balance_sweep.gd` to sweep *runs* (levels cleared before wipe), then a tuning pass on gate difficulty, gold rates, mod values, aggro/leash radii, fog vision radius.
- **Value-proposition playtest:** confirm replaying a mapped level feels like mastery, not a chore (lever = fog radius + level size).
- **Between-level relief:** heal/revive intermission once raw attrition is felt.
- **Partner pairing:** the "partners deploy together" rule needs a pairing UI/decision before enforcement.
- **Level twists:** per-level environment dangers / surprise attacks (now that layouts are data).
- More levels/villains/heroes and named synergies, all addable via config/data.

## Production Notes

- Engine: Godot 4.7-stable, GL Compatibility
- Main scene: `scenes/prep/prep_menu.tscn` (prep → `scenes/battlefield/battlefield.tscn`)
- Display: 1920×1080, fullscreen, PC target
- Tools: `godot-ai` MCP connected for automation
