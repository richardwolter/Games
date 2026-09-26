# Crow Funding

A crew of crows loiters on a balcony above the city and flies trips down to steal
shiny loot (buttons up to pearl necklaces). Day/night cycle, food pantry, upgrades
shop, crow recruiting, end-of-day report. Code lives in `scripts/` (`game.gd` runs
the loop); everything on screen is still drawn with `_draw()` flat shapes.

## Art direction (decided 2026-09-26)

- **Black-and-white pen and ink**, after the three references in the project root
  (`refimage1.png` clean cartoon ink, `refimage2.jpg` loose urban sketch,
  `refimage3.jpg` dense feather hatching).
- **Style per asset type**: crows follow ref 1. Proposed, not yet confirmed: ref 2
  for the city, ref 3 for large crow-card portraits.
- **One spot colour**: everything is ink on paper except each crow's scarf, which
  stays tinted from `crow.gd`'s `scarf_color`. That is how crows are told apart.
- **Parts rig**: the crow sprite gets split into body / wing / scarf layers and
  `crow.gd` keeps animating flap and hop in code. No frame animation.
- **The scarf is its own layer**, drawn or generated separately and left white so
  code can tint it. The model ignores the scarf in the prompt when the LoRA is on.

## Generation pipeline

Shared ComfyUI generator (`_pipeline/tools/generate_art.ps1`, see its `SETUP.md`);
`tools/generate_art.ps1` here is the wrapper. The root CLAUDE.md calls that script
"archived" for Lake Cleanup only; it is live for this game.

- Model: SDXL base + **Ink Art XL 1.2** LoRA (`InkArtXL_1.2.safetensors`, openrail,
  EldritchAdam on Hugging Face) at strength 1.0. LineAniRedmond V2 is also
  installed and was tried; Ink Art won.
- `art/assets.json` records every step: `crow_inkart_*` / `crow_lineani_*` (first
  txt2img sweep), `crow_merge` (collage of three picks), `crow_edit` (hand edits),
  `crow_tail` (tail redraw). Each carries a `_note` saying what went in.
- The approved crow's lineage: body inkart_10 seed 4101 (chest widened ~14%) + beak
  inkart_07 seed 4102 (mirrored) + eye inkart_07 seed 4101, blended at denoise 0.45
  (seed 5203), then `tools/_crow_edit.py` (bigger eye ring, shoulder patch hatched)
  and `tools/_crow_tail.py` (tail as one wedge continuing the back line), blended
  at denoise 0.4. **Approved: `crow_tail` seed 5402, copied to `art/crows/crow.png`.**
- What worked: hand-edit the picture, then low-denoise img2img (0.3–0.45) to blend
  the edits back into the ink. Above ~0.5 the model redraws parts on its own.
- Transparent PNG gotcha: white hatching inside the ink is alpha 0 in LayerDiffuse
  output. Composite on white before pasting or editing, and rebuild alpha by
  flood-filling the exterior, or the white holes paste as nothing.

## In-game rig

- `tools/split_crow.py` cuts `art/crows/crow.png` into `crow_body.png` and
  `crow_wing.png` (wing polygon + shoulder pivot authored in the script; the hole
  in the body is filled with solid ink). `tools/draw_scarf.py` draws
  `crow_scarf.png`, white with ink outline. Both write `art/crows/crow_parts.json`.
- `crow.gd` `_draw()` draws the three textures; the constants at the top mirror
  `crow_parts.json` (update both if the split changes). Origin is at the feet,
  `FEET_Y` below the node; `SPRITE_HEIGHT` (46 px) sets on-screen size. The wing
  rotates up to ~0.9 rad about the shoulder while flying; the scarf is tinted with
  `scarf_color` via `draw_texture`'s modulate.
- The parts import with mipmaps on and the node uses
  `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`: the sprite is drawn at ~5% of source size
  and shimmers without them.
- The scarf is a hand-coded placeholder shape, stiffer than the ink drawing.

## Next

1. Judge the crow in-game (size, flap, scarf) and tune `SPRITE_HEIGHT` / flap angle.
2. Scarf redraw in the ink style (hand edit + low-denoise img2img, like the tail).
3. City backdrop in ref-2 style.
