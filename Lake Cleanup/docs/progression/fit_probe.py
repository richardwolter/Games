"""Fits the sim's k_* calibration constants to tools/last_probe.log (written by tools/probe_rates.tscn).

Run from the project root:  python docs/progression/fit_probe.py
Writes docs/progression/calibration.json, which build_current.py reads. Prints each fit with its
error so a bad fit is visible rather than silently baked in.
"""
import json
import math

LOG = "tools/last_probe.log"
OUT = "docs/progression/calibration.json"

rows = [json.loads(line) for line in open(LOG, encoding="utf8") if line.strip().startswith("{")]
census = next(r for r in rows if r["probe"] == "census")
casts = [r for r in rows if r["probe"] == "cast" and not r["timed_out"]]
ferries = [r for r in rows if r["probe"] == "ferry_run" and not r["timed_out"]]
skims = [r for r in rows if r["probe"] == "skim_run" and not r["timed_out"]]
dogs = [r for r in rows if r["probe"] == "dog"]
cal = {"source": LOG}

# ---- the basin
tiers = {int(k): v for k, v in census["by_tier"].items()}
total = sum(tiers.values())
cal["units_by_tier"] = tiers
cal["strand"] = census["strand"] + census["dry"]
cal["k_stack"] = round(census["mean_stack"], 3)
cal["deepest"] = census["deepest"]
print(f"basin: {total} rubbish pieces by tier {tiers}, strand+dry {cal['strand']}, mean stack {cal['k_stack']}")


def least_squares(xs, ys):
    """y = a + b*x"""
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    b = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sxx if sxx else 0.0
    return my - b * mx, b


# ---- cast cycle: seconds = a + distance * (1/26 + b / reel)
if casts:
    xs = [c["distance"] / c["reel"] for c in casts]
    ys = [c["seconds"] - c["distance"] / 26.0 for c in casts]
    a, b = least_squares(xs, ys)
    err = math.sqrt(sum((a + b * x - y) ** 2 for x, y in zip(xs, ys)) / len(xs))
    cal["k_cast_fixed"] = round(a, 3)
    cal["k_reel_factor"] = round(b, 3)
    print(f"cast cycle: seconds = {a:.2f} + distance/26 + {b:.2f} * distance/reel   (rms {err:.2f} s over {len(casts)} casts)")

    # ---- catch per cast: pieces = min(hold, (2*mouth*max(0, d - shelf) + PI*mouth^2 * [d > shelf]) * density * share(power))
    share = {}
    run = 0
    for t in sorted(tiers):
        run += tiers[t]
        share[t] = run / total
    best = None
    for shelf10 in range(0, 41):
        shelf = shelf10 / 10.0
        for dens100 in range(5, 400, 5):
            dens = dens100 / 100.0
            e = 0.0
            for c in casts:
                mouth = c["radius"] + 0.15
                length = max(0.0, c["distance"] - shelf)
                area = 2 * mouth * length + (math.pi * mouth * mouth if length > 0 else 0.0)
                pred = min(c["hold"], area * dens * share[min(c["power"], max(share))])
                e += (pred - c["pieces"]) ** 2
            if best is None or e < best[0]:
                best = (e, shelf, dens)
    e, shelf, dens = best
    cal["k_shelf"] = shelf
    cal["k_density"] = dens
    print(f"catch: density {dens:.2f} catchable pieces per swept tile (all tiers), shelf {shelf:.1f} tiles   (rms {math.sqrt(e / len(casts)):.2f} pieces)")
    by_cfg = {}
    for c in casts:
        by_cfg.setdefault(tuple(c["config"]), []).append(c)
    for cfg, cs in by_cfg.items():
        print(f"  levels {list(cfg)}: {sum(x['pieces'] for x in cs) / len(cs):5.1f} pieces, {sum(x['seconds'] for x in cs) / len(cs):4.1f} s per cast, hold {cs[0]['hold']}")

# ---- ferry run: seconds = a + b / speed + c * lot  (b = the lap's sailing, c = the volleys)
# Loads are mixed since 2026-09-14, so a run is a lap of every yard it needs; the one-material
# runs measured before that were one-stop trips and came out about three times too fast.
if ferries:
    def solve3(rows3):
        # normal equations for y = a + b*x1 + c*x2
        import itertools
        n = len(rows3)
        S = [[0.0] * 3 for _ in range(3)]
        T = [0.0] * 3
        for x1, x2, y in rows3:
            v = [1.0, x1, x2]
            for i in range(3):
                T[i] += v[i] * y
                for j in range(3):
                    S[i][j] += v[i] * v[j]
        # Gauss
        M = [S[i] + [T[i]] for i in range(3)]
        for i in range(3):
            piv = max(range(i, 3), key=lambda r: abs(M[r][i]))
            M[i], M[piv] = M[piv], M[i]
            for r in range(3):
                if r != i and M[i][i]:
                    f = M[r][i] / M[i][i]
                    M[r] = [M[r][k] - f * M[i][k] for k in range(4)]
        return [M[i][3] / M[i][i] for i in range(3)]
    fa, fb, fc = solve3([(1.0 / f["speed"], f["lot"], f["seconds"]) for f in ferries])
    err = math.sqrt(sum((fa + fb / f["speed"] + fc * f["lot"] - f["seconds"]) ** 2 for f in ferries) / len(ferries))
    cal["k_ferry_leg"] = round(fb / 2.0, 2)
    cal["k_ferry_fixed"] = round(fa, 2)
    cal["k_ferry_per_piece"] = round(fc, 3)
    print(f"ferry run (mixed loads): seconds = {fa:.1f} + {fb:.1f} / speed + {fc:.3f} * lot  (rms {err:.1f} s over {len(ferries)} runs)")
    for f in ferries[::2]:
        print(f"  speed {f['speed']:5.1f}, lot {f['lot']:3d}: {f['seconds']:.1f} s")

# ---- double cast and birds, off the same casts
if casts:
    found = [c for c in casts if "double_found" in c]
    if found:
        cal["k_double_found"] = round(sum(1 for c in found if c["double_found"]) / len(found), 3)
        print(f"double cast: a spot for the second net found on {cal['k_double_found'] * 100:.0f}% of casts (fresh lake)")
    with_birds = [c for c in casts if "birds" in c]
    if with_birds:
        first = [c for c in with_birds if c["hold"] <= 6]
        cal["k_bird_per_cast"] = round(sum(c["birds"] for c in with_birds) / len(with_birds), 3)
        cal["k_bird_per_cast_small"] = round(sum(c["birds"] for c in first) / max(len(first), 1), 3)
        cal["k_birds_on_lake"] = round(sum(c["birds_on_lake"] for c in with_birds) / len(with_birds), 1)
        print(f"birds: {cal['k_bird_per_cast']:.2f} a cast over all casts, {cal['k_bird_per_cast_small']:.2f} with a small net, not aimed at; {cal['k_birds_on_lake']} on the lake")

# ---- skimmer: pieces per run against the model's shape, as one correction factor
if skims:
    cal["skim_runs"] = [{"level": s["level"], "lot": s["lot"], "capacity": s["capacity"], "skimmed": s["skimmed"], "seconds": round(s["seconds"], 1)} for s in skims]
    for s in skims:
        print(f"skimmer level {s['level']:2d}, lot {s['lot']:3d}/{s['capacity']}: {s['skimmed']:3d} skimmed in {s['seconds']:.0f} s")

# ---- dog: pieces per second
if dogs:
    cal["dog_runs"] = [{"levels": d["levels"], "per_minute": round(60.0 * d["left_lake"] / d["seconds"], 2)} for d in dogs]
    for d in dogs:
        print(f"dog levels {d['levels']}: {60.0 * d['left_lake'] / d['seconds']:.2f} pieces per minute")

json.dump(cal, open(OUT, "w", encoding="utf8"), indent=1)
print("wrote", OUT)
