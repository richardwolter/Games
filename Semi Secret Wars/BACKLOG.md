# Semi-Secret Wars — Backlog

This document changes frequently. See [AI_Development_Guide.md](AI_Development_Guide.md) §16.

| Feature | Priority | Status | Dependencies | Notes |
|---|---|---|---|---|
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
| Support Allies priority | Low | Not Started | Support/heal abilities | Deferred until support abilities exist (GDD §11) |
| Prep/results UI polish | Low | Not Started | Prep screen | Checkbox hero names render white/hard to read; results panel off-center; placeholder styling |
| More objectives + effect variety | Low | Not Started | Capturable objectives | 2nd objective, and alternate effects (e.g. weaken villain) |
| Combat balance tuning | Medium | Not Started | Objectives + win/lose | Numbers in BALANCE.md; "fair" depends on win/lose + waves existing |
| Rewards | Medium | Done | Objectives | Folded into Progression — XP from kills + objectives is the demo reward |
| Progression (player-directed upgrades) | High | Done | Rewards | `GameState` (persistent save) + post-run upgrade screen; 4 upgradable stats, rising costs |
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
| Skill trees | Low | Not Started | Progression | Post-demo; node layout/costs/unlocks all TBD |
| Remove unused 3D physics engine config | Low | Not Started | — | `3d/physics_engine="Jolt Physics"` in project.godot is dead config now that the project is 2D |
| Promote Iso tile size to per-battlefield Resource | Low | Obsolete | — | `iso.gd` was deleted with the grid/lane era (battlefield reshape) |
| Camera pan controls | Low | Not Started | Battlefield | Zoom works; panning (drag/keys) deferred until needed |
| Notebook backdrop / clear color | Low | Not Started | PC display setup | Engine-gray shows outside the page at some zooms; needs a proper desk/page backdrop |
| Settings menu (fullscreen/windowed toggle, resolution) | Low | Not Started | PC display setup | Player-facing display options for the published build |
| Placeholder label overlap | Low | Not Started | Hero | Hero/marker text labels overlap when units cluster; cosmetic only |
| Expansion | Low | Not Started | Progression | Intentionally undefined per GDD §23 |
