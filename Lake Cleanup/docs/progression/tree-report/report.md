# Progression sim: Lake Cleanup

## Checks

| | check | result |
|---|---|---|
| PASS | focused clears in 50-70 min | 54.3 min (cleared 99.5%) |
| PASS | casual clears in 100-140 min | 100.2 min (cleared 99.5%) |
| PASS | focused can always finish (no soft-lock) | finishes |
| PASS | casual can always finish (no soft-lock) | finishes |
| PASS | cheapest can always finish (no soft-lock) | finishes |
| PASS | early buys every 10-60 s (first 10 min) | median gap 30 s |
| PASS | no gap between buys over 300 s | longest 200 s at 32.8-36.1 min |
| WARN | last purchase leaves 10-25% of the game to enjoy it | last buy at 36.1 min, 33% of the game after it |
| WARN | every buy raises income at least 8% | line_2 +7.5% |
| PASS | no single pick wins by 3x in over 50% of choices | median best/second 1.54x; over 3x in 28%; "pull" top pick 32% |
| WARN | payback within 4x of its phase median | ferry_1 too strong for price (3 s vs 229 s); line_1 too strong for price (49 s vs 229 s); mouth_1 too weak for price (1157 s vs 278 s) |
| WARN | ferry capacity within 0.8-1.5x of catch rate | inside 66%, lagging 1%, overrunning 33%; box peaked at 215 |
| FAIL | single upgrades are felt (no stage locked against another) | 3 buys only paid off with another: hull_3+bag_4 @12.3, sails_2+line_4 @14.0, ferry_3+bag_5 @19.3 |
| PASS | no bought node whose only value is what it unlocks | none |
| WARN | new systems arrive 2-15 min apart | ferry_1 @0.0, pull_1 @2.4, dog @3.6, ferry_2 @5.8, pull_2 @8.6, ferry_3 @19.3, pull_3 @24.8, pull_4 @27.3 |
| WARN | every node earns its purchase, none only in the last 15% | 2 bought only as filler (earned nothing); 0 never bought; 0 first bought late |

## Bot: focused

- Clear: 54.3 min
- Purchases: 31, spent 254.8k sludge
- Income/s at 2 / 10 / 30 min: 23.4 / 84.3 / 164.1
- Median payback by phase: 0m 229s, 10m 278s, 20m 636s, 30m 543s
- Median seconds from reveal to buy, by group: fleet 250, line 310, bag 155, hull 95, sails 420, pull 260, dog 15, fetch 185, nose 75, mouth 365, beach 340, leash 1085

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.0 | ferry_1 | 50 | from zero | 3 s |
| 0.2 | line_1 | 150 | +20% | 49 s |
| 0.8 | bag_1 | 600 | +11% | 309 s |
| 1.3 | line_2 | 700 | +7% | 485 s |
| 1.6 | hull_1 | 300 | +22% | 65 s |
| 1.9 | sails_1 | 500 | +26% | 75 s |
| 2.4 | pull_1 | 1000 | +9% | 363 s |
| 2.8 | hull_2 | 800 | +18% | 133 s |
| 3.3 | bag_2 | 1300 | +14% | 244 s |
| 3.6 | dog | 700 | from zero | never |
| 4.0 | fetch_1 | 1000 | from zero | never |
| 4.8 | nose | 2000 | from zero | never |
| 5.8 | ferry_2 | 2400 | +25% | 229 s |
| 6.5 | line_3 | 3000 | +28% | 266 s |
| 7.5 | bag_3 | 3000 | +36% | 162 s |
| 8.6 | pull_2 | 4500 | +26% | 261 s |
| 9.8 | fetch_2 | 6000 | from zero | never |
| 11.8 | mouth_1 | 9000 | +10% | 1157 s |
| 12.3 | hull_3 (with bag_4) | 4000 | +29% | 166 s |
| 13.6 | bag_4 | 6000 | +27% | 261 s |
| 14.0 | sails_2 (with line_4) | 2800 | +22% | 119 s |
| 15.4 | beachcomber | 9000 | from zero | never |
| 17.9 | line_4 | 14.0k | +64% | 278 s |
| 19.3 | ferry_3 (with bag_5) | 11.0k | +32% | 267 s |
| 21.6 | bag_5 | 17.0k | +21% | 636 s |
| 22.9 | leash | 13.0k | from zero | never |
| 24.8 | pull_3 | 16.0k | +22% | 554 s |
| 27.3 | pull_4 | 24.0k | +24% | 709 s |
| 30.0 | mouth_2 | 27.0k | +32% | 543 s |
| 32.8 | bank_reach | 34.0k | +5% | 3240 s | filler
| 36.1 | trawl | 40.0k | +18% | 1275 s | filler

## Bot: casual

- Clear: 100.2 min (seeds: 95, 100, 104)
- Purchases: 31, spent 254.8k sludge
- Income/s at 2 / 10 / 30 min: 17.9 / 3.4 / 4.4
- Median payback by phase: 0m 128s, 10m 266s, 20m 584s, 30m 410s, 40m 785s, 50m 632s, 60m 769s
- Median seconds from reveal to buy, by group: fleet 560, hull 180, line 560, bag 160, sails 410, pull 420, dog 20, fetch 340, nose 80, mouth 680, beach 960, leash 1760

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.0 | ferry_1 | 50 | from zero | 4 s |
| 0.3 | hull_1 * | 300 | +0% | never |
| 0.7 | line_1 | 150 | +26% | 45 s |
| 1.3 | bag_1 | 600 | +8% | 473 s |
| 2.0 | line_2 | 700 | +51% | 81 s |
| 2.3 | sails_1 | 500 | +6% | 306 s |
| 3.0 | pull_1 | 1000 | +28% | 139 s |
| 3.3 | hull_2 (with bag_2) | 800 | +31% | 79 s |
| 4.0 | bag_2 | 1300 | +31% | 128 s |
| 4.3 | dog | 700 | from zero | never |
| 4.7 | fetch_1 | 1000 | from zero | never |
| 5.7 | nose | 2000 | from zero | never |
| 9.7 | ferry_2 * | 2400 | +0% | never |
| 11.3 | line_3 | 3000 | +26% | 312 s |
| 12.3 | bag_3 | 3000 | +37% | 173 s |
| 13.7 | sails_2 * | 2800 | +0% | never |
| 14.3 | pull_2 | 4500 | +29% | 266 s |
| 15.7 | fetch_2 | 6000 | from zero | never |
| 20.7 | hull_3 * | 4000 | +0% | never |
| 22.7 | mouth_1 | 9000 | +16% | 848 s |
| 24.0 | bag_4 | 6000 | +25% | 320 s |
| 30.3 | line_4 | 14.0k | +42% | 410 s |
| 31.7 | beachcomber | 9000 | from zero | never |
| 33.3 | ferry_3 * | 11.0k | +0% | never |
| 35.0 | leash * | 13.0k | +0% | never |
| 41.3 | bag_5 | 17.0k | +14% | 1006 s |
| 43.3 | pull_3 | 16.0k | +21% | 614 s |
| 46.0 | pull_4 | 24.0k | +23% | 785 s |
| 53.0 | mouth_2 | 27.0k | +31% | 632 s |
| 60.3 | bank_reach | 34.0k | +15% | 1337 s | filler
| 64.0 | trawl | 40.0k | +36% | 769 s |

## Bot: cheapest

- Clear: 59.6 min
- Purchases: 31, spent 254.8k sludge
- Income/s at 2 / 10 / 30 min: 19.1 / 59.4 / 130.2
- Median payback by phase: 0m 102s, 10m 229s, 20m 10789s, 30m 633s, 40m 1119s
- Median seconds from reveal to buy, by group: fleet 335, line 435, hull 120, sails 205, bag 130, pull 395, dog 20, fetch 298, nose 70, mouth 400, beach 210, leash 1015

| min | buy | cost | income gain | payback | |
|---|---|---|---|---|---|
| 0.0 | ferry_1 | 50 | from zero | 3 s |
| 0.2 | line_1 | 150 | +20% | 49 s |
| 0.5 | hull_1 | 300 | +0% | never |
| 0.9 | sails_1 | 500 | +0% | never |
| 1.5 | bag_1 | 600 | +4% | 794 s |
| 2.1 | line_2 | 700 | +64% | 61 s |
| 2.5 | hull_2 | 800 | +0% | never |
| 3.1 | pull_1 | 1000 | +32% | 115 s |
| 3.7 | bag_2 | 1300 | +18% | 198 s |
| 4.0 | dog | 700 | +0% | never |
| 4.3 | fetch_1 | 1000 | +0% | never |
| 5.2 | nose | 2000 | +0% | never |
| 6.1 | ferry_2 | 2400 | +22% | 251 s |
| 6.8 | sails_2 | 2800 | +0% | never |
| 8.0 | bag_3 | 3000 | +0% | never |
| 9.3 | line_3 | 3000 | +98% | 88 s |
| 10.3 | hull_3 | 4000 | +0% | never |
| 11.5 | pull_2 | 4500 | +34% | 213 s |
| 12.7 | bag_4 | 6000 | +0% | never |
| 13.9 | fetch_2 | 6000 | +0% | 21887 s |
| 16.0 | mouth_1 | 9000 | +54% | 244 s |
| 17.4 | beachcomber | 9000 | +2% | 4974 s |
| 19.3 | ferry_3 | 11.0k | +0% | never |
| 22.1 | leash | 13.0k | +0% | never |
| 25.8 | line_4 | 14.0k | +151% | 180 s |
| 27.9 | pull_3 | 16.0k | +1% | 21398 s |
| 30.1 | bag_5 | 17.0k | +25% | 524 s |
| 32.7 | pull_4 | 24.0k | +24% | 709 s |
| 35.3 | mouth_2 | 27.0k | +31% | 557 s |
| 38.1 | bank_reach | 34.0k | +5% | 3406 s |
| 41.3 | trawl | 40.0k | +21% | 1119 s |
