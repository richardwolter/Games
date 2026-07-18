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

## Dead Ball Rules: Throw-Ins, Corners, Goal Kicks (`scripts/dead_ball_system.gd`)

First-pass placeholder — not designer-reviewed. Adds the pitch's out-of-bounds lines to the previously-unbounded ball: `resources/ball_state.gd` now tracks `last_touch_team`/`last_touch_player` (updated on every `BallState.set_possession`, i.e. every genuine touch, plus explicit `record_touch` calls for a keeper's save or an interceptor's touch that don't hand over possession) and a `dead_ball_active` flag that pauses `PossessionSystem`'s normal loose-ball roll/pickup and `MatchDecisionEngine`'s carrier decisions while a restart is in progress — `DeadBallSystem` is the sole owner of the ball during that window.

- **Detection:** every frame, if the ball is loose (not carried, not mid-pass) and outside the pitch's grass rect (`PlayerMovementSystem.get_grass_rect()` — the same boundary player movement targets are already clamped to), `DeadBallSystem` classifies the restart. A ball exiting top/bottom is a touchline exit; left/right is a goal-line (byline) exit.
- **Throw-in:** touchline exit, awarded to whichever side did **not** touch it last (`last_touch_team`). Restart spot: the exact exit x-position (clamped `THROW_IN_EDGE_MARGIN` = 10 units from the corners) on the line it crossed.
- **Corner vs. goal kick:** byline exit, resolved by the real rule — if the last touch belonged to the team **attacking** that end, it's a **goal kick** for the defending side; if it belonged to the **defending** side (including a goalkeeper's save touch), it's a **corner** for the attacking side. Goal kick spot: a fixed point `GOAL_KICK_DEPTH_RATIO` (0.08 × pitch width) inside the goal line, centered. Corner spot: the corner flag nearest the exit y, inset `CORNER_EDGE_MARGIN` = 14 units from both edges.
- **Shots feed the same rule, not a special case:** `MatchDecisionEngine._take_shot` already resolves SAVED/OFF_TARGET before `PossessionSystem.on_shot_attempt` places the ball; that call now also records the goalkeeper as last touch on a SAVED (so it resolves to a corner) and sends the ball just past the byline on any non-GOAL outcome (an OFF_TARGET leaves the shooter as last touch, so it resolves to a goal kick) — no separate corner/goal-kick logic lives in the shot code itself.
- **Taker (fixed by role, not pure proximity, per Designer sign-off):** throw-in → nearest fielded **DEF**-slot player of the awarded side; corner → nearest fielded **FWD**-slot player; goal kick → the goalkeeper. Falls back to the nearest fielded outfield player if that slot category isn't on the pitch.
- **Sequence:** the taker's movement target is overridden straight to the restart spot (`PlayerMovementSystem.set_dead_ball_taker`) while every other player keeps reacting normally — the awarded side is treated as "attacking" for support-run/marking shape purposes the moment the restart triggers, per Designer sign-off that only the taker should be scripted. Once the taker arrives (within the existing `ARRIVAL_RADIUS` = 24), the restart is played as an instantly-resolving pass (no interception risk modeled for restarts) to the nearest fielded teammate (excluding the GK) to a type-specific aim point: `THROW_IN_AIM_FORWARD` = 120 units downfield of the throw for a throw-in, `CORNER_AIM_DEPTH` = 90 units in front of the goal line for a corner, or the center circle for a goal kick's long punt. Flight duration reuses `MatchDecisionEngine.PASS_SPEED`/`PASS_MIN_DURATION_SEC`/`PASS_MAX_DURATION_SEC` — no duplicated pacing constants.
- **Visual:** no dedicated throw/corner/goal-kick animation exists in the asset pack — the taker plays the existing one-shot Kick animation (`animate_pass`, not `play_kick`, since `play_kick`'s own goal-directed ball tween would fight the restart's real receiver-directed flight); only the ball's own flight distinguishes the three restarts.
- **Explicitly out of scope:** offside, fouls/cards (restarts here are only for the ball leaving the pitch), contested/intercepted restarts, corner near-post/far-post player runs, throw-in foul (over-the-head technique) checks.

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

## Momentum System (Milestone 18: Unified Match Narrative Engine — Phase 1)

First-pass placeholder — not designer-reviewed. Replaces M17's position-driven shot decisions with abstract "pressure phases" driven by momentum, possession, and tactical identity.

### Team Match State (`resources/team_match_state.gd`)

Per-team hidden state that evolves every periodic update (every 3 real-time seconds):

- **momentum** (−100 to +100): confidence/emotional state driven by recent events; decays naturally to prevent permanent dominance
- **possession_pct** (0–100): derived from cumulative ball-possession time; affects pressure calculation
- **territory_pct** (0–100): **TBD** — spatial dominance not yet tracked; planned for Phase 2
- **confidence** (0–100): psychological state, drifts toward momentum; high confidence → more aggression
- **organization** (0–100): defensive cohesion; positive momentum increases, recent goals against decrease
- **physical_energy** (0–100): stamina pool for high-intensity play; drains with time and aggression, slower in first half
- **aggression** (0–100): **TBD** — set per tactical style; affects fouls/cards likelihood
- **tactical_style** (string): one of "High Press", "Possession", "Counter Attack", "Park The Bus", "Long Ball"; determines modifiers on all subsystems
- **pass_chain_length** (int): consecutive passes without turnover; awarded bonus momentum per pass
- **recent_events** (array): last 10 events (goal_scored, tackle, interception, etc), used for momentum combo logic

### Momentum Events & Bonuses (`scripts/momentum_system.gd`)

Event-driven momentum changes, applied when shots are resolved and other match events occur:

| Event | Bonus | Notes |
|---|---|---|
| Goal Scored | +35 | Large swing on scoring |
| Goal Conceded | −30 | Smaller swing (defensive resilience) |
| Save | +8 | Goalkeeper heroics build confidence |
| Tackle | +4 | Ball recovery builds momentum |
| Interception | +5 | Defensive success slightly stronger than tackles |
| Pass Chain | +1.5 per pass | Consecutive passes → cumulative bonus |
| Misplaced Pass | −2 | Small penalty, encourages careful buildup |
| Turnover (interception/tackle) | −8 | Lost possession → confidence dip |
| Yellow Card | −5 | Caution reduces team momentum |
| Red Card | −20 | Ejection → large demoralization |
| Injury (own player) | −10 | Squad loss → morale shock |

All values first-pass placeholders — not designer-balanced.

### Natural Decay & Confidence Drift

- **Base decay:** momentum decays by `BASE_MOMENTUM_DECAY` (2.5) every periodic update (every 3 real-time seconds), preventing one team from dominating permanently via momentum alone
- **Confidence drift:** confidence slowly drifts toward a target calculated from momentum (high momentum → more confident), never snaps instantly
- **Organization shift:** organization = 50 + (momentum / 100) × 15, modified by recent goals against
- **Physical energy drain:** drains with match progress and high aggression; faster in second half

### Possession Tracking

- **Possession time:** each team accumulates `possession_time_seconds` while holding the ball (tracked via `BallState.possession_player`)
- **Possession percent:** recalculated every periodic update as (team's time / total time) × 100
- **Pass chains:** reset to 0 on turnover/interception; each successful pass adds 1 to the chain and awards momentum bonus
- **Pressure calculation:** `(momentum + 100) × 0.25 + (possession % / 100) × 25 + (territory % / 100) × 20`, clamped 0–100 — **TBD pending Phase 2 territory tracking**

## Tactical System (Milestone 18, Phase 2)

Each of the 5 tactical styles applies modifiers to subsystems — affects possession dominance, pass accuracy, defensive intensity, etc.

| Style | Organization | Aggression | Confidence | Possession | Pass Completion | Interception | Tackle | Shot Chance | Fatigue |
|---|---|---|---|---|---|---|---|---|---|
| High Press | ×0.8 | ×1.3 | ×1.15 | ×0.85 | ×0.9 | ×1.4 | ×1.3 | ×0.95 | ×1.25 |
| Possession | ×1.1 | ×0.85 | ×1.2 | ×1.35 | ×1.2 | ×0.85 | ×0.9 | ×0.8 | ×0.9 |
| Counter Attack | ×1.0 | ×1.0 | ×1.05 | ×0.7 | ×0.95 | ×1.15 | ×1.1 | ×1.2 | ×1.1 |
| Park The Bus | ×1.3 | ×0.7 | ×0.9 | ×0.6 | ×1.1 | ×1.5 | ×1.4 | ×0.5 | ×0.8 |
| Long Ball | ×0.95 | ×1.1 | ×1.0 | ×0.75 | ×0.75 | ×1.1 | ×1.05 | ×0.9 | ×1.05 |

**Design rationale:**
- **High Press:** Stretched defensive line, aggressive intent, higher fouls. Possession sacrificed for ball-winning. Exhausting.
- **Possession:** Well-organized, controlled, safer passes. Defensive risk (fewer defenders). Patient buildup.
- **Counter Attack:** Balanced defense, explosive transitions. Fewer shots but higher quality. Bursts of intensity.
- **Park The Bus:** Ultra-compact, disciplined, almost immobile. Kills attacking chances but generates fortress defensive solidity.
- **Long Ball:** Direct, chaotic, risky passes. Many aerial duels. Second-ball situations replace sustained buildup.

All values first-pass placeholders, not designer-balanced.

## Pressure System (Milestone 18, Phase 2)

Replaces discrete "zone" logic with continuous pressure calculation. Pressure drives chance generation.

**Pressure formula:**
```
pressure = (momentum_norm × 0.30) + (possession % × 0.25) + (territory % × 0.25) + (tactical_base × 0.20)
```
Where:
- `momentum_norm` = (momentum + 100) / 200, normalized to 0–1
- `possession %` = 0–100, time-weighted
- `territory %` = 0–100, calculated from player positions (defending team's players in own half / attacking team's players in opponent's half)
- `tactical_base` = fixed per style (High Press: 75, Possession: 60, Counter Attack: 40, Park The Bus: 30, Long Ball: 50)

**Territory calculation:**
- Count attacking team's players in opponent's half: × 5 per player
- Count defending team's players NOT in their own half (i.e., pushed up): × 4 per player pushed up
- Sum: 0–100 representing spatial dominance

**Chance generation thresholds (pressure-based):**
- pressure ≥ 90% → **Clear-Cut chance** (xG: 0.65–0.95)
- pressure ≥ 80% → **Big chance** (xG: 0.45–0.65)
- pressure ≥ 60% → **Good chance** (xG: 0.20–0.45)
- pressure ≥ 40% → **Small chance** (xG: 0.05–0.20)
- pressure < 40% → **No chance**

Approved by Designer 2026-07-17; thresholds first-pass, subject to rebalance after play-testing.

## Chance Generation & Resolution System (Milestone 18, Phase 3)

**Chance object** (`resources/chance.gd`):
- Represents a live chance in the match
- Properties: chance_type (Small/Good/Big/Clear-Cut), xG (0.05–0.95), striker (pre-selected), time_spawned, duration (10–30s random)
- Methods: `is_expired()` (checks if duration exceeded), `take()` (marks as resolved)

**Chance Generation** (`scripts/chance_generator.gd`, Designer decision: Option C):
- Spawns one chance per threshold crossing (pressure crosses 40%/60%/80%/90% boundary)
- **Bonus chances:** If pressure sustained >80% for 15+ seconds, spawn bonus Big chance every 15s (represents sustained pressure/domination)
- Striker pre-selection: Highest-rated forward/attacker available (ST > WING > CAM fallback)
- Chance duration: Random 10–30s (Designer decision: Option B — player can delay taking it)
- Track per-team: `home_active_chances`, `away_active_chances` (auto-expire when time exceeds duration)

**Chance Resolution** (`scripts/chance_resolver.gd`):
- Resolves chance → GOAL / SAVED / OFF_TARGET
- Formula: `goal_probability = xG × striker_quality / goalkeeper_defense`
  - `striker_quality` = 0.7 + (Kick/100 × 0.4), scaled by condition (50%–100%)
    - 70-Kick striker: 0.98 multiplier; 100-Kick striker: 1.10 multiplier
  - `goalkeeper_defense` = 0.85 + (Strength/100 × 0.3), scaled by condition
    - 70-Strength keeper: 0.97 multiplier; 100-Strength keeper: 1.13 multiplier
  - **Example:** 0.60 xG × 1.0 striker × 1.0 goalkeeper = 60% goal chance
  - **Better striker + weak keeper** = higher goal chance
  - **Weak striker + great keeper** = lower goal chance
- Outcome split (if not GOAL):
  - SAVED vs OFF_TARGET split: 60% + (Kick/100 × 20%) = 60–80% chance to hit target
  - Better strikers more likely to at least hit the goal

**Auto-Resolution:** Chances that expire (duration exceeded) auto-resolve immediately. Per Designer decision (Option B), player can "delay taking it" by letting the chance duration tick without resolving — if it expires, it auto-resolves; otherwise, can click to take it (UI wiring deferred to Phase 5).

**Integration:** Wired into `LiveMatchState.update_team_states()` — chance generator checks thresholds each periodic update (every 3s), auto-resolution checks each update. Momentum system is updated on goal/save outcomes (momentum already applied in `record_shot_result()`).

First-pass placeholder constants (duration range, bonus interval, striker selection) — not designer-balanced.

## Event System (Milestone 18: Unified Match Narrative Engine — Phase 4)

First-pass placeholder — not designer-reviewed. Fouls, cards, and injuries trigger probabilistically from tackle contests and apply momentum penalties.

### Foul & Card Triggers (`scripts/event_system.gd`)

Events fire on every tackle contest (checked every 1.4 real-time seconds while a defender is in range):

- **Foul chance (per tackle):**
  - Base: `FOUL_BASE_CHANCE` = 15% (0.15)
  - Aggression bonus: team_state.aggression × 0.005 (+0.5% per aggression point)
  - Pressure bonus: team_state.pressure_level × 0.002 (+0.2% per pressure point)
  - Clamped: 5–60% range
  - **Example:** 50-aggression, 40-pressure team: 15% + 0.25% + 0.08% = 15.33% foul chance
  - **Example:** 80-aggression, 90-pressure team: 15% + 0.40% + 0.18% = 15.58% (clamped to max)

- **Card escalation:**
  - First foul → Yellow card (−5 momentum, logged to match feed)
  - Second foul → Red card/ejection (−20 momentum, logged)
  - Discipline tracking per player in `player_discipline` dict (0, 1, or 2+ fouls)

### Injury Triggers (`scripts/event_system.gd`)

Events fire on every tackle contest (same 1.4s interval):

- **Injury chance (per tackle):**
  - Base: `INJURY_BASE_CHANCE` = 2% (0.02)
  - Aggression bonus: (aggression − 70) × 0.01 if aggression > 70 (only high-intensity play carries injury risk)
  - Clamped: 1–15% range
  - **Example:** 50-aggression team: 2% (base only)
  - **Example:** 80-aggression team: 2% + (10 × 0.01) = 3%

- **Injury distribution (if injury triggers):**
  - 60% chance attacker is injured
  - 40% chance defender is injured
  - Injured player marked in `event_system.recent_match_events` (removal from pitch deferred to Phase 5)

### Momentum Penalties (`resources/live_match_state.gd`)

Applied immediately when event occurs, via `apply_match_event()`:

| Event | Momentum | Notes |
|---|---|---|
| Yellow Card | −5 | Caution reduces team poise |
| Red Card | −20 | Ejection = massive disruption |
| Injury (Own Player) | −10 | Squad loss → morale shock |

First-pass placeholder constants — not designer-balanced.
