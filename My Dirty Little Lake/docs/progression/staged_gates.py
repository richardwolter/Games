"""Sweeps the staged shop's board gates (2026-10-25, the mdll-staged-shop test branch).

Builds the shop model with --gates G1,G2,G3 (build_shop.py), runs the focused bot, and reads off
when each board opened: the second the levels bought reached that board's threshold. The prices
are frozen, so only the gates move. Run from the project root:

    python docs/progression/staged_gates.py 4,6,8 6,6,8 ...   one line per gate set
    python docs/progression/staged_gates.py --bot cheapest 9,7,9

Prints, per gate set: when NET, DOGS and LUCK open, the clear time, the box's peak, the first
Strength buy, and the longest gap between buys in the first ten minutes.
"""
import json
import subprocess
import sys
from pathlib import Path

SIM = Path.home() / ".claude/skills/incremental-progression/scripts/run_sim.js"
WORK = Path("tools/sim_staged")
ORDER = ["net", "dog", "luck"]


def run(gates, bot):
    WORK.mkdir(parents=True, exist_ok=True)
    config = WORK / "shop_staged.json"
    subprocess.run([sys.executable, "docs/progression/build_shop.py", "--gates", gates, "--out", str(config)],
                   check=True, capture_output=True)
    out = WORK / f"report_{bot}"
    subprocess.run(["node", str(SIM), str(config), "--bot", bot, "--out", str(out), "--quiet"],
                   capture_output=True)
    report = json.load(open(out / "report.json", encoding="utf8"))
    log, rep = report["logs"][0], report["reports"][0]
    thresholds, total = [], 0
    for g in gates.split(","):
        total += int(g)
        thresholds.append(total)
    buys = log["purchases"]
    opens = {}
    for board, at in zip(ORDER, thresholds):
        opens[board] = buys[at - 1]["t"] / 60 if len(buys) >= at else None
    box = max((s["pools"].get("box") or 0) for s in log["samples"])
    strength = next((p["t"] / 60 for p in buys if p["id"] == "net_strength"), None)
    early = [p["t"] for p in buys if p["t"] <= 600]
    gaps = [b - a for a, b in zip([0] + early, early)]
    first = {}
    for p in buys:
        first.setdefault(p["tree"], p["t"] / 60)
    return {
        "gates": gates, "opens": opens, "first": first, "clear": rep["clearMinutes"],
        "box": box, "strength": strength, "gap10": max(gaps) if gaps else None,
        "buys": len(buys), "cleared": rep["endCleared"],
    }


def fmt(m):
    return "  -  " if m is None else f"{m:5.1f}"


def main():
    args = sys.argv[1:]
    bot = "focused"
    if args[:1] == ["--bot"]:
        bot = args[1]
        args = args[2:]
    print(f"bot {bot}: gates | opens net dog luck (min) | first buy net dog luck | clear | box | Strength | longest gap <10 min")
    for gates in args:
        r = run(gates, bot)
        o, f = r["opens"], r["first"]
        print(f"{r['gates']:>9} | {fmt(o['net'])} {fmt(o['dog'])} {fmt(o['luck'])} | "
              f"{fmt(f.get('net'))} {fmt(f.get('dog'))} {fmt(f.get('luck'))} | {fmt(r['clear'])} | "
              f"{r['box']:6.0f} | {fmt(r['strength'])} | {r['gap10']:.0f} s"
              + ("" if r["clear"] else f"  (cleared {r['cleared']:.1%})"))


main()
