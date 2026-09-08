

---

## Follow-up 4 (2026-09-06) — net_width / net_hold: the quadratic-area mechanism

### Changed
- `resources/upgrades/net_width.tres`: price_mult 1.52 → 1.6 (curve/value fields untouched from
  this morning's earlier pass)
- `resources/upgrades/net_hold.tres`: price_mult 1.52 → 1.55 (curve/value fields untouched)

### Hypothesis
Reported after further play: still too powerful too fast, specifically from net width and
net hold — despite this morning's curve_b/curve_c softening on all four net tracks.

Traced the actual mechanism in `net.gd`/`lake_grid.gd` before touching any more numbers
(previous passes today reasoned from formulas alone; this one checked the code they act on).
Two things width/hold have that net_range and reel don't:

1. **`net_width`'s value becomes a radius, and catchable tiles are tested as
   `dx² + dy² ≤ radius²`** (a circle-area check) — so a curve that looks linear-ish in level
   (`curve_a + curve_b*L + curve_c*L²`) produces **quadratic growth in the actual money-per-
   cast power** (swept tile area), not the roughly-linear growth the curve shape suggests.
   Lowering `curve_b` this morning slowed the *value* number, but the felt power is that
   value squared — so the real slowdown was smaller than intended.
2. **`net_hold` is a hard additive cap on pieces-per-cast, no formula multiplies it with
   width** — but once width's swept area exceeds hold, hold becomes the binding ceiling. That
   means buying whichever of the two is currently NOT the bottleneck banks free value, and
   buying the other one then unlocks it all at once — an emergent compounding return neither
   track's own (identical: price_base 22, price_mult 1.52) cost curve accounts for.

Lever chosen: `price_mult` specifically (not another curve_b/curve_c cut, to avoid re-opening
this morning's already-made value-curve decision) — slows how fast the pair gets bought
without changing the power ceiling already tuned today. Sized asymmetrically because
`net_hold`'s 22-level cap makes it far more sensitive to the same multiplier than
`net_width`'s 13: a flat 1.52→1.6 for both would have roughly tripled hold's cost-to-max.
Computed with `tools/balance_calc.py`, not by hand:
- `net_width` total cost to max: 9,738.8 → 16,476.5 (+69%)
- `net_hold` total cost to max: 423,579.5 → 615,643.3 (+45%)
- Early levels (1–5) barely move for either track — the slowdown is backloaded, aimed at
  "too fast to reach strong," not "too strong at the start."

### Observed
Not yet played — this is today's newest, most-targeted hypothesis on this specific
complaint; needs its own playtest before anything stacks on top of it.

### Decision
Pending playtest. If still too fast, the next lever is probably pushing `price_mult` further
on these same two fields (the mechanism, not the specific numbers, is what's been verified
here) rather than touching curve_a/b/c again, since that would re-litigate this morning's
value-curve pass on top of an unverified one.

---

## Open item (not acted on) — "money made should exactly match total upgrade costs"

Requested: total achievable income over a full playthrough should land exactly on total
cost-to-max across every track, no leftover, nothing unreachable.

Not attempted this pass — flagging why rather than guessing at it:

1. **"Exactly," literally, isn't a sound target.** Any player who misses pieces, plays
   imperfectly, or skips birds/charms earns less than the theoretical maximum — an "exact"
   design has no slack for that and goes negative (something unreachable) for the first
   player who isn't perfect. A **band** (e.g. total income lands within ~90–110% of total
   upgrade cost for a normal-skill full clear) is achievable; an exact equality isn't a
   meaningful target for a game with player-skill variance.
2. **Computing the achievable-income side requires a fact this pass didn't gather**: the
   actual per-piece payout and rubbish-spawn distribution live in `lake.gd` (not read in
   detail this pass — it's the 100KB file). Total cost-to-max across every current track is
   known (~943,600 after this pass's two changes, computed via `balance_calc.py`), but total
   achievable income isn't, without reading that logic.

This is a separate, sizable hypothesis from the width/hold one above — per this session's own
new rule, it shouldn't stack on top of an unverified change in the same pass. Next step, if
wanted: extend `tools/balance_calc.py` (or a new script) to also model total achievable
income from `lake.gd`'s actual formulas, so "does total income roughly match total upgrade
cost" becomes a real, checkable number instead of a guess — as a separate pass, after this
one's been played.
