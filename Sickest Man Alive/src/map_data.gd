class_name MapData
extends RefCounted

## The run's floor, as pure data. No nodes, no scenes, no side effects --
## so it can be generated and inspected headlessly, and a bad seed is
## reproducible instead of a ghost story.
##
## The layout itself is fixed: it is a body (see BodyPlan). What the seed
## decides is where you break in, where the infection nested, and which
## parts hold supplies. Randomness is placement, not shape -- the shape is
## the point.

enum RoomKind { START, COMBAT, ITEM, BOSS }

## Which infection is nesting in a given boss room. The room KIND says there is a
## boss; this says which one, and it is recorded per room rather than held in a
## parallel list so it cannot fall out of step with `kind == BOSS`.
enum BossKind { WORM, CAN, FUNGUS }

const DIRS: Dictionary = {
	"n": Vector2i(0, -1),
	"s": Vector2i(0, 1),
	"w": Vector2i(-1, 0),
	"e": Vector2i(1, 0),
}
const OPPOSITE: Dictionary = {"n": "s", "s": "n", "w": "e", "e": "w"}

## Room footprints, in world units. Size is data, not scene setup, so a bad
## layout is inspectable headlessly like everything else here.
const CHAMBER_SIZE: Vector2 = Vector2(1180.0, 620.0)
const CAVERN_SIZE: Vector2 = Vector2(1560.0, 900.0)
## A lane is the same room stretched along whichever axis you walk it.
const LANE_LONG: float = 1700.0
const LANE_SHORT: float = 440.0

## cell -> {id, name, color, region, kind, exits, cleared, seen, depth, item}
##
## `exits` is an Array of link records, one per doorway:
##   link   canonical link id, the door's identity for the whole run
##   to     destination CELL. Never recomputed from cell + DIRS
##   to_id  destination part id
##   dir    which wall the doorway is in
##   slot   index among the doors sharing that wall
##   count  how many doors share that wall
##   label  destination display name
##   hint   BodyPlan.Hint
var rooms: Dictionary = {}
var start_cell: Vector2i = Vector2i.ZERO
## Every room holding an infection, in draw order -- `boss_cells[0]` is the
## deepest and is the one that keeps the original "nests at the far end" rule.
##
## Deliberately not a scalar plus a list, and deliberately with no `boss_cell`
## compatibility accessor: a shim returning the first one type-checks everywhere
## and is silently wrong in exactly the places that matter. The fork sweep in
## tools/test_floor.gd would then prove one of three bosses unsealable and pass a
## map that sealed another away, and the rampage gate would open with two of them
## still alive. A green test that has stopped testing the thing is worse than a
## compile error, so the old name is gone and the parser finds every caller.
var boss_cells: Array[Vector2i] = []
var seed_used: int = 0

## The roads not taken. Filled in as the player commits to fork branches and
## never emptied -- a sealed branch is sealed for the run.
var sealed_links: Dictionary = {}   ## link id -> true
var sealed_cells: Dictionary = {}   ## Vector2i -> true
var forks_taken: Dictionary = {}    ## fork "from" id -> the branch chosen

## Fraction of the reachable combat rooms that must be dead before the body
## notices. Paired with killing the infection, not instead of it: the boss is
## the point of the run, and a sweep of every last dead end is a chore rather
## than an ending.
const RAMPAGE_CLEAR_FRACTION: float = 0.70

## How deep the infection may nest: at least this many rooms in, and in the far
## end of whatever the deepest candidate turned out to be.
const BOSS_MIN_DEPTH: int = 8
const BOSS_DEPTH_SHARE: float = 0.6

## How many infections a run holds. Drawn before any cell is picked, so the count
## is a property of the seed rather than of wherever the placement loop happened
## to run out of room.
const BOSS_COUNT_MIN: int = 2
const BOSS_COUNT_MAX: int = 3

## Minimum depth gap between two infections.
##
## Written on DEPTH rather than on a second breadth-first search between
## candidates, because depth is already the BFS distance from the entry -- so by
## the triangle inequality `abs(depth(a) - depth(b))` is a lower bound on the
## walk between them. It reuses numbers `_compute_depths` has already produced,
## and it can only ever be conservative: it never claims two rooms are further
## apart than they are. Two bosses in adjacent organs read as one long fight
## rather than as two, which is the whole thing this prevents.
const BOSS_MIN_DEPTH_GAP: int = 3


static func generate(rng_seed: int = 0, item_room_count: int = 4) -> MapData:
	var m := MapData.new()
	var rng := RandomNumberGenerator.new()
	m.seed_used = rng_seed if rng_seed != 0 else randi()
	rng.seed = m.seed_used

	for id: String in BodyPlan.PARTS:
		var part: Dictionary = BodyPlan.PARTS[id]
		m.rooms[part["cell"]] = {
			"id": id,
			"name": part["name"],
			"color": part["color"],
			"region": part["region"],
			"kind": RoomKind.COMBAT,
			## Which infection nests here, meaningful only where `kind` is BOSS.
			## Present on every room so no reader needs a `has()` guard.
			"boss": BossKind.WORM,
			"exits": [],
			"cleared": false,
			"seen": false,
			"depth": 0,
			## Item rooms get their pedestal contents fixed at generation, so
			## leaving and coming back cannot reroll the drop. Two entries: the
			## room offers a choice, and taking either clears the whole list.
			"items": [] as Array[Item],
			"shape": BodyPlan.shape_of(id),
			## Every pool of blood spilled on this floor, in room-local space.
			## Kept on the MAP and not on the Room, because the Room is thrown
			## away and rebuilt from the seed every time you walk through the
			## door -- and the whole point of the pools is that a room you
			## fought in still looks fought in on the way back.
			"blood": [] as Array,
			## Uncollected DNA lying on this floor, room-local. Kept here for
			## the same reason the blood is: the Room is rebuilt from the seed
			## every time you walk in, and DNA you did not pick up must still be
			## there when you come back for it.
			"dna": [] as Array,
			## Filled in below: a lane's orientation is read off its doorways,
			## which do not exist yet.
			"size": CHAMBER_SIZE,
		}

	m._build_exits()

	for cell: Vector2i in m.rooms:
		m.rooms[cell]["size"] = m._size_of_cell(cell)

	# You wake up in an extremity.
	var entries := BodyPlan.ENTRY_POINTS
	var start_id: String = entries[rng.randi_range(0, entries.size() - 1)]
	m.start_cell = BodyPlan.cell_of(start_id)
	m.rooms[m.start_cell]["kind"] = RoomKind.START
	m.rooms[m.start_cell]["cleared"] = true

	m._compute_depths()

	# The infection nests as far from the wound as the body allows. Any room may
	# hold it, with one exception that is not negotiable: it must not be inside a
	# fork branch, or the player can seal it away and the run becomes
	# unfinishable -- which is exactly what BodyPlan.is_spine tests.
	#
	# Measured from THIS run's entry, not from a fixed list of organs. With nine
	# ways in, "deep" is no longer a property of the body -- a run that starts in
	# an ear has the pelvis at the far end, and a run from a foot has the skull.
	# The old fixed candidate list could not express that and put the boss in one
	# of the same six organs every time.
	var best_depth := -1
	for cell: Vector2i in m.rooms:
		if cell == m.start_cell or not BodyPlan.is_spine(m.rooms[cell]["id"]):
			continue
		best_depth = maxi(best_depth, m.rooms[cell]["depth"])
	# A band at the far end rather than the single furthest room, so the seed
	# still has a say and the deepest boss is not in the same place for a given
	# entry.
	var floor_depth := maxi(mini(BOSS_MIN_DEPTH, best_depth),
		int(ceil(float(best_depth) * BOSS_DEPTH_SHARE)))

	# Everywhere an infection may legally nest, at any depth. Sorted before any
	# draw: iteration order over a Dictionary is not something to bet a seeded
	# run's reproducibility on, and there are three draws riding on it now.
	var eligible: Array[Vector2i] = []
	for cell: Vector2i in m.rooms:
		if cell == m.start_cell or not BodyPlan.is_spine(m.rooms[cell]["id"]):
			continue
		if m.rooms[cell]["depth"] >= BOSS_MIN_DEPTH:
			eligible.append(cell)
	eligible.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y)

	var wanted := rng.randi_range(BOSS_COUNT_MIN, BOSS_COUNT_MAX)
	m.boss_cells = m._draw_bosses(rng, eligible, wanted, floor_depth)
	# Kinds dealt from a bag rather than rolled per boss. Independent rolls hand
	# a three-boss run the same fight three times about one run in nine, which is
	# precisely the outcome having three of them exists to avoid.
	var bag: Array[BossKind] = [BossKind.WORM, BossKind.CAN, BossKind.FUNGUS]
	for i in range(bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := bag[i]
		bag[i] = bag[j]
		bag[j] = swap
	for i in m.boss_cells.size():
		var cell: Vector2i = m.boss_cells[i]
		m.rooms[cell]["kind"] = RoomKind.BOSS
		m.rooms[cell]["boss"] = bag[i % bag.size()]

	m._place_caches(rng, item_room_count)
	m._apply_hints()
	return m


## Picks where the infections nest: the first at the far end of the walk, the
## rest spread back down it.
##
## The deepest one keeps the original rule exactly -- drawn from the rooms past
## `floor_depth` -- so the premise that the infection is at the end of the
## journey survives having several of them.
##
## The others are banded, for the reason `_place_caches` is banded: uniform
## random over a spine that is mostly torso clusters them, and three bosses in
## neighbouring organs is one long fight rather than three. Each band also has to
## clear `BOSS_MIN_DEPTH_GAP` of every boss already placed.
##
## Returns fewer than `wanted` rather than looping until it finds room. A run
## with two infections is finishable and a loop that cannot terminate is not --
## a lopsided entry genuinely can leave nowhere legal for a third.
func _draw_bosses(rng: RandomNumberGenerator, eligible: Array[Vector2i],
		wanted: int, floor_depth: int) -> Array[Vector2i]:
	var chosen: Array[Vector2i] = []
	if eligible.is_empty() or wanted <= 0:
		return chosen

	var deep: Array[Vector2i] = []
	for cell in eligible:
		if rooms[cell]["depth"] >= floor_depth:
			deep.append(cell)
	if deep.is_empty():
		deep = eligible
	chosen.append(deep[rng.randi_range(0, deep.size() - 1)])

	# The rest share the walk from BOSS_MIN_DEPTH up to the deepest one's band,
	# one per slice, shallowest slice first.
	var remaining := wanted - 1
	if remaining <= 0:
		return chosen
	var span := maxi(floor_depth - BOSS_MIN_DEPTH, 1)
	var band := float(span) / float(remaining)
	for i in remaining:
		var low := BOSS_MIN_DEPTH + int(floor(band * i))
		var high := BOSS_MIN_DEPTH + int(floor(band * (i + 1)))
		var in_band: Array[Vector2i] = []
		for cell in eligible:
			var d: int = rooms[cell]["depth"]
			if d < low or (d >= high and i < remaining - 1):
				continue
			if _boss_spaced(cell, chosen):
				in_band.append(cell)
		if in_band.is_empty():
			continue
		chosen.append(in_band[rng.randi_range(0, in_band.size() - 1)])

	# Bands come up short on a lopsided entry, the same way the cache bands do.
	# Backfill from anything still legal so the count is honoured where it can be.
	while chosen.size() < wanted:
		var left: Array[Vector2i] = []
		for cell in eligible:
			if _boss_spaced(cell, chosen):
				left.append(cell)
		if left.is_empty():
			break
		chosen.append(left[rng.randi_range(0, left.size() - 1)])
	return chosen


## Whether `cell` is far enough from every boss already placed. See
## BOSS_MIN_DEPTH_GAP for why this is measured on depth.
func _boss_spaced(cell: Vector2i, chosen: Array[Vector2i]) -> bool:
	if chosen.has(cell):
		return false
	var d: int = rooms[cell]["depth"]
	for other: Vector2i in chosen:
		if absi(d - int(rooms[other]["depth"])) < BOSS_MIN_DEPTH_GAP:
			return false
	return true


## Whether this room holds an infection. The replacement for every
## `cell == boss_cell` test the singular field used to support.
func is_boss(cell: Vector2i) -> bool:
	return boss_cells.has(cell)


## Which infection is in this room. Defaults to the original worm rather than
## erroring: a room that is somehow BOSS without a kind should still be a fight.
func boss_kind_of(cell: Vector2i) -> BossKind:
	return rooms[cell].get("boss", BossKind.WORM) as BossKind


func boss_count() -> int:
	return boss_cells.size()


func bosses_killed() -> int:
	var done := 0
	for cell: Vector2i in boss_cells:
		if is_cleared(cell):
			done += 1
	return done


## What each doorway advertises. Read off what is actually on the other side
## rather than written into the link table: a cache pip that does not mean a
## cache is worse than no pip, and the contents are not known until placement
## has run.
func _apply_hints() -> void:
	for cell: Vector2i in rooms:
		for e: Dictionary in rooms[cell]["exits"]:
			match kind_of(e["to"]):
				RoomKind.ITEM:
					e["hint"] = BodyPlan.Hint.CACHE
				RoomKind.BOSS:
					e["hint"] = BodyPlan.Hint.HAZARD
				RoomKind.COMBAT:
					e["hint"] = BodyPlan.Hint.COMBAT
				_:
					e["hint"] = BodyPlan.Hint.NONE


## Turns BodyPlan.LINKS into two directed doorway records per link, then works
## out where on its wall each one sits.
##
## Slotting is deliberately seed-independent: two runs of the same body must put
## the same door in the same place, or a room's geometry becomes a thing the
## player cannot learn. Doors on a wall are ordered by where their destination
## sits on the minimap, so the door that looks like the upper one is the upper
## one.
func _build_exits() -> void:
	for link: Dictionary in BodyPlan.LINKS:
		var a: String = link["a"]
		var b: String = link["b"]
		var a_dir: String = link["a_dir"]
		var id := BodyPlan.link_id(a, b)
		_add_exit(a, b, a_dir, id)
		_add_exit(b, a, OPPOSITE[a_dir], id)

	for cell: Vector2i in rooms:
		_slot_exits(cell)


func _add_exit(from_id: String, to_id: String, dir: String, id: String) -> void:
	var cell := BodyPlan.cell_of(from_id)
	rooms[cell]["exits"].append({
		"link": id,
		"to": BodyPlan.cell_of(to_id),
		"to_id": to_id,
		"dir": dir,
		"slot": 0,
		"count": 1,
		"label": BodyPlan.PARTS[to_id]["name"] as String,
		"hint": BodyPlan.Hint.NONE,
	})


func _slot_exits(cell: Vector2i) -> void:
	var by_dir: Dictionary = {}
	for e: Dictionary in rooms[cell]["exits"]:
		by_dir.get_or_add(e["dir"], []).append(e)

	for dir: String in by_dir:
		var group: Array = by_dir[dir]
		# Along-wall order: x for the top and bottom walls, y for the sides.
		var horizontal := dir == "n" or dir == "s"
		group.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
			var pk: int = p["to"].x if horizontal else p["to"].y
			var qk: int = q["to"].x if horizontal else q["to"].y
			if pk != qk:
				return pk < qk
			return p["to_id"] < q["to_id"]
		)
		for i in group.size():
			group[i]["slot"] = i
			group[i]["count"] = group.size()


## Caches are placed one per depth band, not at random across the floor.
## Uniform random clusters -- three pedestals around the hips and nothing for
## the next eight rooms is a pacing failure, and it is the default outcome
## unless placement is banded like this.
func _place_caches(rng: RandomNumberGenerator, count: int) -> void:
	var candidates: Array[Vector2i] = []
	var max_depth := 0
	for cell: Vector2i in rooms:
		var id: String = rooms[cell]["id"]
		if cell == start_cell or is_boss(cell):
			continue
		if BodyPlan.NO_ITEM.has(id):
			continue
		candidates.append(cell)
		max_depth = maxi(max_depth, rooms[cell]["depth"])

	if candidates.is_empty() or count <= 0:
		return

	var placed := 0
	var band := float(max_depth + 1) / float(count)
	for i in count:
		var low := int(floor(band * i))
		var high := int(floor(band * (i + 1)))
		var in_band: Array[Vector2i] = []
		for cell in candidates:
			var d: int = rooms[cell]["depth"]
			if d >= low and (d < high or i == count - 1):
				in_band.append(cell)
		if in_band.is_empty():
			continue
		var pick: Vector2i = in_band[rng.randi_range(0, in_band.size() - 1)]
		_stock_cache(pick, candidates)
		placed += 1

	# Bands can come up short on a lopsided entry (a hand leaves few shallow
	# rooms). Backfill from whatever is left so the count is always honoured.
	while placed < count and not candidates.is_empty():
		var idx := rng.randi_range(0, candidates.size() - 1)
		_stock_cache(candidates[idx], candidates)
		placed += 1


## Marks a cache, and mirrors it into the matching room of every sibling branch
## if it landed inside a fork.
##
## Placement runs before the player has chosen anything, so an unmirrored cache
## inside a branch makes how many supplies a run yields depend on a coin flip
## nobody was present for. Mirrored, "cache that way" is never a trap and never
## a jackpot: the fork stays a choice about route and fight, and the pair costs
## one slot out of the budget rather than two.
func _stock_cache(cell: Vector2i, candidates: Array[Vector2i]) -> void:
	rooms[cell]["kind"] = RoomKind.ITEM
	candidates.erase(cell)

	var id: String = rooms[cell]["id"]
	var fork := _fork_containing(id)
	if fork.is_empty():
		return
	for branch: String in fork["branches"]:
		var members: Array = BodyPlan.branch_cells(branch)
		var index := members.find(id)
		if index >= 0:
			# Same branch. Every sibling gets the room at the same position along
			# it, which lines up because branches are the same length.
			for other: String in fork["branches"]:
				if other == branch:
					continue
				var twin: Array = BodyPlan.branch_cells(other)
				if index >= twin.size():
					continue
				var twin_cell := BodyPlan.cell_of(twin[index])
				# The mirror must not overwrite the rooms that are already spoken
				# for. It never could while entries were limb tips, which are in
				# no fork -- but an entry inside a branch (an ear, the nose, the
				# rectum) has a sibling that a cache can land on, and the mirror
				# would then stamp ITEM over START and leave the run beginning in
				# a cache with no start room anywhere.
				#
				# The boss half of this test is the same bug with worse
				# consequences: stamping ITEM over a BOSS room deletes an
				# infection from a run that cannot then be finished, on whatever
				# rare seed puts a boss in a fork sibling of a cache.
				if twin_cell == start_cell or is_boss(twin_cell):
					continue
				rooms[twin_cell]["kind"] = RoomKind.ITEM
				candidates.erase(twin_cell)
			return


func _fork_containing(id: String) -> Dictionary:
	for fork: Dictionary in BodyPlan.FORKS:
		for branch: String in fork["branches"]:
			if BodyPlan.branch_cells(branch).has(id):
				return fork
	return {}


## Breadth-first, because Manhattan distance lies on a body: a hand is four
## cells from the chest but sits right beside the opposite shoulder on the
## grid. Depth is walking distance, and it drives enemy scaling.
func _compute_depths() -> void:
	for cell: Vector2i in rooms:
		rooms[cell]["depth"] = -1
	rooms[start_cell]["depth"] = 0
	var queue: Array[Vector2i] = [start_cell]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for e: Dictionary in all_exits_of(cell):
			var n: Vector2i = e["to"]
			if rooms.has(n) and rooms[n]["depth"] < 0:
				rooms[n]["depth"] = rooms[cell]["depth"] + 1
				queue.append(n)


## A lane runs along the axis you actually walk it, which the doorways already
## say: a shin opens north and south, a forearm east and west. Reading it off the
## exits rather than hardcoding per part means a new row in BodyPlan gets the
## right shape for free.
##
## Only a joint like a thigh opens on both axes; those fall back to the region,
## because a leg is a leg however it happens to connect.
func _lane_is_horizontal(cell: Vector2i) -> bool:
	var horizontal := 0
	var vertical := 0
	for dir: String in exit_dirs_of(cell):
		if dir == "w" or dir == "e":
			horizontal += 1
		else:
			vertical += 1
	if horizontal > 0 and vertical == 0:
		return true
	if vertical > 0 and horizontal == 0:
		return false
	return (rooms[cell]["region"] as BodyPlan.Region) == BodyPlan.Region.ARM


func _size_of_cell(cell: Vector2i) -> Vector2:
	match rooms[cell]["shape"] as BodyPlan.RoomShape:
		BodyPlan.RoomShape.CAVERN:
			return CAVERN_SIZE
		BodyPlan.RoomShape.LANE:
			return Vector2(LANE_LONG, LANE_SHORT) if _lane_is_horizontal(cell) \
				else Vector2(LANE_SHORT, LANE_LONG)
		_:
			return CHAMBER_SIZE


func shape_of(cell: Vector2i) -> BodyPlan.RoomShape:
	return rooms[cell]["shape"] as BodyPlan.RoomShape


func size_of(cell: Vector2i) -> Vector2:
	return rooms[cell]["size"] as Vector2


func has_room(cell: Vector2i) -> bool:
	return rooms.has(cell)


func kind_of(cell: Vector2i) -> RoomKind:
	return rooms[cell]["kind"] as RoomKind


func name_of(cell: Vector2i) -> String:
	return rooms[cell]["name"] as String


func color_of(cell: Vector2i) -> Color:
	return rooms[cell]["color"] as Color


func region_of(cell: Vector2i) -> BodyPlan.Region:
	return rooms[cell]["region"] as BodyPlan.Region


func id_of(cell: Vector2i) -> String:
	return rooms[cell]["id"] as String


## The doorways a player can actually use from here. A sealed one is not a
## locked door -- it is not built at all, and the wall is solid.
func exits_of(cell: Vector2i) -> Array:
	if sealed_links.is_empty():
		return rooms[cell]["exits"] as Array
	var out: Array = []
	for e: Dictionary in rooms[cell]["exits"]:
		if not sealed_links.has(e["link"]):
			out.append(e)
	return out


func is_sealed_cell(cell: Vector2i) -> bool:
	return sealed_cells.has(cell)


## Locks in a fork choice. Called with whatever room the player just walked into;
## does nothing unless that room is a branch entrance, and nothing the second
## time for the same fork.
##
## Both ends of every rejected branch are sealed, not just the one the player
## turned away from. Sealing only the near end would let them walk the branch
## they chose, reach the join, and find the discarded branch open behind it.
func commit_fork(entered_id: String) -> void:
	var fork := BodyPlan.fork_for_branch(entered_id)
	if fork.is_empty() or forks_taken.has(fork["from"]):
		return
	forks_taken[fork["from"]] = entered_id

	for other: String in fork["branches"]:
		if other == entered_id:
			continue
		var members: Array = BodyPlan.branch_cells(other)
		for id: String in members:
			sealed_cells[BodyPlan.cell_of(id)] = true
		# The branch's two doors onto the rest of the body: in from `from`, out
		# to `join`. Everything between them is already unreachable.
		for id: String in members:
			for n: String in BodyPlan.neighbours_of(id):
				if not members.has(n):
					sealed_links[BodyPlan.link_id(id, n)] = true


## Every doorway the body has here, usable or not. The depth BFS runs on this,
## so walking distance is a property of the anatomy rather than of the choices
## a particular run happened to make.
func all_exits_of(cell: Vector2i) -> Array:
	return rooms[cell]["exits"] as Array


## Just the walls a room has doorways on, deduplicated. Room geometry and the
## lane-axis check care about which side, not about where the door leads.
func exit_dirs_of(cell: Vector2i) -> PackedStringArray:
	var out := PackedStringArray()
	for e: Dictionary in exits_of(cell):
		if not out.has(e["dir"]):
			out.append(e["dir"])
	return out


## One doorway by name. Returns an empty dictionary if this room has no such
## door -- which is the honest answer for a stale link id.
func exit_by_link(cell: Vector2i, id: String) -> Dictionary:
	if not rooms.has(cell):
		return {}
	for e: Dictionary in exits_of(cell):
		if e["link"] == id:
			return e
	return {}


## The run's pools for one room, handed out BY REFERENCE: the room's blood layer
## appends to this same array, so a splat is persisted by the act of drawing it
## and there is no second copy to fall out of step.
func blood_of(cell: Vector2i) -> Array:
	if not rooms.has(cell):
		return []
	return rooms[cell]["blood"] as Array


## Uncollected motes for one room, handed out BY REFERENCE, exactly like the
## blood. The room's DnaLayer both reads and WRITES this array, so picking a mote
## up is what removes it from the run.
func dna_of(cell: Vector2i) -> Array:
	if not rooms.has(cell):
		return []
	return rooms[cell]["dna"] as Array


func is_cleared(cell: Vector2i) -> bool:
	return rooms[cell]["cleared"] as bool


func mark_cleared(cell: Vector2i) -> void:
	rooms[cell]["cleared"] = true


func mark_seen(cell: Vector2i) -> void:
	rooms[cell]["seen"] = true
	# Neighbours show as outlines once you have stood next to them.
	for e: Dictionary in exits_of(cell):
		var n: Vector2i = e["to"]
		if rooms.has(n) and not rooms[n]["seen"]:
			rooms[n]["seen"] = true


## True once nothing on the floor is left to fight. Item rooms are deliberately
## excluded: whether a pedestal was taken is a build decision, and gating the
## endgame on it would punish a player for walking past a cache they did not
## want.
## Sealed rooms are excluded, and not as a nicety: a room behind a seal can never
## be cleared, so counting it would make the endgame unreachable.
func all_combat_cleared() -> bool:
	for cell: Vector2i in rooms:
		var kind := kind_of(cell)
		if kind != RoomKind.COMBAT and kind != RoomKind.BOSS:
			continue
		if is_sealed_cell(cell):
			continue
		if not is_cleared(cell):
			return false
	return true


## Whether the body has had enough. Killing EVERY infection is the condition that
## matters; the fraction on top of it is there so the rampage does not start
## while most of the body is still untouched, without demanding a clean sweep of
## a floor with dead ends in it.
##
## A count and not "is the first one dead": one infection left alive is a run the
## player can still finish, so the gate has to wait for all of them or the body
## would give up while something is still nesting in it.
func rampage_ready() -> bool:
	if bosses_killed() < boss_count():
		return false
	var progress := clear_progress()
	if progress.y == 0:
		return true
	return progress.x >= int(ceil(RAMPAGE_CLEAR_FRACTION * float(progress.y)))


## How much of the body has actually been fought through, as (done, total).
## Item rooms are excluded because taking a pedestal is a build decision, and
## sealed rooms because they can never be cleared at all -- the same two rules
## `all_combat_cleared` uses.
##
## One function rather than a loop copied per caller: the endgame gate and the
## end-of-run payout both count rooms, and two copies of this is exactly how a
## player ends up paid for a fraction that does not match the one that let them
## out.
func clear_progress() -> Vector2i:
	var done := 0
	var total := 0
	for cell: Vector2i in rooms:
		var kind := kind_of(cell)
		if kind != RoomKind.COMBAT and kind != RoomKind.BOSS:
			continue
		if is_sealed_cell(cell):
			continue
		total += 1
		if is_cleared(cell):
			done += 1
	return Vector2i(done, total)


## Where the suit can get back out: the mouth, the pelvic floor, and the hole
## he came in through. Three fixed options rather than "walk back the way you
## came", so the rampage is a route decision made from wherever you happen to
## be standing when it starts.
##
## The entry wound is included even though it is usually the furthest, because
## it is the one exit the player already knows the way to.
func escape_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = [
		BodyPlan.cell_of("mouth"),
		BodyPlan.cell_of("pelvis"),
	]
	if not out.has(start_cell):
		out.append(start_cell)
	return out


func is_escape_cell(cell: Vector2i) -> bool:
	return escape_cells().has(cell)


## What the exit is called at a given cell. The head's exit is a mouth, not a
## skull, and the entry wound is the one the player made.
func escape_name(cell: Vector2i) -> String:
	if cell == start_cell:
		return "the entry wound"
	if cell == BodyPlan.cell_of("mouth"):
		return "the mouth"
	return "the pelvic floor"


func distance_from_start(cell: Vector2i) -> int:
	return rooms[cell]["depth"] as int
