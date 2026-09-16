# Lake Cleanup: upgrade tree design

Status: **third pass, for playtest** (2026-09-14, afternoon) · Sim config: `lake-tree.json` (built by `build_tree.py`,
priced by `price_by_income.py`) · Current-shop model: `current.json` (built by `build_current.py`) ·
Skill: `incremental-progression`. The tuner page published on 2026-09-12 predates this pass and does not know
the new nodes or stats.

## Targets

| target | value | source |
|---|---|---|
| Real full clear | about 70 min (focused bot window 60-80, the sim calibrated to Richard's own run) | Richard, 2026-09-14 third pass (was 90, then 1 h) |
| Casual full clear (decorating, relaxed) | sim window 115-160 | follows the focused target |
| Endgame | spend down near zero: the last buy lands close to the final sale, and nothing waits long in the box at the clear | Richard, third pass (his run ended on 16,426 unspent) |
| Time between buys | brisk start, slowing to the end: about 30 s at min 0, 1 min at 10, 2 min at 30, 4 min at 60, 6 min at 90 (`gapCurve`) | Richard, 2026-09-14 |
| Box | the boats nearly keep up: left alone for 2 min, the box is usually empty | Richard, 2026-09-14 |
| Start | net only, 50 sludge buys the first ferry; a slightly better base net and a cheap first ring ("both a bit") | Richard |
| Net shape | rings of Line / Bag / Mouth (plus a luck slot), each joined by a strength node needing any two of its ring | Richard, 2026-09-14 |
| Dog | very cheap, bought right after the first ferry; the net's first ring needs it. Its training spreads through the run behind the strength nodes | Richard, third pass (superseded "mid-game, 25-30 min") |
| Luck and pay | Lucky Haul and Double Cast in the net's rings, Recycle Bonus on the ferry, Pigeons in a Bonus tree beside the dog, from Heavy Lift on | Richard, 2026-09-14; third pass moved the pigeons later |
| Range | the last Line node reaches every shore by the end game | Richard, 2026-09-14 (second request) |
| Reel and width | a quarter stronger again on every Line (reel) and Mouth node | Richard, third pass |
| Bank Reach | replaced by Fast Reel, a reel keystone: the range was already enough | Richard, third pass |
| Boats | more cargo and speed late: Deeper Hull IV-V, Trim Sails IV | Richard, third pass |
| Strength nodes | drawn bigger with a gold rim on the tree screen | Richard, third pass |
| Out of scope | sell-by-tier nodes, the shop run, boat animation timing, the skimmer, a new tree screen look | Richard |

## What the first playtest showed

`user://tree_playtest.log`, run of 2026-09-13 23:33, on the first tree:

- 26 min in, 14.9% of the lake cleared, where the first tree's sim expected about half.
- From minute 10 on, the box held 250-850 pieces. Two ferries (hold 36, speed 9.2) sold about 2.4 pieces a
  second, where the sim expected about 6.
- Buys came about every 60 s early and every 90-120 s by min 15, with one 4.6 min wait (Wide Mouth I).
- Casts: median 2.0-2.4 s apart while casting, 13-25 casts a minute, 1.5 pieces a cast in the first 2 minutes.

**Why the ferries were slow in play and fast in the sim:** `tools/probe_rates` loaded every ferry run with a
single material, so every measured run was a one-stop trip. A real hold is mixed, and a run laps every yard
its load needs, with a volley at each. Re-probed with mixed loads in the lake's own material shares:
**8.4 s + 206.6 / speed + 0.059 s a piece** (rms 0.2 s over 14 runs), which is 58 s at the old base speed of
4.2, where the old fit said 18 s. That is the "economy not circling": every net buy fed a box the boats
could not empty.

## What the second playtest showed

Run of 2026-09-14 12:36, on the second-pass tree (`replay_playtest.py` reads it):

- The lake cleared at 51.9 min. Everything but Bank Reach was bought by 50 min; Richard then held 64,426,
  bought Bank Reach last (48,000) and ended on 16,426.
- From 33 min the box held 300-600 pieces with three ferries; the last piece sold at 56.6 min.
- The dog came at 22.8 min and its five training nodes in a burst at 45-48 min.
- 67 pigeons netted in the whole run (about 1,700-3,000 sludge).
- **The sim was slow**: replaying those purchases at their real seconds (the new `replay` bot policy) the
  model cleared at 71.9 min. Catch at 1.7x (`k_catch_scale`) puts it at 53.9 (rms 0.03 of the lake over
  the run). Ferries stay at 1.0 (`k_ferry_scale`): at that the model's box already runs heavier than play's
  late, so the box checks err on the safe side. The focused bot now stands in for Richard's own pace.

## Model and calibration

Chain: **net -> box -> ferry -> pier (Recycle Bonus) -> sludge**, **dog -> box**, **pigeons -> sludge**.
Measured by `tools/probe_rates.tscn` (headless), fitted by `fit_probe.py` into `calibration.json`.

| constant | value | source | how to confirm |
|---|---|---|---|
| Ferry run | 8.4 s + 2 x 103.3 / speed + 0.059 x cargo | **measured, mixed loads** (2026-09-14) | re-probe after boat or pier changes |
| Cast mechanics | distance/26 + 0.98 x distance/reel | fitted, rms 0.03 s | |
| `k_density` | 1.2 catchable pieces per swept tile | fitted | |
| `k_catch_scale` | 1.7 on the net's catch | **fitted** to the 12:36 playtest, `replay_playtest.py` | replay the next playtest |
| `k_ferry_scale` | 1.0 on ferry capacity | fitted to the same run (the model's late box is already heavier than play's) | |
| `k_reach_far` | the farthest shore is 35.6 tiles from anywhere the angler can stand (mean 29.0) | **measured**, `tools/probe_reach.gd` (2026-09-14) | re-run after changes to the island, the bank or the wade limit |
| `k_shelf` | the first 2.5 tiles of a cast sweep nothing | fitted by hand to the probe's bare net (1.0 a cast, hold 3) and the playtest (1.5) | |
| `k_aim` | 2.0 s a cast of player time | estimate; the playtest's cast gaps (2.0-2.4 s including flight) agree | |
| `k_double_found` | 1.0 | measured: the second net found a spot on 112 of 112 casts (fresh lake) | a late-lake probe |
| Lucky cast | holds 4 more, and lifts one tier heavier (`access_lucky`) | from the code (`LUCKY_EXTRA`, `luck_power`) | |
| `k_bonus_share` | 0.25 of sales at the boosted yard | **estimate** (one yard of four) | log sales by yard |
| `k_bird_swept` | 0.0015 birds a cast per swept tile | measured, not aimed at (33 birds in 112 casts) | |
| `k_bird_aim` | 3x that when the player aims at birds | **estimate** | `birds` is now in the playtest log's progress lines |
| Casual player | random affordable node 15% of the time, decorates 40% of play | estimate | |

## Structure

```
START: net only, 50 sludge
└─ First Ferry ◆
   ├─ DOG: Adopt the Dog ◆ (100) ─┬─ Good Fetch I [Stronger Pull] ─ Good Fetch II [Heavy Lift] ─ Beachcomber ★ [Iron Pull]
   │                              └─ Keen Nose [Heavy Lift] ─ Long Leash [Iron Pull]
   │  └─ NET (rings; each strength node needs any 2 of the ring above it)
   │     Ring 0:  Longer Line I · Bigger Bag I · Wide Mouth I
   │              └─ Stronger Pull ◆t1
   │     Ring 1:  Longer Line II · Bigger Bag II · Wide Mouth II · Lucky Haul I
   │              └─ Heavy Lift ◆t2
   │     Ring 2:  Longer Line III · Bigger Bag III · Wide Mouth III · Double Cast I
   │              └─ Iron Pull ◆t3
   │     Ring 3:  Longer Line IV (reaches every shore) · Bigger Bag IV · Wide Mouth IV · Lucky Haul II
   │              └─ Titan Pull ◆t4
   │     Ring 4:  Fast Reel ★ · Bigger Bag V · Trawl Mouth ★ · Double Cast II
   ├─ FERRY: Deeper Hull I-V · Trim Sails I-IV · Second / Third Ferry ◆ · Recycle Bonus I-III
   └─ BONUS [Heavy Lift]: Pigeon Bounty I ─ II [Iron Pull] ─ III [Titan Pull] ─ IV
```

- **The dog comes first.** It costs 100 and the net's first ring hangs off it, so the second purchase of
  every run is the dog. Its training nodes each also need a strength node (in brackets), which spreads them
  through the run instead of leaving them for a burst at the end.
- **Strength is the connector.** Each ring's nodes are different (reach, bag, mouth, luck), any two open the
  strength node, and the strength node opens the next ring.
- **The bag is the pace.** In the calibrated model the bag is what sets how fast the lake clears (half the
  bag moved the clear from 52 to 70 min; half the reel or the mouth moved it 6-8). So the bag grows by 2 a
  node (3 at Bag V, 15 in all from a base of 4) while reel and width are a quarter stronger again.
- **Reel is everywhere** (same day, Richard: "much improved, scattered around other upgrades"): the base
  reel doubled to 6, every strength node adds reel (+1.5 / +2 / +2.5 / +3) and every luck slot +1, on top
  of the Lines. Mid-game (Iron Pull, Line III) the reel is about 20 tiles a second, where it was 9; the
  whole tree reaches 39.
- **Fast Reel replaces Bank Reach**: +10 reel. Longer Line IV already reaches every shore (35.9 tiles
  against the farthest 35.6), so the old keystone's range was never used.
- **The ferry goes deeper late**: Deeper Hull IV-V (+14, +16) and Trim Sails IV (+5), for Titan Pull's catch.
- **Pigeons from Heavy Lift on**, each later level behind the next strength node. Still cheap extras.
- **On the tree screen** the strength nodes are drawn 1.5x with a gold rim, and a gate from a strength node
  to another category's node is a gold badge with the strength glyph on that node, not a line.

## Nodes

Bought, gain and payback are the focused bot's run.

### Net

| node | name | appears after | cost | effect | tags | bought (min) | income gain | payback |
|---|---|---|---|---|---|---|---|---|
| `line_1` | Longer Line I | Adopt the Dog | 550 | net_range +2.5, reel +1.25 |  | 1.3 | +30% | 123 s |
| `bag_1` | Bigger Bag I | Adopt the Dog | 600 | net_hold +2 |  | 3.2 | +0% | - |
| `mouth_1` | Wide Mouth I | Adopt the Dog | 850 | net_radius +0.25 |  | 3.8 | +18% | 197 s |
| `pull_1` | Stronger Pull | any 2 of Longer Line I, Bigger Bag I, Wide Mouth I | 1,000 | net_power =1, reel +1.5 | unlock | 4.4 | +5% | 703 s |
| `line_2` | Longer Line II | Stronger Pull | 1,200 | net_range +5.0, reel +1.9 |  | 8.1 | +14% | 158 s |
| `mouth_2` | Wide Mouth II | Stronger Pull | 2,000 | net_radius +0.45 |  | 10.5 | +3% | 888 s |
| `lucky_1` | Lucky Haul I | Stronger Pull | 3,000 | lucky_odds +0.15, reel +1.0 |  | 11.5 | +3% | 1030 s |
| `pull_2` | Heavy Lift | any 2 of Longer Line II, Bigger Bag II, Wide Mouth II, Lucky Haul I | 4,500 | net_power =2, reel +2.0 | unlock | 12.0 | +5% | 1005 s |
| `line_3` | Longer Line III | Heavy Lift | 6,000 | net_range +9.0, reel +3.1 |  | 14.8 | +24% | 341 s |
| `bag_2` | Bigger Bag II | Stronger Pull | 1,400 | net_hold +2 |  | 15.1 | +4% | 395 s |
| `bag_3` | Bigger Bag III | Heavy Lift | 6,000 | net_hold +2 |  | 19.8 | +21% | 243 s |
| `mouth_3` | Wide Mouth III | Heavy Lift | 10,000 | net_radius +0.55 |  | 23.1 | +7% | 1099 s |
| `double_1` | Double Cast I | Heavy Lift | 9,500 | double_odds +0.1, reel +1.0 |  | 24.1 | +7% | 1027 s |
| `pull_3` | Iron Pull | any 2 of Longer Line III, Bigger Bag III, Wide Mouth III, Double Cast I | 14,000 | net_power =3, reel +2.5 | unlock | 24.9 | +17% | 640 s |
| `line_4` | Longer Line IV | Iron Pull | 15,000 | net_range +15.0, reel +3.75 |  | 32.9 | +996% | 122 s |
| `bag_4` | Bigger Bag IV | Iron Pull | 15,000 | net_hold +2 |  | 34.8 | +10% | 1102 s |
| `lucky_2` | Lucky Haul II | Iron Pull | 16,000 | lucky_odds +0.15, reel +1.0 |  | 40.2 | +5% | 1739 s |
| `mouth_4` | Wide Mouth IV | Iron Pull | 19,000 | net_radius +0.75 |  | 42.2 | +1% | 7669 s |
| `pull_4` | Titan Pull | any 2 of Longer Line IV, Bigger Bag IV, Wide Mouth IV, Lucky Haul II | 20,000 | net_power =4, reel +3.0 | unlock | 44.2 | +6% | 1956 s |
| `bag_5` | Bigger Bag V | Titan Pull | 32,000 | net_hold +3 |  | 47.8 | +22% | 751 s |
| `double_2` | Double Cast II | Titan Pull | 23,000 | double_odds +0.1, reel +1.0 |  | 49.4 | +9% | 1038 s |
| `trawl` | Trawl Mouth | Titan Pull | 25,000 | net_radius +1.25 | keystone | 51.4 | +1% | 7431 s |
| `fast_reel` | Fast Reel | Titan Pull | 25,000 | reel +10.0 | keystone | 53.4 | +0% | 23341 s |

### Ferry

| node | name | appears after | cost | effect | tags | bought (min) | income gain | payback |
|---|---|---|---|---|---|---|---|---|
| `ferry_1` | First Ferry | start | 50 | boats =1 | unlock | 0.0 | from zero | 3 s |
| `hull_1` | Deeper Hull I | First Ferry | 650 | cargo +6 |  | 0.8 | +5% | 862 s |
| `sails_1` | Trim Sails I | First Ferry | 750 | boat_speed +2.0 |  | 1.9 | +16% | 234 s |
| `hull_2` | Deeper Hull II | Deeper Hull I | 1,300 | cargo +8 |  | 2.9 | +21% | 266 s |
| `ferry_2` | Second Ferry | Deeper Hull I | 4,000 | boats +1 | unlock | 7.3 | +99% | 138 s |
| `recycle_1` | Recycle Bonus I | Trim Sails I | 1,500 | recycle_bonus +0.3 | unlock | 7.8 | +7% | 346 s |
| `sails_2` | Trim Sails II | Trim Sails I | 1,600 | boat_speed +3.0 |  | 8.5 | +18% | 146 s |
| `hull_3` | Deeper Hull III | Deeper Hull II | 6,500 | cargo +12 |  | 10.0 | +25% | 355 s |
| `sails_3` | Trim Sails III | Trim Sails II | 7,000 | boat_speed +4.0 |  | 16.3 | +15% | 494 s |
| `recycle_2` | Recycle Bonus II | Recycle Bonus I | 7,000 | recycle_bonus +0.5 |  | 18.7 | +11% | 578 s |
| `hull_4` | Deeper Hull IV | Deeper Hull III | 11,000 | cargo +14 |  | 21.0 | +21% | 436 s |
| `ferry_3` | Third Ferry | Second Ferry | 12,000 | boats +1 | unlock | 36.1 | +12% | 658 s |
| `recycle_3` | Recycle Bonus III | Recycle Bonus II | 20,000 | recycle_bonus +0.7 |  | 38.2 | +14% | 904 s |
| `sails_4` | Trim Sails IV | Trim Sails III | 25,000 | boat_speed +5.0 |  | 55.4 | +0% | - |
| `hull_5` | Deeper Hull V | Deeper Hull IV | 36,000 | cargo +16 |  | 57.4 | +0% | - |

### Dog

| node | name | appears after | cost | effect | tags | bought (min) | income gain | payback |
|---|---|---|---|---|---|---|---|---|
| `dog` | Adopt the Dog | First Ferry | 100 | dog =1 | unlock, utility | 0.2 | from zero | - |
| `fetch_1` | Good Fetch I | Adopt the Dog and Stronger Pull | 1,100 | dog_fetch +1 | utility | 5.0 | from zero | - |
| `nose` | Keen Nose | Adopt the Dog and Heavy Lift | 5,000 | dog_wait_cut +3 | utility | 12.7 | from zero | - |
| `fetch_2` | Good Fetch II | Good Fetch I and Heavy Lift | 7,500 | dog_fetch +1 | utility | 17.5 | from zero | - |
| `beachcomber` | Beachcomber | Good Fetch II and Iron Pull | 9,000 | dog_beach =0.85, dog_strand_speed =1.6 | keystone, utility | 25.9 | from zero | - |
| `leash` | Long Leash | Keen Nose and Iron Pull | 11,000 | dog_reach +6 | utility | 27.2 | from zero | - |

### Bonus

| node | name | appears after | cost | effect | tags | bought (min) | income gain | payback |
|---|---|---|---|---|---|---|---|---|
| `pigeons_1` | Pigeon Bounty I | Heavy Lift | 6,000 | bird_worth +0.5 | unlock, utility | 13.8 | from zero | - |
| `pigeons_2` | Pigeon Bounty II | Pigeon Bounty I and Iron Pull | 11,000 | bird_worth +0.6 | utility | 28.4 | from zero | - |
| `pigeons_3` | Pigeon Bounty III | Pigeon Bounty II and Titan Pull | 11,000 | bird_worth +0.6 | utility | 44.2 | from zero | - |
| `pigeons_4` | Pigeon Bounty IV | Pigeon Bounty III | 13,000 | bird_worth +0.7 | utility | 45.2 | from zero | - |
Base stats: `net_range` 4.4, `net_hold` 4, `reel` 6.0, `boat_speed` 8.0, `cargo` 28, `boats` 0, dog absent,
`lucky_odds` 0, `double_odds` 0, `recycle_bonus` 0, `bird_worth` 1. Starting sludge 50. Tree total 459,650.

## How it is priced

1. `build_tree.py` lays out the tree and an intended purchase order (`ORDER`), walked along a brisk gap curve
   and stretched so the last scheduled buy lands at 60 min; each node's `at` is its minute on that walk.
2. `price_by_income.py`, eight passes: every node costs the focused bot's income at its `at` times the gap
   the curve wants there (a helper, at most 75 s of income), at least 70% of the dearest node before it
   (helpers 35%), and then the **spend-down**: what the bot holds at the clear plus the unsold box, less what
   it never bought, is spread over the nodes scheduled from 35 min on.
3. Three passes of the spend-down alone (`price_by_income.py spend`), since the income pricing and the
   spend-down pull against each other.

`sh docs/progression/loop.sh` runs all of it, plus the sim and `check_tree.py`.

## Pacing

`tree-report/report.md` plus `check_tree.py`.

| | check | result | read |
|---|---|---|---|
| WARN | focused clear 60-80 min | 59.5 min | just under, since the reel boost: the faster reel speeds the clear |
| WARN | casual clear 115-160 min | 101.4 min | |
| PASS | no soft-lock (focused, casual, cheapest) | all finish; cheapest 68.6 min | |
| PASS | buy gaps follow the curve (0.5-2x per 10 min) | 30 / 65 / 70 / 120 / 120 / 120 s | brisk and slowing |
| PASS | no gap over 300 s | longest 280 s | |
| PASS | dog bought before any net node | second purchase | |
| PASS | spend-down | 8,759 left at the clear, 1.9% of 468,359 earned, every node bought | Richard's run: 16,426 plus a 48,000 buy he did not need |
| PASS | box sells within a minute of the clear | 0 pieces | |
| PASS | ferries carry at least 0.8x the catch / box empties within 2 min | focused 93% / 100%, casual 95% / 100% | the cheapest-first bot fails the box (68%): it skips hulls |
| WARN | last buy leaves 10-25% of the game | 5% (last buy 62.1 min) | the spend-down's price: the last node is bought near the end, as asked |
| FAIL | every buy +8% income | Bigger Bag I, Lucky Haul I, Recycle Bonus I, Third Ferry, Wide Mouth III | ring parts pay off together |
| FAIL | every node earns its purchase | 9 filler | Titan Pull through its ring, the dog's helpers, late ferry depth the bot does not need |

## Open questions

1. **Pigeons earn little.** 67 birds a run. The lever is more birds or a higher `EconomyConfig.bird_bonus`.
2. **Real ferries against the model.** The model now runs its late box heavier than play did, but Richard
   found the boats short after Titan Pull. Hull IV-V and Sails IV are there for that; the next playtest's box
   column says whether the model or the feel is right.
3. **Lucky Haul and Double Cast are weak late**, as before; optional ring slots.
4. **`k_bonus_share` and `k_bird_aim` are estimates.**
5. **Heavy pieces paying more**: the contradiction noted in the first pass (tier pay is nearly flat).

## Handoff

Playable in tree test mode (main menu, "New game (tree)"); the game reads `lake-tree.json` directly.
New in the game for this pass: `requireCount` on nodes (`UpgradeTree.is_visible`), and the tree stats
`lucky_odds`, `double_odds`, `recycle_bonus` and `bird_worth`, read by `Lake.lucky_chance`,
`double_cast_chance`, `recycle_bonus` and `bird_pay` when `tree_mode`. The bonus clock starts with the first
node that gives a bonus. Old tree saves lose the nodes that no longer exist (`sanitize`).

Replay a playtest against the model: `python docs/progression/replay_playtest.py <session start> [catch scale] [ferry scale]`.

Re-run after any change to the lake or these numbers:
`python docs/progression/build_current.py`, then `sh docs/progression/loop.sh`.
Re-probe (`tools/probe_rates.tscn`, then `fit_probe.py`) after changes to the net, boats, dog or fill.
