"""Prices the Steam demo (2026-10-09): the shop model (build_shop.py's shop.json) with every
track cut to its demo cap (scripts/demo.gd CAPS), every level given a minute inside the demo
(DEMO_SCHEDULE: the last one bought at about LAST minutes, the tornado finale after it), and
the prices steered to those minutes pass by pass, the way price_shop.py steers the full game.

Writes docs/progression/demo/demo_prices.json and, with --write, the PRICES table in
scripts/demo.gd. The full game's .tres files are never touched.

Run from the project root:
    python docs/progression/build_shop.py
    python docs/progression/price_demo.py [passes] [--write]
The sim is the incremental-progression skill's run_sim.js; node must be on PATH.
"""
import json
import math
import os
import re
import subprocess
import sys

ROOT = "."
OUT = f"{ROOT}/docs/progression/demo"
SIM = os.path.expanduser("~/.claude/skills/incremental-progression/scripts/run_sim.js")
# The last level should land about here; the finale tornado and the thanks follow it.
LAST = 18.0
FIRST = 0.8
PULL = 0.8
BLEND = 0.6


def demo_caps():
    s = open(f"{ROOT}/scripts/demo.gd", encoding="utf8").read()
    body = re.search(r"const CAPS := \{(.*?)\n\}", s, re.S).group(1)
    return {k: int(v) for k, v in re.findall(r'&"(\w+)": (\d+)', body)}


def spread(n, first=FIRST, last=LAST):
    if n == 1:
        return [round((first + last) / 2, 1)]
    return [round(first + (last - first) * i / (n - 1), 1) for i in range(n)]


# Strength is the demo's one big moment and lands mid-demo; the extra boat and dog come early,
# so the idle layer is seen; the rest spread over the whole demo.
PINNED = {"net_strength": [8.0], "fleet": [3.0], "dog_count": [4.0], "dog_strength": [12.0],
          "boat_volley": [10.0]}


def schedule(key, n):
    if key in PINNED and len(PINNED[key]) == n:
        return PINNED[key]
    return spread(n)


def build(caps, prices):
    config = json.load(open(f"{ROOT}/docs/progression/shop.json", encoding="utf8"))
    nodes = []
    for n in config["nodes"]:
        cap = caps.get(n["id"], 0)
        if cap <= 0:
            continue
        base, mult = prices[n["id"]]
        n = dict(n)
        n["ranks"] = cap
        n["cost"] = [round(base * mult ** level, 1) for level in range(cap)]
        n["effects"] = [dict(e, add=e["add"][:cap]) for e in n["effects"]]
        n["schedule"] = schedule(n["id"], cap)
        nodes.append(n)
    config["nodes"] = nodes
    config["game"] = "My Dirty Little Lake (demo)"
    config["maxMinutes"] = 45
    config["bots"] = [{"id": "focused", "policy": "cheapest", "thinkEvery": 5}]
    config["targets"] = {}
    os.makedirs(OUT, exist_ok=True)
    json.dump(config, open(f"{OUT}/demo.json", "w", encoding="utf8"), indent=1)
    return config


def run():
    subprocess.run(["node", SIM, f"{OUT}/demo.json", "--bot", "focused", "--out", f"{OUT}/report", "--quiet"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    report = json.load(open(f"{OUT}/report/report.json", encoding="utf8"))
    return next(l for l in report["logs"] if l["bot"] == "focused")


def nice(x):
    for step in (1, 5, 10, 50, 100, 500, 1000):
        if x < step * 20:
            return max(step, round(x / step) * step)
    return round(x / 1000) * 1000


def fit(points):
    n = len(points)
    xs = [l for l, _ in points]
    ys = [math.log(w) for _, w in points]
    mx, my = sum(xs) / n, sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    if sxx <= 0:
        return None
    b = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sxx
    return math.exp(my - b * mx), math.exp(b)


def income_curve(log):
    peaks, top = [], 0.0
    for s in log["samples"]:
        top = max(top, s["income"])
        peaks.append((s["t"] / 60.0, top))
    return peaks


def income_at(peaks, minute):
    near = [inc for t, inc in peaks if abs(t - minute) <= 1.0]
    return sum(near) / len(near) if near else (peaks[-1][1] if peaks else 1.0)


# Seconds of income a level should cost at its own minute: brisk at the start, slower later.
GAP = [(0, 12), (10, 25), (18, 40)]


def gap_at(minute):
    for (m0, g0), (m1, g1) in zip(GAP, GAP[1:]):
        if minute <= m1:
            return g0 + (g1 - g0) * (minute - m0) / (m1 - m0)
    return GAP[-1][1]


def reprice(config, log, prices):
    # Priced off the income curve alone, not off when the bot happened to buy: income at the
    # level's minute times the gap there, fitted to the track's geometric ladder. Steering by
    # the bot's own purchase times oscillated pass to pass.
    peaks = income_curve(log)
    out = {}
    for n in config["nodes"]:
        points = [(level, max(income_at(peaks, n["schedule"][level]) * gap_at(n["schedule"][level]), 5.0))
                  for level in range(n["ranks"])]
        base, mult = prices[n["id"]]
        if len(points) == 1:
            base = base * (1 - BLEND) + points[0][1] * BLEND
        else:
            fb, fm = fit(points) or (base, mult)
            fm = min(max(fm, 1.05), 3.5)
            base = base * (1 - BLEND) + fb * BLEND
            mult = mult * (1 - BLEND) + fm * BLEND
        out[n["id"]] = [nice(base), round(mult, 2)]
    return out


def summary(config, log):
    last = max((p["t"] for p in log["purchases"]), default=0) / 60.0
    total = sum(len(n["cost"]) for n in config["nodes"])
    return last, len(log["purchases"]), total


def main():
    passes = next((int(a) for a in sys.argv[1:] if a.isdigit()), 10)
    caps = demo_caps()
    path = f"{OUT}/demo_prices.json"
    if os.path.exists(path):
        prices = json.load(open(path, encoding="utf8"))
    else:
        full = {n["id"]: (n["cost"][0], (n["cost"][1] / n["cost"][0]) if len(n["cost"]) > 1 else 1.5)
                for n in json.load(open(f"{ROOT}/docs/progression/shop.json", encoding="utf8"))["nodes"]}
        prices = {k: [round(v[0], 1), round(v[1], 2)] for k, v in full.items()}
    for i in range(passes):
        config = build(caps, prices)
        log = run()
        last, got, total = summary(config, log)
        print(f"pass {i}: {got}/{total} levels, last at {last:.1f} min")
        prices.update(reprice(config, log, prices))
    config = build(caps, prices)
    log = run()
    last, got, total = summary(config, log)
    print(f"final: {got}/{total} levels, last at {last:.1f} min")
    json.dump(prices, open(path, "w", encoding="utf8"), indent=1)
    for n in config["nodes"]:
        print(f"  {n['id']:14} {prices[n['id']][0]:>7g} x{prices[n['id']][1]:.2f}  "
              f"{' '.join(str(round(c)) for c in n['cost'])}")
    if "--write" in sys.argv:
        lines = "".join(f'\t&"{k}": [{prices[k][0]:g}, {prices[k][1]:g}],\n'
                        for k in caps if k in prices)
        s = open(f"{ROOT}/scripts/demo.gd", encoding="utf8", newline="").read()
        s = re.sub(r"const PRICES := \{.*?\}", "const PRICES := {\n" + lines + "}", s, count=1, flags=re.S)
        open(f"{ROOT}/scripts/demo.gd", "w", encoding="utf8", newline="").write(s)
        print("wrote scripts/demo.gd PRICES")


main()
