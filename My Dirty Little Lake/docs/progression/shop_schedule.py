"""Prints, per track, the minutes the focused bot bought its levels at against the minutes
build_shop.py's SCHEDULE wants, then income, the box and the share cleared every five minutes.

Run from the project root after a sim:  python docs/progression/shop_schedule.py
"""
import json

cfg = json.load(open("docs/progression/shop.json", encoding="utf8"))
rep = json.load(open("docs/progression/shop-report/report.json", encoding="utf8"))
log = next(l for l in rep["logs"] if l["bot"] == "focused")
print("clear", round((log.get("clearedAt") or 0) / 60, 1), "min")
by = {}
for p in log["purchases"]:
    by.setdefault(p["id"], []).append(round(p["t"] / 60, 1))
for n in cfg["nodes"]:
    k, want, cost = n["id"], n["schedule"], n["cost"]
    got = by.get(k, [])
    mult = (cost[-1] / cost[0]) ** (1 / max(1, len(cost) - 1))
    print(f"{k:14s} {cost[0]:>8g} x{mult:.2f} top {cost[-1]:>9.0f}   want {want[0]:g}..{want[-1]:g}"
          f"   got {got[0] if got else '-'}..{got[-1] if got else '-'} ({len(got)}/{len(want)})")
print("strength", by.get("net_strength"), " fleet", by.get("fleet"))
print("min  income  box  cleared")
for s in log["samples"][::10]:
    if s["t"] / 60 > 100:
        break
    print(f"{s['t'] / 60:>3.0f} {s['income']:>7.1f} {s.get('pools', {}).get('box', 0):>4.0f}  {s.get('cleared', 0):.3f}")
