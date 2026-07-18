# Semi-Secret Wars — MVP Implementation Plan

**Owner:** Fable (implementation). **Basis:** the ratified [design report](../../.claude/plans/you-are-a-auto-purrfect-rose.md) — Hybrid roguelite + Light-touch agency. **Method:** the project's milestone rules (one problem per milestone, playable after each, no unrelated systems combined; wait for Designer approval between milestones — [AI_Development_Guide.md](AI_Development_Guide.md)).

---

## Context — why this plan exists

The shipped build proves the *loop* but is structurally an **incremental farm-and-grow**: `GameState` banks per-hero XP and permanent stat upgrades to `user://save.json` ([scenes/state/game_state.gd:194](scenes/state/game_state.gd)), spent on a persistent skill tree. Richard ratified a **hybrid roguelite** direction instead: builds RESET each run; persistence moves to *meta-unlocks* (new heroes/relics into the pool), not flat power. This plan sequences the smallest playable steps from the current build to the MVP vertical slice, reusing existing systems wherever possible.

### Current-state reconciliation (code has diverged from docs — resolve first)
- **Skill tree already exists** (`GameState.ABILITY_NODES`, [scenes/prep/skill_tree_page.gd](scenes/prep/skill_tree_page.gd)) though `Game_Design_Bible.md` lists it "deferred." The report says skip skill trees for MVP → **repurpose** the tree UI into the meta-unlock shop rather than delete it.
- **Role formation system already exists** ([hero.gd:625 `_update_formation`](scenes/heroes/hero.gd)) — proximity role bonuses (same-role DMG+, opposite-role GUARD+/BURST+, mixed-trio CD). This is a strong seed but is *unnamed stat auras*; M6 evolves it into named combinatorial synergies rather than starting from scratch.
- **Minion variety already exists** (elite/brute/ranged/guardian under [scenes/enemies/](scenes/enemies/)) and stages are **config-driven** ([config/stage_config.gd](config/stage_config.gd), `*_config.tres`). M4/M10 build on this, not around it.

### Decisions needed from Richard before coding (flagged, not assumed)
1. **Skill-tree fate:** repurpose into meta-unlock shop (recommended) vs. keep both vs. remove.
2. **Persistence reset:** MVP wipes the current `save.json` schema (v2 → v3, run/meta split). Confirm a clean break is acceptable.
3. **Roster target for the slice:** the report's 4 heroes = keep Thundaar/Artemis + add 2 (Controller, Support). Confirm before M5.

---

## Architecture change (the spine of the plan)

Split state cleanly along the roguelite seam:

- **`RunState`** (NEW autoload, transient — reset every run): drafted party, in-run level + XP-to-next, picked boons/relics, current wave, run modifiers. Nothing here is saved.
- **`MetaState`** (the persistent half of today's `GameState`, repurposed): unlocked heroes, unlocked relics in the pool, meta-currency, cleared stages / difficulty tier. Saved to disk. Loses the per-hero permanent stat upgrades.

Heroes read their *effective* stats from base + `RunState` boons at spawn/`_engage`, not from persistent upgrades. This is the one refactor everything else depends on, so it lands first and incrementally (M1 introduces `RunState` alongside the old system; M2 removes the persistent stat grind).

---

## Milestones

### M1 — In-run leveling + 1-of-3 boon draft  ⭐ highest leverage
**Goal:** farmed XP levels you up *during a run*; each level-up pauses for a 1-of-3 card pick that buffs THIS run only and resets next run. This is the report's "single highest-leverage change" and makes the loop read as a roguelite immediately.
**Reuse:** the pause+overlay pattern from [results_screen.gd](scenes/battle/results_screen.gd); XP crediting hooks already in [game_state.gd:110 `add_xp`](scenes/state/game_state.gd) and [battle_manager.gd:153 `_on_objective_captured`](scenes/battle/battle_manager.gd); boon-application mirrors the existing objective-boost buffs on [hero.gd `apply_*_boost`](scenes/heroes/hero.gd).
**Approach:** new `scenes/run/run_state.gd` autoload (run_level, xp_to_next curve, boons[]); route in-run XP to it; `BattleManager._process` detects a level-up, sets `get_tree().paused = true`, shows a new `scenes/battle/level_up_screen.gd` (3 boon cards); on pick, apply to living heroes and unpause. Boons drawn from a small `scripts/boons.gd` catalog (start with ~6: +DMG%, +Max HP%, +Atk Speed, +Move Speed, ability CD−, XP+).
**Files:** +`scenes/run/run_state.gd`, +`scenes/battle/level_up_screen.gd`, +`scripts/boons.gd`; edit `battle_manager.gd`, `hero.gd` (apply run boons in `_configure`/`_engage`), `project.godot` (autoload).
**Verify (godot-ai):** run a stage; confirm XP fills, level-up overlay appears, chosen boon changes hero stats live, and a new run starts with boons cleared.

### M2 — Retire persistent stat grind → meta-currency + unlock shop
**Goal:** runs no longer bank permanent stats; run end awards **meta-currency**; the prep screen's per-hero UPGRADES button becomes a **meta-unlock shop** (spend currency to unlock heroes/relics into the pool).
**Reuse:** repurpose [game_state.gd](scenes/state/game_state.gd) as `MetaState`; repurpose [skill_tree_page.gd](scenes/prep/skill_tree_page.gd) layout as the unlock-shop page invoked from [prep_menu.gd:197 `_open_skill_tree`](scenes/prep/prep_menu.gd).
**Approach:** drop `UPGRADES`/per-hero `upgrades`/`buy`; add `meta_currency`, `unlocked_heroes`, `unlocked_relics`; award currency in [battle_manager.gd:222 `_end`](scenes/battle/battle_manager.gd); bump `SAVE_VERSION` → 3 with a clean reset of the old schema. `Hero._configure` stops reading `GameState.bonus_*` (stats now come from base + run boons).
**Files:** edit `game_state.gd`→meta, `prep_menu.gd`, `skill_tree_page.gd`, `hero.gd`, `battle_manager.gd`.
**Verify:** win/lose a run → currency granted; unlock shop spends it; a fresh run starts with base stats (no permanent carryover); old save migrates without crashing.

### M3 — Draft step (pick your team from an offer)
**Goal:** the run starts by drafting N heroes from an offered set of unlocked heroes, replacing the "toggle my whole owned roster" checkboxes.
**Reuse:** party model in [game_state.gd:83 `party_of`](scenes/state/game_state.gd) / [`selected_heroes`](scenes/state/game_state.gd); hero cards in [prep_menu.gd:140 `_build_hero_card`](scenes/prep/prep_menu.gd).
**Approach:** `RunState.draft_offer` = sample from `MetaState.unlocked_heroes`; prep shows the offer, player picks up to the party cap; selection lives in `RunState`, not the persistent save.
**Verify:** offer varies per run; picking builds the party that spawns in [battle_manager.gd:118 `_spawn_party`](scenes/battle/battle_manager.gd); re-entering prep re-rolls the offer.

### M4 — Wave/issue structure + boss climax + between-wave relic pick
**Goal:** a run becomes 3 escalating waves + a boss (the villain) at the climax; each wave clear grants a guaranteed relic pick. Gives comic "issue" pacing and a splash-page finale.
**Reuse:** escalation knobs already in [stage_config.gd](config/stage_config.gd) + [minion_spawner.gd](scenes/enemies/minion_spawner.gd); villain spawn already deferred to a trigger in [battle_manager.gd:199 `_spawn_villain`](scenes/battle/battle_manager.gd).
**Approach:** add wave phases to `RunState`; spawner runs a capped wave, signals clear, `BattleManager` shows the relic pick (reuse M1 overlay), then advances; villain only spawns for the final phase. Boss keeps its existing gimmick (Dark Mage teleport / Mech slow-zone).
**Verify:** three waves resolve in order, relic pick between each, boss appears only at the end, win on boss death.

### M5 — Two new heroes: Controller + Support
**Goal:** fill the four MVP roles (have TANK Thundaar, BURST Artemis; add CONTROL + SUPPORT), each a distinct silhouette + one signature ability.
**Reuse:** the `role` system already exists ([hero.gd:245](scenes/heroes/hero.gd) sets role; `CONTROL` is already a default). `HERO_STATS`, `HERO_CATALOG`, and ability scaffolding (`_try_*`) are the extension points.
**Approach:** add two `HERO_CATALOG`/`HERO_STATS` entries + signature abilities (e.g. Controller = slow/root field; Support = shield/heal aura — resolves the long-deferred `SUPPORT_ALLIES` priority in [game_state.gd:49](scenes/state/game_state.gd)). No new base class.
**Verify:** each new hero spawns, fights, and its ability fires; roles show in HUD buff row ([hero.gd:213 `active_buffs`](scenes/heroes/hero.gd)).

### M6 — 3 named combinatorial synergies (the depth R&D)
**Goal:** replace unnamed proximity stat-auras with 3 *named, combinatorial* synergies that create build identity and "team-up panel" moments.
**Reuse:** evolve [hero.gd:625 `_update_formation`](scenes/heroes/hero.gd) — it already computes nearby roles/counts; change the *payload* from flat mults to named effects.
**Approach:** author 3 synergies of distinct shapes — (a) enabler+payoff pair (hero A marks, hero B cashes in), (b) role-count trait (N of a role unlocks a team effect), (c) a duo Team-Up move (sets up M8's button). Surface names in the HUD and level-up cards.
**Verify:** each synergy triggers only under its condition and visibly changes combat; names appear in the buff row.

### M7 — Relic/boon pool (~12–15) with deliberate interactions
**Goal:** flesh the M1/M4 pool into ~12–15 relics designed to *combine* multiplicatively, giving the draft chase targets.
**Reuse:** `scripts/boons.gd` from M1; apply through the same hero hooks.
**Approach:** author relics as data (id, name, hooks); include ~3 obvious combo pairs (e.g. "on-kill AoE" × "attack speed" ). Draw offers from `MetaState.unlocked_relics`.
**Verify:** combos stack correctly; offers respect unlock state; no runtime errors when many relics are active on one hero.

### M8 — Light-touch in-battle inputs
**Goal:** minimal player agency during auto-battle: one manual ability trigger, one Team-Up button on cooldown, and priority re-issue. No micro.
**Reuse:** ability functions already exist (`_try_stomp`/`_try_shockwave`/`_try_dash`/`_try_clone`); priorities already drive AI ([hero.gd:291](scenes/heroes/hero.gd)).
**Approach:** gate one ability per hero behind an input; add a Team-Up button firing the M6 duo move; add an in-battle control to re-issue a hero's priority. Wire into [battle_hud.gd](scenes/battle/battle_hud.gd).
**Verify:** inputs fire the right effects on cooldown; auto-battle still fully resolves if the player does nothing.

### M9 — Legibility pass: post-run summary + elite telegraph (MVP-core, not polish)
**Goal:** the player can always read *why* a run went the way it did.
**Reuse:** extend [results_screen.gd:45 `show_results`](scenes/battle/results_screen.gd); `elite_minion.gd` already exists to add a spawn telegraph to.
**Approach:** results summary (kills per hero, who carried, win/lose cause, relics that mattered); telegraph elite spawns (pre-spawn marker + distinct silhouette).
**Verify:** summary numbers match the run; elites are visually distinct and pre-announced.

### M10 — Thin meta layer + one higher difficulty tier
**Goal:** prove the "unlock breadth + escalating challenge" hook without a big tree.
**Reuse:** `MetaState` (M2) + `StageConfig` scaling.
**Approach:** meta-currency unlocks 1–2 extra heroes and ~6 more relics into the pool, plus one higher difficulty tier (a StageConfig modifier: tougher swarm/boss for more currency).
**Verify:** unlocks persist across runs and appear in draft/relic offers; the harder tier is selectable and meaningfully harder.

---

## Explicitly deferred (scaffold for, do NOT build in MVP)
Thousands-enemy MultiMesh/data-oriented swarm (keep counts modest until fun is proven — [DECISIONS.md 2026-07-14 "Swarm scaling"](DECISIONS.md)); additional biomes; villains beyond the MVP boss; narrative/cutscenes; full skill trees. All are additive config/content on the proven loop.

## Sequencing & risk notes
- **M1 → M2 → M3 are the identity-critical spine** and should land (and be approved) before content milestones (M5–M7). If time is tight, M1 alone already converts the feel to roguelite.
- **M6 is the highest-uncertainty design work** (named synergies) — budget iteration; it's where the "memorable team-up" USP is won or lost.
- Each milestone leaves the game playable and is verified in-engine via `godot-ai` before moving on, per the workflow. Docs (`PRODUCTION.md`, `DECISIONS.md`, `BACKLOG.md`) are updated in a batch at each session end, not mid-milestone.

## Global verification
After each milestone: (1) project compiles/opens clean in Godot 4.7; (2) a full run completes end-to-end via `godot-ai` automation; (3) the milestone's specific behavior is observed, not assumed. A balance re-sweep ([scenes/tools/balance_sweep.gd](scenes/tools/balance_sweep.gd)) is run after M2 (stat model changed) and M10 (difficulty tier added).
