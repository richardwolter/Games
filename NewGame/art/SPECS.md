# Art specs

Derived from the code, not from taste. If a constant below changes in code, the
spec changes with it.

## Isometric projection

`scenes/iso/iso_projector.gd` — 2:1 isometric, `SCALE_X = 0.5`, `SCALE_Y = 0.25`.
A world-axis-aligned square projects to a diamond **exactly twice as wide as tall**.
The camera never rotates. Track camera zoom is 1.4.

## Ground tiles (rock floor, water, road)

`scenes/iso/iso_ground.gd` tiles a single texture along the corridor.

| | |
|---|---|
| World coverage | 220 x 220 units (`corridor_half_width` 110, doubled) |
| Rendered size | 220 x 110 screen px (x1.4 zoom on screen ~ 308 x 154) |
| Author size | **440 x 220** (2x). Must be exactly 2:1 or the sprite scales non-uniformly |
| Shape | Full-bleed diamond, corners at the **midpoints** of the image edges |
| Alpha | The 4 corner triangles are fully transparent |
| Edges | Opaque right up to the diamond boundary. **No feather** — adjacent tiles butt edge-to-edge and a semi-transparent band on both sides double-blends into a seam |

**Seam rule.** Tiles step along world X only, so consecutive tiles land offset by
exactly `(+W/2, +H/2)` in screen space. The **upper-left edge joins the
lower-right edge** of the next copy — that one diagonal axis is the only one that
must be seamless. The upper-right and lower-left edges are the corridor borders
and are never joined (that is where `road_tile.png` puts its barriers).

To check: duplicate the layer, offset by `(+220, +110)`, confirm the joint reads
continuously.

> `road_tile.png` is currently 459x247, which is not 2:1 — it gets squashed
> unevenly. New tiles at a true 2:1 will look cleaner than what ships today.

> **Caveat:** `iso_ground.gd` takes exactly one `tile_texture` for the whole
> corridor. Rock floor and water cannot coexist without a code change — either a
> per-segment texture list or a second ground layer.

## Background

No background node exists yet; outside the corridor is the default clear colour.
Intended as a `ParallaxBackground` (screen space, unaffected by camera zoom).

| | |
|---|---|
| Author size | 1024 x 1024, or 2048 x 1024 for a wider sky |
| Tiling | Seamless in **both** axes — the camera drifts diagonally, travelling ~1200 px right and ~600 px down across a 2400-unit track |
| Format | Opaque, no alpha |
| Viewport | 1152 x 648 (Godot default; not overridden in `project.godot`) |

`ParallaxLayer` mirroring relaxes this to only needing the mirror seam to work.

## Sprite offsets

Props bottom-anchor via `offset = Vector2(0, -height/2)`. **Changing a sprite's
pixel height means updating its offset** in the corresponding `.tscn`, or the
prop floats / sinks.

## Pipeline

- `art_source/` — raw originals, never edited in place
- `art/generated/_raw/` — pre-cleanup backups, written once, always re-read from
- `art/generated/` — game-ready output
- `clean_assets.ps1` — background/shadow removal + edge rebuild for hand-fed art
- `alpha_from_pair.ps1` — exact alpha recovery from a white/black render pair,
  for image models that cannot emit an alpha channel
- `assets.json` — prompt + seed manifest for locally generated assets

**Do not run generated ground tiles through `clean_assets.ps1`.** It trims to
content bounds and flood-fills light desaturated regions, which would eat pale
rock and most water, and the trim would destroy the full-bleed diamond.
