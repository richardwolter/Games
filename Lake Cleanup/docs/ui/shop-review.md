# The upgrades shop: review and proposals

2026-09-17. A UI/UX pass over `scripts/shop_skin.gd` and `Lake._shop_rows`, reviewed
against the ten priority categories of the `ui-ux-pro-max` skill. Nothing here is built
yet: the layout is chosen off mockups first.

**A note on the skill.** `ui-ux-pro-max` is a plugin whose substance is a `search.py` over
a database of web and mobile patterns — 79 styles, 192 palettes, 22 stacks, none of them
Godot, and its rules are 44x44 px touch targets and ARIA labels. The plugin is not
installed here and the database does not transfer. What transfers is its **ten priority
rule categories**, used below as the order to look in. Where a finding needed a number it
was measured, not taken from the database.

## How the numbers were got

Two headless probes, both read-only:

- `tools/probe_shop_text.gd` writes `tools/last_shop_text.log`. It rebuilds `ShopSkin`'s
  own layout arithmetic and measures every row's name, value and price in Bungee at the
  ladder's sizes, at three window shapes.
- `tools/probe_shop_glyphs.gd` writes `tools/last_shop_glyphs.log`. Bungee's coverage of
  the separator glyphs, and what the proposed strings measure.

Contrast ratios below are sRGB relative luminance per WCAG 2.1, computed off the `Style`
constants.

## Findings

Ordered by the skill's priority categories. `file:line` is where the behaviour lives.

### 1. Accessibility

1. **An unaffordable row's value line sits at 1.82:1 contrast, drawn at 11 px.**
   `BOARD_INK_DIM` lerped a quarter towards `BOARD_ROW_OFF` (`shop_skin.gd:663`). The
   floor for body text is 4.5:1. The row's own comment says a row you cannot afford is
   "drawn back rather than hidden: the point of a shop is knowing what is coming" — the
   intent is right and the execution cancels it.

   | what | ratio | verdict |
   |---|---|---|
   | name, affordable | 4.80:1 | passes |
   | value, affordable | 3.47:1 | large text only |
   | level, affordable | 3.20:1 | large text only |
   | name, unaffordable | 2.19:1 | fails |
   | value, unaffordable | 1.82:1 | fails |
   | level, unaffordable | 3.05:1 | large text only |

2. **Affordable and unaffordable are told apart by hue alone.** `BOARD_ROW` (blue-grey)
   against `BOARD_ROW_OFF` (green) are 1.30:1 apart in luminance (`style.gd:74`, `:84`).
   A red-green colourblind player is reading two faces of the same brightness. Nothing
   else in the row changes state — no rule, no mark, no weight.

3. **11 px is under the floor.** `TEXT_TINY` is where a squeezed value lands
   (`shop_skin.gd:657`), and it is where most of them land — see finding 6.

### 4, 6. Style, typography

4. **A row's writing gets 108 px.** Board 262 wide, face 232, row 204; the "?" takes the
   first 13 and the price tag the last 83 (`shop_skin.gd:640`, `TAG_SHARE` 0.34).
   **The same 108 px on every monitor** — `BOARDS_WIDE` caps at 1180, so a 21:9 screen
   buys the shop nothing but more empty table.

5. **The level footnote costs 47 of those 108 px.** "Lvl 20" at `TEXT_TINY`
   (`shop_skin.gd:646`). 43% of a row's writing width goes on a number the code itself
   calls a footnote.

6. **What that costs today, measured at a fresh save:**
   - **12 of 17 value lines are cut with an ellipsis**, at 11 px.
   - **9 of 17 names drop their level** at the top of their track — the row stops saying
     what level it is.
   - **"Recycle Bonus" is cut with an ellipsis in its own name**, at every level.
   - The value lines want 129–359 px and are given 108.

   So at a new game most of the shop shows a truncated sentence at the smallest size on
   the ladder. This is the headline finding.

7. **Seven value grammars.** `+40%` / `Tier 2` / `3 per cast` / `waits 4s at most` /
   `2 in the water` / `18%: +1 tier, +4 held` / `$12 a bird` (`lake.gd` `_shop_rows`).
   Nothing carries from one row to the next, so each is read from scratch.

8. **Two rows called "Speed" mean two different things** — the reel on the net board, the
   sail on the ferry's. **"Haul" (net) / "Hold" (ferry) / "Fast Sell" (ferry)** are three
   near-synonyms for three unrelated mechanics.

### 8. Forms and feedback

9. **The explanation is behind a hover.** The "?" is 15 px square hung on a row's corner
   (`HELP_SIZE`, `HELP_INSET`). It works on pad — the virtual cursor is a real pointer —
   but it is the only route to what an upgrade does, and it is the smallest target on the
   board.

10. **A row that cannot be afforded is silent on click** (`shop_skin.gd:397`) and looks
    much like one with nothing left to sell. "Max" in the tag is the only tell.

11. **Nothing says a row is nearly affordable** — one delivery away reads the same as
    hopeless.

### 5, 9. Layout and navigation

12. **A board drops rows rather than scrolling.** Rows squeeze `ROW_TALL` 50 to
    `ROW_LEAST` 40 and then `break` (`shop_skin.gd:484`) — a purchasable upgrade simply
    stops being drawn. Measured: at the 720-high design frame this bites at **12 rows on
    one board**, and the net board has 7. So it does not bite today. It is what makes
    four-up fragile: group headings and any new track eat that margin.

13. **`UPGRADE_ORDER` is an implementation order, not a reading order.** The net board
    reads Width, Strength, Range, Speed, Haul, then Lucky haul and Double cast — five
    stats and two odds in one undifferentiated column of seven.

14. **No localization slack anywhere.** One `tr()` call in the whole game
    (`dropoff.gd:210`), no `locale/`, nothing in `project.godot`. Row values are built by
    `%` format strings with English word order and hand pluralization (`"%d dog%s"`).
    German runs about 35% longer than English, against a row that already cuts English.

## Proposal A — names

Every name unique across all four boards, using the word the game already uses for the
thing.

| board | now | proposed | why |
|---|---|---|---|
| net | Width | **Width** | unchanged |
| net | Strength | **Strength** | unchanged |
| net | Range | **Range** | unchanged |
| net | Speed | **Reel** | kills the collision with the ferry's Speed; `reel.tres` already calls it that |
| net | Haul | **Catch** | kills the Haul/Hold pair; the code's own word (`CastNet.catch`) |
| net | Lucky haul | **Lucky cast** | pairs with Double cast, the other per-cast roll |
| net | Double cast | **Double cast** | unchanged |
| ferry | Speed | **Sailing** | the collision, resolved on both sides |
| ferry | Hold | **Hold** | unchanged |
| ferry | Fast Sell | **Loading** | it is the volley at both ends of a run, not a price |
| ferry | Extra ferry | **Fleet** | `fleet.tres`; "Extra ferry" reads oddly at level 3 |
| dog | Fetching | **Fetch** | same meaning, one word |
| dog | Keenness | **Keenness** | unchanged |
| dog | Strong Dogs | **Carry** | says what it raises; "Strong" collided with the net's Strength |
| dog | Pack | **Pack** | unchanged |
| market | Recycle Bonus | **Bonus yard** | fits the row; says the thing moves between yards |
| market | Pigeons | **Pigeons** | unchanged |

Alternative for **Carry**: **Bite**.

## Proposal B — one value grammar

Every row reads `now → next unit`: the unit written once at the end, and the arrow doing
the work the words "(… next)" did. Bungee has U+2192 (checked), and an arrow is not a word
anybody has to translate. A maxed track shows the figure alone.

| shape | example |
|---|---|
| rate | `+40% → +55%` |
| count | `4 → 5 a cast` |
| odds | `12% → 18%` |
| tier | `Tier 2 → 3` |
| seconds | `12s → 9s` |
| money | `$8 → $10` |

Measured: **every proposed value line fits the 108 px**, against 12 of 17 cut today. The
longest is Fleet at 95 px.

## Proposal C — structure

Three things the mockups test:

1. **Group rows by what they change** — a carved rule and a small heading inside a board.
   Net: *The cast* (Width, Strength, Range, Reel, Catch) / *Luck* (Lucky cast, Double
   cast). Ferry: *The run* (Sailing, Hold, Loading) / *The fleet* (Fleet). Dog: *The pack*
   (Pack, Carry) / *The trip* (Fetch, Keenness). Market: one group, so no heading.
2. **Move the level footnote off the name line.** 43% of the writing width for a footnote.
   Mocked as a small carved figure beside the "?".
3. **The layout itself** — four-up, tabbed, two-up.

## The mockups

`tools/shot_shop_mock.tscn` (desktop build, `--fixed-fps 60`) draws each layout over the
real lake in `Style`'s own wood, with the sprites the live shop was lent. It writes
`tools/last_shop_now.png` (the shop as it stands) and `last_shop_<layout>_<state>.png`.
`tools/shop_mock.gd` holds the layouts; nothing in `scripts/` knows it exists.

A **red band** on a row is the probe's own diagnostic: it marks how far the writing runs
past the room the row leaves it. It is not part of any proposal.

All three carry the same three changes: the proposed names, the one-line value grammar, and
a **left rail** on every row — one sunk column holding the "?" over the level's figure. The
rail takes 26 px of row and gives back the 47 px the name line spent on "Lvl 20", and it
turns the smallest target on the board into a full-height one.

Two things the mock also proposes, because the pictures could not be judged without them:

- **The value line is written in the row's own ink**, not a quarter of the way back into the
  face. That lerp is what put it under every contrast floor.
- **An affordable row carries the lit edge along its top; an unaffordable one does not.** A
  second channel for the state, so it does not rest on hue alone. With that, the writing can
  stay readable on both: `BOARD_INK_DIM` at `Color(0.76, 0.83, 0.75)` reads 5.01:1 on the off
  face for both lines, against 2.19:1 and 1.82:1 today. The price tag keeps the dim wood —
  the price is the thing you cannot afford, not the name of the upgrade.

### What the pictures say

**Four-up** (`last_shop_four_up_*`). Fresh, it reads: every value fits, the groups land, the
board is legible for the first time. Maxed, it **fails** — a six-figure price makes the tag
wide enough to run over the name, and Bonus yard, Lucky cast, Double cast and Keenness are
all struck through by their own price. The rail costs the row 21 px and the name gets 87–99
px, which three of the seventeen proposed names do not fit at `TEXT_BODY`. Four-up survives
the start of a run and not the end of one.

**Tabbed** (`last_shop_tabbed_*`). Nothing truncates at any state, at any name length, with
room to spare — and that is its problem: a 1000 px row carrying 100 px of writing is mostly
empty plate. It would want that width spent on something (the blurb inline, two columns),
and the board that is up is also the only board you can see. Most slack of the three, least
comparison.

**Two-up** (`last_shop_two_up_*`). Reads best. Nothing truncates fresh or maxed — `$420000`
sits beside `24 A CAST` with room either side — the boards still read as objects on a table,
the groups have air around them, and there is slack left for a language that runs a third
longer. Costs one click to see the other two boards.

**Recommendation: two-up.** It is the only one of the three that survives the endgame, and
it leaves the most room for a translation. Open on it: whether the pager is right, and
whether the dog and market page (`last_shop_two_up_page2`) is too empty at two and four rows.

## What shipped (2026-09-17)

Four-up, with late-game truncation accepted (Richard). The fourth board became **LUCK** —
Lucky cast and Double cast moved onto it beside Bonus yard and Pigeons — titles lost their
articles, the ferry became **BOATS** and the dog **DOGS**, and the close cross went back on
the last board's title plank. The pricing plate kept its place under the middle two boards,
freed from the tallest board's height so that it survives the boards being levelled.

The recycle bonus moved onto the plate: the boosted material's column is lit and wears the
same gold stars `Dropoff.Shine` puts on the boosted box at the pier. It carries no figure of
its own — `_mean_pay_of` already multiplies the boosted kind, so the plate had been printing
the boosted price all along with nothing saying why.

Names, grammar, the rail, the ink and the lit edge all went in as proposed. One grammar bug
was found in the shipping pass: `"Tier %d"` on both sides of the arrow said the unit twice
at 111 px against a row's 87, so tier rows carry a prefix and read `Tier 0 → 1`.

**Cuts before the pass: 21. After the layout pass: 8. After the grammar pass: 2.** — and the 8 is the honest number. Measuring level 0
and max said 2; mid-run is worse than either end, because a rate track reads `+0% -> +35%` at
the start and `+700%` at the top but `+385% -> +420%` in the middle, which wants 118 px
against a row's 87. Two are names (Double cast 115, Bonus yard 108, both on LUCK) and six are
rate tracks mid-run. The probe measures all three states now.

### The grammar pass (same day)

The six rate tracks were fixed by changing what the numbers are rather than how they are
drawn. A value is now two bare figures either side of the arrow, a prefix on the first and a
suffix on the last, each said once: `100 -> 135%`, `Tier 2 -> 3`, `$26 -> 30`, `12 -> 9s`.
Nouns are gone ("a cast", "aboard", "a trip", "dogs", "boats"); marks stay; "Tier" stays.

The load-bearing change is the **basis**: a scaling track reads as a share of its own level 0
rather than as the rise over it. `+385% -> +420%` becomes `485 -> 520%`. Dropping the `+`
without changing the basis would have been a lie -- `385%` claims 3.85x where the stat is
4.85x -- so the sign and the basis go together. Odds and the bonus keep bare percents,
starting at 0 where a scaling track starts at 100.

Worth recording: **dropping the nouns fixed almost nothing on its own.** `17 -> 18 a cast`
went 102 px to 52, but the widest line in the shop was a rate track with no noun in it.

**Widest value line: 118 px before, 87 after**, against the 87 a row leaves. Only the two
names still cut. Levers if that is ever worth spending, none taken: `RAIL_WIDE` 26 px (worth
~6 back), `TAG_SHARE` 0.34 (a four-figure price needs ~55 of the 69 it reserves), and the
names themselves.

`test_lake` is at 677 checks, 0 failed, with `_stage_shop_shape` added.

## Still open

- Real blurb wording, 23 lines. Separate job — the placeholder sentences ship as written,
  without the word "Placeholder".
- A font with Cyrillic and CJK. Separate job; nothing here forecloses it.
- Contrast elsewhere: the shop has its own `INK_DIM` now, but `Style.BOARD_INK_DIM` still
  inks the shed's shelf and the settings board at 2.19:1. Owed the same fix, as its own pass.
- Findings 10 and 11 are untouched: an unaffordable row is still silent on click, and nothing
  says a row is one delivery away.
