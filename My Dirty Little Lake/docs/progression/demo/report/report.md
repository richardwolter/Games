# Progression sim: My Dirty Little Lake (demo)

## Checks

| | check | result |
|---|---|---|
| PASS | focused can always finish (no soft-lock) | finishes |
| PASS | early buys every 10-60 s (first 10 min) | median gap 25 s |
| PASS | no gap between buys over 300 s | longest 60 s at 14.0-15.0 min |
| WARN | last purchase leaves 10-25% of the game to enjoy it | not cleared |
| FAIL | every buy raises income at least 8% | net_hold +0.0%, lucky_haul +0.0%, double_cast +0.1%, net_range +1.7%, net_width +1.9%, net_width r2 +1.0% |
| PASS | no single pick wins by 3x in over 50% of choices | median best/second n/ax; over 3x in 0% |
| FAIL | payback within 4x of its phase median | lucky_haul too weak for price (71248353479884800 s vs 1616 s); double_cast too weak for price (26277 s vs 1616 s); boat_speed too strong for price (138 s vs 1616 s); fleet too strong for price (25 s vs 1616 s); boat_speed r2 too strong for price (143 s vs 1616 s); dog_count too weak for price (7916483719987200 s vs 1616 s) |
| FAIL | ferry capacity within 1-2.5x of catch rate | inside 16%, lagging 82%, overrunning 2%; box peaked at 1641 |
| PASS | single upgrades are felt (no stage locked against another) | none |
| PASS | no bought node whose only value is what it unlocks | none |
| PASS | every node earns its purchase, none only in the last 15% | 0 bought only as filler (earned nothing); 0 never bought; 0 first bought late |

## Bot: focused

- Clear: not cleared
- Purchases: 31, spent 15.4k sludge
- Income/s at 2 / 10 / 30 min: 5.8 / 21.8 / 23.7
- Median payback by phase: 0m 1616s, 10m 25565s
- Median seconds from reveal to buy, by group: net_hold 20, lucky_haul 35, double_cast 55, net_range 70, boat_speed 90, net_width 110, fleet 135, dog_count 180, net_strength 345, boat_volley 375, recycle_bonus 405, bird_worth 430, dog_strength 515

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.3 | net_hold | 90 | +0% | never |
| 0.6 | lucky_haul | 90 | +0% | never |
| 0.9 | double_cast | 90 | +0% | 26277 s |
| 1.2 | net_range | 95 | +2% | 1068 s |
| 1.5 | boat_speed | 100 | +13% | 138 s |
| 1.8 | net_width | 120 | +2% | 1032 s |
| 2.3 | fleet | 150 | +94% | 25 s |
| 2.5 | boat_speed r2 | 187 | +11% | 143 s |
| 2.8 | net_width r2 | 196 | +1% | 1434 s |
| 3.0 | dog_count | 200 | +0% | never |
| 3.3 | net_range r2 | 223 | +1% | 2514 s |
| 3.7 | net_hold r2 | 315 | +0% | never |
| 4.0 | lucky_haul r2 | 315 | +0% | never |
| 4.4 | double_cast r2 | 315 | +0% | 22143 s |
| 4.8 | net_width r3 | 319 | +1% | 1900 s |
| 5.3 | boat_speed r3 | 350 | +9% | 294 s |
| 5.8 | net_strength | 450 | +13% | 231 s |
| 6.3 | boat_volley | 500 | +1% | 5272 s |
| 6.8 | recycle_bonus | 500 | +6% | 460 s |
| 7.2 | bird_worth | 500 | +1% | 2150 s |
| 7.7 | net_width r4 | 520 | +1% | 1797 s |
| 8.1 | net_range r3 | 525 | +0% | 11158 s |
| 8.6 | dog_strength | 650 | +0% | never |
| 9.2 | boat_speed r4 | 654 | +7% | 449 s |
| 9.8 | net_width r5 | 847 | +1% | 3046 s |
| 10.6 | net_hold r3 | 1103 | +0% | never |
| 11.4 | lucky_haul r3 | 1103 | +0% | never |
| 12.3 | double_cast r3 | 1103 | +0% | 25565 s |
| 13.2 | boat_speed r5 | 1223 | +6% | 909 s |
| 14.0 | net_range r4 | 1233 | +0% | 28244 s |
| 15.0 | net_width r6 | 1381 | +1% | 4709 s |
