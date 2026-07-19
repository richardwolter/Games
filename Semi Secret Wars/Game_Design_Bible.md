# Semi-Secret Wars — Game Design Bible

**Scope (current direction, 2026-07-18 rework):** a **run** is a chain of fixed, authored levels. The player prepares once, then plays level after level — carrying HP, in-run levels and boons forward — until the party wipes, which ends the run back at Level 1. What persists between runs is **knowledge** (a permanent, fog-revealed map of each level) and **gold** (permanent ability upgrades). See DECISIONS.md (2026-07-18) for the ratified design.

## Core Loop

**Prep (once per run):** draft a party (3-of-4) + priorities; spend gold on permanent ability mods.

**Per level:**
1. Deploy the party on a *fixed* field. First visit it's fogged; on later runs the fog shows what earlier heroes explored — the map is the player's real progress.
2. Heroes fight automatically: escalating swarm from authored gates, hazards, objective markers for XP, leveling up in-run via 1-of-3 boon picks.
3. The player has one command verb — a limited-charge **focus ping** — to bias where the party commits.
4. The villain sits dormant at a learnable **lair** until the party closes in, then fights in its own style.
5. **Win** (villain down) → chain straight into the next level, keeping HP/boons/levels; the dead stay dead. **Wipe** → run ends, gold awarded (scaled by levels cleared), back to prep at Level 1.

**Philosophy:** When the battle starts it's out of the player's hands — heroes act decisively and autonomously, with one meaningful lever. Difficulty compounds within a run (attrition, no revives yet). Every loss is a fresh attempt armed with more map knowledge and a better permanent kit.

## Characters

**Heroes:** Thundaar (Tank), Artemis (Burst), WARDEN (Control), BEACON (Support). Draft 3-of-4 per run.
- Each has flat base stats + an intrinsic ability kit from run start.
- Growth: in-run boons (reset each run) + permanent gold-bought ability mods (owned forever).

**Villains (per level):** Dark Mage (L1, teleport/resummon, leashed to lair), Berserker (L2, charge/recover), Mech Robot (L3, slow zones).
- Each sits **dormant at a fixed lair** until the party closes in (or it's hit), then fights in its own style. HP bar; defeat = advance.

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

Two currencies, two horizons:
- **XP** (in-run only): kills + objective captures feed each hero's in-run level. On level-up, pick 1 of 3 **boons** (Power/Vitality/Haste/…). Boons + levels reset every run but carry *across levels within a run*.
- **Gold** (permanent): awarded at run end, scaled by levels cleared. Spent at prep on **permanent per-hero ability mods** (`AbilityMods`) — bought once, owned forever, each with an upside **and** a real downside.

The deepest progression is **knowledge**: fixed levels + persistent fog mean the player learns each map — gate positions, the lair, hazards, objective spots — and every run leans on what they've learned and unlocked.

## Rewards

XP (kills + objective capture) → in-run boons; gold (run end) → permanent ability mods; map knowledge (persistent fog). See [BALANCE.md](BALANCE.md) for economy values.

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
