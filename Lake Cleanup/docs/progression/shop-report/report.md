# Progression sim: Lake Cleanup (shop, 2026-09-18 pass)

## Checks

| | check | result |
|---|---|---|
| PASS | focused clears in 48-68 min | 54.2 min (cleared 99.5%) |
| PASS | focused can always finish (no soft-lock) | finishes |
| PASS | casual can always finish (no soft-lock) | finishes |
| PASS | cheapest can always finish (no soft-lock) | finishes |
| PASS | early buys every 10-60 s (first 10 min) | median gap 15 s |
| PASS | no gap between buys over 300 s | longest 120 s at 40.8-42.8 min |
| WARN | last purchase leaves 10-25% of the game to enjoy it | last buy at 53.3 min, 2% of the game after it |
| FAIL | every buy raises income at least 8% | net_range +2.3%, dog_count +4.0%, boat_speed r3 +1.1%, reel +3.5%, boat_speed r4 +1.7%, boat_speed r5 +6.1% |
| WARN | no single pick wins by 3x in over 50% of choices | median best/second 1.72x; over 3x in 4%; "net_strength" top pick 64% |
| FAIL | payback within 4x of its phase median | cargo too strong for price (23 s vs 166 s); net_range too weak for price (702 s vs 166 s); cargo r4 too strong for price (61 s vs 404 s); fleet r3 too strong for price (62 s vs 404 s); cargo r5 too strong for price (84 s vs 404 s); cargo r6 too strong for price (130 s vs 632 s) |
| PASS | ferry capacity within 1-2.5x of catch rate | inside 79%, lagging 14%, overrunning 7%; box peaked at 37 |
| PASS | single upgrades are felt (no stage locked against another) | none |
| PASS | no bought node whose only value is what it unlocks | none |
| FAIL | every node earns its purchase, none only in the last 15% | 6 bought only as filler (earned nothing); 0 never bought; 0 first bought late |

## Bot: focused

- Clear: 54.2 min
- Purchases: 147, spent 629.2k sludge
- Income/s at 2 / 10 / 30 min: 11.5 / 53.4 / 370.9
- Median payback by phase: 0m 166s, 10m 404s, 20m 632s, 30m 785s, 40m 1009s
- Median seconds from reveal to buy, by group: cargo 10, boat_speed 20, bird_worth 35, net_range 65, fleet 115, net_width 185, dog_count 195, reel 260, lucky_haul 345, dog_fetch 435, net_strength 610, double_cast 625, recycle_bonus 645, boat_volley 655, dog_wait 735, net_hold 745, dog_strength 2570

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.2 | cargo | 40 | +36% | 23 s |
| 0.3 | boat_speed | 60 | +14% | 66 s |
| 0.6 | bird_worth | 120 | from zero | never |
| 0.8 | cargo r2 | 100 | +26% | 51 s |
| 1.1 | net_range | 150 | +2% | 702 s |
| 1.3 | boat_speed r2 | 84 | +11% | 81 s |
| 1.6 | bird_worth r2 | 216 | from zero | never |
| 1.9 | fleet | 200 | +28% | 67 s |
| 2.1 | net_range r2 | 191 | +23% | 67 s |
| 2.3 | net_range r3 | 242 | +15% | 109 s |
| 2.6 | bird_worth r3 | 389 | from zero | never |
| 3.1 | net_width | 450 | +33% | 87 s |
| 3.3 | dog_count | 200 | +4% | 244 s |
| 3.3 | boat_speed r3 | 118 | +1% | 513 s |
| 3.6 | net_range r4 | 307 | +10% | 139 s |
| 4.1 | bird_worth r4 | 700 | from zero | never |
| 4.3 | reel | 450 | +3% | 568 s |
| 4.5 | cargo r3 | 250 | +14% | 77 s |
| 4.8 | net_range r5 | 390 | +8% | 181 s |
| 4.8 | boat_speed r4 | 165 | +2% | 339 s |
| 5.2 | net_width r2 | 545 | +10% | 196 s |
| 5.3 | boat_speed r5 | 231 | +6% | 122 s |
| 5.4 | boat_speed r6 | 323 | +5% | 186 s |
| 5.8 | lucky_haul | 350 | +2% | 583 s |
| 6.2 | dog_count r2 | 400 | +3% | 447 s |
| 6.4 | bird_worth r5 | 1260 | from zero | never |
| 6.7 | reel r2 | 531 | +4% | 437 s |
| 6.9 | fleet r2 | 500 | +7% | 205 s |
| 7.1 | net_range r6 | 496 | +12% | 120 s |
| 7.3 | dog_fetch | 500 | +9% | 146 s |
| 7.5 | net_width r3 | 659 | +15% | 109 s |
| 7.8 | reel r3 | 627 | +9% | 151 s |
| 8.0 | net_width r4 | 797 | +5% | 298 s |
| 8.8 | bird_worth r6 | 2268 | from zero | never |
| 9.2 | reel r4 | 739 | +5% | 314 s |
| 9.9 | lucky_haul r2 | 476 | +3% | 314 s |
| 10.2 | net_strength | 3500 | +33% | 202 s |
| 10.3 | cargo r4 | 625 | +15% | 61 s |
| 10.4 | double_cast | 400 | +1% | 361 s |
| 10.8 | recycle_bonus | 1500 | +6% | 313 s |
| 10.9 | double_cast r2 | 616 | +1% | 748 s |
| 10.9 | boat_volley | 160 | +1% | 233 s |
| 11.3 | recycle_bonus r2 | 2415 | +6% | 499 s |
| 11.5 | reel r5 | 872 | +1% | 782 s |
| 11.6 | boat_speed r7 | 452 | +5% | 106 s |
| 11.7 | boat_volley r2 | 398 | +0% | 1015 s |
| 11.8 | lucky_haul r3 | 647 | +1% | 1045 s |
| 11.9 | boat_speed r8 | 633 | +2% | 310 s |
| 12.0 | dog_count r3 | 800 | +1% | 609 s |
| 12.2 | boat_speed r9 | 886 | +1% | 714 s |
| 12.3 | dog_wait | 600 | +1% | 467 s |
| 12.4 | net_hold | 1000 | +2% | 524 s |
| 12.7 | fleet r3 | 1250 | +19% | 62 s |
| 12.8 | reel r6 | 1030 | +5% | 171 s |
| 12.9 | reel r7 | 1215 | +4% | 238 s |
| 13.0 | lucky_haul r4 | 880 | +2% | 345 s |
| 13.2 | net_width r5 | 965 | +4% | 173 s |
| 13.3 | double_cast r3 | 949 | +2% | 408 s |
| 13.6 | net_width r6 | 1167 | +2% | 501 s |
| 13.8 | recycle_bonus r3 | 3888 | +5% | 523 s |
| 14.2 | net_width r7 | 1412 | +2% | 430 s |
| 14.5 | bird_worth r7 | 4082 | from zero | never |
| 14.6 | lucky_haul r5 | 1197 | +2% | 415 s |
| 14.8 | net_width r8 | 1709 | +3% | 404 s |
| 15.2 | reel r8 | 1434 | +3% | 362 s |
| 15.4 | net_width r9 | 2068 | +4% | 373 s |
| 15.8 | net_range r7 | 629 | +2% | 250 s |
| 15.8 | boat_speed r10 | 1240 | +3% | 263 s |
| 16.2 | bird_worth r8 | 7347 | from zero | never |
| 16.6 | reel r9 | 1692 | +3% | 376 s |
| 17.0 | net_hold r2 | 1820 | +5% | 271 s |
| 17.3 | net_range r8 | 799 | +3% | 200 s |
| 17.3 | cargo r5 | 1563 | +12% | 84 s |
| 17.8 | net_strength r2 | 9590 | +32% | 184 s |
| 17.9 | double_cast r4 | 1461 | +2% | 283 s |
| 18.2 | reel r10 | 1996 | +1% | 924 s |
| 18.2 | boat_volley r3 | 992 | +1% | 416 s |
| 18.3 | boat_speed r11 | 1736 | +1% | 771 s |
| 18.4 | lucky_haul r6 | 1628 | +2% | 368 s |
| 18.8 | recycle_bonus r4 | 6260 | +5% | 551 s |
| 19.0 | double_cast r5 | 2250 | +1% | 939 s |
| 19.2 | boat_speed r12 | 2430 | +2% | 607 s |
| 19.3 | dog_fetch r2 | 900 | +1% | 700 s |
| 19.8 | reel r11 | 2355 | +1% | 1142 s |
| 19.8 | boat_speed r13 | 3402 | +2% | 705 s |
| 20.3 | lucky_haul r7 | 2215 | +1% | 825 s |
| 20.4 | recycle_bonus r5 | 10.1k | +5% | 837 s |
| 20.6 | net_width r10 | 2502 | +1% | 801 s |
| 20.9 | net_width r11 | 3027 | +2% | 528 s |
| 21.1 | dog_wait r2 | 1320 | +1% | 663 s |
| 21.2 | reel r12 | 2779 | +2% | 597 s |
| 21.3 | net_width r12 | 3663 | +2% | 668 s |
| 21.4 | lucky_haul r8 | 3012 | +2% | 577 s |
| 21.7 | net_hold r3 | 3312 | +3% | 488 s |
| 21.8 | net_range r9 | 1015 | +2% | 191 s |
| 21.9 | cargo r6 | 3906 | +12% | 130 s |
| 22.3 | reel r13 | 3279 | +2% | 579 s |
| 22.5 | double_cast r6 | 3465 | +2% | 552 s |
| 22.8 | net_range r10 | 1289 | +2% | 217 s |
| 23.0 | reel r14 | 3870 | +2% | 645 s |
| 23.8 | net_hold r4 | 6029 | +4% | 553 s |
| 24.3 | net_range r11 | 1637 | +1% | 443 s |
| 24.6 | net_strength r3 | 26.3k | +25% | 375 s |
| 24.8 | boat_volley r4 | 2470 | +1% | 527 s |
| 25.0 | boat_speed r14 | 4762 | +2% | 597 s |
| 25.3 | boat_speed r15 | 6667 | +2% | 1127 s |
| 25.5 | reel r15 | 4566 | +1% | 971 s |
| 26.3 | recycle_bonus r6 | 16.2k | +4% | 978 s |
| 26.7 | lucky_haul r9 | 4096 | +1% | 952 s |
| 26.9 | net_width r13 | 4432 | +1% | 828 s |
| 27.1 | net_width r14 | 5363 | +1% | 995 s |
| 27.3 | double_cast r7 | 5336 | +2% | 759 s |
| 27.5 | lucky_haul r10 | 5571 | +2% | 840 s |
| 27.6 | net_width r15 | 6489 | +2% | 838 s |
| 28.1 | net_range r12 | 2079 | +1% | 632 s |
| 29.5 | net_hold r5 | 11.0k | +4% | 701 s |
| 29.8 | net_range r13 | 2641 | +2% | 486 s |
| 29.8 | cargo r7 | 9766 | +9% | 298 s |
| 30.2 | reel r16 | 5388 | +2% | 774 s |
| 31.1 | net_range r14 | 3354 | +2% | 561 s |
| 31.1 | double_cast r8 | 8217 | +3% | 747 s |
| 32.6 | net_strength r4 | 72.0k | +51% | 399 s |
| 32.8 | reel r17 | 6358 | +2% | 620 s |
| 33.0 | reel r18 | 7503 | +2% | 780 s |
| 33.8 | recycle_bonus r7 | 26.1k | +4% | 1106 s |
| 34.1 | reel r19 | 8853 | +2% | 1006 s |
| 34.3 | net_width r16 | 7852 | +1% | 1027 s |
| 34.6 | net_width r17 | 9501 | +1% | 1199 s |
| 34.9 | double_cast r9 | 12.7k | +3% | 826 s |
| 35.3 | net_width r18 | 11.5k | +3% | 790 s |
| 35.6 | net_range r15 | 4259 | +1% | 614 s |
| 35.7 | boat_speed r16 | 9334 | +2% | 985 s |
| 36.9 | net_hold r6 | 20.0k | +4% | 998 s |
| 37.2 | net_width r19 | 13.9k | +3% | 1100 s |
| 37.5 | net_range r16 | 5409 | +2% | 536 s |
| 37.8 | cargo r8 | 24.4k | +9% | 597 s |
| 39.2 | net_range r17 | 6870 | +3% | 602 s |
| 39.2 | net_hold r7 | 36.3k | +8% | 965 s |
| 40.8 | net_range r18 | 8725 | +2% | 1108 s |
| 42.8 | dog_strength | 1200 | +0% | never | filler
| 43.0 | net_range r19 | 11.1k | +3% | 919 s |
| 45.0 | dog_fetch r3 | 1620 | +0% | never | filler
| 45.3 | net_range r20 | 14.1k | +3% | 1009 s |
| 47.3 | dog_strength r2 | 2640 | +0% | never | filler
| 49.3 | dog_wait r3 | 2904 | +0% | never | filler
| 51.3 | dog_fetch r4 | 2916 | +0% | never | filler
| 53.3 | dog_strength r3 | 5808 | +0% | never | filler

## Bot: casual

- Clear: 94.4 min (seeds: 93, 94, 96)
- Purchases: 156, spent 823.7k sludge
- Income/s at 2 / 10 / 30 min: 9.6 / 2.7 / 14.0
- Median payback by phase: 0m 116s, 10m 272s, 20m 305s, 30m 398s, 40m 542s, 50m 984s, 60m 841s, 70m 1166s, 80m 2310s
- Median seconds from reveal to buy, by group: cargo 20, bird_worth 40, boat_speed 40, net_range 100, boat_volley 140, dog_count 160, fleet 200, net_width 380, reel 580, dog_fetch 760, lucky_haul 800, double_cast 1040, net_hold 1240, dog_wait 1280, net_strength 1420, recycle_bonus 1460, dog_strength 2420

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.3 | cargo | 40 | +36% | 23 s |
| 0.7 | bird_worth | 120 | from zero | never |
| 0.7 | boat_speed | 60 | +14% | 66 s |
| 1.0 | cargo r2 | 100 | +19% | 71 s |
| 1.3 | bird_worth r2 | 216 | from zero | never |
| 1.7 | net_range | 150 | +21% | 90 s |
| 2.0 | boat_speed r2 | 84 | +11% | 81 s |
| 2.0 | boat_speed r3 | 118 | +9% | 130 s |
| 2.3 | boat_volley * | 160 | +0% | never |
| 2.7 | dog_count * | 200 | +8% | 245 s |
| 2.7 | boat_speed r4 | 165 | +3% | 562 s |
| 3.0 | net_range r2 | 191 | +9% | 185 s |
| 3.3 | fleet | 200 | +13% | 118 s |
| 3.7 | bird_worth r3 | 389 | from zero | never |
| 4.0 | cargo r3 * | 250 | +0% | never |
| 4.3 | net_range r3 | 242 | +16% | 114 s |
| 5.0 | bird_worth r4 | 700 | from zero | never |
| 5.3 | boat_speed r5 * | 231 | +0% | never |
| 5.7 | net_range r4 | 307 | +13% | 170 s |
| 6.3 | net_width | 450 | +29% | 97 s |
| 9.7 | reel | 450 | +17% | 130 s |
| 10.3 | net_width r2 | 545 | +24% | 97 s |
| 10.7 | net_range r5 | 390 | +11% | 126 s |
| 11.0 | reel r2 | 531 | +9% | 188 s |
| 11.0 | boat_speed r6 | 323 | +3% | 328 s |
| 11.3 | net_range r6 | 496 | +5% | 309 s |
| 11.7 | boat_speed r7 | 452 | +4% | 323 s |
| 12.0 | dog_count r2 | 400 | +3% | 410 s |
| 12.3 | bird_worth r5 | 1260 | from zero | never |
| 12.7 | dog_fetch | 500 | +4% | 370 s |
| 12.7 | fleet r2 | 500 | +6% | 241 s |
| 13.0 | net_width r3 | 659 | +14% | 123 s |
| 13.3 | reel r3 * | 627 | +9% | 171 s |
| 13.3 | lucky_haul | 350 | +2% | 328 s |
| 13.7 | reel r4 | 739 | +7% | 240 s |
| 14.0 | net_width r4 | 797 | +9% | 180 s |
| 14.0 | lucky_haul r2 | 476 | +3% | 368 s |
| 14.3 | reel r5 | 872 | +6% | 297 s |
| 15.0 | bird_worth r6 | 2268 | from zero | never |
| 15.3 | net_width r5 | 965 | +10% | 192 s |
| 15.7 | boat_speed r8 * | 633 | +0% | never |
| 17.0 | cargo r4 * | 625 | +0% | never |
| 17.3 | cargo r5 * | 1563 | +0% | never |
| 17.3 | double_cast * | 400 | +2% | 500 s |
| 19.0 | net_range r7 | 629 | +5% | 246 s |
| 20.3 | net_width r6 * | 1167 | +1% | 1605 s |
| 20.7 | net_hold | 1000 | +13% | 140 s |
| 21.3 | net_range r8 | 799 | +8% | 166 s |
| 21.3 | reel r6 | 1030 | +5% | 305 s |
| 21.3 | dog_wait * | 600 | +1% | 700 s |
| 22.3 | bird_worth r7 | 4082 | from zero | never |
| 22.3 | double_cast r2 * | 616 | +2% | 539 s |
| 23.0 | net_range r9 | 1015 | +11% | 158 s |
| 23.7 | net_strength | 3500 | +36% | 152 s |
| 24.0 | net_hold r2 | 1820 | +16% | 132 s |
| 24.0 | dog_count r3 * | 800 | +3% | 311 s |
| 24.3 | recycle_bonus | 1500 | +6% | 248 s |
| 24.7 | lucky_haul r3 | 647 | +2% | 388 s |
| 25.0 | recycle_bonus r2 | 2415 | +6% | 393 s |
| 25.3 | net_hold r3 * | 3312 | +0% | 5954 s |
| 25.7 | fleet r3 | 1250 | +16% | 66 s |
| 25.7 | reel r7 | 1215 | +5% | 187 s |
| 25.7 | lucky_haul r4 | 880 | +2% | 379 s |
| 26.0 | reel r8 | 1434 | +4% | 240 s |
| 26.0 | double_cast r3 | 949 | +2% | 283 s |
| 26.7 | lucky_haul r5 | 1197 | +2% | 468 s |
| 27.3 | boat_volley r2 * | 398 | +0% | never |
| 29.3 | double_cast r4 | 1461 | +3% | 393 s |
| 30.3 | reel r9 | 1692 | +4% | 292 s |
| 30.7 | recycle_bonus r3 * | 3888 | +5% | 487 s |
| 31.0 | reel r10 | 1996 | +3% | 360 s |
| 31.3 | reel r11 | 2355 | +3% | 468 s |
| 31.7 | dog_wait r2 * | 1320 | +0% | never |
| 32.0 | bird_worth r8 | 7347 | from zero | never |
| 32.3 | net_width r7 | 1412 | +5% | 170 s |
| 32.7 | net_width r8 | 1709 | +4% | 247 s |
| 33.3 | net_strength r2 | 9590 | +38% | 161 s |
| 33.3 | lucky_haul r6 | 1628 | +1% | 585 s |
| 33.7 | boat_speed r9 | 886 | +1% | 596 s |
| 33.7 | double_cast r5 | 2250 | +3% | 369 s |
| 34.0 | net_hold r4 * | 6029 | +0% | 6152 s |
| 34.3 | cargo r6 | 3906 | +12% | 147 s |
| 34.3 | boat_speed r10 | 1240 | +2% | 203 s |
| 34.7 | boat_volley r3 * | 992 | +0% | never |
| 34.7 | reel r12 | 2779 | +3% | 398 s |
| 35.0 | recycle_bonus r4 | 6260 | +5% | 471 s |
| 35.3 | net_width r9 | 2068 | +2% | 323 s |
| 35.3 | lucky_haul r7 | 2215 | +1% | 617 s |
| 35.7 | net_width r10 | 2502 | +2% | 393 s |
| 36.0 | net_width r11 | 3027 | +2% | 454 s |
| 36.0 | reel r13 * | 3279 | +1% | 1140 s |
| 36.0 | boat_speed r11 | 1736 | +1% | 521 s |
| 36.0 | boat_speed r12 * | 2430 | +0% | never |
| 40.3 | net_width r12 | 3663 | +3% | 481 s |
| 40.3 | dog_strength * | 1200 | +0% | never |
| 40.7 | net_width r13 | 4432 | +3% | 543 s |
| 41.3 | net_range r10 | 1289 | +10% | 56 s |
| 41.3 | double_cast r6 | 3465 | +3% | 460 s |
| 41.3 | dog_fetch r2 * | 900 | +0% | never |
| 41.3 | reel r14 | 3870 | +2% | 637 s |
| 41.3 | lucky_haul r8 | 3012 | +2% | 699 s |
| 42.7 | net_range r11 | 1637 | +4% | 150 s |
| 42.7 | net_hold r5 | 11.0k | +6% | 697 s |
| 42.7 | dog_strength r2 * | 2640 | +0% | never |
| 42.7 | boat_speed r13 | 3402 | +2% | 538 s |
| 43.7 | reel r15 * | 4566 | +2% | 973 s |
| 44.0 | net_range r12 | 2079 | +6% | 143 s |
| 44.3 | net_strength r3 | 26.3k | +26% | 371 s |
| 45.0 | recycle_bonus r5 | 10.1k | +5% | 635 s |
| 45.0 | net_range r13 * | 2641 | +0% | never |
| 45.3 | double_cast r7 | 5336 | +3% | 541 s |
| 45.7 | reel r16 | 5388 | +2% | 788 s |
| 46.7 | dog_wait r3 * | 2904 | +0% | never |
| 48.7 | boat_volley r4 * | 2470 | +0% | never |
| 48.7 | lucky_haul r9 | 4096 | +1% | 839 s |
| 51.0 | recycle_bonus r6 | 16.2k | +4% | 1064 s |
| 53.3 | net_width r14 | 5363 | +2% | 705 s |
| 54.0 | double_cast r8 * | 8217 | +2% | 1105 s |
| 54.0 | net_range r14 | 3354 | +4% | 244 s |
| 54.7 | reel r17 * | 6358 | +1% | 1465 s |
| 55.3 | net_strength r4 | 72.0k | +44% | 483 s |
| 55.7 | boat_speed r14 | 4762 | +1% | 905 s |
| 55.7 | dog_fetch r3 * | 1620 | +0% | never |
| 55.7 | lucky_haul r10 | 5571 | +1% | 984 s |
| 57.7 | dog_fetch r4 | 2916 | +0% | never | filler
| 59.3 | reel r18 * | 7503 | +0% | 6525 s |
| 60.3 | boat_speed r15 | 6667 | +2% | 717 s |
| 60.7 | boat_speed r16 * | 9334 | +0% | never |
| 61.0 | double_cast r9 | 12.7k | +3% | 828 s |
| 61.3 | net_width r15 | 6489 | +2% | 828 s |
| 61.7 | net_width r16 | 7852 | +2% | 929 s |
| 62.0 | reel r19 * | 8853 | +1% | 1337 s |
| 62.0 | net_width r17 | 9501 | +2% | 855 s |
| 62.7 | net_range r15 | 4259 | +2% | 448 s |
| 63.7 | net_hold r6 * | 20.0k | +2% | 2158 s |
| 63.7 | cargo r7 | 9766 | +5% | 407 s |
| 63.7 | dog_strength r3 * | 5808 | +0% | never |
| 63.7 | net_range r16 * | 5409 | +0% | never |
| 64.7 | dog_strength r4 * | 12.8k | +0% | never |
| 66.3 | cargo r8 * | 24.4k | +0% | never |
| 68.0 | double_cast r10 * | 19.5k | +3% | 1460 s |
| 68.7 | net_range r17 * | 6870 | +0% | never |
| 71.7 | net_hold r7 * | 36.3k | +8% | 1166 s |
| 72.3 | boat_speed r17 * | 13.1k | +0% | never |
| 72.3 | net_range r18 * | 8725 | +0% | never |
| 74.3 | reel r20 | 10.4k | +2% | 1725 s | filler
| 75.0 | net_range r19 | 11.1k | +8% | 371 s |
| 75.7 | net_width r18 * | 11.5k | +0% | 12992 s |
| 76.0 | net_range r20 * | 14.1k | +0% | never |
| 76.3 | boat_speed r18 * | 18.3k | +0% | never |
| 77.7 | boat_speed r19 * | 25.6k | +0% | never |
| 80.7 | net_width r19 | 13.9k | +0% | 18272 s | filler
| 82.7 | net_width r20 | 16.8k | +1% | 7814 s | filler
| 84.7 | boat_speed r20 * | 35.9k | +0% | never |
| 84.7 | recycle_bonus r7 * | 26.1k | +4% | 2310 s |
| 91.0 | recycle_bonus r8 | 42.1k | +4% | 9904 s | filler

## Bot: cheapest

- Clear: not cleared
- Purchases: 157, spent 889.8k sludge
- Income/s at 2 / 10 / 30 min: 11.8 / 47.0 / 52.7
- Median payback by phase: 0m 163s, 10m 548s, 20m 904s, 30m 4574s, 40m 921s, 50m 1410s, 60m 1466s, 70m 2683s, 120m 2903s, 290m 82s
- Median seconds from reveal to buy, by group: cargo 10, boat_speed 20, bird_worth 65, net_range 80, boat_volley 95, fleet 140, dog_count 150, lucky_haul 265, double_cast 345, net_width 390, reel 410, dog_fetch 490, dog_wait 535, net_hold 810, dog_strength 890, recycle_bonus 1045, net_strength 2785

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.2 | cargo | 40 | +36% | 23 s |
| 0.3 | boat_speed | 60 | +14% | 66 s |
| 0.5 | boat_speed r2 | 84 | +11% | 102 s |
| 0.8 | cargo r2 | 100 | +13% | 91 s |
| 0.9 | boat_speed r3 | 118 | +0% | never |
| 1.1 | bird_worth | 120 | +0% | 3115 s |
| 1.3 | net_range | 150 | +41% | 44 s |
| 1.6 | boat_volley | 160 | +0% | 2872 s |
| 1.8 | boat_speed r4 | 165 | +2% | 672 s |
| 2.1 | net_range r2 | 191 | +9% | 184 s |
| 2.3 | fleet | 200 | +16% | 102 s |
| 2.5 | dog_count | 200 | +8% | 180 s |
| 2.8 | bird_worth r2 | 216 | +0% | 3059 s |
| 3.0 | boat_speed r5 | 231 | +0% | never |
| 3.3 | net_range r3 | 242 | +16% | 105 s |
| 3.5 | cargo r3 | 250 | +0% | never |
| 3.8 | net_range r4 | 307 | +12% | 163 s |
| 4.1 | boat_speed r6 | 323 | +0% | never |
| 4.4 | lucky_haul | 350 | +2% | 1044 s |
| 4.8 | bird_worth r3 | 389 | +0% | 4429 s |
| 5.1 | net_range r5 | 390 | +10% | 232 s |
| 5.4 | boat_volley r2 | 398 | +0% | never |
| 5.8 | double_cast | 400 | +2% | 1196 s |
| 6.2 | dog_count r2 | 400 | +6% | 358 s |
| 6.5 | net_width | 450 | +27% | 84 s |
| 6.8 | reel | 450 | +17% | 106 s |
| 7.1 | boat_speed r7 | 452 | +0% | never |
| 7.3 | lucky_haul r2 | 476 | +2% | 780 s |
| 7.6 | net_range r6 | 496 | +10% | 181 s |
| 7.9 | fleet r2 | 500 | +0% | never |
| 8.2 | dog_fetch | 500 | +12% | 146 s |
| 8.4 | reel r2 | 531 | +11% | 143 s |
| 8.7 | net_width r2 | 545 | +20% | 74 s |
| 8.9 | dog_wait | 600 | +2% | 700 s |
| 9.1 | double_cast r2 | 616 | +2% | 828 s |
| 9.3 | cargo r4 | 625 | +0% | never |
| 9.6 | reel r3 | 627 | +8% | 177 s |
| 9.8 | net_range r7 | 629 | +11% | 134 s |
| 10.0 | boat_speed r8 | 633 | +0% | never |
| 10.3 | lucky_haul r3 | 647 | +2% | 572 s |
| 10.4 | net_width r3 | 659 | +11% | 119 s |
| 10.7 | bird_worth r4 | 700 | +1% | 2017 s |
| 10.8 | reel r4 | 739 | +7% | 190 s |
| 11.1 | net_width r4 | 797 | +4% | 355 s |
| 11.3 | net_range r8 | 799 | +0% | never |
| 11.6 | dog_count r3 | 800 | +5% | 311 s |
| 11.8 | reel r5 | 872 | +6% | 244 s |
| 12.1 | lucky_haul r4 | 880 | +3% | 568 s |
| 12.3 | boat_speed r9 | 886 | +0% | never |
| 12.5 | dog_fetch r2 | 900 | +2% | 875 s |
| 12.8 | double_cast r3 | 949 | +2% | 760 s |
| 13.0 | net_width r5 | 965 | +1% | 1436 s |
| 13.3 | boat_volley r3 | 992 | +0% | never |
| 13.5 | net_hold | 1000 | +8% | 180 s |
| 13.8 | net_range r9 | 1015 | +0% | 9121 s |
| 14.0 | reel r6 | 1030 | +0% | 3612 s |
| 14.3 | net_width r6 | 1167 | +1% | 1666 s |
| 14.5 | lucky_haul r5 | 1197 | +0% | never |
| 14.8 | dog_strength | 1200 | +0% | never |
| 15.1 | reel r7 | 1215 | +0% | 4148 s |
| 15.3 | boat_speed r10 | 1240 | +3% | 527 s |
| 15.7 | fleet r3 | 1250 | +15% | 108 s |
| 15.8 | bird_worth r5 | 1260 | +1% | 1601 s |
| 16.1 | net_range r10 | 1289 | +8% | 202 s |
| 16.3 | dog_wait r2 | 1320 | +2% | 817 s |
| 16.6 | net_width r7 | 1412 | +3% | 517 s |
| 16.8 | reel r8 | 1434 | +4% | 469 s |
| 17.1 | double_cast r4 | 1461 | +2% | 893 s |
| 17.4 | recycle_bonus | 1500 | +6% | 319 s |
| 17.7 | cargo r5 | 1563 | +0% | never |
| 18.0 | dog_fetch r3 | 1620 | +0% | never |
| 18.3 | lucky_haul r6 | 1628 | +3% | 720 s |
| 18.6 | net_range r11 | 1637 | +15% | 138 s |
| 18.9 | reel r9 | 1692 | +3% | 612 s |
| 19.2 | net_width r8 | 1709 | +5% | 377 s |
| 19.5 | boat_speed r11 | 1736 | +0% | never |
| 19.8 | net_hold r2 | 1820 | +3% | 844 s |
| 20.2 | reel r10 | 1996 | +3% | 890 s |
| 20.5 | net_width r9 | 2068 | +5% | 510 s |
| 20.9 | net_range r12 | 2079 | +25% | 116 s |
| 21.3 | lucky_haul r7 | 2215 | +3% | 918 s |
| 21.6 | double_cast r5 | 2250 | +2% | 1409 s |
| 22.1 | bird_worth r6 | 2268 | +2% | 1616 s |
| 22.6 | reel r11 | 2355 | +3% | 1172 s |
| 23.1 | recycle_bonus r2 | 2415 | +5% | 802 s |
| 23.6 | boat_speed r12 | 2430 | +0% | never |
| 24.3 | boat_volley r4 | 2470 | +0% | never |
| 24.9 | net_width r10 | 2502 | +3% | 1834 s |
| 25.8 | dog_strength r2 | 2640 | +0% | never |
| 27.3 | net_range r13 | 2641 | +338% | 52 s |
| 27.9 | reel r12 | 2779 | +3% | 1751 s |
| 28.7 | dog_wait r3 | 2904 | +0% | never |
| 29.6 | dog_fetch r4 | 2916 | +0% | never |
| 31.2 | lucky_haul r8 | 3012 | +0% | never |
| 34.4 | net_width r11 | 3027 | +9% | 2086 s |
| 37.7 | reel r13 | 3279 | +3% | 7062 s |
| 40.8 | net_hold r3 | 3312 | +0% | never |
| 44.0 | net_range r14 | 3354 | +342% | 56 s |
| 44.8 | boat_speed r13 | 3402 | +0% | never |
| 45.5 | double_cast r6 | 3465 | +1% | 6099 s |
| 46.4 | net_strength | 3500 | +812% | 19 s |
| 46.8 | net_width r12 | 3663 | +1% | 2312 s |
| 47.1 | reel r14 | 3870 | +3% | 737 s |
| 47.3 | recycle_bonus r3 | 3888 | +5% | 362 s |
| 47.7 | cargo r6 | 3906 | +0% | never |
| 47.9 | bird_worth r7 | 4082 | +1% | 1871 s |
| 48.3 | lucky_haul r9 | 4096 | +2% | 1008 s |
| 48.6 | net_range r15 | 4259 | +0% | never |
| 48.9 | net_width r13 | 4432 | +1% | 2399 s |
| 49.3 | reel r15 | 4566 | +2% | 921 s |
| 49.7 | boat_speed r14 | 4762 | +0% | never |
| 50.0 | double_cast r7 | 5336 | +3% | 838 s |
| 50.4 | net_width r14 | 5363 | +1% | 2677 s |
| 50.8 | reel r16 | 5388 | +2% | 1119 s |
| 51.3 | net_range r16 | 5409 | +0% | never |
| 51.7 | lucky_haul r10 | 5571 | +2% | 1533 s |
| 52.1 | dog_strength r3 | 5808 | +0% | never |
| 52.6 | net_hold r4 | 6029 | +10% | 268 s |
| 53.0 | recycle_bonus r4 | 6260 | +5% | 567 s |
| 53.4 | reel r17 | 6358 | +2% | 1277 s |
| 53.8 | net_width r15 | 6489 | +1% | 3037 s |
| 54.3 | boat_speed r15 | 6667 | +0% | never |
| 54.8 | net_range r17 | 6870 | +0% | never |
| 55.3 | bird_worth r8 | 7347 | +1% | 2378 s |
| 55.8 | reel r18 | 7503 | +2% | 1674 s |
| 56.3 | net_width r16 | 7852 | +2% | 1853 s |
| 56.8 | double_cast r8 | 8217 | +3% | 1352 s |
| 57.4 | net_range r18 | 8725 | +9% | 439 s |
| 58.1 | reel r19 | 8853 | +2% | 2264 s |
| 58.8 | boat_speed r16 | 9334 | +0% | never |
| 59.3 | net_width r17 | 9501 | +3% | 1469 s |
| 60.1 | net_strength r2 | 9590 | +95% | 57 s |
| 60.6 | cargo r7 | 9766 | +0% | never |
| 61.1 | recycle_bonus r5 | 10.1k | +4% | 659 s |
| 61.5 | reel r20 | 10.4k | +2% | 1794 s |
| 62.0 | net_hold r5 | 11.0k | +10% | 313 s |
| 62.5 | net_range r19 | 11.1k | +0% | never |
| 63.0 | net_width r18 | 11.5k | +1% | 5337 s |
| 63.6 | double_cast r9 | 12.7k | +3% | 1108 s |
| 64.2 | dog_strength r4 | 12.8k | +0% | never |
| 64.8 | boat_speed r17 | 13.1k | +0% | never |
| 65.4 | net_width r19 | 13.9k | +1% | 7186 s |
| 66.1 | net_range r20 | 14.1k | +0% | never |
| 66.8 | recycle_bonus r6 | 16.2k | +4% | 1138 s |
| 67.7 | net_width r20 | 16.8k | +0% | 10156 s |
| 68.6 | boat_speed r18 | 18.3k | +0% | never |
| 69.5 | double_cast r10 | 19.5k | +3% | 2503 s |
| 70.5 | net_hold r6 | 20.0k | +3% | 2683 s |
| 72.2 | cargo r8 | 24.4k | +0% | never |
| 86.5 | boat_speed r19 | 25.6k | +0% | never |
| 105.7 | recycle_bonus r7 | 26.1k | +0% | never |
| 124.9 | net_strength r3 | 26.3k | +2618% | 44 s |
| 125.9 | boat_speed r20 | 35.9k | +0% | never |
| 126.9 | net_hold r7 | 36.3k | +3% | 2903 s |
| 128.5 | recycle_bonus r8 | 42.1k | +4% | 5512 s |
| 197.0 | net_hold r8 | 66.1k | +0% | never |
| 297.8 | net_strength r4 | 72.0k | +7403% | 82 s |
