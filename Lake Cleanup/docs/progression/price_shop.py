"""Prices the shop's tracks to a schedule: every level of every track is given a minute of the run
it should be bought at (a track's levels spread evenly over the run up to LAST_BUY, first level
early, last level late), and at that minute it wants to cost income(t) x gap(t), the gap curve
in shop.json (brisk at the start, slower to the end), the income read off the focused bot's own
run. A track's prices are geometric (price_base x price_mult ^ level, see UpgradeTrack), so the
wanted costs are fitted to that shape by least squares in the log, blended towards from the
current numbers, and written back into resources/upgrades/*.tres.

Pricing by when the bot happened to buy (income x gap at its own purchase times) ran away on the
first try: a track the bot bought late was priced for late income and then bought later still,
and a cheap one earlier still. The schedule anchors every level to a minute the bot cannot move.

Run from the project root, after run_sim.js --bot focused --out docs/progression/shop-report:
    python docs/progression/price_shop.py [blend]

Haul (net_hold) and Hold (cargo) are one track twice (Richard, 2026-09-14) and are written the same.
"""
import json
import math
import re
import sys

ROOT = "."
config = json.load(open(f"{ROOT}/docs/progression/shop.json", encoding="utf8"))
report = json.load(open(f"{ROOT}/docs/progression/shop-report/report.json", encoding="utf8"))
log = next(l for l in report["logs"] if l["bot"] == "focused")
# Only the run up to the clear: after it the income is nothing, and a level scheduled past the
# clear would be priced for nothing, bought earlier, and clear the lake earlier still.
END = (log["clearedAt"] / 60.0) if log.get("clearedAt") else 1e9
samples = [(s["t"] / 60.0, s["income"]) for s in log["samples"] if s["t"] / 60.0 <= END]
curve = config["gapCurve"]
blend = float(sys.argv[1]) if len(sys.argv) > 1 else 0.6
PAIRED = {"net_hold": "hold", "cargo": "hold"}


def gap_at(minute):
    for (m0, g0), (m1, g1) in zip(curve, curve[1:]):
        if minute <= m1:
            return g0 + (g1 - g0) * (minute - m0) / (m1 - m0)
    return curve[-1][1]


def income_at(minute):
    # Past the clear, the income the run ended on: a level scheduled after the lake was cleared
    # is priced as if the run had gone on at that pace.
    if minute > END - 1.0:
        minute = END - 1.0
    near = [inc for t, inc in samples if abs(t - minute) <= 1.0]
    return sum(near) / len(near) if near else samples[-1][1]


def nice(x):
    for step in (1, 5, 10, 50, 100, 500, 1000):
        if x < step * 20:
            return max(step, round(x / step) * step)
    return round(x / 1000) * 1000


# The minute of the run each level should be bought at. A level the bot bought early is priced
# up by how early, one it bought late is priced down, one it never bought is cheapened a
# little; the fit below then keeps each track geometric. Steering each level to its minute
# rather than pricing it at income x gap outright: the value bot front-loads whatever is cheap
# for what it gives, so income x gap pricing off its own run had it max the big tracks by
# 18 minutes and sit on a plateau for the rest.
LAST_BUY = 48.0
PULL = 0.7      # how hard a level is pushed towards its minute each pass
bought = {}
for p in log["purchases"]:
    bought[(PAIRED.get(p["id"], p["id"]), p["rank"] - 1)] = (p["t"] / 60.0, p["cost"])
wants = {}
for n in config["nodes"]:
    key = PAIRED.get(n["id"], n["id"])
    if key in wants:
        continue
    ranks = n["ranks"]
    costs = n["cost"]
    for level in range(ranks):
        minute = LAST_BUY * (level + 0.5) / ranks
        if (key, level) in bought:
            at, paid = bought[(key, level)]
            factor = min(max((minute / max(at, 0.25)) ** PULL, 0.5), 2.0)
            want = paid * factor
        else:
            want = costs[level] * 0.85
        want = max(want, income_at(minute) * gap_at(minute) * 0.25, 5.0)
        wants.setdefault(key, []).append((level, want))


def fit(points):
    # log c = a + b * level, least squares over every level.
    if len(points) < 2:
        return None
    n = len(points)
    xs = [l for l, _ in points]
    ys = [math.log(w) for _, w in points]
    mx, my = sum(xs) / n, sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    if sxx <= 0:
        return None
    b = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sxx
    a = my - b * mx
    return math.exp(a), math.exp(b)


def tres_path(key):
    return f"{ROOT}/resources/upgrades/{key}.tres"


def read_price(key):
    s = open(tres_path(key), encoding="utf8").read()
    base = float(re.search(r"^price_base = (.+)$", s, re.M).group(1))
    mult = float(re.search(r"^price_mult = (.+)$", s, re.M).group(1))
    return base, mult


def write_price(key, base, mult):
    s = open(tres_path(key), encoding="utf8").read()
    s = re.sub(r"^price_base = .*$", f"price_base = {base:.1f}", s, flags=re.M)
    s = re.sub(r"^price_mult = .*$", f"price_mult = {mult:.2f}", s, flags=re.M)
    open(tres_path(key), "w", encoding="utf8").write(s)


changed = []
for key in sorted({PAIRED.get(n["id"], n["id"]) for n in config["nodes"]}):
    points = wants.get(key, [])
    fitted = fit(points)
    targets = ["net_hold", "cargo"] if key == "hold" else [key]
    base, mult = read_price(targets[0])
    if fitted is None:
        if len(points) == 1:
            level, want = points[0]
            new_base = want / mult ** level
            base = base * (1 - blend) + new_base * blend
        else:
            continue
    else:
        fb, fm = fitted
        # A single level's cost cannot fall as the level rises, and the ladder is kept gentle.
        fm = min(max(fm, 1.05), 2.5)
        base = base * (1 - blend) + fb * blend
        mult = mult * (1 - blend) + fm * blend
        # The schedule's own steer comes through the wants; a low blend only slows it.
    base = nice(base)
    mult = round(mult, 2)
    for t in targets:
        write_price(t, base, mult)
    changed.append(f"{key} {base:g} x{mult:.2f} ({len(points)} buys)")
print("; ".join(changed))
