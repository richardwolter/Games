# Progression sim: Lake Cleanup (shop, 2026-09-18 pass)

## Checks

| | check | result |
|---|---|---|
| PASS | focused clears in 48-68 min | 49.9 min (cleared 99.5%) |
| PASS | focused can always finish (no soft-lock) | finishes |
| PASS | casual can always finish (no soft-lock) | finishes |
| PASS | cheapest can always finish (no soft-lock) | finishes |
| PASS | early buys every 10-60 s (first 10 min) | median gap 13 s |
| PASS | no gap between buys over 300 s | longest 120 s at 33.8-35.8 min |
| WARN | last purchase leaves 10-25% of the game to enjoy it | last buy at 48.3 min, 3% of the game after it |
| FAIL | every buy raises income at least 8% | net_range +5.3%, boat_speed r4 +1.7%, dog_count +2.4%, net_range r5 +8.0%, boat_speed r5 +2.3%, net_width +7.1% |
| PASS | no single pick wins by 3x in over 50% of choices | median best/second 1.37x; over 3x in 3%; "net_strength" top pick 46% |
| FAIL | payback within 4x of its phase median | cargo too strong for price (23 s vs 182 s); fleet too strong for price (41 s vs 182 s); double_cast too weak for price (730 s vs 182 s); net_hold too strong for price (76 s vs 352 s); fleet r3 too strong for price (36 s vs 352 s); cargo r5 too strong for price (79 s vs 352 s) |
| WARN | ferry capacity within 1-2.5x of catch rate | inside 58%, lagging 33%, overrunning 9%; box peaked at 973 |
| PASS | single upgrades are felt (no stage locked against another) | none |
| PASS | no bought node whose only value is what it unlocks | none |
| FAIL | every node earns its purchase, none only in the last 15% | 6 bought only as filler (earned nothing); 0 never bought; 0 first bought late |

## Bot: focused

- Clear: 49.9 min
- Purchases: 135, spent 483.3k sludge
- Income/s at 2 / 10 / 30 min: 15.2 / 72.3 / 612.6
- Median payback by phase: 0m 182s, 10m 352s, 20m 549s, 30m 644s, 40m 807s
- Median seconds from reveal to buy, by group: cargo 10, boat_speed 20, bird_worth 35, net_range 85, fleet 100, dog_count 160, net_width 220, boat_volley 235, reel 285, net_strength 420, recycle_bonus 445, double_cast 485, net_hold 705, lucky_haul 765, dog_fetch 905, dog_wait 1280, dog_strength 2395

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.2 | cargo | 40 | +35% | 23 s |
| 0.3 | boat_speed | 60 | +13% | 68 s |
| 0.6 | bird_worth | 120 | from zero | never |
| 0.8 | cargo r2 | 100 | +25% | 53 s |
| 1.0 | boat_speed r2 | 84 | +11% | 84 s |
| 1.2 | boat_speed r3 | 118 | +9% | 132 s |
| 1.4 | net_range | 150 | +5% | 261 s |
| 1.7 | fleet | 200 | +43% | 41 s |
| 1.8 | bird_worth r2 | 216 | from zero | never |
| 2.0 | net_range r2 | 191 | +29% | 46 s |
| 2.2 | net_range r3 | 242 | +19% | 72 s |
| 2.4 | net_range r4 | 307 | +11% | 131 s |
| 2.5 | boat_speed r4 | 165 | +2% | 416 s |
| 2.7 | dog_count | 200 | +2% | 357 s |
| 2.9 | bird_worth r3 | 389 | from zero | never |
| 3.2 | net_range r5 | 390 | +8% | 214 s |
| 3.3 | boat_speed r5 | 231 | +2% | 412 s |
| 3.7 | net_width | 450 | +7% | 256 s |
| 3.8 | cargo r3 | 250 | +19% | 50 s |
| 3.9 | boat_volley | 160 | +1% | 404 s |
| 4.3 | bird_worth r4 | 700 | from zero | never |
| 4.8 | reel | 450 | +3% | 452 s |
| 4.8 | boat_speed r6 | 323 | +5% | 195 s |
| 5.3 | bird_worth r5 | 1260 | from zero | never |
| 5.6 | net_width r2 | 545 | +5% | 308 s |
| 5.8 | fleet r2 | 500 | +18% | 83 s |
| 6.0 | net_width r3 | 659 | +20% | 86 s |
| 6.2 | net_range r6 | 496 | +6% | 182 s |
| 6.3 | reel r2 | 531 | +9% | 125 s |
| 7.0 | net_strength | 2000 | +29% | 141 s |
| 7.4 | recycle_bonus | 1500 | +6% | 398 s |
| 8.0 | bird_worth r6 | 2268 | from zero | never |
| 8.1 | double_cast | 400 | +1% | 730 s |
| 8.2 | boat_volley r2 | 398 | +1% | 444 s |
| 8.8 | recycle_bonus r2 | 2415 | +6% | 632 s |
| 9.8 | bird_worth r7 | 4082 | from zero | never |
| 11.3 | net_strength r2 | 6600 | +24% | 387 s |
| 11.3 | reel r3 | 627 | +1% | 913 s |
| 11.4 | boat_speed r7 | 452 | +5% | 110 s |
| 11.6 | cargo r4 | 625 | +3% | 254 s |
| 11.8 | net_hold | 1000 | +14% | 76 s |
| 11.9 | fleet r3 | 1250 | +32% | 36 s |
| 12.0 | boat_speed r8 | 633 | +4% | 109 s |
| 12.2 | cargo r5 | 1563 | +13% | 79 s |
| 12.3 | boat_speed r9 | 886 | +2% | 314 s |
| 12.3 | net_width r4 | 797 | +3% | 134 s |
| 12.4 | boat_volley r3 | 992 | +2% | 271 s |
| 12.6 | boat_speed r10 | 1240 | +2% | 333 s |
| 12.6 | double_cast r2 | 616 | +1% | 274 s |
| 12.8 | lucky_haul | 350 | +1% | 294 s |
| 12.8 | reel r4 | 739 | +1% | 294 s |
| 12.8 | boat_speed r11 | 1736 | +3% | 319 s |
| 13.0 | net_width r5 | 965 | +2% | 284 s |
| 13.2 | boat_speed r12 | 2430 | +3% | 479 s |
| 13.4 | reel r5 | 872 | +1% | 313 s |
| 13.4 | boat_volley r4 | 2470 | +2% | 540 s |
| 13.5 | lucky_haul r2 | 476 | +1% | 336 s |
| 13.6 | net_width r6 | 1167 | +2% | 371 s |
| 13.9 | recycle_bonus r3 | 3888 | +5% | 356 s |
| 14.1 | lucky_haul r3 | 647 | +1% | 364 s |
| 14.1 | net_width r7 | 1412 | +1% | 938 s |
| 14.3 | boat_speed r13 | 3402 | +2% | 786 s |
| 14.3 | dog_count r2 | 400 | +0% | 737 s |
| 14.4 | double_cast r3 | 949 | +1% | 343 s |
| 14.5 | reel r6 | 1030 | +1% | 618 s |
| 14.7 | net_width r8 | 1709 | +1% | 854 s |
| 15.0 | lucky_haul r4 | 880 | +1% | 794 s |
| 15.1 | dog_fetch | 500 | +1% | 354 s |
| 15.2 | reel r7 | 1215 | +2% | 344 s |
| 15.3 | lucky_haul r5 | 1197 | +1% | 534 s |
| 15.3 | reel r8 | 1434 | +2% | 350 s |
| 15.4 | net_width r9 | 2068 | +3% | 373 s |
| 15.5 | cargo r6 | 3906 | +2% | 740 s |
| 15.5 | net_range r7 | 629 | +6% | 48 s |
| 15.9 | recycle_bonus r4 | 6260 | +5% | 521 s |
| 16.4 | bird_worth r8 | 7347 | from zero | never |
| 16.5 | net_range r8 | 799 | +2% | 202 s |
| 17.3 | double_cast r4 | 1461 | +1% | 460 s |
| 17.5 | reel r9 | 1692 | +2% | 356 s |
| 17.7 | net_hold r2 | 1800 | +2% | 376 s |
| 18.0 | net_range r9 | 1015 | +2% | 260 s |
| 18.0 | cargo r7 | 9766 | +10% | 397 s |
| 18.9 | net_strength r3 | 21.8k | +24% | 337 s |
| 19.2 | boat_speed r14 | 4762 | +2% | 627 s |
| 19.5 | boat_speed r15 | 6667 | +2% | 932 s |
| 20.0 | recycle_bonus r5 | 10.1k | +5% | 578 s |
| 20.6 | lucky_haul r6 | 1628 | +2% | 285 s |
| 20.6 | net_width r10 | 2502 | +1% | 955 s |
| 20.8 | net_width r11 | 3027 | +1% | 1163 s |
| 20.9 | reel r10 | 1996 | +1% | 504 s |
| 21.0 | lucky_haul r7 | 2215 | +2% | 319 s |
| 21.0 | double_cast r5 | 2250 | +1% | 894 s |
| 21.1 | net_width r12 | 3663 | +3% | 367 s |
| 21.2 | dog_count r3 | 800 | +0% | 527 s |
| 21.3 | net_width r13 | 4432 | +4% | 327 s |
| 21.3 | lucky_haul r8 | 3012 | +2% | 378 s |
| 21.3 | dog_wait | 600 | +0% | 791 s |
| 21.4 | net_width r14 | 5363 | +3% | 408 s |
| 21.5 | lucky_haul r9 | 4096 | +2% | 468 s |
| 21.6 | reel r11 | 2355 | +1% | 549 s |
| 21.8 | net_range r10 | 1289 | +2% | 187 s |
| 22.4 | recycle_bonus r6 | 16.2k | +4% | 1036 s |
| 23.3 | reel r12 | 2779 | +1% | 784 s |
| 23.3 | lucky_haul r10 | 5571 | +3% | 587 s |
| 23.4 | net_range r11 | 1637 | +1% | 426 s |
| 23.9 | cargo r8 | 24.4k | +9% | 799 s |
| 24.8 | net_range r12 | 2079 | +2% | 341 s |
| 26.3 | net_range r13 | 2641 | +3% | 222 s |
| 27.3 | net_strength r4 | 71.9k | +37% | 513 s |
| 27.4 | net_hold r3 | 3240 | +1% | 728 s |
| 27.8 | boat_speed r16 | 9334 | +2% | 909 s |
| 28.5 | recycle_bonus r7 | 26.1k | +4% | 1039 s |
| 29.5 | net_width r15 | 6489 | +3% | 358 s |
| 29.6 | double_cast r6 | 3465 | +1% | 443 s |
| 29.6 | net_width r16 | 7852 | +3% | 451 s |
| 29.7 | net_width r17 | 9501 | +3% | 578 s |
| 29.7 | reel r13 | 3279 | +1% | 608 s |
| 29.8 | double_cast r7 | 5336 | +1% | 662 s |
| 29.8 | reel r14 | 3870 | +1% | 811 s |
| 29.8 | reel r15 | 4566 | +1% | 1044 s |
| 30.0 | double_cast r8 | 8217 | +1% | 1093 s |
| 30.1 | net_range r14 | 3354 | +3% | 199 s |
| 31.8 | net_width r18 | 11.5k | +2% | 1013 s |
| 31.9 | net_range r15 | 4259 | +3% | 298 s |
| 33.8 | net_range r16 | 5409 | +3% | 457 s |
| 35.8 | net_range r17 | 6870 | +2% | 644 s |
| 37.8 | dog_fetch r2 | 900 | +0% | never | filler
| 37.9 | net_range r18 | 8725 | +3% | 648 s |
| 39.9 | dog_strength | 1200 | +0% | never | filler
| 40.1 | net_range r19 | 11.1k | +5% | 556 s |
| 42.1 | dog_wait r2 | 1320 | +0% | never | filler
| 42.3 | net_range r20 | 14.1k | +3% | 1058 s |
| 44.3 | dog_fetch r3 | 1620 | +0% | never | filler
| 46.3 | dog_strength r2 | 2640 | +0% | never | filler
| 48.3 | dog_wait r3 | 2904 | +0% | never | filler

## Bot: casual

- Clear: 74.8 min (seeds: 74, 75, 75)
- Purchases: 153, spent 721.0k sludge
- Income/s at 2 / 10 / 30 min: 9.8 / 1.8 / 11.0
- Median payback by phase: 0m 132s, 10m 152s, 20m 287s, 30m 301s, 40m 551s, 50m 1065s, 60m 1156s, 70m 5814s
- Median seconds from reveal to buy, by group: cargo 20, bird_worth 40, boat_speed 40, net_range 120, fleet 140, dog_count 240, net_width 260, reel 320, double_cast 340, lucky_haul 360, boat_volley 380, net_strength 780, net_hold 800, dog_wait 860, recycle_bonus 900, dog_fetch 1220, dog_strength 1580

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.3 | cargo | 40 | +35% | 23 s |
| 0.7 | bird_worth | 120 | from zero | never |
| 0.7 | boat_speed | 60 | +13% | 68 s |
| 1.0 | cargo r2 | 100 | +25% | 53 s |
| 1.3 | bird_worth r2 | 216 | from zero | never |
| 1.7 | boat_speed r2 | 84 | +7% | 128 s |
| 2.0 | net_range | 150 | +11% | 141 s |
| 2.0 | net_range r2 * | 191 | +1% | 2044 s |
| 2.3 | fleet | 200 | +78% | 24 s |
| 2.7 | bird_worth r3 | 389 | from zero | never |
| 3.0 | net_range r3 | 242 | +19% | 78 s |
| 3.3 | net_range r4 | 307 | +13% | 126 s |
| 3.7 | bird_worth r4 | 700 | from zero | never |
| 4.0 | dog_count | 200 | +3% | 356 s |
| 4.0 | cargo r3 * | 250 | +0% | never |
| 4.3 | net_width | 450 | +27% | 84 s |
| 4.7 | boat_speed r3 | 118 | +3% | 137 s |
| 4.7 | net_range r5 | 390 | +5% | 290 s |
| 5.0 | boat_speed r4 | 165 | +5% | 117 s |
| 5.3 | reel | 450 | +5% | 321 s |
| 5.3 | fleet r2 * | 500 | +6% | 289 s |
| 5.7 | double_cast * | 400 | +2% | 715 s |
| 6.0 | net_width r2 | 545 | +25% | 74 s |
| 6.0 | lucky_haul * | 350 | +2% | 414 s |
| 6.3 | boat_volley * | 160 | +0% | never |
| 9.7 | boat_speed r5 * | 231 | +0% | never |
| 10.3 | net_width r3 | 659 | +20% | 93 s |
| 10.7 | reel r2 | 531 | +8% | 154 s |
| 11.0 | bird_worth r5 | 1260 | from zero | never |
| 11.3 | net_range r6 | 496 | +11% | 103 s |
| 11.3 | reel r3 | 627 | +5% | 274 s |
| 11.7 | lucky_haul r2 * | 476 | +0% | never |
| 12.0 | fleet r3 * | 1250 | +0% | never |
| 12.3 | net_width r4 | 797 | +12% | 143 s |
| 12.3 | lucky_haul r3 * | 647 | +1% | 839 s |
| 13.0 | net_strength | 2000 | +35% | 116 s |
| 13.3 | boat_speed r6 * | 323 | +0% | never |
| 13.3 | net_hold | 1000 | +29% | 52 s |
| 13.7 | cargo r4 | 625 | +15% | 47 s |
| 13.7 | boat_speed r7 | 452 | +4% | 102 s |
| 13.7 | boat_speed r8 | 633 | +4% | 155 s |
| 14.0 | bird_worth r6 | 2268 | from zero | never |
| 14.3 | dog_wait * | 600 | +0% | never |
| 14.3 | cargo r5 | 1563 | +9% | 168 s |
| 14.7 | net_hold r2 * | 1800 | +0% | 8466 s |
| 14.7 | net_range r7 | 629 | +9% | 64 s |
| 15.0 | recycle_bonus | 1500 | +6% | 206 s |
| 15.3 | reel r4 | 739 | +5% | 123 s |
| 15.3 | recycle_bonus r2 | 2415 | +6% | 332 s |
| 15.7 | net_width r5 | 965 | +5% | 141 s |
| 15.7 | boat_volley r2 | 398 | +2% | 151 s |
| 15.7 | dog_wait r2 * | 1320 | +0% | never |
| 16.0 | boat_speed r9 | 886 | +2% | 328 s |
| 16.0 | double_cast r2 | 616 | +2% | 271 s |
| 16.3 | net_range r8 | 799 | +10% | 64 s |
| 16.3 | boat_speed r10 | 1240 | +3% | 279 s |
| 16.7 | lucky_haul r4 * | 880 | +0% | never |
| 20.3 | dog_fetch * | 500 | +0% | never |
| 20.7 | bird_worth r7 | 4082 | from zero | never |
| 21.0 | reel r5 | 872 | +4% | 142 s |
| 21.3 | net_range r9 * | 1015 | +5% | 151 s |
| 21.3 | cargo r6 | 3906 | +9% | 287 s |
| 21.3 | dog_count r2 | 400 | +1% | 239 s |
| 21.7 | net_width r6 | 1167 | +5% | 153 s |
| 21.7 | boat_volley r3 | 992 | +2% | 259 s |
| 22.3 | bird_worth r8 | 7347 | from zero | never |
| 22.3 | net_width r7 | 1412 | +7% | 134 s |
| 23.0 | net_strength r2 | 6600 | +39% | 108 s |
| 23.3 | boat_speed r11 | 1736 | +3% | 276 s |
| 23.3 | boat_speed r12 | 2430 | +3% | 415 s |
| 23.7 | recycle_bonus r3 | 3888 | +5% | 312 s |
| 24.0 | boat_volley r4 | 2470 | +3% | 391 s |
| 24.0 | boat_speed r13 | 3402 | +2% | 558 s |
| 24.7 | recycle_bonus r4 | 6260 | +5% | 478 s |
| 25.0 | reel r6 | 1030 | +0% | 805 s |
| 25.0 | boat_speed r14 | 4762 | +2% | 793 s |
| 25.0 | net_width r8 * | 1709 | +1% | 1199 s |
| 25.7 | reel r7 | 1215 | +3% | 153 s |
| 25.7 | recycle_bonus r5 | 10.1k | +5% | 754 s |
| 26.0 | net_width r9 | 2068 | +7% | 103 s |
| 26.3 | net_range r10 | 1289 | +7% | 66 s |
| 26.3 | dog_strength * | 1200 | +0% | never |
| 26.3 | dog_strength r2 * | 2640 | +0% | never |
| 26.3 | dog_fetch r2 * | 900 | +0% | never |
| 26.7 | lucky_haul r5 * | 1197 | +0% | never |
| 27.7 | lucky_haul r6 * | 1628 | +0% | never |
| 31.0 | double_cast r3 | 949 | +2% | 166 s |
| 31.0 | reel r8 | 1434 | +1% | 368 s |
| 31.3 | double_cast r4 | 1461 | +2% | 251 s |
| 31.7 | net_width r10 | 2502 | +6% | 162 s |
| 31.7 | net_strength r3 | 21.8k | +23% | 339 s |
| 32.3 | cargo r7 | 9766 | +10% | 273 s |
| 32.7 | boat_speed r15 | 6667 | +2% | 842 s |
| 33.0 | reel r9 | 1692 | +2% | 185 s |
| 33.0 | reel r10 | 1996 | +2% | 242 s |
| 33.3 | dog_fetch r3 * | 1620 | +0% | never |
| 33.3 | net_width r11 | 3027 | +5% | 170 s |
| 33.3 | double_cast r5 | 2250 | +2% | 277 s |
| 33.3 | reel r11 | 2355 | +1% | 923 s |
| 33.7 | net_width r12 | 3663 | +5% | 209 s |
| 33.7 | lucky_haul r7 | 2215 | +1% | 431 s |
| 34.0 | net_width r13 | 4432 | +4% | 287 s |
| 34.0 | net_hold r3 | 3240 | +3% | 250 s |
| 34.0 | reel r12 | 2779 | +1% | 490 s |
| 34.3 | net_range r11 | 1637 | +1% | 301 s |
| 34.7 | recycle_bonus r6 | 16.2k | +4% | 977 s |
| 35.0 | double_cast r6 * | 3465 | +0% | 4612 s |
| 35.3 | reel r13 * | 3279 | +0% | 6591 s |
| 35.3 | double_cast r7 * | 5336 | +0% | 6410 s |
| 36.3 | lucky_haul r8 * | 3012 | +3% | 356 s |
| 36.3 | net_hold r4 * | 5832 | +0% | never |
| 36.3 | net_hold r5 * | 10.5k | +0% | never |
| 36.3 | net_range r12 | 2079 | +16% | 42 s |
| 38.7 | double_cast r8 * | 8217 | +0% | 9008 s |
| 41.3 | net_range r13 | 2641 | +5% | 165 s |
| 41.3 | dog_fetch r4 * | 2916 | +0% | never |
| 41.3 | cargo r8 | 24.4k | +9% | 788 s |
| 42.3 | dog_count r3 * | 800 | +0% | never |
| 43.0 | net_range r14 | 3354 | +12% | 84 s |
| 43.3 | dog_wait r3 * | 2904 | +0% | never |
| 44.7 | net_range r15 | 4259 | +10% | 121 s |
| 44.7 | net_strength r4 | 71.9k | +35% | 551 s |
| 45.0 | boat_speed r16 | 9334 | +2% | 956 s |
| 46.0 | recycle_bonus r7 | 26.1k | +4% | 1084 s |
| 46.7 | net_range r16 * | 5409 | +0% | never |
| 48.7 | reel r14 | 3870 | +0% | 9177 s | filler
| 50.7 | net_width r14 * | 5363 | +0% | 3655 s |
| 52.7 | lucky_haul r9 | 4096 | +0% | never | filler
| 53.3 | net_range r17 | 6870 | +8% | 184 s |
| 54.7 | lucky_haul r10 * | 5571 | +0% | never |
| 55.0 | net_width r15 | 6489 | +3% | 411 s |
| 55.3 | net_range r18 | 8725 | +10% | 202 s |
| 56.7 | net_range r19 | 11.1k | +10% | 282 s |
| 58.0 | boat_speed r17 * | 13.1k | +2% | 1718 s |
| 58.3 | boat_speed r18 * | 18.3k | +2% | 2547 s |
| 58.3 | net_width r16 * | 7852 | +0% | 9431 s |
| 60.3 | reel r15 | 4566 | +0% | 20786 s | filler
| 61.3 | recycle_bonus r8 * | 42.1k | +4% | 2178 s |
| 62.7 | net_width r17 | 9501 | +2% | 973 s |
| 62.7 | net_range r20 * | 14.1k | +0% | never |
| 63.7 | double_cast r9 * | 12.7k | +0% | never |
| 64.7 | net_width r18 | 11.5k | +3% | 944 s |
| 64.7 | net_width r19 | 13.9k | +3% | 1156 s |
| 65.7 | dog_strength r3 * | 5808 | +0% | never |
| 67.3 | boat_speed r19 * | 25.6k | +0% | never |
| 69.3 | reel r16 | 5388 | +1% | 2283 s | filler
| 70.0 | reel r17 * | 6358 | +1% | 2901 s |
| 70.0 | reel r18 * | 7503 | +1% | 3677 s |
| 72.0 | reel r19 | 8853 | +1% | 10528 s | filler
| 73.0 | net_width r20 * | 16.8k | +4% | 7950 s |
| 74.0 | dog_strength r4 * | 12.8k | +0% | never |
| 74.3 | net_hold r6 * | 18.9k | +0% | never |
| 74.3 | reel r20 * | 10.4k | +0% | never |

## Bot: cheapest

- Clear: not cleared
- Purchases: 156, spent 799.8k sludge
- Income/s at 2 / 10 / 30 min: 11.6 / 60.4 / 226.4
- Median payback by phase: 0m 197s, 10m 680s, 20m 2133s, 30m 4471s, 40m 5806s, 50m 22321s, 60m 37s, 70m 1112s
- Median seconds from reveal to buy, by group: cargo 10, boat_speed 20, bird_worth 65, net_range 80, boat_volley 95, fleet 140, dog_count 150, lucky_haul 225, double_cast 290, net_width 325, reel 340, dog_fetch 405, dog_wait 445, net_hold 710, dog_strength 790, recycle_bonus 940, net_strength 1115

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.2 | cargo | 40 | +35% | 23 s |
| 0.3 | boat_speed | 60 | +13% | 68 s |
| 0.5 | boat_speed r2 | 84 | +11% | 105 s |
| 0.8 | cargo r2 | 100 | +25% | 48 s |
| 0.9 | boat_speed r3 | 118 | +7% | 156 s |
| 1.1 | bird_worth | 120 | +0% | 2511 s |
| 1.3 | net_range | 150 | +9% | 154 s |
| 1.6 | boat_volley | 160 | +1% | 1507 s |
| 1.8 | boat_speed r4 | 165 | +7% | 197 s |
| 2.1 | net_range r2 | 191 | +1% | 2264 s |
| 2.3 | fleet | 200 | +69% | 23 s |
| 2.5 | dog_count | 200 | +3% | 360 s |
| 2.7 | bird_worth r2 | 216 | +0% | 2314 s |
| 2.8 | boat_speed r5 | 231 | +0% | never |
| 2.9 | net_range r3 | 242 | +19% | 70 s |
| 3.1 | cargo r3 | 250 | +0% | never |
| 3.3 | net_range r4 | 307 | +15% | 106 s |
| 3.5 | boat_speed r6 | 323 | +0% | never |
| 3.8 | lucky_haul | 350 | +2% | 763 s |
| 4.1 | bird_worth r3 | 389 | +1% | 3233 s |
| 4.3 | net_range r5 | 390 | +12% | 149 s |
| 4.6 | boat_volley r2 | 398 | +0% | never |
| 4.8 | double_cast | 400 | +2% | 875 s |
| 5.2 | dog_count r2 | 400 | +2% | 712 s |
| 5.4 | net_width | 450 | +30% | 62 s |
| 5.7 | reel | 450 | +11% | 133 s |
| 5.9 | boat_speed r7 | 452 | +0% | never |
| 6.1 | lucky_haul r2 | 476 | +2% | 606 s |
| 6.3 | net_range r6 | 496 | +7% | 207 s |
| 6.6 | fleet r2 | 500 | +4% | 382 s |
| 6.8 | dog_fetch | 500 | +5% | 288 s |
| 7.0 | reel r2 | 531 | +8% | 173 s |
| 7.3 | net_width r2 | 545 | +22% | 64 s |
| 7.4 | dog_wait | 600 | +1% | 1385 s |
| 7.7 | double_cast r2 | 616 | +2% | 692 s |
| 7.8 | cargo r4 | 625 | +0% | never |
| 8.1 | reel r3 | 627 | +6% | 218 s |
| 8.3 | net_range r7 | 629 | +11% | 117 s |
| 8.4 | boat_speed r8 | 633 | +0% | never |
| 8.7 | lucky_haul r3 | 647 | +2% | 666 s |
| 8.8 | net_width r3 | 659 | +13% | 100 s |
| 9.1 | bird_worth r4 | 700 | +1% | 1665 s |
| 9.3 | reel r4 | 739 | +5% | 243 s |
| 9.5 | net_width r4 | 797 | +8% | 181 s |
| 9.7 | net_range r8 | 799 | +0% | never |
| 9.9 | dog_count r3 | 800 | +2% | 615 s |
| 10.2 | reel r5 | 872 | +5% | 291 s |
| 10.4 | lucky_haul r4 | 880 | +1% | 964 s |
| 10.6 | boat_speed r9 | 886 | +0% | never |
| 10.8 | dog_fetch r2 | 900 | +1% | 1731 s |
| 11.1 | double_cast r3 | 949 | +2% | 680 s |
| 11.3 | net_width r5 | 965 | +3% | 520 s |
| 11.6 | boat_volley r3 | 992 | +0% | never |
| 11.8 | net_hold | 1000 | +6% | 232 s |
| 12.1 | net_range r9 | 1015 | +0% | 6580 s |
| 12.3 | reel r6 | 1030 | +0% | 4152 s |
| 12.6 | net_width r6 | 1167 | +1% | 1444 s |
| 12.8 | lucky_haul r5 | 1197 | +0% | never |
| 13.2 | dog_strength | 1200 | +0% | never |
| 13.4 | reel r7 | 1215 | +0% | 4778 s |
| 13.7 | boat_speed r10 | 1240 | +3% | 560 s |
| 14.0 | fleet r3 | 1250 | +30% | 55 s |
| 14.3 | bird_worth r5 | 1260 | +1% | 1405 s |
| 14.4 | net_range r10 | 1289 | +11% | 132 s |
| 14.7 | dog_wait r2 | 1320 | +1% | 1615 s |
| 14.9 | net_width r7 | 1412 | +6% | 243 s |
| 15.2 | reel r8 | 1434 | +2% | 627 s |
| 15.4 | double_cast r4 | 1461 | +2% | 994 s |
| 15.7 | recycle_bonus | 1500 | +6% | 306 s |
| 15.9 | cargo r5 | 1563 | +0% | never |
| 16.1 | dog_fetch r3 | 1620 | +0% | never |
| 16.3 | lucky_haul r6 | 1628 | +4% | 512 s |
| 16.7 | net_range r11 | 1637 | +22% | 103 s |
| 17.0 | reel r9 | 1692 | +3% | 780 s |
| 17.3 | net_width r8 | 1709 | +6% | 340 s |
| 17.6 | boat_speed r11 | 1736 | +0% | never |
| 17.9 | net_hold r2 | 1800 | +11% | 213 s |
| 18.3 | reel r10 | 1996 | +2% | 1081 s |
| 18.6 | net_strength | 2000 | +117% | 22 s |
| 18.8 | net_width r9 | 2068 | +1% | 1674 s |
| 19.0 | net_range r12 | 2079 | +0% | never |
| 19.3 | lucky_haul r7 | 2215 | +0% | never |
| 19.5 | double_cast r5 | 2250 | +0% | 5573 s |
| 19.7 | bird_worth r6 | 2268 | +1% | 1445 s |
| 19.9 | reel r11 | 2355 | +0% | 6012 s |
| 20.2 | recycle_bonus r2 | 2415 | +5% | 265 s |
| 20.4 | boat_speed r12 | 2430 | +2% | 544 s |
| 20.6 | boat_volley r4 | 2470 | +2% | 613 s |
| 20.8 | net_width r10 | 2502 | +1% | 1648 s |
| 21.1 | dog_strength r2 | 2640 | +0% | never |
| 21.3 | net_range r13 | 2641 | +0% | never |
| 21.6 | reel r12 | 2779 | +0% | 7254 s |
| 21.8 | dog_wait r3 | 2904 | +0% | never |
| 22.1 | dog_fetch r4 | 2916 | +0% | never |
| 22.3 | lucky_haul r8 | 3012 | +0% | never |
| 22.6 | net_width r11 | 3027 | +1% | 1899 s |
| 22.9 | net_hold r3 | 3240 | +0% | never |
| 23.2 | reel r13 | 3279 | +0% | 8135 s |
| 23.5 | net_range r14 | 3354 | +0% | never |
| 23.8 | boat_speed r13 | 3402 | +2% | 813 s |
| 24.1 | double_cast r6 | 3465 | +0% | 5718 s |
| 24.4 | net_width r12 | 3663 | +1% | 2133 s |
| 24.8 | reel r14 | 3870 | +0% | 9000 s |
| 25.1 | recycle_bonus r3 | 3888 | +5% | 417 s |
| 25.4 | cargo r6 | 3906 | +11% | 183 s |
| 25.8 | bird_worth r7 | 4082 | +1% | 1705 s |
| 26.0 | lucky_haul r9 | 4096 | +0% | never |
| 26.3 | net_range r15 | 4259 | +0% | never |
| 26.7 | net_width r13 | 4432 | +1% | 2231 s |
| 27.0 | reel r15 | 4566 | +0% | 9358 s |
| 27.4 | boat_speed r14 | 4762 | +2% | 1073 s |
| 27.8 | double_cast r7 | 5336 | +0% | 5813 s |
| 28.2 | net_width r14 | 5363 | +1% | 2457 s |
| 28.6 | reel r16 | 5388 | +0% | 10296 s |
| 28.9 | net_range r16 | 5409 | +0% | never |
| 29.3 | lucky_haul r10 | 5571 | +0% | never |
| 29.8 | dog_strength r3 | 5808 | +0% | never |
| 30.3 | net_hold r4 | 5832 | +0% | never |
| 30.7 | recycle_bonus r4 | 6260 | +5% | 620 s |
| 31.2 | reel r17 | 6358 | +0% | 12503 s |
| 31.6 | net_width r15 | 6489 | +1% | 2793 s |
| 32.1 | net_strength r2 | 6600 | +74% | 47 s |
| 32.5 | boat_speed r15 | 6667 | +2% | 976 s |
| 32.8 | net_range r17 | 6870 | +0% | never |
| 33.2 | bird_worth r8 | 7347 | +1% | 2443 s |
| 33.5 | reel r18 | 7503 | +0% | 15321 s |
| 33.9 | net_width r16 | 7852 | +1% | 3612 s |
| 34.3 | double_cast r8 | 8217 | +0% | 7230 s |
| 34.7 | net_range r18 | 8725 | +0% | never |
| 35.1 | reel r19 | 8853 | +0% | 24436 s |
| 35.6 | boat_speed r16 | 9334 | +2% | 1583 s |
| 36.0 | net_width r17 | 9501 | +1% | 5329 s |
| 36.5 | cargo r7 | 9766 | +10% | 304 s |
| 37.0 | recycle_bonus r5 | 10.1k | +5% | 600 s |
| 37.4 | reel r20 | 10.4k | +0% | never |
| 37.9 | net_hold r5 | 10.5k | +0% | never |
| 38.3 | net_range r19 | 11.1k | +0% | never |
| 38.9 | net_width r18 | 11.5k | +0% | 10252 s |
| 39.4 | double_cast r9 | 12.7k | +0% | 14821 s |
| 40.1 | dog_strength r4 | 12.8k | +0% | never |
| 40.7 | boat_speed r17 | 13.1k | +2% | 2274 s |
| 41.3 | net_width r19 | 13.9k | +0% | 9339 s |
| 42.0 | net_range r20 | 14.1k | +0% | never |
| 42.8 | recycle_bonus r6 | 16.2k | +4% | 1103 s |
| 43.6 | net_width r20 | 16.8k | +0% | 13482 s |
| 44.5 | boat_speed r18 | 18.3k | +0% | never |
| 45.3 | net_hold r6 | 18.9k | +0% | never |
| 54.5 | double_cast r10 | 19.5k | +4% | 22321 s |
| 69.4 | net_strength r3 | 21.8k | +2452% | 37 s |
| 70.1 | cargo r8 | 24.4k | +9% | 436 s |
| 70.8 | boat_speed r19 | 25.6k | +1% | 2553 s |
| 71.4 | recycle_bonus r7 | 26.1k | +4% | 1112 s |
| 72.2 | net_hold r7 | 34.0k | +0% | never |
| 95.2 | boat_speed r20 | 35.9k | +0% | never |
| 150.2 | recycle_bonus r8 | 42.1k | +0% | never |
| 230.2 | net_hold r8 | 61.2k | +0% | never |
