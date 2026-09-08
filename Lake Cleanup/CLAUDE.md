# Lake Cleanup — Incremental Trash Collection Game

## Role

You are the lead programmer and technical designer for an incremental game prototype being developed in **Godot 4.7, using the latest stable version available**.

Your job is to build the game incrementally with clean architecture and testable systems. The human developer (Richard) is the game designer and tester. When a design decision is required, explain options briefly and ask before proceeding.

---

## Game Concept

**Lake Cleanup** — an incremental idle/active hybrid where the player manages a lake's restoration.

### Setting
- Single lake, side-view cross-section
- 2D, `gl_compatibility` renderer
- 120Hz physics (**no physics at all** — see Architecture below)

### Verbs
**Manual (active)**:
- Hold-to-haul discrete `TrashObject`s using a boat and net
- Progress ring shows haul rate = player strength ÷ `TrashDef.haul_cost`
- Net bites a configurable depth from each water column it passes, gated by tier

**Idle (automatic)**:
- Machines and drones drain continuous `pollution` float over time
- They work while idle, accumulating per-room upgrade levels

### Economy (Two-Layer)
Why two layers? You cannot idle-drain individual objects without it feeling arbitrary, and a bare meter is just a progress bar with a button.

**Manual layer**: Hold-to-haul collects `TrashObject`s, knocking chunks off `pollution` (resolved per-object).

**Idle layer**: Continuous `pollution` float is what machines reduce passively.

**Visual link**: `pollution` directly drives the water shader. The lake clearing up **IS** the progress bar — not a separate number.

### Progression
Treat it as a deliverable, not polish: the clean state must **gain density** (plants, surfacing fish, birds, clarity) — Richard flagged this as the weakest part of the loop.

**Build order** (Richard's deliberate choice):
1. Water feel and drag mechanics **first**
2. Progression-curve numbers **after**

This inverts the notes' advice but keeps fun physics-first.

---

## Architecture: Physics-Free Grid Layout

**No physics at all** — Lake Cleanup abandoned RigidBody2D, Area2D buoyancy, and collision after several failed designs.

### Why
Every physics-era bug came from the seam between thousands of drawn pieces and a few simulated ones:
- Overlap explosions on promotion
- Sleeping bodies ignoring applied force
- Collapsed heaps without a frozen shell
- Cap leaks

Keeping one representation (layout instead of physics) eliminates these entirely.

### The Grid
- **Basin**: 4 screens wide (`HALF_WIDTH = 2400`, `MAX_DEPTH = 620`), split into 26px columns
- **Stack structure**: Each column is a stack of 22px slots, each holding a trash item ID
- **Built once** from a fixed seed with heaviest items at the bed
- **Reachability**: Only the top of each stack is harvestable
  - "Skim light rubbish first, upgrade to reach deeper" is spatial, not rule-enforced
  - Depth gating is where the trash is, not in code
- **Settling**: Taking a piece shifts the stack down, eases one per-column `settle` float per frame

### Item Data
- `TrashDef` now holds: sprite, size, pollution value, haul_cost, tier, lightness (sort key, not force)
- No physics-derived properties
- **Lightness** determines sort order when reordering the stack — heavy items sink naturally over time

### Why Layout is Better Than Physics
1. One source of truth (layout) prevents overlap bugs
2. Falling junk-line is the progress bar (always visible)
3. No "reachability" bugs from physics state diverging from display
4. "Skim light trash first" is emergent from the stack, not enforced

**Don't re-introduce physics later thinking "I'll fix it differently."** The grid learned these lessons.

---

## Art Pipeline: ComfyUI Generation

### Photo Cutouts → Generated Art
An earlier session (notes: `~/Downloads/lake-cleanup-game-notes.md`) planned **photo-cutouts** from EBC-licensed stock but switched to **ComfyUI generation**.

**Why the switch**:
- EBC license reply blocked the photo path
- Hand-masking cost ~10 min per object
- Yielded only 6–8 usable objects from one 1170×700 photo
- Sprite cap: ~145px per bottle (no headroom for larger items)

**Generated art lives in**: `_pipeline/tools/generate_art.ps1` (PowerShell)

### Art Thesis (Kept)
Photoreal garbage against flat illustrated water, flat-overcast wet mud-caked lighting — the **style shift itself is the reward**. Only the sourcing changed.

**How to apply**: Don't re-raise the EBC email or consider the four pre-generated asset packs. The current pipeline is settled.

### Scale Authoring
Sprites are authored for specific grid/world size. **Stride is not negotiable**:
- 26px columns, 22px slots per column, 145px bottle max
- Layout size determines what fits
- Changing sprite scale breaks the grid assumptions

---

## Godot/Windows Gotchas

### Logging & Debugging
- `print` and `printerr` don't reach shell on GUI Godot builds (Desktop is GUI-based)
- **Write to file**: headless harness writes `tools/last_test.log`, flushed per line
- Test harness for drag mechanics: `tools/test_grab.tscn`, stepped by `_physics_process` (~1s per test, 25 checks)

### GDScript Coroutines
- Errors inside coroutines abort **silently** and leave the tree spinning
- Looks exactly like a hang (stalled output)
- Wrap coroutines carefully; use `print` statements before/after to trace execution

### Headless `--script` Mode
- `await physics_frame` stalls indefinitely on this setup
- Use `_physics_process` in a scene instead (see test harness pattern)

---

## Scripts Overview
- `scripts/lake_grid.gd` — basin, column stacks, settling logic, net harvesting
- `scripts/player.gd` — boat position, net control, haul feedback
- `scripts/boat.gd` — net animation and interaction
- `scripts/water_splash.gd` — ripple feedback on haul/placement
- `shaders/water.gdshader` — surface deformation, `pollution`-driven clarity
- `scripts/sfx.gd` — audio for haul, settling, collection

---

## Before You Start
1. Read root `CLAUDE.md` for shared Godot setup, anti-patterns, vigilance rule
2. Check GitHub Issues (filter by `project:lake-cleanup`)
3. Water and drag feel are locked (Richard tested); progression numbers can shift
4. If editing grid layout or physics: test with `tools/test_grab.tscn`
5. If finding contradiction: stop and name it (see root CLAUDE.md vigilance rule)

---

## See Also
- Root `CLAUDE.md` — shared knowledge, art pipeline details, vigilance rule
- `Strait Across/CLAUDE.md` — sister project (shares water shader, similar project structure)
- Game design notes: `~/Downloads/lake-cleanup-game-notes.md` (historical reference, not current)
