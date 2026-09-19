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
- The ferries carry what waits in the crate to the yards and sell it; the dogs fetch small
  pieces near the island and off the bank. Both are upgraded in the shop.
- **No machines, no drones, no continuous drain** (Richard, 2026-09-18): this section used to
  say machines and drones drained a `pollution` float over time. That was never built and
  never the design. `pollution` moves only when a piece leaves the water — by the net or by
  a dog (`Lake._on_net_caught` and `_dog_brought_back`).

### Economy (Two-Layer)
Why two layers? The player's hands are what clear the lake; the helpers are what turn the catch into money while the hands are busy. A meter that drains by itself is a progress bar with a button.

**Manual layer**: Hold-to-haul collects `TrashObject`s, knocking chunks off `pollution` (resolved per-object).

**Idle layer**: ferries selling the crate's backlog and dogs fetching on their own. Nothing reduces `pollution` passively.

**Visual link**: the lake clearing up **IS** the progress bar — not a separate number. As of the per-tile filth map (`Lake._build_filth_map`), the water shader's colour reads that map, not `pollution` directly: a bay just cleared reads blue on the spot while the next one over is still soup. Since 2026-09-17 the map is graded by how much rubbish an area still holds, in five shades, so a bay lightens as it is worked rather than when it is empty (see Pixel-Art Water). `pollution` is the map's fallback (read only where `filth_mapped` is 0, i.e. before the first map build) and still drives `sparkle` at the finished state.

### Progression
Treat it as a deliverable, not polish: the clean state must **gain density** (plants, surfacing fish, birds, clarity) — Richard flagged this as the weakest part of the loop.

**Build order** (Richard's deliberate choice):
1. Water feel and drag mechanics **first**
2. Progression-curve numbers **after**

This inverts the notes' advice but keeps fun physics-first.

### The Shop Reads (2026-09-17, `/grill-me` with Richard, `ui-ux-pro-max` review)
A UI/UX pass over the upgrades shop. Full review, measurements and the mockups it was picked
off: `docs/ui/shop-review.md`. **Layout and wording only — no price, curve or mechanic moved.**

**What was wrong, measured** (`tools/probe_shop_text.gd`, headless, Bungee at the real sizes):
a row's writing gets **108 px**, the same on every monitor (`BOARDS_WIDE` caps at 1180, so a
21:9 screen bought the shop nothing but more empty table). **47 of those went on "Lvl 20"**.
At a fresh save **12 of 17 value lines were cut with an ellipsis at 11 px**, 9 of 17 names
dropped their level at the top of their track, and "Recycle Bonus" was cut inside its own
name at every level. An unaffordable row's value line read **1.82:1** contrast at 11 px
(`BOARD_INK_DIM` lerped a quarter into the face), against the intent stated in its own
comment — "drawn back rather than hidden: the point of a shop is knowing what is coming".
- **Four boards, renamed, no article**: `NET` / `BOATS` / `DOGS` / `LUCK`. The market board is
  gone; **Lucky cast and Double cast moved off the net's board** to stand with Bonus yard and
  Pigeons, so the boards are **5/4/4/4** instead of 7/4/4/2. The luck board keeps the coin as
  its head.
- **Rows are grouped by what they change** (`ShopSkin.GROUPS`, a carved rule and a small
  heading): boats *The run* / *The fleet*, dogs *The pack* / *The trip*, luck *On a cast* /
  *At the yards*. **A board with one group draws no heading** — one heading over everything
  says nothing — so the net's five rows run on. `UPGRADE_ORDER` is the order tracks *load*
  in and was never a reading order; `GROUPS` is. A row no group claims is drawn after them
  rather than dropped, so a new track appears before anyone remembers to list it.
- **Every name is unique across all four boards.** Two rows called "Speed" meant the reel and
  the sail; "Haul" / "Hold" / "Fast Sell" were three near-synonyms for three unrelated
  mechanics. Now: net Speed → **Reel**, net Haul → **Catch**, ferry Speed → **Sailing**,
  Fast Sell → **Loading**, Extra ferry → **Fleet**, Fetching → **Fetch**, Strong Dogs →
  **Carry**, Recycle Bonus → **Bonus yard**. `test_lake` guards uniqueness across the shop,
  not within a board, because across is where the collisions were.
- **One value grammar**: two bare figures either side of `Lake.ARROW` (U+2192, which Bungee
  has — `tools/probe_shop_glyphs.gd`), a **prefix** on the first and a **suffix** on the last,
  each said exactly once: `100 → 135%`, `Tier 2 → 3`, `$26 → 30`, `12 → 9s`. A maxed track
  shows one figure wearing both. The bracket the value used to carry — "(+55% next)" — is
  gone, and so is the word "next" with it.
- **No nouns in a value** (2026-09-17, second pass with Richard): "a cast", "aboard", "a
  trip", "dogs" and "boats" are all gone — the row's name and its "?" say what is being
  counted. `%`, `$` and `s` stay, being marks rather than words; **"Tier" stays**, being a
  concept of the game with its own names (Light / Small / Medium / Heavy / Bulky) rather than
  a unit of the row.
- **A scaling track reads as a share of its own level 0, not as the rise over it**
  (`_pct_at`): `100 → 135%` at the start, `900%` at the top, where it read `+0% → +35%` and
  `+700%`. **The basis and the missing sign go together.** Two three-digit figures either
  side of the arrow came to 118 px against a row's 87 and cut; dropping the `+` to save that
  width would have been a lie, because `385%` claims 3.85x where the stat is 4.85x. Measured
  from the base it needs no sign, is the same width, and is true.
  **The odds and the bonus are not shares of a base** and stay bare percents — `0 → 6%` for
  Lucky cast and Double cast. Two kinds of percent on one board, told apart by one starting
  at 100 and the other at 0.
  **Dropping the nouns fixed almost nothing on its own** and it is worth knowing why: `17 →
  18 a cast` went 102 px to 52, but that row was never the one deciding how small the shop
  had to be drawn. The widest line was a rate track with no noun in it at all. The nouns went
  because they were noise; the basis changed because it was the width.
  **Widest value line: 118 px before, 87 after**, against the 87 a row leaves.
- **The level moved into a rail** (`ShopSkin.RAIL_WIDE`, `rail_of`, `help_box_of`): one sunk
  column down the left of every row, the "?" answering for its top half and the level's
  **bare figure** standing in its bottom. "Lvl" is a word the row does not need and a
  translation would have to carry, and the rail is what says the figure is a level. It also
  turns the 15 px corner tag — the smallest target on the board — into a full-height one.
- **The writing is readable in both states.** The value's quarter-lerp towards the face is
  gone (the size ladder already says which line is the heading), and an unaffordable row inks
  in `ShopSkin.INK_DIM` (**5.01:1**, against `BOARD_INK_DIM`'s 2.19:1). **Shop-local on
  purpose**: `BOARD_INK_DIM` also inks the shed's shelf and the settings board and the same
  fix is owed there, as its own pass. State is carried by the price tag and by **the lit edge,
  which only an affordable row draws** — the two faces are 1.30:1 apart in luminance, so told
  apart by hue alone they are one face to a red-green colourblind player.
- **The pricing plate is no longer capped by the tallest board.** It used to fit only while
  the net board stood three rows taller than the middle two; grouping levels them (the gap
  goes 146 px to 10). It hangs below that line now and the block — boards and plate together —
  is what gets centred. It stands under whichever two boards are in the middle of `BOARDS`.
- **The recycle bonus is on the plate, not in its row** (Richard, same day): the boosted
  material's column is lit and wears the **same four-point gold stars `Dropoff.Shine` puts on
  the boosted box out at the pier**, so the shop and the lake say it with one mark. The row
  sells a multiplier, so the row says the multiplier. **The bonus carries no figure of its
  own**: `_mean_pay_of` goes through `piece_pay`, which already multiplies the boosted kind —
  so the plate has been printing the boosted price for as long as the bonus has existed, with
  nothing on it saying why the number moved. All this adds is the saying. **The bonus's line
  is reserved whether or not one is running**, or the plate grows a line every thirty seconds
  and re-centres the whole shop with it. Stars sit at fixed spots off one seed: a plate that
  twinkles is a plate that redraws every frame.
- **Some rows still cut, by decision** (Richard: "we'll have to accept some text cutting at
  late game"). Measured honestly, it is **8 rows mid-run**, not 2: two names — Double cast
  (115 px against a row's 87) and Bonus yard (108) — and **six rate tracks whose middle is
  longer than either of its ends**. `+0% → +35%` fits and `+700%` fits, but `+385% → +420%`
  wants 118. Down from 21 before the pass, and every one of them now falls back to `TEXT_TINY`
  with two readable figures rather than to a sentence with its tail missing.
  **`tools/probe_shop_text.gd` measures level 0, mid-run and maxed** for exactly this reason:
  measuring only the two ends said two rows cut and was wrong. The levers, none taken:
  `RAIL_WIDE` 26 (worth ~6 px), `TAG_SHARE` 0.34 (a four-figure price needs ~55 of its 69),
  and the names.
- **Out of scope, by decision**: tabbed and two-up layouts (mocked, rejected — two-up was the
  only one that survived the endgame and was not picked); hold-to-buy (one click, one level
  stays); rewriting the 23 blurb sentences; a font with Cyrillic or CJK; the shelved tracks;
  and moving the rows to Control nodes — **the shop stays hand-drawn `_draw()`**, which is
  what makes the cut-to-fit machinery worth having.
- **Localization**: nothing here is `tr()`-wrapped yet — the game has one `tr()` call in it
  (`dropoff.gd:210`) and no `locale/`. What this pass buys is **room and shape**: the arrow is
  not a word, the unit is said once, the level carries no label, and no row spends 43% of its
  width on a footnote.
- **Probes**: `tools/probe_shop_text.gd` (headless, what cuts and where),
  `tools/probe_shop_glyphs.gd` (Bungee's separator glyphs), `tools/shop_mock.gd` +
  `tools/shot_shop_mock.tscn` (desktop build — the three layouts and the three ways of showing
  the bonus, kept as the record of what was judged). `test_lake`'s `_stage_shop_shape` guards
  the titles, the unique names, every row being claimed by exactly one group, the heading
  rule, the grammar, the plate's room now the boards are level, the bonus reaching the plate
  without a figure of its own, and both inks clearing 4.5:1.

### The Boats Run Ahead (2026-09-18, `/grill-me` with Richard, issue #23; scope locked)
Richard's playthrough: the boats were too slow and too dear to keep up with the net and the
dogs, the net's prices jumped from cheap to dear, Catch (Haul) and Strength came too easily
for what they do, and Strength is the game changer that belongs in the middle of a run.
`docs/scope-lock.md` is the in/out list this pass closes on. **Nothing new after it.**
- **A focused clear is 70 to 80 minutes.** Issue #23's "2-3 hours" is superseded.
- **Supersedes, in The Shop Balance Pass below**: "Haul and Hold are one track twice", the
  20-level Haul/Hold, Ferry speed 4 to 36, every price, the 69-minute clear, and "hidden,
  not deleted" — the shelved code is deleted (see the end of this section).
- **The boats stay slightly ahead of the net and the dogs, all run.** The HUD's *Waiting*
  figure under about two ferry loads, a spike draining within a minute. In the sim: the
  fleet's capacity 1 to 2.5 times what the net lands (`links` band in `build_shop.py`);
  82% of the run inside it, the box peaking at 24, where the old pass had it at 400-2000.
- **Hold is two casts at every level**: Hold 8 + 2 a level, Catch 4 + 1, **eight levels
  each** (24 and 12 at the top), and Hold is the cheaper of the two at every level.
  `test_lake` guards both. The level-0 hull sails at 8 (was 4), to 40.
- **Catch is eight dear levels because it is what paces the run.** With the boats ahead,
  nothing but the net's own levels decides how fast the lake clears, and a cast brings home
  `min(Catch, swept x density)` — Catch binds from about minute five on. At 20 levels to 24
  no price could hold the clear over 50 minutes; at 12 to 16 it was 56; at 8 to 12 it is 64.
  **The levers not pulled** (Richard: Reel, Range and Width are fine): their caps, the luck
  odds, `k_aim`.
- **Every price is fitted to a schedule** (`build_shop.py` `SCHEDULE`, carried in `shop.json`
  as each node's `schedule`; `price_shop.py` steers each level to its minute and keeps each
  track geometric): **Strength at about 10 / 20 / 30 / 40 minutes** (sim: 12.8 / 18.0 /
  31.9 / 40.3); the luck tracks from minute 3 to 5 and steadily through the climb, as
  Strength's teaser; Hold and Sailing ahead of Catch all the way; Range finished by about
  40. **Range runs ahead of the clearing on purpose**: scheduled to 48, its top levels
  priced past what the run could earn, the water in reach emptied, income stopped and the
  sim soft-locked at 82% cleared.
- **The ladders are flatter and start higher** (Width 450 x 1.21, Reel 450 x 1.18, Range
  400 x 1.11), which is the fix for "cheap, then suddenly dear"; Catch is 1000 x 1.82 and
  Strength 5000 x 2.43. **Pinned by hand** (`price_shop.py` `BASE_MOST`): the first extra
  hull 200 (Richard, 2026-09-14), Hold from 40, Sailing from 60 — the boats are forgiving
  early. `test_lake` guards the 200.
- **Three things the pricer had to learn** (all in `price_shop.py`, with the why): a level is
  priced off the **running peak** of income, not the sample — income falls away as the lake
  empties and late levels came out cheap and were bought early; a level is **capped at
  `MOST_GAPS` gaps of income** at its own minute, or it runs away; a level never bought
  because the run ended first is **not cheapened** — cheapened, the tops of the long tracks
  dragged their whole ladders flat.
- **Loading and Carry are in the sim** (`SPEC`, `boat_volley_cut` on the per-piece term of
  `ferry_trip`, `dog_tier` gating the dog's pools), so a re-run no longer drops them.
- **Sim**: focused 64 min, casual 110 min (the band asks 68-82: a WARN, left for the logged
  run to settle, because the bot never stops casting and the calibration is from a tree
  run). `python docs/progression/shop_schedule.py` prints bought-against-wanted per track.
- **The player's own run writes a playtest log** (`scripts/play_log.gd`, `PlayLog`,
  `user://shop_playtest.log`, JSON lines: session with every level, purchase with cost and
  Waiting, progress every 30 s, cast, shed open/close; `Lake._play` is the run's clock,
  saved as `play`). **Only the game's own lake on the player's own save path writes it**
  (`Lake._logs_play`): `tools/shot_menus` hung its lake off the root with no save path of
  its own, wore the front over every board it photographed and wrote two lines into the
  real log before it was fixed. **Turn the log off before a release export.**
- **The first logged run** (2026-09-18 evening, `docs/progression/playtests/
  2026-09-18_shop_run1.log`): **64.5 min** against the sim's 64.2, Strength at 15.4 / 24.6 /
  32.7 / 39.9, the first 20 minutes' Waiting at 31 or under. What it showed the sim had wrong:
  **minutes 5 to 15 stalled** (0.6 pieces a second, income flat at about 20/s — the sim has
  three times that; the tier-0 water in reach ran dry on Range 2 to 5 while 5000 was being
  saved for Strength), and **Waiting ran 195 to 814 from minute 22 to 48** because the fleet
  tops out at about 6.7 pieces a second and the net lands 7 (Richard: the pile-up is fine, it
  drains at the end). 43.5k unspent at the end; Pigeons untouched until minute 50 with 196
  birds netted; eleven dog levels bought in one visit at minute 21.
- **Richard's tweaks off that run, priced by hand and pinned** (`price_shop.py` `HAND`, the
  loop leaves them alone): Strength **3500 x 2.74** (the first tier was too dear; the top
  stays at about 72k, where he maxed it at 40 min); **Hold 8 + 3 a level, 32 at the top**
  (the boats carry more a trip; fleet capacity about 8.9 a second); Range **150 x 1.27**
  (cheap to start, dear to finish — it crosses the old ladder at level 8); Pigeons **120 x
  1.8**, "really early game"; the Pack **200 x 2** and the rest of the dogs dearer (Fetch
  500 x 1.8, Keenness 600 x 2.2, Carry 1200 x 2.2). Sim with them: 59.7 min, Strength 9.7 /
  18.4 / 24.5 / 32.6 — read those against the sim's early game being too rich. **The late
  surplus and the run's length are left for the next session**, by Richard's call.
- **Owed to close #23**: Richard plays one fresh logged run; the log is replayed into the
  sim's calibration (`k_catch_scale`, `k_aim`, the dogs), one more `shop_loop.sh`, times
  recorded on the issue and in `docs/scope-lock.md`.
- **No `SAVE_VERSION` bump**: a saved level over a track's new cap is clamped on the way in
  (`_saved_level`), and a stale `sell_N` or `skimmer` key is simply not read.
- **Deleted, not shelved** (same day, Richard: "delete everything shelved"): tree mode
  (`upgrade_tree.gd`, `tree_screen.gd`, `tree_log.gd`, the menu's two doors, the tree save
  slot, `Dog.reach`/`strand_first`/`strand_speed`, `test_tree`, `shot_tree`,
  `lake-tree.json`/`.md` and the tree's pricing scripts), the skimmer (`Boat`'s skim fields,
  sweep and drawing, `Lake.skim_*`, `BuySkimmer` in `main.tscn`, the probe's skim phase) and
  the five sell-by-tier tracks (`sell_N.tres`, `tier_pay`, `SHELVED`, `MAX_LEVELS`,
  `PRICES`). `calibration.json` stays: the shop's model reads it. **The siege is not
  deleted** — it is a whole level (`siege.gd`, charms, wards, laid nets) and its cleanup is
  its own job; nothing routes to it.

### The Shop Balance Pass (2026-09-14, `/grill-me` with Richard; supersedes the tree)
**Superseded in part 2026-09-18 — see The Boats Run Ahead above.**
Richard's call: **the tree is set aside, the shop stays**, and the shop is rebalanced around
these rules. Everything below the tree section about the tree still describes code that is in
the repo; none of it is on the menu.
- **Hidden, not deleted** (`Menu.TREE_DOORS` false, `Lake.SHELVED`): the tree's two menu
  doors, the skimmer, and the market's five sell-by-tier tracks. Shelved tracks have no row,
  are not counted by `_affordable`, `_buy` refuses them and `tier_pay` is 1; their levels
  still save and load. Flip `TREE_DOORS` to play the tree again.
- **Haul and Hold are one track twice** (`net_hold.tres` = `cargo.tres`, same value and same
  price at every level, `test_lake` guards): one cast fills one ferry. 4 + 1 a level, 24 at
  the top. Richard chose this over Hold = 2 x Haul after the pushback; **the sim says the
  ferry is the ceiling** under it (see below).
- **Caps**: the big tracks stop at 20 levels with round steps — Width 0.6 + 0.21 a level to
  **4.8 tiles (+700%)**, wider stutters and looks bad (Richard); Range 4 + 1.6 to 36 (the
  farthest shore is 35.6, `probe_reach`); Speed (reel) 3 + 1 to 23; Ferry speed 4 + 1.6 to
  36; Haul/Hold as above. The simple ones are short: Strength 4, Extra ferry 3 (**4 ferries
  at most**, `MAX_BOATS`), Pack 3 (**4 dogs at most**, `MAX_DOGS`), Fetching 4, Keenness 3,
  Recycle Bonus 8, Pigeons 8, Lucky haul 10, Double cast 10, Fast Sell 4, Strong Dogs 4.

### Fast Sell and Strong Dogs (2026-09-17, `/grill-me` with Richard)
Two more shop tracks, one on each of the ferry's and the dog's boards.
- **Fast Sell** (`boat_volley.tres`, `Lake.boat_volley_gap`, `Boat.volley_gap`) is the
  **`Haul` volley at both ends of a ferry's run** — loading out of the island crate and
  landing the hold in a yard's box. It is not the sail speed: `boat_speed` ("Speed" on the
  same board) stays exactly as it was. Richard asked for "the speed objects move from boat
  to pier boxes", and the loading volley came with it because they are the two waits a hull
  has and they read as one thing.
- **It tightens the stagger only**, by decision: every piece keeps its own `FLIGHT` (0.62 s)
  arc and they merely leave closer together, so a fast ferry pours its hold instead of
  trickling it and nothing is ever drawn whizzing. `Haul._gap` and `volley_time` take a
  `gap_scale`; the net's throw into the island crate passes none and is untouched. **The
  floor is `FLIGHT`** — the whole load in the air at once, which is the clump the `STAGGER`
  constant exists to prevent — so the track stops at ×0.4 rather than at nothing. 4 levels,
  ×1.0 to ×0.4: at a 24 hold a volley goes 1.72 s to 1.06 s an end, about 1.3 s off a ~14 s
  trip. The row reads as "%d%% faster" (0 / 18 / 43 / 82 / 150), because a row saying the
  gap is 40% of what it was is a row about the code. Stored as a **cut** in the `.tres`
  (0 → 0.6) the way `dog_wait` is, so the curve counts up like every other track.
- **Strong Dogs** (`dog_strength.tres`, `Lake.dog_carry_tier`/`dog_carry_wide`,
  `Dog.carry_tier`/`carry_wide`) raises the pack's weight tier **and its mouth's width
  together**, by decision. Tier alone buys almost nothing: `def.size.x` is the art's own
  width at `SPRITE_SCALE`, so `CARRY_WIDE` 16 means an 8-pixel drawing, and lifting
  `CARRY_TIER` 0 → 4 on its own opens exactly three kinds (`plastic_cup2`, `rubber_disk`,
  `rubber_ball`). 4 levels, matching the net's Strength: tier 0 → 4, width 16 → 32
  (`Lake.DOG_WIDE_STEP`), which is **everything in the catalogue but `plastic_toy`** — at
  31 art px it would still hang half a dog's length out of its mouth at `CARRY_SCALE`.
  `Dog.CARRY_TIER`/`CARRY_WIDE` are the level-0 defaults now; the values are pushed by
  `_push_dog_numbers`, so a `Dog` with no lake behind it fetches what it always did.
- **No `SAVE_VERSION` bump**: both live in the save's `levels` dictionary and a missing key
  reads as level 0. **Tree runs get neither** — `boat_volley_gap` returns 1.0 and the dog's
  two getters return the constants.
- **Priced by hand** (Fast Sell 300 × 2.2, Strong Dogs 120 × 2.6), by Richard's call: "hand
  price, we'll balance later". Every existing price is untouched and the 69-minute clear is
  now an estimate. **Both tracks are in `build_shop.py`'s `SPEC` since 2026-09-18 and priced by the loop.** Before that: **neither track was in `docs/progression/build_shop.py`'s `SPEC`**, so a
  re-run of `shop_loop.sh` would drop them — add them to the model and to `ferry_trip`'s
  `k_ferry_per_piece` (Fast Sell) and the dog's mean pay (Strong Dogs) before re-running.
- **Out of scope, by decision**: re-running the pricing loop, `DWELL`, the approach legs,
  `SPREAD`, `boat_speed`'s curve, tree nodes for either, and `plastic_toy` in a dog's mouth.
- `test_lake`'s `_stage_new_tracks` guards both tracks loading, a blurb on every track, the
  gap sliding to 0.4 and never under `FLIGHT`, an unscaled volley being untouched, every
  hull and every dog being told, the top level opening the whole catalogue bar
  `plastic_toy`, and both levels surviving a save.

- **The pack** (`dog_count.tres`, "Pack" on the dog's board, `Lake._add_dog`/`_fit_dog`/
  `_dogs`): three more dogs, the same sprite, wired like the first, sharing one Fetching and
  Keenness level. **Claims** (`Dog.claims`, static, `_aim_at`/`_release`): a stick one dog is
  swimming for is skipped by the others' sampling, cleared on the take, the give-up or the
  settle. Not a lock — the net and the ferry still take what they like. Petting reaches the
  nearest dog (`_dog_in_reach`). The tree run keeps one dog.
- **Heavier tiers always pay more** (`EconomyConfig.tier_pay_step` 0.5, `piece_pay`): a piece
  pays its flat-plus-filth times 1 + 0.5 x tier, and `test_lake` guards it piece by piece —
  the cheapest of every tier over the dearest of the tier below. `rubber_disk` and
  `rubber_ball` went to pollution 3.0 to sit inside their tiers' bands; a new kind's
  pollution has to keep that order.
- **`SAVE_VERSION` 9**, old saves refused (Richard starts fresh). **10 since 2026-09-16**,
  with version 9 read rather than refused — see Free Placement below.
- **Priced by the sim** (`docs/progression/build_shop.py` -> `shop.json`, `price_shop.py`,
  `shop_loop.sh`, report in `shop-report/`): the tree's calibration (`k_catch_scale` 1.7 from
  Richard's run) on the shop's tracks. `price_shop.py` gives every level a minute of the run
  (a track's levels spread evenly to `LAST_BUY` 48) and steers it there pass by pass, fitting
  each track back to `price_base x price_mult ^ level`; pricing at income x gap off the bot's
  own purchases ran away (a cheap track got cheaper) and pinning to income at the scheduled
  minute front-loaded everything by 18 min. Haul/Hold's multiplier was then set to 1.5 by
  hand (the fit's 1.69 put 420k on each tail). Result: the focused bot clears in **69 min**,
  brisk buys early (median 15 s), income climbs to about 280/s by 48 min. **The first extra
  ferry costs 200** (Richard, same day: "200 at most"; `fleet.tres` 200 x 5, so 200 / 1000 /
  5000, bought at about 2 / 6 / 10 min in the sim, clear 62 min) — set by hand, and
  `shop_loop.sh` would move it back; re-pin it after any re-run.
  **The ceiling is the ferry, by the arithmetic**: at equal Haul and Hold, four hulls carry
  4H / (8.4 + 206/speed + 0.06H) a second against a net at about 0.4H (calibrated), so the
  boats cannot keep up at any speed; the box peaks at about 400 in the sim and income is
  flat from about 25 min. Hold = 2 x Haul (8 + 2 a level) balances at the top and was
  simulated too (cleared faster, the strand stalled the bot). `cargo.tres`'s curve is the one
  number to change if Richard revisits it; re-run `shop_loop.sh` after.
- **Out of scope, by decision**: deleting the tree or skimmer code, new dog art, per-dog
  rows, idle or helper upgrades, tree-mode balance.

### Tree Test Mode (2026-09-12, `upgrade_tree.gd`, `tree_screen.gd`, `tree_log.gd`)
**Deleted 2026-09-18** (The Boats Run Ahead): none of the code this section describes is in
the repo. Kept as the record of what was tried and what the tree taught the shop's pricing.
**Set aside 2026-09-14** (see The Shop Balance Pass): the doors are hidden, the code stays.
The proposed upgrade tree (`docs/progression/lake-tree.md`, designed with the
`incremental-progression` skill) is playable as **its own game mode** before it replaces the
shop. Richard's call: build it beside the shop, test it, then decide.
- **Menu**: "New game (tree)" / "Continue (tree)" go through `MainMenu.reload_asked` and
  `Lake._reload_as`, which sets `Lake.start_tree` (read once, like
  `start_fresh`). Shown in every build, by decision; clean it out before a release export.
- **Separate save slot**: `Lake.TREE_SAVE_PATH` (`user://lake_cleanup_tree.save`). A save carries
  `"tree"`, and a tree run and a shop run each refuse the other's file.
- **Numbers come straight from `res://docs/progression/lake-tree.json`**, the simulator's own
  config, so what is played is what was simulated. Don't copy them into `.tres`. The export's
  `*.json` include filter ships the whole `docs/progression` folder; settle that at export.
- **Stats are a full recompute** from base and owned nodes (largest set, then add, then multiply),
  the simulator's rule. `Lake.net_radius()` and the other getters, plus `fleet_size()`, read
  `_tree_stats` when `tree_mode`.
- **Start state**: net only, the file's `startMoney` (50). The scene's ferry is hidden and stopped
  until First Ferry; later hulls are built by `_sync_tree_world`. The dog is hidden, stopped and
  can't be petted until Adopt the Dog. No skimmer. `Dog.reach` / `strand_first` /
  `strand_speed` are the tree's dog knobs; at their defaults the dog is exactly today's.
- **Screen**: the Upgrades button opens `TreeScreen` instead of the shop board. It's a plain node
  graph like Master Healer Kale's (Richard: not the drawn boards). Auto-laid out from the parents,
  so a tuning pass needs no positions. It never frames below `FRAME_LEAST`; drag to reach the rest.
  **Laid out in rings by depth, a wedge per category** (2026-09-14, Richard: too clustered, lines
  crossing): a node's ring is its longest path from the root, each category's wedge is as wide as
  its most crowded ring needs, wedges are ordered so linked categories sit side by side (the dog
  between net and ferry), each ring is ordered by its parents' angles and spread over
  `RING_SPREAD` of its wedge at least `NODE_GAP` apart. Edges sweep round the rings rather than
  cutting chords; cross-category ones are dashed and run along the wedge border. Nodes and their
  writing scale with the zoom down to `DRAW_LEAST`. `test_tree` guards the ring gap and that no
  two edges within a category cross. `TREE_SHOT_ALL=1` on `tools/shot_tree.tscn` buys the whole
  tree and frames all of it.
- **Playtest log**: `user://tree_playtest.log`, JSON lines (session, purchase, progress every
  30 s, cast with seconds since the last, shed open/close), timed by the run's own play clock.
  Read it to recalibrate the sim's `k_aim`, decorating share and real purchase schedule.
- **Playtest log** also records `birds` (netted so far) in each progress line, for calibrating the
  pigeons (2026-09-14).
- **Tests**: `tools/test_tree.tscn` (headless, 53 checks) and `tools/shot_tree.tscn` (desktop
  build, `tools/last_tree.png`). `test_lake` still covers the shop run.
- **Second pass** (2026-09-14, grilled with Richard; full design in `lake-tree.md`): focused clear
  about 90 min, buys brisk at the start and slowing to the end, the boats nearly keep up with the
  box, the dog mid-game (needs Iron Pull and Second Ferry), the net as **rings** of Line / Bag /
  Mouth plus a luck slot, each joined by a strength node needing **any two** of its ring
  (`requireCount` in the tree file, read by `UpgradeTree.is_visible` and by the skill's `sim.js`).
  **Lucky Haul and Double Cast** are ring slots, **Recycle Bonus** is on the ferry, and the
  **Pigeons** are a fourth tree, "bonus": the tree stats `lucky_odds`, `double_odds`,
  `recycle_bonus` and `bird_worth` feed `lucky_chance`, `double_cast_chance`, `recycle_bonus` and
  `bird_pay` in a tree run, and the bonus clock starts with the first node giving a bonus
  (`_sync_tree_world`). Sell-by-tier stays out: a tree run still sells every tier at par.
- **Range reaches every shore** (2026-09-14): `tools/probe_reach.gd` (headless `--script`) measures
  the farthest shore from anywhere the angler can stand, 35.6 tiles; Longer Line IV reaches 35.9.
  Re-run it if the island, the bank or `Angler.WALK_LIMIT` change.
- **The ferry was mis-measured**: `tools/probe_rates` loaded one material a run, so every run was a
  one-stop trip. It now loads mixed holds; a real run is 8.4 s + 206.6/speed + 0.059 s a piece,
  about three times what the first tree was priced on — the box pile-up in the first playtest.
- **Pricing**: `sh docs/progression/loop.sh` (build, `price_by_income.py`, sim, `check_tree.py`).
  `price_to_schedule.js` oscillated on this tree and is not used.
- **Third pass** (2026-09-14 afternoon, grilled after Richard's full run; see `lake-tree.md`): the sim is
  **calibrated to his run** (`replay_playtest.py` and the skill's new `replay` bot policy: catch x1.7,
  `k_catch_scale`), a real clear of about 70 min that **spends down** (his run ended on 16,426 unspent;
  `price_by_income.py` puts the surplus on the late nodes, `check_tree.py` guards it within 5%). **The dog
  is first**: 100 sludge after First Ferry, and the net's first ring needs it (supersedes "mid-game"); its
  training and the pigeons (now from Heavy Lift) are gated by strength nodes. Deeper Hull IV-V and Trim
  Sails IV added; **Fast Reel replaces Bank Reach**; **reel scattered** (same day: base 6, +1.5 to +3 on every strength node, +1 on every luck slot, on top of the Lines); reel and width a quarter stronger, the bag smaller
  (+2 a node) because the calibrated model showed the bag sets the clear time. On the tree screen the
  strength nodes draw at `POWER_SIZE` with a gold rim, and a strength node gating another category's node
  is a gold badge on that node (`TreeScreen.is_badge`) rather than a dashed arc.

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
- **That band did nothing at all until 2026-09-17.** `_lightness_span` was handed
  `Vector2(max_lightness, min_lightness)` under the names `heaviest`/`lightest`, so `span`
  came out negative and `half` with it — every slot's `lo` was above its `hi`, the filter
  matched nothing, and **every slot in the lake fell through to a uniform roll over its
  material**. Depth pointed at nothing, in either direction, anywhere. `lightness` is
  buoyancy (higher floats), the two ends are named `floor_end`/`surface_end` now for which
  end of the water they are rather than for how heavy they are, and `test_lake` asks the
  lake itself — over the deep stacks, what floats is lighter than what is under it.
  **The floor end still barely bites**: one def (`wood_box2`, 0.6) stretches the span and the
  next heaviest thing is at 1.4, so the band around the floor's target lands where almost
  nothing lives. The surface end is crowded and works. Percentile ends would fix the other
  one; not done.

### What the Surface Shows (2026-09-17, `/grill-me` with Richard, `LakeGrid._dress_surface`)
The top of a stack is the whole first impression of the game, so it is chosen rather than
left to the roll. **Out of the pieces that stack already holds**: the slots under it are
rolled as before and the pick is swapped with whatever the roll left on top, so a tile ends
up holding exactly the pieces `MATERIAL_QUOTA` and the band gave it, in a different order.
- **Yard traffic is the thing that must not move, by decision** (Richard, over flattening
  the real quota and re-pricing): what is *seen* leans towards the colourful materials, what
  is *in the water* — and so what each yard is paid over a run, which `shop.json` was priced
  on — is untouched. `test_lake` guards all four materials against the quota within 2%.
- **`SURFACE_QUOTA` is an aim, not a promise.** A material that is not in a stack cannot be
  swapped up and nothing substitutes one in, so the ask is capped by how often a material is
  in a stack at all: stacks run about four deep and rubber is 13% of the water, so rubber is
  there to be picked only about 43% of the time. Asked as a flat quota it landed nowhere —
  every share the colourful materials could not spend fell through to the weight tiebreak,
  which takes the lightest thing there is, and that is a can. The ask is weighted
  `SURFACE_QUOTA / MATERIAL_QUOTA` over the materials the stack holds instead. Asked 32/16/
  22/30, it lands about **30/13/38/19** against a water of 24/20/42/13. The remaining gap is
  the presence ceiling; closing it means substitution or moving the real quota, and both were
  ruled out.
- **The anti-repeat is by family of look-alikes, read off the names** (`family_of`): a
  trailing number in this catalogue means "another one of these", so `metal_can1` to `4` are
  one can, `wood_painting1` to `4` one painting. By kind it kept each can three tiles from
  itself and let the four sit in a heap, and a can was on 18% of the surface between them.
  Derived, not authored — Richard chose "spatial anti-repeat, no new data" over a `look`
  field, and a name is data that is already there. It fails safe: a kind that does not follow
  the convention is simply its own family.
- **A big piece needs more room** (`_apart_of`, `BIG_ROOM`): spacing runs from
  `SURFACE_APART` for the smallest thing in the lake to `SURFACE_APART * BIG_ROOM` for the
  largest, spread by *drawn area*. Counted by tiles the surface was already well spread — no
  kind over 4.6% — while by area `plastic_toy` alone covered 12.3% of the water. What the eye
  counts is area, and that is what "it still looks like the same few things" actually was.
- **A repeat is graded with a floor under it** (`REPEAT_ANY` + `REPEAT_COST`), not a veto.
  Flat, a repeat outranked everything and quietly squeezed out the materials with the fewest
  kinds to their name — rubber has 7 against metal's 12, so "anything not showing nearby"
  meant "metal" over and over. Measured: flat 17% of tiles repeat / metal 39%; slope alone
  38% / 33%; **floor and slope 17% / 36%**. The slope alone doubles the repeats to buy three
  points of metal, which is a bad price.
- **The opening ring is tier 0** (`OPEN_RING`, 4.6 tiles past the drawn water edge — base
  `net_range` 4.0 plus the wade): inside it the top of every stack is liftable by a level-0
  net, landmark or not, so the first casts of a new game never meet a wall. A stack holding
  nothing liftable has its top substituted, keeping its material — the one place anything is
  substituted at all.
- **A landmark is any of the heavier half of what the tile holds, not the heaviest**
  (`SURFACE_BAIT`, `BAIT_SPREAD`). Taking the heaviest, every baited tile reached for one of
  the same half-dozen kinds, and they are the big ones, so they covered the water.
- **`SAVE_VERSION` 12**, version 11 refused: a save stores its stacks rather than its seed, so
  a v11 file would load and keep its old surface for ever, and a save that quietly opted out
  of the change is one nobody can judge it by.
- **Cost: the fill goes 64 ms to 143 ms.** A window is walked round every tile, and the window
  is only as wide as that tile's own pieces ask for (at the widest any piece might want it was
  188 ms). Load only — `build` does not run in play, and no frame is touched. Reusing one
  scratch dictionary instead of one per tile was tried and measured no gain, so it is not there.
- **Out of scope, by decision**: new or repainted art; the water, grime and filth-map shaders;
  fill density (every wet tile keeps its stack, so the lake is still junk edge to edge);
  `TURN`/`DRIFT`/`SIZE_SPREAD`/`facing`; and the strand line (`_strand` overwrites the bank's
  tiles after the fill and is the dog's band, not the first impression).
- **Numbers are first guesses.** `tools/shot_surface.tscn` (desktop build) saves the opening
  view and a near one plus `tools/last_surface.log` — shares by tile, by family, by how much
  water each kind covers, the material bargain, the ring and the repeats. Retune against it.
  `test_lake`'s `_check_surface` guards the rules, not the numbers.

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
- **Colours**: the water body outputs only palette swatches — five five-step ramps
  (`water_clean_*`, `water_hazy_*`, `water_murky_*`, `water_foul_*`, `water_dirty_*`; three
  until 2026-09-17, see the filth map below) and the grime. Depth, bands and
  sparkle sum to a ramp position rounded to the nearest step: solid areas, hard edges.
  The state is picked by four cutoffs (`state_at`) on local filth, after
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
  **The two ends** (2026-09-13, Richard's call): `MAX_ZOOM` 1.5 (was 1.8), four screen px
  to an art px on 1080p rather than five; the far end is the first level at or out past
  `_fit_zoom` — the whole lake and its piers on screen (level one on 1080p, the lake at
  about 61% of the width). `ZOOM_OUT_PULL` (1.68, "the whole-lake view is a map") is
  retired: on 1080p the levels are thirds, and it stopped the wheel a level short with the
  lake wider than the window. `test_lake` checks both ends. **The pan is clamped with the
  view** (`_process`, same day): `_pan` used to wind up past the ground's edge out of sight,
  so a drag back did nothing until it had unwound — at the far end, where the edge is a
  hand's width away, the sides read as stuck. `test_lake` drives a drag past the edge and
  a hundred pixels back.
  **The wheel zooms onto the spot and stays there** (2026-09-14, `/grill-me` with Richard):
  `_zoom_by` zooms about the cursor and then writes the move into `_pan` (`_keep_view_at`),
  so the follow no longer eases the view back onto the angler and undoes it. A wheel zoom
  is a pan, given back as a drag is: walking, a cast, a middle-button tap.
  **A fifth stop, the one exception to the pixel rule** (`_zoom_stops`, `HALF_STOP_GAP`,
  same day): where the levels are a third or more apart (1080p and coarser) a half level
  sits between the far end and the next one in — 0.33 / **0.5** / 0.67 / 1.0 / 1.33 on
  1080p. At 1.5 screen px an art px it draws 1 and 2 px by turns and crawls in motion;
  accepted by Richard, to be judged in play. 1440p and finer get no half level. No zoom
  glide, by decision (offered, not taken) — **for the wheel**. The one glide in the game is
  the menu's Continue (2026-09-17, The Front): the rule is about where the view rests. `test_lake` asks the rule at stretch 1.5 and 2.0
  and holds a zoomed-to spot for three seconds.
- **The view comes home no faster than `Lake.HOME_SPEED`** (issue #19, 2026-09-13): the
  camera follows a point `CAST_LOOK` (0.45) of the way out to the net, so on the haul it
  came home at 0.45 of the reel speed and a reel upgrade was a camera upgrade. Now its step
  is capped at `HOME_SPEED` world px/s (260, about the pace it follows the angler walking)
  from the first frame of the reel until it has settled back on the angler (`_homing`) — a
  net that beats it home is waited for. **A ceiling, not the speed of the return**: under it
  the view still follows the net at the net's own pace, so a slow reel keeps the view between
  angler and net as before. Return only — the throw is not capped, by the issue's own rule.
  The cost: a max-range haul at the top of the reel track is over in under a second and the
  view then pans home for 3-5 s. `HOME_SPEED` is the one knob for that.
  **Landing is framed, not centred** (`LAND_INSET` 0.25, `_framed_on`): the follow point is
  pulled on towards the net, only as far as it needs to go, until the whole mouth is inside
  the window's middle 75% — taken up over the first `FRAME_BY` (0.6) of the flight towards
  where the net will land, and the flying net itself pushes the view the last of the way if
  a short throw was over before the ease caught up. `tools/probe_camera.tscn` (headless,
  `--fixed-fps 60`) measures all of it: peak camera speed by phase and the landing spot as a
  fraction of the half-view at reel levels 0 and 20, short and long, across and down.
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
- **The filth map is a distance from the rubbish, times how much rubbish is there**
  (`Lake._build_filth_map`, `_chamfer`, `_pooled_share`; 2026-09-17, `/grill-me` with
  Richard: "I see the same green shade, until I remove all the objects, then it turns clear
  on that spot"). **Supersedes "presence only"**: every wet tile holds a stack, so under
  presence alone lifting the top of one moved no water, and the lake was one green until a
  tile was empty.
  - **The outline is still the distance map**: the stain falls off to clean at `FILTH_BLUR`
    (3) tiles from the nearest piece, bent by `FILTH_FALL`. **The strength is the pooled
    share**: the pieces in every stack within `FILTH_POOL` (3) tiles over what those tiles
    could hold at `Iso.MAX_SLOTS` each (only tiles the fill or the strand can use, so the
    island's bare shelf does not dilute it), bent by `FILTH_SHARE_BITE` (0.7) and floored at
    `FILTH_FLOOR` (0.34). The two are **multiplied**, which keeps both halves of the old
    rule and both of its rejections: water past the stain's reach is clean whatever the
    average says (no green over empty water), and water touching a piece is never clean (no
    lone piece on blue — the floor lands inside the first state past clean).
  - **Over the deepest a stack goes, not over what each tile started with, by decision**:
    depth is already smooth across the basin (`Iso.depth_at`), so a fresh lake is darkest
    round the island and lightens to the bank, and **nothing is saved** — the map is still
    derived from the stacks alone. "Uniform soup, then lighten" was offered (start depth per
    tile, a `SAVE_VERSION` bump) and turned down.
  - **Towards the outer bank a tile's room is its own fill, not nine** (`Lake._room_at`,
    `FILTH_BANK_FROM` 0.5, `FILTH_STRAND_ROOM` 2; second `/grill-me` the same day, Richard:
    "the beach shores are too clear... more grimy even with less objects"). Against nine
    slots a full two-deep shallow was a quarter full and read murky going hazy from frame
    one. The room eases from `MAX_SLOTS` to what the fill put there over the outer half of
    the lake, so **a fresh bank reads dirty, the same as the middle** (Richard's pick over
    foul) and still lightens a piece at a time. **This takes back most of "varied from
    start"**: a fresh lake is 71% dirty / 28% foul, and the shades come from working it.
    **A flat lift near the bank was asked for first and turned down on the pushback**: it
    holds until the last piece leaves and then jumps to clean, the complaint the grading
    was built to end, at the bank where the dogs work a piece at a time. Outer bank only;
    by the island the weight is nought. `FILTH_SHARE_BITE` went 0.5 to **0.7** with it
    (at 0.5 half the lake sat on foul from a quarter lifted to three quarters). Probe at
    these numbers: quarter lifted 15 / 79 / 5 (dirty / foul / murky); half 0 / 41 / 55 / 4
    hazy; three quarters 1 foul / 61 murky / 20 hazy / 18 clean.
  - **Broad, by decision** (over a 1-tile blur and over two scales mixed): one early cast
    moves nothing by itself, a handful in one bay moves it a shade. The catch patch stays
    the per-cast feedback. If it reads dead in play, two scales is the fallback.
  - **Five states, two new ramps**: clean / **hazy** / murky / **foul** / dirty
    (`water_hazy_*`, `water_foul_*` in `extract_palette.gd` and `palette.tres`, first
    guesses at the midpoints of their neighbours — retune by eye). Four cutoffs, the
    shader's `state_at` mirrored by `LakeGrid.FILTH_STATE_AT`; `test_lake` reads the shader
    source for them. Still hard steps, no dither, no blend; `murk_wobble` and
    `state_spread` untouched.
  - **A scum film on the two dirtiest states** (`water.gdshader` `scum_*`): clumps off a
    blob noise broken into whole art pixels. Denser on dirty than on foul, gone by murky —
    so the scum is the first thing lifting pieces removes, then the colour. **It rides the
    lake and is one step up the water's own ramp** (second pass the same day, Richard:
    "much less prominent, and sway with the lake (it looks separate)"): the plane it is
    sampled on is pushed along the bands' axis by the bands' own `warp`, in art-pixel
    steps, and a band passing under a clump swells its edge (`scum_sway`). **Retired**: the
    bank's `grime_color` over 42% / 30% of the plane on a straight constant drift, which
    read as a layer sliding over the water. The shore foam and its tint take
    `state * 0.5`, so they read 0-2 as before; the bank's grime still wants murky or worse.
  - **Nature is unchanged**: fish, flora, glints and `_clean_share` ask for state 0, and
    because of the floor, 0 still means "no rubbish within reach". The in-between shades
    earn nothing, by decision. Patches and the lane untouched: they close back onto
    whatever shade the map now says.
  - **`_count_clean` asks which tiles are water once** (`_wet_mask`): it was walking
    `Iso.shore_fraction` for all 8464 tiles on every remap, 12.7 ms of a 20 ms map build —
    mid-haul. The build is 8.5 ms now, graded share (2.7 ms) included.
  - **Probe**: `tools/shot_grime.tscn` (desktop build, own save) lifts a quarter, a half
    and three quarters of the rubbish in uneven pools and saves
    `tools/last_grime_<stage>_{far,near}.png` plus `last_grime.log` — the share of water in
    each state per stage and the map's build time. It is also what proves the shader
    compiles. **Retune `FILTH_SHARE_BITE` against that log**, not by feel.
  - `test_lake`'s `_check_grime`: no piece on clean water, a fresh lake is several shades
    mostly the dirtiest, a full shallow by the bank as dirty as a full deep bay and lighter half fetched, lifting half an area
    lightens it short of clean and dirties nothing, no grime past the stain's reach, the
    floor is the lightest grime, the shader and the palette carry both ramps.
  - **Out of scope, by decision**: stronger contour noise (the island-leak risk), pollution
    values or density as the driver, the meter's art and the `Style` colours picked off the
    old ramps, the siege's flat map, a patch that lifts only a few shades.
- **A catch opens a clean patch** (`Lake._on_net_swept`, `patch_radius`, `_push_patches`,
  `water.gdshader` `patches[8]`/`patch_seeds`, 2026-09-13, Richard: "a glimpse of the cleaned
  lake before the grime sets in again"). The map is presence-only, and most casts lift the top
  piece off a stack with junk still under it, so most casts moved no water at all. Now every
  sweep that takes something (`CastNet.swept`, one per sweep, after its `caught`s) opens a
  patch of clean water at the mouth: the mouth's own extent plus `PATCH_REACH` (3) tiles in
  proportion to how much of the hold it took, opening over `PATCH_IN` (0.4 s, the closing
  run backwards), whole for `PATCH_HOLD` of `PATCH_LIFE` (4 s) and then closing, both ends
  eased. **The numbers here were wrong until 2026-09-16**: this note said 8 patches, 5 s
  and 0.8 s while the code had shipped 14 / 2 s / 0.2 s from the first commit, and the
  shader still held `patches[8]`, so six of the fourteen were dropped silently. Issue #31
  (Richard: the grime should get back together "a little bit slower", and continuously,
  not in beats) settled it at 14 / 4 s / 0.4 s with `patch_soft` raised to
  `PATCH_CLOSE_SOFT` (0.6), the shader's arrays sized to `PATCHES`, and `test_lake` reading
  the shader source for both sizes. **Not a disc and not the net's ring**
  (Richard, same day, twice: the first noise pass was "still too round" with grime spots
  showing inside a fresh patch): the plane is **domain-warped** by a noise rolled per catch
  (`patch_seeds`, `_patch_rng`, `patch_warp`) before the distance is measured, so the outline
  is curved lobes and inlets; a fresh patch is clear right through (the threshold starts
  under the field's floor); and as it closes the threshold climbs through a **ridged** noise
  on the bent plane (`patch_top`), so the grime comes back as curved threads along the ridge
  lines that thicken and run into each other, the last clean water being the ground between
  them near the middle. The grime gathers; nothing shrinks as a ring. Knobs: `patch_blotch`
  (cell size, world px), `patch_warp` (bend, fraction of radius), `patch_shape` (how deep the
  threads cut), `patch_top`,
  `patch_soft`. In the shader the patch takes `filth` to zero **before** the cutoffs, so
  it inherits the stepped ramps, blotch wobble and stagger like any clean bay — no colour
  laid over the water, no sparkle. **A transient lie, by decision**: the one exception to
  "water touching objects looks grimy"; its end state is always the map's value, so an honest
  clear is revealed under the shrinking patch, not replaced. Nets only (both nets). **Every
  sweep is its own patch with its own roll** (Richard, same day): a reel that took on its
  way home used to grow the one patch it had, repeating the same shape at every grab; now
  each grab is a new pool, and the cap keeps a long drag from piling them up. Dog and ferry takes
  leave the water alone. Not saved. Capped at `PATCHES` (14), oldest replaced. Numbers are a
  first guess for Richard to retune by eye. `test_lake` guards the landing, the sizing, the
  closing and the cap.
- **A reel with a catch aboard parts a lane through the grime** (`Lake._lay_lane`,
  `LANE_*`, `water.gdshader` `lane[24]`/`lane_seed`, issue #31, 2026-09-16, Richard: "a
  small clear way as it drags through grime before the grime gets back in again, very
  subtle but noticeable"). A chain of small patches dropped every `LANE_SPACING` (14) world
  px along the mouth's path, `LANE_WIDE` (**0.5**; 0.55, then 0.35, then Richard: "a bit wider", all 2026-09-17) of the mouth across, each opening and
  closing on the patch's own curve over `LANE_LIFE` (2 s, down from 3.2, same day), all on one roll per reel so the
  chain reads as one lane. **Catch only, by Richard's call** over every reel: the lane is
  the catch being dragged home. Both nets. The shader's patch arithmetic is one function,
  `patch_clear`, that the patches and the lane both call. `test_lake` guards the trigger
  (empty net, net in flight), the spacing, the width, the cap and the roll.
- **Blotch noise and stagger, low** (`murk_wobble` 0.1, `state_spread` 0.1): removed once
  because at 0.28 the blobs read as water leaking from under the island, then put back at
  under half that (2026-09-11) because with the cutoffs read straight off the map the
  contours round the island sat dead still while the bands rippled across them. Keep the
  wobble small; the map decides where the junk is, the noise only makes the edge breathe.
- **Clean means clean** (2026-09-18, Richard: "at end game, there are still some grime
  smudges, it should be completely clean"): both terms are multiplied by `edge_live` =
  `smoothstep(0, state_at.x, color_t)`, so they fade out as the filth goes to nothing.
  Unfaded they drew hazy water over a filth of exactly zero: the stagger alone takes the
  first cutoff **under zero** in the darkest band troughs (shade under -1, lean past -0.15),
  where `step()` passes nothing at all, and the wobble's +0.1 cleared the 0.05 left of the
  cutoff over any deep water. It was in every cleaned bay all run; the finished lake is
  where there was nothing else to look at. The shader now agrees with
  `LakeGrid.water_state`, which never had either term. `test_lake` reads the source for it.
- Retune colours in `extract_palette.gd`'s `WATER_RAMPS` (and `palette.tres`), not in the
  shaders — their defaults only mirror the palette.
- Not yet converted to pixel art (pending, still live): `beam.gdshader`
  (`LakeGrid.GlintBeam`). The splash went over on 2026-09-16 — see Foam on the Water.
- **The pollution meter is art, not the water shader** (`hud_skin.gd` `_build_meter`,
  `shaders/meter_water.gdshader`, sheets in `assets/ui/meter/` from
  `art_source/UI/Lake meter/Lake_Meter` PSD): four aligned 290x94 sheets — murky water,
  clean water, wooden frame, garbage circle over it — as child TextureRects in the bottom
  left corner (hint line above it), at `METER_SCALE` (**1.7**, was 1.95) times the art on a
  1080-line window, in proportion elsewhere. Settled by eye (3x, 1.5x, then 1.3x that, then
  cut back an eighth with the rest of the HUD, 2026-09-16), not snapped
  to a pixel step; nearest-filtered. The shader slides the filth-to-clean seam (feather
  `METER_FEATHER`, narrowed at the ends) and rocks both sheets a pixel or two
  (sine, not scroll: the sheets are not tileable). Both sheets have soft, part-transparent
  ends, so every water sample is clamped to `METER_OPAQUE` (where both are fully opaque)
  and the band is forced opaque; the band runs `leak` under the circle. Check gaps by
  filming a whole drift cycle (~18 s) over magenta and scanning every frame — a short film
  misses the bad phase. Garbage circle static; `%` figure only,
  right-aligned on the clean end; no `POLLUTION` label. `Style.meter_water`/`water` and
  the `METER_*` colours are gone.

- **The meter's water is the lake's water** (2026-09-17, `/grill-me` with Richard,
  `tools/recolor_meter.py`): the two painted strips read as off-palette (a teal gradient, a
  bright caustic blue), so each is remapped by brightness rank onto a ramp read from
  `palette.tres` — murky sheet onto `water_dirty_*`, clean onto `water_clean_*`, spanning
  `SPAN` of the ramp. **Interpolated between the steps, not snapped, by decision**: the
  painted gradients and caustics stay. Alpha, frame, garbage circle and the shader untouched.
  The painted originals are `art_source/meter/`; psd-extract venv python, project root,
  **reimport after**. Contact sheet `tools/last_meter_recolor.png`. The `Style` colours once
  picked off the old paint followed: `BOARD` (murky deep, taken down), `BOARD_ROW`/
  `ROW_SOUND` (`water_murky`), `BUTTON_SUNK` (murky deep), `BOARD_ROW_OFF`/`ROW_SCREEN`
  (`water_dirty_shallow`), `ON_WATER` (`water_clean`), `LEVEL_INK` (clean shallow, lifted).
  Written as numbers, not read from `Palette` — a palette retune means re-picking them.

- **The upgrades shop is four drawn boards** (`shop_skin.gd`, 2026-09-11; three until the
  market board, four and renamed since The Shop Reads below): net, ferry, dog
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
  **The settings are `Prefs`' now** (`scripts/prefs.gd`, autoload, 2026-09-12): music,
  sound effects and the window live in the autoload and in `user://settings.cfg`, written on
  every press (sliders on the release). **Since 2026-09-16 the sliders are audio buses and
  the Fullscreen switch is a three-way Window row** — see The Settings Menu. The board reads them on its way in (`pull_prefs`)
  and both the menu's board and the lake's are one set of settings. The board's bottom
  button is **"Save and go to menu"** (`Lake._quit`: a dip to dark, the menu's pose struck
  behind it, the run written, the menu up — no scene change since 2026-09-17, see The Front);
  quitting the game is the menu's Quit or the window's cross. The level swap row is off
  (`swap_shown`, default false): **the siege is set aside** — `Lake._next_scene` returns "",
  the farewell offers no onward door, and nothing new should route to `siege.tscn`.


  **And the settings board reads in the shop's language** (2026-09-17, `/grill-me` with
  Richard, `_stage_settings_shape`): the same pass the upgrades shop had, over the one board
  that had drifted furthest from it. **Layout, wording and ink only** — no row was added or
  removed and nothing any row does moved.
  - **One plate face for every row, under carved headings.** The board carried three faces —
    `ROW_SOUND` for the sound rows, `ROW_SCREEN` for the screen rows, `ROW_SAVE` for the
    buttons — and since the section headings were cut on 2026-09-11 those colours were the
    only thing saying where a section ended. The shop had just gone the other way, so the
    headings are back as `ShopSkin._draw_group`'s own drawing (the words in the clean water's
    blue, a carved rule running to the far edge) and the rows are all `Style.BOARD_ROW`. A
    colour on this board is free to mean something again. `ROW_SOUND`/`ROW_SCREEN`/`ROW_SAVE`
    stay in `Style` for `controls_skin.gd` and `menu_confirm.gd`, which are their own pass.
  - **A heading stands in the section gap, not over it** (`GROUP_TALL`, `wanted_tall`). The
    board wants 662 design pixels and the smallest frame leaves it **680** — height never goes
    under 720 — so headings drawn above the gaps they separate (24 px each) would not have
    fitted, and `_draw` handled that by quietly dropping the bottom of the board, which at
    that size is *Save and go to menu*. Standing in the gap costs 14 px each; `SOUND_TALL`
    came 58 to **54** to pay for them and leave a real margin rather than two pixels.
    **The drop is no longer silent**: `dropped_lines` counts what did not fit and `test_lake`
    lays the board out at 1280x720 and asks for zero.
  - **Master leads and carries no heading.** It is the bus the other three feed, and what says
    so is the rule the "Mix" heading draws over those three — a lid on what is under it.
    Indenting the three, and dimming them while Master is off, were the other two ways.
  - **A switch that is on is the clean water, not the money's gold** (`Style.ON_WATER`). The
    groove directly under it already filled in that blue, so one row said "on" in two
    colours, and gold on the shop's board is a price. `ON_GOLD` is the bind board's now.
  - **A dead chooser draws no arrows at all.** Dimmed, they were a pair of controls that would
    not answer, on the row most players meet first: Resolution is a windowed-mode setting by
    decision and an old `fullscreen: true` migrates to borderless. What is left is the screen
    the window is filling, right-aligned where the chooser stood, with `DEAD_SIZE_NOTE` naming
    the row that decides it — **said only where it fits whole**, since a reason cut in half is
    worse than no reason. A dead row draws no dropped list either.
  - **The two foot buttons are a dark plate**, ringed in the seam and lit along the top with
    `Style.lit_edge` — a `PlankButton`'s own two marks, which is what tells one from the board
    when both are the same colour. They were a plank of the frame's oak and **could not be
    read**: "Controls" measured 2.97:1 and "Save and go to menu" **1.37:1**, and no ink could
    have fixed either, because **white itself only reaches 4.06:1 on that face**. A warning
    wants a dark face to be red against. It keeps its mark (Richard: it leaves the lake), in
    `WARN_INK` at 5.30:1.
  - **Every word on the board clears 4.5:1**, worst 4.76. `Style.LEVEL_INK` is 3.42:1 on the
    rows' one face — it was picked to sit on the shop's plate, which is a different plate — so
    the board lifts it to its own `VALUE_INK` rather than moving a swatch the shop is using.
    A dead row inks in `Style.BOARD_INK_SOFT`, the swatch the shop picked the same day
    (`ShopSkin.INK_DIM` points at it now; **the shed's shelf still inks in `BOARD_INK_DIM` at
    2.19:1 and is owed the same pass**). The dropped list's picked entry was cream on
    `ON_WATER` at 2.82:1 and is dark ink on a pale plate at 9.05:1.
  - **No label carries a key name**: "Music  (M)" and "Window  (F11)" are now "Music" and
    "Window". Neither key is rebindable, so the Controls board will never list them either —
    but a label is a name, not a sentence, and a translation had to carry the brackets through.
  - **Out of scope, by decision**: any row added or removed (the switch and the slider both
    stay, so a sound row keeps its two mutes); what any setting does; the Language row (issue
    #28); `ControlsSkin`, `MenuConfirm`, `Prefs`, the buses and the binds; a two-column board.
  - **The heading words are a first guess.** Judge "Mix" and "Screen" on
    `tools/last_menu_settings.png` and retune. The probe puts the window into windowed for the
    resolution list's picture, through `DisplayServer` rather than `Prefs`, so nothing in
    `user://` is touched.
- **The main menu** (`scripts/menu.gd`, 2026-09-12, issue #12): **an overlay on the live
  lake since 2026-09-17** — see The Front below, which supersedes the menu's scene, its
  picture and the scene change. What is left here is the doors.
  - **Retired, in order**: the capsule art `menu_capsule.jpg`; the painted
    `assets/MDLL_Menu_Background.jpg` (1652x628, title top-centre); and `assets/menu_lake.png`
    (2026-09-16, the trailer's last page filmed by `tools/shot_menu_bg.tscn` and darkened by
    `tools/bake_menu_bg.py`, "a one-off, not a pipeline", its darkening "baked into the PNG,
    by decision") with `scenes/menu.tscn`. A picture of a lake that is not the player's, then
    a cut to one that is, was the thing the live menu exists to end.
  - **The logo is its own node**: `assets/mdll_logo_stacked.png` (the v1 stacked lockup the
    trailer and the capsules use, 3.09:1), `LOGO_WIDE` (**0.40** of the window, down from
    0.50: that picture was there to carry a title, this lake is the thing to look at) at
    `LOGO_AT` in the design frame — **anchored to the top-left corner, not to the plank
    stack**, which grows and shrinks with Continue; a title that moved when a save appeared
    would read as a bug. Both numbers are by eye on `tools/last_menu_main.png`.

  **The four doors stand centred under the logo** (2026-09-17, Richard), not in the bottom-left
  corner: `menu.gd`'s `DROP` is the gap under the logo's foot and the stack takes the logo's
  own drawn box for both its axis and its top, so it cannot drift from the picture it hangs
  under when `LOGO_AT` or `LOGO_WIDE` is retuned. `LEFT` and `FOOT` are gone.
  **Centred on the logo, not on the window, by decision**: the darkening is a **left band**
  (`MainMenu.SCRIM`, full at the edge, gone by `SCRIM_TO` 0.58 of the width; drawn since
  2026-09-17, a `GradientTexture2D` rather than a shader) and the logo's axis is at about
  0.25. A stack centred on the window would stand half out of the band.
  **Credits is in the stack, above Quit** (2026-09-17, Richard), and `CORNER` is gone with the
  corner it named: a lone plank in the bottom right was where a credits button lived while the
  doors were in the opposite corner and the two had the screen between them. With the stack
  centred under the logo it was the only thing left in the old arrangement.
  **The accented door is the one into the lake** (`PlankButton.accent`) — Continue when the
  lake behind loaded a run, **New game when it did not** (2026-09-17): the same wood, the lighter
  `BOARD_ROW` face an affordable shop row wears in place of the boards' dark `BOARD`, **and
  the lit edge along its top** — two channels, because the two faces are close in luminance
  and told apart by hue alone they are one face to a red-green colourblind player. Only ever
  one door is accented, or the accent says nothing.
  Five `PlankButton`s (232x56): Continue (only when the lake behind **loaded** a run —
  `MainMenu.has_run`, set from `load_game`'s own answer; it used to ask whether the file
  existed, and offered to continue a save the lake had just refused), New game (over a run,
  `MenuConfirm` asks "Start over?" first, then `reload_asked` and the lake deletes its own
  file and reloads), Settings (the lake's `SettingsSkin` in `menu_mode`: sound
  and screen rows only), Credits (`CreditsBoard`, all its words in one constant) and Quit. **The credits are real now** (2026-09-16,
  `/grill-me` with Richard): one "Art and Assets" heading over every third-party art pack,
  each in that pack's **own required credit wording** (`Graphics created by Penzilla Design`,
  `Asset by Zato - https://zatoart.itch.io/`, …) and **never saying what the asset is** —
  `docs/CREDITS.md` is the only place the asset → pack mapping and the licence status live.
  AI-generated art is credited nowhere, by decision, and the Steam page and the trailer carry
  no credits. A line too wide for the face **wraps** on spaces rather than being cut or
  shrunk, since none of the required strings may be shortened (`_wrap`, rows of one line set
  `WRAP_GAP` apart); at the board's 460 the longest is 370 of 430, so the wrap is insurance.
  **Spotify's mark stands beside Nuven** (`assets/ui/spotify_icon.png`, baked from their own
  download by `tools/build_spotify_icon.py`): their guidelines forbid redrawing, recolouring
  or distorting it, so it is never built in code and never tinted, and it is drawn by a child
  `TextureRect` at a **linear** filter because it is a vector mark, not pixel art.
  **Decoration only**, by decision — no click, no hover. Probe: `tools/probe_credits_wrap.gd`
  (headless `--script`) prints the rows at three face widths.
  Escape closes whichever board is up and does nothing on the bare menu. The music is the
  `Music` station's, not the menu's (see The Music below): nothing restarts on the way into
  the lake.
### The Front: Splash, Curtain, and the Menu over the Lake (2026-09-17, `/grill-me` with Richard)
The game boots through a loading screen into the lake itself. `run/main_scene` is
`scenes/boot.tscn`, which puts `scenes/main.tscn` in; the player's own run loads behind the
doors and `MainMenu` is an overlay on it (`Lake`'s "The menu over the lake" section,
`MENU_LAYER` 30). Continue hides a menu and nothing else.
- **One loading screen, drawn in three places** (`scripts/loading_screen.gd`, second pass the
  same day, Richard: "lets use a flat image of a dirty lake, and bring the loading meter
  anyways (without the garbage and circle, just the bar). It doesn matter if it loads too
  quickly"): the filthy lake darkened (`DARKEN`), the stacked logo above the island and the
  bar below it. (1) **The engine's splash is a photograph of that control with its bar
  filthy** (`assets/boot_splash.png`, stretch mode Cover to match the control's fit — 4.7
  has `stretch_mode`, not `fullsize`; `bg_color` is `water_dirty_deep` and is what
  `Curtain.water()` reads). (2) The boot scene (`scripts/boot.gd`) sweeps the bar. (3) The
  lake's curtain holds it, bar clean, and dissolves it onto the menu. Same picture each
  time, so no hand-over is a cut. Retired: the logo on flat green and
  `tools/build_boot_splash.py`.
- **The picture is the fresh lake at the menu's own view** (`assets/loading_lake.png`),
  filmed through `Lake._enter_menu` so it cannot drift from the framing it dissolves into:
  near seamless on a new game, a before-and-after on a run in progress. The flock is hidden
  in it (a bird frozen in mid-air hangs there as a ghost while the picture goes).
  **`tools/shot_loading.tscn`, two runs with a reimport between** — the lake, then
  `SHOT_SPLASH=1` for the splash and `tools/last_loading.png`. **Re-run both if the menu's
  view, the island, the fill or the screen's layout change.**
- **The bar is the HUD's meter with nothing on its end** (`scripts/meter_bar.gd`): the same
  sheets, shader (`HudSkin.meter_material`/`meter_seam`, static now, used by both) and built
  frame, the node being the frame's own box with `clip_contents` and the sheet hung behind.
  **At the HUD's own size** (`HudSkin.meter_scale`; Richard on the first look, when it was a
  third of the window wide: "too big and stretched, we dont need it to be bigger than how it
  is in the game"). **It fills right to left, like the game's meter** (Richard: "start green
  and fill to blue, but from right to left, just like in the game"): a mirrored bar filling
  left to right like a stock loading bar was built and turned down. The shader's seam is
  where the *filth* ends, so it is handed `1 - share` — handed the clean share straight, the
  very first cut swept clean to filthy and the splash showed a clean bar. `test_lake` asks
  the seam at both ends and that the water is not flipped.
- **A timed sweep, not a reading, by decision**: `Boot.SWEEP` 0.9 s, eased, then the lake is
  put in with the bar already full, so the half second the screen stands still reads as a
  beat. Costs every boot its length; weighed and taken. **Why it cannot be honest**:
  `tools/probe_boot.tscn` (desktop build; `tools/last_boot.log`; `Lake.boot_marks` / `_mark`
  time `_ready` stretch by stretch) found the threaded load of `main.tscn` is **20 ms** and
  everything else is main thread, where nothing on screen can move; and that **2.17 s of
  the lake's 2.6 s build was one line**: `Ground._boxed` called `Iso.basin_extent()` — which
  walks the whole shore outline — for every lawn tile of the ring. Cached (`_basin_half`),
  the sow is 131 ms and the build 0.56 s. **Re-run the probe before believing a load is
  slow**; every harness and probe got the 2 s back too. (The first pass that day shipped no
  bar at all on these numbers; Richard wanted the bar anyway.)
- **The curtain** (`scripts/curtain.gd`, layer 90) is the one thing over everything.
  `open_on`: the loading screen whole over a lake that has just come up, held `HOLD_FRAMES`
  while its first frames compile and upload, then dissolved (`LIFT`) — **the logo and the
  bar taken off in one frame first, and the lake alone dissolved** (`LoadingScreen.dress`,
  Richard: "should remove logo and bar right away, not in pieces"). The screen is several
  pictures lying on each other, and under one alpha each fades against what is under it, so
  the overlaps went slower than the rest: the lockup and the bar hung on after the lake had
  half gone, and the bar's water showed through its own wood. `to_loading` is the same the
  other way — the lake comes in, then the logo and bar go on at once. The flat fill under
  the picture is a fallback only and hidden when the picture is there, for the same reason. **`dissolve`, the way
  back to the menu**: the live view dims to `DIM` over `DIM_TIME`, *that dimmed frame is
  grabbed and frozen over the screen*, the pose is struck behind it, and the frozen frame
  dissolves onto the menu (`DISSOLVE`) — a crossfade, the snap never seen, no flat colour
  ever on screen. The frame is grabbed on `RenderingServer.frame_post_draw` by a one-shot
  connection, **not awaited**, and what follows is deferred out of the renderer's signal.
  `to_loading` is the reload: the view dims and the loading screen, bar filthy, comes in
  over it. **Retired** (Richard, first look: "a little stiff... not put a total green screen
  right away"): `dip` and `close`, down to the splash's solid green and back.
- **Alive but posed** (Richard: "fully live but dogs just sleeping until game starts, and
  boats are stationary at island. Player is idle."): water, birds, fish, flora, day and
  ambience run. `Dog.doze` (NAP that never runs out, no greeting, no voice, no petting;
  scattered over the island at the boot, lying down where it stands on the way back; wakes
  `WAKE_LEAST`..`WAKE_MOST` after), `Boat.moored` (a docked hull never dispatches), the
  angler held, `_in_menu` gating the lake's input, the pad's reticle and verbs, the autosave,
  the bonus clock and the search for the ending. The HUD layer is hidden.
- **Nothing is lost to the pose and nothing is sold by it** (`_pose_world`): `CastNet.stow`
  lands the catch the ordinary way, `Haul.land_all` brings down everything in the air
  through `arrived` (so a sale in flight is still a sale), `Boat.moor_now` hands its hold
  back and `Dog.doze` its mouthful, all into the crate — the rule a save already kept for
  `afloat`. **`_quit` saves after the pose, not before**: written first, as it used to be, a
  net's catch was in neither the water nor the file.
- **The lake is the message**: no figures on the menu. The view is the far stop with the
  lake's middle `MENU_LAKE_AT` (0.62) across — as far as `_clamped_view` allows, 0.59 on
  1080p, where the lake is most of the window and the doors stand over its left end.
- **Continue is a glide** (`_begin_glide`, `_glide_step`, `GLIDE_TIME` 1.6 s): the zoom
  eased in its logarithm, and what is interpolated is **where the angler stands on the
  screen**, not the camera's place in the world, so they drift to the middle instead of
  swinging in. The one exception to "no zoom glide" (Richard, over stepping stop by stop);
  it lands on the stop nearest `VIEW_ZOOM`. The world is let go at once; the HUD comes in
  over the last `1 - GLIDE_HUD_FROM`; the player's hands come back when it lands.
  `_drive_view` is the old camera block of `_process`, moved whole.
- **New game over a run reloads through the boot scene** (`_reload_as`, `Lake.skip_menu`,
  read once): `Curtain.to_loading`, file deleted *by the lake*, `change_scene_to_file` to
  `BOOT_SCENE` — whose first frame is what the curtain is already showing — the sweep, and
  the new lake strikes the same pose with no doors on it and sets off on the glide by itself
  (`SKIP_GLIDE_AFTER`). One loading screen in the game. F6 keeps its direct reload.
  No save at all: the fresh lake is already behind the menu and New game is just the glide.
- **Only a lake run as the game wears the front** (`get_parent() == root`): every harness
  and probe instantiates `main.tscn` under its own node and gets the lake it always did.
  `Lake.force_front` is for the probes that photograph the menu.
- **Out of scope, by decision**: figures or HUD on the menu, a live wind-down (boats
  finishing trips, dogs walking home) instead of the snap, auto-starting on first launch,
  a drifting camera, threading the lake's build for an honest meter, the web build.
- **First guesses for Richard's eye**: `SCRIM`, `SCRIM_TO`, `LOGO_WIDE`, `MENU_LAKE_AT`,
  `GLIDE_TIME`, `Curtain.LIFT`/`DIM`/`DIM_TIME`/`DISSOLVE`, `LoadingScreen.DARKEN`/`LOGO_AT`/
  `BAR_AT`, `Boot.SWEEP`, the ambience playing under the menu.
- **Probe**: `tools/shot_menu.tscn` (desktop build, `--fixed-fps 60`, **on a copy of the
  save**) saves `tools/last_menu_{curtain,main,main_settings,credits,confirm,glide,landed,
  dim,dissolve,back}.png` and `last_menu.log` (zoom, where the lake's middle stands, dogs
  asleep, hulls moored, per shot). **`tools/shot_reload.tscn`** walks New game over a run
  (lake, loading screen, boot scene, fresh lake, glide): that road ends in a scene change
  only the game's own lake takes, so the probe makes its lake the tree's current scene.
  **`Lake.session_save_path`** exists for it: a static that pins every lake of the session
  to the probe's file, because the lake that comes up after the reload is built by the boot
  scene and no tool can hand it a `save_path`. The probe's first cut relied on quitting
  before the autosave, then stopped stepping at the scene change (**a freed node compares
  equal to null**, and its guard was `_lake == null`), never quit, and the game ran on over
  the player's real save until the autosave wrote it. **A probe's safety may not depend on
  the probe working**: pin the path, and quit on a wall clock as well. `test_lake`'s
  `_check_loading` guards the boot scene being first, the bar having no circle, its size
  being the HUD meter's, the sweep, and the seam at both ends; `_stage_front` guards the pose (with a hold at sea,
  a stick in a mouth and a catch in the net: all in the crate, nothing sold), the holds (a
  full crate sends no ferry, the autosave writes nothing, Escape opens nothing), the doors'
  accent, the release, the glide landing on the play stop, and the way back writing the run
  on the same lake.

### The Ending (2026-09-16, `/grill-me` with Richard, issue #1)
A cleaned lake ends on a beat of clean water, then the words, then the credits.
- **The run ends when the last piece is put in the crate** (`Lake._all_landed`), not when the
  water empties. `_check_cleaned` still asks the field — the meter is float dust and cannot
  be the trigger — and now also asks that no net holds a catch, no dog has anything in its
  mouth (`Dog.carrying`) and nothing the net threw is still in the air. **Only the untagged
  flights count** (`Haul.flying_to(null)`): cargo crossing to a hull and cargo a ferry is
  landing at a pier are tagged, and both are stock already. The ferries may go on running
  under the ending; what they carry is in the box.
- **The field is asked outright, and at once when a piece lands** (2026-09-17, Richard: the
  ending was not triggering reliably). `_look_for_the_end` used to walk the field only once
  `_filth_left` was under `CLEAN_ENOUGH` of the total, and **a dog's delivery never moved
  that float** — so on any lake the pack helped clear the meter never bottomed out, the
  field was never asked and the run never ended. The gate and the constant are gone (the
  walk is 8464 `size()` calls every `CLEAN_CHECK_EVERY`), `_dog_brought_back` moves the
  meter, and both crate landings (`_on_haul_arrived` untagged, the dog's) call
  `_ask_the_end`, which zeroes the clock so the check runs **next frame** — not in the
  call, where the haul and the dog are mid-handover and would answer "not yet". **Any new
  way a piece leaves the water needs no wiring for the ending**, only for the meter.
  `test_lake` ends an empty lake with the meter at half.
- **"n pieces left" over the meter, from fifty down** (`Lake._last_pieces_line`,
  `LAST_PIECES_FROM` 50, 2026-09-17, Richard): the hint line `HudSkin._draw_hint` writes
  over the pollution meter says the count and nothing else, and says nothing above fifty.
  It used to read "n pieces still out there" and only once the meter was on the floor —
  which, with the gate above, was never on a lake the dogs worked. The count is live every
  `CLEAN_CHECK_EVERY`. `test_lake` guards the words, fifty, fifty-one and the singular.
  **The line is its own node over the meter's sheets** (`HudSkin.HintLine`, `_place_hint`,
  `meter_top`, `hint_box`, same day, Richard: it was showing behind the meter). It was
  written in `HudSkin._draw`, and the meter is child TextureRects — **children draw over
  their parent** — and it hung off the *frame's* top while the garbage circle stands
  higher, so the two met and the wood won. Now it is the last child. **It sits on the bar,
  beside the circle, not over it** (`hint_span`, `HINT_LIFT` 0, second pass the same day,
  Richard: hung clear of the circle's top it stood far above the bar and off to its left,
  "dislocated from the UI meter"): centred on the stretch of the frame from the circle's
  right edge to the frame's, its **baseline** on the frame's top — the face is all capitals,
  so descender room is empty air, and the ink's own few pixels short of the baseline are
  the whole gap. Anything new written over the meter goes through it, not through `_draw`.
  `test_lake` guards the child order, that the glyphs end on the bar's top and no more than
  6 px off it, and that they stay inside the span beside the circle; probe
  `tools/shot_pieces_left.tscn` (desktop build) saves `tools/last_pieces_left.png`.
- **Two seconds of shimmer first** (`Lake.ENDING_BEAT`, `_count_the_beat`): the sparkle
  rising, the note ringing, and **the end song coming in with the beat, not with the text**
  (`Lake.ending()`, which is what `MusicStation.set_ending` is told). The angler keeps their
  legs during it; the hold comes with the words.
- **The message stands in the middle of the window** (`Farewell.BLOCK_AT` 0.5, 2026-09-16):
  it used to sit at 0.60, a little low, because the middle is where the island is. With the
  credits climbing under it the low block left the roll a short screen to cross and a long
  one to wait in. One number, read by the words and by the band the roll dims in.
- **The words take `FADE_IN` 3.6 s to arrive**, two seconds longer than they did (Richard:
  the shimmer can last two seconds longer as the message fades in). The lake is live and
  lighting up the whole time and the wash eases in with the words, so a slower fade *is*
  more clean water before the ending is written over it. `Lake.ENDING_BEAT` is untouched —
  that one is silence before anything at all — and **the roll waits for the words**
  (`_shown >= 1.0`): a credit arriving while the message is a third of the way in reads as
  the roll having started without it.
- **The credits roll up and off** (`Farewell.roll_credits`, `_draw_roll`): `CreditsBoard`'s
  own strings and headings, wrapped to `ROLL_WIDE` of the window and climbing over `ROLL_TIME`
  (26 s) from `ROLL_BELOW` under the glass to `ROLL_ABOVE` over it. Drawn **under** the
  message, which does not move: the two lines are what the ending says, and a line that
  scrolls away is a line somebody missed. Spotify's mark rides its row as its own
  `TextureRect` at a linear filter, on the board's own terms.
  **The rows are laid out here, not borrowed**: the board is a plate of wood with a face to
  wrap against and this is open water with the whole window. The words are read from
  `CreditsBoard`, so a credit added there is added here.
- **A click skips the roll** (`skip_roll`, `ROLL_SKIP`): it runs off at nine times the pace
  and leaves the words and the plaque. A second click dismisses as before. **The doors are
  not drawn while the roll is running** — the credits pass over exactly the band they stand
  in, and a plaque under a moving credit is one nobody can aim at.
- **Only an ending that ends the game rolls them**: `_show_farewell` calls `roll_credits`
  when `_next_scene()` is empty. A level that leads somewhere does not end anything.
- **The roll dims where the words are** (`_message_band`, `_roll_clear`, `ROLL_BEHIND`): the
  message does not move and the credits go under it, so the two cross. At full strength the
  crossing is two lines of lettering in one place and neither reads; blinked out it is a
  credit missing. It fades to `ROLL_BEHIND` over `ROLL_BEHIND_SOFT`, the way anything passing
  behind something else does. One band, asked by both, so the dimming cannot drift from the
  words.
- `test_lake` guards the beat (its length, that nothing is written during it, that the song
  is told), the crate rule (a piece in the net keeps the run going), the roll and the words.
  **Headless has no renderer**, so `tools/shot_ending.tscn` (desktop build, `--fixed-fps 60`)
  is what exercises the drawing: the beat, the words arriving, the first credits crossing the
  message, the roll well up, and what is left after a skip —
  `tools/last_ending_{beat,words,behind,roll,skipped}.png` and `last_ending.log`. It runs on
  **a save of its own**, because finishing a lake saves it on the spot and a probe may not
  hand the player back an emptied run.

  The menu comes back from "Save and go to menu" and from the farewell's **"Back to
  menu"** plaque (`Farewell.to_menu`, always drawn under the closing words; clicking
  elsewhere still just dismisses), both through `Lake._quit` — see The Front. Probe:
  `tools/shot_menu.tscn`. `test_lake` guards
  the farewell's menu door and that no siege door is offered.

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
  that border round the recycle box's own brown (`STOCK_TALL` **54**, up from 34 and then down
  from 62 — the wood alone is 30, and its width is measured against the face and then grown by
  the walls), and
  `PlankButton` is it round a `BOARD` face with the word set to the **face** rather than to
  the whole button (`LABEL_SHARE`), so a button sized to its own word carries no empty wood.
  The settings button went 176x38 to 152x56 on that, and to **134x48** in the HUD cut below.
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
  **A ribbon's plank ends where its board's face begins** (`Style.ribbon_plank`, 2026-09-12):
  every menu hangs its ribbon centred on the board's top edge, so the box's middle is that
  edge and the face starts `BORDER_TOP` below it. Centred in its box instead, the plank
  stopped a row short, and the frame's own top-plank outline showed in that row as a dark line
  straight under every bite along the ribbon's foot — closing each notch off.
  **The stiles have no see-through column** (`_fill_empty_columns`, 2026-09-12): the foot plank
  is 14 rows and the wall 15 wide, so turning it on its side left an empty column down the
  inside of both stiles — a hairline of the lake beside every menu's face, hidden on the
  buttons only because they grow their fill. Filled from its neighbour in the frame itself;
  `test_lake` guards the inner ring.
  **A board's face is filled under its wood, not after it** (`board_wood`'s `fill`,
  `FACE_UNDER`, 2026-09-12): filled exactly to the inset after the frame, a board on
  fractional coordinates — the shed's shelf stands at y 99.8 — rounded the frame's texture one
  way and the face's rectangle the other through the window stretch, and a one-pixel seam of
  the lake opened down the inside of its right stile and along the top of its face, at every
  window size tried. The fill now runs `FACE_UNDER` pixels in under the wood. Probe:
  `tools/shot_holes.tscn` (desktop build; `HOLES_W`/`HOLES_H` for the window) draws the
  settings board and the shelf over flat magenta with the world hidden, so any hole is magenta.
  **The drawn wood's bites are V's too** (`Style.v_rows`, `v_all`, 2026-09-12): the fallback
  planks — and the settings board's two button planks, which still use them — carved square
  holes, and a three-pixel square read as a pixel gone missing. Each bite is a staircase of
  one-pixel rows narrowing to `BITE_TIP`, so the rectangle carving and grain clipping cut a V
  without new geometry; `rims` blacks every wood pixel touching it, edge-on or at a shoulder,
  on whole pixels as `_bite_out` does for the painted wood.
  **Every menu nails its close cross to its title plank's right end** (`Style.close_on`,
  `title_room`, `CLOSE_LIFT`, 2026-09-12), as the shed's shelf did first — the settings board
  on its own ribbon, the upgrades shop on the last board's — with the title centred on what
  the cross leaves, mirrored at the left end. The X itself came in (`CloseButton.ARM` 0.3 to
  0.22, `STROKE` 0.1 to 0.085): at that size it ran off the plank and outweighed the title.
  Probe: `tools/shot_menus.tscn` (desktop build) saves all three, `tools/last_menu_*.png`.
  **A plank's bottom bites are backed, not open** (`_backings`, `meter_plank`'s `under`,
  2026-09-12): a ribbon straddles its board's top edge, so a hole in its lower edge shows the
  frame plank it is lying on. `_border_bites` records what each bottom bite cleared into a
  mask, and the plank draws that mask tinted `Style.BOARD` under itself — so the bite reads
  through to the **board's face**, which is what is behind the panel. Top and end bites are
  over the lake and stay open.
  **The HUD speaks one language** (2026-09-17, `/grill-me` with Richard, cohesion pass):
  - **The meter's frame is built, not stamped** (`HudSkin.MeterFrame`, `Style.meter_frame`).
    The sheet's own frame was drawn pre-scaled at `METER_SCALE`, so its planks landed at 27
    and 24 px while every other plate in the HUD landed at 16 and 14 — **and they are the
    same wood**, because `Style._build_border` crops its frames out of `Meter_Border.png`,
    which *is* the meter's frame. One board at two thicknesses, side by side in one corner.
    Built to the wooden box's own drawn size instead, the planks match everywhere and the
    meter gains the V bites every other frame has. The painted water sheets, the shader and
    the garbage circle are untouched; `MeterFrame` falls back to stamping the sheet where
    `Style.border_fits` says no, because a frame at the wrong thickness beats none.
    **Not a repaint, by decision** — the wood was never wrong, only its scale.
  - **The lake's settings button is a gear and carries no word** (`PlankButton.mark`,
    `_draw_mark`/`_cog`, 56x56): Richard's call, "it's the industry standard". Drawn in code
    like the close cross and the coin — `assets/ui.png` has four pieces on it and none is a
    gear — with square shoulders rather than a scalloped rim, because this game's wood is all
    straight cuts, and **its hub is a hole** — filled in the button's own face colour
    (Richard, 2026-09-17), because filled with the oak it read as a disc of wood lying on the
    panel, which is the opposite of what a gear's middle is.
    **The main menu keeps the word "Settings"**, having the room and no
    convention to lean on. One button class still: `mark` is an option on `PlankButton`, so
    the border, the hover, the press and the sound have one path.
  - **The decorate button's finds are a fan, not a band** (`HudButtons._scatter`, every
    `FAN_*`): a sweep from low on one side, up over the roof, down to low on the other, on
    `FAN_RANKS` rings, each find drawn smaller and washed further towards the face the
    further back it sits (`FAN_FADE`) — a peacock's tail behind the shed, Richard's phrase.
    Held inside `room_of` by each find's own half-size, so nothing is clipped by the frame;
    several were. `fit` stands a find on the **bottom** of the box it is given, so the point
    on the sweep is its foot — centred, every find sat half its own height low.
    **All the numbers are first guesses**: judge on `tools/shot_buttons.tscn` and retune
    there, or with the F7 tuner, whose `decor`/`decor_scale` handles still move and scale the
    whole tail as one.
  - **Already true, and worth writing down**: `UPGRADES_SIZE` and `SHED_SIZE` are both
    120x100 and have been since the border pass.
  - **Out of scope, deliberately**: nothing moved corner to corner. Grouping money with the
    shop, giving the fleet and the pack a readout, and whether the stock plate earns its place
    are a second pass, to be grilled off the new screenshot.
  - `test_lake` guards the meter's frame being a node built to the wood's box, the two picture
    buttons being one size, the gear being square and wordless, and the fan keeping every find
    inside the button and reaching above the old band's ceiling.

  **And says two things straighter** (2026-09-17, second pass, `/grill-me` with Richard):
  - **"Waiting", not "In stock"** (`HudSkin.STOCK_LABEL`). The crate has **no cap** —
    `Store.held` is an unbounded list and `CRATE_FULL` only decides how high the heap draws —
    so the plate holds a **backlog**, pieces waiting for a ferry, not a balance. Sat on the
    same plate as the money and labelled "In stock", it read as a second purse. The word is
    the whole fix, by decision: the number rising is the clearest sign the fleet cannot keep
    up (CLAUDE.md's own pricing note has the box peaking near 400 in the sim), but saying so
    with a trend mark is a fleet readout, and Richard left fleet and pack readouts out.
  - **The upgrades button says "Upgrades" and wears the count on a badge**
    (`HudButtons.badge`, `HudSkin.UPGRADES_LABEL`). It read "n available" across the foot: a
    count with no noun — available what? — and the only thing in the HUD whose width moved
    with its own number, so the panel breathed as the purse filled. The badge is sized to
    `BADGE_SAMPLE` ("99"), never to the count in hand. **Still always there, zero included**,
    which was the old panel's rule and a good one — at zero it is drawn back, not hidden.
  - **Out of scope, by Richard's call**: moving money beside the shop, and any readout for the
    fleet or the pack. The diagonal between the purse and the button it feeds stands.
  - `test_lake` guards the label having changed, the foot being a name rather than a count,
    and the badge coming out one width at 1 and at 99.

  **The corner HUD came in an eighth** (2026-09-16, Richard: reduce the meter, the coin, the
  stock plate and the settings button): `METER_SCALE` 1.95 to 1.7, `STOCK_TALL` 62 to 54,
  `MONEY_TALL` 64 to 56, the settings plank 152x56 to 134x48. **The border's planks take a
  fixed 30 px of any plate's height**, so a shorter plate is all face lost and the writing is
  what runs out of room first: the stock plate's two sizes are **derived off that face** now
  (`STOCK_TEXT`, `STOCK_LABEL_SHARE`, `_stock_count_size`/`_stock_label_size`), the way the
  money plate's already was, and `_lay_out` measures the plate's width against the same
  numbers — written down, the plate came in while its reading stayed put and ran off its own
  panel. The sunken reading panel's inset went 5 px to `HudButtons.PANEL_INSET` (2) for the
  same reason, which is what keeps both figures on their old rung (16). One knob each; retune
  by eye.
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
  them, the "n available" panel across the foot. *Shed* (**120x100, the same box as the
  upgrades button** — this said 104x84 until 2026-09-17 and the two have been one size since
  the border pass): sixteen fixed finds
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
  is what "behind" looks like), **the band** (2026-09-17: `DECOR_BAND` put every find between
  0.42 and 0.98 down the face, so the top was bare by rule and what showed was two clumps on
  one baseline either side of the hut — a row of furniture standing in a line), and standing
  the finds in two rows along the back (a band of
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
- **No night** (2026-09-14, Richard: "night is too dark"): the loop runs the sun from `sun_from`
  (0.15, mid morning) to `sun_to` (0.8, late afternoon) over `turn_at` (0.88) of it, and the light
  then eases back to the morning's without passing noon (`DayCycle._sun_at`, `_light_at`). The dim
  blue trough at dusk and `trough_at`/`trough_dip` are gone; late afternoon is the darkest the lake
  gets, and `test_lake` guards that nothing in the loop is darker. Both the shop run and the tree run.
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

### Foam on the Water (issue #31, 2026-09-16, `/grill-me` with Richard)
Every disturbance on the lake is drawn in the one foam language — the collar's rules from
`foam.gdshader`: worked out per art pixel, hard edges, palette swatches, dissolving into
whole bubbles rather than fading. Richard's brief: splashes "replaced by our foam look, but
keep its sizes and splash movement"; the drag's ripples "replaced by a foam streak"; the
dogs' ripples "replaced by a foam streak behind them, ripples only when they enter the
water"; boat splashes likewise.
- **The splash keeps all four parts and every number of motion** (`water_splash.gd`): the
  crown (mound and three plumes), the drops, the 32-frame speck sheet and the flat ring.
  Only the ink changed. `splash_foam.gdshader` now snaps its bubble field to the world's
  art-pixel grid (`foam_pixel` = `Lake.ART_PIXEL`; a splash happens in one place, so the
  world grid, not a moving frame), ticks at `pixel_fps`, outputs one of three alpha steps
  (whole, `remnant`, nothing) and two palette swatches (`foam` / `foam_core` through
  `Palette.dress_foam`) — no gradient anywhere. `splash_specks.gdshader` re-reads the sheet
  once per art-pixel cell at the cell's middle and cuts it hard at `edge`, so the frames'
  soft spray lands on whole pixels. Drops are whole art pixels square (`draw_rect`), never
  circles, and still glide. Rings are **bands, not lines** (`_band`, a strip of twenty
  quads) so the shader has an area to tear: a ripple is `RIPPLE_THICK` (1 art px) of foam,
  which the bubble cells break into a dashed ring; the crown's ring `RING_THICK` of its span.
  `RIPPLE_ALPHA` went 0.3 to 0.5 because a torn band loses most of itself. Three parts,
  drawn in order: `Rings`, `Specks`, `Crowns`; rings and crowns share one material.
  **Every crown rolls its own shape** (`_crown_roll`, `CROWN_VARY` 0.3, `_unroll`, same
  day, Richard: "not repetitive"): the side plumes' lean, which side stands taller and the
  middle plume's breadth each wander up to 30% off the drawn shape. The span is untouched —
  the roll is the shape, not the size.
- **`ripple()` is a foam ring for every caller, by decision**: the net's landing ring (kept,
  mouth x1.2), the fish schools' rings and the shelved siege's. One primitive.
- **The reel wears a bow wave at the mouth, no trail** (`CastNet._push_bow`, `_bow`,
  `MOUTH_STREAK` 0.7, `MOUTH_FLARE` 0.7): the ferry's own `HullFoam`, sized to the mouth,
  its bow laid on the mouth's **leading rim** (laid at the middle the whole wave was under
  the mesh) and drawn behind the net, so what shows is the water parting round the front.
  Richard picked "foam at the mouth only" over a hull-style pair and a single trailing
  strip. The 0.13 s ripple trail (`DRAG_RIPPLE`, `WaterSplash.wake` from the net) is gone.
- **The bow wave is dropped the moment the reel ends** (`HullFoam.drop`, `_push_bow`,
  2026-09-17, Richard: a streak of the drag firing beside the player after the haul). Off
  the reel `_push_bow` fell back to a heading of `Vector2.RIGHT` at the net's home — the
  angler — and eased the push out from there: foam pointing east at the player's feet
  after every haul. Only a reel aims the wave now, and home is the angler's hand, where
  there is nothing left to part. `test_lake` guards that it is gone at once and never
  moved or turned on its way out.
- **`HullFoam` is per instance now** (`streak_long`, `with_trail`): the shape is the one
  shape, the lengths belong to the thing wearing it.
- **The dog and the angler leave a streak and push one ring going in** (`Dog._wake`,
  `Angler._wake`, `STREAK_LONG`/`STREAK_WIDE`/`ENTRY_SPAN` on each): a small `HullFoam`
  with its trail, pushed while moving in the water faster than `Angler.WADE_LEAST`, pointed
  the way the walker is going; one `ripple()` of `ENTRY_SPAN` on the frame the walker goes
  in (`_was_swimming` / `_was_wading`), none after. **Retired**: the dog's drawn ring
  (`_draw_wake`), the angler's pulsing boot rings (`_draw_ripples`, every `RIPPLE_*`,
  and the `rings` term in `_paint_key`) and both `WaterSplash.wake` trails. The angler's
  is the dog's rule by Richard's call; "streak only, keep the boot rings" was offered.
- **The boat's bow spray is the same splash** and changed with it; the hull's own four
  streaks are untouched.
- **Out of scope, by decision**: the click ripple (`ClickRipple`), the hull streaks, the
  grime blotch wobble, dog footsteps, `beam.gdshader`.
- **The clean-water glints are sparser** (`Lake.GLINT_MOST` 0.7 to 0.4, `GLINT_CELL` 20
  art px pushed to the shader's `glint_cell`, was 14; same day, Richard: "more sparse"):
  about a third of the pops. The finished lake's `sparkle` is untouched.
- **Cost** (`bench_frames`, RTX 5060 Ti, 1080p, full lake, uncapped): 2.92 ms mean standing,
  3.46 ms walking, worst 5.55 ms, nothing over 16.7 — inside the bar. The lane adds a
  24-point loop with an early distance skip to every water fragment.
- **Probe**: `tools/shot_foam.tscn` (desktop build, `--fixed-fps 60`, its own save) casts at
  the farthest spot the marker reads green, and saves `tools/last_foam_{land,crown,reel,
  lane}.png` cropped on the net plus `last_foam.log` (bow push, lane and patch counts).
  Headless compiles no shader, so this is what proves the three edited ones — read its
  engine log. `test_lake`'s `_stage_foam` guards the parts and their shaders and swatches,
  the source having no line or circle left, the bow (trail off, short, on the rim, sized,
  pushed up on the reel and dying at home), and both walkers' entry ring firing once.

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
  which they follow as it lies at the berth, to `Dropoff.drop_point()`, the middle of the
  box's mouth lifted to the top of its heap (see The Piers; the old `DROP_UP` fraction of a
  front-on painting is gone). **Paid for as each one lands**, not when the hull tipped
  them: a piece tagged with a `Dropoff` reaches `Lake._on_haul_arrived` as a sale, so the
  purse and the picture say the same thing — the rule `Haul` was built on. The berth is held
  until the volley is over (`_landing`, the second pass through `State.UNLOADING`), for the
  reason the loading one is: a hull that sails out from under its own cargo in mid-air is
  worse than no animation. With no `Haul` the sale still happens on the spot.
- **A ferry sails only with a full hold** (`Boat.ready_to_sail`, 2026-09-14, Richard: "too
  many missed trips"): auto-dispatch waits until the yard holds `capacity` pieces for it, so
  a hull no longer makes its long trip round the lake for two or three pieces. The one exception is
  a lake with no rubbish left in the water (counted every `DRY_CHECK_EVERY` s), where what is
  in the box is all there will be. The shop's hidden "send now" still sends a part load.
  The tree's pricing sim was calibrated on play from before this change;
  check the box pile-up and ferry income against the next playtest log.
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

### The Net Sorts With The Angler (2026-09-16)
The net node and its rope take **the angler's own walker layer, minus one** (`Lake._sort_walkers`),
rather than a fixed z 8.
- **Why**: the rope starts inside the figure's outline and the body is what hides its cut
  end (`CastNet._lay_rope`), which was written against an angler on `IN_FRONT` (9). The
  angler drops a band behind the crate (7) and two behind the hut (5), and on both of those
  the net and the whole rope were drawn **over** the player — casting up the screen off solid
  ground, the end of the rope showed against the figure (Richard). Following the walker rule
  is what makes "behind the angler" mean it wherever they stand.
- **The cost, behind the hut only**: the net lands on 4, under the floating rubbish at 5, so
  the rope passes behind junk on its way out. The angler is already tied with the soup on
  that band, and a two-pixel line going under a bottle is the lesser wrong.
- Both nets, so the double cast's helper does not sort on its own. `test_lake` walks the
  angler through all three bands and guards it.

### The Piers (`scripts/dropoff.gd`, `tools/build_piers.py`, sheet: `assets/piers.png`, 2026-09-12)
The four merchant yards are isometric pixel art **built from rules, not painted** (issue #10;
Richard: "rebuild in code, isometric", judged on a static mockup before anything in the
lake changed). Each is a jetty of planks on posts running `JETTY_OUT` (3) tiles from the
drawn waterline into the lake, one tile wide, bollards at the end, and a two-by-two tile
platform on the sand behind it carrying the recycle box. The first pass had no sign and no
heap of the material, by decision ("just the pier and the empty box"); **superseded
2026-09-13** — each yard now has a name sign, an emblem carved on its box, and a heap that
comes and goes with each delivery, see the last three bullets. The old signboard and heap
stay behind `WITH_HEAP` / the retired `ICONS` history in the builder's docstring only.
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
  `posts_dry`, `landward`, `box`, `box_ground` (the middle of the diamond the box stands
  on), `drop` (the middle of its mouth), `sign` (the bare plank), `sign_foot`, `sign_cut`
  (the post and plank alone, a fifth picture, for the sign's shadow), `berth_end`. All five
  pictures are one size on one anchor. `Dropoff` reads all of it and measures nothing off
  the picture. `Dropoff.JETTY_OUT` must equal the builder's.
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
  recorded — which is why sand banked on that foot sat in the middle of the pole with its
  bottom showing below, and why walking down from a foot to find "the real bottom" walks
  into the beam. `draw.line` includes its endpoint; the drawn row is the bottom.
- **The sand is drawn on the sprite's grid, not the world's** (`Skirt._pixel`'s `snap`): the
  pier stands at a fractional world position, so its pixels are not on the art lattice
  everything else in `skirt.gd` snaps to, and sand snapped to the lattice landed up to a
  pixel off the wood — a dark line of pole under the heap however the rows were counted.
- **Foam and sand are decided against the lake, not read off the sheet**: at `_ready` every
  post's foot is tested with `Iso.shore_fraction` against the foot's own edge. Past it, a
  `WaterlineFoam` collar (`POST_COLLAR` 8 px half-width) **in front of the post** — behind
  a six-pixel post nothing showed — riding the same swell. Short of it, `Skirt.mound`: sand
  banked over the post's bottom rows, widest at the ground, solid (a gap in the pile is the
  dark pole showing through it), plus grains falling below it only — `spill` scatters a full
  ellipse, so half of every cloud went up the screen onto the deck step. The
  coast curves and the jetty does not, so the pair at the water's edge can fall either side
  depending on the bank; `test_lake` guards that at least the two pairs out along the jetty
  froth.
- **Retired**: `assets/Piers_Asset_Sheet.jpg`, `pier_*.png`, `tools/slice_piers.gd`,
  `export_piers.gd`, `debug_pier_coords.gd`, `Dropoff.PIER_OUT` / `PIER_WIDE` / `PIER_FOOT`
  / `DROP_UP`. The strand rubbish still fills the tiles under a jetty and is hidden by it
  (the dog fetches it from under the deck); clearing the jetty's footprint in `LakeGrid` is
  open.
- **Probe**: `tools/shot_piers.tscn` (desktop build) pans to each yard, heaps `HEAPED`
  pieces into its box and sends three coins, and saves `tools/last_pier_<kind>.png`, the
  front cut it draws over the heap (`last_pier_front_<kind>.png`) and `last_piers.log`
  (foot, berth, collar and spill counts, heap, sign text, the sun). The mockup the design
  was judged on is `tools/last_piers_mockup.png`, rewritten by every builder run.
  **Reimport after running the builder.**
- **The yards are named and marked** (2026-09-13, Richard's call). A **sign**: a post and a
  bare plank the builder paints, with the name written on it at runtime by
  `Dropoff._draw_sign` through `tr()` — `sign_text()` is the one place — so a translation
  changes the sign without a repaint; set at the zoom's own pixel size under a transform
  that undoes the zoom, so the glyphs are the font's at that size and not a bigger drawing
  shrunk. Where it stands is decided in the builder by what is behind the plank on the
  screen: `SIGN_BACK` straight behind the box where that is sand (north and west banks,
  whose platforms lie up the screen from the jetty), and at the platform's side corner,
  `SIGN_POST` tall and hung `SIGN_HANG` px outward over the beach, where it would be water
  (south and east banks — a plank across the waterline was the objection; the sign may
  stand apart from the box as long as it stands on the pier). Its shadow is `Shade.lying`
  from the post's foot, drawn by the yard over its own deck, since a billboard on a post is
  the angler's case and not the box's. **The plank is the menus' carpentry** (Richard,
  same day: "the crevices like the menus, so they don't look too flat"): V bites out of
  its edges narrowing to `SIGN_BITE_TIP`, two a long edge and one an end, the corners
  chamfered, grain dashes in the plank's own tones, all hashed off the yard's name so the
  four are four planks; the pier's outline pass rings the holes. A foot-edge bite is
  steered off the post's column. And an **emblem** carved into the box's lit face:
  the actual sprite of one of the yard's pieces (`EMBLEM_PIECE`: globe, wood piece, hanger,
  duck), laid on the face's own slope, colours sunk `EMBLEM_SOAK` into the plank, grooved in
  the wood's dark and lit-edged left and below (`carve_emblem`). Decoration at 10-13 painted
  px — the face is 16 — and the sign is what tells the yards apart. **Tried and rejected the
  same day**: a stencil of the silhouette projected onto the jetty's planks (a one-tile deck
  gives a mark twenty-odd screen pixels across, a smudge whatever is painted in it), the
  emblem wrapped round the box's corner, and an unpainted relief. The pick was made on
  `tools/last_sign_mockup.png`; `sign_mockup`'s `variants` shows the other rows again.
- **The box fills and empties** (`Dropoff.put` / `_drain`, 2026-09-13): each piece the ferry
  lands goes on a heap drawn inside the box the island crate's way (`_draw_heap`, then the
  near walls cut off the sheet's own box — emblem and all — drawn over it), and the heap
  sinks away `DRAIN_HOLD` after the last landing, one piece per `DRAIN_EVERY`: a readout of
  the last delivery, not stock — nothing reads it, and it is not saved. Its floor is higher
  than the island crate's (`HEAP_FLOOR` 0.72 against 0.55) and its scatter tighter, because a
  delivery is a handful and at the crate's numbers a handful is entirely behind the near
  wall (found on the probe). `drop_point()` is the mouth's middle lifted to the top of the
  heap, so a volley aims into the hole; it used to be the box's bottom corner. **The stand
  and the mouth are rows 24 and 8 of the box art, measured from its top** (`BOX_STAND`,
  `BOX_TOP`): the first bake took the mouth as 16 rows above the bottom corner and aimed
  every delivery 8 rows low.
- **A sale pays in coins** (`scripts/coin_fly.gd`, 2026-09-13): every piece landing at a
  yard sends a coin from the box to the money plate's own coin — in screen space on the
  HUD's layer, `FLIGHT` 0.5 s, and past `MOST` (12) in the air a landing joins the last coin
  sent rather than adding one, so a hundred-piece hold is not a fountain. The purse still
  moves when the piece lands (the rule `Haul` was built on); the plate shines again when
  the coin arrives (`HudSkin.shine`, aimed by `coin_centre`) with a chink (`Sfx.play_chink`,
  one coin of the purchase sound, no more than one per `CHINK_GAP`). `test_lake` guards the
  aim, the sign, the heap and its drain, and the coins' cap and carry.

### The Pigeons (`scripts/flock.gd`, 2026-09-16, `/grill-me` with Richard)
The flock is drawn and placed properly, and a sitting bird is worth spotting.
- **They are drawn over everything** (`Lake.BIRD_LAYER` 21): hulls (12), the haul (8), the
  piers, the walkers, and the net and the finds' beams at 20. At z 6 a bird was cut in half
  by a pier deck, hidden behind a moored hull and walked in front of by the angler. **The
  net too, by decision** — "over everything" was the whole of the instruction, and a bird
  disappearing behind the thing being cast at it is the bug, not the fix. The cost: a bird
  perched behind a pier draws on top of the deck; accepted.
- **A perch is the drawn top of the drawn piece** (`LakeGrid.perch_point`): the same
  arithmetic `_stamp`/`_sprite` lay the quad down with — `tilt`, `swing`, the waterline
  `sunk_by` cut, `nudge`, `shove` and the bob. The old perch was `surface_pos` plus the
  def's raw `size.y * 0.35`, which ignored all four: a bird floated a gap above a small
  piece and stood beside a leaning one. `_perch_height` is gone. **The two must move
  together** — a change to how a piece is cut or turned is a change to where a bird stands.
- **A splat is a blob of whole art pixels, rolled per splat** (`_smudge`, `POOP_CELLS`,
  `POOP_SPECKS`): grown a cell at a time out from the middle, with loose specks flicked
  beyond it, snapped to the art grid. Two tones, body and edge. It was the same pair of
  circles at the same offset every time, which reads as a decal rather than mess. Lives
  roughly halved: island 28 s, open water 3.5 s, on the angler 3 s.
- **A flying bird's shadow is its own silhouette** (`_draw_shadow`, `Shade.lying`), like the
  angler, the dog, the trees and the hull — leaning and stretching with the day. It was a
  black disc: the last shadow on the lake that was not the shape of the thing making it and
  the only one that ignored the sun. At the day's own ink it cannot be seen on water, so it
  takes the hull's bargain (`SHADE_GAIN` 2.4, `SHADE_MOST` 0.45, lighter than the boat's),
  and it shrinks and thins with the height the arc has carried the bird to (`SHADE_SHRINK`,
  `SHADE_THIN`) — a shadow the same size at every height reads as a bird sliding along the
  surface. No day, no shadow. Perched birds cast none; they are standing on their perch.
- **A perched bird inside the net's reach wears a pale rim** (`BirdRim`, `RIM_TONE`,
  `Flock.catchable`): the finds' own trick and the finds' own `rim.gdshader`, with its
  `rim_gold` uniform turned down to a blue-white — **not gold**, which on this lake means
  treasure, and a pigeon is worth a handful of sludge. `CastNet.in_reach` rather than
  `can_cast_to`, so the rim does not blink off while a cast is out. Out of range, or in the
  air, no rim: it is a promise the next cast can keep, not decoration.
- **Out of scope, by decision**: perched-bird shadows, painted splat art, and any change to
  the flock's size, perch timing or what a bird pays.
- `test_lake`'s `_stage_pigeon_look` guards the layer, the perch against the drawn picture
  and its lean, the smudge (all cells different, all touching, no two splats alike), the
  shortened lives, the shader, and the rim's three conditions.

**A bird is a bird** (2026-09-16, second `/grill-me` with Richard; supersedes the
"row"-keyed flock above):
- **The sheet is laid out by action, not by bird**, and that is the whole trap. A row's
  first block is one bird's three-frame flap; its second and third blocks are three
  *different* birds standing and sitting — birds 1-3 on row 1, 4-6 on row 2, 7-9 on row 3,
  with rows 4-6 repeating them. So **bird N's poses live on row (N-1)/3+1 at frame
  (N-1)%3**, never on N's own row. `flock.gd` read the standing frames off the flying
  bird's own row and played them as a cycle, so a perched pigeon changed species every
  0.42 s — the bug Richard reported.
- **The pairing is authored, in `assets/pigeon_birds.json`**: all nine birds, each with its
  three fly cells, its stand cell, its sit cell, a name and a `use` flag. Separate from
  `assets/pigeons.json` for the reason `tools/decor_sets.json` is separate from the
  decoration sheet — the slicer finds the rectangles, only a person can say what they are.
  **In `assets/`, not `tools/`**: the export excludes `tools/*`. `pigeons_used.json` (a
  list of sheet rows) is retired with the idea it encoded.
- **Three birds, by decision**: 1 `slate_head`, 3 `white_dove`, 9 `street`, equal thirds,
  picked once at spawn and kept for life. Change the pick by flipping `use`; **do not
  delete a bird** — the other six stay listed and off.
- **The idle is a stand/sit shuffle, not a cycle**: a bird has exactly two ground pictures,
  so a pose is held `POSE_MIN`..`POSE_MAX` and then **rolled again** (`SIT_ODDS` 0.3, so
  standing can follow standing and the shuffle has no beat). It lands standing — a bird
  that touches down already sat has put its feet away in mid-air. `PERCH_FRAME` is gone.
  Numbers by eye, to be retuned in play.
- **The flap is unchanged**: block 0, `FLY_FRAME` 0.09. Those three frames were always the
  right ones.
- **`tools/pigeon_contact.gd` draws birds now**, one row each — flap, then stand and sit,
  unused ones dimmed. Laid out the sheet's way it is the picture the wrong pairing was
  picked off. Re-run it (needs a window) before the next pick.
- **`test_lake` asks the pixels, not the file**: a bird's poses share all their colours
  with its own flap and at most a third with any other bird's, so a mis-authored
  `pigeon_birds.json` fails rather than agreeing with itself. It also guards the three
  chosen birds, that a perched bird only ever shows its own two poses, and that it lands
  standing.

**The head that pops in** (`scripts/pigeon_pop.gd`, `Lake.POP_ODDS` 0.5): netting a bird
pays on the spot, and the only sign of it was a splash out where the player was not
looking. So on half the catches the bird's head slides in from the side of the screen, coos
(`Sfx.play_coo`) and says what it paid. Mortal Kombat II's Toasty, and deliberately not
solemn — a gag that fires every time is a notification. Its own `CanvasLayer` at 18, under
the finds card. The portrait is `assets/pigeon_head.png`, its own drawing rather than a
crop of the flock's eleven-pixel birds, cut by `tools/slice_pigeon_head.gd`.
- **It comes in halfway down the left edge, leaning** (2026-09-16, Richard). The painting
  is a head cut off at the neck and **the cut is its bottom edge**, so whichever screen edge
  that cut is laid against is the edge that does the hiding. Mirrored (`_turned`, baked) it
  faces right; leant `HEAD_LEAN` (**54 degrees**, picked off the mockup after 65 read as too
  square) clockwise the beak swings **down** and the cut comes round to the **left**, where
  the screen's own side cuts it. `HEAD_DOWN` 0.5.
- **The lean is drawn, not baked, and only the head turns**: there is no turning a picture a
  fraction of a quarter without resampling it, and this is pixel art — so `_draw` sets the
  canvas transform for the one `draw_texture_rect` and puts it straight again, or the price
  tag leans over with the bird.
- **How far past the edge it stands is measured off the painting** (`_measure_cut`,
  `cut_reach()`, `CUT_BAND`): the far end of the cut is put `HEAD_TUCK` (0.04 of the head's
  height) past the edge, and where that end lands depends on the lean — so the number is
  read off the art the way `Skirt.hem` reads a silhouette, not written down. Nudge
  `HEAD_LEAN` and the placement follows. **The reach starts at minus infinity, not zero**:
  leant this far the whole cut sits left of the head's middle, and a floor of zero threw
  that away and shoved the bird half off the screen.
- **Retired, in order**: standing upright and mirrored in the **bottom left corner** with
  its neck on the bottom edge (that corner is the pollution meter's, and the two sat on top
  of each other; `HEAD_SINK` went with it), then a flat **quarter turn** with the beak up —
  a head at ninety degrees has fallen over, and it was looking away out of the screen.
- **Where it is drawn is `head_centre()` and `head_box()`**, asked by the harness too, so
  the check that keeps the bird off the meter cannot measure a second layout and drift from
  the first.
- **Every catch sends a coin** to the money plate, the way a sale at a yard does
  (2026-09-16). A pigeon was the only money in the game that arrived with nothing crossing
  the screen. **Every catch, not just the ones that get the head** — the coin is the receipt
  for the money and the money is not part of the joke — and not while the shed is up, whose
  room covers the plate it is aimed at.
- **The coin leaves the bird, so with a head it leaves the head** (`PigeonPop.arrived`,
  `coin_from`, `CoinFly.fly_from`, `Lake._on_pigeon_arrived`): the pop emits once it has
  finished sliding in, and the coin sets off from the middle of what the head covers. It has
  to **wait for the head** — fired at the catch it left an empty edge of the screen a tenth
  of a second before the pigeon got there, which is money from nowhere. `pop()` returns
  false when there is no art, so the lake knows no head is coming and falls back to the
  bird's own splash on the water (`_send_bird_coin`). `fly_from` is `fly` without the canvas
  transform: the pop is on a `CanvasLayer` and has no place on the lake at all. One head is
  one coin, however long it is held.
- `test_lake` guards the head against the meter's own box, its place down the screen, that
  the side cuts it and that the whole of the cut is past the edge, that it leans rather than
  lying on its side, that the coin waits for the head and then leaves it (one a head), and
  that a catch with no head still pays off the water.

### Nature Coming Back (2026-09-16, `/grill-me` with Richard; a spike, to judge in play)
The clean state gains density as the lake is cleaned: fish in the clean water, flora on the
shores, and a tease of the finished sparkle. Three nodes, nothing saved, everything derived
from the filth map and `Lake._clean_share` (the share of wet lake tiles whose
`LakeGrid.water_state` is 0, counted in `_count_clean` on every map build; the island's clean
ring gives a fresh lake about 0.001).
- **Driver = local clean + global stage**, by decision: a thing appears only where the honest
  map says clean, and how much appears is the whole lake's share. **The transient catch
  patches are never read** — a patch that closes never held a fish.
- **Fish are purely ambient** (`scripts/fish.gd`, z 3, between the water and the splash
  layer): no catch, no pay, no target, and `test_lake` guards there is no `catch`/`pay`.
  Three tiers by share (`Fish.TIERS`, `at` 0.12 / 0.38 / 0.68: minnow schools, perch-size
  schools, one or two carp; tiers accumulate), so many schools per clean tile (`per_tiles`,
  capped `most`), reconciled every `RECKON_EVERY`. Seen only as a **shadow** (a fish-shaped
  polygon on the plane, `_shadow`, not art-pixel snapped — open) and **rings** through
  `WaterSplash.ripple` from a member every `ripple` s. They wander, look `LOOK_AHEAD` tiles
  ahead and turn off foul water, fade out and are replaced if they end up in it, and **flee**
  (`scare`) from a net landing (`Lake._on_net_landed`) and from every hull each frame.
- **Flora is decoration only** (`scripts/flora.gd`, z 3): no collision, no footprint, kept
  out of the hut (`Iso.in_shed` at `SHED_COVER`) and off the crate (`Yard.covers`). Every
  candidate is rolled once at build (`_sow`: `LAWN_SPOTS` per lawn tile, one per beach tile
  within `BANK_REACH` of the outer bank's water and on the island, one per water tile in the
  `PAD_OUT` ring off each shore for lily pads), with a species by ground kind and a rank. A
  candidate is due when the water beside it (`_water_beside`: itself, or the first lake
  tile walking out from its shore) reads clean **and** its rank is under `stage * MOST`.
  Once due it **grows in** over `GROW_TIME`, staggered by `GROW_STAGGER`: sprout frame until
  `SPROUT_UNTIL`, then the full picture rising. Never regresses (the lake cannot get
  dirtier); `reset()` exists for the harness only. One triangle array off `assets/flora.png`
  — Ground's rule, anything in the hundreds is one batch.
- **The sheet is built, not painted** (`tools/build_flora.py`, psd-extract venv python, from
  the project root; **reimport after a re-run**): flowers, patches, shrubs (lawn), reeds,
  pale grass, small flowers (beach), lily pads plain/pink/white (water), each with a sprout,
  all off `palette.tres` swatches lifted or mixed, at one painted px drawn at 2. Rectangles
  and kinds in `assets/flora.json`; contact sheet `tools/last_flora_sheet.png`. Richard may
  hand-polish the PNG; the json holds while the rectangles do.
- **The glimmer is rare glints, not per-tile sparkle** (`water.gdshader` `glint`,
  `glint_cell`/`glint_rate`/`glint_fps`; pushed as `pow(share, GLINT_BITE) * GLINT_MOST` from
  `_build_filth_map`): one art pixel of the top step popping per `glint_cell` square at most,
  only where the map's filth is under the clean cutoff (`state_at.x`; this said `murky_at`,
  which the shader does not have), so nothing pops in the soup. The finished lake's
  `sparkle` is untouched. **Cut twice**: 2026-09-16 (`GLINT_MOST` 0.7 to 0.4, cell 14 to
  20), and 2026-09-18 on both knobs (Richard: "decrease the clean lake sparkle while lake is
  still grimy") — `GLINT_MOST` **0.25** and `GLINT_BITE` 1.4 to **2.5**, so at half clean
  the glint is 0.044 where it was 0.15. The light belongs to the last stretch.
- **A third more fish** (2026-09-18, Richard: "increase fish population by a little"):
  `most` 14/7/2 to **18/9/3**, `per_tiles` 70/160/700 to **55/125/550**. Arrival shares,
  school sizes and ink untouched. `shot_nature` at these numbers: 27 schools at 46% clean,
  30 at 84%.
- **Out of scope, by decision**: fish as catch or pay, fish sprites, blocking flora, flora on
  the piers, birds/insects, sound, per-tile sparkle, reading the patches.
- **Numbers are first guesses** — tiers, densities, `MOST`, `BANK_REACH`, the shadows' ink —
  for Richard to retune in play. Bench on a fresh lake: 2.77 ms mean, worst 4.36, but a
  fresh lake has no fish or flora yet; **re-bench on a half-clean save** before calling the
  8 ms bar met.
- `test_lake`'s `_stage_nature` refills the lake, checks the fresh share is small, empties the
  west half, and guards: candidates on the right ground and off the hut and crate, plants
  come due only beside clean water, fish arrive and are never shown in foul water, a scare
  turns them away, the glint uniform is between 0 and 1. Probe: `tools/shot_nature.tscn`
  (desktop build, `--fixed-fps 60`, own save) saves `tools/last_nature_{fresh,half,clean}.png`
  and `last_nature.log`.

### The Market Board and the Luck Tracks (2026-09-13, old shop only)
**2026-09-18**: the five sell-by-tier tracks and `tier_pay` are deleted, not shelved.
**2026-09-14**: the five sell-by-tier tracks are shelved (`Lake.SHELVED`, no rows, at par);
the market board carries Recycle Bonus and Pigeons only. See The Shop Balance Pass.
Five upgrades built from what the game already had, no new art, decided with `/grill-me`
(Richard: skimmer stays cut; helper, idle and tree-mode upgrades out of scope; **old shop
only**, the tree run sells at par and rolls no luck). **Superseded in part on 2026-09-14**:
Lucky Haul, Double Cast, Recycle Bonus and Pigeons are tree nodes now (see Tree Test Mode); a tree
run still sells every tier at par. Nine tracks, all `UpgradeTrack`
`.tres` under `resources/upgrades/`, in `UPGRADE_ORDER`/`TRACKS`, saved under `levels`
like the rest (no `SAVE_VERSION` bump: a missing key reads as level 0).
- **The market** is a fourth drawn board (`ShopSkin.BOARDS` `&"market"`, head the money
  plate's own coin through `HudButtons.coin`; `BOARDS_WIDE` 900 to 1180 for it):
  - **Sell by weight tier** — `sell_0`..`sell_4`, one per `TrashDef.tier`, named by
    `Lake.TIER_NAMES` (Light/Small/Medium/Heavy/Bulky); each multiplies that tier's pay
    and no other's (`tier_pay`). Heavier tiers cost more to start.
  - **Recycle Bonus** — `recycle_bonus`. Once the first level is owned one yard is always
    boosted, and every `BONUS_EVERY` (30 s, **fixed**: the upgrade raises the bonus, never
    the time) it hops to a *different* yard (`_move_bonus`). **Counts at the sale**: a piece
    landing at the boosted yard inside the window, whenever it was netted (Richard's call
    over tagging at the catch). Shown in the world with **the finds' own shine on the box**
    (`Dropoff.boosted`, `Dropoff.Shine`/`Stars`: the beam shader column and
    `GlintTwinkle.draw_star`), no HUD timer; the shop row says which yard and how long.
    Not saved — a load rolls a fresh yard.
  - **Pigeons** — `bird_worth`, a multiplier on `EconomyConfig.bird_bonus` (`bird_pay`).
    Bird count unchanged, by decision.
- **On the net's board**:
  - **Lucky haul** — `lucky_haul`, odds per cast. Rolled in `Lake._roll_luck` after the
    throw; the net carries `luck_power` 1 and `luck_hold` `LUCKY_EXTRA` (4) **for that cast
    only** (`CastNet.strength()`/`room_left()`, cleared in `_come_home`), and is drawn in
    the finds' gold while it does. The aim marker reads the plain `power`.
  - **Double cast** — `double_cast`, odds per cast. A second `CastNet` (`Lake._net2`,
    `helper = true`: it never plays or ends the angler's throw, hidden while stowed so it
    draws no second ring) is thrown the same moment at `_double_spot`: a tile within
    `DOUBLE_NEAR` (4) of the first net's target, at least `DOUBLE_APART` (1.5) from it,
    with a liftable piece on top, inside the angler's range. **Own hold** (Richard's call, so
    it stays useful once every cast fills the bag). None found, no second net — luck on
    bare water throws nothing, which at the starting 3.4-tile range is most of the time.
    The camera frames the first net only.
- Pay is one function now: `Lake.piece_pay(def, kind)` = flat + filth, times the tier's
  track, times the bonus at that yard. Both sale paths (`_on_haul_arrived`, the ferry's
  `sold`) go through `_on_sold` into it.
- **Open**: numbers are first guesses, untuned in play; the `economy_config.gd` comment
  claiming heavy pieces outearn light ones is still contradicted by the data (~13%) — the
  per-tier tracks are the knob that can make it true. Row text is not clipped
  (`ShopSkin._draw_row`): a long name still runs under its tag, as the dog's did before.
- Tests: `test_lake`'s `_stage_market` (tracks load, seven rows a board, tier pay, bonus
  placement/shine/pay/hop, bird pay, luck fields and their clearing, the helper net and its
  spot); `_stage_save` round-trips a sell level.

### The Rows Read in Percents, and Explain Themselves (2026-09-13, old shop only)
**Largely superseded 2026-09-17 by The Shop Reads below**: the "(… next)" bracket, the seven
value grammars, the "Lvl n" footnote on the name line and the "?" hung on a row's corner are
all gone. What still holds: percents and whole numbers, no tenths, a blurb per track, and
the two lines stopping short of the price tag.
Decided with `/grill-me` (Richard): the upgrade rows use **percentages and whole numbers
only**, say what the next level buys, carry a "?" each, and the market is explained once.
- **Values** (`Lake._shop_rows`, `_pct_at`, `_track_value`): a track that scales a rate reads
  as a percent over its level 0 ("+40%"; "+0%" to begin with), a track that counts reads as
  the count ("3 per cast", "Tier 2", "waits 4s at most"), odds as percents; **no tenths
  anywhere**. Each row's line is built by one closure over a level, so the next level's
  figure follows in brackets, "(+55% next)", and a maxed row shows now alone. The tier rows
  read "+0% (+15% next)" — the name is the tier. `test_lake` guards no "." in any value.
- **The level is a footnote** (`Style.TEXT_TINY`, "Lvl n", still `LEVEL_INK` after the name).
- **Both lines stop short of the tag** (`ShopSkin._tag_of`, `_cut_to`): the name drops to
  `TEXT_SMALL` before its level is given up; the value drops to `TEXT_TINY`, then loses the
  word "next", then is cut with an ellipsis. This supersedes "row text is not clipped" above.
- **The "?"** (`HELP_SIZE`, `help_box_of`, `_draw_help`): an oak tag hung out over each
  row's top-left corner (`HELP_INSET` negative — set inside the plate it took a strip off
  every row, Richard 2026-09-13), the writing starts past what is inside; hovering it draws the row's `blurb` on a plate in the
  boards' wood beside it (`_draw_blurb`, `_wrap` — `Style.write` has no wrap), clicking it
  buys nothing. **Blurbs are placeholders** (`Lake.BLURBS`, one line a track) for Richard to
  rewrite; a track added to `TRACKS` needs one, `test_lake` checks.
- **The legend** (`Lake._shop_legend`, `_mean_pay_of`, `ShopSkin.legend`, `_draw_legend`):
  one plate in the boards' wood centred under the ferry's and the dog's boards — the
  shortest, so the room under them is the shop's free space. Three parts, by Richard's
  second pass the same day ("more concise"): the four materials spread across the top with
  what a rubbish piece of each pays on average today, in the price's gold, under each
  (mean `piece_pay` over the non-keepsake defs of that material, at today's tier rates and
  bonus); **no tier line** — `_shop_legend` has returned `tiers` empty since the sell tracks
  were shelved, and this said otherwise until 2026-09-17; and the one sentence "Collect
  objects of different materials and tiers, each pays a flat fee plus bonuses." **Cut**: the
  "Yards:" line, the yard rule, the bonus line and the pay-rule sentence. Drawn only when at
  least `LEGEND_LEAST` is free. Percent and whole dollars only.
- **TreeScreen untouched**, by decision. Probe: `tools/shot_menus.tscn` now also saves
  `tools/last_menu_upgrades_help.png` with the first row's "?" hovered.

### The Settings Menu (issue #26, 2026-09-16, `/grill-me` with Richard)
The final settings menu: four audio buses with a master over them, four display rows, and
every verb rebindable on both devices. **Two boards, by Richard's call** — the settings board
keeps the sound and screen rows and its Controls row opens `ControlsSkin`, because a table of
fifteen verbs on two devices does not belong under a volume slider.
- **The mix is audio buses now** (`Prefs.BUS_*`, `_build_buses`, `apply_audio`): Master over
  Music, SFX and Ambience, built in code at boot rather than in a bus layout resource (a
  second file saying what four lines say). `Sfx` and `MusicStation` no longer hold a copy of
  what the player set and no longer add it to every player — they set each sound's own
  balance and their fades, and every voice names its bus. `Sfx._trim`, `Sfx.level`/`on`/
  `ambience_level`/`ambience_on`, `MusicStation.set_level` and both `LOUDEST` constants are
  gone, and the tops they carried are `BUS_TOP`. **Master's top is 0 dB and its default is
  full**, so a player who never touches it hears the mix exactly as it was tuned by ear.
  A slider at `SLIDER_FLOOR` mutes its bus rather than leaving it whispering.
  **`Sfx.may_play` no longer asks the volume**: a muted bus is the mute, and asking the
  setting as well would be a second copy of it.
- **The lake and the menu push nothing** (`Lake._push_music`/`_push_sfx`/`_push_ambience`,
  `MainMenu._push_music`/`_drag_music`, all gone): the board writes `Prefs`, `Prefs` sets the
  buses. A drag is `Prefs.preview` (heard at once, not written) and the release is
  `Prefs.store` (written), which is the rule the sliders already followed.
- **Display rows**: Window (Windowed / Borderless / Exclusive, replacing the Fullscreen
  switch — **F11 still flips windowed and borderless**, the two that cannot go wrong),
  Resolution, VSync (Off / On / Adaptive) and Frame cap (uncapped, 30, 60, 120, 144).
- **The resolution is a windowed-mode setting, by decision**: in either fullscreen the row is
  dimmed and reads the monitor's own size, and picking one does nothing. So no display row
  can hand a screen a mode it will not show except exclusive, which asks (below). The list is
  **measured against the monitor**, floored at `Prefs.LEAST_WINDOW` (1280x720, under which
  the drawn boards stop fitting).
- **Exclusive fullscreen asks to be kept** (`SettingsSkin._try_window_mode`, `REVERT_AFTER`
  10 s, Richard asked for the safeguard): the mode is taken, a `MenuConfirm` counts down, and
  nothing answering puts the window back — a player looking at a black screen cannot click
  "no". `MenuConfirm`'s words are the caller's now (`title`/`words`/`yes_label`/`no_label`,
  the menu's "Start over?" as the defaults) rather than a second board beside it.
- **A choice row is arrows, except the resolution** (Richard's call): `◂ Borderless ▸` reads
  at a glance and costs no second layer, but a dozen window sizes behind a pair of arrows is
  a lot of clicking, so that one value drops a short list over the board.
- **Nothing in `settings.cfg` is ever refused** (`Prefs`' header): a save file from an older
  build is thrown away rather than migrated, but a settings file is not a save file. A value
  that makes no sense here — a resolution no monitor has, a bind for an action that no longer
  exists, a window mode from a build that had four — falls back to its default and is written
  back, and the worst a bad line costs is that one setting. An old file's `fullscreen` true
  becomes **borderless**, which is what that switch did.

### The Bind Board (`scripts/binds.gd`, `scripts/controls_skin.gd`, same pass)
- **The InputMap is built from `Binds.ACTIONS`, not from `project.godot`**: the actions are
  still listed there so the editor's inspector knows their names, but with **no events** —
  `Binds.install()` erases and refills them at boot, from its own table and then the player's
  overrides. A default in a serialised `Object(InputEventKey, ...)` string in an ini file is a
  default nobody can read or change; here it is a line of GDScript.
  **Don't explain that in `project.godot` itself** (2026-09-17): a comment saying so stood
  over `[input]` and the editor deleted it the first time it re-saved the file — Godot writes
  that file out of its own memory and keeps no comments. The `binds.gd` header and this
  section are where it is written down, and they are the only two places that survive.
- **The keys were always physical and that was never the bug** — `physical_keycode` is a hole
  in the keyboard, so the walk keys sit under the same fingers on AZERTY. What was wrong was
  the **labels**: the game said "W/A/S/D", "E", "Y" in so many words. `Binds.label_of` /
  `key_name` ask the OS what is printed on that hole
  (`DisplayServer.keyboard_get_label_from_physical`), so a French player is told ZQSD and a
  German one Y where we say Z. **No keyboard-layout row, by decision** (Richard, after the
  physical binds were pointed out): there is nothing for the player to get wrong and it works
  for every layout rather than the two we thought of. A real ZQSD keycode preset would move
  the keys *away* from the fingers.
- **Every verb is in the map now**: `cast`, `lay_net`, `interact`, `open_shed`,
  `open_upgrades`, `open_settings`, `zoom_in`, `zoom_out`, `recentre`, `shed_rotate`,
  `shed_switch` beside the four `walk_*`. The `KEY_E` / `KEY_R` checks and the raw wheel and
  mouse-button reads in `Lake._unhandled_input` and `ShedRoom._unhandled_key_input` are gone.
  The old `pad_*` actions are gone with them — one action holds both devices — bar `pad_back`
  and the four `aim_*` sticks, which the player never rebinds (`Binds.FIXED`).
- **Only the desk is read in `_unhandled_input`** (`Lake._desk_pressed`), and **the pad tick
  runs only in pad mode** (`Lake._pad_tick`): the pad's buttons are still read once a frame in
  `_pad_buttons`, because a trigger is an axis and a held axis is a stream of events — but
  `Input.is_action_just_pressed` cannot tell which device pressed an action, and an action
  holds both devices now. Read on every frame it answered the keyboard's Escape and the
  mouse's click as well, and the desk answered them again: Escape opened the settings in the
  tick and the desk shut them in the same frame, so **Escape looked dead** (found by Richard
  the same day). Two answers to one press is no answer. `test_lake` presses Escape in mouse
  mode and runs the tick by hand.
- **Conflicts are checked inside a context, not across the table** (`CONTEXT_LAKE` /
  `CONTEXT_SHED`): X opens the shed out there and turns the piece in your hands in here, E
  works the thing in front of you and works a switch — one button, two places, which is the
  design and not a mistake. Within a context a new binding **swaps** with whatever held it
  (Richard's call over refusing it or allowing duplicates), so nothing is left unbound.
- **Escape is never bound and never captured**: it is what cancels a capture. `open_settings`
  is on Escape by default, so **right-click a cell** puts it back to the table's own — the
  only way back to a binding the capture will not take. Sticks are not bindable either
  (walking and aiming are what they are); triggers are.
- **Not rebindable, by decision**: Escape as back, F11, M, and the debug keys F3/F4/F6/F7 —
  a player who rebinds the way out of a board has no way out of the board, and the tuners are
  not shipped features.
- **The pan drag is the middle button, not a verb** (`Lake.PAN_BUTTON`): a drag is a gesture,
  and `recentre` is the verb the board moves. A `recentre` bound to a mouse button is still
  the tap-after-drag; any other binding acts on the press.
- **The binds live in `settings.cfg`** under `[binds]`, one line a changed cell
  (`walk_up.key = "key:87"`), and **only what differs from the table is kept**, so a default
  retuned later reaches a player who never touched that row.
- **Out of scope, by decision**: mute-when-unfocused, an aim-assist or sensitivity row
  (issue #33 left those out), a reset-progress row in the settings (the menu's New game
  confirm stays the only one), and the language row — **all of that is issue #28**.
- **The bind board reads with the rest** (2026-09-17, `/grill-me` with Richard,
  `_stage_binds_shape`): the same pass the shop and the settings board had.
  - **The two columns are named** — `Keyboard` and `Gamepad`, in a band of their own above the
    first group. It was a table of thirty cells with nothing saying which half was which.
  - **The gesture that is the only way out is said, once there is something to go back from**
    (`ControlsSkin.HINT`, drawn only while `Binds.changed()`, its room reserved either way so
    the board does not jump the first time somebody rebinds). Right-click restores one cell,
    and that is not a convenience: `open_settings` is on Escape, Escape is what cancels a
    capture, so right-click is the **only** route back to that binding short of throwing all
    fifteen away. **The board went 560 to 640 wide to pay for it** — it is short of room down
    the screen (666 of the 680 the smallest frame leaves) and has plenty across, and the hint
    stands in the empty left half of a band that had to exist anyway. At 560 that half was
    234 px and nothing saying the whole gesture fitted; at 640 it is 314 against 296.
    The middle dot is Bungee's (`tools/probe_hint.gd`, which also measures the candidates).
  - **"Set to default", and it asks first** (Richard: the rename, and the confirm). Fifteen
    rows of somebody's own arrangement is not nothing, so the plank opens `MenuConfirm` with
    this board's words rather than wiping on the click: **"Are you sure?" / "Set to default" /
    "Keep current"**, with **no line under the title** (Richard's wording, 2026-09-17): the two
    doors each say what they do, and a sentence saying it a third time is one nobody reads.
    `MenuConfirm` takes an empty `words` now and **stands shorter for it** rather than leaving
    the band empty — a gap where a sentence used to be reads as a sentence that failed to draw.
  - **The words fit the one board rather than the board stretching for them.** A door is 174
    and the line 358; "Keep current buttons" measured 209 and was cut to "Keep current" (126).
    A `board_wide` per caller was built first and
    thrown away — one width the words must clear is a rule, a width per caller is a place for
    them to drift. Found on the way: **the menu's own line had been overrunning its board by
    ten pixels** — "The saved lake will be thrown away." is 348 against the 338 a 400-wide
    board leaves, and `Style.write` neither wraps nor clips — so `BOARD_WIDE` went 400 to
    **420**. `tools/probe_confirm.gd` measures the lines and the doors; `test_lake` guards
    every caller's words and both its labels against the room they actually get.
  - **Open, and known**: `MenuConfirm`'s own doors are still the frame's pale oak, so its
    warning label reads **1.37:1** and its plain one **2.97:1** — the exact defect the
    settings board's and this board's foot buttons were just taken off that face to fix. It
    was out of scope for this pass by decision and is owed the same one-line change.
  - **The plank is the settings board's dark plate.** On the frame's oak its word read
    **2.97:1** and nothing pale clears 4.5:1 on that face. With nothing to undo it draws **no
    lit edge** — the face cannot be dimmed to say so, being the board's own colour, and a lit
    edge is what says a button can be pressed.
  - **A walking row's pad cell reads `Left stick`**, not `—`. The stick moves the angler
    through the row's `extra` list and is `FIXED`, so a dash was telling the player the verb
    had no gamepad control at all. `Binds.standing_label` reads it off the table's own
    `extra`, so a verb given a stick later says so with nothing here edited. **The keyboard
    column is untouched, by decision** — the arrow keys stay unmentioned.
  - **One row face**, and a row that has just taken a moved binding is marked the shop's way:
    `Style.BOARD_ROW_LIT` with `Style.lit_edge` over it. That swatch is **as far as a lift can
    go** — at 1.17x the row's luminance the writing still clears 4.5:1 (4.62) and a lift big
    enough to carry the moment alone would not, so the lit edge carries it.
  - **The capture cell keeps its gold and takes dark ink**: cream on `ON_GOLD` was **2.40:1**,
    the least legible thing on the board at the one moment the player is staring at it.
  - **Every word clears 4.5:1**, worst 4.62. Overflow is counted (`dropped_lines`) and
    `test_lake` lays the board out at 1280x720 and asks for zero, the settings board's rule.
  - **A test that rebinds puts the player's keys back**: `Binds.overrides` /
    `take_overrides` exist for that and nothing in the game calls them. `shot_menus` borrows
    the board the same way — the captured picture needs a touched board, since the hint and
    the swap flash only exist in that state.
- `test_lake`'s `_check_buses` / `_check_display` / `_check_binds` guard the four buses and
  what is on them, a full Master changing nothing, the floor muting, the display choices, the
  resolution row being windowed-only, the physical defaults, the swap, the context sharing,
  what cannot be captured, and the file round-trip. Probe: `tools/shot_menus.tscn` also saves
  `last_menu_settings_list.png`, `last_menu_controls.png` and `last_menu_controls_capture.png`.

### The Gamepad (issue #33, 2026-09-14, `/grill-me` with Richard)
A trial of full controller support, to decide keep or drop after playtesting. Xbox names.
- **The last device wins** (`scripts/pad.gd`, autoload `Pad`): a pad button, or a stick or
  trigger past `WAKE_AXIS`, switches to pad mode; the mouse moved `MOUSE_WAKE` px or clicked
  switches back. No setting. The mouse pointer is hidden in pad mode on the bare lake.
- **Lake**: left stick walks (added to `walk_*`), right stick aims, RT casts, LT lays a lit
  net, A interacts (the shed door, petting the dog), X opens the shed from anywhere (the
  decorate button), Y opens the upgrades, Start opens the settings, LB/RB zoom out/in about
  the reticle, R3 puts the reticle back on the angler. Read in `Lake._pad_buttons` with
  `is_action_just_pressed`, because a trigger is an axis and a held axis sends many events.
- **The reticle is free** (`scripts/pad_aim.gd`, `PadAim`): the stick sets its speed (view
  heights a second, so the same on screen at every zoom). It stays on its spot in the world
  when the stick is let go and when the angler walks. The view leans towards it
  (`Lake._pad_framed`, which calls `_framed_on`), but keeps the angler inside
  `PAD_ANGLER_INSET` first, so walking away pushes the reticle along by the window's edge
  (`PadAim.hold_in`). `Lake.aim_point` / `CastNet.aim_point` are the one place that decides
  what is being aimed at.
- **The assist is subtle and only acts while the stick is pushed** (Richard: "just to help,
  not to fully auto aim and lock on"): over a green spot the reticle slows to `FRICTION`;
  short of one it drifts towards the nearest green spot within `REACH` mouth widths, at
  `PULL` of the speed the stick asks for (`CastNet.nearest_catch`). A still stick means no
  movement at all. Spots behind the push (cosine under `AHEAD`) are skipped, so the assist
  can bend the aim but never hold it back. **Green means green on the marker**
  (`would_catch`), picked over counting pieces or favouring finds. The numbers are first
  guesses for Richard to retune.
- **Menus use a virtual cursor, by decision**, not focus navigation: wherever the scene
  wants a pointer (`pad_cursor_wanted`: on the lake, while a board, the farewell or the main
  menu is up; a scene without the method always wants one), the right stick moves
  the real pointer (`warp_mouse`) and `Pad` turns buttons into real events tagged
  `SYNTH_DEVICE`: A is the left button (hold to drag), B is Escape, LB/RB are the wheel. In
  the shed, X turns the piece in hand and Y works a switch, and the shed's prompt and the
  tree screen's help line show pad buttons in pad mode. **In the shed, A picks a piece up
  and the next A puts it down** (`ShedRoom._gui_input` tells a pad click by its
  `SYNTH_DEVICE` tag; the mouse still drags), and **while a piece is in hand the left stick
  moves it** (`_carry_with_pad`), because the player stands still while carrying anyway.
- **The aim ring stays up while a cast is out** (2026-09-14, both pad and mouse): drawn over
  the net by `CastNet._draw` so the next throw can be lined up, with the same green/red
  verdict (`in_reach` is `can_cast_to` without the idle check). Not on the double cast's
  second net. The laid-net ghost is still idle only, and the assist works during a cast too.
- **Out of scope for now**: focus navigation, button glyph art, rumble, a Steam Deck pass,
  an aim-assist setting.
- **Tests**: `test_lake`'s `_stage_pad` covers the input map, mode switching, the reticle,
  the assist (still stick, bend, never backwards, friction) and the lean.
  `tools/probe_pad_cursor.tscn` (desktop build, not `--headless`) checks that the pad's
  click, wheel and Escape land where the pointer is in a stretched window
  (`tools/last_pad_cursor.log`).

### The Pointer and the Aim Ring (2026-09-16, `/grill-me` with Richard)
The mouse pointer is a wooden arrow, and the net's aim marker is painted off the palette.
Both were picked by Richard off one contact sheet, `tools/last_cursor_mockup.png`, written
by `tools/build_cursor.py` (psd-extract venv python, from the project root; **reimport
after a re-run**). The sheet still draws every option that was offered.

- **One arrow, everywhere, set once at boot** (`Pad.CURSOR_ART`, `Pad.wear_wood` from
  `_ready`): menu, lake, shed, every board. It lives in `Pad` because that is already the
  one node that decides what the pointer *does* — whether it is shown at all, and where it
  is while the pad drives it — so what it looks like belongs beside those.
- **A quick water ripple answers the click** (`ClickRipple`, `scripts/click_ripple.gd`,
  `Pad.ripples`/`ring_water`/`RIPPLE_LAYER` 40): two rings staggered `STAGGER` (0.07 s)
  apart, opening `FROM` 3 to `TO` 22 screen pixels over `LIFE` (0.30 s), out fast and
  slowing, fading the whole way, in the 2:1 of every ellipse in this game and in the
  wading rings' own pale (`Angler.RIPPLE_*`). Over the menus and the boards as well as the
  lake, because the cursor is one cursor everywhere.
  - **Drawn on a layer of its own, not baked into the cursor picture**: a hardware cursor
    can hold a pose but not an animation. **Retired, by decision** (Richard, same day): a
    bead of lake water baked into a second picture and swapped in while the button was
    down — first standing clear of the arrow, then tucked under its point with the wood
    over it. Both read as decoration hanging off the pointer rather than as an answer to
    the press. `assets/cursor_press.png` and the builder's drop are gone with it.
  - **A zero-sized `Control` under a `CanvasLayer` is culled before it is drawn**, whatever
    its `_draw` puts out — an opaque red rect from one does not reach the screen either.
    Anchors will not size it, because it has no parent `Control` to anchor against, so
    `_fit` sets it to the viewport and follows `size_changed`. `test_lake` guards the size
    for that reason alone.
  - **The canvas is 1280x720 and the window is not**: the pointer, the ripple and every
    other drawn thing live in the stretched canvas, so `ring_water` takes the viewport's
    mouse position and `tools/shot_ripple.gd` scales its crop. A point written in window
    pixels is off the bottom of the canvas.
  - **The ripple is rung before the synthetic events are dropped** in `Pad._input`, so the
    pad's own A button rings the water exactly as a mouse click does. **Nothing rings where
    there is no pointer** — pad mode on the bare lake hides the mouse — asked of `Pad`'s own
    `_shown` rather than of `Input.mouse_mode`, which is a second answer that can differ
    from the one this node gave.
  - `MOST` (6) caps what can be ringing at once, and an empty list stops both the clock and
    the redraws, so an idle menu costs nothing.
  - Probe: `tools/shot_ripple.tscn` (desktop build, `--fixed-fps 60`) rings it over the menu
    and saves `tools/last_ripple_{open,wide,going}.png`.
- **No other shape, by decision**: the I-beam, the hand and the drag cursor Godot swaps in
  for itself are left stock, and there is no hover picture. The game has one
  clickable language and it is drawn boards; a second wooden shape would have nothing to
  mean. The arrow is **always drawn on the lake** too, over the aim ring, by decision — it
  is what says the mouse is being listened to when the ring is dashed or off water.
- **Menu oak, bitten, at 2x** (`PICKED` in the builder): `Style.FRAME` body, `FRAME_LIT`
  along the lit top-left edge, `FRAME_LOW` on the shaded one, `FRAME_GRAIN` dashes running
  lengthwise, and two V bites out of the long diagonal edge — the menus' own carpentry.
  Drawn at the 2 screen pixels an art pixel the rest of the game's art is drawn at
  (26x42). The recycle box's plank brown was the other option on the sheet.
- **The straight left edge and the tip are left whole, by decision**: the left edge is the
  arrow's identity and the tip is the hotspot, so a notch in either reads as a broken
  pointer rather than as chipped wood. Twelve pixels across is not room for more bites.
- **`FRAME_DEEP` is not the shaded face**: at a pixel wide it is close enough to the black
  outline that the two read as one fat rim. `FRAME_LOW` is what gives the wood form.
- **The silhouette is a polygon, rasterised** (`ARROW`, `ART_TALL`, `RASTER`), not a table
  of rows: one number resizes the whole arrow and the diagonals stay clean at any of them.
  A hand-authored 10x16 row table was the first pass and had no room for grain or bites.
- **The hotspot is the tip** (`Pad.CURSOR_TIP`, one art pixel in from each edge for the
  outline, times the baked scale). The builder prints it; the two must agree or every click
  lands off the point of the arrow. Missing art leaves the system pointer alone — a game
  with no cursor at all is worse than one with the stock arrow.
- **The ring's three readings are the palette's own** (`CastNet.AIM_OK`/`AIM_NO`/`AIM_FAR`):
  the pack's measured `grass_light` and its `wood` red-brown, each **lifted by `AIM_LIFT`**
  (1.52), and the lake's `foam` white — in place of the screen green and fire-engine red
  they were. **The meanings do not move** — green is will-catch, red is nothing-to-lift,
  pale is out-of-range — only the swatches, so nobody has to relearn the marker.
  **The lift is what makes them carry over dirty water without being invented beside the
  palette**: repaint the pack and the ring moves with it, which is what `test_lake` asks.
  The sheet's row C is the pick; its pale was within four parts in 255 of `foam`, and at
  `AIM_FAR_ALPHA` over water that is under a pixel step, so the palette's own swatch stands.
- **Plus a dark backing line** (`AIM_BACK`, `AIM_BACK_SHARE` 0.55, `AIM_BACK_WIDE` 3.5):
  the same ring drawn once underneath in `Style.HOLE_RIM`'s black, wider, carrying a share
  of whatever the coloured line carries — so the dashed out-of-range ring is backed as
  faintly as it is drawn. Palette swatches are duller than the ones they replaced and the
  ring sits on water running from soup green to clean blue, so a toned green over dirty
  water had nothing to stand on. **The one thing beyond the three swatches**, by Richard's
  call; the 1.5 px line, the alphas, the dashes and the 48-point ellipse are untouched.
- **Out of scope, by decision**: `_draw_lay_ghost` (the charm ring) keeps its warm/cold
  tint — the siege is shelved and repainting a ring nobody sees has no judge. Hover, pressed
  and drag cursor shapes. Pad mode's hidden pointer, which is unchanged.
- `test_lake`'s `_stage_pointer` guards the picture, its outline, that the hotspot lands on
  the arrow, that the retired second picture is gone rather than merely unused, the ripple's
  layer, size, ignoring of the mouse, that a click rings it and the ring dies on its own and
  stops the redraws, the cap, and that nothing rings with no pointer; and the aim ring's
  colours **against `Palette`** rather than against numbers written down twice — repaint the
  pack and it says so — plus that the three stay three and the backing is darker than all of
  them.

### Sound (2026-09-15, `/grill-me` with Richard, `scripts/sfx.gd`, `tools/build_sfx.py`)
The code-built placeholder sounds are replaced by Richard's recordings. **Supersedes the old
`sfx.gd` header's "there are no sound files and there is not going to be a folder of them".**
- **Pipeline**: the recordings stay in `art_source/SFX` (24-bit, 96 kHz, silence either side,
  230 MB). `python tools/build_sfx.py` (ffmpeg on PATH) writes `assets/sfx/`: 16-bit 44.1 kHz
  WAV with the silence cut and the tail faded, footsteps cut into single steps
  (`step_grass_N`, `step_sand_N`), the sniff into three (`sniff_N`), the barks as `bark_N`, the
  find chime cut to its first 1.5 s, and the beds as seamless loops — the lake and the fireplace
  as OGG, the wading cut as WAV (`LOOP_WAV`: as an .ogg it would not open in the editor's
  inspector however often it was reimported, renamed or had its UID rebuilt, while every other
  .ogg in the project did; `Sfx.BEDS` sets the loop point on the way in; lake
  236 s, fire 30 s, wading 2.2 s, equal-power crossfade). Every cut is a number in its `PLAN`. **Reimport
  after a re-run.** 11 MB in all.
- **A harness that borrows a setting puts it back** (2026-09-16): `Prefs.store` writes
  `user://settings.cfg` there and then, and `test_lake`'s save stage set a sound and an ambience
  level to check that a load reads them from `Prefs` — so every headless run left the player's own
  sliders on the test's numbers, and the next launch loaded those. It now records both levels
  first and stores them back, and checks it did. **Nothing in `tools/` may leave `Prefs`, the
  save file or `user://` changed**; the probes that write one copy it first (`film_trailer`'s
  `_load_shed_save`).
- **The settings are `Prefs`' alone** (2026-09-15): the save file used to carry its own copy of
  music, sound, ambience and fullscreen and hand it back on load, which threw away whatever had
  been set on the main menu. `save_game` writes none of them, `load_game` calls
  `SettingsSkin.pull_prefs`, and opening the board reads them again. `test_lake` guards both.
- **`Sfx` is an autoload, `Sound`** (`Sfx.main()`, `Sfx.ui(name)`), so the menu has its clicks
  and the start sound carries into the lake. It reads `Prefs` itself. The lake calls `hush()`
  on `_exit_tree`: the engine, haul, fire and ambience are the lake's and must not follow it to
  the menu. `SOUNDS` is every recording's balance in dB and pitch roll — **first guesses, to be
  tuned by ear**.
- **Nothing important is stolen** (first playtest, same day): through one round-robin pool, a
  sweep's knocks (one per piece) took every voice in a frame and cut the net's splash, the haul,
  the bell and the chime short. `CHANNELS` gives those (and the throw, the find, the barks and
  sniffs) players of their own; `NEVER_CUT` (haul, chime, bell) skips a new play rather than stop
  one sounding, so a haul always finishes; the shared pool takes a free player before stealing;
  the knock is held to `CATCH_GAP`. `ui_click`, `ui_close` and the two decoration drops are cut
  from their own transient (`("peak", ...)`) — each take leads with a softer tick or a rise,
  which was heard as a late press. **Nothing else is late** (measured 2026-09-16): the files
  have no lead-in, `play()` to audible is under a millisecond, and the WASAPI driver's floor is
  10 ms whatever `audio/driver/output_latency` says (4 and 2 both report 10).
  The `ui_*` imports are uncompressed, and `audio/driver/output_latency` is 8 ms rather than the
  15 ms default — both takes start loud in their first millisecond, so what was left of "the
  click is late" was the engine's own buffer. Raise it again if a weaker machine crackles.
- **Second pass by ear** (same day): net splash quieter, and dropped onto one of
  `NET_SPLASH_PITCHES` (six steps since 2026-09-17, never the last one played, with a small
  roll on top) rather
  than rolled about one pitch — one take lands every cast; pigeon wings quieter; `AMBIENCE_DB` -10 (was +2); piece splash louder. **A piece landing
  in a box is the shed's own wooden thud** (`drop_big` at `POP_PITCH` 0.85) — the built pop is
  gone, and dropped in pitch it read as a shot heard from a long way off (Richard: "wood on
  wood, bold"). **Superseded 2026-09-17**: the crate has a recording of its own, see The
  crate's thud below.
- **The throw is stepped too** (2026-09-17, Richard: not too repetitive), `NET_THROW_PITCHES`
  through the same `_next_pitch`. A cast is two takes one after the other, so pitching the
  splash alone left the whoosh in front of it identical every time. **Narrower than the
  splash's spread** (0.9-1.12 against the splash's 0.66-1.26, which was 0.72-1.1 until
  Richard asked for more variety on 2026-09-17): the throw is the rope leaving the hand, and
  a wide swing on it reads as a different net rather than the same one thrown again.
- **Still built in code** (no recording): the lake-cleaned note (`play_found`) and the
  siege's chime. **The catch knock is cut, by decision** (2026-09-16, issue #1): every place
  that played it already drew a splash, dropped a piece in the crate or knocked the box, so
  the knock under those was one event sounded twice. A charm lifted out of the water plays
  the piece splash instead and a dog delivering to the crate plays the crate's own thud
  (`play_pop`), which is what it should always have been. Don't put it back.

### The Audio Audit (2026-09-16, issue #1, `/grill-me` with Richard)
Issue #1's taxonomy was written before the recordings existed and the game moved past it on
purpose. What the audit settled, against the shipped design:
- **Delivered**: `wings`→`pigeon_fly`, `coo`→`pigeon_coo`, `ui_click`, `ui_hover`, `upgrade`,
  `find`→`find_caught`, `decoration_apply`→`drop_small`/`drop_big`, `ambient_layer`→
  `lake_ambient`, `decoration_menu`→`indie_boi_radio`, `main_loop`/`menu_theme`→the Nuven
  playlist, `victory_stinger`→Habibs, plus everything the spec never listed (the ferry, the
  net, the steps, the wading, the coins, the dogs, the shed).
- **Superseded** by decisions above: `horn`→`ferry_bell`, `engine_loop` retired, `drag_loop`→
  `haul`, `pop`→`drop_big` at `POP_PITCH`, and since 2026-09-17 `pop`→`Object_in_box`, its own
  recording in three takes.
- **Struck off, by decision**: the four splash tiers (`splash_small`/`medium`/`large`/`heavy`)
  stay **one recording pitched by weight** — `Object_Splash` through `play_splash`, which is
  what is in play and what works; `catch.wav` (the knock, cut); and `warning.wav`, which has
  no caller, no substitute and none wanted.
- **Open**: `chime.wav`, the lake coming clean, is the one sound still owed a recording.
  `_make_found` stays until the take is in `art_source/SFX`.
- **The delivery format lines are struck too**: the spec's 24-bit 48 kHz PCM in
  `assets/audio/` describes a hand-off, and the hand-off is `art_source/SFX` at 24-bit
  96 kHz, which exceeds it. What the game imports is 16-bit 44.1 kHz in `assets/sfx/` and
  `assets/music/`, by design.

- **Every cut is levelled, and `SOUNDS` is the mix** (2026-09-16, `tools/build_sfx.py`
  `loudness`/`level`, report in `tools/last_sfx.log`): the takes were delivered up to twenty
  decibels apart, so a number in `SOUNDS` was doing two jobs — rescuing a quiet recording and
  mixing the game — and there was no telling which was which. Every file is now measured
  K-weighted (ITU-R BS.1770, **ungated, over the whole cut**: the gate's 400 ms blocks are
  built for programme material and most of this is a tenth of a second long) and gained to
  `TARGET_LUFS` (-22, the middle of issue #1's band; -20 for the beds), held under
  `PEAK_CEIL` (-3 dBFS). `LOUDEN`, `STEP_PEAK` and `peak_gain` are gone with it.
  **Every `SOUNDS` figure was shifted by its own file's gain on the changeover**, so what is
  written there is the balance Richard had tuned by ear, said over a level floor — nothing
  in play changed on the day. The report's last column is that shift, per name: read it after
  a re-record and move the entry by hand. A cut whose peak stops it reaching the target lands
  short and says so in the report (the wading bed, the lake's ambience, the piece splash).
- **The box thud came up** (same day, Richard: still a bit muffled): `POP_DB` -16 to **-9**
  and `POP_PITCH` 0.85 to **0.90**. Dropping the pitch is what makes it bold and also what
  makes it dull, so the pitch went half the way back and the level took the rest. Both are
  by-ear knobs. **Both constants are gone since 2026-09-17**, with the single take they were
  rescuing; the level they settled on is carried into `SOUNDS[&"pop"]`.
- **The crate's thud is its own recording, in three takes** (2026-09-17, `/grill-me` with
  Richard, `art_source/SFX/Object_in_box.wav`). It was the shed's furniture thud, `drop_big`,
  pitched down to 0.90 and stepped across four pitches — both of which existed only to
  disguise one take being heard a thousand times a run. **So both are retired**: `POP_PITCH`
  and `POP_PITCHES` are gone, and `POP_DB` with them (the balance is `SOUNDS[&"pop"]` now,
  where every other recording's is).
  - **The recording holds 28 takes one after another**, so the builder grew an auditioning
    pass: `python tools/build_sfx.py --split Object_in_box.wav` writes every onset whole to
    `art_source/SFX/_takes/<name>/take_NN.wav` with a log of timestamps, for listening to in
    Explorer. Scratch, git-ignored, and **nothing in the build reads it**: the pick a person
    made is data `PLAN` holds, not something the onset finder gets to decide again next run.
  - **Richard picked 5, 18 and 24**, pinned as a `("takes", [(start, end), ...])` cut. Each
    span runs to the next onset, so each is trimmed to where its own ring dies away — three
    takes of one thing should be the same length as each other, not as long as the gaps that
    happened to follow them in the room.
  - **One of the three per drop, never the one played last** (`Sfx.next_step`, the rule
    `_next_pitch` was already following — what is being avoided is the repeat, not the pitch;
    `play` takes a `take` index for it). `SOUNDS`' own small roll goes on top.
  - **Its own name is what keeps it out of the shed**: borrowing `drop_big` put it on the
    room's allow-list, so `play_pop` had to say `if indoors: return` for itself. As `pop` the
    allow-list refuses it with the rest of the lake and the furniture's thud still comes
    through. The ferry-at-a-pier silence is untouched.
  - **`drop_big` is untouched** and is still the shed's own recording, by decision — one
    wooden-thud take everywhere was offered and turned down.
  - **-12 dB**, in `SOUNDS`: `POP_DB`'s own -9 carried over, then 3 dB off by ear once the
    takes were heard in play (Richard, same day). A by-ear knob.
  - `test_lake` guards the three takes loading, the two thuds being different recordings, no
    take following itself, and the shed hearing the furniture but not the crate.
- **A ferry is heard coming home** (same day, Richard: sparsely): `Sfx.play_berth` from
  `Boat`'s RETURNING→DOCKED — the water it pushes on the fleet's own `BOAT_MOVE_GAP`, the
  bell on `BERTH_BELL_GAP` (70 s), much longer than the 25 s it leaves on. **The island end
  only, by decision**: the pier end is across the lake from where the player stands, and the
  coins are what say a delivery landed.
- **The dogs wade on the angler's own rule** (same day, `Dog._push_wade`): past the drawn
  water's edge by `Angler.WADE_IN` and moving faster than `Angler.WADE_LEAST` pushes the same
  wash the angler's boots do, so entering, swimming and coming back up the beach all sound
  the same for both. **Dog footsteps on land stay out**, as before. `Sfx.set_wading` is
  **keyed by walker** now (`_wading`, a set): there is one wading loop and up to four dogs,
  and a boolean set by whoever pushed last was turned off by a dog on the lawn while the
  angler stood in the water. A key is dropped when its walker leaves the tree.
  **Only within `Dog.HEAR` of the angler** (2026-09-17, the barks' own rule): the wash is one
  player at one level, so a dog on a bank run across the lake played it under a player
  standing still, which read as the angler's own wading firing for no reason. `test_lake`
  guards both sides of the radius.
- **The fleet's engine loop is retired, by decision** (2026-09-15): the ferry is a sail boat, the
  water it pushes and its bell say it is leaving, and the built diesel — a hiss with a pulse in
  it — was heard as a wind and a tick under the whole game. `set_engine`, `_make_engine` and the
  engine player are gone; `Lake._push_engine` only pushes the net's wash now.
- **Where each goes**:
  - Ferry leaving the island: the water the hull pushes (`boat_move`, the body of
    `Boatmove_water_steps`), with `Boat_Bell` over it at most once in `BELL_GAP` (25 s) for the
    whole fleet (`play_bell`, replacing the horn). **One hull at a time**: it has a single
    player, is never cut and is held to `BOAT_MOVE_GAP` (2.5 s) — two ferries setting off
    together played the take over itself, which is what read as a weird space sound.
  - Throw: `Throwing_Net`, once (the double cast's second net is silent). Landing, and a lit
    net laid: `Net_Splash`.
  - Hauling: `Haul_Sound` replaces the drag loop. It plays when the reel starts and again every
    `HAUL_EVERY` (1 s) while reeling, pitch and level off the net's effort (`set_drag`).
  - Each piece lifted: `Object_Splash`, pitched lower and louder by weight, at most one every
    `SPLASH_GAP` (0.08 s). The built knock that used to go under it is cut (see above).
  - A piece landing in a box: `Object_in_box`, three takes (`play_pop`), **except when a ferry is
    landing its hold at a pier** (`Haul._pop` skips a `Dropoff` tag, 2026-09-16, Richard: too
    repetitive). That volley is a whole hold going into a box across the lake, several times
    a minute, and it already has a sound of its own — the run of coins to the plate, which is
    what the delivery is about. The angler's own throws into the island crate keep the thud:
    that is the player's hand, in front of them, one cast at a time. `test_lake` guards both
    halves.
  - A find caught: `Decoration_Caught_Net` (replaces the struck note). `Decoration_Chime` (its
    first 1.5 s, faded over 0.9 s, quiet) rings while the aim marker is over a shining find,
    buried or uncovered, **no more than once in `CHIME_GAP` (6 s)**; after the marker leaves,
    the one playing finishes; never restarted while still sounding (`Sfx.hover_find`, `CastNet._chime_at_finds`,
    `LakeGrid.shining_finds`). Also when a find surfaces (`LakeGrid.find_surfaced`, emitted
    from `_restamp`, so a rebuild or a load rings nothing).
  - Coins: `Coin_Sound_2` (`CHINK_GAP`). Purchases: `Upgrade_Purchase`. **The coin is pitched
    in steps** (`COIN_PITCHES`, through `_next_pitch`, which the net's splash and throw share,
    2026-09-16): it fires dozens of times a minute on a long haul, and one take at one pitch
    reads as a metronome. Never the step used last, with `SOUNDS`' own roll on top. **The box's
    thud had the same ladder and no longer needs one** — see The Crate's Thud below.
  - Pigeons: `Pigeon_Fly` passing over, `Pigeon_Noise` lifted from the lake (own player).
  - Dogs (`Dog._maybe_speak`/`_speak`): a bark (1 or 2 at random) passing the angler or sitting
    idle within `HEAR`; a sniff wandering near them or when they walk up. **Sparse by rule**:
    one gap shared by the pack (`_voice_next`, 8-18 s), a roll every `VOICE_ROLL` at
    `VOICE_ODDS`, barks favoured over sniffs. Petting plays a sniff (it used to play the
    purchase sound).
  - Angler steps (`Angler._footfall`): one step on each foot-down frame of the run cycle
    (`FOOTFALLS`, frames 3 and 10 of 14): grass on the lawn, sand otherwise, and
    **wet only past the water's drawn edge by `Angler.WADE_IN` (8 px)** — the wet sand and the
    foam the coast wave runs up it are the beach, not the water (Richard, 2026-09-15). **The shallows are a wash with a gap in it, not
    footsteps** (Richard, same day): `WaterSteps3` is water being moved rather than a drip or a
    splash, so while the boots are moving in it (`Sfx.set_wading`, `Angler._push_wade`, over
    `Angler.WADE_LEAST`) the cut plays, finishes, waits `WADE_EVERY` (1 s) and plays again. Held
    as one loop it was water running without a break. Its own player, never cut. No step sound fires on water. Retired as
    the wet step, in order: `Water_Steps.wav`, `Boatmove_water_steps`' tail, `WaterSteps2`'s
    drip. `Angler.step_surface` is the one
    place that decides, and `test_lake` asks it. The grass and sand takes were recorded some
    20 dB under the rest: the builder drops the faint onsets (`STEP_LEAST`) and brings every step
    up to `STEP_PEAK`, the sniffs and the boat's water likewise (`LOUDEN`). Not the dogs, not the
    shed.
  - Interface: hover on everything clickable (`HOVER_GAP`), a click on **press** (a
    `PlankButton` used to click on release, heard late), **no click on a
    shop row** (the purchase sound is the answer; an unaffordable row is silent). `Close_Tab`
    when the player closes a board — cross, click off it, Escape, E out of the shed
    (`Lake._shut`, `MainMenu._shut`) — never when another board opening puts it away.
    The menu's Quit closes rather than clicks.
    `NewGame_Continue_Sound` on New game / Continue (and "Start over" confirmed) on the
    autoload's own player; the menu's planks set `PlankButton.clicks` false.
  - **The hover and the click takes are inverted** (2026-09-17, Richard: a click should be the
    bolder of the two, and `Mouse_Over_Sound` is the bolder recording). So `ui_click` is built
    from `Mouse_Over_Sound.wav` and `ui_hover` from `Click_Sound.wav`, swapped in
    `build_sfx.py`'s `PLAN` rather than at the 26 `Sfx.ui()` call sites: **a key means the verb,
    not the file**, and the cut recipe travels with the recording. **The click keeps the take
    whole** (`("trim", 0.2)`, the very cut that shipped as the hover): it is two knocks, the
    second at 62% of the first 60 ms later, and the pair reads as a droplet, which Richard
    wanted kept. The first knock alone was tried first and dropped for it. The hover keeps the
    cut that shipped as the click — the loud tick 145 ms in, its soft
    lead tick still discarded. **The click's cut takes a fade-in of its own**
    (`trimmed`'s third argument, 0.5 ms against `FADE_IN`'s 4): its attack is in the take's
    very first samples — 40% of peak half a millisecond in — so the standard ramp lay over
    the knock and turned it into a 5 ms rise, which Richard heard as a late click. It now
    reads 39% in its first millisecond where it read 5%. What is left is the take's own rise
    to a peak at 5.4 ms, the second knock at 60 ms, and the engine's 10 ms output floor. Every cut is levelled to `TARGET_LUFS`, so what `SOUNDS` holds
    is the mix and the gap between click and hover is the whole prominence — the hover's cut is
    peak-limited and lands 3.3 dB short of the target (`tools/last_sfx.log`) on top of it, the
    click's reaches it at a peak of -8.1 dBFS. **Then 3 dB each way by ear** (Richard, same day):
    click -3.0 to **-6.0** and `Close_Tab` -12.4 to **-15.4**, hover -18.6 to **-15.6** —
    which is what the hover's own peak limiting had taken off it, and still leaves about
    13 dB between click and hover.
  - **The lake is not heard from inside the shed** (2026-09-15): `Sfx.indoors`, pushed by
    `Lake._push_rooms`, silences everything but `WHILE_INDOORS` — the door, the pieces put down,
    the fire and the interface — so no ferry sets off and no water moves while the player is
    decorating. `play_pop` checks the flag itself, since a piece landing in a box plays the
    shed's own thud. The coins go with them (`CoinFly.clear`, no new flights while the shed is
    up): they are drawn over everything, and they are a receipt for a plate the room covers.
  - Shed: `Decoration_Menu_Open` when it opens. Put down, a `small` or `wall` piece taps
    (`Drop_Small`), a floor piece thuds (`Drop_Big`). `Fireplace_On` loops while a fire is lit
    in the room and the shed is open (`ShedRoom._fire_lit`), easing in and out.
  - `Lake_Ambient` loops whenever the lake is up, **ducked `AMBIENCE_DUCK` while the shed is
    open**, on its own **Ambience** row on the settings board (`Prefs.ambience_on`/
    `ambience_level`, `settings.cfg`).
- **Out of scope, by decision**: dog footsteps, footsteps in the shed, the tree screen's nodes
  (set aside). `test_lake` guards the autoload, that every name in `SOUNDS` loaded, the variants,
  the looping beds and the duck.
- **The lake goes quiet behind the upgrades board** (`Sfx.shopping`, `WHILE_SHOPPING`,
  `may_play`, pushed from `Lake._push_rooms`, 2026-09-15, Richard: "keep only music, ambient
  and money from lake sounds"). While that board is up the lake's own sounds are held —
  barks, splashes, the ferry, the pigeons, the steps, the haul and the wade bed, and the
  three built sounds through `_fire`. What is left: the song through the radio, the ambience
  bed (it is the lake being there, not an event) and the **money**, `coin` and `upgrade`,
  because a sale landing while the shop is open is the plate's number moving. Interface
  sounds come through `play_ui` and are not the lake's, so they are untouched. The shed and
  the settings board are unchanged. `test_lake` guards what is held and what is not.
- **Every slider obeys one law** (`Prefs.volume_db`, `SLIDER_LAW` 33.2 dB a tenfold,
  `SLIDER_FLOOR`, 2026-09-15, Richard: "they feel like they are only working at half of it,
  the other half is just mute"). The three sliders ran straight from their floor to their
  ceiling in decibels — sixty of them for the music — so half way along was 28 dB down, a
  sixteenth of the loudness, and everything audible was crowded into the top third of the
  groove. A decibel is a ratio and the ear hears ratios, so the travel is a power law
  instead: half the slider is about half the loudness, and the drawn fill is honest about
  what is being used. `loudest` stays each sound's own (+4 music, +6 effects and ambience);
  the law is what the travel between the ends is worth. Music, effects and ambience all go
  through it.

### The Music (2026-09-15, `/grill-me` with Richard, `scripts/music_station.gd`, `tools/build_music.py`)
One station for the whole session. **Supersedes** the lake's two-player Goin crossfade and the
menu's own player (both gone, with `%Music` in both scenes and `assets/music_goin*.mp3`).
- **An autoload, `Music`** (`MusicStation.main()`), started as the engine loads — the splash is
  still up, the earliest Godot allows. Menu and lake hear one stream; going to the menu and back
  restarts nothing. Scenes only say where the player is (`indoors`, `muffled`, `set_ending`,
  `leave_rooms` on a scene's way in and out) and push the volume (`set_level`, live off the
  slider). **Desktop only, by decision**: the web build's loading screen and autoplay block
  were not designed around.
- **Playlist**: beatgucci -> Save ME -> Goin -> beatgucci, forever. The next song eases up
  underneath over `FADE` (4 s, squared, so it is still quiet while the other is whole) and
  the song playing holds its level until its own last `FADE_OUT` (1.5 s). **Not an
  equal-power crossfade** (2026-09-15, Richard: "getting cut too quickly on fade out"): Save
  ME plays at full level to its final sample — it has no outro — so a four-second symmetric
  fade threw four seconds of the song away. The two together peak about a decibel over one
  song, which `test_lake` guards. **beatgucci stops
  at 2:12**, cut in the file by the builder; every song's trailing silence is cut too, so a
  file's length is where it ends and the station fades them all the same way.
- **Muffled** (the upgrades board or the settings open on the lake): the playing song
  crossfades to its `_radio` copy in `DOOR_FADE` (a quarter second). Each pair is started on
  the same instant so the door is a fade, not a seek. **The settings board is new here**;
  it used to be the shop and the shed only.
- **Indoors** (the shed): Indie Boi through the radio. It has played since boot and loops, so
  walking in lands wherever it has reached; the playlist runs on muted underneath.
- **The ending**: Habibs fades in over everything from its start, over `FADE`, when the
  farewell appears on a cleaned lake and when Credits opens on the menu; it fades back to the
  playlist, which kept running, when either closes. Not on a finished lake after the farewell.
- **Silence is a volume**, never a stopped player (below `OFF_DB`).
- **The song's clock is its player's playback position** when it has one, so a long scene
  load cannot run a file out before its fade; `follow_players` off drives it by hand.
- **Levels**: `GAIN_DB` levels each song to Goin's -11.1 LUFS (the deliveries were up to five
  dB apart, which a crossfade turns into a jump). Zero everywhere is as delivered. The
  slider's top, `LOUDEST`, is **0 dB, down from +4** (2026-09-15, Richard: "decrease volume of
  songs a bit overall").
- **Radio recipe** (`RADIO` in the builder): mono, 190 Hz and 7.2 kHz two-stage filters, a
  little tanh drive, a 35 ms slap, 64 kbps. The first bake's recipe was lost; this one was
  matched to `music_goin_radio.mp3` by spectrum and loudness (-20.9 against -20.7 LUFS). A
  baked file, not a bus, because the web export runs no bus effects.
- **Pipeline**: songs stay in `art_source/Music`; `python tools/build_music.py` writes
  `assets/music/` (35 MB). **Reimport after a re-run.**
- **Tests**: `test_lake`'s `_stage_music` drives its own station by hand: the order, the 2:12
  cut, the equal-power handover, shed and radio over a running playlist, the end song in and
  out, and the lake telling the autoload.
- **Credits**: every song and recorded sound is by Nuven (Richard, 2026-09-15), in
  `docs/CREDITS.md` and on the credits board.

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
shows it). 37 finds (2026-09-13: the kitchen chairs and the old table cut, four rubbish-born
finds added — see The Shed Floor below).

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

- **The Music switch covers the ending, by decision** (2026-09-18): Habibs is on the Music
  bus like every song, so a player who has music off gets a silent ending. Found when
  Richard reported the credits song not triggering: the ending had fired (the save's
  `farewell` was true) and `settings.cfg` had `music_on=false`, written two minutes before
  the last piece. Overriding the mute was offered and not taken. **Before calling the end
  song broken, read `settings.cfg`.**
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
  into `pieces.json`, read via `Sheets.copies_of`. The dining chairs are **4** (a dining table
  with one chair at it is not a room anybody lives in); everything else is 1. Each copy is
  its own def, its own hiding place in the lake, and its own row in `unlocked` — they share
  one dirty sprite and are netted and stood separately. `_keep` caps at `copies_of`, and
  `in_store()` **counts** rather than matching by name: matching emptied the shelf of all
  four the moment the first was stood down.
- `ShedRoom.DOG_BED` is `decor_pet_bed` — one find, two styles, so either bed is the dog's.

### Free Placement in the Shed (2026-09-16, `/grill-me` with Richard)
Furniture stands on **any whole source pixel**, not on the 8 px cell grid: Richard's call,
"the snap is too tight to adjust exactly where I want the decoration". At ZOOM 3 the step
went from 24 screen pixels to 3.
- **Whole art pixels, never finer**, by decision: the room is pixel art, and a piece at half
  a pixel blurs or crawls on the screen grid.
- **No coarse snap anywhere**, by decision: no Shift modifier, no magnet to a neighbour's
  edge. One gesture, one thing. Lining four chairs up at a table is done by eye.
- **`ShedRoom.CELL` (8) stays the walkers' grid.** The player and the dog still move in
  cells, `REACH` and the glow radii are cells, and `_taken` still blocks whole cells:
  per-pixel walker collision is sixty-four times the entries for a difference nobody can
  feel. So there are two units in one file, and every place they meet divides by `CELL` —
  `_foot_of` and `_walker_key` (**sort keys are in cells**, because the walkers' keys are
  sorted against the furniture's), `_taken`, `_bed_cell`, `_switch_near`. A new caller that
  mixes them is out by eight.
- **`PLACE_COLS`/`PLACE_ROWS`/`PLACE_WALL`** are the floor and the wall in placement pixels.
  `cell_at` is renamed **`spot_at`** — it does not return a cell any more, and the name was
  the only thing that would have said so.
- **A footprint is now the drawing itself** (`span_of` = `footprint_view(..., 1)`), not the
  nearest whole cells to it — the rounding `Sheets._cells_across` does was the dead floor
  around everything.
- **A base is still authored in cells** and multiplied back up (`base_of`). `Sheets.base_of`
  reads `bases`, which the catalogue authors by eye off `tools/last_decor_views.png`; asked
  at a granularity of one it would hand those cell counts back as pixels and every piece
  would stand on a one-pixel foot. **Don't ask `Sheets` for a base at 1.**
- **A cell is blocked when its middle is inside a base** (`_taken`), with a fallback to the
  cell the base's own middle is in. Marking every cell a base *touches* would round the
  blocked floor up on all four sides, which is the dead floor coming back in the one place
  it would still be felt.
- **The drag is held inside the floor, not refused at it** (2026-09-16, Richard: "fix the
  limits you can put heavy objects, they should not go with base over wall or border").
  `_drop_cell` clamps **both** axes now (`_held`): a wide piece dragged up against a side
  wall used to be let go past the floor's edge, fail `can_place` and go back to the shelf.
  It slides along the wall instead, the way one let go too high already slid down. `_held`
  exists because `clampi` with a low over its high keeps the **low** — for a piece too big
  for the room that is the far wall, and the hand is aiming at the near one.
- **The bound is the floor's own rectangle: a piece's whole base on the boards, its picture
  free to rise up the wall.** Tried and **reverted the same day**: holding a base clear of
  the room's drawn moulding as well. It parked a *small* piece a run's width down the floor
  while a tall one still looked flush against the wall (Richard: "I can't push them close to
  the top wall") — a pot's base is most of its picture and a wardrobe's is a strip along the
  bottom of one, so the same inset costs them completely different amounts of wall. And it
  was wrong anyway: those runs are the room's skirting, and furniture standing against a
  wall covers the skirting. `_trim` stays, as the **walkers'** bound alone (`_feet_keep`),
  which is what it always was.
- **The faint cell grid under a carried piece is gone**: it was drawn to show what the drop
  snapped to, and what it snaps to now is the floorboards.
- **`SAVE_VERSION` 10, and version 9 is read rather than refused** (`Lake.SAVE_SHED_CELLS`):
  a v9 file is exact in cells, so its `decor` rows are scaled by `CELL` on the way in and
  every piece lands back where it stood — Richard's furnished save, which the trailer's shed
  shot loads, survives. **The one exception to "older saves are refused rather than
  migrated"**, and not a migration chain: the next change to the def list refuses v9 again.
- **Out of scope, by decision**: free movement or finer collision for the walkers,
  snap-to-surface stacking, base collision, refusing overlaps.
- `test_lake` guards the pixel placement and that a row is kept to the pixel, the footprint
  against the art, the base-only blocking in cells, the wall, a small piece reaching the
  back wall and no further, the stable tie, the pot's host, the walker key, and the v9
  migration. `tools/shot_shed.gd` writes its layout in cells and
  scales it, since a room is laid out by eye in cells.

### The Shed Floor: Bases, the Wall, Small Pieces (2026-09-13, `/grill-me` with Richard)
- **Cut**: `decor_kitchen_chair` (4) and `decor_old_table`. Dining table and dining chairs
  stay. `SAVE_VERSION` 8.
- **Four finds born from the rubbish**: `decor_painting_a` ("Painting", the lake's
  `wood_painting3`), `decor_painting_b` ("Landscape", `wood_painting4`), `decor_chew_toy`
  (the **rubber bone**, not `rubber_toy` — Richard, same day), `decor_globe`. Richard painted
  both groups into the Decoration PSD, so they go through the ordinary pipeline: PSD layers
  `wood_painting`/`wood_painting_2` (clean) and `_3`/`_4` (dirty; the psd-extract slugs are
  by layer order, so re-check the pairing after any re-extract — the manifest bboxes at
  x 157 and x 139 tell them apart), `rubber_bone_copy`/`rubber_bone`,
  `plastic_globe`/`plastic_globe_2`. **The rubbish kinds stay in the fill as well** —
  netting a plain one is rubbish, the find is one extra buried copy that shines. The
  builder's `dirty_piece` (a lake sprite copied onto the dirty sheet, with the clean view
  falling back to it) was the bridge before the paint existed; unused now, kept.
- **Only a piece's base takes floor** (`base` per view in the catalogue, `Sheets.base_of`,
  `ShedRoom.base_of`): the bottom N rows of cells; the rest of the picture is height and
  **rises up the back wall** when the piece is pushed to it. Authored by eye off
  `tools/last_decor_views.png` (the art is three-quarter view: a front-on sofa's base is
  its seat depth, a side-on one's nearly the whole picture); rugs default to their whole
  height, everything else to one row. Blocking, the drop clamp and the draw order all read
  it. **Richard corrects the numbers by eye**; nothing else has to move.
- **The wall is `WALL_ROWS` (4) cells**, not `BOARD * ZOOM * WALL_GROW` px: placement rows
  must mean the same at every window size. (In pixels since 2026-09-16, `PLACE_WALL` = 32;
  the rule is unchanged.) `_zoom()` fits wall and floor together. A
  bookcase (6 cells, base 1) stands one row off the wall, a fridge two. `_drop_cell` clamps
  the row so a piece let go too high slides down until its base is on the boards rather
  than going back on the shelf.
- **`place`**: `floor` (default), `wall` (the paintings — hang on the wall strip only,
  `can_place` wants the whole picture above row 0, no floor cell blocked, drawn first),
  `small` (pots, table lamp, clock, chew toy, globe — may be set over a big piece).
  **Free overlap kept, by Richard's call** over refusing shared base cells.
- **One draw order** (`_order`, `_before`): wall, flats, then standing by foot row, **ties
  by the order the pieces went down** (`sort_custom` is not stable — two pieces on one
  row swapped frame to frame, the "chair through the desk"). A small piece keyed
  `OVER_HOST` past its host, the standing piece whose picture holds the middle of its base
  (`_host_of`), so a pot on a table draws right after the table however high up the
  picture it sits. The dog and the player sort in by `_walker_key`: their feet, or
  `OVER_PIECE` past any piece whose base band their feet are in — a dog on the bed is on
  the bed wherever on it it lies (replaces the 1.2-cell `own_bed` rule). The piece in hand
  is sorted in as a ghost (`_ghost`, alpha in the row) so what is seen is what lands; the
  green/red rect goes on the boards under everything.
- **Not done, by decision**: snap-to-surface stacking (a surface height per piece), base
  collision, scaling the dog.
- **The angler indoors is `YOU_TALL` 3.9**: 1.3x (4.4) was asked for and then read as too
  big, so half way. At the room's usual zoom of 2 that is one and a half screen pixels to
  an art pixel, so the figure's scale rounds to **half pixels** (`YOU_STEP`) — whole pixels
  only ever gave 1 or 2, the two sizes already rejected. Dog unchanged.
- **The bed draws 1.5x** (`scale` in the catalogue, `Sheets.scale_of`/`view_size_of`; the
  footprint, stamp and ghost all go through `view_size_of`). 1.5, not "a bit" as 1.25,
  because at zoom 2 it is three whole screen pixels to one painted. **The stove and the
  kitchen counter draw 0.75x** (same day, "decrease size"). And **it has its name
  on the shelf**: the starter bed is no def, so `Lake` hands its title over from the
  catalogue by hand.
- **Finds float 1.2x smaller** (`Lake.FIND_SHRINK`: `SPRITE_SCALE` 1.67 and the cap 57 for
  keepsake defs; rubbish untouched). Not a whole art pixel — accepted, judge in play.
- **The walkers stay on the boards** (`ShedRoom._feet_keep`, `FEET_CLEAR`, 2026-09-16): the
  moulded frame is drawn *inside* `_floor_rect` along its outer edge, and the bound was half
  a cell on all four sides — narrower than the moulding is on three of them, so both the
  player and the dog stood on the skirting and on the wall's bottom edge. The inset is
  **measured off the art**, not written down (the vertical strip's width down the sides, the
  horizontal run's height along the top, the sill's along the bottom, plus `FEET_CLEAR`), so
  a repainted border moves the walls with it. The corner pieces are deeper than the runs and
  are not counted: nobody walks into a corner on purpose.
- **Feet only, by decision**: the drawing may still rise over the wall, the way a bookcase's
  does. A room where the whole figure had to fit would lose four rows of floor at the top.
  Placement is untouched — `can_place` has its own bounds and furniture may still stand on
  the moulding.
- **Probe**: `tools/shot_shed.tscn` now furnishes the room (bookcase and fridge on the
  wall, paintings, table with a pot, chair pair, sofa on rug). `test_lake` guards the wall
  rows, the base-only block, the painting, the stable tie, the pot's host, the walker key
  and the find scale.

### Where the Finds Lie (2026-09-17, `/grill-me` with Richard, `Lake._hide_treasures`)
Finds are hidden by distance from the island, measured as `Iso.past_shelf` tiles. **Supersedes
the basin-wide darts described under Golden Glitter below**; `FIND_APART` and the floating
first pet bed are unchanged.
- **Early** (`Lake.EARLY_FINDS`, piece -> forced tier): pet bed x2, chew toy x2, table lamp at
  tier 0; record player, armchair (`decor_loveseat`), coffee table at tier 1 (first Strength
  buy). Within `EARLY_OUT` (15) tiles, **exactly one slot down, on a tile whose top piece is
  no heavier than the find** — early means never waiting on Strength.
- **The second pet bed and second chew toy are `copies: 2`** in `decor_sets.json`; the bed is
  a `VARIANT`, so R changes either copy's colour. One bed floats, the other is an early dig.
- **The rest by rule, not authored**: tier 1-2 between `EARLY_OUT` and `MID_OUT` (25), tier
  `LATE_TIER` (3) and up beyond, buried 1-3 down as before. A new find needs no placement data.
- **800 darts** (banded for 760, spaced for 700): they are thrown over the whole square and
  most miss a band; at 160 eight pairs landed inside `FIND_APART`. `_plant_anywhere` is still
  the last resort. Bands are first guesses (7 / 20 / 13 finds) to judge in play.
- **`SAVE_VERSION` 11**, everything older refused; the version 9 shed-unit read
  (`SAVE_SHED_CELLS`) is gone, as its own note promised. The v10 save is kept at
  `_builds/lake_cleanup_v10_20260917.save`; **the trailer's shed shot needs a refurnished
  save before a re-shoot**.
- Out of scope, by decision: an authored stage field, floor lamp early, save migration.

### Golden Glitter (`LakeGrid.GlintLayer`, `shaders/beam.gdshader`, rim in `rubbish.gdshader`)
Finds stay **buried** (`Lake._hide_treasures` plants them a couple of slots down, dealt
**`FIND_APART` (7) tiles from each other** — 160 darts, the last 40 unspaced, then
`_plant_anywhere`; Richard, 2026-09-13: they sat too close). **Two exceptions**, same day:
the **pet bed** (`FIRST_FIND`) is planted first, afloat on top of a stack in the first
`FIRST_FIND_OUT` (0.8) tiles of water past the island's shelf and **at tier 0**, so a new
game's net — power 0, a 3.4-tile throw — can bring it home on the first casts; and the **house's bed** (`STARTER_BED`, `decor_bed`) is not a
find at all — the shed starts with it (`_seed_starter_bed`), so `_all_defs` skips it.
`SAVE_VERSION` went to 7 for the def list (8 on 2026-09-13, same reason). `test_lake` guards all three. The
glitter is not a map: a find within `GLINT_REACH = 3` slots of the top shows through the
muck, and shines fully once uncovered. **Rewritten 2026-09-13 after Fortnite's floor loot**
(Richard's reference: the golden gun with its column of light, gold outline and glitter):
- **Beam** (`GlintBeam`, buried or not): a see-through column of gold light standing
  straight up the screen from the piece's waterline, `BEAM_TALL` (2.5) times the find's
  larger drawn side, soft-sided, brightest at the foot and gone by the top, faint streaks
  climbing inside it, breathing out of step per tile. **One width for every beam** — the
  mean drawn width of the finds (`GlintBeam.width`) — by decision. Buried finds get a
  dimmer, shorter one (`BEAM_FAINT`, `BEAM_SUNK_TALL` at the bottom of the reach). Drawn
  **over everything on the lake** (absolute z 20: hulls, haul, walkers) by decision; it is
  additive and see-through. Not yet on the art-pixel grid.
- **Rim** (uncovered only): the find's own picture stamped again in gold half an art pixel
  out on each of four sides, **in the rubbish soup** just before the piece, flagged to
  `rubbish.gdshader` by `RIM_FLAG` (vertex alpha 0.5, an alpha nothing else in the soup
  uses) and coloured by its `rim_gold`. In the soup by decision: rubbish nearer the camera
  covers the rim as it covers the piece; a layer over the soup would draw gold across the
  mug lying on the sofa. **Every tile with a find anywhere in its stack carries the rim's
  room** (`_stamp_len` adds `RIM_VERTS`, blank quads while the find is down), so uncovering
  and taking a find both patch in place (`_restamp` blanks what a smaller stamp leaves)
  and never cost a 25 ms rebuild mid-haul. `test_lake` counts the soup against it.
- **Twinkles** (`GlintTwinkle`, uncovered only): four-point stars of whole art pixels,
  gold going white, popping and fading over `STAR_LIFE` at spots sampled once per find
  off the atlas image's own opaque pixels, laid out by the same cut and mirror `_sprite`
  draws the piece with — so the piece itself glitters and nothing lands on the water beside
  it. Just over the soup (the layer's own z, drawn after it), under the piers.
- **The swell has one clock** (`lake_clock`, a global shader uniform pushed from
  `LakeGrid._process` every frame, 2026-09-13): `rubbish`, `shadow` and `foam.gdshader`
  rock their vertices off it, not off `TIME`. Found through the beams: `LakeGrid._time`
  runs from the lake's start and `TIME` from the engine's, so everything the CPU placed on a
  piece through `surface_pos` — splashes, perching birds, the piers' wet shadows, the beam
  and the twinkles — bobbed seconds out of step with the piece it was on. Anything new that
  rocks on the swell in a shader reads `lake_clock`; anything on the CPU reads
  `wave_time()`. Declared in `project.godot` under `[shader_globals]`.
- **Second pass, same day** (Richard's notes): rim thinner — half an art pixel, four
  sides, `RIM_STEP` 1.0 (the colour stays; darkening it was the wrong reading of "tone
  down"); the beam's foot starts `BEAM_SINK` px under the waterline and fades in
  over `foot_soft` of its height, so it comes up out of the water rather than standing on
  a line cut across it; the stars are whole art pixels drawn in the piece's own frame
  (`STAR_PIXEL`, a plus with `STAR_ARM` arms), with single-pixel sparks between them
  (`SPARK_RATE`, `SPARK_LIFE`) — smooth polygons over the picture read as disconnected.
- **The shine follows every patch** (`GlintLayer.refresh` from `_restamp`, 2026-09-13):
  it used to be set only by the rebuild, so a find netted out left its beam and stars over
  the rubbish that came up under it until the view moved — read as rubbish shining. Stars
  on a tile no longer uncovered die with the change. **Beams over rubbish are otherwise
  the buried finds under it**, by the first-pass decision.
- **A find keeps its shine in the net** (`CastNet.CatchRim`/`CatchBeam`/`CatchStars`,
  `shaders/rim.gdshader`, 2026-09-13): `_draw_catch` hands every shown find's spot, turn
  and scale to three children — the rim behind the net's own drawing
  (`show_behind_parent`; the picture drawn again in a pure-green modulate that
  `rim.gdshader` turns to flat gold, so the piece and the rest of the catch cover it), the
  beam at the lake's beam z with its own breath clock, the stars over the mesh with no
  material. `GlintTwinkle.sample_spots`/`draw_star` are static so the two twinkle layers
  are one drawing. Cleared on idle. Not carried on to the hold or the dog.
- **Third pass** (Richard: the beam sank into the water, above all when buried): a pale
  core (`core_white`) up the middle of the column, firmer sides (`soft_side` 0.55),
  `BEAM_BRIGHT` 0.85 / `BEAM_FAINT` 0.45 / `BEAM_SUNK_TALL` 0.6.
- **Retired, by decision**: the radial glow disc (`glint.gdshader`, `GlintGlow`), the
  32-frame sparkle sheet laid flat round the piece (`GlintSparkle`,
  `Sparkle_Effect_Decorations_v2.png` — Richard: speckles, not sparkles) and the specular
  sweep across the piece (proposed, rejected: "more like the object is glittering").
  `assets/Sparkle_Effect_Decorations.png` (the v1 sheet) was already unused and is still
  in the tree.

### Strand Line (outer bank rubbish, fetched by the dog)
The ordinary fill stops `LAKE_EDGE` short of the bank. The band inside that margin
(`Iso.on_strand`) gets its own washed-up rubbish from `LakeGrid._strand`: `STRAND_CHANCE` of
those tiles hold one piece, `STRAND_TWO` of them a second. **Only tier-0 pieces no wider than
`STRAND_WIDE`** (the cans, cup, wrap, sheet) — because the **dog** is what collects them. The
net reaches ~6 tiles from the island and the bank is ~26 away; patrolling boats stay inside
85% of the radius. So the dog makes an occasional bank run (`Dog.STRAND_ODDS`, only when
nothing near the island is fetchable), with its own trip limit (`STRAND_TRIP_MOST`).
- **The dog delivers from whichever side of the crate it is already at** (`Dog._drop_spot`,
  2026-09-16): all four, the far side included — the crate stands in front of the animal
  there and hides some of it, accepted, and the walkers sort into their layer by position so
  it is drawn correctly. It used to be one side, picked off the crate's bearing from the
  middle of the island and the same whatever direction the dog came from, so a dog arriving
  from the east walked the whole way round the box to deliver from the west. Water and the
  hut are still refused (`Iso.on_island_ground`, the drawn edge, not the waterline).
- **A blocked step slides along the face, not along an axis** (`Dog._hug`, `_bumped`,
  2026-09-16): the two things on the island a walker can bump into are rectangles in tile
  space — `Iso.in_shed` is the diamond the hut's walls stand on, `Yard.covers` the crate —
  so the tangent is one axis and a step along it is a **whole step at walking pace**, not
  the fraction an axis slide leaves when the dog is coming in at an angle. The face is the
  axis the dog has least room inside; the way along it is the way it was already leaning, or
  towards where it is going when it is heading dead-on. **The side is held** (`_hug_along`,
  `_hug_way`) until a clear step is taken: a corner is where the two faces swap over, and a
  dog re-deciding every frame there rocks on the spot — the stall `_no_gain` was put in to
  catch, not to cause. The axis slides stay underneath it for the island's own curved edge,
  and `_way_round` and the stuck timers are still the last resort.
- **No path planning, by decision** (Richard, over corner waypoints and over A*): the dog
  still discovers a wall by touching it. Two convex boxes a tile and a third apart do not
  need a search.
- **The pack loafs away from the box and the hut, and away from each other**
  (`Dog._elbow_room`, `_somewhere_on_land`, `IDLE_CLEAR` 3.2 / `SHED_CLEAR` 4.0 /
  `PACK_APART` 3.6 tiles, 2026-09-16, Richard: they cluster around the box). A spot is
  scored by **the worst** of its three wants, each capped at met — a spot wedged against the
  crate is a bad spot however far it is from the hut, and once a want is met, going further
  does not make one dart beat another, which is what keeps the pack spread over the whole
  island instead of all filing off to the one corner furthest from everything.
  `_somewhere_on_land` takes the first of `IDLE_DARTS` that satisfies all three, so the spot
  is still a random one; only a crowded island falls back to the roomiest it tried.
- **Preferences, not walls, by decision**: `_may_stand` is untouched and still lets a dog
  walk right up to the crate — the delivery spot is `CRATE_SIDE` (1.35 tiles) from the
  middle of the box, and a hard clearance would make delivering impossible.
- **The pack is a static registry** (`Dog.pack`, joined in `_ready`, left in `_exit_tree`,
  `is_instance_valid` on every read), the way `Dog.claims` is: which dogs there are is a
  fact about the lake, not about any one animal. A dog keeps clear of where another is
  **going** (`aiming_for`), not only where it is — two dogs choosing spots a stride apart
  arrive together however far apart they were when they chose.
- **A dog that has just delivered always walks off** (`_settle(true)` from `_hand_over`):
  the mood roll used to settle two thirds of them into a still mood on the spot, so four
  dogs coming home one after another piled up at the crate. The swim roll is untouched —
  going straight back out to fetch is still the commonest thing it does.
- Collectible and counted like any piece: the lake cannot finish until the dog has cleared
  the strand. If a bank piece ever becomes unfetchable (bigger def, tier > 0), the lake
  stalls — keep `STRAND_WIDE`/tier in step with `Dog.CARRY_WIDE`/`CARRY_TIER`. Strong Dogs
  (2026-09-17) only ever **raises** `Dog.carry_tier`/`carry_wide` off those constants, so it
  widens what is fetchable and cannot strand anything; the constants are still the floor the
  strand's fill must sit inside.
- Outer bank only, by decision: the island's beach stays tidy.
- Seeded off the lake seed on its own generator, so the rest of the fill is unchanged.
  Existing saves restore their stacks and have no strand pieces.
- Grime: `water.gdshader` draws scum blotches in the bank's shallowest water, scaled by the
  local filth, so they go as that stretch is fetched clean.
  **They sway with the water** (2026-09-17, Richard: "shore scum is not swaying"): the
  blotches' plane is pushed by the bands' own `warp`, like the open-water film, and the band
  rides the coast wave (`bank_lap`) up the beach and back. They sat on the static line
  while the water's edge moved under them.
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

**The material is Wood, not Timber** (Richard, 2026-09-13, "in all accounts"):
`TrashDef.Kind.WOOD`, `KIND_NAMES` "Wood", the piers' sheet key `wood`, the sign reads
WOOD, `pieces.json`'s `yard` field "Wood", the art brief likewise. Saves are untouched —
kinds are stored by index and the order did not change.

**Adding kinds**: a `.tres` under `resources/trash/`, its slug appended to `TRASH_ORDER`
(`lake.gd`), and a `SAVE_VERSION` bump. Saved stacks hold indices into the whole def list and
the finds come after the rubbish in it, so appending rubbish moves every find's index.
`size` in a `.tres` is only the no-art fallback: `Lake._dress` draws a piece at its pixel
size × `SPRITE_SCALE` (2.0), clamped to `SPRITE_SMALLEST`..`SPRITE_LARGEST`.

### Retired
`assets/TopDownHouse_FurnitureState1/2.png` no longer feed the catalogue and `furniture_NN`
names are gone (so is `scripts/find_names.gd` — titles live in `pieces.json` beside the
rectangles now). `SAVE_VERSION` is 10 (8 when this was written) and older saves are refused
rather than migrated, bar the one v9 shed-unit scale above;
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
- **The load is measured the same way** (`tools/probe_boot.tscn`, 2026-09-17): the lake's
  build is 0.56 s, the boot about 2 s. It was 2.6 s and 5 s until one call was cached —
  `Ground._boxed` asking `Iso.basin_extent()` (a walk round the whole shore outline) once a
  lawn tile. `Lake._mark` stamps `_ready` stretch by stretch into `Lake.boot_marks`; a
  stretch that grows shows up by name. **`main.tscn` itself loads in 20 ms**: everything
  heavy is built in `_ready`, on the main thread, which is why there is no loading bar.

Measured 2026-09-11, RTX 5060 Ti: 15.0 ms -> 2.2 ms mean standing, worst walking frame
42 ms -> 3-4 ms.

---

### The Trailer (2026-09-16, `tools/film_trailer.tscn`, `marketing/My Dirty Little Lake/trailer/`)
A 30 s Steam trailer cut to Habibs 2#1, built by a re-runnable pipeline (Richard's call:
scripted capture, no OBS). **Film**: `godot --path . --fixed-fps 60 res://tools/film_trailer.tscn`
(desktop build) poses each shot — five casts from five banks, each further and wider, the last
gold with its double, over a lake thinned in noise pools (`_thin`, grime spots left, the next
landing and the dogs' sticks kept foul by `KEEP_NEAR`); the fleet followed hull to pier and
the logo's hold **filmed first, on the dirty lake** (Richard: a much dirtier lake at the end,
a few clear pools; thinning only cleans, so the order is the state); the pack on the east beach (one asleep, three sent swimming out, `_send_dogs`); the furnished shed
from Richard's own save (`_load_shed_save` copies `user://lake_cleanup.save` and never writes
it; the farewell a finished lake raises is dropped every frame; the room's box is logged for
the cut's `crop`); the near-clean hold — and dumps 60 fps JPEGs to `tools/film/<shot>/` (git-ignored, ~2.7 GB).
No HUD; the aim ring is pointed off the lake; the camera is the game's own for casts and held by
hand elsewhere; zoom is set straight on the camera (levels 5-6, past `MAX_ZOOM`, whole pixels).
`FILM_ONLY=a,b` re-shoots by name; `last_film.log` gives each cast's landing frame. **Cut**:
`build_trailer.py` reads `shots.json` (everything in beats: 143.55 BPM, beat 0 on frame one,
the song started on the grid at 4.273 s) — per-cut drift, `crop` for the shed room, flashes as a white overlay (never
`fade c=white`, which paints all frames before it), Bungee captions with the logo's sticker rim,
the stacked v1 logo, "Wishlist now" — and writes `trailer.mp4`, 1080p60 H.264. Re-run the probe
then the script; retune by editing `shots.json`.

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
- `scripts/water_splash.gd` — splashes, ripples and drops, drawn as pixel foam (see Foam on the Water)
- `shaders/water.gdshader` — pixel-art lake surface: palette ramps, stepped filth/depth, shore foam
- `shaders/pixel.gdshaderinc` — shared pixel grid, stepped time (no dither, by decision)
- `scripts/skirt.gd` — baked painted grass tufts and sand spill round the shed and the box
- `scripts/flora.gd`, `scripts/fish.gd` — nature coming back as the lake cleans (see Nature Coming Back)
- `scripts/sfx.gd` — the `Sound` autoload: recordings from `assets/sfx/` (see Sound), plus the few sounds still built in code

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
