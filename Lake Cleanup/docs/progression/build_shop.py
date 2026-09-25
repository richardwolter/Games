"""Builds docs/progression/shop.json: the progression sim model of Lake Cleanup's shop after the
2026-09-18 balance pass (issue #23): the boats slightly ahead of the net and the dogs all run
(Hold 8 + 2 a level against Haul's 4 + 1, a faster level-0 hull), Strength bought at about
10 / 20 / 30 / 40 minutes, Haul trailing Hold, the luck tracks early and steady, a focused
clear of 70 to 80 minutes. SCHEDULE below is the minute each level is meant to be bought at;
price_shop.py steers the prices to it.

Run from the project root:  python docs/progression/build_shop.py
Then:                        node ~/.claude/skills/incremental-progression/scripts/run_sim.js docs/progression/shop.json --out docs/progression/shop-report
Or the whole pricing loop:   sh docs/progression/shop_loop.sh

Prices and effect curves are read from resources/upgrades/*.tres, pay from resources/economy.tres,
tiers and pollution from resources/trash/*.tres. Everything named k_* is a calibration constant:
the net's four (k_density, k_aim, k_cast_share, k_catch_scale) are fitted by replay_shop.py to
Richard's two logged shop runs of 2026-09-18, the rest measured by tools/probe_rates, all through
calibration.json.

**The prices are frozen as played in the second logged run** (Richard, 2026-09-18: "the pacing
was good"). This model is for judging a future tweak before it is played; shop_loop.sh would
move the ten tracks price_shop.py's HAND does not pin, and is not to be re-run without his say.
"""
import glob
import json
import math
import re

ROOT = "."


def tres(path):
    d = {}
    for line in open(path, encoding="utf8"):
        m = re.match(r"^(\w+) = (.+)$", line.strip())
        if m:
            try:
                d[m.group(1)] = float(m.group(2))
            except ValueError:
                d[m.group(1)] = m.group(2)
    return d


economy = tres(f"{ROOT}/resources/economy.tres")
cal = json.load(open(f"{ROOT}/docs/progression/calibration.json", encoding="utf8"))
TIER_STEP = economy.get("tier_pay_step", 0.5)

tiers = {}
for f in glob.glob(f"{ROOT}/resources/trash/*.tres"):
    d = tres(f)
    tiers.setdefault(int(d["tier"]), []).append(d["pollution"])
pollution = {t: sum(v) / len(v) for t, v in tiers.items()}

# The lake holds DENSITY times the pieces the calibration probe counted (LakeGrid.DENSITY,
# 2026-09-24): every stack past the island's ring is that many times deeper, and the strand is
# untouched. A cast sweeps that many more pieces off the same water, so k_density goes with it.
DENSITY = 2
STRAND = cal["strand"]
UNITS = {int(t): n for t, n in cal["units_by_tier"].items()}
UNITS = {t: (n - (STRAND if t == 0 else 0)) * DENSITY + (STRAND if t == 0 else 0) for t, n in UNITS.items()}
LAKE = sum(UNITS.values()) - STRAND
LAKE_R = math.sqrt(40 * 34)
ISLAND_R = math.sqrt(8 * 6.8) + 2.2

stats = {
    "piece_base_pay": economy.get("piece_base_pay", 2.5),
    "piece_filth_pay": economy.get("piece_filth_pay", 6.0),
    "net_radius": 0, "net_power": 0, "net_range": 0, "reel": 0, "net_hold": 0,
    "boat_speed": 0, "cargo": 0, "boats": 1, "boat_volley_cut": 0,
    "dog_fetch": 0, "dog_wait_cut": 0, "dog": 1, "dog_tier": 0,
    "dog_beach": 0.35, "dog_strand_speed": 1.0, "dog_reach": 6,
    "lucky_odds": 0.0, "double_odds": 0.0, "recycle_bonus": 0.0, "bird_worth": 1.0,
    "bird_bonus": economy.get("bird_bonus", 26.0),
    "k_lucky_extra": 4,
    "k_double_found": cal.get("k_double_found", 1.0),
    "k_bonus_share": 0.25,
    "k_bird_swept": 0.0015, "k_bird_aim": 3.0,
    "k_lake_r": round(LAKE_R, 2), "k_island_r": round(ISLAND_R, 2),
    "k_units_total": LAKE, "k_stack": cal["k_stack"],
    "k_density": cal["k_density"] * DENSITY, "k_reel_factor": cal["k_reel_factor"],
    "k_aim": cal.get("k_aim", 2.0), "k_cast_share": cal.get("k_cast_share", 0.75), "k_mouth_edge": 0.15,
    "k_shelf": 2.5, "k_reach_far": 35.6,
    "k_catch_scale": cal.get("k_catch_scale", 1.7), "k_ferry_scale": 1.0,
    "k_ferry_leg": cal["k_ferry_leg"], "k_ferry_fixed": cal["k_ferry_fixed"],
    "k_ferry_per_piece": cal.get("k_ferry_per_piece", 0.0),
    "k_dog_trip": 8, "k_dog_carry": 2.2, "k_dog_carry_share": 0.5,
    "k_strand": STRAND, "k_strand_band": 2.5,
}

pools, catch_from, access_terms = {}, [], []
for t in sorted(tiers):
    pid = f"lake_t{t}"
    stats[f"k_units_t{t}"] = UNITS[t] - (STRAND if t == 0 else 0)
    pools[pid] = {"units": f"k_units_t{t}",
                  "value": f"(piece_base_pay + {pollution[t]:.2f} * piece_filth_pay) * {1 + TIER_STEP * t:.2f}"}
    catch_from.append({"pool": pid, "gate": f"net_power >= {t}", "share": "coverage"})
    access_terms.append(f"max(0, pool_{pid} - k_units_t{t} * (1 - coverage)) * (net_power >= {t})")
pools["strand"] = {"units": STRAND, "value": f"piece_base_pay + {pollution[0]:.2f} * piece_filth_pay"}
catch_from.append({"pool": "strand", "share": "strand_reach"})
access_terms.append("max(0, pool_strand - k_strand * (1 - strand_reach))")
pools["box"] = {"units": 0}
pools["pier"] = {"units": 0, "sell": True, "payMult": "1 + recycle_bonus * k_bonus_share"}
pools["flock"] = {"units": "inf", "value": "bird_bonus * bird_worth"}
pools["purse"] = {"units": 0, "sell": True}

ring_range = "(net_range * (k_lake_r - k_island_r) / k_reach_far)"
ring = "(min(k_lake_r, k_island_r + {d}) ^ 2 - k_island_r ^ 2) / (k_lake_r ^ 2 - k_island_r ^ 2)"
access_now = " + ".join(access_terms)
derived = [
    ["coverage", ring.format(d=ring_range)],
    ["dog_coverage", ring.format(d="dog_reach") + " * k_dog_carry_share"],
    ["strand_reach", f"clamp((k_island_r + {ring_range} + net_radius - k_lake_r) / k_strand_band, 0, 1)"],
    ["access_now", access_now],
    ["density", "k_density * access_now / max(coverage * k_units_total + strand_reach * k_strand, 1)"],
    ["cast_dist", "net_range * k_cast_share"],
    ["mouth", "net_radius + k_mouth_edge"],
    ["swept", "2 * mouth * max(0, cast_dist - k_shelf) + (cast_dist > k_shelf ? PI * mouth ^ 2 : 0)"],
    ["per_cast", "min(net_hold, swept * density)"],
    ["cast_cycle", "k_aim + cast_dist / 26 + k_reel_factor * cast_dist / reel"],
    # Loading (boat_volley) tightens the stagger of the volley at both ends of a run, which is
    # what the per-piece term measures.
    ["ferry_trip", "k_ferry_fixed + 2 * k_ferry_leg / boat_speed + k_ferry_per_piece * cargo * (1 - boat_volley_cut)"],
    ["ferry_rate", "k_ferry_scale * (boats * cargo / ferry_trip)"],
    ["access_lucky", access_now.replace("(net_power >= ", "(net_power + 1 >= ")],
    ["density_lucky", "k_density * access_lucky / max(coverage * k_units_total + strand_reach * k_strand, 1)"],
    ["lucky_cast", "min(net_hold + k_lucky_extra, swept * density_lucky)"],
    ["double_cast", "per_cast * k_double_found"],
    ["catch_rate", "k_catch_scale * (per_cast + lucky_odds * max(0, lucky_cast - per_cast) + double_odds * double_cast) / cast_cycle"],
    ["lake_left", "(pool_lake_t0 + pool_lake_t1 + pool_lake_t2 + pool_lake_t3 + pool_lake_t4) / k_units_total"],
    ["bird_rate", "k_bird_swept * k_bird_aim * swept * (1 + double_odds) * min(1, lake_left * 2) / cast_cycle"],
    ["dog_near_left", "max(0, pool_lake_t0 - k_units_t0 * (1 - dog_coverage))"],
    ["dog_beach_share", "dog_near_left > 5 ? dog_beach : 1"],
    ["dog_rate", "dog * min(dog_fetch, k_dog_carry) / (k_dog_trip + max(10 - dog_wait_cut, 3))"],
]
flows = [
    {"id": "catch", "label": "net catch", "from": catch_from, "to": "box", "rate": "catch_rate", "active": True},
    # Carry (dog_strength) opens the heavier tiers to the pack, a tier a level.
    {"id": "dog", "label": "dog fetch", "from": [{"pool": f"lake_t{t}", "gate": f"dog_tier >= {t}", "share": "dog_coverage"}
                                                  for t in sorted(tiers)], "to": "box",
     "rate": "dog_rate * (1 - dog_beach_share)"},
    {"id": "dog_beach", "label": "dog strand runs", "from": ["strand"], "to": "box",
     "rate": "dog_rate * dog_beach_share * dog_strand_speed"},
    {"id": "ferry", "label": "ferry haul", "from": ["box"], "to": "pier", "rate": "ferry_rate"},
    {"id": "birds", "label": "pigeons netted", "from": ["flock"], "to": "purse", "rate": "bird_rate", "active": True},
]


def curve(d, level):
    l = min(level, d["level_cap"])
    v = min(d["curve_a"] + d["curve_b"] * l + d["curve_c"] * l * l, d["value_cap"])
    return math.floor(v) if d["is_integer"] == "true" else v


# key, board, name, stat, tags
SPEC = [
    ("net_width", "net", "Width", "net_radius", []),
    ("net_strength", "net", "Strength", "net_power", []),
    ("net_range", "net", "Range", "net_range", []),
    ("reel", "net", "Reel", "reel", []),
    ("net_hold", "net", "Catch", "net_hold", []),
    ("lucky_haul", "luck", "Lucky cast", "lucky_odds", []),
    ("double_cast", "luck", "Double cast", "double_odds", []),
    ("boat_speed", "ferry", "Sailing", "boat_speed", []),
    ("cargo", "ferry", "Hold", "cargo", []),
    ("fleet", "ferry", "Fleet", "boats", []),
    ("boat_volley", "ferry", "Loading", "boat_volley_cut", []),
    ("dog_fetch", "dog", "Fetch", "dog_fetch", []),
    ("dog_wait", "dog", "Keenness", "dog_wait_cut", []),
    ("dog_count", "dog", "Pack", "dog", []),
    ("dog_strength", "dog", "Carry", "dog_tier", []),
    ("recycle_bonus", "luck", "Bonus yard", "recycle_bonus", []),
    ("bird_worth", "luck", "Pigeons", "bird_worth", ["utility"]),
]


def spread(first, last, ranks):
    if ranks == 1:
        return [first]
    return [round(first + (last - first) * i / (ranks - 1), 1) for i in range(ranks)]


# The minute of a focused run each level is meant to be bought at (Richard, 2026-09-18).
# Strength is the game changer and is held to the middle of the run, a tier every ten minutes.
# Hold and Sailing run ahead of Haul all the way, so the boats stay in front of the net. The
# luck tracks start early and keep coming through the climb to Strength, as its teaser.
# Range finishes early on purpose: the reach has to run ahead of the clearing, or the water in
# reach empties, income stops and the last Range levels can never be paid for (the sim
# soft-locked at 82% cleared with Range scheduled to minute 48). The net's own tracks run to
# about an hour: bought by minute 46 they cleared the lake in 46, because with the boats ahead
# nothing but the net's levels paces the run.
SCHEDULE = {
    "net_strength": [10, 20, 30, 40],
    "net_hold": spread(8, 66, 8),
    "net_width": spread(1.5, 58, 20),
    "net_range": spread(1, 42, 20),
    "reel": spread(2, 58, 20),
    "lucky_haul": spread(3, 39, 10),
    "double_cast": spread(5, 52, 10),
    "cargo": spread(0.5, 48, 8),
    "boat_speed": spread(1, 54, 20),
    "fleet": [2, 9, 20],
    "boat_volley": [6, 16, 28, 42],
    "dog_fetch": [8, 16, 24, 32],
    "dog_wait": [12, 22, 32],
    "dog_count": [4, 9, 15],
    "dog_strength": [12, 22, 32, 42],
    "recycle_bonus": spread(6, 54, 8),
    "bird_worth": spread(2, 30, 8),
}
nodes = []
for key, tree, name, stat, tags in SPEC:
    d = tres(f"{ROOT}/resources/upgrades/{key}.tres")
    cap = int(d["level_cap"])
    if stat not in ("boats", "dog"):
        stats[stat] = curve(d, 0)
    nodes.append({
        "id": key, "tree": tree, "group": key, "name": name, "ranks": cap,
        "cost": [round(d["price_base"] * d["price_mult"] ** level, 1) for level in range(cap)],
        "effects": [{"stat": stat, "add": [round(curve(d, level + 1) - curve(d, level), 5) for level in range(cap)]}],
        "tags": tags,
        "schedule": SCHEDULE[key],
    })
    assert len(SCHEDULE[key]) == cap, key

config = {
    "game": "Lake Cleanup (shop, 2026-09-18 pass)", "currency": "sludge", "maxMinutes": 300, "startMoney": 0,
    "stats": stats, "derived": derived, "pools": pools, "flows": flows,
    "goal": {"pools": ["lake_t0", "lake_t1", "lake_t2", "lake_t3", "lake_t4", "strand"], "clearAt": 0.995},
    # The boats slightly ahead (Richard, 2026-09-18): the fleet's capacity at or over what the net
    # lands, never under it. The dogs feed the box too, which is why the band starts at par.
    "links": [{"up": "catch", "down": "ferry", "band": [1.0, 2.5], "buffer": "box"}],
    "trees": ["net", "ferry", "dog", "luck"], "nodes": nodes,
    "bots": [
        {"id": "focused", "policy": "value", "thinkEvery": 5},
        {"id": "casual", "policy": "mixed", "noise": 0.15, "attention": 0.9,
         "offline": {"every": 600, "for": 240}, "thinkEvery": 20, "seeds": 3},
        {"id": "cheapest", "policy": "cheapest", "thinkEvery": 5},
    ],
    # A run that only cleans is about 50 minutes and a first run about 65 (Richard's two logged
    # runs, 2026-09-18: 50.5 and 64.5); decorating and the rest are what take a run past that.
    # Supersedes "70 to 80 focused" and issue #23's 2-3 hours. The casual bot stays for the
    # soft-lock check and carries no time target.
    "targets": {"clearMinutes": {"focused": [48, 68]},
                "paybackCurve": [[0, 30], [10, 90], [30, 240], [60, 480], [90, 720]]},
    # Seconds between buys the pricing aims for: brisk at the start, slowing to the end. Its
    # average over the run has to match the 181 levels of SCHEDULE.
    "gapCurve": [[0, 7], [10, 14], [30, 26], [60, 42], [90, 60]],
}

with open(f"{ROOT}/docs/progression/shop.json", "w", encoding="utf8") as out:
    json.dump(config, out, indent=1)
print(f"shop.json: {len(pools)} pools, {len(nodes)} tracks, {sum(n['ranks'] for n in nodes)} levels")
