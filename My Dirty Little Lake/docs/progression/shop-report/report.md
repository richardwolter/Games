# Progression sim: My Dirty Little Lake (shop, 2026-09-18 pass)

## Checks

| | check | result |
|---|---|---|
| PASS | focused clears in 48-68 min | 49.9 min (cleared 99.5%) |
| PASS | focused can always finish (no soft-lock) | finishes |
| PASS | early buys every 10-60 s (first 10 min) | median gap 15 s |
| PASS | no gap between buys over 300 s | longest 120 s at 31.8-33.8 min |
| WARN | last purchase leaves 10-25% of the game to enjoy it | last buy at 49.7 min, 1% of the game after it |
| FAIL | every buy raises income at least 8% | net_range +5.8%, boat_speed r4 +5.5%, dog_count +1.9%, reel +4.7%, boat_speed r5 +5.9%, net_width r2 +6.0% |
| PASS | no single pick wins by 3x in over 50% of choices | median best/second 1.42x; over 3x in 7%; "net_strength" top pick 45% |
| FAIL | payback within 4x of its phase median | cargo too strong for price (21 s vs 168 s); fleet r2 too strong for price (22 s vs 168 s); fleet r3 too strong for price (29 s vs 314 s); cargo r5 too strong for price (68 s vs 314 s); net_range r9 too strong for price (81 s vs 594 s); net_range r13 too strong for price (129 s vs 594 s) |
| WARN | ferry capacity within 1-2.5x of catch rate | inside 52%, lagging 39%, overrunning 9%; box peaked at 1013 |
| PASS | single upgrades are felt (no stage locked against another) | none |
| PASS | no bought node whose only value is what it unlocks | none |
| FAIL | every node earns its purchase, none only in the last 15% | 6 bought only as filler (earned nothing); 0 never bought; 0 first bought late |

## Bot: focused

- Clear: 49.9 min
- Purchases: 134, spent 483.6k sludge
- Income/s at 2 / 10 / 30 min: 12.3 / 83.3 / 585.4
- Median payback by phase: 0m 168s, 10m 314s, 20m 594s, 30m 514s, 40m 842s
- Median seconds from reveal to buy, by group: cargo 10, boat_speed 20, bird_worth 45, net_range 60, fleet 140, net_width 205, dog_count 235, reel 280, net_strength 430, boat_volley 445, recycle_bonus 470, lucky_haul 480, double_cast 510, dog_fetch 635, net_hold 740, dog_wait 1310, dog_strength 2385

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.2 | cargo | 40 | +35% | 21 s |
| 0.3 | boat_speed | 60 | +13% | 62 s |
| 0.5 | boat_speed r2 | 84 | +11% | 96 s |
| 0.8 | bird_worth | 120 | from zero | never |
| 1.0 | net_range | 150 | +6% | 295 s |
| 1.2 | cargo r2 | 100 | +25% | 44 s |
| 1.3 | boat_speed r3 | 118 | +9% | 119 s |
| 1.6 | boat_speed r4 | 165 | +5% | 240 s |
| 1.8 | bird_worth r2 | 216 | from zero | never |
| 2.1 | net_range r2 | 191 | +9% | 168 s |
| 2.3 | fleet | 200 | +18% | 82 s |
| 2.5 | net_range r3 | 242 | +20% | 84 s |
| 2.8 | net_range r4 | 307 | +14% | 128 s |
| 3.1 | bird_worth r3 | 389 | from zero | never |
| 3.4 | net_width | 450 | +32% | 74 s |
| 3.7 | net_range r5 | 390 | +11% | 146 s |
| 3.9 | dog_count | 200 | +2% | 384 s |
| 4.3 | bird_worth r4 | 700 | from zero | never |
| 4.7 | reel | 450 | +5% | 361 s |
| 4.7 | boat_speed r5 | 231 | +6% | 141 s |
| 5.3 | net_width r2 | 545 | +6% | 324 s |
| 5.3 | cargo r3 | 250 | +17% | 50 s |
| 5.8 | bird_worth r5 | 1260 | from zero | never |
| 6.0 | net_range r6 | 496 | +8% | 180 s |
| 6.2 | boat_speed r6 | 323 | +3% | 338 s |
| 6.5 | reel r2 | 531 | +6% | 252 s |
| 7.2 | net_strength | 1700 | +28% | 167 s |
| 7.3 | fleet r2 | 500 | +48% | 22 s |
| 7.4 | boat_volley | 160 | +1% | 173 s |
| 7.5 | boat_speed r7 | 452 | +5% | 142 s |
| 7.8 | recycle_bonus | 1500 | +6% | 338 s |
| 8.0 | lucky_haul | 350 | +1% | 536 s |
| 8.4 | bird_worth r6 | 2268 | from zero | never |
| 8.5 | double_cast | 400 | +1% | 602 s |
| 8.6 | boat_volley r2 | 398 | +1% | 491 s |
| 8.8 | lucky_haul r2 | 476 | +1% | 635 s |
| 9.2 | recycle_bonus r2 | 2415 | +6% | 536 s |
| 10.0 | bird_worth r7 | 4082 | from zero | never |
| 10.1 | reel r3 | 627 | +2% | 485 s |
| 10.3 | cargo r4 | 625 | +6% | 130 s |
| 10.4 | reel r4 | 739 | +6% | 150 s |
| 10.5 | reel r5 | 872 | +5% | 206 s |
| 10.6 | dog_fetch | 500 | +1% | 351 s |
| 10.8 | net_width r3 | 659 | +2% | 295 s |
| 10.8 | boat_speed r8 | 633 | +3% | 223 s |
| 11.1 | double_cast r2 | 616 | +1% | 424 s |
| 11.7 | net_width r4 | 797 | +2% | 377 s |
| 12.0 | net_strength r2 | 5899 | +24% | 239 s |
| 12.2 | boat_speed r9 | 886 | +1% | 530 s |
| 12.2 | dog_count r2 | 400 | +1% | 281 s |
| 12.3 | net_hold | 1000 | +1% | 524 s |
| 12.5 | fleet r3 | 1250 | +32% | 29 s |
| 12.7 | cargo r5 | 1563 | +13% | 68 s |
| 12.8 | boat_speed r10 | 1240 | +3% | 197 s |
| 12.8 | boat_volley r3 | 992 | +2% | 226 s |
| 13.2 | cargo r6 | 3906 | +12% | 162 s |
| 13.3 | boat_speed r11 | 1736 | +3% | 257 s |
| 13.3 | net_width r5 | 965 | +2% | 248 s |
| 13.5 | boat_speed r12 | 2430 | +3% | 386 s |
| 13.7 | lucky_haul r3 | 647 | +1% | 322 s |
| 13.8 | net_width r6 | 1167 | +2% | 265 s |
| 13.8 | boat_volley r4 | 2470 | +3% | 392 s |
| 13.9 | double_cast r3 | 949 | +1% | 310 s |
| 14.1 | reel r6 | 1030 | +2% | 248 s |
| 14.2 | recycle_bonus r3 | 3888 | +5% | 283 s |
| 14.3 | lucky_haul r4 | 880 | +1% | 354 s |
| 14.3 | net_width r7 | 1412 | +2% | 282 s |
| 14.7 | reel r7 | 1215 | +1% | 318 s |
| 14.8 | recycle_bonus r4 | 6260 | +5% | 456 s |
| 14.8 | reel r8 | 1434 | +2% | 257 s |
| 14.9 | double_cast r4 | 1461 | +2% | 328 s |
| 15.0 | lucky_haul r5 | 1197 | +1% | 351 s |
| 15.2 | net_width r8 | 1709 | +5% | 137 s |
| 15.3 | net_width r9 | 2068 | +2% | 438 s |
| 15.4 | boat_speed r13 | 3402 | +2% | 514 s |
| 15.5 | reel r9 | 1692 | +2% | 354 s |
| 15.7 | net_range r7 | 629 | +2% | 103 s |
| 16.0 | bird_worth r8 | 7347 | from zero | never |
| 16.8 | lucky_haul r6 | 1628 | +1% | 400 s |
| 16.9 | net_width r10 | 2502 | +3% | 314 s |
| 17.1 | net_hold r2 | 1800 | +2% | 309 s |
| 17.2 | net_range r8 | 799 | +1% | 341 s |
| 17.2 | cargo r7 | 9766 | +10% | 348 s |
| 18.1 | net_strength r3 | 20.5k | +23% | 292 s |
| 18.3 | boat_speed r14 | 4762 | +2% | 553 s |
| 18.6 | boat_speed r15 | 6667 | +2% | 819 s |
| 19.0 | recycle_bonus r5 | 10.1k | +5% | 508 s |
| 19.6 | boat_speed r16 | 9334 | +2% | 1158 s |
| 19.8 | net_width r11 | 3027 | +2% | 315 s |
| 19.8 | dog_count r3 | 800 | +0% | 481 s |
| 19.9 | net_width r12 | 3663 | +4% | 233 s |
| 20.0 | lucky_haul r7 | 2215 | +2% | 290 s |
| 20.0 | reel r10 | 1996 | +1% | 409 s |
| 20.1 | net_width r13 | 4432 | +4% | 280 s |
| 20.2 | lucky_haul r8 | 3012 | +2% | 351 s |
| 20.2 | reel r11 | 2355 | +1% | 544 s |
| 20.3 | double_cast r5 | 2250 | +1% | 603 s |
| 20.4 | net_range r9 | 1015 | +3% | 81 s |
| 20.9 | recycle_bonus r6 | 16.2k | +4% | 885 s |
| 21.8 | net_width r14 | 5363 | +3% | 412 s |
| 21.8 | dog_wait | 600 | +0% | 689 s |
| 21.9 | net_range r10 | 1289 | +1% | 325 s |
| 22.2 | cargo r8 | 24.4k | +9% | 688 s |
| 23.2 | net_range r11 | 1637 | +2% | 164 s |
| 24.6 | net_range r12 | 2079 | +1% | 644 s |
| 25.0 | net_strength r4 | 71.0k | +28% | 594 s |
| 25.2 | net_hold r3 | 3240 | +1% | 638 s |
| 25.9 | recycle_bonus r7 | 26.1k | +4% | 1010 s |
| 27.7 | boat_speed r17 | 13.1k | +2% | 1200 s |
| 27.8 | net_width r15 | 6489 | +3% | 381 s |
| 27.8 | double_cast r6 | 3465 | +1% | 462 s |
| 27.8 | net_width r16 | 7852 | +3% | 482 s |
| 27.8 | reel r12 | 2779 | +1% | 508 s |
| 27.8 | reel r13 | 3279 | +1% | 659 s |
| 27.9 | net_width r17 | 9501 | +2% | 613 s |
| 27.9 | double_cast r7 | 5336 | +1% | 688 s |
| 27.9 | reel r14 | 3870 | +1% | 865 s |
| 28.0 | net_width r18 | 11.5k | +2% | 785 s |
| 28.0 | double_cast r8 | 8217 | +1% | 1040 s |
| 28.3 | net_range r13 | 2641 | +4% | 129 s |
| 30.0 | net_range r14 | 3354 | +5% | 138 s |
| 31.8 | net_range r15 | 4259 | +1% | 892 s |
| 33.8 | net_range r16 | 5409 | +5% | 241 s |
| 35.7 | net_range r17 | 6870 | +2% | 807 s |
| 37.7 | dog_fetch r2 | 900 | +0% | never | filler
| 37.8 | net_range r18 | 8725 | +3% | 606 s |
| 39.8 | dog_strength | 1200 | +0% | never | filler
| 39.9 | net_range r19 | 11.1k | +6% | 422 s |
| 41.9 | dog_wait r2 | 1320 | +0% | never | filler
| 42.1 | net_range r20 | 14.1k | +5% | 573 s |
| 43.7 | reel r15 | 4566 | +1% | 1111 s |
| 45.7 | dog_fetch r3 | 1620 | +0% | never | filler
| 47.7 | dog_strength r2 | 2640 | +0% | never | filler
| 49.7 | dog_wait r3 | 2904 | +0% | never | filler
