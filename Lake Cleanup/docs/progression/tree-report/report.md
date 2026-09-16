# Progression sim: Lake Cleanup

## Checks

| | check | result |
|---|---|---|
| WARN | focused clears in 60-80 min | 59.5 min (cleared 99.5%) |
| WARN | casual clears in 115-160 min | 101.4 min (cleared 99.5%) |
| PASS | focused can always finish (no soft-lock) | finishes |
| PASS | casual can always finish (no soft-lock) | finishes |
| PASS | cheapest can always finish (no soft-lock) | finishes |
| PASS | early buys every 10-60 s (first 10 min) | median gap 30 s |
| PASS | no gap between buys over 300 s | longest 270 s at 28.4-32.9 min |
| WARN | last purchase leaves 10-25% of the game to enjoy it | last buy at 57.4 min, 3% of the game after it |
| FAIL | every buy raises income at least 8% | hull_1 +4.7%, bag_1 +0.0%, pull_1 +5.1%, recycle_1 +7.5%, mouth_2 +2.5%, lucky_1 +3.3% |
| PASS | no single pick wins by 3x in over 50% of choices | median best/second 2.25x; over 3x in 14%; "fleet" top pick 35% |
| WARN | payback within 4x of its phase median | ferry_1 too strong for price (3 s vs 197 s); hull_1 too weak for price (862 s vs 197 s); line_4 too strong for price (122 s vs 781 s) |
| PASS | ferry capacity within 0.8-1.5x of catch rate | inside 80%, lagging 5%, overrunning 15%; box peaked at 157 |
| WARN | single upgrades are felt (no stage locked against another) | 1 buys only paid off with another: bag_3+hull_4 @19.8 |
| WARN | no bought node whose only value is what it unlocks | bag_1 (bought for pull_1) |
| PASS | new systems arrive 0-25 min apart | ferry_1 @0.0, dog @0.2, pull_1 @4.4, ferry_2 @7.3, recycle_1 @7.8, pull_2 @12.0, pigeons_1 @13.8, pull_3 @24.9, ferry_3 @36.1, pull_4 @44.2 |
| FAIL | every node earns its purchase, none only in the last 15% | 7 bought only as filler (earned nothing); 0 never bought; 4 first bought late (trawl, fast_reel, sails_4, hull_5) |

## Bot: focused

- Clear: 59.5 min
- Purchases: 48, spent 459.6k sludge
- Income/s at 2 / 10 / 30 min: 19.8 / 73.5 / 69.9
- Median payback by phase: 0m 197s, 10m 536s, 20m 834s, 30m 781s, 40m 895s
- Median seconds from reveal to buy, by group: fleet 390, dog 10, hull 425, line 220, sails 433, bag 470, mouth 435, pull 198, fetch 183, recycle 655, luck 670, nose 40, pigeons 105, double 520, beach 60, leash 135

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.0 | ferry_1 | 50 | +12315% | 3 s |
| 0.2 | dog | 100 | from zero | never |
| 0.8 | hull_1 | 650 | +5% | 862 s |
| 1.3 | line_1 | 550 | +30% | 123 s |
| 1.9 | sails_1 | 750 | +16% | 234 s |
| 2.9 | hull_2 | 1300 | +21% | 266 s |
| 3.3 | bag_1 (for pull_1) | 600 | +0% | never |
| 3.8 | mouth_1 | 850 | +18% | 197 s |
| 4.4 | pull_1 | 1000 | +5% | 703 s |
| 5.0 | fetch_1 | 1100 | from zero | never |
| 7.3 | ferry_2 | 4000 | +99% | 138 s |
| 7.8 | recycle_1 | 1500 | +7% | 346 s |
| 8.1 | line_2 | 1200 | +14% | 158 s |
| 8.5 | sails_2 | 1600 | +18% | 146 s |
| 10.0 | hull_3 | 6500 | +25% | 355 s |
| 10.5 | mouth_2 | 2000 | +3% | 888 s |
| 11.5 | lucky_1 | 3000 | +3% | 1030 s |
| 12.0 | pull_2 | 4500 | +5% | 1005 s |
| 12.7 | nose | 5000 | from zero | never |
| 13.8 | pigeons_1 | 6000 | from zero | never |
| 14.8 | line_3 | 6000 | +24% | 341 s |
| 15.1 | bag_2 | 1400 | +4% | 395 s |
| 16.3 | sails_3 | 7000 | +15% | 494 s |
| 17.5 | fetch_2 | 7500 | from zero | never |
| 18.7 | recycle_2 | 7000 | +11% | 578 s |
| 19.8 | bag_3 (with hull_4) | 6000 | +21% | 243 s |
| 21.0 | hull_4 | 11.0k | +21% | 436 s |
| 23.1 | mouth_3 | 10.0k | +7% | 1099 s |
| 24.1 | double_1 | 9500 | +7% | 1027 s |
| 24.9 | pull_3 | 14.0k | +17% | 640 s |
| 25.9 | beachcomber | 9000 | from zero | never |
| 27.2 | leash | 11.0k | from zero | never |
| 28.4 | pigeons_2 | 11.0k | from zero | never |
| 32.9 | line_4 | 15.0k | +996% | 122 s |
| 34.8 | bag_4 | 15.0k | +10% | 1102 s |
| 36.1 | ferry_3 | 12.0k | +12% | 658 s |
| 38.2 | recycle_3 | 20.0k | +14% | 904 s |
| 40.2 | lucky_2 | 16.0k | +5% | 1739 s | filler
| 42.2 | mouth_4 | 19.0k | +1% | 7669 s | filler
| 44.2 | pull_4 | 20.0k | +6% | 1956 s | filler
| 44.2 | pigeons_3 | 11.0k | from zero | never |
| 45.2 | pigeons_4 | 13.0k | from zero | never |
| 47.8 | bag_5 | 32.0k | +22% | 751 s |
| 49.4 | double_2 | 23.0k | +9% | 1038 s |
| 51.4 | trawl | 25.0k | +1% | 7431 s | filler
| 53.4 | fast_reel | 25.0k | +0% | 23341 s | filler
| 55.4 | sails_4 | 25.0k | +0% | never | filler
| 57.4 | hull_5 | 36.0k | +0% | never | filler

## Bot: casual

- Clear: 101.4 min (seeds: 101, 101, 115)
- Purchases: 48, spent 459.6k sludge
- Income/s at 2 / 10 / 30 min: 17.4 / 2.9 / 5.2
- Median payback by phase: 0m 234s, 10m 5227s, 20m 360s, 30m 685s, 40m 439s, 50m 3785s, 60m 1044s, 70m 5242s, 80m 1000s, 90m 1938s
- Median seconds from reveal to buy, by group: fleet 840, dog 20, line 360, hull 740, sails 720, bag 860, pull 320, fetch 230, recycle 1100, mouth 680, luck 1160, nose 80, pigeons 230, double 1060, beach 340, leash 440

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.0 | ferry_1 | 50 | +12765% | 3 s |
| 0.3 | dog | 100 | from zero | never |
| 1.0 | line_1 | 550 | +13% | 297 s |
| 1.7 | hull_1 | 650 | +20% | 200 s |
| 2.3 | sails_1 | 750 | +16% | 234 s |
| 2.7 | bag_1 * | 600 | +0% | never |
| 3.7 | hull_2 | 1300 | +12% | 466 s |
| 4.3 | pull_1 | 1000 | +42% | 116 s |
| 5.0 | fetch_1 | 1100 | from zero | never |
| 6.0 | bag_2 * | 1400 | +0% | never |
| 6.7 | recycle_1 | 1500 | +7% | 693 s |
| 10.3 | line_2 (with ferry_2) | 1200 | +100% | 39 s |
| 11.0 | sails_2 * | 1600 | +18% | 291 s |
| 11.7 | mouth_1 * | 850 | +0% | 5227 s |
| 13.0 | mouth_2 * | 2000 | +1% | 6375 s |
| 14.0 | lucky_1 * | 3000 | +0% | never |
| 15.7 | ferry_2 | 4000 | +98% | 110 s |
| 16.7 | pull_2 * | 4500 | +0% | never |
| 18.0 | nose | 5000 | from zero | never |
| 19.3 | pigeons_1 | 6000 | from zero | never |
| 21.3 | hull_3 | 6500 | +25% | 360 s |
| 22.3 | line_3 | 6000 | +42% | 222 s |
| 23.7 | fetch_2 | 7500 | from zero | never |
| 25.0 | recycle_2 | 7000 | +11% | 669 s |
| 26.3 | sails_3 * | 7000 | +0% | never |
| 31.0 | bag_3 | 6000 | +17% | 354 s |
| 32.3 | double_1 * | 9500 | +0% | never |
| 33.7 | hull_4 | 11.0k | +21% | 436 s |
| 35.3 | pull_3 * | 14.0k | +11% | 935 s |
| 41.0 | beachcomber | 9000 | from zero | never |
| 41.3 | mouth_3 * | 10.0k | +14% | 575 s |
| 42.7 | leash | 11.0k | from zero | never |
| 44.7 | line_4 | 15.0k | +70% | 302 s |
| 49.7 | pigeons_2 * | 11.0k | +2% | 5931 s |
| 52.0 | ferry_3 * | 12.0k | +0% | never |
| 53.7 | bag_4 | 15.0k | +18% | 716 s |
| 58.0 | mouth_4 * | 19.0k | +2% | 6855 s |
| 62.3 | recycle_3 | 20.0k | +14% | 1044 s |
| 64.3 | lucky_2 | 16.0k | +5% | 1928 s | filler
| 66.3 | pull_4 | 20.0k | +5% | 2239 s | filler
| 71.3 | pigeons_3 | 11.0k | from zero | never |
| 72.3 | pigeons_4 | 13.0k | from zero | never |
| 75.0 | trawl * | 25.0k | +3% | 5242 s |
| 81.3 | sails_4 * | 25.0k | +0% | never |
| 84.0 | bag_5 | 32.0k | +22% | 837 s |
| 86.0 | double_2 | 23.0k | +9% | 1163 s |
| 91.7 | fast_reel * | 25.0k | +6% | 1938 s |
| 94.7 | hull_5 | 36.0k | +0% | never | filler

## Bot: cheapest

- Clear: 83.0 min
- Purchases: 48, spent 459.6k sludge
- Income/s at 2 / 10 / 30 min: 16.3 / 36.9 / 152.1
- Median payback by phase: 0m 971s, 10m 71895s, 20m 442s, 30m 251s, 50m 645s, 60m 1653s, 70m 1899s
- Median seconds from reveal to buy, by group: fleet 665, dog 10, line 150, bag 235, hull 465, sails 618, mouth 590, pull 428, fetch 328, recycle 835, luck 1075, nose 70, pigeons 143, double 465, beach 45, leash 95

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.0 | ferry_1 | 50 | +12315% | 3 s |
| 0.2 | dog | 100 | +0% | never |
| 0.8 | line_1 | 550 | +1% | 5331 s |
| 1.3 | bag_1 | 600 | +0% | never |
| 2.0 | hull_1 | 650 | +20% | 200 s |
| 2.7 | sails_1 | 750 | +16% | 234 s |
| 3.3 | mouth_1 | 850 | +0% | 7759 s |
| 4.0 | pull_1 | 1000 | +4% | 1244 s |
| 4.8 | fetch_1 | 1100 | +0% | never |
| 5.6 | line_2 | 1200 | +1% | 7078 s |
| 6.5 | hull_2 | 1300 | +21% | 254 s |
| 7.3 | bag_2 | 1400 | +0% | never |
| 8.2 | recycle_1 | 1500 | +7% | 697 s |
| 9.0 | sails_2 | 1600 | +17% | 291 s |
| 9.9 | mouth_2 | 2000 | +1% | 5783 s |
| 11.3 | lucky_1 | 3000 | +0% | never |
| 13.1 | ferry_2 | 4000 | +97% | 110 s |
| 14.1 | pull_2 | 4500 | +0% | never |
| 15.3 | nose | 5000 | +0% | never |
| 16.6 | line_3 | 6000 | +1% | 10475 s |
| 18.0 | bag_3 | 6000 | +0% | never |
| 19.3 | pigeons_1 | 6000 | +1% | 8050 s |
| 20.8 | hull_3 | 6500 | +24% | 358 s |
| 22.1 | recycle_2 | 7000 | +11% | 669 s |
| 23.3 | sails_3 | 7000 | +15% | 442 s |
| 24.3 | fetch_2 | 7500 | +0% | never |
| 25.6 | double_1 | 9500 | +0% | never |
| 27.0 | mouth_3 | 10.0k | +1% | 8748 s |
| 28.6 | hull_4 | 11.0k | +21% | 436 s |
| 29.9 | ferry_3 | 12.0k | +49% | 170 s |
| 31.0 | pull_3 | 14.0k | +34% | 251 s |
| 31.8 | beachcomber | 9000 | +1% | 4145 s |
| 32.6 | leash | 11.0k | +0% | never |
| 34.7 | pigeons_2 | 11.0k | +4% | 7332 s |
| 55.8 | line_4 | 15.0k | +2374% | 120 s |
| 57.8 | bag_4 | 15.0k | +18% | 645 s |
| 59.6 | lucky_2 | 16.0k | +5% | 1986 s |
| 61.5 | mouth_4 | 19.0k | +2% | 6366 s |
| 63.6 | recycle_3 | 20.0k | +14% | 891 s |
| 65.3 | pull_4 | 20.0k | +5% | 2038 s |
| 66.3 | pigeons_3 | 11.0k | +1% | 4919 s |
| 67.4 | pigeons_4 | 13.0k | +1% | 5344 s |
| 69.3 | double_2 | 23.0k | +9% | 1269 s |
| 71.3 | sails_4 | 25.0k | +0% | never |
| 73.3 | fast_reel | 25.0k | +6% | 1899 s |
| 75.2 | trawl | 25.0k | +1% | 7624 s |
| 77.5 | bag_5 | 32.0k | +22% | 666 s |
| 79.9 | hull_5 | 36.0k | +0% | never |
