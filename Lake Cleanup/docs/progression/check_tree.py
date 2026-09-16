"""Checks the tree report against Richard's pacing rules from 2026-09-14 that run_sim.js has no check for.

Run from the project root, after run_sim.js --out docs/progression/tree-report:
    python docs/progression/check_tree.py

- Buys: the gap between purchases follows lake-tree.json's `gapCurve` (brisk at the start, slower
  towards the end). Reported per ten-minute phase as the median gap against the curve's value;
  within half to double the curve passes.
- Box: the boats nearly keep up. Ferry capacity at least 0.8 of the catch, and what sits in the
  box could be carried off within 120 s of ferry work (the "leave it two minutes and the box
  empties" rule), on at least 80% of samples.
- Dog: bought right after the first ferry, before any net node (third pass, 2026-09-14).
- Spend-down (third pass): at the clear, money in hand plus the box's value, less what the nodes
  still unbought cost, is within 5% of everything earned (Richard ended his run on 16,426 unspent).
- The end of the run: what is in the box when the lake clears sells within a minute of ferry work.
"""
import json
import statistics

config = json.load(open("docs/progression/lake-tree.json", encoding="utf8"))
report = json.load(open("docs/progression/tree-report/report.json", encoding="utf8"))
curve = config["gapCurve"]


def gap_at(minute):
    for (m0, g0), (m1, g1) in zip(curve, curve[1:]):
        if minute <= m1:
            return g0 + (g1 - g0) * (minute - m0) / (m1 - m0)
    return curve[-1][1]


failed = 0
config_nodes = {n["id"]: n for n in config["nodes"]}
# What a piece in the box is worth, near enough: flat pay plus the mean filth pay across tiers.
BOX_VALUE = 22.0


def verdict(ok, text):
    global failed
    if not ok:
        failed += 1
    print(("PASS " if ok else "FAIL ") + text)


seen = set()
for log in report["logs"]:
    bot = log["bot"]
    if bot in seen:
        continue
    seen.add(bot)
    buys = sorted(p["t"] for p in log["purchases"])
    clear = (log.get("clearedAt") or buys[-1]) / 60.0
    print(f"\n== {bot}: {len(buys)} buys, clear {clear:.1f} min")
    phases = {}
    for a, b in zip(buys, buys[1:]):
        phases.setdefault(int(a // 600) * 10, []).append(b - a)
    rows = []
    for phase in sorted(phases):
        med = statistics.median(phases[phase])
        want = gap_at(phase + 5)
        rows.append((phase, med, want, len(phases[phase])))
    if bot == "focused":
        bad = [r for r in rows if not (0.5 * r[2] <= r[1] <= 2.0 * r[2])]
        for phase, med, want, n in rows:
            print(f"   {phase:3d}-{phase + 10:<3d} min: median gap {med:5.0f} s (curve {want:3.0f} s), {n} buys")
        verdict(not bad, "buy gaps follow the curve within 0.5-2x" + ("" if not bad else f"  (off: {[r[0] for r in bad]})"))
    lag = drain = n = 0
    worst = (0, 0)
    for s in log["samples"]:
        up = s["rates"].get("catch", 0) + s["rates"].get("dog", 0) + s["rates"].get("dog_beach", 0)
        cap = s["caps"].get("ferry", 0)
        if up <= 0 or cap <= 0:
            continue
        n += 1
        if cap >= 0.8 * up:
            lag += 1
        box = s["pools"].get("box", 0)
        if box <= cap * 120:
            drain += 1
        elif box / cap > worst[0]:
            worst = (box / cap, s["t"] / 60)
    if n:
        verdict(lag / n >= 0.8, f"ferries carry at least 0.8x the catch on {100 * lag / n:.0f}% of samples")
        verdict(drain / n >= 0.8, f"the box empties within 2 min of ferry work on {100 * drain / n:.0f}% of samples"
                + (f"  (worst {worst[0]:.0f} s at {worst[1]:.1f} min)" if worst[0] else ""))
    end = log["samples"][-1]
    cap = end["caps"].get("ferry", 0)
    box = end["pools"].get("box", 0)
    verdict(cap > 0 and box <= cap * 60, f"the box sells within a minute of the clear ({box:.0f} pieces, {box / max(cap, 0.001):.0f} s)")
    if bot == "focused":
        order = [p["id"] for p in sorted(log["purchases"], key=lambda p: p["t"])]
        net_first = next((i for i, id in enumerate(order) if config_nodes[id]["tree"] == "net"), 99)
        verdict("dog" in order and order.index("dog") < net_first, f"dog bought before any net node (at {order.index('dog') + 1 if 'dog' in order else 'never'})")
        unbought = sum(n["cost"] for n in config["nodes"] if n["id"] not in order)
        surplus = log["end"]["money"] + box * BOX_VALUE - unbought
        share = surplus / max(log["end"]["earned"], 1)
        verdict(-0.02 <= share <= 0.05, f"spend-down: {surplus:,.0f} left at the clear, {100 * share:.1f}% of {log['end']['earned']:,.0f} earned"
                + f" (money {log['end']['money']:,.0f}, box {box * BOX_VALUE:,.0f}, unbought {unbought:,.0f})")

print(f"\n{failed} failed")
