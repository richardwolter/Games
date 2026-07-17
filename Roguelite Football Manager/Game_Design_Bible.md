# Roguelite Football Manager — Game Design Bible

**Working title:** Football Roguelite Manager (placeholder). Source: GDD at `Desktop/Game Idea/Roguelite Football Manager/GDD - Roguelite Football Manager.txt`.

**High concept:** A satirical football management roguelite. Build a club from the 4th division, survive absurd events, develop players through RPG progression, and reach the top league before getting fired or relegated. Every season is a run.

**Genre:** Sports Management / Roguelite / Strategy-Simulation / Comedy-Satire.

**Core fantasy:** Turn a group of random nobodies into legendary champions while surviving the chaos of football management.

## Core Loop

1. Create club
2. Generate random squad
3. Prepare match (formation, tactics, lineup)
4. Watch simulated match, make live decisions (subs, commands, formation, coach abilities)
5. Receive rewards (Ability Points, traits, events)
6. Upgrade team
7. Handle events / transfers
8. Next match → end of season → promotion/continue, or relegation/fired → new run

## Club Creation

Player chooses:
- Club name
- Primary color
- Secondary color (optional)
- Club badge (procedural/simple)

Club always starts in the 4th Division.

## Match System

Matches are fully simulated — the player is the manager, not a player-controlled athlete.

**Pre-match:** select lineup, choose formation, set tactical style, assign captain, choose substitutes.

**Live:** watch simulation, pause anytime, make substitutions, change formation, issue tactical commands, activate coach abilities.

**Outcome depends on:** player quality, morale, physical condition, interest/motivation, team synergies, active traits, random events.

## Player Progression

Each match rewards Ability Points (AP), spent on five permanent stats:

| Stat | Effect |
|---|---|
| Speed | Movement speed |
| Strength | Ball possession and physical duels |
| Kick | Shooting and crossing quality |
| Pass | Passing accuracy |
| Stamina | Fatigue resistance |

## Squad & Positions

Squad size: 23 players. Detailed positions: GK, CB, FB, DM, CM, CAM, WING, ST. Most players have one natural position; a minority are versatile and have a second natural position (adjacent on the pitch, e.g. CB↔FB, WING↔ST). Fielding a player outside their natural position(s) applies a stat penalty. Exact composition and rates in [BALANCE.md](BALANCE.md).

## Coach Progression

Managers level up and unlock abilities (cooldowns or limited uses per match):

| Ability | Effect |
|---|---|
| Motivator | Temporarily increases team morale |
| Sergeant | Restores one player's interest |
| Tactical Genius | Temporary tactical bonus |
| Risk Taker | Offensive boost with defensive penalty |
| Ice Cold | Reduce panic after conceding goals |

## Player Traits & Superpowers

Traits appear after stat thresholds, memorable performances, injuries, funny events, training accidents, or media scandals.

- **Positive:** Rocket Legs (+Speed), Sniper (+Kick), Wall (+Strength), Iron Lungs (+Stamina), One Touch Master (+Pass)
- **Weird:** Lucky Socks, Alien Vision, Magnet Boots, Time Slows Down, Ball Whisperer
- **Negative:** Diva, Glass Knees, Drama Queen, Gambling Addiction, Allergic to Rain

## Random Events

Generated between matches, e.g.: viral social media challenge, UFO sighting, stadium haunted, star player falls in love, team bus breaks down, club accountant disappears, match fixed rumor, mascot causes chaos, referee becomes influencer, training invaded by goats.

Can modify: morale, interest, fatigue, money, player traits, injuries, team synergy.

## Team Synergies

Success depends on combinations rather than raw stats:

| Combination | Bonus |
|---|---|
| Target Man + Crossing Wingers | Crossing effectiveness |
| Fast Wingers + Counter Attack | Speed bonus |
| Playmaker + Clinical Striker | Shooting bonus |
| High Press + High Stamina | Pressure bonus |
| Defensive Line + Strong Center Backs | Defensive stability |

## Transfer Window

Between groups of matches: trade players, scout replacements, negotiate swaps, recruit random prospects. Intentionally lightweight — strategic roster changes, not detailed financial simulation.

## Roguelite Structure

One season = one run. Each run: ~10–15 league fixtures, transfer period(s), random events, training opportunities, boss matches (promotion rivals).

**Run failure:** club relegated, or manager fired → run ends immediately. New run: new randomly generated players, personalities, traits, events. Permanent unlocks remain.

## Meta Progression

Between runs, permanent unlocks: coach abilities, new tactical formations, starting bonuses, new random events, additional player traits, stronger scouting options, cosmetic club customization.

## Art Direction

Stylized cartoon, exaggerated player animations, broadcast-inspired presentation, strong visual comedy, colorful UI with sports TV influences.

## Design Pillars

- **Fast Management** — capture the fun of football management without overwhelming complexity
- **Every Season Tells a Story** — emergent narratives from events, development, and outcomes
- **Synergy Over Star Power** — smart combinations beat collecting the highest-rated players
- **Failure Is Progress** — each lost season unlocks new strategic options
- **Satirical Football Chaos** — bizarre events, quirky personalities, over-the-top abilities

## Known TBDs

- Match simulation formulas — a real-time, position-driven engine now exists (`MatchDecisionEngine`, PRODUCTION.md Milestone 17: real player positions and per-player stat contests decide passing/tackling/shooting/goals, replacing the earlier abstract per-minute duel engine), not yet Designer-verified for feel/balance; morale/synergy/events still don't factor in at all (those systems don't exist yet)
- Exact AP costs/curves and coach ability cooldown/use values
- Formation/tactics list and their mechanical effects
- Full event catalogue and probability/weighting
- Trait trigger thresholds and stacking rules
- League/promotion structure beyond "4th division start"
- UI/UX flow for match-day live decisions beyond substitutions (formation changes, tactical commands, coach abilities) — subs/formation changes are still panel-based (see PRODUCTION.md Milestone 5); an animated pitch view is now wired into Live Match (Milestone 12), showing goal/formation events visually alongside the existing text ticker
- Demo scope (which slice of this loop ships first)
