"""Builds docs/progression/lake-tree.json: the proposed upgrade tree on the calibrated lake model.

Run from the project root, after build_current.py:  python docs/progression/build_tree.py
The lake itself (pools, catch, ferry and dog rates, k_* constants) is taken from current.json so
the two configs can never disagree about the world; only the upgrades differ.

Once the tuner is published, lake-tree.json plus the tuner's saved edits are the source of truth.
Re-running this script resets the tree to the table below.
"""
import json

current = json.load(open("docs/progression/current.json", encoding="utf8"))

# ---- the world, minus the skimmer (cut from the design, 2026-09-12)
stats = {k: v for k, v in current["stats"].items() if k not in ("skimmer",)}
stats.update({
    "boats": 0,            # net only at the start; the first ferry is the first purchase
    "cargo": 18,           # was 6: one 6-piece ferry carried 0.34/s against a 0.8/s net, so early net buys earned nothing
    "dog": 0,              # adopted through the tree
    "dog_beach": 0.35,     # Dog.STRAND_ODDS: share of trips to the strand while near pieces remain
    "dog_strand_speed": 1.0,
    "dog_reach": stats.get("k_dog_reach", 6),
})
derived = []
for name, expr in current["derived"]:
    if name.startswith("skim") or name in ("trips", "avg_lot"):
        continue
    if name == "dog_rate":
        continue
    derived.append([name, expr.replace("k_dog_reach", "dog_reach")])
derived += [
    ["dog_near_left", "max(0, pool_lake_t0 - k_units_t0 * (1 - dog_coverage))"],
    ["dog_beach_share", "dog_near_left > 5 ? dog_beach : 1"],
    ["dog_rate", "dog * min(dog_fetch, k_dog_carry) / (k_dog_trip + max(10 - dog_wait_cut, 3))"],
]
flows = [
    next(f for f in current["flows"] if f["id"] == "catch"),
    {"id": "dog", "label": "dog fetch", "from": [{"pool": "lake_t0", "share": "dog_coverage"}], "to": "box",
     "rate": "dog_rate * (1 - dog_beach_share)"},
    {"id": "dog_beach", "label": "dog strand runs", "from": ["strand"], "to": "box",
     "rate": "dog_rate * dog_beach_share * dog_strand_speed"},
    next(f for f in current["flows"] if f["id"] == "ferry"),
]
pools = current["pools"]


def node(id, tree, name, cost, effects, parents=(), tags=(), group=None, require_all=False, desc="", fixed=False, at=None):
    n = {"id": id, "tree": tree, "group": group or tree, "name": name, "cost": cost,
         "parents": list(parents), "effects": [{"stat": s, op: v} for s, op, v in effects], "tags": list(tags)}
    if require_all:
        n["requireAll"] = True
    if desc:
        n["desc"] = desc
    if fixed:
        n["fixedCost"] = True
    if at is not None:
        n["at"] = at
    return n


N, F, D = "net", "ferry", "dog"
U = ["utility"]
nodes = [
    # ---- ferry: capacity keeps pace with the bag.  at= is the minute the design wants a focused player to buy it
    node("ferry_1", F, "First Ferry", 50, [("boats", "set", 1)], tags=["unlock"], group="fleet", fixed=True,
         desc="The first purchase: a boat to carry the catch to the piers. Starting money covers it."),
    node("hull_1", F, "Deeper Hull I", 300, [("cargo", "add", 4)], ["ferry_1"], group="hull", at=1.2),
    node("sails_1", F, "Trim Sails I", 500, [("boat_speed", "add", 2.0)], ["ferry_1"], group="sails", at=2),
    node("hull_2", F, "Deeper Hull II", 800, [("cargo", "add", 6)], ["hull_1"], group="hull", at=5.5),
    node("ferry_2", F, "Second Ferry", 2400, [("boats", "add", 1)], ["hull_1"], tags=["unlock"], group="fleet", at=9.5),
    node("sails_2", F, "Trim Sails II", 2800, [("boat_speed", "add", 3.0)], ["sails_1"], group="sails", at=15),
    node("hull_3", F, "Deeper Hull III", 4000, [("cargo", "add", 8)], ["hull_2"], group="hull", at=16.5),
    node("ferry_3", F, "Third Ferry", 11000, [("boats", "add", 1)], ["ferry_2"], tags=["unlock"], group="fleet", at=23.5),

    # ---- net: reach first, then the bag; strength is the spine; the mouth is the late sweep
    node("line_1", N, "Longer Line I", 150, [("net_range", "add", 2.2), ("reel", "add", 1.0)], ["ferry_1"], group="line",
         desc="Casts clear the rubbish-free shelf round the island and land in real water.", at=0.7),
    node("bag_1", N, "Bigger Bag I", 600, [("net_hold", "add", 3)], ["line_1"], group="bag", at=6.5),
    node("pull_1", N, "Stronger Pull", 1000, [("net_power", "set", 1)], ["line_1"], tags=["unlock"], group="pull",
         desc="Lifts tier 1: a quarter of the lake that was dead weight becomes catch.", at=4.5),
    node("line_2", N, "Longer Line II", 700, [("net_range", "add", 4.0), ("reel", "add", 2.0)], ["line_1"], group="line", at=3.5),
    node("bag_2", N, "Bigger Bag II", 1300, [("net_hold", "add", 3)], ["bag_1"], group="bag", at=8.5),
    node("bag_3", N, "Bigger Bag III", 3000, [("net_hold", "add", 6)], ["bag_2", "ferry_2"], group="bag", require_all=True, at=14),
    node("pull_2", N, "Heavy Lift", 4500, [("net_power", "set", 2)], ["pull_1"], tags=["unlock"], group="pull", at=11),
    node("line_3", N, "Longer Line III", 3000, [("net_range", "add", 7.0), ("reel", "add", 3.0)], ["line_2"], group="line", at=13),
    node("bag_4", N, "Bigger Bag IV", 6000, [("net_hold", "add", 10)], ["bag_3"], group="bag", at=19),
    node("mouth_1", N, "Wide Mouth I", 9000, [("net_radius", "add", 0.4)], ["line_3"], group="mouth", at=20.5),
    node("pull_3", N, "Iron Pull", 16000, [("net_power", "set", 3)], ["pull_2"], tags=["unlock"], group="pull", at=22),
    node("line_4", N, "Longer Line IV", 14000, [("net_range", "add", 10.7), ("reel", "add", 5.0)], ["line_3"], group="line", at=25),
    node("bag_5", N, "Bigger Bag V", 17000, [("net_hold", "add", 14)], ["bag_4"], group="bag", at=28),
    node("mouth_2", N, "Wide Mouth II", 27000, [("net_radius", "add", 0.6)], ["mouth_1"], group="mouth", at=34),
    node("pull_4", N, "Titan Pull", 24000, [("net_power", "set", 4)], ["pull_3"], tags=["unlock"], group="pull", at=32),
    node("bank_reach", N, "Bank Reach", 34000, [("net_range", "add", 3.0), ("reel", "add", 8.0)], ["line_4"],
         tags=["keystone"], group="line", desc="Past the water's edge: the strand and beach litter come within a cast, and the reel flies. Line IV already reaches all the water, so nobody can be locked out by this price.", at=37),
    node("trawl", N, "Trawl Mouth", 40000, [("net_radius", "add", 2.0)], ["mouth_2"], tags=["keystone"], group="mouth",
         desc="A mouth wide enough to sweep the last stragglers out of thin water.", at=41),

    # ---- dog: a helper, judged by what it takes off the player's hands rather than by income
    node("dog", D, "Adopt the Dog", 700, [("dog", "set", 1)], ["bag_2"], tags=["unlock", "utility"], group="dog", at=7.5),
    node("fetch_1", D, "Good Fetch I", 1000, [("dog_fetch", "add", 1)], ["dog"], tags=U, group="fetch", at=12),
    node("nose", D, "Keen Nose", 2000, [("dog_wait_cut", "add", 3)], ["dog"], tags=U, group="nose", at=17.5),
    node("fetch_2", D, "Good Fetch II", 6000, [("dog_fetch", "add", 1)], ["fetch_1"], tags=U, group="fetch", at=26.5),
    node("leash", D, "Long Leash", 13000, [("dog_reach", "add", 6)], ["nose"], tags=U, group="leash",
         desc="The dog ranges twice as far from the island for light pieces.", at=35.5),
    node("beachcomber", D, "Beachcomber", 9000, [("dog_beach", "set", 0.85), ("dog_strand_speed", "set", 1.6)], ["fetch_2"],
         tags=["keystone", "utility"], group="beach", desc="The dog works the far bank on its own: strand runs first, and quicker.", at=39),
]

config = {
    "game": "Lake Cleanup", "currency": "sludge", "maxMinutes": 300, "startMoney": 50,
    "stats": stats, "derived": derived, "pools": pools, "flows": flows,
    "goal": current["goal"], "links": current["links"],
    "trees": ["net", "ferry", "dog"], "nodes": nodes,
    "bots": [
        {"id": "focused", "policy": "value", "thinkEvery": 5},
        {"id": "casual", "policy": "mixed", "noise": 0.15, "attention": 0.9,
         "offline": {"every": 600, "for": 240}, "thinkEvery": 20, "seeds": 3},
        {"id": "cheapest", "policy": "cheapest", "thinkEvery": 5},
    ],
    "targets": {"clearMinutes": {"focused": [50, 70], "casual": [100, 140]}, "unlockGapMin": [2, 15],
                "paybackCurve": [[0, 30], [10, 120], [30, 360], [60, 600]]},
}
json.dump(config, open("docs/progression/lake-tree.json", "w", encoding="utf8"), indent=1)
print(f"lake-tree.json: {len(nodes)} nodes, total cost {sum(n['cost'] for n in nodes):,}")
