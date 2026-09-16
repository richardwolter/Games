"""Prices every scheduled node at the focused bot's income at its `at` minute times the gap the
buy curve wants there: cost = income(at) x gap(at).

Run from the project root, after run_sim.js --out docs/progression/tree-report:
    python docs/progression/price_by_income.py

Why not price_to_schedule.js alone: on this tree it oscillates (the clear moved 68-88 minutes from
one iteration to the next) because every price it moves changes when the lake clears. A player
buying one thing after another waits cost / income for each, so pricing to income times the gap is
the gap curve itself, and a few passes of build-free re-pricing settle it. Nodes marked `fixedCost`
keep their price. Nodes without `at` (the pigeons) take `priceAt` instead, if they have one.
Utility nodes (the dog's, the pigeons) are priced at no more than 75 s of income, see below.
"""
import json
import sys

PATH = "docs/progression/lake-tree.json"
config = json.load(open(PATH, encoding="utf8"))
report = json.load(open("docs/progression/tree-report/report.json", encoding="utf8"))
log = next(l for l in report["logs"] if l["bot"] == "focused")
samples = [(s["t"] / 60.0, s["income"]) for s in log["samples"]]
curve = config["gapCurve"]
# Nodes scheduled from this minute on carry the spend-down adjustment.
SPEND_FROM = 35.0
# `spend` as the first argument runs the spend-down step alone, at full strength: the income
# pricing and the spend-down pull against each other, so the loop finishes with a few of these.
SPEND_ONLY = len(sys.argv) > 1 and sys.argv[1] == "spend"
blend = 1.0 if SPEND_ONLY else (float(sys.argv[1]) if len(sys.argv) > 1 else 0.6)  # how far to move per pass


def gap_at(minute):
    for (m0, g0), (m1, g1) in zip(curve, curve[1:]):
        if minute <= m1:
            return g0 + (g1 - g0) * (minute - m0) / (m1 - m0)
    return curve[-1][1]


def income_at(minute):
    # Averaged over the minute either side: the sampled income jumps at every purchase.
    near = [inc for t, inc in samples if abs(t - minute) <= 1.0]
    return sum(near) / len(near) if near else samples[-1][1]


def nice(x):
    for step in (10, 50, 100, 500, 1000):
        if x < step * 20:
            return max(step, round(x / step) * step)
    return round(x / 1000) * 1000


for n in config["nodes"]:
    if n.get("fixedCost") or SPEND_ONLY:
        continue
    at = n.get("at", n.get("priceAt"))
    if at is None:
        continue
    want = income_at(at) * gap_at(at)
    if "utility" in n.get("tags", []):
        # A helper earns little of its own, so a player (and the bot's utility rule, 90 s of
        # income) buys it when it is cheap against income, not when it pays back.
        want = income_at(at) * min(gap_at(at), 75.0)
    n["cost"] = nice(n["cost"] * (1 - blend) + want * blend)
# Late in the run income falls as the lake empties, and income x gap would make the last nodes
# cheap exactly when they should feel like the big ones. Along the schedule, a node costs at least
# FLOOR of the dearest before it (a helper, HELPER_FLOOR).
FLOOR, HELPER_FLOOR = 0.7, 0.35
dearest = 0.0
for n in sorted(config["nodes"], key=lambda n: n.get("at", n.get("priceAt", 0.0))):
    if not n.get("fixedCost") and n.get("at", n.get("priceAt")) is not None:
        least = dearest * (HELPER_FLOOR if "utility" in n.get("tags", []) else FLOOR)
        n["cost"] = nice(max(n["cost"], least))
    if "utility" not in n.get("tags", []):
        dearest = max(dearest, n["cost"])
# Spend-down (third pass): what the focused bot is left holding at the clear, plus the box it has
# not sold, less what it never bought, goes onto the late nodes, so the last buy uses up the run.
end_box = log["samples"][-1]["pools"].get("box", 0)
bought = {p["id"] for p in log["purchases"]}
unbought = sum(n["cost"] for n in config["nodes"] if n["id"] not in bought)
surplus = log["end"]["money"] + end_box * 22.0 - unbought - 0.02 * log["end"]["earned"]
late = [n for n in config["nodes"] if not n.get("fixedCost") and n.get("at", n.get("priceAt", 0)) >= SPEND_FROM]
late_cost = sum(n["cost"] for n in late)
if late and late_cost > 0:
    factor = min(max(1.0 + blend * surplus / late_cost, 0.7), 1.4)
    for n in late:
        n["cost"] = nice(n["cost"] * factor)
    print(f"spend-down: surplus {surplus:,.0f}, late nodes x{factor:.2f}")
json.dump(config, open(PATH, "w", encoding="utf8"), indent=1)
print(f"priced; total {sum(n['cost'] for n in config['nodes']):,}")
