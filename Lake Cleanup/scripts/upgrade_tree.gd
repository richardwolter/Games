## The proposed upgrade tree, read straight from the progression simulator's config.
##
## Tree test mode (2026-09-12): a second way to play the lake, started from the main menu's
## "New game (tree)", so the tree can be played before it replaces the shop. The numbers are not
## copied into resources: this reads `docs/progression/lake-tree.json`, the same file the
## simulator and the tuner page use, so what is played is exactly what was simulated. See
## `docs/progression/lake-tree.md` for the design and why each node exists.
##
## A node is visible once any parent is owned (all of them, for `requireAll`; at least
## `requireCount` of them, when that is set — the net's strength nodes need any two of their
## ring), and roots are
## visible from the start. Stats are recomputed from the base values every time, never applied
## a purchase at a time: the largest `set` replaces the base, then every `add` is summed, then
## every `mul` multiplies. That is the simulator's rule, and it makes buy order irrelevant.
##
## Everything else in the file (pools, flows, `k_*` calibration constants, bots, targets) is the
## simulator's and is ignored here.
class_name UpgradeTree
extends RefCounted

const PATH := "res://docs/progression/lake-tree.json"

## The stats the lake reads off the tree. Anything a node changes that is not here does
## nothing in the game, and is reported once at load rather than silently ignored.
const GAME_STATS := [
	"net_radius", "net_power", "net_range", "reel", "net_hold",
	"boat_speed", "cargo", "boats",
	"dog", "dog_fetch", "dog_wait_cut", "dog_reach", "dog_beach", "dog_strand_speed",
	"lucky_odds", "double_odds", "recycle_bonus", "bird_worth",
]

var nodes: Array = []
var by_id: Dictionary = {}
## Node ids whose first-listed parent is this node, in file order.
var children: Dictionary = {}
var trees: PackedStringArray = PackedStringArray()
var base_stats: Dictionary = {}
var start_money: float = 0.0
var game_name: String = ""
## Empty when the file loaded cleanly. The lake refuses tree mode rather than half-running it.
var error: String = ""
## Stats a node changes that the game does not read. Shown once, in the log and the output.
var unused_stats: PackedStringArray = PackedStringArray()


static func load_file(path: String = PATH) -> UpgradeTree:
	var tree := UpgradeTree.new()
	if not FileAccess.file_exists(path):
		tree.error = "no tree file at %s" % path
		return tree
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		tree.error = "%s is not a JSON object" % path
		return tree
	tree._read(parsed as Dictionary)
	return tree


func _read(data: Dictionary) -> void:
	game_name = String(data.get("game", ""))
	start_money = float(data.get("startMoney", 0.0))
	base_stats = (data.get("stats", {}) as Dictionary).duplicate()
	for t: Variant in data.get("trees", []) as Array:
		trees.append(String(t))
	for raw: Variant in data.get("nodes", []) as Array:
		var n := (raw as Dictionary).duplicate(true)
		n["id"] = String(n.get("id", ""))
		n["tree"] = String(n.get("tree", "tree"))
		n["name"] = String(n.get("name", n["id"]))
		n["ranks"] = int(n.get("ranks", 1))
		n["parents"] = (n.get("parents", []) as Array).map(func(p: Variant) -> String: return String(p))
		n["tags"] = (n.get("tags", []) as Array).map(func(p: Variant) -> String: return String(p))
		n["requireAll"] = bool(n.get("requireAll", false))
		n["requireCount"] = int(n.get("requireCount", 0))
		if String(n["id"]).is_empty() or by_id.has(n["id"]):
			error = "a node has no id, or two share one (%s)" % n["id"]
			return
		nodes.append(n)
		by_id[n["id"]] = n
		children[n["id"]] = []
		if not trees.has(n["tree"]):
			trees.append(n["tree"])
	for n: Dictionary in nodes:
		for p: String in n["parents"]:
			if not by_id.has(p):
				error = "node %s has an unknown parent %s" % [n["id"], p]
				return
		if not (n["parents"] as Array).is_empty():
			(children[(n["parents"] as Array)[0]] as Array).append(n["id"])
		for e: Dictionary in n.get("effects", []) as Array:
			var stat := String(e.get("stat", ""))
			if not base_stats.has(stat):
				error = "node %s changes %s, which has no base value" % [n["id"], stat]
				return
			if not GAME_STATS.has(stat) and not unused_stats.has(stat):
				unused_stats.append(stat)
	for stat: String in GAME_STATS:
		if not base_stats.has(stat):
			error = "the tree has no base value for %s" % stat
			return


func rank_of(owned: Dictionary, id: String) -> int:
	return int(owned.get(id, 0))


func is_owned(owned: Dictionary, id: String) -> bool:
	return rank_of(owned, id) > 0


func is_maxed(owned: Dictionary, id: String) -> bool:
	return rank_of(owned, id) >= int(by_id[id]["ranks"])


## Shown on the tree: a root, or a node with its parents owned.
func is_visible(owned: Dictionary, id: String) -> bool:
	var parents: Array = by_id[id]["parents"]
	if parents.is_empty():
		return true
	var need := int(by_id[id]["requireCount"])
	if need > 0:
		var have := 0
		for p: String in parents:
			if is_owned(owned, p):
				have += 1
		return have >= need
	if by_id[id]["requireAll"]:
		for p: String in parents:
			if not is_owned(owned, p):
				return false
		return true
	for p: String in parents:
		if is_owned(owned, p):
			return true
	return false


## Visible and not yet bought to its last rank.
func is_buyable(owned: Dictionary, id: String) -> bool:
	return by_id.has(id) and is_visible(owned, id) and not is_maxed(owned, id)


## The price of the next rank.
func cost(owned: Dictionary, id: String) -> float:
	var n: Dictionary = by_id[id]
	var rank := rank_of(owned, id)
	var c: Variant = n.get("cost", 0.0)
	if c is Array:
		var list := c as Array
		return float(list[mini(rank, list.size() - 1)])
	return float(c) * pow(float(n.get("costMult", 1.0)), float(rank))


## Every stat, from the base values and what is owned.
func stats(owned: Dictionary) -> Dictionary:
	var sets := {}
	var adds := {}
	var muls := {}
	for id: String in owned:
		var rank := rank_of(owned, id)
		if rank <= 0 or not by_id.has(id):
			continue
		for e: Dictionary in by_id[id].get("effects", []) as Array:
			var stat := String(e["stat"])
			if e.has("set"):
				sets[stat] = maxf(float(sets.get(stat, -INF)), float(e["set"]))
			if e.has("add"):
				adds[stat] = float(adds.get(stat, 0.0)) + _sum(e["add"], rank)
			if e.has("mul"):
				muls[stat] = float(muls.get(stat, 1.0)) * _product(e["mul"], rank)
	var out := {}
	for stat: String in base_stats:
		var base := float(sets.get(stat, base_stats[stat]))
		out[stat] = (base + float(adds.get(stat, 0.0))) * float(muls.get(stat, 1.0))
	return out


## What the stats would be with one more rank of `id`.
func stats_with(owned: Dictionary, id: String) -> Dictionary:
	var more := owned.duplicate()
	more[id] = rank_of(owned, id) + 1
	return stats(more)


## Ids that were saved but are no longer in the file are dropped, and ranks are held to what
## the node now sells. A tuning pass that renames or removes a node must not break a test run.
func sanitize(owned: Dictionary) -> Dictionary:
	var out := {}
	for id: Variant in owned:
		var key := String(id)
		if by_id.has(key):
			out[key] = clampi(int(owned[id]), 0, int(by_id[key]["ranks"]))
	return out


func _sum(v: Variant, rank: int) -> float:
	if v is Array:
		var list := v as Array
		var s := 0.0
		for i in rank:
			s += float(list[mini(i, list.size() - 1)])
		return s
	return float(v) * float(rank)


func _product(v: Variant, rank: int) -> float:
	if v is Array:
		var list := v as Array
		var p := 1.0
		for i in rank:
			p *= float(list[mini(i, list.size() - 1)])
		return p
	return pow(float(v), float(rank))
