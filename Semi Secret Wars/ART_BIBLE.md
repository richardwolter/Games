# Semi-Secret Wars — Art Bible

Defines the visual language. Initially small; expands as production grows.

## Art Direction

Minimalist, hand-drawn, notebook aesthetic, child's comic book. Simple colors, thick outlines, imperfect shapes. The game takes place inside the pages of a child's notebook.

## Character Proportions

TBD.

## UI Style

Interface matches the notebook presentation. Menus remain simple and readable. Placeholder UI during prototype development.

## Color Palette

TBD.

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

From the same sketch (placeholder styling for now, notebook aesthetic):

- **Villain HP bar** — boss health, shown prominently.
- **Per-hero panels** — each hero (Hero #1, Hero #2) shows an HP bar and an attack-cooldown indicator.
- **Objectives tracker** — objectives list with completion state / progress %, e.g. "Objective 1 — 30%", "Objective 2 — not complete".

## Visual References

- Designer battlefield/HUD sketch "Stage 1 — Dark Mage" (2026-07-14) — see Battlefield Layout above.
