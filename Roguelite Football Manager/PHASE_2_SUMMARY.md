# Milestone 18, Phase 2: Tactical & Pressure Systems

## Completion Summary

Phase 2 adds tactical identity and continuous pressure calculation, laying groundwork for chance generation in Phase 3.

## Files Created

### Tactical System
- `scripts/tactical_system.gd` (`TacticalSystem`)
  - 5 tactical styles: High Press, Possession, Counter Attack, Park The Bus, Long Ball
  - Each style has modifier multipliers for organization, aggression, confidence, possession %, pass completion %, interception %, tackle %, shot chance %, and fatigue
  - `apply_modifiers()` method called each periodic update to tweak team characteristics
  - Static helper: `get_style_description()` for UI display

### Pressure System
- `scripts/pressure_system.gd` (`PressureSystem`)
  - Continuous pressure calculation (0–100) from weighted average:
    - Momentum: 30% (drives confidence/urgency)
    - Possession %: 25% (time-weighted ball control)
    - Territory %: 25% (spatial dominance)
    - Tactical base: 20% (style-specific pressure tendency)
  - Territory calculation from player positions:
    - Attacking players in opponent's half: +5 per player
    - Defending players NOT in own half: +4 per player pushed up
    - Range: 0–100
  - Chance type thresholds (approved by Designer):
    - ≥90% pressure: Clear-Cut chance (xG: 0.65–0.95)
    - ≥80%: Big chance (xG: 0.45–0.65)
    - ≥60%: Good chance (xG: 0.20–0.45)
    - ≥40%: Small chance (xG: 0.05–0.20)
    - <40%: No chance

## Files Modified

### `resources/team_match_state.gd`
- Added `pressure_level` property (0–100, updated each periodic update)

### `resources/live_match_state.gd`
- Added `tactical_system`, `pressure_system`, `movement_system_ref` references
- Added `set_movement_system()` method (called from live_match.gd)
- Modified `update_team_states()`: now calls tactical modifiers and pressure calculation each update

### `scenes/live_match/live_match.gd`
- Wired movement system reference: `_match.set_movement_system(_movement_system)` in _ready()

### `BALANCE.md`
- Added "Tactical System" section with full modifier table and design rationale
- Added "Pressure System" section with formula, territory calculation, and chance thresholds

### `PRODUCTION.md`
- Updated Milestone 18 entry to cover both Phase 1 and Phase 2

## What Phase 2 Enables

✅ **Tactical identity matters** — each style changes how pressure builds and how teams play
✅ **Continuous pressure calculation** — replaces discrete zones with smooth 0–100 scale
✅ **Territory tracking** — player positions directly affect pressure (spatial dominance)
✅ **Chance type generation** — pressure thresholds determine chance quality (small/good/big/clear-cut)
✅ **xG values per chance** — each chance type has a realistic expected goal range

## What's Still TBD / Not Yet Implemented

- 🚫 Chance objects (actual chance generation when thresholds crossed) — Phase 3
- 🚫 Chance resolver (resolves chance → goal/save/miss with xG) — Phase 3
- 🚫 Event system (injuries, cards, fouls triggered by pressure/aggression) — Phase 4
- 🚫 UI indicators (momentum bar, pressure gauge, team shape, tactical indicators) — Phase 5
- 🚫 Commentary system (narrative interpretation of pressure/momentum) — Phase 5

## Verification Needed

1. **In-engine test:** Run a full match and check:
   - Pressure rises/falls realistically based on possession/territory
   - Territory % accurately reflects player positions
   - Tactical style modifiers affect team characteristics visibly
   - Pressure thresholds generate chances at the right times

2. **Balance check:**
   - Does High Press truly build pressure faster than Park The Bus?
   - Does Possession hold the ball proportionally longer?
   - Does Counter Attack create isolated, high-quality chances?

## Next Phase: Phase 3 — Chance Generation & Resolution

### Goals
- Implement `ChanceGenerator` — spawns chance objects when pressure thresholds crossed
- Implement `ChanceResolver` — resolves chances into goal/save/off-target outcomes
- **Replace M17's direct shot decisions** with pressure-driven chance flow
- Remove `MatchDecisionEngine._make_decision()` shot logic (passes remain, but shots only from chances)

### Files to Create/Modify
- New: `scripts/chance_generator.gd` (ChanceGenerator)
- New: `scripts/chance_resolver.gd` (ChanceResolver)
- Modify: `scripts/match_decision_engine.gd` (remove shoot decision, integrate chance system)
- Modify: `resources/live_match_state.gd` (track active chances, integrate chance resolution)

### Key Questions Before Phase 3

1. **Chance spawn rate:** How often should chances spawn? Every time pressure crosses a threshold, or continuously if sustained?
2. **Chance selection:** Who shoots? The player currently on the ball, or do we pre-select a "chance striker"?
3. **Chance duration:** If a chance is generated but not taken immediately, how long does it stay "live" (30s? Until pressure drops)?
4. **Goalkeeper role:** Does the keeper's quality factor into xG calculation, or is it post-roll?
