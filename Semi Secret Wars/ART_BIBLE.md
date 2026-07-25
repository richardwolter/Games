# Semi-Secret Wars — Art Bible

Defines the visual language. Initially small; expands as production grows.

## Art Direction

Minimalist, hand-drawn, notebook aesthetic, child's comic book. Simple colors, thick outlines, imperfect shapes. The game takes place inside the pages of a child's notebook.

## Character Proportions

TBD.

## UI Style

Interface matches the notebook presentation: everything looks drawn onto the same page as the battlefield and the hero sprites. Menus remain simple and readable.

**Single source of truth (2026-07-25):** every UI colour, size and shape comes from one of two places, which mirror each other — change both together:

- [`scripts/ui_style.gd`](scripts/ui_style.gd) (`UIStyle`) — palette constants, the type scale, and factory helpers (`panel`, `card`, `overlay_panel`, `label`, `button`, `texture_button`, `hero_portrait`) that all code-built UI calls.
- [`assets/ui/notebook_theme.tres`](assets/ui/notebook_theme.tres) — the project-wide default `Theme`, set via `gui/theme/custom` in `project.godot`, so every Control inherits the look without its scene wiring a theme. `scripts/ui_boot.gd` re-asserts it at runtime as a fallback.

Rules:

- **One ink.** `#2c2c2c` for all body text and outlines; `INK_MUTED` (same ink, 60% alpha) for footnotes. No second black.
- **Paper, never white.** Panels and cards use the page colour at varying alpha (`PAGE` / `CARD` / `CARD_STRONG`), never flat `Color(1,1,1,…)`.
- **Corners wobble.** Panels use uneven corner radii from `UIStyle.CORNER_SETS` — a hand-drawn box never closes square. Pass a *stable* `variant` (an index, an id length) so the shape doesn't crawl between redraws.
- **Named sizes only.** Use `UIStyle.SIZE_TITLE/HEADING/SUBHEAD/BODY/SMALL/TINY` (56 / 42 / 32 / 24 / 20 / 17). Don't invent new font sizes at call sites.
- **Mind the 0.67× canvas.** All sizes are in design-canvas pixels (1920×1080) but the window runs 1280×720 with `canvas_items` stretch, so the player sees everything at two-thirds. Divide by 1.5 to get real pixels — this is why the first pass at 18px body text was unreadable. Nothing should be specified below `SIZE_TINY`.
- **The HUD owns the top band.** In battle, y 0–150 is taken (XP/gold left, timer centre, villain right, back button, then hero panels down the left edge from y110) and the bottom-centre band holds objectives from y910. Transient battle UI goes in the free middle-bottom band on its own `CanvasLayer` above layer 0 — see `DeployController.DEPLOY_LAYER`. Any panel overlaying the field must set `MOUSE_FILTER_IGNORE` so field clicks still get through.
- **Menu art is the anchor.** The hand-drawn logo and NEW GAME / CONTINUE / START RUN button PNGs define the vibe; screens are styled to match them, not the other way round.
- **Rosters show real sprites.** Hero cards use `UIStyle.hero_portrait`, which pulls the actual battlefield sprite via `Hero.sprite_for` — the menu and the field show the same drawing, not a colour swatch standing in for it.

**Font:** DrawFont (dafont.com, added by the Designer 2026-07-25) at `assets/fonts/DrawFont.ttf`, wired as the theme's `default_font`. Replacing that one file restyles all text in the game.

**Menu page dressing (2026-07-25):** `PrepPage` — the shared background behind TitleScreen, PrepMenu, AbilitiesPage and StatsPage — is not a blank page. It carries scenery props and bloodstains so the menus read as the same fought-over world as the battlefield:

- Props reuse the battlefield's own sprite PNGs (`assets/sprites/`), drawn bottom-anchored on a ground point exactly like `LaneField._draw_prop_sprite`.
- Stains reuse `BloodLayer`'s blot shape — overlapping lobes plus satellite speckles, never one clean circle.
- Placement is **hand-authored and normalised**, never randomly scattered: every prop's drawn rect must clear the centred UI column (x 0.21–0.79 — PrepMenu's column is the widest at 1122px on the 1920 canvas). Verify extents when adding props; a prop's *width* can intrude even when its centre doesn't.
- Stain lobes come from a fixed-seed RNG. `_draw` re-runs on resize, so an unseeded RNG would make the page's stains crawl every time the window changed.

## Color Palette

Defined in `UIStyle`; these hex values are the whole palette.

| Role | Colour | Notes |
| --- | --- | --- |
| Page (paper) | `#f4efe1` | `PAGE_SOLID` opaque, `PAGE` for overlays, `CARD`/`CARD_STRONG` for cards on a page |
| Ink | `#2c2c2c` | all text, all outlines; `INK_MUTED` = same at 60% for footnotes |
| Rule lines | `#aac4dd` | the notebook's ruled lines |
| Margin rule | `#d98f8f` | the red left margin |
| Gold (accent) | `#b08a3e` | picks, unlocks, focus, Duo A, Ultimates |
| Teal | `#2c8f7a` | Duo B |
| Green (good) | `#5c7a3f` | ready / positive state; `BAR_FILL` `#a3c06f` for progress bars |
| Red (danger) | `#c63d3d` | cooldown / down / negative state |
| Blue (info) | `#6fa8dc` | synergy banners and other neutral callouts |

Hero identity colours stay in `GameState.HERO_CATALOG`, and role colours in `Hero.ROLE_COLORS` — those are gameplay data, not UI chrome, and are tinted over paper rather than used as flat fills.

## Camera & Perspective

Battles use a 2D isometric projection — sprites arranged on an isometric grid, not a true 3D scene. Camera supports zoom in/out: zoomed out shows the scope of the whole battle, zoomed in shows detail as the action unfolds.

Note: `project.godot` has `3d/physics_engine="Jolt Physics"` configured from initial setup; that's now unused since the project is 2D. Flagged in BACKLOG.md as low-priority cleanup.

## Animation Rules

Characters animate in a crude but charming way. Visual inspiration: South Park, paper puppets, children's doodles.

Primarily use:
- Body bobbing
- Small rotations
- Simple scaling
- Limited keyframes

Goal is personality rather than realism.

## Battlefield Layout & Composition (Stage 1 — Dark Mage)

Reference: designer hand sketch, 2026-07-14 ("Stage 1 — Dark Mage"). Original retained by the Designer.

The zoomed-out battlefield reads as a single **organic shape** drawn on the notebook page — an irregular, hand-drawn outline, not a rigid rectangle or grid. Composition:

- **Hero Spawn Point** — top-left; a funnel-like entrance where the party (2 heroes shown) enters.
- **Villain Spawn / Villain** — bottom-right, opposite the heroes; the Dark Mage sits here, defended.
- **Minions** — summoned swarms spread as loose clusters across the mid/lower field (not single file).
- **Objectives** — capturable field features; Objective #1 drawn as a small structure/building (bottom-left).
- **Obstacles** — irregular blob shapes that block movement and shape pathing.
- **Scenery Props** — decorative-only shapes (no gameplay effect).
- **Poison Lake** — an elongated hazard-terrain feature near the villain.

**Status:** Implemented (2026-07-14) as `StageField` — organic field blob, funnel, obstacles, scenery, Poison Lake (visual), one objective. Multiple objectives and the hazard effect remain future work.

## In-Battle HUD (Stage 1 reference)

From the same sketch. No longer placeholder-styled — as of 2026-07-25 the HUD inherits the project-wide notebook theme like every other screen (the old scene-local `scenes/battle/hud_theme.tres` was folded into it and removed):

- **Villain HP bar** — boss health, shown prominently.
- **Per-hero panels** — each hero (Hero #1, Hero #2) shows an HP bar and an attack-cooldown indicator.
- **Objectives tracker** — objectives list with completion state / progress %, e.g. "Objective 1 — 30%", "Objective 2 — not complete".

## Lane Field Rules (2026-07-25)

- **No entity text in world space.** Heroes, villains, minions, spawn gates, obstacles, the lake and objectives carry no floating names or readouts — sprite art and shape identify them, and the HUD carries anything written. `Combatant.label_text` still exists as *data* (BattleHUD titles its villain panel from it), it is simply not drawn. The only in-world text left is the DEPLOY / TOP LANE / BOTTOM LANE zone markers, which label regions rather than things.
- **Colour is reserved for hazards.** Every field shape draws transparent with an ink outline so the page reads through — except the **Poison Lake**, which is purple (`lake_color` / `lake_ink_color`) because it costs HP on entry and must catch the eye. Don't spend colour elsewhere without a gameplay reason.
- **Obstacles are typed, and the type decides both art and collision:**
  - *Collidable, squat* (`rock1`, `rock2`, `sword`) — drawn centred on the collision circle.
  - *Collidable, tall* (`tree_bushy`, `alien_tree`, `alien_tree_thin`) — drawn standing on the ground at `TALL_OBSTACLE_HEIGHT_MULT` × radius, trunk at the bottom of the circle so units path around the trunk and the canopy overhangs.
  - *Not collidable* (`smudge`, `mushroom`) — these live in `scenery`, never `obstacles`. A smudge is a mark on the floor; walking through it is correct.
- **Art size is decoupled from collision.** Tune how big a prop *looks* via `OBSTACLE_ART_SCALE` (per kind), never by editing its radius — the radius is what the lane-walkability BFS was validated against, so changing it to fix a visual silently risks re-blocking a lane.
- **Collision is an OVAL derived from the art, not a circle (2026-07-25).** Everything used to collide as a circle spanning the sprite's *longest image edge*, transparent margin included — so a tall character's collision width was set by his height (Thundaar's circle was ~1.4× wider than he is) and a padded export paid for its empty pixels. `SpriteFootprint` (`scripts/sprite_footprint.gd`) now derives semi-axes from the opaque pixels instead. Rules:
  - **The oval is derived from the AUTHORED radius, never from the drawn size.** So it can only ever *reshape* a blocker, never grow one — `rx, ry ≤ radius` always. That invariant is what makes the change safe for every layout already validated, and any future footprint code must preserve it.
  - **One knob:** `SpriteFootprint.COVERAGE` (0.85) sets how much of the art the oval wraps. It scales every unit and obstacle at once, so it is a balance number, not a visual tweak.
  - **Ellipses reuse the circle math** via `SpriteFootprint.radius_toward` — the same directional-radius trick the Poison Lake already used. There is no ellipse solver, and new blockers should not add one.
  - **Tall props are NOT wrapped by their art.** A tree's canopy is meant to overhang (see `TALL_OBSTACLE_HEIGHT_MULT`), so tall kinds get a flat ground footprint at the trunk (`LaneField.TALL_FOOTPRINT`) instead of an oval covering the leaves.
  - **Scenery still never collides.** `scenery` is draw-only; walking through a smudge remains correct.
- **The villain lair is the wrecked spaceship, and it collides.** It is appended to `obstacles` at load (`LaneField.apply_lane_layout`) rather than authored per level, so art and collider can never disagree. The villain spawns `VILLAIN_LAIR_OFFSET` in FRONT of it (toward the incoming party), so blocking the ship never walls off the win condition — the approach to him stays open, you just can't walk through his ship.
- **`villain_pos` is the villain's LIVE position, not the lair.** `BattleManager` overwrites it every frame while he's alive. Anything needing the fixed structure must read `lair_pos`; drawing the wreck at `villain_pos` made it slide around the field following him.
- **Size obstacle placement against Thundaar's footprint.** He is the widest thing that must get down a lane, so he is the constraint for every layout. Since 2026-07-25 that footprint is the oval `Combatant._collision_radii()` returns — **41 × 50px** for Thundaar (`body_radius` 22, `sprite_scale` 1.8 × `SPRITE_SCALE_MULT` 1.7). It was a 67px circle before the oval change; the numbers below still quote 67 because the authored layouts were cleared against it, and 41 × 50 fits inside it, so they remain valid with slack rather than needing re-authoring.
- **No obstacle may touch a hard clamp boundary — this is the pathing-bug rule.** `Combatant` runs `clamp_out_of_obstacles`, then `Hero` runs `clamp_to_lane` *after* it (hero.gd). An obstacle whose blocked zone (`radius + 67`) overlaps either the lane divider (±`LANE_CLAMP_MARGIN`) or the field edge (±`lane_half_height − 67`) makes those two clamps shove a hero opposite ways every frame — it jitters in place instead of pathing around. **Connectivity testing cannot detect this**; it is a purely local clamp conflict.
  - Legal centre band per lane: top `[−(lane_half_height−67), −20]`, bottom `[20, lane_half_height−67]`.
  - An obstacle at `y` with radius `r` must satisfy `y − (r+67)` and `y + (r+67)` both strictly inside that band, with ≥10px slack, and ≥45px free corridor on at least one side.
  - With a 450 half-height this forces obstacles to sit near each lane's mid-line (y ≈ ±200) with `r ≤ ~55`. That is geometry, not preference — obstacles cannot hug the lane edges while Thundaar occupies 67px.
- **Verify before committing a layout**: containment for every obstacle *and* every spawn gate (gates block at radius 44), no obstacle within `deploy_obstacle_margin` of the deploy band, plus a grid BFS per lane inflated by the widest unit footprint. Current levels clear at 64–72px narrowest centre-corridor.
  - There is no committed BFS harness — it is written ad hoc when geometry changes. The oval pass (2026-07-25) used one that reads the `level_*_layout.tres` directly, derives each obstacle's oval the same way `LaneField._footprint_for` does, and floods from the deploy band to the lair per lane using `radius_toward` on both sides. All three levels cleared both lanes. Re-run something equivalent after any change to a radius, a footprint rule, or `COVERAGE`.

## Per-Stage Art (2026-07-25)

Each stage dresses itself from its own art set, all keyed off `RunState.current_level` with a fallback so an unfinished stage never renders blank:

- **Villain** — sprite on the villain script (`DarkMage1`, `Berserk_Villain`).
- **Swarm** — `Minion.SPRITE_VARIANTS_BY_LEVEL`; any minion without art of its own picks one of its stage's variants at random. Levels with no entry fall back to level 1's set.
- **Lair** — `LaneField.LAIR_KIND_BY_LEVEL` (`spaceship`, `berserk_lair`); falls back to the wreck.

Hazards come in two flavours, both edge-triggered (one hit per entry, never a continuous drain) and neither a blocker:

- **Poison Lake** — wide elliptical area you skirt around; purple wash + hatching.
- **Spike Pit** — small circular spot you step in; hits harder (`spike_damage` 14 vs `lake_damage` 6) and carries real art instead of a drawn blob.

Ability VFX use `BattleFX.draw_burst(canvas, tex, at, diameter, alpha)` — a plain draw helper, not a spawned node, since each caller already owns an expand/fade timer. **Always pass the ability's real radius** (including mod/boon additions) so the art keeps matching the damage area instead of drifting from it once upgrades widen the ability.

## The Wandering Monster (2026-07-25)

A faction-less beast that occasionally crashes stage 2 — `scenes/enemies/monster.gd`, rolled in `BattleManager._roll_monster`. Three properties define it:

- **No side.** Its `enemy_group` is `Combatant.TARGETABLE_GROUP`, the group every Combatant joins, so heroes, minions and the villain are all valid targets. It *also* joins `hostiles`, which is what lets heroes fight back. Minions don't retaliate — it's a hazard that mauls the swarm in passing, not a third army.
- **It leaves.** After `RAMPAGE_DURATION` (10s) it stops fighting, bolts for the nearest long edge and frees itself. The party survives it; they don't clear it.
- **It isn't farmable.** `xp_value` is 0 and it never targets pinned structures, so it can't chew through spawn gates and hand out free gold on a lucky roll.

Any future faction-agnostic attacker should reuse `TARGETABLE_GROUP` rather than adding a second scan loop to `_find_target` — that function is on the hot targeting path and scans exactly one group by design.

## Visual References

- Designer battlefield/HUD sketch "Stage 1 — Dark Mage" (2026-07-14) — see Battlefield Layout above.
