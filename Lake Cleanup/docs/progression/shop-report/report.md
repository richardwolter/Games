# Progression sim: Lake Cleanup (shop, 2026-09-18 pass)

## Checks

| | check | result |
|---|---|---|
| WARN | focused clears in 68-82 min | 64.2 min (cleared 99.5%) |
| PASS | focused can always finish (no soft-lock) | finishes |
| PASS | casual can always finish (no soft-lock) | finishes |
| PASS | cheapest can always finish (no soft-lock) | finishes |
| PASS | early buys every 10-60 s (first 10 min) | median gap 15 s |
| PASS | no gap between buys over 300 s | longest 135 s at 37.3-39.5 min |
| WARN | last purchase leaves 10-25% of the game to enjoy it | last buy at 63.2 min, 2% of the game after it |
| FAIL | every buy raises income at least 8% | cargo r2 +5.3%, boat_speed r4 +1.5%, dog_fetch +5.7%, net_width +7.5%, boat_speed r5 +6.4%, boat_speed r6 +5.5% |
| WARN | no single pick wins by 3x in over 50% of choices | median best/second 1.76x; over 3x in 2%; "net_strength" top pick 67% |
| FAIL | payback within 4x of its phase median | cargo too strong for price (34 s vs 277 s); fleet too strong for price (34 s vs 277 s); boat_speed too strong for price (36 s vs 277 s); boat_speed r2 too strong for price (56 s vs 277 s); net_range r16 too strong for price (163 s vs 995 s) |
| PASS | ferry capacity within 1-2.5x of catch rate | inside 82%, lagging 15%, overrunning 3%; box peaked at 24 |
| WARN | single upgrades are felt (no stage locked against another) | 1 buys only paid off with another: lucky_haul+boat_volley @19.1 |
| PASS | no bought node whose only value is what it unlocks | none |
| FAIL | every node earns its purchase, none only in the last 15% | 7 bought only as filler (earned nothing); 0 never bought; 0 first bought late |

## Bot: focused

- Clear: 64.2 min
- Purchases: 137, spent 528.4k sludge
- Income/s at 2 / 10 / 30 min: 19.1 / 61.5 / 215.5
- Median payback by phase: 0m 277s, 10m 399s, 20m 661s, 30m 734s, 40m 995s, 50m 1012s
- Median seconds from reveal to buy, by group: cargo 10, fleet 45, boat_speed 50, net_range 85, dog_fetch 115, net_width 170, reel 220, lucky_haul 235, double_cast 245, dog_count 355, dog_wait 390, boat_volley 440, recycle_bonus 490, net_hold 565, bird_worth 680, net_strength 765, dog_strength 2625

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.2 | cargo | 40 | +24% | 34 s |
| 0.8 | fleet | 200 | +98% | 34 s |
| 0.8 | boat_speed | 60 | +14% | 36 s |
| 0.9 | boat_speed r2 | 84 | +11% | 56 s |
| 1.1 | cargo r2 | 100 | +5% | 126 s |
| 1.4 | net_range | 400 | +26% | 106 s |
| 1.6 | boat_speed r3 | 118 | +9% | 72 s |
| 1.7 | boat_speed r4 | 165 | +2% | 553 s |
| 1.9 | dog_fetch | 300 | +6% | 277 s |
| 2.3 | net_range r2 | 444 | +12% | 198 s |
| 2.5 | cargo r3 | 250 | +13% | 89 s |
| 2.8 | net_width | 450 | +7% | 262 s |
| 2.9 | boat_speed r5 | 231 | +6% | 146 s |
| 3.2 | boat_speed r6 | 323 | +6% | 222 s |
| 3.4 | boat_speed r7 | 452 | +2% | 918 s |
| 3.7 | reel | 450 | +7% | 222 s |
| 3.9 | lucky_haul | 350 | +2% | 607 s |
| 4.1 | double_cast | 400 | +2% | 931 s |
| 4.4 | net_range r3 | 493 | +6% | 288 s |
| 4.7 | fleet r2 | 500 | +19% | 88 s |
| 4.9 | net_width r2 | 545 | +21% | 79 s |
| 5.1 | reel r2 | 531 | +7% | 203 s |
| 5.3 | net_range r4 | 547 | +12% | 115 s |
| 5.5 | lucky_haul r2 | 476 | +2% | 454 s |
| 5.9 | dog_count | 550 | +2% | 517 s |
| 5.9 | cargo r4 | 625 | +3% | 512 s |
| 6.2 | reel r3 | 627 | +6% | 259 s |
| 6.4 | net_width r3 | 659 | +8% | 195 s |
| 6.5 | dog_wait | 300 | +1% | 525 s |
| 6.8 | dog_count r2 | 847 | +5% | 330 s |
| 7.1 | reel r4 | 739 | +4% | 408 s |
| 7.3 | net_range r5 | 607 | +3% | 419 s |
| 7.3 | boat_volley | 160 | +1% | 459 s |
| 7.5 | boat_speed r8 | 633 | +3% | 501 s |
| 7.8 | lucky_haul r3 | 647 | +3% | 503 s |
| 8.2 | recycle_bonus | 1500 | +6% | 471 s |
| 8.5 | net_width r4 | 797 | +4% | 382 s |
| 9.4 | net_range r6 | 674 | +4% | 313 s |
| 9.4 | net_hold | 1000 | +5% | 344 s |
| 9.4 | fleet r3 | 1250 | +12% | 192 s |
| 9.5 | reel r5 | 872 | +4% | 365 s |
| 10.1 | net_width r5 | 965 | +5% | 290 s |
| 10.6 | net_range r7 | 748 | +5% | 230 s |
| 10.6 | net_hold r2 | 1820 | +15% | 195 s |
| 11.3 | bird_worth | 4000 | from zero | never |
| 11.6 | net_range r8 | 831 | +9% | 141 s |
| 12.8 | net_strength | 5000 | +48% | 160 s |
| 12.8 | double_cast r2 | 616 | +2% | 308 s |
| 13.0 | reel r6 | 1030 | +4% | 256 s |
| 13.4 | recycle_bonus r2 | 2415 | +6% | 406 s |
| 13.5 | dog_fetch r2 | 444 | +0% | 917 s |
| 13.6 | boat_volley r2 | 398 | +0% | 985 s |
| 14.2 | recycle_bonus r3 | 3888 | +5% | 649 s |
| 15.0 | bird_worth r2 | 5920 | from zero | never |
| 16.3 | bird_worth r3 | 8762 | from zero | never |
| 18.0 | net_strength r2 | 12.2k | +21% | 489 s |
| 18.8 | recycle_bonus r4 | 6260 | +5% | 858 s |
| 18.8 | double_cast r3 | 949 | +1% | 1159 s |
| 18.9 | boat_speed r9 | 886 | +2% | 322 s |
| 19.0 | dog_wait r2 | 636 | +1% | 420 s |
| 19.1 | lucky_haul r4 (with boat_volley) | 880 | +1% | 468 s |
| 19.3 | boat_speed r10 | 1240 | +2% | 484 s |
| 19.3 | lucky_haul r5 | 1197 | +2% | 391 s |
| 20.8 | bird_worth r4 | 13.0k | from zero | never |
| 22.3 | reel r7 | 1215 | +1% | 1111 s |
| 22.3 | cargo r5 | 1563 | +3% | 358 s |
| 22.3 | net_hold r3 | 3312 | +9% | 212 s |
| 22.3 | boat_speed r11 | 1736 | +3% | 306 s |
| 22.3 | boat_volley r3 | 992 | +1% | 788 s |
| 22.4 | reel r8 | 1434 | +1% | 782 s |
| 22.4 | boat_speed r12 | 2430 | +2% | 667 s |
| 22.4 | double_cast r4 | 1461 | +1% | 727 s |
| 22.8 | lucky_haul r6 | 1628 | +1% | 622 s |
| 22.9 | net_width r6 | 1167 | +1% | 985 s |
| 23.2 | reel r9 | 1692 | +1% | 738 s |
| 23.4 | net_width r7 | 1412 | +2% | 471 s |
| 23.6 | net_width r8 | 1709 | +1% | 656 s |
| 23.8 | net_width r9 | 2068 | +1% | 764 s |
| 23.9 | reel r10 | 1996 | +2% | 581 s |
| 24.1 | double_cast r5 | 2250 | +2% | 569 s |
| 24.2 | net_width r10 | 2502 | +1% | 869 s |
| 24.3 | lucky_haul r7 | 2215 | +2% | 612 s |
| 24.4 | net_width r11 | 3027 | +2% | 774 s |
| 24.5 | reel r11 | 2355 | +1% | 872 s |
| 24.7 | lucky_haul r8 | 3012 | +2% | 717 s |
| 25.1 | net_range r9 | 922 | +2% | 225 s |
| 25.1 | cargo r6 | 3906 | +9% | 237 s |
| 25.2 | reel r12 | 2779 | +2% | 840 s |
| 25.8 | double_cast r6 | 3465 | +2% | 742 s |
| 26.4 | net_hold r4 | 6029 | +6% | 562 s |
| 26.7 | net_range r10 | 1023 | +2% | 228 s |
| 26.7 | boat_speed r13 | 3402 | +2% | 700 s |
| 27.0 | cargo r7 | 9766 | +7% | 722 s |
| 28.2 | net_range r11 | 1136 | +1% | 519 s |
| 28.2 | net_hold r5 | 11.0k | +10% | 576 s |
| 29.4 | bird_worth r5 | 19.2k | from zero | never |
| 29.8 | net_range r12 | 1261 | +2% | 394 s |
| 31.9 | net_strength r3 | 29.5k | +50% | 297 s |
| 32.1 | reel r13 | 3279 | +2% | 579 s |
| 32.7 | recycle_bonus r5 | 10.1k | +5% | 687 s |
| 33.5 | recycle_bonus r6 | 16.2k | +5% | 1107 s |
| 33.9 | reel r14 | 3870 | +1% | 1115 s |
| 34.2 | net_width r12 | 3663 | +1% | 791 s |
| 34.3 | net_width r13 | 4432 | +1% | 1093 s |
| 34.4 | lucky_haul r9 | 4096 | +1% | 834 s |
| 34.6 | double_cast r7 | 5336 | +2% | 718 s |
| 34.8 | net_width r14 | 5363 | +2% | 865 s |
| 35.3 | net_range r13 | 1399 | +2% | 313 s |
| 35.3 | boat_speed r14 | 4762 | +2% | 734 s |
| 35.3 | boat_volley r4 | 2470 | +1% | 712 s |
| 37.3 | net_range r14 | 1553 | +3% | 217 s |
| 37.3 | reel r15 | 4566 | +2% | 1026 s |
| 39.5 | net_range r15 | 1724 | +1% | 549 s |
| 39.5 | double_cast r8 | 8217 | +3% | 1014 s |
| 40.3 | net_strength r4 | 71.7k | +50% | 540 s |
| 40.6 | reel r16 | 5388 | +2% | 875 s |
| 41.8 | bird_worth r6 | 28.4k | from zero | never |
| 43.8 | dog_strength | 500 | +0% | never | filler
| 44.6 | lucky_haul r10 | 5571 | +1% | 1054 s |
| 45.0 | net_width r15 | 6489 | +1% | 1145 s |
| 45.1 | double_cast r9 | 12.7k | +3% | 1160 s |
| 45.2 | net_width r16 | 7852 | +2% | 1191 s |
| 45.5 | net_width r17 | 9501 | +2% | 1193 s |
| 46.0 | net_range r16 | 1914 | +4% | 163 s |
| 46.0 | boat_speed r15 | 6667 | +2% | 935 s |
| 48.0 | dog_fetch r3 | 657 | +0% | never | filler
| 48.5 | net_range r17 | 2124 | +3% | 277 s |
| 50.5 | dog_fetch r4 | 973 | +0% | never | filler
| 51.0 | net_hold r6 | 20.0k | +6% | 1189 s |
| 51.3 | net_range r18 | 2358 | +2% | 413 s |
| 52.6 | cargo r8 | 24.4k | +7% | 1190 s |
| 54.0 | net_range r19 | 2617 | +1% | 1012 s |
| 56.0 | dog_strength r2 | 1015 | +0% | never | filler
| 57.2 | net_range r20 | 2905 | +1% | 786 s |
| 59.2 | dog_count r3 | 1304 | +0% | never | filler
| 61.2 | dog_wait r3 | 1348 | +0% | never | filler
| 63.2 | dog_strength r3 | 2060 | +0% | never | filler

## Bot: casual

- Clear: 110.2 min (seeds: 105, 110, 112)
- Purchases: 151, spent 828.8k sludge
- Income/s at 2 / 10 / 30 min: 17.7 / 6.3 / 2.2
- Median payback by phase: 0m 211s, 10m 312s, 20m 380s, 30m 490s, 40m 861s, 50m 635s, 60m 894s, 70m 1064s, 80m 7953s, 90m 1297s, 100m 2789s
- Median seconds from reveal to buy, by group: cargo 20, fleet 60, boat_speed 60, net_range 120, net_width 180, reel 200, dog_fetch 220, dog_wait 240, boat_volley 280, dog_count 340, lucky_haul 360, double_cast 500, dog_strength 720, net_hold 800, bird_worth 940, net_strength 1300, recycle_bonus 1320

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.3 | cargo | 40 | +24% | 34 s |
| 1.0 | fleet | 200 | +99% | 34 s |
| 1.0 | boat_speed | 60 | +14% | 36 s |
| 1.3 | boat_speed r2 | 84 | +11% | 57 s |
| 1.3 | cargo r2 (with dog_fetch) | 100 | +7% | 92 s |
| 1.3 | boat_speed r3 * | 118 | +0% | never |
| 2.0 | net_range | 400 | +53% | 72 s |
| 2.3 | net_range r2 | 444 | +30% | 98 s |
| 3.0 | cargo r3 * | 250 | +0% | never |
| 3.0 | net_width | 450 | +21% | 115 s |
| 3.0 | boat_speed r4 | 165 | +8% | 95 s |
| 3.0 | boat_speed r5 | 231 | +2% | 507 s |
| 3.3 | reel | 450 | +9% | 211 s |
| 3.7 | dog_fetch | 300 | +2% | 744 s |
| 4.0 | dog_wait * | 300 | +1% | 2121 s |
| 4.0 | net_range r3 * | 493 | +0% | 12144 s |
| 4.3 | fleet r2 | 500 | +26% | 75 s |
| 4.7 | net_width r2 | 545 | +19% | 95 s |
| 4.7 | boat_volley * | 160 | +0% | never |
| 5.0 | reel r2 | 531 | +7% | 216 s |
| 5.0 | boat_volley r2 * | 398 | +0% | never |
| 5.3 | net_width r3 | 659 | +12% | 165 s |
| 5.7 | dog_count * | 550 | +7% | 215 s |
| 6.0 | lucky_haul | 350 | +3% | 339 s |
| 6.3 | lucky_haul r2 | 476 | +2% | 503 s |
| 6.7 | dog_fetch r2 * | 444 | +0% | never |
| 7.3 | boat_speed r6 | 323 | +2% | 476 s |
| 8.3 | double_cast * | 400 | +1% | 673 s |
| 10.0 | net_range r4 | 547 | +2% | 765 s |
| 10.3 | lucky_haul r3 * | 647 | +1% | 2065 s |
| 10.7 | boat_speed r7 | 452 | +2% | 441 s |
| 11.0 | fleet r3 * | 1250 | +0% | never |
| 11.3 | reel r3 | 627 | +6% | 270 s |
| 11.7 | dog_count r2 | 847 | +7% | 300 s |
| 12.0 | net_width r4 | 797 | +8% | 240 s |
| 12.0 | dog_strength * | 500 | +0% | never |
| 12.3 | net_width r5 | 965 | +5% | 403 s |
| 12.7 | cargo r4 * | 625 | +0% | never |
| 13.0 | net_range r5 | 607 | +7% | 207 s |
| 13.3 | net_hold | 1000 | +15% | 142 s |
| 13.3 | reel r4 | 739 | +4% | 324 s |
| 14.0 | net_range r6 | 674 | +9% | 153 s |
| 14.0 | reel r5 | 872 | +4% | 384 s |
| 14.3 | cargo r5 * | 1563 | +0% | never |
| 15.7 | bird_worth | 4000 | from zero | never |
| 15.7 | net_range r7 | 748 | +10% | 143 s |
| 17.0 | net_width r6 * | 1167 | +0% | 5115 s |
| 17.3 | net_range r8 * | 831 | +0% | never |
| 20.0 | dog_wait r2 * | 636 | +2% | 525 s |
| 20.3 | net_hold r2 | 1820 | +15% | 228 s |
| 21.7 | net_strength | 5000 | +36% | 222 s |
| 22.0 | recycle_bonus | 1500 | +6% | 289 s |
| 22.3 | reel r6 | 1030 | +4% | 291 s |
| 22.3 | double_cast r2 | 616 | +2% | 328 s |
| 22.7 | dog_count r3 | 1304 | +4% | 380 s |
| 22.7 | double_cast r3 | 949 | +2% | 450 s |
| 23.0 | reel r7 | 1215 | +3% | 378 s |
| 23.0 | lucky_haul r4 | 880 | +2% | 460 s |
| 23.7 | net_hold r3 | 3312 | +14% | 239 s |
| 24.0 | recycle_bonus r2 | 2415 | +6% | 378 s |
| 24.3 | reel r8 | 1434 | +3% | 411 s |
| 24.3 | double_cast r4 | 1461 | +2% | 518 s |
| 25.0 | recycle_bonus r3 * | 3888 | +5% | 589 s |
| 25.3 | lucky_haul r5 | 1197 | +2% | 544 s |
| 26.0 | bird_worth r2 | 5920 | from zero | never |
| 27.0 | reel r9 | 1692 | +1% | 1163 s |
| 30.3 | dog_fetch r3 * | 657 | +0% | never |
| 30.3 | lucky_haul r6 * | 1628 | +0% | never |
| 30.7 | dog_wait r3 * | 1348 | +0% | never |
| 30.7 | boat_speed r8 | 633 | +4% | 115 s |
| 30.7 | boat_volley r3 * | 992 | +0% | 2616 s |
| 31.7 | net_width r7 | 1412 | +3% | 393 s |
| 31.7 | net_width r8 * | 1709 | +1% | 942 s |
| 32.3 | bird_worth r3 | 8762 | from zero | never |
| 32.7 | net_range r9 | 922 | +4% | 213 s |
| 34.0 | net_strength r2 | 12.2k | +36% | 275 s |
| 34.3 | double_cast r5 | 2250 | +3% | 496 s |
| 34.3 | reel r10 | 1996 | +2% | 484 s |
| 35.0 | recycle_bonus r4 | 6260 | +5% | 701 s |
| 36.0 | recycle_bonus r5 | 10.1k | +5% | 1129 s |
| 37.7 | dog_strength r2 * | 1015 | +0% | never |
| 41.3 | bird_worth r4 | 13.0k | from zero | never |
| 42.3 | lucky_haul r7 | 2215 | +1% | 921 s |
| 42.3 | net_width r9 * | 2068 | +0% | 3460 s |
| 42.3 | boat_speed r9 | 886 | +1% | 356 s |
| 42.3 | net_hold r4 * | 6029 | +2% | 1242 s |
| 42.3 | boat_volley r4 * | 2470 | +1% | 1429 s |
| 42.3 | boat_speed r10 | 1240 | +3% | 178 s |
| 42.7 | net_width r10 | 2502 | +1% | 865 s |
| 42.7 | boat_speed r11 | 1736 | +1% | 654 s |
| 43.0 | net_width r11 * | 3027 | +3% | 533 s |
| 43.0 | net_range r10 * | 1023 | +0% | never |
| 43.3 | dog_strength r3 * | 2060 | +0% | never |
| 44.0 | reel r11 | 2355 | +1% | 857 s |
| 45.7 | reel r12 * | 2779 | +1% | 1132 s |
| 45.7 | net_range r11 | 1136 | +7% | 90 s |
| 48.3 | net_hold r5 * | 11.0k | +1% | 5813 s |
| 48.3 | cargo r6 | 3906 | +10% | 221 s |
| 49.3 | dog_fetch r4 * | 973 | +0% | never |
| 50.7 | boat_speed r12 * | 2430 | +0% | never |
| 50.7 | double_cast r6 | 3465 | +3% | 618 s |
| 51.3 | net_range r12 | 1261 | +3% | 243 s |
| 52.3 | net_strength r3 | 29.5k | +35% | 431 s |
| 52.7 | reel r13 | 3279 | +2% | 652 s |
| 52.7 | lucky_haul r8 | 3012 | +2% | 743 s |
| 53.0 | net_range r13 * | 1399 | +0% | never |
| 53.0 | double_cast r7 | 5336 | +3% | 709 s |
| 54.3 | bird_worth r5 | 19.2k | from zero | never |
| 57.3 | double_cast r8 * | 8217 | +1% | 3696 s |
| 57.3 | boat_speed r13 | 3402 | +2% | 575 s |
| 61.7 | cargo r7 * | 9766 | +0% | never |
| 61.7 | net_hold r6 | 20.0k | +10% | 790 s |
| 62.3 | net_width r12 | 3663 | +2% | 716 s |
| 62.3 | reel r14 | 3870 | +2% | 894 s |
| 62.7 | net_width r13 | 4432 | +2% | 743 s |
| 63.0 | net_range r14 | 1553 | +2% | 391 s |
| 64.3 | recycle_bonus r6 * | 16.2k | +5% | 1352 s |
| 64.7 | recycle_bonus r7 * | 26.1k | +4% | 2185 s |
| 64.7 | lucky_haul r9 * | 4096 | +1% | 1149 s |
| 65.3 | net_range r15 | 1724 | +2% | 342 s |
| 65.3 | reel r15 | 4566 | +2% | 986 s |
| 67.3 | reel r16 * | 5388 | +1% | 1831 s |
| 69.0 | net_range r16 * | 1914 | +0% | never |
| 70.0 | boat_speed r14 * | 4762 | +0% | never |
| 72.7 | net_range r17 * | 2124 | +0% | never |
| 74.3 | boat_speed r15 * | 6667 | +0% | never |
| 74.7 | net_strength r4 | 71.7k | +48% | 575 s |
| 75.0 | lucky_haul r10 | 5571 | +1% | 1064 s |
| 75.3 | reel r17 | 6358 | +1% | 1100 s |
| 75.7 | double_cast r9 | 12.7k | +3% | 996 s |
| 76.7 | reel r18 * | 7503 | +1% | 1352 s |
| 80.3 | net_width r14 * | 5363 | +0% | 6996 s |
| 81.3 | bird_worth r6 | 28.4k | from zero | never |
| 83.3 | net_range r18 | 2358 | +0% | never | filler
| 83.7 | double_cast r10 * | 19.5k | +3% | 1629 s |
| 84.7 | net_range r19 * | 2617 | +0% | never |
| 85.0 | bird_worth r7 * | 42.0k | +0% | never |
| 85.0 | net_width r15 * | 6489 | +0% | 8910 s |
| 86.7 | net_width r16 * | 7852 | +0% | 11589 s |
| 87.3 | cargo r8 * | 24.4k | +0% | never |
| 90.3 | net_range r20 | 2905 | +0% | never | filler
| 92.3 | dog_strength r4 | 4183 | +0% | never | filler
| 93.0 | net_hold r7 * | 36.3k | +9% | 1297 s |
| 95.0 | reel r19 | 8853 | +1% | 1893 s | filler
| 97.0 | boat_speed r16 | 9334 | +0% | never | filler
| 99.0 | net_width r17 | 9501 | +0% | 32798 s | filler
| 101.0 | recycle_bonus r8 * | 42.1k | +4% | 2789 s |
| 101.7 | net_width r18 * | 11.5k | +1% | 4847 s |
| 102.3 | net_width r19 * | 13.9k | +2% | 2207 s |
| 104.3 | reel r20 | 10.4k | +1% | 12352 s | filler
| 105.0 | bird_worth r8 * | 62.2k | +0% | never |

## Bot: cheapest

- Clear: not cleared
- Purchases: 153, spent 762.4k sludge
- Income/s at 2 / 10 / 30 min: 12.2 / 44.1 / 67.5
- Median payback by phase: 0m 210s, 10m 650s, 20m 1209s, 30m 1973s, 40m 2159s, 60m 1814s, 70m 3088s, 80m 1159s, 90m 13572s, 250m 59s, 260m 2182s
- Median seconds from reveal to buy, by group: cargo 10, boat_speed 20, boat_volley 75, fleet 110, dog_fetch 145, dog_wait 160, lucky_haul 220, net_range 290, double_cast 315, net_width 390, reel 405, dog_strength 490, dog_count 550, net_hold 940, recycle_bonus 1285, bird_worth 2535, net_strength 3850

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.2 | cargo | 40 | +24% | 34 s |
| 0.3 | boat_speed | 60 | +14% | 72 s |
| 0.6 | boat_speed r2 | 84 | +11% | 111 s |
| 0.8 | cargo r2 | 100 | +19% | 68 s |
| 1.0 | boat_speed r3 | 118 | +9% | 144 s |
| 1.3 | boat_volley | 160 | +0% | 3876 s |
| 1.6 | boat_speed r4 | 165 | +8% | 218 s |
| 1.8 | fleet | 200 | +57% | 33 s |
| 2.1 | boat_speed r5 | 231 | +0% | never |
| 2.3 | cargo r3 | 250 | +0% | never |
| 2.4 | dog_fetch | 300 | +9% | 277 s |
| 2.7 | dog_wait | 300 | +2% | 1107 s |
| 3.1 | boat_speed r6 | 323 | +0% | never |
| 3.7 | lucky_haul | 350 | +2% | 1498 s |
| 4.3 | boat_volley r2 | 398 | +0% | never |
| 4.8 | net_range | 400 | +67% | 64 s |
| 5.3 | double_cast | 400 | +2% | 1707 s |
| 5.8 | net_range r2 | 444 | +40% | 79 s |
| 6.1 | dog_fetch r2 | 444 | +1% | 1817 s |
| 6.5 | net_width | 450 | +29% | 83 s |
| 6.8 | reel | 450 | +10% | 201 s |
| 7.1 | boat_speed r7 | 452 | +0% | never |
| 7.3 | lucky_haul r2 | 476 | +3% | 672 s |
| 7.7 | net_range r3 | 493 | +30% | 72 s |
| 7.9 | fleet r2 | 500 | +2% | 733 s |
| 8.2 | dog_strength | 500 | +0% | never |
| 8.4 | reel r2 | 531 | +7% | 267 s |
| 8.8 | net_width r2 | 545 | +22% | 87 s |
| 9.0 | net_range r4 | 547 | +27% | 62 s |
| 9.2 | dog_count | 550 | +7% | 195 s |
| 9.4 | net_range r5 | 607 | +2% | 876 s |
| 9.7 | double_cast r2 | 616 | +2% | 726 s |
| 9.9 | cargo r4 | 625 | +0% | never |
| 10.2 | reel r3 | 627 | +7% | 217 s |
| 10.3 | boat_speed r8 | 633 | +0% | never |
| 10.6 | dog_wait r2 | 636 | +2% | 787 s |
| 10.8 | lucky_haul r3 | 647 | +3% | 533 s |
| 11.0 | dog_fetch r3 | 657 | +0% | never |
| 11.3 | net_width r3 | 659 | +8% | 191 s |
| 11.5 | net_range r6 | 674 | +0% | never |
| 11.8 | reel r4 | 739 | +5% | 295 s |
| 12.0 | net_range r7 | 748 | +0% | never |
| 12.3 | net_width r4 | 797 | +0% | 4607 s |
| 12.6 | net_range r8 | 831 | +0% | never |
| 12.9 | dog_count r2 | 847 | +7% | 262 s |
| 13.2 | reel r5 | 872 | +4% | 411 s |
| 13.5 | lucky_haul r4 | 880 | +3% | 685 s |
| 13.8 | boat_speed r9 | 886 | +0% | never |
| 14.1 | net_range r9 | 922 | +0% | never |
| 14.4 | double_cast r3 | 949 | +2% | 1003 s |
| 14.7 | net_width r5 | 965 | +0% | 4637 s |
| 15.0 | dog_fetch r4 | 973 | +0% | never |
| 15.3 | boat_volley r3 | 992 | +0% | never |
| 15.7 | net_hold | 1000 | +9% | 217 s |
| 16.0 | dog_strength r2 | 1015 | +0% | never |
| 16.3 | net_range r10 | 1023 | +0% | 17999 s |
| 16.6 | reel r6 | 1030 | +0% | 13531 s |
| 16.9 | net_range r11 | 1136 | +0% | 19761 s |
| 17.3 | net_width r6 | 1167 | +0% | 4925 s |
| 17.6 | lucky_haul r5 | 1197 | +0% | never |
| 18.0 | reel r7 | 1215 | +0% | 14956 s |
| 18.3 | boat_speed r10 | 1240 | +3% | 650 s |
| 18.7 | fleet r3 | 1250 | +19% | 112 s |
| 19.0 | net_range r12 | 1261 | +0% | never |
| 19.3 | dog_count r3 | 1304 | +5% | 404 s |
| 19.6 | dog_wait r3 | 1348 | +3% | 626 s |
| 19.9 | net_range r13 | 1399 | +0% | never |
| 20.3 | net_width r7 | 1412 | +0% | 5335 s |
| 20.7 | reel r8 | 1434 | +3% | 770 s |
| 21.0 | double_cast r4 | 1461 | +2% | 1131 s |
| 21.4 | recycle_bonus | 1500 | +6% | 370 s |
| 21.8 | net_range r14 | 1553 | +0% | never |
| 22.2 | cargo r5 | 1563 | +0% | never |
| 22.5 | lucky_haul r6 | 1628 | +2% | 1209 s |
| 22.9 | reel r9 | 1692 | +3% | 916 s |
| 23.3 | net_width r8 | 1709 | +1% | 5599 s |
| 23.8 | net_range r15 | 1724 | +0% | never |
| 24.3 | boat_speed r11 | 1736 | +0% | never |
| 24.9 | net_hold r2 | 1820 | +16% | 201 s |
| 25.4 | net_range r16 | 1914 | +0% | never |
| 25.9 | reel r10 | 1996 | +3% | 1033 s |
| 26.4 | dog_strength r3 | 2060 | +0% | never |
| 27.0 | net_width r9 | 2068 | +1% | 6231 s |
| 27.5 | net_range r17 | 2124 | +0% | never |
| 28.1 | lucky_haul r7 | 2215 | +2% | 1615 s |
| 28.7 | double_cast r5 | 2250 | +3% | 1313 s |
| 29.3 | reel r11 | 2355 | +3% | 1279 s |
| 29.8 | net_range r18 | 2358 | +0% | never |
| 30.5 | recycle_bonus r2 | 2415 | +6% | 656 s |
| 31.1 | boat_speed r12 | 2430 | +0% | never |
| 31.7 | boat_volley r4 | 2470 | +0% | never |
| 32.3 | net_width r10 | 2502 | +1% | 6793 s |
| 32.8 | net_range r19 | 2617 | +0% | never |
| 33.5 | reel r12 | 2779 | +3% | 1571 s |
| 34.2 | net_range r20 | 2905 | +0% | never |
| 34.9 | lucky_haul r8 | 3012 | +2% | 2041 s |
| 35.7 | net_width r11 | 3027 | +1% | 7691 s |
| 36.4 | reel r13 | 3279 | +2% | 1973 s |
| 37.2 | net_hold r3 | 3312 | +13% | 347 s |
| 37.8 | boat_speed r13 | 3402 | +0% | never |
| 38.6 | double_cast r6 | 3465 | +3% | 1502 s |
| 39.3 | net_width r12 | 3663 | +1% | 8641 s |
| 40.1 | reel r14 | 3870 | +2% | 2159 s |
| 40.8 | recycle_bonus r3 | 3888 | +5% | 866 s |
| 41.5 | cargo r6 | 3906 | +0% | never |
| 42.3 | bird_worth | 4000 | +2% | 2299 s |
| 43.0 | lucky_haul r9 | 4096 | +3% | 1928 s |
| 43.8 | dog_strength r4 | 4183 | +0% | never |
| 44.8 | net_width r13 | 4432 | +2% | 3680 s |
| 46.3 | reel r15 | 4566 | +1% | 29404 s |
| 54.1 | boat_speed r14 | 4762 | +0% | never |
| 64.2 | net_strength | 5000 | +1792% | 34 s |
| 64.8 | double_cast r7 | 5336 | +3% | 1176 s |
| 65.3 | net_width r14 | 5363 | +0% | 8713 s |
| 65.9 | reel r16 | 5388 | +2% | 1914 s |
| 66.4 | lucky_haul r10 | 5571 | +2% | 1814 s |
| 67.1 | bird_worth r2 | 5920 | +1% | 2752 s |
| 67.7 | net_hold r4 | 6029 | +11% | 317 s |
| 68.2 | recycle_bonus r4 | 6260 | +5% | 671 s |
| 68.8 | reel r17 | 6358 | +2% | 2016 s |
| 69.3 | net_width r15 | 6489 | +0% | 8137 s |
| 69.8 | boat_speed r15 | 6667 | +0% | never |
| 70.4 | reel r18 | 7503 | +1% | 2543 s |
| 71.1 | net_width r16 | 7852 | +0% | 9661 s |
| 71.8 | double_cast r8 | 8217 | +3% | 1320 s |
| 72.4 | bird_worth r3 | 8762 | +1% | 3558 s |
| 73.2 | reel r19 | 8853 | +1% | 3088 s |
| 73.8 | boat_speed r16 | 9334 | +0% | never |
| 74.6 | net_width r17 | 9501 | +0% | 10479 s |
| 75.3 | cargo r7 | 9766 | +0% | never |
| 76.1 | recycle_bonus r5 | 10.1k | +5% | 1005 s |
| 76.9 | reel r20 | 10.4k | +1% | 5206 s |
| 77.7 | net_hold r5 | 11.0k | +3% | 1989 s |
| 78.8 | net_width r18 | 11.5k | +1% | 14343 s |
| 85.9 | net_strength r2 | 12.2k | +2161% | 40 s |
| 86.6 | double_cast r9 | 12.7k | +3% | 1241 s |
| 87.3 | bird_worth r4 | 13.0k | +1% | 6281 s |
| 87.9 | boat_speed r17 | 13.1k | +0% | never |
| 88.6 | net_width r19 | 13.9k | +0% | 17448 s |
| 89.4 | recycle_bonus r6 | 16.2k | +5% | 1076 s |
| 90.3 | net_width r20 | 16.8k | +0% | 23315 s |
| 91.2 | boat_speed r18 | 18.3k | +0% | never |
| 92.1 | bird_worth r5 | 19.2k | +0% | 11770 s |
| 93.0 | double_cast r10 | 19.5k | +2% | 3828 s |
| 94.1 | net_hold r6 | 20.0k | +0% | never |
| 112.5 | cargo r8 | 24.4k | +0% | never |
| 147.8 | boat_speed r19 | 25.6k | +0% | never |
| 183.8 | recycle_bonus r7 | 26.1k | +0% | never |
| 223.0 | bird_worth r6 | 28.4k | +12% | 19573 s |
| 259.3 | net_strength r3 | 29.5k | +3699% | 59 s |
| 260.5 | boat_speed r20 | 35.9k | +0% | never |
| 261.8 | net_hold r7 | 36.3k | +4% | 2182 s |
| 263.2 | bird_worth r7 | 42.0k | +0% | never |
