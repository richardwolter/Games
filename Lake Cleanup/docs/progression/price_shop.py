"""Prices the shop's tracks to a schedule: every level of every track is given a minute of the run
it should be bought at (build_shop.py's SCHEDULE, carried in shop.json as each node's
"schedule"), and at that minute it wants to cost income(t) x gap(t), the gap curve
in shop.json (brisk at the start, slower to the end), the income read off the focused bot's own
run. A track's prices are geometric (price_base x price_mult ^ level, see UpgradeTrack), so the
wanted costs are fitted to that shape by least squares in the log, blended towards from the
current numbers, and written back into resources/upgrades/*.tres.

Pricing by when the bot happened to buy (income x gap at its own purchase times) ran away on the
first try: a track the bot bought late was priced for late income and then bought later still,
and a cheap one earlier still. The schedule anchors every level to a minute the bot cannot move.

Run from the project root, after run_sim.js --bot focused --out docs/progression/shop-report:
    python docs/progression/price_shop.py [blend]

Haul (net_hold) and Hold (cargo) are two tracks again (Richard, 2026-09-18): Hold runs ahead and
cheap, Haul trails it. BASE_MOST holds the prices Richard set by hand.
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
peaks, top = [], 0.0
for t, inc in samples:
    top = max(top, inc)
    peaks.append((t, top))
curve = config["gapCurve"]
blend = float(sys.argv[1]) if len(sys.argv) > 1 else 0.6
PAIRED = {}
# Richard, 2026-09-14: the first extra ferry costs 200 at most. 2026-09-18: the boats are
# forgiving early, so Hold and Sailing start cheap and their ladders take up the difference.
BASE_MOST = {"fleet": 200.0, "cargo": 40.0, "boat_speed": 60.0}
# Priced by Richard off his logged run of 2026-09-18 (docs/progression/playtests/), not by
# the fit, and left alone by this script: Strength from 3500 with its top kept where he maxed
# it at 40 minutes; Range cheap to start and dear to finish (the tier-0 water in reach ran dry
# at minutes 5 to 15 on Range 2 to 5); Pigeons cheap and early (he netted 196 birds and did
# not buy a level until minute 50); the Pack cheap and the rest of the dogs dearer (he bought
# eleven dog levels in one visit at minute 21). Catch's ladder was eased by hand on
# 2026-09-19 (1.82 to 1.80, top level 66k to 61k) and is pinned here so a re-run cannot
# put it back.
HAND = {"net_strength", "net_range", "bird_worth", "dog_count", "dog_fetch", "dog_wait",
        "dog_strength", "net_hold"}


def gap_at(minute):
    for (m0, g0), (m1, g1) in zip(curve, curve[1:]):
        if minute <= m1:
            return g0 + (g1 - g0) * (minute - m0) / (m1 - m0)
    return curve[-1][1]


def income_at(minute):
    # Past the clear, the income the run ended on: a level scheduled after the lake was cleared
    # is priced as if the run had gone on at that pace.
    # Read off the running peak, not the sample: income falls away over the last stretch as the
    # lake empties, and a late level priced off that tail came out cheap, was bought early, and
    # cleared the lake earlier still (the clear sat at 50 minutes whatever the schedule said).
    if minute > END - 1.0:
        minute = END - 1.0
    near = [inc for t, inc in peaks if abs(t - minute) <= 1.0]
    return sum(near) / len(near) if near else peaks[-1][1]


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
PULL = 0.7
MOST_GAPS = 6.0      # how hard a level is pushed towards its minute each pass
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
        minute = n["schedule"][level]
        if (key, level) in bought:
            at, paid = bought[(key, level)]
            factor = min(max((minute / max(at, 0.25)) ** PULL, 0.5), 2.0)
            want = paid * factor
        elif minute < END - 8.0:
            want = costs[level] * 0.85
        else:
            # Never bought, but scheduled for the last stretch: the run ended first, which is
            # not the price's fault. Cheapened with the rest, the tops of the long tracks
            # dragged their whole ladders flat (Reel sat at x1.17) and were bought early.
            want = costs[level]
        # Held between a quarter of a gap's income and MOST_GAPS of them at its own minute. The
        # ceiling is what stops a late level running away: priced past what the run can earn it
        # is never bought, the water in reach empties, and the next pass prices off a dead run.
        pace = income_at(minute) * gap_at(minute)
        want = min(max(want, pace * 0.25, 5.0), max(pace * MOST_GAPS, 5.0))
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


print(f"clear {END:.1f} min" if END < 1e8 else "clear never")
changed = []
for key in sorted({PAIRED.get(n["id"], n["id"]) for n in config["nodes"]}):
    if key in HAND:
        continue
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
    if key in BASE_MOST and base > BASE_MOST[key]:
        # The base is held and the ladder takes up the difference, so the last level still
        # lands where the fit put it.
        if fitted is not None and len(points) > 1:
            top = base * mult ** (len(points) - 1)
            mult = min((top / BASE_MOST[key]) ** (1.0 / (len(points) - 1)), 2.5)
        base = BASE_MOST[key]
    base = nice(base)
    mult = round(mult, 2)
    for t in targets:
        write_price(t, base, mult)
    changed.append(f"{key} {base:g} x{mult:.2f} ({len(points)} buys)")
print("; ".join(changed))
