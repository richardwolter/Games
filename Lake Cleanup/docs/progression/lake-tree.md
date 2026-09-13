# Lake Cleanup: upgrade tree design

Status: **draft for Richard's review** (2026-09-12) · Sim config: `lake-tree.json` (built by `build_tree.py`) ·
Current-shop model: `current.json` (built by `build_current.py`) · Tuner: https://claude.ai/code/artifact/02566e97-ccd1-4b7d-9e3e-92907019227e · Skill: `incremental-progression`

## Targets

| target | value | source |
|---|---|---|
| Focused full clear (upgrades only, no decorating) | 1 hour (sim window 50-70 min) | Richard, 2026-09-12 |
| Casual full clear (decorating, relaxed) | 2 hours (sim window 100-140 min) | Richard |
| Start state | Net only, starting money buys the first boat; dog and everything else through the tree | Richard |
| Tree shape | One tree per category (net, ferry, dog), nodes revealed as neighbours are bought | Richard |
| Feel | Early game is hard work, early upgrades visibly relieve it; stronger upgrades cost more and feel worth it | Richard |
| Coupling | Cross-tree links at key tiers plus pricing | Richard |
| Out of scope | Runs/prestige, second currency, many-tiny-node trees, the skimmer (cut; room kept for new upgrades later) | Richard |

## Diagnosis of the current shop

Model of today's 11 tracks with real prices, calibrated on the real lake (`current-report/report.md`).

| complaint | what the sim and the probe show |
|---|---|
| Buy anything anytime; width, strength, haul always first | Measured: from the mid-game levels on, **every cast fills the bag** (28 of 28 pieces at hold 28, whatever the width, strength or range). Hold is the real catch limit, so it's always right to buy. Width only matters in thin late water, where it decides everything, which is why it feels essential. |
| Width grows too large too fast | Width's radius goes 0.6 to 10.3 tiles (area x160) on a price curve (x1.6 per level) far below its effect curve. |
| Ferries overrun or fall behind | Both, in sequence: one 6-piece ferry carries 0.34 pieces/s against a 0.8/s net at the start (net upgrades earn nothing), then extra hulls reach 98% of samples overrunning. |
| (not reported) Skimmer | Measured: a level-4 skimmer on a ferry leaving with 5 pieces brings back **98** in one 8 s run; level 7+ fills the whole 157 hold. Every bot that buys it clears the lake in 6-10 min. Richard avoids it because it "speeds the game up too much". Cut. |
| Clear time | The skimmer-avoiding bot clears in 20 min, matching Richard's 20-40 min. |

**Contradiction found (for Richard):** `economy_config.gd` says the filth half of pay "is why a late hold of
heavy pieces outearns an early hold of light ones", but the trash data makes pollution nearly flat by
tier (mean 3.01 / 3.40 / 3.07 / 3.27 / 3.50 for tiers 0-4), so a tier-4 piece pays about 13% more than a
tier-0 one. Either the comment or the data is stale. This design doesn't depend on it. If heavy pieces
should pay more, that becomes a pricing input for the next pass.

## Model and calibration

Chain: **net -> box -> ferry -> pier -> sludge**, plus **dog -> box** for near light pieces and the strand.
Measured by `tools/probe_rates.tscn` (headless, sets levels and times real casts and runs), fitted by
`fit_probe.py` into `calibration.json`.

| constant | value | source | how to confirm |
|---|---|---|---|
| Rubbish by tier | 6,785 / 3,896 / 2,769 / 1,551 / 1,711 | measured (census) | re-run probe after fill changes |
| Strand + beach litter | 448 (273 + 175) | measured | |
| Mean stack | 4.07 pieces per occupied tile | measured | |
| `k_density` | 1.2 catchable pieces per swept tile (fresh lake, all tiers) | fitted, rms 3 pieces | probe casts in a half-cleared lake |
| Cast mechanics | distance/26 + 0.98 x distance/reel seconds | fitted, rms 0.03 s | |
| `k_aim` | 2.0 s of player time per cast | **estimate** | time 20 casts in a playtest |
| `k_cast_share` | casts land at 75% of max range | **estimate** | |
| Ferry run | 6.3 s + 48.4 / speed | fitted, rms 2.8 s | |
| Dog | min(fetch, 2.2) pieces per trip, 8 s trip + wait | fitted to 3.3 / 7.3 / 11.3 pieces a minute | |
| Strand reach | a mouth overlapping 2.5 tiles of bank takes all of it | **estimate** ("width helps clearing it") | |
| Casual player | buys a random affordable node 15% of the time, reacts every 20 s, decorates 40% of play time | **estimate** | how long does decorating really take? |

## Structure

```
START: net only, 50 sludge
└─ First Ferry ◆ (the forced first buy)
   ├─ NET
   │  └─ Longer Line I
   │     ├─ Bigger Bag I ─ Bag II ─ Bag III [needs Second Ferry] ─ Bag IV ─ Bag V
   │     ├─ Stronger Pull ◆t1 ─ Heavy Lift ◆t2 ─ Iron Pull ◆t3 ─ Titan Pull ◆t4
   │     └─ Longer Line II ─ Line III ─┬─ Line IV (reaches all water) ─ Bank Reach ★
   │                                   └─ Wide Mouth I ─ Wide Mouth II ─ Trawl Mouth ★
   ├─ FERRY: Deeper Hull I ─ II ─ III · Trim Sails I ─ II · Second Ferry ◆ ─ Third Ferry ◆
   └─ DOG [appears after Bigger Bag II]: Adopt the Dog ◆ ─ Good Fetch I ─ II ─ Beachcomber ★
                                                          └ Keen Nose ─ Long Leash
```

- **Strength is the spine.** Each tier opens fresh, dense water: a felt jump every 3-10 minutes.
- **Reach before bag.** The first casts land in the rubbish-free shelf; Longer Line I is the first relief.
- **The bag is the engine**, capped at 39 (was 110) and linked to the Second Ferry so the net can't outrun the boats.
- **Width is a late sweep**, 0.6 to 3.6 tiles total (was 10.3), for the thin water at the end.
- **Longer Line IV reaches all the water**, so no purchase order can lock a player out; Bank Reach only adds the bank.
- **The dog is a helper**, judged by what it takes off your hands, not by income. Beachcomber makes it the strand specialist.
- **Coupling:** one structural link (Bag III needs Second Ferry); the rest is pricing. Two more links (Bag V needs Third Ferry) were
  tried and removed. Ferries were already ahead, so the link only forced a useless buy.

## Nodes

Bought/gain/payback columns are the focused bot's run.

### Net

| node | name | appears after | cost | effect | tags | bought (min) | income gain | payback |
|---|---|---|---|---|---|---|---|---|
| `line_1` | Longer Line I | First Ferry | 150 | net_range +2.2, reel +1 |  | 0.2 | +20% | 49 s |
| `bag_1` | Bigger Bag I | Longer Line I | 600 | net_hold +3 |  | 0.8 | +11% | 309 s |
| `pull_1` | Stronger Pull | Longer Line I | 1,000 | net_power =1 | unlock | 2.4 | +9% | 363 s |
| `line_2` | Longer Line II | Longer Line I | 700 | net_range +4, reel +2 |  | 1.3 | +7% | 485 s |
| `bag_2` | Bigger Bag II | Bigger Bag I | 1,300 | net_hold +3 |  | 3.3 | +14% | 244 s |
| `bag_3` | Bigger Bag III | Bigger Bag II + Second Ferry | 3,000 | net_hold +6 |  | 7.5 | +36% | 162 s |
| `pull_2` | Heavy Lift | Stronger Pull | 4,500 | net_power =2 | unlock | 8.6 | +26% | 261 s |
| `line_3` | Longer Line III | Longer Line II | 3,000 | net_range +7, reel +3 |  | 6.5 | +28% | 266 s |
| `bag_4` | Bigger Bag IV | Bigger Bag III | 6,000 | net_hold +10 |  | 13.6 | +27% | 261 s |
| `mouth_1` | Wide Mouth I | Longer Line III | 9,000 | net_radius +0.4 |  | 11.8 | +10% | 1157 s |
| `pull_3` | Iron Pull | Heavy Lift | 16,000 | net_power =3 | unlock | 24.8 | +22% | 554 s |
| `line_4` | Longer Line IV | Longer Line III | 14,000 | net_range +10.7, reel +5 |  | 17.9 | +64% | 278 s |
| `bag_5` | Bigger Bag V | Bigger Bag IV | 17,000 | net_hold +14 |  | 21.6 | +21% | 636 s |
| `mouth_2` | Wide Mouth II | Wide Mouth I | 27,000 | net_radius +0.6 |  | 30.0 | +32% | 543 s |
| `pull_4` | Titan Pull | Iron Pull | 24,000 | net_power =4 | unlock | 27.3 | +24% | 709 s |
| `bank_reach` | Bank Reach | Longer Line IV | 34,000 | net_range +3, reel +8 | keystone | 32.8 | +5% | 3240 s |
| `trawl` | Trawl Mouth | Wide Mouth II | 40,000 | net_radius +2 | keystone | 36.1 | +18% | 1275 s |

### Ferry

| node | name | appears after | cost | effect | tags | bought (min) | income gain | payback |
|---|---|---|---|---|---|---|---|---|
| `ferry_1` | First Ferry | start | 50 | boats =1 | unlock | 0.0 | from zero | 3 s |
| `hull_1` | Deeper Hull I | First Ferry | 300 | cargo +4 |  | 1.6 | +22% | 65 s |
| `sails_1` | Trim Sails I | First Ferry | 500 | boat_speed +2 |  | 1.9 | +26% | 75 s |
| `hull_2` | Deeper Hull II | Deeper Hull I | 800 | cargo +6 |  | 2.8 | +18% | 133 s |
| `ferry_2` | Second Ferry | Deeper Hull I | 2,400 | boats +1 | unlock | 5.8 | +25% | 229 s |
| `sails_2` | Trim Sails II | Trim Sails I | 2,800 | boat_speed +3 |  | 14.0 | +22% | 119 s |
| `hull_3` | Deeper Hull III | Deeper Hull II | 4,000 | cargo +8 |  | 12.3 | +29% | 166 s |
| `ferry_3` | Third Ferry | Second Ferry | 11,000 | boats +1 | unlock | 19.3 | +32% | 267 s |

### Dog

| node | name | appears after | cost | effect | tags | bought (min) |
|---|---|---|---|---|---|---|
| `dog` | Adopt the Dog | Bigger Bag II | 700 | dog joins | unlock, utility | 3.6 |
| `fetch_1` | Good Fetch I | Adopt the Dog | 1,000 | dog_fetch +1 | utility | 4.0 |
| `nose` | Keen Nose | Adopt the Dog | 2,000 | dog_wait_cut +3 | utility | 4.8 |
| `fetch_2` | Good Fetch II | Good Fetch I | 6,000 | dog_fetch +1 | utility | 9.8 |
| `leash` | Long Leash | Keen Nose | 13,000 | dog reach 6 -> 12 tiles | utility | 22.9 |
| `beachcomber` | Beachcomber | Good Fetch II | 9,000 | 85% of trips to the strand, 1.6x faster there | keystone, utility | 15.4 |

Base stats that change: `boats` 1 -> 0 (bought), ferry `cargo` 6 -> 18 (a 6-piece first ferry made every early net buy
worthless), dog absent until adopted. Starting sludge 50. Tree total 254,800 sludge against about 370,000 the lake pays.

## Pacing

`tree-report/report.md`, 16 checks: 9 pass, 6 warn, 1 fail.

| | check | result | read |
|---|---|---|---|
| PASS | focused clear 50-70 min | 54.3 min | |
| PASS | casual clear 100-140 min | 100.2 min (seeds 95 / 100 / 104) | at the edge; hangs on the 40% decorating estimate |
| PASS | no soft-lock (focused, casual, cheapest) | all finish; cheapest in 59.6 min | an earlier draft let the cheapest-first player strand itself at 66% (fixed by making Line IV reach all water) |
| PASS | early buys every 10-60 s | median 30 s | |
| PASS | no dead stretch over 5 min | longest 200 s | |
| PASS | no dominant pick | best/second median 1.54x; top pick rotates (strength 32%) | |
| PASS | no gatekeepers | none | |
| WARN | finale 10-25% of game after the last buy | 33% (last buy 36 min) | the tail: see open question 1 |
| WARN | every buy +8% income | Longer Line II +7.5% | borderline |
| WARN | payback within 4x of phase | First Ferry and Line I very cheap (intended relief), Wide Mouth I slow | Mouth I is a late-water tool priced before its time |
| WARN | ferry within 0.8-1.5x of catch | 66% inside, 33% overrunning | overrun is the safe side: a full box never piles up for long |
| WARN | unlock spacing 2-15 min | Stronger Pull 2.4, Dog 3.6, Second Ferry 5.8 are close | early systems arrive quickly; spread them if the start feels crowded |
| FAIL | single upgrades felt | 3 moments where a net and a ferry buy only pay off together (min 12, 14, 19) | the cost of links + pricing: the two stages grow in step, so at a few points neither side alone moves income. The world still shows it (box fills, then empties) |

Also: Bank Reach and Trawl Mouth are bought late with small **90-second** gains. The sim values a node
by the next 90 s, and tail tools pay off over the last 20 minutes. Judge those two in play, not by
this number.

## Open questions

1. **The tail.** After the last purchase (36 min) the focused player spends 18 min catching thinning
   stragglers. Options: accept it as the "full power" victory lap; add a finale node (e.g. remaining
   pieces glint, or ferries sweep for stragglers) at about 45 min; or widen Trawl Mouth further. Needs
   Richard's call on how the end should feel.
2. **`k_aim` and decorating time** are estimates. Timing 20 casts and one decorating session in a
   playtest would confirm the clear times.
3. **Heavy pieces paying more** (the contradiction above). If wanted, tier-based pay changes the late
   income curve, and the tree gets re-priced.
4. **Room for new upgrades** where the skimmer was: the ferry tree is now 8 nodes and ends at 19 min.
   A late ferry keystone (not a skimmer) would give the ferry side a finale too.

## Handoff

No code in this document. What the build session needs, as data:

| design value | game data | notes |
|---|---|---|
| Each node: id, tree, name, parents, requireAll, cost, effects [stat, op, value], tags | **new resource type**, e.g. `resources/upgrades/tree/<id>.tres` with those fields | `UpgradeTrack` (price_base x mult^L, curve a+bL+cL^2) can't express a tree. Keep `UpgradeTrack` only if some node gets ranks. |
| Stats from owned nodes | computed from base values by full recompute: largest `set`, then sum of `add`, then product of `mul` | same order-independent rule as Sickest Man Alive's `Loadout` |
| Base stats | net_radius 0.6, net_power 0, net_range 3.4, reel 2.4, net_hold 3; boat_speed 4.2, cargo 18, boats 0; dog absent, dog_fetch 1, wait cut 0 | `cargo` base changes from 6 |
| Starting sludge | 50 | covers First Ferry exactly |
| Skimmer | removed: `skimmer` track, `PRICES`/`MAX_LEVELS` entries, the shop row | boat skimmer code can stay dormant or go; design no longer uses it |
| Dog reach, strand share, strand speed | new dog parameters: reach tiles (6, Long Leash 12), strand trip share (0.35 today via `STRAND_ODDS`, Beachcomber 0.85), strand trip speed x1.6 | today these are constants in `dog.gd` |
| Dog presence | dog not in the scene until Adopt the Dog | today the dog exists from the start |
| Reveal-on-buy | a node is visible when any parent is owned (all, for requireAll) | the shop boards need a tree view per category; silhouettes of the next ring are recommended |
| Pay | unchanged (`economy.tres` 2.5 + pollution x 6) | see open question 3 |

**Playable now as tree test mode** (2026-09-12): main menu, "New game (tree)". The game reads this
tree straight from `lake-tree.json`, on its own save slot, beside the untouched shop. Playtest data
lands in `user://tree_playtest.log`. Bring it back and the sim gets recalibrated from real play (see
CLAUDE.md, Tree Test Mode). The table above is still what a final build would need.

Re-run after any change to the lake or these numbers:
`python docs/progression/build_current.py`, `python docs/progression/build_tree.py`,
`node ~/.claude/skills/incremental-progression/scripts/run_sim.js docs/progression/lake-tree.json`.
Re-probe (`tools/probe_rates.tscn`, then `fit_probe.py`) after changes to the net, boats, dog or fill.
