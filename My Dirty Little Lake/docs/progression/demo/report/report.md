# Progression sim: My Dirty Little Lake (demo)

## Checks

| | check | result |
|---|---|---|
| PASS | focused can always finish (no soft-lock) | finishes |
| PASS | early buys every 10-60 s (first 10 min) | median gap 15 s |
| PASS | no gap between buys over 300 s | longest 60 s at 14.1-15.1 min |
| WARN | last purchase leaves 10-25% of the game to enjoy it | not cleared |
| FAIL | every buy raises income at least 8% | recycle_bonus +6.1%, net_hold +0.0%, lucky_haul +0.0%, double_cast +0.1%, net_range +1.5%, net_width +1.7% |
| PASS | no single pick wins by 3x in over 50% of choices | median best/second n/ax; over 3x in 0% |
| FAIL | payback within 4x of its phase median | recycle_bonus too strong for price (231 s vs 1108 s); double_cast too weak for price (27737 s vs 1108 s); cargo too strong for price (48 s vs 1108 s); boat_speed too strong for price (116 s vs 1108 s); fleet too strong for price (19 s vs 1108 s); reel r2 too weak for price (5218 s vs 1108 s) |
| FAIL | ferry capacity within 1-2.5x of catch rate | inside 29%, lagging 66%, overrunning 5%; box peaked at 932 |
| PASS | single upgrades are felt (no stage locked against another) | none |
| PASS | no bought node whose only value is what it unlocks | none |
| PASS | every node earns its purchase, none only in the last 15% | 0 bought only as filler (earned nothing); 0 never bought; 0 first bought late |

## Bot: focused

- Clear: not cleared
- Purchases: 45, spent 35.4k sludge
- Income/s at 2 / 10 / 30 min: 6.9 / 37.8 / 7.7
- Median payback by phase: 0m 1108s, 10m 8513s
- Median seconds from reveal to buy, by group: recycle_bonus 15, net_hold 35, lucky_haul 50, double_cast 65, cargo 85, bird_worth 95, net_range 110, boat_speed 125, net_width 140, reel 155, fleet 175, dog_count 215, net_strength 420, dog_fetch 445, dog_wait 470, boat_volley 545, dog_strength 600

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.3 | recycle_bonus | 75 | +6% | 231 s |
| 0.6 | net_hold | 95 | +0% | never |
| 0.8 | lucky_haul | 95 | +0% | never |
| 1.1 | double_cast | 95 | +0% | 27737 s |
| 1.4 | cargo | 95 | +35% | 48 s |
| 1.6 | bird_worth | 95 | +1% | 1946 s |
| 1.8 | net_range | 110 | +1% | 951 s |
| 2.1 | boat_speed | 120 | +13% | 116 s |
| 2.3 | net_width | 130 | +2% | 860 s |
| 2.6 | reel | 130 | +0% | 2988 s |
| 2.9 | fleet | 160 | +94% | 19 s |
| 3.2 | net_width r2 | 244 | +1% | 1264 s |
| 3.4 | reel r2 | 244 | +0% | 5218 s |
| 3.6 | dog_count | 250 | +0% | never |
| 3.8 | recycle_bonus r2 | 263 | +6% | 261 s |
| 4.1 | boat_speed r2 | 268 | +10% | 135 s |
| 4.3 | net_range r2 | 326 | +1% | 2141 s |
| 4.7 | net_hold r2 | 333 | +0% | never |
| 4.9 | lucky_haul r2 | 333 | +0% | never |
| 5.2 | double_cast r2 | 333 | +0% | 15165 s |
| 5.4 | cargo r2 | 333 | +25% | 65 s |
| 5.7 | bird_worth r2 | 333 | +1% | 1539 s |
| 5.9 | net_width r3 | 460 | +1% | 1443 s |
| 6.3 | reel r3 | 460 | +0% | 5479 s |
| 6.6 | boat_speed r3 | 597 | +8% | 269 s |
| 7.0 | net_strength | 700 | +18% | 131 s |
| 7.4 | dog_fetch | 850 | +0% | never |
| 7.8 | dog_wait | 850 | +0% | never |
| 8.3 | net_width r4 | 864 | +1% | 1794 s |
| 8.7 | reel r4 | 864 | +0% | 8362 s |
| 9.1 | boat_volley | 900 | +1% | 2653 s |
| 9.5 | net_range r3 | 964 | +0% | never |
| 10.0 | dog_strength | 1100 | +0% | never |
| 10.5 | net_hold r3 | 1164 | +0% | never |
| 11.0 | lucky_haul r3 | 1164 | +0% | never |
| 11.5 | double_cast r3 | 1164 | +0% | 19506 s |
| 12.0 | cargo r3 | 1164 | +19% | 164 s |
| 12.5 | bird_worth r3 | 1164 | +1% | 2701 s |
| 12.9 | boat_speed r4 | 1331 | +7% | 428 s |
| 13.5 | net_width r5 | 1624 | +1% | 2972 s |
| 14.1 | reel r5 | 1624 | +0% | 12053 s |
| 15.1 | net_range r4 | 2853 | +0% | never |
| 16.1 | boat_speed r5 | 2968 | +6% | 1063 s |
| 17.1 | net_width r6 | 3053 | +1% | 4972 s |
| 18.0 | reel r6 | 3053 | +0% | 19365 s |
