# Semi-Secret Wars — Decisions

Records important project decisions and why they were made.

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

## 2026-07-18 — Ability visual feedback: status ring + cast-name callout

**Decision:** Added two visual-feedback mechanisms so ability procs are trackable in real-time play (Designer feedback: couldn't keep up with what fired during a normal-speed run). (1) A floating "ABILITY NAME!" text callout above the caster on every hero-ability proc (Stomp/Clone/Shockwave/Dash/Ensnare/Rally). (2) A colored status ring on **any** `Combatant` (not just heroes) affected by a stun/slow/buff/shield — cyan/violet/gold/light-blue respectively.

**Reason:** Direct Designer request after playtesting M5. The status ring was deliberately built into the shared `Combatant` base rather than per-ability, so it's a systemic fix, not six bespoke ones.

**Impact (bonus, unplanned):** because the ring lives on `Combatant`, it retroactively made the Stage 3 Mech Robot's slow-zone ability and the existing objective party-wide reward buffs visible for the first time — both previously had zero per-unit visual feedback beyond a HUD chip/banner.
