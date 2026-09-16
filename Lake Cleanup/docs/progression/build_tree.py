"""Builds docs/progression/lake-tree.json: the upgrade tree on the calibrated lake model.

Run from the project root, after build_current.py:  python docs/progression/build_tree.py
Then price it to its schedule and check it:
    node ~/.claude/skills/incremental-progression/scripts/price_to_schedule.js docs/progression/lake-tree.json --out docs/progression/lake-tree.json
    node ~/.claude/skills/incremental-progression/scripts/run_sim.js docs/progression/lake-tree.json --out docs/progression/tree-report
    python docs/progression/check_tree.py

The lake itself (pools, catch, ferry and dog rates, k_* constants) is taken from current.json so
the two configs can never disagree about the world; only the upgrades differ.

Third pass, 2026-09-14 afternoon (grilled with Richard, after a full playtest): calibrated to that
run, a real clear of about 70 min that spends down to near zero, more ferry capacity late, the dog
very cheap and first (the net's first ring needs it), pigeons from Heavy Lift on, reel and width a
quarter stronger, Fast Reel in place of Bank Reach.

Second pass, 2026-09-14 (grilled with Richard): a focused clear of about 90 minutes; buys brisk at
the start and slowing through the run; the boats nearly keep up with the box; the dog is a
mid-game system; the net is rings of Line / Bag / Mouth (and a luck slot) joined by the strength
nodes, each needing any two of its ring; Lucky Haul and Double Cast in the rings, the Recycle
Bonus on the ferry, the Pigeons in a Bonus tree of their own.

`ORDER` is the purchase order the design intends for a focused player. Each node's `at` minute
comes from walking that order along `GAP_CURVE`, so the schedule is the brisk-then-slower pace
itself rather than a column of guessed minutes, and price_to_schedule.js prices towards it.
"""
import json

current = json.load(open("docs/progression/current.json", encoding="utf8"))
cal = json.load(open("docs/progression/calibration.json", encoding="utf8"))

# ---- the world, minus the skimmer (cut from the design, 2026-09-12)
stats = {k: v for k, v in current["stats"].items() if k not in ("skimmer",)}
stats.update({
    # "Both a bit" (2026-09-14): a slightly better net to start with, and a cheap first ring.
    "net_range": 4.4,       # was 3.4: the first casts reach past the shelf into rubbish
    "net_hold": 4,          # was 3
    "reel": 6.0,            # was 2.4, then 3 (Richard, 2026-09-14: "reel speed needs to be much improved")
    "boats": 0,             # net only at the start; the first ferry is the first purchase
    "boat_speed": 8.0,      # was 4.2: a mixed load laps every yard, 58 s at 4.2 (measured)
    "cargo": 28,            # was 18: with speed 8, about 0.8 pieces a second, the opening net's pace
    "dog": 0,               # adopted through the tree
    "dog_beach": 0.35,      # Dog.STRAND_ODDS: share of trips to the strand while near pieces remain
    "dog_strand_speed": 1.0,
    "dog_reach": stats.get("k_dog_reach", 6),
    # Luck, the bonus and the pigeons (the shop's market tracks, as tree stats)
    "lucky_odds": 0.0,
    "double_odds": 0.0,
    "recycle_bonus": 0.0,
    "bird_worth": 1.0,
    "bird_bonus": 26.0,             # EconomyConfig.bird_bonus
    "k_lucky_extra": 4,             # Lake.LUCKY_EXTRA
    "k_double_found": cal.get("k_double_found", 1.0),  # measured on a fresh lake; scaled by density below
    "k_bonus_share": 0.25,          # ESTIMATE: one yard of four is boosted, so about a quarter of sales
    "k_bird_swept": 0.0015,         # measured: birds a cast takes per swept tile, not aimed at
    "k_bird_aim": 3.0,              # ESTIMATE: a player nets birds on purpose about three times as often
    # The first tiles out from where the angler stands are nearly empty (the shelf, and the
    # thin inner rings of the fill): the probe's bare net caught 1.0 a cast with a hold of 3, and
    # the playtest 1.5. Swept length only counts past this.
    "k_shelf": 2.5,
    # The lake is an ellipse with a wobbling bank, so a ring model of range under-counts what a
    # throw has to cover: tools/probe_reach.gd measured the farthest shore at 35.6 tiles from
    # anywhere the angler can stand (mean 29.0), where the ring model reaches the bank at
    # k_lake_r - k_island_r = 27.3. Range counts towards coverage at that ratio, so the model
    # covers the whole lake exactly when the net reaches the farthest shore.
    "k_reach_far": 35.6,
    # Fitted to the 2026-09-14 12:36 playtest by replay_playtest.py (third pass): with the purchases
    # replayed at their real seconds, the model cleared the lake at 71.9 min against the real 51.9.
    # Catch at 1.7x puts the model's clear at 53.9 (rms 0.03 of the lake over the run). Ferries fit at
    # 1.0: at that the model's box already runs heavier than play's late, so box checks err safe.
    "k_catch_scale": 1.7,
    "k_ferry_scale": 1.0,
})

derived = []
for name, expr in current["derived"]:
    if name.startswith("skim") or name in ("trips", "avg_lot", "dog_rate", "catch_rate"):
        continue
    derived.append([name, expr.replace("k_dog_reach", "dog_reach")])
derived = [[n, "2 * mouth * max(0, cast_dist - k_shelf) + (cast_dist > k_shelf ? PI * mouth ^ 2 : 0)"] if n == "swept" else [n, e]
           for n, e in derived]
ring_range = "(net_range * (k_lake_r - k_island_r) / k_reach_far)"
derived = [[n, e.replace("net_range", ring_range)] if n in ("coverage", "strand_reach") else [n, e] for n, e in derived]
derived = [[n, f"k_ferry_scale * ({e})"] if n == "ferry_rate" else [n, e] for n, e in derived]
derived += [
    # A lucky cast holds k_lucky_extra more and finds more to lift; a double cast throws a second
    # net with its own hold at nearby water, found as often as the water is still dense.
    ["access_lucky", next(e for n, e in current["derived"] if n == "access_now").replace("(net_power >= ", "(net_power + 1 >= ")],
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
    next(f for f in current["flows"] if f["id"] == "catch"),
    {"id": "dog", "label": "dog fetch", "from": [{"pool": "lake_t0", "share": "dog_coverage"}], "to": "box",
     "rate": "dog_rate * (1 - dog_beach_share)"},
    {"id": "dog_beach", "label": "dog strand runs", "from": ["strand"], "to": "box",
     "rate": "dog_rate * dog_beach_share * dog_strand_speed"},
    next(f for f in current["flows"] if f["id"] == "ferry"),
    {"id": "birds", "label": "pigeons netted", "from": ["flock"], "to": "purse", "rate": "bird_rate", "active": True},
]
pools = dict(current["pools"])
pools["pier"] = {"units": 0, "sell": True, "payMult": "1 + recycle_bonus * k_bonus_share"}
pools["flock"] = {"units": "inf", "value": "bird_bonus * bird_worth"}
pools["purse"] = {"units": 0, "sell": True}
goal = {"pools": ["lake_t0", "lake_t1", "lake_t2", "lake_t3", "lake_t4", "strand"], "clearAt": 0.995}


def node(id, tree, name, cost, effects, parents=(), tags=(), group=None, require_all=False, require=0, desc="", fixed=False):
    n = {"id": id, "tree": tree, "group": group or tree, "name": name, "cost": cost,
         "parents": list(parents), "effects": [{"stat": s, op: v} for s, op, v in effects], "tags": list(tags)}
    if require_all:
        n["requireAll"] = True
    if require:
        n["requireCount"] = require
    if desc:
        n["desc"] = desc
    if fixed:
        n["fixedCost"] = True
    return n


N, F, D, B = "net", "ferry", "dog", "bonus"
U = ["utility"]
nodes = [
    # ---- ferry: cheap to start, and deep enough late (Hull IV-V, Sails IV) to carry Titan Pull's catch
    node("ferry_1", F, "First Ferry", 50, [("boats", "set", 1)], tags=["unlock"], group="fleet", fixed=True,
         desc="The first purchase: a boat to carry the catch to the piers. Starting money covers it."),
    node("hull_1", F, "Deeper Hull I", 120, [("cargo", "add", 6)], ["ferry_1"], group="hull"),
    node("sails_1", F, "Trim Sails I", 200, [("boat_speed", "add", 2.0)], ["ferry_1"], group="sails"),
    node("hull_2", F, "Deeper Hull II", 700, [("cargo", "add", 8)], ["hull_1"], group="hull"),
    node("sails_2", F, "Trim Sails II", 1200, [("boat_speed", "add", 3.0)], ["sails_1"], group="sails"),
    node("ferry_2", F, "Second Ferry", 2000, [("boats", "add", 1)], ["hull_1"], tags=["unlock"], group="fleet"),
    node("recycle_1", F, "Recycle Bonus I", 1500, [("recycle_bonus", "add", 0.3)], ["sails_1"], tags=["unlock"], group="recycle",
         desc="One yard at a time pays over the odds, and the bonus moves every 30 seconds. Watch for the shining box."),
    node("hull_3", F, "Deeper Hull III", 5000, [("cargo", "add", 12)], ["hull_2"], group="hull"),
    node("recycle_2", F, "Recycle Bonus II", 6000, [("recycle_bonus", "add", 0.5)], ["recycle_1"], group="recycle"),
    node("ferry_3", F, "Third Ferry", 9000, [("boats", "add", 1)], ["ferry_2"], tags=["unlock"], group="fleet"),
    node("sails_3", F, "Trim Sails III", 12000, [("boat_speed", "add", 4.0)], ["sails_2"], group="sails"),
    node("recycle_3", F, "Recycle Bonus III", 20000, [("recycle_bonus", "add", 0.7)], ["recycle_2"], group="recycle"),
    node("hull_4", F, "Deeper Hull IV", 16000, [("cargo", "add", 14)], ["hull_3"], group="hull"),
    node("sails_4", F, "Trim Sails IV", 22000, [("boat_speed", "add", 5.0)], ["sails_3"], group="sails"),
    node("hull_5", F, "Deeper Hull V", 28000, [("cargo", "add", 16)], ["hull_4"], group="hull"),

    # ---- dog: very cheap, the second buy, and the net's first ring needs it (Richard, 2026-09-14,
    # third pass). Its training is gated by the strength nodes so it spreads through the run.
    node("dog", D, "Adopt the Dog", 100, [("dog", "set", 1)], ["ferry_1"], tags=["unlock", "utility"], group="dog", fixed=True,
         desc="A dog for the island. It fetches light rubbish near the shore, and the net's upgrades start with it."),
    node("fetch_1", D, "Good Fetch I", 5000, [("dog_fetch", "add", 1)], ["dog", "pull_1"], require_all=True, tags=U, group="fetch"),
    node("nose", D, "Keen Nose", 7000, [("dog_wait_cut", "add", 3)], ["dog", "pull_2"], require_all=True, tags=U, group="nose"),
    node("fetch_2", D, "Good Fetch II", 12000, [("dog_fetch", "add", 1)], ["fetch_1", "pull_2"], require_all=True, tags=U, group="fetch"),
    node("leash", D, "Long Leash", 22000, [("dog_reach", "add", 6)], ["nose", "pull_3"], require_all=True, tags=U, group="leash",
         desc="The dog ranges twice as far from the island for light pieces."),
    node("beachcomber", D, "Beachcomber", 16000, [("dog_beach", "set", 0.85), ("dog_strand_speed", "set", 1.6)], ["fetch_2", "pull_3"],
         require_all=True, tags=["keystone", "utility"], group="beach", desc="The dog works the far bank on its own: strand runs first, and quicker."),

    # ---- net: rings of Line / Bag / Mouth (and a luck slot), each joined by a strength node.
    # Reel is not only the Lines' (2026-09-14, Richard: "much improved, scattered around other
    # upgrades"): the base doubled to 6, every strength node adds 1.5-3 and every luck slot 1.
    # Reel and width are a quarter stronger than the second pass (Richard, third pass).
    # Ring 0
    node("line_1", N, "Longer Line I", 100, [("net_range", "add", 2.5), ("reel", "add", 1.25)], ["dog"], group="line",
         desc="Casts clear the rubbish-free shelf round the island and land in real water."),
    node("bag_1", N, "Bigger Bag I", 150, [("net_hold", "add", 2)], ["dog"], group="bag"),
    node("mouth_1", N, "Wide Mouth I", 250, [("net_radius", "add", 0.25)], ["dog"], group="mouth"),
    node("pull_1", N, "Stronger Pull", 700, [("net_power", "set", 1), ("reel", "add", 1.5)], ["line_1", "bag_1", "mouth_1"], require=2,
         tags=["unlock"], group="pull", desc="Lifts tier 1: a quarter of the lake that was dead weight becomes catch. Needs any two of the ring before it."),
    # Ring 1
    node("line_2", N, "Longer Line II", 900, [("net_range", "add", 5.0), ("reel", "add", 1.9)], ["pull_1"], group="line"),
    node("bag_2", N, "Bigger Bag II", 1100, [("net_hold", "add", 2)], ["pull_1"], group="bag"),
    node("mouth_2", N, "Wide Mouth II", 1400, [("net_radius", "add", 0.45)], ["pull_1"], group="mouth"),
    node("lucky_1", N, "Lucky Haul I", 1600, [("lucky_odds", "add", 0.15), ("reel", "add", 1.0)], ["pull_1"], group="luck",
         desc="Some casts are lucky: the net holds four more and lifts one tier heavier, that cast only. Shines gold."),
    node("pull_2", N, "Heavy Lift", 4000, [("net_power", "set", 2), ("reel", "add", 2.0)], ["line_2", "bag_2", "mouth_2", "lucky_1"], require=2,
         tags=["unlock"], group="pull", desc="Lifts tier 2. Needs any two of the ring before it."),
    # Ring 2
    node("line_3", N, "Longer Line III", 5000, [("net_range", "add", 9.0), ("reel", "add", 3.1)], ["pull_2"], group="line"),
    node("bag_3", N, "Bigger Bag III", 5500, [("net_hold", "add", 2)], ["pull_2"], group="bag"),
    node("mouth_3", N, "Wide Mouth III", 4000, [("net_radius", "add", 0.55)], ["pull_2"], group="mouth"),
    node("double_1", N, "Double Cast I", 8000, [("double_odds", "add", 0.1), ("reel", "add", 1.0)], ["pull_2"], group="double",
         desc="Some casts throw a second net at rubbish close by, with its own bag."),
    node("pull_3", N, "Iron Pull", 14000, [("net_power", "set", 3), ("reel", "add", 2.5)], ["line_3", "bag_3", "mouth_3", "double_1"], require=2,
         tags=["unlock"], group="pull", desc="Lifts tier 3. Needs any two of the ring before it."),
    # Ring 3
    node("line_4", N, "Longer Line IV", 16000, [("net_range", "add", 15.0), ("reel", "add", 3.75)], ["pull_3"], group="line",
         desc="Reaches every shore (the farthest is 35.6 tiles out), so nothing past here can lock a player out."),
    node("bag_4", N, "Bigger Bag IV", 17000, [("net_hold", "add", 2)], ["pull_3"], group="bag"),
    node("mouth_4", N, "Wide Mouth IV", 9000, [("net_radius", "add", 0.75)], ["pull_3"], group="mouth"),
    node("lucky_2", N, "Lucky Haul II", 12000, [("lucky_odds", "add", 0.15), ("reel", "add", 1.0)], ["pull_3"], group="luck"),
    node("pull_4", N, "Titan Pull", 30000, [("net_power", "set", 4), ("reel", "add", 3.0)], ["line_4", "bag_4", "mouth_4", "lucky_2"], require=2,
         tags=["unlock"], group="pull", desc="Lifts tier 4, the heaviest. Needs any two of the ring before it."),
    # Ring 4: the finish
    node("fast_reel", N, "Fast Reel", 20000, [("reel", "add", 10.0)], ["pull_4"], tags=["keystone"], group="line",
         desc="The late casts are long; this brings the net home in a fraction of the time."),
    node("bag_5", N, "Bigger Bag V", 36000, [("net_hold", "add", 3)], ["pull_4"], group="bag"),
    node("trawl", N, "Trawl Mouth", 40000, [("net_radius", "add", 1.25)], ["pull_4"], tags=["keystone"], group="mouth",
         desc="A mouth wide enough to sweep the last stragglers out of thin water."),
    node("double_2", N, "Double Cast II", 38000, [("double_odds", "add", 0.1), ("reel", "add", 1.0)], ["pull_4"], group="double"),

    # ---- bonus: the pigeons, from Heavy Lift on (Richard, third pass: later in the tree). Priced
    # as cheap extras (utility), because a netted bird is a small share of income whatever it pays.
    node("pigeons_1", B, "Pigeon Bounty I", 300, [("bird_worth", "add", 0.5)], ["pull_2"], tags=["unlock", "utility"], group="pigeons",
         desc="A netted pigeon pays more."),
    node("pigeons_2", B, "Pigeon Bounty II", 3000, [("bird_worth", "add", 0.6)], ["pigeons_1", "pull_3"], require_all=True, tags=U, group="pigeons"),
    node("pigeons_3", B, "Pigeon Bounty III", 10000, [("bird_worth", "add", 0.6)], ["pigeons_2", "pull_4"], require_all=True, tags=U, group="pigeons"),
    node("pigeons_4", B, "Pigeon Bounty IV", 15000, [("bird_worth", "add", 0.7)], ["pigeons_3"], tags=U, group="pigeons"),
]

# ---- the schedule: the order a focused player should buy in, walked along the gap curve
GAP_CURVE = [(0, 30), (10, 60), (30, 120), (60, 240), (90, 360)]  # (minute, seconds between buys), Richard's "brisk"
# The walk is then stretched so the last scheduled buy lands at LAST_BUY: a real clear of about
# 70 minutes (third pass) with the last stretch spent enjoying the full net.
LAST_BUY = 60.0


# The walk itself starts brisker than the checked curve: the opening is bought faster than a walk
# at 30 s would put it, and a walk that starts slow leaves a hole after it.
WALK_CURVE = [(0, 22), (10, 50), (30, 120), (60, 240), (90, 360)]


def gap_at(minute, curve=WALK_CURVE):
    for (m0, g0), (m1, g1) in zip(curve, curve[1:]):
        if minute <= m1:
            return g0 + (g1 - g0) * (minute - m0) / (m1 - m0)
    return curve[-1][1]


ORDER = [
    "ferry_1", "dog", "line_1", "bag_1", "hull_1", "sails_1", "mouth_1", "pull_1",
    "fetch_1", "line_2", "hull_2", "bag_2", "recycle_1", "sails_2", "mouth_2", "lucky_1", "ferry_2", "pull_2",
    "nose", "line_3", "bag_3", "hull_3", "sails_3", "recycle_2", "fetch_2", "double_1", "mouth_3", "ferry_3", "pull_3",
    "line_4", "leash", "bag_4", "hull_4", "lucky_2", "recycle_3", "beachcomber", "mouth_4", "pull_4",
    "double_2", "sails_4", "bag_5", "hull_5", "fast_reel", "trawl",
]
by_id = {n["id"]: n for n in nodes}
# The pigeons are bought off schedule (utility), but price_by_income.py still needs a minute to
# price them at: each a little after the strength node that opens it.
for id, minute in {"pigeons_1": 12, "pigeons_2": 26, "pigeons_3": 45, "pigeons_4": 52}.items():
    by_id[id]["priceAt"] = minute
UNSCHEDULED = {"pigeons_1", "pigeons_2", "pigeons_3", "pigeons_4"}
assert sorted(ORDER) == sorted(set(by_id) - UNSCHEDULED), set(ORDER) ^ (set(by_id) - UNSCHEDULED)
walk = []
t = 0.0
for id in ORDER:
    walk.append(t)
    t += gap_at(t) / 60.0
stretch = LAST_BUY / walk[-1]
for id, at in zip(ORDER, walk):
    if id not in ("ferry_1", "dog"):
        by_id[id]["at"] = round(at * stretch, 1)
t = walk[-1] * stretch

config = {
    "game": "Lake Cleanup", "currency": "sludge", "maxMinutes": 400, "startMoney": 50,
    "stats": stats, "derived": derived, "pools": pools, "flows": flows,
    "goal": goal, "links": [{"up": "catch", "down": "ferry", "band": [0.8, 1.5], "buffer": "box"}],
    "trees": ["net", "ferry", "dog", "bonus"], "nodes": nodes,
    "bots": [
        {"id": "focused", "policy": "value", "thinkEvery": 5},
        {"id": "casual", "policy": "mixed", "noise": 0.15, "attention": 0.9,
         "offline": {"every": 600, "for": 240}, "thinkEvery": 20, "seeds": 3},
        {"id": "cheapest", "policy": "cheapest", "thinkEvery": 5},
    ],
    # Third pass: a real clear of about 70 minutes. The sim is calibrated to the 2026-09-14 12:36
    # playtest (k_catch_scale), so the focused bot stands in for Richard's own pace.
    "targets": {"clearMinutes": {"focused": [60, 80], "casual": [115, 160]}, "unlockGapMin": [0, 25],
                "paybackCurve": [[0, 30], [10, 90], [30, 240], [60, 480], [90, 720]]},
    "gapCurve": GAP_CURVE,
}
json.dump(config, open("docs/progression/lake-tree.json", "w", encoding="utf8"), indent=1)
print(f"lake-tree.json: {len(nodes)} nodes, total cost {sum(n['cost'] for n in nodes):,}, schedule ends at {t:.0f} min")
