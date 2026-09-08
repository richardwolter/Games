# Modern Daedalus Studio — Game Development Monorepo

## Context

This is a monorepo holding 5 independent Godot 4.7+ game prototypes under development by Richard Wolter. Each game is at a different stage; this document covers shared knowledge, decisions, and tools that span across them.

**Projects:**
- **Lake Cleanup** — incremental lake-cleaning game, 2D side-view, ComfyUI-generated art
- **Strait Across** — physics bridge-builder, levels + shop + surprise boxes, 2D
- **Sickest Man Alive** — twisted roguelite in a shrinking kid's body, top-down twin-stick
- **Semi Secret Wars** — (status: active, CLAUDE.md at `Semi Secret Wars/CLAUDE.md`)
- **Roguelite Football Manager** — (status: active, CLAUDE.md at `Roguelite Football Manager/CLAUDE.md`)

---

## Directory Structure

```
Games/
├── CLAUDE.md                          ← You are here (shared knowledge)
├── _pipeline/
│   └── tools/                         ← Godot build tools, asset generation (PowerShell)
├── _builds/                           ← Release artifacts (git-ignored usually)
│
├── Lake Cleanup/
│   ├── CLAUDE.md                      ← Project-specific decisions
│   ├── project.godot
│   ├── scripts/
│   ├── scenes/
│   ├── assets/
│   └── .claude/
│       ├── settings.local.json
│       └── launch.json
│
├── Strait Across/
│   ├── CLAUDE.md                      ← Project-specific decisions
│   ├── project.godot
│   ├── data/levels/
│   ├── scripts/
│   ├── scenes/
│   └── .claude/
│
├── Sickest Man Alive/
│   ├── CLAUDE.md (not yet)            ← Create during full onboarding
│   ├── project.godot
│   ├── src/
│   ├── scenes/
│   └── .claude/
│
├── Semi Secret Wars/
│   ├── CLAUDE.md
│   ├── project.godot
│   └── .claude/
│
├── Roguelite Football Manager/
│   ├── CLAUDE.md
│   ├── project.godot
│   └── .claude/
│
└── .claude/
    └── settings.local.json            ← Monorepo defaults (projects override locally)
```

---

## Godot Shared Knowledge

### Version & Setup
- **Engine**: Godot 4.7+ (latest stable at session start)
- **Build System**: Desktop builds are GUI-based (no shell integration). Headless scripting use `--script` with `SceneTree` and `_physics_process`, not `await physics_frame` (stalls indefinitely on this setup).
- **Executable Path**: The Desktop Godot in `C:\Program Files\` is the one that runs. `Documents/Godot/` is broken; don't use it.

### Physics & Simulation Gotchas
- **Lake Cleanup** abandoned physics (`RigidBody2D`, `Area2D` buoyancy, collision) after several failed designs. Now uses a fixed grid of columns with discrete item stacks — no physics at all. Keep one representation always (layout OR simulation, not both).
- **Strait Across** uses full 2D physics for bridge pieces; test harness is at `tools/test_grab.tscn`, stepped by `_physics_process` (~1s per test, 25 checks). `GDScript` errors inside coroutines abort silently and leave the tree spinning (looks like a hang).

### Logging & Debugging
- `print` and `printerr` don't reach shell on GUI builds. Write to file instead: see Lake Cleanup's `tools/last_test.log` (flushed per line).
- Test harness for Sickest Man Alive: runs headless, validates pipeline order-independence via `tools/test_pipeline.gd`.

---

## Shared Art Pipeline

### Photo Cutouts → ComfyUI
**Lake Cleanup** originally planned photo-cutouts of real trash (from EBC-licensed stock) but switched to ComfyUI generation (`_pipeline/tools/generate_art.ps1`):
- **Why**: EBC license reply blocked, hand-masking cost ~10 min/object, yielded only 6–8 objects, source capped sprites at 145px.
- **How It Works**: Prompt-based generation of photoreal garbage against flat illustrated water, flat-overcast lighting.
- **Thesis Kept**: The style shift (photoreal trash + flat water) remains the reward.
- **How to Apply**: Don't re-raise photo sourcing; the current pipeline is settled.

### Sprite & Asset Data
- **Asset JSON Format**: Spritesheets are paired with `.json` metadata (name, frames, animations).
- **Scale Authoring**: Sprites are authored for specific grid/world size. Lake Cleanup: 26px columns, 22px slots, 145px bottle max. Stride is not negotiable per object; layout size determines what fits.

---

## Locked Design Patterns

### Order-Independent Stat Pipelines
**Sickest Man Alive** builds stats from modular item lists:
- **Invariant**: `Loadout` recomputes stats fully from scratch every time — no incremental apply.
- **Reason**: `MULTIPLY` and `BLEND` operations have no clean inverse; chaining `lerp(0.5)` is not associative.
- **Blending**: `BLEND` uses mean aggregation, not pairwise chaining, so pickup order never matters.
- **Escape Hatch**: `Op.APPEND` is fenced by `APPENDABLE` — if you add a stat to that list, do it consciously.
- **Validation**: Run `tools/test_pipeline.gd` (headless) after any pipeline change. Treat it as the regression gate.

### Two-Layer Economy (Lake Cleanup)
- **Manual verb**: Hold-to-haul discrete `TrashObject`s (progress ring, rate = strength ÷ haul_cost).
- **Idle drain**: A single continuous `pollution` float is what machines and drones reduce while idle.
- **Why**: You cannot idle-drain individual objects without it feeling arbitrary; a bare meter is a progress bar with a button.
- **Visual Link**: `pollution` drives the water shader directly — lake clearing up IS the progress bar.

### Physics-Free Grid Layout (Lake Cleanup)
- **Structure**: Basin 4 screens wide (`HALF_WIDTH=2400`, `MAX_DEPTH=620`), 26px columns, 22px slots, fixed stackable items.
- **Reachability**: Only the top of each stack is harvestable — depth gating is spatial, not rule-enforced.
- **No Overlap Bugs**: One representation (layout) eliminates physics-era problems: overlap explosions, sleeping bodies ignoring force, collapsed heaps.
- **Why Matters**: Don't re-introduce physics later thinking you'll "fix it differently" — the grid learned lessons.

---

## Known Anti-Patterns

### Don't Do These (We Learned)
1. **Physics simulation + drawn pieces**: Leads to overlap explosions, sleeping bodies that ignore force, heaps collapsing.
2. **Physics-driven depth gating**: Use layout and spatial rules instead (Lake Cleanup's column stack model).
3. **Incremental stat application**: Causes order-dependent behavior (Sickest Man Alive switched to full recompute).
4. **`await physics_frame` in headless `--script` mode**: Stalls indefinitely. Use `_physics_process` in a scene instead.
5. **Photo-cutout asset sourcing on uncertain licensing**: Use generated art if authorship is unsure.

---

## Workflow

### GitHub Issues & Backlog
- **Repository**: `richardwolter/Games` (monorepo on GitHub)
- **Tracking**: GitHub Issues with project labels (`project:lake-cleanup`, etc.) and Milestones (one per project).
- **Process**:
  1. Open session, read backlog for the target project (filter by label + milestone).
  2. Pick one issue together.
  3. Work, commit (e.g., `Implement net drag mechanic for Lake Cleanup`).
  4. Close issue when done (or update status if blocked).

### CLAUDE.md as Source of Truth
- **Project CLAUDE.md**: Locked design, role, game concept, progression, architecture rules.
- **Root CLAUDE.md (this file)**: Shared knowledge, tools, setup, anti-patterns, vigilance rules.
- **Single Representation**: If a fact exists in both places, the more specific one (project > root) wins.

---

## Vigilance Rule

**When you find a contradiction, stop and name it. Do not silently proceed.**

**Contradiction = any conflict between:**
- Two CLAUDE.md sections (root vs. project, or within a project)
- CLAUDE.md vs. current code (stale docs)
- CLAUDE.md vs. GitHub Issue (decision changed but doc wasn't updated)
- CLAUDE.md vs. memory files (project decisions moved to CLAUDE.md, memory not deleted)
- Design claim vs. observable code behavior (e.g., "physics off" but `RigidBody2D`s exist)

**When found:**
1. Quote both sources.
2. Ask: "Which is authoritative, and why did they diverge?"
3. Wait for clarification or fix it together.
4. **Never guess**. The cost of a wrong guess is a broken codebase later.

**Example**: Strait Across CLAUDE.md §4–5 claimed donations and factories drive economy, but code shows shop + surprise boxes. (Resolved: §4–5 are stale, see memory note; root CLAUDE.md now flags it.)

---

## Before You Start

1. **Read the project's own CLAUDE.md** (it overrides this root doc on specifics).
2. **Check GitHub Issues** for that project (filter by label + milestone).
3. **If you edit code that affects design**: update CLAUDE.md and close stale issues.
4. **If you find a contradiction**: point it out before proceeding.
5. **Test harness**: Lake Cleanup (`tools/last_test.log`), Sickest Man Alive (`tools/test_pipeline.gd` headless).

---

## Shared Tools

### PowerShell Pipeline Scripts
Located in `_pipeline/tools/`:
- `generate_art.ps1` — ComfyUI prompt-based sprite generation (Lake Cleanup)
- Build & slice tools (per-project, see individual CLAUDE.md files)

### Test Harnesses
- **Lake Cleanup**: `tools/test_grab.tscn` (drag/haul mechanics, ~1s per test)
- **Sickest Man Alive**: `tools/test_pipeline.gd` (stat order-independence, headless)
- See project CLAUDE.md for invocation details.

---

## Next Steps

When you onboard a new project:
1. Create its CLAUDE.md (if missing) by absorbing any memory notes and current code structure.
2. Migrate project-specific memories into the CLAUDE.md, then delete the memory files.
3. Create GitHub Issues/Milestones for backlog.
4. Commit the CLAUDE.md.
5. Update root MEMORY.md to reflect that project decisions are now in CLAUDE.md, not memory.
