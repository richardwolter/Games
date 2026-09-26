---
name: crow-empire-build
overview: >-
  Cozy lo-fi idle/management game: train a growing flock of crows to steal from
  the city across a daily feed-dispatch-collect-level loop.
createdAt: '2026-09-09T13:57:35.813Z'
todos:
  - id: base-day-loop
    content: >-
      Build the minimum playable base in main.tscn: 3 crows, Dispatch button,
      timed flight out/return with loot, XP and 5-tier leveling, day counter.
    status: completed
  - id: food-inventory
    content: >-
      Add food inventory (berries, worms, seeds) with stock counts; better food
      boosts dispatch speed or loot odds.
    status: completed
  - id: upgrades-shop
    content: >-
      Add money upgrades (training, bags, speed) and crow recruitment up to a
      roster cap.
    status: completed
  - id: art-pass
    content: >-
      Lo-fi cozy art pass: crow sprites/animation, dreamlike city backdrop, warm
      UI theme and icons.
    status: cancelled
  - id: polish-audio
    content: 'Add SFX, music, idle crow animations, and a balance pass on the day loop.'
    status: pending
  - id: day-night-cycle
    content: >-
      Day/night cycle: dispatch at dawn, backdrop shifts through sunset to night
      with sun setting and moon rising as the run progresses; Next Day button
      opens a daily log listing each crow's XP, objects, and value.
    status: completed
  - id: balcony-view
    content: >-
      Balcony view: rework the scene so the HUD reads as a balcony overlooking
      the city, crew birds loiter on the balcony before dispatch, and
      Pantry/Upgrades/Dispatch/roster UI sit on the balcony - styled after
      refimage1/2/3 - with the day/night cycle driving the view.
    status: pending
---
# Crow Empire - Build Plan

## Spine
Freeform build. No examples-library slice matches an idle/management game (the survivors slice has XP/upgrades but a real-time dodge loop - wrong fit). Design brief is the onboarding vision: cozy lo-fi, crows as characters that grow, day-loop management, warm muted golds and sky blues, soft rounded UI.

## Core loop
Each day: feed crows (from inventory, later milestone) -> Dispatch -> crows fly off to the city -> timed return -> collect money and objects -> XP award -> automatic leveling through 5 tiers (Newbie -> Master) -> plan upgrades -> repeat. Passive progression + active planning, not twitch gameplay.

## Scene architecture (2D, GDScript)
- res://main.tscn as the single scene and main scene: a cozy rooftop/awning backdrop, crow roster cards, money + day counters, Dispatch button, loot feed.
- Crows are lightweight character nodes (ColorRect/circle + name label for now) that tween off-screen and back; each holds name, tier, xp, and stats (speed, luck).
- Game state lives in one manager script (roster, money, day, dispatch timer); crow state lives on each crow script.
- Flat colors and simple shapes are scaffolding; art arrives in the art-pass milestone.

## Milestones
1. base-day-loop (NOW): roster of 3 named crows, Dispatch sends them out, timed return with money + loot, XP and 5-tier leveling, day counter. One scene, one loop, no menus/save/shop/audio.
2. food-inventory: food items with stock, food consumed per dispatch, better food = faster or luckier runs.
3. upgrades-shop: spend money on training/bags/speed upgrades and recruit new crows to a cap.
4. art-pass: asset expert delivers crow sprites + animation, city backdrop, warm UI theme, item icons.
5. polish-audio: SFX, music loop, idle animations, balance pass.

## Verification
Each milestone: files written, main scene set, no script parse errors, signals/UI wired. Runtime feel (dispatch pacing, level-up satisfaction) is verified by the user pressing Play.
