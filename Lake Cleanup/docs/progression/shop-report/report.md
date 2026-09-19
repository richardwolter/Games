# Progression sim: Lake Cleanup (shop, 2026-09-18 pass)

## Checks

| | check | result |
|---|---|---|
| FAIL | focused clears in 68-82 min | 59.7 min (cleared 99.5%) |
| PASS | focused can always finish (no soft-lock) | finishes |
| PASS | casual can always finish (no soft-lock) | finishes |
| PASS | cheapest can always finish (no soft-lock) | finishes |
| PASS | early buys every 10-60 s (first 10 min) | median gap 10 s |
| PASS | no gap between buys over 300 s | longest 120 s at 30.3-32.3 min |
| WARN | last purchase leaves 10-25% of the game to enjoy it | last buy at 59.0 min, 1% of the game after it |
| FAIL | every buy raises income at least 8% | net_range r2 +3.0%, net_range r3 +5.5%, boat_speed r4 +7.5%, boat_volley +0.6%, dog_count +2.2%, net_range r4 +3.5% |
| WARN | no single pick wins by 3x in over 50% of choices | median best/second 1.73x; over 3x in 3%; "net_strength" top pick 62% |
| FAIL | payback within 4x of its phase median | cargo too strong for price (23 s vs 224 s); fleet too strong for price (31 s vs 224 s); boat_speed too strong for price (33 s vs 224 s); cargo r2 too strong for price (35 s vs 224 s); boat_speed r2 too strong for price (40 s vs 224 s); cargo r4 too strong for price (44 s vs 402 s) |
| PASS | ferry capacity within 1-2.5x of catch rate | inside 88%, lagging 8%, overrunning 3%; box peaked at 31 |
| WARN | single upgrades are felt (no stage locked against another) | 1 buys only paid off with another: net_range+boat_speed @37.3 |
| PASS | no bought node whose only value is what it unlocks | none |
| FAIL | every node earns its purchase, none only in the last 15% | 8 bought only as filler (earned nothing); 0 never bought; 0 first bought late |

## Bot: focused

- Clear: 59.7 min
- Purchases: 137, spent 478.8k sludge
- Income/s at 2 / 10 / 30 min: 12.0 / 59.1 / 299.2
- Median payback by phase: 0m 224s, 10m 402s, 20m 631s, 30m 990s, 40m 770s, 50m 949s
- Median seconds from reveal to buy, by group: cargo 10, bird_worth 30, fleet 90, boat_speed 95, net_range 110, boat_volley 160, dog_count 170, lucky_haul 260, net_width 280, reel 310, dog_fetch 360, net_strength 580, double_cast 590, recycle_bonus 620, net_hold 800, dog_wait 860, dog_strength 2470

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.2 | cargo | 40 | +36% | 23 s |
| 0.5 | bird_worth | 120 | from zero | never |
| 1.0 | bird_worth r2 | 216 | from zero | never |
| 1.5 | fleet | 200 | +98% | 31 s |
| 1.6 | boat_speed | 60 | +14% | 33 s |
| 1.8 | cargo r2 | 100 | +19% | 35 s |
| 1.8 | net_range | 150 | +9% | 94 s |
| 1.9 | boat_speed r2 | 84 | +11% | 40 s |
| 2.1 | boat_speed r3 | 118 | +8% | 69 s |
| 2.2 | net_range r2 | 191 | +3% | 281 s |
| 2.3 | cargo r3 | 250 | +18% | 60 s |
| 2.5 | net_range r3 | 242 | +6% | 167 s |
| 2.6 | boat_speed r4 | 165 | +7% | 80 s |
| 2.7 | boat_volley | 160 | +1% | 853 s |
| 2.8 | dog_count | 200 | +2% | 316 s |
| 3.0 | bird_worth r3 | 389 | from zero | never |
| 3.2 | net_range r4 | 307 | +3% | 306 s |
| 3.3 | boat_speed r5 | 231 | +6% | 120 s |
| 3.7 | bird_worth r4 | 700 | from zero | never |
| 3.9 | net_range r5 | 390 | +6% | 228 s |
| 4.3 | lucky_haul | 350 | +2% | 656 s |
| 4.7 | net_width | 450 | +3% | 541 s |
| 5.0 | bird_worth r5 | 1260 | from zero | never |
| 5.2 | reel | 450 | +2% | 579 s |
| 5.3 | boat_speed r6 | 323 | +5% | 183 s |
| 5.6 | fleet r2 | 500 | +7% | 209 s |
| 5.8 | reel r2 | 531 | +10% | 152 s |
| 6.0 | dog_fetch | 500 | +6% | 219 s |
| 6.2 | dog_count r2 | 400 | +6% | 175 s |
| 6.4 | reel r3 | 627 | +6% | 233 s |
| 6.6 | lucky_haul r2 | 476 | +3% | 411 s |
| 6.8 | reel r4 | 739 | +5% | 351 s |
| 7.0 | net_width r2 | 545 | +4% | 260 s |
| 7.7 | dog_count r3 | 800 | +4% | 380 s |
| 8.1 | bird_worth r6 | 2268 | from zero | never |
| 8.3 | net_width r3 | 659 | +4% | 303 s |
| 9.3 | net_width r4 | 797 | +5% | 299 s |
| 9.7 | net_strength | 3500 | +36% | 190 s |
| 9.8 | boat_speed r7 | 452 | +2% | 294 s |
| 9.8 | double_cast | 400 | +2% | 322 s |
| 10.0 | double_cast r2 | 616 | +1% | 570 s |
| 10.3 | recycle_bonus | 1500 | +6% | 339 s |
| 10.8 | recycle_bonus r2 | 2415 | +6% | 546 s |
| 11.7 | bird_worth r7 | 4082 | from zero | never |
| 12.5 | recycle_bonus r3 | 3888 | +5% | 881 s |
| 13.3 | net_hold | 1000 | +1% | 1012 s |
| 13.3 | cargo r4 | 625 | +16% | 44 s |
| 13.3 | boat_speed r8 | 633 | +2% | 322 s |
| 13.3 | lucky_haul r3 | 647 | +2% | 282 s |
| 14.3 | bird_worth r8 | 7347 | from zero | never |
| 14.3 | dog_wait | 600 | +1% | 479 s |
| 14.5 | net_width r5 | 965 | +2% | 546 s |
| 14.6 | boat_volley r2 | 398 | +1% | 421 s |
| 14.8 | reel r5 | 872 | +1% | 598 s |
| 14.8 | boat_speed r9 | 886 | +2% | 392 s |
| 15.0 | net_width r6 | 1167 | +4% | 287 s |
| 15.2 | lucky_haul r4 | 880 | +2% | 432 s |
| 15.3 | double_cast r3 | 949 | +2% | 508 s |
| 15.5 | reel r6 | 1030 | +2% | 383 s |
| 15.7 | net_width r7 | 1412 | +3% | 391 s |
| 15.9 | net_width r8 | 1709 | +4% | 434 s |
| 16.1 | lucky_haul r5 | 1197 | +2% | 455 s |
| 16.3 | net_range r6 | 496 | +1% | 344 s |
| 16.3 | fleet r3 | 1250 | +12% | 98 s |
| 16.5 | net_hold r2 | 1820 | +14% | 107 s |
| 16.7 | reel r7 | 1215 | +3% | 338 s |
| 17.3 | net_range r7 | 629 | +2% | 263 s |
| 17.3 | net_hold r3 | 3312 | +10% | 248 s |
| 17.3 | boat_speed r10 | 1240 | +2% | 402 s |
| 18.4 | net_strength r2 | 9590 | +38% | 181 s |
| 18.5 | reel r8 | 1434 | +1% | 527 s |
| 18.6 | boat_volley r3 | 992 | +1% | 533 s |
| 19.2 | recycle_bonus r4 | 6260 | +5% | 635 s |
| 19.7 | cargo r5 | 1563 | +1% | 1183 s |
| 19.7 | double_cast r4 | 1461 | +2% | 291 s |
| 19.7 | reel r9 | 1692 | +2% | 341 s |
| 19.7 | lucky_haul r6 | 1628 | +2% | 430 s |
| 19.8 | double_cast r5 | 2250 | +3% | 397 s |
| 19.9 | dog_fetch r2 | 900 | +1% | 700 s |
| 20.1 | reel r10 | 1996 | +2% | 434 s |
| 20.3 | lucky_haul r7 | 2215 | +2% | 546 s |
| 20.4 | reel r11 | 2355 | +2% | 670 s |
| 20.7 | reel r12 | 2779 | +1% | 928 s |
| 20.8 | net_width r9 | 2068 | +1% | 802 s |
| 21.0 | double_cast r6 | 3465 | +2% | 631 s |
| 21.2 | net_width r10 | 2502 | +2% | 589 s |
| 21.3 | net_width r11 | 3027 | +2% | 711 s |
| 21.8 | net_range r8 | 799 | +1% | 309 s |
| 21.8 | net_hold r4 | 6029 | +5% | 594 s |
| 22.0 | boat_speed r11 | 1736 | +3% | 260 s |
| 22.2 | boat_speed r12 | 2430 | +3% | 388 s |
| 23.2 | net_range r9 | 1015 | +2% | 241 s |
| 23.2 | double_cast r7 | 5336 | +3% | 807 s |
| 24.5 | net_strength r3 | 26.3k | +35% | 344 s |
| 24.7 | lucky_haul r8 | 3012 | +2% | 638 s |
| 24.8 | reel r13 | 3279 | +1% | 729 s |
| 25.4 | recycle_bonus r5 | 10.1k | +5% | 693 s |
| 26.2 | net_width r12 | 3663 | +1% | 996 s |
| 26.3 | reel r14 | 3870 | +1% | 1121 s |
| 26.4 | lucky_haul r9 | 4096 | +2% | 837 s |
| 26.5 | net_width r13 | 4432 | +2% | 880 s |
| 26.6 | lucky_haul r10 | 5571 | +2% | 1060 s |
| 27.2 | net_range r10 | 1289 | +1% | 381 s |
| 27.2 | cargo r6 | 3906 | +4% | 330 s |
| 27.3 | net_hold r5 | 11.0k | +8% | 458 s |
| 27.5 | boat_volley r4 | 2470 | +1% | 602 s |
| 28.5 | net_range r11 | 1637 | +2% | 264 s |
| 28.5 | double_cast r8 | 8217 | +3% | 920 s |
| 30.3 | net_range r12 | 2079 | +2% | 457 s |
| 30.3 | reel r15 | 4566 | +2% | 1050 s |
| 32.3 | net_range r13 | 2641 | +2% | 456 s |
| 32.6 | net_strength r4 | 72.0k | +43% | 610 s |
| 32.8 | reel r16 | 5388 | +1% | 944 s |
| 33.3 | double_cast r9 | 12.7k | +3% | 990 s |
| 33.6 | reel r17 | 6358 | +1% | 1167 s |
| 34.3 | recycle_bonus r6 | 16.2k | +5% | 859 s |
| 36.3 | net_width r14 | 5363 | +1% | 1192 s |
| 36.6 | net_width r15 | 6489 | +2% | 1012 s |
| 36.7 | net_hold r6 | 20.0k | +4% | 1097 s |
| 36.8 | net_width r16 | 7852 | +2% | 1141 s |
| 36.9 | net_width r17 | 9501 | +2% | 1053 s |
| 37.3 | net_range r14 (with boat_speed) | 3354 | +1% | 589 s |
| 37.3 | cargo r7 | 9766 | +9% | 271 s |
| 39.2 | net_range r15 | 4259 | +2% | 559 s |
| 41.2 | dog_strength | 1200 | +0% | never | filler
| 41.5 | net_range r16 | 5409 | +2% | 720 s |
| 43.5 | dog_wait r2 | 1320 | +0% | never | filler
| 44.1 | net_range r17 | 6870 | +3% | 717 s |
| 46.1 | dog_fetch r3 | 1620 | +0% | never | filler
| 46.8 | net_range r18 | 8725 | +3% | 890 s |
| 48.8 | dog_strength r2 | 2640 | +0% | never | filler
| 49.8 | net_range r19 | 11.1k | +5% | 820 s |
| 51.8 | dog_wait r3 | 2904 | +0% | never | filler
| 53.0 | net_range r20 | 14.1k | +5% | 949 s |
| 55.0 | dog_fetch r4 | 2916 | +0% | never | filler
| 57.0 | boat_speed r13 | 3402 | +0% | never | filler
| 59.0 | boat_speed r14 | 4762 | +0% | never | filler

## Bot: casual

- Clear: 102.1 min (seeds: 101, 102, 102)
- Purchases: 156, spent 854.0k sludge
- Income/s at 2 / 10 / 30 min: 10.2 / 4.4 / 2.3
- Median payback by phase: 0m 168s, 10m 332s, 20m 511s, 30m 572s, 40m 883s, 50m 1392s, 60m 1954s, 70m 1078s, 80m 951s, 90m 36410s
- Median seconds from reveal to buy, by group: cargo 20, bird_worth 40, boat_speed 40, fleet 100, net_range 120, boat_volley 180, dog_count 200, net_width 280, dog_wait 300, reel 320, lucky_haul 400, double_cast 520, dog_fetch 740, net_strength 920, net_hold 940, recycle_bonus 1220, dog_strength 2820

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.3 | cargo | 40 | +36% | 23 s |
| 0.7 | bird_worth | 120 | from zero | never |
| 0.7 | boat_speed * | 60 | +14% | 66 s |
| 1.3 | bird_worth r2 | 216 | from zero | never |
| 1.7 | fleet | 200 | +98% | 27 s |
| 2.0 | boat_speed r2 | 84 | +3% | 222 s |
| 2.0 | net_range | 150 | +9% | 112 s |
| 2.0 | cargo r2 | 100 | +26% | 23 s |
| 2.3 | bird_worth r3 | 389 | from zero | never |
| 2.7 | net_range r2 | 191 | +18% | 59 s |
| 2.7 | boat_speed r3 | 118 | +7% | 78 s |
| 3.0 | net_range r3 | 242 | +7% | 153 s |
| 3.0 | boat_volley * | 160 | +0% | 1436 s |
| 3.0 | boat_speed r4 | 165 | +8% | 94 s |
| 3.3 | dog_count | 200 | +1% | 862 s |
| 3.3 | boat_speed r5 | 231 | +3% | 267 s |
| 3.7 | dog_count r2 * | 400 | +4% | 365 s |
| 4.0 | bird_worth r4 | 700 | from zero | never |
| 4.3 | net_range r4 | 307 | +12% | 107 s |
| 4.3 | cargo r3 | 250 | +3% | 317 s |
| 4.7 | net_width | 450 | +17% | 102 s |
| 5.0 | dog_wait * | 600 | +1% | 1407 s |
| 5.3 | reel | 450 | +6% | 229 s |
| 5.3 | boat_speed r6 | 323 | +5% | 183 s |
| 6.0 | bird_worth r5 | 1260 | from zero | never |
| 6.7 | lucky_haul | 350 | +2% | 437 s |
| 8.7 | double_cast | 400 | +2% | 721 s |
| 10.3 | net_range r5 | 390 | +5% | 243 s |
| 11.3 | bird_worth r6 | 2268 | from zero | never |
| 12.0 | reel r2 | 531 | +5% | 332 s |
| 12.0 | boat_speed r7 | 452 | +4% | 357 s |
| 12.3 | net_width r2 | 545 | +4% | 376 s |
| 12.3 | fleet r2 | 500 | +4% | 345 s |
| 12.3 | dog_fetch | 500 | +10% | 130 s |
| 12.7 | reel r3 | 627 | +6% | 249 s |
| 13.0 | dog_count r3 | 800 | +6% | 311 s |
| 13.3 | net_width r3 | 659 | +4% | 355 s |
| 13.3 | lucky_haul r2 * | 476 | +2% | 437 s |
| 13.7 | boat_speed r8 * | 633 | +0% | never |
| 14.0 | reel r4 | 739 | +4% | 378 s |
| 14.3 | net_width r4 | 797 | +5% | 323 s |
| 15.3 | net_strength | 3500 | +47% | 163 s |
| 15.7 | net_hold | 1000 | +14% | 105 s |
| 15.7 | cargo r4 | 625 | +4% | 186 s |
| 16.0 | reel r5 | 872 | +4% | 274 s |
| 16.0 | lucky_haul r3 | 647 | +2% | 351 s |
| 16.3 | boat_volley r2 * | 398 | +0% | never |
| 17.3 | double_cast r2 | 616 | +2% | 368 s |
| 19.0 | reel r6 | 1030 | +3% | 365 s |
| 20.3 | recycle_bonus | 1500 | +6% | 275 s |
| 20.3 | lucky_haul r4 | 880 | +1% | 651 s |
| 21.0 | recycle_bonus r2 | 2415 | +6% | 437 s |
| 21.0 | net_range r6 * | 496 | +0% | never |
| 21.0 | double_cast r3 | 949 | +2% | 472 s |
| 21.3 | reel r7 | 1215 | +2% | 743 s |
| 21.3 | net_range r7 * | 629 | +0% | never |
| 21.7 | lucky_haul r5 | 1197 | +2% | 567 s |
| 22.3 | bird_worth r7 | 4082 | from zero | never |
| 23.0 | boat_volley r3 * | 992 | +0% | never |
| 23.0 | dog_fetch r2 | 900 | +1% | 827 s |
| 23.3 | recycle_bonus r3 | 3888 | +5% | 739 s |
| 24.0 | net_hold r2 | 1820 | +5% | 395 s |
| 24.0 | fleet r3 | 1250 | +10% | 117 s |
| 24.0 | dog_fetch r3 * | 1620 | +0% | never |
| 24.7 | net_hold r3 | 3312 | +14% | 216 s |
| 24.7 | double_cast r4 * | 1461 | +3% | 464 s |
| 25.0 | net_width r5 * | 965 | +0% | 1591 s |
| 25.0 | reel r8 | 1434 | +3% | 392 s |
| 25.7 | cargo r5 * | 1563 | +0% | never |
| 27.0 | net_width r6 | 1167 | +2% | 490 s |
| 27.0 | reel r9 | 1692 | +2% | 531 s |
| 27.0 | double_cast r5 | 2250 | +3% | 627 s |
| 27.0 | net_width r7 * | 1412 | +1% | 1600 s |
| 30.3 | net_range r8 * | 799 | +0% | never |
| 31.0 | net_hold r4 | 6029 | +12% | 377 s |
| 31.0 | boat_speed r9 * | 886 | +0% | never |
| 32.0 | bird_worth r8 | 7347 | from zero | never |
| 32.7 | net_width r8 * | 1709 | +5% | 262 s |
| 32.7 | net_range r9 | 1015 | +5% | 148 s |
| 33.3 | net_strength r2 | 9590 | +33% | 210 s |
| 33.7 | reel r10 | 1996 | +2% | 449 s |
| 33.7 | lucky_haul r6 | 1628 | +2% | 542 s |
| 34.0 | reel r11 | 2355 | +2% | 582 s |
| 34.0 | lucky_haul r7 | 2215 | +2% | 688 s |
| 34.3 | double_cast r6 | 3465 | +3% | 604 s |
| 34.7 | reel r12 | 2779 | +2% | 728 s |
| 35.0 | double_cast r7 | 5336 | +3% | 844 s |
| 35.3 | lucky_haul r8 | 3012 | +2% | 878 s |
| 35.7 | reel r13 | 3279 | +2% | 906 s |
| 36.0 | recycle_bonus r4 | 6260 | +5% | 562 s |
| 40.7 | recycle_bonus r5 * | 10.1k | +5% | 905 s |
| 41.3 | net_width r9 | 2068 | +2% | 454 s |
| 41.7 | dog_wait r2 * | 1320 | +0% | never |
| 41.7 | net_width r10 | 2502 | +2% | 474 s |
| 42.3 | net_range r10 | 1289 | +5% | 118 s |
| 43.0 | net_strength r3 | 26.3k | +28% | 430 s |
| 43.3 | reel r14 | 3870 | +2% | 887 s |
| 43.7 | lucky_haul r9 | 4096 | +2% | 879 s |
| 43.7 | boat_speed r10 * | 1240 | +0% | never |
| 44.0 | reel r15 | 4566 | +1% | 1124 s |
| 44.0 | boat_volley r4 * | 2470 | +0% | never |
| 44.3 | lucky_haul r10 | 5571 | +2% | 1131 s |
| 45.0 | double_cast r8 | 8217 | +3% | 997 s |
| 45.7 | net_width r11 | 3027 | +1% | 728 s |
| 45.7 | net_range r11 * | 1637 | +0% | never |
| 46.7 | recycle_bonus r6 * | 16.2k | +5% | 1348 s |
| 47.0 | dog_strength * | 1200 | +0% | never |
| 52.0 | net_width r12 * | 3663 | +1% | 1230 s |
| 52.3 | net_hold r5 | 11.0k | +6% | 684 s |
| 52.3 | cargo r6 * | 3906 | +0% | never |
| 52.7 | net_range r12 | 2079 | +5% | 162 s |
| 52.7 | net_hold r6 | 20.0k | +8% | 947 s |
| 52.7 | net_range r13 * | 2641 | +0% | never |
| 53.0 | net_range r14 * | 3354 | +0% | never |
| 53.0 | dog_fetch r4 * | 2916 | +0% | never |
| 54.3 | net_width r13 * | 4432 | +0% | 3227 s |
| 55.3 | double_cast r9 * | 12.7k | +3% | 1392 s |
| 57.0 | reel r16 * | 5388 | +1% | 1464 s |
| 57.0 | cargo r7 * | 9766 | +0% | 14948 s |
| 59.0 | net_range r15 * | 4259 | +0% | never |
| 59.3 | dog_strength r2 * | 2640 | +0% | never |
| 60.3 | reel r17 * | 6358 | +1% | 1589 s |
| 61.0 | boat_speed r11 * | 1736 | +0% | never |
| 62.7 | recycle_bonus r7 * | 26.1k | +4% | 2146 s |
| 64.0 | reel r18 * | 7503 | +1% | 1954 s |
| 64.3 | dog_strength r3 * | 5808 | +0% | never |
| 65.3 | net_range r16 | 5409 | +4% | 525 s |
| 67.0 | net_range r17 * | 6870 | +0% | never |
| 67.3 | boat_speed r12 * | 2430 | +0% | never |
| 69.0 | net_width r14 * | 5363 | +0% | 4196 s |
| 70.3 | cargo r8 * | 24.4k | +0% | never |
| 70.3 | dog_strength r4 * | 12.8k | +0% | never |
| 73.7 | net_strength r4 | 72.0k | +59% | 436 s |
| 75.0 | net_hold r7 | 36.3k | +9% | 950 s |
| 77.0 | dog_wait r3 * | 2904 | +0% | never |
| 77.7 | double_cast r10 * | 19.5k | +3% | 1206 s |
| 79.3 | reel r19 * | 8853 | +1% | 1419 s |
| 80.3 | net_width r15 * | 6489 | +0% | 7129 s |
| 81.7 | boat_speed r13 * | 3402 | +0% | never |
| 82.0 | net_width r16 | 7852 | +2% | 873 s |
| 82.3 | reel r20 * | 10.4k | +1% | 3009 s |
| 82.3 | net_width r17 | 9501 | +2% | 934 s |
| 82.7 | net_range r18 | 8725 | +2% | 951 s |
| 84.7 | boat_speed r14 | 4762 | +0% | never | filler
| 85.3 | recycle_bonus r8 * | 42.1k | +4% | 3005 s |
| 85.3 | net_range r19 | 11.1k | +8% | 393 s |
| 85.3 | boat_speed r15 * | 6667 | +0% | never |
| 87.3 | boat_speed r16 | 9334 | +0% | never | filler
| 89.3 | net_width r18 | 11.5k | +0% | 22644 s | filler
| 89.3 | boat_speed r17 * | 13.1k | +0% | never |
| 90.0 | net_range r20 * | 14.1k | +0% | never |
| 91.7 | net_width r19 * | 13.9k | +0% | never |
| 93.0 | net_width r20 * | 16.8k | +0% | never |
| 94.7 | net_hold r8 * | 66.1k | +3% | 7638 s |
| 96.7 | boat_speed r18 | 18.3k | +0% | never | filler
| 101.3 | boat_speed r19 | 25.6k | +0% | never | filler

## Bot: cheapest

- Clear: not cleared
- Purchases: 156, spent 817.8k sludge
- Income/s at 2 / 10 / 30 min: 11.7 / 49.7 / 10.6
- Median payback by phase: 0m 482s, 10m 875s, 20m 1228s, 30m 1431s, 40m 8365s, 50m 1236s, 60m 1880s, 70m 2140s, 80m 3623s, 160m 52s, 170m 4047s
- Median seconds from reveal to buy, by group: cargo 10, boat_speed 20, bird_worth 65, net_range 80, boat_volley 95, fleet 140, dog_count 150, lucky_haul 215, double_cast 265, net_width 290, reel 300, dog_fetch 365, dog_wait 400, net_hold 715, dog_strength 800, recycle_bonus 990, net_strength 3410

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.2 | cargo | 40 | +36% | 23 s |
| 0.3 | boat_speed | 60 | +14% | 66 s |
| 0.5 | boat_speed r2 | 84 | +11% | 102 s |
| 0.8 | cargo r2 | 100 | +26% | 46 s |
| 0.9 | boat_speed r3 | 118 | +9% | 124 s |
| 1.1 | bird_worth | 120 | +0% | 4200 s |
| 1.3 | net_range | 150 | +1% | 2410 s |
| 1.6 | boat_volley | 160 | +0% | 2872 s |
| 1.8 | boat_speed r4 | 165 | +8% | 189 s |
| 2.1 | net_range r2 | 191 | +0% | 3925 s |
| 2.3 | fleet | 200 | +98% | 16 s |
| 2.5 | dog_count | 200 | +0% | never |
| 2.7 | bird_worth r2 | 216 | +0% | 3990 s |
| 2.8 | boat_speed r5 | 231 | +6% | 144 s |
| 2.9 | net_range r3 | 242 | +0% | 5053 s |
| 3.1 | cargo r3 | 250 | +20% | 46 s |
| 3.3 | net_range r4 | 307 | +0% | 7833 s |
| 3.4 | boat_speed r6 | 323 | +6% | 183 s |
| 3.6 | lucky_haul | 350 | +0% | never |
| 3.8 | bird_worth r3 | 389 | +0% | 5518 s |
| 4.0 | net_range r5 | 390 | +1% | 1191 s |
| 4.2 | boat_volley r2 | 398 | +1% | 1657 s |
| 4.4 | double_cast | 400 | +0% | never |
| 4.6 | dog_count r2 | 400 | +0% | never |
| 4.8 | net_width | 450 | +0% | 2711 s |
| 5.0 | reel | 450 | +0% | 4218 s |
| 5.3 | boat_speed r7 | 452 | +5% | 273 s |
| 5.5 | lucky_haul r2 | 476 | +0% | never |
| 5.7 | net_range r6 | 496 | +0% | 9219 s |
| 5.9 | fleet r2 | 500 | +10% | 133 s |
| 6.1 | dog_fetch | 500 | +9% | 146 s |
| 6.3 | reel r2 | 531 | +9% | 147 s |
| 6.4 | net_width r2 | 545 | +1% | 2267 s |
| 6.7 | dog_wait | 600 | +2% | 700 s |
| 6.9 | double_cast r2 | 616 | +2% | 762 s |
| 7.2 | cargo r4 | 625 | +0% | never |
| 7.3 | reel r3 | 627 | +7% | 209 s |
| 7.6 | net_range r7 | 629 | +0% | never |
| 7.8 | boat_speed r8 | 633 | +0% | never |
| 8.1 | lucky_haul r3 | 647 | +3% | 568 s |
| 8.3 | net_width r3 | 659 | +1% | 2245 s |
| 8.6 | bird_worth r4 | 700 | +1% | 2680 s |
| 8.8 | reel r4 | 739 | +5% | 287 s |
| 9.1 | net_width r4 | 797 | +1% | 2094 s |
| 9.3 | net_range r8 | 799 | +0% | never |
| 9.7 | dog_count r3 | 800 | +5% | 311 s |
| 9.9 | reel r5 | 872 | +4% | 397 s |
| 10.2 | lucky_haul r4 | 880 | +2% | 685 s |
| 10.5 | boat_speed r9 | 886 | +0% | never |
| 10.8 | dog_fetch r2 | 900 | +2% | 875 s |
| 11.1 | double_cast r3 | 949 | +2% | 924 s |
| 11.3 | net_width r5 | 965 | +1% | 2168 s |
| 11.6 | boat_volley r3 | 992 | +0% | never |
| 11.9 | net_hold | 1000 | +16% | 107 s |
| 12.2 | net_range r9 | 1015 | +0% | never |
| 12.4 | reel r6 | 1030 | +4% | 423 s |
| 12.8 | net_width r6 | 1167 | +1% | 2344 s |
| 13.1 | lucky_haul r5 | 1197 | +2% | 885 s |
| 13.3 | dog_strength | 1200 | +0% | never |
| 13.7 | reel r7 | 1215 | +3% | 556 s |
| 13.9 | boat_speed r10 | 1240 | +0% | never |
| 14.3 | fleet r3 | 1250 | +0% | never |
| 14.5 | bird_worth r5 | 1260 | +1% | 2231 s |
| 14.8 | net_range r10 | 1289 | +0% | never |
| 15.2 | dog_wait r2 | 1320 | +2% | 817 s |
| 15.5 | net_width r7 | 1412 | +1% | 2261 s |
| 15.8 | reel r8 | 1434 | +3% | 726 s |
| 16.2 | double_cast r4 | 1461 | +2% | 958 s |
| 16.5 | recycle_bonus | 1500 | +6% | 350 s |
| 16.8 | cargo r5 | 1563 | +0% | never |
| 17.2 | dog_fetch r3 | 1620 | +0% | never |
| 17.5 | lucky_haul r6 | 1628 | +2% | 1045 s |
| 17.8 | net_range r11 | 1637 | +0% | never |
| 18.3 | reel r9 | 1692 | +3% | 863 s |
| 18.6 | net_width r8 | 1709 | +1% | 2365 s |
| 18.9 | boat_speed r11 | 1736 | +0% | never |
| 19.3 | net_hold r2 | 1820 | +14% | 176 s |
| 19.7 | reel r10 | 1996 | +2% | 1106 s |
| 20.1 | net_width r9 | 2068 | +4% | 757 s |
| 20.5 | net_range r12 | 2079 | +9% | 316 s |
| 21.0 | lucky_haul r7 | 2215 | +2% | 1379 s |
| 21.5 | double_cast r5 | 2250 | +2% | 1228 s |
| 21.9 | bird_worth r6 | 2268 | +1% | 2246 s |
| 22.4 | reel r11 | 2355 | +2% | 1755 s |
| 22.9 | recycle_bonus r2 | 2415 | +5% | 798 s |
| 23.4 | boat_speed r12 | 2430 | +0% | never |
| 24.1 | boat_volley r4 | 2470 | +0% | never |
| 24.9 | net_width r10 | 2502 | +3% | 2639 s |
| 26.4 | dog_strength r2 | 2640 | +0% | never |
| 30.6 | net_range r13 | 2641 | +525% | 48 s |
| 31.3 | reel r12 | 2779 | +2% | 2814 s |
| 32.0 | dog_wait r3 | 2904 | +0% | never |
| 33.0 | dog_fetch r4 | 2916 | +0% | never |
| 36.1 | lucky_haul r8 | 3012 | +0% | never |
| 40.7 | net_width r11 | 3027 | +9% | 2992 s |
| 45.2 | reel r13 | 3279 | +2% | 13737 s |
| 49.6 | net_hold r3 | 3312 | +0% | never |
| 54.1 | net_range r14 | 3354 | +512% | 53 s |
| 54.8 | boat_speed r13 | 3402 | +0% | never |
| 55.7 | double_cast r6 | 3465 | +1% | 8504 s |
| 56.8 | net_strength | 3500 | +1191% | 22 s |
| 57.3 | net_width r12 | 3663 | +1% | 3305 s |
| 57.6 | reel r14 | 3870 | +2% | 1246 s |
| 58.0 | recycle_bonus r3 | 3888 | +5% | 440 s |
| 58.3 | cargo r6 | 3906 | +0% | never |
| 58.8 | bird_worth r7 | 4082 | +1% | 2632 s |
| 59.1 | lucky_haul r9 | 4096 | +2% | 1225 s |
| 59.5 | net_range r15 | 4259 | +0% | never |
| 59.9 | net_width r13 | 4432 | +1% | 3419 s |
| 60.3 | reel r15 | 4566 | +2% | 1549 s |
| 60.8 | boat_speed r14 | 4762 | +0% | never |
| 61.3 | double_cast r7 | 5336 | +3% | 1034 s |
| 61.8 | net_width r14 | 5363 | +1% | 3848 s |
| 62.3 | reel r16 | 5388 | +2% | 1908 s |
| 62.8 | net_range r16 | 5409 | +0% | never |
| 63.3 | lucky_haul r10 | 5571 | +2% | 1851 s |
| 63.8 | dog_strength r3 | 5808 | +0% | never |
| 64.4 | net_hold r4 | 6029 | +11% | 324 s |
| 64.9 | recycle_bonus r4 | 6260 | +5% | 685 s |
| 65.5 | reel r17 | 6358 | +1% | 2156 s |
| 66.0 | net_width r15 | 6489 | +1% | 4372 s |
| 66.5 | boat_speed r15 | 6667 | +0% | never |
| 67.1 | net_range r17 | 6870 | +0% | never |
| 67.8 | bird_worth r8 | 7347 | +1% | 3308 s |
| 68.3 | reel r18 | 7503 | +1% | 2818 s |
| 69.0 | net_width r16 | 7852 | +1% | 4614 s |
| 69.7 | double_cast r8 | 8217 | +3% | 1340 s |
| 70.4 | net_range r18 | 8725 | +0% | never |
| 71.2 | reel r19 | 8853 | +1% | 3565 s |
| 72.0 | boat_speed r16 | 9334 | +0% | never |
| 72.8 | net_width r17 | 9501 | +2% | 2938 s |
| 73.6 | net_strength r2 | 9590 | +80% | 76 s |
| 74.2 | cargo r7 | 9766 | +0% | never |
| 74.8 | recycle_bonus r5 | 10.1k | +5% | 784 s |
| 75.3 | reel r20 | 10.4k | +1% | 2968 s |
| 75.9 | net_hold r5 | 11.0k | +10% | 374 s |
| 76.5 | net_range r19 | 11.1k | +0% | never |
| 77.2 | net_width r18 | 11.5k | +1% | 7677 s |
| 77.9 | double_cast r9 | 12.7k | +3% | 1342 s |
| 78.6 | dog_strength r4 | 12.8k | +0% | never |
| 79.3 | boat_speed r17 | 13.1k | +0% | never |
| 80.1 | net_width r19 | 13.9k | +0% | 10385 s |
| 80.8 | net_range r20 | 14.1k | +0% | never |
| 81.8 | recycle_bonus r6 | 16.2k | +4% | 1352 s |
| 82.8 | net_width r20 | 16.8k | +0% | 14685 s |
| 83.8 | boat_speed r18 | 18.3k | +0% | never |
| 85.0 | double_cast r10 | 19.5k | +3% | 2412 s |
| 86.2 | net_hold r6 | 20.0k | +3% | 3623 s |
| 90.0 | cargo r8 | 24.4k | +0% | never |
| 116.0 | boat_speed r19 | 25.6k | +0% | never |
| 142.5 | recycle_bonus r7 | 26.1k | +0% | never |
| 169.1 | net_strength r3 | 26.3k | +3045% | 52 s |
| 170.3 | boat_speed r20 | 35.9k | +0% | never |
| 171.4 | net_hold r7 | 36.3k | +4% | 2008 s |
| 172.9 | recycle_bonus r8 | 42.1k | +4% | 6085 s |
| 269.2 | net_hold r8 | 66.1k | +0% | never |
