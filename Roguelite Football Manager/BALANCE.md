# Roguelite Football Manager — Balance

**Status:** First-pass placeholder values, not tuned. Update in place as numbers change; don't duplicate values in code comments.

## Squad Generation (`scripts/squad_generator.gd`)

- **Squad size:** 23 players (Designer-approved 2026-07-17)
- **Stat scale:** 0–100 per stat (Speed, Strength, Kick, Pass, Stamina)
- **Starting stat range:** 15–55 (4th-division "raw nobodies" band, Designer-approved 2026-07-17)
- **Position composition (23 total):** GK 2, CB 4, FB 4, DM 2, CM 3, CAM 2, WING 3, ST 3
- **Secondary position chance:** 25% of players get one additional natural position, drawn from an adjacency map (e.g. CB↔FB, WING↔ST). First-pass placeholder — not designer-reviewed for exact rate or adjacency pairs.
- **Off-position penalty (`Player.OFF_POSITION_PENALTY`):** ×0.8 to all 5 stats when fielded outside natural positions. First-pass placeholder — not designer-reviewed. Used by squad generation only; superseded by the Formation Slot Compatibility table below for match-fielding once the position compatibility validation milestone lands.

## Formations (`resources/formation.gd`, `resources/formation_library.gd`)

**Shape (Designer-approved 2026-07-17):**

| Formation | Shape | GK | DEF | MID | FWD |
|---|---|---|---|---|---|
| High Defense | 5-3-2 | 1 | 5 | 3 | 2 |
| Solid Defense | 4-4-2 | 1 | 4 | 4 | 2 |
| Solid Attack | 4-3-3 | 1 | 4 | 3 | 3 |
| High Attack | 3-5-2 | 1 | 3 | 5 | 2 |

**Position Compatibility (stat multiplier, detailed position → formation slot category) (Designer-approved 2026-07-17):**

| Position | GK slot | DEF slot | MID slot | FWD slot |
|---|---|---|---|---|
| GK | 1.0 | — | — | — |
| CB | — | 1.0 | 0.8 | 0.5 |
| FB | — | 1.0 | 0.9 | 0.4 |
| DM | — | 0.8 | 1.0 | 0.6 |
| CM | — | 0.5 | 1.0 | 0.85 |
| CAM | — | 0.3 | 1.0 | 0.95 |
| WING | — | 0.2 | 0.95 | 1.0 |
| ST | — | 0.1 | 0.7 | 1.0 |

"—" slots are not implemented (e.g. a CB can never fill the GK slot) — validation should reject that assignment.

## Live Match Simulation (Milestone 17: Unified Real-Time Match Engine)

First-pass placeholder formulas — not designer-reviewed. No morale/traits/synergy/events/tactical-instructions yet (those systems don't exist). Superseded the old abstract per-minute duel/zone engine (`MatchEngine`, deleted) and the independent decorative pass RNG (`PassSystem`, deleted): `scripts/match_decision_engine.gd` (`MatchDecisionEngine`) is now the single source of truth for every ball-affecting event — shots, passes, tackles, interceptions — resolved from real player positions (`scripts/player_movement_system.gd`) and real per-player stat contests between whoever is actually involved, so the pitch view is not decoration over a separate dice roll. Only reuses existing Player stats (Speed/Strength/Kick/Passing/Stamina)/Condition/Formation/PositionCompatibility — no new attributes invented.

- **Real-time clock (`live_match.gd`):** replaces the old fixed 0.35s-per-minute tick. Sim-minutes advance from accumulated real time at `SIM_SECONDS_PER_SIM_MINUTE` = 3.3 (a full 90-minute match takes ~5 real minutes at 1x). A 1x/2x/4x speed control scales the `delta` fed to every per-frame system (decisions, ball physics, movement, the clock) uniformly, so speeding up doesn't change relative behavior, only pacing.
- **Condition (in-match fatigue, distinct from the permanent Stamina stat):** every fielded player starts each match at `STARTING_CONDITION` = 100.0. Each simulated minute it drains by `BASE_CONDITION_DRAIN` (0.6) × `(1.0 - (player.stamina / 100.0) × CONDITION_DRAIN_STAMINA_MITIGATION)`, where `CONDITION_DRAIN_STAMINA_MITIGATION` = 0.5 — a 0-Stamina player drains at the full base rate (~54 lost over 90 min), a 100-Stamina player drains at half that (~27 lost). Floored at 0. **Unchanged.**
- **Condition → effective stats:** each player's `PositionCompatibility`-adjusted stat (for their own fielded slot) is scaled by `CONDITION_FLOOR_MULTIPLIER + (1.0 - CONDITION_FLOOR_MULTIPLIER) × (condition / 100.0)`, `CONDITION_FLOOR_MULTIPLIER` = 0.5 — full condition = 100% effective, zero condition floors at 50% effective. **Unchanged**, now applied per individual contest rather than to a whole-team average.
- **Carrier decisions (`MatchDecisionEngine._make_decision`):** every `DECISION_INTERVAL` (randomized 0.8–1.6s) while a player holds the ball, they evaluate shoot / pass / dribble:
  - **Shoot** when within `SHOOTING_RANGE` = 260 world units of the real goal mouth (continuous distance, not a discrete zone). Chance per decision = `SHOT_CHANCE_BASE` (0.06) + proximity × `SHOT_CHANCE_PROXIMITY_BONUS` (0.30), proximity = `1 - dist/SHOOTING_RANGE`.
  - **Pass** — candidate receiver picked by weighted-random among fielded teammates within `PASS_MIN_DISTANCE`–`PASS_MAX_DISTANCE` (60–750 units), weight favoring closer + more forward-progressed options (`POSITION_WEIGHT_FORWARD` = 1.5, using the side's real current attack direction). Chance = `clamp((PASS_CHANCE_BASE (0.30) + PASS_CHANCE_PRESSURE_BONUS (0.25 if a defender is within PRESSURE_RANGE=90)) × (0.5 + carrier.passing/100), 0.05, 0.9)`.
  - **Dribble** — the default when neither fires: `PlayerMovementSystem` already drives the carrier forward every frame.
- **Tackles (`MatchDecisionEngine._update_tackle_pressure`):** the nearest real opposing defender within `TACKLE_RANGE` = 45 rolls a contest every `TACKLE_ATTEMPT_INTERVAL` = 1.4s while in range: `p_defender_wins = defender_rating / (defender_rating + carrier_rating)`, both condition-scaled — defender rating = `strength×0.6 + speed×0.4` (`DEFENSE_STRENGTH_WEIGHT`/`DEFENSE_SPEED_WEIGHT`), carrier "retention" rating = `strength×0.5 + speed×0.3 + passing×0.2` (`RETENTION_*_WEIGHT`). A win hands the ball straight to the defender (already adjacent — no separate loose-ball phase needed).
- **Pass interception (`MatchDecisionEngine._check_interception`):** any real opponent within `INTERCEPTION_RADIUS` = 55 world units of the pass lane can cut it out; the nearest/highest-rated candidate rolls `p_intercept = defender_rating×closeness / (defender_rating×closeness + passer_rating × PASS_LANE_SAFETY)`, `PASS_LANE_SAFETY` = 1.3 (favors the passer). A miss lands the pass at the receiver; a hit diverts the ball to the interception point along the lane.
- **Pass flight:** ball-flight duration = `clamp(distance / PASS_SPEED, PASS_MIN_DURATION_SEC, PASS_MAX_DURATION_SEC)`, `PASS_SPEED` = 550 units/sec, clamped 0.25–1.6s. The ball interpolates position every frame (`PossessionSystem._update_pass_flight`) so it's visibly in flight, and the intended receiver's movement target switches to "run to meet the ball" for the flight's duration.
- **Loose-ball 50/50s (`PossessionSystem._check_loose_ball_pickup`):** a single nearby player just picks it up; 2+ players from both sides within `PICKUP_RADIUS` = 34 resolve via a weighted contest (`strength×0.5 + speed×0.5`, biased by proximity) instead of "nearest wins outright."
- **Shot resolution (`MatchDecisionEngine._take_shot`):** shooter's condition-scaled Kick × a continuous quality multiplier (`lerp(SHOT_QUALITY_MIN=1.0, SHOT_QUALITY_MAX=2.2, proximity)`, replacing the old 3-step Zone lookup) vs. the opposing GK's condition-scaled Strength × `DEFENSE_FACTOR` = 1.1. `p_goal = shooter_kick / (shooter_kick + keeper_strength × DEFENSE_FACTOR)`. A miss is "SAVED" `SAVED_FRACTION` (0.6) of the time, "OFF_TARGET" otherwise — flavor-only split.
- **Events:** GOAL updates the score and emits `goal_scored` (unchanged text format `"%d' GOAL! <team> — <scorer> (h-a)"`); SAVED/OFF_TARGET append a flavor line with no score effect. Every shot also emits `shot_attempt` for the pitch-view animation. Passes/tackles/interceptions are **not** logged to the text event feed (too frequent at real-time pace) — the pitch view is the record of those, matching the Designer's ask to watch it rather than read a summary.
- **Movement (`scripts/player_movement_system.gd`):** formation slot is the base reference; ball carriers dribble forward (`DRIBBLE_ADVANCE_STEP`=60, `DRIBBLE_WANDER`=12, `PITCH_EDGE_MARGIN`=20 clamp); off-ball attackers make forward support runs (`FORWARD_SUPPORT_BIAS`=50) with separation from teammates (`SEPARATION_RADIUS`=90, `SEPARATION_STRENGTH`=40); defenders press (nearest only, `PRESSING_RADIUS`=220) or man-mark near their own zone (`MARKING_RADIUS`=260, `MARKING_BLEND`=0.55). Movement is steered with an acceleration cap (`ACCELERATION`=600 units/sec²) and eases down within `ARRIVAL_RADIUS`=24 of the target, instead of snapping directly to a fresh heading every frame — removes the frame-to-frame jitter from a heuristic target that flip-flops (e.g. switching who presses vs. marks). `BASE_MOVEMENT_SPEED` = 200 units/sec scaled by `player.speed/100`.
- **Substitutions (`MAX_SUBS`):** capped at 5 per match, home side only — the opponent lineup is fixed for the full 90 minutes (no AI subs yet). Any bench player can come on for any starter; the incoming player's condition resets to 100. **Unchanged.**
- **Formation changes:** unchanged — home side only, reassigns the current 11 starters into a new shape mid-match, no condition reset.
- **Opponent (`scripts/opponent_lineup_builder.gd`):** unchanged — fresh 23-player squad via `SquadGenerator`, random formation from `FormationLibrary`, lineup filled greedily by best `PositionCompatibility` fit per slot. Opponent name is flavor text only, not a balance value.
- **Kickoffs:** home side kicks off the match; the side that didn't kick off a half takes the next one; after a goal, the conceding side restarts from center. Taker is the nearest fielded outfield player on that side to the center circle (`live_match.gd._kickoff`) — a simple stand-in, not a designed mechanic.

## Persistent Condition (Fatigue) (`Player.persistent_condition`, `GameState.finish_match`)

First-pass placeholder — not designer-reviewed. Distinct from in-match Condition (above), which resets every match; persistent condition carries between matches so playing a player too many matches in a row has a lasting cost.

- **Storage:** `Player.persistent_condition` (0-100, default 100.0), saved with the squad.
- **Seeding a match:** `LiveMatchState` now seeds each fielded/substituted-in player's in-match Condition from their `persistent_condition` instead of a flat 100 — a tired player starts the match already worn down, which (via the existing Condition→effective-stats formula) drains faster and floors lower for the rest of that match. No separate stat-penalty formula.
- **End of match (`GameState.finish_match`, called from `live_match.gd` on Continue):** every squad player recovers `GameState.PERSISTENT_CONDITION_RECOVERY` (25.0), capped at 100 — models one match cycle of rest for the whole squad, played or not. Then every player who actually appeared in that match (started or subbed on) has their `persistent_condition` overwritten with the in-match Condition they finished at, superseding the recovery for that player.
- **Display:** color-coded "COND %" cue (green ≥70, yellow ≥40, red <40 — `LineupSlot._condition_color`) shown on every pitch slot and bench card in Pre-Match Setup, alongside (not replacing) the existing position-compatibility color tint.

## Matchday Bench

- **Size:** uncapped — the bench is the entire non-starting squad (currently 12 of 23 players with the standard 11-player formations). Designer-approved 2026-07-17: no cap needed, all available players are eligible substitutes. Implemented via `GameState.get_bench()`.

## Match Flow (`scripts/match_flow_engine.gd`)

Manages the display-minute clock's half-time pause (hard stop at 45', requires player Continue click) and injury time, randomized per half:
- First half: `INJURY_TIME_FIRST_HALF_MIN` = 2, `INJURY_TIME_FIRST_HALF_MAX` = 5
- Second half: `INJURY_TIME_SECOND_HALF_MIN` = 3, `INJURY_TIME_SECOND_HALF_MAX` = 6

Rendering: pitch sprite positions update per frame from `PlayerMovementSystem`. Ball height/color changes based on `BallState.in_air` (pure visual). Player animations auto-speed per movement velocity (idle when static, run when moving, kick on shots/passes). No offside/fouls/cards yet (deferred).
