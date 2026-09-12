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
- **The ring is the catch, by decision** (2026-09-11, `net.gd` `_touches`/`_reach`): a piece,
  bird or charm is caught when any of its *drawing* (an ellipse at its drawn position and
  size) touches the mouth — not when its tile is inside a tile radius. The aiming marker's
  green/red verdict uses the same test at the open mouth. `mouth_extent()` is the one number
  for drawing, sweep and marker, including the `HOME_SIZE` shrink on the haul. The sweep also
  runs on the landing frame. Tiles only narrow the search (`LakeGrid.footprint_reach`).
  `net_width.tres` was left as it was, to be retuned after playtesting the honest ring.
- **The hauled net bends, by decision** (2026-09-11, `net.gd` `_draw_warped`): the landed
  frame is drawn as a `WARP_COLS` x `WARP_ROWS` sheet of quads laid out as one triangle
  array, so the rim tips towards the rope (`LEAN_TIP`), the body trails behind the pull
  (`LEAN_TRAIL`) and the belly sags and spreads with the load (`BULGE_DEEP`/`BULGE_WIDE`).
  `_lean` and `_pull` are eased, and fall back out when the haul ends. **The `drag` sheet
  stays retired** — this bends the net that landed, it does not replace it. A net in flight,
  and an empty one lying still, are drawn flat as before.
- **The catch fills the bag** (`_draw_catch`, `_shown_count`): the drawn count is as many of
  `catch` as cover `CATCH_FILL` of the mouth's area at the packed scale — so a wider net and
  a fuller hold both show more — capped at what is really aboard. No filler pieces: what is
  drawn was caught. Every piece is scaled to `CATCH_FIT` of the mouth and scattered over the
  mouth **less its own half-size**, so nothing cuts through the rim; the pile rides `_belly`,
  back against the pull and down under the load. The old out-of-the-mouth stacking
  (`CATCH_RISE`) is gone.
- **The haul shoves what it will not take** (`_shove_aside`): pieces over the net's strength,
  and everything once the hold is full, are pushed clear of the rim through
  `LakeGrid.shove_to` — the hulls' own call — outwards from the middle of the mouth, with a
  piece dead centre parted to a side picked off its tile. Nothing catchable is ever shoved.
  Haul only: the throw flies over the water.
- **The rope ties to the crown, not the rim** (`_line_end`, `_bridle_points`, `_crown_frame`,
  2026-09-11): a cast net is hauled from its gathered apex through a bridle, so the hand line
  ends at a horn over the crown (lifted `HORN_LIFT`, pulled `HORN_LEAN` towards the rod with
  the lean) and `BRIDLES` short lines fan from it onto the crown ring, flattened by
  `BRIDLE_SQUASH`. **Both numbers are fractions of the crown's own width**, not the frame's,
  so the bridle stays in proportion to the ring it is tied to at any drawn size. Every point
  goes through `_warp_point`, so horn and bridle bend with the mesh. Far-side bridles draw at
  `BRIDLE_FAR`. `test_lake` guards that no little rope reaches the rim.
- **The crown is measured, not authored** (`tools/slice_net.gd` `_crown`): the ink centroid
  and width across the top `CROWN_BAND` of each frame, baked into `net_frames.json` as
  `crown_x`/`crown_y`/`crown_w` and read back as fractions of the frame's box. It lands on the
  apex dome of the landed net and on the top of the bundle in a throw. **Re-run the slicer if
  the net sheets change**; `CROWN_FALLBACK` keeps an older cut running.
- **Retired anchors, in order**: the rope ending at the top of the frame's box (a point in
  the air above a net lying flat); that plus a guessed lean offset (came apart from the mesh
  the moment the net bent); the rope tied to one point on the near rim (on the net, but read
  as a line to a hoop); bridles fanning from the horn all the way to the rim (little ropes
  drawn straight across the mesh they are supposed to be gathering).
- **The rope is a verlet chain, drawn only** (`_drive_rope`, `_rope_tick`): `ROPE_POINTS`
  pinned at `rod_tip()` and the rim anchor, fixed `ROPE_STEP`s banked across frames,
  `ROPE_PASSES` of tightening, per-step `ROPE_LEAP` clamp, re-seeded straight on every
  cast and on any `ROPE_JUMP`. Rest length runs `ROPE_SLACK` over the rod-to-net gap while
  the net flies or sits and eases to `ROPE_TAUT` under the haul, so reeling visibly takes
  line up. **This is not the physics the project banned**: no bodies, no collision, nothing
  gameplay reads — it is how the string is drawn. The old sine arc and its `sag` are gone.

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
- **Colours**: the water body outputs only palette swatches — three five-step ramps
  (`water_clean_*`, `water_murky_*`, `water_dirty_*`) and the grime. Depth, bands and
  sparkle sum to a ramp position rounded to the nearest step: solid areas, hard edges.
  Clean/murky/dirty is picked by two cutoffs (`murky_at`, `dirty_at`) on local filth, after
  a small drifting blob noise (`murk_blotch`, `murk_wobble` 0.1) and a shade stagger
  (`state_spread` 0.1) so the contours breathe instead of sitting still.
  The water is opaque. Foam keeps its own shapes and soft alpha.
- **No dither, by decision**: a per-pixel Bayer dither was tried and rejected — grainy open
  water, lone dirty pixels in cleaned bays, shimmer under camera motion.
- **Zoom and camera**: zoom only lands on levels where one art pixel (`Lake.ART_PIXEL` = 2
  world px) is a whole number of real screen pixels, through the window stretch
  (`_zoom_level`, `_near_level`, `_far_level`). The drawn camera is snapped to whole screen
  pixels via `Camera2D.offset` (`_snap_camera`); the logical position stays smooth. The cast
  lean-in zoom (`CAST_PUSH`) was removed for this — no level is close enough.
  Moving objects glide between art pixels, **by decision** (2026-09-11): an F4 trial drew the
  angler, dog, boat and the rubbish's swell on the art-pixel grid, and Richard judged the game
  much better with it off (commit `91cc581`, reverted). The low-res SubViewport would give the
  same stepped motion, so it is not pursued either. Don't re-raise.
- **The ground is drawn per pixel, not per tile** (`shaders/ground.gdshader`, issue #17,
  2026-09-11): each `Ground` layer is one `Polygon2D` with the shader on it; every pixel works
  out its tile, whether it is lawn or beach (`coverage` — `out_of_water` less `beach_width`
  less value-noise `wander`), which lawn patch it is in (per-pixel Voronoi, `patch_size`),
  and so which texel of the pack's top faces to show off a 7-cell strip (sand, yard pool,
  rough pool). The lawn/beach line and the patch borders are therefore curves stepped at art
  pixels, the same way `water.gdshader` cuts the island coast. The front tiles' turf
  overhang (the pack draws its grass leaning back over the rear diamond edges, rows 0-2
  above `GRASS_FACE_ROW` 3) is composited per pixel so the lawn stays bushy and its far
  edge ragged; the near edge gets a 1 art-px `lip` and per-pixel `fringe` blades hanging
  over the sand (mode 1 straight down, mode 2 along the curve's normal). The island: same
  shader, no wander, no fringe, lip only. Cube sides are not drawn at all (`GRASS_LIFT`,
  skirts, `_face_top` gone). **`Ground.coverage_at`/`kind_at` mirror the shader** — the props
  (trees, rocks, leaves, and the sparse beach tufts within `TUFT_REACH` of the line at
  sub-tile offsets) are laid by them; the two must move together.
  **Retired, by decision**: the mixed `BLEND` band, `GRASS_BORDER` mounds, `SAND_TUFTED`
  cubes, the generated fringe strips (`assets/fringe`, `generate_fringe.py`), the per-tile
  batched mesh, and the pack's grass/sand join tiles (tried 2026-09-11, a corner set that
  reads as a staircase of cuts). A line drawn by choosing whole tiles is a staircase
  whatever the tiles; don't go back to tile picking for the edge.
  **Tuning**: F4 in a debug build opens `GroundTuner` (sliders for every ground uniform, plus
  the island's coast wave, values written to `user://ground_tune.log`); bake picks into
  `Ground`'s constants, or `Lake`'s for the coast rows. The
  beach cannot go under `beach_width - wander_amp` = 3.5 tiles (`Dog.BEACH_WALK`,
  `Iso.BEACH_LITTER` count on sand there).
- **Sprite scale**: rubbish, finds (`SPRITE_SCALE`) and pigeons (`Flock.SCALE`) draw at 2.0.
  A piece under `SPRITE_SMALLEST` scales up by whole steps. The ~15 big finds over 34 px art
  keep an exact fractional cap to `SPRITE_LARGEST` (68) — rounding their scales inverted the
  size order (44 px mirror -> 88, 55 px sofa -> 55), which `test_lake` guards. Carried pieces
  (dog/boat/net) stay fractional.
- **Motion**: pattern animation runs on `stepped_time(TIME, pixel_fps)` (default 8 fps). The
  **swell** the foam collars ride keeps real `TIME` because the rubbish rides it smoothly.
- **No glints and no open-water foam, by decision** (Sep 2026): the glints (band crests lifted
  to the light step, gathered under the sun by `sun_lean`) drew pale strips across clean
  water, and the loose foam streaks riding the swell drew white ones. Both removed, uniforms
  and all. Bands stay; shore foam stays; the finished-lake sparkle stays.
- **The filth map is a distance from the rubbish** (`Lake._build_filth_map`, `_chamfer`):
  a tile with a piece on it is foul, the stain falls off to clean at `FILTH_BLUR` (3) tiles,
  bent by `FILTH_FALL`. Presence only — no pollution values, no capacity, no averaging. The
  rule, by decision: **water touching objects looks grimy, water with no objects looks
  clean**, and the rubbish-free band round the island is a plain clean ring. Rejected on the
  way here: a pollution-over-capacity box blur (lone pieces floated on blue, green spread
  over empty water), a weighted blur, and a fill that made the island's band foul.
- **Blotch noise and stagger, low** (`murk_wobble` 0.1, `state_spread` 0.1): removed once
  because at 0.28 the blobs read as water leaking from under the island, then put back at
  under half that (2026-09-11) because with the cutoffs read straight off the map the
  contours round the island sat dead still while the bands rippled across them. Keep the
  wobble small; the map decides where the junk is, the noise only makes the edge breathe.
- Retune colours in `extract_palette.gd`'s `WATER_RAMPS` (and `palette.tres`), not in the
  shaders — their defaults only mirror the palette.
- Not yet converted to pixel art (pending, still live): `splash_foam`, `splash_specks`
  (`water_splash.gd`), `glint.gdshader` (`LakeGrid.GlintLayer`).
- **The pollution meter is art, not the water shader** (`hud_skin.gd` `_build_meter`,
  `shaders/meter_water.gdshader`, sheets in `assets/ui/meter/` from
  `art_source/UI/Lake meter/Lake_Meter` PSD): four aligned 290x94 sheets — murky water,
  clean water, wooden frame, garbage circle over it — as child TextureRects in the bottom
  left corner (hint line above it), at `METER_SCALE` (1.95) times the art on a 1080-line
  window, in proportion elsewhere. Settled by eye (3x, 1.5x, then 1.3x that), not snapped
  to a pixel step; nearest-filtered. The shader slides the filth-to-clean seam (feather
  `METER_FEATHER`, narrowed at the ends) and rocks both sheets a pixel or two
  (sine, not scroll: the sheets are not tileable). Both sheets have soft, part-transparent
  ends, so every water sample is clamped to `METER_OPAQUE` (where both are fully opaque)
  and the band is forced opaque; the band runs `leak` under the circle. Check gaps by
  filming a whole drift cycle (~18 s) over magenta and scanning every frame — a short film
  misses the bad phase. Garbage circle static; `%` figure only,
  right-aligned on the clean end; no `POLLUTION` label. `Style.meter_water`/`water` and
  the `METER_*` colours are gone.

- **The upgrades shop is three drawn boards** (`shop_skin.gd`, 2026-09-11): net, ferry, dog
  side by side, each a grained, chipped oak frame (drawn like the meter's) round a dark
  face, a bowed three-tone oak ribbon over the top edge (front block only — hanging tails
  were tried and rejected), the thing itself under the ribbon, and two-line rows (name over
  value, clean-water price tag) with 3 px clipped corners. Colours are the meter's own, as
  `Style.BOARD*`, `FRAME*`, `RIBBON*`, `TAG*`: the murky-to-clean palette, picked over
  oak-only, clean-water (tried first, too bright) and sand-and-bag. No row icons, by decision.
  The heads are alive: the ferry is a `Sprite2D` over a `HullFoam` wake, bobbing 2 px; the net
  is drawn black over three fixed rubbish pieces the lake lends as `sprites[&"catch"]`; the
  dog draws itself through `DogArt`, rolling idle or asleep each time the shop opens. The
  painted `assets/shop.png` / `shop.json` / `tools/slice_shop.gd` are gone. Rows carry a
  `board` key from `Lake._shop_rows`; a track added to `TRACKS` needs one.

- **The settings are a drawn board too** (`settings_skin.gd`, 2026-09-11): one board in the
  shop's wood — plank title, then Music and Sound effects each as **one plate two lines
  tall** (label and switch over a full-width volume groove), Fullscreen, the level swap, and
  the quit alone at the bottom. It owns the state (`music_on`, `music_level`, `sfx_on`,
  `sfx_level`, `fullscreen`) and emits signals; the lake reads and sets those. The stock
  Controls and their WoodUI theming are gone from the settings; WoodUI still dresses the
  remaining scene buttons. The frame and title plank are `Style.board_frame`/`board_ribbon`,
  the same as the shop's.
  **Retired, by decision** (2026-09-11): the plank section headings (Sound / Screen / Save)
  and their seam lines; the separate slider plates; the *Save the run* and *Load the last
  save* rows **and the F5/F9 keys with them**. Saving is automatic — `Lake.AUTOSAVE_EVERY`
  (20 s), the window's close request, and *Save and quit* — and the game loads on start. A
  crash costs at most the 20 s; that was weighed and kept. Don't put a save button back.

- **The bites out of the wood are holes** (`Style.frame_bites`/`ribbon_bites`/`button_bites`,
  `carved`, `fill_carved`, `line_carved`, `rims`, 2026-09-11): every plank and frame is
  drawn as a polygon with its bites cut out (`Geometry2D.clip_polygons`), grain and highlight
  runs skip the bites, and each hole is ringed in one pixel of pure black (`Style.HOLE_RIM`).
  What is behind the wood shows through — the lake through an outer frame, the board face
  through a title plank. `Style.chip` (a painted brown rim, darker hollow and lit lip) is
  gone; anything that wants a bite passes `bites` to `plank`. **All drawn wood at once**, by
  decision — it is one set of functions. The pollution meter is painted art and keeps its
  painted crevices; repaint it if the mismatch ever reads.

- **The upgrades rows say their level in blue** (`Style.LEVEL_INK`, 2026-09-11): `Lake._shop_rows`
  hands `level` ("(Lvl n)") as its own field and `ShopSkin._draw_row` writes it after the
  name in the clean water's blue, dimmed with the row when it cannot be bought. Not the gold:
  gold on this board is a price.

- **The corner buttons wear the meter's own border** (`Style.meter_frame`/`_build_border`/
  `border_inset`, 2026-09-12): `assets/ui/meter/Meter_Border.png` is one painting 188x49 with
  its grain running the full length, so a frame of any size is **built** out of it, once per
  size and kept. **Nothing is stretched**: the top and bottom edges are the art's own planks
  cropped out of their long clean runs (`BORDER_TOP_RUN`/`BORDER_FOOT_RUN`, mirrored end to
  end past their length so the grain turns back rather than repeating), the side walls are a
  length of the top plank turned ninety degrees so the grain runs down the stile, the corners
  are the meter's own stamped whole, and the butt joints are painted in the wood's outline
  colour so a join reads as two boards meeting. Walls 15 px, 16 at the top, 14 at the foot,
  measured off the sheet's alpha; the buttons grew to 148x100 / 120x100 to keep their faces.
  **The left half is the right half mirrored**: the meter's own left side was never painted,
  because the garbage circle sits over it. `hud_buttons.gd`'s `FRAME`/`CHIPS` drawn frame is
  the fallback when the sheet is missing or the box is under `BORDER_LEAST`; `face_of` is the
  one place the inset is decided. Re-measure every `BORDER_*` if the meter art is repainted.
  **The stock readout and the settings button wear it too** (2026-09-12): the stock plate is
  that border round the recycle box's own brown (`STOCK_TALL` 62, up from 34 — the wood alone
  is 30, and its width is measured against the face and then grown by the walls), and
  `PlankButton` is it round a `BOARD` face with the word set to the **face** rather than to
  the whole button (`LABEL_SHARE`), so a button sized to its own word carries no empty wood.
  The settings button went 176x38 to 152x56 on that.
  **The built frame is bitten too** (`_border_bites`, 2026-09-12): one hole per `BITE_EVERY`
  of each outer edge, pixels cleared and the wood round each ringed in `HOLE_RIM`, exactly
  like the drawn boards' `frame_bites`. Punched into the image, so a hole is a real hole and
  the lake shows through. Needed because the planks' *clean* runs are what the edges are
  cropped from — the art's own chips are in the stretches the crop avoids — so an unbitten
  built frame read as plastic beside the drawn boards. Bites stay `BITE_CLEAR` off the
  corners: the chamfer is already the corner's shape.
  **Retired, by decision** (2026-09-12): dressing the buttons with a nine-patch of that art —
  tiling eight-pixel slices of a long grain turned the oak into corduroy and flattened the
  chamfer off its corners. Don't nine-patch painted wood.

- **The corner buttons are drawn wood carrying the game's sprites** (`hud_buttons.gd`,
  2026-09-11): a dark `BOARD` face inside that border.
  *Upgrades* (132x84): the landed net dimmed behind, the ferry in from the left, the dog
  (`DogArt` idle) in its right, both mirrored to face outwards and both at a size that can
  be made out, a black-ringed green (`SAFE`) block arrow large in the middle drawn last over
  them, the "n available" panel across the foot. *Shed* (104x84): sixteen fixed finds
  (`Lake.BUTTON_DECOR`, clean views, barely dimmed) scattered over the face by `_scatter` —
  each shoved off an even spread by its own hash, drawn back to front — with the hut standing
  in the middle of them so they stick out on every side, and "Decorate" on a sunken panel
  across the foot.
  **Retired, by decision** (2026-09-11): holding the ferry and the dog clear of the arrow's
  edges (the lane left was a couple of dozen pixels and shrank them to smudges — overlapping
  is what "behind" looks like), and standing the finds in two rows along the back (a band of
  furniture behind the hut, not a heap it sits in). *Money*: as wide
  as the stock plate over it, a drawn gold coin on the left and the running figure on a
  sunken panel to its right; the swell-and-shine on payment stays. Same places as before.
  The lake lends the sprites once (`Lake._lend_button_art`) to `HudSkin.sprites` and the
  static `UiButton.sprites`, so the shed's copy of the upgrades button is the same drawing.
  **Retired**: `assets/buttons.png`/`.json` and `tools/slice_buttons.gd`. `assets/ui.png`/
  `ui.json` stay only because `tools/slice_shed.gd` cuts the hut off them; nothing draws
  from them at runtime. The shed icon does not track the collection, by decision.

### The Angler (`scripts/player.gd`, shed: `shed_room.gd`)
One sheet, `assets/character.json`/`.png`, cut by `tools/slice_character.gd` from the strips
psd-extract left in `art_source/character_extracted/` (source `Character_Sprite_Sheet.psd`).
Four real directions (south/north/east/west), `idle` 9, `run` 17, `cast` 16 frames; the straw
hat is painted in. Frames are centred on their ink, not their cell (cells are an even split
of a hand-trimmed strip). The shed draws the same sheet, idle and run only.
- **Retired, by decision** (2026-09-11): the first angler (three rows + mirrored side, 6
  poses), the separately drawn straw hat (`straw_hat.png`, `slice_hat.gd`, per-frame head
  marks) and the F9 sheet toggle. Don't bring back a worn hat: the art has one.

### The Ferry (`scripts/boat.gd`, sheet: `assets/boat_sail_frames.png`)
The hull is the PixZels blue boat (`art_source/Blue_Boat/blue_boat_16dir.png`, a 16-heading
128 px sheet, credit @Pixel_Salvaje), cut for the lake by `tools/build_boat_sheet.py`
(psd-extract venv python, project root), which writes the sheet and its json. Decided
2026-09-11:
- **The jib is gone, and the forestay with it.** Three sails were drawn — a jib on the
  forestay, a square sail on the yard at the mast (its forward billow is the white-and-slate
  lens in the side views), a gaff sail aft — and Richard wanted the front one off. The edit
  is a per-frame table of ops in the script (`OPS`, frames 0-8, mirrored onto 9-15: the sheet
  is mirror-symmetric to within a few pixels of the hull's blue stripe), not a hand-saved PNG,
  so it can be re-run. What the jib hid is repainted from the frame's own colours: the bow
  deck under its clew as a far rail stepping down to the stem cap with deck in shadow inside
  it, the square sail's lit face where the jib's shaded half lay over it, the sail's foot
  spar where its far end was. Bow on and stern on, the jib was edge-on behind its own stay,
  so only the stay came out.
- **The baked floor shadow is stripped** (every half-alpha pixel): a hull on water throws
  none. No replacement shadow.
- **Drawn at 2.0**, like every other sprite. `HULL_IN_FRAME` (46, the waterline length in a
  frame) and `HULL_LENGTH` (92) set that; `HULL_WIDTH` 50 is the beam bow on, doubled.
  Foam, wake, stern ripple, shove clearance and the shop board's wake follow from those,
  untuned this pass. The old 138 px ferry was a third longer; judge the size in play.
- **The anchor** (json `anchor`, the side view's waterline under the mast; `HULL_ANCHOR`
  is only the fallback) is the frame point that lands on the boat's position: the water
  under the mast, the point the frames turn about. `heading_frame` counts frames clockwise
  from `FRAME_ZERO_TURN` (bow towards the camera = tile diagonal (1, 1)); `turn_heading`
  gives the shop board the heading its frame faces. The pennant flies from the masthead the
  json lists per frame (`MASTHEAD` in the script, mirrored).
- **In the water, not on it, but only just** (2026-09-11). Each frame is cut along a level
  waterline the json lists (`cut`: `SINK_ROWS` (2) up from the bottom of the hull's body,
  the lowest row `HULL_WIDE` (8) pixels wide, so the stem foot and the rudder post go under
  and a couple of rows of keel planking with them; derived by the script, `CUT_ROW` to pin
  a frame by hand), and drawn as a polygon of what is above it (`Boat.hull_polygon`). It
  was cut at the boot-top first — the whole underwater hull gone — and Richard wanted it
  sitting higher. Level by decision: a line bent to follow the boot-top along the
  near side ran diagonally into the bow and the transom in the quartering headings and made
  a V across the bow face end on; one row at the anchor for every frame chopped the bow
  off end on (the frames are not one strict projection — the bow-on rail is six rows tall
  where thirty degrees would make it eighteen). The far end of a quartering hull shows a
  few rows below its stripe, accepted as the lesser wrong. Along the cut
  lies the lake's own foam collar (`HullCollar`: foam.gdshader with its own material,
  `COLLAR_SCALE` 2.4 times the rubbish's rise and fall, one strip over the cut's segments,
  tear and bubbles scaled to the width through the shader's new `tear_across` uniform — not
  a `WaterlineFoam`, which is one shared material sized for a figure on a straight edge).
  The shadow is the sun's (`HullShade`): the same above-water polygon drawn again in the
  day's ink under `Shade.lying`, like the angler, the dog and the trees, so it leans and
  stretches with the day and is the shape of the boat on its heading, at `SHADE_GAIN` (3)
  times the day's ink, capped at `SHADE_MOST` (0.7): the day's ink is set for sand and
  grass, and on the lake — darker, and darkening away from the island the way the shadow
  falls — the same alpha could not be seen (0.16 at dawn: nothing; 0.35: still nothing;
  0.48: reads). The rubbish's squashed crescent (shadow.gdshader) was tried first and could
  not be seen under a hull either. `Boat.day` is set in `Lake._fit_out`; no day, no
  shadow. `tools/shot_boat.tscn` logs the sun and the shade node beside its pictures
  (`tools/last_boat.log`), since a missing shadow can be either. The shop board draws the same
  polygon (`Polygon2D`, `cut` from `art_frame`).
- **Cargo draws over the picture**, sails and all, on the foredeck just ahead of the mast
  (`HOLD_FROM` 0.06 to `HOLD_TO` 0.24, `HOLD_LIFT` 0.9 hull heights). Kept short of the
  bow: laid to the rail by the plane's projection it floated past the cut bow end on,
  because the frames draw that deck higher than the projection puts it. Cutting each
  heading into hull and sail layers would have tripled the art; not drawing the load loses
  the laden-ferry read. Richard's call.
- `assets/Blue_Boat/PixZels_Model_BlueBoat.json` that came with the sheet is a *different*
  boat (a pirate ship with a skull sail) and was no use as a reference; the edit is 2D only.
- **Not yet retired**: `tools/bake_boat.gd` and the Kenney sheet `assets/boat_frames.png`
  it bakes, kept until the sail boat is judged in play. `tools/shot_boat.tscn` (desktop
  build, not `--headless`) saves three close crops of the ferry under way,
  `tools/last_boat_N.png`, for checking that the anchor puts the hull on the water.
- **Open**: the bow-foam streaks (`HullFoam`, `HUG` at a constant `SQUASH`) sit inside the
  hull's silhouette in the side and end-on views and only show where they spread past the
  stern — as they did under the old hull. A heading-aware across scale would fix it.

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

### The Shed's Shelf (`scripts/shed_shelf.gd`, 2026-09-11)
The inventory column down the right of the shed is a drawn oak board, the same furniture as
the upgrades shop and the settings: plank frame, dark `Style.BOARD` face, a title plank over
the top edge reading "Shed Decoration" with the count, and one clipped `Style.plate` per
find (clean sprite fitted left, name in `BOARD_INK`, `HOVER_WASH` under the pointer). The
old scrim rectangle and its 1.5 px ink outline are gone.
- **The board grows outwards**: `_board_rect` is the column `LIST_WIDTH`/`GUTTER` already
  reserved, grown by `SHELF_FRAME`, clamped to the panel's right edge. `_room_rect` and
  `_floor_rect` still size off `LIST_WIDTH` alone, so the wood costs the floor nothing.
  `_list_rect` (the rows) is derived *from* the board, so a clamp moves rows and hit-testing
  together.
- **Top and bottom come off the shed, not the floor** (`_shed_rect`): the wall's top edge
  down to the floor's front edge, the same two numbers `_draw` builds the wall from. A board
  squared up with the floor alone started below the wallpaper and read as a panel bolted on.
  **The line to match is the title plank's, not the frame's**: the plank straddles the
  board's top edge, so squaring the frame with the shed left half a plank sticking up over
  the room. `_board_rect` starts `SHELF_RIBBON * 0.5` below the shed's top instead, and the
  shelf's outline lands on the shed's at both ends. The border sheets carry no transparent
  padding (measured), so rect edges and drawn edges are the same line.
- **The close cross is nailed to the title plank's right end** (`_place_close`,
  `_title_box`). It used to sit in the air above the column; once the plank took that edge
  the cross covered the title. `Style.board_ribbon` takes a `within` box so the writing
  centres on the wood the cross leaves free, mirrored at the left end so the title stays
  centred on the board. The title drops to `TEXT_SMALL` rather than being cut when the count
  will not fit.
- **It is its own Control** only so `modulate.a` can fade the whole thing to `LIST_BUSY`
  while a piece is carried. Threading an alpha through `Style.plank`/`grain`/`highlight`/
  `rims` would put an extra argument on every shared drawing helper in the game. The shelf
  holds no state: `ShedRoom._dress_shelf` hands it rects and rows each draw, measured once
  and reused by `_listed_at`/`_hovered_row`, so drawn rows and clicked rows cannot drift.
  It ignores the mouse; the room still takes every click.
- **Overflow**: wheel scroll as before (`_scroll_by`, now against `_list_rect().size.y`, not
  a guessed `size.y - 96`), whole rows only, plus a drawn track and plate thumb down the
  face's right edge. A reading, not a handle — the lane is reserved whether or not anything
  scrolls, so rows never change width.
- Long names are cut with an ellipsis (`_draw_name`): `Style.write` has no clip box, and a
  title running off the wood reads as a bug rather than as a long name.
- **The frame and the title plank live in `style.gd`** (`Style.board_frame`,
  `Style.board_ribbon`); `shop_skin.gd` now calls them. One wood, one place.

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

### Island Coast (under the water, cut by the shader)
The island's ground (`Ground.Layer.ISLAND`) draws **under** the water at z 1, same as the
bank, and `water.gdshader` **discards** its pixels where its `island_fraction` is under 1.
That curve is the coast. The sand runs `Ground.ISLAND_UNDER` (one tile) past it so there is
sand under every open pixel; beyond that it is under opaque water and not drawn.
- **One edge, two languages**: the shader's `island_fraction` (radii shrunk by `shore_lap`)
  equals `Iso.island_ring_fraction(at, WATER_LAP_TILES)`, so `Iso.past_shelf` (tiles) and
  `Iso.past_water` (world px) are the drawn edge. `Iso.on_island_ground`, the angler's
  `_wet_by`/`WALK_LIMIT`, and the dog's `_on_land` all ask those. Never ask the tile under a
  walker, and never move one wobble term without the other. **One term is exempt, by
  decision — the coast wave below, and only because it runs one way.**
- **The coast laps, and only outward** (`water.gdshader` `coast_lap`, `Lake.COAST_WAVE`/
  `COAST_WAVES`/`COAST_WAVE_SPEED`, 2026-09-12): the island's drawn edge is carried up its
  beach and back on a slow wave travelling round the shore, so the coastline breathes instead
  of sitting on one curve. This is **the exception to one-edge-two-languages**, and it cannot
  be anything else: `Iso` is static and has no time to carry, and mirroring a wave into it
  would dry and wet the ground under a walker several times a second. What makes the
  divergence safe is that `coast_lap` returns 0 to `COAST_WAVE` and is **never negative** —
  the paint covers sand the code calls dry and never uncovers water the code calls wet, so the
  angler and the dog stay dry-correct by a line that does not move. `test_lake` guards both
  ends: not negative, and under `Ground.BEACH_IN` (2.6) so a crest never reaches the lawn.
- **The foam stays on the static line, and that is the whole trick**: `shore_foam`'s
  `lip = step(dist, lip_w)` has no lower bound, so the lip is already drawn under the sand.
  Water running up the beach therefore **uncovers** foam instead of sliding out from under it
  — the band reads wider at a crest and narrower in a trough, and the wave arrives in the
  existing foam's own style for no extra work. `isl_out` is deliberately measured off the
  unwarped fraction. **Don't feed the lapped edge into `shore_foam`** thinking it is the fix;
  it is the thing that would break it.
- Whole waves per lap (`round(coast_waves)`), or the ring seams where `atan()` wraps from pi
  to minus pi — the same rule `shore_foam`'s cells and tears follow. Two terms beating, not
  one: a single travelling sine reads as a scalloped border turning on the spot.
- **The outer bank laps too** (2026-09-12, second pass): the bank used to have no discard at
  all — the water simply ran out of polygon at `Iso.shore_outline(SHORE_LAP)`. Now the polygon
  is drawn well past the waterline (`Lake.WATER_RIM`) and a second discard carves it back to
  wherever the wave has run to, so the bank's edge is decided by the shader like the island's.
  **Grow one without the other** and either the crest is clipped flat by the rim or the surplus
  water is left standing on the sand. `WATER_RIM` is `SHORE_LAP + COAST_WAVE * 2` plus a tenth,
  because `shore_outline` adds its grow to the *wobbled* radius while `shore_fraction` folds
  the lap in *before* the wobble; `test_lake` walks 240 bearings and checks the rim clears the
  crest rather than trusting that arithmetic.
- **One wavelength, not one wave count** (`coast_lobes`): `COAST_WAVES` is the count round the
  island, and any other shore gets whatever count holds the same wavelength — the bank's mean
  is about five times the island's, so it gets about five times as many. The same count on both
  makes a bank wave some eighty tiles long, which reads as the coast not moving at all. The
  island is the shore the number was tuned on, so it is the one that holds it.
- The bank's foam is measured off the static line as well, for the same reason as the island's,
  and the bank's beach litter (`Iso.BEACH_LITTER`, 2.4 tiles up) can take a wash from a crest.
  That is wanted — the pieces are `dry`-flagged and do not bob, so the water moving over them
  is the only thing that says they are at the waterline.
- Tuning: F4's `GroundTuner` carries the three coast sliders beside the ground's (they go to
  the water material, not the `Ground` nodes); bake picks into `Lake`'s constants.
- **Retired, by decision**: the island standing above the water with a drowned-sand shelf
  stepping down into the lake (`SINK_*`, `ISLAND_DEEP`, `IslandShallows`), and the flat
  water-coloured plate over it before that. Both left a stepped edge; the discard is what
  made the coast a curve. Do not bring the island back above the water.
- `Iso.SHELF_TILES`/`SHELF_CLEAR` still hold the rubbish off the beach (the first cast has to
  reach); they no longer describe anything drawn.
- Island foam ring width in the shader is 1.0 like the bank's (was 1.5 to cover tile corners).

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
size × `SPRITE_SCALE` (2.0), clamped to `SPRITE_SMALLEST`..`SPRITE_LARGEST`.

### Retired
`assets/TopDownHouse_FurnitureState1/2.png` no longer feed the catalogue and `furniture_NN`
names are gone (so is `scripts/find_names.gd` — titles live in `pieces.json` beside the
rectangles now). `SAVE_VERSION` is 5 and older saves are refused rather than migrated;
`RECUT_RENAMES` and `tools/repair_save.gd` went with them. `tools/slice_sheets.gd` still
cuts the rubbish sheet, and still writes the whole `pieces.json` — **run
`tools/build_decor.py` after any re-slice** or the decor half is lost.

---

## Performance

**Bar** (settled 2026-09-11): mean frame under 8 ms and no frame over 16.7 ms, uncapped,
fullscreen 1080p, full lake, standing and walking. The 8 ms is headroom standing in for weaker
PCs — there is no weak-hardware test, by decision. No visible quality cuts to get there.

**Measure, don't guess.** `tools/bench_frames.tscn` (real window, vsync off, 600 frames):
`BENCH_WALK=1` walks the angler, `BENCH_OFF=water|ripple` removes suspects, result in
`tools/last_bench.log` with rebuild causes and draw calls. `tools/census.tscn` attributes the
frame's draw calls to each top-level branch (`tools/last_census.log`). In play, F3's perf
overlay logs every frame over 20 ms to `user://last_frames.log` with the rebuild cause.

**Rules the numbers came from:**
- **Draw calls are the cost.** Each `draw_texture*` with a different texture (or a transform
  change between them) is its own draw call. The forest was ~5,600 of them — 15 ms a frame —
  until `Ground._pack_props` put every tree, rock and tuft into one atlas and `_lay_props` laid
  them and their shadows out as one triangle array. Anything drawn in the hundreds goes in a
  batch off an atlas, never a loop of `draw_texture_rect`.
- **`LakeGrid._rebuild` costs ~25-30 ms** over the whole basin. It must never run while
  walking, casting or hauling. The soup is laid out for the view plus `BUILT_MARGIN`; a take
  patches its tile (`_restamp`); detail changes skip the rebuild when every def has art.
  `test_lake` guards the counts.
- **The shaders are not the cost**: `BENCH_OFF=water` measured no difference.
- **Eases use `Lake._ease` (exponential)**, not `rate * delta`, so the camera does not lurch at
  an uneven frame rate.

Measured 2026-09-11, RTX 5060 Ti: 15.0 ms -> 2.2 ms mean standing, worst walking frame
42 ms -> 3-4 ms.

---

### Shed Screenshot Probe
`tools/shot_shed.tscn` opens the lake, fills the shelf, opens the shed and saves
`tools/last_shed.png` plus `tools/last_shed.log` (the room, shed, floor, board, ribbon and
row rectangles, and the colour changes down a column of each). Run it with the **desktop
build, not `--headless`** — nothing renders under the dummy driver. The pictures are
git-ignored; the scene is not. Use it for questions about where an edge actually lands:
eyeballing a screenshot to a pixel does not work, and the rect the log prints is in the
room's own coordinates while the picture is the whole window.


## Godot/Windows Gotchas

### Logging & Debugging
- `print` and `printerr` don't reach shell on GUI Godot builds (Desktop is GUI-based)
- **Write to file**: headless harness writes `tools/last_test.log`, flushed per line
- Test harnesses: `tools/test_lake.tscn` (the lake: heap, angler, net, yard, save, art —
  `tools/last_test.log`) and `tools/test_siege.tscn` (the siege — `tools/last_siege_test.log`)

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
- `shaders/water.gdshader` — pixel-art lake surface: palette ramps, stepped filth/depth, shore foam
- `shaders/pixel.gdshaderinc` — shared pixel grid, stepped time (no dither, by decision)
- `scripts/sfx.gd` — audio for haul, settling, collection

---

## Before You Start
1. Read root `CLAUDE.md` for shared Godot setup, anti-patterns, vigilance rule
2. Check GitHub Issues (filter by `project:lake-cleanup`)
3. Water and drag feel are locked (Richard tested); progression numbers can shift
4. If editing grid layout or the angler: run `tools/test_lake.tscn` headless
5. If finding contradiction: stop and name it (see root CLAUDE.md vigilance rule)

---

## See Also
- Root `CLAUDE.md` — shared knowledge, art pipeline details, vigilance rule
- `Strait Across/CLAUDE.md` — sister project (shares water shader, similar project structure)
- Game design notes: `~/Downloads/lake-cleanup-game-notes.md` (historical reference, not current)
