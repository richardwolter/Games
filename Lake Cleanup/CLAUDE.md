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
  colour so a join reads as two boards meeting. **The stiles come off the foot plank**
  (2026-09-12), not the lit top one: a frame with the light tone down both sides and the dark
  one along its bottom read as three woods. Light along the top, one shade everywhere else. Walls 15 px, 16 at the top, 14 at the foot,
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
  **And so do the three menus** (2026-09-12): the upgrades boards, the settings board and the
  shed's shelf call `Style.board_wood` for their frames and `Style.board_ribbon` — which now
  reaches for `meter_plank` first — for their title planks. `board_wood` **returns the face**
  and `board_face`/`board_wood_tall` give the same numbers without drawing, because the two
  woods are not the same thickness and every caller that worked its own inset out would be
  wrong for one of them. A ribbon is `_build_border` at exactly `PLANK_TALL` (30), where
  there are no middle rows to fill and it comes out a solid plank with rounded, bitten ends
  rather than a frame with a hole. `Style.board_frame`/`plank` stay as the fallback.
  **The close crosses too** (`close_button.gd`, 2026-09-12): each is `meter_plank` with the
  cross drawn over it, so a cross pinned to a title plank is part of that plank rather than a
  lighter tile bolted on. They grew 34 to 44 (`CLOSE_SIZE`/`CLOSE_SIDE`) and
  `_border_seams` skips the end joints when the run between the corners is under
  `BORDER_JOINT` — on something that small the two corners nearly meet and a pair of joints a
  few pixels apart reads as a crack down the middle.
  **The built frame is bitten too** (`_border_bites`, 2026-09-12): one hole per `BITE_EVERY`
  of each outer edge, pixels cleared and the wood round each ringed in `HOLE_RIM`, like the
  drawn boards' `frame_bites`. Punched into the image, so a hole is a real hole and the lake
  shows through. **Each is a V**, widest where it opens on the edge and narrowing to a blunt
  point `BITE_TIP` wide — a square notch read as a slot someone cut, and what these are is a
  splinter that came away. The rim goes on after the whole V is carved (a pixel on the slope
  would otherwise be blacked and then cleared by the next step in) and covers the diagonal
  shoulders too, or a corner touching the hole at a point draws as a loose pixel in the gap. Needed because the planks' *clean* runs are what the edges are
  cropped from — the art's own chips are in the stretches the crop avoids — so an unbitten
  built frame read as plastic beside the drawn boards. Bites stay `BITE_CLEAR` off the
  corners: the chamfer is already the corner's shape.
  **A plank's bottom bites are backed, not open** (`_backings`, `meter_plank`'s `under`,
  2026-09-12): a ribbon straddles its board's top edge, so a hole in its lower edge shows the
  frame plank it is lying on. `_border_bites` records what each bottom bite cleared into a
  mask, and the plank draws that mask tinted `Style.BOARD` under itself — so the bite reads
  through to the **board's face**, which is what is behind the panel. Top and end bites are
  over the lake and stay open.
  **Retired, by decision** (2026-09-12): dressing the buttons with a nine-patch of that art —
  tiling eight-pixel slices of a long grain turned the oak into corduroy and flattened the
  chamfer off its corners. Don't nine-patch painted wood.

- **Where each picture on a button stands is tunable by hand** (`HudButtons.BAKED`/`tune`/
  `_at`/`_scale`, `scripts/button_tuner.gd`, **F7** in a debug build, 2026-09-12): three
  layers, first one wins — the tuner's live overrides, the `BAKED` dictionary of what was
  picked and kept, and the rule the constants describe. Rules are the right way to start (they
  hold at any button size) and the wrong way to finish: "a little further left" is not a number
  anybody can write down. Positions are the drawn picture's **middle** as a fraction of the
  face — of the room, for the shed's two — and sizes are fractions of its height, so a picked
  place survives a resize.
  The canvas draws both buttons at `ZOOM` **through `draw_upgrades`/`draw_shed` themselves**,
  with the lake's own sprites, and they report where every picture landed through
  `HudButtons.traced` (filled only while `tracing`). There is no second layout to drift from
  the first — which is why this is a panel in the game rather than a web canvas with the sums
  written out again. Drag to move, wheel to size (shift for the arrow's width), arrows to
  nudge, alt-click for the picture underneath, R to put one back to its rule, S to write
  `user://button_tune.log` — a `BAKED` literal to paste. Only what was actually moved is
  written: baking the rule's own answer freezes a number nobody chose.
  Probe: `tools/shot_buttons.tscn` (desktop build, not `--headless`) opens the canvas and
  saves `tools/last_buttons.png`.

- **The corner buttons are drawn wood carrying the game's sprites** (`hud_buttons.gd`,
  2026-09-11): a face inside that border. The two picture buttons stand theirs on
  `Style.BUTTON_FACE` (2026-09-12) — the boards' own murky water, one step up the palette
  from `BOARD` — because they are mostly pictures, and the darkest swatch in the set read as
  a hole in the corner of the screen rather than a sign on it. Their sunken panels are
  `Style.BUTTON_SUNK`, that water taken well down. The money plate and the menus keep
  `BOARD`: their job is to be read.
  *Upgrades* (120x100, the decorate button's own size): the landed net behind in
  `Style.NET_INK` — the shop board's own black, one net wherever it is drawn as a picture of
  itself — the ferry to the left of the arrow, the dog
  (`DogArt` idle) in its right, both mirrored to face outwards and both at a size that can
  be made out, a black-ringed green (`SAFE`) block arrow large in the middle drawn last over
  them, the "n available" panel across the foot. *Shed* (104x84): sixteen fixed finds
  (`Lake.BUTTON_DECOR`, clean views, barely dimmed) scattered over the face by `_scatter` —
  each shoved off an even spread by its own hash, drawn back to front — with the hut standing
  in the middle of them so they stick out on every side, and "Decorate" on a sunken panel
  across the foot.
  **That panel is drawn once** (`HudButtons.label`, `LABEL_TALL`/`LABEL_TEXT`/`LABEL_LEAST`,
  2026-09-12): the decorate button's name, the upgrades button's count and the shed's copy of
  it all call the one function, which is given the **face** because that is what all three
  callers have. Written out three times they drifted — the decorate plate was measured off its
  own band rather than the face and its lettering went through `Style.step` onto the size
  ladder, so "Decorate" stood taller on a deeper plate than "n available" beside it.
  `room_of` is the matching sum for what the band leaves the pictures, asked for by the shed's
  heap, its hut and the tuner alike.
  The ferry and the dog are **sized to their share of the face** and placed by their own drawn
  edges, so `SIDE_UNDER` (0.3) of each goes behind the arrow (2026-09-12). Sizing them to the
  lane beside the arrow was tried while the button was 176 wide and does not survive the
  narrower one — a couple of dozen pixels of lane shrinks both to smudges. The lane decides
  where they stand, `SIDE_UNDER` how much the arrow takes, neither how big they are. Fitting
  them to a slot and then clamping them onto the face is the older, worse way: it put the
  ferry half under the arrow, which is where it started.
  **`fit`'s mirror turns the canvas over** (`draw_set_transform`), because a `Rect2` of
  negative width does **not** flip a `draw_texture_rect_region` — it degenerates, and the
  ferry drew as a few scraps for a day before that was spotted. Don't "flip" with a negative
  rect anywhere.
  **Retired, by decision** (2026-09-11): holding the ferry and the dog clear of the arrow's
  edges (the lane left was a couple of dozen pixels and shrank them to smudges — overlapping
  is what "behind" looks like), and standing the finds in two rows along the back (a band of
  furniture behind the hut, not a heap it sits in). *Money*: as wide
  as the stock plate over it, a drawn gold coin on the left and the running figure on a
  panel **pressed into** the wood to its right (`HudButtons.sunk`, the stock readout's own
  panel — a figure on a raised plate read as a tile stuck on the button while the one beside
  it was cut into its board); the swell-and-shine on payment stays. Same places as before.
  The lake lends the sprites once (`Lake._lend_button_art`) to `HudSkin.sprites` and the
  static `UiButton.sprites`, so the shed's copy of the upgrades button is the same drawing.
  **Retired**: `assets/buttons.png`/`.json` and `tools/slice_buttons.gd`. `assets/ui.png`/
  `ui.json` stay only because `tools/slice_shed.gd` cuts the hut off them; nothing draws
  from them at runtime. The shed icon does not track the collection, by decision.

### The Shed and the Box Stand in Grass (`scripts/skirt.gd`, 2026-09-12)
The hut on the island and the recycle box are front-on pictures set on a lawn, and the row
of pixels where each ends was a straight cut. `Skirt.hem` grows small painted tufts along
that line: blades drawn as columns of whole art pixels (2-4 tall, 2-4 to a tuft, palette
greens), rolled off a fixed seed, **standing on the sprite's own silhouette** — for every
art pixel across the picture, the lowest opaque row of that column is where a tuft stands.
The grass therefore follows the shed's diamond and the crate's V exactly and fills the line
rather than dotting it. Every blade is drawn **over** the picture: covering that last row is
the whole job.
- **Not a ring round the base, by decision**: an ellipse on the ground stood clear of a
  front-on painting round its sides, leaving lawn between the blades and the picture and the
  hard line still showing. The line to hug is the drawing's, not the footprint's.
- **Overhangs are not ground** (`HEM_BAND`): the shed's eaves end at row 52 of 127, seventy
  pixels up in the air, and grass planted on a column's lowest row alone grew out of the
  roof. Only columns within the band above the picture's deepest row are planted.
- **The blades are cut down towards the far ends of the line** (`HEM_SHORTEST`, `HEM_TAPER`),
  measured against the base's *own* rise — seven rows on the crate, thirty-three on the shed —
  and cubed, so the cut bites only at the corners. A full-height tuft on the crate's lower-left
  edge reached the recycle mark painted just above it. A flat taper measured against `HEM_BAND`
  was tried first and left the shed's left wall bare.
- **A caller can set its own blade height** (`Yard.SKIRT_BLADES` 1-2 against the hem's 2-4):
  the crate is drawn at 2.5, so one of its painted pixels is two and a half of the game's and
  a shed-sized blade stands a third of the way up it.
- **The doorway is kept bare** (`Lake.SHED_DOOR`, columns 30-47 of 130 as fractions): a door
  with grass across it is a door nobody opens, and this is the one the player walks through
  several times a run. `hem` takes any number of such cleared spans.
- **Baked, one draw call** (`Skirt.Patch`, `RenderingServer.canvas_item_add_triangle_array`,
  the same batching as `Ground._lay_props`). The island redraws every frame, so a few hundred
  `draw_rect` calls is exactly the cost that put the forest at 15 ms. **Not `draw_polygon`**:
  it triangulates the points as one outline, and loose pixel quads handed to it fail
  triangulation and draw nothing.
- **Static, by decision** — no sway. A batched mesh never has to be rebuilt, and swaying grass
  at the shed on an island of still grass reads as the only wind in the world.
- **Painted in code, not pack `Leaves`** — the tufts on the beach and the island are the pack's;
  these are blades sized and leaned to a base.
- **The box also spills sand** (`Skirt.spill`): loose single art pixels thinning outwards from
  its foot, palette `sand`, fading with distance, drawn under the picture. A spill, not a
  patch, and nothing in `Ground` knows about it — the box stands on the island's lawn, and
  this is ground the crate has worn.
- **The shed's contact patch is gone, by decision**: the soft black quad under the hut
  (alpha 0.11). The grass is what says the hut meets the ground; the quad under a skirt of
  blades read as a second shadow.
- **The hut is 1.2x bigger, and its footprint is measured off the art** (`Iso.SHED_TALL` 141.6,
  `SHED_FOOT` 1.15 x 0.83, 2026-09-12). The footprint was an ellipse of 1.70 x 1.40 — sized to
  hold a walker clear of the whole picture, eaves and all, which cost most of a tile of grass
  on every side and made the hut feel round to walk round. It is now **a rectangle in tile
  space, the diamond the walls stand on**, exactly as `Yard.covers` treats the crate, and the
  angler slides along its faces (`Angler._slide`) instead of being handed to the shore's
  curve. You may stand against the wall and under the eaves, as you may against the box.
- **And the hut stands where it is drawn** (`Iso.shed_centre`, `SHED_STAND`, `SHED_ART_GROUND`):
  the picture's bottom row is the near corner of the walls' base, so the building stands about
  two thirds of a tile north of the island's middle — and the footprint, `_shed_front`, the
  layer test, the door's range (`_at_shed`) and the lamp were all measured from the middle.
  A walker was stopped short of the near wall and could stand inside the far one. The drawing
  numbers live in `Iso` now, because the walkers need them too; drawing off one number and
  colliding off another is how they drifted. `test_lake` guards both ends — the footprint
  against the corners measured in the art, and `_shed_front` against the drawn near corner.
- **A dog inside the footprint can walk out of it** (`Dog._may_stand`): the rule is only
  enforced on an animal that is outside already, the way the crate's always was. It was not,
  so a dog that started inside (an old save, or the hut growing under it) was walled in.
- **The island's tufts keep clear of the picture, not of the footprint** (`Iso.SHED_COVER`):
  they draw under the hut, so one inside it is wasted rather than wrong — but the walkers must
  not inherit that clearance, which is what the old single number did.
- **The hut's shadow is rooted where the building stands, not at the bottom of the picture**
  (`Lake.SHED_ART_GROUND` 0.224, `_shed_feet`): the walls' feet are an isometric diamond and the
  art's last row is that diamond's **near corner**, some 27 px down the grass from the middle of
  it. A shadow pinned there read as belonging to something else. The picture
  itself has not moved (`SHED_STAND` 0.35 is unchanged) — only what hangs off it. **Re-measure
  `SHED_ART_GROUND` if the hut is re-cut** (`tools/slice_shed.gd`): it is the diamond's side
  corners, rows 93 and 103 of 127, as a fraction up from the bottom.
- **The hut is drawn coarser** (`tools/downres_shed.py`, 2026-09-12): the 130x127 cut
  `slice_shed.gd` makes (kept as `art_source/shed_tan.png`) is resampled to **103x101** and
  drawn at 1.4 world px per painted pixel (`Iso.SHED_TALL` 141.4), because at 1.1 beside the
  box (2.5) it read as a higher-resolution picture pasted on. 1.4 by decision, over 2.0 (one
  art pixel each, but seams and thatch went to mush) and 1.6, judged side by side; not an
  art-pixel multiple, so it draws faintly uneven on the screen grid, as the original did.
  Resampled **by class** (each target pixel takes the class covering most of it and that
  class's mean colour), snapped to a few tones per class, seams re-inked, roof speckle
  cleaned, window and handle redrawn by rule, fascia kept as a line. Writes
  `art_source/shed_101.png`. **Richard polishes that file by hand** ("rules first, polish
  after"); from then on it is the painted source and a re-cut means redoing the polish.
  `SHED_ART_GROUND` re-measured at 0.233; the footprint measured 1.14 x 0.83 and stays.
  Both scripts take `--tall N` / `--source` / `--out` for trying another grain without
  touching the pipeline's files.
- **The hut's walls are the box's wood** (`tools/recolor_shed.py`): reads `shed_101.png` and
  writes `assets/shed.png` with every wall pixel **histogram-matched onto the recycle box's plank
  browns** read off `Recycle_Box.png` — the same brown the ferry's hull took, not
  `Style.CRATE`. A remap by brightness rank, not a tint: seams stay seams and the outline
  becomes the box's darkest brown (one wood, by decision). Untouched: the thatch, the wooden
  fascia along the roof's outer edges (told from the walls by having thatch *below* it in
  its column), the lit yellow window and the grey door hardware. **The walls also get the
  box's border**: every wall pixel on the picture's outer edge is painted in the box's own
  silhouette colour (read off the box, 48,37,33), the one-pixel dark line the box is drawn
  with; the roof's edge is left as painted. One painted pixel deep now (`BORDER_DEEP`), and
  the half-alpha shadow row the art had under the walls is stripped (`STRIP_SOFT`) — one
  soft pixel with a grey smear under it read thin and faded next to the box's edge. A hut
  on grass throws no baked shadow; the lake draws the sun's. **One pixel is then cleared off
  each vertical side** (`SIDE_TRIM`). The box has the same step (`tools/trim_box_sides.py`,
  from `art_source/recycle_box_painted.png`) **at zero, by decision**: its side line is one
  pixel, and taking it off left the box with no border. What that script does do is
  **repaint the box's vertical sides in its upper rim's colour** (the red-brown 76,29,29,
  read off the top edges) so the outline reads as one line; the lower edges keep theirs. `recolor_shed.py` reads the box's
  wood and edge colour off the painted source, not the asset, for the same reason. Only
  vertical runs of the silhouette are sides; the sloping edges keep their line. Run it with the psd-extract
  venv python from the project root; **re-run after any re-cut**, copying the fresh cut to
  `shed_tan.png` first. `--mask out.png` writes the classification for checking.
- Both need the art: a hem is measured off an `Image`, so the blocked-in fallbacks (no sheet)
  grow nothing. **Shed and box only**, this pass. The four dropoff piers have the same hard
  bottom edge on the bank and are the obvious next ones.

### The Sun Is in the Southeast (`day_config.gd`, `shadow.gdshader`, 2026-09-12)
Every painted asset in the game is lit from the right: the shed's and the recycle box's own
pixels are measurably brighter down that side. The day cycle used to swing the sun across
the sky — `lean_dawn` +1.7 through `lean_noon` +0.18 to `lean_dusk` -1.7 — which threw the
cast shadows to the *right* of their casters for most of the loop, onto the same side as
every baked highlight, and crossed zero at noon so the whole world's shadows flipped sides
in front of the player.
- **The shadow always falls down and to the left**, and the sun only drifts west through the
  day instead of crossing. `test_lake`'s `_stage_sun` walks 200 phases and guards the side.
- **The lean is derived from the stretch, not set beside it** (`DayConfig.slant_*`,
  `DayCycle._settle`, 2026-09-12). The exports are a *bearing* now — how far the shadow goes
  sideways per unit it goes down the screen — and the lean handed out is that times the
  shadow's own drawn length. Set independently they drifted apart on the first pass: a noon
  lean of 1.0 against a noon stretch of 0.42 threw the shed's shadow 141 px sideways while it
  was only 30 px long, 78 degrees off vertical, a flat streak lying beside a building it had
  come away from. Tied together the shadow keeps its bearing all day and only its length
  changes, which is what a sun climbing and setting in one quarter of the sky does. Slants
  are 0.5 dawn, 0.35 noon, 0.25 dusk, which puts the shed's shadow 27, 19 and 14 degrees off
  vertical. **Pulled in twice from 1.25 / 0.95 / 0.7** (51, 44, 35 degrees), by eye, once the
  sweep landed: a swept shadow reaches much further to the side than the old sheared one did
  at the same slant, because the shear only ever showed the part that escaped past the sprite
  while the sweep draws the whole occluded region. At the old numbers the shadow stood off the
  left wall instead of belonging to it. It is meant to tuck under the roof's overhang. **The
  two sets of numbers are not comparable** — don't read a slant from before the sweep. **`test_lake` guards the angle** (`SHADOW_FLATTEST`, 60 degrees) as well as the
  side: the numbers are by eye and free to be retuned, the two rules are not.
- **A narrow arc, by decision** — not a pinned sun. Pinning would take the movement out of
  the light for no gain; a wide arc is what contradicted the paint. `stretch`, `ink` and the
  tint gradient are untouched: the sun's *height* through the day was never the problem.
- **The floating rubbish's crescents lean too** (`shadow.gdshader` `sun_lean`/`sun_reach`,
  `LakeGrid.sun_lean`, pushed every frame from `Lake._push_daylight`). They used to be
  centred under their pieces with no sun in them at all, which read as the only thing on the
  lake the light did not reach. The lean is applied **in the vertex shader**, as a flat world
  distance rather than a per-piece height: the quads are built once per rebuild, and re-laying
  eighteen thousand of them every time the sun moved is the ~25-30 ms rebuild that layer
  exists to avoid. A piece of rubbish has no height to lean anyway — the whole shadow slides.
- Applied before the `DRY_ANCHOR` test, so a piece lying on the beach throws its shadow the
  same way as one afloat. The anchor decides whether a shadow *bobs*, not whether the sun is out.
- **A front-on painting sweeps its shadow, it does not shear it** (`Shade.sweep`,
  `Shade.Cast`, `Lake._shed_shade`, `Store._shade`, 2026-09-12). `Shade.lying` moves every
  pixel sideways in proportion to its height. That is right for a billboard standing on a flat
  edge — a figure, whose feet are a straight line — and it comes apart on the hut and the
  recycle box, which end in the near corner of the diamond their walls stand on. Against a V,
  exactly one pixel of the picture touches the anchor and every other column's shadow starts
  below its own base, so what draws is a slab of shade lying on the grass a little way off the
  building. **No anchor fixes this**: the ground line and the near corner were both tried and
  both wrong, because no single horizontal line is the contact line of a V.
- **What a solid casts is a sweep**: the ground it hides is its footprint smeared along the
  light, and that region touches the caster's own base everywhere by construction — there is
  nowhere for a gap to open. `Shade.sweep` uses the *silhouette* in place of the footprint,
  since a front-on painting is all the depth there is, so the hut's shadow is the shape of the
  picture rather than of the floor plan. On a thatched hut that reads: the eaves are its
  widest part and the ground round a hut is shaded by its roof. Per column and per opaque run
  within it, so a gap in the art is a gap in the shadow; each run's swept region is the convex
  hull of its four corners and the same four dragged, fanned into triangles.
- **Only the columns that reach the ground cast** (2026-09-12). An overhang is up in the air
  and the sweep has no idea there is a wall under it: dragged with the rest, the hut's
  right-hand eaves threw shade straight down onto open grass beside the wall — out on the
  *sunlit* side of the building, which is the one place a shadow cannot be. A column casts only
  if its lowest opaque pixel is within `ground` of the picture's deepest row, **the same rule
  `Skirt.hem` uses** to decide where a blade may stand, and there for the same reason. The
  columns that do cast carry their whole height, roof included, so the shadow is still as tall
  as the building and only as *wide* as what stands on the ground. `test_lake` guards that
  nothing of a sweep lands on the sunlit side.
- **Overlaps composite once, through a `CanvasGroup`** (`Shade.Cast`). Every column's smear
  overlaps its neighbours', and a few hundred translucent triangles laid over each other come
  out as a black core with a pale fringe. The group draws its children into a buffer and then
  draws that buffer once under **`self_modulate`** — `modulate` would reach the child and put
  the stacking back. The node sits behind its parent's own drawing (`show_behind_parent`) at
  the parent's z, so the caster covers the half of the sweep beneath it and the shadow still
  lies over the ground.
- **Rebuilt only when the sun steps** (`Shade.SWEEP_STEP`, 0.02), the bargain
  `Ground._sun_baked` already strikes: the geometry is laid out, not transformed, and the
  island redraws every frame. Measured on an RTX 5060 Ti, full lake: 2.33 ms mean standing and
  2.48 ms standing, worst frame 3.46 ms, no frame over 16.7 — inside the 8 ms bar.
- **`Shade.lying` is untouched** and stays the shadow for the angler, the dog, the ferry, the
  trees and the props. A figure's feet are a flat edge; the shear is right for them.
- **Any new front-on painting sweeps** — the four piers are the obvious next ones, as they are
  for `Skirt`. `test_lake` casts a V-shaped test picture and guards that the sweep encloses the
  picture it came from, which is the property a shear cannot have.
- **The shadow falls toward the camera, and only its sideways half can match the art**:
  `stretch` is always positive, so a cast shadow runs *down* the screen whatever the hour.
  Screen-down is the near side, so the sun is on the far side of the lake and cannot be put in
  the south without sending every shadow up the screen and behind the thing casting it, where
  none of it would be seen. What the southeast pass actually bought is the left/right half:
  shadows fall left, highlights are painted right. Don't try to finish the compass.

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
  `COLLAR_SCALE` 2.4 times the rubbish's rise and fall, one strip over the waterline arc,
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
- **Cargo sits in the hull, behind the sail** (2026-09-12): `tools/build_boat_sheet.py`
  writes a second sheet, `assets/boat_sail_over.png`, holding the sail alone frame for
  frame, and `Boat` draws the hull, then the load, then that over both — same polygon, same
  texture coordinates (`_hull_mesh`/`_hull_uvs`), so the two line up by construction. The
  overlay is a **copy** of the sail's pixels, not a cut, so the main sheet is whole and a
  missing overlay costs only the layering. What counts as sail is the cloth, the recycle
  mark and its edge, plus the spars and ropes that **touch** the cloth (`SAIL_CLOTH`/
  `SAIL_TOUCHING`) — the mast and the rails do not touch it and stay with the hull, which is
  right: a load on the foredeck is behind the sail and in front of nothing. **Grow that one
  step against the cloth, never against the running answer** — grown against itself it walks
  the outline down to the keel and the overlay comes out as the whole boat.
  This **supersedes the 2026-09-11 call** that the load draws over the picture, sails and
  all: that weighed hand-cutting sixteen headings into two layers, and the builder detects
  the cloth instead.
- **The hold fills bottom up, like the box it feeds** (`hold_spot`, 2026-09-12): the load
  lies in the well round the mast (`HOLD_FROM` 0.02 to `HOLD_TO` 0.20, `HOLD_LIFT` 0.55 hull
  heights — down in the boat, which only the overlay makes possible), `HOLD_LAYER` (4) pieces
  to a layer, each layer `HOLD_STACK` (0.3) hull heights above the last and tapered in, so a
  ferry with one piece aboard has it on the boards and a full one is heaped. `HOLD_SHOWN` is
  12; six read as a handful. Kept short of the bow: laid to the rail by the plane's
  projection it floated past the cut bow end on, because the frames draw that deck higher
  than the projection puts it.
- **The waterline foam wraps the hull** (`Boat.waterline_arc`, `COLLAR_BOW` 0.34,
  `COLLAR_STEPS` 8, 2026-09-12): the cut is one level line, so the collar laid straight along
  it was a bar under the boat — a hull leaning on one strip of the lake rather than floating
  in it. It is now a curve from one end of the cut, round the near side towards the camera,
  to the other. **Its ends are the cut's own ends**, so the fit to the painted hull is exact
  by construction and the foam cannot leave it at any heading — the load already floated past
  the cut bow once for trusting the plane's projection over the drawing, and white on open
  water would read worse than the bar did. The far half is not drawn: it would be above the
  cut, behind the hull drawn over it. Shallow by decision — a deeper curve reads as a puddle
  the boat is standing in rather than the line it floats on. The whole arc is then lifted
  `COLLAR_LIFT` (0.8) of the foam's own reach **up into the hull**, and `COLLAR_REACH` past
  the ends cut from 4 to 1.5: the cut is the bottom of the drawn hull, so a collar hung
  straight on it puts its entire lower band outside the sprite and the boat wears a skirt.
  Lifted, the froth sits in the hull's own bottom edge and only its tongues show past it.
  The froth also **carries further out to the ends** than a piece of rubbish's does
  (`COLLAR_SIDES` 0.45 on the shader's new `round_bite`, `COLLAR_TEAR` 1.45 on its tongue
  count): the half-ellipse that takes the reach away towards the ends is right for a
  ten-pixel lip and wrong for a hull, which is in the water at its ends as much as its
  middle. The tongue count rises with it, or what spreads is a stretched copy of the same
  shapes rather than more foam. `round_bite` defaults to 1, so every other collar in the lake
  is untouched.
- **The hull is drawn one art pixel low** (`HULL_DROP`, 2026-09-12): the picture, its shadow,
  the sail over it and the load in it all sit `Lake.ART_PIXEL` (2 world px) below where the
  anchor puts them; the waterline collar does not move, so the froth rides that much higher
  up the sprite and the boat sits down into its own foam rather than on top of it. **A whole
  art pixel, not half of one** — the sheet is nearest-filtered, and half a pixel puts it off
  its own texels and sets the planking crawling. `HullCollar.lay` takes each
  point's normal from the run either side of it, not from one segment, or every bend leaves a
  notch outside and an overlap inside. `test_lake` guards the bow and the fit at all sixteen
  headings. **This is not the ring `HullFoam` rejected** — that was the moving bow wave,
  where a ring read as a halo; this is the static line a floating hull sits on.
- **Hulls do not sit inside each other** (`Lake._part_the_fleet`, `PART_CLEAR` 1.7 tiles,
  2026-09-12): after every boat has moved, each pair closer than the clearance is eased apart
  by half the overlap each. **Not physics** — no bodies, nothing to fall out of step with —
  and not a rule the boats obey: the route is untouched, and a nudged hull sails on from
  wherever it now is, because every leg is planned from `tile_pos`. The same bargain
  `Boat._shove_aside` strikes with the floating rubbish. Two hulls exactly on top of each
  other part along a direction taken from their place in the fleet, not a roll, which would
  jitter. **Keep `PART_CLEAR` under the 2.4 tiles `_reberth` spreads the moorings by**, or a
  fleet at rest pushes itself out of its own row; `test_lake` guards both ends.
- **A ferry throws its load ashore** (`Boat._land_cargo`, 2026-09-12): the pieces a yard buys
  fly to it through the same `Haul` the yard already uses to load the boat — from the hull,
  which they follow as it lies at the berth, to `Dropoff.drop_point()`, which is `DROP_UP`
  (0.34) of the way up the yard's own painting, the deck its crates stand on rather than the
  feet of its posts in the water. **Paid for as each one lands**, not when the hull tipped
  them: a piece tagged with a `Dropoff` reaches `Lake._on_haul_arrived` as a sale, so the
  purse and the picture say the same thing — the rule `Haul` was built on. The berth is held
  until the volley is over (`_landing`, the second pass through `State.UNLOADING`), for the
  reason the loading one is: a hull that sails out from under its own cargo in mid-air is
  worse than no animation. With no `Haul` the sale still happens on the spot.
- **No wake and no rings**, by decision (2026-09-12): the pale wedge of slabs behind the
  stern with arcs shedding down it (`_draw_wake`, `_wake_arc`, `_wake_noise`, every `WAKE_*`)
  and the ripple rings dropped into the splash layer every `HULL_RIPPLE` are both gone. What
  a boat leaves is foam it drags, not water it sits on — see `HullFoam` below. Nothing else
  in the lake stopped making rings.
- **The foam is four streaks, and the trail is two of them** (`hull_foam.gd`, 2026-09-12):
  the pair that hug the hull are as they were; behind them a pair that start tucked further
  in (`TRAIL_HUG`), leave the hull sooner (`TRAIL_HUG_UNTIL`), open much wider
  (`TRAIL_SPREAD`), run `TRAIL_LONG` (2.5) half-lengths back and draw at `TRAIL_FADE`. The
  trail drawn first, so the bow's own wave sits over it where they cross. One shader, four
  strips, by decision: a separate stern system would be the wedge again under another name.
- **The hull wears the yard box's brown, and the sail its mark** (2026-09-12,
  `repaint_hull`/`MARK`/`MARK_AT` in the builder): the sheet's one hull-plank colour
  (122,66,34) is repainted to `Style.BOX` (120,89,64) — hull planks only, by decision; deck
  wood, spars, outline and the blue stripe stay as drawn — so the ferry and the recycle box
  it serves read as one wood. The square sail's lit face carries the box's recycle mark
  in `Style.BOX_BLUE`: **two curved arrows chasing round one ring**, one over the top and
  one under, each ending in a chevron head — the box's own mark (`assets/Recycle_Box.png`),
  round rather than the triangular one the HUD draws. Geometry on a unit canvas (`MARK_*`
  fractions: ring radius, bar thickness, head width and length, sweep and start angle),
  **decided pixel by pixel**: each frame pixel's centre is mapped back through the heading's
  parallelogram (`MARK_QUAD`: top-left, top-right, bottom-left, measured off the lit face's
  white rows, about seven tenths of the face wide, and **square, no lean**: sheared to the
  cloth's slope the ring in the quartering headings tilted into a flat ellipse, at a couple
  of rows' lean it still read squashed going south-west, and the art's sail is hardly
  foreshortened there, so the canvas starts a row or two lower, where the sloping top edge
  has left the whole width white, and sits level) and tested — distance to the ring, point-in-triangle for the heads — so in a
  quartering heading it leans and foreshortens with the sail, and an edge is a pixel on or
  off, not a blurred step. Then **clipped to the face's own white pixels**: nothing of it
  lands on the shaded head strip, the billow or the sky. **A one-pixel edge all round each
  arrow** (`MARK_EDGE`, the sheet's dark wood `d`, not its outline ink): every white pixel
  edge-on to a painted one, so the blue stands off the cloth (2026-09-12, after the plain
  blue was judged too faint). Frames
  0-3 and their mirrors carry the face; the side view (4, 12) shows only the billow's lens a
  few pixels wide and gets the mark squeezed into that, so a hint of the blue shows at every
  heading the painted side faces. The stern quarters show the sail's back and stay plain, by
  decision. Tried and rejected on the way (all 2026-09-12): a 15 px hand bitmap in the middle
  of the sail (a small odd knot); three bent arrows round a triangle, drawn at zoom and boxed
  down to size (ragged, heads bled into blobs); a flat box per heading that ran past the face
  (bled onto the cloth round it); a one-pixel slate outline round the outside only, left off
  the hole and the gaps by a flood fill (read as more bleed, and came out sparse once the
  arrows went round). **The pennant is gone** with it — the flag in the yard's colour at the masthead,
  `PENNANT_STAFF`, `masthead()`, and the json's `masthead` list — the yards' own tints tell
  the piers apart. **After re-running the builder, reimport** (`<exe> --path . --headless
  --import`): a `--path` run without the editor draws the stale `.godot/imported` texture.
- `assets/Blue_Boat/PixZels_Model_BlueBoat.json` that came with the sheet is a *different*
  boat (a pirate ship with a skull sail) and was no use as a reference; the edit is 2D only.
- **Retired, by decision** (2026-09-12): the Kenney watercraft pack and everything that
  baked it — `assets/kenney_watercraft-pack/` (7 MB of models), the sheet
  `assets/boat_frames.png` and its json, `tools/bake_boat.gd` and `tools/bake_boat.tscn`.
  They were kept until the sail boat had been judged in play; it has been, and it is the
  ferry. Gone from `docs/CREDITS.md` and from the art brief's licensing note with them.
  `tools/shot_boat.tscn` (desktop
  build, not `--headless`) saves three close crops of the ferry under way,
  `tools/last_boat_N.png`, for checking that the anchor puts the hull on the water. It loads
  the boat to `HOLD_SHOWN` — a full hold is the case worth looking at, an empty one shows
  nothing and a half one hides whether the heap clears the sail.
- **Open**: the bow-foam streaks (`HullFoam`, `HUG` at a constant `SQUASH`) sit inside the
  hull's silhouette in the side and end-on views and only show where they spread past the
  stern — as they did under the old hull. A heading-aware across scale would fix it.

### The Piers (`scripts/dropoff.gd`, `tools/build_piers.py`, sheet: `assets/piers.png`, 2026-09-12)
The four merchant yards are isometric pixel art **built from rules, not painted** (issue #10;
Richard: "rebuild in code, isometric", judged on a static mockup before anything in the
lake changed). Each is a jetty of planks on posts running `JETTY_OUT` (3) tiles from the
drawn waterline into the lake, one tile wide, bollards at the end, and a two-by-two tile
platform on the sand behind it carrying the recycle box, empty. No sign and no heap of the
material, by decision (both were drawn first and taken off: "just the pier and the empty
box"; they stay behind `WITH_SIGN` / `WITH_HEAP` in the builder). The yards are told apart
by their place on the bank and the tint the ferry reads.
- **Laid into the plane, not stood on it**: the deck is a 2:1 diamond on the grid, projected
  the way `Iso.tile_to_world` does at one painted px to two world px, so the four banks are
  four different drawings and nothing is mirrored. The old front-on paintings were drawn at
  four tenths of their size against a game where everything else is at 2.0 nearest.
- **The wood is the box's**: plank pitch five painted px, the box's own rows 12-16 (a lit
  line, two of body, a lighter one, a seam), the deck in its lit face's tones and the beams
  and posts in its shaded face's, the silhouette ringed in its edge colour (48,37,33). The
  box is `assets/Recycle_Box.png` pasted at one painted px to one, so it draws at 2.0 —
  four fifths of the island's crate (`Yard.ART_SCALE` 2.5). **A whole art pixel, by
  decision**: at one and a quarter the sheet would crawl on the grid.
- **The json is the contract**: `anchor` (the drawn waterline point on the jetty's
  centreline), `region` (the deck top and what stands on it), `under` (posts and beams),
  `shade_wet` / `shade_dry` (the deck top's silhouette over water / over sand, white),
  `jetty` and `platform` (deck-top outlines, `deck_up` above the plane), `posts_wet` /
  `posts_dry`, `landward`, `drop` (the box), `box`, `berth_end`. All four pictures are one
  size on one anchor. `Dropoff` reads all of it and measures nothing off the picture.
  `Dropoff.JETTY_OUT` must equal the builder's.
- **Two layers, by decision** (Richard, second pass: "objects in front of the poles must
  not clip through it"): `Dropoff.Under` draws the posts and beams at z 4, **below** the
  floating rubbish (5); the yard itself draws the deck top and the box at z 6, above it. A
  piece floating in front of a post is drawn over the post; a piece under the deck is still
  hidden by it. The under layer is also where the shadow, the collars and the sand live.
- **Mooring is one bearing** (`Dropoff.moor`): the foot is `Iso.basin_point(angle, 1)`
  plus `Lake.SHORE_LAP` outward (the drawn water's edge, not Iso's line); the axis is the
  tile axis nearest the way to the lake's middle (the four yards are cardinal); the berth
  lies `BERTH_ASIDE` (1.3) tiles beside the jetty's end **on the camera's side**, so the
  hull (z 12) drawn over the pier (z 6) is the hull in front of it. `Boat._plan_legs` lines
  up `APPROACH` (2.5) tiles out along the jetty before coming in and leaves the same way,
  as it does for the island's dock, so the ferry lies alongside rather than nosing in.
- **The shadow is the deck's own silhouette slid along the sun**: a flat slab's shadow is
  its shape moved by (`lean` x height, `stretch` x 0.5 x height) from its footprint, so the
  sheet's `shade_dry` and `shade_wet` are drawn in the day's ink under the posts, the wet
  one at the hull's gain (`SHADE_GAIN` 3, capped `SHADE_MOST` 0.7) because the day's ink is
  set for sand. **Polygons were the first pass and were rejected as blocky** — the
  silhouette carries the posts and bollards. **The wet shadow rides the swell**: the water
  is what it falls on, so it rises and falls by `LakeGrid._swell` at the jetty's x off the
  grid's clock (`Dropoff.swell`), the same swell the rubbish beside it bobs on. The box is
  swept by `Shade.Cast` from its base on the deck, like the island's crate.
- **Only the posts the deck leaves showing are dressed** (2026-09-12): a deck one tile wide
  carries a row of posts down each side and the far row is drawn under a deck that covers it
  completely, so dressing every post the geometry placed hung sand and foam on open beach a
  tile from any pole. The builder keeps a post only when its foot pixel survives into the
  `under` layer, and records it as `[middle, bottom, width]` in painted px.
- **The beam is keyed to the deck mask, not to pixel colour**: the post's body is painted in
  the same tone as the edge beam, so a colour test called every post a deck top and hung two
  more rows of "beam" under each one. Every pole was two rows longer than the foot the json
  recorded â€” which is why sand banked on that foot sat in the middle of the pole with its
  bottom showing below, and why walking down from a foot to find "the real bottom" walks
  into the beam. `draw.line` includes its endpoint; the drawn row is the bottom.
- **The sand is drawn on the sprite's grid, not the world's** (`Skirt._pixel`'s `snap`): the
  pier stands at a fractional world position, so its pixels are not on the art lattice
  everything else in `skirt.gd` snaps to, and sand snapped to the lattice landed up to a
  pixel off the wood â€” a dark line of pole under the heap however the rows were counted.
- **Foam and sand are decided against the lake, not read off the sheet**: at `_ready` every
  post's foot is tested with `Iso.shore_fraction` against the foot's own edge. Past it, a
  `WaterlineFoam` collar (`POST_COLLAR` 8 px half-width) **in front of the post** — behind
  a six-pixel post nothing showed — riding the same swell. Short of it, `Skirt.mound`: sand
  banked over the post's bottom rows, widest at the ground, solid (a gap in the pile is the
  dark pole showing through it), plus grains falling below it only â€” `spill` scatters a full
  ellipse, so half of every cloud went up the screen onto the deck step. The
  coast curves and the jetty does not, so the pair at the water's edge can fall either side
  depending on the bank; `test_lake` guards that at least the two pairs out along the jetty
  froth.
- **Retired**: `assets/Piers_Asset_Sheet.jpg`, `pier_*.png`, `tools/slice_piers.gd`,
  `export_piers.gd`, `debug_pier_coords.gd`, `Dropoff.PIER_OUT` / `PIER_WIDE` / `PIER_FOOT`
  / `DROP_UP`. The strand rubbish still fills the tiles under a jetty and is hidden by it
  (the dog fetches it from under the deck); clearing the jetty's footprint in `LakeGrid` is
  open.
- **Probe**: `tools/shot_piers.tscn` (desktop build) pans to each yard and saves
  `tools/last_pier_<kind>.png` plus `last_piers.log` (foot, berth, collar and spill counts,
  the sun). The mockup the design was judged on is `tools/last_piers_mockup.png`, rewritten
  by every builder run. **Reimport after running the builder.**

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
- `scripts/skirt.gd` — baked painted grass tufts and sand spill round the shed and the box
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
