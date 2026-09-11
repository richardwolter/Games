# Lake Cleanup — Incremental Trash Collection Game

## Role

You are the lead programmer and technical designer for an incremental game prototype being developed in **Godot 4.7, using the latest stable version available**.

Your job is to build the game incrementally with clean architecture and testable systems. The human developer (Richard) is the game designer and tester. When a design decision is required, explain options briefly and ask before proceeding.

---

## Game Concept

**Lake Cleanup** — an incremental idle/active hybrid where the player manages a lake's restoration.

### Setting
- Single lake, isometric (2:1) tile field seen from above at an angle — see `scripts/iso.gd`
- 2D, `gl_compatibility` renderer
- No physics at all (see Architecture below)

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

**Visual link**: the lake clearing up **IS** the progress bar — not a separate number. As of the per-tile filth map (`Lake._build_filth_map`), the water shader's colour reads that map, not `pollution` directly: a bay just cleared reads blue on the spot while the next one over is still soup. `pollution` is the map's fallback (read only where `filth_mapped` is 0, i.e. before the first map build) and still drives `sparkle` at the finished state.

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
- **Basin**: an isometric tile field (`Iso.COLS = Iso.ROWS = 92`), an ellipse of tiles inside it —
  see `scripts/iso.gd`. Superseded the earlier column-stack description below; the lessons
  (one representation, no physics) carried over, the geometry did not.
- **Reachability**: only the top of what a tile holds is harvestable — spatial, not
  rule-enforced. "Skim light rubbish first, upgrade to reach deeper" is a *trend*, not a
  schedule (see below) — depth still points a stack at a rough weight class, but no
  longer at one piece off one line sorted lightest to heaviest.

### Item Data
- `TrashDef` now holds: sprite, size, pollution value, haul_cost, tier, lightness (weight class, not force)
- No physics-derived properties
- **Lightness** used to be a sort key for the whole basin's fill — every stack drawn from
  one line, lightest on top, heaviest at the floor. That read as a schedule: skim long
  enough and the next tier down was always the very next entry. `LakeGrid._roll_piece`
  replaced it — a material by `MATERIAL_QUOTA`, then a lightness band around the slot's
  depth (`FILL_BAND`), with `FILL_BAIT_CHANCE` of slots ignoring the band so a rare heavy
  piece can float near the surface as a landmark rather than a hazard. Material quota is
  measured off the old fill, not guessed, so the four yards keep the traffic they had.

### Why Layout is Better Than Physics
1. One source of truth (layout) prevents overlap bugs
2. Falling junk-line is the progress bar (always visible)
3. No "reachability" bugs from physics state diverging from display
4. "Skim light trash first" is emergent from the stack, not enforced

**Don't re-introduce physics later thinking "I'll fix it differently."** The grid learned these lessons.

---

## Art Pipeline: Pixel Art Isometric

### Current Direction: Cohesive Pixel Art
Lake Cleanup's visual target is **cohesive pixel art isometric**, all assets from a single visual voice. This is the settled direction for the vertical slice.

### Asset Sourcing
**Base + Retouch Pipeline**:
- Use CC0 pixel art packs as base (e.g., Kenney, Forest Isometric Pack Free)
- Programmatic retouching: recolor to palette, scale, shadow, alignment
- No ComfyUI generation or photoreal elements in the vertical slice

**Why this choice**:
- Earlier attempts at photoreal + illustrated water split the visual voice
- Cohesive pixel art reads as a single game and scales to any resolution
- Palette-driven recolor keeps all assets aligned
- Faster iteration than ComfyUI + hand-masking

### Master Palette
All visuals (ground, water, UI, furniture) derive from a **master palette extracted from Forest Isometric Pack** (see issue #3). This ensures consistency by construction, not by manual matching.

**Palette lives in**: `scripts/palette.gd` and `resources/palette.tres`, written by
`tools/extract_palette.gd` (measured colours from the pack, plus the authored `WATER_RAMPS`).

### Pixel-Art Water
`water.gdshader`, `foam.gdshader` and `hull_foam.gdshader` draw as pixel art, not as smooth
effects behind it. Shared rules in `shaders/pixel.gdshaderinc`:
- **Grid**: every effect is evaluated once per `foam_pixel` (2 world px) cell. Water uses the
  world grid; the foam collars and bow waves snap in their own piece/boat frame, so the grid
  travels with the smoothly moving sprite instead of crawling across it.
- **Colours**: output is only palette swatches — two five-step water ramps
  (`water_clean_*`, `water_dirty_*`), `foam`/`foam_light`/`foam_dirty`, and the grime.
  Depth, bands, glints and sparkle sum to a ramp position; in-between values are dithered
  with a fixed 4x4 Bayer pattern, never blended. Clean vs dirty ramp is dithered on local
  filth the same way, so a bay clears as a thinning green pattern. The water is opaque.
- **Motion**: pattern animation runs on `stepped_time(TIME, pixel_fps)` (default 8 fps). The
  **swell** (what open foam and foam collars ride) keeps real `TIME` because the rubbish rides
  it smoothly; open foam's swell offset is rounded to whole pixels instead.
- Retune colours in `extract_palette.gd`'s `WATER_RAMPS` (and `palette.tres`), not in the
  shaders — their defaults only mirror the palette.
- Out of scope, by decision: `splash_foam`, `splash_specks`, `glint.gdshader`, and the
  pollution meter (`style.gd` `METER_*` still mirror the old smooth water; the UI is due
  to be replaced).

### Archive
- The earlier `_pipeline/tools/generate_art.ps1` (ComfyUI pipeline) and EBC photo approach are archived.
- Do not resurrect unless vertical slice changes scope to explicitly include photoreal art.

### Scale Authoring
Sprites are authored for the isometric tile size (`Iso.TILE_W = 64`, `Iso.TILE_H = 32`). Changing
sprite scale breaks the grid assumptions.

### The Decoration Catalogue (the collection)
The finds — the furniture the player nets and stands in the shed — come from
`art_source/Decoration_Clean_Dirty` (a PSD, no extension). It holds two layer groups:
`Decoration` (restored, as the shed shows it) and `Decoration Dirty` (grimy, as the lake
shows it). 34 finds.

**Pipeline** (all offline, run from the project root):
1. `psd-extract` skill → `art_source/decoration_extracted/` (one PNG per layer + manifest).
   `art_source/.gdignore` keeps these out of the Godot project.
2. `tools/decor_sets.json` — the **authored** catalogue: titles, dirty↔clean pairing, set
   kind, and slice rects.
3. `tools/build_decor.py` → `assets/decor_clean.png`, `assets/decor_dirty.png`, and the
   decor half of `assets/pieces.json`.

**Why the table is authored, not detected**: a set is several sprites packed into *one*
layer. Nothing in the pixels says whether the second sprite is the same chair turned
sideways (`ROTATE`), a second style of the same thing (`VARIANT`), or the same fridge with
its door open (`STATE`) — and those are three different mechanics. Gap detection finds the
rectangles; only a person can say what they are.

**Clean and dirty are no longer the same picture twice.** The retired TopDownHouse pair was
one layout in two palettes, so `sheets.gd` read one rectangle against a parallel sheet. The
decoration art draws each find grimy once and restored as several views at their own sizes
(dirty sofa 22x55, clean sofa front 49 wide). So every piece carries its own rectangle on
each sheet: `Sheets.views` / `view_region_of` / `footprint_view`. **The shed must measure
footprints off the view it is standing, never off `region_of`** — that is the lake's sprite.

**The invisible wall**: a layer's bounding box is not the object. The dirty `Bath Sink`
layer is a 19x29 sink with an 8-pixel fleck 150 px away, giving a 172x86 box that draws as
an invisible wall in the water — it covers what is behind it and eats clicks. `despeck` in
`build_decor.py` fixes it by *distance*, not by size: the largest pixel island is the
object, anything within `GLUE = 4` px joins it, the rest is a stray. A size threshold is
the wrong rule — at 8 px that fleck is bigger than plenty of real detail.

### Shed Verbs (`scripts/shed_room.gd`)
- **R** cycles the piece **in hand** — `ROTATE` views and `VARIANT` styles both. Only while
  carrying: a placed piece is turned by picking it up again, so one gesture means one thing.
  A three-view set (sofa, armchair, both chairs) gets a fourth face from a mirrored side,
  baked into the sheet by the builder. Two-view sets are front and side as drawn.
- **E** works a `STATE` piece the player is **standing at** (`REACH`), with an on-screen
  prompt. Fireplace on/off, fridge open/shut. A lit piece draws a glow on the boards —
  warm and wide for fire, weaker and whiter for the fridge. Drawn circles, not Light2D:
  the room is one `_draw` on a Control.
- The view a piece stands in persists in the `decor` row as `"view"`.
- **Copies**: a find can be hidden more than once — `copies` in `decor_sets.json`, baked
  into `pieces.json`, read via `Sheets.copies_of`. Both chairs are **4** (a dining table
  with one chair at it is not a room anybody lives in); everything else is 1. Each copy is
  its own def, its own hiding place in the lake, and its own row in `unlocked` — they share
  one dirty sprite and are netted and stood separately. `_keep` caps at `copies_of`, and
  `in_store()` **counts** rather than matching by name: matching emptied the shelf of all
  four the moment the first was stood down.
- `ShedRoom.DOG_BED` is `decor_pet_bed` — one find, two styles, so either bed is the dog's.

### Golden Glitter (`LakeGrid.GlintLayer`)
Finds stay **buried** (`Lake._hide_treasures` plants them a couple of slots down). The
glitter is not a map: a find within `GLINT_REACH = 3` slots of the top shimmers faintly
through the muck, and glints fully with turning specks once uncovered. Drawn *above* the
rubbish, because the point is to be visible while the find itself is not.

### Strand Line (outer bank rubbish, fetched by the dog)
The ordinary fill stops `LAKE_EDGE` short of the bank. The band inside that margin
(`Iso.on_strand`) gets its own washed-up rubbish from `LakeGrid._strand`: `STRAND_CHANCE` of
those tiles hold one piece, `STRAND_TWO` of them a second. **Only tier-0 pieces no wider than
`STRAND_WIDE`** (the cans, cup, wrap, sheet) — because the **dog** is what collects them. The
net reaches ~6 tiles from the island and the bank is ~26 away; patrolling boats stay inside
85% of the radius. So the dog makes an occasional bank run (`Dog.STRAND_ODDS`, only when
nothing near the island is fetchable), with its own trip limit (`STRAND_TRIP_MOST`).
- Collectible and counted like any piece: the lake cannot finish until the dog has cleared
  the strand. If a bank piece ever becomes unfetchable (bigger def, tier > 0), the lake
  stalls — keep `STRAND_WIDE`/tier in step with `Dog.CARRY_WIDE`/`CARRY_TIER`.
- Outer bank only, by decision: the island's beach stays tidy.
- Seeded off the lake seed on its own generator, so the rest of the fill is unchanged.
  Existing saves restore their stacks and have no strand pieces.
- Grime: `water.gdshader` draws scum blotches in the bank's shallowest water, scaled by the
  local filth, so they go as that stretch is fetched clean.
- **Beach litter** (dry pieces): the same small set also lies up the outer bank's sand,
  `Iso.BEACH_LITTER` tiles past the waterline, on `BEACH_CHANCE` of those tiles. They are real
  stacks on land tiles, flagged by `LakeGrid.dry`: no bob/sway (packed with `DRY_ANCHOR`,
  which rubbish.gdshader and shadow.gdshader read as "still"), no waterline cut, no foam, no
  rise, no bump/shove. The dog may walk up the bank's beach to `Dog.BEACH_WALK` to fetch
  them. Any new code that moves or cuts pieces must respect `dry`.

### Rubbish Sheets
The regular rubbish (not finds) is drawn from two sheets:
- `assets/lake_objects.png` — the first 27 kinds, from `art_source/LakeObjects.psd`. Its
  regions in `pieces.json` were cut once and corrected by hand; nothing regenerates them.
- `assets/lake_objects_new.png` — the second batch of 10, built from
  `art_source/New_Objects_Lake` by `tools/build_lake_objects_new.py` (psd-extract venv
  python, project root). Despecks with `build_decor.py`'s rule, maps the two
  `Wood Painting` layers to `wood_painting3`/`4` by left-to-right position, and replaces
  only its own sheet's entries.

**Adding kinds**: a `.tres` under `resources/trash/`, its slug appended to `TRASH_ORDER`
(`lake.gd`), and a `SAVE_VERSION` bump. Saved stacks hold indices into the whole def list and
the finds come after the rubbish in it, so appending rubbish moves every find's index.
`size` in a `.tres` is only the no-art fallback: `Lake._dress` draws a piece at its pixel
size × `SPRITE_SCALE` (1.5), clamped to `SPRITE_SMALLEST`..`SPRITE_LARGEST`.

### Retired
`assets/TopDownHouse_FurnitureState1/2.png` no longer feed the catalogue and `furniture_NN`
names are gone (so is `scripts/find_names.gd` — titles live in `pieces.json` beside the
rectangles now). `SAVE_VERSION` is 5 and older saves are refused rather than migrated;
`RECUT_RENAMES` and `tools/repair_save.gd` went with them. `tools/slice_sheets.gd` still
cuts the rubbish sheet, and still writes the whole `pieces.json` — **run
`tools/build_decor.py` after any re-slice** or the decor half is lost.

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
- `shaders/water.gdshader` — pixel-art lake surface: palette ramps, dithered filth/depth, shore and open foam
- `shaders/pixel.gdshaderinc` — shared pixel grid, Bayer dither, stepped time
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
