"""Reads the player's playtest log (PlayLog, user://shop_playtest.log) and prints what a
balance pass needs: when each track was bought, Strength's minutes, Waiting against the
fleet's capacity, the clear curve, income, cast cadence.

    python docs/progression/read_playtest.py [log] [run]
`run` counts "new" sessions from the end: 1 is the latest new game (the default), 2 the one
before. A run is every line from its "new" session line to the next "new" one, so a run
played over several sittings reads as one.
"""
import collections
import glob
import json
import os
import re
import statistics
import sys

path = sys.argv[1] if len(sys.argv) > 1 else os.path.expandvars(r"%APPDATA%\Godot\app_userdata\Lake Cleanup\shop_playtest.log")
which = int(sys.argv[2]) if len(sys.argv) > 2 else 1
rows = [json.loads(l) for l in open(path, encoding="utf8") if l.strip()]
news = [i for i, r in enumerate(rows) if r["kind"] == "session" and r.get("started") == "new"]
start = news[-which]
end = news[-which + 1] if which > 1 else len(rows)
rows = rows[start:end]
# A "continue" session line inside the run is a later sitting of it; one whose clock is behind
# the run's is another save loading behind the menu, and its lines are not this run's.
buys = [r for r in rows if r["kind"] == "purchase"]
prog = [r for r in rows if r["kind"] == "progress"]
casts = [r for r in rows if r["kind"] == "cast"]
print(f"run from {rows[0]['at']} to {rows[-1]['at']}: {len(buys)} buys, {len(casts)} casts, "
      f"{rows[-1]['t'] / 60:.1f} min on the clock, cleared {prog[-1]['cleared']:.3f}")
done = next((p for p in prog if p["pieces_left"] == 0), None)
print("lake empty at", f"{done['t'] / 60:.1f} min" if done else "never (run not finished)")

tracks = {}
for f in sorted(glob.glob("resources/upgrades/*.tres")):
    d = dict(re.findall(r"^(\w+) = (.+?)\r?$", open(f, encoding="utf8").read(), re.M))
    tracks[os.path.basename(f)[:-5]] = d
by = collections.OrderedDict()
for b in buys:
    by.setdefault(b["id"], []).append(b)
print("\ntrack          got    first..last min    spent")
for k, d in tracks.items():
    b = by.get(k, [])
    cap = int(d["level_cap"])
    if b:
        print(f"{k:14s} {len(b):2d}/{cap:2d}  {b[0]['t'] / 60:5.1f}..{b[-1]['t'] / 60:5.1f}   {sum(x['cost'] for x in b):8d}")
    else:
        print(f"{k:14s}  0/{cap:2d}")
for k in ("net_strength", "net_hold", "fleet", "lucky_haul", "bird_worth", "dog_count"):
    print(f"{k:13s} at", [round(b["t"] / 60, 1) for b in by.get(k, [])])
print("spent", sum(b["cost"] for b in buys), " unspent at the end", prog[-1]["sludge"])


def level(key, t):
    return sum(1 for b in buys if b["id"] == key and b["t"] <= t)


def value(key, lv):
    d = tracks[key]
    return min(float(d["curve_a"]) + float(d["curve_b"]) * lv + float(d["curve_c"]) * lv * lv, float(d["value_cap"]))


print("\nmin cleared  out/s  ferry/s   box  sludge  earn/s  str catch range  birds")
last_e, last_t, last_left = 0.0, 0.0, prog[0]["pieces_left"]
for m in range(5, int(rows[-1]["t"] / 60) + 6, 5):
    p = min(prog, key=lambda r: abs(r["t"] - m * 60))
    if abs(p["t"] - m * 60) > 60:
        break
    t = p["t"]
    speed, hold = value("boat_speed", level("boat_speed", t)), value("cargo", level("cargo", t))
    cut = value("boat_volley", level("boat_volley", t))
    cap = (1 + level("fleet", t)) * hold / (8.4 + 206.6 / speed + 0.059 * hold * (1 - cut))
    e = p["sludge"] + sum(b["cost"] for b in buys if b["t"] <= t)
    print(f"{m:3d} {p['cleared']:7.3f} {(last_left - p['pieces_left']) / max(t - last_t, 1):6.2f} {cap:8.2f} {p['box']:5d} "
          f"{p['sludge']:7d} {(e - last_e) / max(t - last_t, 1):7.1f}  {level('net_strength', t):3d} {level('net_hold', t):5d} "
          f"{level('net_range', t):5d}  {p['birds']:5d}")
    last_e, last_t, last_left = e, t, p["pieces_left"]
boxes = [p["box"] for p in prog]
print(f"\nWaiting: max {max(boxes)}, median {statistics.median(boxes):.0f}, over two loads in "
      f"{sum(p['box'] > 2 * value('cargo', level('cargo', p['t'])) for p in prog) / len(prog):.0%} of samples")
gaps = [c["since_last"] for c in casts if c["since_last"] > 0]
print(f"casts: median gap {statistics.median(gaps):.1f} s")
shed, opened = 0.0, None
for r in rows:
    if r["kind"] == "shed_open":
        opened = r["t"]
    elif r["kind"] == "shed_close" and opened is not None:
        shed += r["t"] - opened
        opened = None
print(f"shed: {shed / 60:.1f} min; shop open in {sum(p['shop_open'] for p in prog)} of {len(prog)} samples")
bg = [b2["t"] - b1["t"] for b1, b2 in zip(buys, buys[1:])]
visits = 1 + sum(g > 20 for g in bg)
print(f"buys: {len(buys)} in about {visits} shop visits, longest wait {max(bg):.0f} s at {buys[bg.index(max(bg))]['t'] / 60:.1f} min, last buy {buys[-1]['t'] / 60:.1f} min")
