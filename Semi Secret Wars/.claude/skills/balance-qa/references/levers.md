# Tuning lever map

Concrete knobs, ordered by the lever hierarchy in SKILL.md (most surgical first).
Values are current as of the V1-removal / V2-promotion refactor (2026-07-20).

**Verify before quoting.** These drift. Read the file rather than trusting this table
when a number is load-bearing for a decision.

---

## 1. Level layout — `config/level_{1,2,3}_layout.tres` (`LevelLayout`)

Per-level geometry. The most surgical lever and the main source of level *identity*.

| Field | Meaning | L1 current |
|---|---|---|
| `lane_length` | Total lane length (centred on origin) | 6000 |
| `lane_half_height` | Half-height; play area is ±this | 450 |
| `deploy_band_x_min/max` | Fixed deploy band at the left end | -2900 / -2300 |
| `villain_lair` | Where the dormant villain sits | (2900, 0) |
| `spawn_points` | `Array[Vector3]` — (x, y) = position, **z = gate HP** | 4 gates: (-1100,-180,**340**), (-100,220,**400**), (900,-220,**480**), (1900,200,**560**) |
| `obstacles` | (x,y)=centre, z=radius; blocks + steers | — |
| `lakes` | (x,y)=centre, z=x-radius; entry hazard | — |
| `scenery` / `border_decor` | Decorative only, no gameplay effect | — |
| `objective_positions` | Dormant — no lane authors these today | empty |

**Raw derived geometry** (arithmetic only — do not treat distance as a diagnosis by
itself; see the callout below):

- Hero spawn = centre of the deploy band = **(-2600, 0)** on L1.
- Deploy → lair straight-line distance ≈ **5500px**.
- Nearest gate to spawn ≈ **1500px** away.
- Gate spacing ≈ 1000px apart, HP ramping 340 → 560 left to right.

> ⚠ **A raw distance is not a timeline, and a timeline is not a cause.** It's tempting
> to read "5500px is a long way" and stop there — V1's Level 1 really was broken by a
> ~3170px deploy→lair gap, so a bigger number here looks like the same story repeating.
> **It measured differently the one time this was actually traced**: minions hunt
> heroes field-wide (not gated by detect range — see `minion.gd` `HUNT_INTERVAL`) and
> close at roughly their own speed plus the hero's, so first contact on L1 lands in
> single-digit seconds, not tens. The straight-line distance to the *lair* barely
> matters if the swarm reaches the party long before the party reaches the lair.
>
> The lesson isn't "L1 is fine" — it's that **the distance number seduces you into
> guessing instead of computing.** Before attributing a pacing complaint to travel time
> (here or on any level), work out the actual timeline: time-to-first-contact (closing
> speed of the nearest threat, not raw distance), then time-to-kill against what's
> actually in the way (gate HP ÷ realistic party DPS, accounting for `V2_DAMAGE_MULT`
> and however much of that DPS the swarm is absorbing rather than the gate). Only once
> you have that timeline do you know whether the drag is travel-bound, contact-bound,
> or DPS-bound — and each points at a different lever. Never let a plausible-looking
> static number substitute for that arithmetic, including numbers you find in this
> document.

---

## 2. Encounter config — `config/stage_{1,2,3}_config.tres` (`StageConfig`)

Per-level swarm pressure. Shapes the fight's curve *over time*.

| Field | Meaning | Default | L1 current |
|---|---|---|---|
| `swarm_cap_start` | Live-minion cap at fight start | 6 | **14** |
| `escalate_every` | Seconds between cap raises | 12.0 | **14.0** |
| `escalate_step` | Cap raise per escalation | 1 | **2** |
| `swarm_max_cap` | Hard ceiling on live minions | 24 | **90** |
| `spawn_interval` | Seconds between spawn ticks | 0.5 | **2.2** |
| `spawn_batch` | Minions per tick | 1 | **5** |
| `minion_speed` | Swarm move speed | 90.0 | **105.0** |
| `villain_type` | `dark_mage` / `berserker` / `mech_robot` | — | dark_mage |
| `minion_type` | Which minion scene the swarm uses | — | minion |
| `villain_hp_mult` | Multiplies villain's authored max_hp at spawn | 1.0 | **1.6** |

**Which knob for which symptom:**

- *Opening too brutal / cold-start deaths* → `swarm_cap_start`, `spawn_batch`
- *Long fights spiral late* → `escalate_every`, `escalate_step`, `swarm_max_cap`
  (`escalate_every` is the dominant lever for longer fights specifically)
- *Sustained pressure wrong throughout* → `spawn_interval`, `spawn_batch`
- *Boss is a flat HP wall* → `villain_hp_mult` (prefer behavior work — see SKILL.md)

Note L1 currently sits well above the script defaults across the board (cap 90 vs 24,
batch 5 vs 1) — these came from the "grind progression" pass and are **first-pass,
unswept**.

---

## 3. Villain stats & behavior — `scenes/villain/`

| File | Class | Knobs |
|---|---|---|
| `villain_base.gd` | `Villain` (base) | `villain_name`, `aggro_radius` (350 = dormancy wake distance) |
| `dark_mage.gd/.tscn` | `DarkMage` | `flee_distance` 260, `teleport_interval` 20, `teleport_range` 400, `teleport_minion_count` 4, `leash_radius` 520, `shoot_interval` 1.0, `shoot_damage` 4, HP 1450 |
| `berserker.gd/.tscn` | `Berserker` | `charge_duration` 3.0, `recover_duration` 1.5, HP 725, dmg 10, interval 1.1 |
| `mech_robot.gd/.tscn` | `MechRobot` | `zone_interval` 5.0, `zone_duration` 4.0, `zone_radius` 60, `zone_slow_factor` 0.7, HP 1050, dmg 12 |

Effective villain HP = authored `max_hp` × the level's `villain_hp_mult`
(e.g. Dark Mage on L1 = 1450 × 1.6 = **2320**).

All three behaviors were authored for V1's open ellipse, not a 6000×900 lane —
Dark Mage has little lateral room to kite, MechRobot is fully stationary, and none
interact with the lane's defining feature (destructible gates). Re-authoring them for
the lane is planned work (Part C3).

---

## 4. Economy — run-to-run pacing

Change these when the complaint is about *progress*, not about a specific fight.

### In-run XP → boons (`scenes/run/run_state.gd`)

`xp_needed(level) = XP_BASE × XP_GROWTH^level × (EARLY_LEVEL_DISCOUNT if level < EARLY_LEVEL_CAP) × XP_GRIND_MULT`

| Const | Value |
|---|---|
| `XP_BASE` | 40.0 |
| `XP_GROWTH` | 1.35 |
| `EARLY_LEVEL_CAP` | 3 |
| `EARLY_LEVEL_DISCOUNT` | 0.5 |
| `XP_GRIND_MULT` | 1.8 |
| `OFFER_SIZE` | 3 boon cards per level-up |

Resulting thresholds: **L0 36, L1 49, L2 66, L3 177, L4 239.**

> ⚠ **Discount cliff at level 3.** The early-level discount ends exactly as growth
> compounds, so the L2→L3 step jumps **2.7×** (66 → 177) while every other step is
> ~1.35×. If boon pacing "falls off a cliff" mid-run, this is the first suspect.

### Persistent currencies (`scenes/state/game_state.gd`, `scenes/enemies/lane_spawner.gd`)

| Source | Value |
|---|---|
| Gold per minion kill | 0.5 (fractional, banked as it crosses whole numbers) |
| Gold per gate destroyed | 15 |
| Run-end payout | `GOLD_PER_LEVEL 10` × levels cleared + `GOLD_WIN_BONUS 15` on a win, floor `GOLD_MIN 5` |
| Kill XP assist share | `KILL_ASSIST_SHARE 0.5` (non-killers bank half) |
| Banked XP | Every point of run XP also banks permanently (shared across roster) |

A clean L1 clear ≈ 4 gates × 15 = **60g** + kill drip + 25g run-end.

### Spending

| Catalog | Costs |
|---|---|
| `scripts/ability_tiers.gd` | Tier 2 **40g**, tier 3 **70g** per hero (tier 1 free) |
| `scripts/ability_mods.gd` | 45–60g per mod; **downsides currently disabled in code** (upside-only) |
| `scripts/stat_upgrades.gd` | HP base 20g / Damage 25g / Atk Speed 30g, all `cost_growth` 1.15 per purchase; effect +8% / +8% / +5% each. Bought with **banked XP**, not gold |

### Unlock gates (`scripts/achievements.gd`)

| Achievement | Threshold | Unlocks |
|---|---|---|
| Swarmbreaker | 150 minions killed (lifetime) | ARTEMIS |
| Gatecrasher | 10 gates destroyed (lifetime) | WARDEN |
| Giant Slayer | 50% of a villain's HP in one run | BEACON |

All **first-pass guesses**, never calibrated against real throughput. Gatecrasher ≈ 2.5
clean L1 clears (4 gates each). Fresh saves start with **THUNDAAR only**.

---

## 5. Hero stats & boons — last resort

Touching these invalidates every prior result for every level and comp simultaneously.

### `scenes/heroes/hero.gd` — `HERO_STATS`

Authored table, then multiplied by `V2_HP_MULT 0.5` / `V2_DAMAGE_MULT 0.5` at spawn,
then by purchased `StatUpgrades`.

| Hero | Role | Authored HP / DMG | Effective at spawn (×0.5) | Speed | Range |
|---|---|---|---|---|---|
| THUNDAAR | Tank | 110 / 10 | **55 / 5** | 90 | melee, 0.7s |
| ARTEMIS | Burst | 80 / 6 | **40 / 3** | 100 | ranged |
| WARDEN | Control | 90 / 6 | **45 / 3** | 90 | ranged 120, 0.6s |
| BEACON | Support | 100 / 8 | **50 / 4** | 90 | melee, 0.6s |

Other hero-wide knobs: `SYNERGY_DISTANCE` 200 / `SYNERGY_DAMAGE_MULT` 1.15 /
`SYNERGY_COOLDOWN_REDUCTION` 0.3 / `SYNERGY_XP_MULT` 1.25; `RANGED_STANDOFF_FRACTION`
0.6 (`combatant.gd`). Lone Wolf was **removed entirely** — solo runs get no
compensation buff, by design.

### Swarm units — `scenes/enemies/`

`minion.gd` applies `DETECT_RANGE_MULT 2.2` and `INTERCEPT_LEAD_MULT 0.35` on top of
each scene's authored values (aggressive, beeline-y by intent). Variants
(`brute_`/`elite_`/`ranged_minion.gd`) are currently **stat reskins only** — all run the
same hunt logic, so a `ranged_minion` charges like a brute rather than holding range.
Giving them distinct behavior is planned work (Part C4).

`scripts/boons.gd` holds the in-run boon catalog (Power/Vitality/Haste/Swiftness/
Fortune/Ferocity).

---

## Instrumentation & harness

> **There is currently no automated sweep.** `balance_sweep.gd`, `balance_sweep_runner`,
> `behavior_probe`, and `death_curve_probe` were all deleted with V1 (they loaded V1's
> `battlefield.tscn`). Rebuilding a lane-shaped harness is Part C6. **Nothing in the
> lane build has ever been swept.**

When rebuilding, the V1 harness earned these lessons — carry them forward:

- Play whole **run attempts** (chained level loads), not isolated battles — depleted
  entry HP is the thing that made L2 unwinnable and only a chained harness shows it.
- Emit per-level diagnostics, not just win/lose: **entry HP, time-to-villain-alert,
  peak swarm, kills, per-hero level and boons**. Failures must be diagnosable from the
  sweep output alone.
- Explicitly set mod/tier/stat-upgrade state per sweep — never inherit it from
  `user://save.json`. Run a **zero-upgrade floor** pass and a **with-upgrades** pass.
- Set `RunState.headless = true` so level-ups don't pause for the boon UI and deadlock.
- Keep it level-count-agnostic (a 4th level shouldn't require harness edits).
- Time cap generously and check whether failures cluster at the cap before believing
  them; 8+ trials per comp, since 4 was too noisy to read.
- Wipe fog between geometry changes — stale per-level PNGs are keyed to old layouts.

## Persistence

`user://save.json` (schema **v6**), `user://fog/level_N.png`. `GameState.full_reset()`
(F12 in-game) wipes save + run state + fog. Schema bumps wipe rather than migrate.
