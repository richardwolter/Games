# Asset Replacement Checklist

Working list for the visual overhaul pass. Scope is **Stages 1–2**; Stage 3 is deferred.

Companion pieces:
- [`assets/ASSET_INVENTORY.json`](assets/ASSET_INVENTORY.json) — what exists, its status, where it's wired in.
- `scenes/tools/sprite_gallery.tscn` — run this scene to see every asset without booting a battle.

## How to use the gallery

Open `scenes/tools/sprite_gallery.tscn` in Godot and press **Run Current Scene** (F6).

- Tabs group assets by category; the count per tab is in the tab name.
- The **Height** slider redraws every sprite at a chosen pixel height — sizes are design-canvas px, so the player sees them at 0.67×.
- **Thundaar 67px reference** draws his collision circle behind each sprite. He is the widest thing that must fit down a lane, so he is the scale everything else is judged against.
- **Art bounds vs collision** draws the sprite's true opaque bounds (dashed green) against the circle the game actually collides with (solid red). Each card also captions its padding, in red past 1.25×.
- **Filter** narrows by filename.
- Characters and props stand on the ground line (matching `LaneField._draw_prop_sprite`); rocks, rings and projectiles draw centred (matching `_draw_obstacle_sprite`). Everything previews at `Combatant.SPRITE_ALPHA`, the same paper-cutout alpha the field uses.

The folder scan is authoritative. A PNG dropped into `assets/sprites/` appears immediately, tagged `? unlisted` until it gets an inventory entry — the gallery can't silently disagree with the disk.

## Status counts (verified 2026-07-25)

44 PNGs on disk, all 44 catalogued. Every claim below was checked with a reference grep, not assumed.

| Status | Count | Meaning |
| --- | --- | --- |
| ✓ complete | 35 | wired in and rendering |
| ⊘ stale/unused | 6 | zero references; safe to delete |
| ⚠ source art | 1 | not loaded at runtime, but deliberately kept |
| ? unknown | 2 | zero references, intent unclear — needs a Designer call |

## Priority 1 — Cleanup

Two corrections came out of the audit: `Verdant_Path.png` and `Portal-Spawn.png` were both initially reported as orphans and are in fact **in active use**. They are not on this list.

- [ ] **Delete confirmed-stale duplicates** (all verified at zero references)
  - `assets/sprites/Thundaar.png` — superseded by `Thundaar1.png`; only a historical comment at `hero.gd:412` names it
  - `assets/sprites/DarkMage.png` — superseded by `DarkMage1.png`
  - `assets/Dark_Mage_1.png`, `assets/Destroyed_Spaceship.png`, `assets/Minion_Dark_Mage.png`, `assets/Portal_Spawn.png` — underscore-named copies of files that live in `assets/sprites/`
  - Delete each `.png` together with its `.png.import` sidecar, then re-run the gallery: the tab counts should drop and nothing should turn blank.

- [ ] **Decide two unknowns** (zero references, but intent unclear — a Designer call, not a cleanup)
  - `assets/sprites/Lightning-Bolt.png` — unused ability art? Wire it up or drop it.
  - `assets/Sprites.png` — looks like a contact sheet or source atlas rather than a shipped asset. If it is a working file it should live outside `assets/`.

- [ ] **Keep, do not delete**
  - `assets/sprites/Arrow.png` — the unrotated original. `hero.gd:502` documents it as the source for the pre-rotated `Arrow_Right.png` that actually ships.

## Finding — collision circles include transparent padding

`Combatant._collision_radius()` returns `body_radius * sprite_scale`, and `_draw` sizes art so the **longest image edge** spans that diameter. The collision circle therefore circumscribes the whole PNG square, transparent margin included — so empty pixels cost real space on the field.

Measured across all 44 sprites (`Image.get_used_rect`, cross-checked against a per-pixel scan):

| Sprite | Image | Opaque art | Collision vs art |
| --- | --- | --- | --- |
| `Berserk_Minion_1.png` | 1307×1160 | 456×534 | **2.4×** |
| `Boulder.png` | 1307×1160 | 679×643 | **1.9×** |
| `Berserk_Lair.png` | 1307×1160 | 815×693 | **1.6×** |
| `Searing_Bind.png` | 283×378 | 195×280 | 1.3× |
| everything else | | | ≤1.2× |

The three worst share one 1307×1160 canvas — exported on a common oversized sheet. Note `minion.gd` gives `Berserk_Minion_1` a `sprite_scale` of 3.6, which looks like compensation for that padding; it scales the art up to look right and inflates the collision radius by the same factor.

- [ ] **Decide the fix** — Designer call, nothing changed yet. Options, in rising order of risk:
  - *Crop the source PNGs* so art fills its canvas, then lower `sprite_scale` to hold the on-screen size. Collision shrinks to match the art, and no pathing geometry is touched. Only 3–4 sprites move meaningfully.
  - *Derive collision from alpha in code* — self-correcting for future assets, but shifts effective radii game-wide at once (steering, obstacle clamping, crowding), so it needs a balance sweep after.

  Shrinking a unit's radius loosens lane corridors rather than blocking them, so it does not threaten the walkability BFS — but it does change crowding and swarm feel, which is a playtest question.

## Priority 2 — Review against current art direction

Judge these in the gallery with the Thundaar reference on, so relative scale is visible.

- [ ] **Hero line-up** — Thundaar / Artemis / Warden / Beacon read as one set: same papercut treatment, same apparent height, same line weight.
- [ ] **Stage 1 vs Stage 2 swarms** — the four minion variants should be tellable apart at a glance. Note that Stage 2 minions draw at roughly double Stage 1's scale.
- [ ] **Menu and UI art** — `Logo_Menu.png`, `Button_StartRun.png`, `Buttons_New_Continue.png` against the notebook palette in `ART_BIBLE.md`.
- [ ] **Obstacle set** — the three squat kinds and three tall kinds should be distinguishable in silhouette.

## Priority 3 — Deferred

- [ ] Obstacle art scale vs collision radius. Tune via `OBSTACLE_ART_SCALE`, **never** by editing a radius — the lane-walkability BFS was validated against those radii (`ART_BIBLE.md`).
- [ ] Hazard VFX (Poison Lake, Spike Pit) checked in motion; the gallery shows stills only.
- [ ] **Stage 3** — MechRobot villain sprite, Stage 3 lair, and Stage 3 minion variants. Out of scope this pass.

## Replacing an asset

1. Drop the PNG into `assets/sprites/`.
2. Run the gallery — it appears under `? unlisted`. Check size and silhouette against the Thundaar reference.
3. Add or update its entry in `assets/ASSET_INVENTORY.json` (`filename`, `category`, `status`, `used_by`, `notes`).
4. Wire it up where it belongs: `hero.gd` `HERO_SPRITES`, `minion.gd` `SPRITE_VARIANTS_BY_LEVEL`, a villain script's `sprite_texture`, or a `battlefield.tscn` export.
5. Re-run the gallery to confirm the status tag flipped to ✓.
6. Play the level when the change is one you need to *feel* rather than see.
