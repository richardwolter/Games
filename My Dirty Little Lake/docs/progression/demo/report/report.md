# Progression sim: My Dirty Little Lake (demo)

## Checks

| | check | result |
|---|---|---|
| PASS | focused can always finish (no soft-lock) | finishes |
| PASS | early buys every 10-60 s (first 10 min) | median gap 20 s |
| PASS | no gap between buys over 300 s | longest 115 s at 14.6-16.5 min |
| WARN | last purchase leaves 10-25% of the game to enjoy it | not cleared |
| FAIL | every buy raises income at least 8% | net_hold +0.0%, lucky_haul +0.0%, double_cast +0.1%, net_range +1.7%, net_width +0.7%, net_width r2 +0.8% |
| PASS | no single pick wins by 3x in over 50% of choices | median best/second n/ax; over 3x in 0% |
| FAIL | payback within 4x of its phase median | double_cast too weak for price (29197 s vs 1220 s); cargo too strong for price (59 s vs 1220 s); fleet too strong for price (16 s vs 1220 s); boat_speed too strong for price (67 s vs 1220 s); dog_count too weak for price (19791209299968000 s vs 1220 s); boat_speed r2 too strong for price (184 s vs 1220 s) |
| FAIL | ferry capacity within 1-2.5x of catch rate | inside 39%, lagging 36%, overrunning 25%; box peaked at 293 |
| PASS | single upgrades are felt (no stage locked against another) | none |
| PASS | no bought node whose only value is what it unlocks | none |
| PASS | every node earns its purchase, none only in the last 15% | 0 bought only as filler (earned nothing); 0 never bought; 0 first bought late |

## Bot: focused

- Clear: not cleared
- Purchases: 35, spent 41.7k sludge
- Income/s at 2 / 10 / 30 min: 6.8 / 60.4 / 3.4
- Median payback by phase: 0m 1220s, 10m 4894s
- Median seconds from reveal to buy, by group: net_hold 20, lucky_haul 40, double_cast 60, net_range 80, cargo 100, fleet 115, boat_speed 125, net_width 135, dog_count 170, net_strength 375, recycle_bonus 555, bird_worth 575, dog_strength 605

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.3 | net_hold | 100 | +0% | never |
| 0.7 | lucky_haul | 100 | +0% | never |
| 1.0 | double_cast | 100 | +0% | 29197 s |
| 1.3 | net_range | 110 | +2% | 1237 s |
| 1.7 | cargo | 110 | +34% | 59 s |
| 1.9 | fleet | 110 | +97% | 16 s |
| 2.1 | boat_speed | 130 | +14% | 67 s |
| 2.3 | net_width | 140 | +1% | 1204 s |
| 2.5 | net_width r2 | 288 | +1% | 2115 s |
| 2.8 | dog_count | 300 | +0% | never |
| 3.2 | boat_speed r2 | 322 | +11% | 184 s |
| 3.5 | net_hold r2 | 350 | +0% | never |
| 3.8 | lucky_haul r2 | 350 | +0% | never |
| 4.1 | double_cast r2 | 350 | +0% | 28934 s |
| 4.4 | net_range r2 | 374 | +0% | 4114 s |
| 4.8 | cargo r2 | 374 | +25% | 82 s |
| 5.1 | fleet r2 | 385 | +39% | 43 s |
| 5.4 | net_width r3 | 594 | +15% | 137 s |
| 5.8 | boat_speed r3 | 800 | +0% | never |
| 6.3 | net_strength | 1100 | +107% | 44 s |
| 6.8 | net_width r4 | 1224 | +0% | 5185 s |
| 7.2 | net_hold r3 | 1225 | +0% | never |
| 7.6 | lucky_haul r3 | 1225 | +0% | never |
| 8.0 | double_cast r3 | 1225 | +0% | never |
| 8.4 | net_range r3 | 1272 | +0% | never |
| 8.8 | cargo r3 | 1272 | +19% | 136 s |
| 9.3 | recycle_bonus | 1300 | +6% | 369 s |
| 9.6 | bird_worth | 1300 | +1% | 4056 s |
| 10.1 | dog_strength | 1900 | +0% | never |
| 10.7 | boat_speed r4 | 1983 | +7% | 460 s |
| 11.3 | net_width r5 | 2521 | +0% | 8292 s |
| 12.4 | net_range r4 | 4323 | +1% | 11145 s |
| 13.5 | cargo r4 | 4323 | +16% | 435 s |
| 14.6 | boat_speed r5 | 4918 | +0% | never |
| 16.5 | net_width r6 | 5194 | +13% | 1496 s |
