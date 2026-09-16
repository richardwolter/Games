"""Replays a tree playtest through the sim and compares the lake it clears against the real run.

Run from the project root:
    python docs/progression/replay_playtest.py [session start, e.g. 2026-09-14T12:36] [catch scale] [ferry scale]

Reads user://tree_playtest.log (the Godot user dir), takes the purchases of the run that started at
that time, has the sim buy the same nodes at the same seconds (policy `replay`), and prints cleared
share and box, real against model, every three minutes. Used to fit `k_catch_scale` and `k_ferry_scale`.
"""
import json
import os
import subprocess
import sys

LOG = os.path.expandvars(r"%APPDATA%\Godot\app_userdata\Lake Cleanup\tree_playtest.log")
START = sys.argv[1] if len(sys.argv) > 1 else "2026-09-14T12:36"
rows = [json.loads(l) for l in open(LOG, encoding="utf8") if l.strip()]
begin = next(i for i, r in enumerate(rows) if r["kind"] == "session" and r.get("started") == "new" and r["at"].startswith(START))
run = []
for r in rows[begin + 1:]:
    if r["kind"] == "session" and r.get("started") == "new":
        break
    run.append(r)
schedule = [[r["t"], r["id"]] for r in run if r["kind"] == "purchase"]
progress = [r for r in run if r["kind"] == "progress"]

config = json.load(open("docs/progression/lake-tree.json", encoding="utf8"))
# Trial calibration, without rebuilding the tree the run was played on.
config["stats"].setdefault("k_catch_scale", 1.0)
config["stats"].setdefault("k_ferry_scale", 1.0)
if len(sys.argv) > 2:
    config["stats"]["k_catch_scale"] = float(sys.argv[2])
if len(sys.argv) > 3:
    config["stats"]["k_ferry_scale"] = float(sys.argv[3])
for d in config["derived"]:
    if d[0] == "catch_rate" and "k_catch_scale" not in d[1]:
        d[1] = f"k_catch_scale * ({d[1]})"
    if d[0] == "ferry_rate" and "k_ferry_scale" not in d[1]:
        d[1] = f"k_ferry_scale * ({d[1]})"
config["bots"] = [{"id": "replay", "policy": "replay", "schedule": schedule, "thinkEvery": 1}]
os.makedirs("tools/replay", exist_ok=True)
json.dump(config, open("tools/replay/config.json", "w", encoding="utf8"))
sim = os.path.expanduser("~/.claude/skills/incremental-progression/scripts/run_sim.js")
subprocess.run(["node", sim, "tools/replay/config.json", "--out", "tools/replay", "--quiet"], capture_output=True)
log = json.load(open("tools/replay/report.json", encoding="utf8"))["logs"][0]
samples = log["samples"]


def at(minute):
    best = samples[0]
    for s in samples:
        if s["t"] <= minute * 60:
            best = s
    return best


err = 0.0
n = 0
print(" min | real cleared  box | model cleared  box")
for p in progress[::6]:
    s = at(p["t"] / 60)
    print(f"{p['t'] / 60:4.0f} | {p['cleared']:.3f} {p['box']:6d} | {s['cleared']:.3f} {s['pools'].get('box', 0):6.0f}")
    if p["cleared"] < 0.999:
        err += (p["cleared"] - s["cleared"]) ** 2
        n += 1
real_clear = next((p["t"] / 60 for p in progress if p["cleared"] >= 0.995), None)
print(f"real clear {real_clear} min, model clear {None if not log['clearedAt'] else round(log['clearedAt'] / 60, 1)} min, rms cleared {((err / max(n, 1)) ** 0.5):.3f}")
