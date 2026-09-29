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
- **Every environment is seen FROM a high perch** (Richard, 2026-09-29): the top of a
  balcony, roof or other tall structure, looking out and down over the city, like the
  balcony scene. The perch (railing, parapet, roof edge, ledge) is in the foreground where
  the crows stand; the city is below and beyond. No ground-level views, no clouds.

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

Draw order: Backdrop (paper gradient) - Sky (sun, moon, stars) - City - Balcony -
Crows. The City is opaque with its sky cut away, so the sun and moon set behind the
buildings instead of showing through them (they did while the city was a multiply
layer).

- **City** (`city.gd`): `skyline` seed 8101, engraving-style ink panorama.
  `tools/skyline_art.py <preview>` finds the horizon (first dense row of rooftops),
  climbs each column up through the towers to cut the sky out, and writes
  `art/scene/city.png` (ink faded ~20% for distance) plus `city_lights.png`: small
  upright dark blobs below the horizon, a random third of them lit, with a soft
  halo. The city takes the lower-sky paper tone, darkens at night, and the lights
  fade in additively from sunset (`smoothstep(0.62, 0.95, phase)`).
  `TEX_HORIZON` must match the horizon the script prints.
- **Sky** (`sky.gd`): paper-tone gradient; engraved sun (`sun` seed 8201, rays
  left see-through, disc solid, slowly turning, warmed by time of day) rising low
  over the roofs and setting behind the city around phase 0.8; engraved crescent
  moon (`moon` seed 8303) rising after sunset; pen-cross stars.
- **Balcony** (`balcony.gd`): carved stone balustrade (coping ledge, vase
  balusters, piers). `tools/balcony_template.py` draws the geometry already as line
  art with pen hatching, img2img inks it (`balcony` d0.5 seed 7601), and
  `tools/scene_art.py` cuts the gaps between balusters from the template mask. The
  wooden plank railing it replaces looked flat and awful (Richard, 2026-09-26);
  grey-filled templates made the model paint grey, hatched ones made it ink.
- **Trips go into the city**: `crow.gd` scales the crow down to `CITY_DEPTH` on the
  way out and fades it among the rooftops (hidden while out working); the way back
  reverses it. `game.gd` `_trip_target` picks spots down among the roofs.
- **HUD**: paper panels with ink borders and ink text (`hud.gd` applies one ink
  Theme to every control it builds). Coins/Day and compact roster cards top-left,
  loot log top-right, Pantry and Upgrades in the bottom corners, Dispatch on the
  deck under the crows. The title label is hidden.
- `tools/shot.tscn -- phase=0.75` holds the sky at a time of day for screenshots.

## Environments (level 2: Downtown, added 2026-09-26)

Two cities, picked freely and **visual only** (loot, economy and save are shared).
`scripts/environments.gd` lists them (`classic` Old Town, `modern` Downtown); the
`Prefs` autoload (was `Settings`) stores the choice in `user://settings.cfg` and
emits `environment_changed`, and City, Sky and Balcony swap live. Picked on the
Settings board's City row; F2 (rebindable, "Next city") still cycles it.

- **City**: `skyline_modern` seed 8912, cut by `tools/skyline_art.py <preview>
  --modern`. It writes `city_modern.png` and `city_modern_lights.json` (window
  rects, neon spots, blinker tips, street lines, horizon); `city.gd` reads the
  horizon from the JSON and animates the lights live.
- **Night**: window grids switching on and off, flickering neon signs, red aviation
  blinkers from dusk, traffic streaks and a street glow. Neon breaks the one-colour
  rule on purpose; it stays saturated while the scarves are pastel.
- **Balcony**: glass panels under a steel handrail. `tools/balcony_modern_template.py`
  writes the template and mask, img2img `balcony_modern` d0.4 seed 9101, then
  `tools/scene_art_modern.py` composites it (glass is a faint tint, ink is opaque).
- **Sun and moon**: drawn in code (`sky.gd` `_draw_flat_sun` / `_draw_flat_moon`) as
  a flat disc and a sharp crescent with ink rings. Only a few stars (light pollution).
- `tools/shot.tscn -- env=modern` shoots the chosen city without saving it.
  `tools/_py.sh` runs Python with PIL/cv2 (ComfyUI's interpreter); plain `python`
  on this machine has neither.

## Crow care stations (2026-09-29, unattended pass; numbers are first guesses)

Every crow has **stamina** (0-100) and **injury days**. Each morning the player drags
crows (mouse, `scripts/stations.gd`) onto one of four stations on the rail: **Trip**
(the middle of the rail, default), **Training post** (left), **Nest** and **First-aid
box** (right). Rules are pure functions in `scripts/care.gd`; `game.gd`
`assign_station` / `_care_day` / `_injure` apply them.

- A trip costs `TRIP_STAMINA_COST`; under `LOW_STAMINA` loot (coins and object
  chance) falls to `LOOT_MULT_SPENT` at zero and the per-trip injury chance climbs
  from `INJURY_CHANCE_RESTED` to `INJURY_CHANCE_SPENT`.
- An injury lasts 1-2 days, ends the crow's remaining trips that day, moves it to
  the First-aid box for the night, and it cannot be put on Trip until healed. Only
  the First-aid box heals (one day per night).
- Kept home earns nothing. Nest gives `NEST_RESTORE`, Training and First aid
  `HOME_RESTORE`; Training grants `TRAINING_XP` (times the Training upgrade).
- **Only the Trip crew eats and flies**; a day with nobody on Trip just passes.
  Assignments persist day to day. Reassigning is mornings only.
- Stations are flat ink placeholders drawn in code; a refused drop is struck
  through (no red: one spot colour). Labels sit above the props because the
  Pantry and Upgrades panels cover the deck under the rail.
- Crow cards show a stamina bar and a care line; the report shows station and
  stamina from > to, and HURT.
- **No save exists**, so care state is in memory like everything else.
- Test: `tools/test_care.tscn` (headless, writes `tools/last_care_test.log`, exits 1
  on failure).

## UI: ink menus (2026-09-29, unattended pass; structure after Lake Cleanup's menus, not its wood)

- **One look** (`scripts/ink.gd`): a Theme built in code, ink on paper with one spot
  colour (`SPOT`, the default scarf's ochre, a first guess) for the lit door, slider
  fill, focus ring and hover tint. Buttons stand on a hard ink shadow; hover tints
  the paper and thickens the border; pressed sinks the face onto the shadow. The
  accented door is the `InkAccent` type variation. `Ink.strip` clears old per-node
  overrides so the theme shows; the HUD, crow cards, pantry, upgrades/recruit and
  the report all wear it now (report gained a veil, Dispatch and Start Day are lit).
- **Text** (`scripts/text.gd`): every player-facing string is a const there, read as
  `Text.KEY` (loot, foods, upgrades, tiers, statuses, log lines, stations, cities,
  menus). Crow names stay in game.gd (names, not strings).
- **Prefs** autoload (`scripts/prefs.gd`, replaces `settings.gd`): four buses built
  at boot (Master/Music/SFX/Ambience, power-law sliders `SLIDER_LAW` 33.2, mute
  toggles), window mode windowed/borderless/exclusive, windowed resolution (dead
  in fullscreen), vsync, frame cap, city, binds. Headless runs never write the file.
  An old `fullscreen=true` reads as borderless. The game has no audio yet, so the
  buses are ready and silent.
- **Binds** (`scripts/binds.gd`): the InputMap is built from its table at boot
  (`dispatch` Space, `toggle_fullscreen` F1, `next_city` F2); project.godot holds no
  input events now. Physical keys, OS labels. Rebinding swaps with whatever held
  the key; only overrides are saved. Escape is never bindable (pause/cancel).
  Space is new: it presses Dispatch / Next Day.
- **Menu** (`scripts/ui/menu.gd`, a CanvasLayer the game adds at `_ready`): boot
  menu over the live balcony (New game lit, no Continue: there is no save to
  continue), Escape in play opens it paused (Continue lit, New game asks, Quit asks).
  Boards stack over it (`scripts/ui/board.gd`: settings, binds, credits, confirm);
  Escape closes the top one. The HUD hides while the doors are up. Only the game's
  own scene (parent is root) shows the boot menu; `game.gd force_front` for probes.
  Exclusive fullscreen asks "Keep this display?" and reverts after 10 s.
- **Known**: pausing stops tweens but `create_timer` timers in game.gd run through a
  pause (Godot's default), so a crow mid-day can get a step out of phase with its
  flight. Credits are placeholder lines for Richard to settle.
- Probe: `tools/shot.tscn -- menu=boot|pause|settings|binds|confirm|credits|report`.

## Next

1. Judge the crows in-game: size, flap speed, idle timing, the wing-edge flip.
2. Crow-card portraits in the ref-3 dense-hatching style.
