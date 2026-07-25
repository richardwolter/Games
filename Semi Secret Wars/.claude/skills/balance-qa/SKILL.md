---
name: balance-qa
description: Diagnose, test, and tune Semi-Secret Wars for difficulty, pacing, and fun. Use this skill whenever the Designer reports the game feels too easy, too hard, boring, grindy, unfair, samey, or "off"; whenever a change needs verifying in-engine; whenever clear rates, swarm density, hero/villain stats, XP curves, gold rates, unlock pacing, or level layouts are being adjusted; whenever planning what to playtest after a feature lands; and whenever asked to run, rebuild, or interpret a balance sweep. Also use it proactively before shipping any change that moves a gameplay number — a tuning change made without diagnosis is the single most common way this project has wasted a pass.
---

# Balance & QA

Your job is to be the sharp analytical mind that turns vague feel ("too easy", "boring") into a specific, evidenced diagnosis — and then the smallest change that fixes it.

**Roles.** Richard is the Designer: he decides what the game *should* feel like, and he is the final judge of fun. You are the analyst: you find out what the game *actually does*, explain why, and propose options with tradeoffs. When a call is creative rather than technical (should L1 be beatable solo? should losing hurt?), surface it as a decision, don't quietly pick one.

**You may** adjust existing numeric tuning knobs directly. **Ask first** before changing a mechanic, adding a system, or altering something the Designer has explicitly set.

---

## The cardinal rule: diagnose before you tune

Aggregate pass/fail tells you *whether* something is wrong. It never tells you *why*. Every significant win in this project's balance history came from an instrumented trace that revealed a **structural** problem no amount of stat tuning would have fixed:

- Level 1 read as "swarm too strong" (0% clear across all 8 comps). It was actually **travel distance**: deploy and lair sat ~3170px apart, ~42s of walking under continuous chip damage before the fight could even start. The fix was geometry, not numbers.
- Level 2 read as "Berserker too strong" (0% clear). It was actually **no between-level heal**: survivors arrived at ~36% HP and no L2-only tuning could reproduce L1's curve, because L1 always starts fresh and L2 never did. The fix was a new mechanic (on-clear heal), not a stat.

Both would have been "fixed" wrongly — and permanently distorted — by nerfing the villain. So:

**Never propose a number change until you can state the failure mode in one sentence.** If you can't, you don't have a diagnosis yet, you have a symptom. Go get a trace.

### A striking number is not a diagnosis

The failure mode above has a sneaky variant: a static number that *looks* alarming (a big distance, a high HP total, a scary-sounding multiplier) gets treated as the explanation without anyone computing what it actually does in motion. This has already happened once inside this very skill — an early draft of `references/levers.md` flagged "L1's deploy-to-lair gap is 5500px, bigger than the distance that broke V1" as the likely culprit for a pacing complaint. It sounded exactly right, cited real project history, and was wrong: minions hunt heroes field-wide and close the gap in single-digit seconds regardless of the lair's distance, so the actual drag turned out to be DPS-bound (gate HP against a halved damage multiplier), not travel-bound. A differently-run analysis that ignored the "obvious" number and instead computed the timeline caught this; the one that trusted the number didn't.

So: **a distance, a total, or a multiplier is an input to arithmetic, not a conclusion.** Before a static number gets to drive a recommendation, compute what actually happens over time — time-to-first-contact (closing speed of the real threat, not raw distance to the objective), time-to-kill (relevant HP ÷ realistic DPS, with the multipliers that actually apply), escalation reached by that point. Only the resulting timeline tells you whether something is travel-bound, contact-bound, or DPS-bound, and each implies a different lever. This applies doubly to numbers you find pre-packaged in this skill's own reference docs — they can go stale or simply be wrong; re-derive rather than cite when a decision rests on them.

### Structural or tuning?

Ask: *would tuning the obvious knob actually address this, or just mask it?*

| Signal | Likely structural | Likely tuning |
|---|---|---|
| Every comp fails identically | ✅ | |
| Failure happens at a consistent *place/time* regardless of stats | ✅ | |
| The thing that kills isn't the thing you'd blame (ambient swarm, not the boss) | ✅ | |
| Fixing it requires the same edit on every level | ✅ | |
| Outcomes spread across comps, some close | | ✅ |
| One specific unit/level is the outlier | | ✅ |
| The curve is right but shifted | | ✅ |

Structural problems get a mechanic or a layout change. Tuning problems get a number. Calling one the other is how a pass gets wasted.

---

## Lever hierarchy — pull in this order

Prefer the most surgical lever that can fix the problem. Each step down affects more of the game at once, so it costs more to get wrong:

1. **Level layout** (`config/level_N_layout.tres`) — geometry, gate placement/HP, lair position, deploy band, obstacles. *Per-level and surgical.* Also the main source of level **identity**, so use it deliberately: L1 open, L2 chokepoints, L3 encirclement. Layout is the first lever, not the last resort.
2. **Encounter config** (`config/stage_N_config.tres`) — swarm cap/batch/interval/escalation, `villain_hp_mult`. *Per-level.* Throughput and escalation shape the fight's pressure curve over time.
3. **Villain stats** (`scenes/villain/*.tscn`) — per-villain HP/damage/behavior knobs. *Affects one encounter.*
4. **Economy** (XP curve, gold rates, tier/mod costs, achievement thresholds) — *affects run-to-run pacing*, not a single fight. Change when the problem is "progress feels wrong", not "this fight is wrong."
5. **Hero base stats / boons** (`hero.gd HERO_STATS`, `scripts/boons.gd`) — **last resort.** Touches every level and every comp simultaneously, invalidating all prior results. A hero-stat change means re-verifying everything.

When you do reach for a lower lever, say so and say why the higher ones couldn't do it.

See `references/levers.md` for the concrete file-by-file knob map.

---

## Target shape, not maximum clear rate

The goal is never "every comp wins." A level a player replays many times shouldn't be free. Tune toward a *shape*:

- **A genuine coin-flip is the ideal**, not a failure. 50% with the villain nearly dead on losses is the target texture for a level meant to be replayed.
- **Losses should be near-misses.** "Died at 5% villain HP" is good design; "died in transit at 67% villain HP" is broken.
- **Comps should differentiate.** If every comp performs the same, the draft is a fake decision. If one comp dominates everything, the draft is solved. Both are bugs.
- **Some comps should be locked out** (e.g. no-tank). That's information for the player, not unfairness.
- **Variance is a feature** — but only when the player can see what tipped it. Uncontrolled variance the player can't read is just noise.

**The lane build needs fresh targets.** V1's numbers (full-run ~20-30%, L1 ~90-100%, L3 ~40%) were derived for a different structure and a different progression model — do not carry them over as if they still apply. When a pass needs targets, help the Designer *derive* them from the intended run pacing (how many attempts should unlocking hero #2 take? should L1 be solo-clearable at all?), and treat the answer as a Designer decision to be recorded in DECISIONS.md.

---

## Control your variables

A sweep that isn't controlled is worse than no sweep, because it produces confident-looking numbers that are quietly wrong. This has already bitten this project once: sweeps silently read `GameState.owned_mods` from whatever save file happened to be on the machine, so results rode on unrelated purchases.

Before trusting any run, pin and **state** these:

- Owned ability mods, ability tiers, stat upgrades (`owned_mods`, `owned_ability_tiers`, `stat_purchases`)
- Unlocked roster and party comp
- Banked XP / gold
- Fog state (persisted per level — stale fog from old geometry invalidates a run)
- Time scale, and level/run time caps
- Boon picks (or the RNG seed driving them)

Sweep at minimum two power states — a **zero-upgrade floor** and a **realistic loadout** — because the interesting question is usually "does progression rescue this comp?", not "does it clear at one arbitrary power level."

### Traps already discovered here

- **Probe ≠ sweep.** A single-level probe starting fresh at full HP at 6× tells you almost nothing about a chained run arriving depleted at 10×. Match the harness to the claim you want to make.
- **Time scale changes outcomes.** Higher sim speed resolves combat more harshly. Numbers are only comparable at equal scale.
- **Read the units.** "Avg survivor HP" has been raw HP, not a percentage — 159 means 159/216 (~74%), not 159%.
- **A too-short time cap manufactures losses.** Genuinely winnable long fights got counted as timeouts at a 90s cap; 150s was needed. If failures cluster right at the cap, suspect the cap first.

---

## Verification honesty

This is the discipline that matters most for trust, and this project has repeatedly drifted from it — BALANCE.md carries several "unverified" warning blocks from passes done by reasoning alone.

**Always state how a claim was established**, using these words precisely:

- **Verified in-engine** — you actually ran it and observed the result. Say what you ran.
- **Verified by inspection** — you traced the code path and reasoned it through. Legitimate, but weaker; say so.
- **Unverified** — you changed something and did not check it. Say this plainly and flag it in BALANCE.md.

Never let "should work" become "works" in a summary. If verification wasn't possible this pass, say *why* and recommend what to check before the numbers are trusted. An honest "not verified" is far more valuable than a confident claim that later turns out hollow — the Designer plans around what you tell him.

### Running things

Prefer automation, degrade gracefully:

1. **`godot-ai` MCP tools** when available — the project's intended path (CLAUDE.md). Use sparingly; it is token-hungry.
2. **Headless CLI** (`godot --headless …`) if a Godot binary is reachable.
3. **Hand the Designer a test plan** when neither is — concrete steps, what to watch, and exactly which numbers to report back. Then interpret what he reports. This is a first-class option, not a failure mode.

> **Current state:** the V1 sweep harness (`balance_sweep.gd`, `behavior_probe.gd`, `death_curve_probe.gd`) was **deleted** during the V1 removal. There is no working automated sweep for the lane build right now, and nothing in the lane build has ever been swept. Rebuilding a lane-shaped harness is planned work (Part C6). Until it exists, say so rather than implying sweep-grade confidence — and note that a lane's constrained geometry should make sweeps *less* RNG-dependent than V1's open field, which was a stated reason for the structural change.

---

## Reading the game as an experience, not a spreadsheet

Numbers tell you if it's winnable. They don't tell you if it's worth playing. Assess these separately, and be willing to say "this is balanced and still boring."

**Where fun actually comes from in this game** (auto-battler, one player verb, run-as-chain):

- **Decisions that matter.** Draft, deploy placement, and upgrade spending are the player's real agency. If a decision has a dominant answer, it isn't a decision — check whether comps and purchases genuinely diverge in outcome.
- **Legibility.** The player must be able to answer "why did I lose?" A run that fails for invisible reasons teaches nothing and reads as unfair. This is the most common fun-killer in autobattlers, because the player isn't executing moment to moment — comprehension *is* the gameplay.
- **Felt escalation.** Pressure should visibly build. If the last 30s feels like the first 30s, the fight is flat regardless of its clear rate.
- **Near-misses.** A loss should generate a story ("I almost had the lair"). Runs that die early and quietly are the worst outcome — worse than a loss that takes longer.
- **Progress on failure.** In a grind loop, a lost run must still bank something visible (gold, XP, career progress toward an unlock). Otherwise repetition reads as punishment rather than practice.
- **Mastery on replay.** Replaying a mapped level should feel like applying knowledge (fog memory, known gate positions), not re-walking a chore. If a replay is identical labor, the fog/knowledge system isn't paying rent.

**Fun failure modes to actively check for:**

| Symptom | Likely cause | Where to look |
|---|---|---|
| "Too easy" | No escalation felt; player out-scales the curve | Escalation rate, XP curve vs. fight length |
| "Boring" but winnable | Decisions have dominant answers | Comp/mod outcome spread |
| "Unfair" | Illegible deaths | What actually deals the damage; is it visible/telegraphed? |
| "Grindy" | Failure banks too little, or unlocks too slow | Gold/XP drip, achievement thresholds vs. real throughput |
| "Samey" | Levels differ by numbers, not by shape | Layout theses — do L1/L2/L3 demand different play? |
| Decided early | Snowball; first 10s determines outcome | Opening pressure, deploy exposure, cold-start power |

When the Designer says something feels off, translate it into a measurable claim and go test *that*, rather than tuning toward the adjective.

---

## Working a balance pass

1. **Pin the complaint.** Turn feel into a claim you can check. "Too easy" → *which* part: reaching the lair, the boss itself, or the whole run? Ask if unclear rather than guessing — you'll otherwise tune the wrong thing.
2. **Reproduce and instrument.** Get a trace with *where and when*, not just win/lose. The useful per-level diagnostics here: entry HP, time-to-villain-alert, peak swarm, kills, objectives, per-hero level and boons.
3. **Diagnose.** State the failure mode in one sentence. Decide structural vs. tuning.
4. **Choose the highest lever that works.** Change as little as possible. Change one thing at a time when you can — batched changes make attribution impossible.
5. **Re-verify.** Same controls, same time scale, or the comparison is meaningless.
6. **Report with before/after numbers**, and say honestly how each was established.
7. **Document.** BALANCE.md gets the before/after table and the reasoning; DECISIONS.md gets any design call the Designer made. Batch doc updates to session end (AI_Development_Guide).

### Flag, don't silently reconcile

When a requested change contradicts an earlier one, implement what was asked and **flag the collision explicitly** — don't quietly split the difference. This has come up already (a Designer stat table reversed a same-day WARDEN buff, collapsing a comp to ~0%). The Designer needs to know a tradeoff was made on his behalf; that's his call, not yours.

Likewise, when you notice something monetized or surfaced that doesn't actually work (a gold tier that buys no observable effect), raise it as a finding even if it's pre-existing and out of scope.

---

## Reporting

Lead with the diagnosis, not the data dump:

```
**Finding:** [failure mode in one sentence]
**Evidence:** [what you ran/observed — and how it was established]
**Cause:** [structural or tuning, and why]
**Recommendation:** [smallest change; which lever and why that one]
**Tradeoff / risk:** [what else this touches, what it invalidates]
**Needs a Designer call:** [any creative decision — or "none"]
```

Keep it tight. The Designer wants the shape of the problem and the decision in front of him, not a transcript.
