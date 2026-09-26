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

Two rigs in `crow.gd`, both drawn from textures in `_draw()`; the constants at the
top mirror `art/crows/crow_parts.json` (update both if a split changes). All art is
drawn at `SPRITE_SCALE` (46 px tall perched) with mipmaps on, since it shows at ~5%
of source size.

- **Perched** (`tools/split_crow.py` cuts `crow.png`): body, folded wing, head,
  tail, scarf. Idle: breathing, the head snaps to a new look and holds (how bird
  heads move), occasional tail flick, and hops with crouch - air - landing squash
  and the wings lifting off the back. The body keeps ink under the head and tail so
  small turns never open a hole; the scarf hides the neck seam.
- **Flying**: `fly_body.png` (approved crow rotated level, legs cut, head re-set;
  `tools/flight_body.py` + img2img, `crow_fly_body` d0.5 seed 7300) and a
  two-piece spread wing cut from `crow_fly` seed 6101 (`tools/split_flight.py`).
  Crows row with steady shallow beats and do not soar: ~3.5 beats/s, stroke from
  above the back to well below the belly. Seen from the side the wing shows as
  length x sin(stroke angle); the hand trails the arm and folds on the upstroke;
  the body lifts on each downstroke; far wing drawn darker behind the body; landing
  flares (pitch up, wings held high). `FLY_BODY_STRETCH` slims the chunky
  generated body (Richard: flying crows looked fat), and `WING_CHORD_FLIP` picks
  which wing edge faces forward (Richard: feathers were on the wrong edge; -1 now).
- **Scarf**: ink scarf cut from img2img of the crow wearing the placeholder shape
  (`tools/ink_scarf.py`, `crow_scarf` d0.4 seed 7103). White, tinted per crow with
  `scarf_color`. In flight it streams back from the throat.
- `tools/rig_preview.tscn` renders the flap at 10x, one phase per frame, to
  `tools/_rig_strip.png`; `tools/shot.tscn` screenshots the game (`-- fly=1` sends
  the crew out first). Both need a windowed run.

## Scene

- **City** (`city.gd`, `art/scene/city.png`): `city_bg` seed 6200, loose ink
  sketch in the ref-2 style, ink faded to 60% for distance. Drawn with a multiply
  blend over the sky backdrop, so its paper takes the time-of-day tint.
- **Sky** (`sky.gd`): paper tones instead of sky colours, sun and moon as pen
  circles, stars as pen crosses.
- **Balcony** (`balcony.gd`, `art/scene/balcony.png`): front-on railing from a
  drawn template (`tools/balcony_template.py`) inked by img2img (`balcony` d0.5 seed
  7500); `tools/scene_art.py` turns its greys into pen hatching and cuts the gaps
  between balusters from the template mask. Plain txt2img railings came out
  coloured and in perspective.
- **HUD**: paper panels with ink borders and ink text (`hud.gd` applies one ink
  Theme to every control it builds). Coins/Day and compact roster cards top-left,
  loot log top-right, Pantry and Upgrades in the bottom corners, Dispatch on the
  deck under the crows. The title label is hidden.

## Next

1. Judge the crows in-game: size, flap speed, idle timing, the wing-edge flip.
2. City windows at night (the old flat city had glowing windows; the ink one has none).
3. Crow-card portraits in the ref-3 dense-hatching style.
