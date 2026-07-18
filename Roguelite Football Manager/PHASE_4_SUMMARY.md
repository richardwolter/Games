# Milestone 18, Phase 4: Event System

## Completion Summary

Phase 4 implements the event system for match disruptions: fouls, yellow/red cards, and injuries triggered by tackle intensity, aggression, and pressure. Events apply momentum penalties and are logged to the match event feed.

## Files Created

### Event System
- `scripts/event_system.gd` (`EventSystem`)
  - Tracks discipline per player (foul accumulation)
  - Triggers fouls on tackles based on defender aggression + pressure
  - Yellow card on first foul, red card on second foul (ejection)
  - Injury probability on high-impact tackles, affects both players
  - Methods: `check_tackle_event()`, `get_player_fouls()`, `is_player_sent_off()`

## Files Modified

### `resources/live_match_state.gd`
- Added `event_system` (EventSystem instance)
- Added `apply_match_event()` method: logs events and applies momentum penalties
  - Yellow card: −5 momentum
  - Red card: −20 momentum
  - Injury: −10 momentum

### `scripts/match_decision_engine.gd`
- Added tackle event checking after each tackle contest
- Calls `event_system.check_tackle_event()` with defender/carrier and team states
- Processes event consequences: logs to match feed, applies momentum penalties

### `BALANCE.md` (updated with Phase 4 section — see below)

### `PRODUCTION.md` (updated with Phase 4 entry)

## Event System Constants (BALANCE.md)

- **Foul/card triggers:**
  - Base foul chance on tackle: 15%
  - Aggression multiplier: +0.5% per aggression point
  - Pressure multiplier: +0.2% per pressure point
  - Clamp range: 5–60%
  - Yellow card: first foul
  - Red card: second foul (ejection)

- **Injury triggers:**
  - Base injury chance on tackle: 2%
  - Aggression multiplier: +1% per point above 60
  - Clamp range: 1–15%
  - 60% chance to injure attacker, 40% defender

- **Momentum penalties:**
  - Yellow card: −5
  - Red card: −20
  - Injury (own player): −10

## What Phase 4 Enables

✅ **Fouls scale with intensity** — high aggression/pressure teams foul more
✅ **Discipline accumulation** — yellow → red escalation
✅ **Injuries add risk** — high-intensity play has consequences
✅ **Event logging** — fouls/cards/injuries appear in the match feed
✅ **Momentum swing** — events affect team confidence (cascading effects)

## What's Still TBD / Not Yet Implemented

- 🚫 **Player ejection enforcement** — red-carded players stay on pitch (Phase 5 UI)
- 🚫 **Injury removal** — injured players stay fielded (Phase 5 substitution wiring)
- 🚫 **Event commentary** — narrative reactions to cards/injuries (Phase 5)
- 🚫 **Pre-match injury/suspension** — players who were injured in prior match (future milestone)
- 🚫 **Straight red cards** — very violent play (future balance tuning)

## Design Decisions Applied

1. **Foul chance scaling:** Aggression (0.5%) and pressure (0.2%) combine, encouraging aggressive teams to foul more when desperate
   - Result: matches with high pressure see more disciplinary action

2. **Discipline accumulation:** Simple 0→1→2 foul tracking (yellow→red)
   - Rationale: clear escalation path, avoids tracking multiple cards per player
   - Alternative: straight reds on very aggressive challenges (Phase 5 balance)

3. **Injury probability:** Base 2% increases with aggression >70
   - Rationale: high-intensity challenges (>70 aggression) carry injury risk
   - Result: physical teams pay a price for aggressive play if unlucky

4. **Momentum penalties:** Large swing (−20 red card) mirrors scoring swing (+35 goal)
   - Rationale: ejection is a massive disruption; injury to key player is demoralizing
   - Effect: cascading consequences after disciplinary action

## Verification Needed

1. **In-engine test:** Run a full 90-minute match with high-aggression opponent:
   - Confirm fouls accumulate proportional to pressure/aggression
   - Confirm yellow → red card escalation works
   - Confirm momentum swings after events
   - Check event text appears in feed correctly

2. **Balance check:**
   - Does high-press team (High Press style, 75 base pressure) generate more fouls than Park The Bus?
   - Do injuries occur realistically (1-2 per match at normal aggression)?
   - Does red card momentum penalty feel appropriately severe?

3. **Edge cases:**
   - What happens when a player receives a red card? (Currently stays on pitch — Phase 5 fix)
   - What happens to bench players in injury reserve? (Not yet implemented)

## Next Phase: Phase 5 — UI & Commentary

### Goals
- Display momentum/pressure/chance indicators on screen
- Implement injury/red card enforcement (remove player from pitch)
- Add manual chance-taking UI (click to take pending chance)
- Commentary system (narrative reactions to events)

### Files to Create/Modify
- New: UI indicators (momentum bar, pressure gauge, chance timer)
- Modify: `scenes/live_match/live_match.gd` (UI integration)
- New: `scripts/commentary_system.gd` (narrative layer)

### Key Questions Before Phase 5

1. **Injury enforcement:** When a player is injured, what happens? Removed immediately, or can they stay on and slow down?
2. **Red card enforcement:** When sent off, do we show a visual highlight/removal from pitch?
3. **Chance UI:** How should pending chances be displayed? Highlight on pitch, or on-screen notification?
