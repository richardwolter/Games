# Progression sim: Lake Cleanup (shop, 2026-09-18 pass)

## Checks

| | check | result |
|---|---|---|
| PASS | focused clears in 48-68 min | 51.9 min (cleared 99.5%) |
| PASS | focused can always finish (no soft-lock) | finishes |
| PASS | casual can always finish (no soft-lock) | finishes |
| PASS | cheapest can always finish (no soft-lock) | finishes |
| PASS | early buys every 10-60 s (first 10 min) | median gap 10 s |
| PASS | no gap between buys over 300 s | longest 120 s at 41.4-43.4 min |
| WARN | last purchase leaves 10-25% of the game to enjoy it | last buy at 51.6 min, 1% of the game after it |
| FAIL | every buy raises income at least 8% | dog_count +2.8%, boat_speed r4 +1.4%, lucky_haul +1.8%, net_range r5 +1.9%, cargo r3 +7.9%, boat_speed r5 +6.2% |
| WARN | no single pick wins by 3x in over 50% of choices | median best/second 1.60x; over 3x in 2%; "net_strength" top pick 64% |
| FAIL | payback within 4x of its phase median | cargo too strong for price (23 s vs 168 s); fleet too strong for price (35 s vs 168 s); lucky_haul too weak for price (772 s vs 168 s); net_range r5 too weak for price (811 s vs 168 s); double_cast r2 too weak for price (772 s vs 168 s); fleet r3 too strong for price (45 s vs 494 s) |
| WARN | ferry capacity within 1-2.5x of catch rate | inside 73%, lagging 20%, overrunning 7%; box peaked at 92 |
| WARN | single upgrades are felt (no stage locked against another) | 1 buys only paid off with another: net_range+fleet @1.4 |
| PASS | no bought node whose only value is what it unlocks | none |
| FAIL | every node earns its purchase, none only in the last 15% | 5 bought only as filler (earned nothing); 0 never bought; 0 first bought late |

## Bot: focused

- Clear: 51.9 min
- Purchases: 145, spent 610.4k sludge
- Income/s at 2 / 10 / 30 min: 11.7 / 83.5 / 421.4
- Median payback by phase: 0m 168s, 10m 494s, 20m 516s, 30m 761s, 40m 1110s
- Median seconds from reveal to buy, by group: cargo 10, boat_speed 20, bird_worth 35, net_range 85, fleet 120, dog_count 150, lucky_haul 195, net_width 235, reel 300, dog_fetch 345, boat_volley 435, net_strength 555, double_cast 560, recycle_bonus 575, net_hold 875, dog_wait 1170, dog_strength 2605

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.2 | cargo | 40 | +36% | 23 s |
| 0.3 | boat_speed | 60 | +14% | 66 s |
| 0.6 | bird_worth | 120 | from zero | never |
| 0.8 | cargo r2 | 100 | +26% | 51 s |
| 1.0 | boat_speed r2 | 84 | +11% | 81 s |
| 1.2 | boat_speed r3 | 118 | +9% | 124 s |
| 1.4 | net_range (with fleet) | 150 | +45% | 29 s |
| 1.7 | bird_worth r2 | 216 | from zero | never |
| 2.0 | fleet | 200 | +48% | 35 s |
| 2.2 | net_range r2 | 191 | +25% | 46 s |
| 2.3 | net_range r3 | 242 | +17% | 73 s |
| 2.5 | dog_count | 200 | +3% | 316 s |
| 2.6 | boat_speed r4 | 165 | +1% | 509 s |
| 2.8 | bird_worth r3 | 389 | from zero | never |
| 3.1 | net_range r4 | 307 | +13% | 107 s |
| 3.3 | lucky_haul | 350 | +2% | 772 s |
| 3.5 | net_range r5 | 390 | +2% | 811 s |
| 3.7 | cargo r3 | 250 | +8% | 125 s |
| 3.9 | net_width | 450 | +16% | 107 s |
| 4.1 | boat_speed r5 | 231 | +6% | 122 s |
| 4.3 | boat_speed r6 | 323 | +4% | 231 s |
| 4.4 | dog_count r2 | 400 | +2% | 525 s |
| 4.8 | bird_worth r4 | 700 | from zero | never |
| 5.0 | reel | 450 | +4% | 373 s |
| 5.3 | fleet r2 | 500 | +6% | 263 s |
| 5.4 | net_width r2 | 545 | +23% | 69 s |
| 5.6 | net_range r6 | 496 | +11% | 112 s |
| 5.8 | dog_fetch | 500 | +8% | 146 s |
| 6.0 | reel r2 | 531 | +8% | 145 s |
| 6.3 | net_width r3 | 659 | +4% | 354 s |
| 6.3 | cargo r4 | 625 | +10% | 124 s |
| 6.6 | reel r3 | 627 | +6% | 183 s |
| 6.7 | lucky_haul r2 | 476 | +3% | 321 s |
| 7.0 | bird_worth r5 | 1260 | from zero | never |
| 7.3 | net_width r4 | 797 | +6% | 230 s |
| 7.3 | boat_volley | 160 | +1% | 330 s |
| 7.4 | boat_speed r7 | 452 | +2% | 327 s |
| 7.7 | reel r4 | 739 | +5% | 248 s |
| 8.2 | bird_worth r6 | 2268 | from zero | never |
| 8.3 | net_range r7 | 629 | +7% | 142 s |
| 9.3 | net_strength | 3500 | +37% | 154 s |
| 9.3 | double_cast | 400 | +2% | 257 s |
| 9.6 | recycle_bonus | 1500 | +6% | 297 s |
| 9.8 | double_cast r2 | 616 | +1% | 772 s |
| 9.8 | boat_volley r2 | 398 | +1% | 521 s |
| 10.3 | recycle_bonus r2 | 2415 | +6% | 471 s |
| 10.9 | bird_worth r7 | 4082 | from zero | never |
| 11.1 | net_width r5 | 965 | +1% | 1032 s |
| 11.8 | recycle_bonus r3 | 3888 | +5% | 758 s |
| 12.9 | bird_worth r8 | 7347 | from zero | never |
| 14.5 | net_strength r2 | 9590 | +20% | 458 s |
| 14.6 | net_hold | 1000 | +1% | 1025 s |
| 14.8 | fleet r3 | 1250 | +22% | 45 s |
| 14.8 | reel r5 | 872 | +5% | 117 s |
| 14.9 | lucky_haul r3 | 647 | +2% | 177 s |
| 15.0 | lucky_haul r4 | 880 | +2% | 267 s |
| 15.2 | net_width r6 | 1167 | +1% | 1028 s |
| 15.3 | net_width r7 | 1412 | +1% | 1186 s |
| 15.9 | recycle_bonus r4 | 6260 | +5% | 744 s |
| 16.4 | reel r6 | 1030 | +1% | 1138 s |
| 16.4 | boat_speed r8 | 633 | +4% | 98 s |
| 16.4 | double_cast r3 | 949 | +1% | 791 s |
| 16.4 | boat_speed r9 | 886 | +2% | 294 s |
| 16.4 | reel r7 | 1215 | +2% | 280 s |
| 16.4 | boat_speed r10 | 1240 | +1% | 522 s |
| 16.5 | dog_count r3 | 800 | +1% | 339 s |
| 17.3 | recycle_bonus r5 | 10.1k | +5% | 1076 s |
| 18.6 | net_width r8 | 1709 | +1% | 989 s |
| 19.0 | net_width r9 | 2068 | +1% | 979 s |
| 19.3 | reel r8 | 1434 | +1% | 776 s |
| 19.3 | cargo r5 | 1563 | +2% | 407 s |
| 19.3 | net_hold r2 | 1800 | +7% | 112 s |
| 19.3 | net_width r10 | 2502 | +4% | 251 s |
| 19.4 | lucky_haul r5 | 1197 | +1% | 353 s |
| 19.5 | dog_wait | 600 | +0% | 540 s |
| 19.6 | double_cast r4 | 1461 | +1% | 450 s |
| 19.7 | reel r9 | 1692 | +1% | 570 s |
| 19.7 | boat_volley r3 | 992 | +1% | 627 s |
| 19.8 | lucky_haul r6 | 1628 | +2% | 376 s |
| 19.8 | net_width r11 | 3027 | +3% | 459 s |
| 19.8 | boat_speed r11 | 1736 | +2% | 348 s |
| 19.8 | dog_fetch r2 | 900 | +0% | 751 s |
| 19.9 | reel r10 | 1996 | +2% | 516 s |
| 20.0 | lucky_haul r7 | 2215 | +2% | 458 s |
| 20.1 | net_width r12 | 3663 | +3% | 494 s |
| 20.1 | boat_speed r12 | 2430 | +1% | 675 s |
| 20.2 | dog_wait r2 | 1320 | +1% | 623 s |
| 20.3 | net_range r8 | 799 | +1% | 261 s |
| 20.4 | cargo r6 | 3906 | +11% | 141 s |
| 20.6 | boat_speed r13 | 3402 | +2% | 527 s |
| 21.0 | double_cast r5 | 2250 | +2% | 444 s |
| 21.2 | net_hold r3 | 3240 | +2% | 491 s |
| 21.4 | net_range r9 | 1015 | +1% | 334 s |
| 21.6 | cargo r7 | 9766 | +10% | 359 s |
| 22.0 | reel r11 | 2355 | +2% | 412 s |
| 22.3 | net_hold r4 | 5832 | +5% | 440 s |
| 22.4 | net_range r10 | 1289 | +2% | 197 s |
| 22.4 | boat_volley r4 | 2470 | +1% | 555 s |
| 23.3 | double_cast r6 | 3465 | +2% | 482 s |
| 23.6 | net_range r11 | 1637 | +1% | 379 s |
| 23.6 | reel r12 | 2779 | +2% | 433 s |
| 23.7 | reel r13 | 3279 | +2% | 558 s |
| 24.3 | net_strength r3 | 26.3k | +27% | 323 s |
| 24.4 | lucky_haul r8 | 3012 | +2% | 499 s |
| 24.6 | reel r14 | 3870 | +1% | 686 s |
| 25.3 | recycle_bonus r6 | 16.2k | +4% | 927 s |
| 25.7 | reel r15 | 4566 | +1% | 1115 s |
| 26.3 | net_width r13 | 4432 | +1% | 747 s |
| 26.5 | lucky_haul r9 | 4096 | +1% | 784 s |
| 26.7 | net_width r14 | 5363 | +2% | 733 s |
| 26.8 | double_cast r7 | 5336 | +2% | 579 s |
| 27.0 | lucky_haul r10 | 5571 | +2% | 748 s |
| 27.1 | net_width r15 | 6489 | +2% | 755 s |
| 27.3 | net_hold r5 | 10.5k | +4% | 692 s |
| 27.7 | net_range r12 | 2079 | +1% | 506 s |
| 27.7 | boat_speed r14 | 4762 | +2% | 570 s |
| 27.7 | boat_speed r15 | 6667 | +2% | 847 s |
| 29.2 | net_range r13 | 2641 | +3% | 244 s |
| 29.2 | cargo r8 | 24.4k | +9% | 707 s |
| 30.1 | net_range r14 | 3354 | +2% | 337 s |
| 30.6 | double_cast r8 | 8217 | +3% | 701 s |
| 31.8 | net_range r15 | 4259 | +2% | 478 s |
| 31.8 | net_hold r6 | 18.9k | +8% | 588 s |
| 33.1 | net_strength r4 | 72.0k | +55% | 337 s |
| 33.3 | reel r16 | 5388 | +1% | 786 s |
| 34.0 | recycle_bonus r7 | 26.1k | +4% | 1004 s |
| 34.7 | reel r17 | 6358 | +1% | 880 s |
| 34.9 | net_width r16 | 7852 | +2% | 755 s |
| 35.1 | net_width r17 | 9501 | +2% | 894 s |
| 35.2 | reel r18 | 7503 | +1% | 1052 s |
| 35.3 | double_cast r9 | 12.7k | +2% | 875 s |
| 35.5 | net_width r18 | 11.5k | +2% | 767 s |
| 35.8 | net_width r19 | 13.9k | +3% | 879 s |
| 36.2 | net_range r16 | 5409 | +3% | 316 s |
| 36.2 | boat_speed r16 | 9334 | +2% | 906 s |
| 37.8 | net_range r17 | 6870 | +3% | 412 s |
| 39.6 | net_range r18 | 8725 | +3% | 696 s |
| 41.0 | net_hold r7 | 34.0k | +7% | 1147 s |
| 41.4 | net_range r19 | 11.1k | +2% | 1110 s |
| 43.4 | dog_strength | 1200 | +0% | never | filler
| 43.6 | net_range r20 | 14.1k | +3% | 949 s |
| 45.6 | dog_fetch r3 | 1620 | +0% | never | filler
| 47.6 | dog_strength r2 | 2640 | +0% | never | filler
| 49.6 | dog_wait r3 | 2904 | +0% | never | filler
| 51.6 | dog_fetch r4 | 2916 | +0% | never | filler

## Bot: casual

- Clear: 90.3 min (seeds: 85, 90, -)
- Purchases: 156, spent 838.7k sludge
- Income/s at 2 / 10 / 30 min: 10.3 / 3.9 / 3.2
- Median payback by phase: 0m 98s, 10m 192s, 20m 343s, 30m 475s, 40m 676s, 50m 664s, 60m 929s, 70m 1855s
- Median seconds from reveal to buy, by group: cargo 20, bird_worth 40, boat_speed 40, net_range 120, dog_count 140, fleet 200, boat_volley 220, net_width 260, lucky_haul 540, reel 660, dog_fetch 700, double_cast 720, net_strength 920, net_hold 940, recycle_bonus 1240, dog_wait 1300, dog_strength 1880

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.3 | cargo | 40 | +36% | 23 s |
| 0.7 | bird_worth | 120 | from zero | never |
| 0.7 | boat_speed | 60 | +14% | 66 s |
| 1.0 | cargo r2 | 100 | +26% | 51 s |
| 1.3 | bird_worth r2 | 216 | from zero | never |
| 1.7 | boat_speed r2 | 84 | +11% | 81 s |
| 1.7 | boat_speed r3 | 118 | +3% | 390 s |
| 2.0 | net_range | 150 | +15% | 98 s |
| 2.3 | dog_count * | 200 | +0% | never |
| 2.7 | cargo r3 * | 250 | +20% | 107 s |
| 3.0 | bird_worth r3 | 389 | from zero | never |
| 3.3 | fleet | 200 | +11% | 124 s |
| 3.7 | net_range r2 | 191 | +30% | 50 s |
| 3.7 | net_range r3 | 242 | +19% | 78 s |
| 3.7 | boat_volley * | 160 | +0% | never |
| 4.0 | net_range r4 | 307 | +14% | 118 s |
| 4.3 | net_width | 450 | +30% | 70 s |
| 4.7 | boat_volley r2 * | 398 | +0% | never |
| 5.0 | bird_worth r4 | 700 | from zero | never |
| 5.3 | net_range r5 | 390 | +11% | 132 s |
| 6.0 | bird_worth r5 | 1260 | from zero | never |
| 7.3 | dog_count r2 | 400 | +4% | 361 s |
| 9.0 | lucky_haul | 350 | +2% | 653 s |
| 10.3 | net_width r2 | 545 | +3% | 645 s |
| 10.3 | boat_speed r4 | 165 | +7% | 78 s |
| 10.7 | boat_speed r5 | 231 | +6% | 119 s |
| 10.7 | boat_speed r6 * | 323 | +5% | 183 s |
| 11.0 | reel | 450 | +3% | 420 s |
| 11.3 | fleet r2 | 500 | +6% | 252 s |
| 11.3 | net_range r6 | 496 | +12% | 115 s |
| 11.7 | net_width r3 | 659 | +16% | 109 s |
| 11.7 | dog_fetch | 500 | +8% | 146 s |
| 12.0 | reel r2 | 531 | +8% | 143 s |
| 12.0 | double_cast * | 400 | +2% | 465 s |
| 12.3 | reel r3 | 627 | +5% | 266 s |
| 13.0 | bird_worth r6 | 2268 | from zero | never |
| 13.3 | net_range r7 | 629 | +7% | 168 s |
| 13.3 | lucky_haul r2 * | 476 | +0% | never |
| 13.7 | boat_speed r7 | 452 | +4% | 198 s |
| 13.7 | boat_speed r8 * | 633 | +0% | never |
| 14.0 | reel r4 * | 739 | +5% | 275 s |
| 14.3 | net_width r4 | 797 | +8% | 182 s |
| 15.0 | dog_fetch r2 * | 900 | +1% | 1313 s |
| 15.3 | net_strength | 3500 | +36% | 172 s |
| 15.7 | cargo r4 | 625 | +4% | 217 s |
| 15.7 | net_hold | 1000 | +12% | 100 s |
| 16.0 | fleet r3 | 1250 | +7% | 194 s |
| 16.3 | dog_count r3 * | 800 | +3% | 318 s |
| 18.0 | net_width r5 * | 965 | +1% | 1299 s |
| 19.0 | reel r5 | 872 | +5% | 191 s |
| 20.3 | net_hold r2 | 1800 | +16% | 109 s |
| 20.3 | double_cast r2 | 616 | +1% | 352 s |
| 20.7 | recycle_bonus | 1500 | +6% | 209 s |
| 21.0 | cargo r5 * | 1563 | +1% | 1352 s |
| 21.0 | reel r6 | 1030 | +4% | 200 s |
| 21.0 | lucky_haul r3 | 647 | +2% | 258 s |
| 21.3 | reel r7 | 1215 | +3% | 260 s |
| 21.3 | double_cast r3 | 949 | +2% | 295 s |
| 21.3 | lucky_haul r4 | 880 | +2% | 396 s |
| 21.7 | recycle_bonus r2 | 2415 | +6% | 294 s |
| 21.7 | dog_wait * | 600 | +0% | never |
| 22.0 | boat_speed r9 | 886 | +2% | 374 s |
| 22.0 | reel r8 | 1434 | +2% | 398 s |
| 22.3 | bird_worth r7 | 4082 | from zero | never |
| 22.7 | net_width r6 | 1167 | +5% | 141 s |
| 23.0 | net_width r7 | 1412 | +3% | 272 s |
| 23.3 | lucky_haul r5 | 1197 | +2% | 398 s |
| 23.3 | recycle_bonus r3 | 3888 | +5% | 457 s |
| 23.3 | net_range r8 * | 799 | +0% | never |
| 23.7 | double_cast r4 | 1461 | +2% | 431 s |
| 24.3 | bird_worth r8 | 7347 | from zero | never |
| 24.7 | reel r9 * | 1692 | +2% | 536 s |
| 25.0 | net_width r8 | 1709 | +3% | 343 s |
| 25.7 | net_range r9 | 1015 | +5% | 144 s |
| 25.7 | cargo r6 * | 3906 | +0% | never |
| 25.7 | net_hold r3 | 3240 | +12% | 163 s |
| 27.7 | net_width r9 | 2068 | +3% | 434 s |
| 27.7 | net_hold r4 | 5832 | +7% | 459 s |
| 30.3 | net_range r10 | 1289 | +4% | 178 s |
| 31.0 | net_width r10 * | 2502 | +2% | 749 s |
| 31.3 | net_strength r2 | 9590 | +31% | 168 s |
| 31.3 | dog_strength * | 1200 | +0% | never |
| 31.7 | reel r10 | 1996 | +3% | 302 s |
| 31.7 | lucky_haul r6 | 1628 | +2% | 415 s |
| 32.0 | recycle_bonus r4 | 6260 | +5% | 512 s |
| 32.7 | recycle_bonus r5 | 10.1k | +5% | 825 s |
| 33.0 | reel r11 * | 2355 | +1% | 1706 s |
| 33.0 | boat_speed r10 | 1240 | +2% | 232 s |
| 33.0 | boat_volley r3 * | 992 | +0% | never |
| 33.0 | double_cast r5 | 2250 | +3% | 306 s |
| 33.3 | dog_fetch r3 * | 1620 | +0% | never |
| 34.7 | net_strength r3 | 26.3k | +21% | 438 s |
| 35.3 | lucky_haul r7 * | 2215 | +0% | never |
| 35.3 | boat_speed r11 | 1736 | +2% | 250 s |
| 35.3 | reel r12 | 2779 | +1% | 782 s |
| 35.3 | boat_speed r12 | 2430 | +1% | 584 s |
| 35.3 | lucky_haul r8 | 3012 | +1% | 568 s |
| 36.0 | recycle_bonus r6 | 16.2k | +5% | 987 s |
| 40.3 | net_width r11 | 3027 | +1% | 559 s |
| 40.3 | net_range r11 * | 1637 | +0% | never |
| 40.3 | double_cast r6 | 3465 | +3% | 361 s |
| 40.7 | reel r13 | 3279 | +2% | 504 s |
| 41.3 | reel r14 * | 3870 | +0% | 9918 s |
| 41.3 | boat_speed r13 | 3402 | +2% | 482 s |
| 42.3 | net_width r12 | 3663 | +1% | 711 s |
| 42.7 | net_range r12 * | 2079 | +0% | never |
| 42.7 | double_cast r7 | 5336 | +3% | 542 s |
| 42.7 | lucky_haul r9 | 4096 | +2% | 761 s |
| 44.0 | dog_fetch r4 * | 2916 | +0% | never |
| 44.7 | net_width r13 | 4432 | +2% | 655 s |
| 44.7 | reel r15 | 4566 | +2% | 867 s |
| 45.0 | net_width r14 | 5363 | +2% | 698 s |
| 45.0 | dog_wait r2 * | 1320 | +0% | never |
| 45.3 | net_range r13 | 2641 | +2% | 527 s |
| 45.3 | reel r16 | 5388 | +2% | 1012 s |
| 49.0 | double_cast r8 * | 8217 | +1% | 2182 s |
| 49.0 | boat_volley r4 | 2470 | +1% | 574 s |
| 49.7 | recycle_bonus r7 * | 26.1k | +4% | 1872 s |
| 51.3 | cargo r7 * | 9766 | +0% | never |
| 51.3 | net_range r14 | 3354 | +4% | 241 s |
| 51.3 | net_hold r5 | 10.5k | +10% | 317 s |
| 53.0 | net_range r15 | 4259 | +5% | 237 s |
| 53.0 | net_hold r6 | 18.9k | +7% | 823 s |
| 53.0 | boat_speed r14 | 4762 | +2% | 587 s |
| 53.7 | boat_speed r15 * | 6667 | +0% | never |
| 54.0 | dog_strength r2 * | 2640 | +0% | never |
| 54.7 | net_range r16 | 5409 | +6% | 248 s |
| 55.0 | net_strength r4 | 72.0k | +42% | 474 s |
| 55.3 | reel r17 | 6358 | +2% | 770 s |
| 55.3 | dog_wait r3 * | 2904 | +0% | never |
| 55.7 | double_cast r9 | 12.7k | +3% | 742 s |
| 57.7 | net_width r15 * | 6489 | +0% | 3286 s |
| 60.3 | lucky_haul r10 | 5571 | +1% | 1236 s | filler
| 60.3 | dog_strength r3 * | 5808 | +0% | never |
| 60.7 | boat_speed r16 * | 9334 | +1% | 3159 s |
| 61.0 | reel r18 | 7503 | +1% | 929 s |
| 61.3 | dog_strength r4 * | 12.8k | +0% | never |
| 62.7 | net_width r16 | 7852 | +2% | 842 s |
| 62.7 | cargo r8 * | 24.4k | +0% | never |
| 63.0 | net_width r17 | 9501 | +2% | 817 s |
| 63.3 | net_width r18 | 11.5k | +3% | 872 s |
| 63.7 | net_width r19 * | 13.9k | +3% | 992 s |
| 63.7 | net_range r17 (with net_hold) | 6870 | +8% | 176 s |
| 64.0 | net_range r18 * | 8725 | +0% | never |
| 65.0 | net_hold r7 | 34.0k | +8% | 926 s |
| 65.3 | reel r19 * | 8853 | +1% | 1311 s |
| 66.0 | boat_speed r17 * | 13.1k | +0% | never |
| 66.0 | reel r20 * | 10.4k | +0% | 9647 s |
| 70.7 | net_range r19 | 11.1k | +0% | never | filler
| 72.7 | net_range r20 | 14.1k | +0% | never | filler
| 73.7 | net_hold r8 * | 61.2k | +8% | 1844 s |
| 74.3 | boat_speed r18 * | 18.3k | +0% | never |
| 75.0 | boat_speed r19 * | 25.6k | +0% | never |
| 77.0 | double_cast r10 * | 19.5k | +3% | 1866 s |
| 80.3 | net_width r20 | 16.8k | +3% | 1413 s | filler
| 82.3 | boat_speed r20 | 35.9k | +0% | never | filler

## Bot: cheapest

- Clear: 270.9 min
- Purchases: 157, spent 880.7k sludge
- Income/s at 2 / 10 / 30 min: 11.9 / 67.5 / 17.4
- Median payback by phase: 0m 193s, 10m 780s, 20m 1768s, 30m 4048s, 40m 1338s, 50m 1186s, 60m 4157s, 110m 1467s, 260m 77s
- Median seconds from reveal to buy, by group: cargo 10, boat_speed 20, bird_worth 65, net_range 80, boat_volley 95, fleet 140, dog_count 150, lucky_haul 220, double_cast 285, net_width 315, reel 330, dog_fetch 395, dog_wait 430, net_hold 675, dog_strength 750, recycle_bonus 895, net_strength 2450

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.2 | cargo | 40 | +36% | 23 s |
| 0.3 | boat_speed | 60 | +14% | 66 s |
| 0.5 | boat_speed r2 | 84 | +11% | 102 s |
| 0.8 | cargo r2 | 100 | +26% | 46 s |
| 0.9 | boat_speed r3 | 118 | +9% | 124 s |
| 1.1 | bird_worth | 120 | +0% | 2511 s |
| 1.3 | net_range | 150 | +5% | 286 s |
| 1.6 | boat_volley | 160 | +0% | 2872 s |
| 1.8 | boat_speed r4 | 165 | +7% | 189 s |
| 2.0 | net_range r2 | 191 | +1% | 2264 s |
| 2.3 | fleet | 200 | +72% | 22 s |
| 2.5 | dog_count | 200 | +5% | 182 s |
| 2.6 | bird_worth r2 | 216 | +0% | 2314 s |
| 2.8 | boat_speed r5 | 231 | +0% | never |
| 2.9 | net_range r3 | 242 | +17% | 71 s |
| 3.1 | cargo r3 | 250 | +0% | never |
| 3.3 | net_range r4 | 307 | +14% | 107 s |
| 3.4 | boat_speed r6 | 323 | +0% | never |
| 3.7 | lucky_haul | 350 | +2% | 772 s |
| 3.9 | bird_worth r3 | 389 | +1% | 3233 s |
| 4.3 | net_range r5 | 390 | +11% | 150 s |
| 4.5 | boat_volley r2 | 398 | +0% | never |
| 4.8 | double_cast | 400 | +2% | 889 s |
| 5.0 | dog_count r2 | 400 | +4% | 360 s |
| 5.3 | net_width | 450 | +28% | 63 s |
| 5.5 | reel | 450 | +8% | 165 s |
| 5.7 | boat_speed r7 | 452 | +1% | 927 s |
| 5.9 | lucky_haul r2 | 476 | +2% | 613 s |
| 6.2 | net_range r6 | 496 | +5% | 280 s |
| 6.4 | fleet r2 | 500 | +5% | 252 s |
| 6.6 | dog_fetch | 500 | +9% | 146 s |
| 6.8 | reel r2 | 531 | +8% | 174 s |
| 7.0 | net_width r2 | 545 | +21% | 62 s |
| 7.2 | dog_wait | 600 | +2% | 700 s |
| 7.3 | double_cast r2 | 616 | +2% | 694 s |
| 7.6 | cargo r4 | 625 | +0% | never |
| 7.8 | reel r3 | 627 | +6% | 218 s |
| 7.9 | net_range r7 | 629 | +12% | 105 s |
| 8.1 | boat_speed r8 | 633 | +0% | never |
| 8.3 | lucky_haul r3 | 647 | +2% | 479 s |
| 8.5 | net_width r3 | 659 | +13% | 89 s |
| 8.7 | bird_worth r4 | 700 | +1% | 1665 s |
| 8.8 | reel r4 | 739 | +5% | 233 s |
| 9.1 | net_width r4 | 797 | +6% | 197 s |
| 9.3 | net_range r8 | 799 | +0% | never |
| 9.4 | dog_count r3 | 800 | +4% | 311 s |
| 9.7 | reel r5 | 872 | +2% | 667 s |
| 9.9 | lucky_haul r4 | 880 | +0% | never |
| 10.1 | boat_speed r9 | 886 | +4% | 358 s |
| 10.3 | dog_fetch r2 | 900 | +0% | never |
| 10.5 | double_cast r3 | 949 | +0% | 8453 s |
| 10.8 | net_width r5 | 965 | +1% | 1324 s |
| 11.0 | boat_volley r3 | 992 | +1% | 1531 s |
| 11.3 | net_hold | 1000 | +0% | never |
| 11.4 | net_range r9 | 1015 | +0% | 6580 s |
| 11.7 | reel r6 | 1030 | +0% | 4152 s |
| 11.9 | net_width r6 | 1167 | +1% | 1444 s |
| 12.3 | lucky_haul r5 | 1197 | +0% | never |
| 12.5 | dog_strength | 1200 | +0% | never |
| 12.8 | reel r7 | 1215 | +0% | 4778 s |
| 13.1 | boat_speed r10 | 1240 | +3% | 527 s |
| 13.3 | fleet r3 | 1250 | +30% | 54 s |
| 13.6 | bird_worth r5 | 1260 | +1% | 1405 s |
| 13.8 | net_range r10 | 1289 | +2% | 627 s |
| 14.0 | dog_wait r2 | 1320 | +0% | never |
| 14.3 | net_width r7 | 1412 | +1% | 1404 s |
| 14.4 | reel r8 | 1434 | +0% | 4603 s |
| 14.7 | double_cast r4 | 1461 | +0% | 5722 s |
| 14.9 | recycle_bonus | 1500 | +6% | 258 s |
| 15.2 | cargo r5 | 1563 | +0% | never |
| 15.4 | dog_fetch r3 | 1620 | +0% | never |
| 15.6 | lucky_haul r6 | 1628 | +3% | 599 s |
| 15.8 | net_range r11 | 1637 | +17% | 111 s |
| 16.1 | reel r9 | 1692 | +2% | 740 s |
| 16.3 | net_width r8 | 1709 | +6% | 319 s |
| 16.6 | boat_speed r11 | 1736 | +0% | never |
| 16.9 | net_hold r2 | 1800 | +3% | 755 s |
| 17.3 | reel r10 | 1996 | +2% | 1091 s |
| 17.6 | net_width r9 | 2068 | +5% | 511 s |
| 17.9 | net_range r12 | 2079 | +24% | 103 s |
| 18.3 | lucky_haul r7 | 2215 | +3% | 780 s |
| 18.6 | double_cast r5 | 2250 | +2% | 1398 s |
| 18.9 | bird_worth r6 | 2268 | +2% | 1445 s |
| 19.3 | reel r11 | 2355 | +2% | 1388 s |
| 19.8 | recycle_bonus r2 | 2415 | +5% | 727 s |
| 20.2 | boat_speed r12 | 2430 | +0% | never |
| 20.8 | boat_volley r4 | 2470 | +0% | never |
| 21.4 | net_width r10 | 2502 | +3% | 1651 s |
| 22.1 | dog_strength r2 | 2640 | +0% | never |
| 23.4 | net_range r13 | 2641 | +334% | 48 s |
| 24.1 | reel r12 | 2779 | +2% | 2062 s |
| 24.8 | dog_wait r3 | 2904 | +0% | never |
| 25.5 | dog_fetch r4 | 2916 | +0% | never |
| 27.0 | lucky_haul r8 | 3012 | +0% | never |
| 29.9 | net_width r11 | 3027 | +9% | 1885 s |
| 32.8 | net_hold r3 | 3240 | +0% | never |
| 35.8 | reel r13 | 3279 | +2% | 8045 s |
| 38.7 | net_range r14 | 3354 | +338% | 52 s |
| 39.3 | boat_speed r13 | 3402 | +0% | never |
| 40.0 | double_cast r6 | 3465 | +1% | 5530 s |
| 40.8 | net_strength | 3500 | +802% | 17 s |
| 41.2 | net_width r12 | 3663 | +1% | 2096 s |
| 41.4 | reel r14 | 3870 | +2% | 838 s |
| 41.7 | recycle_bonus r3 | 3888 | +5% | 330 s |
| 42.0 | cargo r6 | 3906 | +0% | never |
| 42.3 | bird_worth r7 | 4082 | +1% | 1705 s |
| 42.5 | lucky_haul r9 | 4096 | +2% | 919 s |
| 42.8 | net_range r15 | 4259 | +0% | never |
| 43.1 | net_width r13 | 4432 | +1% | 2182 s |
| 43.4 | reel r15 | 4566 | +2% | 1045 s |
| 43.8 | boat_speed r14 | 4762 | +0% | never |
| 44.2 | double_cast r7 | 5336 | +3% | 766 s |
| 44.5 | net_width r14 | 5363 | +1% | 2446 s |
| 44.9 | reel r16 | 5388 | +2% | 1272 s |
| 45.3 | net_range r16 | 5409 | +0% | never |
| 45.7 | lucky_haul r10 | 5571 | +2% | 1404 s |
| 46.1 | dog_strength r3 | 5808 | +0% | never |
| 46.4 | net_hold r4 | 5832 | +10% | 237 s |
| 46.8 | recycle_bonus r4 | 6260 | +5% | 520 s |
| 47.3 | reel r17 | 6358 | +2% | 1449 s |
| 47.7 | net_width r15 | 6489 | +1% | 2494 s |
| 48.0 | boat_speed r15 | 6667 | +0% | never |
| 48.4 | net_range r17 | 6870 | +0% | never |
| 48.9 | bird_worth r8 | 7347 | +1% | 2183 s |
| 49.4 | reel r18 | 7503 | +1% | 1919 s |
| 49.9 | net_width r16 | 7852 | +2% | 1599 s |
| 50.4 | double_cast r8 | 8217 | +3% | 1310 s |
| 50.9 | net_range r18 | 8725 | +11% | 348 s |
| 51.5 | reel r19 | 8853 | +1% | 2611 s |
| 52.1 | boat_speed r16 | 9334 | +0% | never |
| 52.7 | net_width r17 | 9501 | +3% | 1400 s |
| 53.3 | net_strength r2 | 9590 | +95% | 53 s |
| 53.8 | cargo r7 | 9766 | +0% | never |
| 54.3 | recycle_bonus r5 | 10.1k | +4% | 609 s |
| 54.7 | reel r20 | 10.4k | +0% | 11945 s |
| 55.2 | net_hold r5 | 10.5k | +10% | 281 s |
| 55.6 | net_range r19 | 11.1k | +0% | never |
| 56.1 | net_width r18 | 11.5k | +1% | 5006 s |
| 56.6 | double_cast r9 | 12.7k | +3% | 1037 s |
| 57.2 | dog_strength r4 | 12.8k | +0% | never |
| 57.8 | boat_speed r17 | 13.1k | +0% | never |
| 58.3 | net_width r19 | 13.9k | +1% | 6740 s |
| 58.9 | net_range r20 | 14.1k | +0% | never |
| 59.7 | recycle_bonus r6 | 16.2k | +4% | 1063 s |
| 60.4 | net_width r20 | 16.8k | +0% | 9505 s |
| 61.3 | boat_speed r18 | 18.3k | +0% | never |
| 62.1 | net_hold r6 | 18.9k | +4% | 1541 s |
| 63.0 | double_cast r10 | 19.5k | +2% | 4157 s |
| 64.5 | cargo r8 | 24.4k | +0% | never |
| 76.8 | boat_speed r19 | 25.6k | +0% | never |
| 94.8 | recycle_bonus r7 | 26.1k | +0% | never |
| 112.8 | net_strength r3 | 26.3k | +2617% | 41 s |
| 113.7 | net_hold r7 | 34.0k | +4% | 1467 s |
| 114.5 | boat_speed r20 | 35.9k | +0% | never |
| 115.9 | recycle_bonus r8 | 42.1k | +4% | 4713 s |
| 170.4 | net_hold r8 | 61.2k | +0% | never |
| 264.6 | net_strength r4 | 72.0k | +7343% | 77 s |
