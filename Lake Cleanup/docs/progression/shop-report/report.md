# Progression sim: Lake Cleanup (shop, 2026-09-14 pass)

## Checks

| | check | result |
|---|---|---|
| PASS | focused clears in 62-78 min | 69.3 min (cleared 99.5%) |
| FAIL | casual clears in 110-160 min | 81.9 min (cleared 99.5%) |
| PASS | focused can always finish (no soft-lock) | finishes |
| PASS | casual can always finish (no soft-lock) | finishes |
| PASS | cheapest can always finish (no soft-lock) | finishes |
| PASS | early buys every 10-60 s (first 10 min) | median gap 13 s |
| PASS | no gap between buys over 300 s | longest 170 s at 32.8-35.6 min |
| WARN | last purchase leaves 10-25% of the game to enjoy it | last buy at 67.7 min, 2% of the game after it |
| FAIL | every buy raises income at least 8% | recycle_bonus +6.2%, net_width +3.1%, net_width r2 +2.8%, reel +0.7%, net_width r3 +2.3%, net_width r4 +1.9% |
| PASS | no single pick wins by 3x in over 50% of choices | median best/second 1.57x; over 3x in 12%; "net_hold" top pick 37% |
| FAIL | payback within 4x of its phase median | cargo too strong for price (24 s vs 127 s); dog_count too strong for price (35 s vs 168 s); lucky_haul r2 too strong for price (41 s vs 168 s); dog_fetch too strong for price (29 s vs 168 s); net_range too strong for price (31 s vs 168 s); net_range r2 too strong for price (10 s vs 168 s) |
| PASS | ferry capacity within 0.8-1.5x of catch rate | inside 76%, lagging 12%, overrunning 12%; box peaked at 409 |
| FAIL | single upgrades are felt (no stage locked against another) | 3 buys only paid off with another: double_cast+reel @14.6, net_hold+lucky_haul @35.6, net_hold+reel @35.6 |
| PASS | no bought node whose only value is what it unlocks | none |
| FAIL | every node earns its purchase, none only in the last 15% | 11 bought only as filler (earned nothing); 0 never bought; 0 first bought late |

## Bot: focused

- Clear: 69.3 min
- Purchases: 133, spent 210.6k sludge
- Income/s at 2 / 10 / 30 min: 3.5 / 25.3 / 236.3
- Median payback by phase: 0m 127s, 10m 168s, 20m 648s, 30m 1132s, 40m 282s, 50m 544s, 60m 999s
- Median seconds from reveal to buy, by group: cargo 10, boat_speed 115, bird_worth 240, fleet 500, recycle_bonus 510, net_strength 520, net_width 525, reel 525, net_hold 615, lucky_haul 820, dog_count 835, dog_fetch 840, net_range 845, double_cast 875, dog_wait 2255

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.2 | cargo | 8 | +23% | 24 s |
| 0.3 | cargo r2 | 12 | +19% | 35 s |
| 0.4 | cargo r3 | 18 | +16% | 53 s |
| 0.6 | cargo r4 | 27 | +14% | 80 s |
| 0.8 | cargo r5 | 41 | +12% | 120 s |
| 1.2 | cargo r6 | 61 | +11% | 181 s |
| 1.9 | boat_speed | 160 | +31% | 147 s |
| 2.3 | cargo r7 | 91 | +10% | 206 s |
| 2.8 | cargo r8 | 137 | +9% | 310 s |
| 3.4 | boat_speed r2 | 211 | +21% | 182 s |
| 4.0 | bird_worth | 250 | from zero | never |
| 4.8 | boat_speed r3 | 279 | +16% | 267 s |
| 5.9 | bird_worth r2 | 565 | from zero | never |
| 8.3 | fleet | 1100 | +98% | 145 s |
| 8.5 | recycle_bonus | 120 | +6% | 127 s |
| 8.7 | net_strength | 200 | +12% | 104 s |
| 8.8 | net_width | 25 | +3% | 44 s |
| 8.8 | net_width r2 | 35 | +3% | 67 s |
| 8.8 | reel | 14 | +1% | 108 s |
| 8.8 | net_width r3 | 49 | +2% | 107 s |
| 8.9 | net_width r4 | 69 | +2% | 172 s |
| 9.1 | cargo r9 | 205 | +8% | 122 s |
| 9.3 | boat_speed r4 | 368 | +12% | 130 s |
| 9.6 | cargo r10 | 308 | +7% | 159 s |
| 9.8 | recycle_bonus r2 | 289 | +6% | 176 s |
| 10.0 | net_strength r2 | 500 | +10% | 160 s |
| 10.1 | reel r2 | 21 | +0% | 177 s |
| 10.3 | net_width r5 | 96 | +1% | 233 s |
| 10.3 | net_hold | 8 | +0% | 115 s |
| 10.3 | boat_speed r5 | 486 | +10% | 141 s |
| 10.6 | cargo r11 | 461 | +7% | 174 s |
| 10.8 | boat_speed r6 | 641 | +8% | 187 s |
| 11.3 | bird_worth r3 | 1277 | from zero | never |
| 12.3 | bird_worth r4 | 2886 | from zero | never |
| 13.3 | fleet r2 | 2750 | +49% | 118 s |
| 13.5 | cargo r12 | 692 | +6% | 155 s |
| 13.7 | boat_speed r7 | 846 | +7% | 163 s |
| 13.7 | lucky_haul | 16 | +0% | 192 s |
| 13.8 | recycle_bonus r3 | 697 | +5% | 158 s |
| 13.9 | dog_count | 45 | +2% | 35 s |
| 13.9 | lucky_haul r2 | 37 | +1% | 41 s |
| 13.9 | lucky_haul r3 | 84 | +1% | 120 s |
| 14.0 | dog_fetch | 65 | +3% | 29 s |
| 14.1 | net_range | 20 | +1% | 31 s |
| 14.1 | cargo r13 | 1038 | +6% | 223 s |
| 14.3 | net_strength r3 | 1250 | +11% | 137 s |
| 14.3 | net_hold r2 | 12 | +0% | 58 s |
| 14.3 | reel r3 | 32 | +0% | 163 s |
| 14.4 | net_width r6 | 135 | +1% | 217 s |
| 14.4 | net_hold r3 | 18 | +0% | 156 s |
| 14.5 | net_width r7 | 188 | +1% | 310 s |
| 14.6 | boat_speed r8 | 1117 | +6% | 200 s |
| 14.6 | double_cast (with reel) | 16 | +0% | 68 s |
| 14.8 | boat_speed r9 | 1475 | +5% | 285 s |
| 15.1 | cargo r14 | 1557 | +5% | 265 s |
| 15.3 | recycle_bonus r4 | 1680 | +5% | 287 s |
| 15.8 | net_strength r4 | 3125 | +16% | 166 s |
| 15.8 | reel r4 | 49 | +0% | 135 s |
| 15.8 | double_cast r2 | 37 | +0% | 148 s |
| 15.8 | net_width r8 | 264 | +1% | 165 s |
| 16.7 | bird_worth r5 | 6522 | from zero | never |
| 17.4 | fleet r3 | 6875 | +27% | 170 s |
| 17.5 | net_range r2 | 28 | +2% | 10 s |
| 17.6 | boat_speed r10 | 1947 | +4% | 245 s |
| 17.8 | cargo r15 | 2335 | +5% | 248 s |
| 18.0 | boat_speed r11 | 2570 | +4% | 342 s |
| 18.3 | cargo r16 | 3503 | +5% | 369 s |
| 18.6 | boat_speed r12 | 3392 | +3% | 479 s |
| 18.7 | net_width r9 | 369 | +0% | 632 s |
| 18.9 | recycle_bonus r5 | 4048 | +5% | 393 s |
| 19.0 | net_range r3 | 40 | +4% | 5 s |
| 19.3 | boat_speed r13 | 4477 | +3% | 664 s |
| 19.7 | cargo r17 | 5255 | +5% | 525 s |
| 20.3 | net_range r4 | 57 | +0% | 144 s |
| 20.3 | net_hold r4 | 27 | +0% | 105 s |
| 20.3 | reel r5 | 75 | +0% | 281 s |
| 20.8 | bird_worth r6 | 14.7k | from zero | never |
| 21.3 | reel r6 | 114 | +0% | 470 s |
| 21.5 | net_range r5 | 81 | +0% | 332 s |
| 21.5 | net_hold r5 | 41 | +0% | 164 s |
| 23.0 | net_range r6 | 116 | +0% | 448 s |
| 24.7 | reel r7 | 173 | +0% | 665 s |
| 24.9 | net_range r7 | 164 | +0% | 615 s |
| 27.4 | net_range r8 | 233 | +0% | 648 s |
| 27.4 | double_cast r3 | 84 | +0% | 367 s |
| 29.3 | net_width r10 | 517 | +0% | 680 s |
| 29.5 | double_cast r4 | 192 | +0% | 714 s |
| 29.6 | cargo r18 | 7882 | +4% | 809 s |
| 29.7 | reel r8 | 262 | +0% | 868 s |
| 29.7 | net_width r11 | 723 | +0% | 850 s |
| 29.8 | recycle_bonus r6 | 9756 | +5% | 889 s |
| 29.8 | boat_speed r14 | 5910 | +3% | 850 s |
| 29.9 | net_range r9 | 331 | +0% | 910 s |
| 32.6 | net_width r12 | 1012 | +0% | 1104 s |
| 32.8 | net_range r10 | 470 | +0% | 1043 s |
| 35.6 | reel r9 | 399 | +0% | 1082 s |
| 35.6 | double_cast r5 | 440 | +0% | 1127 s |
| 35.6 | cargo r19 | 11.8k | +4% | 1138 s |
| 35.6 | boat_speed r15 | 7801 | +2% | 1159 s |
| 35.6 | net_range r11 | 667 | +0% | 1152 s |
| 35.6 | net_hold r6 (with lucky_haul) | 61 | +0% | 208 s |
| 35.6 | net_hold r7 (with reel) | 91 | +0% | 151 s |
| 37.6 | dog_wait | 45 | +0% | never | filler
| 37.9 | net_range r12 | 947 | +0% | 1165 s |
| 39.9 | dog_wait r2 | 113 | +0% | never | filler
| 40.8 | net_range r13 | 1344 | +0% | 1111 s |
| 42.8 | dog_count r2 | 113 | +0% | never | filler
| 44.7 | reel r10 | 606 | +1% | 282 s |
| 44.7 | net_width r13 | 1417 | +0% | 1095 s |
| 44.8 | net_range r14 | 1909 | +3% | 254 s |
| 46.8 | net_hold r8 | 137 | +0% | never | filler
| 47.4 | net_range r15 | 2711 | +4% | 270 s |
| 49.4 | dog_fetch r2 | 163 | +0% | never | filler
| 50.3 | net_width r14 | 1984 | +3% | 248 s |
| 50.3 | reel r11 | 922 | +1% | 548 s |
| 50.3 | double_cast r6 | 1008 | +1% | 293 s |
| 50.3 | net_width r15 | 2778 | +2% | 464 s |
| 50.4 | net_range r16 | 3849 | +3% | 473 s |
| 52.4 | lucky_haul r4 | 192 | +0% | never | filler
| 53.5 | net_range r17 | 5466 | +4% | 511 s |
| 55.5 | net_hold r9 | 205 | +0% | never | filler
| 56.6 | reel r12 | 1401 | +1% | 544 s |
| 56.7 | net_width r16 | 3889 | +2% | 609 s |
| 56.7 | double_cast r7 | 2308 | +1% | 669 s |
| 56.7 | reel r13 | 2129 | +1% | 1154 s |
| 56.8 | net_range r18 | 7761 | +3% | 836 s |
| 58.8 | dog_wait r3 | 281 | +0% | never | filler
| 60.2 | net_range r19 | 11.0k | +4% | 999 s |
| 62.2 | dog_count r3 | 281 | +0% | never | filler
| 63.6 | net_width r17 | 5445 | +2% | 1155 s |
| 63.7 | net_range r20 | 15.6k | +7% | 914 s |
| 65.7 | net_hold r10 | 308 | +0% | never | filler
| 67.7 | dog_fetch r3 | 406 | +0% | never | filler

## Bot: casual

- Clear: 81.9 min (seeds: 80, 82, 90)
- Purchases: 161, spent 574.1k sludge
- Income/s at 2 / 10 / 30 min: 3.3 / 7.7 / 4.9
- Median payback by phase: 0m 181s, 10m 199s, 20m 789s, 30m 2034s, 40m 2439s, 50m 2997s, 60m 4324s, 70m 4271s, 80m 13598s
- Median seconds from reveal to buy, by group: cargo 20, lucky_haul 60, net_width 80, dog_wait 160, boat_speed 160, bird_worth 260, net_range 280, net_strength 440, reel 440, dog_fetch 540, fleet 600, dog_count 600, recycle_bonus 640, net_hold 640, double_cast 980

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.3 | cargo | 8 | +23% | 24 s |
| 0.3 | cargo r2 | 12 | +19% | 35 s |
| 0.7 | cargo r3 | 18 | +16% | 53 s |
| 0.7 | cargo r4 | 27 | +14% | 80 s |
| 1.0 | cargo r5 | 41 | +12% | 120 s |
| 1.0 | lucky_haul * | 16 | +0% | never |
| 1.3 | net_width * | 25 | +1% | 549 s |
| 1.7 | cargo r6 | 61 | +11% | 181 s |
| 2.0 | lucky_haul r2 * | 37 | +0% | never |
| 2.7 | dog_wait * | 45 | +0% | never |
| 2.7 | boat_speed | 160 | +31% | 147 s |
| 3.0 | cargo r7 | 91 | +10% | 206 s |
| 3.7 | boat_speed r2 | 211 | +21% | 198 s |
| 4.3 | bird_worth | 250 | from zero | never |
| 4.7 | net_range | 20 | +1% | 293 s |
| 5.0 | cargo r8 | 137 | +9% | 256 s |
| 5.7 | boat_speed r3 | 279 | +15% | 267 s |
| 7.0 | bird_worth r2 | 565 | from zero | never |
| 7.3 | net_strength * | 200 | +10% | 253 s |
| 7.3 | net_width r2 | 35 | +3% | 148 s |
| 7.3 | reel | 14 | +1% | 146 s |
| 9.0 | dog_fetch * | 65 | +0% | never |
| 10.0 | fleet | 1100 | +96% | 124 s |
| 10.0 | dog_count * | 45 | +0% | never |
| 10.3 | dog_wait r2 * | 113 | +0% | never |
| 10.3 | cargo r9 * | 205 | +8% | 138 s |
| 10.7 | recycle_bonus | 120 | +6% | 96 s |
| 10.7 | net_width r3 | 49 | +1% | 181 s |
| 10.7 | net_hold | 8 | +0% | 199 s |
| 10.7 | net_hold r2 * | 12 | +0% | never |
| 10.7 | net_width r4 | 69 | +1% | 224 s |
| 10.7 | reel r2 | 21 | +0% | 218 s |
| 11.0 | boat_speed r4 | 368 | +12% | 135 s |
| 11.3 | cargo r10 | 308 | +7% | 165 s |
| 11.3 | lucky_haul r3 * | 84 | +0% | 6740 s |
| 11.3 | recycle_bonus r2 | 289 | +6% | 184 s |
| 11.7 | boat_speed r5 | 486 | +10% | 170 s |
| 11.7 | net_hold r3 * | 18 | +0% | never |
| 12.0 | net_strength r2 | 500 | +8% | 186 s |
| 12.0 | net_width r5 | 96 | +2% | 183 s |
| 12.0 | reel r3 | 32 | +0% | 243 s |
| 12.3 | cargo r11 | 461 | +7% | 188 s |
| 12.7 | net_width r6 * | 135 | +1% | 343 s |
| 12.7 | boat_speed r6 | 641 | +8% | 200 s |
| 13.3 | bird_worth r3 | 1277 | from zero | never |
| 14.3 | bird_worth r4 | 2886 | from zero | never |
| 14.3 | net_hold r4 * | 27 | +0% | never |
| 15.3 | fleet r2 | 2750 | +48% | 128 s |
| 15.7 | cargo r12 | 692 | +6% | 167 s |
| 15.7 | boat_speed r7 | 846 | +7% | 177 s |
| 16.0 | recycle_bonus r3 | 697 | +5% | 171 s |
| 16.0 | net_range r2 * | 28 | +0% | never |
| 16.3 | cargo r13 | 1038 | +6% | 228 s |
| 16.3 | net_strength r3 | 1250 | +7% | 228 s |
| 16.3 | double_cast | 16 | +0% | 163 s |
| 16.3 | reel r4 | 49 | +0% | 246 s |
| 16.3 | double_cast r2 * | 37 | +0% | 325 s |
| 16.7 | boat_speed r8 | 1117 | +6% | 215 s |
| 16.7 | net_width r7 | 188 | +1% | 348 s |
| 16.7 | net_hold r5 | 41 | +0% | 180 s |
| 17.0 | dog_fetch r2 * | 163 | +0% | never |
| 17.0 | cargo r14 | 1557 | +5% | 299 s |
| 17.3 | boat_speed r9 | 1475 | +5% | 290 s |
| 17.7 | recycle_bonus r4 | 1680 | +5% | 309 s |
| 18.3 | net_strength r4 | 3125 | +12% | 227 s |
| 18.3 | net_hold r6 | 61 | +1% | 73 s |
| 18.3 | net_hold r7 | 91 | +0% | 150 s |
| 18.3 | reel r5 | 75 | +0% | 199 s |
| 18.7 | net_width r8 * | 264 | +1% | 353 s |
| 18.7 | net_hold r8 | 137 | +0% | 250 s |
| 19.0 | dog_wait r3 * | 281 | +0% | never |
| 19.3 | bird_worth r5 | 6522 | from zero | never |
| 20.7 | fleet r3 | 6875 | +33% | 143 s |
| 20.7 | boat_speed r10 | 1947 | +4% | 223 s |
| 21.0 | cargo r15 | 2335 | +5% | 224 s |
| 21.0 | net_width r9 | 369 | +0% | 442 s |
| 21.0 | net_width r10 * | 517 | +0% | 639 s |
| 21.3 | net_hold r9 * | 205 | +0% | never |
| 21.3 | boat_speed r11 | 2570 | +4% | 308 s |
| 21.3 | dog_fetch r3 * | 406 | +0% | never |
| 21.7 | cargo r16 | 3503 | +5% | 334 s |
| 22.0 | recycle_bonus r5 | 4048 | +5% | 364 s |
| 22.3 | net_range r3 | 40 | +14% | 2 s |
| 22.3 | lucky_haul r4 * | 192 | +0% | never |
| 22.3 | boat_speed r12 | 3392 | +3% | 444 s |
| 22.3 | boat_speed r13 | 4477 | +3% | 630 s |
| 22.7 | cargo r17 | 5255 | +5% | 503 s |
| 22.7 | double_cast r3 (with reel) | 84 | +0% | 322 s |
| 23.3 | cargo r18 | 7882 | +4% | 789 s |
| 23.3 | dog_count r2 * | 113 | +0% | never |
| 23.3 | net_range r4 | 57 | +0% | 152 s |
| 23.3 | reel r6 (with double_cast) | 114 | +0% | 312 s |
| 23.3 | net_width r11 | 723 | +0% | 1197 s |
| 23.7 | net_width r12 * | 1012 | +0% | 1543 s |
| 23.7 | reel r7 (with double_cast) | 173 | +0% | 410 s |
| 24.0 | net_range r5 | 81 | +0% | 248 s |
| 24.0 | recycle_bonus r6 | 9756 | +5% | 877 s |
| 24.3 | double_cast r4 (with reel) | 192 | +0% | 411 s |
| 24.7 | dog_count r3 * | 281 | +0% | never |
| 24.7 | boat_speed r14 | 5910 | +3% | 852 s |
| 24.7 | net_range r6 (with reel) | 116 | +0% | 308 s |
| 24.7 | reel r8 | 262 | +0% | 967 s |
| 25.3 | cargo r19 | 11.8k | +4% | 1145 s |
| 25.3 | lucky_haul r5 * | 440 | +0% | 14456 s |
| 26.0 | boat_speed r15 | 7801 | +3% | 1170 s |
| 26.0 | net_range r7 (with net_hold) | 164 | +0% | 391 s |
| 26.7 | net_width r13 * | 1417 | +0% | 2055 s |
| 26.7 | net_hold r10 | 308 | +0% | 928 s |
| 26.7 | double_cast r5 | 440 | +0% | 1129 s |
| 26.7 | reel r9 | 399 | +0% | 1196 s |
| 27.0 | bird_worth r6 | 14.7k | from zero | never |
| 27.3 | net_hold r11 | 461 | +0% | 1170 s |
| 29.3 | net_range r8 | 233 | +0% | 1146 s | filler
| 29.7 | cargo r20 * | 17.7k | +4% | 1639 s |
| 30.7 | net_range r9 * | 331 | +0% | 1271 s |
| 32.3 | bird_worth r7 * | 33.3k | +0% | 29030 s |
| 34.3 | net_range r10 | 470 | +0% | 1515 s | filler
| 36.0 | net_width r14 * | 1984 | +0% | 2034 s |
| 36.3 | lucky_haul r6 * | 1008 | +0% | never |
| 38.3 | double_cast r6 * | 1008 | +0% | 2379 s |
| 40.3 | net_range r11 * | 667 | +0% | 2319 s |
| 40.7 | dog_fetch r4 * | 1016 | +0% | never |
| 40.7 | reel r10 * | 606 | +0% | 1641 s |
| 41.3 | lucky_haul r7 * | 2308 | +0% | never |
| 43.0 | net_hold r12 * | 692 | +0% | never |
| 43.7 | net_range r12 | 947 | +7% | 49 s |
| 44.3 | net_width r15 * | 2778 | +0% | 2559 s |
| 45.0 | lucky_haul r8 * | 5284 | +0% | never |
| 46.3 | net_range r13 * | 1344 | +16% | 32 s |
| 46.7 | net_range r14 * | 1909 | +0% | 5902 s |
| 46.7 | double_cast r7 * | 2308 | +0% | 4496 s |
| 48.7 | reel r11 | 922 | +0% | 2289 s | filler
| 49.7 | reel r12 * | 1401 | +0% | 3836 s |
| 50.0 | bird_worth r8 * | 75.3k | +1% | never |
| 50.3 | net_hold r13 * | 1038 | +0% | never |
| 51.7 | lucky_haul r9 * | 12.1k | +0% | never |
| 53.7 | net_hold r14 | 1557 | +0% | never | filler
| 54.7 | net_range r15 | 2711 | +11% | 92 s |
| 55.0 | net_hold r15 * | 2335 | +0% | never |
| 55.0 | net_width r16 * | 3889 | +0% | 4158 s |
| 57.0 | net_range r16 | 3849 | +3% | 497 s |
| 57.0 | recycle_bonus r7 * | 23.5k | +4% | 1837 s |
| 57.7 | net_range r17 * | 5466 | +0% | 21192 s |
| 59.7 | reel r13 | 2129 | +0% | 7254 s | filler
| 59.7 | net_range r18 * | 7761 | +0% | 29789 s |
| 61.7 | reel r14 | 3237 | +0% | 13898 s | filler
| 63.7 | net_hold r16 | 3503 | +0% | never | filler
| 64.0 | reel r15 * | 4920 | +0% | 32786 s |
| 64.7 | boat_speed r16 * | 10.3k | +2% | 1473 s |
| 66.7 | net_hold r17 | 5255 | +0% | never | filler
| 68.7 | net_range r19 | 11.0k | +16% | 267 s |
| 69.3 | recycle_bonus r8 * | 56.7k | +4% | 4324 s |
| 69.7 | net_range r20 * | 15.6k | +0% | never |
| 71.3 | reel r16 * | 7478 | +0% | never |
| 73.0 | boat_speed r17 * | 13.6k | +2% | 1985 s |
| 75.0 | double_cast r8 | 5284 | +0% | never | filler
| 77.0 | net_width r17 | 5445 | +4% | 1668 s | filler
| 77.3 | net_width r18 * | 7623 | +4% | 2399 s |
| 78.0 | double_cast r9 * | 12.1k | +2% | 6143 s |
| 80.0 | double_cast r10 * | 27.7k | +2% | 13598 s |
| 80.3 | lucky_haul r10 * | 27.7k | +0% | never |

## Bot: cheapest

- Clear: 67.5 min
- Purchases: 162, spent 421.6k sludge
- Income/s at 2 / 10 / 30 min: 2.6 / 5.1 / 30.9
- Median payback by phase: 0m 523s, 10m 704s, 20m 1287s, 30m 1711s, 40m 818s, 50m 1263s, 60m 86519s
- Median seconds from reveal to buy, by group: net_hold 10, cargo 15, reel 35, lucky_haul 40, double_cast 50, net_range 75, net_width 95, dog_wait 220, dog_count 230, dog_fetch 325, recycle_bonus 590, boat_speed 695, net_strength 865, bird_worth 985, fleet 2005

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
| 14.8 | net_hold r9 | 205 | +0% | 17029 s |
| 15.3 | cargo r9 | 205 | +6% | 380 s |
| 15.7 | boat_speed r2 | 211 | +17% | 135 s |
| 16.0 | net_range r8 | 233 | +1% | 2870 s |
| 16.4 | bird_worth | 250 | +6% | 397 s |
| 16.8 | reel r8 | 262 | +1% | 2978 s |
| 17.2 | net_width r8 | 264 | +3% | 755 s |
| 17.6 | boat_speed r3 | 279 | +12% | 190 s |
| 17.9 | dog_wait r3 | 281 | +0% | never |
| 18.3 | dog_count r3 | 281 | +0% | never |
| 18.6 | recycle_bonus r2 | 289 | +5% | 459 s |
| 18.9 | net_hold r10 | 308 | +0% | never |
| 19.3 | cargo r10 | 308 | +6% | 361 s |
| 19.7 | net_range r9 | 331 | +1% | 2721 s |
| 20.1 | boat_speed r4 | 368 | +10% | 243 s |
| 20.4 | net_width r9 | 369 | +2% | 1016 s |
| 20.8 | reel r9 | 399 | +1% | 3896 s |
| 21.2 | dog_fetch r3 | 406 | +0% | never |
| 21.6 | lucky_haul r5 | 440 | +0% | never |
| 22.0 | double_cast r5 | 440 | +1% | 3868 s |
| 22.5 | net_hold r11 | 461 | +0% | never |
| 22.9 | cargo r11 | 461 | +5% | 483 s |
| 23.3 | net_range r10 | 470 | +1% | 3102 s |
| 23.8 | boat_speed r5 | 486 | +8% | 329 s |
| 24.2 | net_strength r2 | 500 | +4% | 628 s |
| 24.6 | net_width r10 | 517 | +2% | 1242 s |
| 25.0 | bird_worth r2 | 565 | +5% | 555 s |
| 25.5 | reel r10 | 606 | +1% | 4136 s |
| 25.9 | boat_speed r6 | 641 | +6% | 425 s |
| 26.4 | net_range r11 | 667 | +1% | 4807 s |
| 26.8 | net_hold r12 | 692 | +0% | never |
| 27.3 | cargo r12 | 692 | +5% | 536 s |
| 27.8 | recycle_bonus r3 | 697 | +4% | 584 s |
| 28.2 | net_width r11 | 723 | +2% | 1332 s |
| 28.7 | boat_speed r7 | 846 | +5% | 532 s |
| 29.2 | reel r11 | 922 | +0% | 6280 s |
| 29.7 | net_range r12 | 947 | +1% | 5487 s |
| 30.2 | lucky_haul r6 | 1008 | +0% | never |
| 30.8 | double_cast r6 | 1008 | +1% | 4741 s |
| 31.3 | net_width r12 | 1012 | +2% | 1711 s |
| 31.8 | dog_fetch r4 | 1016 | +0% | never |
| 32.3 | net_hold r13 | 1038 | +0% | never |
| 32.9 | cargo r13 | 1038 | +5% | 708 s |
| 33.4 | fleet | 1100 | +78% | 42 s |
| 33.8 | boat_speed r8 | 1117 | +5% | 360 s |
| 34.1 | net_strength r3 | 1250 | +4% | 532 s |
| 34.4 | bird_worth r3 | 1277 | +2% | 918 s |
| 34.8 | net_range r13 | 1344 | +0% | never |
| 35.2 | reel r12 | 1401 | +0% | 6455 s |
| 35.5 | net_width r13 | 1417 | +1% | 1808 s |
| 35.8 | boat_speed r9 | 1475 | +4% | 476 s |
| 36.2 | net_hold r14 | 1557 | +0% | never |
| 36.6 | cargo r14 | 1557 | +5% | 439 s |
| 36.9 | recycle_bonus r4 | 1680 | +5% | 475 s |
| 37.3 | net_range r14 | 1909 | +0% | never |
| 37.8 | boat_speed r10 | 1947 | +4% | 605 s |
| 38.1 | net_width r14 | 1984 | +1% | 2799 s |
| 38.5 | reel r13 | 2129 | +0% | 10629 s |
| 39.0 | lucky_haul r7 | 2308 | +0% | never |
| 39.4 | double_cast r7 | 2308 | +0% | 6940 s |
| 39.9 | net_hold r15 | 2335 | +0% | never |
| 40.3 | cargo r15 | 2335 | +5% | 599 s |
| 40.8 | boat_speed r11 | 2570 | +4% | 818 s |
| 41.3 | net_range r15 | 2711 | +0% | never |
| 41.8 | fleet r2 | 2750 | +45% | 68 s |
| 42.2 | net_width r15 | 2778 | +1% | 4173 s |
| 42.6 | bird_worth r4 | 2886 | +1% | 1831 s |
| 43.0 | net_strength r4 | 3125 | +4% | 570 s |
| 43.3 | reel r14 | 3237 | +0% | 12293 s |
| 43.8 | boat_speed r12 | 3392 | +3% | 714 s |
| 44.2 | net_hold r16 | 3503 | +0% | never |
| 44.6 | cargo r16 | 3503 | +5% | 506 s |
| 45.0 | net_range r16 | 3849 | +0% | never |
| 45.4 | net_width r16 | 3889 | +0% | 6128 s |
| 45.8 | recycle_bonus r5 | 4048 | +5% | 541 s |
| 46.3 | boat_speed r13 | 4477 | +3% | 886 s |
| 46.8 | reel r15 | 4920 | +0% | 31165 s |
| 47.3 | net_hold r17 | 5255 | +0% | never |
| 47.8 | cargo r17 | 5255 | +4% | 690 s |
| 48.3 | lucky_haul r8 | 5284 | +0% | never |
| 48.8 | double_cast r8 | 5284 | +0% | 17651 s |
| 49.3 | net_width r17 | 5445 | +0% | 9650 s |
| 49.8 | net_range r17 | 5466 | +0% | never |
| 50.3 | boat_speed r14 | 5910 | +3% | 1192 s |
| 50.9 | bird_worth r5 | 6522 | +1% | 6217 s |
| 51.5 | fleet r3 | 6875 | +32% | 117 s |
| 52.0 | reel r16 | 7478 | +0% | never |
| 52.6 | net_width r18 | 7623 | +0% | 15243 s |
| 53.1 | net_range r18 | 7761 | +0% | never |
| 53.6 | boat_speed r15 | 7801 | +3% | 1263 s |
| 54.2 | net_hold r18 | 7882 | +0% | never |
| 54.7 | cargo r18 | 7882 | +4% | 743 s |
| 55.3 | recycle_bonus r6 | 9756 | +5% | 814 s |
| 55.9 | boat_speed r16 | 10.3k | +2% | 1633 s |
| 56.6 | net_width r19 | 10.7k | +0% | 32089 s |
| 57.3 | net_range r19 | 11.0k | +0% | never |
| 57.9 | reel r17 | 11.4k | +0% | never |
| 58.7 | net_hold r19 | 11.8k | +0% | never |
| 59.4 | cargo r19 | 11.8k | +4% | 1050 s |
| 60.1 | lucky_haul r9 | 12.1k | +0% | never |
| 60.8 | double_cast r9 | 12.1k | +0% | never |
| 61.6 | boat_speed r17 | 13.6k | +2% | 2215 s |
| 62.4 | bird_worth r6 | 14.7k | +0% | never |
| 63.3 | net_width r20 | 14.9k | +0% | never |
| 64.2 | net_range r20 | 15.6k | +0% | never |
| 65.2 | reel r18 | 17.3k | +0% | never |
| 66.3 | net_hold r20 | 17.7k | +0% | never |
| 67.3 | cargo r20 | 17.7k | +4% | 1557 s |
