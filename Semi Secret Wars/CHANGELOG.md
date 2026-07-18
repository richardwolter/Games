# Semi-Secret Wars — Changelog

Records completed milestones. See [AI_Development_Guide.md](AI_Development_Guide.md) §12/§17.

## 2026-07-15 — Swarmier spawns (density up, chip-damage/XP budget held constant)

### Changed
- `config/stage_1_config.tres` — `swarm_cap_start` 12→18, `swarm_max_cap` 40→60, `spawn_batch` 2→3, `escalate_step` 3→4 (×1.5 spawn throughput and on-screen density; `spawn_interval` unchanged)
- `config/stage_2_config.tres` — `swarm_cap_start` 14→21, `swarm_max_cap` 48→72, `spawn_batch` 2→3, `escalate_step` 3→4 (same ×1.5 scaling)
- `scenes/enemies/minion.tscn` — `damage` 1.5→1.0, `xp_value` 8→5 (÷1.5, offsets the ×1.5 kill-rate increase so total chip damage and XP income per run are unchanged)
- `scenes/enemies/elite_minion.tscn` — `damage` 2.0→1.3, `xp_value` 8→5 (same ÷1.5 offset)

### Verified
- In-engine via `godot-ai`: deployed a LV 20 synergy duo (5/5/5/5 split each) into Stage 1 at 5× time scale. At ~26s-equivalent sim time held 188/220 (Thundaar) / 119/145 (Artemis) HP with the villain at 46% — matching the pre-existing verified LV 20 gate (205/220, 125.5/145) within noise — then won outright shortly after (170/220, 114/145 final HP). Active-minion counts (up to 30) and kill counts (109) were markedly higher throughout than the prior lower-density baseline, confirming the swarm reads denser without moving the win/loss gate. See [BALANCE.md](BALANCE.md) Swarm section.

## 2026-07-15 — Stage 2 Unlocked banner + HUD polish

### Added
- `scenes/battle/results_screen.gd` — gold "STAGE 2 UNLOCKED!" line, shown only on the run that first flips `GameState.stage_1_won` (not on repeat Stage 1 wins). `BattleManager._end()` computes the transition before overwriting the flag and passes it through `show_results(win, unlocked_stage)`
- `scenes/objectives/objective.gd` — `contested` exposed as a member var (hostile inside `contest_radius` while a hero holds the point), previously a throwaway local
- `scenes/battle/battle_hud.gd` — objective panel gained a fill bar (`ObjectiveBar`, gold stylebox matching the villain HP bar) and a "CONTESTED" text state distinct from an uncontested capture-in-progress
- `scenes/heroes/hero.gd` — `ability_cooldown_max()` (Stomp 3.5s / Clone 8.0s) so the HUD can compute a fill fraction, not just remaining seconds
- `scenes/battle/hero_panel_ui.gd` / `.tscn` — `CooldownBar` fill (0 = just used, full = ready) alongside the existing text/color cooldown indicator; zeroed on KO

### Verified
- In-engine via `godot-ai`: `game_eval` forced `BattleManager._end(true)` on a fresh `stage_1_won = false` — banner appeared; re-ran `_end(true)` with the flag already set — banner stayed hidden. Objective/HUD node paths confirmed wired (`ObjectivePanel/VBox/ObjectiveBar` etc.). Instantiated `hero_panel_ui.tscn` directly and called `update_display()` with known cooldown/max pairs — bar read 0.5 mid-cooldown, 1.0 at ready

## 2026-07-15 — Prep-menu stage select + freed-follow crash fix

### Added (stage select)
- `scenes/prep/prep_menu.gd` — "Stage" dropdown above START BATTLE, shown once `GameState.stage_1_won` is true; lists stages from `config/stage_*_config.tres` (display names from `stage_name`), defaults to the furthest unlocked stage, and writes `GameState.stage_override` (already read by `BattleManager._ready`). Pre-unlock the menu is unchanged (no selector, original footer) and any stale override is cleared
- `GameState.reset_save()` now also clears `stage_override` so an F12 wipe can't leave a hidden stage-2 pick

### Fixed
- **Freed-hero crash:** when the camera-followed hero died, `BattleCamera.follow_target()` leaked the freed instance to `BattleHUD._update_hero_panels`, parking the game at a per-frame "Trying to assign invalid previously freed instance" break. Root cause: in Godot 4 a **freed instance compares equal to `null`**, so the `_follow != null and not is_instance_valid(_follow)` guard never fired. Guards now use `is_instance_valid()` alone (`follow_target()` + `_apply_follow`)
- Shadowing warnings cleared: `name` iterator (`battle_hud.gd`), local `offset` ×2 (`battle_camera.gd`), `size` param (`prep_menu.gd`)

### Verified
- In-engine via `godot-ai`: freed a followed hero mid-battle — no debugger break, `follow_target()` returns null, battle continues; with the Designer's real save (stage 1 beaten) the selector listed both stages, defaulted to Stage 2, and START BATTLE loaded the Berserker with elite minions (8 active = stage 2 cap); pre-unlock path re-tested with `stage_1_won` off (no selector, override cleared). Designer save backed up and restored around tests
- Tooling note: `script_patch` reports a spurious "GDScript reload failed (error 43)" on every edit — files parse clean on a fresh run

### Known Issues
- Stage pick is transient by design — the dropdown defaults to the newest unlocked stage each visit rather than remembering the last pick across sessions (open to Designer)

## 2026-07-15 — Stage-level balance targets + hero-panel camera focus

### Changed (balance — verified in-engine, see BALANCE.md)
- `config/stage_1_config.tres` — swarm cap 8 (+1/12s, max 30), minion speed 105, **spawn interval 1.4s**
- `config/stage_2_config.tres` — swarm cap 8 (+1/12s, max 30), elite speed 115, **spawn interval 1.6s**
- `scenes/villain/berserker.tscn` — HP 3500 → 2000, damage 18 → 12 (identity kept: strong-but-slow, mobile)
- `scenes/enemies/elite_minion.tscn` — 25 HP / 5 dmg / 0.75s → 22 / 4 / 0.8s
- Targets verified with instrumented runs: 2 × LV 10 beats Stage 1 (LV 6 loses); 2 × LV 25 beats Stage 2 (LV 20 loses)

### Added (camera focus)
- `scenes/battle/hero_panel_ui.gd` — panels are clickable (`clicked` signal, pointing-hand cursor, children ignore mouse); gold name highlight while followed
- `scenes/battlefield/battle_camera.gd` — `focus_on()` follow lock (eased tracking, respects pan limits); toggled off by a second click; broken by WASD/middle-drag pan; edge pan ignored while locked; auto-releases when the hero dies
- `scenes/battle/battle_hud.gd` — wires panel clicks to the camera and mirrors the lock state onto panels each frame
- `GameState.stage_override` — transient next-battle stage select (balance tests now; stage-select UI later); read by `BattleManager._ready`

### Verified
- In-engine via `godot-ai`: synthetic GUI click on a panel locked the camera onto the hero (camera position tracked the unit); highlight, toggle-off, key-pan cancel, and death release all confirmed; balance runs observed to completion at 5× time scale; Designer save backed up and restored after test runs

### Known Issues
- Stage-gate wins are photo-finishes by design (last hero at ~10–25% HP); a level or two above the gate makes them comfortable
- Balance runs were driven at 5× `Engine.time_scale` — a 1× spot-check of feel (not outcome) is worth a Designer pass

## 2026-07-14 — v0.1

### Added
- Living documentation scaffold: `README.md`, `AI_Development_Guide.md`, `Game_Design_Bible.md`, `PRODUCTION.md`, `BACKLOG.md`, `BALANCE.md`, `LOCALIZATION.md`, `DECISIONS.md`, `ART_BIBLE.md`, `AUDIO_BIBLE.md`, `CHANGELOG.md` (this file)

### Modified
- `CLAUDE.md` slimmed to a role summary + repo-specific tooling notes, pointing to the new living docs instead of duplicating them

### Known Issues
- No gameplay scenes exist yet; all balance, combat, and battlefield values remain TBD

## 2026-07-14 — Project Setup Verification

### Verified
- Project runs clean via `godot-ai` MCP: no editor errors, no plugin errors
- `application/run/main_scene` is unset — expected, no scenes exist yet

### Known Issues
- No main scene configured; will be set once the Battlefield scene exists

## 2026-07-14 — Scope & Style Alignment

### Decided
- Playable demo scope: one full gameplay loop, one villain (roster select → priorities → auto-battle → reward → level up → repeat)
- Camera/perspective: 2D isometric projection with zoom (not 2D side view, not true 3D)
- Combat movement model: simple lane movement (heroes advance toward villain, minions block the lane)
- Demo progression: XP/level with flat stat bumps only — skill trees deferred

### Known Issues
- `3d/physics_engine="Jolt Physics"` in project.godot is now unused dead config (low-priority cleanup)
- Which villain (Dark Mage vs Berserker) leads the demo is still undecided

## 2026-07-14 — Battlefield (placeholder scene)

### Added
- `scenes/battlefield/battlefield.tscn` — first gameplay scene, set as project main scene
- `scenes/battlefield/iso.gd` — 2:1 isometric grid math + single-source tile size
- `scenes/battlefield/battlefield_ground.gd` (@tool) — notebook page (cream, ruled lines, red margin) + isometric tile grid with hand-drawn jittered outlines + highlighted hero→villain lane
- `scenes/battlefield/battle_marker.gd` (@tool, `class_name BattleMarker`) — reusable placeholder pin distinguished by color/size/shape/label; self-positions from its grid cell
- `scenes/battlefield/battle_camera.gd` (`class_name BattleCamera`) — smooth mouse-wheel / +- key zoom, starts centered
- Markers placed: HERO SPAWN (green circle), 2× MINION SPAWN (red squares), OBJECTIVE (gold diamond), VILLAIN (larger purple diamond)

### Modified
- `project.godot` — `application/run/main_scene` now points at the battlefield scene

### Known Issues
- Scene is static — no hero, enemy, or combat behavior yet (by design; those are later milestones)
- Camera zoom verified to run clean; interactive zoom feel to be confirmed by Designer QA

## 2026-07-14 — Minion swarm + path following (concept test)

### Added
- `scenes/enemies/minion.gd` (`class_name Minion`) — placeholder swarm minion: follows world-space waypoints down the lane with a subtle bob, then despawns; kept lightweight for a future bulk/data-oriented swarm system
- `scenes/enemies/minion.tscn` — minion scene
- `scenes/enemies/minion_spawner.gd` (`class_name MinionSpawner`) — the Dark Mage's summoner: maintains a small looping swarm (refills as minions despawn), with clumped lateral spread; placeholder values (swarm size 8, 0.5s interval, speed 90)

### Modified
- `scenes/battlefield/battlefield.tscn` — added a `MinionSpawner` node referencing the minion scene

### Verified
- Runs clean; swarm summons from the villain and flows down the single lane as intended

### Known Issues
- Minions currently only traverse the path (no heroes to target yet); hero-targeting priority is deferred to the Combat milestone
- Swarm tuning values (count/speed/interval) are placeholders in the spawner — to move to BALANCE.md once tuned
- Per-minion `Node2D` + `queue_redraw` is fine at this scale but will be replaced by the bulk swarm system before pushing toward large counts

## 2026-07-14 — Hero (placeholder + movement) + PC display setup

### Added
- `scenes/heroes/hero.gd` (`class_name Hero`) — placeholder party hero: advances up the lane from HERO SPAWN toward the villain, then idles; name label + subtle bob; per-hero lateral offset so party walks side by side
- `scenes/heroes/hero.tscn` — hero scene
- Two hero instances in the battlefield: Thundaar (blue), Artemis (pink)
- `Iso.line_points(start_cell, end_cell)` — shared lane-path helper

### Modified
- `scenes/battlefield/battlefield.tscn` — added `Heroes` node with the two hero instances; default camera zoom 0.7 → 1.2 for 1080p framing
- `scenes/enemies/minion_spawner.gd` — refactored `_build_path()` to use the shared `Iso.line_points()` (removes duplicated lane math)
- `project.godot` — PC display specs: viewport 1920×1080, window mode fullscreen, resizable (stretch `canvas_items`/`expand` unchanged)

### Verified
- Runs clean at 1920×1080 fullscreen; heroes spawn and advance up the lane past the incoming swarm

### Known Issues
- No combat yet — heroes and minions pass through each other (Combat is the next milestone)
- Engine-gray visible outside the notebook page at some zooms (backlogged: notebook backdrop)
- Placeholder text labels overlap when units cluster (cosmetic, backlogged)

## 2026-07-14 — Combat

### Added
- `scenes/combat/combatant.gd` (`class_name Combatant`) — shared unit base: HP, throttled nearest-enemy target acquisition, melee attacks on cooldown, death (fade/shrink + removal), path movement, health bars, hit-flash, attack lunge

### Modified
- `scenes/heroes/hero.gd`, `scenes/enemies/minion.gd` — now thin `Combatant` subclasses (config only); minions target the "heroes" group so they prioritize heroes
- `scenes/heroes/hero.tscn`, `scenes/enemies/minion.tscn` — combat/visual stat defaults (see BALANCE.md)
- `scenes/enemies/minion_spawner.gd` — uses `tree_exited` to track active count (covers both combat death and path-end despawn); `setup()` now called before `add_child`
- `scenes/battlefield/battlefield.tscn` — hero instances use `body_color` / `lateral`
- `project.godot` — dev window set to windowed 1280×720 (base resolution unchanged; fullscreen remains the shipping target)
- `BALANCE.md` — combat placeholder values recorded

### Verified
- In-engine: heroes and minions fight; heroes take damage and die; minions die and the swarm refills; minions prioritize heroes; runs clean windowed

### Known Issues
- No win/lose condition yet, so the endless swarm always eventually overwhelms the heroes (~10s at placeholder balance) — expected; Objectives/Rewards milestone
- Combat balance is placeholder; tuning deferred until win/lose + waves exist
- Target acquisition is a per-unit group scan (fine now; needs spatial partitioning for the future large-swarm system)

## 2026-07-14 — Win/Lose (survive finite waves)

### Added
- `scenes/villain/villain.gd` (`class_name Villain`) + `villain.tscn` — the Dark Mage as a stationary, high-HP (2000), non-attacking `Combatant` (summoner + HP target); killing it is an alternate win
- `scenes/battle/battle_manager.gd` (`class_name BattleManager`) — win (survive all waves, or villain dead) / lose (all heroes dead) detection + placeholder HUD (status line + VICTORY/DEFEAT banner + R to replay)
- Battlefield HUD `CanvasLayer` (status label + banner label)

### Modified
- `scenes/enemies/minion_spawner.gd` — endless loop replaced with a finite **wave** coroutine (4 waves × 4); added `is_finished()` / `current_wave()`
- `scenes/enemies/minion.gd`, `scenes/heroes/hero.gd` — factions unified to `heroes` vs `hostiles` so heroes target both minions and the villain
- `scenes/enemies/minion.tscn` — minion damage 4 → 3 (balance)
- `scenes/battlefield/battlefield.tscn` — removed the static VILLAIN marker; added `Villain` instance, `HUD`, `BattleManager`
- `scenes/battlefield/battlefield_ground.gd` — renamed `_jit(seed)` param to avoid shadowing the built-in `seed()` (clears editor warning)
- `BALANCE.md` — combat + wave values recorded

### Verified
- In-engine, both outcomes: a VICTORY (heroes survived all 4 waves at ~40/88 HP) and a DEFEAT (harder tune, heroes fell on the last wave). Status HUD and banner update correctly; runs clean windowed.

### Known Issues
- Villain doesn't attack yet (summoner + HP target only); full boss behavior is a later milestone
- Balance is placeholder/tunable; leans slightly easy at current values
- The two "MINION SPAWN" markers are now cosmetic (minions summon from the villain end, not those points)

## 2026-07-14 — Retune: farm + defeat-villain loop (supersedes finite waves)

Designer clarified the core loop (GDD §16): the swarm is an XP farm, defeating the villain = out-leveling the stage to advance. The finite-wave survival win was replaced.

### Changed
- `scenes/enemies/minion_spawner.gd` — finite waves → a **continuous, escalating** swarm (cap starts at 6, +1 every 12s up to 24; spawn interval 0.5s); tracks `kills` (combat deaths = farm); removed `is_finished()`/`current_wave()`
- `scenes/battle/battle_manager.gd` — win is now **defeat the villain only**; lose = all heroes dead; status line shows `FARMED / HEROES / DARK MAGE %`; banner reworded (VICTORY = stage cleared, DEFEAT = retry)
- `scenes/enemies/minion.tscn` — minion damage 3 → 4 (restore farm pressure)
- `scenes/battlefield/battlefield.tscn` — status label default text updated
- `GDD §5/§16` — incremental farm-and-grow loop documented; `BALANCE.md`, `DECISIONS.md`, `PRODUCTION.md`, `BACKLOG.md` synced

### Verified
- In-engine: a run ended in DEFEAT after farming ~22 minions with the Dark Mage untouched at 100% — base heroes farm and are overwhelmed, exactly as intended for the pre-Progression state

### Known Issues
- Intentionally unwinnable at base stats; real winnability arrives with the Progression milestone (XP/upgrades)
- Balance is placeholder/tunable

## 2026-07-14 — Objectives (hold-to-capture)

### Added
- `scenes/objectives/objective.gd` (`class_name CaptureObjective`) + `objective.tscn` — hold-to-capture objective: a hero within range fills progress over time, a nearby hostile contests (pauses, no reset); grants a one-time farm/XP bonus on capture; drawn as a diamond with a progress ring and % label (turns green when captured)

### Modified
- `scenes/battle/battle_manager.gd` — connects objective `captured` signals, adds the bonus into the run's farm total, shows objective % / CAPTURED in the HUD status line
- `scenes/battlefield/battlefield.tscn` — replaced the static OBJECTIVE marker with a `CaptureObjective` instance

### Verified
- In-engine: heroes captured the lane objective mid-run (progress → 100%, +15 farm applied, HUD updated to "OBJECTIVE CAPTURED"), then were overwhelmed (DEFEAT) — farm-and-die loop with the objective bonus working as intended

### Known Issues
- Heroes auto-capture by proximity; pre-battle priority assignment (choosing to capture) is a later milestone
- Real XP hookup waits on Progression (the bonus currently feeds the placeholder farm tally)

## 2026-07-14 — Progression (player-directed upgrades)

### Added
- `scenes/state/game_state.gd` — **GameState autoload**: per-hero XP + upgrade purchases, saved to `user://save.json` (on run end and every purchase); upgrade catalog + rising-cost math; F12 dev save reset
- `scenes/battle/upgrade_screen.gd` (`class_name UpgradeScreen`) — post-run upgrade screen: per-hero results (+XP this run, banked, upgrade count) and buy buttons for Max HP / Damage / Attack Speed / Move Speed with live costs/affordability; R starts the next run
- `Combatant.xp_value` export + killer credit: `take_damage(amount, attacker)` calls the attacker's `_on_kill(victim)` hook on a killing blow

### Modified
- `scenes/heroes/hero.gd` — applies purchased upgrades on spawn; `_on_kill` banks kill XP to GameState immediately (kept even on a wipe)
- `scenes/enemies/minion.tscn` — `xp_value = 5`
- `scenes/battle/battle_manager.gd` — starts/ends the run against GameState, splits objective XP among living heroes, shows the upgrade screen on run end (banner removed); HUD status now shows RUN XP + per-hero LV
- `scenes/battlefield/battlefield.tscn` — `UpgradeScreen` CanvasLayer replaces the banner label
- `project.godot` — GameState autoload registered

### Verified
- In-engine end-to-end: kills credit the killer's XP live; objective bonus splits; upgrade screen appears on wipe with correct per-hero results; purchases deduct XP with rising costs; upgrades apply on spawn (exact stat math confirmed); **save persists across a full game process restart**; an upgraded hero visibly farms deeper (178 XP vs ~85 at base) — the incremental loop works
- Test save data wiped afterward (fresh start for the Designer)

### Known Issues
- Upgrade panel sits off-center (cosmetic, backlogged)
- Editor may show stale "Identifier not found: GameState" compile errors from before the autoload registration — runtime is clean; they clear on editor restart
- `godot-ai` `game_eval` can double-execute mutating code (tool quirk, noted for future testing — not a game bug)

## 2026-07-14 — Prep screen (roster + priorities + upgrades)

### Added
- `scenes/prep/prep_menu.gd` + `prep_menu.tscn` (`class_name PrepMenu`) — new **main scene**: per-hero card with party toggle, priority dropdown, live stats, and XP upgrade buttons; START BATTLE (disabled with empty party) persists config and loads the battlefield
- `scenes/battle/results_screen.gd` (`class_name ResultsScreen`) — slim post-run overlay (outcome + per-hero XP gained/banked), R returns to the prep menu
- `GameState`: `HERO_CATALOG` (names/colors), `PRIORITIES`, `party` config (selected + priority, persisted in save), party API
- `Hero.priority` behaviors: ATTACK_MINIONS (default), CAPTURE_OBJECTIVES (path to objective, hold until captured, then advance), ATTACK_VILLAIN (engagement range = attack range × 1.3, pushes to the villain)

### Modified
- `scenes/battle/battle_manager.gd` — spawns the selected party from `GameState.party` (heroes no longer hardcoded in the scene); R now returns to prep instead of reloading
- `scenes/battlefield/battlefield.tscn` — hero instances removed; `ResultsScreen` replaces `UpgradeScreen`
- `project.godot` — main scene → `prep_menu.tscn`

### Removed
- `scenes/battle/upgrade_screen.gd` — superseded by the prep menu (upgrades) + results screen (outcome)

### Verified
- In-engine full loop: prep menu loads as main scene with persisted defaults → priorities assigned (Thundaar ATTACK_VILLAIN, Artemis CAPTURE_OBJECTIVES) → battlefield spawns the party with correct per-priority behavior (rusher's detect 33.8 and villain path; capturer pathed to the objective, captured it, earned more XP holding ground) → results screen with per-hero XP → return to prep with XP spendable and priorities remembered
- Test save wiped afterward (fresh start)

### Known Issues
- Checkbox hero names render white/hard to read on the cream background (cosmetic, backlogged)
- Support Allies priority deferred until support abilities exist

## 2026-07-14 — Battlefield reshape: open field (Stage 1 sketch)

### Added
- `scenes/battlefield/stage_field.gd` (`class_name StageField`, @tool) — single source of field truth + renderer: organic hand-drawn field blob on the notebook page, hero-spawn funnel (top-left), villain corner (bottom-right), objective point (bottom-left), two blocking obstacles, scenery prop, Poison Lake (drawn; hazard effect TBD); `steer_around()` obstacle-avoidance helper (radial pushback + tangential slide)

### Modified
- `scenes/combat/combatant.gd` — movement rewritten from waypoint paths to goal-point steering (`set_goal` / `_advance_goal` / `_on_goal_reached`), avoiding field obstacles; engage-approach also steers
- `scenes/heroes/hero.gd` — spawns at the funnel, goals per priority (villain corner / objective point)
- `scenes/enemies/minion.gd` + `minion_spawner.gd` — minions spawn spread around the villain and flow toward the funnel with per-minion goal offsets (loose clusters, not a column)
- `scenes/villain/villain.gd` — positions at the field's villain corner
- `scenes/objectives/objective.gd`, `battle_marker.gd`, `battle_camera.gd` — position/point-based (grid-cell API removed)
- `scenes/battlefield/battlefield.tscn` — rebuilt around `Field`; minion-spawn markers removed

### Removed
- `scenes/battlefield/iso.gd`, `scenes/battlefield/battlefield_ground.gd` — grid/lane era over

### Fixed
- Obstacle avoidance originally used pure radial pushback, which cancels to zero lateral deflection on head-on approaches (units would walk through) — caught via in-engine steering probe, fixed with a tangential slide component

### Verified
- In-engine: field renders per the sketch; heroes cross the open field per priority (capturer took the objective then advanced; fighter pushed mid-field); swarm spreads in clusters; steering probe deflects head-on approaches; zero units inside obstacle cores during a live battle; full run → results → prep loop intact with the Designer's real save data applied (upgraded Artemis at 110 HP)

### Known Issues
- Poison Lake is visual only (hazard effect TBD, backlogged)
- No strict field-boundary enforcement (units' goals are interior, so it doesn't arise in practice)
- Steering is simple circle avoidance — sufficient now; revisit if obstacle shapes get complex

## 2026-07-15 — Poison Lake hazard + steering hardening

Battlefield reshape approved by Designer; Berserker/second-battlefield request deferred back to post-demo (Designer confirmed staying on plan).

### Added
- `StageField.lake_dps` (8 HP/s placeholder), `in_lake()` ellipse test, `_lake_radius_toward()` (elliptical lake reuses circular avoidance math), `clamp_out_of_obstacles()` hard collision — units can never clip obstacle cores
- `Combatant._take_hazard_damage()` — steady HP drain with no hit-flash spam and no killer XP credit; green tint while inside the lake

### Changed
- `scenes/battlefield/stage_field.gd` — obstacle steering refactored into one `_avoid()` helper with a smoothstepped ramp (less boundary jitter); the lake is now a soft-avoid zone (extra 50px shore margin, slightly weaker than hard obstacles so combat pursuit can still drag units through)
- `scenes/combat/combatant.gd` — per-frame hard clamp out of obstacles; steering output eased against previous heading (`_heading` slerp) so avoidance reads as smooth arcs; poison applied to all units (heroes and minions) inside the lake

### Verified
- In-engine via `godot-ai`: poison drained 190 → 173.9 HP over 2s (matches 8 dps); unit dropped inside an obstacle ejected to exactly radius + body radius (128px); unit sent straight through the lake skirts it (27/191 frames brushing the shore vs. 214 wading before tuning); test-run mutations discarded by restart

### Known Issues
- Lake DoT rate is a placeholder — tune with the field-scale balance pass
- Whether the lake should also slow units is open (Designer chose DoT-only for now)
- `game_eval` limits noted: ~8s eval budget (long frame-loops must be split or sped up) and typed-`:=` inference fails on Variant member access (declare explicit types)

## 2026-07-14 — Minion intercept behavior (fix)

### Changed
- `scenes/enemies/minion.gd` — minions now **hunt** the nearest living hero field-wide (throttled 0.3s re-evaluation), steering to an intercept point `intercept_lead` (90px) ahead of the hero toward the villain, plus their per-minion cluster offset — the swarm blocks the party's way instead of drifting to the funnel; with no heroes alive they fall back to flowing toward the funnel and despawn there
- `scenes/enemies/minion_spawner.gd` — passes the swarm-cluster offset to `setup()` (reused for both the fallback exit and the hunt formation)

### Verified
- In-engine: 6/6 minions hunting with goals placed villain-side of the hero (57–140px from it); swarm visibly converged and piled onto both heroes at the Dark Mage while they attacked it (villain at 1904/2000 — heroes damaging the boss through the defending swarm)

### Known Issues
- Intercept lead is a flat 90px — may want per-minion variation later for a more organic surround
