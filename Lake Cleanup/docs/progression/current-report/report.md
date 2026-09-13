# Progression sim: Lake Cleanup (current shop)

## Checks

| | check | result |
|---|---|---|
| FAIL | focused clears in 50-70 min | 6.9 min (cleared 99.5%) |
| FAIL | casual clears in 100-140 min | 10.1 min (cleared 99.5%) |
| WARN | early buys every 10-60 s (first 10 min) | median gap 0 s |
| PASS | no gap between buys over 300 s | longest 120 s at 3.1-5.1 min |
| FAIL | every buy raises income at least 8% | boat_speed +6.0%, boat_speed r2 +5.8%, boat_speed r3 +6.8%, boat_speed r4 +7.8%, boat_speed r5 +6.3%, cargo r8 +7.7% |
| PASS | no single pick wins by 3x in over 50% of choices | median best/second 1.34x; over 3x in 12%; "cargo" top pick 31% |
| FAIL | payback within 4x of its phase median | cargo too strong for price (3 s vs 13 s); skimmer r3 too strong for price (2 s vs 13 s); cargo r5 too strong for price (2 s vs 13 s); net_range r2 too strong for price (2 s vs 13 s); net_range r4 too strong for price (1 s vs 13 s); net_range r6 too strong for price (1 s vs 13 s) |
| FAIL | ferry capacity within 0.8-1.5x of catch rate | inside 0%, lagging 7%, overrunning 93%; box peaked at 1 |
| PASS | no bought node whose only value is what it unlocks | none |
| WARN | every node earns its purchase, none only in the last 15% | 1 bought only as filler (earned nothing); 0 never bought; 0 first bought late |

## Bot: focused

- Clear: 6.9 min
- Purchases: 106, spent 102.1k sludge
- Income/s at 2 / 10 / 30 min: 2206.0 / - / -
- Median payback by phase: 0m 13s
- Median seconds from reveal to buy, by group: cargo 5, boat_speed 10, net_range 10, skimmer 10, fleet 20, dog_fetch 30, net_width 35, reel 40, dog_wait 45, net_strength 60, net_hold 305

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.1 | cargo | 14 | +67% | 3 s |
| 0.1 | cargo r2 | 18 | +40% | 4 s |
| 0.2 | boat_speed | 14 | +6% | 14 s |
| 0.2 | net_range | 16 | +8% | 11 s |
| 0.2 | skimmer | 26 | +9% | 16 s |
| 0.2 | boat_speed r2 | 19 | +6% | 16 s |
| 0.3 | skimmer r2 | 39 | +15% | 12 s |
| 0.3 | cargo r3 | 24 | +24% | 4 s |
| 0.3 | cargo r4 | 31 | +18% | 6 s |
| 0.3 | boat_speed r3 | 26 | +7% | 11 s |
| 0.3 | fleet | 200 | +54% | 10 s |
| 0.4 | skimmer r3 | 57 | +48% | 2 s |
| 0.4 | cargo r5 | 40 | +20% | 2 s |
| 0.4 | cargo r6 | 52 | +13% | 4 s |
| 0.4 | boat_speed r4 | 34 | +8% | 4 s |
| 0.4 | cargo r7 | 68 | +15% | 4 s |
| 0.4 | boat_speed r5 | 47 | +6% | 5 s |
| 0.5 | cargo r8 | 88 | +8% | 8 s |
| 0.5 | net_range r2 | 21 | +6% | 2 s |
| 0.5 | cargo r9 | 114 | +11% | 6 s |
| 0.5 | boat_speed r6 | 63 | +5% | 7 s |
| 0.5 | cargo r10 | 149 | +7% | 10 s |
| 0.5 | dog_fetch | 18 | +2% | 4 s |
| 0.5 | boat_speed r7 | 85 | +3% | 13 s |
| 0.5 | net_range r3 | 29 | +2% | 7 s |
| 0.6 | fleet r2 | 400 | +31% | 6 s |
| 0.6 | net_range r4 | 39 | +13% | 1 s |
| 0.6 | skimmer r4 | 84 | +2% | 11 s |
| 0.6 | cargo r11 | 193 | +7% | 8 s |
| 0.6 | net_width | 22 | +1% | 5 s |
| 0.6 | net_range r5 | 52 | +1% | 10 s |
| 0.6 | cargo r12 | 251 | +8% | 8 s |
| 0.6 | boat_speed r8 | 114 | +4% | 7 s |
| 0.6 | boat_speed r9 | 155 | +3% | 11 s |
| 0.7 | cargo r13 | 326 | +7% | 11 s |
| 0.7 | net_width r2 | 35 | +1% | 9 s |
| 0.7 | fleet r3 | 800 | +11% | 15 s |
| 0.7 | net_range r6 | 69 | +19% | 1 s |
| 0.7 | reel | 22 | +1% | 7 s |
| 0.7 | skimmer r5 | 125 | +2% | 13 s |
| 0.7 | cargo r14 | 424 | +7% | 9 s |
| 0.7 | cargo r15 | 551 | +8% | 10 s |
| 0.8 | boat_speed r10 | 209 | +2% | 13 s |
| 0.8 | net_width r3 | 56 | +1% | 8 s |
| 0.8 | boat_speed r11 | 282 | +2% | 19 s |
| 0.8 | dog_wait | 16 | +0% | 19 s |
| 0.8 | reel r2 | 33 | +0% | 19 s |
| 0.8 | cargo r16 | 717 | +4% | 23 s |
| 0.8 | net_range r7 | 93 | +2% | 5 s |
| 0.8 | fleet r4 | 1600 | +24% | 8 s |
| 0.8 | net_width r4 | 90 | +1% | 14 s |
| 0.8 | skimmer r6 | 185 | +1% | 18 s |
| 0.8 | skimmer r7 | 273 | +2% | 15 s |
| 0.8 | boat_speed r12 | 380 | +2% | 16 s |
| 0.8 | cargo r17 | 932 | +5% | 17 s |
| 0.8 | net_range r8 | 124 | +2% | 7 s |
| 0.8 | cargo r18 | 1211 | +6% | 16 s |
| 0.8 | cargo r19 | 1574 | +6% | 21 s |
| 0.8 | boat_speed r13 | 513 | +2% | 20 s |
| 0.8 | boat_speed r14 | 693 | +2% | 30 s |
| 0.8 | skimmer r8 | 404 | +1% | 32 s |
| 0.9 | skimmer r9 | 599 | +2% | 21 s |
| 0.9 | cargo r20 | 2047 | +6% | 26 s |
| 0.9 | cargo r21 | 2661 | +5% | 34 s |
| 0.9 | boat_speed r15 | 935 | +1% | 42 s |
| 1.0 | net_strength | 150 | +2% | 5 s |
| 1.0 | reel r3 | 51 | +0% | 11 s |
| 1.0 | cargo r22 | 3459 | +2% | 91 s |
| 1.0 | net_range r9 | 166 | +3% | 4 s |
| 1.0 | boat_speed r16 | 1262 | +1% | 55 s |
| 1.0 | skimmer r10 | 886 | +1% | 67 s |
| 1.1 | cargo r23 | 4497 | +5% | 56 s |
| 1.1 | cargo r24 | 5846 | +4% | 73 s |
| 1.1 | boat_speed r17 | 1704 | +1% | 119 s |
| 1.1 | dog_wait r2 | 30 | +0% | 3 s |
| 1.2 | cargo r25 | 7599 | +3% | 129 s |
| 1.2 | dog_fetch r2 | 34 | +0% | 10 s |
| 1.2 | dog_wait r3 | 58 | +0% | 13 s |
| 1.2 | net_range r10 | 223 | +1% | 8 s |
| 1.3 | boat_speed r18 | 2300 | +1% | 104 s |
| 1.3 | cargo r26 | 9879 | +4% | 121 s |
| 1.4 | cargo r27 | 12.8k | +5% | 135 s |
| 1.5 | net_width r5 | 144 | +1% | 11 s |
| 1.5 | reel r4 | 77 | +0% | 13 s |
| 1.5 | net_range r11 | 299 | +2% | 6 s |
| 1.5 | cargo r28 | 16.7k | +4% | 207 s |
| 2.9 | reel r5 | 117 | +0% | 153 s |
| 3.0 | reel r6 | 179 | +0% | 261 s |
| 3.0 | reel r7 | 271 | +0% | 431 s |
| 3.0 | reel r8 | 412 | +0% | 721 s |
| 3.1 | net_width r6 | 231 | +0% | 397 s |
| 3.1 | reel r9 | 627 | +0% | 1048 s |
| 5.1 | net_hold | 22 | +0% | never | filler
| 5.1 | net_hold r2 | 34 | +8% | 15 s |
| 5.1 | net_width r7 | 369 | +7% | 163 s |
| 5.1 | net_hold r3 | 53 | +5% | 31 s |
| 5.1 | net_width r8 | 591 | +12% | 140 s |
| 5.1 | net_width r9 | 945 | +7% | 342 s |
| 5.1 | net_hold r4 | 82 | +5% | 37 s |
| 5.1 | net_width r10 | 1512 | +9% | 386 s |
| 5.1 | net_hold r5 | 127 | +2% | 108 s |
| 5.1 | net_width r11 | 2419 | +9% | 557 s |
| 5.1 | net_hold r6 | 197 | +2% | 219 s |
| 5.1 | reel r10 | 953 | +2% | 774 s |
| 5.1 | net_width r12 | 3870 | +9% | 798 s |
| 5.1 | net_hold r7 | 305 | +1% | 803 s |

## Bot: casual

- Clear: 10.1 min (seeds: 10, 10, 10)
- Purchases: 127, spent 175.7k sludge
- Income/s at 2 / 10 / 30 min: 1238.2 / 4.9 / -
- Median payback by phase: 0m 29s
- Median seconds from reveal to buy, by group: cargo 20, boat_speed 20, net_width 20, skimmer 20, fleet 40, reel 40, net_range 40, net_hold 60, dog_fetch 60, dog_wait 60, net_strength 100

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.3 | cargo | 14 | +67% | 3 s |
| 0.3 | cargo r2 | 18 | +40% | 4 s |
| 0.3 | boat_speed | 14 | +4% | 21 s |
| 0.3 | net_width | 22 | +14% | 10 s |
| 0.3 | boat_speed r2 | 19 | +8% | 12 s |
| 0.3 | skimmer * | 26 | +9% | 14 s |
| 0.3 | cargo r3 | 24 | +4% | 24 s |
| 0.7 | skimmer r2 | 39 | +41% | 4 s |
| 0.7 | cargo r4 | 31 | +17% | 6 s |
| 0.7 | fleet | 200 | +53% | 11 s |
| 0.7 | skimmer r3 | 57 | +43% | 2 s |
| 0.7 | cargo r5 | 40 | +20% | 3 s |
| 0.7 | boat_speed r3 | 26 | +10% | 3 s |
| 0.7 | reel * | 22 | +0% | never |
| 0.7 | cargo r6 | 52 | +13% | 4 s |
| 0.7 | boat_speed r4 | 34 | +7% | 4 s |
| 0.7 | cargo r7 | 68 | +7% | 7 s |
| 0.7 | net_range * | 16 | +8% | 2 s |
| 1.0 | net_range r2 | 21 | +4% | 4 s |
| 1.0 | boat_speed r5 * | 47 | +6% | 5 s |
| 1.0 | net_range r3 * | 29 | +0% | 224 s |
| 1.0 | cargo r8 | 88 | +13% | 4 s |
| 1.0 | cargo r9 * | 114 | +11% | 6 s |
| 1.0 | net_hold * | 22 | +0% | never |
| 1.0 | net_width r2 * | 35 | +0% | 613 s |
| 1.0 | fleet r2 | 400 | +44% | 5 s |
| 1.0 | dog_fetch * | 18 | +2% | 3 s |
| 1.0 | net_range r4 | 39 | +2% | 7 s |
| 1.0 | boat_speed r6 | 63 | +5% | 4 s |
| 1.0 | cargo r10 | 149 | +10% | 5 s |
| 1.0 | boat_speed r7 | 85 | +4% | 6 s |
| 1.0 | boat_speed r8 | 114 | +3% | 9 s |
| 1.0 | dog_wait * | 16 | +0% | 202 s |
| 1.0 | skimmer r4 | 84 | +3% | 9 s |
| 1.0 | dog_wait r2 * | 30 | +0% | never |
| 1.0 | fleet r3 * | 800 | +14% | 16 s |
| 1.0 | dog_wait r3 * | 58 | +2% | 8 s |
| 1.0 | net_range r5 | 52 | +15% | 1 s |
| 1.3 | net_range r6 * | 69 | +12% | 1 s |
| 1.3 | cargo r11 | 193 | +9% | 4 s |
| 1.3 | net_width r3 * | 56 | +0% | 70 s |
| 1.3 | cargo r12 | 251 | +7% | 6 s |
| 1.3 | skimmer r5 | 125 | +2% | 12 s |
| 1.3 | net_range r7 * | 93 | +0% | never |
| 1.3 | cargo r13 * | 326 | +8% | 7 s |
| 1.3 | boat_speed r9 | 155 | +3% | 8 s |
| 1.3 | cargo r14 | 424 | +7% | 9 s |
| 1.3 | reel r2 * | 33 | +0% | 14910 s |
| 1.3 | fleet r4 | 1600 | +25% | 9 s |
| 1.3 | cargo r15 | 551 | +8% | 8 s |
| 1.3 | net_range r8 * | 124 | +0% | 983 s |
| 1.3 | boat_speed r10 | 209 | +3% | 8 s |
| 1.3 | reel r3 * | 51 | +0% | 10702 s |
| 1.3 | boat_speed r11 | 282 | +2% | 12 s |
| 1.3 | cargo r16 | 717 | +6% | 12 s |
| 1.3 | cargo r17 | 932 | +7% | 13 s |
| 1.3 | skimmer r6 | 185 | +1% | 15 s |
| 1.3 | boat_speed r12 | 380 | +2% | 16 s |
| 1.7 | net_range r9 | 166 | +6% | 3 s |
| 1.7 | cargo r18 * | 1211 | +6% | 16 s |
| 1.7 | skimmer r7 | 273 | +1% | 15 s |
| 1.7 | cargo r19 | 1574 | +6% | 21 s |
| 1.7 | dog_fetch r2 * | 34 | +0% | never |
| 1.7 | boat_speed r13 | 513 | +2% | 20 s |
| 1.7 | cargo r20 | 2047 | +6% | 27 s |
| 1.7 | boat_speed r14 | 693 | +2% | 29 s |
| 1.7 | skimmer r8 * | 404 | +1% | 32 s |
| 1.7 | net_strength * | 150 | +0% | 510 s |
| 1.7 | skimmer r9 | 599 | +2% | 20 s |
| 1.7 | cargo r21 | 2661 | +5% | 34 s |
| 1.7 | boat_speed r15 | 935 | +2% | 39 s |
| 1.7 | net_range r10 * | 223 | +0% | never |
| 1.7 | net_hold r2 | 34 | +4% | 1 s |
| 1.7 | cargo r22 | 3459 | +5% | 44 s |
| 1.7 | boat_speed r16 | 1262 | +1% | 55 s |
| 1.7 | cargo r23 | 4497 | +5% | 56 s |
| 1.7 | skimmer r10 | 886 | +1% | 67 s |
| 1.7 | cargo r24 | 5846 | +4% | 73 s |
| 2.0 | boat_speed r17 | 1704 | +1% | 73 s |
| 2.0 | cargo r25 | 7599 | +5% | 81 s |
| 2.0 | boat_speed r18 | 2300 | +1% | 102 s |
| 2.0 | net_width r4 * | 90 | +0% | 6021 s |
| 2.0 | cargo r26 | 9879 | +4% | 121 s |
| 2.0 | net_strength r2 * | 900 | +0% | never |
| 2.0 | cargo r27 | 12.8k | +5% | 135 s |
| 2.0 | net_width r5 * | 144 | +0% | 1795 s |
| 2.3 | net_range r11 | 299 | +12% | 1 s |
| 2.3 | cargo r28 * | 16.7k | +2% | 375 s |
| 3.0 | net_hold r3 | 53 | +0% | 32 s |
| 3.3 | net_hold r4 * | 82 | +0% | 140 s |
| 3.3 | net_hold r5 * | 127 | +0% | 296 s |
| 3.3 | net_strength r3 * | 5400 | +0% | 14772 s |
| 3.3 | reel r4 * | 77 | +0% | 22 s |
| 3.3 | reel r5 | 117 | +0% | 39 s |
| 3.3 | net_width r6 | 231 | +0% | 57 s |
| 3.3 | net_hold r6 | 197 | +0% | 138 s |
| 3.3 | reel r6 * | 179 | +0% | 141 s |
| 3.3 | net_width r7 | 369 | +0% | 156 s |
| 3.3 | net_hold r7 | 305 | +0% | 204 s |
| 3.3 | net_range r12 | 400 | +0% | 150 s |
| 3.3 | reel r7 | 271 | +0% | 158 s |
| 3.3 | net_width r8 | 591 | +0% | 249 s |
| 3.3 | net_hold r8 | 473 | +0% | 182 s |
| 3.3 | reel r8 | 412 | +0% | 222 s |
| 3.3 | reel r9 * | 627 | +0% | 374 s |
| 3.3 | net_hold r9 | 733 | +0% | 265 s |
| 3.3 | net_width r9 | 945 | +0% | 246 s |
| 3.3 | net_hold r10 | 1136 | +0% | 342 s |
| 3.3 | net_width r10 | 1512 | +0% | 351 s |
| 3.7 | dog_fetch r3 * | 65 | +0% | never |
| 3.7 | net_width r11 | 2419 | +1% | 521 s |
| 3.7 | net_range r13 * | 536 | +0% | never |
| 3.7 | net_hold r11 * | 1761 | +0% | 803 s |
| 3.7 | reel r10 | 953 | +0% | 457 s |
| 3.7 | reel r11 | 1448 | +0% | 785 s |
| 3.7 | net_width r12 | 3870 | +1% | 830 s |
| 3.7 | net_hold r12 | 2729 | +0% | 1037 s |
| 3.7 | dog_fetch r4 * | 124 | +0% | never |
| 5.7 | net_range r14 | 719 | +0% | 6634 s | filler
| 5.7 | reel r12 * | 2201 | +2% | 4984 s |
| 7.7 | net_range r15 * | 963 | +0% | 9786 s |
| 7.7 | net_width r13 * | 6192 | +7% | 4125 s |
| 7.7 | reel r13 * | 3346 | +1% | 10503 s |
| 7.7 | net_strength r4 * | 32.4k | +0% | never |
| 8.3 | net_range r16 * | 1290 | +0% | 18309 s |
| 8.3 | net_hold r13 * | 4231 | +0% | never |
| 8.3 | net_hold r14 * | 6557 | +0% | never |

## Bot: cheapest

- Clear: 5.7 min
- Purchases: 136, spent 333.5k sludge
- Income/s at 2 / 10 / 30 min: 573.5 / - / -
- Median payback by phase: 0m 65s
- Median seconds from reveal to buy, by group: boat_speed 5, cargo 5, net_range 10, dog_wait 10, dog_fetch 10, net_width 15, reel 15, net_hold 20, skimmer 20, net_strength 65, fleet 75

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.1 | boat_speed | 14 | +18% | 11 s |
| 0.1 | cargo | 14 | +67% | 3 s |
| 0.2 | net_range | 16 | +0% | never |
| 0.2 | dog_wait | 16 | +0% | never |
| 0.2 | dog_fetch | 18 | +0% | never |
| 0.2 | cargo r2 | 18 | +40% | 3 s |
| 0.3 | boat_speed r2 | 19 | +5% | 21 s |
| 0.3 | net_range r2 | 21 | +0% | never |
| 0.3 | net_width | 22 | +0% | never |
| 0.3 | reel | 22 | +7% | 15 s |
| 0.3 | net_hold | 22 | +0% | never |
| 0.3 | cargo r3 | 24 | +0% | never |
| 0.3 | boat_speed r3 | 26 | +0% | never |
| 0.3 | skimmer | 26 | +18% | 7 s |
| 0.4 | net_range r3 | 29 | +0% | never |
| 0.4 | dog_wait r2 | 30 | +2% | 86 s |
| 0.4 | cargo r4 | 31 | +0% | 1325 s |
| 0.4 | reel r2 | 33 | +6% | 23 s |
| 0.4 | net_hold r2 | 34 | +23% | 6 s |
| 0.5 | dog_fetch r2 | 34 | +1% | 117 s |
| 0.5 | boat_speed r4 | 34 | +1% | 114 s |
| 0.5 | net_width r2 | 35 | +0% | never |
| 0.5 | net_range r4 | 39 | +0% | never |
| 0.5 | skimmer r2 | 39 | +51% | 3 s |
| 0.6 | cargo r5 | 40 | +11% | 8 s |
| 0.6 | boat_speed r5 | 47 | +3% | 32 s |
| 0.6 | reel r3 | 51 | +4% | 27 s |
| 0.6 | net_range r5 | 52 | +0% | never |
| 0.6 | cargo r6 | 52 | +0% | never |
| 0.7 | net_hold r3 | 53 | +21% | 5 s |
| 0.7 | net_width r3 | 56 | +0% | never |
| 0.7 | skimmer r3 | 57 | +11% | 9 s |
| 0.7 | dog_wait r3 | 58 | +0% | never |
| 0.8 | boat_speed r6 | 63 | +5% | 18 s |
| 0.8 | dog_fetch r3 | 65 | +0% | never |
| 0.8 | cargo r7 | 68 | +15% | 7 s |
| 0.8 | net_range r6 | 69 | +0% | 2721 s |
| 0.8 | reel r4 | 77 | +0% | never |
| 0.8 | net_hold r4 | 82 | +0% | never |
| 0.8 | skimmer r4 | 84 | +3% | 41 s |
| 0.8 | boat_speed r7 | 85 | +4% | 24 s |
| 0.8 | cargo r8 | 88 | +13% | 8 s |
| 0.8 | net_width r4 | 90 | +0% | never |
| 0.9 | net_range r7 | 93 | +0% | 2896 s |
| 0.9 | cargo r9 | 114 | +11% | 11 s |
| 0.9 | boat_speed r8 | 114 | +4% | 29 s |
| 0.9 | reel r5 | 117 | +0% | never |
| 1.0 | dog_fetch r4 | 124 | +0% | never |
| 1.0 | net_range r8 | 124 | +0% | 4214 s |
| 1.0 | skimmer r5 | 125 | +2% | 68 s |
| 1.0 | net_hold r5 | 127 | +0% | never |
| 1.0 | net_width r5 | 144 | +0% | never |
| 1.1 | cargo r10 | 149 | +10% | 13 s |
| 1.1 | net_strength | 150 | +2% | 73 s |
| 1.1 | boat_speed r9 | 155 | +3% | 39 s |
| 1.2 | net_range r9 | 166 | +0% | never |
| 1.2 | reel r6 | 179 | +0% | 1261 s |
| 1.2 | skimmer r6 | 185 | +2% | 81 s |
| 1.2 | cargo r11 | 193 | +9% | 17 s |
| 1.3 | net_hold r6 | 197 | +0% | 348 s |
| 1.3 | fleet | 200 | +98% | 1 s |
| 1.3 | boat_speed r10 | 209 | +3% | 27 s |
| 1.3 | net_range r10 | 223 | +0% | never |
| 1.3 | net_width r6 | 231 | +0% | never |
| 1.3 | cargo r12 | 251 | +8% | 11 s |
| 1.3 | reel r7 | 271 | +0% | 1657 s |
| 1.3 | skimmer r7 | 273 | +2% | 48 s |
| 1.3 | boat_speed r11 | 282 | +2% | 36 s |
| 1.4 | net_range r11 | 299 | +0% | never |
| 1.4 | net_hold r7 | 305 | +0% | 696 s |
| 1.4 | cargo r13 | 326 | +7% | 14 s |
| 1.4 | net_width r7 | 369 | +0% | never |
| 1.4 | boat_speed r12 | 380 | +2% | 50 s |
| 1.5 | fleet r2 | 400 | +50% | 2 s |
| 1.5 | net_range r12 | 400 | +0% | never |
| 1.5 | skimmer r8 | 404 | +1% | 55 s |
| 1.5 | reel r8 | 412 | +0% | 2748 s |
| 1.5 | cargo r14 | 424 | +7% | 11 s |
| 1.6 | net_hold r8 | 473 | +0% | 1092 s |
| 1.6 | boat_speed r13 | 513 | +2% | 46 s |
| 1.6 | net_range r13 | 536 | +0% | never |
| 1.6 | cargo r15 | 551 | +8% | 12 s |
| 1.6 | net_width r8 | 591 | +0% | never |
| 1.7 | skimmer r9 | 599 | +2% | 44 s |
| 1.7 | reel r9 | 627 | +0% | 5559 s |
| 1.7 | boat_speed r14 | 693 | +2% | 62 s |
| 1.7 | cargo r16 | 717 | +6% | 18 s |
| 1.7 | net_range r14 | 719 | +0% | never |
| 1.8 | net_hold r9 | 733 | +0% | 1944 s |
| 1.8 | fleet r3 | 800 | +33% | 3 s |
| 1.8 | skimmer r10 | 886 | +1% | 86 s |
| 1.8 | net_strength r2 | 900 | +0% | never |
| 1.8 | cargo r17 | 932 | +7% | 15 s |
| 1.8 | boat_speed r15 | 935 | +2% | 60 s |
| 1.8 | net_width r9 | 945 | +0% | never |
| 1.8 | reel r10 | 953 | +0% | 9312 s |
| 1.8 | net_range r15 | 963 | +0% | never |
| 1.9 | net_hold r10 | 1136 | +0% | 2912 s |
| 1.9 | cargo r18 | 1211 | +6% | 19 s |
| 1.9 | boat_speed r16 | 1262 | +1% | 83 s |
| 1.9 | net_range r16 | 1290 | +0% | never |
| 2.0 | reel r11 | 1448 | +0% | 13299 s |
| 2.0 | net_width r10 | 1512 | +0% | never |
| 2.0 | cargo r19 | 1574 | +6% | 25 s |
| 2.0 | fleet r4 | 1600 | +25% | 5 s |
| 2.1 | boat_speed r17 | 1704 | +1% | 93 s |
| 2.1 | net_hold r11 | 1761 | +0% | 5418 s |
| 2.1 | cargo r20 | 2047 | +5% | 25 s |
| 2.1 | reel r12 | 2201 | +0% | 18248 s |
| 2.2 | boat_speed r18 | 2300 | +1% | 129 s |
| 2.2 | net_width r11 | 2419 | +0% | never |
| 2.2 | cargo r21 | 2661 | +5% | 33 s |
| 2.3 | net_hold r12 | 2729 | +0% | 6259 s |
| 2.3 | reel r13 | 3346 | +0% | 25875 s |
| 2.3 | cargo r22 | 3459 | +5% | 42 s |
| 2.3 | net_width r12 | 3870 | +0% | never |
| 2.3 | net_hold r13 | 4231 | +0% | 7688 s |
| 2.4 | cargo r23 | 4497 | +5% | 55 s |
| 2.4 | reel r14 | 5086 | +0% | never |
| 2.5 | net_strength r3 | 5400 | +0% | 10950 s |
| 2.6 | cargo r24 | 5846 | +4% | 71 s |
| 2.6 | net_width r13 | 6192 | +0% | never |
| 2.7 | net_hold r14 | 6557 | +0% | 9879 s |
| 2.8 | cargo r25 | 7599 | +5% | 80 s |
| 2.8 | reel r15 | 7731 | +0% | never |
| 2.8 | cargo r26 | 9879 | +3% | 164 s |
| 2.9 | net_hold r15 | 10.2k | +0% | 2117 s |
| 3.0 | reel r16 | 11.8k | +0% | 8565 s |
| 3.2 | cargo r27 | 12.8k | +1% | 555 s |
| 3.3 | net_hold r16 | 15.8k | +1% | 1617 s |
| 3.4 | cargo r28 | 16.7k | +0% | 2197 s |
| 3.5 | reel r17 | 17.9k | +0% | 10307 s |
| 3.7 | net_hold r17 | 24.4k | +0% | 8470 s |
| 3.9 | reel r18 | 27.1k | +0% | 28279 s |
| 4.1 | net_strength r4 | 32.4k | +0% | 12856 s |
| 4.5 | net_hold r18 | 37.8k | +0% | never |

## Bot: no_skimmer

- Clear: 20.4 min
- Purchases: 99, spent 192.0k sludge
- Income/s at 2 / 10 / 30 min: 30.6 / 442.4 / -
- Median payback by phase: 0m 64s, 10m 695s
- Median seconds from reveal to buy, by group: cargo 5, boat_speed 10, net_range 10, dog_fetch 10, net_width 15, reel 15, dog_wait 15, net_strength 30, net_hold 305, fleet 310

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.1 | cargo | 14 | +67% | 3 s |
| 0.1 | cargo r2 | 18 | +40% | 4 s |
| 0.2 | boat_speed | 14 | +6% | 14 s |
| 0.2 | net_range | 16 | +8% | 11 s |
| 0.2 | dog_fetch | 18 | +3% | 34 s |
| 0.2 | boat_speed r2 | 19 | +3% | 33 s |
| 0.3 | net_width | 22 | +8% | 14 s |
| 0.3 | reel | 22 | +3% | 39 s |
| 0.3 | cargo r3 | 24 | +4% | 27 s |
| 0.3 | reel r2 | 33 | +6% | 25 s |
| 0.3 | dog_wait | 16 | +1% | 56 s |
| 0.3 | reel r3 | 51 | +5% | 43 s |
| 0.3 | reel r4 | 77 | +4% | 76 s |
| 0.4 | dog_wait r2 | 30 | +1% | 83 s |
| 0.4 | dog_fetch r2 | 34 | +1% | 116 s |
| 0.4 | dog_wait r3 | 58 | +2% | 107 s |
| 0.5 | net_strength | 150 | +4% | 144 s |
| 0.6 | reel r5 | 117 | +3% | 157 s |
| 0.6 | boat_speed r3 | 26 | +1% | 172 s |
| 0.7 | reel r6 | 179 | +3% | 239 s |
| 0.8 | reel r7 | 271 | +2% | 437 s |
| 1.1 | reel r8 | 412 | +2% | 799 s |
| 3.1 | net_range r2 | 21 | +0% | never | filler
| 5.1 | net_hold | 22 | +0% | never | filler
| 5.1 | net_hold r2 | 34 | +7% | 16 s |
| 5.1 | cargo r4 | 31 | +20% | 5 s |
| 5.1 | net_hold r3 | 53 | +2% | 80 s |
| 5.1 | boat_speed r4 | 34 | +7% | 12 s |
| 5.1 | net_range r3 | 29 | +0% | 202 s |
| 5.1 | cargo r5 | 40 | +23% | 4 s |
| 5.1 | boat_speed r5 | 47 | +1% | 93 s |
| 5.1 | net_width r2 | 35 | +2% | 36 s |
| 5.1 | net_hold r4 | 82 | +3% | 46 s |
| 5.1 | cargo r6 | 52 | +15% | 6 s |
| 5.1 | cargo r7 | 68 | +8% | 14 s |
| 5.1 | net_width r3 | 56 | +2% | 34 s |
| 5.1 | net_hold r5 | 127 | +5% | 35 s |
| 5.1 | cargo r8 | 88 | +14% | 9 s |
| 5.1 | boat_speed r6 | 63 | +2% | 37 s |
| 5.1 | net_hold r6 | 197 | +3% | 75 s |
| 5.1 | cargo r9 | 114 | +6% | 21 s |
| 5.1 | net_range r4 | 39 | +6% | 7 s |
| 5.1 | boat_speed r7 | 85 | +4% | 20 s |
| 5.2 | boat_speed r8 | 114 | +1% | 83 s |
| 5.2 | net_width r4 | 90 | +1% | 109 s |
| 5.2 | net_hold r7 | 305 | +2% | 190 s |
| 5.2 | fleet | 200 | +20% | 9 s |
| 5.2 | net_hold r8 | 473 | +10% | 36 s |
| 5.2 | net_width r5 | 144 | +7% | 14 s |
| 5.2 | net_hold r9 | 733 | +14% | 36 s |
| 5.2 | net_width r6 | 231 | +6% | 23 s |
| 5.2 | net_hold r10 | 1136 | +13% | 48 s |
| 5.2 | net_range r5 | 52 | +1% | 22 s |
| 5.2 | reel r9 | 627 | +2% | 135 s |
| 5.2 | cargo r10 | 149 | +1% | 83 s |
| 5.2 | net_hold r11 | 1761 | +10% | 83 s |
| 5.2 | boat_speed r9 | 155 | +2% | 28 s |
| 5.3 | net_width r7 | 369 | +2% | 88 s |
| 5.3 | cargo r11 | 193 | +1% | 150 s |
| 5.3 | reel r10 | 953 | +3% | 150 s |
| 5.5 | net_hold r12 | 2729 | +8% | 145 s |
| 5.5 | boat_speed r10 | 209 | +1% | 85 s |
| 5.5 | net_range r6 | 69 | +1% | 19 s |
| 5.6 | reel r11 | 1448 | +0% | 1190 s |
| 5.6 | cargo r12 | 251 | +2% | 44 s |
| 5.8 | net_hold r13 | 4231 | +7% | 212 s |
| 5.8 | boat_speed r11 | 282 | +2% | 39 s |
| 5.9 | net_range r7 | 93 | +1% | 21 s |
| 5.9 | cargo r13 | 326 | +1% | 197 s |
| 6.0 | reel r12 | 2201 | +2% | 296 s |
| 6.2 | reel r13 | 3346 | +2% | 538 s |
| 6.3 | net_width r8 | 591 | +1% | 324 s |
| 6.5 | reel r14 | 5086 | +2% | 905 s |
| 6.6 | net_width r9 | 945 | +0% | 829 s |
| 6.9 | net_width r10 | 1512 | +1% | 649 s |
| 7.1 | net_hold r14 | 6557 | +2% | 1125 s |
| 7.1 | fleet r2 | 400 | +7% | 18 s |
| 7.1 | net_strength r2 | 900 | +4% | 64 s |
| 7.5 | net_hold r15 | 10.2k | +12% | 229 s |
| 7.7 | net_width r11 | 2419 | +1% | 509 s |
| 7.8 | net_strength r3 | 5400 | +2% | 601 s |
| 8.4 | net_width r12 | 3870 | +2% | 524 s |
| 8.6 | net_width r13 | 6192 | +2% | 773 s |
| 8.8 | net_range r8 | 124 | +1% | 22 s |
| 8.8 | net_hold r16 | 15.8k | +13% | 318 s |
| 9.5 | reel r15 | 7731 | +2% | 1069 s |
| 9.8 | net_range r9 | 166 | +2% | 22 s |
| 10.1 | net_hold r17 | 24.4k | +11% | 512 s |
| 11.3 | net_strength r4 | 32.4k | +8% | 923 s |
| 12.2 | net_range r10 | 223 | +1% | 35 s |
| 12.6 | net_hold r18 | 37.8k | +10% | 831 s |
| 12.6 | boat_speed r12 | 380 | +0% | 744 s |
| 13.8 | net_range r11 | 299 | +1% | 82 s |
| 15.8 | dog_fetch r3 | 65 | +0% | never | filler
| 16.2 | net_range r12 | 400 | +2% | 50 s |
| 17.5 | net_range r13 | 536 | +0% | 647 s |
| 17.6 | net_range r14 | 719 | +0% | 1070 s |
| 17.8 | net_range r15 | 963 | +0% | 1097 s |
| 19.8 | dog_fetch r4 | 124 | +0% | never | filler
