# Semi-Secret Wars — Balance

Stores gameplay values. Every gameplay value should eventually live here instead of in source code (see [AI_Development_Guide.md](AI_Development_Guide.md) §8, §11).

> **⚠ Updated 2026-07-19 (visuals + ranged-behavior + roster pass, same session) — not yet balance-swept or played live:**
>
> **Artemis Dash → Multishot** (`hero.gd`): see DECISIONS.md — same 6s cooldown / 220px range / 5-target budget as Dash, each arrow at `MULTISHOT_DAMAGE_MULT 0.6`× a normal hit instead of Dash's escalating melee-range bonus damage. Different damage shape (guaranteed multi-hit vs. positional dive), unverified against the existing trio sweep numbers.
>
> **Ranged standoff/kiting** (`Combatant.gd`, `RANGED_STANDOFF_FRACTION 0.6`): any `is_ranged` hero (Artemis, Warden) now backs away once its target closes inside 60% of `attack_range`, rather than standing still. Changes effective uptime/exposure for both ranged heroes in a fight — not accounted for in any existing sweep result.
>
> **Hero/minion size** (`hero.tscn`/`minion.tscn`): `body_radius` 18→22 (hero) / 9→11 (minion), `sprite_scale` 1.6→1.8 for both. Bigger hitboxes change separation spacing and how close enemies can get before contact — a real (if probably small) combat-feel change, not just cosmetic.
>
> **Party cap removed**: see DECISIONS.md — every sweep to date assumed 3-of-4; a real player can now field all 4. No comp with the full roster has been swept.
>
> **V2 fog-of-war rules** (`lane_battlefield.tscn` FogOfWar overrides, `fog_alpha 1.0`/`memory_alpha 0.0`): unexplored ground is now fully opaque (was 0.88 — obstacles/spawn points no longer faintly show through); explored ground never dims again once seen (was a 0.30 "memory" wash). Visual/information only, not a combat-values change — noted here since it changes how much of the field a player can plan around at a glance.

> **⚠ Updated 2026-07-19 (V2 grind progression, scheduled task) — all numbers first-pass, unverified by a live playtest or sweep:**
>
> **Career achievement thresholds** (`scripts/achievements.gd`) — unlock ARTEMIS/WARDEN/BEACON respectively: `minions_killed 150`, `gates_destroyed 10`, `best_villain_damage_pct 0.5`. Guessed to land hero #2 in ~2–4 runs, full roster in ~10–15 — **now sitting on top of a slower early curve** than assumed, since removing Lone Wolf (below) also removed the solo `SYNERGY_XP_MULT` (1.25×) kill-XP bonus. Needs recalibration against real solo swarm throughput.
>
> **Ability tier costs** (`scripts/ability_tiers.gd`) — tier 2 (passive upgrade) 40g, tier 3 (ultimate) 70g, tier 1 free. Mirrors `AbilityMods`' 45–60g range for a single mod, so two tiers (110g total) costs roughly what 2 mods used to.
>
> **Gold drip** (`v2/enemies/lane_spawner.gd`) — 0.5g/minion kill (fractional, banked as it crosses whole numbers), 15g/spawn-gate destroyed, on top of the unchanged run-end `gold_for_run()` payout. Banked via `GameState.bank_gold()` (no per-kill disk save — flushed once by the existing `award_gold()` save at run end).
>
> **V2 stage configs** (`v2/config/lane_{1,2,3}_stage_config.tres`, new — V1's `config/stage_*_config.tres` untouched): swarm cap/max/batch roughly +50-75% and spawn_interval ~35-40% shorter than the shared V1 numbers; new `StageConfig.villain_hp_mult` field (additive, V1 defaults to 1.0) set to **1.6 on L1**, **1.4 on L2/L3**.
>
> **Level 1 gate HP raised** (`v2/config/lane_1_layout.tres` spawn_points z-component): 220/260/320/380 → 340/400/480/560 (~50% up across the board), stacked with the villain_hp_mult and heavier swarm above and the Lone Wolf removal below — together meant to make solo Thundaar structurally unable to clear L1 (the core design bet; unverified by an actual battle spin-up this pass, see PRODUCTION.md verification notes).
>
> **Lone Wolf removed for V2** (`hero.gd:518`): the solo-roster ×1.8 HP / ×1.75 damage / −0.4s cooldown compensation buff (see the Stage-3/Lone-Wolf entry below) now only applies when `not GameState.v2_mode`. V1's numbers and behavior are untouched byte-for-byte; V2 solo runs get none of it.

> **⚠ Updated 2026-07-18 (Level 1 tightening pass, same session):** two Designer-requested tuning changes, values unverified against a fresh sweep:
> - **Early boon cadence** (`RunState.xp_needed`): levels 0–2 now cost **half** XP (`EARLY_LEVEL_DISCOUNT 0.5`, `EARLY_LEVEL_CAP 3`) so a hero's first few boon picks land faster; growth reverts to the normal `XP_BASE 40 × XP_GROWTH 1.35` curve from level 3 on.
> - **Ability mod downsides disabled** (`scripts/ability_mods.gd`, `Hero._apply_ability_mod`): all 8 permanent gold-bought mods are upside-only for now — the downside lines are commented out in code (not deleted) so the tradeoff design can return later. `desc` strings trimmed to match.
>
> **⚠ Updated 2026-07-18 (gameplay-loop rework — balance UNVERIFIED):** the run is now a chain of levels; heroes carry HP/boons/levels across levels, so difficulty compounds within a run in a way the old per-battle gates never modeled. New first-pass tunables introduced this pass, all flagged for a tuning pass (Level 1's swarm/layout since re-tuned — see the Level 1 whole-run sweep section below; Level 2/3 still carry the pre-rework numbers untouched):
> - **Gold payout** (`GameState`): `GOLD_PER_LEVEL 10`, `GOLD_WIN_BONUS 15`, `GOLD_MIN 5` (scales with levels cleared).
> - **Ability mods** (`scripts/ability_mods.gd`): 8 permanent per-hero tradeoffs, costs 45–60g, up/down magnitudes first-pass (e.g. Seismic Stomp radius ×1.6 / cooldown +1.5s; Glass Arrows dmg ×1.30 / HP ×0.80).
> - **Focus ping** (`scenes/battle/focus_ping.gd`): 3 charges, 5s lifetime, 320px influence radius, `SCORE_FOCUS_PING 260` targeting weight.
> - **Villain dormancy** (`Combatant.villain_aggro_radius`): 350px on all three villains (just inside fog vision 400 so they're seen on waking).
> - **Dark Mage leash** (`villain.gd leash_radius 520`): fixes the prior "un-catchable teleporter" flag — he now juke-teleports only within his lair area, so a chasing party's progress isn't reset. Confirmed in the Level 1 sweep below: he's now reliably found and finished off.
> - **Lone-deploy boon** (`BattleManager.LONE_DEPLOY_DISTANCE 550`): a 2+ hero party member placed >550px from every ally gets a free boon. Distinct from the solo-roster **Lone Wolf** standing buff (they don't stack — Lone Wolf is size-1 only), but the interaction of both being "reward isolation" wants a look.

## Difficulty pass (2026-07-19) — hero stat rebase, BEACON ultimate, denser swarm, tougher villains

Designer feedback: game plays too easy. This pass rebases all four heroes onto a Designer-authored stat table, adds BEACON's first second-ability (Confuse), raises minion density, and bumps villains modestly.

**Hero base stats — rebased (`HERO_STATS` / `ARTEMIS_ATTACK_INTERVAL` in `hero.gd`):**

| Hero | HP | DMG | ATK | SPD |
|---|---|---|---|---|
| THUNDAAR | 120→110 | 10 | 0.7 | 88→90 |
| ARTEMIS | 65→80 | 6 | 0.32→0.4 | 102→100 |
| WARDEN | 85→90 | **9→6** | 0.55→0.6 | 95→90 |
| BEACON | 95→100 | 6→8 | 0.6 | 98→90 |

- **WARDEN DMG 9→6 reverses the same-day buff** (7→9) that took the no-burst THUNDAAR+WARDEN+BEACON comp 0%→66% on L3. Applied verbatim per Designer instruction; the consequence is documented below, not silently patched.
- Move-speed spread tightened again to 90–100 (~1.11×), continuing the 2026-07-18 compression (1.53×→1.16×). Deliberate.

**BEACON Confuse (ultimate / second-ability slot, `hero.gd`):** cone of light (range 200, half-width 90) toward the nearest cluster; every minion caught is confused for 3s — targets and attacks its own group (new `Combatant._confused_t` / `apply_confusion` / `_effective_enemy_group`; minions physically walk at neighbors via `_nearest_confused_mate`). Cooldown 12s, fires only with ≥2 in-cone, **villains immune**. New status ring colour `STATUS_CONFUSE_COLOR` (magenta). Bigger swarms are now partly self-consuming, which buys density headroom.

**Swarm density (`config/stage_*_config.tres`):** `swarm_max_cap` 40/45/50 → 52/58/64; `spawn_batch` 2→3 all stages.

**Villains (modest +~20-25%):** Dark Mage 1200→1450 HP; Berserker 600→725 HP / 8→10 dmg; Mech Robot 850→1050 HP / 10→12 dmg.

**Sweep results (8 trials/comp, trios-only; noisy at N=8):**
- **Zero-mod floor:** L1 ~50–87% (target 90–100, slightly low for weaker comps), L2 became the structural wall (~0–16%, was ~40 — this is the intended "need mods" floor), full-run ~0–12%.
- **With mods (1 upgrade/hero):** tank comps clear full runs — T/A/W ~50%, T/A/B ~37% (both at/above the 20–30% target); L2/L3 passable. No-tank A/W/B correctly ~0% (locked out).
- **Known deviation — no-burst T/W/B collapsed to ~0% even with mods**, driven by the accepted WARDEN DMG nerf (a zero-hard-burst comp can't beat the raised villain HP checks). Reported, not re-tuned — flagged for Designer call (revisit WARDEN, or accept that the no-burst comp needs a burst hero).
- Net: the game is meaningfully harder; mods now matter; BEACON comps run clean through all 3 levels with Confuse live.

## MVP 3-level balance pass (2026-07-19) — layout differentiation + whole-run tuning

Goal: an MVP where a whole **run** (Level 1→2→3) is a real, completable curve, layouts differ enough that geometry is a balance lever, and the sweep covers every implemented system and stays open to future levels. **Trios only this pass** (Designer call): solo/Lone-Wolf is left in code but untested — solo Thundaar (216 HP) currently out-tanks a trio Thundaar (120 HP), inverting the party fantasy, so the game is tuned/felt as obligatory trios before deciding solo's fate. Target curve: L1 ~90% / L2 ~60% / L3 ~40%, full-run **20–30% for a good trio**.

### Environment differentiation (each level now has a spatial thesis)

Layouts were re-authored so geometry — not just numbers — shapes each fight (`config/level_N_layout.tres`). Deploy→lair held at the proven **~1900px** on all three (the L1/L2 travel-exposure fix), so difficulty comes from *what's in the way*:

| Level | Thesis | Geometry |
|---|---|---|
| **L1 — Dark Mage** | **Open field** (onboarding) | 4 obstacles (was 5), pulled off the deploy→lair line; lakes to the corners; all 4 gates on the lair side so pressure only comes from ahead. |
| **L2 — Berserker** | **Chokepoints** | Central `(0,0,170)` blocker splits the approach into a north and a south lane, each pinched by an obstacle + a lake; gates split 3-ahead / 1-flanking-north. Warden comps route ~8s slower here (villain alerts ~24s vs Artemis+Beacon's ~16s) — the terrain differentiates comps. |
| **L3 — Mech Robot** | **Encirclement** (the gauntlet) | **Travel cut ~3100px→~1945px** (its dominant, never-fixed failure — the party used to die in transit, never reaching the lair). Central hard blocker kept; obstacles ring the field; gates on **all four sides incl. behind the deploy anchor** so the swarm arrives from the rear; objectives pushed off the direct path (detour-vs-risk). |

Fog is stored per level against geometry (`user://fog/level_N.png`) — the old fog was wiped since every layout moved.

### Tuning (layout > stage config > villain stats; hero base stats + boons untouched)

| Value | Before | After | Why |
|---|---|---|---|
| Dark Mage `max_hp` | 1500 | 1200 | L1 fights ran 70–80s; shorter fight = less swarm chip over its length |
| `stage_1` cap_start / interval | 10 / 3.3 | 8 / 3.6 | Ease L1 toward the ~90% onboarding target |
| Berserker `max_hp` | 750 | 600 | L2 was a DPS-race loss for lower-DPS comps |
| `stage_2` cap_start / interval | 14 / 2.8 | 12 / 3.1 | Ease L2 swarm a step |
| Mech Robot `max_hp` / `damage` | 2500 / 14 | 850 / 10 | Un-kiteable stationary tank was unbeatable for a depleted lvl-2 party; brought into the Berserker's range |
| `stage_3` cap_start | 24 | 12 | L3 swarm was ~2× L2's — its peak (18–20) still reads a touch denser than L1/L2 (~10) by design |
| `stage_3` interval / batch | 3.0 / 3 | 2.6 / 2 | (batch/escalate also normalized to L1/L2: escalate 12s/+4 → 16s/+2, max_cap 80 → 50) |

### Result (final sweep, 4 trios × 8 trials = 32 full-run attempts)

| Comp | L1 | L2 | L3 | Full run |
|---|---|---|---|---|
| Thundaar+Artemis+Warden | 100% | 12% | (1/1) | 12% |
| Thundaar+Artemis+Beacon | 87% | 42% | 33% | 12% |
| Thundaar+Warden+Beacon | 100% | 37% | 33% | 12% |
| Artemis+Warden+Beacon (no tank) | 37% | 0% | — | 0% |

**Read on this:** the run went from *L3-unreachable / 0% completable* to **every tank trio completing it (~12% each)**, with the no-tank comp correctly locked out. L1 ~90–100% (on target), L3 ~33% (near its 40% target). **L2 is the noisy lever** — it swung {100/12/50}→{12/42/37} between two sweeps whose only change was Mech HP (which can't affect L2), i.e. ±30 points of spawn/L1-survival RNG at 8 trials; averaged it sits ~40% (a hair under the 60% target). Full-run ~12% is the low end of the 20–30% target, with best-case **50%** observed the prior sweep — the target is bracketed, not centered. Not chasing L2 further against that variance; the next real lever if it wants centering is easing L2 specifically for lower-DPS (Warden) comps without trivializing it for Artemis+Beacon. **This is a numbers baseline for the Designer to *feel*, per the value-proposition/mastery question that only a human can answer.**

### Mod-state control + zero-mod vs. with-mods comparison (2026-07-19, same session)

**Gap found:** the sweep never controlled `GameState.owned_mods` — it reads straight from `user://save.json` on process start (`GameState._ready() → load_game()`), so every sweep above silently rode on whatever mods happened to be owned on the machine running it (empty, this time, by luck — not by design). Also never varied hero **priority** (`ATTACK_VILLAIN`/`CAPTURE_OBJECTIVES`/`ATTACK_MINIONS`/`SUPPORT_ALLIES`), which stayed at the default all pass. Priority variation is deliberately deferred (Designer call: the level/layout curve was this pass's job; revisit once the curve above is playtest-confirmed) — flagged here so it isn't forgotten.

**Fix:** `BalanceSweep.mod_loadout` is now set explicitly per sweep instance (`GameState.owned_mods = mod_loadout.duplicate()` at the top of every trial), and `balance_sweep_runner.gd` runs **two labeled passes** back to back: a zero-mod **floor** and a **with-mods** pass using one representative upside-only pick per hero (Iron Skin/Glass Arrows/Overcharge/Zealot — the flat-power picks, since downsides are currently disabled game-wide). Results land in separate files (`BALANCE_SWEEP_RESULTS_no_mods.json` / `_with_mods.json`) so neither pass clobbers the other.

Design intent (Designer, 2026-07-19): *"players should only be able to beat level 3 with at least 1 ability upgrade per hero used on run, good strategy, and a little bit of luck."*

| Comp (run 1) | Zero-mod full-run | With-mods full-run |
|---|---|---|
| Thundaar+Artemis+Warden | 0% | 25% |
| Thundaar+Artemis+Beacon | 25% | 50% |
| Thundaar+Warden+Beacon | 12% | 50% |
| Artemis+Warden+Beacon (no tank) | 0% | 0% |

| Comp (run 2, post teardown-fix — see below) | Zero-mod full-run | With-mods full-run |
|---|---|---|
| Thundaar+Artemis+Warden | 12% | 12% |
| Thundaar+Artemis+Beacon | 25% | 37% |
| Thundaar+Warden+Beacon | 0% | **75%** |
| Artemis+Warden+Beacon (no tank) | 0% | 25% |

**Read on this — matches intent across both runs:** mods roughly double-to-triple the full-run clear rate for tank trios, consistent with "achievable with mods + good strategy + luck," not guaranteed. Run 2's no-tank comp hit 25% with mods (vs. 0% everywhere else it was measured) — within 8-trial noise for a comp sitting right at the edge (L1 87%, L2 42%), not a real contradiction of "no tank = locked out," but worth knowing it isn't an absolute wall either. No further retuning done off this data; it confirms the current numbers already produce the intended shape.

**Harness teardown race — fixed (2026-07-19, same session):** the with-mods pass originally logged ~11 non-fatal `SCRIPT ERROR: ...previously freed` console errors per pass (`DeployController`/`StageField`). Root cause: `DeployController` normally frees ITSELF from inside its own `_unhandled_input`, triggered only by the player's final deploy click — `balance_sweep.gd` calls `BattleManager._on_deploy_chosen()` directly to skip those clicks, so the controller was never freed and sat processing (holding a stale `field` reference) into the next level, once that level's own field was torn down. Fixed at the root: `BattleManager` now owns and frees its `_deploy_controller` the instant `_on_deploy_chosen` runs, regardless of caller (`battle_manager.gd`), plus defensive `is_instance_valid(field)` guards added in `DeployController._process`/`_unhandled_input` (`deploy_controller.gd`) as a second layer. Re-verified: errors dropped from ~11/pass to 1 across a fresh 64-trial two-pass run, with zero corrupted (`error`/`timeout`) trial outcomes in either run — the residual single occurrence is a separate, much narrower timing window in the sweep's own retry loop, non-fatal and not chased further (dev-only tool, never shipped).

### Sweep harness changes (`scenes/tools/balance_sweep.gd` + `_runner.gd`)

- **Solo comps dropped** (trios-only call); `TRIALS` 4→8 to halve the trio-rate noise.
- **Per-level diagnostics** added so a failure is diagnosable from the sweep alone (folds in what `death_curve_probe` was run separately for): `entry_hp` (exposed the L2 depletion problem), `time_to_villain_alert` (isolates travel from fight — the number that diagnosed L1/L2/L3), `peak_minions`, `kills`, `objectives_captured`, per-hero end level + boons. Focus-ping usage deliberately *not* recorded (headless has no player input — would always read zero). The runner prints these under each per-level clear-rate line.
- Still driven by `RunState.current_level` + the `while true` level chain, so a future `level_4_layout.tres` + `stage_4_config.tres` is swept automatically with no harness edit.

## Scheduled balance sweep (2026-07-19) — floor/mods re-check + first priority-variation pass

Ran as an unattended background pass (4am) via the existing harness — no code/value changes made this pass, diagnostic only. **The sweep's own session stopped after generating results and never wrote its findings back to this doc**; the numbers below were pulled from the raw `BALANCE_SWEEP_RESULTS_*.json` files after the fact. Same 4-trio matrix, 8 trials/comp, same `LEVEL_CAP_SIM_SECONDS`.

**Zero-mod floor** (target: L1 ~90% / L2 ~60% / L3 ~40%, full-run 20–30%):

| | L1 | L2 | L3 |
|---|---|---|---|
| Clear rate | 75% | 42% | 40% |

| Comp | Full-run |
|---|---|
| Thundaar+Artemis+Beacon | 38% |
| Thundaar+Warden+Beacon | 12% |
| Thundaar+Artemis+Warden | 0% |
| Artemis+Warden+Beacon (no tank) | 0% |

**L1 read 75% zero-mod, below the earlier ~90% figure** — but Designer-confirmed (2026-07-19) this is an acceptable zero-mod floor: the ~90% target was always meant for a party with at least some gold spent, not a fresh zero-mod run. Not chasing this further; no re-sweep needed.

**With gold mods** (1 flat-power mod/hero — Iron Skin/Glass Arrows/Overcharge/Zealot):

| | L1 | L2 | L3 |
|---|---|---|---|
| Clear rate | 91% | 66% | 68% |

| Comp | Full-run |
|---|---|
| Thundaar+Artemis+Beacon | 75% |
| Thundaar+Warden+Beacon | 62% |
| Thundaar+Artemis+Warden | 25% |
| Artemis+Warden+Beacon (no tank) | 0% |

Consistent with the existing Designer intent ("beatable with ≥1 upgrade/hero + strategy + luck, not free") — mods roughly double full-run clears for every tank trio, no-tank comp still locked out.

**First priority-variation pass (new — previously flagged as never swept):** `balance_sweep_runner.gd` gained a third pass, `ALT_PRIORITY_ALL_FARM` — every hero forced to `ATTACK_MINIONS` (never explicitly targets the villain), zero mods, isolating priority choice from gold spend. All 4 comps completed the full 8/8 trials (confirmed directly against the raw `"trial":N` markers in `BALANCE_SWEEP_RESULTS_alt_priority.json` — an initial parse of this data mis-reported one comp as only 5/8 due to a regex bug on re-analysis, not a harness issue; corrected below). Full-run result: **worse than or equal to the matching zero-mod default-priority floor for every comp** — Thundaar+Artemis+Beacon 25% (vs. 38% default), Thundaar+Warden+Beacon 0% (vs. 12% default), the other two comps 0% both ways. Reads as expected — a party that never commits to the villain can farm the swarm indefinitely but never closes out the level — and is the first real evidence that the current default priority (`ATTACK_VILLAIN` for everyone but Beacon's `SUPPORT_ALLIES`) is actually better than at least one alternative, rather than an untested assumption. Priority variation beyond this one extreme profile is still open (e.g. a mixed profile, or Beacon-only support vs. all-push).

No tuning changes recommended off this data — it's a diagnostic re-check, and the numbers now read as an accepted baseline (see L1 note above). Priority variation beyond the one all-farm extreme profile remains open for a future pass.

## Design-testing fixes (2026-07-18, same session) — re-sweep result

Six fixes landed from a Designer playtest pass (behavioral/feel issues, not new balance numbers — see DECISIONS.md for the full list): support-ally leash band (260px, replacing a 46px hard tether), objective-capture commitment (a hero that has spotted an objective now holds it instead of getting pulled off by rally-to-ally or combat drift), hero move-speed compression (75–115 → 88–102), Poison Lake changed from an 8 HP/s drain to a single 6-damage hit per entry (with stronger avoidance steering), deploy-phase hero-color/name readability, and focus-ping-on-villain now locks + chases the villain's live position (was: minion-bias only, static point).

Two of these (speed compression, hazard rework) are real balance levers, so a full re-sweep was run to confirm Level 1 didn't regress:

| Party | Before this pass | After this pass |
|---|---|---|
| Thundaar (solo) | 75% (4/4 avg, prior sweep) | **100%** (4/4) |
| Artemis / WARDEN / BEACON (solo) | 0% | 0% (unchanged by design — a fragile hero alone still dies fast) |
| Thundaar+Artemis+WARDEN | 50% | **100%** |
| Thundaar+Artemis+BEACON | 0% | **100%** |
| Thundaar+WARDEN+BEACON | 0% | **75%** |
| Artemis+WARDEN+BEACON (no tank) | 0% | **25%** |

No comp regressed; every trio anchored by Thundaar now clears reliably (avg survivor HP on win dropped somewhat — 96%→44–51% for the trios — reflecting real fights rather than trivial ones), and the no-tank trio picked up its first-ever win. Level 2 stayed at 0% across the board, consistent with the pre-existing, already-flagged gap (still on stale pre-rework numbers — see "Known follow-up" below).

**Read on this:** the AI/feel fixes (support behavior, capture commitment, ping-on-villain) had no measurable balance cost, and the speed/hazard changes landed as a net positive rather than a regression — likely because tighter speeds keep the party's damage output clustered together (feeding focus-fire and Rally/synergy uptime) more than the faster Thundaar's shorter effective travel window hurt. Not chasing this further this pass; L2/L3 tuning remains the next real balance work.

## Whole-run balance sweep (2026-07-18) — methodology + Level 1 findings

**`balance_sweep.gd` reworked** for the new loop: it no longer injects a power level (the old model granted boons directly to simulate a persistent-upgrade axis that no longer exists). It now plays whole **run attempts** — the same way a real player would, chaining battlefield scene loads on each win — for every solo hero (worst case once a run is down to one survivor) and every 3-of-4 trio (`RunState.PARTY_CAP`, what a real player drafts), 4 trials each, at 10× sim speed. `scenes/tools/balance_sweep_runner.gd/.tscn` is the entry point (`godot --headless … res://scenes/tools/balance_sweep_runner.tscn`); full per-trial detail lands in `BALANCE_SWEEP_RESULTS.json`, a console summary prints per party comp. New companion tool: `scenes/tools/death_curve_probe.gd/.tscn` — a single instrumented run that prints hero HP%/level, swarm count, and villain HP%/alert-state every few sim seconds, for diagnosing *where* a run dies rather than just whether it did.

**Initial sweep result: 0% clear rate across all 8 party comps.** Every comp — including the tankiest solo (Thundaar) and every trio — wiped at Level 1, in 29–76 sim-seconds. The `death_curve_probe` trace explained why: Level 1's original layout placed the deploy point and the villain's fixed lair at opposite corners of the field (~3170px apart) — at Thundaar's 75px/s move speed that's ~42s of pure travel, all of it under continuous chip damage from the escalating gate swarm, *before the party could even reach the (now-fixed, dormant) villain*. By the time the villain woke, a solo Thundaar was already down to ~38% HP; the ambient swarm (not the villain or his teleport-summon burst) was the dominant killer throughout. This is a structural mismatch introduced by the rework, not a code bug: Level 1's swarm throughput was tuned (through several "swarmier" passes, see below) assuming heroes arrive **already pre-buffed** with injected power (the old sweep's methodology, and — in real play — the old model's persistent multi-run stat grind); the new model requires a **zero-boon** party to survive *and* level up live, in one continuous encounter, and the old numbers never accounted for that cold start.

**Fix (Level 1 only):**

| Value | Before | After | Why |
|---|---|---|---|
| `level_1_layout.tres` deploy_anchor → villain_lair distance | ~3170px | ~1945px | Halves the pure-exposure travel window before the party can start actually fighting the villain |
| `stage_1_config.tres` swarm_cap_start | 18 | 10 | Cold-start party faces a much smaller initial swarm |
| `stage_1_config.tres` escalate_step | +4 | +2 | Gentler cap growth over a long fight |
| `stage_1_config.tres` escalate_every | 12s | 16s | The dominant lever for *trios*, which run longer (70–90s) than a buffed solo — slows late-fight density growth specifically |
| `stage_1_config.tres` spawn_batch | 3 | 2 | Lower per-tick throughput |
| `stage_1_config.tres` spawn_interval | 2.8s | 3.3s | Lower throughput |
| `stage_1_config.tres` swarm_max_cap | 60 | 40 | Lower ceiling for very long fights |

Each change was validated with `death_curve_probe` between iterations (travel-distance fix alone took a solo Thundaar death from 67%-villain-HP-remaining to 5%; the escalation-rate fix then flipped several near-misses into wins) before committing to a full re-sweep.

**Sweep result after the fix** (32 trials, 150s level cap — an earlier 90s cap was too short and falsely counted a couple of genuinely-winnable trio fights as timeouts; corrected before trusting these numbers):

| Party | Level 1 clear rate | Avg sim time | Notes |
|---|---|---|---|
| Thundaar (solo) | **100%** (4/4) | 81.9s | Lone Wolf ×1.8 HP/×1.75 dmg carries this hard; then 0% at Level 2 (untouched, see below) |
| Artemis / WARDEN / BEACON (solo) | 0% (0/4) | 28–39s | A fragile hero alone dies fast — matches "dangerous to go alone" by design; no standing buff besides Lone Wolf helps here since it's the same buff Thundaar gets, just less HP to multiply |
| Thundaar+Artemis+WARDEN | **50%** (2/4) | 78.8s | Genuine coin-flip variance — the target shape for an onboarding level |
| Thundaar+Artemis+BEACON | 0% (0/4) | 88.0s | Close (right at the tail), Artemis dies early and consistently (~t=20–30s) in every trio trial — glass-cannon by design (65 HP, lowest of all 4), not a bug |
| Thundaar+WARDEN+BEACON | 0% (0/4) | 81.4s | Also close |
| Artemis+WARDEN+BEACON (no tank) | 0% (0/4) | 43.8s | Expected — no tank in the comp at all |

**Read on this:** the fix took Level 1 from *literally unbeatable* to a real, tense curve — comps anchored by Thundaar consistently reach the tail of a long fight (78–88s) with the villain nearly dead, comps without him don't get that far. Not chasing every comp to a high clear rate deliberately — a level a player will replay many times shouldn't be free, and "some comps/some luck" clearing is enough for forward run progress to exist. If a future pass wants trio clear rates higher across the board, the same levers apply (throughput/escalation), but pushing further risks trivializing Thundaar-solo, which is already at the ceiling.

**Known follow-up:** ~~Level 2 (Berserker)~~ — **done, see the Level 2 section below.** Level 3 (Mech Robot) still carries its original layout/swarm numbers untouched and confirmed too hard (0/4). It needs the same methodology: a `death_curve_probe` / chained-probe pass to find its failure mode, then targeted tuning, then a re-sweep.

## Whole-run balance sweep (2026-07-18) — Level 2 (Berserker) findings

Same methodology as Level 1, but the diagnosis surfaced a **structural** problem that pure stage/villain tuning could not solve, plus a mislabeled metric worth recording:

**Two diagnostic traps corrected first:**
1. The `death_curve_probe` starts each level *fresh at full HP* (isolated diagnosis) and runs at 6× time scale. The **sweep** chains L1→L2 (heroes arrive *depleted*, carrying HP) and runs at **10×** (harsher combat resolution). Fresh-probe wins therefore badly overstated real survivability — a chained probe (run L1 to a win, then trace L2 at 10×) was built to reproduce the sweep faithfully.
2. The sweep-runner's "avg survivor HP on win" prints **raw HP averaged**, not a percentage — e.g. a solo Thundaar "159" is 159/216 max ≈ 74%, and a trio Thundaar "80" is 80/120 ≈ 67%. Read it as raw HP, not %.

**Real failure mode (chained probe):** survivors reach Level 2 at ~**36% HP** (solo Thundaar 78/216), and trios usually arrive as a *lone* depleted Thundaar because the squishies died during Level 1. With **no between-level heal**, no amount of Level-2-only tuning reproduced Level 1's curve — Level 1 always starts fresh at full HP, Level 2 never does. Designer call: **add an on-clear heal** rather than trivialize the Berserker.

**Fix (Level 2):**

| Value | Before | After | Why |
|---|---|---|---|
| **NEW `battle_manager.gd` `CLEAR_HEAL_MISSING_FRACTION`** | — | 0.5 | On clearing a level, each survivor recovers 50% of *missing* HP before it carries forward (a 36%-HP survivor resumes at ~68%). Root-cause fix for the depleted-entry problem; also benefits Level 3. Dead stay dead (permadeath unchanged). |
| `level_2_layout.tres` deploy→lair distance | ~3200px | ~1880px | Same travel-exposure fix as Level 1 (villain was never even reached before) |
| `berserker.tscn` max_hp | 2000 | 750 | Cold-DPS-race lever; a healed-but-not-full party can now close the fight |
| `berserker.tscn` damage | 15 | 8 | His melee was shredding squishies faster than the party could out-DPS 2000 HP; keeps his charge/recover rhythm as the threat, less one-shot lethality |
| `stage_2_config.tres` swarm_cap_start | 63 | 14 | Was ~6× Stage 1's; cold-start party faced near-max density instantly |
| `stage_2_config.tres` escalate_every / step | 12s / +4 | 16s / +2 | Gentler growth over a long fight (matches Stage 1's eased curve) |
| `stage_2_config.tres` swarm_max_cap | 216 | 45 | Was ~5× Stage 1's ceiling |
| `stage_2_config.tres` spawn_interval / batch | 1.1s / 6 | 2.8s / 2 | Throughput was ~3× Stage 1's |

**Sweep result after the fix** (32 trials, heal enabled):

| Party | Level 2 clear rate | Notes |
|---|---|---|
| Thundaar (solo) | **100%** (4/4) | Reliable carry, mirrors Level 1's solo ceiling — Lone Wolf ×1.8 HP + the heal |
| Thundaar-anchored trios | **0–50%** (noisy) | Coin-flip depending on whether squishies survive Level 1; one trio hit 50% this sweep, others 33–50% in prior samples — trio Thundaar has only 120 max HP vs solo's 216, so the fight is genuinely harder |
| No-Thundaar comps | 0% | Never clear even Level 1 — expected |

**Read on this:** Level 2 went from *literally 0% across every comp* to solo-reliable / trio-coin-flip — the same shape as Level 1, a step harder (Berserker actively fights back where Dark Mage is passive; elite minions are ~30% tougher). Trio rates are noisy at 4 trials because they hinge on Level-1 survival luck; the stable signal is that Thundaar reliably clears and the run can progress. The heal is the load-bearing change — the Berserker/swarm cuts only matter because a healed party can act on them. **Note:** with the heal fixing entry HP, the deep Berserker/swarm cuts may now leave headroom to walk his numbers *up* a little if a future pass wants Level 2 tenser for solo; left conservative here to guarantee forward progress exists.


> **Updated 2026-07-15 (rebalance pass):** Hero stat differentiation, synergy system, XP economy tuning, and swarm density increase. Previous gates (LV 10 / LV 25) require re-verification with new economy. Unit scenes and stage configs are the source of truth.
>
> **Updated 2026-07-15 (swarmier pass):** Spawn throughput and on-screen caps raised ×1.5 for a denser "swarmy" feel; minion damage and XP value cut ÷1.5 to hold the chip-damage and XP budgets (and thus the LV 20/LV 25 gates) constant. Verified in-engine — see Swarm and Stage gates sections below.
>
> **Added 2026-07-16 (role system + formation bonuses):** Role assignment (TANK/BURST/CONTROL) at prep screen with proximity-based formation bonuses. Emerges from role pairings: same-role clustering ×1.1 damage; Tank+Burst opposition ×1.15 multiplier each; mixed trio (3+ roles) ×0.05 cooldown. Applied to all damage (combat + abilities) and cooldown timers. Verified: UI rendering, hero spawning with role intact, formation bonus calculation on each frame. Existing balance gates (LV 10/LV 25) and Lone Wolf/Synergy systems unaffected (role bonuses are separate multiplier tier).
>
> **⚠ Updated 2026-07-18 (M2 — persistent stat grind retired, hybrid roguelite):** Everything below that references "upgrades," "LV" as a persistent purchase count, or the old stage win gates (LV 10/LV 19–26/LV 25 etc.) describes the **pre-M2 model and is stale**. Heroes now always spawn at the flat base stats in the table below; there is no more per-upgrade scaling. Hero abilities are **intrinsic** (full kit from run start) instead of gated behind skill-tree points. Power now comes from in-run boon picks (see "Run boons" section) and, later, meta-unlocked relics. **`BALANCE_SWEEP_RESULTS.json` and every stage win-gate number in this file predate this change and are not comparable** — a fresh `balance_sweep.gd` run + tuning pass is an open follow-up (tracked in BACKLOG.md). Sections are left in place as historical reference for swarm/minion/villain tuning, which M2 did not touch.

## Combat stats (updated 2026-07-18 — flat base stats, M2)

### Heroes (flat base stats — no persistent per-upgrade scaling; see M2 flag above)

| Hero | Role | Base HP | Base Damage | Attack interval | Attack range | Ranged? | Move speed |
|---|---|---|---|---|---|---|---|
| Thundaar | TANK | 110 | 10 | 0.7s | 26 (melee default) | No | 90 |
| Artemis | BURST | 80 | 6 | 0.4s | 160 | Yes | 100 |
| WARDEN | CONTROL | 90 | 6 | 0.6s | 120 | Yes | 90 |
| BEACON | SUPPORT | 100 | 8 | 0.6s | 26 (melee default) | No | 90 |

> **Rebased 2026-07-19 (difficulty pass)** onto a Designer-authored table — see the "Difficulty pass" section at the top. WARDEN DMG 9→6 reverses the same-day L2/L3-centering buff below (accepted by Designer; the centering section's rationale for a higher WARDEN number still stands and is the flagged risk).

**Stat differentiation:** Thundaar (TANK) is durable and slow. Artemis (BURST) is fragile, fast-attacking, ranged DPS. WARDEN (CONTROL) is a squishier ranged controller — its value is Ensnare *and* real personal damage (raised 2026-07-19, see "L2/L3 centering" below). BEACON (SUPPORT) has modest HP/low personal damage — its value is Rally's party buff. Roles are **fixed per hero**, determined at spawn via hero name.

### L2/L3 centering for low-DPS comps (2026-07-19)

**Problem:** the whole-run sweep showed THUNDAAR+WARDEN+BEACON (no burst hero) clearing L2 fine (62%) but flatlining at L3 (**0%**, 0/5) — a comp with zero real damage output can't beat a raw HP check like the Mech Robot even when it survives the earlier levels. Two other hypotheses were checked and ruled out first: (a) the previously-documented "Warden comps route ~8s slower through L2's chokepoint" — re-probed directly, alert times now cluster 15–19s for every comp with no gap, so that finding was stale (predates the chokepoint/heal/Ensnare tuning); (b) Ensnare providing indirect DPS value by locking down the villain — checked the targeting code, Ensnare anchors on WARDEN's current attack target (usually a minion), so it rarely lands on the villain at all.

**Fix:** `WARDEN` base damage 7 → **9** (`HERO_STATS` in [hero.gd](scenes/heroes/hero.gd)), raising its DPS from ~12.7 to ~16.4 — between Thundaar's ~14.3 and Artemis's ~18.75, still the lowest of the three attack-focused stats but no longer negligible. Chose a stat buff over retargeting Ensnare onto the villain (a mechanic change) or cutting Mech Robot HP further (risks trivializing L2/L3 for the trios already clearing 50–100% there) — Designer call.

**Re-sweep (8 trials/comp, zero-mod floor):**

| Comp | L2 | L3 | Full run |
|---|---|---|---|
| THUNDAAR+WARDEN+BEACON | 62%→75% | **0%→66%** | **0%→50%** |
| THUNDAAR+ARTEMIS+WARDEN | 75%→50% | 50%→100% | 37%→50% |
| THUNDAAR+ARTEMIS+BEACON | 75%→62% | 50%→100% | 37%→62% |
| ARTEMIS+WARDEN+BEACON (no tank) | 40%→14% | 100%(n=2)→100%(n=1) | 25%→12% |

L2's swing on the two unaffected-by-WARDEN-buff numbers is within the already-documented ±30pt/8-trial noise band (driven by L1-survival RNG, not this change); the L3/full-run jump for the Warden-anchored tank trio is the real, decisive signal. No comp regressed outside that noise band, including the tankless comp (still inside the 0–25% range every prior sweep has shown it).

**Move speed compressed 2026-07-18** (design-testing fix): the prior 75–115 spread (1.53×) read as heroes stringing out across the field rather than fighting together. Tightened to 88–102 (1.16×) — see "Design-testing fixes" above for the re-sweep confirming no balance regression.

## Run boons (M1 — in-run leveling, resets every run)

Each hero levels up independently from farmed XP (rising curve: `40 × 1.35^level` XP per level, `RunState.xp_needed`). On level-up the battle pauses and offers 1-of-3 boon picks from this catalog (`scripts/boons.gd`); picks are permanent for the current run only and apply as a direct multiplier to the hero's live stats.

| Boon | Effect |
|---|---|
| Power | +15% Damage |
| Vitality | +15% Max HP |
| Haste | −10% Attack interval |
| Swiftness | +12% Move speed |
| Fortune | +20% XP gained |
| Ferocity | +8% Damage, +8% attack speed (both, smaller each) |

First-pass values — not yet tuned against real playtests of the new model.

## Meta-currency (M2 — persistent, wiped 2026-07-18 save schema v3)

| Value | Amount |
|---|---|
| Awarded on run win | 15 |
| Awarded on run loss | 5 |

Spent (once real content exists — currently nothing to buy) at the unlock shop to add new heroes/relics to the pool. First-pass values.

### Minions & Villains

| Unit | HP | Damage | Attack interval | Attack range | Detect range | Move speed | XP value |
|---|---|---|---|---|---|---|---|
| Minion (Stage 1) | 10 | 1.0 | 0.8s | 18 | 70 | per stage config | 2 |
| Elite Minion (Stage 2) | 14 | 1.3 | 0.8s | 18 | 80 | per stage config | 2 |
| Ranged Minion (Stage 3, placeholder) | 12 | 1.2 | 1.0s | 100 | 60 | 85 | 2 |
| Brute Minion (Stage 3, placeholder) | 18 | 1.8 | 0.8s | 18 | 70 | 80 | 3 |
| Villain (Dark Mage) | 1500 | 0 (no attack) | — | — | — | 0 (stationary) | — |
| Villain (Berserker) | 750 (was 2000) | 8 (was 15) | 1.1s | 26 | 120 | 80 (3s charge / 1.5s recover) | — |
| Villain (Mech Robot, placeholder) | 2500 | 14 | 0.9s | 40 | 100 | 0 (stationary, melee only) | — |

Minion HP/damage/xp were halved and body_radius shrunk (art pass — smaller sprites reads better at swarm density); hero gained `knockback_chance 0.1` / `knockback_distance 40` / `knockback_splash_damage 6` (contact knockback, not ability-only).

**2026-07-15 swarmier pass:** minion/elite damage and XP value cut a further ÷1.5 (1.5→1.0, 2→1.3; xp_value 8→5) to offset the ×1.5 spawn-throughput increase below — see Swarm section for the full rationale and in-engine re-verification.

**2026-07-16 minimum-swarm-XP pass (Designer feedback — swarm kills should be minimal, runs are long enough to farm many of them):** removed the density bonus entirely (previously +1 XP per active minion on field, capped +30 — this compounded XP *upward* with swarm size, the opposite of the intent) and cut base `xp_value` further: Minion/Elite/Ranged 5–6→2, Brute 7→3. A minion kill is now a flat, small value regardless of how many minions are on screen or how long the run has been going; meaningful progression should come from sustained kill volume, objective captures, and (eventually) villain kills rather than swarm-density scaling. Not yet re-verified against the stage gates below — expect the LV 19–26 duo win bands in the sweep section to shift upward; re-run `balance_sweep.gd` before treating those numbers as current.

## Hero abilities (updated 2026-07-18 — intrinsic kit, M2/M5)

Auto-cast on cooldown whenever an enemy is in detect range (Rally needs no enemy — casts proactively). **As of M2, every hero has its full ability kit from the start of every run** — the old skill-tree gating (base/passive/active unlock tiers bought with XP) is gone; Thundaar's stun-on-Stomp and Artemis's Clone-damage-boost are now always active. Damage/cooldown values are still a first pass, not tuned against fresh stage gates (see M2 flag above). All ability procs show a floating "ABILITY NAME!" callout above the caster and a colored status ring on affected units (cyan=stun, violet=slow, gold=buff, light-blue=shield) — see DECISIONS.md 2026-07-18 "Ability visual feedback."

| Hero | Ability | Cooldown | Effect |
|---|---|---|---|
| Thundaar | Stomp | 3.5s (starts once it lands a hit) | 26 dmg + 100px knockback + stun (0.5s) to every enemy within 70px; expanding shockwave-ring VFX on landing |
| Thundaar | Shockwave (2nd ability) | 5s | Wide line in front of him (180px range × 60px half-width), 40 dmg + 80px knockback |
| Artemis | Clone | 8s | Spawns a stationary copy of herself (+50% damage) 40px to her side for 2s; taunts enemies within 90px and fights back |
| Artemis | Dash (2nd ability) | 6s | Dashes toward the nearest enemy cluster, hitting up to 5 targets with escalating damage (+3/target) |
| WARDEN | Ensnare | 6s (starts once it catches something) | Roots every enemy within 95px of the current target (cluster anchor) for 1.2s |
| BEACON | Rally | 7s | Grants every hero within 180px (self included) +15% damage and +20% attack speed for 4s |

## Swarm (per-stage, continuous XP farm)

The swarm is a continuous, escalating farm (not finite waves). Win = defeat the villain; lose = all heroes die. See the incremental-loop intent in [Game_Design_Bible.md](Game_Design_Bible.md) §16. Values live in `config/stage_N_config.tres`.

**⚠ Stage 1 & 2 re-tuned 2026-07-18** for the gameplay-loop rework's cold-start / depleted-chain survivability — see the whole-run sweep sections above for the full before/after and rationale (Stage 2 also introduced the on-clear heal, the load-bearing fix). **Stage 3 still carries the pre-rework "swarmier pass" numbers, unverified and confirmed too hard** (0/4 clears) — due the same treatment before trusting it.

| Value | Stage 1 (2026-07-18) | Stage 2 (2026-07-18) | Stage 3 (unverified) | Notes |
|---|---|---|---|---|
| Swarm cap (start) | 10 | 14 | 24 | Max simultaneously active minions at run start |
| Spawn interval | 3.3s | 2.8s | 3.0s | Time between spawn ticks |
| Spawn batch | 2 | 2 | 3 | Minions spawned per tick |
| Escalate every | 16s | 16s | 12s | Cap grows over time so the farm intensifies |
| Escalate step | +2 | +2 | +4 | Cap increase per escalation |
| Max cap | 40 | 45 | 80 | Ceiling on active minions |
| Minion speed | 105 | 115 | 82 | Ranged+Brute hybrid mix, Stage 3 |
| Spawn points | 4 authored gates | 4 authored gates | 4 authored gates | All three levels read `spawn_gates` from their `level_N_layout.tres` (fixed-layout rework, Phase 6). Stage 3 still carries OLD throughput numbers (its column), unverified against a depleted chained party |

**Hunting/intercept:** minions re-evaluate their hunt goal every 0.3s, targeting a point `intercept_lead = 160px` ahead of the nearest hero (toward the villain), plus their per-minion cluster offset.

**Chip-damage model (why throughput is the knob):** every minion that reaches melee lands ≥1 hit before dying (its first attack has no cooldown), so each kill costs the party HP regardless of hero DPS. Party HP pool ÷ chip-per-kill = a hard budget of total kills a run can absorb. Spawn throughput bounds how fast the swarm forces those kills, so it — not the cap — decides whether the party's HP outlasts the travel + villain burn.

**2026-07-15 regression, caught and fixed:** an in-progress experiment (bigger swarm + deploy phase + fog of war) had left cap/interval at 60–70 → 220–260 with a 0.25s interval — ~22× the verified throughput. Re-run in-engine: a LV14/LV17 party (above the old LV10 gate) wiped completely without denting the villain. Rescaled cap/interval/batch back to match the original verified throughput; re-run confirmed the party held near-full HP through sustained combat and engaged the villain.

**2026-07-15 swarmier pass (Designer request — "more swarmy" feel):** spawn throughput (batch) and all caps raised ×1.5 for a denser on-screen swarm; minion damage and XP value cut ÷1.5 in the same pass (see Combat stats) so total per-run chip-damage and XP budgets are unchanged — density-bonus XP (`+1/active minion, capped +30`) already saturated below the old max caps, so it doesn't compound further. Re-verified in-engine: a LV 20 synergy duo cleared Stage 1 at ~26s-equivalent sim time with 188/220 (Thundaar) and 119/145 (Artemis) HP — matching the pre-swarmier-pass gate below (205/220, 125.5/145) within noise — and won outright shortly after (170/220, 114/145 final), with active-minion counts and kill counts markedly higher throughout (up to 30 active, 109 kills vs. the prior lower-density run).

## Stage 3: Mech Robot ability (placeholder, added 2026-07-16)

Stationary villain (like Dark Mage) that also fights back in melee (unlike Dark Mage) and periodically drops a slow zone on the nearest hero:

| Value | Current | Notes |
|---|---|---|
| Zone interval | 5s | Time between slow-zone casts |
| Zone duration | 4s | How long a dropped zone lasts |
| Zone radius | 60px | Any hero inside is affected |
| Slow factor | ×0.7 | Multiplies move speed and attack rate while inside |

Implementation: `Combatant.apply_slow(duration, factor)` (new shared method, additive — default `_slow_factor = 1.0` / `_slow_t = 0` means no existing unit behavior changed) drives both movement speed and attack-cooldown decay via `_effective_rate_mult()`. See `scenes/combat/combatant.gd`, `scenes/villain/mech_robot.gd`, `scenes/villain/abilities/slow_zone.gd`.

Swarm: hybrid mix of Ranged + Brute minions, 50/50 split per spawn tick (`MinionSpawner._pick_minion_scene`, driven by `minion_type = "hybrid_stage3"` in `stage_3_config.tres`).

## Poison Lake (Stage 1 hazard)

| Value | Current | Notes |
|---|---|---|
| Lake damage | 6 per entry (2026-07-18, was 8 HP/s drain) | `lake_damage` on `StageField`; edge-triggered by `Combatant` on the outside→inside transition — one hit, then silent until the unit fully exits and re-enters; affects **all** units (heroes and minions); no slow (Designer choice 2026-07-15) |
| Avoidance margin | body clearance + 90px, strength 1.6 (2026-07-18, was +50px/1.3) | Units skirt the shore well before entering; still soft avoid — pursuit of a target in/behind the lake can drag them through, now at a fixed one-shot cost instead of an open-ended drain |
| Hazard XP | none | Poison kills grant no killer XP credit |

Verified: 8 dps drain matches (190 → 173.9 HP over 2s); a goal straight through the lake routes around it (27/191 frames brushing the shore vs. 214 wading pre-tune).

## Duo Bonus System (2026-07-20 — replaces Synergy + Formation below)

> **⚠ First-pass numbers, not yet balance-swept** (no lane-shaped sweep harness exists — see DECISIONS.md balance-qa pass, 2026-07-20). Replaces the old opportunistic Synergy (any nearby ally) and role-based Formation (proximity stat auras) systems entirely — see DECISIONS.md for why. The "No-tank viability pass" and pairing-table history below is kept for record but **`FORMATION_PAIRS` no longer exists in code** — treat that section as historical, not current mechanics.

Active only when a hero has a **confirmed Duo partner** (`GameState.duo_pairings`, set via the prep screen's drag-and-drop pairing panel — not just "any ally nearby"), that partner is alive, and both are within **200px** (`DUO_DISTANCE`, `hero.gd`):

| | Damage | Cooldown reduction | XP |
|---|---|---|---|
| **Leader** | ×1.15 | −0.3s | ×1.25 |
| **Follower** | ×1.10 | −0.2s | ×1.15 |

**Leader/follower is a pure player choice, not role-derived:** whichever hero is dropped in a Duo's left/A prep-menu slot leads; right/B follows (`GameState.is_duo_leader`). Explicitly *not* "TANK always leads" — the Designer called this out as not fitting the new design; leading with an unconventional pick (e.g. Beacon) is meant to be a real, experimentable choice, not a wasted one.

**Per-hero leader/follower behavior (additive, on top of the table above — see [hero.gd](scenes/heroes/hero.gd)):**

| Hero | Leading | Following |
|---|---|---|
| THUNDAAR | ×1.20 attack speed only (`THUNDAAR_LEADER_ATK_SPEED_MULT`) | Bodyguard — hard-targets whatever is attacking the Duo leader, overriding normal target scoring |
| ARTEMIS | ×1.25 max HP, ×0.75 Clone cooldown (`ARTEMIS_LEADER_HP_MULT`/`_CLONE_COOLDOWN_MULT`) | Focus-fires the leader's current target (a target-score nudge, not a hard override — execute/threat can still win out) |
| WARDEN | *(none yet — generic Duo Bonus only)* | *(none yet)* |
| BEACON | *(none yet — generic Duo Bonus only)* | *(none yet)* |

**Design constraint (deliberate, see DECISIONS.md):** this per-hero layer is keyed ONLY on `(hero_name, leader-vs-follower)` — never on the specific partner's identity. An earlier version keyed behavior on the *partner's* role (e.g. Warden's Ensnare anchor switching depending on whether her partner was TANK/BURST/SUPPORT) and it visibly conflicted with itself; that version was removed entirely rather than patched.

### balance-qa pass 1 findings (2026-07-20)

**Finding 1 — fixed:** Thundaar's leader bonus originally stacked `×1.15 damage` on top of the generic Duo Bonus's own `×1.15` leader damage (compounding to `×1.3225`) plus `×1.20` attack speed — a personal DPS swing of **+44%** (leading vs. following), roughly 10x every other hero's ~+4.5% generic-only swing. Cut back to attack-speed only: leading DPS now **~+20-25%** over following — still a real identity trait, no longer dwarfing the rest of the roster. `THUNDAAR_LEADER_DAMAGE_MULT` deleted.

**Finding 2 — fixed:** `Hero._acquire_target()` checked Thundaar's bodyguard override (no range cap — defends the leader however far away) *before* the nearby-swarm-interrupt bubble added the same session. A following Thundaar could walk past an adjacent spawn point/minion to intercept whatever was hitting a leader across the map — the exact tunnel-vision failure mode the interrupt exists to prevent, reintroduced via a different lock. Reordered: nearby-swarm-interrupt now runs first.

**Finding 3 — open, needs a Designer call:** Warden/Beacon still have no per-hero leader/follower layer at all, while a Thundaar- or Artemis-containing Duo does. This compounds the pre-existing no-tank-comp weakness (see "No-tank viability pass" below) rather than just being neutral unfinished content. Two options: (a) give Warden/Beacon a comparable-magnitude layer before the next sweep, or (b) explicitly decide the no-tank comp should stay weakest. Not resolved this pass.

**Still open for the eventual sweep:** are the base Duo Bonus leader/follower gaps (+15%/+10% damage etc.) the right magnitude at all — none of this has been tested in motion, only computed by arithmetic on the live constants.

## Synergy System / Formation Bonuses (RETIRED 2026-07-20 — history only, not current mechanics)

The two systems below were unified into the Duo Bonus system above. Kept for record (the "No-tank viability pass" changes still apply to current tuning — Clone/Ensnare cooldown values are live).

### No-tank viability pass (2026-07-19)

**Problem:** every prior sweep locked the tankless trio (Artemis+WARDEN+BEACON) at 0% Level-1 clear, making Thundaar a mandatory pick and collapsing the draft-3-of-4 decision. Root cause was structural, not stats (party HP was already comparable): the swarm hunts nearest-hero so nobody held the line, the only role-pair formation bonus was TANK+BURST, and the sole taunt (Clone) had 25% uptime.

**Fix (three constants + formation generalization, [hero.gd](scenes/heroes/hero.gd)):**

| Change | Before | After | Why |
|---|---|---|---|
| `CLONE_DURATION` | 2.0s | 3.5s | Clone taunt uptime 25% → 44% — a real aggro-hold rotation without buffing clone damage |
| `ENSNARE_COOLDOWN` | 6.0s | 4.5s | WARDEN root cadence up; crowd control doubles as the tankless survivability tool |
| Formation pairs | TANK+BURST only | symmetric `FORMATION_PAIRS` | Tankless trio now fires CONTROL+SUPPORT and BURST+SUPPORT, matching a Thundaar trio's one pair |

**Re-sweep (8 trials/comp, zero-mod floor, two runs):** Artemis+WARDEN+BEACON Level-1 clear went **0% → 62–87%** (genuine coin-flip-to-reliable band across runs) and the comp now reaches L2/L3 and occasionally completes a full run (25%). No Thundaar trio regressed — all still 100% at L1 with healthy L2/L3. The Ensnare change mildly lifts Thundaar+WARDEN+BEACON too (acceptable — that comp was also weak). Level 2/3 tankless clears remain gated by the broader stale-numbers pass (out of scope; see BACKLOG.md).

## Objectives (hold-to-capture)

| Value | Current | Notes |
|---|---|---|
| Capture time | 5s | Uncontested hero-presence time to fully capture |
| Capture radius | 80px | A hero within this range captures |
| Contest radius | 45px | A hostile within this range pauses progress (no reset) |
| Farm bonus | 20 | One-time XP bonus granted on capture (increased from 15, split evenly among living heroes) |

Current build: one objective on the lane. Captures grant the Duo Bonus XP multiplier (see Duo Bonus System above) if both heroes of a confirmed Duo participate.

## Heroes

| Hero | Base Stats | Abilities |
|---|---|---|
| Thundaar | see Combat stats (hero placeholder) | TBD |
| Artemis | see Combat stats (hero placeholder) | TBD |

## Enemy Stats

**Villains**

| Villain | Base Stats | Abilities |
|---|---|---|
| Dark Mage (Stage 1) | 1500 HP, no attack | Summons minions (per stage config) |
| Berserker (Stage 2) | 2000 HP, 12 dmg / 1.1s, speed 80 | Pursues nearest hero; 3s charge / 1.5s recover cycle; summons elite minions |

**Minions:** base minion (Stage 1) and Elite Minion (Stage 2) — see Combat stats. Long-term target scales toward thousands per battlefield at higher levels.

## Experience & Upgrades (player-directed)

XP is the upgrade currency — players spend it directly on per-hero stat upgrades between runs (no automatic level bumps). A hero's displayed "LV" = total upgrades purchased.

**XP sources** (with synergy multiplier; no density bonus — see 2026-07-16 pass above)

| Source | Base XP | Notes |
|---|---|---|
| Minion kill (base) | 2–3 (killer) + 50% assist | Flat per `xp_value` (Minion/Elite/Ranged 2, Brute 3) regardless of swarm size or run length; killing-blow hero banks the full value, every other **living** hero banks 50% (rounded up) |
| Synergy multiplier | ×1.25 to all | Applied when both heroes within 200px and alive |
| Objective capture | 20, split | Split evenly among living heroes (rounded up); synergy multiplier applies |

**Effective XP examples:**
- Solo minion kill: 2 XP (3 for Brute)
- Minion kill, duo in synergy: 2 × 1.25 = 3 XP per hero (killer, rounded down), assist ~1 XP
- Objective capture (duo, synergy): (20 ÷ 2) × 1.25 = 12.5 → 13 XP each

**Upgrade catalog** (cost = `base × 1.25^owned`, rounded up)

| Upgrade | Base cost | Effect per purchase | Hero scaling |
|---|---|---|---|
| Max HP | 30 | +15 max HP base | ×(hero hp_scale ÷ 15) |
| Damage | 42 | +2 damage base | ×(hero damage_scale ÷ 2) |
| Attack Speed | 36 | ×0.95 attack interval (multiplicative) | ×(hero attack_speed_scale ^ owned) |
| Move Speed | 24 | +6 move speed | no hero scaling (same for all) |

**Rebalance rationale (2026-07-15 rebalance):** Lower base costs (HP 30→25, DMG 40→35, AS 35→30, MS 25→20) make early progression faster; XP density bonus rewards surviving swarm pressure; synergy multiplier forces 2-hero teams and creates exponential scaling moments. Expected party income ≈ 300–400 XP/run with density + synergy multipliers (estimate; requires in-engine re-verification).

**Progression tuning (2026-07-16):** Base upgrade costs increased by ×1.2 (HP 25→30, DMG 35→42, AS 30→36, MS 20→24) to slow progression speed. Keeps XP farming rewarding (same 300–400 XP/run economy) while reducing level gain per run (~4 levels → ~1.5 levels), targeting 8-10 runs per stage to comfortably clear instead of 5. XP sources unchanged; this tuning does not affect balance gates (which were verified against current XP income, not costs). Re-verification sweep pending.

XP is banked to disk (`user://save.json`) live on each kill/capture and kept in full even on a wipe — every run contributes. F12 = dev save reset.

## Stage gates (verified in-engine 2026-07-15 rebalance pass)

Verified with instrumented runs (builds set via GameState, battles observed to completion at 5× time scale):

| Party | Stage 1 (Dark Mage) | Stage 2 (Berserker) |
|---|---|---|
| 1 × LV 8 (Thundaar solo, 3 DMG/3 HP/1 AS/1 MS) | **VICTORY** — razor-thin (6/180 HP left, villain reached ~5%) | — |
| 2 × LV 20 (5/5/5/5 split, synergy active) | **VICTORY** — comfortable (205/220, 125.5/145 HP, ~26s sim) | — |
| 2 × LV 25 (9/9/5/2 split, synergy active) | — | **VICTORY** — comfortable (276/300 Thundaar, 55/193 Artemis, ~30s@5×) |

**Key findings:**
- **Solo LV 8 is now a nail-biter win, not a loss** — density-bonus XP and lower upgrade costs pushed the baseline up faster than the plan's LV-8-loses projection. This is still "so close" (villain at ~5% HP, hero nearly dead) so the farm-more signal reads clearly; treat LV 8 solo as the practical floor rather than tightening further.
- **Synergy duo at LV 20 trivializes Stage 1** — near-full HP win in ~26s of 5×-scaled combat, confirming the +15% damage / XP / cooldown-reduction stack compounds quickly once both heroes stay paired.
- **Stage 2 at LV 25 shows real tank/DPS asymmetry** — Thundaar (tank) finished near full HP while Artemis (DPS) dropped to ~28%, exactly the differentiated-role behavior the hero stat split was designed to produce.
- Ability unlocks (LV 15 Stomp-stun / Clone-damage, LV 20 Shockwave / Dash) fire correctly in these runs (both test builds were ≥ LV 20) but individual ability contribution wasn't isolated — future balance passes should A/B with abilities unlocked vs. locked to quantify their share of the win margin.

**Not yet re-verified:** LV 12–15 duo (expected: Stage 1 comfortable win, first ability-passive unlock), LV 15–20 duo on Stage 2 (expected: competitive/struggle before second-ability unlock). These fill the gap between the floor (LV 8 solo) and the two confirmed comfortable-win points above.

## Comprehensive sweep (automated, 2026-07-16)

Full-matrix verification: solo + duo, LV 0–30, all 3 stages (186 runs), each capped at **60 simulated seconds** (a tighter, standardized window vs. the ad-hoc 5×-scale manual runs above — not directly comparable to the "razor-thin win"/"~26s sim" language in the section above, which likely measured wall-clock at 5× rather than sim-seconds). Builds use an even 4-way stat split per level (e.g. LV 20 = 5/5/5/5), heroes deployed immediately at the default spawn point, no manual priority tuning. Raw per-run data: `BALANCE_SWEEP_RESULTS.json`.

### Stage 1 (Dark Mage)

| Party | Result |
|---|---|
| Solo (Thundaar) | **Never wins within the 60s cap, LV 0–30.** Villain damage climbs steadily at high levels (LV 29: villain to 824/1500) but solo can't close it out in the window. |
| Duo (synergy) | First win at **LV 19** (58.4s — a near-miss-turned-win). Wins consistently from **LV 22 onward**. LV 21 alone timed out just short (villain at 76.6/1500 — bad luck on spawn RNG, not a real wall). |

### Stage 2 (Berserker)

| Party | Result |
|---|---|
| Solo (Thundaar) | **Loses at every level, LV 0–30** (full wipe each time). Villain damage improves with level (LV 30: villain to 778/2000) but solo never survives long enough to finish it. |
| Duo (synergy) | One early win at **LV 10** (noisy — surrounded by losses at LV 11–14, likely spawn-RNG dependent at that low a level). Wins consistently from **LV 15 onward**, with three notable near-miss losses at **LV 20** (villain 60.5/2000), **LV 24** (villain 361.5/2000), and **LV 28** (villain 25.5/2000) — all close enough that these read as run-to-run variance, not a real difficulty wall. |

### Stage 3 (Mech Robot — new, unbalanced placeholder)

| Party | Result |
|---|---|
| Solo (Thundaar) | **Never wins, LV 0–30.** Frequently dies outright from LV 6 up; villain only reaches ~1714/2500 (31% damaged) even at LV 30. Confirms Stage 3 is currently tuned far too hard for solo — expected, since stats are first-pass placeholders. |
| Duo (synergy) | No wins before **LV 20**. LV 20–25 is a genuine contested band (mix of wins/losses/near-timeouts — LV 25 timed out with the villain at just 11.7/2500 HP). Wins consistently from **LV 26 onward**. |

**Key findings (pre-Lone-Wolf-buff):**
- **Solo is not viable at any level 0–30 on any stage under this stricter cap.** Every prior "solo win" reference in this doc was almost certainly a much longer real-world run (5× scale, no time cap) — the demo's actual solo experience within a reasonable play session may be weaker than previously assumed.
- **Duo progression is coherent across all 3 stages**: Stage 1 ~LV 19–22, Stage 2 ~LV 15 (with an outlier LV 10), Stage 3 ~LV 20–26. Difficulty ordering (Stage 1 < Stage 2 ≈ Stage 3) holds, though Stage 3's placeholder stats land it slightly harder than Stage 2 rather than a clean step up — reasonable for a first pass, worth a tuning look before treating Stage 3 as demo-ready.
- **Stage 2 and 3 both show a handful of "just barely lost" runs scattered through their win bands** (villain HP in the low single digits to low hundreds at time of loss/timeout). This is likely spawn-point/RNG variance rather than a structural wall, but is worth a multi-seed re-run at those specific levels before concluding anything is broken.
- **Stage 3's Mech Robot + hybrid minions are functioning as designed** (villain fights back in melee, slow-zone ability fires and applies the movement/attack debuff, ranged+brute minions both spawn) — the difficulty numbers above reflect first-pass placeholder stats, not a mechanical bug.

## Lone Wolf buff (2026-07-16 — makes solo wins possible)

The sweep above showed solo never closing out a win within the 60s cap at any level on any stage. Rather than buff all heroes (which would trivialize duo), added a **Lone Wolf** bonus: a standing compensation buff for a true 1-hero roster, cached once at spawn from `GameState.selected_heroes().size() == 1` — mutually exclusive with the existing dynamic Synergy system (which requires an ally), so **duo balance is completely untouched** by this change.

| Value | Current |
|---|---|
| Max HP multiplier | ×1.8 |
| Damage multiplier | ×1.75 |
| Ability cooldown reduction | −0.4s (vs. synergy's −0.3s) |

Implementation: `scenes/heroes/hero.gd` — `_is_lone_wolf` set once in `_configure()` (drives the HP multiplier at spawn); `_update_synergy()` applies the damage multiplier / cooldown reduction through the same `_synergy_damage_mult` / `_synergy_cooldown_reduction` fields the Synergy system already uses (has_ally and is_lone_wolf are mutually exclusive, so no double-dipping). The XP density-bonus check (`_synergy_damage_mult > 1.0`) also now grants the synergy XP multiplier to Lone Wolf runs — an intentional side benefit, not a bug.

**Tuning process:** started at HP ×1.5 / DMG ×1.4 / CD −0.3s (roughly matching synergy's magnitude), spot-checked, then iterated up twice based on results before landing here. Full re-sweep (93 runs: solo × LV 0–30 × all 3 stages) with final values:

| Stage | Solo result |
|---|---|
| Stage 1 (Dark Mage) | **Still never wins, LV 0–30** — but trending hard toward one: villain down to 314.5/1500 (79% damaged) by LV 30, vs. never breaking 45% pre-buff. |
| Stage 2 (Berserker) | **Wins consistently from LV 21** (10/10 wins, LV 21–30). |
| Stage 3 (Mech Robot) | **Still never wins, LV 0–30** — also trending hard: villain down to 384.5/2500 (85% damaged) by LV 30, vs. ~31% pre-buff. |

**Why Stage 1 resists pure stat buffs where Stage 2/3 don't:** Dark Mage flees when a hero closes in (`flee_distance = 260`) and every `teleport_interval = 10s` blinks to a new spot and resummons a fresh burst of minions there. A lone hero's chase progress gets reset roughly every 10 sim-seconds and has to fight through a new minion burst before it can resume pressing the villain — structurally different from Berserker (actively chases, stands and fights) and Mech Robot (stationary, melees back), where raw stat increases convert directly into sustained damage windows. Buffing Lone Wolf further would eventually brute-force a Stage 1 win too, but the diminishing returns and the already-large multipliers (×1.8 HP / ×1.75 DMG) suggested stopping here and flagging the mechanic instead of the numbers.

**Open item for Designer:** Stage 1 is currently the *hardest* stage to solo despite being the first stage — the opposite of the intended difficulty curve. Two paths forward: (a) tune Dark Mage's kiting specifically for solo (e.g. shorter `teleport_interval` cooldown between resummons scaled by party size, or a smaller `teleport_minion_count` when only one hero is present), or (b) accept Stage 1 as solo-unwinnable by design and lean into "duo unlocks Stage 1, solo is a Stage-2-only curiosity" — inconsistent with the current stage-gating (Stage 2 unlocks only after beating Stage 1), so (a) is likely the better direction if solo progression through the stage order matters.

## Economy

Reward types beyond Experience: TBD. Values: TBD.

## Skill Trees

Node layout, upgrade costs, unlock conditions: all TBD.

## Damage Formulas

TBD.

## Progression

Level progression curve: TBD.
