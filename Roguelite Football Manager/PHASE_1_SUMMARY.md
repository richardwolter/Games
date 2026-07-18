# Milestone 18, Phase 1: Foundational State & Momentum

## Completion Summary

Phase 1 establishes the foundational systems that later phases (Pressure, Chance Generation, Events) will build upon.

## Files Created

### New Resource Class
- `resources/team_match_state.gd` (`TeamMatchState`)
  - Per-team hidden state: momentum, possession %, territory %, confidence, organization, physical energy, aggression
  - Tactical identity placeholder
  - Pass chain tracking, recent event history
  - Helper methods: `get_momentum_normalized()`, `get_pressure()`, `add_event()`, `add_possession_time()`, `update_possession_pct()`

### New System Classes
- `scripts/momentum_system.gd` (`MomentumSystem`)
  - Event-driven momentum changes (goals: ±35/30, saves: +8, tackles/interceptions: +4/+5, pass chains: +1.5 each, turnovers: −8, cards: −5/−20)
  - Natural decay (−2.5 per periodic update, prevents permanent dominance)
  - Team characteristic updates: confidence (drifts toward momentum), organization (factored from momentum), physical energy (drains with time/aggression)
  - Pass chain bonus system (called on pass completion, resets on turnover)

## Files Modified

### `resources/live_match_state.gd`
- Added `home_state`, `away_state` (TeamMatchState instances)
- Added `momentum_system` (MomentumSystem instance)
- Initialized in `_init()`
- New method `update_team_states(delta_seconds)`: called every 3 real-time seconds, updates possession time tracking, recalculates possession %, applies momentum decay and team characteristic updates
- Modified `record_shot_result()`: applies momentum bonuses/penalties on goals/saves, resets opponent's pass chain
- Possession tracking via `BallState.possession_player`

### `scenes/live_match/live_match.gd`
- Added `TEAM_STATE_UPDATE_INTERVAL` = 3.0s, `_team_state_accumulator`
- Modified `_process()`: periodic call to `_match.update_team_states(scaled_delta)` every 3 real-time seconds (scaled by speed multiplier)

### `BALANCE.md`
- Added "Momentum System" section documenting:
  - Team Match State properties and their ranges
  - Momentum event bonuses/penalties table
  - Natural decay and confidence drift formulas
  - Possession tracking mechanics
  - Pressure calculation (preliminary)

### `PRODUCTION.md`
- Updated "Current Milestone" to reflect M18 in progress
- Added full Milestone 18 Phase 1 entry with context, implementation details, and caveats

## What Phase 1 Enables

✅ **Momentum fluctuates naturally** based on goals, saves, and ball recovery events
✅ **Possession tracking** accumulates time for each team, converted to possession %
✅ **Team state evolution** — confidence/organization/physical energy drift based on momentum
✅ **Foundation for pressure** — `TeamMatchState.get_pressure()` combines momentum + possession + territory (territory tracking TBD)

## What's Still TBD / Not Yet Implemented

- 🚫 Territorial control tracking (will be added in Phase 2)
- 🚫 Tactical style modifiers (defined in TacticalSystem, Phase 2)
- 🚫 Pressure driving chance generation (Phase 2–3)
- 🚫 Pass chain bonuses wired to actual pass events (M17 engine doesn't yet emit pass-complete events; Phase 2 will add this)
- 🚫 UI indicators (momentum bar, pressure gauge, team shape) — Phase 5
- 🚫 Event system (injuries, cards, fouls) — Phase 4
- 🚫 Commentary system — Phase 5
- 🚫 Drama variables (crowd energy, weather, referee strictness, etc) — Phase 5

## Verification Needed

1. **In-engine test:** Run a full 90-minute match and verify momentum fluctuates after goals/saves
2. **Possession % accuracy:** Confirm possession % approaches 100 for the team with the ball
3. **Confidence/organization drift:** Check that these values follow momentum over time
4. **Physical energy decay:** Verify energy drains over 90 minutes and faster in second half
5. **Speed control:** Confirm periodic updates scale correctly at 1x/2x/4x speed

## Next Phase: Phase 2 — Tactical & Pressure

### Goals
- Implement `TacticalSystem` (5 tactical styles and their modifiers)
- Implement `PressureSystem` (uses momentum + possession + territory to calculate team pressure)
- Begin replacing M17's direct shot decisions with pressure-driven chance generation

### Files to Create/Modify
- New: `scripts/tactical_system.gd` (TacticalSystem)
- New: `scripts/pressure_system.gd` (PressureSystem)
- Modify: `scripts/match_decision_engine.gd` (replace direct shot logic; shots only on chance resolution)
- Modify: `resources/team_match_state.gd` (wire in tactical modifiers on team states)

### Key Design Decisions Needed
1. **Tactical modifier table:** For each of the 5 styles, what % modifiers apply to possession %, pass completion %, pressure buildup rate, interception %, tackle %, etc.?
2. **Territory tracking:** How is territory_pct calculated from player positions? (Currently undefined)
3. **Pressure thresholds:** At what pressure % values do small/good/big/clear-cut chances spawn?
4. **Pass completion events:** How do completed passes get reported so momentum bonuses can be awarded?
