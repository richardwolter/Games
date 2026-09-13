"""Builds docs/progression/current.json: the progression sim model of Lake Cleanup's shop as it is.

Run from the project root:  python docs/progression/build_current.py
Then:                        node ~/.claude/skills/incremental-progression/scripts/run_sim.js docs/progression/current.json

Prices and effect curves are read from resources/upgrades/*.tres, pay from resources/economy.tres,
tiers and pollution from resources/trash/*.tres. Everything named k_* is a calibration constant:
see docs/progression/lake-tree.md for where each one comes from and how sure it is.
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
# Measured by tools/probe_rates.tscn and fitted by docs/progression/fit_probe.py.
cal = json.load(open(f"{ROOT}/docs/progression/calibration.json", encoding="utf8"))

# Rubbish kinds by tier: how many kinds, and their mean pollution (pay is base + pollution * filth).
tiers = {}
for f in glob.glob(f"{ROOT}/resources/trash/*.tres"):
    d = tres(f)
    tiers.setdefault(int(d["tier"]), []).append(d["pollution"])
kinds = {t: len(v) for t, v in tiers.items()}
kinds_total = sum(kinds.values())
pollution = {t: sum(v) / len(v) for t, v in tiers.items()}

UNITS = {int(t): n for t, n in cal["units_by_tier"].items()}  # every rubbish piece, finds excluded
STRAND = cal["strand"]  # strand line plus dry beach litter: the dog's alone
LAKE = sum(UNITS.values()) - STRAND
LAKE_R = math.sqrt(40 * 34)          # Iso.RADIUS as one radius
ISLAND_R = math.sqrt(8 * 6.8) + 2.2  # Iso.ISLAND_RADIUS plus SHELF_TILES
LAKE_TILES = math.pi * (LAKE_R ** 2 - ISLAND_R ** 2)

stats = {
    "piece_base_pay": economy.get("piece_base_pay", 2.5),
    "piece_filth_pay": economy.get("piece_filth_pay", 6.0),
    # upgradeable, bases filled from the tracks below
    "net_radius": 0, "net_power": 0, "net_range": 0, "reel": 0, "net_hold": 0,
    "boat_speed": 0, "cargo": 0, "skimmer": 0, "boats": 1,
    "dog_fetch": 0, "dog_wait_cut": 0,
    # geometry, derived from Iso
    "k_lake_r": round(LAKE_R, 2), "k_island_r": round(ISLAND_R, 2),
    "k_units_total": LAKE, "k_stack": cal["k_stack"],
    # net cycle
    "k_density": cal["k_density"],        # measured: catchable pieces per swept tile, full lake, all tiers
    "k_reel_factor": cal["k_reel_factor"],  # measured: cast seconds = distance/26 + factor * distance/reel
    "k_aim": 2.0,           # ESTIMATE: player seconds per cast (look, aim, click, walk)
    "k_cast_share": 0.75,   # ESTIMATE: typical cast as a share of max range
    "k_mouth_edge": 0.15,   # Net.MOUTH_EDGE
    # ferry
    "k_ferry_leg": cal["k_ferry_leg"],      # measured: tiles each way, dock to pier
    "k_ferry_fixed": cal["k_ferry_fixed"],  # measured: seconds per run not spent sailing
    # skimmer
    "k_material_share": 0.3,  # sum of MATERIAL_QUOTA squared: chance a piece is the pier's material
    "k_stack_slots": 4,       # measured mean stack 4.07
    "k_skim_factor": 1.4,     # fitted so level 4 on a light load brings up ~98, as measured
    # dog
    "k_dog_trip": 8, "k_dog_carry": 2.2,  # fitted: 3.3 / 7.3 / 11.3 pieces a minute at levels 0/0, 4/0, 4/3
    "k_dog_reach": 6, "k_dog_carry_share": 0.5,
    "k_strand": STRAND, "k_strand_band": 2.5,  # ESTIMATE: tiles of bank a mouth has to overlap to take all of it
}

pools, catch_from, skim_from = {}, [], []
access_terms, skim_terms = [], []
for t in sorted(tiers):
    pid = f"lake_t{t}"
    stats[f"k_units_t{t}"] = UNITS[t] - (STRAND if t == 0 else 0)
    pools[pid] = {"units": f"k_units_t{t}", "value": f"piece_base_pay + {pollution[t]:.2f} * piece_filth_pay"}
    catch_from.append({"pool": pid, "gate": f"net_power >= {t}", "share": "coverage"})
    skim_from.append({"pool": pid, "gate": f"skim_power >= {t}"})
    access_terms.append(f"max(0, pool_{pid} - k_units_t{t} * (1 - coverage)) * (net_power >= {t})")
    skim_terms.append(f"pool_{pid} * (skim_power >= {t})")
pools["strand"] = {"units": STRAND, "value": f"piece_base_pay + {pollution[0]:.2f} * piece_filth_pay"}
# A wide mouth cast to the bank reaches the strand and the beach litter too (the ring is the catch).
catch_from.append({"pool": "strand", "share": "strand_reach"})
access_terms.append("max(0, pool_strand - k_strand * (1 - strand_reach))")
pools["box"] = {"units": 0}
pools["pier"] = {"units": 0, "sell": True}

ring = "(min(k_lake_r, k_island_r + {d}) ^ 2 - k_island_r ^ 2) / (k_lake_r ^ 2 - k_island_r ^ 2)"
derived = [
    ["coverage", ring.format(d="net_range")],
    ["dog_coverage", ring.format(d="k_dog_reach") + " * k_dog_carry_share"],
    ["strand_reach", "clamp((k_island_r + net_range + net_radius - k_lake_r) / k_strand_band, 0, 1)"],
    ["access_now", " + ".join(access_terms)],
    ["density", "k_density * access_now / max(coverage * k_units_total + strand_reach * k_strand, 1)"],
    ["cast_dist", "net_range * k_cast_share"],
    ["mouth", "net_radius + k_mouth_edge"],
    ["swept", "2 * mouth * cast_dist + PI * mouth ^ 2"],
    ["per_cast", "min(net_hold, swept * density)"],
    ["cast_cycle", "k_aim + cast_dist / 26 + k_reel_factor * cast_dist / reel"],
    ["catch_rate", "per_cast / cast_cycle"],
    ["ferry_trip", "k_ferry_fixed + 2 * k_ferry_leg / boat_speed"],
    ["ferry_rate", "boats * cargo / ferry_trip"],
    # The skimmer only fishes on a loaded run to a pier, only for that pier's material.
    ["trips", "min(boats / ferry_trip, rate_ferry)"],
    ["avg_lot", "rate_ferry / max(trips, 0.000001)"],
    ["skim_room", "skimmer + max(0, cargo - avg_lot)"],
    ["skim_chance", "skimmer >= 1 ? lerp(0.3, 1, (skimmer - 1) / 9) : 0"],
    ["skim_power", "floor(max(skimmer - 1, 0) / 2)"],
    ["skim_left", "(" + " + ".join(skim_terms) + ") / k_units_total"],
    ["skim_found", "k_skim_factor * k_ferry_leg * (2 * (skimmer - 1) + 1) * k_stack * min(1, (skimmer + 1) / k_stack_slots) * k_material_share * skim_left * skim_chance"],
    ["skim_rate", "skimmer >= 1 ? trips * min(skim_room, skim_found) : 0"],
    ["dog_rate", "min(dog_fetch, k_dog_carry) / (k_dog_trip + max(10 - dog_wait_cut, 3))"],
]
flows = [
    {"id": "catch", "label": "net catch", "from": catch_from, "to": "box", "rate": "catch_rate", "active": True},
    {"id": "dog", "label": "dog fetch", "from": ["strand", {"pool": "lake_t0", "share": "dog_coverage"}], "to": "box", "rate": "dog_rate"},
    {"id": "ferry", "label": "ferry haul", "from": ["box"], "to": "pier", "rate": "ferry_rate"},
    {"id": "skim", "label": "skimmer", "from": skim_from, "to": "pier", "rate": "skim_rate"},
]


def curve(d, level):
    l = min(level, d["level_cap"])
    v = min(d["curve_a"] + d["curve_b"] * l + d["curve_c"] * l * l, d["value_cap"])
    return math.floor(v) if d["is_integer"] == "true" else v


nodes = []
spec = [
    ("net_width", "net", "Width", "net_radius"), ("net_strength", "net", "Strength", "net_power"),
    ("net_range", "net", "Range", "net_range"), ("reel", "net", "Speed", "reel"), ("net_hold", "net", "Haul", "net_hold"),
    ("boat_speed", "ferry", "Ferry speed", "boat_speed"), ("cargo", "ferry", "Ferry hold", "cargo"),
    ("fleet", "ferry", "Extra ferry", "boats"),
    ("dog_fetch", "dog", "Fetching", "dog_fetch"), ("dog_wait", "dog", "Keenness", "dog_wait_cut"),
]
for key, tree, name, stat in spec:
    d = tres(f"{ROOT}/resources/upgrades/{key}.tres")
    cap = int(d["level_cap"])
    if stat != "boats":
        stats[stat] = curve(d, 0)
    nodes.append({
        "id": key, "tree": tree, "group": key, "name": name, "ranks": cap,
        "cost": [round(d["price_base"] * d["price_mult"] ** level, 1) for level in range(cap)],
        "effects": [{"stat": stat, "add": [round(curve(d, level + 1) - curve(d, level), 5) for level in range(cap)]}],
        "tags": [],
    })
# skimmer keeps its own price table in lake.gd (PRICES / MAX_LEVELS)
nodes.append({"id": "skimmer", "tree": "ferry", "group": "skimmer", "name": "Skimmer", "ranks": 10,
              "cost": [round(26 * 1.48 ** level, 1) for level in range(10)],
              "effects": [{"stat": "skimmer", "add": 1}], "tags": []})

config = {
    "game": "Lake Cleanup (current shop)", "currency": "sludge", "maxMinutes": 300, "startMoney": 0,
    "stats": stats, "derived": derived, "pools": pools, "flows": flows,
    "goal": {"pools": [p for p in pools if p not in ("box", "pier")], "clearAt": 0.995},
    "links": [{"up": "catch", "down": "ferry", "band": [0.8, 1.5], "buffer": "box"}],
    "trees": ["net", "ferry", "dog"], "nodes": nodes,
    "bots": [
        {"id": "focused", "policy": "value", "thinkEvery": 5},
        {"id": "casual", "policy": "mixed", "noise": 0.3, "attention": 0.9,
         "offline": {"every": 600, "for": 270}, "thinkEvery": 20, "seeds": 3},
        {"id": "cheapest", "policy": "cheapest", "thinkEvery": 5},
        {"id": "no_skimmer", "policy": "value", "thinkEvery": 5, "avoid": ["skimmer"]},
    ],
    "targets": {"clearMinutes": {"focused": [50, 70], "casual": [100, 140]}},
}

with open(f"{ROOT}/docs/progression/current.json", "w", encoding="utf8") as out:
    json.dump(config, out, indent=1)
print(f"current.json: {len(pools)} pools, {len(nodes)} tracks; kinds per tier {kinds}")
