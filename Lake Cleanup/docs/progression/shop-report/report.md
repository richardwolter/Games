# Progression sim: Lake Cleanup (shop, 2026-09-14 pass)

## Checks

| | check | result |
|---|---|---|
| PASS | focused clears in 62-78 min | 62.0 min (cleared 99.5%) |
| FAIL | casual clears in 110-160 min | 80.2 min (cleared 99.5%) |
| PASS | focused can always finish (no soft-lock) | finishes |
| PASS | casual can always finish (no soft-lock) | finishes |
| PASS | cheapest can always finish (no soft-lock) | finishes |
| PASS | early buys every 10-60 s (first 10 min) | median gap 10 s |
| PASS | no gap between buys over 300 s | longest 120 s at 19.3-21.3 min |
| WARN | last purchase leaves 10-25% of the game to enjoy it | last buy at 60.6 min, 2% of the game after it |
| FAIL | every buy raises income at least 8% | recycle_bonus +6.2%, net_width +2.8%, net_range +1.4%, reel +0.6%, net_width r2 +0.6%, cargo r10 +7.4% |
| PASS | no single pick wins by 3x in over 50% of choices | median best/second 1.24x; over 3x in 3%; "fleet" top pick 25% |
| FAIL | payback within 4x of its phase median | cargo too strong for price (24 s vs 123 s); dog_count too strong for price (32 s vs 281 s); dog_fetch too strong for price (14 s vs 281 s); net_range r2 too strong for price (5 s vs 281 s); cargo r19 too weak for price (1153 s vs 281 s); boat_speed r15 too weak for price (1174 s vs 281 s) |
| FAIL | ferry capacity within 0.8-1.5x of catch rate | inside 28%, lagging 43%, overrunning 29%; box peaked at 1968 |
| FAIL | single upgrades are felt (no stage locked against another) | 12 buys only paid off with another: net_hold+double_cast @12.3, lucky_haul+net_hold @13.1, net_hold+reel @13.1, net_hold+reel @13.1, net_range+net_hold @13.6 |
| PASS | no bought node whose only value is what it unlocks | none |
| FAIL | every node earns its purchase, none only in the last 15% | 16 bought only as filler (earned nothing); 0 never bought; 0 first bought late |

## Bot: focused

- Clear: 62.0 min
- Purchases: 140, spent 209.2k sludge
- Income/s at 2 / 10 / 30 min: 3.5 / 101.1 / 279.8
- Median payback by phase: 0m 123s, 10m 281s, 20m 1172s, 30m 241s, 40m 493s, 50m 881s
- Median seconds from reveal to buy, by group: cargo 10, fleet 115, boat_speed 150, bird_worth 195, recycle_bonus 225, net_strength 240, net_width 240, net_range 245, reel 245, net_hold 395, double_cast 505, dog_count 690, dog_wait 690, dog_fetch 695, lucky_haul 785

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.2 | cargo | 8 | +23% | 24 s |
| 0.3 | cargo r2 | 12 | +19% | 35 s |
| 0.4 | cargo r3 | 18 | +16% | 53 s |
| 0.6 | cargo r4 | 27 | +14% | 80 s |
| 0.8 | cargo r5 | 41 | +12% | 120 s |
| 1.9 | fleet | 200 | +97% | 65 s |
| 2.1 | cargo r6 | 61 | +11% | 90 s |
| 2.5 | boat_speed | 160 | +32% | 73 s |
| 2.7 | cargo r7 | 91 | +10% | 103 s |
| 2.9 | cargo r8 | 137 | +9% | 155 s |
| 3.3 | bird_worth | 250 | from zero | never |
| 3.6 | boat_speed r2 | 211 | +21% | 91 s |
| 3.8 | recycle_bonus | 120 | +6% | 147 s |
| 4.0 | net_strength | 200 | +12% | 116 s |
| 4.0 | net_width | 25 | +3% | 57 s |
| 4.1 | net_range | 20 | +1% | 85 s |
| 4.1 | reel | 14 | +1% | 136 s |
| 4.3 | cargo r9 | 205 | +8% | 149 s |
| 4.6 | boat_speed r3 | 279 | +16% | 95 s |
| 4.9 | boat_speed r4 | 368 | +12% | 137 s |
| 5.3 | bird_worth r2 | 565 | from zero | never |
| 5.9 | fleet r2 | 1000 | +49% | 81 s |
| 6.0 | net_width r2 | 35 | +1% | 162 s |
| 6.1 | cargo r10 | 308 | +7% | 110 s |
| 6.3 | recycle_bonus r2 | 289 | +6% | 123 s |
| 6.4 | boat_speed r5 | 486 | +10% | 114 s |
| 6.6 | net_strength r2 | 500 | +9% | 123 s |
| 6.6 | net_hold | 8 | +0% | 38 s |
| 6.6 | reel r2 | 21 | +0% | 114 s |
| 6.7 | net_width r3 | 49 | +1% | 95 s |
| 6.7 | net_hold r2 | 12 | +0% | 67 s |
| 6.7 | net_width r4 | 69 | +1% | 162 s |
| 6.7 | net_hold r3 | 18 | +0% | 96 s |
| 6.8 | cargo r11 | 461 | +7% | 124 s |
| 7.0 | boat_speed r6 | 641 | +8% | 134 s |
| 7.0 | reel r3 | 32 | +0% | 272 s |
| 7.1 | net_width r5 | 96 | +1% | 206 s |
| 7.3 | cargo r12 | 692 | +6% | 169 s |
| 7.4 | recycle_bonus r3 | 697 | +5% | 184 s |
| 7.7 | boat_speed r7 | 846 | +7% | 167 s |
| 7.8 | cargo r13 | 1038 | +6% | 223 s |
| 8.1 | bird_worth r3 | 1277 | from zero | never |
| 8.3 | net_strength r3 | 1250 | +7% | 213 s |
| 8.4 | net_width r6 | 135 | +1% | 157 s |
| 8.4 | double_cast | 16 | +0% | 154 s |
| 8.4 | net_width r7 | 188 | +1% | 245 s |
| 8.4 | reel r4 | 49 | +0% | 271 s |
| 8.7 | boat_speed r8 | 1117 | +6% | 202 s |
| 9.2 | bird_worth r4 | 2886 | from zero | never |
| 10.0 | fleet r3 | 5000 | +33% | 148 s |
| 10.2 | cargo r14 | 1557 | +6% | 205 s |
| 10.3 | boat_speed r9 | 1475 | +5% | 199 s |
| 10.6 | recycle_bonus r4 | 1680 | +5% | 211 s |
| 10.9 | net_strength r4 | 3125 | +18% | 106 s |
| 10.9 | double_cast r2 | 37 | +0% | 109 s |
| 10.9 | net_width r8 | 264 | +1% | 123 s |
| 10.9 | net_width r9 | 369 | +1% | 188 s |
| 11.0 | reel r5 | 75 | +0% | 215 s |
| 11.0 | double_cast r3 | 84 | +0% | 253 s |
| 11.0 | net_width r10 | 517 | +1% | 310 s |
| 11.2 | boat_speed r10 | 1947 | +5% | 205 s |
| 11.4 | cargo r15 | 2335 | +5% | 196 s |
| 11.5 | dog_count | 45 | +1% | 32 s |
| 11.5 | dog_count r2 | 113 | +1% | 79 s |
| 11.5 | dog_wait | 45 | +0% | 165 s |
| 11.6 | dog_fetch | 65 | +2% | 14 s |
| 11.7 | dog_wait r2 | 113 | +1% | 82 s |
| 11.7 | dog_count r3 | 281 | +1% | 101 s |
| 11.7 | net_width r11 | 723 | +1% | 623 s |
| 11.8 | dog_fetch r2 | 163 | +1% | 111 s |
| 11.8 | dog_wait r3 | 281 | +1% | 214 s |
| 11.8 | reel r6 | 114 | +0% | 361 s |
| 11.8 | recycle_bonus r5 | 4048 | +5% | 406 s |
| 11.9 | net_range r2 | 28 | +3% | 5 s |
| 12.1 | boat_speed r11 | 2570 | +4% | 327 s |
| 12.3 | cargo r16 | 3503 | +5% | 355 s |
| 12.3 | net_hold r4 (with double_cast) | 27 | +0% | 119 s |
| 12.6 | boat_speed r12 | 3392 | +3% | 461 s |
| 12.9 | cargo r17 | 5255 | +4% | 542 s |
| 13.1 | net_range r3 | 40 | +0% | 80 s |
| 13.1 | lucky_haul (with net_hold) | 16 | +0% | 69 s |
| 13.1 | net_hold r5 (with reel) | 41 | +0% | 108 s |
| 13.1 | net_hold r6 (with reel) | 61 | +0% | 206 s |
| 13.3 | boat_speed r13 | 4477 | +3% | 646 s |
| 13.6 | net_range r4 (with net_hold) | 57 | +0% | 159 s |
| 13.6 | net_hold r7 | 91 | +0% | 389 s |
| 13.6 | net_hold r8 (with reel) | 137 | +0% | 325 s |
| 13.8 | bird_worth r5 | 6522 | from zero | never |
| 13.8 | reel r7 | 173 | +0% | 735 s |
| 13.8 | double_cast r4 | 192 | +0% | 785 s |
| 14.1 | net_range r5 (with net_hold) | 81 | +0% | 246 s |
| 14.1 | reel r8 | 262 | +0% | 1099 s |
| 14.1 | net_range r6 (with net_hold) | 116 | +0% | 340 s |
| 14.3 | boat_speed r14 | 5910 | +3% | 931 s |
| 14.8 | cargo r18 | 7882 | +4% | 795 s |
| 15.5 | recycle_bonus r6 | 9756 | +5% | 876 s |
| 15.5 | lucky_haul r2 (with net_hold) | 37 | +0% | 144 s |
| 15.5 | net_range r7 (with net_hold) | 164 | +0% | 442 s |
| 15.5 | net_hold r9 (with net_range) | 205 | +0% | 537 s |
| 16.3 | cargo r19 | 11.8k | +4% | 1153 s |
| 16.8 | boat_speed r15 | 7801 | +3% | 1174 s |
| 17.7 | bird_worth r6 | 14.7k | from zero | never |
| 17.7 | net_range r8 (with double_cast) | 233 | +0% | 409 s |
| 17.8 | net_width r12 | 1012 | +0% | 1198 s |
| 17.8 | double_cast r5 | 440 | +0% | 1172 s |
| 17.8 | reel r9 | 399 | +0% | 1180 s |
| 19.3 | net_range r9 | 331 | +0% | 1182 s |
| 21.3 | lucky_haul r3 | 84 | +0% | 9526 s | filler
| 21.6 | net_range r10 | 470 | +0% | 1176 s |
| 23.6 | lucky_haul r4 | 192 | +0% | never | filler
| 24.3 | net_range r11 | 667 | +0% | 1168 s |
| 26.3 | net_hold r10 | 308 | +0% | never | filler
| 28.3 | dog_fetch r3 | 406 | +0% | never | filler
| 30.3 | lucky_haul r5 | 440 | +0% | never | filler
| 30.4 | net_range r12 | 947 | +0% | 1189 s |
| 32.4 | net_hold r11 | 461 | +0% | never | filler
| 34.4 | reel r10 | 606 | +0% | 1901 s | filler
| 35.2 | net_range r13 | 1344 | +2% | 218 s |
| 37.2 | net_hold r12 | 692 | +0% | never | filler
| 37.6 | net_width r13 | 1417 | +2% | 265 s |
| 37.7 | net_range r14 | 1909 | +4% | 160 s |
| 39.7 | reel r11 | 922 | +0% | 3364 s | filler
| 40.4 | net_width r14 | 1984 | +2% | 369 s |
| 40.5 | net_range r15 | 2711 | +4% | 228 s |
| 42.5 | double_cast r6 | 1008 | +0% | 3084 s | filler
| 43.4 | net_width r15 | 2778 | +2% | 606 s |
| 43.5 | net_range r16 | 3849 | +4% | 341 s |
| 45.5 | lucky_haul r6 | 1008 | +0% | never | filler
| 46.6 | net_range r17 | 5466 | +4% | 493 s |
| 48.6 | dog_fetch r4 | 1016 | +0% | never | filler
| 49.7 | reel r12 | 1401 | +0% | 1167 s |
| 49.8 | net_range r18 | 7761 | +4% | 711 s |
| 51.8 | net_hold r13 | 1038 | +0% | never | filler
| 53.0 | net_width r16 | 3889 | +2% | 923 s |
| 53.0 | double_cast r7 | 2308 | +1% | 1006 s |
| 53.1 | net_range r19 | 11.0k | +5% | 839 s |
| 55.1 | net_hold r14 | 1557 | +0% | never | filler
| 56.6 | net_range r20 | 15.6k | +8% | 814 s |
| 58.6 | reel r13 | 2129 | +0% | never | filler
| 60.6 | lucky_haul r7 | 2308 | +0% | never | filler

## Bot: casual

- Clear: 80.2 min (seeds: 75, 80, 81)
- Purchases: 167, spent 676.0k sludge
- Income/s at 2 / 10 / 30 min: 3.2 / 6.4 / 216.0
- Median payback by phase: 0m 105s, 10m 244s, 20m 1126s, 30m 1795s, 40m 705s, 50m 531s, 60m 526s, 70m 7547s
- Median seconds from reveal to buy, by group: cargo 20, lucky_haul 60, net_width 80, dog_wait 140, bird_worth 160, dog_count 200, fleet 240, boat_speed 280, recycle_bonus 360, net_strength 380, net_range 380, reel 380, net_hold 380, double_cast 720, dog_fetch 980

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.3 | cargo | 8 | +23% | 24 s |
| 0.3 | cargo r2 | 12 | +19% | 35 s |
| 0.7 | cargo r3 | 18 | +16% | 53 s |
| 0.7 | cargo r4 | 27 | +14% | 80 s |
| 1.0 | cargo r5 | 41 | +12% | 120 s |
| 1.0 | lucky_haul * | 16 | +0% | never |
| 1.3 | net_width * | 25 | +1% | 549 s |
| 2.3 | dog_wait * | 45 | +0% | never |
| 2.7 | bird_worth | 250 | from zero | never |
| 3.3 | dog_count * | 45 | +0% | never |
| 4.0 | fleet | 200 | +95% | 65 s |
| 4.3 | cargo r6 | 61 | +11% | 90 s |
| 4.7 | boat_speed | 160 | +31% | 73 s |
| 5.0 | cargo r7 | 91 | +10% | 103 s |
| 5.0 | cargo r8 | 137 | +9% | 155 s |
| 5.3 | boat_speed r2 | 211 | +21% | 91 s |
| 5.7 | boat_speed r3 | 279 | +16% | 133 s |
| 6.0 | recycle_bonus | 120 | +6% | 127 s |
| 6.3 | net_strength | 200 | +10% | 123 s |
| 6.3 | net_range | 20 | +2% | 61 s |
| 6.3 | net_width r2 * | 35 | +2% | 105 s |
| 6.3 | reel | 14 | +1% | 95 s |
| 6.3 | net_hold | 8 | +0% | 132 s |
| 6.3 | cargo r9 | 205 | +8% | 136 s |
| 6.7 | boat_speed r4 | 368 | +12% | 146 s |
| 7.0 | net_width r3 | 49 | +1% | 142 s |
| 7.0 | dog_count r2 * | 113 | +0% | never |
| 7.0 | net_hold r2 | 12 | +0% | 139 s |
| 7.3 | bird_worth r2 | 565 | from zero | never |
| 8.0 | dog_count r3 * | 281 | +0% | never |
| 8.3 | net_hold r3 * | 18 | +0% | never |
| 8.3 | cargo r10 * | 308 | +7% | 167 s |
| 8.7 | fleet r2 | 1000 | +50% | 74 s |
| 9.0 | net_strength r2 | 500 | +16% | 74 s |
| 9.0 | lucky_haul r2 * | 37 | +0% | 4437 s |
| 9.7 | recycle_bonus r2 | 289 | +6% | 101 s |
| 10.3 | boat_speed r5 | 486 | +10% | 94 s |
| 10.3 | net_width r4 * | 69 | +0% | 245 s |
| 10.3 | cargo r11 | 461 | +7% | 117 s |
| 10.3 | reel r2 | 21 | +0% | 178 s |
| 10.7 | bird_worth r3 | 1277 | from zero | never |
| 10.7 | lucky_haul r3 * | 84 | +0% | 10375 s |
| 11.0 | boat_speed r6 | 641 | +8% | 127 s |
| 11.3 | cargo r12 | 692 | +6% | 163 s |
| 11.3 | boat_speed r7 | 846 | +7% | 172 s |
| 11.3 | net_width r5 | 96 | +0% | 270 s |
| 11.7 | boat_speed r8 * | 1117 | +6% | 248 s |
| 11.7 | recycle_bonus r3 | 697 | +5% | 157 s |
| 12.0 | net_strength r3 | 1250 | +8% | 189 s |
| 12.0 | reel r3 | 32 | +0% | 151 s |
| 12.0 | double_cast | 16 | +0% | 168 s |
| 12.0 | net_width r6 | 135 | +1% | 200 s |
| 12.0 | lucky_haul r4 * | 192 | +0% | 3474 s |
| 12.0 | net_hold r4 | 27 | +0% | 194 s |
| 12.3 | cargo r13 | 1038 | +6% | 186 s |
| 13.0 | bird_worth r4 | 2886 | from zero | never |
| 13.7 | fleet r3 | 5000 | +33% | 149 s |
| 13.7 | net_width r7 | 188 | +0% | 341 s |
| 13.7 | net_range r2 * | 28 | +0% | never |
| 14.0 | cargo r14 | 1557 | +5% | 215 s |
| 14.0 | boat_speed r9 | 1475 | +5% | 209 s |
| 14.3 | net_strength r4 | 3125 | +11% | 196 s |
| 14.3 | reel r4 * | 49 | +0% | 120 s |
| 14.3 | net_hold r5 | 41 | +0% | 85 s |
| 14.3 | double_cast r2 | 37 | +0% | 161 s |
| 14.3 | net_hold r6 | 61 | +0% | 215 s |
| 14.3 | reel r5 | 75 | +0% | 243 s |
| 14.7 | dog_wait r2 * | 113 | +0% | never |
| 14.7 | recycle_bonus r4 | 1680 | +5% | 195 s |
| 14.7 | net_width r8 | 264 | +1% | 239 s |
| 14.7 | double_cast r3 | 84 | +0% | 395 s |
| 14.7 | net_width r9 | 369 | +1% | 393 s |
| 15.0 | boat_speed r10 | 1947 | +4% | 242 s |
| 15.3 | cargo r15 | 2335 | +5% | 239 s |
| 15.3 | boat_speed r11 | 2570 | +4% | 327 s |
| 15.7 | cargo r16 | 3503 | +5% | 347 s |
| 16.0 | reel r6 * | 114 | +0% | 799 s |
| 16.0 | recycle_bonus r5 | 4048 | +5% | 378 s |
| 16.3 | dog_fetch * | 65 | +0% | never |
| 16.3 | boat_speed r12 | 3392 | +3% | 435 s |
| 16.3 | net_width r10 | 517 | +0% | 614 s |
| 16.7 | bird_worth r5 | 6522 | from zero | never |
| 17.0 | net_width r11 | 723 | +1% | 607 s |
| 17.0 | double_cast r4 | 192 | +0% | 662 s |
| 17.3 | net_range r3 | 40 | +12% | 2 s |
| 17.3 | net_hold r7 | 91 | +0% | 374 s |
| 17.3 | boat_speed r13 * | 4477 | +3% | 657 s |
| 17.7 | double_cast r5 * | 440 | +0% | 1398 s |
| 17.7 | cargo r17 | 5255 | +5% | 520 s |
| 17.7 | dog_wait r3 * | 281 | +0% | never |
| 17.7 | net_hold r8 | 137 | +0% | 479 s |
| 17.7 | reel r7 | 173 | +0% | 636 s |
| 17.7 | net_width r12 | 1012 | +0% | 1190 s |
| 17.7 | reel r8 | 262 | +0% | 1103 s |
| 18.0 | net_hold r9 | 205 | +0% | 805 s |
| 18.0 | lucky_haul r5 * | 440 | +0% | 18137 s |
| 19.7 | boat_speed r14 | 5910 | +3% | 904 s |
| 20.3 | net_range r4 * | 57 | +0% | never |
| 20.3 | net_hold r10 | 308 | +0% | 869 s |
| 20.7 | cargo r18 | 7882 | +4% | 779 s |
| 21.0 | double_cast r6 * | 1008 | +0% | 3128 s |
| 21.3 | net_range r5 | 81 | +0% | 130 s |
| 21.3 | recycle_bonus r6 | 9756 | +5% | 859 s |
| 22.0 | net_range r6 (with reel) | 116 | +0% | 248 s |
| 22.0 | dog_fetch r2 * | 163 | +0% | never |
| 22.3 | bird_worth r6 | 14.7k | from zero | never |
| 23.0 | net_range r7 | 164 | +0% | 628 s |
| 23.3 | cargo r19 | 11.8k | +4% | 1146 s |
| 23.3 | lucky_haul r6 * | 1008 | +0% | never |
| 23.7 | boat_speed r15 | 7801 | +3% | 1166 s |
| 24.3 | net_range r8 | 233 | +0% | 816 s |
| 24.7 | net_hold r11 * | 461 | +0% | 4458 s |
| 25.7 | net_range r9 | 331 | +0% | 1105 s |
| 27.7 | reel r9 | 399 | +0% | 1314 s | filler
| 28.7 | recycle_bonus r7 * | 23.5k | +4% | 1925 s |
| 29.7 | boat_speed r16 * | 10.3k | +2% | 1525 s |
| 31.3 | bird_worth r7 * | 33.3k | +0% | 30535 s |
| 33.0 | net_range r10 | 470 | +14% | 13 s |
| 35.0 | net_range r11 * | 667 | +0% | 2288 s |
| 35.3 | lucky_haul r7 * | 2308 | +0% | never |
| 37.0 | net_range r12 | 947 | +4% | 82 s |
| 37.0 | boat_speed r17 * | 13.6k | +2% | 2146 s |
| 39.0 | recycle_bonus r8 * | 56.7k | +4% | 4400 s |
| 39.3 | net_hold r12 * | 692 | +0% | never |
| 39.3 | cargo r20 * | 17.7k | +4% | 1444 s |
| 40.0 | lucky_haul r8 * | 5284 | +0% | never |
| 41.7 | lucky_haul r9 * | 12.1k | +0% | never |
| 42.3 | net_range r13 | 1344 | +8% | 53 s |
| 43.0 | boat_speed r18 * | 17.9k | +2% | 2786 s |
| 43.7 | net_hold r13 * | 1038 | +0% | never |
| 44.7 | reel r10 | 606 | +0% | 705 s |
| 44.7 | net_width r13 * | 1417 | +0% | 1524 s |
| 45.0 | net_hold r14 * | 1557 | +0% | never |
| 45.0 | bird_worth r8 * | 75.3k | +0% | never |
| 45.0 | net_range r14 | 1909 | +11% | 55 s |
| 47.0 | net_range r15 | 2711 | +12% | 73 s |
| 47.7 | double_cast r7 * | 2308 | +0% | 5545 s |
| 48.0 | lucky_haul r10 * | 27.7k | +0% | never |
| 48.3 | net_hold r15 * | 2335 | +0% | never |
| 49.7 | dog_fetch r3 * | 406 | +0% | never |
| 51.7 | reel r11 | 922 | +0% | 3068 s | filler
| 53.3 | boat_speed r19 * | 23.7k | +0% | never |
| 53.3 | reel r12 * | 1401 | +1% | 531 s |
| 53.3 | net_range r16 | 3849 | +16% | 79 s |
| 55.3 | boat_speed r20 * | 31.3k | +2% | 5457 s |
| 56.0 | double_cast r8 * | 5284 | +1% | 1423 s |
| 56.0 | net_range r17 | 5466 | +13% | 138 s |
| 58.0 | dog_fetch r4 * | 1016 | +0% | never |
| 60.0 | net_width r14 | 1984 | +0% | 2888 s | filler
| 61.7 | net_width r15 | 2778 | +3% | 259 s |
| 61.7 | net_width r16 | 3889 | +3% | 373 s |
| 62.0 | reel r13 * | 2129 | +1% | 679 s |
| 62.0 | net_range r18 | 7761 | +13% | 191 s |
| 62.3 | net_width r17 * | 5445 | +0% | 9672 s |
| 64.3 | reel r14 | 3237 | +0% | 23043 s | filler
| 65.3 | net_range r19 | 11.0k | +24% | 166 s |
| 67.0 | net_width r18 * | 7623 | +0% | 27178 s |
| 67.3 | net_hold r16 * | 3503 | +0% | never |
| 69.0 | double_cast r9 * | 12.1k | +0% | never |
| 70.7 | net_range r20 * | 15.6k | +5% | 880 s |
| 72.7 | reel r15 | 4920 | +0% | never | filler
| 74.7 | net_hold r17 | 5255 | +0% | never | filler
| 75.0 | net_width r19 * | 10.7k | +4% | 4832 s |
| 75.7 | net_width r20 * | 14.9k | +3% | 10263 s |
| 77.7 | double_cast r10 * | 27.7k | +2% | 34060 s |
| 78.0 | net_hold r18 * | 7882 | +0% | never |
| 80.0 | reel r16 | 7478 | +1% | 19437 s | filler

## Bot: cheapest

- Clear: 55.1 min
- Purchases: 162, spent 417.1k sludge
- Income/s at 2 / 10 / 30 min: 2.6 / 5.1 / 121.9
- Median payback by phase: 0m 523s, 10m 901s, 20m 1490s, 30m 887s, 40m 1917s, 50m 86495s
- Median seconds from reveal to buy, by group: net_hold 10, cargo 15, reel 35, lucky_haul 40, double_cast 50, net_range 75, net_width 95, dog_wait 220, dog_count 230, dog_fetch 325, recycle_bonus 590, boat_speed 695, net_strength 865, fleet 890, bird_worth 960

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.2 | net_hold | 8 | +0% | never |
| 0.3 | cargo | 8 | +23% | 24 s |
| 0.3 | net_hold r2 | 12 | +0% | never |
| 0.5 | cargo r2 | 12 | +19% | 35 s |
| 0.6 | reel | 14 | +0% | 1714 s |
| 0.7 | lucky_haul | 16 | +0% | never |
| 0.8 | double_cast | 16 | +0% | 7197 s |
| 1.0 | net_hold r3 | 18 | +0% | never |
| 1.1 | cargo r3 | 18 | +16% | 53 s |
| 1.3 | net_range | 20 | +2% | 356 s |
| 1.4 | reel r2 | 21 | +0% | 1913 s |
| 1.6 | net_width | 25 | +3% | 339 s |
| 1.8 | net_hold r4 | 27 | +0% | never |
| 1.9 | cargo r4 | 27 | +13% | 80 s |
| 2.1 | net_range r2 | 28 | +2% | 450 s |
| 2.3 | reel r3 | 32 | +1% | 1829 s |
| 2.4 | net_width r2 | 35 | +3% | 345 s |
| 2.7 | lucky_haul r2 | 37 | +0% | never |
| 2.8 | double_cast r2 | 37 | +0% | 3555 s |
| 3.0 | net_range r3 | 40 | +2% | 565 s |
| 3.3 | net_hold r5 | 41 | +0% | never |
| 3.4 | cargo r5 | 41 | +10% | 120 s |
| 3.7 | dog_wait | 45 | +0% | never |
| 3.8 | dog_count | 45 | +0% | never |
| 4.1 | net_width r3 | 49 | +4% | 391 s |
| 4.3 | reel r4 | 49 | +1% | 1600 s |
| 4.6 | net_range r4 | 57 | +2% | 739 s |
| 4.8 | net_hold r6 | 61 | +0% | never |
| 5.1 | cargo r6 | 61 | +9% | 181 s |
| 5.4 | dog_fetch | 65 | +0% | never |
| 5.7 | net_width r4 | 69 | +4% | 454 s |
| 5.9 | reel r5 | 75 | +1% | 1994 s |
| 6.3 | net_range r5 | 81 | +2% | 975 s |
| 6.6 | lucky_haul r3 | 84 | +0% | never |
| 6.9 | double_cast r3 | 84 | +1% | 3140 s |
| 7.3 | net_hold r7 | 91 | +0% | never |
| 7.6 | cargo r7 | 91 | +8% | 272 s |
| 7.9 | net_width r5 | 96 | +4% | 530 s |
| 8.3 | dog_wait r2 | 113 | +0% | never |
| 8.7 | dog_count r2 | 113 | +0% | never |
| 9.1 | reel r6 | 114 | +1% | 2525 s |
| 9.4 | net_range r6 | 116 | +2% | 1268 s |
| 9.8 | recycle_bonus | 120 | +5% | 515 s |
| 10.3 | net_width r6 | 135 | +4% | 652 s |
| 10.7 | net_hold r8 | 137 | +0% | never |
| 11.1 | cargo r8 | 137 | +6% | 384 s |
| 11.6 | boat_speed | 160 | +24% | 116 s |
| 11.9 | dog_fetch r2 | 163 | +0% | never |
| 12.3 | net_range r7 | 164 | +1% | 1829 s |
| 12.7 | reel r7 | 173 | +1% | 2993 s |
| 13.1 | net_width r7 | 188 | +3% | 815 s |
| 13.6 | lucky_haul r4 | 192 | +0% | never |
| 14.0 | double_cast r4 | 192 | +1% | 3477 s |
| 14.4 | net_strength | 200 | +6% | 404 s |
| 14.8 | fleet | 200 | +76% | 31 s |
| 15.1 | net_hold r9 | 205 | +0% | 18863 s |
| 15.3 | cargo r9 | 205 | +7% | 189 s |
| 15.6 | boat_speed r2 | 211 | +19% | 68 s |
| 15.8 | net_range r8 | 233 | +0% | 4164 s |
| 16.0 | bird_worth | 250 | +3% | 397 s |
| 16.2 | reel r8 | 262 | +0% | 2764 s |
| 16.4 | net_width r8 | 264 | +2% | 716 s |
| 16.7 | boat_speed r3 | 279 | +14% | 96 s |
| 16.8 | dog_wait r3 | 281 | +0% | never |
| 17.1 | dog_count r3 | 281 | +0% | never |
| 17.3 | recycle_bonus r2 | 289 | +5% | 232 s |
| 17.4 | net_hold r10 | 308 | +0% | never |
| 17.7 | cargo r10 | 308 | +7% | 182 s |
| 17.8 | net_range r9 | 331 | +0% | 3051 s |
| 18.1 | boat_speed r4 | 368 | +11% | 122 s |
| 18.3 | net_width r9 | 369 | +1% | 987 s |
| 18.5 | reel r9 | 399 | +0% | 3775 s |
| 18.8 | dog_fetch r3 | 406 | +0% | never |
| 18.9 | lucky_haul r5 | 440 | +0% | never |
| 19.2 | double_cast r5 | 440 | +0% | 3798 s |
| 19.4 | net_hold r11 | 461 | +0% | never |
| 19.7 | cargo r11 | 461 | +6% | 242 s |
| 19.9 | net_range r10 | 470 | +0% | 3662 s |
| 20.2 | boat_speed r5 | 486 | +9% | 165 s |
| 20.4 | net_strength r2 | 500 | +4% | 347 s |
| 20.7 | net_width r10 | 517 | +1% | 1276 s |
| 20.9 | bird_worth r2 | 565 | +3% | 555 s |
| 21.2 | reel r10 | 606 | +0% | 3677 s |
| 21.4 | boat_speed r6 | 641 | +7% | 218 s |
| 21.7 | net_range r11 | 667 | +0% | never |
| 21.9 | net_hold r12 | 692 | +0% | 14464 s |
| 22.2 | cargo r12 | 692 | +6% | 276 s |
| 22.4 | recycle_bonus r3 | 697 | +5% | 300 s |
| 22.7 | net_width r11 | 723 | +1% | 1316 s |
| 23.0 | boat_speed r7 | 846 | +6% | 272 s |
| 23.3 | reel r11 | 922 | +0% | 5842 s |
| 23.6 | net_range r12 | 947 | +0% | 15650 s |
| 23.8 | fleet r2 | 1000 | +44% | 41 s |
| 24.1 | lucky_haul r6 | 1008 | +0% | never |
| 24.3 | double_cast r6 | 1008 | +0% | 4470 s |
| 24.5 | net_width r12 | 1012 | +1% | 1664 s |
| 24.8 | dog_fetch r4 | 1016 | +0% | never |
| 24.9 | net_hold r13 | 1038 | +0% | never |
| 25.2 | cargo r13 | 1038 | +5% | 237 s |
| 25.4 | boat_speed r8 | 1117 | +5% | 241 s |
| 25.6 | net_strength r3 | 1250 | +3% | 416 s |
| 25.8 | bird_worth r3 | 1277 | +1% | 918 s |
| 26.1 | net_range r13 | 1344 | +0% | never |
| 26.3 | reel r12 | 1401 | +0% | 5918 s |
| 26.6 | net_width r13 | 1417 | +1% | 1892 s |
| 26.8 | boat_speed r9 | 1475 | +5% | 323 s |
| 27.1 | net_hold r14 | 1557 | +0% | 24370 s |
| 27.3 | cargo r14 | 1557 | +5% | 297 s |
| 27.6 | recycle_bonus r4 | 1680 | +5% | 320 s |
| 27.9 | net_range r14 | 1909 | +0% | never |
| 28.2 | boat_speed r10 | 1947 | +4% | 407 s |
| 28.5 | net_width r14 | 1984 | +1% | 2601 s |
| 28.8 | reel r13 | 2129 | +0% | 9613 s |
| 29.1 | lucky_haul r7 | 2308 | +0% | never |
| 29.4 | double_cast r7 | 2308 | +0% | 6475 s |
| 29.8 | net_hold r15 | 2335 | +0% | never |
| 30.0 | cargo r15 | 2335 | +5% | 399 s |
| 30.3 | boat_speed r11 | 2570 | +4% | 544 s |
| 30.7 | net_range r15 | 2711 | +0% | never |
| 31.1 | net_width r15 | 2778 | +1% | 4008 s |
| 31.4 | bird_worth r4 | 2886 | +1% | 1756 s |
| 31.8 | net_strength r4 | 3125 | +4% | 640 s |
| 32.2 | reel r14 | 3237 | +0% | 11771 s |
| 32.6 | boat_speed r12 | 3392 | +3% | 715 s |
| 33.0 | net_hold r16 | 3503 | +0% | never |
| 33.4 | cargo r16 | 3503 | +5% | 505 s |
| 33.8 | net_range r16 | 3849 | +0% | never |
| 34.3 | net_width r16 | 3889 | +0% | 6032 s |
| 34.7 | recycle_bonus r5 | 4048 | +5% | 540 s |
| 35.1 | boat_speed r13 | 4477 | +3% | 883 s |
| 35.6 | reel r15 | 4920 | +0% | 30646 s |
| 36.1 | fleet r3 | 5000 | +32% | 91 s |
| 36.5 | net_hold r17 | 5255 | +0% | never |
| 36.8 | cargo r17 | 5255 | +4% | 515 s |
| 37.3 | lucky_haul r8 | 5284 | +0% | never |
| 37.6 | double_cast r8 | 5284 | +0% | 17450 s |
| 38.0 | net_width r17 | 5445 | +0% | 9557 s |
| 38.3 | net_range r17 | 5466 | +0% | never |
| 38.8 | boat_speed r14 | 5910 | +3% | 890 s |
| 39.3 | bird_worth r5 | 6522 | +0% | 6090 s |
| 39.8 | reel r16 | 7478 | +0% | never |
| 40.3 | net_width r18 | 7623 | +0% | 14973 s |
| 40.8 | net_range r18 | 7761 | +0% | never |
| 41.3 | boat_speed r15 | 7801 | +3% | 1258 s |
| 41.8 | net_hold r18 | 7882 | +0% | never |
| 42.3 | cargo r18 | 7882 | +4% | 740 s |
| 43.0 | recycle_bonus r6 | 9756 | +5% | 811 s |
| 43.6 | boat_speed r16 | 10.3k | +2% | 1627 s |
| 44.3 | net_width r19 | 10.7k | +0% | 32027 s |
| 44.9 | net_range r19 | 11.0k | +0% | never |
| 45.6 | reel r17 | 11.4k | +0% | never |
| 46.3 | net_hold r19 | 11.8k | +0% | never |
| 47.0 | cargo r19 | 11.8k | +4% | 1046 s |
| 47.8 | lucky_haul r9 | 12.1k | +0% | never |
| 48.4 | double_cast r9 | 12.1k | +0% | never |
| 49.3 | boat_speed r17 | 13.6k | +2% | 2207 s |
| 50.1 | bird_worth r6 | 14.7k | +0% | never |
| 50.9 | net_width r20 | 14.9k | +0% | never |
| 51.8 | net_range r20 | 15.6k | +0% | never |
| 52.8 | reel r18 | 17.3k | +0% | never |
| 53.8 | net_hold r20 | 17.7k | +0% | never |
| 54.9 | cargo r20 | 17.7k | +4% | 1553 s |
