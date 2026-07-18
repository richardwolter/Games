# Semi-Secret Wars — Game Design Bible

**Scope:** Demo loop only — one full cycle (roster → priorities → auto-battle → farm XP → level up → repeat) vs. Dark Mage. Skill trees and additional villains are post-demo.

## Core Loop

1. Select hero roster (Thundaar + Artemis)
2. Assign each hero a battlefield priority
3. Start battle — villain summons continuous escalating swarm
4. Heroes fight automatically
5. Receive XP rewards (minion kills + objective bonus)
6. Upgrade hero stats (player-directed, not automatic)
7. Repeat

**Philosophy:** Stages are farm cycles. Base heroes intentionally lose first run; the swarm is the XP source. Each run they grow stronger until they out-level the stage and can defeat the villain (win condition = advance). New stages are harder; loop repeats indefinitely.

## Characters

**Heroes:** Thundaar, Artemis (max 4 per party)
- Each has: Experience, Levels, Individual stats
- Upgrades: Player allocates XP between runs (no skill tree in demo)

**Villain:** Dark Mage (stationary, summons minions)
- Has HP bar; defeat = win

**Minions:** Swarm spawned by villain
- Hunt nearest hero field-wide, steer to intercept point on hero's route
- Delay hero progression, protect villain

## Battlefield (Stage 1)

Organic open field, hand-drawn:
- Hero spawn (funnel, top-left)
- Villain corner (bottom-right)
- Obstacles (units steer around)
- Capturable objective (bottom-left) — hold-to-capture, grants XP bonus
- Poison Lake (drawn, hazard effect TBD)
- Scenery (decorative)

## Hero Priorities (Implemented)

- **Attack Minions:** engage nearby enemies, advance when clear
- **Capture Objectives:** hold objective until captured, advance toward villain
- **Attack Villain:** push toward villain, fight only blocking enemies

## Combat

Fully automated. Open-field movement with obstacle avoidance. Minions attempt to intercept; heroes attempt objectives/villain.

## Progression

Demo only: XP from farming → player-directed stat upgrades between runs. Skill trees deferred post-demo.

## Rewards

Experience (kills + objective capture). See [BALANCE.md](BALANCE.md) for economy values.

## Art Direction

Notebook aesthetic: minimalist, hand-drawn, child's comic style, simple colors, thick outlines. South Park/paper-puppet inspiration. Animations: simple bobbing, rotation, scaling.

See [ART_BIBLE.md](ART_BIBLE.md) for full reference.

## Known TBDs

- Combat formulas & damage calculations
- Hero base stats
- Poison Lake effect
- Full skill tree design (post-demo)
- Additional villain types & minion variety
- Battle HUD design details
