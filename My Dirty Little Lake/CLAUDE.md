# My Dirty Little Lake — Incremental Trash Collection Game

## Role

You are the lead programmer and technical designer for an incremental game prototype being developed in **Godot 4.7, using the latest stable version available**.

Your job is to build the game incrementally with clean architecture and testable systems. The human developer (Richard) is the game designer and tester. When a design decision is required, explain options briefly and ask before proceeding.

---

## Game Concept

**My Dirty Little Lake** — an incremental idle/active hybrid where the player manages a lake's restoration.

### Setting
- Single lake, isometric (2:1) tile field seen from above at an angle — see `scripts/iso.gd`
- 2D, `gl_compatibility` renderer
- No physics at all (see Architecture below)

### Verbs
**Manual (active)**:
- The angler walks the island and **casts a net** at the water, then reels it home; what the
  mouth touches and Strength can lift comes back, up to Catch. **There is no hold-to-haul
  and no progress ring** — these two lines said so until 2026-09-18, off a design from
  before the net. `TrashDef.haul_cost` is still in the data and nothing reads it.
- **A sweep digs until the bag is full** (2026-10-03, see The Net Digs the Pile): layer
  after layer under the mouth, never past a piece too heavy to lift. This line said "bites a
  configurable depth" (`SWEEP_LAYERS` 2) until then.
- **The ring is the catch, by decision** (2026-09-11, `net.gd` `_touches`/`_reach`): a piece,
  bird or charm is caught when any of its *drawing* (an ellipse at its drawn position and
  size) touches the mouth — not when its tile is inside a tile radius. The aiming marker's
  green/red verdict uses the same test at the open mouth. `mouth_extent()` is the one number
  for drawing, sweep and marker, including the `HOME_SIZE` shrink on the haul. The sweep also
  runs on the landing frame. Tiles only narrow the search (`LakeGrid.footprint_reach`).
  `net_width.tres` was left as it was, to be retuned after playtesting the honest ring.
- **The net is drawn by rule, and the haul lays it out again** (2026-10-02, see The Net
  Drawn by Rule): the hauled net is a pear-shaped bag dragged from its crown along the
  water, not a picture bent. Supersedes the warped sheet (`_draw_warped`, `WARP_*`,
  `LEAN_TIP`/`LEAN_TRAIL`, `BULGE_*`). `_lean` and `_pull` are still eased and fall back out
  when the haul ends.
- **The catch fills the bag** (`_draw_catch`, `_shown_count`): the drawn count is as many of
  `catch` as cover `CATCH_FILL` of the mouth's area at the packed scale — so a wider net and
  a fuller hold both show more — capped at what is really aboard. No filler pieces: what is
  drawn was caught. Every piece is scaled to `CATCH_FIT` of the mouth and scattered over the
  mouth **less its own half-size**, so nothing cuts through the rim; every spot is laid out on
  the net's shape (`_on_shape`), so the pile rides the bag and settles towards its back under
  the haul (`CATCH_BACK`). The old out-of-the-mouth stacking (`CATCH_RISE`) and `_belly` are
  gone.
- **The haul shoves what it will not take** (`_shove_aside`): pieces over the net's strength,
  and everything once the hold is full, are pushed clear of the rim through
  `LakeGrid.shove_to` — the hulls' own call — outwards from the middle of the mouth, with a
  piece dead centre parted to a side picked off its tile. Nothing catchable is ever shoved.
  Haul only: the throw flies over the water.
- **The rope ties to the crown, not the rim** (`_line_end`, `_bridle_points`, 2026-09-11):
  a cast net is hauled from its gathered apex through a bridle, so the hand line ends at a
  horn over the crown (lifted `HORN_LIFT` of the crown's width, never more than `HORN_MOST`
  px and nothing under the haul; pulled `HORN_LEAN` towards the rod with the lean) and
  `BRIDLES` short lines fan from it onto a ring of the net's own shape (`NetShape.at`), so
  they bend with it. The crown is `CROWN_WIDE` of the mouth's half-width, what the etching's
  apex measured. Far-side bridles draw at `BRIDLE_FAR`. `test_lake` guards that no little
  rope reaches the rim.
- **Retired anchors, in order**: the rope ending at the top of the frame's box (a point in
  the air above a net lying flat); that plus a guessed lean offset (came apart from the mesh
  the moment the net bent); the rope tied to one point on the near rim (on the net, but read
  as a line to a hoop); bridles fanning from the horn all the way to the rim (little ropes
  drawn straight across the mesh they are supposed to be gathering); the crown measured off
  the etching (`tools/slice_net.gd`, deleted with it).
- **The rope is a verlet chain, drawn only** (`_drive_rope`, `_rope_tick`): `ROPE_POINTS`
  pinned at `rod_tip()` and the rim anchor, fixed `ROPE_STEP`s banked across frames,
  `ROPE_PASSES` of tightening, per-step `ROPE_LEAP` clamp, re-seeded straight on every
  cast and on any `ROPE_JUMP`. Rest length runs `ROPE_SLACK` over the rod-to-net gap while
  the net flies or sits and eases to `ROPE_TAUT` under the haul, so reeling visibly takes
  line up. **This is not the physics the project banned**: no bodies, no collision, nothing
  gameplay reads — it is how the string is drawn. The old sine arc and its `sag` are gone.
  **Drawn as a smooth curve, not the chain** (2026-09-26, Richard: "pointy curves and
  splits"): `CastNet.rope_curve` runs a Catmull-Rom through the chain's points every
  `ROPE_DRAW_STEP` (3 px) and `_draw_rope` puts a disc at every drawn point, because
  `draw_polyline` draws no joints and the thick line's edges parted at each bend.
  `ROPE_POINTS` 11 to 16. **Drawing only, by decision**: the motion is untouched.

**Idle (automatic)**:
- The ferries carry what waits in the crate to the yards and sell it; the dogs fetch small
  pieces near the island and off the bank. Both are upgraded in the shop.
- **No machines, no drones, no continuous drain** (Richard, 2026-09-18): this section used to
  say machines and drones drained a `pollution` float over time. That was never built and
  never the design. `pollution` moves only when a piece leaves the water — by the net or by
  a dog (`Lake._on_net_caught` and `_dog_brought_back`).

### Economy (Two-Layer)
Why two layers? The player's hands are what clear the lake; the helpers are what turn the catch into money while the hands are busy. A meter that drains by itself is a progress bar with a button.

**Manual layer**: every piece the net brings home knocks its own `pollution` off the lake's (resolved per piece).

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
- **Four boards, renamed, no article**: `NET` / `BOATS` / `DOGS` / `LUCK` (standing NET / LUCK /
  BOATS / DOGS since 2026-10-03, see Seven Adjustments). The market board is
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
  the bonus, kept as the record of what was judged; both deleted 2026-10-03). `test_lake`'s `_stage_shop_shape` guards
  the titles, the unique names, every row being claimed by exactly one group, the heading
  rule, the grammar, the plate's room now the boards are level, the bonus reaching the plate
  without a figure of its own, and both inks clearing 4.5:1.

### The Boats Run Ahead (2026-09-18, `/grill-me` with Richard, issue #23; scope locked)
Richard's playthrough: the boats were too slow and too dear to keep up with the net and the
dogs, the net's prices jumped from cheap to dear, Catch (Haul) and Strength came too easily
for what they do, and Strength is the game changer that belongs in the middle of a run.
`docs/scope-lock.md` is the in/out list this pass closes on. **Nothing new after it.**
- **A run that only cleans is about 50 minutes; a first run about 65** (Richard's two logged
  runs: 50.5 and 64.5). Decorating, petting and looking round are what take a run past that,
  and none of it is counted. **Supersedes "70 to 80 focused"**, which this line said until
  the second run (Richard: "the pacing was good... let's keep it this way"), and issue #23's
  "2-3 hours".
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
- **Sim, before the logged runs** (after them: focused 54 min, band 48-68): focused 64 min, casual 110 min (the band asked 68-82: a WARN, left for the logged
  run to settle, because the bot never stops casting and the calibration is from a tree
  run). `python docs/progression/shop_schedule.py` prints bought-against-wanted per track.
- **Deleted 2026-10-03 (The Pre-Release Cleanup).** **The player's own run writes a playtest log** (`scripts/play_log.gd`, `PlayLog`,
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
- **The second logged run, and the prices are frozen on it** (`playtests/
  2026-09-18_shop_run2.log`): **50.5 min**, Strength at 5.8 / 15.5 / 20.1 / 28.4, Waiting's
  median 33 with one spike to 762 when Strength 4 landed (the net at 9.3 a second against the
  fleet's 7.8, drained in five minutes), the stall at minutes 5 to 15 gone (2.2 pieces a
  second at minute 10 against 0.6), Pigeons from minute 6, the Pack whole at minute 7, 56k
  unspent. He went straight for Strength and spent 0.7 min in the shed. **Richard judged the
  pacing good and nothing moves**: raising Strength 2-4 and Catch to put the max back at 40
  was offered and turned down. `shop_loop.sh` is not to be re-run without his say — it would
  move the ten tracks `HAND` does not pin.
- **The Reel is quicker and Catch's tail is cheaper** (2026-09-19, Richard: "a little bit
  cheaper at the last level... increase the reel speed overall, it should be a bit quicker
  all game"). **The two named exceptions to the freeze above**, and both are pinned rather
  than re-fitted: `net_hold` is in `price_shop.py`'s `HAND` now, and `build_shop.py` reads
  the `.tres` files, so `shop.json` was rebuilt from them without the pricing loop running.
  - **Reel** (`reel.tres`) goes **5 + 1.2 a level to 28**, from 3 + 1 to 23: every level is
    quicker, the level-0 net most of all (+67%). **Base and step both, by decision**, over
    scaling the whole curve evenly — the early reel is where the dead time is. The cap binds
    one level early (level 19 is 27.8), so the last level buys 0.2 rather than 1.2.
  - **Catch** (`net_hold.tres`) goes **1000 x 1.80**, from x 1.82: the top level 66k to 61k
    and the whole track 145k to 137k. **The multiplier, not a pin on the last level alone** —
    `UpgradeTrack` costs are `base x mult ^ level` and nothing else, and a per-level override
    field on every track in the game is not worth one number. So the back half of the ladder
    eases with the tail.
  - **`HOME_SPEED` stays 260, by decision** (Richard: judge it in play). At 5 tiles a second
    the level-0 net already beats the camera home, so the view trails on every haul rather
    than only the late ones. It is the one knob if that reads badly.
  - **The run gets shorter and that is accepted** (Richard: "accept, feel wins"): the sim
    goes **54.2 to 51.9 min** focused, still inside the 48-68 band, and no other price moved
    to offset it. The three failing checks in `shop-report` fail identically before and
    after. No `SAVE_VERSION` bump — both tracks keep their level caps.
- **A player who knows the game buys Strength first, and price cannot stop that**: a tier
  roughly triples income, and 8k is earned by minute 6. The water before Strength 1 is the
  thin part of the game (few green spots), so it is kept short on purpose.
- **The lake's money is finite**: about 870k in it and 812k of upgrades, so prices cannot all
  rise, and a longer run does not earn more. **The 43-56k left at the end is not a balance
  problem and is left alone**. The find-cleaning machine first named as its use (issue #37)
  was built as the pump and the wash room, and **is not a sink**: soap is about 400 a run,
  by Richard's call. See The Pump and the Wash Room.
- **The sim is calibrated to both runs** (`docs/progression/replay_shop.py`: his purchases
  replayed at the second he made them; `read_playtest.py` reads a log on its own). The net's
  four constants went to `k_density` 0.7, `k_aim` 0.8, `k_cast_share` 0.65, `k_catch_scale`
  1.3 (the tree run's fit was 1.2 / 2.0 / 0.75 / 1.7): he casts every 1.8 to 2.2 s, closer in
  and faster than the model had him. It now replays run 1 at 65.5 min (real 64.0) and run 2 at
  52.9 (50.5), the share cleared never more than 0.043 out. **What it still gets wrong**: it
  earns about 7% less than he did, and its box does not follow the real Waiting minute by
  minute (it piles up early where his did not, and misses his spike at 30). Trust it for the
  clear curve and for when a track gets bought, not for the box.
- **#23 closed on that** (2026-09-18): two logged runs, the sim recalibrated and not
  re-priced, the times on the issue and in `docs/scope-lock.md`.
- **No `SAVE_VERSION` bump**: a saved level over a track's new cap is clamped on the way in
  (`_saved_level`), and a stale `sell_N` or `skimmer` key is simply not read.
- **Deleted, not shelved** (same day, Richard: "delete everything shelved"): tree mode
  (`upgrade_tree.gd`, `tree_screen.gd`, `tree_log.gd`, the menu's two doors, the tree save
  slot, `Dog.reach`/`strand_first`/`strand_speed`, `test_tree`, `shot_tree`,
  `lake-tree.json`/`.md` and the tree's pricing scripts), the skimmer (`Boat`'s skim fields,
  sweep and drawing, `Lake.skim_*`, `BuySkimmer` in `main.tscn`, the probe's skim phase) and
  the five sell-by-tier tracks (`sell_N.tres`, `tier_pay`, `SHELVED`, `MAX_LEVELS`,
  `PRICES`). `calibration.json` stays: the shop's model reads it. **The siege was
  deleted later**, as its own job — see The Siege Deleted.

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
  (`Lake.DOG_WIDE_STEP`), which is **every kind no wider than 16 art px** — anything wider
  would hang half a dog's length out of its mouth at `CARRY_SCALE`, and stays the net's.
  (This said "everything but `plastic_toy`" until the third rubbish batch, 2026-09-21; the
  width rule was kept and ten of the 81 kinds are over it.)
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

**No physics at all** — My Dirty Little Lake abandoned RigidBody2D, Area2D buoyancy, and collision after several failed designs.

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
- `TrashDef` holds: sprite, size, material, tier. **Nothing else balances a kind**
  (2026-10-01, `/grill-me` with Richard: "balance the lake only by object type and weight
  tier"). `pollution`, `lightness` and `haul_cost` are deleted from the class and from
  every `.tres`. **Supersedes** every per-kind pollution and lightness note below (the
  band, `_lightness_span`, "a new kind's pollution has to keep that order", the third
  batch's fitted values) and the old Item Data notes on `FILL_BAND`.
- **Pay** is `EconomyConfig.piece_prices` (`resources/economy.tres`), one price per
  material per tier, `material * 5 + tier`. Fitted by `tools/fit_prices.py` off the
  probe's per-material tier mix so each yard's mean pay holds (22.00 / 22.88 / 18.25 /
  20.29 per piece), shaped `SHAPE` 1 / 1.5 / 2 / 2.6 / 3.4 so every step clears the 1.25
  the yards spread by and every heavier tier still pays more than any piece of the tier
  below. `piece_base_pay`, `piece_filth_pay` and `tier_pay_step` are gone.
- **The meter counts pieces**: every piece out of the water (net, dog, tornado) is 1,
  finds included, so the meter and "n pieces left" agree.
- **The fill** (`LakeGrid._roll_piece`): a material by `MATERIAL_QUOTA`, a tier from
  `TIER_BY_DEPTH` (five depth rows of five tier shares, **measured off the lake as it was**,
  `depth_tiers` in `tools/last_fill_economy.log`), or any tier `FILL_BAIT_CHANCE` of the
  time, then any kind of that material and tier, all equal (`_by_cell`). With 12 kinds in
  each of the 20 cells the commonest kind is about 1% of the water. Shares landed at
  28.6 / 22.9 / 20.6 / 10.7 / 17.3% (superseded below).
- **The shares are a smooth ladder** (2026-10-03, `/grill-me` with Richard): **30 / 25 /
  23 / 12 / 10%** in the water. Tier 3 had been the thinnest and tier 4 heavier than it.
  Each `TIER_BY_DEPTH` column was scaled, every band keeping its own lean, by
  `tools/fit_tier_shares.py` (base python, a loop: probe, script, until within 0.4 points),
  then `fit_prices.py` refitted the pay so each yard's mean pay and the lake's value held
  (672,663 to 672,712; every piece about 6% dearer). The probe also logs `surface_tiers`
  now, the top piece of every wet tile: past the ring 39.6 / 24.6 / 18.9 / 9.9 / 6.9%
  (was 38.9 / 24.3 / 16.5 / 8.8 / 11.5), the ring all tier 0. `test_lake`'s `TIER_PRICED`
  follows; `PAY_PRICED` did not move. No new kinds: a tier's share is the roll, not its
  kind count. Out of scope, by decision: `FLOAT_STEP`, the ring, light-on-top depth, the
  shop and the sim. **`SAVE_VERSION` 22**, v21 refused (its backup save was deleted 2026-10-06).
- **Known**: the measured table is not light-on-top: its surface row is heavier than its
  floor row, because the old fitted lightness had stopped sorting by weight. What the
  player sees is still light, because `_dress_surface` breaks ties `FLOAT_STEP` (0.7) a
  tier lighter. Flip or steepen the rows to bring back "skim light first" in depth. The
  ladder's rescale sharpened it: tier 3 is 24% of the top band and 4-7% of the floor ones.
- `tools/solve_pack_rubbish.py`, `fit_pack_rubbish.py` and their json are deleted.
- **`SAVE_VERSION` 19**, v18 refused; the v18 save is `_builds/lake_cleanup_v18_20261001.save`.

### The Lake Twice as Deep (2026-09-24, `/grill-me` with Richard)
Richard: Strength 1 was too dear, and at the end of a run "the net is huge but not a lot of
objects are caught". Catch never bound late: a cast is `min(Catch, swept x density)`, and the
late lake is thin. So the lake got denser **and** Catch got bigger, with the money held.
- **`LakeGrid.DENSITY` 2**: every slot the depth asks for is doubled in `_plan_slots`, so
  what the ring gives up is doubled too and dealt out past it. **The ring stays
  `RING_SLOTS`**, the strand untouched. About 33k pieces, the deepest tile 16; the filth
  map's ceiling follows `deepest()` by itself.
- **Pay per piece halved** (`economy.tres` 1.25 / 3.0, was 2.5 / 6.0): the lake's value
  moved 330k to 334k. Birds untouched. Because the ring and the strand did not double, the
  mix leans heavier (tier 0 35% to 29%) and a piece pays 2-6% more than half; `test_lake`'s
  `PAY_PRICED`/`TIER_PRICED` are re-measured on it. **Accepted**: evening the band out by
  layering the deep stacks was tried and moved nothing.
- **Strength 2000 x 3.30** (2000 / 6.6k / 21.8k / 72k), was 3500 x 2.74; the top unchanged.
  Pinned in `HAND` as before.
- **Catch 8 + 7 a level, 64 at the top** (was 4 + 1 to 12). **Hold 16 + 6, 64** (was 8 + 3
  to 32): **one cast at every level, not two** - supersedes "Hold is two casts" in The
  Boats Run Ahead, by Richard's call ("time can be spent washing and decorating while they
  sell"). Hold x1.5 was asked first and ran the sim to 61 min; x2 lands 49.9.
- **Every other price frozen**; `shop_loop.sh` not run. The sim takes `DENSITY` in
  `build_shop.py` (lake units and `k_density` times it).
- **Sim** (`shop-report`): focused clears in **49.9 min**, Strength at 7 / 11 / 20 / 29, the
  box peaking near **970** (was 24 in the sim, 814 in run 1). **The sim buys only 3-4 of
  Catch's 8 levels**: it thinks a cast is sweep-limited past about 24. Its density is one
  lake-wide mean and cannot see a thick bay, so read that against a logged run, not as
  proof Catch is too big.
- **`SAVE_VERSION` 16**, v15 refused; the v15 save is `_builds/lake_cleanup_v15_20260924.save`.
- **Out of scope, by decision**: the ring, Reel/Range/Width, every other track's price,
  the boats beyond Hold, re-running the pricing loop.
- **Open**: fill and `_rebuild` cost with twice the pieces (bench before trusting the 8 ms
  bar), and whether the sim's Catch read is right - Richard's next logged run decides.

### The Ring Leans Tier 0 (2026-09-29, `/grill-me` with Richard)
The start was slow and leaned too hard on Strength. **Supersedes, in The Thin Ring below**:
`RING_SLOTS` 2/3 and "every piece is tier 1 or lighter".
- **Thicker, not wider**: `RING_SLOTS` 3/4 (the ring is not multiplied by `DENSITY`),
  `RING_OUT` 8 unchanged, the extra slots taken from past the ring as before.
- **Tier 0 but for bait**: `_lighten_ring` trades every ring piece that is not tier 0 for a
  tier-0 one from past it, except `RING_BAIT` (0.15) of tier 1-2 pieces left where rolled
  (`RING_TIER` 2). Measured: 97 of 1638 ring pieces are bait; tier 0 still 29.3% of the lake.
- **Tops are tier 0**: `_dress_surface` holds the whole ring to the opening ring's rule, bar
  `RING_BAIT_TOP` (0.15) of tiles past `OPEN_RING` that may show bait, no two within
  `RING_BAIT_APART` (2) tiles. It lands about 1 bait top a lake: most bait rolls find a
  tier-0 top to prefer anyway.
- **Early finds skip the ring's inner half** (`_find_band`): it was 2 deep and so skipped by
  `height < 3`; now 3 deep, a find there went in the first casts.
- **Strength 1700 x 3.47** (1700 / 5.9k / 20.5k / 71k), top kept, pinned in `HAND`;
  `shop.json` rebuilt, the pricing loop not run, the sim not re-run.
- **`SAVE_VERSION` 17**, v16 refused; the v16 save is `_builds/lake_cleanup_v16_20260929.save`.
- Out of scope: a wider ring, other prices. Bait numbers are first guesses; the next logged
  run judges them.

### The Thin Ring Round the Island (2026-09-22, `/grill-me` with Richard, player feedback)
Players' first sessions: the water by the island was nine-deep soup, so ten minutes of
casting skimmed the top off it and nothing ever read as cleared. Now the first stretch out
from the island is thin and light, and what it gave up is out in the rest of the lake.
- **`LakeGrid.RING_OUT` 8 tiles past the drawn water edge**: the level-0 net (4 tiles)
  plus the first couple of Range levels. Inside it every stack holds `RING_SLOTS` (2 over
  the inner half, 3 over the outer) instead of the depth's 9, and **every tile is still
  filled** — no gaps, by Richard's call over empty water from the start. Every piece is
  tier `RING_TIER` (1) or lighter: liftable at level 0 or after the first Strength.
  `OPEN_RING` (top piece tier 0, 4.6 tiles) still applies inside it.
- **The total is held, the depth untouched** (`_plan_slots`): `Iso.depth_at` still feeds
  the water's bands and the old count, and the slots the ring gave up are dealt back one
  each over the tiles past it, the remainder to a shuffle off the lake's seed. Measured:
  436 ring tiles, 16264 slots before and after. The nine-deep tiles were all by the island,
  so the deepest tile is 8 now (`deepest()`), which is what the filth map's ceiling reads
  in place of `Iso.MAX_SLOTS`.
- **The roll is the same roll, then traded** (`_lighten_ring`): a heavy piece rolled inside
  the ring is swapped with a light one from past it, matched by which quarter of its stack
  it sits in, so the material quota, the tier shares and the depth band come out as before
  and nothing is re-rolled or thrown away. `test_lake`'s `PAY_PRICED`/`TIER_PRICED` hold
  within their 2%/3% (tier 0 at 33.3% against 35.1% is the widest). `_dress_surface` runs
  after the trade, over every tile.
- **A fresh ring reads dirty, the bank's rule brought inward** (`Lake._room_at`): inside
  `RING_OUT` a tile's room is its own thin fill, so the ring is one soup with the rest at
  the start and lightens a piece at a time as it is worked. Honestly-lighter-from-the-start
  was offered and turned down: the point is to see it cleared, not to be told it nearly is.
- **Prices stay frozen, by Richard's call**; he judges it on a fresh run. The sim was
  **not** re-run: its `k_density` is one number for the whole lake and it cannot see a
  spatial thinning, so a re-run would report no drift and mean nothing. Expect the first
  ten minutes to land fewer pieces a cast and Catch to bind later; if the run drags, the
  levers are `RING_SLOTS` and `RING_OUT`, not the prices.
- **`SAVE_VERSION` 15**, v14 refused (stacks are saved, so an old file would keep its deep
  ring for ever); the v14 save is at `_builds/lake_cleanup_v14_20260922.save`.
- **Out of scope, by decision**: empty tiles, `depth_at`, the strand and beach litter, the
  find bands (`EARLY_FINDS` still land one slot down inside 15 tiles; a 2-deep tile is
  skipped by `_find_spots`'s `height < 3`, the 3-deep outer half of the ring is not).
- `test_lake`'s `_check_surface` guards the ring's depth and tier (finds excluded), the
  fresh ring reading the dirtiest state, the slot total against the depth's own, and the
  ceiling. `_deep_tile` moved out past the ring. Numbers are first guesses for the run.

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
My Dirty Little Lake's visual target is **cohesive pixel art isometric**, all assets from a single visual voice. This is the settled direction for the vertical slice.

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
  less value-noise `wander`), and so what it shows: the pack's sand slab (a 1-cell strip),
  or the lawn **drawn blade by blade** (`blade_grass`).
  **The lawn is drawn, not sampled** (2026-09-28, `/grill-me` with Richard, picked off
  `tools/last_grass_*.png` and trial sheets from `tools/shot_grass.tscn`): every pack grass
  tile showed its diamond seams and repeated one blotchy pattern a tile, and patching the
  edges, a screen-space swatch and random per-tile crops were each tried and left a grid or a
  rhythm. Now each art pixel is the layer's ground green, a little speckle (`speckle`), or
  part of a thin blade one pixel wide, two or three tall, with a lit tip, `blade_share` of
  pixels rooting one and `blade_lean` of blades leaning a pixel at the top (Richard: "thinner
  blades, lean only just a bit"). The greens are three steps of the pack's own grass ramp
  (`Ground.lawn_shades`: the slice's commonest green, one down for the blades, one up for the
  tips): island off slice 18 (`GRASS_ISLAND`, flat, `TONE_ISLAND` 0), bank off slice 21
  (`GRASS_BANK`, one step darker, `TONE_BANK` 3: darker and lighter blotches at two scales,
  hard art-pixel edges). **Supersedes** the Voronoi patches, `patch_size`, the yard/rough
  pools and the turf overhang (a sampled tile's, gone with the tiles; the lawn's edge is the
  curve and the fringe). The island wears the bank's fringe and no lip (Richard: its south
  edge showed a hard line); its edge still does not wander.
  **The greens round objects are the lawn's**: `_pack_props` remaps every saturated green of
  the rocks, tufts and leaves (not the trees) onto its layer's three shades by brightness
  rank (`_green_to_lawn`, `_is_green`: saturation over 0.3, so a rock's greenish grey is left
  alone), and `Skirt._greens` (the hut's, the crate's and the pump's hems) takes the island's
  blade and ground greens. The lawn/beach line is a curve stepped at art pixels, the same
  way `water.gdshader` cuts the island coast; `fringe` blades hang over the sand (mode 1
  straight down, mode 2 along the curve's normal). Cube sides are not drawn at all
  (`GRASS_LIFT`, skirts, `_face_top` gone). **`Ground.coverage_at`/`kind_at` mirror the
  shader** — the props
  (trees, rocks, leaves, and the sparse beach tufts within `TUFT_REACH` of the line at
  sub-tile offsets) are laid by them; the two must move together.
  **Retired, by decision**: the mixed `BLEND` band, `GRASS_BORDER` mounds, `SAND_TUFTED`
  cubes, the generated fringe strips (`assets/fringe`, `generate_fringe.py`), the per-tile
  batched mesh, and the pack's grass/sand join tiles (tried 2026-09-11, a corner set that
  reads as a staircase of cuts). A line drawn by choosing whole tiles is a staircase
  whatever the tiles; don't go back to tile picking for the edge.
  **Deleted 2026-10-03 (The Pre-Release Cleanup).** **Tuning**: F4 in a debug build opens `GroundTuner` (sliders for every ground uniform, plus
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
  - **The remap runs on a worker thread** (2026-09-26, Richard: "performance is bad when
    casting net"; `bench_frames` `BENCH_CAST=1`). The build had grown to 9.6 ms (distance
    map 2.7, pooled share 2.6, clean count 1.6, sources and pixels 2.2), once a cast, and
    that was the 16-17 ms hitch at every catch. `_remap_filth` now snapshots each tile's
    count on the main thread (`_filth_counts`, ~1 ms), `_filth_work` builds the pixels and
    the clean tiles on `WorkerThreadPool` touching no node, and `_land_filth` applies the
    answer the frame it lands (`_apply_filth`). **The map is a frame or two late, by
    decision**; nothing waits on it but the shader. `_build_filth_map` is still the whole
    thing at once, for the load and the harness, and waits out a remap in flight first.
    Casting: worst frame 17.3 ms to 9.2, mean about 6. The haul's count over the angler
    measured 0.1 ms and was not the cause.
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
  patch of clean water at the mouth: the mouth's own extent plus `PATCH_REACH` (0.5) tiles in
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
  Controls and their WoodUI theming are gone from the settings. **Nothing is themed by
  `WoodUI` any more** (2026-09-20): `Lake._polish_panel_controls` was its only caller, and
  the deletion of the stock shop panel left it pointing at two nodes
  (`HUD/Shed/Pad/Lines/Title`/`Note`) that had not been in the scene for some time — so it
  had already been styling nothing. `scripts/wood_ui.gd` is now unreferenced. The frame and
  title plank are `Style.board_frame`/`board_ribbon`,
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
  quitting the game is the menu's Quit or the window's cross. The level swap row, `_next_scene`
  and the farewell's onward door are gone with the siege (see The Siege Deleted).


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
    were deleted from `Style` on 2026-10-06, nothing reading them any more.
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
    **Since v3 (2026-10-08, see The Logo, v3) both name the sticker, not the picture**
    (`LoadingScreen.LOGO_INK`): 0.374 of the window and (69, 51), which is where v1's 0.40 at
    (56, 40) put the letters. `DROP` went 24 to 46 for the same reason.

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
  **How to play stands above Credits** (2026-09-19, issue #24): the onboarding cards again,
  and **the only way back to them** once the intro is over — the note on the shed door is
  gone by then. Accepted cost: a player ten minutes in has to go to the menu to re-read
  them, which the settings board's *Save and go to menu* makes one click.
  Six `PlankButton`s (232x56): Continue (only when the lake behind **loaded** a run —
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
  no credits.
  **And one heading that owes nothing: `Tools`, "Made with Godot Engine"** (2026-09-19,
  issue #27). Godot is MIT and a game made with it owes no attribution; it is on the board
  because a player has nowhere else to look, and it is the only line there that is not a
  licence obligation. **The font is not listed** — Bungee's OFL asks for nothing either, and
  a list of everything that asks for nothing has no end. Neither is PixelLab, which would
  reverse the AI-art call. The board is 478 design px of the 680 the smallest window leaves.
  A line too wide for the face **wraps** on spaces rather than being cut or
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

### The Doors Hold Water (2026-09-26, `/grill-me` with Richard)
- **The main menu's six doors are tanks of lake water** (`PlankButton.water`, set only in
  `menu.gd`): the HUD meter's painted sheet, sampled inside `HudSkin.METER_OPAQUE`, in a
  **rounded pool** (`POOL_ROUND` corners) `WATER_FILL` (0.4) up the face. Murky in every door,
  **clean in the accented one** (dimmed `CLEAN_DIM` so the cream word reads), lit edge kept.
- **Alive, not a line** (second pass the same day, Richard: "a straight line that jiggles"):
  the body rocks on a spring (`_tilt`, `TILT_*`), climbs each wall (`MENISCUS`), carries three
  waves, a pale lip with a shade under it, a glint riding the crest and `BUBBLES` rising in
  whole pixels. A hover throws the water one way (`TILT_KICK`), kicks the waves and jolts the
  wood once (`JOLT_TIME` 0.3 s, `JOLT_PX` 3); it sloshes back and settles.
- Out of scope, by decision: other buttons, new sounds or art, water answering a click.
  All numbers first guesses; judge on `tools/last_menu_main.png`.
- **A hover drips** (2026-09-27, `/grill-me` with Richard): `DRIPS_ON_HOVER` (2) drips
  squeeze out under the door's foot, stretch and fall (`_drips`, `_draw_drips`), in the
  door's own water (`DRIP_MURKY`/`DRIP_CLEAN`, picked off the sheets inside
  `METER_OPAQUE`). None at rest. **Tried and reverted the same day**: the logo's liquid in
  the doors (LAKE green in the accent, DIRTY mud in the rest, mottled body, torn lime crest);
  the meter's water stays.

### The Arrival and the Letter (2026-09-19, `/grill-me` with Richard, issue #24)
A new game opens with the angler and his dog landing by boat and reading a letter on the
shed door. Five cards (four until the Welcome card, 2026-09-22), then the first steps on the lake (see The First Steps below, which
**supersedes "that is the whole of the tutorial"** — this line said so until 2026-09-22).
Still no unlock pacing that teaches one system at a time and no goal readout. **#24 stays
open** for the hints still to come.
- **Unskippable, and therefore short** (Richard's call over a skip key): about twelve
  seconds from the glide landing to the cards being up. A skip is an admission that the
  thing is too long.
- **The boat is the fleet's own first hull**, not a visitor built for the occasion:
  `Boat.arrive_from` puts it off the lake and sails it home as `RETURNING`, so the course,
  the bell and the berthing are the ones it already had, and it is the ferry from then on.
  It is `moored` until the cards are closed, so it does not set off on a run behind them.
- **The pair step off onto the beach, not onto the berth** (`Lake._ashore_of`): a berth is
  water and `Angler.stand_at` walks a figure off water to the nearest dry tile, which is
  inland — so the two appeared halfway up the island. The spot is measured off
  `Iso.ISLAND_RADIUS`, not as a share of the way out to the berth, which is still water
  however small the share looks.
- **The angler is led, not driven** (`Angler.walk_to`): read **instead of** the input rather
  than through it, because the player's hands are held for the whole arrival and that is
  exactly what `can_walk` refuses. The walk clears it on arrival, so the lake watches it for
  the end of the beat.
- **`Arrive.READING` is a state and not tidiness**: `WALKING` is tested every frame, and
  with nowhere to go the step raised the letter again on each one — which calls
  `Letter.open`, which puts the reader back on the first card. The cards could not be paged
  at all until it was there. `test_lake` drives the step twice with a card turned.
- **The note on the door is the intro's alone.** It opens itself and is gone; the cards are
  read again from the main menu's **How to play** plank (see The Front above).
- **`intro_done` in the save, and a missing key reads as *done***: every file written before
  this existed belongs to somebody who has already played, and giving them the arrival on
  Continue would be a bug wearing a tutorial's clothes. Nothing else in the save moved, so
  **no `SAVE_VERSION` bump** — the furnished save and the trailer's shed shot are untouched.
  A borrowed lake (every harness and probe) is marked done as well, unless it asks with
  `Lake.force_intro`.
- **A paper letter on the wood, not a fourth settings board** (`scripts/letter.gd`; second
  `/grill-me` the same day, a UI pass over the first cut). The oak frame, the title plank and
  the close cross are the carpentry every board wears; the face is **a sheet in the sand's
  tones** (`PAPER`, `INK`, `HEAD_INK`) with the planks' V bites torn out of its edges — **no
  black rim round them**, which is what a hole in wood wears — and dark ink with **no drop
  shadow** (`_ink`, not `Style.write`: that shade is for labels on dark wood or open water
  and under dark ink on a pale sheet it is a smudge). The first cut was the shop's dark face
  with three ellipses on it and read as a menu with nothing to set.
- **The pictures are the game photographing itself** (`tools/shot_letter_art.tscn` ->
  `assets/letter/*.png`, nine stills), **pinned like photographs**: a white border, a pin, a
  shadow down and to the left, each hung up to `SNAP_TILT` (1.6 degrees) off level by a hash
  of its name, as child `Snap` nodes at a **linear** filter so the board's pixel wood does
  not go soft with them. **This supersedes the first cut's "every picture is drawn in code,
  so nothing can drift"**: a ring on a flat face explained nothing, because what a ring
  means is what is under it. **The cost, taken knowingly** (Richard): a repainted ring,
  lake, shop or HUD means re-running the probe and reimporting, and **the stills carry the
  game's English UI as it stands** — a language pass (#28) re-shoots them.
- **A pose is found, not written down**: the probe asks the net where the ring reads green
  (the busiest such water in reach, a tie going further out — by the island the fill is
  thin), where it reads red over open water, where a piece too heavy for the net floats, and
  the grid where the new game's find lies; the wash shot is sprayed **until the stand says
  half clean** (`WASH_UNTIL`), not for a number of seconds. What it cannot find it says in
  `tools/last_letter_art.log` and leaves the old still alone. Contact sheet:
  `tools/last_letter_art.png`. The Strength row is cropped **with the rows either side of
  it** (`ROW_CONTEXT`): alone it is a strip 3.5 times as wide as tall, and pinned beside a
  photograph it took the whole card.
- **The cards** (reworded 2026-09-22, `/grill-me` with Richard; see The Board Reads
  "How to Play" below): *Welcome* — the greeting and three sentences, no pictures; *Net* — three stills captioned in the ring's own colours; *Upgrades*
  — the shop's NET / BOATS / DOGS boards, one each; *Object Tier* — a red ring on a heavy
  piece ("Too heavy"), the Strength row ("Upgrade Strength"); *Decoration* — Catch it / Wash
  it / Decorate, the last a furnished shed. One to three stills a card, one height for a
  row, each as wide as its own shape, the row scaled down together if too wide.
- **The greeting is the first card's alone** (Richard, over a letterhead on every card and
  over a fifth opening page); the other three cards give its room to their pictures. **One
  line since 2026-09-22**, the lake's name a size up — see below.
- **One height whatever card is up** (450 design px of the 680 a 720 window leaves, was
  428): laid out from the top — greeting, heading, sentence — and from the bottom — pager,
  and the door on the last card — and the pictures take what is left between. Before
  2026-09-22 "Start cleaning" stood at the pager's right end in place of the forward arrow.
- **Every line is measured against the paper** (`_fitted`, `overruns`, `dropped_lines`):
  `Style.write` neither wraps nor clips, and the first cut's net card ran its second line
  clean over both stiles of the frame. A line too wide drops a size; one still too wide is
  counted, and `test_lake` asks for none, captions included.
- **Out of scope, by decision**: contextual hints, unlock pacing, a goal readout, a skip
  key, new painted art, loops or animation on the cards, a live viewport onto the lake,
  per-language stills (superseded 2026-10-07, see The Cards in Every Language), and any
  tutorial quest or checklist.
- **Probes**: `tools/shot_letter.tscn` (desktop build, `--fixed-fps 60`, its own save path
  and no file at it, `Lake.force_front` + `Lake.force_intro`) saves
  `tools/last_letter_{sailing,walking,card_*}.png` and `last_letter.log`. **A page turned is
  not the frame the capture lands on** — taken on the turn, all four pictures came out as
  card one — so it waits `TURN_SETTLE` frames. `test_lake`'s `_stage_letter` guards the four
  cards, the pager's clamping, the door on the paper centred above the dots, the
  cross, the room at 1280x720, every line and caption fitting, every still being shot and
  imported, the greeting's room going to the pictures, the absent-key rule, the close ending
  the arrival, and the menu's plank standing above Credits.

### The First Steps (2026-09-22, `/grill-me` with Richard, issue #24)
After the letter's cards close on a new game, walking and casting are taught on the lake
itself. `scripts/first_steps.gd` (`FirstSteps`, draws only) and `Lake._first_steps_step`
(decides). Every piece was approved off a mockup (`tools/tutorial_mockup.py`) before a line
of game code, and then off the probe's captures.
- **Walk**: a pulsing white ring and a down arrow on a spot of the island's beach, the mouse
  and the four walk keys (the stick in pad mode) over the angler's head. **Ends when he
  stands on the spot** (`STEPS_ARRIVE`), not on the first press, and the prompts do not fade
  on input. **The cast is held until then** (`_walk_not_cast`): a press on water walks to the
  shore towards it and throws nothing. Nothing else is held — the world, the dogs, the boats
  and the HUD buttons all run.
- **The spot is found, not authored** (`_beach_spot`): 48 bearings round the island, the
  standing point pulled `STEPS_BEACH_IN` onto the sand, kept only where a sure cast spot is in
  reach from it, and the nearest at least `STEPS_WALK_LEAST` from the angler. None found, the
  steps are marked done rather than stuck. The search is one-off, about 200 ms, on the frame
  the steps start.
- **Cast**: a ring on water and the click (RT) over the head. **The ring is a promise**
  (Richard: "a cast around and inside the circle is guaranteed"): `_sure_catch` asks the aim
  ring's own verdict at the middle and at `STEPS_RING_TESTS` points on the rim and half way
  in, and the ring is `STEPS_RING_SHARE` of the net's open mouth. Straight out from the beach
  spot first, then up to two tiles either side. Re-found if its piece goes (a dog, the double
  cast). **Any cast that catches ends the step**; an empty one keeps it.
- **The note**: a paper card beside the recycle box (the letter's paper and inks, a dark
  rim, 10 px — a pixel under `TEXT_TINY` so the sentence sits in three lines) and the arrow
  over the box. Closes on a click on the card, or `STEPS_NOTE_HOLD` (5 s) after the catch
  lands in the crate, never past `STEPS_NOTE_MOST`; **in pad mode 5 s after it appears**,
  there being no pointer to click it with. The timer pauses under a board. No camera move,
  by decision: the crate is already on screen.
- **Prompts are Kenney's Input Prompts Pixel** (CC0, `assets/ui/prompts/`, cut by
  `tools/build_prompts.py` off Richard's tile picks on `tools/last_prompt_contact.png`),
  drawn at `PROMPT_PX` (2) physical pixels to one of theirs whatever the window's stretch,
  in screen space through the camera's transform. **Keys follow the layout**: the walk keys'
  printed labels (`Binds.label_of`) pick the tile, so AZERTY shows Z Q S D; a label the pack
  has no tile for falls back to W A S D. The device swaps live (`Pad.is_pad`).
- **Saved as `first_steps`, absent reads as done** (the `intro_done` rule), no
  `SAVE_VERSION` bump. **A run saved before the note closes starts over from the walk**, by
  decision — nothing of where it had got to is kept. A borrowed lake is marked done.
- **The note's sentence is `Text.STEPS_NOTE`** in `locale/translations.csv` (this line said
  it was a literal until 2026-09-29; it had been keyed already, as the letter's are).
- **Out of scope, by decision**: a skip key, a hint on the first decoration, hints on the
  upgrades and decorate boards (all to come, #24), path planning for the walk.
- Probe: `tools/shot_first_steps.tscn` (desktop build, `--fixed-fps 60`, own save, under its
  own node) saves `tools/last_steps_{move,move_azerty,move_pad,cast,cast_pad,note}.png` and
  `last_steps.log`, casting near the ring's **edge** to prove the promise. `test_lake`'s
  `_stage_first_steps` guards the start, the beach spot, the sure ring, the held cast, the
  walk ending on the spot, empty and catching sweeps, the pad's five seconds, the flag, and
  the key fallback.

### The Shop Tour (2026-09-22, `/grill-me` with Richard, issue #24)
The first time a new game opens the upgrades shop, six paper cards walk it, one at a time.
`ShopSkin.TOUR`, `_draw_tour`, `_tour_input`; the lake starts it and saves it
(`Lake._shop_tour_done`, `_on_shop_tour_ended`). Approved off `tools/last_shop_tour_mockup.png`.
- **The cards, in order**: the NET board; the LUCK board's *On a cast* rows ("your net
  luck", Richard's wording); BOATS; DOGS; *At the yards*; the pricing plate. A group's box is
  measured as it is drawn (`_group_boxes`, off the heading in `GROUPS`).
- **Spotlight and card**: everything but the target dimmed (`TOUR_DIM`), a white outline, the
  down arrow on its top edge, and the recycle note's paper card (`FirstSteps.NOTE_*`) beside
  it — right of it on the left half of the screen, left of it on the right, above the plate —
  with "n/6", "Skip" and "Continue" with the mouse click (the pad's A, tile 4, in pad mode).
- **Drawn on a child layer (`_tour_layer`), kept last**: the ferry, the net and the dog heads
  are child nodes and draw over anything the board draws itself — the first capture had the
  ferry standing on the card.
- **A click (A) goes on, "Skip" ends it for good**, and while it is up nothing can be bought
  and a click off the boards does not close the shop; the cross and Escape still do.
- **Closed half way, it picks up at the same card** next time the shop opens (the board keeps
  `tour` for the session). **Quit half way, it starts over**: only the done flag is saved,
  as `shop_tour`, absent reads as done, no `SAVE_VERSION` bump. New games only.
- **The six sentences are keys** (`TOUR_SHOP_*`) in `locale/translations.csv`.
- **Out of scope, by decision**: tours of the decorate board and the first decoration (to
  come, #24), changes to the shop's layout, hover tips outside the tour.
- Probe: `tools/shot_shop_tour.tscn` (desktop build, own save, under its own node) saves
  `tools/last_shop_tour_{1..6,pad}.png`. `test_lake`'s `_stage_first_steps` also guards the
  tour starting, keeping its place over a close, blocking a buy, ending saved and not coming
  back.

### The Decoration Tour (2026-09-22, `/grill-me` with Richard, issue #24)
The first time a new game opens the shed, five cards walk washing and placing, in the shop
tour's look. `scripts/tour_card.gd` (`TourCard`, draws and reports clicks) and
`Lake._decor_tour_step` (the `DecorTour` states, the targets, the room swaps). Approved off
`tools/last_decor_tour_mockup.png`.
- **A new game's bed starts at the pump** (`_bed_to_the_pump`, from `_start_arrival`), not
  standing in the shed, and **washes free** (`WashRoom.free`, the row reads "Free"). Older
  saves keep their bed where it stands; `_seed_starter_bed` treats a bed waiting at the pump
  as had.
- **Two ways in**: the shed opened first starts on card 1; **a find netted before the shed
  was ever opened** puts a hint on the Decorate button `DECOR_HINT_AFTER` (2.8 s, after the
  find-caught card) — outline, arrow and a card with no count, **no dimming and clicks
  passing through**, since the player is being shown where to click. Opening the shed turns
  it into card 1.
- **The cards**: the wash plank; the wash list; the stand (pad: "Aim and hold RT…"); the
  shelf (mouse: drag, R to turn; pad: A to pick up and place, X to turn — **not "X to
  place"**, which was the brief and matches neither device; key names off `Binds.shown`);
  the room — the first placed piece with a switch lit, or the whole shed when there is none
  (`ShedRoom.switch_box`, `room_box` is `_shed_rect`).
- **Between cards the target keeps a pointer** (outline and arrow, pass-through) until the
  player does the thing: clicks the plank, washes. **A find coming clean in the tour takes
  the player back into the shed** `DECOR_BACK_AFTER` (1.6 s, after its shine) — the one
  place the wash room does not close to the lake.
- **A card waits for its room**: shut the shed on card 1 and it is there next time. Saved
  as `decor_tour` once over (read through or skipped), absent reads as done, quit half way
  starts over.
- **`TourCard` is hung off the HUD's CanvasLayer and sizes itself to the viewport by hand** —
  anchors have no parent rect there, and the first capture came out with a zero-size card
  and no paper.
- **The shop tour still draws its own copy** (`ShopSkin._draw_tour`); folding it into
  `TourCard` is owed. The sentences are keys (`TOUR_DECOR_*`).
- **Out of scope, by decision**: soap prices, wash mechanics, tours for later finds.
- Probe: `tools/shot_decor_tour.tscn` saves `tools/last_decor_tour_{hint,1,2,3,3pad,4,4pad,5}.png`.
  `test_lake`'s `_stage_first_steps` guards the bed at the pump, the hint giving way, the
  cards following the rooms, the free wash, the walk back into the shed and the flag.

### Onboarding Fixes (2026-09-24, `/grill-me` with Richard)
- **The boat sets off from the plastic pier's berth** (`Lake._arrival_berth`), moored there
  while the glide lands, and sails its course home. It used to start off the basin and
  cross the forest and the beach. The crossing is longer; accepted.
- **The angler is led to the shed door** (`_before_the_door`, `DOOR_ALONG` 0.2 of the
  half-footprint along the hut's left front face, `DOOR_STAND` 0.45 tiles out), and a
  **paper note is pinned beside the door** (`_draw_door_note`, `NOTE_ACROSS`/`NOTE_UP`,
  whole art pixels sheared to the wall's slope) until `intro_done`. The cards still open
  by themselves on arrival; the note is gone once they close. `ARRIVE_AT_SHED` is retired.
- **The Welcome card shows the whole lake** (`lake_whole`, the fresh lake at the far stop,
  shot first by `shot_letter_art`), under the greeting and over the paragraphs
  (`LETTER_ART_TALL` 150; the card's `rows` 6 to 5).
- **The last card keeps its back arrow**; still no dots and no forward arrow.
- **The recycle note stopped trembling** (`FirstSteps._on_screen`): it was rounded to whole
  canvas pixels while the world is snapped to whole screen pixels, so at a 1.5 stretch it
  stepped against the box on alternate frames of a walk. Rounded on the window's grid now.
- **A tour card's lit target takes the click** (`TourCard.through`, `_has_point`): on the
  plank, list, stand and shelf cards a click on what is lit does what it does and moves
  the tour on; Continue and the rest of the screen only advance, as before. The room's
  card stays blocking. Picking a find in the list puts it on the stand and the stand's
  card comes up over it; the stand's card gives way once `DECOR_SPRAYED` of the coat is
  off; the shelf's card gives way while a piece is in hand and the room's follows when it
  is put down.
- **A piece clicked out of the shelf stays in hand** (`ShedRoom._gui_input`): let go over
  the shelf, the next press puts it down. A drag onto the floor still drops where it is
  let go. For every player, not only in the tour.

### The Board Reads "How to Play" (2026-09-22, `/grill-me` with Richard)
A wording and layout pass over the onboarding cards, off Richard's first-time-player notes.
`scripts/letter.gd`, `tools/shot_letter_art.gd`; nothing in the arrival moved.
- **The plank says "How to play"**, not "A letter" — the menu's plank already did.
- **A Welcome card opens it** (Richard, later the same day): its plank says **Welcome**
  (`title`, per card; the rest keep "How to play"), it has no heading (`head` empty), and
  it is **set like a letter** (`letter`): the greeting over three paragraphs — the lake
  abandoned (plain ink), the goal (catch, recycle, bring life back) and that the cards teach
  how (both marked) — spread down the page (`LETTER_SPREAD` caps the gap at 2.2 rows),
  **all centred** (ranged right was asked for and then taken back the same evening). No
  pictures; `rows` 6 gives their room to the words. Five cards now.
- **The Net card is two paragraphs** (`rows` 4, so both stay at the body size), like the
  tier card.
- **The last card has no pager**: no dots, no arrows, their boxes emptied; "Start cleaning"
  stands centred in the pager's row, so the pictures reach the same foot on every card and
  the door is the one way on.
- **Heading, then words, then pictures** on every card (the first cut stood the heading
  under the pictures): the Net card's sentence says "the circles below", so the pictures
  are below. `_head_base` / `_text_foot` / `_art_box` are the top-down walk; the door and
  the pager come up from the bottom.
- **The Net captions say their colour in it** (`CAPTION_INKS`): "Guaranteed objects" in the
  aim ring's green, "No object available" in its red, each **darkened until it clears
  4.5:1 on the paper** (4.6 / 5.1 — the ring's own swatches are lifted for dirty water and
  read 1.3 / 2.9 on cream); "Out of net range" in the soft ink with a **dashed underline**
  (`_underline`). A white-stroked word was asked for and turned down on the pushback: white
  on cream is nothing. `test_lake` measures both inks against `Style.PAPER`.
- **The greeting is one line** (Richard: "decrease size if needed"), the lead in body ink
  and **"My Dirty Little Lake." a rung up in the head ink** on the same baseline
  (`GREETING_LEAD` / `GREETING_NAME`, `greeting_sizes`, `_draw_greeting`). Bungee has one
  weight, so bolder is bigger. On the 678 px paper it lands at **16 / 20** (at 620 wide it
  was 11 / 13, which Richard read as too small).
- **The sentences are wrapped, not authored in rows** (`text` per card, `_rows`,
  `SENTENCE_ROWS` 3): body size first, a rung down if that needs more rows. Typos in the
  brief fixed on the way ("indicates", "weight 5 weight tiers", "Strenght").
- **"Start cleaning" stood centred above the dots** for an afternoon; see the last card
  having no pager, below.
- **A word between asterisks is written in the head ink** (`_tokens`, `_wrap_marked`,
  `_ink_marked`): "*Left click*", "*circles below*", "*5 weight tiers*", "*catches more
  objects and cleans faster*", and the three on the Upgrades card — the lake's name's own
  red, so a card points at what matters with no second face or size. A `
` in a card's
  text is a paragraph: its own row, `PARA_GAP` (half a row) over it. `test_lake` asks that
  some words are marked and no asterisk reaches the paper.
- **The Upgrades card is three boards over three blurbs** (`blurbs`, `_caption_band`,
  `_draw_blurb`, `BLURB_ROWS` 3): the top of each board — plank, head, first row or two
  (`BOARD_TOP` 250 in the probe) — in a row, its own sentence wrapped narrow under it at
  the small size. **Side by side was tried the same day and rejected** (Richard: the boards
  too small, the left half bare): stacked down the left with the words beside them, three
  rows in a 450 board gave each board 95 px however it was cropped, and a taller board
  would have left bare paper on the other three cards.
- **The board went 620 to 760 wide**, which is what took the greeting from 11 / 13 to
  **16 / 20**; `ART_LEAST` came 150 to 110 with it, since the room now comes across.
- **Upgrades shows the three boards** (net, boats, dogs, plank to foot, `BOARD_PAD` /
  `BOARD_PLANK`), shot with the corner HUD skin hidden — the HUD *layer* cannot be, the
  shop lives on it. **Decoration's last still is the shed** furnished as `tools/shot_shed.gd`
  lays it out (`SHED_LAYOUT`, copied, every switch on, dogs cleared), cropped to
  `_shed_rect`; `_room_rect` took lake round the room. The HUD buttons (`upgrades_button`,
  `decor_button`) and the two-board `upgrades_shop` stills are deleted.
- **Object Tier** is the Weight card renamed; its stills re-shot on the third rubbish batch
  and the rimmed Strength row, which the probe did by being run.
- **Out of scope, by decision**: any card added or removed, a skip key, contextual hints,
  new painted art, the arrival's timing, the paper's look.
- `test_lake`'s `_stage_letter` guards the heads, the title, the one-line greeting with the
  name a size up, the three caption inks and their contrast, heading over words over
  pictures, the door centred above the dots and its row reserved, and the rest as before.

### The Cards in Every Language (2026-10-07, `/grill-me` with Richard)
- **Welcome**: greeting, then "The lake has been abandoned and neglected for too long."
  (`LETTER_WELCOME_LEAD`, the card's `lead`, `_lead_fit`, `_top_tall`), then the lake
  picture, then the goal and instructions paragraphs (`LETTER_WELCOME_TEXT` lost its first
  paragraph). PT source "O lago foi abandonado e esquecido por tempo demais."
- **Net**: "*Left mouse-click* to cast..." in every language; the pad wording is unchanged.
- **Pictures stand under the rows really written** (`_text_foot`), not the rows reserved, and
  are centred between them and the pager: a two-row sentence under four reserved rows left
  them hanging low. Every pictured card, not only the Net one.
- **The worded stills are shot per language** (`tools/shot_letter_art.gd` `WORDED`,
  `_speak`): the three boards and the Strength row as `name.png` (English) and
  `name.<locale>.png`; `Letter._still` takes the locale's, then its language's, then
  English. **Supersedes "per-language stills" out of scope** above. Wordless stills stay
  single. The language is set by hand; `settings.cfg` is never written.
- **The dogs still has the pack staged across the card** (`ShopCard.stage_dogs`, probes
  only: four dogs held in place, legs running).
- **The house and wash stills are Richard's room**: `user://play_decor.save` copied to
  `user://probe_letter_decor.save`, version raised (shot_wash_place's rule), a second lake
  loaded from it, every switch on and counted as tried (no pointing hands), dogs out; the
  white sofa half washed. `play_decor.save` was copied over once from the old Lake Cleanup
  folder, which `Prefs._bring_old_files` does not carry.
- **"Start cleaning" floats on a pond** (`scripts/letter_door.gd`, `LetterDoor`, picked A off
  `tools/last_door_mockup.png`, `tools/door_mockup.py`): clean water behind the whole plank
  and in a strip past both ends (`REACH`, `STRIP_FROM`, `UNDER`), so **the plank's bites
  show the lake, not the paper** (Richard, on the mockup); reeds and cattails at both ends,
  a pad, a lily, a bottle and a can (`DRESS`), pack art at 2 design px an art px. Stepped
  bands and a torn foam lip at `PIXEL_FPS`, pieces bob a whole art px, reeds lean by rows; a
  hover kicks foam rings out from the plank's corners, a double bob and a swing over
  `KICK_TIME`. No sound. All numbers first guesses.
- `test_lake`'s `_stage_letter` guards the worded stills in all eight languages, the lead
  line, the net wording, and the pond behind the door on the last card only.

### The Boards Are Paper (2026-09-20, `/grill-me` with Richard, issue #7)
The last UI pass, and what closes #7: every board that opens shares one face. Richard's four
asks — more of the letter's cream, the decorate menu aligned and cosier, Strength set apart
and moved to the top of its board, and the luck coin animated.
- **Cream is the face, and only the face** (`Style.PAPER`/`PAPER_EDGE`/`PAPER_RULE`/
  `PAPER_INK`/`PAPER_HEAD`/`PAPER_SOFT`, moved out of `letter.gd`, which now reads them):
  `board_wood`'s fill defaults to the paper, so the shop's four boards, the pricing plate,
  the blurb plate, the settings board, the bind board, `MenuConfirm`, the credits, the shed's
  shelf and the wash room's tray all took it at once. **The row plates stay the murky water**
  — every ink on them was measured against that face over three passes, and moving the plates
  would have thrown all of it away. The letter keeps its dark board under its paper sheet, or
  the sheet would vanish into the board.
- **The HUD, the menu's doors and the gear keep their dark faces, by decision**: they stand
  over open water, which is what `Style.BUTTON_FACE` was picked against, and a pale plate on
  a cleaned lake at the end of a run would wash out.
- **`Style.write` drops its shadow for dark ink** (`SHADE_UNDER`): the shade is for a pale
  label on wood or water, and under dark ink on a pale sheet it is a smudge — `Letter._ink`
  found that first and worked around it by not calling `write` at all. One rule now, in the
  one place, so nothing written on paper has to remember.
- **What is written straight on the paper takes the paper's inks**: group headings and their
  rules (shop and settings, one drawing), the bind board's column names and hint, the
  legend's sentence, the credits, the confirm's line, the shelf's "Nothing kept yet". Worst
  measured 5.89:1. `test_lake` asks all three inks against the paper.
- **A head stands in a window of the old dark water** (`ShopSkin._draw_board`): the ferry's
  foam, the net drawn in black and the coin were all picked against `Style.BOARD`, and white
  foam on cream is nothing. The legend's figures likewise — the price's gold is 1.6:1 on
  paper — so the materials and their prices keep a dark plate and the sentence under it does
  not. **The plate's foot is measured off `at.y`'s own walk**, not guessed: guessed, it ran
  under the sentence and cut it in half.
- **`MenuConfirm`'s doors are the settings board's dark plate**, ringed and lit-edged. This
  is the 1.37:1 warning and 2.97:1 plain label that the settings pass named and left; white
  reaches only 4.06:1 on that oak, so no ink could have fixed it. `Style.WARN_INK` is
  `Style`'s now, not the settings board's.
- **The shelf and the shed are one row** (`ShedRoom.GUTTER` 14 to 22, `shelf_lift`): the
  shelf's title plank was overhanging the room — the gutter was narrower than
  `SHELF_OVERHANG` — and its drawn top sat 4 px under the shed's, because the board was
  squared with **half the ribbon's box** while the painted plank stands `PLANK_TALL` with its
  foot on the face. `shelf_lift` asks `Style` where the wood really is. The title is
  **"Decorate"** with a bare count, the word the HUD button already uses.
- **The room is lit through the window** (`shaders/shed_light.gdshader`, `ShedRoom._dress_light`,
  Richard: "sunlight coming through the left side, as if sun was hitting the side wall of the
  shed with the round window... no circled rings like current fireplace, it looks blocky and
  ugly"). One additive quad over the shed, under the shelf and the cross: a shaft from the
  left wall opening across the floor, and a soft pool for every lit piece. **Smooth, but
  worked out once per art pixel of the room** — a gradient per screen pixel is an HD effect
  laid over pixel art, and hard steps are what the rings were. **Retired**: `GLOW_RINGS`, the
  three stacked `draw_circle`s.
  - **The shaft is a cone and the pools face front** (Richard, 2026-09-20): the shaft opens
    as it crosses the room (`SHAFT_SPREAD` 0.78, `SHAFT_WIDE` 2.4 cells) so it lands on the
    floor instead of running along the back wall, and dims with the distance it has come
    (`SHAFT_LONG`). `shaft_spread` was a uniform the room never pushed, so the shader's own
    0.22 was what shipped. A lit piece's pool reaches `pool_ahead` times as far down the
    screen as across and falls off `pool_back` times as fast behind the piece: a hearth's
    fire is on its front face and lights the boards before it, not the wall behind it.
    **Its middle stays on the piece's own foot** — pushed forward instead (tried the same
    day), the brightest patch came away from the hearth and left a dark gap between the fire
    and its own light.
  - **The window is half way down the shed, not up in the wall** (`WINDOW_DOWN` 0.48 of the
    shed's own height; Richard, 2026-09-20: "a little bit more from the middle/down of the
    shed, not on top"). It was a share of `_wall_tall()`, which is four cells — 35 px down a
    512 px room — so the shaft entered at the ceiling and the light read as coming through
    the roof.
  - **The light follows the day** (`DayCycle.sun` through `sun_share`): pale, short and steep
    in the morning, long, low and orange late. `Lake` hands the room its `_day`; a room with
    none sits at `SUN_NO_DAY`.
  - **The room is dimmed for it** (`ROOM_DIM`, over the floor and the furniture, under the
    quad): the light is additive and can only brighten, so with nothing to lift it out of the
    shaft read as a pale wash rather than as sun. The lake behind is dimmed too
    (`ROOM_SCRIM`), so the room is the lit thing on the screen.
  - **`shot_shed` lights a fire and opens the fridge**: a probe that never lights one cannot
    show the pools the rings were replaced by.
  - Every number — `WINDOW_DOWN`, `SHAFT_*`, `SUN_POWER`, `SUN_SLOPE`, the two tones,
    `ROOM_DIM`, `ROOM_SCRIM`, `FIRE_POWER` — is a first guess for Richard's eye.
- **Strength leads the net's board and wears a gold rim** (`ShopSkin.GROUPS`, `FEATURED`,
  `_draw_featured`): a tier roughly triples income and opens rubbish nothing else can lift,
  and it read as one row in five. Two pixels of `Style.GOLD` round the plate, drawn back when
  it cannot be bought. **Gold on this board is a price**, which was weighed: the rim is a line
  round the plate rather than writing on it, and the tag still says the price.
  **Retired, by decision**: a four-point gold star on the plate's corner — the top right is
  the tag's, which reaches within a few pixels of the plate, and the top left is the rail's,
  where it sat on the "?". And `Style.PRICE_INK` for the rim: the tag's pale gold on the
  cream face read as a cream line.
- **The luck coin is tossed** (`ShopSkin.toss_pose`, `HudButtons.coin_turned`): it rests face
  on, and every 3-5 s (rolled, so it has no beat) and on any purchase from its own board it
  hops and turns twice, landing on the face it left. **Tossed, not spinning**: the ferry bobs
  and the dog breathes beside it, and a coin turning for ever is the busiest thing in the
  shop. Drawn by squashing the disc to a **whole** number of pixels across with the coin's
  thickness showing behind it, and the struck ring with no glint on its back. The board
  redraws only while it is in the air.
- **Out of scope, by decision**: cream row plates, the HUD's and the menu's faces, new
  painted art, a painted window in the room's own art, and any price or mechanic.
- `test_lake`'s `_stage_paper` guards the three paper inks, the shade rule, the letter
  reading `Style`'s swatches, the confirm's doors being off the oak, the shelf standing clear
  of the room and level with it at both ends, the ringed glow being gone rather than unused,
  the room's light node and its day, Strength leading and being the one rimmed row, and the
  coin's rest, hop, back and landing. Probes: `tools/shot_shed.tscn`,
  `tools/shot_menus.tscn`, `tools/shot_menu.tscn`, `tools/shot_pump.tscn`.

### The Pulse and the Wash Plank (2026-09-22, `/grill-me` with Richard)
Two small signals: the upgrades button says when something has just become buyable, and the
shed's shelf has a door to the wash room.
- **The upgrades button pulses only when the affordable count rises** (`HudSkin.available`'s
  setter, `_pulse`, `pulse_amount`, `PULSE_TIME` 4 s, `PULSE_BEATS` 3.5). **Not a steady loop,
  by decision**: the run ends with 43-56k unspent, so something is affordable most of the
  time and a loop would run for thirty minutes. A hold or a fall starts nothing; the first
  reading of a sitting only sets the mark (a load is not a rise). **After the burst it does
  not stop** (Richard, same day): the envelope settles to `PULSE_IDLE` (0.45) and keeps
  breathing there until the board is opened (`hush_pulse`, from `_set_menu` / `_set_shed`),
  which is the player seeing what was pending. A hover does not put it out. Supersedes
  "fades out on its own", which lasted an afternoon.
- **Superseded 2026-10-05** (see Four End-Game Fixes): the button hops and throws gold
  motes; the lift, halo and rays below are gone, and the wash plank throws motes instead of
  glowing.
- **The look is the button lifting and a gold glow with rays behind it** (`HudButtons.pulse`,
  `lift_by`, `PULSE_LIFT`, `GLOW_REACH`, `RAYS`, `RAY_REACH`): the button rises `PULSE_LIFT`
  (2) **whole** pixels and settles, the hover's own gesture, stacked on it. **Not a swell**:
  growing the box was tried the same day and "distorted the borders and text" — the border
  was rebuilt at a new size and the label re-measured — so nothing is resized, the badge
  included (it wears a gold ring instead). The wash plank neither lifts nor swells, it only
  glows. under the wood a halo of eight
  per-vertex-coloured quads runs from gold at the edge to nothing at `GLOW_REACH`, and
  fourteen tapering rays fade out past it, their lengths rolled off their index and
  breathing with the pulse. **Gold, and not subtle** (Richard, same day: a pale blue rim at
  0.75 was "too subtle"): gold on this HUD is a price, and this is a thing that can be
  bought. **No stepped rims** (Richard, same day: three rects of different shades were
  "blocky and ugly") — gradients, drawn under the button so its wood covers the inside.
  `_paint_key` carries the amounts, so the HUD redraws only while one is breathing.
- **The decorate button pulses the same way when a find arrives at the pump**
  (`HudSkin.waiting`, pushed from `_update_hud` as `unwashed.size()`; Richard, same day:
  "nothing happened to the decoration button when something was caught"). Pulses are kept
  by button name (`_pulses`/`_marks`, `pulse_amount(name)`, `hush_pulse(name)`); opening the
  shed puts the shed's out, the shop the upgrades'.
- **The shelf's wash plank** (`ShedRoom._wash_plank`, a `PlankButton`; `WASH_LABEL`
  "Wash  %d", `SHELF_WASH_N`): drawn **only while `unwashed` holds something**, right after
  the last row **and scrolling with the rows** (Richard's call over a fixed foot; it counts
  in `_scroll_by`'s span and, like a row, is hidden while its box is not wholly on the
  face), or alone `WASH_UNDER_EMPTY` under "Nothing kept yet." on an empty shelf. Clicking it
  emits `wash_asked` and the lake swaps rooms (`_shed_to_wash`: shed down, wash room up,
  one click); the wash room's own close returns to the shed (2026-09-26, was the lake).
- **It breathes the same pulse** (`PlankButton.pulse`, `ShedRoom.opened`, `_wash_seen`,
  `WASH_PULSE_IDLE`) when the shed opens with more waiting than the last time it opened,
  and keeps breathing at the idle level until the plank is clicked. Session only, nothing
  saved. The find-caught card is still the announcement; this is the door.
- **Out of scope, by decision**: a steady pulse, a sound on it, glow on any other button,
  walking the angler to the pump, going back to the shed after washing, showing the plank
  with nothing waiting, a fixed-foot plank. Amplitude, tone and beats are first guesses for
  Richard's eye.
- `test_lake`'s `_check_upgrades_pulse` and `_check_wash_plank` (inside `_stage_wash`)
  guard the rise/hold/fall rule, the breathing, the settle to idle, the hover not cutting it
  and the board opening cutting it, the plank alone and after the rows, its label, its pulse once and not on a reopen, its
  place at the end of an overfull shelf, its absence with nothing waiting, and the room swap.

### Three Shop and Shelf Fixes (2026-09-24, `/grill-me` with Richard)
- **The purse shows over the shop** (`HudSkin.purse_over`, `HudSkin.Purse`,
  `ShopSkin.purse_box`, `PURSE_GAP`): the HUD's own money plate, same drawing, running
  figure and shine, hung under the first board while the shop is up, on a node added after
  the shop in the HUD layer so nothing of the shop covers it. The corner plate is not drawn
  meanwhile and coins aim at the hung one (`coin_centre` reads `money_drawn_box`). One
  purse, by decision: no second figure drawn on the shop.
- **The wash plank stands clear of the last row** (`ShedRoom.WASH_UNDER_ROWS` 14, counted
  in `_scroll_by`'s span): under a single find its built frame and gold glow ran up into
  the row above.
- **The bonus's lit panel is measured, not guessed** (`ShopSkin.bonus_panel`, `_ink_box`,
  `BONUS_PAD` 6, `BONUS_SIDE` 22): the boosted material's name and figure with padding,
  held inside its slot of the dark plate. It was the whole slot at a guessed height and ran
  off the plate. **The stars stand in the panel's side margins** (`bonus_star_at`), not on
  its top edge, where they crossed the plate onto the paper and sat on the name.
- Probes: `tools/shot_shop_money.tscn` (desktop build, own save: `tools/last_shop_money.png`),
  `SHED_ONE=1` on `tools/shot_shed.tscn` (one find, one waiting). `test_lake`'s
  `_check_shop_purse`, `_check_bonus_panel` and `_check_wash_plank` guard all three.

### The Boards Wear Colours (2026-09-26, `/grill-me` with Richard)
The shop's four boards read apart, a maxed row reads as done, the coin is pixel art, and
ribbon titles are carved.
- **Row plates per board** (`ShopSkin.TONES`, `tones_of`): NET blue, BOATS brown, DOGS red
  rust, LUCK plum, each an [affordable, drawn back] pair. **None is green**: green is a maxed
  row. `BOARD_INK` and `INK_DIM` clear 6:1 on every pair. The lit edge still marks
  affordable. The paper face and the frame are untouched, by decision.
- **The head window** behind each board's sprite is its rows' hue `darkened(HEAD_DARK)`
  (0.45), replacing the one `Style.BOARD` window.
- **A maxed row** (`maxed` from `Lake._shop_rows`) is a deep green plate (`MAX_FACE`, ink
  5.5:1) and its MAX word stands on a pale green badge (`MAX_BADGE`) where the price tag was.
  **Not gold, by decision**: gold on this board is a price and Strength's rim.
- **The coin is a sheet** (`tools/build_coin.py`, `assets/coin.png`/`.json`, psd-extract
  venv python, **reimport after**): Richard's pick C of four rule-built options (`last_coin_options.png`),
  an 18 px disc with two arrows chasing round a ring, **struck on both faces** (the back
  mirrored and darker), nine toss frames face to edge to back. `HudButtons.coin` and
  `coin_turned` draw the frame nearest the turn (`coin_frame_of`) through a nearest-filtered
  `CanvasTexture`, so the luck board's toss, the money plate and every flying coin are one
  coin. **Supersedes the code-drawn disc** (`COIN_RIM`/`COIN_RING`/`COIN_GLINT` are unused
  now); the toss's timing is unchanged. Rules first: Richard may repaint `coin.png`.
- **Ribbon titles are carved** (`Style.write`'s `cut_in`, `CARVE_DARK`/`CARVE_LIP`/
  `CARVE_RIM`): a dark rim round the letters and a lit lip two pixels under them in place of
  the drop shadow. Every ribbon, through `board_ribbon`, not only the shop's.
- **The head cards are scenes** (second `/grill-me` the same day, `scripts/shop_card.gd`,
  one `ShopCard` a board, kept first among `ShopSkin`'s children so the hull, wake, mesh and
  collar draw over it; `clip_contents` so a dog or the pigeon's head can run off it). Drawn
  in whole 2 px art pixels off the palette's ramps, inside the board's hued plate
  (`CARD_RIM` of it shows). **A drawn mini-lake, not the player's lake, by decision**
  (a live view and a snapshot were offered). **Net**: always filthy water, scum, 16 pieces
  of the lake's own rubbish bobbing (lent as `sprites[&"rubbish"]`, the wash room's
  list), the catch drawn by the card under the mesh. **Boats**: clean water, three pieces,
  the ferry as before. **Dogs**: a new strip (trees on the far bank, clean lake with a
  ferry crossing, lawn; since 2026-10-03 the wash room's view in miniature, see Seven
  Adjustments) with **all four breeds always**, whatever the pack, running in and
  out of frame on their own gaits. **Luck**: the recycle box catching a piece every 1.5 s,
  the coin tossing in the middle, the pigeon's head leaning in off the right edge every
  6 s. **Always in motion, by decision** ("alive is the point"), over the old rule that the
  coin only tossed. The dog's idle/sleep head and the halos are retired. Frame cost with
  the shop open is not benched. **The letter's Upgrades stills show the old heads** until
  `shot_letter_art` is re-run.
- All colours and the carve are first guesses. `test_lake`'s `_check_board_tones` guards a
  tone per board, none green, the inks, the max face and badge, the rows' `maxed`, the coin
  sheet's nine frames and the carve.

### The Shelf Centred and the Tray in Plates (2026-10-09, `/grill-me` with Richard)
- **The Decorate column is 250 wide** (`ShedRoom.LIST_WIDTH`, was 210): the house and the
  column are centred as one block, so the house moves left by half of it. The Deck check
  (`keep_clear`) still passes at 1280 x 800.
- **The rows stand in the middle of the card** (`_list_rect`): the scrollbar's lane is still
  reserved on the right whether or not it scrolls, and the same width is now left free on
  the left, 20 px a side (it was 8 left, 20 right).
- **The wash tray's rows are the shelf's plates** (`WashRoom.Tray._draw_row`: `Style.plate`,
  the hover wash, the lit edge) **with the shop's price tag** (`ShopSkin.draw_tag_on` in
  `WashRoom.price_slot`, "Free" on it too); a row the purse cannot cover is greyed the
  shop's way, plate and tag. The whole row still picks: putting a find on the stand is not
  paying, the soap is taken when it comes clean. Supersedes the flat `draw_rect` rows.

### What Is Drawn Is What Clicks (2026-09-25, `/grill-me` with Richard)
The shop and the settings board answer only on their drawn controls, not on a whole plate.
- **Shop**: only a row's price tag buys (`ShopSkin._tag_boxes`, the same `_tag_of` sum the
  tag is drawn on; `_row_under` asks it). Name, value and plate are for reading; a maxed row
  has no tag and answers nothing. Hover wash and `ui_hover` follow the tag; the row still
  lights while its tag is hovered. The rail's "?" is unchanged. A click on a board's dead
  part is eaten; only off the boards closes.
- **Settings**: a sound row toggles on its switch alone (`SettingsSkin.switch_box_of`) and
  drags on its groove and thumb plus `GROOVE_SLACK` (4) (`slider_box_of`); a drag under way
  still follows anywhere. A chooser's value is a target only on Resolution (it opens the
  list); the arrows as before. Hover follows the same boxes.
- **The control lights and swells, the plate does not** (same day, Richard): no row plate on
  either board takes the hover wash any more. Under the pointer the thing itself washes by
  `Style.HOVER_WASH` and grows 2 px a side (`ShopSkin.TAG_SWELL`, `SettingsSkin.SWELL`): the
  price tag, the switch, the slider's thumb (while dragged too), a chooser's arrow, and
  Resolution's value, which gets a lit plate only while hovered. Hit boxes do not swell.
- **Out of scope, by decision**: the bind board, `MenuConfirm`, HUD buttons, the shelf,
  new art, layout moves. `GROOVE_SLACK` is a first guess.
- `test_lake` guards a tag buying and a name not (`_stage_shop_shape`), and the switch, the
  slider's box, the label being dead and no value box but Resolution's (settings shape).

### Every Word Is a Key (issue #28, 2026-09-20, `/grill-me` with Richard)
The localization pass. **Scope this pass: the pipeline and English only** — extraction, one
table, the CSV, a pseudo-locale and a Language row. The eight real languages, the CJK font
and the letter's re-shot stills are later passes.
- **`translations.csv` in the repo is the source of truth.** Committed, one row a key, one
  column a locale. The artifact page is a viewer and editor over it with **no server state**:
  a reviewer's in-progress edits survive a refresh in their own browser and **Export** hands
  them a CSV to send back. Nothing the page holds is authoritative.
- **Call sites read `Text.KEY`**, one generated table, rather than `tr()` scattered over
  thirty scripts — the codebase's "one place decides" habit, and what makes the width probe
  possible at all. The backing store is still Godot's `TranslationServer`, so locale
  fallback and the `.translation` import stay the engine's job. `dropoff.gd:210`'s `tr()`,
  the game's one existing call, folds into it.
- **Every key carries a max-width budget**, measured in Bungee at its real drawn size.
  Over budget is a flag on the page, and **where no sane translation fits, the board may be
  widened** — layouts settled over three UI passes are open to re-tuning for this.
- **Back-translation is the offensive-language guard**, by decision: every non-EN cell
  carries a machine back-translation to EN beside it and drift is flagged for a human. No
  blocklist. Nothing is judged by a machine alone.
- **Deleted 2026-10-03 (The Pre-Release Cleanup).** The `qps` pseudo-locale. **The pseudo-locale is the success test**: a generated `qps` that wraps every string and
  runs ~40% longer, reachable from the Language row, so a missed literal and an overflow
  both show themselves in play before a real translation exists.
- **Out, by decision**: the credits' pack-attribution strings (verbatim by licence — the
  headings over them are keyed), the nine letter stills, the Steam page, every tuner and
  probe, and the siege (`siege.gd`, `defeat.gd`, `charm.gd`, `hud_skin.gd`'s wave block —
  about 20 strings, its own pass if it is ever revived).
- **Not a string, by decision**: `ARROW`, and figures wearing marks (`%d%%`, `$%d`, `%ds`).
  `%`, `$` and `s` are marks rather than words, which is the shop's own settled rule. And
  **the gamepad button names** (`A`, `LB`, `D-Pad Up`, `Left click`): Xbox's own printed
  legends, not translated on the hardware either (since 2026-10-06 a pad button is drawn as
  its glyph, Xbox or PlayStation: see The PlayStation Pad). Keyboard keys already come from
  `DisplayServer.keyboard_get_label_from_physical` and involve no string at all.
- **The 17 shop blurbs are translated as they stand**, placeholders and all (Richard,
  2026-09-20: he rewrites them in the artifact). Their EN is known to be provisional.
- **The inventory is `docs/ui/strings.md`**: 203 keys, each with its file, its box in design
  pixels and its format placeholders. Read it before adding a key.

**The CSV and its budgets** (2026-09-21, `locale/translations.csv`, 205 keys):
- **One file carries the words and the room they get.** Beside `keys` and each locale
  column: `_where` (the script that draws it), `_size` (the rung it is drawn at), `_least`
  (the smallest it may fall to) and `_width` (its box, design px; 0 is a line that wraps).
  **Godot's CSV importer skips a column whose name starts with `_`** — checked on import: it
  makes `translations.en.translation` and `.qps` and nothing else. The `.translation` files
  are built on import and git-ignored.
- **`tools/probe_text_fit.gd`** (headless `--script`) measures every cell in **its own
  locale's face** and walks it down the ladder the way the boards do — fits, shrinks, OVER —
  and checks every `%d`/`%s` survives. Exits 1 on an OVER or a broken placeholder, except in
  `qps`, which is read, not gated. `tools/last_text_fit.log`. **An English OVER means the
  budget is wrong, not the word.** A `_size` off the ladder (the pier sign's 18) is walked a
  pixel at a time, which is what `Dropoff._draw_sign` does.
- **The budgets are checked against numbers already on record**: English puts *Double cast*
  at 115 and *Bonus yard* at 108 against a row's 87, as The Shop Reads measured. English is
  OVER nowhere and shrinks in six places — the five accepted shop rows and *PLASTIC* by a
  pixel on its 82 px plank. Two first guesses were caught by that run: the controls hint is
  drawn at 11, and the sign steps a pixel at a time.
- **`tools/build_translations.py`** does two mechanical things and nothing else: the
  `DECOR_*` rows follow `pieces.json` (added, renamed; **a vanished one is reported, never
  deleted** — a renamed slug looks exactly like a deleted one), and `qps` is rebuilt from
  `en` — brackets, accented vowels, 40% longer, **Latin-1 only**, because system fallback is
  off and any glyph Bungee lacks would read as tofu. **Run it after touching `en` or a
  find's title.** At +40% 24 boxes are OVER: the map of where boards will want widening
  (worst: the controls hint +120, the start-over line +69, *set by Window* +39).
- `docs/ui/strings.md` is the record of how the table was drawn up; the CSV is what is true.

**The faces** (Richard, 2026-09-20; `Style.FALLBACK_*`, `tools/shot_fonts.gd`):
- **Bungee draws every Latin language and nothing else.** 1082 codepoints, measured off its
  own cmap: all of EN, PT-BR, ES, DE and FR including every accent, the arrow and the
  middot — and **no kana, no Han, no Hangul, no Cyrillic at all**.
- **Three stand-ins, picked per locale, not per glyph** (`Style.FALLBACKS`): M PLUS Rounded
  1c for `ja`, Noto Sans SC for `zh`, Noto Sans KR for `ko`, all OFL, in `assets/fonts/`.
  M PLUS Rounded 1c was Richard's pick and covers Japanese and Latin, but **not Chinese or
  Korean** — its Google Fonts subsets are `cyrillic, greek, hebrew, japanese, latin,
  vietnamese`, and measured it misses a third of a simplified-Chinese sample and every
  Hangul. Per locale rather than one chain **because the first face holding a Han character
  would answer for all three CJK languages**, and Chinese drawn in a Japanese font is the
  wrong shapes rather than missing ones — which is worse, because nothing looks broken.
- **Latin keeps Bungee, and the mixed look is accepted** (Richard, over one face for all
  eight): the boards were laid out against Bungee over three UI passes, and a Japanese
  player seeing a rounded gothic is what localized games do.
- **The game ships its own glyphs or it shows none** (`Style._no_system`).
  `FontFile.allow_system_fallback` is **on by default**, so a missing glyph is quietly drawn
  out of whatever the machine has installed — on this Windows box Japanese, Chinese and
  Korean all rendered correctly **out of Bungee alone, with no chain wired up**, and would
  have shipped as tofu to anyone without a CJK system face. It is off now, so a glyph the
  game does not carry draws as .notdef, which a probe can see. **Turning it off is what made
  the font work testable at all**; don't turn it back on to make a screenshot look right.
- **The weight is a synthetic embolden, not the `wght` axis** (`FALLBACK_EMBOLDEN`). Both
  Noto files carry the axis — `{2003265652: (100, 900, 100)}` — and **open at Thin**, but a
  `FontVariation` with `variation_opentype` set draws identically at 100 and at 900 whether
  the key is a String, a StringName or the integer tag: four identical hairline rungs on the
  ladder page, checked by **counting ink in the saved picture**, not by eye — an advance
  width cannot show it, because an ideograph is the same width at every weight. Google Fonts
  ships no static Noto SC/KR instance to use instead (404). So the axis is set anyway in
  case a later Godot honours it, and `variation_embolden` is what actually lands.
  **Per face, because they do not start in the same place**: 0.22 for M PLUS (a static
  Regular), 0.55 for the two Notos (Thin). One number made Japanese heavy while Chinese was
  still a hairline.
- **`ShopSkin.titles` and `ShopSkin.headings` are the lake's to set** now, beside `rows`.
  `TITLES` and the headings inside `GROUPS` are the English defaults and the layout's
  reading order, not the strings a player sees.
- **Probe**: `tools/shot_fonts.tscn` (desktop build, `--fixed-fps 60`, own save, under its
  own node) saves `tools/last_font_<locale>.png` — the **real** net board with that locale's
  words in it — plus `last_fonts_type_a/b.png` (all eight as type at the real ladder sizes)
  and `last_fonts_weights.png` (the embolden ladder), and `last_fonts.log`. Words come from
  `tools/font_samples.gd` and are **samples, not the translation**.
  - **The board is shown by hand, not through `_set_menu`**: with the menu open the lake
    writes `_shop_skin.rows = _shop_rows()` every frame and overwrote the sample words
    between pushing them and photographing them.
  - **A `draw_string` does not rasterise inside `_draw`.** Dropping the font cache at the end
    of `_draw` freed the chains before the frame was drawn and the whole page came out as
    tofu — twice — which looks exactly like the fallback not being wired up. The probe holds
    every face it drew with until the page has been photographed.
  - German is the Latin worst case and is in the pictures for it: *Reichweite* is 109 px
    against a row's 87 and falls to `TEXT_SMALL` rather than cutting.

**Deleted on the sweep, same day** (Richard: "delete dead strings"). Four surfaces wrote
text no player could reach — **34 strings that would otherwise have been translated eight
times and reviewed by native speakers**:
- **The stock shop panel**: the whole `HUD/Shop` subtree of `scenes/main.tscn` (16 labels and
  buttons) and the block of `Lake._update_hud` that formatted 10 more into it **every frame
  the board was open**. `lake.gd` said so itself — "which no player sees (the drawn board
  replaces it)". `ShopSkin` is the shop and now the only one.
  - **`auto_ferry` was real state on a dead control**: a `CheckButton` nobody could see,
    saved and loaded. It is `Lake._auto_ferry_on`, a plain bool, under the same save key —
    **no `SAVE_VERSION` bump**. `_set_auto_ferry` stays; `test_lake` and `probe_rates` call it.
  - **`_send_ferry` and `_any_boat_docked` went with it** — see the ferry's full-hold rule.
- **`Lake._fleet_line`** — no caller at all. `Boat.status_line`, its only other reader, stays
  as a **test diagnostic** and is marked as such in its own docstring: English, not a key.
- **`Lake._note_save`** — six strings written to `_save_note`, its timer ticked every frame,
  the string never drawn.
- **`Lake._polish_panel_controls`**, found by the cut: with the shop panel gone it pointed
  only at `HUD/Shed/Pad/Lines/Title`/`Note`, **which are not in the scene** — so it had
  already been styling nothing. `scripts/wood_ui.gd` was deleted on 2026-10-03; it was left on
  disk pending Richard's call.

`test_lake` asks that `HUD/Shop` is **gone rather than hidden**, which is the check a
deleted-because-invisible node needs.

### The Language Flag (2026-09-26, `/grill-me` with Richard, issue #28)
The pipeline is live and eight languages ship. **Supersedes "a Language row" and "the
pipeline and English only"** in Every Word Is a Key above.
- **A flag in the main menu's top right corner** (`MainMenu._flag`, a `PlankButton` with
  `mark = &"flag"`, `FLAG_BUTTON` 72x56, `FLAG_INSET` 24) opens `LanguageBoard`
  (`scripts/language_board.gd`): two columns of plates, a flag and the language's name **in
  itself, in its own face** (`Style` switched per plate). A pick applies at once and closes
  the board. **Not in settings, by decision**: the menu's corner is the only way in.
- **Flags are DaFluffyPotato's 15x10** (`marketing/flags_15x10/`, copied to
  `assets/ui/flags/`, credited on the board and in `docs/CREDITS.md`): EN `us`, PT-BR `br`, ES
  `es`, DE `de`, FR `fr`, JA `jp`, ZH `cn`, KO `kr`. `qps` wears `unknown` and is offered in
  **debug builds only** (`Prefs.languages()`).
- **`Prefs` owns the language** (`LANGUAGES`, `language`, `set_language`, saved as
  `language` in `settings.cfg`). Empty until chosen: the first launch takes the OS locale if
  it is one of the eight (whole locale, then its language), otherwise English. Translations
  are loaded by `Prefs._load_translations`, **not listed in `project.godot`**, which the open
  editor re-saves from memory. A change redraws every canvas item once (`_redraw_all`) and
  emits `language_changed`, which boards with cached layouts listen to.
- **Every call site reads `Text.KEY`** (`scripts/text.gd`, **generated** by
  `tools/build_translations.py` — never edit it), or `Text.of("KEY")` for a key built at run
  time (`MATERIAL_*`, `DECOR_*`, `TRACK_*`, `BLURB_*`, `VERB_*`). Strings that were consts
  are static getters now, so a switch shows on the next draw.
- **The translations are machine drafts** in `locale/translations.csv`, each with a
  `_back_<locale>` back-translation beside it for review (the importer skips `_` columns).
  Not reviewed by a native speaker. Known picks to review: Spanish is neutral ("tomar", not
  "coger"); FR `MATERIAL_RUBBER` is "Caoutch." to fit the sign.
- **No real locale is OVER anywhere** (2026-09-29, `tools/probe_text_fit.gd`,
  `tools/last_text_fit.log`): the Latin OVERs were **reworded, no box widened** — PT `Nív. `
  and ES `Niv. ` for the tier prefix, ES `Caseta` and DE `Hütte` for the record player's
  Shed column (`RECORD_SHED`, new since the list was written), DE `Auslassen` for Skip and
  `Feld klicken, Taste · Rechtsklick: Standard` for the bind hint, FR `Chance`, `Lancer x2`
  and `Gratis`. `CONTROLS_HINT_PAD` had no translations at all and has drafts now. Machine
  drafts with their `_back_` columns, still unreviewed; FR `Chance` in particular is a
  shorter, vaguer name than "Lucky cast". Only `qps` is OVER, which is read, not gated.
- **A harness never goes through `Prefs.set_language`**: it writes `settings.cfg`. `test_lake`
  sets `TranslationServer`/`Style` to English by hand (the machine's locale may be any of
  the eight). `_check_language` guards the flag, its corner, eight languages each with words
  and a flag, a plate each, and a switch changing the words.
- Probe: `tools/shot_language.tscn` (desktop build) saves `tools/last_language_{main,board,
  <locale>}.png`, applying each language by hand and putting the player's back.
- **Out of scope, by decision**: the letter stills (still English), the siege, the credits'
  pack lines, the Steam page, widening boards.

### Portuguese Is the Source (2026-09-29, Richard)
Richard rewrote 85 strings in Portuguese in an artifact (see memory `lake-pt-rewrite-artifact`);
`tools/pt_source_pass.py` merged them and retranslated en and the six others from his meaning.
- **pt_BR is the source text now**; en follows it. Machine drafts still unreviewed for es/de/fr/ja/zh/ko.
- **Player-facing words changed**: the shed is **the house** (casa) in every visible string (code
  names stay `shed`), yards are **piers**, the ferry is **the boats**. Shop names: Speed, Loading,
  Capacity, Carry, Luck, Size, $ Bonus, Reel; groups Progress / Number of boats / Helping / At the
  piers. PT has "Carrega" on both Capacity (boats) and Carry (dogs): the uniqueness guard reads English.
- **Shorter find titles** (Rug, Table, Bookcase, Chair, Mirror, Small table, Clock, Painting, Lamp,
  Pet toy), set in `decor_sets.json` and `pieces.json`, since `build_translations.py` makes DECOR_*
  follow them. Two rugs and two bookcases now share a name, by decision.
- **The letter's name line reads "Dirty Little Lake."** (no "My"), this line only; the game's title is unchanged.
- **Code**: the menu's Quit is "Save and quit" and saves before closing (`MainMenu.quit_asked`,
  `Lake._save_and_quit`); the settings board's never-shown wipe row is deleted (F6 stays);
  the wash tray no longer writes "soap" (only "Washing" while on the stand); the room card names
  the key (`TOUR_DECOR_ROOM` takes `%s`, `Binds.shown(&"shed_switch", pad)`); the console spike
  (`console_shelf.gd`, `console_spike`) and `CONSOLE_COUNT` are deleted.
- The letter stills still show the old English UI; re-shoot with `shot_letter_art` when wanted.
- **The pack finds' names are in every language** (2026-10-04, Richard reviewed the PT): the
  60 `DECOR_PK_*` rows had English only, so they showed in English whatever was set. PT is
  his, the other six are machine drafts from it. Repeats by decision (Old Seat and Armchair
  are both "Poltrona", Small Rug is "Tapete"). Oval Rug became **Small Rug** and Car Picture
  **Poster** in English too (`build_pack_decor.py`, `pieces.json`). `test_lake` fails on any
  `DECOR_*` row missing a language. Needs fontTools: the base Python313, not `.local`.
- **The shop's blurb draws over the hung purse** (`ShopSkin._blurb_layer`, z 1): the Reel
  row's ran under it, the purse being a later sibling of the shop.

### The Save Is Written Safely (2026-09-29, issue #25)
- **Temp, then rename** (`Lake.save_game`, `_swap_in_save`): the run is written to
  `<save>.tmp`, checked for a write error, and only then moved over the save; the save it
  replaces is kept as `<save>.bak` (`SAVE_TEMP`, `SAVE_BACKUP`). Remove-then-rename, because
  Windows will not rename over a file: a crash between the two leaves no save and a good
  backup.
- **The load falls back** (`load_game`, `_read_save`): a save that is missing, empty or will
  not parse is read from the `.bak`. A save that parses but is refused (another
  `SAVE_VERSION`, another seed) does **not** fall back — the backup is the same run one
  write earlier and would be refused too. `has_save` counts a backup alone.
- **New game and F6 remove all three files** (`_remove_save_files`), or a wiped run would
  come back from its backup.
- **A save held open by another reader cannot be swapped on Windows**: `save_game` returns
  false and leaves the `.tmp`, which the next save overwrites. `test_lake` had exactly that
  bug (a `FileAccess` left open in `_stage_save`); a tool that reads a save must close it.
- No `SAVE_VERSION` bump. `test_lake`'s `_check_save_hardening` (end of `_stage_save`, on
  the harness's own path) guards the backup, no temp left, a corrupt save and a missing one
  both loading the backup's run, and no save with neither file.

### The Siege Deleted (2026-09-29, issue #38)
The second level is gone, not shelved: `siege.gd`/`.tscn`, `defeat.gd`, `ward.gd`,
`charm.gd` (`CharmField`), `charm_box.gd`, `sludge.gd`, `volley.gd`, `laid_net.gd`,
`test_siege`, the HUD's wave block, the settings board's level-swap row, `Lake._next_scene`/
`_go_onward`/`_swap_levels`/`_other_level_*`, the farewell's onward door and its two strings
(`END_ONWARD`, `END_ONWARD_HINT`), the net's charm sweep and `caught_charm`, and the siege's
built chime in `Sfx` (`play_chime`, `_fire`, `_make_chime`). `check_real_save` lost its
`-- siege` mode.
- **The lit net laid by LT is deleted too** (2026-09-29, Richard's call): `lay_net` (the
  bind, its `project.godot` entry, `VERB_LAY_NET`), `CastNet.enchant`/`enchanted`/
  `charm_left`/`Charm`/`_leave_it_there`/`left_behind`/`field_radius`, the laid-net ghost
  (`_draw_lay_ghost`), the pad's LT, and `Sfx.play_net_splash` with its one ladder. Nothing
  on the lake ever called `enchant`, so LT did nothing. An old `settings.cfg` line for
  `lay_net` is dropped by `Binds.load_from`.

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
- **The words and the roll are once per save** (2026-09-19, Richard: "after player has
  already ended the game, a continue should not trigger the end credits or message again").
  `_on_lake_cleaned` gates `_show_farewell` on the saved `farewell` flag; everything else it
  does — the lit water, the meter on the floor, the write — happens every time a finished
  lake is worked out, because those are facts about the field. A continue into a finished
  lake is the clean water and the HUD, nothing written over it, playlist not Habibs (which
  is still on the menu's Credits board). **Supersedes "a finished lake offers its ending
  whenever it is opened — once per sitting"** (2026-09-12): that existed because the door on
  to the siege lived on that screen, and `_next_scene()` has returned "" since the same day,
  so the farewell's only door is the menu's — which the settings board offers on any run.
  **An ending that was owed is still paid**: a save with an empty field and a false flag (the
  last piece in a net's hold at the write, or a crash before the words) gets its ending on
  the way back in. No `SAVE_VERSION` bump — the `farewell` key already means this.
  `test_lake`'s `_stage_ending_on_load` walks both: owed, then thanked.
- **Straight to the words and the end song** (2026-09-18, Richard: "no need for the end game
  bell, lets run straight to the message and credit song"). `_on_lake_cleaned` raises the
  farewell on the spot, and `Lake.ending()` is simply "the words are up", which is what
  `MusicStation.set_ending` is told. **Retired**: the two seconds of shimmer in front of the
  words (`Lake.ENDING_BEAT`, `_ending_in`, `_count_the_beat`, 2026-09-16) and the struck
  note that opened them (`Sfx.play_found`, `_make_found`, `FOUND_DB`). The breath is the
  words' own `FADE_IN`, with the lake lighting up under it. The angler is held from the
  same frame.
- **The message stands in the middle of the window** (`Farewell.BLOCK_AT` 0.5, 2026-09-16):
  it used to sit at 0.60, a little low, because the middle is where the island is. With the
  credits climbing under it the low block left the roll a short screen to cross and a long
  one to wait in. One number, read by the words and by the band the roll dims in.
- **The words take `FADE_IN` 3.6 s to arrive**, two seconds longer than they did (Richard:
  the shimmer can last two seconds longer as the message fades in). The lake is live and
  lighting up the whole time and the wash eases in with the words, so a slower fade *is*
  more clean water before the ending is written over it — and since the beat in front was
  cut it is the only such stretch there is. **The roll waits for the words**
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
- `test_lake` guards that the words are up the moment the run ends, that the song is told,
  that no beat and no bell are left, the crate rule (a piece in the net keeps the run
  going), the roll and the words.
  **Headless has no renderer**, so `tools/shot_ending.tscn` (desktop build, `--fixed-fps 60`)
  is what exercises the drawing: the words beginning (the shot still called `beat`), the
  words arrived, the first credits crossing the
  message, the roll well up, and what is left after a skip —
  `tools/last_ending_{beat,words,behind,roll,skipped}.png` and `last_ending.log`. It runs on
  **a save of its own**, because finishing a lake saves it on the spot and a probe may not
  hand the player back an emptied run. **And under its own node, not the root**
  (2026-09-18): hung off the root it was the game's own lake, wore the front, and from
  2026-09-17 photographed the menu five times with no ending behind it. Its log said
  `words up: false` and nobody read it. **Read a probe's log, not only its exit code.**

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

- **Deleted 2026-10-03 (The Pre-Release Cleanup).** The tuner and `shot_buttons`; `BAKED` stays. **Where each picture on a button stands is tunable by hand** (`HudButtons.BAKED`/`tune`/
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
  **Retired**: `assets/buttons.png`/`.json` and `tools/slice_buttons.gd`; `assets/ui.png`/
  `ui.json`, `UI_Buttons.jpg`, `tools/slice_ui.gd` and `tools/slice_shed.gd` are deleted
  (2026-10-03: AI placeholders nothing drew). The shed icon does not track the collection, by decision.

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
- **The hut wears a one-pixel outline, roof and all** (2026-09-24, `/grill-me` with Richard: the
  hut and the rubbish read as lower detail than the crate and the angler). `recolor_shed.py`
  `OUTLINE` rings the whole silhouette outside it in the box's edge colour, so `shed.png` is
  105x103; `SHED_TALL` 144.2, `SHED_STAND` 0.39375 and `SHED_ART_GROUND` 0.2382 moved by that
  pixel so the walls stand where they did. **Tried and rejected the same day**, off a
  before/after sheet: a rule pass on the rubbish (lit edge, shade edge, per-material texture)
  and Scale2x rubbish at the angler's 1.0 grain � the pieces are already outlined and shaded
  and a pass on 6-20 px sprites adds noise, not detail; and the hut rebuilt at 2.0 (muddier).
  **The real gap is pixels per object** (a can is 6x9, the crate 32x33, the angler 44 tall at
  1.0), which only repainting at a bigger source size would close. The rubbish stays as it is.
- **Then Richard repainted the hut by hand** (same day): `art_source/shed_paint.png` is the
  painted source and `assets/shed.png` a straight copy of it. **`recolor_shed.py` no longer
  writes the asset** unless given `--overwrite-painted` (or `--out` for a trial); its
  functions are still imported by the pier, nozzle and downres builders.
- **The hut's and the box's outer outline is near-black** (24,18,17), same day (Richard: the
  brown read as no outline): every silhouette pixel of `shed_paint.png`/`shed.png` and
  `Recycle_Box.png` that was (48,37,33) or the rim's (76,29,29). Done on the assets;
  `tools/trim_box_sides.py` would put the box's brown sides back if re-run. The piers' boxes
  were re-baked with it (`build_piers.py` reads the box's edge colour for the pier's whole
  silhouette, so the jetties' outline went near-black too). **The island crate draws at
  2.0** (`Yard.ART_SCALE`, was 2.5), so its outline is one art pixel like everyone else's;
  the crate is 20% smaller and its footprint follows.
- **The rubbish wears the angler's black outline** (same day): `build_lake_objects.py`
  `ink_outline` turns every silhouette pixel darker than `OUTLINE_UNDER` (110 luma) pure black;
  lit edge pixels keep their colour, so a pale piece (the bottle, the sheet) has a broken line
  where it was painted with a highlight. The rebuild rewrote `pieces.json` in another order
  with identical content; the committed file was kept.
- Both need the art: a hem is measured off an `Image`, so the blocked-in fallbacks (no sheet)
  grow nothing. **Shed and box only**, this pass. The four dropoff piers have the same hard
  bottom edge on the bank and are the obvious next ones.

### The Hut Redrawn (2026-10-01, `/grill-me` with Richard)
The hut is redrawn at the angler's grain, one world px an art px, and grows with the run.
**Supersedes** `assets/shed.png` (Richard's repaint, `art_source/shed_paint.png`, kept as the
old source) and the 1.4 grain notes above for what the lake draws.
- **Same silhouette, by decision**: `tools/build_shed_v2.py` lays the old hut's corners times
  1.4, so each picture is 147x144 and the footprint, door, note, hem, sweep and walking rule
  stay. `Iso.SHED_TALL` 144, `SHED_ART_GROUND` 0.23853 (the same 34.35 world px), `SHED_STAND`
  unchanged. Rule-built, then picked off `tools/last_shed_mockup.png` over five passes:
  oak-moss palette, lap siding on every wall (the "small planks"), fascia, frieze and barge as
  planks of the same wood, corner boards, sage shutters with a heart cut out.
- **Three stages by the meter** (`Lake.SHED_ARTS`, `SHED_STAGE_AT` 0.5 / 0.9 cleaned,
  `shed_stage_for`, `_restage_shed`): picked off `pollution` each draw, nothing saved, no
  `SAVE_VERSION` bump. A change rebuilds the hem (`_shed_skirt`), re-sweeps the shadow
  (`Shade.Cast.forget`) and hands the decorate button the new hut.
  - **Neglected**: broken roof (holes onto the rafters, cracked shingles, gaps in the ridge
    cap), heavy moss, cracked and knotted boards, missing board pieces, a cobweb under the
    eave, one shutter sagging and the other dangling from one strap, a dim cracked window,
    weeds, dock, dead ivy, mushrooms.
  - **Tidied**: the holes filled with fresh tan shingles and boards, a third of the cracks
    left, young ivy, pots, a watering can, shrubs, a young rose, daisies.
  - **Cosy**: clean, no moss on the roof, the repairs weathered in; roses over the door,
    hollyhocks, a flower box, a birdhouse, a lantern, ivy climbing onto the roof and vines
    falling off the eave with pink blooms and wisteria.
  - Damage is seeded once, so the boards and shingles broken in stage 1 are the ones mended
    in stage 2. **Plants, not fishing gear**, by Richard's call.
- **The window glows** (`shed_glow.png`, `SHED_GLOW_*`): the glass's pixels drawn over the hut
  in a warm white, stronger late in the afternoon (`DayCycle.sun`) and under a storm
  (`overcast`), half on the neglected hut.
- **The hut gets wet** (`SHED_WET`): tinted darker and cooler by `Puddles.sand_wet`, the
  sand's own soak and dry.
- **Pipeline**: `--write` overwrites `art_source/shed_v2_<stage>.png` and the glow mask (for
  Richard to polish by hand), `--ship` copies them to `assets/shed_*.png`; reimport after.
  Base python with the psd-extract venv's site-packages on `PYTHONPATH`.
- **Contrast and volume** (2026-10-02, Richard: beside the 1x recycle box the hut read washed
  out, "lines and details less visible, less volume"): siding boards `Hut.ROW` 7 rows (was
  5) and `SEG` 32 long (was 16), each seam a dark row with a shadow row under it and a lit
  top edge, board tone wandering `TONE` 0.28 (was 0.45), the shaded front at `FRONT` 2.8 and
  the sunlit gable at `GABLE` 4.4 (were 3.3 and 4), less grime. Roof shingles 6x9 (were
  5x6), moss in fewer, larger patches, a rounder ridge cap (lit crown, body, underside,
  shadow), a **verge board down the roof's left end**, and the far slope past the gable's
  right rake drawn as a verge (lit lip, course joints, dark underside) over a **rake board**
  on the gable, where it was a flat two-tone strip that read cut. Shipped over all three
  stages (`--write --ship`); no hand polish was lost, the art_source pictures matched.
- **The recycle box is the hut's carpentry** (same day, Richard: "same wood treatment and
  construction, so it perfectly matches"): `build_recycle_box.hut_wall` lays the hut's own
  siding rules and corner boards on the box's faces, in the hut's `WALL` ramp, the left face
  as the hut's front and the right as its gable. The pier decks keep the brown ramp.
- **Credit, open**: the old hut was cut from Zato's CC BY pack; the new one copies none of its
  pixels, only its outline's corners. `docs/CREDITS.md` still credits it until Richard decides.
- Out of scope, by decision: animation (smoke, flicker), a new footprint, the shed's interior,
  porch items that echo placed finds, the trailer.

### One Sun (2026-10-02, `/grill-me` with Richard)
Every shadow in the game follows one light model. **Supersedes every per-caster shadow gain,
cap, colour and drop below** (the hull's 2.7/0.63, the piers' 3.0/0.7, the pigeons' and the
ducks' 2.4/0.45, the tornado's 1.1/0.36, the wash room's 1.6 and 1.5, `LakeGrid.SHADOW_ALPHA`
0.15, `DRY_SHADE`, `Fish.SHADOW_INK` and `SHADOW_NEAR`/`FAR`, the shed's black ellipses, the
hive steps' green-grey, the haul's round black disc).
- **One ink, one gain per surface** (`Shade.On` LAND / WATER / BED, `Shade.GAIN` 1.0 / 2.7 /
  1.4, `Shade.MOST` 1.0 / 0.63 / 0.42, `ink_on`, `tint_on`): `Shade.INK` at the day's ink, which
  already carries the overcast and the flash, so every shadow thins in rain. Water is the
  hull's old pair; the bed's numbers are first guesses. **No caster keeps an ink of its own**:
  `test_lake` fails on any `SHADE_GAIN`, `SHADE_MOST`, `SHADOW_INK`, `SHADOW_COLOUR`,
  `SHADOW_ALPHA`, `DOG_SHADE_GAIN` or `DRY_SHADE` const in `scripts/`.
- **Everything falls down and left along the day** (`Shade.drop(day, height)`, the offset
  `lying` gives a pixel that high). Air casters put their shadow at the ground point plus the
  drop of their height (pigeons, ducks, dragonflies, the haul, tornado debris, the net in
  flight); things under the water put theirs at the drop of their depth (fish, frogs, turtles,
  ducks' bed shadows, crayfish, lily pads), so a bed shadow lengthens late in the day.
  `DayCycle.here` is the day for a caster nobody handed one (`Shade.sun_of`).
- **A shadow draws on the layer of what it falls on**: the water's shadow layer is absolute
  z 4 (under the floating soup at 5 and every walker). Pigeons' shadows came off the bird layer
  (21), dragonflies' off the air layer, the haul's and the hull's off z 10; the haul's are their
  own batch (`Haul.SHADOW_LAYER`, 2:1 ellipses, `CIRCLE_SEGMENTS` 16). The angler's and the
  dogs' still draw at their own walker z, under their sprites.
- **The rubbish's crescent leans and stretches** (`shadow.gdshader` `sun_lean`/`sun_stretch`,
  `LakeGrid.SHADOW_SUN_SHARE` 0.25): slid by `Shade.drop` of a quarter of the piece's height
  above its waterline, which rides in each corner's alpha under the top/bottom bit
  (`ShadowLayer.write`, `SHADOW_TALLEST` 127). **Centred on the waterline**
  (`SHADOW_DROP` 0.04 of the piece's height under it; second pass, Richard: "closer to its
  body"): half under the drawn piece, half peeking out. It sat a fifth of the picture below
  the piece's middle and a tall piece's shadow came away from it. Water ink afloat, land ink
  on the beach. `LakeGrid.sun(day)` replaces `sun_lean`. **Four times as dark as the old
  0.15**: the first thing to judge in play.
- **What is under the waterline shows through clean water** (`LakeGrid.SUNK_FLAG` 0.7,
  rubbish.gdshader `sunk`; second pass, Richard): every piece with art is two quads now, the
  part above the water and the part the cut takes off, laid under the waterline before it
  (on the sand that room is a blank quad). The soup reads the same `filth_map` the water does
  (pushed by `Lake._build_filth_map`), shows the under-part only where the honest map is
  clean or hazy (the floor under a piece makes its own tile hazy), mixed `sunk_mix` 0.5 towards
  `water_clean_mid` (hazy: `water_hazy_mid`, 0.15 more) at `sunk_alpha` 0.9, and discards it
  in grime. **`_stamp_len` counts 8 a piece and 8 a shore pair**; `test_lake` guards it.
  Probe: `tools/shot_sunk.tscn` (desktop build, own save) thins the lake to scattered singles
  and saves `tools/last_sunk.png` and `last_sunk_near.png`.
- **The rope's shadow leaves the hands of the body's** (`Angler.shadow_point`, second pass,
  Richard: a gap east and west): its near end is where the drawn hands land in the angler's
  own laid-down frame (drawn `LAND_SINK` low, folded about the feet), the difference eased out
  along the chain so the far end still meets the net's. Probe: `tools/shot_rope.tscn`.
- **New shadows**: perched pigeons; ducklings in flight; frogs sitting and hopping (water ink on
  a pad); turtles on land and swimming; a short surface shadow under floating ducks and
  turtles; swimming dogs, cut at the waterline like the wading angler; every land plant,
  shrub, reed and cattail (baked into the flora batch, ink by uniform, swaying and growing in
  with its plant); the island tufts' shadows sway now too; the net (its rim, one faint fan,
  `CastNet.ShadowLayer`, `SHADOW_FADE` 0.35) and its rope (one strip, tapering from the hand's
  height to the water); the placeholder hull (a blot).
- **The props' ink follows the weather without a rebake**: `flora_sway.gdshader` takes
  `land_ink`/`water_ink`/`bed_ink` and reads a shadow vertex by its alpha (0.25 / 0.5 / 0.75,
  `Flora.SHADE_*`); geometry still rebakes on `Ground.SUN_STEP`. Both ground layers use the sway
  material, with trees and rocks packed still.
- **The shed's light is its window, a point** (`ShedRoom._window_at`, `_room_away(feet)`,
  `_room_reach(feet)`, `_room_light(feet)`, `_room_ink`; second pass, Richard: "objects closer
  to the light source should have a darker shadow, and there should be a stretch"): every
  shadow falls straight away from the round window, up the room for a caster above it and down
  for one below (third pass, `_lay` lets the stretch go negative), and is
  as long as its caster is tall `WINDOW_HIGH` (16) cells out, longer further away, times the
  hour (`HOUR_REACH` 0.9..1.1), held to `REACH_LEAST`..`REACH_MOST` (0.12..0.42 of the caster's
  height; fourth pass, Richard: "keep it more grounded and close to the object base"). **The window is tiny** (Richard: "a
  cone of light coming from the center, not like the entire wall is the window"): the shaft
  leaves it `SHAFT_WIDE` 0.6 cells wide and opens at `SHAFT_SPREAD` 0.36 (were 2.4 and 0.78).
  **It stands half way down the floor's left edge and points straight across** (`_window_at`,
  `CONE_AXIS`; third pass, Richard: "the cone comes from center wall and from up"): the old
  `WINDOW_DOWN` and the hour's slope (`SUN_SLOPE`) are retired.
  The shadow group draws through `SHADE_FALL_CODE`: darker by the window (`NEAR_DARK` 1.3 to
  `FAR_DARK` 0.45 over `DARK_REACH` 34 cells) and **only inside the cone**, the shaft's own
  Gaussian, down to `OUTSIDE_DARK` 0.18 out of it, in `DARK_STEPS` hard steps. Walkers lay their own frames
  (`_paint_walker_shades`, a white-silhouette shader); every standing floor piece sweeps one
  shadow into a single `Shade.Face` (wall, flat and hosted pieces cast nothing), rebuilt only on
  a layout change or a light step. The floor and the shadows are drawn by two children behind
  the room (`_paint_room`, `_build_shade_layers`). A sitter or a dog on its seat casts nothing
  on the floor.
- **The wash and hive rooms use the outdoor sun, land ink**: the pallet sweeps its own picture
  (`PIECE_SHADE` 0.35 kept, so the find's shadow stays on the deck); the hive steps' contact
  ellipses take the shared ink, nudged by `Shade.drop(null, CONTACT_RISE)`, and are **not**
  2:1, by decision of the pass: those steps are seen from eye height.
- **Deleted**: `Player._blot`, `Wildlife.FROG_SHADOW`, the switched-off cloud and spout shadows
  in `tornado_water.gdshader`; the tornado's cloud and rag shadows used half the projection
  everything else does and now use `Shade.drop`.
- **Cost** (`bench_frames`, RTX 5060 Ti, 1080p): standing 3.8 ms mean, rain 5.9, cleaned and
  grown 6.4, big lucky double 12.4-12.7 (still over the bar, as before; the net's shadow
  measured within noise, A/B'd). `BENCH_OFF=sway` now stills the motion rather than removing
  the shader, since the plants' shadows need it.
- **`tools/shot_shed.tscn` furnishes with the pack decoration** (`decor_pk_*`), not the old
  PSD finds (Richard: "stop using the old decoration as reference").
- **Out of scope, by decision**: bees, the hive swarm, pier box heaps, coins, splashes, rain;
  shadows in the surface's own ramp colour; the UI cards (trophy, record player); the lakebed's
  baked items. All gains are first guesses for Richard's eye, judged in play.

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
- **Superseded by One Sun (2026-10-02)**: the crescent now leans and stretches by height.
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
- **The run rows come from `art_source/character.png`** (2026-09-28, Richard's repaint of
  the walk): a flat sheet of all twelve rows stacked. `slice_character.gd` reads only the
  run rows from it (`SHEET_BANDS`, each at its old strip's band and width, so no frame
  boundary moves); idle and cast still come from `character_extracted/`. The first three run
  frames are still dropped. The repaint changed only the east run's legs (303 px).
- **The reach to pet** (2026-09-28, `/grill-me` with Richard): E (or A) beside a dog turns
  the angler to it and plays `pet_<dir>`, six frames over `Angler.PET_TIME` (1 s) with the
  boots held; the dog sits and waits (`Dog.await_pet`) and is petted on
  `Angler.pet_touched`, at `PET_TOUCH` (0.34 s, the arm fully out), not on the press.
  **Built by rule** (`tools/build_pet_frames.py`, logo venv python, writes
  `character_extracted/pet_*.png` and `tools/last_pet_frames.png`): the idle frame's upper
  body lowered over the legs and the cast frames' arm (cream sleeve, a rolled cuff a touch
  wider, bare forearm, fist, ringed in black even over the shirt). **It aims at the dog**
  (Richard, same day: head or body, whichever is nearer): every view is built at four arm
  angles (`pet0`..`pet3`, `Angler.PET_SIDE_ANGLES` 0-75 degrees below straight out,
  `PET_FRONT_ANGLES` -40..40 off straight down), and `Angler.pet_arm_for` takes the one
  pointing nearest the nearer of `Dog.pet_spots()` from the shoulder. **Front and back reach
  with the free hand** (screen-right from the front, screen-left from behind; the basket is
  in the other): that idle frame's hanging arm is cleared while the reach is out
  (`FREE_ARMS` in the builder, measured in pixels off the idle frames: re-measure if they are
  repainted), and from behind the arm rises up the screen behind the body and hat
  (`PET_BACK_ANGLES`). For Richard to polish; a re-run
  overwrites the strips. The slicer measures every pet frame against the first's ink
  (`ink_first`), or the body would slide back as the arm went out. **Each dog waits
  `Dog.PET_AGAIN` (10 s) before it can be petted again**, per dog, from the press; a press on
  a waiting dog, a dog in the water, or during a reach does nothing and shows nothing. Not
  saved.
- **Petting in the shed too** (2026-09-28, second pass): the room's E takes a dog or a
  switch, **whichever is nearer the player** (Richard's call); a dog still waiting out its
  ten seconds is no candidate. The same reach frames, aimed by `Angler.arm_toward`, the player
  held, `Dog.hearts_on` over the dog at the touch, a sniff through `Sfx.room_sniff`. The key
  prompt stands over the dog when it is the nearer. Each room dog keeps its own cooldown,
  apart from the lake dog of the same slot, since the room's dogs are rolled each visit.
- **Walkers are drawn by their feet** (same day, Richard: dogs were drawn over the angler):
  inside one walker layer the angler and the pack trade tree slots in feet order
  (`Lake._order_walkers`), the shed's rule; the layer bands are unchanged.
- **E opens the shed only in front of its door** (same day): `_at_shed` is within
  `DOOR_RANGE` (0.6 tiles) of `_before_the_door()`, not `SHOP_RANGE` round the hut, and the
  lamp follows. The Decorate button and the pad's X still open it from anywhere.
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
- **Superseded 2026-10-02** (see The Piers, the Box and the Hold at the Angler's Grain):
  **The hold fills bottom up, like the box it feeds** (`hold_spot`, 2026-09-12): the load
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
  in the box is all there will be.**The hidden "send now" is gone** (2026-09-20, with the stock
  shop panel): it was a `Button` on a panel that was never shown, so nothing in the game
  dispatches a part load any more. `Boat.dispatch()` stays, for the automatic run.
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
  few pixels wide and carries **the mark seen edge-on** (2026-09-19, `/grill-me` with
  Richard, picked off `--mark-mockup`): frame 3's own 14 rows squeezed to the lens's seven
  white pixels, a tall thin ring that cannot be read by itself and makes sense the moment the
  hull turns a heading. **The one exception to "square in every frame"**, and it supersedes
  the small 7x7 round ring up the lens, which read as a second, tiny mark. Seven wide is all
  the white there is and the least that works: at 5 and 6 the bar maps to under a pixel, the
  sides drop out and two blobs are left. Edge kept (`MARK_SIDE_EDGE`; bare was the other row). The stern quarters show the sail's back and stay plain, by
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

### The Throw and the Quiet Landing (2026-09-24, `/grill-me` with Richard)
- **Superseded 2026-10-02** (The Net Drawn by Rule): the throw's frames, the `skip` of the
  coil and the hold on `land` frame 4 went with the etched sheet.
- **An empty landing makes no spray** (`WaterSplash.splash`'s `tall`, `_crown_tall`): when
  the landing sweep takes nothing, the crown is the foam mound and its ring, plus the
  landing's ripple. No plumes, no speck sheet, no drops. The sweep runs before the splash
  so it knows. Both nets. A catching landing is unchanged.
- Out of scope, by decision: `cast_far` frames 2-3, the land settle, the `drag` sheet.

### The Net Drawn by Rule (2026-10-02, `/grill-me` with Richard)
The etched net read washed out: an AI etching off a JPEG, drawn 2-3x smaller than its frames
and point-sampled since nearest became the default, so its hairline mesh broke into faint
dots. It is redrawn as pixel art by rule, picked off `tools/last_net_mockup.png`
(`tools/net_mockup.py`, offline, two passes: look A, then the bend).
- **`NetShape`** (`scripts/net_shape.gd`) is the shape: `rho` 0 at the crown to 1 at the
  rim, `theta` round it, laid out by `at`. **`shaders/net_mesh.gdshader`** draws it: the
  vertex stage runs the same shape (`shape`, **written twice, change both**; `test_lake`
  compares the constants), the fragment stage decides per pixel of the net's own grid
  (snapped through the derivatives, so the grid travels with the gliding net) whether it is
  a strand, the rim cord, a lead bead, the crown's knot, the shade pixel under any of them,
  or nothing.
- **Look A**: a diamond mesh, `CELL` 12 plane px (12 x 6 on screen), cord a pixel wide in a
  lighter brown than the hand line (Richard: "a little bit of a lighter brown"), a lit top
  row on the rim, the far side a step down, one `SHADE` pixel under every strand, lead beads
  every `BEAD_EVERY` px. **The cell is fixed, so a wider net has more cells** (spokes a
  multiple of 32, halving towards the crown with a tuck ring over each seam). A pursing net
  keeps its cells and draws them smaller. Where the cord bunches it thins: a strand family
  closer than `MIN_GAP` px drops every other strand, then every fourth.
- **The haul lays the net out again** (Richard: "the bend should look much more natural and
  distort the net accordingly"): the crown leads towards the rope (`LEAD_OUT`), the rim
  purses into a pear with its tip just ahead of the crown and its back dragging
  (`RIM_BACK`, `TIP_GAP`, `REAR`, `PURSE_ACROSS`, `PINCH`), so the cells stretch along the
  pull; the load sinks and spreads the back (`SAG`, `SPREAD`), the bag swings (`SWAY`) and
  its rim ripples (`CastNet.HAUL_RIPPLE`). Driven by `_lean` (0.45 empty to 1 full).
- **It drags on the water, nothing lifts it** (Richard, same day, on a big net: "looks like
  it's being pulled by a crane from top"): no crown lift, the dome capped at `DOME_MOST`
  (8 px) lying and flattened out by the haul, the landing's dome capped at `LAND_DOME_MOST`,
  and the horn kept low (`HORN_MOST`) and on the water under the haul.
- **The throw is a bundle opening** (`shape_now`, `FLY_*`): it leaves the hand `FLY_FROM`
  of its width, a tall bell (`FLY_DOME`) with a squashed, wobbling rim, and opens to a low
  dome as it flies, rising `FLY_ARC` over its path (`draw_at`). Unbent in the air.
- **And it dangles** (2026-10-02, Richard: "it shouldn't be a straight circle, it should be
  dangly"): `NetShape.flutter`/`trail`/`flap` (and the shader's copy, `TRAIL`, `TUCK`,
  `DANGLE`, `LOBES`): the skirt streams `TRAIL` of the half-width out behind the way it
  flies, tucks `TUCK` in at the front, and hangs below the plane in `LOBES` lobes up to
  `DANGLE` of the half-width, the trailing side lowest, flapping at `CastNet.FLY_FLAP` rad/s.
  The rim's wobble runs on the clock (`FLY_WOB_RATE`) at `FLY_WOBBLE` 0.2 rather than off the
  distance flown; `FLY_OPEN_KEEP` of both is still on at the landing, which settles them out
  (`LAND_WOBBLE` 0.09). The net's shadow, the catch and the horn follow, all being `at`.
  `test_lake` guards the trail, the tuck and the uneven droop.
- **A lucky cast shines, the cord stays tan** (second `/grill-me` the same day, Richard: the
  flat gold cord "looks ugly"; look B picked off `tools/last_net_lucky_mockup.png` and its
  GIFs, `tools/net_lucky_mockup.py`): the rim cord (three px deep, `GOLD_RIM_HALF`) and the
  beads go gold on a ramp off the finds' own (`NetShape.GOLD_DEEP`..`GOLD_PALE`), and the
  gold creeps in from the rim over `FADE_CELLS` (2.2) cells. **On the splash** two heads of
  light run round the rim both ways from the front (`BURST_RUN`, `BURST_TAIL`,
  `BURST_FADE`), lighting the beads and the outer cells, while the finds' four-point stars
  pop round it and sparks fly off (`CastNet.LuckStars`, `LUCK_BURST_STARS`, `LUCK_SPARKS`).
  **Then** a glint `GLINT_WIDE` of the net sweeps it diagonally `LUCK_GLINT_FROM` after the
  splash and every `LUCK_GLINT_EVERY` (1.5 s), lifting the cord to pale gold and white, with
  `LUCK_TWINKLES` stars twinkling on the cord, until the net is home (`_lucky_age`). In
  flight only the gold rim and beads. The burst and glint numbers are written again in the
  shader; `test_lake` compares them. Boosted once in the game over the mockup (rim three
  deep, the creep, the glint to white, eight twinkles): judged at 3x it was faint at play
  zoom. `NET_FILM=1` on `tools/shot_net.tscn` films a lucky haul into
  `tools/film/net_lucky/` (`tools/last_net_lucky_game.gif` is built from it). All numbers
  first guesses.
- **Draw order**: this node draws the catch; its first child `NetMesh` (the shader) the net
  over it; then the rope and the stars; the aim ring is on the last child (`AimLayer`), so
  nothing hides it.
- **One net everywhere**: the shop's NET card draws the lake's own net itself
  (`ShopCard._lay_net`, a `CastNet.NetMesh` child, same shader), at the lake's grain, one
  card px a net px, `NET_FILL` (0.94) of the card's width; the card being 3.5 times wider
  than tall, the net is seen from lower down, its height squashed to what the card leaves
  (`NetShape.squash`, never under `NET_SQUASH_LEAST`), wandering `NET_SWAY` whole px as one
  picture. **Its shape never moves**: a rim ripple shifted it by fractions of a pixel a
  frame and the strands hopping between pixels shimmered (Richard: "looks glitched"). Its catch and the rubbish round it are at 1x too (Richard, same day: the
  card's net was too small; "lake's grain, fills the card" picked over a chunky 2 px net
  cropped by the card). The upgrades button (HUD and shed copy) draws a picture rendered
  once by the same shader in a `SubViewport` (`CastNet.bake_picture`, lent by
  `_lend_net_picture`) at whole steps. Headless renders and lends nothing. `Style.NET_INK`
  tints nothing in the game. **Retired** with it: the card's foam collar
  (`NET_WATERLINE`/`NET_COLLAR`, laid at the old etching's waterline), `NET_GROW`,
  `CATCH_SCALE`. The letter's stills were re-shot.
- **Retired**: `assets/net_frames.png`/`.json`, `assets/sliced_net.png`, `tools/slice_net.gd`,
  `tools/shot_nethold`; the two etching JPEGs moved to `art_source/retired_assets/net/`.
- **Cost** (`bench_frames`, RTX 5060 Ti, 1080p): a plain cast 5.1 ms mean; the worst case
  (`BENCH_BIG=1 BENCH_LUCK="lucky double"`, two max nets) 12.3-12.7 against about 11.6-12.0
  with the mesh off, so the net costs about half a millisecond there. That case was over the
  bar before.
- Probe: `tools/shot_net.tscn` (desktop build, `--fixed-fps 60`, own save, under its own
  node) casts at three widths, the last lucky, and saves `tools/last_net_<cast>_<moment>.png`,
  `tools/last_net.png` and `tools/last_net_picture.png`. It is what compiles the shader.
  `test_lake`'s `_check_net_shape` guards the shape's rules, the constants and the retirement.
- All numbers are first guesses for Richard's eye.

### The Net Digs the Pile (2026-10-03, `/grill-me` with Richard)
Richard: a full-strength, full-width cast on a pile came home with a few pieces, and the
rest "floated up" behind it. **The sweep took two layers a tile** (`SWEEP_LAYERS`, deleted):
open water filled the bag (80-odd tiles x 2), a tight deep pile did not (9 tiles x 2 = 18).
- **A sweep takes layer after layer until the bag is full or nothing under the mouth can be
  lifted** (`CastNet._sweep`, `_take_from` returns its count). Same order as before: the
  whole top layer across the mouth, nearest first, then the next, so a bag that fills part
  way leaves an even patch. Never past a piece too heavy to lift.
- **A tile the sweep has taken from stays in it** (`dug` in `_sweep`). The piece under a take
  is rolled a new drift and starts `EMERGE_DROP` (16 px) low to rise into view, so asked of
  its drawing alone it often fell outside the ring and floated up behind the net: one
  nine-deep tile under the smallest mouth gave 1 / 1 / 1 / 3 / 3 / 9 over six landings, 9
  every time since. A big net lost its rim tiles the same way. **The column under a piece
  the net closed on is under the net** — an extension of "the ring is the catch", not a
  reversal: a tile still has to be touched once to be dug.
- **Landing and reel alike, both nets**: a haul dragged over a second pile scoops it too.
- **Cost**: none measurable. `bench_frames` big lucky double, two runs each: two layers 13.5
  / 14.4 ms mean, dug to full 11.7 / 14.6 (the machine was noisy that day). On a full lake a
  maxed net filled its bag on the landing before too, so the bench's work is the same.
- **Pacing: accepted, judged in play** (Richard). Catch now binds on any pile, so the run
  shortens by an amount the sim cannot see (one lake-wide density). Prices frozen, sim not
  re-run; the next logged run decides.
- Probe: `tools/probe_catch.tscn` (headless, maxed net, own save, `tools/last_probe_catch.log`):
  fresh lake 64/64 every cast before and after; `PROBE_THIN=0.85` a thinned lake;
  `PROBE_PILE=1` an empty lake but a 3x3 / 5x5 / 7x7 pile nine deep: the 3x3 landing now
  takes 64, was capped at 18. `test_lake`'s `_check_dig_to_full` (in `_stage_net_ring`)
  guards a roomy sweep leaving nothing liftable under the mouth, deeper than two layers, and
  a small bag stopping at the bag.

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
  the actual sprite of one of the yard's pieces (`EMBLEM_PIECE`: bottle, chair, extinguisher,
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

### The Piers Tidied (2026-09-26, `/grill-me` with Richard)
- **Only the near edge's posts are dressed** (`build_piers.py`, the post filter): a post whose
  foot is under the deck top or box, or whose foot has the deck's footprint still in front of
  it (`UNDER_PIER` 3 px, tested in the yard's own local frame), gets no sand and no foam. The
  far rows' feet showed in the gap under the jetty, so their sand and foam were seen through
  under the pier and the foam lifted into the deck with the swell. Jetties went 7-8 wet posts
  to 3-5, platforms 4-5 dry.
- **A post on the sand has no mound at all** (`Dropoff._dress`): it stands straight in the
  beach. A drift of two low rows was tried the same day and still showed a line against the
  shaded sand round it (Richard: "no visible division"); any drawn heap does. `Skirt.mound` is
  unused now and left in `skirt.gd`.
- **The deck top owns its pixels, and the deck mask is written** (`build_piers.py`'s deck
  loop): a far-row post rising into the deck left those pixels on the under layer, so the
  deck had holes with the pole showing through; and `deck[x][y]` was never set by that loop,
  so the edge beam, both shadow masks and the box's contact rows had all been empty. With it
  set, the near edges carry their beam and the pier throws its shadow again.
- **The box stands on the platform's middle** (`BOX_STAND` row of the art on it): it stood its
  art's bottom row there, which is the near corner of its base, so it sat in the back corner.
  `BOX_CONTACT` takes the two deck rows under its foot down to 0.55 and 0.8.
- **Each sign is painted** (`SIGN_PAINT`, `SIGN_WEATHER` 0.15, carried as `sign_paint` in
  `piers.json`): metal grey, wood brown, plastic blue, rubber near-black, the wood's light and
  grain kept under the paint; the post stays wood. `Dropoff.SIGN_INK` clears 4.5:1 on all
  four (worst 4.93).
- **`tools/shot_piers.tscn` hangs its lake off its own node and its own save**
  (`user://probe_piers.save`): off the root it photographed the main menu and had no save
  path of its own.
- Out of scope, by decision: jetty shape, sign placement, the box art. **Open**: the open-water
  lily beds are drawn over the jetty (`Flora.avoid` keeps them off the feet and berths, not the
  deck).
- `test_lake`'s `_check_pier_look` guards the paint and its contrast, the box's stand, no
  mound, and no hole in the deck top (the old sheet has two).

### The Piers, the Box and the Hold at the Angler's Grain (2026-10-02, `/grill-me` with Richard)
The piers and the recycle box read coarse beside the redrawn hut, the angler and the pack
rubbish, and a ferry's load stuck out over its sides. **Supersedes** "drawn at 2.0" for the
piers and both boxes (The Piers above, the island crate at 2.0 under The Hut), and "The hold
fills bottom up" under The Ferry.
- **One box, drawn by rule at 1x** (since the same afternoon in the hut's own siding, see
  The Hut Redrawn; the board/post description below is the first pass) (`tools/build_recycle_box.py`, writes
  `assets/Recycle_Box.png` 64x66; the old 32x33 painting is kept as
  `art_source/recycle_box_2x.png`): the same box at twice the pixels, so it is the same size
  in the world. Top diamond centred on row 16 (`Yard.ART_TOP`), ground on row 48
  (`ART_GROUND`), walls 32 rows. Horizontal boards (`BOARD` 8 rows: lit row, body with grain,
  darker row, seam), corner posts, nails, a knot, a 3-row rim (`RIM`, `Yard.ART_RIM`, which
  the front cut keeps), the recycle mark on the shaded left face (picked off four: radius
  7.5, bar 2.2, arcs of 100 degrees, heads 5 by 4.5), near-black outline. **Both the island
  crate (`Yard.ART_SCALE` 1.0) and the four piers' boxes**; the luck card's box follows
  (`ShopCard.BOX_SCALE` 0.75).
- **Brown, by Richard's pick** off `tools/last_pier_palettes.png` (`build_piers.py
  --palettes`): the old box's own browns (`RAMPS["brown"]`) over the hut's oak with moss.
  `oak` is still in the table.
- **The piers at 1x** (`build_piers.py`, `HALF_W`/`HALF_H` 32/16, `ART_PIXEL` 1,
  `Dropoff.ART_SCALE` 1.0): every painted-px count doubled (deck 12 up, beam 4, posts 6
  wide, bollards 10, sign 88x26), the layout untouched. Deck boards `PLANK_PX` 10 rows with a
  lit row, grain dashes, nails over the stringers (`NAIL_IN`, `NAIL_GONE` missing), worn
  ends and knots (`deck_tone`); round piles with grain rings; bollards with a rope band; the
  sign two boards with nails. **Emblems re-picked at native size** (the rubbish is 1x now):
  plastic bottle, `wood_stump1`, `metal_kettle`, `rubber_ball`, drawn at whole steps.
- **The hold is the box's heap in a hull** (`Boat.hold_spot`, `hold_shown`, `hold_scale`,
  `_draw_held`, `_draw_front`): `build_boat_sheet.py` finds each frame's near rail
  `RAIL_ABOVE` (3) rows over the blue stripe, the well the load stands across (the stripe's
  span less `WELL_TRIM`), writes both as `well` in the sheet's json, and copies the hull from
  the rail down into `assets/boat_hold_front.png`. The pile stands on the rail
  (`HOLD_SINK` under it, `HOLD_STEP` a layer, `HOLD_BACK` up the deck for the odd piece),
  spreads over `HOLD_SPREAD` of the well and is held in by the widest a piece may be
  (`HOLD_FIT` of its slot, `HOLD_SCALE` 0.7 at most); then the front, then the sail. **The
  pile drawn follows how full the hold is** (cargo over capacity, of `HOLD_SHOWN`). Rule, not
  a table: the same at all sixteen headings. The hull frames themselves are unchanged.
- **The hut and the piers draw nearest** (`_island.texture_filter`, `Dropoff._ready`, same
  day, Richard: the hut "still looks a bit off"): the project's default filter is linear and
  neither node set one, so both drew smoothed beside a crisp angler, crate and pump. Any new
  node that draws a picture sets `TEXTURE_FILTER_NEAREST` itself. Probe:
  `tools/shot_hut_px.tscn` (desktop build, own save) photographs the hut at every zoom stop
  with the screen px per world px in `tools/last_hut_px.log`. Note the 1x art at the 1.0
  stop on 1080p draws 1.5 screen px per world px, unevenly, as the angler always has.
- **Every picture draws nearest unless it asks otherwise** (same day, Richard: "make sure we
  don't have any other assets with the same issue"): `Prefs._ready` sets the root viewport's
  `canvas_item_default_texture_filter` to nearest. **Not in `project.godot`**, which the open
  editor re-saves from memory. `tools/probe_filters.tscn` walked the live tree first and found
  the rubbish, the dogs, the net, the pigeons, the haul, the wildlife, the tornado, the shop's
  head cards, the find-caught card and the settings board all drawing smoothed. Linear on
  purpose, and set so: the rubbish shadows, the logo, the loading picture, the letter's
  stills, Spotify's mark, the curtain's frozen frame, and the menu's scrim gradient (set
  linear here, or 256 px stretched over the window steps). The probe lists any item still
  linear; `test_lake` guards the root default.
- **The plants move with the water** (same day, Richard: "the sway should be with the water,
  not wind"; all flora, the water's rhythm): `shaders/flora_sway.gdshader` on `Flora` and on
  the island `Ground`'s prop batch (its tufts). A plant's foot rides packed in its corners'
  colour (`LakeGrid.pack_anchor`, the blue saying what the corner does: `Flora.AFLOAT`,
  `TOP`, `FOOT`). Afloat (pads, open beds, standing reeds) it rides the rubbish's own swell
  and wander on `lake_clock`; on land its top corners lean `Flora.LEAN` (1.4) art px with
  the swell at its foot, rounded to whole art px, a pixel-art shear. **Open**: a pad's stem
  and shadow under the water (`Flora.Below`) do not bob with it. Probe: `tools/shot_sway.tscn`
  (`tools/last_sway.png`, six frames 1.2 s apart).
- **`tools/shot_boat.tscn` has its own node and save** (`user://probe_boat.save`): off the
  root it was the game's lake and wrote a session line into the playtest log (taken out).
- Out of scope, by decision: the ferry's own art (still 2x), the jetty's shape, the sail.
  All numbers first guesses for Richard's eye.
- `test_lake` guards every heading having a well, every slot at its widest inside it, the
  bottom layer behind the rail, the pile following the fill, and the front sheet.

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
  capped `most`), reconciled every `RECKON_EVERY`. Seen as lit bodies with their shadow on the
  lakebed since 2026-09-30 (see The Lakebed Through Clean Water; this said "only as a shadow")
  and **rings** through
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
  **And a third time, 2026-09-19** (Richard: "still too much sparkle on clean water at early
  game, it should be really sparse and rare"): `GLINT_BITE` 2.5 to **5**. **Count it, don't
  feel it**: a screen of clean water at zoom 1 is 576 glint cells rolled five times a
  second, so it shows `259 x glint` pops a second, and four times that at the 0.5 zoom
  stop. At 2.5 that was 1.2 a second with a fifth of the lake clean and 3.2 at three
  tenths, which is a steady twinkle. At 5: one in fifty seconds, one in six seconds, 2 a
  second at half clean, 15 at eight tenths. `_clean_share` lags the meter (a tile is clean
  only with nothing within `FILTH_BLUR` of it), so "early game" is a share under about 0.3.
  `test_lake` holds the early rate (under one pop in four seconds at 30% clean), not the
  constants.
  **And a fourth, the same night, from 92% cleared** (Richard: "still too much shine
  overall, tone down a lot"): the bite fixed the early game and left the ceiling alone, so
  nine tenths clean was still 38 pops a second on that screen and 150 at the 0.5 stop.
  `GLINT_MOST` 0.25 to **0.03** and `GLINT_BITE` back to **3.5**, so what is left is spread
  over the run: 0.1 a second at 30% clean, 0.7 at half, 3.6 at 80%, 5.4 at 90%, 7.8 at the
  very end — lower than before at every share. **Both knobs have to be read together**: the
  bite moves *when*, the ceiling moves *how much*, and twice a complaint about one was
  answered with the other. `test_lake` holds both ends (under 0.25 a second at 30%, under
  8 at 90%). The finished lake's `sparkle` is still untouched.
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

### The Lake Fills With Life (2026-09-22, `/grill-me` with Richard)
More nature as the lake is cleaned: frogs, turtles, ducks with ducklings, dragonflies, bees,
more kinds of plant, and beds of pads and reeds out on the open water. `scripts/wildlife.gd`
(`Wildlife`: frogs, turtles, broods, dragonflies), bees and the open-water beds in
`scripts/flora.gd`. Builds on Nature Coming Back above, and every rule there holds.
- **Ambient, but they flee** (Richard's call over fully ambient and over catchable): no
  catch, no pay, nothing saved. A net landing (`Lake._on_net_landed` → `scare`), and the
  angler, any dog or any hull coming within reach (`Lake._wildlife_threats`, asked once a
  frame) send them off: a frog jumps in, a turtle pulls its head in or dives, the brood takes
  off, a dragonfly darts away. **Silent this pass**, by decision; no recordings exist.
- **All of them from the first clean water, more as it spreads** (Richard, over a staged
  ladder like the fish's): `ceil(most * stage)` once `stage` passes 0.02, capped by
  `FROGS_MOST` 30, `TURTLES_MOST` 14, `BROODS_MOST` 5, `DRAGONFLIES_MOST` 20 (raised the
  same evening, Richard: "more prevalent on shore"). Broods come in
  one at a time, `BROOD_GAP` apart. Only where the honest map says clean, never a catch patch.
- **Frogs are the Pixel Frog pack, green and brown, recoloured onto the palette and halved**
  (`tools/build_wildlife.py`, `recolour_frog`, `halve`; blue, purple and the GameBoy sheets
  are out). The pack is drawn at twice the game's grain — at the game's 2 a whole frog stood
  as tall as the angler — so each 2x2 block is folded to its commonest colour. Idle, croak,
  jump and hop, eight facings (`_row_of`: S, SE, E, NE, N, NW, W, SW). They sit on the sand
  of both shores (`_find_shore`, 220 spots found on the bearings, kept off the hut, crate,
  pump and yards), croak, hop along the beach, jump in, **swim as a shadow**
  (`frogswim_<heading>_<frame>`: a rule-built top-down silhouette, eight headings on the
  plane, three kick frames, drawn in `SHADOW_INK` under the surface at z 3), and climb out
  onto the sand or onto a grown pad (`Flora.pad_spots`).
- **Turtles, ducks, ducklings: built by rule** in the same builder, palette swatches, the
  pack's dark ring (`outline`), facing left and mirrored through `Flock.stamp`. Turtles bask,
  walk, paddle the shallows, tuck, dive. A brood is a drake alone or a hen with up to five
  ducklings trailing her wake (`_kids_swim`); it flies in from off the lake, glides down,
  lands with rings, paddles, dabbles, and takes off when frightened or after `DUCK_STAY`.
  A flying brood's shadow is its silhouette under `Shade.lying`, the pigeons' bargain.
  Floating animals sit in torn whole-pixel foam (`_collar`).
- **Dragonflies and bees are drawn in code, whole art pixels.** A dragonfly is a body along
  its heading snapped to eighths, two pairs of flicking wings and a shadow pixel; it hovers
  and darts round a home over a clean shore or a pad. Bees (`Flora._draw_bees`) circle grown
  flower heads, up to `BEES_MOST` 70, on their own child node (`Flora.Bees`), so their
  per-frame redraw does not resend the whole plant batch (that cost 1.2 ms). Up to
  `BEES_MOST` 90, **picked by rank with the island's flowers first**: picked in painter's
  order every bee went to the far bank and none to the island.
- **Layers**: the frog's swim shadow at z 3, everything on the sand and the water at z 6
  (above the rubbish soup), flying ducks and dragonflies at z 20. Land animals do not sort
  against the angler (z 9): a frog in front of him is drawn under him, accepted, because it
  jumps away before he gets there.
- **Second look, same evening** (Richard, on `tools/play_clean.tscn`, a near-clean lake on
  its own save): **a frog's swim never crosses sand** (`_clear_path` on every swim target,
  and a step onto land turns it back out along its shore) — its shadow was showing through
  the island; the shadow is drawn over water only. **Tracks in the sand** (`_track`,
  `TRACK_LIFE` 14 s, `TRACKS_MOST` 500, dry sand only, `_sandy`): a frog leaves two dents
  where it takes off and lands, a turtle a foot each side and its shell's drag. **Frogs face
  the way they go**: the pack's rows run **S, SE, E, NE, N, NW, W, SW** (read off the jump
  frames), `_row_of` is `2 - k`; it was mirrored and every sideways frog leapt backwards.
  **Turtles have two legs showing**, and **only walking moves them**: the walk is paced by
  ground covered (`TURTLE_STEP_PX`), not by the clock, four frames stepping one leg at a
  time (`TURTLE_STRIDE` in the builder); a timed walk paddled its legs while it crept.
- **The animals move to the music** (same evening, second `/grill-me` with Richard).
  `MusicStation.beat_clock()` / `beat_length()` read a beat grid per song,
  `assets/music/beats.json`, measured off the built files by `tools/measure_beats.py`
  (spectral flux, low end weighted, whole-song grid score): **beatgucci 135, Save ME 80,
  Goin 118, Habibs 144**. Habibs measures a crisp 144.0 on the built file where the
  trailer's cut used 143.55. **Which octave a song is in is the ear's call** (`TEMPO_HINT`:
  beatgucci's half-time 67.5 outscores its 135); `tools/beat_click.py` writes
  `tools/last_beat_<slug>.wav` with a click on every measured beat for that check. The
  heard song drives it: the ending once over half up, the next song once the handover is
  half done. **The clock runs when nothing is audible**, by decision — muted, muffled or
  through the shed wall, the animals keep dancing to a silent song.
  - **Frogs**: each picks its own beats, now and then (`FROG_SIT_BEATS` 3-10 beats of rest,
    the move `FROG_PICK_AHEAD` 1-3 beats on), a hop or jump launched early enough to
    **land** on its beat, a croak starting on it and swelling over `FROG_CROAK_BEATS`.
    Frights stay instant. A cue the clock jumped past (a crossfade's handover moves it) is
    picked again (`CUE_MISSED`), not fired late.
  - **Turtles**: a resting turtle nods its head a pixel on every beat, up on the beat and
    down off it, half of them a half beat behind (Richard's pick over half-time).
  - **Dragonflies** hover whole beats (`FLY_HOVER_BEATS`) and dart on one. **Bees**' orbits
    jump ahead `BEE_PULSE` on each beat and ease out (`Flora.music`).
  - **Out of scope, by decision**: ducks and fish, live audio analysis, the shed's radio
    song driving the lake. `test_lake`'s `_check_beat` guards a grid for every song, the
    station counting off it, frogs' hops landing on the beat, and the nod.
- **The animals may use half the splash layer's rings at most** (`Wildlife._ripple`): at
  first their rings filled `WaterSplash.MAX_RIPPLES` and a walker's entry ring was refused.
- **More plants** (`tools/build_flora.py`): tulips, an orange flower, daisies, two clovers,
  a fern, a mushroom, two flowering shrubs on the lawn; cattails and sea pinks on the beach;
  a yellow lily and small pads on the shore water. **Open water** is a new kind, `open`:
  beds of pad clusters, lilies and standing reeds where a coarse value noise
  (`OPEN_CELL`, `OPEN_AT`) is high, kept `OPEN_CLEAR` tiles off the yards' feet and berths
  (`Flora.avoid`). The net passes over them; decoration only.
- **Cost** (`tools/bench_frames.tscn` with the new `BENCH_CLEAN=1`, west half emptied, RTX
  5060 Ti, 1080p): 5.8 ms mean, worst 8 ms; with wildlife and flora off (`BENCH_OFF="wild
  flora"`) 4.7. Inside the 8 ms bar.
- **Out of scope, by decision**: sound, catching or paying, saving, licensed art, floating
  algae mats (they would read as grime), frog colours other than green and brown.
- **Numbers are first guesses** — counts, speeds, shyness, `DUCK_STAY`, the open beds'
  density, the bees' orbit — for Richard to retune in play. Contact sheets:
  `tools/last_wildlife_sheet.png`, `tools/last_flora_sheet.png`. **Re-run both builders and
  reimport** after changing either.
- Probe: `tools/shot_nature.tscn` also saves `last_nature_<stage>_near.png` (the middle at
  2x) and logs every animal's count; it now hangs its lake under its own node. `test_lake`'s
  `_check_bees` and `_check_wildlife` (in `_stage_nature`) guard the open beds keeping off
  the yards, bees only at grown flowers and under the cap, pads offered to frogs, the shore
  spots being sand behind and water in front, nobody on a dirty lake, counts following the
  share, homes and landings on clean water, frogs swimming ashore, a frog jumping in and
  swimming as a shadow when walked up to, the brood taking off at a landing, the facing
  rows, and no catch or pay.

### Still Walkers, Prop Shadows, the Pump's Flower, Reeds (2026-09-28, `/grill-me` with Richard)
- **A still angler or dog frightens nothing; it is an obstacle** (`Lake._sort_walkers_for_wildlife`,
  `WILDLIFE_STILL_SPEED` 12 px/s, `Wildlife.obstacles`, `_round`, `_taken_by_still`,
  `OBSTACLE_REACH` 0.9 tiles). Only walkers moving faster than that, hulls and net landings
  startle. Frogs swimming, turtles and rabbits/foxes walking slide round a still walker's
  room; hop, walk and wander targets inside it are refused. A startled animal used to come
  back to an idle angler and startle again, in a loop. Flying things (ducks, dragonflies) are
  untouched. **Supersedes "the angler, any dog or any hull coming within reach"** in The Lake
  Fills With Life for the angler and the dogs.
- **Tree and rock shadows are hinged on their base** (`Ground._prop_pad`, `_pad_under`): the
  lowest opaque row, plus a quarter of the ink's width over its bottom `BASE_ROWS` (a
  three-quarter-view rock's lowest pixel is the near edge of what it stands on; the shadow
  tucks under it). The sprites did not move.
- **Props and pier signs cast with `Shade.cast`, not `Shade.lying`** (second pass the same
  day, Richard: still disconnected, and the sign's shadow had no pole): the shear keeps a
  picture's width level, so when the shadow runs sideways a trunk or a post is a line with
  no thickness and the crown's or plank's shadow floats. `cast` lays the width across the
  shadow's own heading. The walkers, hulls and birds keep `lying`. Probe:
  `tools/shot_props.tscn` (desktop build) saves `tools/last_props_{tree,rock,forest,sign}.png`.
- **Flowers grow on the forest floor** (`Flora.FOREST_DEEP` 8 tiles past `WOOD_FROM`,
  `FOREST_SPOTS` 2, kind `forest`: the lawn's plants less the shrubs), never where a tree's
  or rock's drawing is (`Ground.hidden_by_prop`, alpha-tested, since flora draws over the
  ground layer). They wait on the clean water off their bank like the rest.
- **No plant behind the pump's picture** (`Pump.hides`): the footprint alone let a flower grow
  just up-screen of the pump and read as painted on it. Pump only, by decision; hut and crate
  unchanged.
- **Reeds and cattails grow within `Flora.REED_REACH` (1 tile) of the drawn waterline**, on
  both shores (`_from_water`); further up the sand the spot grows another beach species.
- `test_lake`'s `_check_still_walkers` guards all four.

### Seven Visual Fixes (2026-09-25, `/grill-me` with Richard)
- **A dog lies on a sofa's cushion or its side, never its backrest.** The sofa's catalogue
  rects are labelled the wrong way round: the one called `front` (view 0) is the backrest,
  the one called `back` (view 2) shows the cushion. Seats are now sofa `[0, 4, 4, 4]` and
  armchair `[3, 4, 0, 4]` (whose labels are right), sides both ways included. The labels
  were not swapped, by decision: view 0 is what leaves the store and saves hold view
  indices. `test_lake`'s `_check_shed_dogs` places the sofa by `SOFA_CUSHION`.
- **The pigeons wear the rubbish's black outline** (`tools/ink_pigeons.py`): one pixel of
  pure black outside every bird, baked into `assets/pigeons_inked.png` with the cut grown a
  pixel a side in `pigeons_inked.json`. `Flock` and `pigeon_contact` read the inked pair;
  the pack's sheet and `pigeons.json` are untouched. **Re-run it after `slice_pigeons.gd`.**
  The head pop's portrait is its own drawing and is not outlined.
- **Ducks wait on the meter** (`Wildlife.cleared`, `LATE_FROM` 0.6, `_want_late`): none
  until the pollution meter reads 60% cleaned, then filling in to `BROODS_MOST` on a cleaned
  lake. The lake hands `1 - pollution` through `refresh`. Everything else still follows
  the clean-water share.
- **Rabbits and foxes on the outer bank** (`Wildlife.Land`, `_new_land`, `_land_step`,
  `_land_fright`; sprites `rabbit_*`/`fox_*` in `build_wildlife.py`, the rabbit hand-drawn
  as letter rows, the fox by rule). Bank shore spots only, never the island. Rabbits from
  the first clean shore (`RABBITS_MOST` 8), foxes from the late gate (`FOXES_MOST` 3). They
  come out of the trees, sit, wander along the sand, leave prints, and run inland fading
  out when the angler, a dog, a hull or a landing net comes near (`RABBIT_SHY`, `FOX_SHY`).
  Ambient: no catch, no pay, not saved, and they ignore each other. All numbers first guesses.
- **A bolt over the wash room's far bank** (`WashBackdrop._strike_bolt`, `_draw_bolt`): a
  flash rising past `BOLT_FROM` rolls a jagged run of whole painted pixels from the sky's
  top to the treeline, with up to two branches, lit with the flash; the echo relights it
  (`BOLT_HOLD`). **The only drawn bolt in the game**: the lake keeps its flash without one.
- **The globe stands on a 2 px base** (`base_px`), like the pots, so it can be pushed up
  against the shed's back wall.
- **The stove switches on** (`tools/build_stove_on.py` -> `art_source/decoration_extracted/
  stove_on.png`, a plain file like the bed's): burner plates flood-found and lit orange
  with a red rim, the oven window lit red. `STATE`, off first, light `ember` (new:
  `ShedRoom.EMBER_*`, a small red pool, silent). Built by rule for Richard to polish. **Re-run
  it after a re-extract of the decoration PSD**, then `build_decor.py`. No `SAVE_VERSION`
  bump: the def list did not move and view 0 is the plain stove.

### Eight More Fixes (2026-09-25, second `/grill-me` with Richard the same day)
- **The south wood hides what is behind it** (`Ground` `_cover`, `COVER_LAYER` 7,
  `covers_at`, `COVER_FROM`): the forest trees south of the lake's middle are drawn a second
  time over the animals (6) and the bees (flora, 3), under the walkers (9). The ground is one
  layer under everything on land, so a near-side canopy could not hide a rabbit or a bee on
  the lawn behind it. North trees are not redrawn: their canopies rise away from the lawn,
  and redrawn they would cover an animal standing in front of them.
- **Rabbits and foxes throw the sun's shadow** (`_draw_land`, `Shade.lying` in the day's
  ink, the dog's rule), left on the ground under a rabbit's hop.
- **Rabbits and foxes live on the bank's lawn by the trees** (`Wildlife.LAND_HOME` 6-9.5
  tiles out of the water, the woods thickening from `Ground.WOOD_FROM` 10), grazing along
  the grass pulled back towards home, a trip to the sand at `LAND_BEACH_ODDS` and back.
  `_on_bank` is where they may walk. Prints are still sand only.
- **The fox's legs are one pixel wide and bend** (`FOX_SWING`, `FOX_LEGS`): hip, joint, foot,
  the pair's legs swinging opposite ways, the hind hock kicked back, the far legs darker.
- **Lightning at half strength** (`Weather.FLASH_PEAK` 0.5): everything reading the flash
  follows; the wash room's bolt reads the flash against the peak (`BOLT_FROM` 0.25).
- **The meter reads 0% over empty water**: `_look_for_the_end` zeroes `pollution` the
  moment the field holds no piece, not only once the last has landed in the crate, and the
  HUD's ease compares exactly (`is_equal_approx` let a sliver stand, which rounds up to 1%).
- **Glints are soft pops** (`water.gdshader`): a 2x2 of art pixels that swells up to
  `GLINT_UP` (3) steps and back over its cycle, each cell on its own phase, `glint_fps` 0.72
  cycles a second where it was 5 ticks: a seventh as many, each seen seven times as long.
  Sun-path glints were offered and turned down (the strips retired in Sep 2026).
- **A puddle by the hut runs up to the walls and stops short** (`Puddles.shed_gap`,
  `SHED_NEAR` 0.3, `DOOR_NEAR` 0.75 in front of the door, `SHED_SOFT` 0.8): measured round
  the footprint's corners, the reach pushed up with the edge noise near the walls, so the
  edge wanders instead of the old straight cut at `OFF_SHED`, which now only keeps a
  puddle's middle off the hut. `DOOR_ALONG` must match `Lake.DOOR_ALONG` (`test_lake`).
- **Half as many fish schools again** (`Fish.TIERS` 27/14/5, per 36/83/360 tiles). Their
  rings take half the splash layer's cap at most, like the wildlife's: raised, they filled it.
- **The settings board pauses the game** (`Lake._pause_world`, `_world_frozen`,
  `world_paused`): the angler, the nets, the haul, the hulls, the dogs, the birds, the
  wildlife, the fish, the flora and the day are switched off where they stand, and the
  lake's clocks (play clock, autosave, bonus, ending search, tours, the weather's schedule)
  do not run. The water, the rubbish's bob, falling rain and the sound carry on. Not a
  tree pause, by design; not the shop, shed or wash room, by decision.

### Three Small Fixes (2026-09-26, `/grill-me` with Richard)
- **The angler faces his net** (`Angler.face_toward`, `Lake._face_the_net`): on the throw and
  every frame the first net is out, he turns to where it will land (flying) or where it lies,
  snapped to the sheet's four views by `_view()`'s own rule. Only while the cast pose is held,
  so walking still decides the facing. The double cast's second net turns nobody.
- **Superseded by One Sun (2026-10-02)**: the hull's pair is now `Shade.On.WATER`.
- **The ferry's shadow is 10% lighter**: `Boat.SHADE_GAIN` 3.0 to 2.7, `SHADE_MOST` 0.7 to
  0.63. The piers keep their own constants, unchanged.
- **Closing the wash room lands in the shed** (`Lake._wash_to_shed`), cross, Escape, E or
  pad B, whether it was opened from the shelf's plank or the pump. **Supersedes "the wash
  room's own close returns to the lake"**. Forced closes (the menu's pose) still go to the lake.
- `test_lake` guards the four facings, no turn without the pose, and both closes.

### The Blurb and the Nozzle Wait (2026-09-26, `/grill-me` with Richard)
- **A shop blurb never covers its own row** (`ShopSkin.blurb_at`). **Superseded 2026-10-06**
  (see The PlayStation Pad, second pass): it stands beside the row's whole board, level with
  the row, so the column being read stays clear. `BLURB_OFF` and `_mouse_at` are gone.
- **The wash nozzle waits** (`WashStand.awake`, `WAKE_AFTER` 0.4 s): a find put on the stand
  parks the aim on its middle, and the player's paths (`_gui_input`, `WashRoom._pad_aim`) are
  deaf until the choosing press is let go and the wait has run. `spray` itself is not gated,
  so probes still drive it straight away. On the pad the hidden pointer is warped to the find.
- `test_lake`'s `_check_blurb_and_wake` guards both.

### Five Signals (2026-09-26, `/grill-me` with Richard)
- **The wildlife moment** (`Lake._on_first_wildlife`, `_start_owed_moment`, `_moment_step`,
  `MomentCard`, `Wildlife.first_arrived`): the run's first animal (frog, turtle, dragonfly,
  rabbit, fox or brood, not a plant) glides the view to where it is headed and in to the
  nearest zoom stop over `MOMENT_IN`, holds `MOMENT_HOLD`, and glides home over `MOMENT_OUT`,
  with "Wildlife is coming back, great news!" (`Text.WILDLIFE_BACK`) on a paper card low in
  the window. **The player's hands are held and the world runs**: walking and all input are
  off, **the net is not held**, so a haul in progress reels itself home off screen, by
  Richard's call over waiting for the net. Only a board, the menu, the arrival, the letter or
  the ending make it wait (`_moment_owed`). **The third zoom glide in the game**, after the
  menu's Continue. Saved as `wildlife_seen`, absent reads as seen (the tours' rule), no
  `SAVE_VERSION` bump; a new game sets it false in `_start_arrival`.
- **Superseded 2026-10-05** (see Four End-Game Fixes): thirty pieces, arrows grouped, and a
  shrinking mark is patched in place.
- **The last three pieces are marked** (`Lake.LAST_MARKED`, `_mark_last_pieces`,
  `LakeGrid.mark_last`, `LastArrows`): from three pieces left, every tile holding one wears
  a **pale** rim in the soup (`PALE_FLAG` 0.3, `rubbish.gdshader`'s `rim_pale`: gold is
  treasure) and a white column (`LAST_TINT`, the find's beam), and a screen-edge arrow points
  at each one the view does not hold. Strand pieces the dogs fetch are marked the same.
  Marking relays the soup once per change, a handful of times a run.
- **Pigeons drop half as much and never while perched** (`Flock.POOP_CHANCE` 0.9 to 0.45,
  `POOP_CHANCE_PERCHED` deleted).
- **A spend runs the purse down** (`HudSkin._process`, `_spent`, `SPENT_*`): at the pace
  earnings run up, with a red "-X" dropping off the plate and fading over `SPENT_LIFE`, on
  the corner plate and the one over the shop alike. Supersedes "It simply drops".
- **The haul's count over the angler** (`HaulCount`, `Lake._haul_count_step`, `_bank_haul`):
  "7/24", pieces over this cast's room (lucky haul's included), ticking with each grab.
  **Both nets of a double cast are one count** ("11/32", second pass the same day): a net
  home banks its catch, and the figure pops and fades once the last net of the cast is home.
  **Luck shows from the throw** (`throw`): a lucky or double cast is up at "0/..", with a
  swell; a lucky figure is the finds' gold with art-pixel stars round it, a double wears an
  "x2" tag, both together swell bigger with more stars. **A full cast is pale red**
  (`FULL_INK`), so gold means lucky and nothing else. A plain throw shows from its first
  catch.
- All numbers first guesses. `test_lake`'s `_check_signals` guards all five.

### First-Time Cues (2026-10-07, `/grill-me` with Richard)
Every mechanic a player meets mid-run is named the first time it happens.
- **The first tornado is a moment** (`Lake._on_tornado_touched_down`, `Tornado.touched_down`):
  at touchdown the view glides to the funnel with "A tornado on the lake, tame it with your
  net." (`Text.TORNADO_FIRST`), the wildlife moment's queue and treatment. **Its clock is
  held** (`Tornado.held`, `_held_t`, `Lake._tornado_moment_holds`) from touchdown until the
  moment is over, a wait behind a board included: it spins, lifts and flings, but neither
  hunts nor counts down its life. **No count of hits left, by decision**: the card and the
  funnel shrinking teach it. The tornado's moment does not `save_game` (a save settles the
  tornado); a tornado gone before its moment runs is dropped and stays unseen.
- **Four hints** (`Lake._owe_hint`, `_hint_step`, `HINT_TEXT`): a card beside the thing with
  an arrow at it, the game running on, gone on a click on its paper or after `HINT_HOLD`
  (8 s) up; one at a time; held by the camera tip's conditions (and a moment owed), shown in
  pad mode too (it times out). The **first lucky cast** ("Your lucky cast catches more and
  heavier objects.") and the **first double cast** ("Double cast throws a copy of your
  current net."), both at the count over the angler, lucky first on a cast that is both;
  the **first pigeon netted** ("Pigeons earn money when caught.") at the money plate; the
  **ferries** ("Boats wait to be filled to set sail. Upgrade Capacity to carry more.") at
  the Waiting plate, once every hull has sat docked with pieces short of a load for
  `FERRY_HINT_AFTER` (20 s) of play. The Capacity line was kept on Richard's call after the
  pushback that a bigger hold waits longer. The **pollution meter** ("This trash meter shows
  how much of the lake still needs cleaning.", `CUE_METER`, Richard, same day) at the meter,
  the first time it moves; on a new game that is the first catch, and the hint waits behind
  the first steps' note. Its theme is olive, a little meter for its icon, rising in with
  bubbles. **Closes issue #24**, the onboarding.
- **One card pattern, a theme each** (`scripts/cue_card.gd`, `CueCard`; Richard: "share a
  pattern ... font highlights/coloring on keywords, similar to the trailer, but not
  entirely"): the recycle note's paper, a coloured tab down the left with a whole-pixel icon
  (funnel, sprout, bee on its striped coat, honey jar, four-point star, two nets, the coin,
  the boat) keeping a small loop, keywords between `*asterisks*` in the string drawn in the
  theme's ink over a ragged highlighter swipe that wipes in after the card lands, and a
  themed entrance (swirl with wind specks, sprout from its foot, buzz with bees, drop with a
  hanging drip, pop in the finds' stars, a ghost copy merging, a hop shedding feathers, a
  glide on the swell). **`MomentCard` extends it**, so the wildlife, swarm and honey moments
  wear their themes too. Hint lines are evened out (no word alone on a row); CJK is broken
  by letters. Every ink clears 4.5:1 on the paper and on its swipe (`test_lake`).
- **Saved as `cues_seen`** (the kinds seen); **a save without it has seen none** (the camera
  tip's rule), so a run past its first tornado gets the moment on its next. No
  `SAVE_VERSION` bump. A borrowed lake is marked all seen.
- **Strings**: `TORNADO_FIRST`, `CUE_LUCKY`, `CUE_DOUBLE`, `CUE_PIGEON`, `CUE_FERRY`, and
  asterisks added to `WILDLIFE_BACK`, `HIVE_SWARM`, `HIVE_READY`. Machine drafts in every
  language but English, PT included (Richard's source rule: review them).
- **Out of scope, by decision**: hit pips on the tornado, a find's gold beam, the untamed
  tornado leaving, the Recycle Bonus, rests in the shed, the hose upgrade.
- All colours, timings and entrances are first guesses for Richard's eye. Probe:
  `tools/shot_cues.tscn` (desktop build, `--fixed-fps 60`, no lake) saves
  `tools/last_cues.png` (every theme across its entrance) and `last_cues_<kind>.png`.
  `test_lake`'s `_check_cues` guards the themes and inks, the marked units and wrap, every
  key's marks, the tornado's moment and held clock, the second tornado having none, the
  hint queue, holds, hold time and close, the pigeon's and ferries' triggers and targets,
  and the save rule.

### Weight in the Walk (2026-09-26, `/grill-me` with Richard)
- **The angler slips** (`Angler._vel`, `SLIP_TIME` 0.1, `STOP_TIME` 0.09, `_move_by`): the walk
  is a velocity eased towards the input, so a turn curves and letting go glides about a fifth
  of a tile. The sprite faces the new input at once; only the body lags. A throw plants the
  boots (`_vel` zeroed under `_cast_lock`), `stand_at` clears it, a slide keeps only the part
  of the velocity that went somewhere. Dogs do not slip: nobody steers them.
- **Feet kick** (`scripts/kick_dust.gd`, `KickDust`, one node on the lake at z 4, and its
  `Tracker`): on a start from rest or a swing of more than 60 degrees off a settled heading
  that drifts after the real one, so a gentle curve fires nothing. On land a puff of whole
  art pixels in the palette's sand or lawn green, the lawn throwing less; on water
  `KickDust.splash_at` throws `WaterSplash.drip`s and a small ring, under half the ring cap.
- **The shallows splash on every footfall** at `STEP_SHARE` of a start's burst, on the frames
  the footstep sound uses; a swimming dog every `Dog.STROKE_EVERY` (18 px) at `STROKE_SIZE`.
  Dogs kick at `KICK_SIZE` 0.6.
- **Every foam ring stays on the water** (`WaterSplash.wet_at`, `_band`'s `water_only`): a
  ripple drops each of its 20 quads whose outer edge lands on dry ground, by the rain's own
  wet test (off `Iso.on_island_ground`, inside `Iso.shore_fraction`). Before this, rings
  from the walkers at the shore were drawn over the island's sand.
- Out of scope, by decision: the shed's walkers, new sounds, the wash room's actors.
- All numbers first guesses. `test_lake`'s `_check_walk_weight` guards the tracker, the two
  dust colours, drops off water, the glide stopping and a turn curving. Bench walking: 3.65 ms
  mean, worst 9.7.

### Ten Fixes (2026-09-27, `/grill-me` with Richard)
- **Shore pieces lie apart** (`LakeGrid.shore`, `shore_offset`, `SHORE_APART` 0.27): a
  strand or dry-beach tile keeps its count (up to two) and both are drawn, each at its own
  fixed spot either side of the tile's middle, the line between them turned by a hash of
  the tile. The second is an extra quad in the tile's stamp (no shadow of its own). A take
  leaves the other where it was drawn (no rise, no re-pose); nothing saved. The dog swims
  to the top piece's drawn spot, held inside its tile (`Dog._aim_at`).
- **Coins fly over the hung purse** (`CoinFly.fly_from` moves the node last in the HUD
  layer; each coin re-aims at `coin_centre` every frame), so they land on its coin.
- **Head cards** (`shop_card.gd`): the dogs' strip has no ferry; the boats' card is water
  and ferry only; the net's card floats 6 pieces (`DIRTY_PIECES`), its
  water lifted `NET_WATER_LIFT` towards the lightest step, and the net and its catch are
  drawn `ShopSkin.NET_GROW` 1.5 times bigger (**superseded 2026-10-02**: the card draws the
  lake's own net across its width, see The Net Drawn by Rule); the luck box starts with a heap
  (`HEAP_START` 4, growing to `HEAP_MOST` 9 and starting over) and the piece drops into it,
  the near walls (`Yard._cut_front`) drawn over both.
- **The pricing plate** spreads its four columns over the whole face and reaches
  `LEGEND_REACH` (20) into the gaps beside its two boards; one pairing, name at
  `LEGEND_NAME_PX` (small) over pay at `LEGEND_PAY_PX` (body). Bonus panel and sentence
  untouched.
- **Finds shine more**: `BEAM_FAINT` 0.45 to 0.65, `BEAM_SUNK_TALL` 0.6 to 0.85,
  `STAR_RATE` 2.5 to 4.5, `SPARK_RATE` 8 to 14. Rim and size unchanged.
- **The dog eases into its run** (`Dog._eased`, `RUN_EASE` 0.13): exponential, about 0.4 s
  to full and the same down; top speeds unchanged. The gait runs on its own clock
  (`_stride`, `_clock()`), advanced at the share of the pace reached.
- **A rug is a rug in any language** (`Sheets.lies_flat`): it read the *shown* title, so in
  any language but English a rug blocked floor and sorted with the furniture. It reads the
  catalogue's English title and the piece name now. Flats already block nothing, place
  anywhere, and draw right after the wall pieces.
- All numbers first guesses. `test_lake`'s `_check_ten_fixes` guards each.

### Six Small Fixes (2026-10-01, `/grill-me` with Richard)
- **Going into the water is 20 dB quieter, angler and dogs** (`Sfx.ENTRY_DB`, second pass
  the same day: -10 was still too loud): the entry splash (`play_lake_entry`) and the first
  wash of every wade (`_wade_opening`). The wading wash itself came down 6 dB (-19.9).
- **A dog's mouth opens only while it barks** (`DogArt.BARK_TAIL`, `BARK_ROWS`,
  `WALK2_QUIET`, `Dog._barking`, `BARK_OPEN` 0.45 s): the pack's idle, sit and laid rows end
  on two head-up open-mouth frames, which looped as a silent bark. They are cut off into
  `<row>_bark` and shown only for the bark's length. **`run2`/`walk2` are the first pair
  started half a cycle on** (second pass: the pack's second gaits bark through their stride,
  worst on the dark brown dog), so odd slots still run out of step. A moving dog barks with its mouth shut. Shed dogs and hounds lose the frames.
- **Crayfish live from depth 0.3 to 0.85** (`CRAY_SHALLOWEST`, `CRAY_DEEPEST`) and **never
  dart**: not from walkers, hulls or nets. **Supersedes** "dart backwards, tail first" and
  "no deeper than 0.55" in The Lakebed Through Clean Water.
- **Fish draw under everything on the surface** (moved before `Flora` in the tree, both at
  z 3) and take `Fish.DEEPER` (0.15) more water over each depth step.
- **Pigeons draw at 1.5** (`Flock.SCALE`, was 2.0); the wildlife's critters keep their size
  through their own ratio.
- **The forest is 25% thinner** (`Ground.WOOD_DENSITY` 0.75 over every share, two passes).
- `test_lake` asks that a crayfish does not dart and stands in its band.
- **A led cast walks to the best spot, not at the click** (`Angler.cast_stand`,
  `CAST_GRID` 0.25, `CAST_SPARE` 0.3): of the island's standing points, the one nearest the
  angler from which the click is in range less the spare; none, the standing point nearest
  the click (no throw). Sampled once per press over the island's box. **Supersedes "straight
  line" and `shore_toward` as the walk's end** in The Led Cast; the aim ring's
  `castable_after_walk` still asks `shore_toward` (cheap, per frame).
- **A catch pops** (`Sfx._make_pops`, `_pop_ladder`, `catch_pop`, 6 channels): a soft
  bubble pop built in code (a rising sine, 3 takes) per piece, `POP_FIRST` after the net's
  splash, `POP_DB` -12, pitch climbing `POP_PITCH` 0.4 to 0.7 over `POP_TOP_STEPS` and
  `POP_LOUDER` dB a pop. **No beat**: `POP_CLUMP` (a third) land within `POP_TOGETHER` of
  the last and overlap it, the rest after an uneven `POP_GAP` (0.05-0.16 s). `POPS_MOST` 14.
  Grabs on the reel carry on the cast's ladder; a new landing past `SWELL_GAP` starts it
  over. **A recording since the same evening**: Ben Paramore's
  `868713__benparamoreaudio__bubble_5.wav` (freesound, in `art_source/`), cut whole by
  `build_sfx.py` to `assets/sfx/catch_pop.wav`; the built pops stay as the fallback. Numbers
  by ear (three passes the same day).
  **Fourth pass**: `POP_DB` -10, `POP_CLUMP` 0.5, one pop a piece up to `POPS_MOST` 80 with
  the gaps squeezed past `POP_EVEN` (14), and **the haul count over the angler steps up one
  figure a pop** (`Sfx.pops_heard`/`pops_waiting`, `HaulCount._heard`), snapping to the
  truth when no pops are waiting. The crate's `pop` -17 to **-21** (three passes), `ferry_bell` -17.9 to
  **-20.9**, and 3 dB off `boat_move` (-15.3, stepped over `BOAT_MOVE_PITCHES` 0.8-1.18, never the last), `net_throw` (-11) and `net_splash` (-17.8). `game_start` (New game / Continue) -9.1 to **-21.1**.
- **The potted tree's fallen leaf is gone** (`build_pack_decor.py` `main_island`, a cut box's
  fifth element `"main"`): the leaf reached into the tree's box at its bottom left and the
  crown is as wide, so the piece keeps its largest 8-connected island.
- **A dog lies on any bed, on every face** (`build_pack_decor.py` `SEATS`): the pack bed
  front 18 / side 12 / back 18, the fancy bed 22 / 15 / 26 / 15, by eye off
  `tools/last_beds.png` (the mattress's near edge). **Supersedes "front views only" for the
  beds**; sofas and chairs keep it.

### Seven Adjustments (2026-10-03, `/grill-me` with Richard)
- **The shop**: Catch is the second row of the NET board, under Strength
  (`ShopSkin.GROUPS`), and the boards stand **NET / LUCK / BOATS / DOGS** (`BOARDS`). The
  pricing plate follows `_mid_boards` and stands under Luck and Boats; the purse still hangs
  under the first board, the close cross on the last (Dogs). The shop tour's order is
  unchanged, by decision.
- **The dogs card is the wash room's view in miniature** (`ShopCard._draw_strip`,
  `HORIZON`/`SHORE`/`LAWN`, `LAKE_BANDS`, `LAKE_BEND`): stepped sky, the far wood on the
  horizon, the lake in murky bands widening towards the eye with drifting streaks and scum
  flecks, `DOG_LAKE_PIECES` (5) small rubbish pieces (`DOG_PIECE_MOST` 9 art px, bigger ones
  stand half as tall as the lake), the island's beach and the lawn the pack runs on. **Always
  murky**, by decision, not the player's lake. No ferry.
- **The camera tip** (`Lake.CAMERA_TIP_AT` 600 s of play, `CAMERA_TIP_HOLD` 8 s,
  `_camera_tip_step`, `Text.CAMERA_TIP`): a `TourCard` hint with the arrow on the camera lock
  button, "Here you can choose between camera locked on player, or free roam." The game runs
  on; a click on the card (`TourCard.closable`: the card takes that click, everything else
  passes through) or on the button, or 8 s, takes it down for good. Waits while a board, the
  menu, a tour, the first steps, a moment, the letter or the ending is up, and in pad mode.
  Saved as `camera_tip`; **a save without the key reads as not seen** (Richard's call, against
  the tours' rule), so old runs past ten minutes get it on their next load. A borrowed lake
  is marked seen. `TourCard` now puts its arrow **under** a target at the top of the screen,
  pointing up, and the card under the arrow. Machine drafts for the seven other languages.
- **Decoration views checked against the packs** (`build_pack_decor.py`, `LATE`): the
  **Side Desk**'s side was the open-drawer drawing (1153) standing as shut and its "back"
  was its shut side (1152); now side 1152, back 1151, side open 1153. The **File Cabinet**'s
  "side" was its back (1325); now side 1327, back 1325, side open 1326. The **Drawer Desk**
  gains the side the pack drew (409, open 410). **Views added after a piece was built go in
  `LATE`**, appended after every view and mirror it had, so a saved `view` index never moves:
  no `SAVE_VERSION` bump. Where the pack draws no open counterpart (Drawer, Nightstand,
  Coffee Table, Corner Desk and Microwave sides) the face stays shut and E does nothing on
  it, by decision.
- **Every rug turns** (`TURN`: the object rotated a quarter, the packs drawing a rug one way
  round only): Gold Rug, Blue Rug, Dotted Rug and the three new ones are `ROTATE`.
- **The fourth batch of finds**, off the tagger (`art_source/packs_local/tagger/pull`, the
  previous pull kept as `pull_20261001`): Rose Vase and Leafy Pot (299 is two objects, cut
  apart), Floor Lamp (332, cut off its cushions; no lit drawing, so no switch), Drinks Cart
  (428), Striped Rug (1097), Oval Rug (1112), Runner Rug (2156), and the tagger's
  "Decorated Table" set (1232 front, 1229 side, mirrored), named as tagged. **Appended to
  `PIECES`, so every old find keeps its def index: no `SAVE_VERSION` bump, and a save made
  before carries none of them in its water** (a new game deals them). Dealt by tier like the
  rest: 60 finds, early / mid / late 6 / 38 / 15, none closer than `FIND_APART`.
- **Shed dogs find their way** (`ShedRoom._path_grid`, `_route`, `_reaches`, `_line_clear`,
  `PATH_RES` 2, `PATH_LOOK`, `DOG_BLOCKED` 0.7 s): an `AStarGrid2D` over the floor at two
  points a cell, solid where `_dog_may_stand` refuses, memoised on the furniture and the
  dog's `over`; the path is pulled straight wherever the next point is in plain sight. A
  dog only picks a spot on its own patch of floor (a flood-fill label), and a walker in the
  way is slid past and, after `DOG_BLOCKED`, thought round. **The lake's dogs keep their no-
  search rule**; the shed's clutter is what needed one. Supersedes "a slide that makes no
  ground gives up and picks a new target".
- **The find-caught card fades as one**: see The Find-Caught Card.
- `test_lake` guards the board order and the Catch row, the camera tip (none before ten
  minutes, up on the button after, gone for good on a click, the save rule), a shed dog
  walking round a sofa, and the card's faded group.

### Greyed Rows, the Dogs' Wood, the First Pigeon, the $ (2026-10-09, `/grill-me` with Richard)
- **A row that cannot be bought is greyed** (`ShopSkin.drawn_back`, `OFF_SATURATION` 0.55,
  `OFF_VALUE` 0.85; pick C of three rendered off the real shop): the plate (`tones_of`'s second
  face, so the wash room's hose row too), the price tag and the price's ink. The writing on the
  plate is untouched; the lit edge still marks affordable and Strength keeps its gold rim.
- **The dogs card's far wood is a wall** (`ShopCard.WOOD_TALL` 0.7, `WOOD_LEAST` 0.75,
  `WOOD_BASE`; pick D over the wash room's painted wood): the blocks were a few px with sky
  through every gap.
- **The catch that brings up the pigeon's cue card always shows the head and holds it**
  `Lake.FIRST_POP_HOLD` (2 s, `PigeonPop.pop`'s `hold`); later catches keep the roll and
  `PigeonPop.HOLD`.
- **The money plate reads "$12345"** and its spend tag "-$1700" (`HudSkin.money_text`), corner
  plate and the purse over the shop alike; the figure drops a rung rather than run off its
  panel (`fitted_size`, `MONEY_PAD`). The coin stays.
- `test_lake` guards all four.

### Rain (2026-09-25, `/grill-me` with Richard)
Up to five showers a run, **atmosphere only**: no catch, pay, price, boat or dog changes, and
the sim is untouched. `scripts/weather.gd` (`Weather`, z 22 over the birds) and
`scripts/puddles.gd` (`Puddles`, z 3 on the island), wired in `Lake._start_weather`.
- **When**: `Weather.MOST` 5 a run, rolled at random (`FIRST_AFTER` 4-12 min, then `GAP`
  6-14 min of play), each shower `LASTS` 1-2 min, easing in over `RISE` and out over `CLEAR`.
  The clock stops behind the menu; a shower already falling keeps falling there. **A shower
  never starts** over the intro, the first steps, a tour or the ending (`Lake._rain_held`,
  tried again `HELD_RETRY` later). Saved as `showers` and `rain_next`; absent reads as none
  yet, so no `SAVE_VERSION` bump. A shower in progress is not saved.
- **The light goes grey through the day, not beside it**: `DayCycle.overcast` and `flash`,
  folded over the hour in `DayCycle._weather` (`RAIN_TINT`, `RAIN_INK`, `FLASH_TINT`,
  `FLASH_INK`). Everything that reads the day (the world's modulate, every shadow) follows
  with no wiring.
- **Where a drop lands is decided when it is born**: a spot in the view is picked and asked
  once what is drawn there (`Weather._landing`): a roof, a floating piece
  (`LakeGrid.perch_point`, `PIECE_ODDS` of a tile's drops), the lake (`WaterSplash.ripple`,
  held under `RING_SHARE` of the splash layer's cap through the new `ripples_up`) or the
  ground. Only drops in view cost anything. Streaks and splash bits are whole art pixels.
- **Roofs are silhouettes measured off the art** (`_tops`, topmost opaque row per column):
  the hut, the crate (`Yard.roof`), the pump (`Pump.roof`) and the piers' boxes
  (`Dropoff.roof`). Walkers and hulls are a rounded box over their drawing. `DRIP_ODDS` of
  roof drops run to the eave, hang `DRIP_HANG` and fall to the picture's foot.
- **Puddles**: `COUNT` spots found once off a fixed seed on the island's dry ground, clear of
  the water's edge (`OFF_WATER`), the hut, the crate and the pump. They fill over `FILL` s
  of rain and dry over `DRY` s after it. Each is a spill of `LOBES` overlapping ellipses with
  its edge bent by a coarse noise (`WOBBLE`), laid once as cells with the wetness each needs,
  so it grows and dries along its own bays and arms (Richard: "too round and perfect"; four,
  bigger). Whole art pixels in the clean ramp, see-through;
  rain on one rings it. **Reflections**: a clipped child (`clip_children`) draws the hut, the
  pump, the angler and the dogs upside down about their feet (`Angler.reflect_on`,
  `Dog.reflect_on`), only where a puddle is. Nothing saved.
- **The mirror is clipped to the water alone** (`Puddles.Pools`, 2026-09-25): it was clipped
  to the puddles' whole drawing, which held the drop spots on the sand and the rain's rings
  too, so the hut and the angler flickered upside down all over the beach after a shower.
  The spots draw on `Puddles`, the water on `Pools` (the clip parent), the rings on `Rings`
  over the mirror. `test_lake` guards the mirror's parent. **And `Pools` is hidden until a
  cell of water is drawn** (`_first_wet`): a clip parent that draws nothing clips nothing, so
  as a shower began and as the puddles dried the whole mirror (the hut sheared upside down,
  the angler, the dogs) drew straight onto the island.
- **Grass only, one colour, three** (same day, Richard): puddles lie on the lawn
  (`Iso.on_lawn`), `COUNT` 3, drawn in `water_clean_light` alone at 0.85.
- **The sand soaks instead** (`Puddles.sand_wet`, `SOAK` 25 s, `SAND_DRY` 90 s): pushed to
  every `Ground` through `set_wet`, where `ground.gdshader`'s `wet_sand` multiplies sand
  texels by `wet_ink` and leaves the lawn alone. Before it catches up, every drop on sand
  leaves a dark whole-pixel spot (`MARK_LIFE` 7 s, `MARKS_MOST` 600) that fades as the
  beach darkens under it.
- **Lightning**: in a shower over `FLASH_FROM`, a roll every `FLASH_GAP` at `FLASH_ODDS`; two
  pulses, bright then an echo, and thunder `THUNDER_AFTER` later. No bolt, by decision.
- **Elsewhere**: the wash room's backdrop rains and rings its lake off `Weather.now` and
  greys and flashes its modulate; the shed's window shaft thins to `RAIN_SUN` and flashes by
  `FLASH_SUN`; the menu's lake rains as the lake does.
- **Sound is Nuven's, not built**: `Weather` loads `assets/sfx/rain.ogg` and
  `thunder_1..3.wav` on the Ambience bus when they exist and is silent until then. Add them
  to `tools/build_sfx.py`'s `PLAN` (rain as a loop) when the recordings arrive.
- **Out of scope, by decision**: any gameplay effect, a drawn bolt, a settings toggle, rain on
  a timer.
- **Numbers are first guesses** for Richard's eye. **Open**: the wash room's backdrop greys
  twice if the room is opened mid-shower (its `tint` is read off a day already grey).
- **What a shower costs** (2026-09-26, `/grill-me` with Richard: "performance drops a lot
  during rain"; `bench_frames` `BENCH_RAIN=1`, RTX 5060 Ti, 1080p, full lake): 2.86 ms mean
  dry, **6.64 ms** in a shower, **4.90** after the fix. `BENCH_OFF=rings|puddles|sky|raindraw`
  split it: the rain's own logic was 0.2 ms and its drawing 0.5, and **the rain's ripple rings
  were 2.4 ms** — each of up to 45 rings ran 20 `WaterSplash.wet_at` shore tests a frame and
  was its own draw command. Now a ring asks once at birth whether its widest extent is all
  open water (`_ripple_open`), and every ring goes in one triangle array (`_band_into`).
  **The look did not change, by decision.** Batching the drops' `draw_rect`s into one array
  was tried and measured no gain (Godot batches them already), so it is not there.
- `test_lake`'s `_stage_rain` guards the cap, the ease-in, the grey light, drops under the
  cap, no money or pollution moved, roof/water/ground landings, puddles on allowed ground and
  filling, the flash coming and going, and a saved count held to the cap. Probe:
  `tools/shot_rain.tscn` (desktop build, `--fixed-fps 60`, own save, under its own node)
  saves `tools/last_rain_{far,near,flash}.png` and `last_rain.log`.

### The Tornado (2026-09-30, `/grill-me` with Richard)
**Superseded in part 2026-10-05 — see The Tornado, Second Pass below**: the 80% gate, the
2-3 a run and the time gaps, the three hits, "the third puts what it carries into that net up
to its room", the hit's two pieces shaken loose, the wander on sines and its speeds, and
the clockwise turn.
A late-game event: a waterspout comes down on a nearly cleaned lake, stirs the rubbish up and
is tamed with the net. `scripts/tornado.gd` (the event, ported from the mock's harness),
`scripts/tornado_look.gd` + `shaders/tornado_spout.gdshader`/`tornado_water.gdshader` (the
drawing, the mock's **look D, approved as it is**), `scripts/tornado_debris_draw.gd`, wired
in `Lake`'s "The tornado" block. The mock (`tools/tornado_mock/`) was the record until it was deleted on 2026-10-03.
- **When**: once the meter reads `Tornado.GATE` (80%) cleaned, `MOST_RANGE` 2-3 a run (rolled
  once, saved as `tornado_most`), the first `FIRST_AFTER` 20-70 s of play after the gate,
  then `GAP` 150-300 s. Never over what `_rain_held` holds, a board (`_panelled`), the ending,
  the glide or the wildlife moment; a due one is asked again every `HELD_RETRY`. **Only the
  game's own lake rolls them** (`get_parent() == root`, or `tornado_schedule`); a harness or
  probe starts one with `start()`.
- **Its own storm**: `Weather.storm`/`clear_storm`, the shower's rain, grey light and
  flashes, **not one of the five showers**. `BREW` 6 s of storm, then the touchdown (2 s,
  the look's gather), with a strike at touchdown and at the vanish.
- **Wanders within reach**: round the island on smooth sines (`_wander`), between
  `GROW_LEAST` (2.2) tiles past the shore and the net's range less `RANGE_SPARE` (1.2), so
  it is always castable from the beach. `SPEED_ROAM` 60 px/s (the mock's 72 was for a 16 s
  film), `SPEED_HURT` 34 after a hit.
- **The lake is the mock's**: the top piece of a tile under the foot (`LIFT_REACH` 0.9,
  never a find, tier 3 at most) lifted with `LakeGrid.take` into the orbit (`CARRY_MOST`
  14), flung `FLING_EVERY` 2.5-4.5 tiles onto floating water and `insert`ed as that tile's
  top (it can dirty cleaned water; finds under a lifted piece surface on their own), pieces
  round it shoved tangentially and bumped. The meter moves per piece (`filth_moved`), the
  filth map is remapped on `REMAP_EVERY` (0.5 s) through the worker-thread path, never per
  piece. Rings only, no crown splashes (look D's harness options).
- **No piece is ever lost**: a piece is in the grid, the orbit, the air or a net's catch.
  `carrying()` (orbit + air) keeps `_all_landed` false, so the ending cannot fire under it.
  A throw with nowhere to land goes back to the tile it came from.
- **Tamed by three landings**: `CastNet.touched_down` (new, after the landing sweep) whose
  mouth touches the foot (`FOOT` 30x15 px, `CastNet._touches`); two within `HIT_APART`
  (0.5 s, the double cast) are one hit. Each hit steps it down (`HIT_STRENGTH` 0.74, 0.5),
  knocks it away from the angler and shakes two pieces loose; the third puts what it carries
  **into that net up to its room** (appended to `catch`, no `caught` signal: the meter already
  moved at the lift) and sheds the rest onto the water, and the look's vanish runs.
- **Untamed**: after `LIFE` (60 s) the same vanish, everything carried dropped onto the water.
  The look is handed three hits for it, so its vanish carries a small last burst; accepted.
- **Holds**: while one is out every hull is `moored` (a sailing one finishes its leg and
  stays) and every dog dozes, its mouthful put in the crate; kept up each frame so a hull or
  dog bought mid-storm is held too, let go on `ended`. Wildlife treats the foot as a threat
  (ducks too); fish are scared off it every `SCARE_EVERY`.
- **Not saved mid-event**: `save_game` calls `settle_now()` first (every carried piece put
  back on the water, the event ended and counted), the menu's pose does the same, and the
  autosave waits while one is out (the last save already has those pieces in the water).
  Saved: `tornadoes`, `tornado_next`, `tornado_most`; absent reads as none yet. No
  `SAVE_VERSION` bump.
- **The one change to the look**: painting the cloud cell by cell was ~45 ms of GDScript a
  frame (the mock filmed at a fixed step). The same painters now run on a `WorkerThreadPool`
  task over a copy of the frame's shape (`_pump_paint`, `_paint_off_thread`) into one
  triangle array each for the cloud and the lip, drawn a frame or three late and shifted by
  whole art pixels to follow the base. The mock's fixed `COLLAPSE_AT` (12.5 s) is read off
  `since_hit` instead, and its eye log is gone. Nothing else in `look_d.gd` moved.
- **Sound**: the storm's rain and thunder (Ambience). `Tornado.WIND_SOUND`
  (`assets/sfx/wind.ogg`) plays on the Ambience bus while it is down once Nuven records one;
  silent until then.
- **Cost** (`bench_frames` `BENCH_TORNADO=1`, RTX 5060 Ti, 1080p, full lake, touchdown and
  the start of the roam): 5.89 ms mean, p99 7.95, worst 9.67, against 3.3 with none. Inside
  the bar. Before the threaded paint: 63 ms.
- **Deleted 2026-10-03 (The Pre-Release Cleanup).** **F9 in a debug build calls one down at once** (`Lake._unhandled_input`), whatever the
  meter says, for judging whether `GATE` should come earlier.
- **First guesses**: `GATE`, the counts and gaps, `LIFE`, `SPEED_ROAM`, the grow band,
  `FOOT`, `BREW`. The rest are the mock's numbers.
- **Out of scope, by decision**: feeding ducks and fish (its own pass), wind recordings,
  new art, any price or sim change, saving a tornado in progress.
- `test_lake`'s `_stage_tornado` guards the gate, the hold, the cap, the storm being
  uncounted, lift and fling keeping every piece, the carry cap, a miss not hitting, the
  ending waiting, three hits collapsing it into the net, the fleet and pack held and let go,
  the untamed wander-off returning every piece and the meter, the reach, and a save ending
  it with everything back in the water and the count saved. Probe: `tools/shot_tornado.tscn`
  (desktop build, `--fixed-fps 60`, own save, under its own node) forces one on a lake 88%
  cleaned, casts the real net at it three times and saves
  `tools/last_tornado_{touchdown,roam,hit1,hit2,collapse,calm}.png`, frames in
  `tools/film/tornado/` and `last_tornado.log`; `ffmpeg -framerate 30 -i
  tools/film/tornado/f_%04d.png ... tools/last_tornado.mp4` makes the film.

### The Tornado, Second Pass (2026-10-05, `/grill-me` with Richard)
More often, from earlier, bigger, wilder, and every hit pays. Supersedes the parts of The
Tornado named at its head.
- **Four a run, by the meter** (`Tornado.MARKS` 20 / 40 / 60 / 80% cleaned, each rolled
  `MARK_JITTER` 0.03 either way): the first as the meter passes 20%, the next at 40%, and so
  on, `CALM_FIRST` (2 s) after nothing holds it (the old holds). `count` is how many marks are
  behind; a mark the meter is already `MARK_SKIP` (0.12) past is **skipped, not owed**, so a
  save from before the marks or a rushed stretch does not get tornadoes back to back.
  `tornado_next` is the rolled share now (an old save's seconds are rolled again);
  `tornado_most` is no longer saved. No `SAVE_VERSION` bump.
- **3 / 4 / 4 / 5 hits** to tame the run's first to fourth (`HITS_NEEDED`), the later ones
  meeting a wider net. Untamed it goes after `life()` = `LIFE` 40 + `LIFE_PER_HIT` 12 a hit
  (76 to 100 s).
- **It starts big and shrinks** (`SIZE_START` 1.5, `SIZE_LAST` 0.5, `_size`, eased): each
  hit takes it a step, reaching 0.5 with one hit to go. Height, radius, the foot a net must
  touch, the look (column, eye, cloud, skirt, rings, plumes: `TornadoLook._size`, every
  length multiplied, the pixel grid untouched) and what it carries (`carry_most()`,
  `CARRY_MOST` 14 times the size: 21 to 7) all follow. Strength no longer steps down with
  hits (`HIT_STRENGTH` gone); it only takes a hit's jolt. The look's hit beats read
  `weak` (1 down to 0.65 over the hits) and `hit_no` from the tornado, since the count of
  hits differs per tornado.
- **It hunts** (`_hunt`, `_pick_goal`, `_richness`): `HUNT_SAMPLES` spots in its band (the
  old band: `GROW_LEAST` to the net's reach less `RANGE_SPARE`, always castable from the
  beach) within `HUNT_ARC` of where it is, scored by the pieces within `HUNT_REACH` tiles (the
  grime is where the rubbish is) over distance; it darts to the best at `SPEED_DART` (150,
  easing up over `DART_RISE`, slowing inside `ARRIVE_SLOW`), churns over it at
  `SPEED_CHURN` for `CHURN` seconds, then hunts again. Moved in the band's own terms, so a
  goal round the island is reached round the ring. **Chaos**: the heading wanders up to
  `JITTER_TURN` off the line, the foot shakes `JITTER_PX`, the column snakes and leans harder
  and the look's top lags the foot further. Supersedes `_wander`, `SPEED_ROAM`, `SPEED_HURT`.
- **A hit reels it, then it flees**: knocked `KNOCK` (40) away from the angler, and after the
  hit's beat it darts to a new goal off the way it was going (`FLEE_DOT`) and `FLEE_CLEAR`
  from the old one.
- **Every hit puts everything it carries into that net, past the net's room, its Strength
  and its Catch** (`_into_net`, `netted_into`). A hit no longer shakes pieces loose. The last
  hit collapses it as before. Lifting is still up to tier 3: an early-run windfall, by
  decision.
- **The storm tally** (`HaulCount.storm_hit`, `Lake._on_tornado_netted`): from a hit to the
  end of that cast the count over the angler runs past the bag ("38/24") in storm grey-blue
  (`STORM_INK`), with white whole-pixel specks circling it counter-clockwise, a little funnel
  of pixels beside it and a jolt on every hit.
- **It turns counter-clockwise and draws the lake in**: the water's arms used to slide
  *outwards* while their comment said in. Now the water's arms, the skirt, the spout's bands
  and streaks (the twist flipped with the turn, so they still climb, faster: 260 px/s), the
  plumes, the debris orbit, the cloud's arms and eye wall and its ring puffs all turn
  counter-clockwise seen from above, the arms winding in; the water is shoved round and
  drawn in harder. `test_lake` reads the two shader lines.
- **Cost** (`bench_frames` `BENCH_TORNADO=1`): 7.8 ms mean, none over 16.7. The size is not
  the cost: 8.8 at size 1 on a noisy run.
- All numbers first guesses for Richard's eye. Out of scope: new art or sounds, more
  flinging, the sim and prices, saving one mid-event.
- `test_lake`'s `_stage_tornado` guards the marks, the skip, the four, the hit counts, the
  CCW shader lines, the carry at size, a goal in the band, every hit netting all it carried
  past the room, the storm tally, the shrink, the flee, and the rest as before.

### Pigeons in the Tornado and the Shed's Window (2026-10-08, `/grill-me` with Richard)
Fixed for the trailer re-shoot (a pigeon sat beside a funnel), in the game itself.
- **A pigeon at the foot is sucked into the whirl** (`Tornado._pull_birds`, `BIRD_PULL` 1.8
  tiles, `BIRDS_MOST` 4): taken out of the flock (`Flock.pull`, no pay), it orbits on the
  debris' own fields, flapping `BIRD_FLAP` times faster, drawn by the look among the debris
  through the dict's `paint` callable (`_paint_bird`). **One sitting within `BIRD_FLUSH` (3.5) that
  cannot be taken is frightened off** (`Flock.flush`), and while the funnel is down no bird
  picks a perch within `Flock.AVOID_TILES` (4) of the foot (`Flock.avoid`, set by the lake).
- **A hit nets every bird in the whirl and pays it** (`bird_netted` -> `Lake._on_bird_caught`:
  bird pay, coin, the head pop at its odds). The untamed end, a save or the menu's pose let
  them go flying off (`_let_birds_go`, `Flock.release`). Not carried pieces: `carrying()`, the
  ending and the carry cap ignore them.
- **The shed's window light starts under the roof** (Richard: the glow sat on top of the left
  wall's plank): `_window_at` is the plank's inner edge, and `shed_light.gdshader`'s `inside`
  cuts every light to inside the room's moulding, so no plank round the room glows.
- `test_lake`'s `_stage_tornado` guards the pull, the flush, not carried, the perch rule, the
  hit paying and the release.

### The Ground Has Volume (2026-10-01, `/grill-me` with Richard)
The lawn and the beach read flat: one green with sparse blades, one sand. Picked off
`tools/last_ground_volume_mockup3.png`, panel **1b** (`tools/ground_volume_mockup.py`, offline,
three passes: A raised turf, C lit mounds and dunes turned down; B clumps quieter and with a
lighter dark; the sand's bands laid along the water line, tide line, fewer ripples). All of it is
`shaders/ground.gdshader`, both shores; `Ground.coverage_at` and the props are untouched.
- **The lawn grows in clumps** (`blade_grass`, `CLUMP_CUT` 0.7, `CLUMP_SHARE` 0.42,
  `clump_scale` 5 art px): where a coarse noise passes the cut, blades stand 3-4 tall, root
  pixel `lawn_low`, body `lawn_soft` (half way low to mid: Richard's "lighter dark"), tip
  `lawn_hi` (`Ground.lawn_shades`, one more step up the pack ramp) on the clump's east side and
  `lawn_light` on its west. Between clumps the old sparse two-pixel blades. The bank keeps its
  tone blotches under them.
- **The clumps sway** (`gust_*`, `storm`): a gust noise drifts over the lawn on the stepped
  clock and tips blade tops (row 2 up) one art pixel where it passes `GUST_CUT`. `storm` is the
  day's overcast (`Ground.set_storm` from `Lake._push_daylight`): a lower cut, a faster drift,
  and past half a second pixel on row 3 up, so rain and the tornado both blow harder. The gust
  is read at the pixel, not the blade's root; a blade straddling a gust's edge can tear by a
  pixel for a frame, accepted.
- **The beach is banded by its distance from the drawn waterline** (`shore_at`, mirroring
  water.gdshader's island and bank fractions), so every band runs along the shore. Distances
  are tiles; thicknesses are art pixels across the line, through the distance's own gradient.
  From the water up: the **wet edge**, a dashed **tide line** of wrack at `TIDE_AT` (0.55)
  tiles wandering `tide_wander` with a shell now and then, sparse short **ripples** only in
  patches (`RIPPLE_FIELD` 0.66, `RIPPLE_GAP` 5 px, from `ripple_from` past the tide line),
  scattered **pebbles** (body, lit pixel over, shade down-left) and **shells**, and a pale
  **dry strip** `dry_strip` px under the lawn. The pack slab's texel is still the plain sand.
  Rain's `wet_sand` darkens all of it as before.
- **The wet edge follows the coast wave** (`coast_lap`/`coast_lobes`, copied from
  water.gdshader, `test_lake` holds the two bodies equal): sand the crest covered within the
  last `wet_steps` x `WET_STEP` (6 x 0.6 s) is `sand_wet` if lately, `sand_damp` if longer
  ago, dry after. Nothing saved: the wave is a function of the clock and is read back. So it
  only shows where the water is pulling back; at a crest there is no band. `Ground` is handed
  `Lake.COAST_WAVE*`. **Move the water's wave and the ground's together.**
- **Static, by decision**: the tide line, ripples, pebbles and shells do not change with
  cleaning.
- **Deleted 2026-10-03 (The Pre-Release Cleanup).** **Tuning**: F4's `GroundTuner` has `clump_cut`, `clump_share`, `gust_cut`, `tide_at`,
  `ripple_field`, `ripple_gap`, `wet_step`; bake picks into `Ground`'s constants. Colours are
  shader defaults off the mockup (`sand_*`, `pebble*`, `shell`). All first guesses.
- **Cost** (`bench_frames`, RTX 5060 Ti, 1080p): 3.65 ms mean standing, 4.13 walking, 5.81 in
  a shower, worst 9.0, nothing over 16.7.
- **Re-shot**: `assets/loading_lake.png` and `assets/boot_splash.png` (`shot_loading`). The
  letter's stills still show the old ground.
- **Out of scope, by decision**: a raised turf edge, lit mounds and dunes, the tide line
  following the cleaning, new painted art, prop changes.
- Probe: `tools/shot_grass.tscn` (desktop build) saves `tools/film/grass/now_{isle,bank}.png`;
  its bank spot now stands on the beach. `test_lake`'s `_check_ground_volume` guards the
  uniforms, the wave's two copies being one, the tips' step, the push of the wave and the tide,
  and the storm reaching the sway.

### The Sky in the Water (2026-09-28, `/grill-me` with Richard, off a reference picture)
Picked off `tools/last_sky_mockup.png` (`tools/sky_reflect_mockup.py`, offline, psd-extract
venv python; the sheet still shows lake option C and wash sky option 3 as judged).
- **Clean water mirrors clouds** (`water.gdshader` `sky_reflect`, `sky_tint`, `sky_cloud`,
  `sky_stretch`, `sky_drift`): cloud-shaped patches one step up the ramp, their rim broken
  into dashed rows (option C), drifting in whole art pixels. **Only where the honest map is
  clean** (`honest`, the filth before patches and the lane), on every clean tile from the
  first bay, and faint, by decision: the glints were cut four times for being busy. **This is
  the exception to "no pale strips on clean water"**: the patches are cloud-shaped and one
  ramp step, not streaks.
- **It follows the day** (`Lake._push_daylight`, `Lake.sky_low`): `sky_tint` is the low sky
  swatch for the hour, mixed in at `sky_tint_mix` (0.2). **In a storm they turn to storm
  cloud** (second pass, Richard): `sky_storm` (the overcast) takes them a step down the ramp
  towards `sky_storm_ink` and spreads them wider, and a strike lights them (`sky_flash`). They
  first shrank away in rain; supersedes that. `sky_cloud` went 44 to 26 and the fair-day cut
  up to 0.64 (Richard: toned down, closer to option C). Probe: `tools/shot_rain.tscn` saves a
  nearly cleaned lake as `last_rain_fair.png` before the shower.
- **The wash room's clouds are one noisy mass each** (`build_wash_backdrop.py` `cloud`,
  **reimport after**): a flat base rounding off as it rises, not a heap of round puffs
  ("made of snowballs"). One sun, top left: the mass and each billow lit on their upper
  left, **white the majority**, shade a blue-grey between cloud grey and sky, the base
  melting into shade with no dark band, the thin edge half see-through (`EDGE_ALPHA`) so it
  sits in any sky. Three sets on the sheet: `clouds` (near), `far_clouds`, `wisps`, each a
  layer in `WashBackdrop.CLOUD_LAYERS`. **Every cloud's foot is held above the trees**
  (`CLOUD_FOOT` 0.86 of the open sky, Richard: a tip sat on the ground in the mockup).
- **The wash room's lake mirrors its clouds** (`_draw_cloud_reflections`): each cloud flipped
  under the far shore, squashed by `REFLECT_SQUASH`, dashed rows at `REFLECT_MIX`, only when
  the lake's state is clean.
- **Open**: the wash room's sky is short (the trees start at 12% of the window), so the near
  clouds draw at scale 1. All numbers first guesses for Richard's eye.
- **The sky is left out of the wash room's `DARKEN`** (same day, Richard: the room read darker
  than the lake): the darkening that keeps the grime readable is now a black veil from the far
  waterline down plus the far bank's strip drawn at `DARKEN`, so the sky and clouds keep the
  day's tint alone. Masts standing above the far waterline are not darkened, accepted.
- **A storm darkens and fills the wash room's sky** (same day, Richard's picks 1 and 2 of
  three): the clouds are multiplied towards `STORM_INK` with the rain, so white goes grey-blue
  and the shade goes darker, and two storm-only layers (flagged `true` in `CLOUD_LAYERS`) come
  in one cloud at a time as the rain rises (`_cloud_shown`). Flat overcast was the option not
  taken. `shot_pump` saves `tools/last_wash_room_{storm,flash}.png`.
  **Second pass** (Richard: much more cover, darker, the flash hitting the clouds): 28 storm
  clouds in three layers, `STORM_INK` 0.36-0.48, the sky's steps sinking to `STORM_SKY` by
  `STORM_SKY_MIX`, and a strike lighting the clouds from inside (`FLASH_CLOUD`, `_flash_lit`)
  more than the sky behind them (`FLASH_SKY`).
- `test_lake`'s `_check_sky_reflect` guards the honest-map rule, the push, the hour's tint and
  the clouds' feet. Probes: `tools/shot_pump.tscn`, `tools/shot_nature.tscn`.

### Songbirds on the Shores (2026-10-03, `/grill-me` with Richard)
Kelano Studio's Wild Birds pack (bought, `art_source/birds/`): sparrow, tit, bluebird and
cardinal. **The cockatoo and the parrot are not used, by decision.** `Wildlife` "songbirds".
- **Art**: `tools/build_wildlife.py` `songbird` reads the four 32 px sheets (fly 4, idle,
  peck and walk 5 frames each), halves them by the frog rule (`halve_inked`: each 2x2 block
  to its commonest colour, but an edge pixel keeps its block's darkest pixel if that is
  outline-dark, `BIRD_INK`, so the painted outline survives) and mirrors them to face left
  like every critter. They go onto `critters.png` as `bird_<species>_<anim><n>`, the ground
  poses on one shared crop and the flight on another, so a bird does not shift between
  frames. **The painted colours are kept** (Richard), not recoloured onto the palette.
  Drawn at one world px a painted px (`BIRD_SCALE` 0.5 of the critters' 2), about 16x12.
  Contact sheet: `tools/last_bird_sheet.png` (not written by the builder; the session's).
- **Where**: the sand of both shores and the island's lawn (`_bird_ground`), never the water
  and never the bank's lawn, off the hut, the pump, the hive and the crate.
  `_find_bird_spots` deals `BIRD_SPOTS_PER_SHORE` spots round every shore spot, up to
  `BIRD_WATER_REACH` (3.5) tiles inland, each keeping its shore spot.
- **When**: a spot is open only while its shore spot's water is clean on the honest map
  (Richard: "they should come in as there is clean water close"). The count is
  `ceil(SONGBIRDS_MOST * stage)` (24) from the first clean water; one flies in at a time,
  `BIRD_GAP` apart, from `BIRD_FROM` off the lake. Species in equal shares.
- **Behaviour**: on the ground a bird idles, walks a little (pulled back to its spot) or
  pecks one to `PECKS_MOST` times, **each peck's lowest frame on the beat** (`_peck_lead`,
  `_bird_on_cue`, the frogs' cue rule). Something moving inside `BIRD_WARY` (2.6 tiles)
  sends it walking off; inside `BIRD_SHY` (1.4) or a net landing, it flushes to another open
  spot `BIRD_FLUSH_LEAST`..`BIRD_FLUSH_REACH` tiles off, or off the lake if there is none.
  They read the walkers' threats only, as the ducks do: a ferry at the island berth would
  flush the island's birds every few seconds. Still walkers are obstacles.
- **Shadows (One Sun)**: on the ground the bird's own picture laid by `_lay` in the ink of
  what it stands on; in flight the silhouette thrown from the ground point plus
  `Shade.drop` of its height, shrunk and thinned with it (`BIRD_SHADE_ALT`). Grounded at z 6
  with the other animals, flying at z 20, shadows on the ground layer.
- **Sound** (Ambience bus, within `Dog.HEAR`): `Sfx.play_songbird`, one of the forest chirp
  takes on its own `SONGBIRD_GAP` at `SONGBIRD_DB`; `Sfx.play_flush`, the pigeon's wings at
  `FLUSH_DB` and pitch 1.25 on `FLUSH_GAP`.
- **A songbird counts for the wildlife moment** and is likely the first animal of a run.
- Credited as "Kelano Studio" on the credits board (not asked for; the Kipperfalcon rule).
- **Out of scope, by decision**: the cockatoo and the parrot, palette recolouring, landing on
  water or perching on rubbish (the pigeons'), the bank's lawn, sand prints, new recordings.
- All numbers first guesses. `test_lake`'s `_check_songbirds` guards the spots (dry, none on
  the bank's lawn, some on the island's), every frame, no cockatoo or parrot, none before the
  first clean water, one at a time, only to an open spot, the landing on dry ground, the
  peck's lead, the walk away and the flush, and the shadow code. Probe:
  `tools/shot_nature.tscn`'s "birds" stage saves `tools/last_nature_bird_<species>.png` and
  `last_nature_bird_fly.png`.

### The Land Animals From Packs (2026-10-05, `/grill-me` with Richard)
Bought and free packs in `art_source/Fauna`, cut by `tools/build_wildlife.py` (`bunnies`,
`snakes`, `canids`, `capybara`, `peacock`) onto `critters.png`. **Supersedes the rule-built
rabbits and fox** (Seven Visual Fixes, Eight More Fixes: their art, `rabbit_*`/`fox_*`,
`RABBITS_MOST`, `FOXES_MOST`, the fox's bent legs and the rabbit's drawn rows are gone).
`Wildlife`'s "the land animals" section, one list, `KINDS` a table per kind.
- **Art**: bunnies (Toffeecraft: Brown2Color, BunnyBlack, WhiteBunny, idle 12 and run 8),
  snakes (Carysaurus: SnakeBlue, SnakeCorn, a 7-frame slither), fox (MiniFox Original) and
  wolf (MiniWolf Metal) (LapizWCG off LYASeeK: idle row 0, run row 1), capybara (Rainloaf: side,
  front and back walk, idle, sit, run, the lie-down; no grid, so each drawing is found by its
  ink and set on its feet in a 32 cell), peacock (walk side, front and back, tail folded and
  open; Pixeline). Attack, death, howl, jump, hurt, kick and stomp rows are not cut. Every group shares
  one crop centred on its first frame's feet (`_stood`), every picture faces left, front and
  back views are never mirrored. Facing through `Flock.facing_of`.
- **Sizes, by decision** (Richard's pick C off `tools/last_fauna_lineup.png`): everything at
  one world px a painted px (`KINDS` `scale` 0.5) but the fox and wolf at two (`scale` 1.0):
  painted, they were smaller than the bunny. The folded peacock's tail is 35 px long and kept
  whole.
- **Where and when** (a spot opens only by honestly clean water; counts follow the clean
  share, `_want`, or the meter, `_want_from`): bunnies the bank's lawn by the trees, 14, from
  the first clean shore, and 2 on the island's lawn from 70% cleaned (`ISLE_BUNNY_FROM`);
  fox 5 and wolf 5 from 40% (`CANID_FROM`, was 60% for the fox), each new one on the clean
  bank spot furthest from the others (`_spread_spot`), patrolling along the beach a waypoint
  every `PATROL_STRIDE` shore spots so it never cuts across the water; snakes 8 on the bank (on its grass since 2026-10-06, see Wildlife Sizes below) from the first clean shore, **never the island** (Richard:
  "no snake on main isle"); capybaras 3 pairs from 50% (`CAPY_FROM`); the
  peacock 1 from 80% (`PEACOCK_FROM`), on the island's lawn in front of the hut
  (`_peacock_spots`).
- **Out of the forest, and up onto the grass** (same day, Richard: "animals should come from
  the forest like they are rediscovering the lake, and they should also be around the grass
  and forest sometimes, not just on the beach"): every bank animal, snakes included, starts
  `FOREST_FROM` tiles past `Ground.WOOD_FROM` and walks out to its home, **unseen until it
  steps clear of the trees at the woods' edge** (`arriving`; its fade held at 0 while past
  `WOOD_FROM` or in a tree's clash), so it is never drawn wrongly against the trunks it walks
  through; a capybara follower stays hidden while its lead does. The first-wildlife moment
  frames that edge (`edge`), not the home. The bank's ground reaches `FOREST_REACH` (2.5)
  tiles into the woods, and each rest a bank animal may wander up onto the grass or to the
  forest's edge (`INLAND_ODDS` by kind: bunny 0.15, fox and wolf 0.35, capybara 0.2, snake 0.3)
  and then back to its ways. A snake's home is on the grass, never the sand (2026-10-06, see
  Wildlife Sizes below). **The island's bunnies and
  the peacock walk out from behind the recycle box** (Richard: "peacock and bunnies can spawn
  behind the box and just come out walking"; `_out_of_the_box`, `_crate_box`), unseen while
  their drawing overlaps the box's, on their way to their spot. Until it is out it neither
  fans its tail nor steps aside for a walker (`arriving`).
- **Snakes 15% smaller** (Richard, same day): `build_wildlife.py` `_shrink` (`SNAKE_SHRINK`
  0.85), box-filtered, alpha cut, snapped back to the picture's own colours, picked off
  `tools/last_snake_sizes.png` over nearest, which broke the thin body's bands. 32x18 a frame.
- **Behaviour**: a bunny runs (bank: into the trees, fading; island: across the island); the
  fox and the wolf trot off into the trees; a snake slithers `SNAKE_AWAY` tiles along the sand
  and stays. **A capybara and the peacock never run**: a capybara walks out of a walker's way
  (`_make_room`, inside `ROOM` tiles), and the dogs walk round it (`Dog.calm`, pushed clear
  the way a dog gives way to the angler, `CALM_REACH`); the peacock does neither since
  2026-10-06 (see Wildlife Sizes below). A net landing frightens neither.
- **Capybaras are pairs**: a lead and a follower (`"lead"`), the follower behind and beside,
  catching up at a run. Each rest the lead may set off for the island (`CAPY_VISIT_ODDS`):
  down to its spot's water, straight across to the island's spot facing it
  (`_isle_spot_for`), up onto the island, `CAPY_STAY` there, and back. They swim the dogs'
  way: cut at the waterline (`CAPY_SINK`), bobbing, a foam collar, the ferry's HullFoam streak
  (`_lay_streaks`, `Dog.STREAK_LONG`/`WIDE`) and one ring going in (`Dog.ENTRY_SPAN`). Rest
  poses idle, sit or lie, settling in and getting up through the sheet's own frames.
- **The peacock fans its tail** at the angler or a dog inside `PEACOCK_NEAR`, turned to them
  (front, back or side, the open-tail frames strutting at `PEACOCK_STRUT_FPS`), and folds it
  `PEACOCK_HOLD` after they leave.
- **Trees, rocks and buildings** (Richard: "mind the trees and rocks, so they dont clip or
  overlap the sprite incorrectly"): `Ground.clashes(feet, half, tall)` is true for feet in a
  tree's or rock's tile, a drawing over a prop's ink with the feet behind its base, or a
  drawing under a south-wood tree's ink with the feet in front of it (the cover layer). Every
  step and every target asks `Wildlife._blocked`, which also refuses any overlap with the
  buildings' drawn boxes (`Lake._wildlife_buildings`: hut, crate, pump, hive, piers), since
  the island's animals are on a layer the walkers' sorting does not reach. A blocked step is
  turned `SIDESTEPS`; blocked every way, the walk gives up after `STUCK_TIME`. A fleeing bank
  animal and a capybara's swim ignore it.
- **Animals go behind the plants** (same day, Richard: "make sure animals go behind the
  bushes and vegetation"): Flora is one batch at z 3 under every animal, so each frame
  `Wildlife._cover_plants` hands every grounded animal's drawn box (land animals, frogs and
  turtles out of the water, songbirds on the ground) to `Flora.cover` and each
  `Ground.cover`, and every land plant or ground tuft whose foot is lower on the screen than
  the animal's feet and whose picture overlaps it is drawn a second time on an `Over` child
  at `Flora.OVER_LAYER` (7): over the animals (6), under the walkers (9). The same quads,
  colours and sway material as the batch, so the copy lies on the plant; floating pads are
  never redrawn, standing reeds are. Only rebuilt when the set changes. **Known**: a plant
  between two animals is drawn over the one in front of it too; rare, accepted. Trees and
  rocks stay `clashes`' and the cover layer's.
- **Cost** (`bench_frames` `BENCH_CLEAN=1`, RTX 5060 Ti, 1080p): 7.4 ms mean, the wildlife
  about 1.2 ms of it (`BENCH_OFF=wild` 6.2). The plant pass alone was about 1 ms until it
  was held to the animals on screen, a 4x4 cell window and int cell keys (`Flora.CELL_KEY`).
- **The turtle is Toffeecraft's TurtlePaid pack** (same day, Richard bought it; supersedes the rule-built
  turtle, its `turtle_sit`/`_up`/`walk`/`tuck`/`swim` frames, `_nod` and the drawn flippers
  `_turtle_flippers`, in The Lake Fills With Life and The Lakebed Through Clean Water). Idle,
  Sit, Sleep, Hide and Walking (`build_wildlife.py` `turtles`, one crop), drawn at one world
  px a painted px (`TURTLE_ART`). **The head bobs to the song**: idle and sit play one cycle a
  beat (`_beat_frame`), the sheets' head up at the cycle's start, half of them half a beat
  behind (`nod_seed`), the old nod's rule. At rest it rolls idle, sit or sleep
  (`TURTLE_POSES`, `_turtle_rest`); sleep breathes at `TURTLE_SLEEP_FPS` with the pack's Z's.
  A fright on land plays Hide into the shell, holds, and plays it back out over the tuck's
  last stretch (`TURTLE_HIDE_FPS`). On the water it swims the dogs' and the capybaras' way:
  cut at the waterline (`TURTLE_SINK` of `TURTLE_INK`, the walking turtle's own 15 px: the
  crop is padded for the Z's), bobbing, a foam collar, the ferry's streak (`_lay_streaks`
  takes the turtles too) and one ring going in. Dived (`UNDER`) it is its walking frame drawn
  through the water as before, its bed shadow the same picture. Attack, Die, Hurt, Jump and
  LieDown are not cut.
  **Slow, and mostly still** (Richard: "walk much slower to match the feet animation... idle
  much more than walk and swim"): a walk cycle carries the body about 2 painted px, so the walk
  is `TURTLE_WALK` 2.5 px/s with a frame every `TURTLE_STEP_PX` 0.3 px; swimming 5 px/s,
  paddling on the clock (`TURTLE_PADDLE_FPS` 6). Basks run `TURTLE_BASK` 25-60 s, a bask ends
  in the water only `TURTLE_TO_WATER` (0.2) of the time and a short shuffle along the sand
  otherwise, and a turtle in the water paddles on only `TURTLE_PADDLE_ON` (0.25) of the time.
- **Shadows**: `Shade.lying` in the land ink; a swimming capybara's cut picture in the water
  ink at `FLOAT_SHADE`. Every new kind counts for the first-wildlife moment.
- Nothing saved, no `SAVE_VERSION` bump. **Out of scope, by decision**: sounds, catching or
  paying, the packs' other coats, animals reacting to each other, dogs chasing.
- **Licences**: the bunnies and the turtle are Toffeecraft's paid packs, bought by Richard. See
  `docs/CREDITS.md`. Carysaurus and Rainloaf require
  credit; both are on the board with Toffeecraft, LYASeeK, LapizWCG and Pixeline (the peacock,
  pixeline-k.itch.io, commercial use allowed).
- All numbers first guesses. `test_lake`'s `_check_land_animals` guards every frame on the
  sheet, the old art gone, counts and caps, the pairs, the zones, the peacock in front of the
  hut, a tree clash behind and none in front, no animal standing in a prop or a building,
  `Dog.calm`, the calm ones not running, the fan and the fold, a pair swimming to the island
  together, the gates at 30% cleaned, a bunny running off and a snake slithering away and
  staying, and a plant drawn over an animal behind it and not one in front. Probe:
  `tools/shot_fauna.tscn` (desktop build, own save, under its own node) saves
  `tools/last_fauna_{bunny,bunny_isle,fox,wolf,snake,capy,peacock,behind_plant,turtle,turtle_swim,capy_swim}.png` and
  `last_fauna.log`.

### Wildlife Sizes and the Peacock (2026-10-06, `/grill-me` with Richard)
- **The peacock collides with no walker** (Richard: "its buggy"): it does not step out of the
  angler's or a dog's way (`_make_room` is the capybaras' alone), still walkers are not
  obstacles to it (`_minds_walkers`), and it is not in `Dog.calm`, so the dogs walk through
  it. It still keeps off the buildings, trees and rocks, walks out from behind the crate and
  fans its tail at whoever is near.
- **Smaller, drawn smaller, not rebaked** (Richard's picks off `tools/last_shrink_sheet.png`,
  `tools/shrink_sheet.py`, which also shows a rebake and, for the crayfish, a rule redraw):
  bunnies and snakes 1.5x (`KINDS` `scale` 0.5 / 1.5, their `half`/`tall` boxes in to match,
  `SNAKE_STEP_PX` 1.5 to 1.0), crayfish 1.5x (`CRAY_DRAWN`, shadow and `CRAY_SHADE_UP` with
  it), frogs 1.2x (`FROG_DRAWN`, `FROG_ART`: sitting, hopping, the swim shadow and the frog
  seen swimming, the hop and jump heights and the plant-cover box). **Fractional pixels,
  accepted**: the art is untouched and draws uneven, and may shimmer in motion. The rebake
  lost the snake's bands and the frog's swimming shape. `critters.png` and the frog sheets
  did not change.
- **Snakes live on the grass and the woods' edge, never the sand**: home `SNAKE_HOME`
  (0.4-5.5) tiles past the lawn's line (`_to_grass`, `_past_lawn`, the outer ground's
  `coverage_at`), `_walkable` holds a snake `SNAKE_GRASS_IN` (0.25) past the line, and a snake
  on its grass will not step onto sand (`_step_to`), so a straight line across a sandy bay is
  sidestepped. A fright slithers it along the grass. Still never the island.
- **Nothing goes away where it can be seen** (same day, Richard: "wildlife suddenly
  disappearing or fading out, it should not happen where player can see"; `Wildlife._in_view`,
  `VIEW_MARGIN` 48, `BROOD_VIEW_MARGIN` 160). A bank animal running off keeps running at full
  strength, another `FLEE_REACH` the same way (`flee_dir`) each time it arrives still on
  screen, and is gone only off it (it used to fade over 1.4 s); a songbird leaving flies on
  until off screen (it faded over the last 30% of its flight); a brood taking off is gone
  past `DUCK_FROM` only off screen; a crayfish off clean water holds where the bed shows on
  screen; a fish school boxed in by foul water slows (`Fish.BOXED_SLOW`) and turns on screen,
  and one whose water turned under it swims on, both fading only off screen. **Fading in is
  untouched.**
- **The capybara follower no longer flickers** (Richard: "jiggly and bugged when walking"):
  it switched between walk and rest every few frames behind a walking lead, one 4 px threshold
  for both (`tools/probe_capy.tscn`, headless, counted 86 and 148 flips a minute). Now it sets
  off at `CAPY_GO` (10 px) and stops within `CAPY_STOP` (2), walking `CAPY_KEEP_UP` (1.15) of
  the lead's pace so it closes the gap: 0 flips.
- **No land animal steps off its ground onto the water** (Richard: "foxes are walking over
  water"): a fox's or wolf's patrol runs between waypoints on the outer bank, and the chord
  between two of them cuts across the lake. `_step_to` now refuses, and sidesteps, a step from
  walkable ground to unwalkable for every land animal, the snake's grass rule folded in.
  Forced steps (a capybara's swim, a bank animal fleeing) are untouched.
- **Turtles 1.3x smaller** (same day, Richard; `TURTLE_DRAWN`, `TURTLE_ART` 0.5 / 1.3), drawn
  smaller like the rest. Walk and swim speed and `TURTLE_STEP_PX` come in with it, so the feet
  still carry the body at the same frame rate; the streak, the rings and the plant-cover box
  too. **A turtle surfacing from a dive keeps its fade**: it was reset to 0 and blinked out.
- Out of scope, by decision: fox, wolf, capybara, peacock, songbird and duck sizes; snake
  counts and gates.
- `test_lake` guards the peacock out of `Dog.calm`, not minding walkers and not stepping
  aside, every snake's home on the grass, and a frightened snake ending on the grass.

### The Wood and the Pack Plants (2026-10-05, `/grill-me` with Richard)
More tree and plant variety from Toffeecraft's animated trees and lake plants (bought in the
bunnies' mega deal), mixed with what was there. Picked off an offline mockup laid on the
game's own plates: option D of `tools/flora_look/mock2_*.png` (`tools/shot_flora_base.tscn`
shoots the plates and logs where every prop and plant stands; `tools/flora_look/flora_mockup.py`,
scratch, lays the pack art on those feet). **Supersedes** the dead trees in `Ground.TREES`,
"out on the bank nothing moves" for the trees, and our rule-built flowers, patches, shrubs,
fern, mushroom, beach grass, reeds, cattails and plain/yellow lilies.
- **The wood is a fifth old Forest trees, two fifths each of the dark and light green round
  trees** (`Ground.TREES` is the weighting: three old, six of each new). **No dead trees, no
  pines** (the pre-autumn pine read as a brown wall), no other season. Round trees at 2x, the
  Forest trees' grain. `test_lake` guards the share (measured 20%) and no dead tree.
- **The trees move on one wind** (`flora_sway.gdshader`, two new blue roles, `Flora.WIND`
  0.375 and `Flora.FRAMES` 0.125): a round tree steps through its 16 frames (`tree_fps` 8),
  the uv moved along its strip in the atlas, its phase hashed off its packed x (jittered by
  under a pixel off its y so a column is not in step); an old Forest tree leans its top
  whole art pixels on a gust running across the wood (`wind_lean` 1, `wind_speed`). The
  clock is `Ground._wind`, pushed every frame, running at `WIND_CALM` (0.6) on a calm day and
  climbing to full pace with the overcast, so a shower or a tornado brings the first pace
  back (Richard: it was too fast as the everyday wind). Shadows
  follow (same roles). The south wood's cover redraw wears the batch's material, or it would
  stand still over moving trees.
- **The strips are built** (`tools/build_trees.py` -> `assets/trees/round_{dark,light}.png`,
  `trees.json`): the pack's baked black shadow and half pixels dropped, every frame cut to one
  shared box, 2 px gutter; `_pack_props` lays a strip into the atlas whole.
- **The wood's floor from a new game** (`FLOOR_SHARE` 0.03 of open forest-floor tiles past
  `FLOOR_FROM`, never on a tree's tile): logs, mossy logs, sticks, a stump; and driftwood
  now and then on the bank's beach (`DRIFTWOOD_SHARE`). At 1x (`Ground._one_x`,
  `_scale_of`). `assets/trees/floor.png`.
- **The pack's plants grow back with cleaning** (`tools/build_flora.py` `pack_plants`, the
  `pk_*`/`shrub_pk_*` entries): flowers, flower beds, bushes, fern, leafy plants, mushrooms,
  beach grass, cattails and reeds, pads and the lotus, at 1x (the bunnies' grain), with
  `LAKE_BIG` (15%) of the lake plants a `_big` twin at 2x on the same rectangle. **Where the
  pack has a twin, ours is gone; ours stays where it has none** (clovers, thrift, beach
  flowers, pink/white lilies, open beds, flowering shrubs). The json gained `scale`, `weight`,
  `reed` (beach, by the water only, `Flora.is_reed`), `stand` (open, standing in the water)
  and `host`; `BEE_HOSTS` takes `pk_flower_`/`pk_bed_`. Sprouts stay ours at 2x.
- **Out of scope, by decision**: seasons, pines, falling leaves, the clay pots and cacti, the
  pack's tileset. **Open**: the lake plants' amount and the 15% (Richard: judge in play).
- **Cost** (`bench_frames`): standing 3.8 ms; cleaned 8.3-8.5 ms mean, and 9.0-9.3 with the
  old flora sheet swapped back, so the plants cost nothing new. The cleaned lake is over the
  8 ms bar on the wildlife (3 ms, `BENCH_OFF=wild` 5.4), not on this.
- `test_lake` guards the wood's mix, no dead trees, the floor wood, the shader's roles, the
  wind clock, the plants' grain, the twins gone and ours kept, and bees on the pack flowers.

### The Lakebed Through Clean Water (2026-09-30, `/grill-me` with Richard, after Spilled!)
Clean water is see-through to a lakebed of sand, rocks, branches, water plants and shells. The
bottom showing is the reward for clearing a bay, the way oil lifting is in Spilled!. Picked
over four passes off `tools/lakebed_mockup.py` (`tools/last_lakebed_mockup.png`).
- **Only on clean water, and fainter on hazy** (`water.gdshader` `lakebed`, `bed_on`): murky,
  foul and dirty water stay opaque. **The catch patches and the reel's lane show the bed**
  (rocks, branches, ground); **what grows back** (plants, shells: rank over 0) **shows only
  where the honest map is clean or hazy** (`grown_here`), as fish and flora do.
- **Drawn in steps, not colours**: every bed pixel is a material and a step offset on that
  material's own five-step ramp, mixed `bed_mix` (0.38 / 0.52 / 0.72) of the way towards the
  water's own step, one share per depth band (`bed_bands` 0.3 / 0.58 / 0.85 on the shader's
  `d`). Each band is a small palette of hard steps, so the band edges read as depth contours.
  Past the last band only the dark shapes of things show, one step down.
  **The band edges wander** (`bed_depth`, `bed_wobble` 0.16, `bed_lobe` 60 art px; same day,
  Richard: the edges were "that straight separation"): the depth the bed reads is broken by
  two octaves of noise into lobes and inlets, and the water's share steps from `bed_mix.x` to
  `bed_mix.z` through `.y` in `bed_levels` (5) hard steps rather than three, so neighbours are
  closer. Static: the bed does not move, the surface does. **Tinting by
  brightness was tried first and failed**: rocks came out as hollow rings, their bodies melting
  into the sand.
- **The ground is the shader's** (sand to mud, broad silt patches a step down, sand ripples in
  the shallowest band, light lines drifting on the stepped clock in the two shallow bands).
  **Everything on it is baked** by `tools/build_lakebed.py` into `assets/lakebed.png`, one texel
  per art pixel over the whole basin (2944x1472, RGBA: material, step | height << 4, growth
  rank, present), with `assets/lakebed.json` holding its place in the world and the eleven
  material ramps (`bed_ramps`, 55 entries). Offline because the geometry is the same on every
  save (it mirrors `Iso` and the shader's shore functions), so the bed is too. **Re-run and
  reimport** if the basin, the island or a ramp changes; the import has `fix_alpha_border` off.
  Review sheet: `tools/last_lakebed_sheet.png`.
- **Rocks are the Forest pack's own five slices**, ranked by brightness into four steps, moss
  onto its own ramp, **sunk**: a wavy sand line over the bottom 2-4 rows, a lit drift spilling
  past the sides, a shaded row under the foot, loose grains. **Branches are drawn by rule**: a
  wandering, tapering limb with twigs, bark cracks and knots, a pale broken end, an outline, a
  stretch buried. **Plants** (eelgrass, waterweed, hornwort, pondweed, stonewort) stand up off
  the bed side on, each in a sand heap; **shells** are the old snail and mussel stamps.
- **Life returns** (`bed_growth`, the clean share over `Lake.BED_GROWN_AT` 0.6, never falling
  back): a plant or shell shows once the growth passes its rank. Rocks and branches are there
  from the start.
- **The sky's cloud reflections keep off the two shallow bands** (`sky_over_bed`): laid over the
  bed they read as holes cut in the picture. Glints and the finished sparkle lift the bed's
  colour towards the light step where they fire.
- **Cost**: `bench_frames` `BENCH_CLEAN=1` 7.2 ms without the bed, 7.3-7.5 with it.
- **Fish are seen, not only shadows** (same day; `tools/build_fish.py`, `assets/fish.png`,
  `shaders/fish.gdshader`; supersedes "seen only as a shadow" in Nature Coming Back). A fish is a
  run of lit elliptic sections, fatter at the head, with a forked tail standing up, a low dorsal
  and pectorals, laid on the plane at its heading and seen at 2:1 with some height, ringed in its
  ramp's darkest step, an eye on the near side. **Six species, each its own colours**: minnow
  (olive, dark side stripe), roach (blue-silver, red fins), perch (green-gold, bars, red fins),
  rudd (gold, red fins), tench (dark olive), carp (bronze, a hint of scales). Tier 0 is minnows,
  tier 1 roach, perch or rudd, tier 2 tench or carp; one species a school. Baked at sixteen
  headings with three tail-beat frames, 48x40 cells, drawn at 2 world px an art pixel.
  **Mixed towards the water by depth** (`Fish.MIX_*`, the bed's five steps, less water than the
  bed gets because a fish is over it) in the fish shader, and **faded in and out a whole art
  pixel at a time**, the foam's rule. The flat shadow falls on the bed at `SHADOW_INK`, further
  down the screen the deeper the water (`SHADOW_NEAR`/`SHADOW_FAR`). Big fish looked blocky when
  swept as a flat outline, and that is why the body is sections.
- **The rest of the lake's life is seen through the water too** (same day, Richard: "make sure
  we integrate frog, turtle and current wildlife"; all four options picked). Shared helpers on
  `Fish`: `water_over`/`under_water`/`through_tint` (the bed's depth steps, a share of water
  given per caller), `shadow_drop`, and `bed_shows` (clean or hazy water, and water under it:
  the map reads a dry tile as clean).
  - **A swimming frog is a frog**: `frogdive_<green|brown>_<heading>_<kick>` in the critters
    sheet (`build_wildlife.py` `frog_dive`, the silhouette's own shape: a lighter back stripe,
    darker legs, black eyes, the ramp's dark ring), drawn through the fish shader on the
    wildlife's `Submerged` layer (z 3, over `Under`). **A dived turtle stays in sight** under
    the surface, fainter than a frog (more water over it) until it comes up.
  - **Shadows on the bed** (`Wildlife._shadow_of`): swimming frogs, dived and swimming turtles,
    floating ducks and ducklings, each its own picture in ink at `Fish.SHADOW_INK`, dropped by
    depth. The frog's white `frogswim` silhouette is its shadow now, not the frog.
  - **Legs under the surface**: a floating duck paddles two orange legs with webbed feet by
    turns (`_duck_legs`, a duckling's shorter), a swimming turtle strokes its flippers over its
    shell's underside (`_turtle_flippers`), all mixed towards the water (`LEGS_WATER`).
  - **Water plants are anchored** (`Flora.Below`, `show_behind_parent`, laid in `_lay`): every
    lily pad and pad bed casts its shadow on the bed, and a stem of whole art pixels runs from
    the pad's middle, or from a standing reed's foot, down to a three-pixel root on the bed where
    its shadow falls, leaning with the drop. Only where the bed shows.
  - Probe: `tools/shot_nature.tscn`'s fourth stage, `under`, sends every frog into the water,
    puts turtles under it and lets a brood in, and saves close crops
    (`tools/last_nature_under_<frog|turtle_under|turtle_swim|duck>.png`). The duck's legs were
    not caught by the probe on 2026-09-30 (no brood on the water at the shot).
- **The bed's plants sway** (`lakebed`, `bed_texel`, `bed_sway_from` 5, `bed_sway_speed` 0.9,
  `bed_sway_cell` 40; same day): a slow current, one swing a patch of the lake on the stepped
  clock, stands a plant pixel five art pixels above its root one pixel over and one ten above
  two over; a pixel shows whichever plant pixel swayed onto it, or the ground where its own
  swayed off. Roots, rocks and shells never move. The height is the map's `g` high nibble.
- **Crayfish crawl the bed** (`Wildlife` "crayfish on the lakebed", `crayfish_<heading>_<step>`
  in the critters sheet, `build_wildlife.py` `crayfish`): the mockup's rule-built crayfish at
  eight headings and two steps, squashed 0.78 so the claws read, legs drawn as one-pixel lines.
  Up to `CRAYFISH_MOST` (12) with the clean share, on clean water no deeper than
  `CRAY_DEEPEST` (0.55); they rest and crawl, turn off anything else, and **dart backwards,
  tail first**, from a threat within `CRAY_SHY` or a landing net. Drawn through the fish shader
  with the bed's own water shares, a small shadow under each. Not counted for the wildlife
  moment. All numbers first guesses.
- **Snails, mussels and clams** (`build_lakebed.py` `snail`, `mussels`, `clam`, material
  `mussel`, so twelve ramps and `bed_ramps[60]`): hand-set river snails with a lit spiral shell
  and a pale foot (two poses, mirrored at random), mussel beds of three to six blue-black shells
  kept apart so the bed does not run into one blob, and pale clams half in the sand. They come
  back with the growth, as the plants do.
- **First guesses**: `bed_mix`, `bed_bands`, `bed_hazy` 0.22, `BED_GROWN_AT`, the plan's
  counts in the builder (about 450 rocks, 160 branches, 1050 plants, 350 shell groups).
- `test_lake`'s `_check_lakebed` guards the gating, the honest map for growth, the sky rule,
  the ramps filling the array, the map reaching the shader at its size, and growth never
  falling back. Probe: `tools/shot_nature.tscn`.

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
- **Every verb is in the map now**: `cast`, `interact`, `open_shed`,
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

### The Pump and the Wash Room (issue #37, 2026-09-18/19, `/grill-me` with Richard)
A find is washed before the shed will have it. The one named exception to the scope lock.
- **Must wash to place.** `Lake._keep` puts a netted find in `unwashed` (at the pump), not
  `unlocked` (the shed's shelf); `_on_find_washed` moves it across. A copy is a copy on
  either list. **Saved as names under `unwashed`; no `SAVE_VERSION` bump** — an older save
  has no such key and everything in its `unlocked` is simply washed already, so Richard's
  furnished save and the trailer's shed shot are untouched. The ending does not wait on
  washing: a run still ends when the last piece is in the crate.
- **The pump is free and there from a new game. Soap is flavour, not a sink**: 5 / 10 / 15
  by the restored picture's area, in thirds of the catalogue (`WashRoom.soap_of`), about
  400 over a run against the 870k the lake holds. **This supersedes issue #37's and the
  scope lock's "paid for out of the 43-56k a run ends with"**: the surplus stays unspent,
  by Richard's call. **Checked when a find is picked, charged when it comes clean**; a
  purse that cannot cover it leaves the row drawn back and deaf. Walking away from a
  half-washed find costs nothing and puts the whole coat back — the same coat, rolled off
  the find's name — and nothing of a wash is ever saved.
- **The pump** (`scripts/pump.gd`, `tools/build_pump.py`, `assets/pump.png`/`.json`): an
  iron hand pump on a plank of the box's wood, a bucket under its spout, the nozzle's canvas
  hose coiled at its side. Authored as rows of letters and inked by the builder, "rules
  first, polish after". It stands `Lake.PUMP_AT` off the hut's walls, out past the near
  right wall on the side the door is not, on the crate's layer; a walker north of it is put
  on `BEHIND_CRATE`. Hemmed and swept like the hut and the crate. **`Pump.tile` is a
  static the walkers ask** (the `Dog.pack` pattern): the angler's `_can_stand`/`_slide`,
  the dog's `_may_stand`/`_bumped` and the flora's sow all go through `Pump.covers`, the
  crate's own square-in-tile-space rule. E (or A) within `PUMP_RANGE` opens the room; the
  pump stands inside `SHOP_RANGE`, so `_at_pump` is asked before `_at_shed` and the lamp
  moves over the pump.
- **The room** (`scripts/wash_room.gd`): the stand over the whole window and a tray of what
  waits down the left in the shelf's wood — the find as the lake showed it, its name, its
  soap. Click one and it goes on the stand. `_wash_open` is in `_panelled`,
  `pad_cursor_wanted` and `Sfx.indoors`; Escape and E close it; the menu's pose closes it.
  `find_caught` was added to `Sfx.WHILE_INDOORS` for the finish.
- **The stand** (`scripts/wash_stand.gd`) knows nothing of money, the queue or the save.
  **The grime is made, not painted**: a noise off the find's name over the restored view 0,
  heavier low down and on the silhouette's edges, in the water's own filthy swatches, four
  hard steps (scum / film / stain / clean). The lake's dirty sprite is not used — it is a
  different drawing at a different size. `FINE` 2: grime cells are half a painted pixel,
  which mixes two pixel sizes on one picture; 1 is the purist's knob.
- **Drawn only, the rope's bargain**: the stream's dashes, the spray, the trickles and the
  hose are lists of cells stepped by hand; nothing reads them back but how much grime is
  left. The spray comes off **dirty while there is grime under the jet and white once there
  is not**, which is the honest answer to "is this bit done". Trickles run down the
  silhouette wearing a little away (the clean streaks), drop off edges, land again on what
  is under them.
- **The table is one size whatever is on it** (Richard, 2026-09-19): it was the piece's
  width plus `STAND_PAD` cells a side and changed size with every find. Now
  `WashStand.STAND_WIDE` (0.54) of the window, just over the `ROOM_WIDE` the widest find is
  fitted to; drops slide to its real ends through `_stand_pad` (cells, per piece).
  `test_lake` puts a sofa, a lamp and nothing on it and asks for the same top.
- **Some finds draw bigger on the stand** (2026-09-28, `/grill-me` with Richard): a
  per-entry `wash_scale` in `tools/decor_sets.json` (carried in `pieces.json`,
  `Sheets.wash_scale_of`) multiplies the fitted zoom, past `ROOM_WIDE`/`ROOM_TALL`. Zoom
  still moves in steps of `FINE`, so a scale only counts once it reaches the next step:
  old clock 1.5 (zoom 6 to 10), fridge 1.34 and tall bookcase 1.2 (6 to 8). **`tuning`
  only reaches PSD-group pieces**; an authored entry carries it on the entry. And **the
  lowest painted row stands on the plank** (`WashStand._stood`): a switched piece's view
  is padded to its pair's box, and the fridge floated on five empty rows.
- **Nothing rests on the stand** (Richard: the puddle looked bad): a drop that lands slides
  to the nearer end or turns over the front edge, creeps down the plank's face, falls, splats
  on the floor and is gone. `_pool` is retired.
- **It finishes itself at `DONE_AT` 0.99** (0.93, then 0.97, by Richard's eye), and **a
  cell that looks clean is clean** (`_wear` snaps anything under `THIN_AT` to nothing) — or
  at 99% the player is sent to spray grime nobody can see. Then a rinse line, the finds'
  gold stars, `find_caught`.
- **The nozzle is one drawing, turned** (`tools/build_nozzle.py`, `assets/nozzle.png`): a
  brass fireman's nozzle on an oak grip. **Retired, in order**: a `draw_line` turned at
  runtime ("ugly and blocky, not pixel art"); eleven headings each drawn afresh (each lit
  and cut anew read as a different nozzle every move); the straight one alone, never
  turning ("lost the curving"). What stands: the straight frame drawn once by rule and
  **that same picture turned** onto the art grid every 4 degrees to +-48 (`turned`: a
  majority vote per pixel, the one-pixel shine and the bore kept, the outline re-inked
  after). It glides between art pixels, eased toward the pointer and toward its heading —
  the lake's own rule that stepping a moving thing on the grid is what reads as stiff —
  kicks back while it sprays, breathes at rest, hangs a bead or two on its lip when let go,
  and runs a glint down the brass on the press and on the finish.
- **The water leaves the bore** (2026-10-02, Richard: it came from underneath the tip):
  `_draw_stream` runs after `_draw_nozzle`, and each dash is centred on the stream's line
  before it is put on the grid. Drawn first, the brass hid the stream's start; anchored by
  its corner, every dash hung down and right of the line. The contract's `tip` was right.
- **The hose is laid out every frame** (`_draw_hose`), not baked: a curve from the grip's
  foot, leaving along the nozzle's own axis, to an anchor low and to one side
  (`HOSE_SIDE`), its belly trailing a nozzle that moves. The builder's canvas tones and
  edge colour come through `nozzle.json`, on the nozzle picture's own pixel grid.
- **The jet starts on the tip's own cell** (2026-10-02, Richard, third pass): every dash of
  `_draw_stream` is centred on the line and put on a grid counted from the tip, not the
  screen's (on that grid the stream sat beside the bore), and only `JET_GAPS` (0.08, was a
  fifth) of the dashes are left out. **Tried and reverted the same day**: a solid jet as
  wide as the bore started inside the nozzle (too thick, lost the dashes' style, and drew
  over the brass).
- **The jet is Nuven's recording** (2026-09-19, `/grill-me` with Richard):
  `art_source/SFX/Water_Hose_Spray.wav`, a steady spray with no tap-on or shut-off in it,
  cut to a 9 s seamless loop and levelled by `build_sfx.py` as `hose_spray` (`--only a,b`
  builds named cuts alone, so a new take does not re-encode the rest). `WashStand` loads it
  for itself — it is not one of `Sfx`'s names — and eases it in and out on the button as
  before. **Duller on the piece, brighter off it, narrowly**: `HISS_ON_PIECE` 0.96 /
  `HISS_OFF_PIECE` 1.06, where the code-built noise swung 0.92 to 1.22 — a real recording
  pitched that far is a different hose. `HISS_DB` -13. All by-ear knobs. The noise loop is
  still built when the file is missing.
- **Behind the stand is the view from the pump** (`scripts/wash_backdrop.gd`,
  `tools/build_wash_backdrop.py`, same day; supersedes the two grey rects): sky, the far
  bank's trees and sand, the lake, the island's sand, and its lawn under the stand to the
  bottom of the window, the near waterline at `HORIZON` 0.52.
  - **Two baked strips, two things drawn in code.** `assets/wash_bank.png` and
    `wash_lawn.png` are all pack art (psd-extract venv python, project root, **reimport
    after**; contact sheet `tools/last_wash_backdrop.png`): `Tree_1-3` in three ranks, the
    back ones multiplied down, and ground as a patchwork of the rectangle inscribed in each
    tile's top diamond. **The diamonds themselves are not used, by decision**: a first-person
    floor is a plane running away and a 2:1 diamond under a front-on stand is two
    perspectives in one picture. The patchwork's blocks get shorter and narrower towards the
    horizon instead — stepped, nearest, whole painted pixels. Both strips wrap.
  - **The water is the player's own lake**: the palette's five ramps, the state picked from
    `pollution` through `LakeGrid.FILTH_STATE_AT`, flat bands (shallow at both shores, deep
    between, far bands thinner), seeded streaks one step up the ramp, a foam line at each
    shore. The state is set when the room opens and left alone while it is up. **"Still, by
    decision" lasted an afternoon** — see the second pass below.
  - **The sky follows the day** (`DayCycle.sun`, new: the hour, eased back with the rest of
    the light): `SKY_STEPS` (5; two read as "2 blue blocks") flat steps from the high swatch
    to the low, lerped between `sky_morning/noon/afternoon_high/low`,
    authored in `extract_palette.gd` and `palette.tres`. **The only sky in the game.**
  - **All of it under `DARKEN` (0.66) times the day's tint**: the grime and the dirty spray
    are the water's filthy greens and lose to a full-strength lawn. One knob.
  - At `PIXEL` 2, finer than the stand's and the nozzle's grain, on purpose: far is fine.
  - The stand keeps its flat wall when it has no room round it (`WashStand.bare_room`,
    `tools/wash_spike`). The backdrop holds nothing of the lake's: the room hands it
    `filth`, `sun`, `tint`.
  - **First guesses**: `HORIZON`, `LAKE_TALL`, `DARKEN`, the sky swatches, `RANKS`,
    `DEAD_ODDS`. Judge on `tools/last_wash_room.png` / `last_wash_room_clean.png`
    (`shot_pump`).
  - **Out of scope, by decision**: parallax with the nozzle, tap-on and shut-off sounds.
- **The view is alive, and answers the jet** (second `/grill-me` the same day, Richard:
  "water movement and pigeons flying... pixelated clouds... the dogs running around").
  Everything on one stepped clock (`WashBackdrop.PIXEL_FPS` 8, the lake's `pixel_fps`).
  - **Water**: streaks drift along the shore, faster nearer, and blink in and out whole
    (`STREAK_*`); the near foam line laps a painted pixel in stretches (`LAP_*`).
  - **Clouds**: rule-built puffs on a flat base, two tones, baked by the same builder into
    `assets/wash_clouds.png` (rectangles in `wash_backdrop.json`); two layers at two paces
    and sizes (`CLOUD_LAYERS`), wrapping.
  - **Pigeons**: the flock's own sheet and birds (lent through `WashRoom.flock`), one or a
    pair every `BIRD_EVERY` (8-20 s) on a shallow arc. **Dogs**: as many as the pack holds
    (`pack_size`), `DogArt`'s run and rest poses, on the lawn between beach and the stand's
    feet (`DOG_BAND`), smaller further back, **behind the stand only** — in front, a dog
    walks over the grime being read.
  - **Both answer the jet** (`sprayed_at`, fed by `WashStand.jet_past_piece`): a bird veers
    up and away with a foam puff and a coo, a dog bolts with a bark (`BARK_GAP`). **Only
    while the jet is off the find.** No pay, no count, existing frames only. The stand still
    knows nothing of any of it: the room reads the jet and tells the backdrop.
  - **The bark and coo come through `Sfx.room_bark`/`room_coo`, not `WHILE_INDOORS`**: on
    the allow-list, the lake's real pack — which goes on barking behind the room — would be
    let in with them. The room's own call is what is let through, not the name.
  - **They are not the lake's real dogs and birds**, which carry on behind the room.
    Nothing saved, dropped and re-rolled each time the room opens (`reset`).
  - **The stand is grounded, not redrawn** (picked over a perspective table, which would
    re-fit every drip): blades over each leg's foot in the palette's greens times the
    lawn's tone (`ground_tone` — the backdrop is darkened and the stand is not, so plain
    greens would glow), and the sun's shadow of stand and find down the lawn
    (`Shade.lying`, `shade` = the day's lean, stretch, ink; `SHADE_GAIN`). Neither is drawn
    with `bare_room`.
  - **The song goes through the radio** behind the wash room as behind the shop
    (`music.muffled` in `_push_rooms`).
  - **Out of scope, by decision**: pigeons perching, pay or score for hits, dogs in front of
    the stand, shadows for the actors, mirroring the real pack or flock.
- **Which way a sprite faces is asked of its owner, never written by the caller** (third
  pass the same day, Richard: "pigeons are flying backwards... I don't want to see this
  mistake again"). The backdrop's first pigeons crossed tail first: `Flock.stamp`'s
  `facing` is **the sheet's sign** — the birds are drawn facing left, so +1 is a bird
  heading *left* — and the backdrop passed the direction of travel. Now
  `Flock.facing_of(from, to)` is the one place (the flock's own flight calls it too),
  `Boat.frame_heading` / `Boat.turn_sailing(screen_direction)` pick a hull's frame by the
  boat's own heading rule (screen-right is tile (1, -1)), and `DogArt.stamp` already took
  `facing_left`. **Any new mover routes through these and is checked on a zoomed crop of a
  probe shot before it is called done**; `test_lake` guards that the backdrop hands a
  rightward bird the flock's own answer and that left and right hulls are different frames.
- **The backdrop's lake carries what the player's does** (same pass: "we should see objects
  on the lake so it does not break immersion. And boats also crossing"):
  - **Rubbish**: the lake's own sprites (tiers 0-2, no finds, lent by `Lake` as
    `{sheet, region}` rows), `RUBBISH_MOST` (40) on a full lake down to none on a clean one.
    **One seed whatever the meter says**, so a cleaner lake shows the first so-many of the
    same pieces — they thin out, they do not reshuffle. Bottom `RUBBISH_SUNK` under water
    (not drawn), bobbing a pixel on the stepped clock, half grain past `RUBBISH_NEAR_FROM`.
  - **Ferries**: `fleet_size()` hulls on two lanes (`BOAT_LANES`: far at 1 canvas px a
    painted one, near at 2), `Boat.art_frame`'s waterline-cut picture, shore to shore, a
    wait out of sight (`BOAT_WAIT`), back the other way. No cargo, no foam, no bell.
    **Drawn over the far bank's strip**: under it, the far hull sailed with its sail behind
    the sand.
  - **The jet does nothing to the lake, the boats or the rubbish, by decision** (a foam
    splash, pushed rubbish and a rung bell were offered).
  - Dogs drew 26-54 px tall and read "too small in comparison": `DOG_TALL` 36-72.
  - `shot_pump` forces two hulls, one each way on each lane, because which way a bow points
    is a thing to look at.
  - **What floats wears a foam collar, and the dogs throw the sun's shadow** (fourth look,
    Richard: "it lacks the objects foams, the dogs shadows and the boats can seem a little
    bit quicker"). `_draw_collar`: a torn row of whole foam pixels on the waterline and a
    thinner one under it, re-torn `FOAM_BEATS` (2) times a second, `foam_dirty` on foul or
    dirty water — round every piece and along each hull's own waterline
    (`Boat.art_frame`'s new `waterline` ends, not the picture's box). Dog shadows are
    `Shade.lying` on `WashBackdrop.shade`, the same (lean, stretch, ink) the room hands the
    stand, at `DOG_SHADE_GAIN`. **This supersedes "shadows for the actors" being out of
    scope** for the dogs; birds and boats still throw none. Ferries went 20/38 to **32/60**
    canvas px a second.
  - All paces, counts and sizes are first guesses. `shot_pump` puts a pair of pigeons and
    the pack in its clean-lake shot; `_stage_wash` guards the muffle, the pack's count and
    band, the stepped clock, the bird's veer, the dog's bolt, a wide jet troubling nothing,
    and the real barks staying shut out.
- **Out of scope, by decision**: pump upgrades, a timer or a score, nozzle types, stubborn
  spots, saved masks, washing rubbish, washing a view other than the first, painted grime,
  cellular water, any price or track change.
- **Probes**: `tools/wash_spike.tscn` (the stand on its own, every find a key away;
  `WASH_AUTO=1` washes one by raster and quits — what proves it runs end to end),
  `tools/shot_pump.tscn` (desktop build, own save, under its own node:
  `tools/last_pump.png`, `last_wash_room.png`, `last_pump.log`). `test_lake`'s
  `_stage_wash` guards the pump's place, footprint and sorting, the three soap prices, the
  broke refusal, no charge for picking or walking away, the bare stand on the way back, a
  wash right through charging once and landing on the shelf, and the save; `_stage_shed`
  guards that a netted find waits at the pump.

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
- **Menus used a virtual cursor** (superseded 2026-09-26, above), not focus navigation: wherever the scene
  wants a pointer (`pad_cursor_wanted`: on the lake, while a board, the farewell or the main
  menu is up; a scene without the method always wants one), the right stick moves
  the real pointer (`warp_mouse`) and `Pad` turns buttons into real events tagged
  `SYNTH_DEVICE`: A is the left button (hold to drag), B is Escape, LB/RB are the wheel. In
  the shed, X turns the piece in hand and Y works a switch, and the shed's prompt and the
  tree screen's help line show pad buttons in pad mode. **In the shed, A picks a piece up
  and the next A puts it down** (`ShedRoom._gui_input` tells a pad click by its
  `SYNTH_DEVICE` tag; the mouse still drags), and **while a piece is in hand the left stick
  moves it** (`_carry_with_pad`), because the player stands still while carrying anyway.
- **Boards are walked with the left stick, not pointed at** (2026-09-26, `/grill-me` with
  Richard). **Supersedes "Menus use a virtual cursor" below**: the right-stick pointer is
  gone and the mouse's arrow is never shown in pad mode. A board joins `Pad.FOCUS_GROUP` and
  answers `pad_focus()` with its controls (`box`, optional `at`/`key`/`first`/`ring`); the
  left stick or the D-pad steps between them (`Pad.step_from`: nearest ahead, sideways
  counted `NAV_ACROSS` times; a held push repeats after `NAV_FIRST`, then every
  `NAV_REPEAT`; a push held as a board comes up waits to be let go). **The pick drives the
  real pointer, hidden**: it is warped onto the control and A is the same left click, so
  every board's own hover wash, swell and sound come for nothing. Over that, one gold ring
  (`FocusRing`, `Pad.RING_LAYER` 39; a shining halo since 2026-10-06, see The PlayStation Pad). Optional hooks:
  `pad_press(key)` (A taken by the board), `pad_nudge(key, step)` (left/right spent on the
  control), `pad_scroll(step)` (a step off a scrolling list's end), `pad_hold()` (stick
  frozen), `pad_free()` + `pad_mark()` (the board reads the stick itself; the ring marks what
  A would act on). Of every board up, the highest canvas layer then the latest in the tree
  listens.
  - **Main menu**: the doors, the accented one first, and the flag. **`MenuConfirm`**: "keep"
    first. **Settings**: a chooser is one stop stepped by left/right, A on Resolution drops
    its list (whose entries are then the only stops); a slider moves `PAD_LEVEL_STEP` 0.05 a
    push and A does nothing on it; switches and buttons are A. **Shop**: one stop a row, the
    pointer on its tag so A buys, **the row's blurb shows while it is picked**; the tour's
    card is two stops, go on and skip. **Controls board**: every cell and the reset plank; A
    captures, **X restores the picked cell** (`_pad_restore`), the stick is held while a cell
    listens (`pad_hold`), and the hint reads `CONTROLS_HINT_PAD` in pad mode. **Letter**:
    back, on, the door, the cross, and left/right turn the page from anywhere. **Languages**:
    the one in use first. **Credits**: the cross. **Farewell**: one unringed stop over the
    screen while the roll climbs (A skips it), then the menu door. **Tour cards**: the lit
    target first when it takes the click, then go on and skip.
  - **Shed, free aim**: the stick walks the player; **A picks up the placed piece the player
    stands at** (`_piece_near`, within `REACH`, ringed through `pad_mark`) and puts a carried
    one down where the stick has carried it; Y works a switch, X turns what is in hand.
    **RB or LB opens the shelf** (`_pad_shelf`, the shoulder shown on a chip on its title
    plank): its rows, the wash plank and the cross are stops, the list scrolls off its ends,
    A takes a row into the hands (and the pointer to the player), B puts the shelf away
    rather than leaving the room.
  - **Wash room**: nothing on the stand, the tray's rows and the cross are stops. **A find on
    it, the stick is the nozzle's** (`WashRoom._pad_aim`): it moves the pointer the jet
    follows, RT or a held A sprays, and B puts the find back on the tray, nothing paid.
  - `test_lake`'s `_check_pad_focus` guards the step rule, the repeat, the menu's doors, a
    board over them, the letter paging, A on a slider, the bind board's hold, and the
    credits' cross.
- **The aim ring stays up while a cast is out** (2026-09-14, both pad and mouse): drawn over
  the net by `CastNet._draw` so the next throw can be lined up, with the same green/red
  verdict (`in_reach` is `can_cast_to` without the idle check). Not on the double cast's
  second net. The laid-net ghost is still idle only, and the assist works during a cast too.
- **Superseded in part 2026-10-06** (see The PlayStation Pad below): button glyph art is in.
- **Out of scope for now**: focus navigation, button glyph art, rumble, a Steam Deck pass,
  an aim-assist setting.
- **Tests**: `test_lake`'s `_stage_pad` covers the input map, mode switching, the reticle,
  the assist (still stick, bend, never backwards, friction) and the lean.
  `tools/probe_pad_cursor.tscn` (desktop build, not `--headless`) checks that the pad's
  click, wheel and Escape land where the pointer is in a stretched window
  (`tools/last_pad_cursor.log`).

### The PlayStation Pad (issue #33, 2026-10-06, `/grill-me` with Richard)
The DualSense joins the Xbox pad, every pad button on screen is a glyph, and a pad-only
player can reach every board. **Supersedes** the Xbox text names on screen (`Binds.PAD_NAMES`
is now only the fallback) and, in Every Word Is a Key, "the gamepad button names ... Xbox's
own printed legends".
- **Glyphs everywhere, never words** (`scripts/glyphs.gd`, `Glyphs`): the bind board's pad
  cells, the tour cards, the hive and shed key chips, the first steps, the letter's net card,
  the shop tour's foot. Kenney's Input Prompts Pixel, cut by `tools/build_prompts.py`: `xb_*`,
  `ps_*`, and the sticks and D-pad shared. **The pack's PlayStation faces are cut in two**
  (the symbol's right half in the next tile) and are laid one over the other by the builder.
  `pad_a`/`pad_rt` are retired: the cast and confirm prompts follow the bindings.
- **A glyph in a sentence is a token** (`Glyphs.token`, two private-use characters round the
  written binding). `Binds.shown(action, true)` returns one, and `Style.write` /
  `Style.measure` / `FirstSteps._wrap` / `Glyphs.draw_line` draw and measure it as the
  picture, so a `%s` filled with it needs nothing else. A token reaching a plain
  `draw_string` shows as tofu, by design. Inline glyphs are whole screen pixels to a pixel of
  the pack's (`inline_px`, about `INLINE_GROW` of the text); a glyph alone is 2 (`prompt_px`).
  A key chip holding a lone glyph draws the glyph only (`Glyphs.lone`).
- **Family: auto, with an override** (`Glyphs.detected` from `Pad.note_device`: Sony's vendor
  0x054C, or a Sony word in the pad's name, is PlayStation, anything else Xbox; the last pad
  pressed decides). **The Controls board's pad column head is the chooser** (`◂ Auto ▸` /
  Xbox / PlayStation, Auto wearing the detected family's confirm glyph), saved as
  `pad_prompts` in `settings.cfg` (`Prefs`, `Glyphs.choice`). The board went 640 to 664 and
  its pad column 96 to 120 to carry it. A change redraws every canvas item (`Pad.redraw_all`,
  also on a mouse/pad switch).
- **Cross confirms and Circle backs out everywhere**, Japanese included (positions, not
  letters: Cross is A). **B is never bound** (`Binds.bindable`) and cancels a capture on the
  bind board, the pad's Escape.
- **Steam: opt out of Steam Input**, decided. In Steamworks declare Xbox and PlayStation
  support and turn Steam Input off for them, so SDL sees the real DualSense; a DualSense under
  forced Steam Input reaches the game as a virtual Xbox pad and gets Xbox glyphs, which the
  override fixes. Set in Steamworks by Richard on 2026-10-06. The Deck's own controls arrive as a virtual
  Xbox pad and get Xbox glyphs.
- **Light bar follows the lake** (`Lake._push_pad_light`, `LIGHT_DIRTY` murky green to
  `LIGHT_CLEAN` clear blue in `LIGHT_STEPS`, `Pad.set_light`, `Input.set_joy_light`, laid on a
  pad plugged in later too). Game's own lake only. Xbox pads have none.
- **A lost pad pauses the lake** (`Pad.pad_lost`/`pad_found`, `Lake._on_pad_lost`,
  `PadLostCard`): the last pad going while it is the hand in use drops to the mouse, and on the
  bare lake the world pauses (`_repause`, the settings pause) under "Controller disconnected"
  until the pad comes back, the mouse is moved or clicked, or Escape. On a board or behind the
  menu nothing is put up.
- **Audit fixes** (every screen walked by an agent for pad-only gaps): `MenuConfirm` answers
  the stick ("keep" first) and Escape/B is "keep" there; the farewell has a "keep fishing"
  stop and Escape/B runs the roll off or dismisses (`Farewell.back`); Start, Y and X open
  nothing under the farewell, the arrival or the letter, and Escape/B closes the arrival's
  letter; nothing opens the shop over the wash room (pad Y and the U key); the resolution list
  folds up on Escape/B and is never left dropped; the record menu closes on the pad's Y; a tour
  card whose target takes the click gives the stick to the room under it (the tray, the shelf,
  the nozzle) instead of clicking the target's middle; the shelf card names the shoulder that
  opens the shelf (`TOUR_DECOR_SHELF_PAD`, three glyphs); the find hint names the pad's open
  button (`TOUR_DECOR_HINT_PAD`); the letter's net card says the cast button
  (`LETTER_NET_TEXT_PAD`); the shelf's shoulder chip is drawn by the shelf (drawn by the room
  it was under the shelf and was never seen); the shoulders send no wheel under a board reading
  the stick itself (the shelf opened a row down); `Pad._find_again` compares keys like with like.
- **Known, accepted**: the shop is not reached from inside the shed on the pad (Y is the
  shed's switch there): B, then Y. The hive hints say "Drag" and "Slide" beside the cast glyph.
  The tour cards' Skip is not reachable while a pass-through card is up; doing the thing moves
  it on. New strings are machine drafts for the seven other languages.
- **Second pass, off Richard's first DualSense run** (same day):
  - **Washing aims with the right stick** (`WashRoom._pad_aim`), the left still works; the
    hive's tools likewise (`HiveStep.aim_stick`: right stick, else left).
  - **The shelf's R1 is the loudest glyph on the plank** (`ShedShelf.KEY_PX` 3 screen px a
    texel, against 2 elsewhere), standing proud of its left end.
  - **The focus mark is a shining halo** (`FocusRing`): a gold glow breathing outward from the
    box (a gradient round it, never over it), a gold edge with a pale lip, two glints running
    round it, the finds' stars twinkling at its corners in turn, and a glide from pick to
    pick. Supersedes the two-pixel gold rectangle.
  - **The camera has two bound verbs** (`Binds`, `BIND_GROUP_VIEW`, Richard's picks):
    `camera_pan`, held (middle drag on the desk, a key held drags with the mouse; **LT + right
    stick** on the pad, `Lake._pad_pan`, `PAD_PAN_SPEED`, into the pan the follow gives back,
    or the free camera's spot; the reticle stands still while it is held), and `camera_lock`
    (**L / Create-View**, the camera button by the gear). The pan shares the middle button
    with `recentre` by design (`Binds.SHARED`); a tap of it recentres only while they share.
    `PAN_BUTTON` is gone. The Controls board's rows went 26 to 25 to fit sixteen verbs at
    1280x720. R3 now also puts the view back on the angler.
  - **The upgrade blurb stands beside its row's board** (`ShopSkin.blurb_at`, `BLURB_SIDE`),
    level with the row, over the next board: the column being read stays clear.
  - **A board just opened keeps the stick on its own first control until the player steps**
    (`Pad._stepped`): the shop's rows are laid out a frame after it opens, and the stick had
    settled on the close cross.
- **Out of scope, by decision**: rumble, the touchpad as a button, adaptive triggers and HD
  haptics, aim speed / assist / deadzone rows, Nintendo and Deck glyphs, the Steam Input API.
- `test_lake`'s `_check_glyphs` and `_check_pad_audit` (in `_stage_pad`) guard every tile cut,
  every default pad binding having a glyph in both families, the override, a prompt being a
  glyph and never words, PlayStation words for the fallback, the measuring and wrapping, the
  hint's two glyphs, the letter's two wordings, B unbindable, the light API, the question
  board's stick and Escape, the pass-through card, and the lost-pad pause and its two ways
  out. Probe: `tools/shot_glyphs.tscn` (desktop build, own save, `Glyphs.choice` set directly
  so `settings.cfg` is untouched) saves `tools/last_glyphs_{controls,tour,letter,shed,lost}_
  {ps,xbox}.png`.

### The Camera Glides on a Spring (2026-10-05, `/grill-me` with Richard)
Richard: the haul home stuttered in steps, worst zoomed out on a long cast near the edge.
`tools/probe_camera.tscn` measured it (`PROBE_FAR=1` for the far stop, eight long casts):
11 of 16 casts jolted, the velocity jumping up to 300 px/s in one frame.
- **The causes**: the follow eased the camera, then `_clamped_view` clamped it (a box per
  axis, then `_pulled_to_forest` radially), two pushes a frame that disagreed at the edge;
  `HOME_SPEED` clipped each step with `limit_length`; the flying net pushed the camera after
  the ease (`_framed_on` on the position); and the exponential ease starts at full speed.
- **Now** (`Lake._glide_to`): the clamp is applied to the **target**, and the camera chases
  it on a critically damped spring (SmoothDamp), `FOLLOW_TIME` 0.22 s, tightening to
  `THROW_TIME` 0.1 over a throw so a short one still lands framed. Velocity carries frame to
  frame (`_cam_vel`, zeroed when anything else moved the camera, `_cam_left`). The way home's
  cap is the spring's speed limit, eased on from the pace the view already has and off again
  (`_home_cap`, `NO_CAP`, `CAP_EASE`), so `HOME_SPEED` 260 is reached by easing, not
  clipping. The flight's push is gone; `_watching` frames the net **with the pan already
  in**, which is what the push had been hiding. The free camera rides the same spring.
  `FOLLOW_SPEED` is gone.
- **Looser edge**: `CORNER_MARGIN` 4 to **2** tiles of forest under a screen corner, then
  (second `/grill-me` the same day, Richard: a cast near the border slid the view along
  the limit and read as dizzy) to **0.5**, and `DRAG_PULL` 1.5 to **1.0**: one limit for the
  drag, the follow and the cast, the forest's edge. `probe_camera` checks every frame that
  no corner of the view is past the ground.
- **A re-cast goes straight to the new net** (same pass): the throw's frame-in ramps from
  where the view was at the click (`_throw_from`), not from the angler; and a throw made
  while the view was still on its way home (`_throw_out`) is framed from where the view is,
  with no lean back towards the angler at all. `PROBE_RECAST=1` throws the next cast the
  moment the net is home and allows `BACK_MOST` (8) frames of the homeward pace carrying on
  as the view turns. **Known**: a short throw right after a max-reel long haul, in another
  direction, lands just off-frame (the view is thousands of px out and the throw lasts 12
  frames) and the view catches up fast; the old push that framed it was a jolt.
- **Zoom still snaps**, by decision.
- Probe after: far stop 0 of 16 fail, near stop 0 of 8, `test_lake` passes. The one change
  left over the old 50 threshold is the frame a net lands (the target stops dead, ~60 px/s a
  frame at 500 px/s); `JUMP` is 70 and says why. The probe now logs every jolt with its
  phase. All numbers first guesses for Richard's eye.

### The Free Camera (2026-09-20, `/grill-me` with Richard; a trial, to judge in play)
A toggle beside the gear pins the view to a spot in the world, so the player aims and casts by
the cursor and nothing takes the view back.
- **Pinned means pinned** (`Lake._free_view`, `_free_at`, `_drive_free_view`): no follow, no
  `CAST_LOOK` lean, no landing framing, no `HOME_SPEED` way home, and the cast's and the
  step's `_pan_yielded` give-back is skipped. **The angler may walk off the screen, by
  decision** (offered and turned down: following the walk, and pulling the view just enough
  to keep them in the window). Cast rules are untouched: range is from the angler.
- **Moved by the middle drag, the wheel and the window's edges.** The drag and
  `_keep_view_at` write `_free_at` instead of `_pan`; `_pan` is zeroed on the toggle, so
  switching off is the ordinary follow easing home with nothing to unwind.
- **Edge scroll is free mode's alone** (`_edge_scroll`, `_edge_push`, `EDGE_MARGIN` 24 canvas
  px, `EDGE_SPEED` 0.9 view heights a second — `PadAim`'s rule, the same on screen at every
  zoom). Held off while the pointer is out of the window (`_mouse_inside`, off
  `NOTIFICATION_WM_MOUSE_EXIT`: **a pointer that leaves stays at its last spot, which on an
  edge is a view scrolling for ever**), the window is unfocused, a board is up, the middle
  button has the view, or the pointer is on a HUD button (`_over_hud`,
  `HudSkin.over_button` — the corner buttons are inside the margin). **Known cost, accepted**:
  aiming at water near the window's edge slides the view.
- **Recentre stays free** (`_recentre`, the middle tap and the verb): the view jumps to the
  angler and the mode does not change.
- **Session only, by decision**: not in `Prefs`, not in the save, every launch and every
  trip to the menu starts following (`_enter_menu` switches it off — the glide down onto the
  angler is a thing a pinned view cannot do). **"Mouse only, no key" is superseded
  2026-10-06** (The PlayStation Pad, second pass): `camera_lock` (L / Create-View) toggles it
  on both devices, `camera_pan` (middle drag / LT + right stick) moves it, and `_free_now()`
  is true in pad mode too.
- **The button** is a `PlankButton` at the gear's size to its left (`%FreeCamera`,
  `mark = &"camera"`, `_draw_camera`, `_draw_lock`): a video icon (a chamfered box with a
  wedge on its right) with a padlock over its bottom-right corner, on whole pixels (2026-09-29,
  `/grill-me` with Richard, over the boxy photo camera). **The lock is shut while the view
  follows the angler and open while it is pinned**; it snaps, no animation. **Free is two
  channels** (`PlankButton.lit`): the open lock and the mark in `Style.ON_WATER`, the
  settings board's switch colour, plus the lit edge. Probe: `tools/shot_camera_mark.gd`
  (desktop `--script`) saves `tools/last_camera_mark.png`. Hidden while any board is up.
- **Out of scope, by decision**: left-drag or WASD panning, a pad free camera, a settings
  row, persistence, an off-screen-angler marker.
- `test_lake`'s `_check_free_view` guards the button, the unlit start, the view holding
  through a step and a cast, the wheel's hold, the edge push and its out-of-window gate, the
  clamp, recentre staying free, and the way home when switched off.

### The Led Cast (2026-09-22, `/grill-me` with Richard)
A cast press on water out of reach walks the angler towards it and throws the moment it
comes into reach, so a better spot no longer needs WASD first. `Lake._cast_or_walk`,
`_led_step`, `_stop_led_cast`; the walk is `Angler.walk_to`, the arrival's own lead.
- **One gesture**: the spot is committed at the press (a world point, not the pointer,
  which stays free); the aim ring draws under the pointer as ever and nothing new is drawn.
  A press in reach is the plain throw. Both devices: the desk's click and the pad's RT.
- **Straight line, first spot in range, no path planning**: the angler pushes straight at
  the spot and `_slide` takes him round the crate, the pump and the hut's faces; the frame
  `CastNet.in_reach` says yes the walk ends and `_cast_at` fires at the committed point.
  A walk that makes no ground for `LED_STALL` (0.6 s) is given up.
- **Unreachable from anywhere** (`Angler.shore_toward`: the ray out of the island's middle
  through the spot, ending at the last standing point): the walk goes to that shore and
  stops with no throw, by Richard's call over ignoring the press and over throwing short.
  The player aims again from there.
- **A press on the island's ground walks there** (Richard, same day: "walks to there
  instead of standing"), no throw owed; the hut, the crate, the pump and the bank are
  nothing, as `Angler._can_stand` says.
- **The ring says what a press does** (same day, Richard: the dashed circle only where
  a cast is really out of bounds): **no ring on the island** — pointer alone, hut and
  crate included; **solid green/red over any water a press throws at**, now or after the
  walk (`CastNet.castable_after_walk`: open water within range of `shore_toward`'s spot,
  the verdict the mouth's at that spot); **dashed** over water no shore reaches and over
  the outer bank and the piers, where a press is nothing. `in_reach` is untouched.
- **Cancelled by** any walk input (WASD, arrows, the left stick), any board, the menu, the
  arrival, the farewell, or a net no longer idle. A new press retargets. Session only.
- **Out of scope, by decision**: A* or waypoints, a pinned ring or a stop marker, any
  change to range, `WALK_LIMIT` or the aim assist, walking to the shed or pump by click.
- `test_lake`'s `_stage_led_cast` (after the front stage, on the landed lake) guards the
  walk-then-throw across the island, the shore walk with no throw, the three cancels, the
  retarget and the plain throw in reach.

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
  white is out-of-range — only the swatches, so nobody has to relearn the marker.
  **The lift is what makes them carry over dirty water without being invented beside the
  palette**: repaint the pack and the ring moves with it, which is what `test_lake` asks.
  (It went 1.15 and 0.7 for an afternoon on 2026-10-03 under a white rim; the pixel ring
  below put it back.)
- **The ring is pixel art** (2026-10-03, `/grill-me` with Richard: the smooth ring was hard
  to see, off-style, and its verdict unclear; `scripts/aim_ring.gd`, `AimRing`). Picked off
  `tools/last_aim_sheet.png` (`tools/shot_aim.tscn`, desktop build, own save: the real lake
  at play zoom over dirty, murky and clean water, the level-0 and a 2.4-tile net), candidate
  **A2** of four (A black outline / B white outline with a black edge, body 1 or 2 art px):
  a stepped 2:1 ellipse of whole art pixels on the mouth's own size, a body `THICK` 2 art
  px with its top row lit (`LIT`), ringed by one art pixel of `AIM_BACK` black, its middle
  snapped to the art grid. **The shape carries the verdict as well as the colour**, so it
  reads with the colour off: catch is a whole ring with four ticks pointing in
  (`TICK_SHARE` of the half-height, `TICK_LEAST` 3..`TICK_MOST` 6 art px); nothing is four
  arcs, the gaps (`GAP`) on the diagonals; out of range is bold white dashes (`DASH`).
  **Supersedes** the smooth ring, its backing line (`AIM_BACK_SHARE`/`AIM_BACK_WIDE`), the
  white rim and the dark colours, the 48-point ellipse and the alphas. Rejected on the sheet:
  B (the white swallowed the colour, catch and nothing both read "white ring"); offered and
  turned down: lighting the pieces that will be caught, a centre icon, a fill, a count, and
  quieter dashes. A layout is the cells whose middles lie in the band (signed distance
  through the gradient, position round the perimeter by arc length), only the band walked
  and one quarter mirrored, the rim grown eight-neighbour so it wraps every end; **cached as
  triangle arrays** (`_mesh`, `CACHE_MOST`) and drawn with one
  `canvas_item_add_triangle_array`, whose `count` is in triangles.
- **The marker moves** (2026-10-03, `/grill-me` with Richard; `CastNet.Mark`, `_note_mark`,
  `mark_halos`, `HALO_*`, `FAR_*`). **The ring itself never changes size**: it is the mouth,
  and a ring that swelled past it would claim a wider catch than the net has. What swells is
  a halo: the ring's body alone (`HALO_POP_THICK` 2 / `HALO_THICK` 1 art px, no outline),
  opening from `HALO_OUTSIDE` past the ring's middle line (or the ring's own outline covers
  it), growing against at least `HALO_SPAN_LEAST` (or the level-0 ring's never leaves it),
  and **dissolving pixel by pixel** (the foam's rule: the mesh's cells are bucketed by a hash
  and a shorter prefix is drawn). **Green**: a big halo the moment it turns green
  (`HALO_POP_*`), then **the song's own beat** (`MusicStation.beat_clock`, the animals'
  clock, handed in as `CastNet.music`): big on every `HALO_POP_BEATS`th (4) beat of the
  song's grid, small on the beats between, each small halo at most `HALO_OK_LIFE_SHARE` of a
  beat. The clock runs muted or muffled, as it does for the frogs. With no station (a
  harness) it keeps beatgucci's `HALO_OK_BPM` 135 on the net's own clock. **Red**: the same
  halo, smaller and slower (1.6 s), no pop. **Out of range**: no halo (a halo means a cast
  lands here); the dashes march round `FAR_MARCH` art px a second (`phase`, so a dash period
  is a dozen cached layouts) and the ring breathes (`FAR_BREATHE`, the layer's
  `self_modulate`). **Only while the net is idle**: with a cast out the ring is still, so the
  pop fires the moment the net is home on a green spot. Led-cast spots pulse as green does.
  Drawing only; idle, `_repaint` redraws the ring alone while it is up. Halo strengths went
  up for the pixel ring (0.95 / 0.8 / 0.6): at the smooth ring's alphas a dissolving pixel
  halo could not be seen.
  **Cost** (`bench_frames` `BENCH_AIM=1`, new, sweeps the reticle round the angler): 3.86 ms
  mean against 3.79 with no aim; with `BENCH_BIG` (the widest net) 4.20 mean, worst 8.0 —
  12.7 at p95 before the layout walked a quarter and bucketed rather than sorted.
  **The How to Play cards show it** (same day): the Net card's three stills and the Object
  Tier card's "Too heavy" re-shot with `LETTER_ONLY=net_catch,net_nothing,net_far,
  weight_heavy` on `tools/shot_letter_art.tscn` (new: names the stills to write, the rest
  left alone), the ring photographed calm (`CastNet.calm_ring`, probes only: no halo, still
  dashes). The heavy pose now aims at the **biggest** heavy piece in reach **where it is
  drawn** (`surface_pos`), not at its tile's middle: before, a small sock off-centre left the
  red ring round bare water. The other stills, the shed's and the shop's included, still
  show what they did.
  Out of scope: sounds, `FirstSteps`' sure ring. All numbers first guesses.
  `test_lake`'s `_check_aim_ring` guards the mouth's size, the ticks, the arcs on the
  diagonals, the dashes sparser and marching, every body pixel ringed, the halo plain, and
  the cache; `_check_aim_halos` the pop, the loops, red milder than green, no halo out of
  range or with the net out, none inside the ring, and the halo opening clear of the ring.
- **Out of scope, by decision**: hover, pressed
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
- **Nothing is built in code any more**: the siege's chime went with the siege
  (2026-09-29), and the lake-cleaned note (`play_found`) was cut on 2026-09-18, see The Ending. **The catch knock is cut, by decision** (2026-09-16, issue #1): every place
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
- **Closed, by decision** (2026-09-18): `chime.wav`, the lake coming clean, was the one
  sound still owed a recording. Richard cut the bell instead — the end song is the ending's
  sound — so `_make_found` is deleted and no take is owed.
- **The delivery format lines are struck too**: the spec's 24-bit 48 kHz PCM in
  `assets/audio/` describes a hand-off, and the hand-off is `art_source/SFX` at 24-bit
  96 kHz, which exceeds it. What the game imports is 16-bit 44.1 kHz in `assets/sfx/` and
  `assets/music/`, by design.
- **The SFX side of #1 is done** (2026-10-07, Richard: "done with the audio assets and
  application of them"). Everything since the audit is a recording in `assets/sfx/` or a
  written decision below. **#1 stays open only for Nuven's mastered songs**; see The Music.

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
- **Four sounds came down, and the crate thuds less often** (2026-09-18, Richard: "a bit more
  gentle on the ear"). In `SOUNDS`: `pop` -12 to **-15**, `net_splash` -12.8 to **-14.8**,
  `sniff` -6.8 to **-9.8**, and `wading` -10.9 to **-13.9** — read as "the entering water
  splash", since the wash is the only sound a walker going into the water makes; the entry
  ring is silent and `piece_splash` is a piece coming *out*. `Haul.POP_GAP` 0.07 to 0.22 and
  then, the same day, back to **0.15** (Richard: "can increase a little bit"): it was under
  the gap pieces land at, so every piece thudded; now a short volley thuds every second
  piece and a long one is capped at about six and a half a second. **The choice is in steps,
  not a dial** — between one and two staggers is every second piece, between two and three
  every third. **This supersedes "one pop per piece"** in `Haul._pop`'s older note. Keep the
  gap off a whole multiple of `Haul.STAGGER` (0.09), or frame jitter makes the run uneven.
  All by-ear knobs.
- **A landing says whether it caught** (2026-09-18, `/grill-me` with Richard: "there isn't
  much of a difference when I cast a net and it catches nothing"). An empty cast and a
  catching one played the same net splash at the same level; the catch added one piece
  splash on the same frame, masked, and a haul already a third as loud when empty.
  - **The net splash's ladder is split by catch** (`Sfx.NET_SPLASH_CAUGHT` 0.62-0.95,
    `NET_SPLASH_EMPTY` 1.0-1.3, `EMPTY_SPLASH_DB` -5, `play_landing`): six steps a half,
    each with its own never-the-last memory. Richard asked for more pitches in the same
    breath, and **random across the whole range a pitch cannot also mean anything** — so the
    extra steps were spent on the split. Low comes to mean "got something". Picked over
    random-with-level-only and over pitch following catch size. (The laid lit net's
    whole ladder and `play_net_splash` were deleted with the lit net, 2026-09-29.)
  - **Caught means the landing's own sweep took anything** — rubbish, a find, a bird, a
    charm. `CastNet._sweep` returns it, and **the landing sweeps before it sounds**; it used
    to sound first. `test_lake` reads the source for that order.
  - **A catch is one swell, then water draining off the mesh** (second `/grill-me` the same
    day, Richard: "too scripted, it feels the same every catch... less of a series of pops").
    `Sfx.play_lifted`, `_tick_catch`, `_sound_swell`. The piece splash plays **once** a
    landing, `SWELL_AFTER` (0.08-0.2 s, rolled) behind the net's own, louder and lower with
    `swell_size` — the root of the piece count against `SWELL_FULL` (12), mixed with the mean
    weight — and a pitch and level roll on top. `SWELL_SOFT_ODDS` of them start a few
    hundredths into the take, eased in over `SWELL_SOFT_IN`, so the attack is sometimes a
    slap and sometimes a round push; **eased, because a take started cold in mid-waveform
    clicks**. Then 0 to `DRIPS_MOST` (4) drips, the count **rolled** and only leaning with the
    size, each at a time of its own between `DRIP_FROM` and `DRIP_TO`, its own take and
    pitch, each quieter than the last. The double cast's second net joins the first's swell
    (`SWELL_GAP`) rather than doubling it. Dropped whole when the shop or the shed comes up.
  - **The drips are `drip_1`..`4`**, cut by `build_sfx.py` from `WaterSteps2.wav` and
    `Water_Steps.wav` — the two recordings retired as the angler's wet step for sounding like
    drips, which is what is wanted here. `WaterSteps2`'s 2 s dribble tail is not used; it is
    the obvious bed under a very full net if the drips read thin. `drip_4` is peak-limited
    and lands about 9 dB under the others: a drip that is sometimes barely there, accepted.
  - **A grab on the way home is a plip** (`Sfx.play_grab`, `GRAB_GAP` 0.32 s): one drip take
    pitched by what was grabbed. **The swell is the landing's alone** — a reel through a
    thick bay grabs several times a second and a swell each is the row of pops again. The
    haul rising with the load is what says the net is getting heavier. `CastNet._sweep`
    takes `landing` and hands `_lifted` to one or the other; `_take_from` no longer calls
    `play_splash` a piece.
  - **Retired the same day it was built**: a run of one to five piece splashes 0.09 s apart,
    counted off a ladder of piece counts (`CATCH_RUN_*`, `run_length`). There is one
    piece-splash recording, so it was the same take on a fixed beat with a count anybody
    could learn. **Don't vary one take by retriggering it**; vary it by what is rolled on it
    and by what follows it. Staggering the crowns to match was offered and turned down: the
    net's feel is locked, so this is **sound only**. **Not `play_catch`**: that was the
    retired knock's name and `test_lake` guards it staying gone.
  - **An empty reel is a whisper** (`Lake.EMPTY_WASH` 0.12, was 0.36 inline in `_net_wash`);
    the load brings the haul up as before, so a piece grabbed on the way home is heard.
  - **Out of scope, by decision**: any visual change, a new recording or built catch sound,
    the throw, the find's and the bird's own sounds.
  - All first guesses for Richard's ear. If empty casts read samey, the fix is more steps in
    the high half.
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
    when the player closes a board — cross, click off it, Escape (E no longer leaves the shed, 2026-09-29)
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

### The Second Batch of Sounds (2026-09-28, `/grill-me` with Richard)
Ten recordings in `art_source/SFX/New SFX - 28-09/`, cut by `tools/build_sfx.py` (`NEW`) and
levelled like the rest; `SOUNDS` holds the mix. All spans, levels and gaps are first guesses.
- **Shed doors** (`Sfx.play_door`): the creak replaces `shed_open` when the shed opens, the
  solid shut replaces `ui_close` when the player closes it (`Lake._shut`). Coming in from the
  wash room opens no door (`_room_swap`). Both on `WHILE_INDOORS`.
- **Rain and thunder, cut apart**: the storm recording has thunder baked in at fixed times, so
  `rain` is its quiet 12-24 s stretch as a loop and its claps, with the lightning-strike file,
  are `thunder_1..4`. One plays `Weather.THUNDER_AFTER` (1.2-3.2 s, was 0.6) after each
  flash, never the take played last.
- **Puddle steps** (`step_puddle`, `Sfx.play_puddle_step`, pitched in steps): a footfall on
  a wet puddle cell (`Puddles.here.standing_in`) and the angler's first step into the lake.
  Dogs get none. **Going into the water is never one pitch** (2026-09-30, `/grill-me` with
  Richard): the first step in is `Sfx.play_lake_entry`, the puddle's take on its own ladder
  (`ENTRY_PITCHES`, six steps 0.72-1.24, memory `lake_entry`, apart from the lawn's
  `PUDDLE_PITCHES`), and every play of the wading wash steps through `WADE_PITCHES` (five,
  0.88-1.12, narrower because it repeats every second). Never the step played last; the dogs
  share the wash's ladder. **The wash that opens a wade takes the entry's wide ladder**
  (`wade_pitch`, `_wade_fresh`, memory `wade_entry`): it lands a frame or two after the
  entry splash and is louder, so on the narrow ladder every entry still sounded alike.
  **Only a real entry counts** (same day, Richard: it fired in the water and coming out):
  `Angler._wake` calls the boots in once `Iso.past_water` passes `ENTRY_DEEP` (4 px) and out
  only back on the sand (0 or under), so a walk along the line or out of the lake splashes
  nothing; and only `play_lake_entry` sets `_wade_fresh`, so the wash stopping and starting
  in the water (a cast holds the feet) or a dog going in stays on the narrow ladder. The
  entry ring follows the same rule.
  First guesses by ear.
- **Wildlife, heard only within `Dog.HEAR` of the angler** (`Wildlife.ear`/`hears`,
  `Flora.ear`), each species on one shared rolled gap (`Sfx._due`): a frog's croak cue
  (`FROG_GAP` 6-12 s, pitched); a brood calling (`DUCK_GAP` 15-30 s, the mallard's three
  quacks or `GEESE_ODDS` of four far geese cuts); **the session's first brood always calls**;
  forest chirp cuts when a plant near the angler starts to show (`FOREST_GAP` 20-45 s); a bee
  at a heard flower (`BEE_GAP` 60-120 s), **panned left to right in the file** (`PAN_SWEEP`).
- **Out of scope, by decision**: a forest bed, the whole geese file, dog water steps,
  replacing the wading loop. `test_lake`'s `_check_new_sounds` guards the takes, the storm's
  files, the thunder's delay, the doors indoors, the frog's gap, the bee's pan (read off the
  built file: the import compresses it) and the earshot.

### Softer and Outdoors (2026-09-28, `/grill-me` with Richard)
- **The crate's and the hold's thud is muffled** (`build_sfx.py` `MUFFLE`, two one-pole low
  passes at 2.5 kHz on `pop`) and down to -17. Down too: `step_puddle` -16, `net_throw` -8,
  `pigeon_fly` -18.5, `bee` -17; `Flock.WINGS_GAP` 1.6 to 4 s.
- **A startled frog within earshot ribbits** `Sfx.FROG_FRIGHT_ODDS` (a third) of the time,
  held to `FROG_GAP` with its croaks (`Wildlife._frog_fright`).
- **The wash room is outdoors**: no shed sound on opening it, and `Sfx.indoors` is the shed's
  alone, so the lake goes on behind the pump. **Supersedes** "The wash room covers the lake
  as the shed's does" and the barks and coos being shut out (the room's own backdrop calls
  still come through `room_bark`/`room_coo`). The music stays muffled there.
- **Ducks are not startled by the ferries** (`Wildlife.walker_threats`, `Lake._wildlife_walkers`):
  the broods shy from moving walkers and net landings only. Every other animal still flees hulls.
- **The settings board no longer muffles the music**; the shop and the wash room still do.
  **Supersedes** "the settings board is new here" in The Music.

### Ambience Is the World (2026-09-29, `/grill-me` with Richard)
- **Every animal, the weather and the beds ride the Ambience bus** (`Sfx.AMBIENT`, `Sfx.bus_of`,
  set on each voice in `play` and on the coo and fire players): frogs, ducks, geese, forest
  chirps, bees, pigeon wings and coo, the dogs' barks and sniffs (the shed's and wash room's
  too), the wading wash, the fireplace, the lake bed, rain and thunder. **SFX keeps what the
  player does**: net, catch, crate, coins, upgrades, ferry, steps, doors, drops, hose, UI.
- Bus only, by decision: no level, gap or indoors/shopping gating moved. Ambience at zero now
  also silences thunder, accepted. `test_lake`'s `_check_buses` guards the split.

### The Issue #29 Sound Pass (2026-10-06, `/grill-me` with Richard)
Four new recordings in `art_source/` (not `SFX/`, so `PLAN` names them `../`), cut by
`tools/build_sfx.py`. **Supersedes** the crate's three `Object_in_box` takes and its
`MUFFLE` (The crate's thud, above), `Lake_Ambient.wav` as the bed, and the lake's hive hum
(The Beehive). All levels and gaps are first guesses for Richard's ear.
- **The crate's thump is `Thump_Plastic.wav`**, six takes (`pop_1`..`6`) picked by rule:
  single clean hits (three takes whose gap held a second sound left out), spread dull to
  bright by zero crossings over the first 80 ms. Not muffled. Never the take played last.
- **A catching landing is `net_land`**, six takes built by a new `mixes` cut: the net's
  splash with another lake recording laid under it (the boat's push, a WaterSteps2 splash,
  the puddle step, Object_Splash leading, Water_Steps leading), each levelled. Never the
  take before, on the caught pitch ladder, rolled `LAND_DB_ROLL` (1.5 dB). The empty landing
  keeps `net_splash`.
- **The bed is `Ambient_LAke.wav`** (an 88 s loop): the old one carried a recurring splash
  that read as the angler wading in.
- **The cardinal sings `Cardinal_Call.wav`** (`cardinal_1`..`5`, its whistled runs and
  trills); `Sfx.play_songbird(species)` gives the other three songbirds the forest takes.
- **Crickets in the late afternoon only** (`crickets` loop, `Sfx.CRICKET_*`): with the sun
  past `CRICKET_FROM` 0.62 (`Lake._push_sun` every frame), spells of 4-10 s from a random
  point in the loop, eased in and out, 15-40 s apart, at -26 dB. Not in the shed.
- **Each dog barks at its own pitch** (`Sfx.BARK_PITCHES` by slot, `bark_pitch`): dark brown
  0.82, yellow 0.94, tan-and-white 1.06, orange 1.18. "By size" was the ask, but the four
  sheets are one silhouette, so the darker coat has the deeper voice. Far barks and the
  wash room's hounds use it too.
- **No hum on the lake by the hive in any stage**: `Lake._push_hive_hum`, `HIVE_HUM_BUSY`,
  `Sfx.set_hive_hum` and its bed player are deleted. The gold mark is the cue. The room's
  catch-step buzz and the bees at flowers stay.
- **A lucky or double cast sounds on top of the throw** (same day, second pass):
  `lucky_cast` (`Lucky_Net_Cast.mp3`) when the roll makes the cast lucky, `double_cast`
  (`DoubleNet_Cast.wav` from 1.6 s, its final hit only) when the second net really flies,
  both when both (`Sfx.play_luck`, from `Lake._roll_luck`). SFX bus, own players, -11 dB, no pitch roll on either, the lucky one at `LUCKY_PITCH` 0.85.
- **The crate's thump came up 3 dB** (`SOUNDS[&"pop"]` -21 to -18).
- `test_lake`'s `_check_issue_29_sounds` guards the six takes of both, no repeat, the
  cardinal, the crickets' hours and spells, four distinct bark pitches; the hive stage
  guards the hum being gone.

### Four End-Game Fixes (2026-10-05, `/grill-me` with Richard)
- **A piece lifted off the dry beach throws sand, not a crown** (`CastNet._take_from`,
  `SAND_PUFF`, `CastNet.dust` = the lake's `KickDust`): a `grid.dry` tile puffs whole-pixel
  sand grains where the piece lay. The catch's sound is unchanged; strand pieces (in the
  shallows) still splash.
- **The last 30 pieces are marked** (`Lake.LAST_MARKED` 30, was 3): pale rim and white
  column on every one. **Off-screen pieces share an arrow by direction** (`LastArrows.arrows`,
  `GROUP_ANGLE` 22 degrees seen from the window's middle) with their count behind it when
  more than one. **A shrinking mark is no rebuild** (`LakeGrid.mark_last`): only a newly
  marked tile lays the soup out (once when the marking starts, again only if a piece lands
  on an unmarked tile, a tornado's fling); a tile leaving the set is restamped in place.
  Supersedes "relays the soup once per change".
  **A growing mark asks for the redraw itself** (same day, Richard: marked pieces stayed drawn
  after being netted): `_dirty` alone waited for something else to redraw the soup, and
  every take's `_restamp` stands down while `_dirty` is set, so nothing was patched until
  the view moved. `tools/probe_last_marked.tscn` (desktop build, own save) thins a new lake
  to 12 pieces, nets each and logs what the soup still holds for the tile.
- **Wildlife calls quicken with the crowd in earshot** (`Sfx.set_crowd`, `crowd_scale`,
  `CROWD_FULL`, `CROWD_LEAST` 0.25): a species' rolled gap shrinks linearly from one of it
  (as written) to `CROWD_FULL` of it (a quarter): frogs 8, ducks 3, songbirds 8, grown plants
  30 (forest), bee flowers 6. `Wildlife._push_crowds` counts frogs, broods and songbirds in
  `Dog.HEAR` every `CROWD_EVERY` (1 s); `Flora._listen_for_crowds` walks its candidates a
  slice a frame (the whole list once a `FOREST_LISTEN`) for grown plants and bee hosts, and
  **with `FOREST_LEAST` (5) plants grown round the angler the woods chirp on their own gap**,
  not only as a plant shows itself. A species never stacks on itself; different species may
  overlap. A bare shore keeps the old gaps.
- **The HUD buttons hop and throw gold motes** (picked A off `tools/last_pulse_mockup.gif`,
  `tools/pulse_mockup.py`; rays and both-at-once were the others): the burst hops on its
  first `HudSkin.BURST_HOPS` (3) beats, `HudButtons.HOP_PX` (6) whole pixels, rising and
  falling over `HOP_AIR` of the beat and squashing `HOP_SQUASH` on landing about the foot.
  **The squash is a transform over the drawing** (`HudButtons.base`, which `fit`'s mirror
  composes with), so nothing is rebuilt. Settled, it hops once every `IDLE_HOP_EVERY` (4-6 s)
  at `IDLE_HOP` (0.6) until the board is opened. Motes (`HudButtons.Motes`: whole pixels of
  gold with a dark rim, some 2x2, some four-point stars, fading in hard steps) drift up off
  the top and sides at `MOTES_BURST` 30 / `MOTES_IDLE` 8 a second. The badge keeps its gold
  ring. **The wash plank throws motes and does not hop** (`PlankButton.PULSE_MOTES`). The
  halo, the rays, `PULSE_LIFT`, `lift_by` and `HudButtons.pulse` are deleted. When a pulse
  fires and what stops it are unchanged.
- Probe: `tools/shot_pulse_base.tscn` (desktop build, own save, under its own node) saves the
  buttons at rest for the mockup; `PULSE_FILM=1` films the real pulse into
  `tools/film/pulse/`. All numbers first guesses for Richard's eye and ear.
- `test_lake`'s `_check_end_fixes` (sand, the thirty, the shrinking mark, grouped arrows),
  `_check_crowds`, and `_check_upgrades_pulse` (hop in whole pixels, motes, the squash, the
  idle hop) guard it.

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
- **The Music switch covers the ending, by decision** (2026-09-18): Habibs is on the Music
  bus like every song, so a player who has music off gets a silent ending. Found when
  Richard reported the credits song not triggering: the ending had fired (the save's
  `farewell` was true) and `settings.cfg` had `music_on=false`, written two minutes before
  the last piece. Overriding the mute was offered and not taken. **Before calling the end
  song broken, read `settings.cfg`.**
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
- **Habibs is an interim take, 3 #4.2** (2026-10-07, `/grill-me` with Richard, issue #1):
  `art_source/Music/Habibs 3 #4.2.mp3`, 170 s built, -8.7 LUFS, so `GAIN_DB` -2.4 (was
  -2.7); beat grid re-measured, 144 BPM, offset 0.3819. **The game only**: `Habibs 2#1.mp3`
  stays beside it because every trailer cut (`shots.json`, `shots2.json`,
  `shots_vertical.json`, 143.55 BPM, song in at 4.0 s) reads it by name. Don't delete it.
- **Nuven's mixed and mastered songs are owed** (expected the week of 2026-10-12, issue #1
  stays open for them). When they land: ask for **24-bit WAV**; point each `PLAN` entry at
  the master; **keep the levelling** (re-measure the built files with `ebur128` and re-fit
  `GAIN_DB` to Goin's level, whatever the masters' own targets); re-run
  `tools/measure_beats.py` (base python with the psd-extract venv's site-packages) and check
  by ear with `tools/beat_click.py`; reimport; run `test_lake`. **beatgucci is built whole
  first and Richard judges where it ends** — the 2:12 cut holds until then. **The trailers
  are re-cut once, on the final Habibs master**, not on interim takes.
- **Tests**: `test_lake`'s `_stage_music` drives its own station by hand: the order, the 2:12
  cut, the equal-power handover, shed and radio over a running playlist, the end song in and
  out, and the lake telling the autoload.
- **Credits**: every song and recorded sound is by Nuven (Richard, 2026-09-15), in
  `docs/CREDITS.md` and on the credits board.

### The Record Player (2026-09-28, `/grill-me` with Richard)
E on the record player in the shed lifts its lid and puts up a menu (`scripts/record_menu.gd`,
`RecordMenu`, a child of `ShedRoom`): which songs play on the lake and which in the shed.
**Supersedes the fixed playlist and "Indie Boi in the shed"** in The Music above; those are
now only the defaults.
- **Two tick columns, Lake and Shed**, over beatgucci, Save ME, Goin, Indie Boi and Habibs.
  A list plays in `MusicStation.SONGS` order and loops. **Habibs is locked** (padlocks) until
  the lake has been cleaned (`habibs_open`, from the save's `farewell`). **A list is never
  empty**: the last tick will not come off.
- **Sync, an on/off switch centred under the list**: the shed plays the lake's own song
  through the radio, at the same second; the Shed column greys out and shows the lake's
  ticks. The radio copy stays, by decision.
- **Two tracks, each on its own players** (`MusicStation.Track`): one song can be on both
  lists at different places in it. Every song now has an outdoors and a radio copy
  (`build_music.py`, `--only`); `indie_boi.mp3` and `habibs_radio.mp3` are new. The ending's
  Habibs has its own player and loops by hand, since streams are shared.
- **Now playing and skip** under the record show the **shed's** song (the lake's if synced).
  Unticking the song playing moves on to the next ticked one.
- **The needle moves on every change of song**, skipped or played through while the menu is
  up (`changes_in`): it comes up off the record (the head rises `ARM_RISE` over its shadow),
  crosses straight to the new song's band and sets down (Richard: no swing out past the rim).
  **A skip holds the song while the needle is up** (`hold`, `next_in`): it pauses as the
  needle lifts, and the next song starts only when the needle sets down on its band, about
  a second later. Closing the menu mid-skip lands it at once. **The record is an album**: five bands of grooves with smooth gaps between,
  `SONGS` order from the rim in (beatgucci outermost, Habibs by the label), and **the needle
  stands still in the middle of its song's band** (`band_middle`; Richard's second pass,
  superseding a needle that crept in with the song's progress). The
  record keeps turning through a skip (2026-09-29; it used to spin down), stepped at
  8 fps off 16 baked frames. **No white sheen on the disc**, by Richard's call.
- **The label reads "Nuven"** (2026-09-29, `/grill-me` with Richard, `LABEL_WORD`,
  `label_ink`): a 3x5 hand-set face at `LABEL_SCALE` 1.5 in `OUT` brown on a label grown to 16 art px (grooves from 17), curved round the top of the label, tops
  outward, baked into every spin frame so it turns with the record. Replaces the amber mark.
  Not translated.
- **Saved in the run's save as `records`** (`picks`/`take_picks`); a save without it reads
  as the old fixed lists. No `SAVE_VERSION` bump. **Always applies**, placed or not.
- **The lid is only a picture**: E opens it and it stays open after the menu closes
  (Richard, second pass). The room
  takes no input and gives up the stick while the menu is up; Escape, E, the cross or a
  click off the board close it. On the pad the ticks, switch, skip and cross are stops.
- **Drawn in the sprite's own colours** on 3 px art pixels (option A of
  `tools/build_record_menu_mockup.py`, picked by Richard with the mode keys cut and Sync
  moved under the list). Five keys `RECORD_*` in `translations.csv` are machine drafts;
  song titles are names and not translated.
- **Out of scope, by decision**: shuffle, per-song volume, a beat grid for Indie Boi (it
  runs on `FALLBACK_BPM` if ticked for the lake).
- `test_lake`'s `_check_record_lists` (station) and `_check_record_player` (shed) guard the
  rules. Probe: `tools/shot_record_menu.tscn` (desktop build, own save) saves
  `tools/last_record_menu_{apart,synced,skip}.png` and `last_record_menu.log`.

### The Beehive (2026-09-30, second pass off `tools/hive_mockup2.py`, Richard)
An old hive on the island's lawn takes a swarm mid-run and makes honey. Build contract:
`docs/hive/contract.md` (first pass; this section supersedes it where they differ). `Hive`
(`scripts/hive.gd`), `HiveRoom`, one `HiveStep` script a step, art by `tools/build_hive.py`.
- **The arc is split** (`Hive.PLAN_*`): a swarm visit is **Catch, Smoke, Queen**, and ends
  there: the colony goes `BUSY` on the ordinary refill clock (`_on_colony_settled`), the card
  reads `HIVE_HINT_SETTLED`. A colony caught and left before its queen is `SETTLE` (appended to
  the enum, so saved numbers keep their meaning) and plays Smoke, Queen. **Every harvest, the
  first included, is Uncap, Pour.** The crank is deleted (`hive_step_crank.gd` gone, nothing of
  it was saved).
- **The first honey has a moment**: the wildlife moment's queue (`_owe_moment`), a glide to the
  hive and "The honey is ready!" (`HIVE_READY`), once (`Hive.ready_seen`, saved; absent reads as
  seen when a harvest was already taken). Later refills show only in the world's ready mark.
- **Old saves**: a `READY` saved with `first_done` false was a caught colony mid-ceremony and
  loads as `SETTLE`. No `SAVE_VERSION` bump.
- **No hands anywhere**: the pointer holds every tool.
  - **Catch**: no branch. Five clumps of real bee sprites in the air; press on one and drag,
    its bees chase their places at their own paces so it trails the pointer; let go over the box
    and it pours in, `MISS` of it flying back to a cloud. The heap over the bars and five comb
    pips on the box's front fill; done at 80% boxed (`ENOUGH`), the rest pours in by itself.
  - **Smoke**: the smoker is held by its bellows at the pointer. Three rings over the swarm on the
    hive; hold with the nozzle in reach of one and billows (the builder's `billow_*`, four
    greys) curl to it; its bees fold their wings, the ring goes green with stars. ~400 bees over
    a dark core. No penalty. **Top to bottom since 2026-10-04** (see Hive Fixes below).
  - **Queen**: the brood frame in a pine uncapping rest (`rest`), 330 workers. The lens as
    before; a miss sends the bee clicked buzzing off and wobbles the glass; after `HINT_AFTER`
    (20 s) a faint glint winks on her. Bigger and moving differently since 2026-10-04.
  - **Uncap**: one face in the same rest, the knife dragged down the comb. Curtains run off the
    cut into a slanted tin gutter; the honey is fatter than the tin, bulges over its rim, spills
    over the lip, and runs off the low end into the bucket, where it lands in folding coils.
    **Every unit is kept** and the bucket's level is handed on (`HiveRoom.honey`). The stream,
    the knife's drag and the gutter's look are 2026-10-04's (below).
  - **Pour**: the same bucket on the bottling table, its level carried over; a brass lever with a
    wooden grip on the gate: hold on it and it turns sideways and honey runs, thicker as it
    opens; let go and it springs shut. Fill each jar to the dashed line; over it the jar crowns
    and runs, no penalty. Jars are the builder's `jar2_*` layers (blue-grey glass edge, faint
    tint, highlight streaks, small gingham lid), the honey drawn between them with a meniscus.
- **Honey motion is drawn only** (the rope's bargain): springs and eases on whole art pixels,
  nothing gameplay reads but the jar count.
- Harness hooks per step, never gated on `awake` (see each script's header); `test_lake`'s
  `_stage_hive` drives them. Probe: `tools/shot_hive.tscn` (desktop build) saves
  `tools/last_hive_{empty,swarm,moment,ready,busy,honey}.png` and
  `tools/last_hive_room_{catch,smoke,queen,settled,uncap,pour,done}.png`.
- All numbers are first guesses for Richard's eye.

### Hive Fixes (2026-10-04, `/grill-me` with Richard)
**Supersedes, above**: "Later refills show only in the world's ready mark" (the mark is over
every actionable hive now), "Three rings ... any order", "the queen a subtly longer bee (no
court)", "falls off the low end as a sprung rope", and the pour's glug.
- **The gold mark and the key** (`Hive.mark`, `_draw_chip`, `CHIP`): the orb bobs over the roof
  whenever there is something to do (a swarm, a colony to settle, honey ready). With the angler
  in reach (`lit`, `_at_hive`) it turns into a wooden key chip, the shed room's prompt, naming
  the `interact` key (the pad's button in pad mode). **Hive only**: the pump and the door keep
  their lamp. The lamp is left only over the no-picture post; `lamp_point`/`LAMP_OVER` gone.
- **Messier bees**: the swarm on the lake has `SWARM_SPECKS` 22 bees each circling its own spot
  out to `SWARM_REACH` and peeling off on loops (`SWARM_PEEL`). In the room, **every step has
  loose bees wandering the air** (`HiveStep.wanderers`/`draw_wanderers`, `WANDER_*`: goals rolled
  anywhere in a box, weaving, turning on a lag, drawn behind the work): catch 28 over the sky,
  smoke 36 over the whole scene (its old cloud of 60 round the swarm gone), queen 8, uncap 7
  (its five figure-eight bees gone), pour 6. Catch's clumps are looser too (`SPREAD` 34x20,
  `JITTER` 4) and each bee now and then strays out of its clump on a loop (`STRAY` 46, `_stray`).
- **Smoke goes top to bottom** (`hive_step_smoke.gd`, `RINGS`/`RING_HALVES`, `BAND_TO`): the top
  of the beard, its middle, then the entrance slit. **One ring lit at a time** (`_now`), a faint
  pulsing arrow down to the next; smoke anywhere else only drifts; `smoke_ring` refuses an
  out-of-order stop. While a band is smoked its quiet bees sag towards the entrance (`SAG`);
  once quiet its bees walk down the face and crowd the landing board (`Walk.DOWN`/`CROWD`,
  `CROWD_HALF`), and the done ring fades green (`DONE_FADE`). The entrance quiet, the crowd and
  the bottom of the beard file in; done once all are in or `IN_WAIT` after.
- **The queen** (`build_hive.py` `queen_long`, `_QUEEN_SHAPE`): **18 by 7**, banded two gold to
  one dark in a richer orange gold (`QUEEN_GOLD`, `QUEEN_LIT`), and a laying pose (`queen_lay`,
  her tail dipped a pixel). She **glides** at one pace (`QUEEN_SPEED` 4) on a slow arc swinging
  side to side (`QUEEN_ARC`), never a twitch, while the workers crawl in stops and starts
  (`STUTTER`) and turn sharper and oftener (`WORKER_SPIN` 2.6, `RETARGET` 0.25-0.9). **Workers
  in her path shuffle aside** (`_parting`, `PART_*`); a loose court of `COURT` 5 faces her;
  every 2.5-4.5 s she may stop to lay, dipping her abdomen on `QUEEN_LAY_BEAT`. One worker on
  her back, not two. `WORKER_CLEAR` 14, `QUEEN_GRACE` 6 for the bigger body.
- **The knife drags** (`hive_step_uncap.gd`): `EASE` 5 and `MOST_SPEED` 55 (a face in three
  seconds, was one), pad paces under the same cap. Pulled more than `STRAIN_FROM` ahead it
  strains (`_strain`): the blade shudders a pixel, the sizzle swells and drops in pitch, a
  crackle every `STRAIN_CRACKLE`, and a taut dashed line runs from the handle to the pointer
  (`_draw_taut`, mouse only). Never fails, never faster.
- **Honey tips are round** (`_curtain`): a curtain on its way down ends in a bead (`TIP`), and
  one no longer fed necks to a thread at its top (`NECK`), where both ended in a flat cut.
- **The gutter is juicier**: a rounded tin channel (back wall with a lit rolled edge, a rolled
  front rim drawn over the honey's foot, honey lapping over it when deep), iron `STRAPS` up to
  the frame, end caps and a pouring lip; honey with a lit top, an amber core, ripples running
  downhill (`RIPPLE_*`), glints sliding down with the flow (`GLINTS`), air bubbles riding along
  and popping at the low end (`_bubbles`, `BUBBLE_*`), and spills leave smears down the tin
  (`_smears`, kept for the visit).
- **One stream, drips only at the end** (`_drive_rope`, `_draw_stream`): while the gutter runs
  the honey leaves the lip as one wobbling stream (`STREAM_*`), its head falling to the pool, a
  little heap and coils where it lands (`COIL_EVERY`). When the flow drops under `STREAM_OFF`
  it lets go of the lip and its tail falls in after; only then does what is left on the lip
  bead and drip (the old rope's spring, `SNAP_MASS` 10). Every unit still counted
  (`honey_left` holds `_stream_mass`).
- **The bucket fills from empty** (`_draw_pool`, `_pool_y`, `POOL_DEEP` 12): the honey's surface
  starts down inside the bucket and is clipped to the mouth, a crescent at its foot rising to
  the whole mouth at the brim. It used to sit at the brim from the first drop.
- **The jar-fill sound is rebuilt** (`HiveSounds._pour`, `_bubble`, `_glop`, `POUR_*`): no hiss;
  a low thick bed breathing three times a 2.4 s loop under round bubble blips that climb in
  pitch, some popping twice, some on a low glop. The step still raises its pitch as the jar
  fills. By ear.
- All numbers first guesses. `test_lake`'s `_stage_hive` guards the orb and the chip, loose
  bees in every step, the smoke's order and the bees gathering at the entrance, the queen's
  size and pose, the knife's cap and strain, the empty bucket, the stream with no drops while it
  runs, and the bucket filling.
- Playable: `tools/play_hive.tscn` (desktop build, own save removed on the way in): a swarm on
  the hive and the angler a few steps off; F1 swarm, F2 honey ready, F3 colony to settle, F5
  back to the hive.

### Hive Fixes, Second Pass (2026-10-04, `/grill-me` with Richard, off `play_hive`)
**Supersedes, above**: the queen at 18 by 7, the uncapping rest under the queen's frame, the
catch box's glow, and each step's own crown and star burst.
- **The bucket's near wall** (`build_hive.py` `bucket_front`, the bucket's pixels below the
  mouth's middle less its inside): drawn over the stream and the drips in the uncap step, so
  honey ends on the pool. Where the stream lands, a low mound in the pool's colours and rings
  of light spreading through the surface (`_draw_landing`, `LANDING_RING_*`), everything
  clipped to what of the surface shows in the mouth (`_on_pool`). The bucket's label is gone
  (one picture, both steps).
- **The pour's bucket empties** (`_draw_level`, `POOL_DEEP`): the uncap step's rising-surface
  picture run backwards, from `HiveRoom.honey` to nothing over the three jars (it moved 3 px).
- **Honey into a jar sits in the honey** (`_draw_coils`, `MOUND_TALL`, `FOLD_TALL`,
  `SINK_DEEP`): a mound in the surface's light where the stream lands, each fold a pair of
  humps sliding out along the surface and settling, a darker swirl sinking under; inside the
  glass. The floating rings are gone.
- **The catch**:
  - the three yellow ellipses gone; the mouth lights while a clump in hand is over it
    (`MOUTH_LIT`, `_over_mouth`);
  - the box's shadow a solid core and a checkered fringe (`SHADE_CORE`, `SHADE_FRINGE`);
  - the five comb cells round and centred on the box's front (`PIP_Y`, `PIP_R`, `_disc`);
  - a dashed ring breathing and turning round each clump in the air (`_draw_marks`,
    `MARK_*`), hidden on the one in hand;
  - once caught, the pile crawls down through the cracks between the top bars, top last
    (`CRACK_*`, `DRAIN_*`), `PAYOFF_HOLD` 2.6;
  - sound (`HiveSounds._whoomp`, `_chime`, the step's own `Buzz`/`Whoomp`/`Chime` players on
    SFX): the colony's hum while a clump is in hand, up `BUZZ_FADE`, higher the faster it is
    dragged; a whoomp and a chime a step up `CHIME_STEPS` for each clump poured. The old
    `hive_swarm` on a pour is gone. By ear.
- **One ending for every step** (`HiveStep.payoff`, `draw_payoff`, `payoff_crown_at`): gold
  rays of whole pixels fanning up out of the thing finished (`RAYS`, `RAY_*`), stars twinkling
  in and out each on its own beat (`PAYOFF_STARS`, `STAR_COME`, `STAR_SHOW`), the crown
  dropping in with a bounce and a soft gold halo (`CROWN_*`). Catch over the box, smoke over
  the hive, queen over her (drawn on the lens's rim), uncap over the comb at the sweep's foot,
  pour over the jars on the board. The steps' own crown pops and star bursts are deleted;
  smoke's per-ring stars, uncap's sweep stars and pour's lid stars stay.
- **The queen is 15 by 5** (`_QUEEN_WIDE`, `_QUEEN_SHAPE`; 17 by 9 inked): the banding, gold,
  laying pose and her ways unchanged.
- **She is looked for down in the open hive** (`build_hive.py` `hive_well`, `well_back` and
  `well_front`, `WELL_*`): the box seen from above at a tilt over the whole grid, its back wall
  and side walls, rows of frame top bars (two behind the tipped frame, seven in front, growing
  nearer), the next frame's comb dim either side, and the middle frame (`frame_brood`) tipped
  back between them. The bars come to the step as `well_front`'s `bar<k>_l`/`_r` anchors
  (`_read_bars`); `BAR_BEES` crawl along them, stopping and turning (`_walk_bar_bees`). The
  rest and the lawn shadow are gone from this step (the uncap step keeps its rest).
- All numbers first guesses. `test_lake` guards the queen's length, the open hive and its bar
  bees, the catch's payoff, and the bucket's near wall.
- **Third round, same day** (Richard, off `play_hive`):
  - **The smoker puffs**: the bellows are three pictures (`build_hive.py` `smoker(squeeze)`,
    `smoker`, `smoker_half`, `smoker_shut`), the back board swinging in and out over each
    `PUMP` (`_bellows`), and every squeeze plays `hive_puff` (`_say_puff`, `PUFF_DB`).
  - **No shadow behind the swarm**: the beard's dark core rows and the settle under the ring
    being smoked are deleted.
  - **The curtains sink into the gutter's honey** (`_curtain`'s `join`, drawn after the honey
    in the tin): `SINK` px in, flaring `FLARE_WIDE` over the last `FLARE` rows in the honey's
    top colours with no dark edge (`_soft_row`). **A falling foot is a teardrop of the curtain
    itself** (`_tip_width`, `TIP_*`), and the stream's head into the bucket the same; the
    ringed `_blob` on their ends is gone (`TIP` retired).
  - **The drag buzz hums rather than revs**: pitch rises a few percent at most
    (`BUZZ_PITCH_PER` 0.0004, `BUZZ_PITCH_MOST` 1.08), speed makes it louder
    (`BUZZ_LOUDER`, `BUZZ_FAST`), and it wavers (`BUZZ_WAVER`). The chime is up to A5
    (`CHIME_HZ` 880, was E5).

### Steam Achievements (2026-10-06, `/grill-me` with Richard)
Nine achievements on App **5375170**, through GodotSteam. The game runs exactly the same
without Steam. `scripts/achievements.gd` (`Achievements`), the lake's "Achievements" section
(`_audit_achievements`, `_earn`, `_achievements_step`), and `docs/steam/achievements.md`, the
sheet Richard enters on Steamworks.
- **GodotSteam is a GDExtension** (`addons/godotsteam/`, 4.23-gde, Steamworks SDK 1.65,
  Windows x86_64 only, the `.gdextension` trimmed to that). The stock exe stays. The export
  preset excludes `addons/godot_ai/*` and no longer all of `addons/*`, or the extension would
  not ship. **The licence travels with the build**: see `docs/CREDITS.md`, Tools.
  `steam_appid.txt` in the project root is for dev runs. `tools/probe_steam.gd` (`--script`)
  says whether the extension loads and Steam starts; run it by hand only, because it starts
  Steam for the app.
- **`Achievements` is not in `project.godot`'s autoloads.** `Prefs._ready` hangs it off the
  root (the editor re-saves project.godot from memory). Steam starts lazily, only when the
  game's own lake hands it something, never under `--headless`, and never when the extension
  or the client is missing. No relaunch through Steam, no DRM.
- **What is earned lives in `user://achievements.cfg`, not in the run's save**, so it
  survives a New game. Everything in it is pushed to Steam each time Steam starts, so an
  unlock made offline lands later. **Resetting while testing means deleting that file as
  well** as clearing Steam, or the game hands the achievements straight back.
- **Only the game's own lake hands achievements on** (`_owns_achievements`: hung off the root,
  on `SAVE_PATH`, no `session_save_path`). Every lake still works them out into `achieved`,
  which is what `test_lake` reads.
- **Two kinds.** What the save proves is asked on every load (this is what makes them
  retroactive, by Richard's call) and every `ACH_EVERY` (1 s) while playing, so none of these
  needs an event wired:
  - **Friend of Nature**: `_farewell_shown`.
  - **Cheapskate**: `sludge >= CHEAPSKATE_AT` (100,000) at one moment.
  - **Maximalist**: every `TRACKS` row at its cap. The hose does not count.
  - **Honeymaker**: `_hive.harvests > 0`, the first uncap and pour done.
  - **Island DJ**: the record player in `switch_tried`, which `ShedRoom._open_record` writes.
  - **Best Pals**: `dog_count() == MAX_DOGS` and every slot in `petted`.
  - **Decoraholic**: every keepsake def in `_grid.defs`, every copy, washed into `unlocked`.
    Read off the catalogue (60 finds), **not off what this save's water held**, by decision:
    a save from before the 2026-10-03 batch needs a new game.

  Moments are earned where they happen and count from 2026-10-06 on, since nothing recorded
  them before:
  - **Great Net**: the cast's count over the angler (`_haul_count_step`) reaching
    `GREAT_NET_AT` (100). It is both nets of a double cast, plus anything a tornado hit
    poured in, so a single net (64 at the top) never gets there.
  - **Twistered**: `Tornado.ended(true)`. Untamed, or settled by a save or the menu's pose,
    does not count.
- **`petted`** is saved (slots, absent reads as none). The lake dog's `petted` signal and the
  shed's new `ShedRoom.dog_petted(slot)` (at the touch) both tally into it. No
  `SAVE_VERSION` bump.
- **Maximalist is a plan-for-it achievement**: all 17 tracks cost 868k. The lake's pieces pay
  673k (`probe_fill_economy`), and the rest has to come from the Recycle Bonus (a quarter of
  sales boosted, up to +200%) and the pigeons. Judged with Richard before shipping; see the
  session's report.
- **Icons**: `tools/build_achievement_icons.py` (base python with the psd-extract
  site-packages, `--write`). It writes 64 px PNGs, unlocked and greyed, to
  `Marketing/My Dirty Little Lake/steam/achievements/`, plus the contact sheet
  `tools/last_achievement_icons.png`. The game icon's water square with the game's own sprites
  on it: armchair and vase, the peacock among flowers, two dogs and a heart, a heap of
  rubbish, the HUD's green arrow, a rule-built funnel, the bottling jar, the record player
  with notes, a stack of coins. Rules first, for Richard to pick over.
- **Out of scope, by decision**: translations (English only), hidden achievements, progress
  stats, an in-game list or toast.
- `test_lake`'s `_check_achievements` (end of `_stage_save`) guards: nine ids; a harness lake
  never hands achievements on, touches the earned file or starts Steam; sixty finds; every
  audit rule against its near miss; both pet paths; Great Net at 100 and not 99; Twistered
  tamed and not untamed; the pets saved.

### Steam Cloud, Rich Presence and the Deck (2026-10-06, Richard, issue #33)
- **Steam Cloud is Auto-Cloud, no code**: `my_dirty_little_lake.save`, its `.bak` and
  `achievements.cfg` under `WinAppDataRoaming` / `My Dirty Little Lake`.
  **`settings.cfg` is not synced, by decision**: the window, resolution and binds belong to
  the machine, and a PC's must not land on a Deck. The path is the game's own user dir
  (see The Rename), so changing its name means changing Cloud too. The Steamworks steps
  are in `docs/steam/cloud_and_presence.md`.
- **Rich Presence is percent only** (Richard's pick over a line per activity): "Cleaning the
  lake: 42% clean", from `Achievements.presence_clean`, which the game's own lake calls each
  frame. It reaches Steam only when the whole percent changes. The words are the `#Status`
  token in `docs/steam/rich_presence.vdf`, uploaded on Steamworks, English only. The figure
  carries its own `%`.
- **Controller support is kept** (Richard): Xbox and PlayStation, Steam Input off for both on
  Steamworks. See The Gamepad and The PlayStation Pad.
- **The Deck pass is on the desktop** (`tools/shot_deck.tscn`, desktop build, `--fixed-fps
  60`, own save; `DECK_H=720` for the smallest window). At 1280 x 800 the canvas is
  1280 x 800 at a stretch of 1, the smallest text is `TEXT_TINY` 11 px (Valve asks for 9),
  and every board reports nothing dropped or overrun. **One bug found and fixed**: there the
  shed steps up to zoom 3 and fills the window, and its shelf ran under the shed's own
  Upgrades button, which covered the title and the cross. `ShedRoom._zoom` now steps down
  while the shelf would meet `keep_clear` (the button's box, set in `Lake._set_shed`).
  1080p and 1440p were already clear and keep their zoom. **Not measured**: the Deck's GPU.
  The cleaned lake runs 7-9 ms on an RTX 5060 Ti, so expect the frame cap to matter there.
  Valve's review decides Verified.

### The Rename (2026-10-06, Richard: "the name of the game is My Dirty Little Lake")
"Lake Cleanup" was the working title. Everything is My Dirty Little Lake now: the folder
(`Games/My Dirty Little Lake/`), `config/name` (the window's title), the exe
(`MyDirtyLittleLake.exe`, with its file properties filled), the docs, issue titles and the
`project:my-dirty-little-lake` label.
- **The game has a user dir of its own**: `application/config/use_custom_user_dir`, named
  `My Dirty Little Lake`, so `%APPDATA%\My Dirty Little Lake\` and no `Godotpp_userdata`
  in the path. The run is `my_dirty_little_lake.save` (`Lake.SAVE_PATH`). Steam Cloud syncs
  that folder.
- **Old files are copied over once** (`Prefs._bring_old_files`, before the settings load): if
  the new folder holds neither a save nor `settings.cfg`, the save (renamed), its backup,
  the settings and `achievements.cfg` are copied from `Godot/app_userdata/Lake Cleanup`. The
  old folder is left alone. Probes' own saves are not brought over.
- **Left with the old name, by decision**: file names already on disk (`_builds/lake_cleanup_v*`,
  `lake_cleanup_tree.save` and the other retired saves named in history), git history, and the
  `Lake` class and its code names. "Lake Cleanup" in a note older than this one is the game.

### The Steam Demo (2026-10-09, `/grill-me` with Richard)
A separate Steam demo app (no festival), about 25 minutes. `scripts/demo.gd` (`Demo`), the
lake's "demo's finale" block, and the **Windows Demo** export preset.
- **One codebase**: the preset's `demo` feature tag is the demo (`Demo.on()`; `Demo.forced`
  for tests). Its own save, `user://my_dirty_little_lake_demo.save`; nothing carries into the
  full game, by decision. No achievements and no Steam calls in the demo (`_owns_achievements`).
- **Cut by caps** (`Demo.CAPS`, read by `Lake._level_cap`): every track stops short (Range 4,
  Strength 1, Catch 3, ...), so only the water round the island is worked. A capped row reads
  MAX; nothing says what is locked, by decision. `Demo.PRICES` overrides prices
  (`Lake.cost_of`); **empty, so the demo runs on the full game's prices until its economy
  pass** (the sim with a demo spec, then a logged run).
- **The finale** (`_demo_step`, `demo_bought_out`, `_end_demo`): the last level bought brings
  down one tornado (the run's first, 3 hits); when it ends, tamed or not, the farewell comes
  up with the demo's words (`DEMO_LINE_1/2`), the credits and a **Wishlist** door
  (`Farewell.wishlist`, `open_store`, `Demo.STORE_URL`) beside Back to menu. `_farewell_shown`
  is the demo's done flag. A save or the menu's pose settles the tornado without `ended`, so
  the finale is owed again.
- **Off in the demo**: the tornado schedule, the hive's swarm (the hive stands as scenery).
- **Finds** are dealt only within `Demo.REACH` (9) tiles of the shelf and up to tier
  `Demo.FIND_TIER` (1), never under heavier rubbish; the rest are not dealt.
- Machine drafts for the three new strings. All caps and reach first guesses.
- **Open**: the demo economy (prices, the 25 minutes), what Continue does on a finished demo
  save, the demo's Steam app id and depot. `test_lake`'s `_check_demo` guards the caps, the
  bought-out rule, the finale and its hold, the owed finale, and the ending's door.

### Archive
- The earlier `_pipeline/tools/generate_art.ps1` (ComfyUI pipeline) and EBC photo approach are archived.
- Do not resurrect unless vertical slice changes scope to explicitly include photoreal art.

### Scale Authoring
Sprites are authored for the isometric tile size (`Iso.TILE_W = 64`, `Iso.TILE_H = 32`). Changing
sprite scale breaks the grid assumptions.

### The Decoration Catalogue (the collection)
The finds — the furniture the player nets and stands in the shed — come from
**`art_source/Decoration_Clean_Dirty.psd`, the one file** (2026-09-20, `/grill-me` with
Richard): Richard edits it, the build pulls from it, and the stale extensionless twin of it
is deleted. It holds two layer groups: `Decoration` (restored, as the shed shows it) and
`Decoration Dirty` (grimy, as the lake shows it). 37 finds (2026-09-13: the kitchen chairs
and the old table cut, four rubbish-born finds added — see The Shed Floor below).

**Pipeline** (all offline, run from the project root):
1. `psd-extract` skill → `art_source/decoration_extracted/` (one PNG per layer + manifest).
   `art_source/.gdignore` keeps these out of the Godot project.
2. `tools/decor_sets.json` — the numbers, and the older authored entries.
3. `tools/build_decor.py` → `assets/decor_clean.png`, `assets/decor_dirty.png`, and the
   decor half of `assets/pieces.json`.

**A new find is drawn, not written down** (2026-09-20). A piece is a **group** under
`Decoration` holding **one layer per view**, plus one layer of the same name under
`Decoration Dirty`; the group's name is the title and its `(rotate)` / `(variant)` /
`(state)` suffix is the mechanic. Roles are the layer names, in the PSD's own stacking
order, and a one-view piece needs no suffix and is `SINGLE`. Nothing about such a piece is
authored in `decor_sets.json`, and a piece may not be in both places.
- **The suffix exists because the role words cannot carry the mechanic.** The rugs turn
  between `wide` and `long`, which no vocabulary of faces would have guessed; `round`/`oval`
  is a restyle and `shut`/`open` is a switch, and by their names alone they are the same
  shape of thing. Gap detection finds rectangles; only a person can say what they are —
  the PSD is now where that person says it.
- **Tuning numbers never come from the PSD**, by decision: `place`, `base`, `base_px`,
  `seat`, `scale`, `copies`, `mirror` live under `tuning` in `decor_sets.json`, keyed by
  piece name, because they are set by eye against the shed and retuned without reopening
  the art.
- **A piece is always a group, never a bare layer**: the flat layers under `Decoration` are
  the 37 authored finds, and reading those as pieces too would claim every one of them
  twice.
- **Mirror is derived, not asked for**: a `ROTATE` piece whose three roles are exactly
  `front`, `side`, `back` gets the fourth face flipped, as the sofa always did. Anything
  else is what is drawn.
- **The 37 authored entries do not move.** They keep their several-views-to-a-layer
  rectangles; the builder reads both and the sheets came out byte-identical when it landed.

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

### The Second Batch: Switches, Two Axes, Two Finds (2026-09-20, `/grill-me` with Richard)
Richard's PSD pass: switched-off views for seven pieces, a colour for the oval rug, and the
aquarium and the rug as new finds. **He kept flat layers** rather than the group convention,
so these are authored entries; every new view is a whole layer, no rects.
- **Layers are referenced by group and name, never by slug** (`build_decor.layer_file`,
  `'Decoration/Drawer#2'`). Moving `Decoration Dirty` above `Decoration` in the file swapped
  every psd-extract slug (`lamp` became the dirty one). Mapped by **pixels** on the way over:
  every old sprite has an identical new layer bar three deliberate changes — the counter's
  new dirty sprite (`Kitchen Counter Empty Dirty`, the old dirty counter layer is gone), 23
  retouched pixels on the dirty lamp, 11 on painting B. The bed's two views are plain files
  from another PSD and kept as such.
- **Every view has a face and a state** (`faces`/`states` in `pieces.json`, `Sheets.turned`/
  `switched`/`is_on`/`face_of`). R goes to the next face — in the same state where that face
  was drawn in it, otherwise in whatever state it was — and E flips the state keeping the
  face, **or does nothing where the other drawing was never made**. Plain rotations count
  faces, plain switches count states; the two are authored per view only where a piece does
  both. **Supersedes "the two verbs are exclusive"**: the toilet (front/side × empty/full)
  and the kitchen counter (front × empty/full, plus a full side with no empty twin) turn
  *and* switch (Richard: both mechanics, "empty counter face front only").
- **View 0 is what leaves the store and it faces front, switched off** — the builder refuses
  anything else. Off is the drawn-as-found state: record player closed, lamps off, water
  empty. `STATE_ON` is gone: which view is on is the catalogue's to say.
- **Light is per piece** (`light`: `fire` / `warm` / `cold` / none, `Sheets.light_of`):
  `fire` is the hearth — the warm pool and the crackle, the only thing that crackles; `warm`
  the lamps (`LAMP_*`, a smaller softer pool, silent, first guesses); `cold` the open fridge.
  The record player, the water and the aquarium switch in silence. Until now every switched-on
  piece that was not an open fridge counted as a fire, which held only while there were two.
- **Both states of a face share one frame** (`build_decor.shared_frame`, 2026-09-21,
  Richard: the lamp and the fridge "getting dislocated sideways"). Each view was cropped to
  its own drawing and a lit shade or an open door makes that crop a different size, so E
  moved the piece. The builder slides the on-view over the off-view to where the most pixels
  match exactly (nearest offset on a tie, within `ALIGN_REACH`) and pads both into the box
  holding them — measured every build, picked over hand-aligning layers in the PSD. The cost,
  taken: a switched piece's footprint is the union of both drawings in either state.
- **A mirror flips every side view** (same day, Richard: the toilet "can be flipped on both
  sides"): it was the sofa's rule — exactly one `side` — and now takes each view whose role
  starts with `side`, in its own state, as one new face. The toilet turns front, side, other
  side, empty or full. Flipped after aligning, so a flipped pair stays aligned.
- **The record player is visual only**, by decision. Letting the player pick the song on the
  lake and in the shed was raised and is **a later pass**.
- **`SAVE_VERSION` 13**: two finds joined and seven pieces changed what view 0 is.
- `test_lake` guards R and E each moving only its own axis, the store rule, the toilet's
  full side, the counter turning empty-to-full and refusing E side on, the light table, a
  lit lamp pooling without crackling, and the two new finds.

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
- **E** works a switchable piece the player is **standing at** (`REACH`), with an on-screen
  prompt: fireplace, fridge, both lamps, the record player, bathtub, sink, toilet, counter.
  A lit piece throws a pool through `shed_light.gdshader` by its **light**, not by being
  on (see The Second Batch below).
- The view a piece stands in persists in the `decor` row as `"view"`.
- **Copies**: a find can be hidden more than once — `copies` in `decor_sets.json`, baked
  into `pieces.json`, read via `Sheets.copies_of`. The dining chairs are **4** (a dining table
  with one chair at it is not a room anybody lives in); everything else is 1. Each copy is
  its own def, its own hiding place in the lake, and its own row in `unlocked` — they share
  one dirty sprite and are netted and stood separately. `_keep` caps at `copies_of`, and
  `in_store()` **counts** rather than matching by name: matching emptied the shelf of all
  four the moment the first was stood down.
- `ShedRoom.DOG_BED` is `decor_pet_bed` — one find, two styles, so either bed is the dog's.
  Since 2026-09-19 that constant only says which piece a dog may **walk over** (`_taken`
  leaves it out of the blocked floor). What a dog may **lie on** is the seat below.

### Four Dogs, a Sit, and a Piece in the Jaws (2026-09-22, `/grill-me` with Richard)
The pack is four visibly different dogs, they sit, and what a dog carries rides in its
mouth and bobs with its stride. Sheets from the Pixel Dogs pack (`art_source/
PixelDogsSprites/`, 12 breeds as plain/mouth-open pairs; contact sheet `tools/
last_dog_pack.png`), Richard's pick: **22** the yellow dog the game always had, **02** the
orange, **20** the tan-and-white, **14** the dark brown. **Four, one a slot**: three was
asked for first and the fourth dog repeated the first (Richard: "we need 4 different
breeds"). The ball (odd) sheets never ship.
- **Fixed by order, nothing saved** (`Dog.slot` → `DogArt.breed_of`): dog 1 is yellow,
  2 orange, 3 tan-and-white, 4 dark brown — the same on every save, no `SAVE_VERSION`
  bump. `Lake._add_dog` sets the slot; the scene's first dog is slot 0 by default.
- **One cut sheet and one json a breed** (`assets/dogs/dog_NN.png`/`.json`,
  `tools/slice_dog.gd` over `DogArt.BREEDS`): trims and footlines are the drawing's own.
  `DogArt` keeps a `Book` per breed and **every call takes a trailing `breed`, default 0**,
  so a caller that never heard of breeds — the shop board's head, the HUD button — draws
  the yellow dog it always did. `assets/Dogs-Sprite-Sheet.png` and `dog.json` are gone
  (`dog_22` is that sheet byte for byte).
- **Eight rows named**: idle, **sit**, laid, run, walk, **run2**, **walk2**, sleep. The beg
  row stays unnamed. **Odd slots run the second gait pair** (`DogArt.gait(slot, walking)`),
  so four dogs on one beach do not run in step; a breed without the pair falls back.
- **Sit is three things** (`Dog.State.SIT`, `_showing`): a still mood of its own on the
  island (the roll is 30 wander / 20 idle / 20 nap / 16 lounge / 14 sit), the `DROP_WAIT`
  beat at the crate, and being petted. Shed dogs sit on the floor too (`ShedRoom._dog_think`,
  never on a seat) and the wash room's hounds rest in it (`REST_POSES`).
- **The mouth is measured per frame, not guessed** (`slice_dog.gd`, `mouth` in the json,
  `DogArt.mouth(name, height, facing_left, frame, breed)`): the odd twin's three red
  tongue pixels give the jaws' height where the twin frame is the same drawing
  (`TWIN_SAME`), the row's own median where it is not; the x is always the plain frame's
  nose at that height, `JAW_IN` (2) px in. Taking the tongue's x where found and the
  nose's where not put the mouth three pixels apart on neighbouring frames. Supersedes the
  first frame's edge at 0.86 / 0.66, one point whatever the legs did.
- **The piece is gripped, drawn under the dog** (`Dog._draw_stick`, before `stamp`):
  `CARRY_AHEAD` (0.42) of its width past the nose, the rest under the head, which covers
  it — that is what "held in a mouth" looks like; leaning nose-end down `CARRY_TILT`,
  hanging `CARRY_SAG` per pixel of its own height. **The bob is the gait**: the mouth rides
  the head, and `_carry_drop` (`_chase_mouth`, `CARRY_LAG`, `CARRY_SWING`) trails it with an
  exponential ease and swings by the gap, so a gallop rocks it and a sit lets it hang still.
  In the water the dog's own bob carries it. All first guesses for Richard's eye.
- **Shed dogs and the wash room's hounds wear their slot's breed and gait**
  (`ShedDog.slot`/`breed`, `Hound.slot`/`breed`). The shop head and the HUD button keep the
  yellow dog, by decision.
- **Out of scope, by decision**: the beg row, the ball sprites, new dog art, per-dog shop
  rows, saving breeds, a bigger pack. **`MAX_DOGS` and `DogArt.BREEDS` move together** —
  a fifth dog would wear the yellow coat again; `test_lake` holds them equal.
- **Probe**: `tools/shot_dogs.tscn` (desktop build, `--fixed-fps 60`, own save, under its
  own node) — `tools/last_dogs.png`, a strip of every dog over six gait frames carrying a
  piece, then sit / laid / sleep; `last_dogs.log` has the mouth and the lag per column.
  Judge the carry on it, zoomed. `test_lake`'s `_stage_dog_breeds` guards the four sheets
  loading and differing, the slot rule, a full pack sharing no coat, the gait pairs, the sit in its four places and in
  the roll, the mouth moving through the run and sitting at the front of the head, and the
  piece being drawn under the dog with a lag.

### The Pack's Manners (2026-09-22, `/grill-me` with Richard)
A dog gives way to the angler, walks slow and runs every land leg, bends round the
buildings before it touches them, and the pack is heard more, from all over the island.
- **The angler never stops; the dog gives way** (`Dog._give_way`, `NUDGE_REACH` 0.6,
  `NUDGE_SPEED` 2.2): a dog inside the reach is pushed sideways off the angler's walk
  (their heading read off where they stood last frame) or straight away when they stand
  still, onto ground it may stand on, dozing dogs included. **This reverses the note in
  `player.gd`** that took the dog out of the angler's collision ("an animal in the way");
  `Angler._slide` is untouched and still walks through — the push is the dog's own.
  Picked over the angler sliding round the dog and over a half-each shove.
- **`WALK_SPEED` 2.4 → 1.6**; the run home stays 6.2; **the land leg out to a stick runs**
  (`_swim_pace` picks `RUN_SPEED` on land, `SWIM_SPEED` afloat) — it crossed the beach at
  swim pace before.
- **Steering, a tile ahead** (`_steer`, `AVOID_AHEAD` 1.0, `AVOID_CLEAR` 0.35, `AVOID_AT`
  0.1, `_around`, `_crosses`): before each step the dog feels `AVOID_AHEAD` along its line
  with `_bumped` (the hut, the crate, the pump — the same boxes `_may_stand` refuses); a
  box there sends it to the corner that is the shorter way round **among the corners it
  can see** — a corner whose line from here crosses the box is the far one, and heading
  for it is heading through the wall (found on the crate) — and **never the corner it is
  standing on** (found on the hut: it picked itself and rocked). Held until reached within
  `AVOID_AT`, not `CLOSE`: let go a third of a tile short, the next leg ran along the face
  inside the clearance and scraped. A target inside the box's own margin (the drop spot by
  the crate) is walked at straight. **`_hug` and the axis slides stay underneath** as the
  last resort for something already touching; `test_lake` sends a dog through the crate
  and through the hut and asks `_hug` never engaged. No A*, by decision.
- **Barks per dog, never over each other, faint from afar** (`_voice_next` is each dog's,
  `VOICE_GAP` 6-14 s from 8-18 shared; `_pack_hush`/`VOICE_APART` 1.2 s pack-wide;
  `FAR_SHARE` 0.33 of `VOICE_ODDS` beyond `HEAR`, played through `Sfx.play(&"bark",
  FAR_DB)` at -14 dB). Four dogs are heard about four times as often as one. Sniffs stay
  near only. Richard: "no barking at the same time... some barks from afar, very faint".
- **Out of scope, by decision**: the angler blocked by dogs, dog-to-dog collision, a path
  search, new recordings, barks from the shed's or wash room's actors, real distance
  attenuation (one faint level).
- All numbers first guesses for Richard's eye and ear. `test_lake`'s `_stage_dog_manners`
  guards the speeds, both walks round, the nudge (clear of a standing angler, sideways off
  a walking one, the angler unmoved, the dog's mood kept), the per-dog gap, the faint far
  bark and two dogs not barking together.

### The Pack in the Shed (2026-09-19, `/grill-me` with Richard, issue #30)
One dog could be in the shed; up to the whole pack can be now, and they lie on the
furniture. `ShedRoom`'s seven `_dog_*` members are a list of `ShedDog` rows.
- **As many as the player owns, each rolling `DOG_ODDS` on its own** (Richard's call over a
  count rolled once). `Lake` hands the room a `pack_size` **Callable**, the wash room's own
  pattern — the pack grows mid-run and a number pushed at `_ready` would hold the shed at
  one dog for the session. Unset, it reads as one dog, which is what every harness gets.
  **The price, accepted**: at four dogs the room is empty 4% of the time rather than 45%,
  so walking in and finding a dog asleep stops being a find. `DOG_ODDS` is the one knob.
- **A seat is authored, per view, in `tools/decor_sets.json`** (`seat`, drawn pixels up from
  the picture's bottom edge; `Sheets.seat_of`/`has_seat`): the two pet beds, the bed, and
  the sofa and the armchair **seen from the front only** — from the side or the back a dog
  laid on the cushion is cut in half by the backrest.
  **A seat is where the dog's feet go and the drawing rises from there**, so a lift picked
  for where a dog would *stand* puts its body on the backrest (Richard, 2026-09-20: a dog
  "sleeping over the backside of the sofa... only front/seating side"). The sofa went 10 px
  to **6** and the armchair 12 to **7**, which is the front edge of the cushion rather than
  its back. `test_lake` guards the rule for any seat on a piece a whole cell taller than the
  dog — what has a back to lie over; a pet bed is two cells to the dog's one and a half and a
  dog on one sticks out by design.
  **Nothing tests a view's *name*.** `decor_bed`'s views are colours (green/blue) and
  `decor_pet_bed`'s are shapes (round/oval), so a gate on the role `front` would have given
  both beds no seat at all and **deleted the one seat that already worked**. Authored or
  not is the whole rule.
- **The starter bed is a seat too** (Richard, asked and answered): `Lake.STARTER_BED` is
  `decor_bed` and every save has one from a new game, so a dog nearly always has somewhere
  to lie and the walk/idle/laid/sleep mood roll is what a dog with no *free* seat gets.
- **One dog to a seat**, claimed the way a stick in the lake is (`Dog.claims`): not a lock —
  the player may pick the sofa up from under a sleeping dog, and the claim is dropped on
  the spot when they do — but two dogs are never sent to one cushion. The key is the piece
  and the spot it stands on, never its index in `decor`, which shifts as furniture moves.
- **A dog lying on a piece is exempt from that piece's own block** (`ShedDog.over`). The
  sofa, the bed and the armchair all block floor in `_taken`, so without this a dog sent to
  a cushion fails `_dog_may_stand` and the unstick in `_drive_dog` shoves it off **every
  frame**. The player gets no such exemption. The pet bed needed none of it — it is left
  out of `_taken` altogether, which is why it was the only seat that ever worked.
- **Seats are measured off `assets/decor_clean.png`**, by eye, like the bases; the numbers
  are first guesses (pet bed 6, bed 21, sofa 10, armchair 12) to retune on the probe.
- Dogs keep `ROOM_PERSONAL` from each other as well as from the player, and the escape
  hatch in `_clear_of_all` is applied **per other** — applied once for the whole list, a dog
  already overlapping one of the pack walks through all of them and through the player.
  `IDLE_DARTS` went 24 to 32: four dogs and a player each wanting their own patch is a lot
  more to miss than one dog was.
- Nothing here is saved: which dogs are in is rolled each time the door opens.
- `test_lake`'s `_check_shed_dogs` guards the count, the seat table, a sofa turned side on
  offering none, one dog a seat, the rest on the floor, the exemption, the player being
  refused the cushion, and the dog sorting over the piece it lies on. `tools/shot_shed.gd`
  forces the whole pack in rather than leaving the picture to the roll.
  **And it hangs its lake off its own node now**: parented to the tree root it was the game,
  which since The Front means the menu is up and the HUD is hidden, so the probe had been
  photographing a shed that was never laid out (`room size (0.0, 200.0)` in its own log,
  which nobody read). The ending probe learned this in 2026-09-18; read a probe's log.

### Walking the Shed (2026-09-27, `/grill-me` with Richard)
**Supersedes the cell-blocking parts** of Free Placement and The Pack in the Shed (`_taken`,
"a cell is blocked when its middle is inside a base", cell sets in `ShedDog.over`).
- **Walkers collide with rectangles, not cells** (`ShedRoom._blockers`): each standing
  piece's floor base (`base_of`, placement pixels) grown by `WALK_CLEAR` (3 px) a side. Rugs,
  paintings, the pet bed and a `small` piece set on a host block nothing; the picture above
  the base never does. Positions stay floats in cell units; nothing snaps.
- **A refused step slides** (`_slid`): the whole step, else the longer allowed axis alone,
  else the other. Player and dogs both; a dog whose slide makes no ground picks a new target.
- **`ShedDog.over` is a set of piece keys** (`piece@x,y`, the seat key), exempting the dog
  from that one piece's rectangle.
- **Sorting**: a walker is behind a piece while its feet are above the base's front edge and
  in front below it; a dog on its seat is drawn over it (`_walker_key`, unchanged rule).
- **The carried piece is centred on the pointer to the nearest whole pixel** (`_drop_cell`
  rounds the float floor position less half the span), so the ghost is where it lands.
- `test_lake` guards the clearance, a slide along a face making ground, the sort flip at the
  front edge and the carried piece's centre.
- **Every turning piece's base is in pixels, on every face** (2026-09-29, `/grill-me` with
  Richard: side views blocked the floor behind them). Side bases were whole cells authored
  by eye and reached far up the picture (a tall bookcase side 40 of 48 px). The rule now: a
  piece is as tall on every face, so **side base = side picture height less (front height
  less front base)**, in `base_px` (drawn, scaled pixels). Sofa, armchair, dining chair,
  dresser, nightstand, both bookcases, big table, side desk, counter, toilet; plus bed and
  bathtub, which read as too deep. Other pieces stay in cells. Review sheet:
  `tools/bases/overlay.py` writes `tools/last_shed_bases.png` (base red, clearance yellow).
- **A walker is drawn over a piece unless it is behind it** (same day): behind means feet
  past the base's back edge. In front, or beside it level with its base (within
  `ShedRoom.BESIDE`, 1.5 cells, of either side), it is drawn over. Beside used to sort by
  feet alone and the angler went under a sofa's arm.

### Sitting, Lying and Reading in the Shed (2026-09-29, `/grill-me` with Richard)
E at a seat sits the player on it, at the bed lies them in it, at a bookcase they reach up
for a book and read it facing the room. Picked off `tools/last_pose_mockup.png`
(`tools/build_pose_mockup.py`) over four passes before any game code.
- **Where, per view** (`ShedRoom.RESTS`: kind, the hips' height in drawn pixels up from the
  picture's bottom, sideways offset): sofa, armchair and dining chair **front** (facing the
  room, drawn over the piece) and **back** (turned away); both beds' colours **lie**; the
  three bookcases' front
  **read**. **No side views, by decision** (Richard, after three passes: "looks really bad,
  lets not work with it"). The sofa's rests follow its pictures, not its swapped labels:
  view 0 is the back, view 2 the cushion. On the sofa the player sits left of middle.
- **A back sit is over the seat and under the backrest** (2026-10-03, Richard; it was drawn
  behind the whole piece and read as standing behind it): the player sorts over the piece
  like a front sit (`_you_key`), and `_draw_resting` then draws the piece's rows from the
  back entry's fourth number down (the drawing's own rows from its top, by eye off every
  back view: sofas 5-6, armchairs 4, chairs 2) over the player. **A chair's back view draws
  its seat cushion below the backrest, and the player sits on it** (second pass, Richard: "it
  should be between cushion and back rest"): the fifth number is where the backrest ends and
  only the band between is redrawn, the sixth is the cushion's foot and the figure is not
  drawn below it (the legs go forward under the seat), and the chairs' hips went up to the
  cushion (13-18). Sofas and armchairs from behind are all backrest and have neither. **The basket is put down**
  for it (`build_pose_mockup.drop_basket`, rebuilt into `sit_north`): with the seat under
  him it hung beside a narrow chair. **A sitter is centred on the body, not the ink box**
  (`_body_axis`, the median of every row's middle, stored as each `sit_` frame's `axis`):
  from behind the hand hangs out on one side and put the box's middle 1.5 frame px off the
  body's, so the player sat left of a narrow chair; the front sit moved a pixel too.
  First guesses; `tools/shot_rest.tscn` photographs the
  pack's seats now (`last_rest_{sofa,armchair}_back`, `chair_back`, `diner_back`,
  `carved_back`).
- **E is one choice among three**: the nearest of a dog, a switch and a rest wins
  (`switch_near`, `_draw_prompt`), measured from the foot's middle like a switch. **Any walk
  key, E again, the piece going away** (picked up or turned) **or leaving the shed** gets up,
  at once, where the player stood before (`stand_up`, `_rest_from`). Nothing is saved.
- **E no longer leaves the shed** (Richard, same day): it is the room's own verb in there,
  and only Escape and the cross close the room (`Lake._unhandled_input`'s interact).
- **The strips are built by rule** (`tools/build_rest_frames.py`, psd-extract venv python,
  project root, then `slice_character.gd` and a reimport): `sit_south` and `sit_north` (rest
  and a breath in: **the chest opens a pixel either side, the head stays**, `chest_breath`;
  the first cut lowered the whole upper body and read as the head bobbing), `lie_south`,
  `lie_north`, `lie_west`, `lie_east` (see Lying in Every Bed below), `read_south` (the book's back cover to the room, a
  page lifting; **five books**, `COVERS`, two frames each, one picked each read,
  `ShedRoom.BOOKS`/`_read_book`). For Richard to polish; a re-run overwrites. `ShedRoom.SIT_HIP` must match
  the rows the builder cuts. The slicer takes a `dirs` list per animation now.
- **Front sitting presses a shade into the cushion**: the figure itself drawn again
  `SIT_SHADE_AT` right and down in `SIT_SHADE` (Richard: "closer to the player, less
  round" than the ellipse it replaced). The basket stays in hand sitting and **vanishes
  while reading**, by decision.
- **Reading reuses the petting reach from behind** (`pet3_north`, the arm near straight up)
  for `Angler.PET_TIME`, then reads; a page turns every `PAGE_EVERY`. No reach frames of
  its own, by decision.
- **Idle life**: a breath every `BREATH`; lying, Zs after `SLEEP_AFTER`.
- **Dogs**: on the sofa and the bed a dog already lying there stays, **in the middle**
  (moved over to the free half it lay on the sofa's arm, Richard); on the armchair and chair (`SEAT_FOR_ONE`) it hops
  off. A dog with nowhere to lie climbs up on a free seat of the piece at `JOIN_ODDS`. **The
  dogs' seats went up a little** (Richard, same day): sofa cushion 4 to 6, armchair 3 to 5,
  bed 21 to 24, in `decor_sets.json` and `pieces.json` by hand (the builder was not run).
- **A dog sharing the piece lies over the player's lap** (2026-10-03, Richard): a dog whose
  seat is the piece the player rests on sorts `SHARED_OVER` past the player's own key, so on
  the sofa and both beds it is drawn over them, not under.
- **A rest is reached from anywhere along the piece** (`_rest_gap`, same day, Richard: E
  beside the fancy bed did nothing or petted the dog): the distance is to the piece's base
  rectangle, not its middle, so a wide bed is got into from its side. **A dog lying on the
  piece yields E** (`_dog_on`): with the player at that piece the dog's own distance is
  ignored and E rests rather than pets. The cost, accepted: that dog cannot be petted from
  beside its own bed. `shot_rest` photographs `fancy_bed` too.
- **Lying in every bed, on every face, the head on the pillow** (2026-10-03, Richard: "fix
  lying on beds, and mind their positioning and where the pillows are"; the head had been the
  hat brim alone, put two pixels under the picture's top, which on the fancy bed is the
  headboard and on the pack bed's view 0 is the foot). `ShedRoom.LIES` says, per bed and
  view, where the pillow is and which way the head lies, measured off the pack pictures:
  **up** (pillow at the far end, `lie_south`: the face down to the chin), **down** (pillow
  behind the board nearest the camera, `lie_north`: the back of the hat), **west**/**east**
  (a side view, `lie_west`/`lie_east`: the face-up head turned a whole quarter, held inside the
  headboard by `clip`). The bed's own picture is drawn back over the head from `cover` towards
  the feet (`_draw_lying`), so the blanket comes up to the chin and the near board hides the
  pillow; the folds run from there to `feet` (`_draw_blanket`). **The pack bed's labels run
  the other way round from the fancy bed's**: its view 0 has the pillow at the near end and
  view 2 at the far end. On the double bed the player takes one pillow, the same from every
  side, the far one on a side view (the near one put the head over the dog). **The dog's
  seat moved off the near pillow** on the two "down" faces (pack bed view 0 18 to 32, fancy
  bed view 2 26 to 37, `build_pack_decor.SEATS` and `pieces.json` by hand): it lay over the
  sleeper's head. Probe: `REST_ONLY=bed,fancy` on `tools/shot_rest.tscn` shoots all eight
  faces (`last_rest_{bed,bed_side,bed_back,old_bed,fancy_bed,fancy_side,fancy_back,
  fancy_side_r}.png`). All numbers first guesses for Richard's eye.
- **The chew toy blocks nothing** (`ShedRoom.WALK_OVER`, Richard, same day): stepped over,
  like the pet bed and the rugs.
- **Out of scope, by decision**: side sitting, get-up frames, sounds, a carried book,
  reading anywhere else, the lake.
- `test_lake`'s `_check_shed_rest` guards the strips, no side-view rest, E resting and E
  standing up where the player stood, the dog hopping off the armchair and staying on the
  sofa, and the seat going away. Probe: `tools/shot_rest.tscn` (desktop build, own save,
  whole pack forced) saves `tools/last_rest_{sofa,sofa_back,armchair,chair_back,bed,read}.png`.

### The Shed's Cues (2026-10-02, `/grill-me` with Richard)
A carried piece says it can turn, and a switch nobody has tried points at itself.
- **The turn chip** (`ShedRoom._draw_turn_hint`, `turn_hint_alpha`, `TURN_HINT_HOLD` 2 s,
  `TURN_HINT_FADE` 0.6 s): the `shed_rotate` key as `Binds.shown` names it (the pad's button
  in pad mode) and a turning arrow (`TURN_GLYPH`) on the E chip's wood, beside the piece in
  hand, right of it or left where the right runs off the room. Whole from the pick-up, then
  fading; turning does not restart it. **Only where R would change the piece**
  (`Sheets.turned` != the view in hand), so a pot shows nothing. No words, nothing saved.
- **No place or store chips, by decision**: the drag explains itself.
- **The pointing hand** (`hand_rows`, `_draw_hands`): over the top of every placed piece of
  a kind never worked **that switches in the face it stands in** (2026-10-03: it asked
  whether any face switched, so a counter turned side on wore it). Seats, beds and bookcases get none, by
  decision. Drawn over the room's dim with the key chip, so nothing in front hides it. Not
  over the switch in E's reach (the key chip is there), not while a piece is in hand or the
  record menu is up.
- **It is the angler's own hand** (2026-10-03, Richard's pick C of three off
  `tools/last_hand_mockup.png`/`.gif`, `tools/hand_mockup.py`; a cartoon glove and a carved
  oak hand were the others): `HAND` is the silhouette, and `hand_pixels` outlines, tones
  (lit from the right, `_hand_tone`) and creases it in the angler's skin and his cream shirt
  cuff (`HAND_SKIN`, `HAND_SHIRT`), with a pink nail and the finds' gold star at the
  fingertip winking on the middle two of four frames (`HAND_HOLDS`, `HAND_BOBS`, `HAND_ARMS`,
  `hand_frame`), a pixel's bob with it, and a soft shadow down and to the left
  (`HAND_SHADE`). Baked once to four textures (`_hand_image`) and drawn at the furniture's
  grain (`HAND_GRAIN` 0.74, `build_pack_decor.py`'s `SHED_SCALE`), its tip `HAND_LIFT`
  over the drawing. **Supersedes** the paper hand with a blue cuff at the room's zoom.
- **Per kind, saved** (`switch_tried`, piece names; `ShedRoom._tried` from `switch_near` and
  `_open_record`): working one lamp takes the hand off every copy. Owned by `Lake`, shared
  with the room by reference like `decor`, saved as `switch_tried`. **A save without it reads
  as nothing tried**, so old runs get the hands too (Richard's call). No `SAVE_VERSION` bump.
- **Out of scope, by decision**: cues on seats, beds, bookcases or dogs; a setting to turn
  them off; the decoration tour; new art or sounds.
- **The fridge stands without the pack's puddle** (2026-10-03, Richard): the Messy pack
  draws a blue-grey puddle under its front, open front and open side. `build_pack_decor.py`
  clears those four colours from the bottom `PUDDLE_ROWS` of those views (`DRY`, `PUDDLE`,
  `dried`), so the pictures are a pixel or four shorter and narrower; a fridge already placed
  keeps its cell.
- All numbers first guesses. `test_lake`'s `_check_shed_cues` guards the chip's hold, fade
  and one-face rule, the hand on every copy and none on a sofa, none while carrying, none in
  reach, the hand going on a press, the list saving, the hand's loop and tones, and no
  puddle pixel under any fridge view. Probe: `SHED_CUES=1` on
  `tools/shot_shed.tscn` saves `tools/last_shed_cues.png` (hands) and `last_shed_turn.png`.

### The Pack Decoration Replaces the Finds (2026-10-01, Richard)
The finds in the lake are the 0_mem0ry packs' decoration, picked on the Lake Pack Tagger and
built by `tools/build_pack_decor.py` (`decor_pk_*`, sheets `decor_pack_dirty`/`_clean`).
**Supersedes** the PSD finds as what the lake hides; the old `decor_dirty` pieces stay in the
catalogue (the shed's tests still use them) and are no longer dealt (`Lake.FIND_SHEET`).
- **The builder is the table**: every piece's views by catalogue id, cut to one island where a
  sprite holds several objects, faces (R) and states (E), a mirrored copy of a flagged side
  view, the two states of a face aligned into one frame (`shared_frame`, so E never moves a
  piece), footprints (`FRONT_BASE`, the old finds' rule: side = side height less the front's
  height above its footprint), dog seats (`SEATS`), copies (`COPIES`, empty: every find is unique since 2026-10-01, the diner chair
  was four), and
  the tier tagged on the tagger (`Sheets.tier_of`, read by `_all_defs`). Drawn at
  `SHED_SCALE` 0.74 in the shed (Richard's pick). The grimy sprite is rule-built murk.
- **Both lamps switch** (2026-10-03, Richard): the table lamp is the Messy pack's own pair,
  1063 off and 1064 lit (it was 1064 alone, so one saved before reads as off); the Coastal
  floor lamp has no lit drawing, so its "on" is the same cut with the shade's blues and bulb
  mapped onto the table lamp's yellows (`LIT`, `LIT_ROWS`, a `"lit"` flag in the cut box).
  Both `STATE` with light `warm` (the lamp pool, silent), so both wear the hand. A Messy floor
  lamp with its own pair (1068/1069) exists and was not taken.
- **The record player is the first find** (`FIRST_FIND`), afloat by the island at tier 0. It is
  the old `decor_vynil_player` entry redrawn as the pack turntable (`REPLACES`), a small piece
  that sits on furniture; the song menu is drawn in its greys.
- **The shed starts with the pack bed** (`STARTER_BED` `decor_pk_bed`). Early finds:
  record player, flower vase, nightstand, coat stand (tier 0), sofa, coffee table, chair (1).
  Sit/lie/read spots for the pack seats, beds and bookshelf are in `ShedRoom.RESTS` (first
  guesses).
- **Finds float at the rubbish's grain**, one world px an art px (`_is_pack_find` in `_dress`).
- **55 finds where there were 37**: `FIND_APART` 7 to 6 and `MID_OUT` 25 to 27 so they deal.
- **The wash stand's grime is the art's own pixels** (`WashStand.FINE` 1, was 2): the pack
  pieces are drawn up to 14 screen px an art px and half-pixel grime read as a second picture.
  **Every cleared cell gleams** (`GLEAM_*`): pale, paler, gone, and now and then a gold star.
- **The wash stand draws every find at one zoom** (`WashStand._zoom_for_all`, second
  `/grill-me` the same day): the least zoom at which each find's first view fits
  `ROOM_WIDE` by `ROOM_TALL` (0.7), so a cactus reads small and a bed big, as in the shed.
  **Supersedes fitting each find on its own** and `wash_scale` (no longer read).
- **The find stands on a pallet, not a table** (`PALLET_*`, `_build_pallet`): built by rule
  in the pack's style at the finds' zoom, low and boxy (deck boards and gaps, stringers
  under the gaps at the blocks, dark fork openings), its foot at `PALLET_GROUND` 0.8. Runoff
  goes through the slats (`THROUGH_ODDS`) or over the front edge, and either way darkens the
  grass in front in whole art pixels (`_wet`, `WET_*`), drying back. No standing pool.
- **The hose upgrades in the wash room** (2026-10-01, `/grill-me` with Richard): a plank
  under the tray (`WashRoom.hose_box`, `buy_hose`, `HOSE_PRICES` 1500 / 6000) takes the hose
  from level 1 to 3, each wider and harder (`WashStand.HOSE_GROW` x1.2 / x1.45, gentle by
  decision), the stream a pixel wider a level and the spray scaled with it. Paid from the
  purse in `Lake._on_hose_bought`, saved as `hose` (absent reads as 1, no bump). Not a shop
  row, by decision. Words `HOSE_UP` / `HOSE_TOP` (machine drafts).
- **The money and Waiting plates stay up in the wash room** (`HudSkin.plates_only`, same
  day): the room sits under the HUD skin, which draws only those two plates and takes no
  clicks; the tray moved down to `TRAY_AT` y 172 (`ROWS_MOST` 7) to clear them, and the
  gear is hidden while the room is open.
- `SAVE_VERSION` 20; the v19 save is `_builds/lake_cleanup_v19_20261001.save`. **21** since the
  diner chair went from four copies to one (Richard: finds are unique); the v20 save is
  `_builds/lake_cleanup_v20_20261001.save`.
- **Open**: the letter's decoration stills still show the old finds (re-run
  `shot_letter_art`); dog seats and rest heights are first guesses; 1146 and 1172 are named
  "Sculpture" and "Blue Rug" until Richard says otherwise. `tools/play_decor.tscn` opens a
  shed holding all of them.

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
  reads `bases`, which the catalogue authors by eye; asked
  at a granularity of one it would hand those cell counts back as pixels and every piece
  would stand on a one-pixel foot. **Don't ask `Sheets` for a base at 1.**
  **Except for the two pots, which author theirs in pixels** (2026-09-19, issue #30,
  `base_px` in `tools/decor_sets.json`, `Sheets.has_base_px`/`base_px_of`, the one branch in
  `ShedRoom.base_of`). A floor piece's base is exactly how far its picture may *not* go up
  the back wall, and the least a cell can say is 8 px — a third of a 23 px pot, which stood
  it that far down the floor with nothing drawn in the gap (Richard: "invisible pixels
  behind it"). At 2 px it stands against the wall. **Not a free unit swap**: the same number
  is the walker block, the host probe and the band a walker sorts over, so a pixel base is
  right for a pot standing on its foot ring and wrong for a sofa. The builder refuses an
  entry that authors both. No `SAVE_VERSION` bump — a `decor` row holds piece, cell and
  view, and no base was ever saved.
  **`tools/last_decor_views.png` is not the reference any more**: it is git-ignored and
  nothing in the repo writes it. Measure off `assets/decor_clean.png`.
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
  `plastic_globe`/`plastic_globe_2`. **The rubbish kinds left the fill on 2026-09-21**
  (the third rubbish batch: the new PSD does not carry them), so these four are finds only. The
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
- **Dealt, not darted** (2026-09-21, `_find_spots`, `_clear_spot`): every deep wet tile in
  the find's band is listed and shuffled off the seed, and the first `FIND_APART` clear of
  every find down wins; failing that, a clear tile anywhere (spacing beats band, as the old
  darts' fallback had it — `test_lake` allows two finds out of band); failing that, the
  roomiest in the band. It was 800 darts over the whole square, and the spacing was luck:
  **the late band is short of room** — a few hundred tiles three deep past `MID_OUT`,
  bunched to the bank, for fourteen finds — and the third rubbish batch tipped it from two
  crowded pairs to three. `_plant_anywhere` is still the last resort. Bands are first guesses (7 / 20 / 13 finds) to judge in play.
- **`SAVE_VERSION` 11**, everything older refused; the version 9 shed-unit read
  (`SAVE_SHED_CELLS`) is gone, as its own note promised. The v10 save is kept at
  `_builds/lake_cleanup_v10_20260917.save`; **the trailer's shed shot needs a refurnished
  save before a re-shoot**.
- Out of scope, by decision: an authored stage field, floor lamp early, save migration.

### The Find-Caught Card (`scripts/trophy.gd`, 2026-09-19, `/grill-me` with Richard, issue #30)
A find netted out is held up in the middle of the screen for 2.8 s, because the shed is two
clicks away and the only other sign was a line of small text in the corner. The card itself
is older than this note; what the note records is the pass that made it the game's own.
- **It holds up the grimy sprite** (`Sheets.region_of`), not the restored one. It showed the
  restored one on the reasoning that the card should say what the find will become — and the
  pump made that false: a netted find goes to `unwashed`, and the shed will not have it until
  it has been washed. So the card was showing the end of an errand nobody had run.
- **It reads "New decoration available to wash"** (Richard's wording), which says where the
  find went rather than what it is.
- **The light round it is the finds' own** (Richard: the card "feels generic", the disc was
  "blocky and doesn't blend in well with the style"): the gold column, the four-point
  art-pixel stars and the gold rim the lake and the net already put on a find.
  **Retired**: the wheel of ten spinning rays, the fourteen drifting motes, and the five
  stacked dark discs the piece stood in.
- **The rim is what lets the grimy picture be held up at all.** The disc's own comment said a
  chair drawn straight onto the lake is a chair lost in a field of bottles, and it was right
  about the problem; a gold outline separates the piece from the water without laying a
  circle over the game. **The rim, the picture and the glitter fade as one** (2026-10-03, a
  `CanvasGroup` named `Fade`, `self_modulate.a` the card's fade): the rim is four whole
  copies of the sprite and only their edges are meant to show, so faded one by one the
  picture went see-through and the gold was left behind. **Supersedes `RIM_FADE`**, which
  cubed the rim's own alpha and still left a gold ghost.
- **Copied from `CastNet`'s `CatchRim`/`CatchBeam`/`CatchStars`, not from `LakeGrid`'s own
  `GlintBeam`/`GlintTwinkle`**: those are tile-bound (every line indexes `grid.stacks[i]`,
  `grid.swing[i]`, `grid.surface_pos(i)`) and a card has no tile. Only the two statics and
  the two shaders travel. `GlintTwinkle.sample_box` is new — `sample_spots` wants a
  `TrashDef` and the card has a piece name and a `Sheets`.
  **`show_behind_parent` does not travel**: on the net it means behind the catch, because
  the net draws the catch itself; here the picture is a child, so child order is what puts
  the rim behind it and the flag would sink the gold under the words as well.
- **Sizes are the card's own, not the lake's**: the beam is sized to the picture rather than
  to `beam_width` (one find on screen, nothing to be out of step with), the rim's step is in
  screen pixels rather than scaled with a picture blown up to `PIECE_ZOOM`, and a star is
  `STAR_BIG` times its lake size. All by eye.
- **Probe: `tools/shot_trophy.tscn`** (desktop build, `--fixed-fps 60`, under its own node)
  — three finds of three shapes at the pop, the hold and the way out, plus
  `tools/last_trophy.log`. **Headless compiles no shader, so this is what proves the two
  compile.** Driving `Trophy._process` by hand to jump to a moment was tried and does not
  work: the node's own `_process` is running too and the two ages add.
- `test_lake`'s `_check_trophy` guards the wording, the retired drawing being gone rather
  than unused, the four layers in the one order they can be drawn in, their materials, the
  rim not wearing the net's flag, and the glitter having spots on the grimy picture.

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
- **Beach pieces throw a sand-coloured shadow and sit in the sand** (2026-09-29, Richard:
  "no shadows"). They always had one, in the water's ink at 0.15, which cannot be seen on
  sand and lay tucked under the piece. On a `DRY_ANCHOR` shadow `shadow.gdshader` draws
  `dry_shade` (`LakeGrid.DRY_SHADE`, sand's dark at 0.6), and `ShadowLayer.write` centres it
  on the piece's foot (`DRY_SHADOW_UP`), half under the piece and half on the sand, hugging
  the base; thrown down and left beside the piece was tried the same day and read as a
  second object. A dry piece is bedded
  `dry_sunk_by` into the sand (`DRY_SINK` 2 px, at most `DRY_SINK_MOST` of its height),
  in `_sprite`, `perch_point` and the sprite layer alike. **A shore tile's second piece has
  its own shadow and, on the strand, its own foam** (`_shade_second`/`_reshade_second`,
  `_shadow2_at`, `_second_at`); it had neither. Probe: `tools/shot_beach.tscn` (desktop
  build) saves `tools/last_beach_{dry,strand}.png`. Numbers are first guesses.

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
- **Deleted 2026-10-03 (The Pre-Release Cleanup).** Tuning: F4's `GroundTuner` carries the three coast sliders beside the ground's (they go to
  the water material, not the `Ground` nodes); bake picks into `Lake`'s constants.
- **Retired, by decision**: the island standing above the water with a drowned-sand shelf
  stepping down into the lake (`SINK_*`, `ISLAND_DEEP`, `IslandShallows`), and the flat
  water-coloured plate over it before that. Both left a stepped edge; the discard is what
  made the coast a curve. Do not bring the island back above the water.
- `Iso.SHELF_TILES`/`SHELF_CLEAR` still hold the rubbish off the beach (the first cast has to
  reach); they no longer describe anything drawn.
- Island foam ring width in the shader is 1.0 like the bank's (was 1.5 to cover tile corners).

### Rubbish Sheets
**The rubbish is the 0_mem0ry packs' art since 2026-10-01**: `tools/build_pack_rubbish.py`
(fed by `fetch_mem0ry_packs.py`, `cut_packs.py`, the Lake Pack Tagger and
`tools/pack_rubbish.json`) writes `assets/lake_objects.png`, the `lake_objects` entries of
`pieces.json`, one `.tres` a kind and `TRASH_ORDER`. 121 kinds. **Supersedes the PSD
pipeline below**, whose builder (`build_lake_objects.py`) was deleted on 2026-10-03; the
naming rules (numbered families) still hold.

**Superseded: one PSD, one sheet** (2026-09-21, `/grill-me` with Richard): `art_source/New_Objects_Lake.psd`
is the only source of the lake's rubbish, 81 kinds, cut by `tools/build_lake_objects.py`
(psd-extract venv python, project root, **reimport after**) onto `assets/lake_objects.png`.
It replaced the hand-corrected first sheet and the second batch's `lake_objects_new.png`;
every kept kind was pixel-checked against its old sprite first (only `rubber_block` was
retouched). The stale extensionless PSD is deleted.
- **Layers map to slugs by name and left-to-right position** (`SLUGS` in the builder).
  A repeated name is a **numbered family** by decision (`rubber_toy`, `rubber_toy2`..5,
  `plastic_toy1`..5, `wood_box3`..5), which `family_of` reads as look-alikes. Moving a
  layer across the canvas can swap two slugs; the builder prints each slug's x.
  `Metal blah` is `metal_controller`.
- **Five kinds left the lake**: `plastic_toy`, `plastic_globe`, `rubber_bone`,
  `wood_painting3`/`4` — not in the new PSD. Their finds keep their own decoration art.
  The plastic pier's emblem went `plastic_globe` to **`plastic_bottle`** (Richard's pick;
  the basketball he asked for first is `rubber_ball3`, a Rubber layer, and a box carrying a
  piece its yard does not buy was turned down). The wood and metal emblems went `wood_piece` and `metal_hanger` to **`wood_chair`**
  and **`metal_extinguisher`** the same day, picked off every candidate carved on its box:
  the old two read as a smear and as nothing.
- **The economy was held, not re-priced**: the 49 new kinds' tier, pollution and lightness
  were picked so each yard's mean pay per piece stays within 2% and each tier's share of the
  water within 2 points of the lake the shop was priced on (`test_lake` `PAY_PRICED`,
  `TIER_PRICED`; measured with `tools/probe_fill_economy.tscn`, headless). **A low
  lightness draws a kind far more often** — the floor end of the band holds few kinds, so
  each fills a lot of water; new tier-4 kinds sit at 1.7-1.9, not the 1.4-1.5 of the old
  ones. A kind promoted a tier keeps its pay by carrying lower pollution (tier 1 at 2.4).
- **`SAVE_VERSION` 14**, v13 refused; the v13 save is kept at
  `_builds/lake_cleanup_v13_20260921.save`.

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
`RECUT_RENAMES` and `tools/repair_save.gd` went with them.

**`tools/slice_sheets.gd` is deleted** (2026-09-20) and so are the 64 `small_*` pieces it
cut. Its last sheet was `TopDownHouse_SmallItems.png`, which only the retired
`resources/trash/_old/*.tres` ever named — and it wrote the *whole* `pieces.json`, so with
nothing left to cut a run would have emptied the catalogue. The first rubbish sheet's
regions were cut by it once and corrected by hand since: they live in `pieces.json` and in
git, and **nothing recomputes them**.

**Pack art does not live in `assets/`** (2026-09-20): Penzilla's and LimeZu's own sheets
were sitting there and therefore shipping in the export, which both licences forbid. They
are in `art_source/retired_assets/` now, with the Forest pack's `Aseprite_files/` and
`Atlas_files/`, the Pigeons `.mdp` sources, `Bungee.zip`, `Buttons_Fixed.png`,
`lake_reference.png` and the slicer's two debug pictures. **Moved, not deleted** — they are
what a future selection is mined from — and `art_source/.gdignore` is what stops them
shipping, which also means **no Godot tool can load them**; a builder off them is Python,
like `build_decor.py`.

---

### The Pre-Release Cleanup (2026-10-03, `/grill-me` with Richard)
The game is close to done, so the download, the project folder and the code were cut down.
Audit and method: `docs/cleanup-audit.md`. **Nothing a player sees moved**; the music is
re-encoded and the fonts cut down. **Supersedes** every note elsewhere in this file that
tells you to use one of the things below.
- **Shipped size**: the stock Godot exe stays (109 MB, by decision: no custom template). The
  pack lost the 9 MB pirate-ship JSON (`assets/Blue_Boat/`, shipped only through the old
  `*.json` include filter, which is now `assets/*.json`), the music halved and the CJK fonts
  cut to under 1 MB.
- **Music is Ogg Vorbis** (`build_music.py` `SONG_Q` 5, about 160 kbps; radio `RADIO_Q` 0),
  `MusicStation` loads `.ogg`. **Supersedes the `.mp3` files** named in The Music and The
  Record Player. `measure_beats.py` measured the same grid off the Ogg files.
- **The CJK fonts are subset** by `build_translations.py` (`subset_fonts`, `CJK_FACES`,
  `CJK_ALWAYS`): every character of the locale's column, plus the language names written in
  the scripts, plus CJK punctuation and full-width forms. The full faces live in
  `art_source/fonts/`. **Re-run `build_translations.py` after any CSV edit**, or a new
  character draws as tofu; `probe_text_fit.gd` now reports glyphs a face does not carry.
  Needs fontTools (`pip install --user fonttools`).
- **Desktop only**: the Web export preset is gone.
- **Debug code removed outright, not gated**: `GroundTuner` (F4), `ButtonTuner` (F7) and
  `HudButtons.tune`/`tracing`/`traced`, the perf overlay (F3, `perf_hud.gd`), `PlayLog` and
  the playtest log, the screenshot key (F12, `shot_key.gd`), F6 wipe-reload (`wipe_save`),
  F9 tornado, and the `qps` pseudo-locale (its CSV column, its Language entry, its
  `unknown` flag). `HudButtons.BAKED` stays as the picked numbers; `Ground.retune` stays for
  `tools/shot_grass`. The `BENCH_*` hooks stay with `bench_frames`.
- **Dead files deleted**: `scripts/wood_ui.gd`, the console spike's sheets, the slicer debug
  pictures, `resources/trash/_old/`, 37 unused Forest tileset slices (kept 1, 2, 18-21, 67).
  The pigeon pack's sheets and the head painting moved to `art_source/Pigeons/` (they were
  shipping), read there by `slice_pigeons.gd`, `slice_pigeon_head.gd` and `ink_pigeons.py`.
  About 90 unused functions and constants left the scripts.
- **tools/ kept**: `test_lake`, `bench_frames`, `census`, the probe and shot scenes, the
  builders whose output ships, and `film_trailer` (`shot_rope` extends it). **Deleted**:
  mockups and one-offs (`tornado_mock/`, every `*_mockup.py`, `shop_mock`, `shot_shop_mock`,
  `shot_pack_mock`), the Steam and devlog film probes (`shot_steam`, `shot_keyart`,
  `shot_wash_place`, `film_devlog`), `shot_buttons` (it drove the tuner), builders for
  retired art (`build_consoles`, `build_lake_objects`, `recolor_shed`, `recolor_box`,
  `downres_shed`, `trim_box_sides`), and scratch (`specks/`, `hd_rubbish/`, `menu_bg/`,
  `cursor/`, every `last_*` and stray log). `tools/film/` stays (its frames were deleted
  on 2026-10-06, 22 GB; only `.gdignore`, `beats.json` and `beats.py` are kept).
- **Probe output never reaches git**: `.gitignore` takes every picture, film, sound and log in
  `tools/` and every subfolder but `bases/` and `film/`.
- **The rubbish's source**: see Rubbish Sheets, rewritten. The section said a PSD and 81
  kinds while the code had moved to the 0_mem0ry packs on 2026-10-01.
- **Left alone, by decision**: git history (no rewrite); the old PSD finds in
  `decor_clean/dirty.png` and `pieces.json` (no longer dealt, but removing them shifts every
  def index and needs a `SAVE_VERSION` bump); `Claude outputs/`.

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

**A big net** (2026-09-26, Richard: lag casting, worst lucky or doubled; `bench_frames` `BENCH_CAST=1 BENCH_BIG=1 BENCH_LUCK="lucky double"`): 17.8 ms mean, p99 29 -> about 13 ms, p99 21; big net alone 13.1 -> 10.6; plain cast 5.8 -> 5.0. Four fixes, none visible: every crown, ring and drop of `WaterSplash` in one triangle array (each piece a sweep lifts throws a crown); `LakeGrid._restamp(index, true)` skips the glint refresh for rising and shoved tiles; `Lake._ask_the_end` walks the field only when the last count was under `ASK_WITHIN` (it walked all 8464 stacks on every crate landing); the rope is one mitred strip (`_rope_strip`) with a disc at each end, not one per drawn point. **Still over the 8 ms bar.** Tried and reverted: sending the soup in chunks (no gain, so re-sending it is not the cost).

**Where the big net's frame goes, measured** (2026-09-29, same bench, every `_process`/`_draw` timed by a temporary wrapper, render split with `viewport_set_measure_render_time`): plain cast 6.8 ms, big lucky double 14.5. **Not the GPU** (1.3 -> 2.5 ms) and not render CPU (1.0 -> 2.0); scripts went 4.8 -> ~10 ms. **No single cause**: about 130 pieces in the air at once (~127 haul flights, ~99 rising tiles, ~180 drops, ~44 crowns), each costing a few microseconds in several systems. Top items: splash crowns 2.3 ms, `Lake._process` 1.3-1.5, `LakeGrid._process` (rising tiles restamping) 1.2-1.3, `Haul._draw` 1.0, the soup's `_draw` 0.8, the nets 1.2 together, HUD 0.5. That is why switching systems off one at a time never moved the mean past noise. **Fixed**: `WaterSplash._draw_crowns` built a temporary array per triangle (`append_array([...])`) and per drop, and walked each plume's normals twice; now pushed straight in, same vertices in the same order (crowns 2.26 -> 1.34 ms; three runs each, mean 14.6 -> 13.5, frames over 16.7 ms about 26% -> 13%). **Still over the bar**; the rest is per-piece GDScript volume. Options, none taken: batch `Haul`'s flights into one triangle array, move the rising bob into the soup's vertex shader, cap crowns per sweep (visible).

**The haul is one batch** (2026-09-29, Richard approved: "nothing visible"): `Haul._draw` lays every flight's shadow disc (`CIRCLE_SEGMENTS` 64, `canvas_item_add_circle`'s own count), waterline diamond and picture into one triangle array off the atlas, the shadow and diamond sampling `Sheets.white`, in the old loop's order, corners worked out on the CPU from the old `draw_set_transform`. `Haul.batched` false, or any flight with no art on the atlas, draws the old way. Big lucky double, three runs each: mean 12.90 -> 12.33 ms, draw calls ~483 -> ~286 a frame, frames over 16.7 ms 7-10% -> 3-5.5%. **Proved on one frozen frame** by `tools/probe_same_frame.tscn` (desktop build, `--fixed-fps 60`, `PROBE_WHAT=haul`; tree paused and time scale nought, old / new / old photographed, `tools/last_same_frame.log`): old against old again 0 pixels, old against new **20 pixels of 2.07 million**, all on the two edge columns of one axis-aligned piece just leaving the hand, where a pixel centre sits on the picture's edge and the CPU's corner and the GPU's round to opposite sides of it. Not reproducible bit for bit; accepted as noise.

**The rise is the shaders'** (2026-09-29, same approval): a tile coming up after a take, or bobbing after a bump, is stamped once at rest with a slot (`LakeGrid.RISE_SLOTS` 126) in a spare vertex channel (the soup's blue, 1.0 on every piece with art; the shadow's blue as 2 + slot * 2 + its corner flag; the foam collar's empty blue as slot + 1), and `rubbish`/`shadow`/`foam.gdshader`'s `uniform float rise[126]` add the `emerge` the CPU still works out every frame; the tile is stamped at rest again once still. `LakeGrid._process` no longer `_restamp`s rising tiles. Foam adds the rise before `local`, which its pixel grid is snapped in. **Only while the soup is all art** (`rise_on`): a placeholder's grey rides in the same blue; with no free slot, or `gpu_rise` false, a tile is patched every frame as before. `surface_pos`/`surface_still` still include the rise, so gameplay sees nothing new; `_stamp_at` is where the stamp goes. Three runs each, with the batched haul: 11.91 -> 11.13 ms mean, frames over 16.7 ms 1.7-3.8% -> 0.7-1.7%. `probe_same_frame` `PROBE_WHAT=rise` over 63 tiles moved by the shaders: **0 pixels differ** (a copy handed a zeroed `rise` differs in 22,079, so the probe sees it). Big lucky double is now about 11.1 ms from 13.5 this morning; **still over the 8 ms bar**.

**The long big catch, 2026-10-05** (`/grill-me` with Richard: "stuttering when too many objects are caught, late game, big net, long cast"). New `BENCH_FAR=1` (with `BENCH_CAST`) throws every cast near the net's full range, round the island. Before: plain far casts 10.9 ms mean, 8% of frames over 16.7; lucky double far 13.9 mean, p99 28, **20% over**. Measured by stopping processes one at a time and timing inside them, the cost was not the splashes but **the pieces the haul pushes aside**:
- `LakeGrid._settle_shoves` restamped every shoved tile every frame as it drifted back, about 300 on a maxed haul, ~3 ms. Now a tile is restamped only once its offset moved `SHOVE_STAMP` (0.5 world px) since it was drawn (`_stamp_shove`, `_shove_drawn`).
- `shove_to` asked `_shoved.has()` per piece (a list of 300); now a flag array (`_is_shoved`).
- `CastNet._shove_aside` went through `_reach`, which runs the exact drawing-touch test on every tile and sorts the result, twice when the net is full; ~1-2 ms per net per frame. It walks the tiles itself now, cut by the same distance it already used (`_shove_one`). Behaviour: a piece is pushed when its middle is inside the mouth plus `SHOVE_CLEAR`, no longer also asking that its drawing touch the mouth; the same pieces in practice.
- **Caps on huge catches, by Richard's call ("subtle thinning OK")**: `WaterSplash.CROWNS_MOST` 24 crowns on the water at once (`CROWNS_HEAVY` 32 for a piece at `HEAVY_FROM` 0.6 strength); `LakeGrid.RISING_MOST` 48 tiles rising after a take, past it the piece under is simply there; `Haul.SHOWN_MOST` 48 throws into the island crate drawn in the air, past it a piece flies undrawn with the same timing, landing and sale (hull and pier throws always drawn). **Decided as each piece leaves the hand and counting the crate's throws only** (2026-10-06, Richard: "sometimes objects are not showing flying from player to box"): decided at the queue, a volley's tail stayed hidden after its head had landed, and a ferry loading from the crate (up to 64 tagged throws) counted against the cap and hid a whole catch. An ordinary cast meets none of them.
After, two runs each: plain far 7.7 ms mean, **0 frames over**; lucky double far 9.3-9.7 mean, p99 16.5-16.6, **0.7-0.8% over** (was 20%). Near lucky double (`BENCH_CAST BENCH_BIG`) before the last two fixes 11.4 / 3.2%. All caps first guesses for Richard's eye.

Measured 2026-09-11, RTX 5060 Ti: 15.0 ms -> 2.2 ms mean standing, worst walking frame
42 ms -> 3-4 ms.

**The cleaned lake, 2026-10-02** (`BENCH_CLEAN=1`, and the new `BENCH_GROWN=1` that grows
every plant in at once to measure the lake as it stands): 8.4-8.7 ms mean, over the bar, but
6.9 settled. The difference was the plants growing in after a clean: `Flora._lay` rebuilds
the whole batch (about 1.2 ms) and ran every frame for the several seconds everything due
grows together. It runs at `Flora.GROW_FPS` (12) now, the last step always landing. The fish
(about 1.8 ms) worked their spots out in each of two draws and asked the lake's depth three
times a fish; now once a frame in `_process` (`Fish._spots`, `_water_at`, `_tint_at`), the
same values. After: **6.0 ms** mean during the grow-in and settled, 6.4 walking, worst under
10. The plants' water sway measured at noise (`BENCH_OFF=sway` for the A/B), and nearest
sampling everywhere at nothing.

---

### The Trailer (2026-09-16, `tools/film_trailer.tscn`, `marketing/My Dirty Little Lake/trailer/`)
A 30 s Steam trailer cut to Habibs 2#1, built by a re-runnable pipeline (Richard's call:
scripted capture, no OBS). **Film**: `godot --path . --fixed-fps 60 res://tools/film_trailer.tscn`
(desktop build) poses each shot — five casts from five banks, each further and wider, the last
gold with its double, over a lake thinned in noise pools (`_thin`, grime spots left, the next
landing and the dogs' sticks kept foul by `KEEP_NEAR`); the fleet followed hull to pier and
the logo's hold **filmed first, on the dirty lake** (Richard: a much dirtier lake at the end,
a few clear pools; thinning only cleans, so the order is the state); the pack on the east beach (one asleep, three sent swimming out, `_send_dogs`); the furnished shed
from Richard's own save (`_load_shed_save` copies `user://my_dirty_little_lake.save` and never writes
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

**Re-cut 2026-09-24** (`/grill-me` with Richard, then his notes on the first cut): still
~31 s, the logo at beat 55. Order: walkout + `cast_3` + gold `cast_5` (casts 2 and 4 cut),
ferries, **wash** ("Wash your findings": the sofa on the stand, the tray and cross hidden,
sprayed at real speed by a raster that stays on the piece and ends about half clean), the
shed (**not re-filmed**, its entry left out of the shot list; old frames kept), dogs,
**wildlife** ("Bring back wildlife", 14 beats: lake thinned 97%, then flora and wildlife
reset and handed a clean share ramping 0.05 to 1 over five seconds so plants sprout on
screen, extra frogs swimming in to the shore in view every 12 frames, five broods flown in
from 520 px off). Then the logo over the dirty lake as before. **The parked fleet is hidden
in the casts, the dogs and the wildlife** (`_hide_boats`): it blocked the second cast. A
**pigeon** shot is still in the probe (forced head pop, `_force_pop`) and **cut from the
edit**, by Richard's call. `build_trailer.py` needs PIL: run it with the psd-extract venv
python.

### The Haul Goes Into the Box (2026-10-02, Richard, off the store clip)
- **The flights draw over the island's buildings** (`Haul` at `Lake.IN_FRONT + 1`): it sat on
  `CRATE_LAYER` before the hive in the tree, so every piece crossing the hive went under it.
  Over the walkers too: a thrown piece is in the air.
- **The last stretch into a box is the box's** (`Haul.LAND_FROM` 0.7, `draw_landing_on`,
  `landing_moved`): past it, a piece bound for the island crate (untagged) or a pier's box
  (tagged with its `Dropoff`) is not drawn by the haul; the box draws it between its heap and
  its near walls, shrinking to its heap's size (`Yard.HEAP_SIZE` 0.62, `Dropoff.HEAP_SIZE`
  0.5). It lands within `BOX_SCATTER` (10 x 4 px) of the mouth's middle, not the old 26 x 11,
  which hung pieces over the rim. Hull loading and other flights are unchanged.
- **A flight's shadow shows only while it is up** (`Haul._aloft`, `SHADOW_IN` 0.18): from the
  first frame, a whole catch's shadows stacked at the angler's hand into a black blotch.
- **The rope leaves the chest** (`Angler.HAND_HEIGHT` 0.5 to 0.36): half way up the figure is
  the beard under the hat. `tools/shot_rope.tscn` (desktop build) saves the four directions,
  `tools/last_rope_<dir>.png`.
- `test_lake` guards the layer, the scatter, the hand-over, the crate's reference, the shadow
  and the hand height.

### The Wash Room in First Person (2026-10-02, Richard, off the Steam screenshot)
**Supersedes** `HORIZON`/`LAKE_TALL`, `DOG_TALL`/`DOG_BAND`, the pack-tile patchwork ground
and the lanes as shares of the lake in The Pump and the Wash Room.
- **One perspective model** (`WashBackdrop.y_at`/`d_at`, `EYE` 0.43, `NEAR_D` 1.6): ground
  `d` tiles out stands at the eye line plus `(1 - EYE) * NEAR_D / d` of the window. The lawn
  meets the sand at `LAWN_D` 4, the near waterline is `SHORE_D` 7.5 (the island's 3.5-tile
  beach), the far one `FAR_D` 33.5. The lake box, the ferries' lanes (`BOAT_LANES` by
  distance, 26 and 12 tiles, grains 1 and 2), the rubbish's grain (`_grain_at`) and the dogs
  (`DOG_D` 7 to 3 tiles, drawn `DOG_SIZE / d` tall) all come off it. `BANDS` thin towards
  the far shore. The dogs trot at `DOG_PACE` 140 (was 95).
- **The far bank is drawn at one canvas px a painted one** (`FAR_PIXEL`): the pack's trees at
  native size are about a tenth of the window tall. Its strip (`build_wash_backdrop.py`
  `BANK_TALL` 96, grass 5, sand 3 rows) closes the gaps between crowns (`close_canopy`:
  any see-through pixel under the canopy with crown either side within `CANOPY_REACH` or
  above it goes the trees' deep shade), so no sky shows through the wood.
- **The ground is the island's own rules in Python** (`draw_lawn`, `draw_beach`,
  `lawn_shades`, `_pnoise` periodic across `WIDE` so the strips wrap): blades in
  `Ground.lawn_shades`' greens with clumps, the bank's tone blotches on the far grass; the
  sand's wet edge, tide line with shells, ripples in patches, pebbles, pale dry strip, and
  the lawn's blades standing over its edge. `NEAR_SAND` 38 rows must match what `y_at` puts
  between `LAWN_D` and `SHORE_D` on a 720-line window.
- **The sky's steps are dithered** (`SKY_STEPS` 8, `_blend_sky`, `SKY_BLEND` 2): across
  each edge the next step's colour comes in at a quarter, then a half, and the old one goes
  out at a half, then a quarter, through a 2x2 ordered pattern of whole painted pixels (one
  tiled texture draw a band). **The water keeps no dither, by its own decision**; the sky
  is the one place it is used.
- **The hose is a shop row** (`WashRoom.HoseRow`, `hose_value`/`hose_cost`/`hose_tag_box`,
  `ShopSkin.draw_tag_on`/`tag_box_of`): the NET board's plate, a rail with the level,
  "Hose" (`Text.HOSE_NAME`, replacing `HOSE_UP`/`HOSE_TOP`) over "1 → 2", and the shop's
  price tag, which is the one part that buys; at the top the maxed row's green and MAX.
- **A long tray name drops to `TEXT_TINY` before it is cut** (the shop's ladder).
- **The stage stands in the middle of what the tray leaves** (`WashStand.centre_x`, `_mid`,
  set by `WashRoom._lay_out` to halfway between the tray's right edge and the window's): the
  pallet, the find, the nozzle and the hose. Below nought it is the window's middle.
- **A cloud bank sits low along the horizon** (the first two `CLOUD_LAYERS`, `CLOUD_FOOT`
  1.06, Richard: "lower and more prominent, covering the skyline"): the feet stand behind the
  wood, never out under it. **Supersedes "every cloud's foot is held above the trees"** in
  The Sky in the Water. The far wood has two more dark back ranks of crowns (`RANKS`), so the
  canopy fill (`CANOPY_REACH` 4) only closes small gaps and the skyline is bumps, not plateaus.
- **Grandfather Clock is "Old Clock"** (`build_pack_decor.py`, `pieces.json`, the CSV).
- Probe: `tools/shot_steam.tscn` `FILM_ONLY=wash` (desktop build, own save) poses the white
  sofa half washed with eight finds waiting, two ferries and three dogs staged by distance.
  All numbers first guesses for Richard's eye.

### The Screenshot Key and the Key Art (2026-10-02, Steam page)
- **Deleted 2026-10-03 (The Pre-Release Cleanup).** So were `shot_keyart`, `shot_steam` and `shot_wash_place`; the frames in `tools/film/` stay. **F12 in a debug build saves the screen** (`scripts/shot_key.gd`, a child of the `Pad`
  autoload so `project.godot` is untouched): a PNG at the window's own size, HUD and all, to
  `Games/Marketing/My Dirty Little Lake/screenshots/raw/` (`user://screenshots/` where
  `res://` is not a folder). **Shift+F12 takes it bare**: every CanvasLayer hidden for one
  drawn frame. A faint blink answers the press after the grab. Store screenshots are taken
  by hand with it, by Richard's call.
- **The capsules and library art come from `tools/shot_keyart.tscn`** (desktop build,
  `--fixed-fps 60`, own save, under its own node): bare renders of a lake split clean and
  dirty, into `Marketing/.../source/keyart/`, cut by that folder's `capsules_v2.py` at whole
  pixel ratios. `FILM_ONLY=tall_z2` runs alone (the shots share one lake).
- **How the store dresses the lake** (2026-10-02, Richard): `film_trailer.gd`'s
  `_dress_island()` pins the hut to its second look (`Lake.shed_stage_pin` 1, under nought
  the meter decides as in play) and keeps the crate heaped past `Yard.CRATE_FULL`;
  `_spread_life(apart)` sends away any animal within `apart` world px of one kept and sets
  `Wildlife.held`, which stops `_reckon` refilling behind it. `shot_steam` resets the flora
  to the shot's own share, and `_hide_boats` moors what it hides (a hidden hull loaded the
  crate and its spray crossed the water on its own). The
  capsules use the two-line lockup only, may lie over the island's far sand, and the small
  capsule centres it on its drawn pixels. **The store's clips ship as WEBM** (VP9, 30 fps,
  no audio): Steam's About This Game froze MP4s on their first frame; GIFs are 780 wide.
- **The pier shot pours a big hold, the west clip leaves a clean spot** (same day, Richard):
  the ferry lands `PIER_HOLD` 64 at the Loading track's top (`PIER_VOLLEY`), so a thick line
  of pieces is in the air, onto a box held at a low heap (`PIER_BOX_START`) until the hold
  starts landing, so the heap is seen stacking. The west clip is cast on an almost grimy
  lake (`WEST_CLEAN` 0.08); as each net lands `_empty_under` takes what is left under its
  mouth (`WEST_EMPTY` of it), so once the catch patch closes the honest map shows a clean
  spot, and the clip runs `WEST_CLIP_FRAMES` to see it.
- **The tornado shot** (`shot_steam` `FILM_ONLY=tornado`, same day): a funnel pinned
  `TORN_OUT` tiles off the island's screen-right beach (`TORN_ANGLE`; left to wander it
  hugged the shore, and straight down-screen its cloud covered the angler), a whirl topped up
  past `Tornado.CARRY_MOST` to `TORN_CARRY` by hand (`_feed_tornado`, the event's own entry)
  and spread wider and lower (`_spread_whirl`), and the net aimed `TORN_SHORT` of its mouth
  short of the foot so it is caught flying at the funnel, not landed over it.
  **Second pass** (Richard: farther out, zoomed out, net midway, a grimier lake with
  contrast): `TORN_OUT` 13, `TORN_ZOOM` 2, `TORN_CLEAN` 0.45 with a ring `TORN_CLEAR` tiles
  round the foot emptied (`_clear_round`) so the whirl reads on clean water, no flings
  (they would land on the ring), `TORN_CARRY` 56 spread `TORN_BAND`/`TORN_MARGIN`, and the
  net aimed at the foot itself and caught half way.
- **The wash-and-place loop** (`tools/shot_wash_place.tscn`, same day): on a copy of
  `play_decor`'s save, the globe is taken off the floor and put at the pump with
  `TRAY_MORE` other finds on the tray (an illusion of more to wash), washed by a jet that
  walks to the nearest grime left (`_dirtiest_near`; a fixed raster missed cells and never
  reached `DONE_AT`), then the room's own close into the shed, and the globe carried off the
  shelf and put down where it stood. Frames in `tools/film/steam/wash_place/`. **Real time,
  by Richard's call** (a 3x wash looked bad): the jet sweeps the find in rows over its own
  width (`ROW_GAP`, `SWEEP_PACE`), then chases what is left; about six seconds at hose
  level 3, which is the wear rate, not the path. The cut drops the room swap and opens on a
  close crop of the shelf and the room, with the wooden cursor drawn in afterwards off
  `pointer.txt` (the capture has no hardware cursor). `06_wash_place.gif`/`.mp4`.
- **The start shot** (`shot_steam` `FILM_ONLY=dirty`, same day): a new game's lake, nothing
  thinned, at the far stop (`_zoom(1)`), the boats hidden, the angler on the island's west
  shore facing west and a dog sat beside him facing the same way. **A facing set from
  outside needs `Angler._repaint`**: the sheet is only redrawn on a change it notices
  itself, so `facing` alone left him facing the camera. `07_dirty_start.png`.
- **Grime to beauty** (`shot_steam` `FILM_ONLY=beauty`, same day): the island centred at
  zoom 3, no HUD, the angler beside the crate with a dog, the lake cleaned in a wave out
  from the island (tiles ordered by `Iso.past_shelf` plus noise, paced by distance squared
  so the shot's own water takes most of the film), stopping at `BEAUTY_MOST` so the run does
  not end and raise the farewell. The hut mends off the meter, the hive takes its colony at
  `BEAUTY_HIVE_AT`, water plants held to `BEAUTY_PADS`, crowds thinned, one duck family
  flown in to the south. Cut to 11.8 s: `08_grime_to_beauty.gif`/`.mp4`.
- **The crayfish crawl under the fish** (same day, Richard): they and their shadows are on
  `Wildlife`'s two bed layers (`bed_layers`), which the lake reparents before `Fish` in its
  tree; same z 3, so the tree's order is what puts the fish over them.

### The Store Re-shoot (2026-10-04, `/grill-me` with Richard, `tools/shot_steam.tscn`)
`shot_steam` is back, rewritten on the trailer v2 probe (`film_trailer.gd`, which it extends),
for four store assets. **One shot a run** (`FILM_ONLY=s_west` and so on): thinning only cleans,
so a shot after the beauty's wave finds an empty lake. Frames go to `tools/film/<shot>/`, the log
to `tools/film/last_steam.log`; the clips are cut with ffmpeg into
`Marketing/.../screenshots/candidates/` (1170x658 30 fps WEBM and MP4, 640-wide 15 fps GIF), and
the files they replaced are in `candidates/old_20261002/`.
- **`s_west`** (`01_cast_west`): one gold net thrown 14 tiles off the west beach over a lake 8%
  cleaned, the landing stocked so the bag fills; the count climbs gold to 54/54 and turns its
  pale red (the trailer's `HaulCount.pop` fix), and what the net leaves under it is emptied, so a
  clean spot shows once the patch closes (filmed, but cut: Richard, the clip ends a beat after
  the count turns red, kept frames 50 to 240, 3.2 s). The camera eases from `WEST_LEAN_REST` of the way to
  the landing out to `WEST_LEAN_OUT` with the net and back to `WEST_LEAN_BACK` on the haul.
- **`s_beauty`** (`08_grime_to_beauty`): the trailer's `t2_beauty` as it stands, kept from the
  wave's first frame, 12 s.
- **`s_tornado`** (`09_tornado_orbit`, new): no nets; over a lake 25% cleaned the funnel circles
  the island at `ORBIT_OUT` tiles past the beach, one lap in `ORBIT_LAP` s, its whirl topped up to
  `ORBIT_CARRY` and flinging as in play; the camera follows its foot. Kept from 3.5 s after
  touchdown, filmed 14 s and cut to its first 7 (Richard: too long).
- **`s_bignet`** (`01_cast`): one plain net at Width 20 thrown north, saved as PNGs through the
  flight in `tools/film/s_bignet_png/`; `big_06` is the still. Replaces the double-net still.
- All numbers first guesses for Richard's eye.

### The Logo, v3 (2026-10-08, `/grill-me` with Richard)
The trailer's logo read soft and its shadow looked cut out. **Both were the pixel file**:
`shots3.json` laid `logo/v1/mdll_logo_stacked_pixel.png`, which `make_logo.py`'s `pixelate`
shrinks to 640 px, cuts to 64 colours and thresholds to on/off alpha (the soft shadow became
a hard dark band), then the trailer resized that 1280 px picture to 1190 by nearest.
**The trailer fix is owed** (Richard, to do with his other trailer fixes): point it at the
hi-res `logo/v3/mdll_logo_stacked.png` and keep it smooth, like the HD captions. The
vertical cut is out of scope.
- **v3 is the hi-res logo with a new shadow**, picked off a mock (`logo/mock_shadows.py`,
  `tools/logo_check/shadow_sheet.png`; three styles, two directions, over the end card, the
  loading lake and two capsules): option **C, halo, down-left**: the sticker's outline swept
  `SHADOW_DROP` (0.08 of the font size) down-left (the game's sun) as a solid dark slab, over
  a wide soft dark glow. Supersedes v1's faint blur off down-right. Also fixes a pale strip
  inside the A's hole (`DROWN_BEVEL`: no top-lit bevel under LAKE's waterline). Letters,
  colours and outline are v1's.
- **Built by `Marketing/My Dirty Little Lake/logo/make_logo.py --v3 stacked compact`**
  (git-ignored, the logo venv) into `logo/v3/`, hi-res only. Without `--v3` it still makes
  v1. **The halo makes the picture bigger round the same letters** (2403x885 against
  2237x723), so everything lays the logo by the sticker's box, alpha 250 and up:
  `LoadingScreen.LOGO_INK` (163, 143, 2093 x 579) in the game, `V1_BOX`/`V3_INK` in
  `capsules_v2.py`. **Re-measure both on a re-render.**
- **Where it is**: `assets/mdll_logo_stacked.png` (menu and loading screen, letters where
  v1's stood), `assets/boot_splash.png` (re-shot, `SHOT_SPLASH=1`; the loading lake has no
  logo and was not), and every capsule (`capsules_v2.py` reads `logo/v3`; the old set is in
  `capsules_v2/old_20261008/`). The library logo stays 1280 wide, so its letters are 7%
  smaller there.

### The Icon (2026-10-03, `/grill-me` with Richard, `tools/build_icon.py`)
The game's own icon, in place of Godot's: the orange dog (slot 1, `dog_02`) sitting, mouth
closed, its first sit frame **mirrored to face right**, a bust running off the icon's bottom and
right edges, over a rounded square split on a stepped diagonal, murky `water_dirty` bottom-
left, clean `water_clean` top-right. Picked off `tools/last_icon_sheet.png`.
- **Native pixels only**: masters at 16, 24 and 32; 48 is 24 doubled, 64/128/256 are 32 in
  whole steps. **16 px is the cut head alone** (the bust's head is 17 wide), drawn over the
  corners; the bust is clipped by them. No outline, the corners cut transparent.
- **The cut head filling the icon was the other layout and lost** ("B is much better"),
  as were sound lines, an oak frame and a 2x redraw. **The bark frame was built first and
  swapped for the closed mouth** (Richard, same session), at the same spot in the icon.
- **Where**: `icon.png` (256, `config/icon`), `icon.ico` (16-256, `config/windows_native_icon`
  and the Windows preset's `application/icon` and `console_wrapper_icon`). **Godot 4.7 writes
  the .exe's icon itself, no rcedit**: a test export's embedded 32 px icon matched the master
  pixel for pixel. Steam's client icon (`.ico`) and community icon (184 JPG, the bust on a
  square 23 px backing x8) go to `Marketing/My Dirty Little Lake/steam/icons/`.
- Re-run with `--write` (base python, the psd-extract site-packages on `PYTHONPATH`) after the
  dog sheet or the water swatches change, then reimport. Out of scope: the web/PWA icons.

### Trailer v3: Habibs 3, New Order, Real Sound (2026-10-08, `/grill-me` with Richard)
Before the store goes public. `marketing/.../trailer/shots3.json` through `build_trailer2.py`;
v2's `shots2.json` is kept as the record. Landscape only; the vertical cut waits for this one.
- **Song**: `Habibs 3 #4.2` (the interim take), 144.0 BPM. Its arrangement is 2#1's to the
  sample: the drop hits at 6.70 s in both, so `first_beat` 0.0333 puts the drop on beat 16
  (`song_in` 4.0 rounds to 4.2, the drop on trailer beat 6). v2's 143.55 / 0.093 grid drifted
  about 0.1 s by the end. Re-cut once more on Nuven's master.
- **Order**: cast (cut to 9 beats: net home and the first pieces into the crate) -> upgrade,
  cast, upgrade, gold -> Wash & decorate -> Tame the elements -> Clean with friends ->
  Recycle for money -> wildlife -> logo, held 2 s longer (beauty 25 beats, `t2_beauty` filmed
  24 s).
- **The game's own sound is recorded** (`tools/film_audio.gd`): the films run under Movie
  Maker (`--write-movie`, the throwaway AVI kept small by an `override.cfg` holding
  `editor/movie_writer/mjpeg_quality` 0.05, deleted after), which mixes one frame of sound a
  frame, and `AudioEffectRecord` on the SFX and Ambience buses writes `sfx.wav` and
  `ambience.wav` per shot from its first kept frame (music bus muted, buses at Prefs'
  defaults, `settings.cfg` untouched). Checked in step: a bark logged on kept frame 51 starts
  at 0.86 s. The cut lays the stems on every stretch shown at real speed, the event log
  (`sfx.txt`, which now also hears `play_ui`, the coo and the start sound) on slowed or sped
  stretches, and the ambience stem at real speed everywhere. `"sfx_stem": false` keeps a cut on
  the log (the pier, whose coins and bell stay the hand-laid roll). The hand-laid rain and
  hose beds are gone; the thunder hits, the bell, the coin roll and the Wishlist chime stay.
- **Probe fixes**: the dogs set off before the first kept frame (`PACK_SIT` -40); the angler
  turns to the funnel before every throw (`_turn_to`).
- Runs: the three `film_trailer` runs and `shot_wash_place`, each with `--write-movie`.

### The Vertical Trailer (2026-10-05, `/grill-me` with Richard)
The wishlist trailer (v2, `shots2.json`) for TikTok, Reels, Stories and Shorts: the same edit,
song, beats, captions and 37.2 s, **re-filmed in portrait, not cropped**.
- **Film**: `FILM_TALL=1` on `tools/film_trailer.tscn` (same three runs as v2) opens a
  1080x1920 borderless window (taller than the 1080p monitor; the viewport renders all of it)
  with canvas 720x1280, so the stretch is 1.5 and every zoom level and UI size is v2's. Frames
  go to `tools/film/v_<shot>/`, the log to `last_film_tall.log`. The shop shots open
  2196x1920 at canvas 1220 wide (stretch 1.8) and hide the HUD skin and the pricing plate, so
  the edit crops the NET and LUCK boards and the purse 1:1. The opening's push starts at zoom
  2 (zoom 1's view is taller than the ground) and its camera rides the edit's virtual camera.
  The tornado stands up and to the right of the island (`TORN_ANGLE` -1.95, out 15), so the
  column rises over the angler. **Casts stay sideways, by decision**: iso tiles are 2:1, so an
  up-screen throw is half as long on screen.
- **`tools/shot_wash_place.tscn` is back** (deleted 2026-10-03), with `FILM_TALL`. It copies
  `user://play_decor.save` and raises the copy's version to the game's. At the room swap the
  vertical film opens a 1650x1920 window (canvas 1100 wide), so the room draws at zoom 2
  rather than the portrait canvas's 1 (Richard: "decoration should be much more zoomed in"),
  and the edit crops it 1:1.
- **The wash room's lawn strip is 360 rows** (`build_wash_backdrop.py` `LAWN_TALL`, was 200;
  `LAWN_NEAR` 200 keeps the near scale): a 9:16 window showed a flat green block under it.
  The first 200 rows are pixel-identical, so a landscape window is unchanged.
- **Cut**: `marketing/.../trailer/shots_vertical.json` through `build_trailer2.py` into
  `trailer/vertical/Wishlist Trailer Vertical.mp4`. The wash is two cuts, the washing zoomed
  1.7x onto the stand (Richard: "more focused on washing and less on the menu"). Captions sit
  at 128 px (`caption_px`, up to 76% of the width) inside the feeds' safe area (clear of the top 14%, bottom 25%, right 12%) and off the action,
  checked frame by frame; `vertical/review_sheet.py` makes the stills sheet.

### The Devlog (2026-09-25, `/grill-me` with Richard, `tools/film_devlog.tscn`, `marketing/My Dirty Little Lake/devlog/`)
**Deleted 2026-10-03 (The Pre-Release Cleanup).** `film_devlog` only; the cut in `marketing/` and the frames stay.
An 83 s YouTube devlog cut to Save ME (80 BPM, grid from `assets/music/beats.json`), captions
only, no game UI. Captions are Richard's, in `shots.json`; a later voiceover is written to fit
the shot lengths, nothing is re-timed for it.
- **Film**: `film_devlog.gd` extends `film_trailer.gd` (whose save and log paths are vars now,
  with a wall-clock quit and `_cast`'s gold and double split): the day timelapse and a forced
  shower with two flashes (phase driven by hand to `turn_at` 0.88, **no fake dawn or dusk**),
  then three plain casts at Width 0 / 9 / 20 over a lake thinned 15 / 30 / 50%, a gold cast and a
  double cast over 55%. `_dry()` stops the shower before each cast, or it rains through them.
  **Never stand the angler at (2, 2) off the island's middle**: the crate hides him there.
- **Reused from the trailer's film**: `wash`, `wildlife`, `clean_hold` (8.5 s, so the logo
  ending is 11 beats). **The prototype** is Richard's own recording of the itch build,
  `marketing/.../Prototype_Recording.mp4`, 30 fps, brought to 60 and muted.
- **Cut**: `build_devlog.py` (psd-extract venv python) imports `build_trailer.py` and adds a
  video-file cut, one caption list over the whole timeline (multi-line, per-caption size and
  height) and no "Wishlist now". A cast cut's `land_beat` must sit close enough to `in` that
  `land_frame` covers the gap (a beat is 45 frames).
- **Second pass, same day** (Richard): the middle plain cast is out and the trailer's
  `ferries` stands in its place; the music is `music_db` -9 under the game's own recordings
  (`sfx` in `shots.json`, beats, one-shots and looped beds, mixed with `normalize=0`). **No rain
  or thunder sound exists yet** (`Weather` waits on Nuven's recordings), so the rain shot
  carries the lake's ambience only.

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
  `tools/last_test.log`). `test_siege` went with the siege (2026-09-29).

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
- `scripts/flora.gd`, `scripts/fish.gd`, `scripts/wildlife.gd` — nature coming back as the lake cleans (see Nature Coming Back, The Lake Fills With Life)
- `scripts/sfx.gd` — the `Sound` autoload: recordings from `assets/sfx/` (see Sound), plus the few sounds still built in code

---

## Before You Start
1. Read root `CLAUDE.md` for shared Godot setup, anti-patterns, vigilance rule
2. Check GitHub Issues (filter by `project:my-dirty-little-lake`)
3. Water and drag feel are locked (Richard tested); progression numbers can shift
4. If editing grid layout or the angler: run `tools/test_lake.tscn` headless
5. If finding contradiction: stop and name it (see root CLAUDE.md vigilance rule)

---

## See Also
- Root `CLAUDE.md` — shared knowledge, art pipeline details, vigilance rule
- `Strait Across/CLAUDE.md` — sister project (shares water shader, similar project structure)
- Game design notes: `~/Downloads/lake-cleanup-game-notes.md` (historical reference, not current)
