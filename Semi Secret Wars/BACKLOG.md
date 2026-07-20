# Semi-Secret Wars — Backlog

This document changes frequently. See [AI_Development_Guide.md](AI_Development_Guide.md) §16.

| Feature | Priority | Status | Dependencies | Notes |
|---|---|---|---|---|
| **Gameplay-loop rework (run = chain of fixed levels)** | High | Done | — | 2026-07-18, 6 phases, validated in-engine. See PRODUCTION.md / DECISIONS.md |
| Fixed authored layouts (`LevelLayout`) | High | Done | Rework | Replaced `StageField.randomize_*`; levels 1–3 authored in `config/level_N_layout.tres` |
| Persistent fog per level | High | Done | Rework | Explored ground saved to `user://fog/level_N.png`, never decays |
| Run chaining + HP carryover + permadeath | High | Done | Rework | `RunState.current_level/hp_carry/dead`; win chains, loss resets to L1 |
| Fixed minion gates + dormant lair villain | High | Done | Rework | Waves from authored gates; `Combatant.is_alerted()` dormancy; Dark Mage leash |
| Focus ping (in-battle command verb) | High | Done | Rework | 3 charges, biases party 5s, refunds on capture |
| Gold shop — permanent ability mods | High | Done | Rework | `ability_mods.gd` 8 tradeoff nodes; `meta_currency`→`gold`; `UnlockShopPage` repurposed |
| Stage-select + `stage_1_won` unlock | — | Superseded | Rework | Every run starts at L1; progression is knowledge + gold, not stage unlocks |
| Per-battle layout randomization | — | Superseded | Rework | Contradicted "levels become familiar"; replaced by authored layouts |
| Balance whole-run sweep + tuning (Level 1) | High | Done | Rework | 2026-07-18. `balance_sweep.gd` reworked to whole-run model; found 0% clear rate, fixed via layout+throughput tuning. See BALANCE.md |
| Balance whole-run sweep + tuning (Level 2/3) | High | Not Started | Balance sweep (L1) | Same methodology as L1 (now proven); confirmed still too hard (0/4 for Thundaar arriving from an L1 win). See BALANCE.md |
| Between-level heal/revive | Medium | Deferred | Rework | Ship raw attrition first, then add relief (Designer decision) |
| Partner-pairing deploy rule | Low | Deferred | Rework | "Partners deploy together" needs a pairing UI/decision first |
| Per-level twists (hazards/ambush) | Low | Not Started | Fixed layouts | Environment danger / surprise attacks, now that layouts are data |
| Documentation scaffold | High | Done | — | Living docs created from source PDFs 2026-07-14 |
| Project setup verification | High | Done | Documentation scaffold | Confirmed clean via `godot-ai` MCP — no errors, no main scene yet (expected) |
| Scope & style alignment | High | Done | Project setup | Demo scope, camera/perspective, movement model, progression depth decided — see DECISIONS.md |
| Battlefield (placeholder scene) | High | Done | Scope & style alignment | `scenes/battlefield/`: isometric field, lane, markers, zoom camera; set as main scene |
| Minion swarm + path following (concept test) | High | Done | Battlefield | `scenes/enemies/`: swarm follows single lane; villain-summoned, looping, clumped spread |
| Villain summon spawner | High | Done | Minion swarm | Folded into concept test — `MinionSpawner` maintains a looping swarm |
| Hero (placeholder + movement) | High | Done | Battlefield | `scenes/heroes/`: Thundaar + Artemis advance up the lane; shared `Iso.line_points()` path |
| PC display / fullscreen setup | High | Done | — | 1920×1080 base, fullscreen, `canvas_items`/`expand`, camera framing tuned |
| Combat (automated) | High | Done | Hero, Minion swarm | Shared `Combatant` base; HP/targeting/attacks/death/health bars; minions prioritize heroes |
| Win/lose (farm + defeat-villain) | High | Done | Combat | Continuous escalating farm swarm, HP villain, `BattleManager`; win = defeat villain, lose = heroes dead. Unwinnable at base by design |
| Capturable objectives + progress | High | Done | Win/lose | `CaptureObjective`: hold-to-capture (contested), grants farm/XP bonus, % in HUD. One objective |
| Pre-battle prep screen (roster + priorities + upgrades) | High | Done | Objectives, Progression | `PrepMenu` main scene; priorities change combat behavior; party/priority persist in save |
| Support Allies priority | Low | Done | Support/heal abilities | Un-deferred 2026-07-18 — BEACON's Rally ability exists; `SUPPORT_ALLIES` shadows the nearest ally so its aura lands, villain-push fallback when solo |
| Prep/results UI polish | Low | Not Started | Prep screen | Checkbox hero names render white/hard to read; results panel off-center; placeholder styling |
| More objectives + effect variety | Low | Not Started | Capturable objectives | 2nd objective, and alternate effects (e.g. weaken villain) |
| Combat balance tuning | Medium | Not Started | Objectives + win/lose | Numbers in BALANCE.md; "fair" depends on win/lose + waves existing |
| Rewards | Medium | Done | Objectives | Folded into Progression — XP from kills + objectives is the demo reward |
| Progression (player-directed upgrades) | High | Superseded | Rewards | Retired 2026-07-18 (M2) — persistent stat-buy replaced by the hybrid-roguelite model below; see DECISIONS.md |
| Scalable swarm rendering/simulation | Medium | Not Started | Minion swarm | Data-oriented / MultiMeshInstance2D bulk system for thousands of enemies — build when small version is validated |
| Organic battlefield layout (Stage 1) | High | Done | Combat | `StageField`: sketched open field — funnel, villain corner, obstacles, lake, scenery |
| Open-field movement + pathing | High | Done | Organic battlefield layout | Goal-point steering with obstacle avoidance (radial + tangential) |
| Obstacles (block movement) | High | Done | Open-field movement | Two blob obstacles; hard position clamp guarantees zero penetrations (2026-07-15); steering smoothed |
| Poison Lake hazard effect | Medium | Done | Battlefield reshape | DoT (8 HP/s placeholder) on all units inside + green tint; units soft-avoid it. No slow (Designer choice 2026-07-15) |
| Scenery props (decorative) | Low | Done | Organic battlefield layout | One prop, no gameplay effect |
| Villain as boss (HP, defeat = win) | High | Not Started | Objectives + win/lose | Villain HP bar; defeating the Dark Mage is a win path |
| Battle HUD (villain HP, hero panels, objectives tracker) | Medium | Not Started | Combat | Per sketch: villain HP bar, per-hero HP + attack cooldown, objectives progress |
| Growing battlefields over levels | Low | Not Started | Combat loop | Battlefield gets larger + swarms scale up as player advances |
| Second villain (Berserker) + battlefield | Low | Not Started | Demo loop | Post-demo expansion |
| Skill trees | Low | Superseded | Progression | Built 2026-07-16, then repurposed 2026-07-18 (M2) into `UnlockShopPage` — persistent stat nodes don't fit the hybrid-roguelite direction |
| Remove unused 3D physics engine config | Low | Not Started | — | `3d/physics_engine="Jolt Physics"` in project.godot is dead config now that the project is 2D |
| Promote Iso tile size to per-battlefield Resource | Low | Obsolete | — | `iso.gd` was deleted with the grid/lane era (battlefield reshape) |
| Camera pan controls | Low | Not Started | Battlefield | Zoom works; panning (drag/keys) deferred until needed |
| Notebook backdrop / clear color | Low | Not Started | PC display setup | Engine-gray shows outside the page at some zooms; needs a proper desk/page backdrop |
| Settings menu (fullscreen/windowed toggle, resolution) | Low | Not Started | PC display setup | Player-facing display options for the published build |
| Placeholder label overlap | Low | Not Started | Hero | Hero/marker text labels overlap when units cluster; cosmetic only |
| Expansion | Low | Not Started | Progression | Intentionally undefined per GDD §23 |
| In-run boon leveling (M1) | High | Done | Combat | `RunState` autoload; per-hero in-run XP/level, 1-of-3 boon pick on level-up (`scripts/boons.gd`, `level_up_screen.gd`); resets every run |
| Meta-currency + unlock shop (M2) | High | Done | In-run boon leveling | Persistent stat grind retired; flat base stats every run; win/loss currency toward `UnlockShopPage` — currently nothing to buy (no locked content yet) |
| 4-hero roster: WARDEN + BEACON (M5) | High | Done | Meta-currency + unlock shop | Controller (Ensnare) + Support (Rally); placeholder names, not locked — see DECISIONS.md 2026-07-18 |
| Ability visual feedback (status ring + cast callout) | Medium | Done | 4-hero roster | Shared `Combatant`-level status ring (stun/slow/buff/shield) + floating ability-name text; Designer-confirmed working |
| Draft step (M3) | High | Not Started | 4-hero roster | Offer a subset of unlocked heroes each run instead of toggling the whole roster; enforce party cap = 3 of 4 (Designer-decided 2026-07-18) |
| Wave/issue structure + boss climax + relic pick (M4) | Medium | Not Started | Draft step | 3 escalating waves + boss finale per run; guaranteed relic pick between waves |
| Named combinatorial synergies (M6) | Medium | Not Started | 4-hero roster | Replace/extend the unnamed proximity formation bonuses with real team-up identities across all 4 roles |
| Relic pool, ~12-15 with interactions (M7) | Medium | Not Started | Wave/issue structure | Draws from `unlocked_relics` (scaffolded in M2, currently always empty) |
| Light-touch in-battle inputs (M8) | Medium | Not Started | Named synergies | One manual ability trigger + Team-Up button + priority re-issue |
| Post-run legibility summary + elite telegraph (M9) | Medium | Not Started | — | Kills/carry/why-you-won summary; pre-announced elite spawns |
| Balance re-sweep + tuning (post-M2) | Medium | Not Started | Meta-currency + unlock shop | Old `BALANCE_SWEEP_RESULTS.json` is stale — power model changed shape (boon-stacking vs. additive purchases) and abilities are now intrinsic |
| Warden/Beacon Duo leader/follower layer | Medium | Not Started | Duo system (2026-07-20) | balance-qa pass 1 Finding 3: only THUNDAAR/ARTEMIS have a per-hero leader/follower behavior layer, compounding the pre-existing no-tank-comp weakness. Needs a Designer call: give Warden/Beacon a comparable layer, or explicitly accept the no-tank comp stays weakest. See BALANCE.md/DECISIONS.md |
| Rebuild lane-shaped balance sweep harness (Part C6) | Medium | Not Started | — | V1's `balance_sweep.gd`/`behavior_probe.gd`/`death_curve_probe.gd` were deleted with V1; nothing in the lane build has ever been swept, including the entire Duo system (2026-07-20 balance-qa pass was arithmetic/inspection only, no in-motion verification). Blocks real confidence on any Duo Bonus/leader-follower numbers |
