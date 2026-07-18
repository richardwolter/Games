# Milestone 18, Phase 3: Chance Generation & Resolution

## Completion Summary

Phase 3 replaces Milestone 17's direct shot decisions with pressure-driven chance generation. Chances now spawn when pressure crosses thresholds, stay live 10–30 seconds, and auto-resolve if not taken.

## Files Created

### Chance Object
- `resources/chance.gd` (`Chance`)
  - Data class: chance_type (Small/Good/Big/Clear-Cut), xG (0.05–0.95), striker (pre-selected), spawn_time, duration (10–30s random), taken flag
  - Methods: `is_expired()`, `take()`

### Chance Generation
- `scripts/chance_generator.gd` (`ChanceGenerator`)
  - Spawns chances on pressure threshold crossings (40%/60%/80%/90%)
  - Bonus Big chances every 15s if pressure sustained >80%
  - Pre-selects highest-rated forward/striker as chance taker
  - Tracks active chances per team, auto-removes expired ones
  - Signal: `chance_generated` emitted when spawned

### Chance Resolution
- `scripts/chance_resolver.gd` (`ChanceResolver`)
  - Resolves chance to GOAL/SAVED/OFF_TARGET
  - Formula: `goal_probability = xG × striker_quality / goalkeeper_defense`
    - Striker quality multiplier (0.3–1.5): based on Kick stat, scaled by match condition
    - Goalkeeper defense multiplier (0.5–1.5): based on Strength stat, scaled by condition
  - SAVED vs OFF_TARGET split: 60%–80% chance to hit target (favors high Kick strikers)
  - Signal: `chance_resolved` emitted with shooter, outcome, xG

## Files Modified

### `resources/live_match_state.gd`
- Added `chance_generator`, `chance_resolver`, `match_time_seconds` properties
- Modified `update_team_states()`: calls chance generator to check for threshold crossings
- New method `_auto_resolve_expired_chances()`: auto-resolves chances when duration exceeded
- Modified `advance_minute()`: clears remaining chances at full-time

### `scenes/live_match/live_match.gd`
- Track `match_time_seconds` each periodic update for chance expiry tracking
- Pass `TEAM_STATE_UPDATE_INTERVAL` (not scaled delta) to chance system for consistent timing

### `BALANCE.md`
- Added "Chance Generation & Resolution System" section with full details
- Documented spawn logic, striker selection, duration, auto-resolution, and resolution formula

### `PRODUCTION.md`
- Updated Milestone 18 entry to include Phase 3 details and Designer decisions

## What Phase 3 Enables

✅ **Pressure-driven chances** — no more random shots; chances spawn from momentum/possession/territory buildup
✅ **Chance quality variation** — Small/Good/Big/Clear-Cut reflect actual match pressure
✅ **Striker agency** — best available forward gets the chance (not random)
✅ **Realistic xG model** — better striker + weak keeper = higher goal chance
✅ **Natural match flow** — sustained pressure = multiple chances (bonus logic); pressure drops = fewer chances

## What's Still TBD / Not Yet Implemented

- 🚫 Manual chance trigger (player UI to click "Take Shot") — Phase 5
- 🚫 Event system (injuries, cards, fouls from aggressive play/pressure) — Phase 4
- 🚫 UI indicators (chance highlights, countdown timer on active chances) — Phase 5
- 🚫 Commentary (narrative reactions to chances generated/missed) — Phase 5
- 🚫 Chance-based momentum (gaining momentum when generating chances, losing on missed chances) — could be Phase 4

## Design Decisions Applied

1. **Spawn rate (Option C):** One chance per threshold crossing + bonus Big chances every 15s if sustained >80% pressure
   - Rationale: Single threshold provides clear, quantifiable breakpoints; bonus sustains pressure periods
   - Result: Dominating teams get multiple chances; struggling teams see drier periods

2. **Chance taker (Option B):** Pre-select highest-rated forward/striker
   - Rationale: Striker is most likely to capitalize; avoids defensive players shooting
   - Selection order: ST > WING > CAM > CM (fallback)

3. **Duration & expiry (Option B):** 10–30 seconds live, auto-resolve if not taken
   - Rationale: Allows narrative breathing room; player can delay without pressure, but passive play results in miss
   - Result: Matching designer request to "delay taking it" while maintaining natural expiry

## Verification Needed

1. **In-engine test:** Run a full match and check:
   - Chances spawn at correct pressure thresholds (40%/60%/80%/90%)
   - Bonus chances spawn during sustained >80% pressure
   - Striker is always the highest-rated forward (visual check in events log)
   - Chances auto-resolve after 10–30s
   - Goal probability matches xG formula (60% xG + 100-Kick striker + 70-Strength keeper ≈ ~60% goal)

2. **Balance check:**
   - Do better strikers convert more often?
   - Do worse keepers concede more from same xG?
   - Do sustained pressure runs produce multiple chances?

## Next Phase: Phase 4 — Event System

### Goals
- Implement `EventSystem` (fouls, cards, injuries triggered by pressure/aggression)
- Wire aggression/intensity into discipline calculations
- Add injury probability on high-impact tackles

### Key Questions Before Phase 4
1. **Foul/card triggers:** How does aggression/pressure combine to create foul risk? (e.g., >70% aggression + >70% pressure = ~30% foul roll each tackle?)
2. **Injury probability:** On every high-intensity event (tackle, aerial duel), what's base injury risk? (e.g., 1% per tackle?)
3. **Consequence flow:** Do injuries/cards affect momentum? (injury to key player: −15 momentum?)
4. **Discipline accumulation:** Track fouls per player to increase red-card risk after yellow? (first yellow: −5 momentum, second: −20 + ejection?)
