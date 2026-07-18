# Semi-Secret Wars — Production

**Status:** Living Document (current state, updated as work progresses)

## Current Milestone

**Stage 3 (Mech Robot) + comprehensive balance sweep + Lone Wolf solo buff** — Complete, pending Designer review.
- **Stage 3 built (placeholder):** new villain (Mech Robot — stationary, melee-capable, periodic slow-zone AoE ability) and a hybrid Ranged/Brute minion swarm (50/50 mix). Verified in-engine: villain spawns, both minion types spawn, slow-zone ability fires and applies its movement/attack debuff. Stats are first-pass placeholders, not tuned. See [BALANCE.md](BALANCE.md).
- **Comprehensive automated sweep (186 runs):** solo + duo × LV 0–30 × Stage 1/2/3, each capped at 60 simulated seconds, run via a new in-engine test harness (`scenes/tools/balance_sweep.gd`), raw data in `BALANCE_SWEEP_RESULTS.json`. Found solo never won within the cap at any level on any stage; duo progression was coherent across all 3 stages (~LV 19–22 Stage 1, ~LV 15 Stage 2, ~LV 20–26 Stage 3).
- **Lone Wolf buff (solo wins now possible):** added a standing compensation buff for true 1-hero rosters (×1.8 HP / ×1.75 damage / −0.4s cooldown, mutually exclusive with the existing Synergy system so **duo balance is untouched**). Re-swept solo (93 runs): Stage 2 now wins consistently from LV 21. Stage 1 and Stage 3 still don't cross the win line within the 60s cap but trend hard toward one (villain down to 79%/85% damaged by LV 30, up from ~45%/31% pre-buff).
- **Open item for Designer:** Stage 1's Dark Mage (flees + teleports + resummons every 10s) resists pure stat buffs structurally — a lone hero's chase progress resets each teleport cycle, unlike Stage 2/3 villains that stand and fight. This means **solo can currently beat Stage 2 but not Stage 1**, the opposite of the intended difficulty curve, and since Stage 2 only unlocks after beating Stage 1, a solo player can't actually reach the stage they can win. Needs either a Stage-1-specific tweak (e.g. shorter resummon burst or teleport interval when solo) or a deliberate design call that solo isn't meant to clear Stage 1.

## Previous Milestone

**Balance pass: hero differentiation, synergy system, ability unlocks** — Complete, pending Designer approval.
- **Hero differentiation:** Thundaar (tank) and Artemis (DPS) now have distinct base stats and per-upgrade scaling instead of identical placeholder stats — see [BALANCE.md](BALANCE.md). Builds stay flexible (either hero can be leaned tankier or glassier via upgrade choice).
- **Synergy system:** both heroes alive within 200px grants +15% damage, −0.3s ability cooldown, +25% XP — makes the duo meaningfully stronger than either hero solo. Verified in-engine: LV 20 synergy duo cleared Stage 1 at near-full HP in ~26s (5× sim).
- **Ability unlocks:** LV 15 grants passive upgrades to the existing abilities (Stomp stuns, Clone hits harder); LV 20 unlocks a second active ability per hero (Thundaar's Shockwave, Artemis's Dash). Gives the player a visible power spike roughly every 2-3 runs instead of pure stat-line growth.
- **XP economy + swarm density retuned:** kill/capture XP up, upgrade costs down, swarm caps/escalation raised so early runs feel more "swarmy." Verified in-engine: solo LV 8 Thundaar now wins Stage 1 (razor-thin, 6/180 HP left) rather than the old narrow-loss baseline — the floor moved up; LV 25 duo clears Stage 2 comfortably with visible tank/DPS HP asymmetry.
- **Not yet re-verified:** LV 12–20 range (the gap between the LV 8 solo floor and the two confirmed comfortable-win points); minion variety (ranged/brute types) from the plan wasn't implemented this pass.
- **Swarmier spawns (2026-07-15):** Designer feedback that the swarm should feel denser — spawn throughput/caps raised ×1.5 across both stages, minion damage/XP cut ÷1.5 to hold the chip-damage and XP budgets constant. Re-verified in-engine: LV 20 synergy duo still clears Stage 1 comfortably (170/220, 114/145 final HP), matching the pre-existing gate within noise while active-minion/kill counts ran markedly higher. See [BALANCE.md](BALANCE.md).

## Previous Milestone

**Stage 2 Unlocked banner + HUD polish** — Complete, pending Designer approval.
- **Stage 2 Unlocked banner:** results screen shows a gold "STAGE 2 UNLOCKED!" line the moment Stage 1 is beaten for the first time (not on repeat wins). Verified in-engine via `game_eval`: fires on the unlock transition, stays hidden on a subsequent win with the flag already set.
- **HUD polish:** objective tracker gained a fill bar and a "CONTESTED" state (hostile actively blocking capture, distinct from just being nearby); hero panels gained a cooldown fill bar (0 = just used, full = ready) alongside the existing text, sized per hero's real ability cooldown (Stomp 3.5s, Clone 8.0s). Verified in-engine: bar nodes wired correctly, fraction math checked at mid-cooldown (0.5) and ready (1.0).

## Previous Milestone

**Deployment phase, hero abilities, fog of war, art pass** — Complete, pending Designer approval.
- **Deployment phase:** battle no longer auto-starts the party; the player sees a legal deploy zone (green) and minion-spawner standoff rings (red) and clicks to place the party before the swarm begins. Verified in-engine (legal-point placement spawns the party exactly there; swarm holds until deployed).
- **Hero abilities:** Thundaar auto-casts Stomp (AoE damage + knockback), Artemis auto-casts Clone (taunting stand-in). Verified firing in-engine (cooldown UI, Clone spawn/taunt); damage/cooldown values are a first pass, not yet tuned against the stage gates — see [BALANCE.md](BALANCE.md).
- **Fog of war:** explored-stays-revealed terrain fog + live hero-vision-bubble unit hiding, visual only (combat/targeting untouched). Verified rendering and revealing correctly in-engine.
- **Art pass:** Thundaar and Minion now use real sprites; obstacles render as Mountain/Forest art; field shapes went to a hand-inked notebook style (transparent fill + ink outline, cross-hatched lake).
- **Caught and fixed a balance regression:** an in-progress swarm-size experiment had left Stage 1/2 spawn throughput at ~22× the verified balance pass, wiping an over-leveled party instantly. Rescaled back to the original verified throughput (see BALANCE.md) — LV10/LV25 gates should be re-run through the full instrumented pass before trusting them exactly, since minion HP/damage/XP were also halved in the art pass.

## Completed Milestones

1. Project setup & scope alignment
2. Placeholder battlefield (isometric, zoom camera)
3. Hero characters (Thundaar + Artemis)
4. Combat system (Combatant base, HP, attacks, health bars)
5. Win/Lose conditions (farm swarm, defeat villain, placeholder banners)
6. Objectives (hold-to-capture, XP bonus)
7. Progression (persistent upgrades, post-run screen)
8. Minion AI (intercept targeting, field-wide hunt)
9. Battlefield reshape (Stage 1 open field — approved 2026-07-15)
10. Poison Lake hazard + steering hardening (approved 2026-07-15)
11. Balance & Pacing: 2-Level System (Stage 1 + Stage 2 Berserker, expandable architecture)
12. Stage-level balance targets (LV 10 / LV 25 gates) + hero-panel camera focus
13. Prep-menu stage select (progression unlock) + freed-follow crash fix
14. Deployment phase, hero abilities (Stomp/Clone), fog of war, art pass
15. Stage 2 Unlocked banner + HUD polish (objective tracker, hero cooldown bars)

## Demo Scope

**Two-run progression loop:** Stage 1 vs. Dark Mage (run 1–4), Stage 2 vs. Berserker (run 5+). Hero roster: Thundaar + Artemis. Auto-battle loop: roster select → assign priorities → battle → farm XP → upgrade → repeat. Progression: base heroes lose Stage 1 first ~3 runs, beat it after ~4 runs of farming; Stage 2 takes ~5–7 runs to overcome. 2D isometric, player zoom. Core gameplay loop proven; Stage 3+ can be added via config only.

## Next Candidates

- Optional: additional villain type or minion variant for Stage 3 prototype

## Production Notes

- Engine: Godot 4.7-stable, GL Compatibility
- Main scene: `scenes/prep/prep_menu.tscn` (prep → `scenes/battlefield/battlefield.tscn`)
- Display: 1920×1080, fullscreen, PC target
- Tools: `godot-ai` MCP connected for automation
