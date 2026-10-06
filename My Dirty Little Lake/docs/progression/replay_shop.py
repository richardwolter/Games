"""Replays Richard's logged shop runs through the sim: his purchases, at the second he made
them, whatever the sim's purse says, so the model's catch, carry and income can be laid
beside what the real run did. This is what the k_* constants in calibration.json are fitted
against. It prices nothing and writes no .tres.

    python docs/progression/replay_shop.py [k_name=value ...]

Run from the project root, after build_shop.py. Reads every log under
docs/progression/playtests/, writes docs/progression/replay-report/<run>.json, and prints
real against sim every five minutes. `k_name=value` overrides a stat for the run, for
trying a constant before it is written into calibration.json.

The sim's replay policy buys a node once, so every ranked track is unrolled here into a
chain of one-rank nodes (`net_width#1`, `net_width#2`, ...), each carrying that level's own
step. The model is otherwise exactly shop.json.
"""
import glob
import json
import os
import subprocess
import sys

ROOT = "."
SIM = os.path.expanduser("~/.claude/skills/incremental-progression/scripts/run_sim.js")
OUT = f"{ROOT}/docs/progression/replay-report"
config = json.load(open(f"{ROOT}/docs/progression/shop.json", encoding="utf8"))
for arg in sys.argv[1:]:
    name, value = arg.split("=")
    assert name in config["stats"], name
    config["stats"][name] = float(value)

unrolled = []
for n in config["nodes"]:
    for rank in range(n["ranks"]):
        unrolled.append({
            "id": f"{n['id']}#{rank + 1}", "tree": n["tree"], "group": n["group"],
            "name": f"{n['name']} {rank + 1}", "cost": n["cost"][rank],
            "parents": [f"{n['id']}#{rank}"] if rank else [],
            "effects": [{"stat": e["stat"], "add": e["add"][rank]} for e in n["effects"]],
            "tags": n.get("tags", []),
        })
config["nodes"] = unrolled
config["links"] = []
config["targets"] = {"clearMinutes": {}}


def read_run(path):
    rows = [json.loads(l) for l in open(path, encoding="utf8") if l.strip()]
    buys = [r for r in rows if r["kind"] == "purchase"]
    prog = [r for r in rows if r["kind"] == "progress"]
    return buys, prog


def at(samples, seconds, key):
    return min(samples, key=lambda s: abs(s[key] - seconds))


os.makedirs(OUT, exist_ok=True)
worst = 0.0
squares = []
for path in sorted(glob.glob(f"{ROOT}/docs/progression/playtests/*.log")):
    name = os.path.basename(path)[:-4]
    buys, prog = read_run(path)
    config["bots"] = [{"id": "replay", "policy": "replay", "thinkEvery": 1,
                       "schedule": [[b["t"], f"{b['id']}#{b['rank']}"] for b in buys]}]
    tmp = f"{OUT}/{name}.config.json"
    json.dump(config, open(tmp, "w", encoding="utf8"))
    subprocess.run(["node", SIM, tmp, "--out", f"{OUT}/{name}", "--quiet"], capture_output=True)
    os.remove(tmp)
    report = json.load(open(f"{OUT}/{name}/report.json", encoding="utf8"))
    log = report["logs"][0]
    real_end = next((p["t"] for p in prog if p["pieces_left"] == 0), prog[-1]["t"])
    sim_end = log.get("clearedAt")
    print(f"\n{name}: real clear {real_end / 60:.1f} min, sim {sim_end / 60:.1f} min" if sim_end
          else f"\n{name}: real clear {real_end / 60:.1f} min, sim never")
    print("min   cleared real/sim    earned real/sim     box real/sim")
    for m in range(5, int(real_end / 60) + 1, 5):
        p = at(prog, m * 60, "t")
        s = at(log["samples"], m * 60, "t")
        earned = p["sludge"] + sum(b["cost"] for b in buys if b["t"] <= p["t"])
        print(f"{m:3d}   {p['cleared']:6.3f} {s['cleared']:6.3f}   {earned:8d} {s['earned']:8.0f}   "
              f"{p['box']:5d} {s['pools'].get('box', 0):5.0f}")
        worst = max(worst, abs(p["cleared"] - s["cleared"]))
        squares.append((p["cleared"] - s["cleared"]) ** 2)
rms = (sum(squares) / len(squares)) ** 0.5
print(f"\nshare cleared, real against sim: worst gap {worst:.3f}, rms {rms:.4f}")
