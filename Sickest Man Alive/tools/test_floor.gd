extends SceneTree

## Headless check of the floor layer. Run:
##   godot --headless --script res://tools/test_floor.gd
## The body layout is fixed, so the interesting failures are structural:
## an accidental shortcut from a foot to an organ, a limb that is not a
## chain, an entry point that skips the journey.

const TRIALS: int = 200

## How many rooms a run actually contains: everything except one branch of every
## fork.
const REACHABLE_ROOMS: int = 43

## How many fork combinations the sweep checks. Every one of them regenerates the
## floor, so the exhaustive 2^17 is not worth what it costs over a sample.
const SEAL_SAMPLES: int = 400

## Walking distance that the premise depends on: you cannot reach the chest from
## a hand without crossing the whole arm. Every row must hold whichever way the
## forks fall, which is what makes depth safe to compute once.
const EXPECTED_WALK: Array = [
	["l_hand", "sternum", 5],
	["r_hand", "sternum", 5],
	["l_foot", "pelvis", 5],
	["r_foot", "pelvis", 5],
	["l_hand", "r_hand", 10],
	["l_hand", "heart", 8],
	["l_foot", "gut", 7],
	["l_foot", "pineal", 27],
]


func _initialize() -> void:
	_test_anatomy()
	_test_generation()
	_test_room_build()
	_test_wall_capacity()
	_test_multi_slot_wall()
	_test_sealing()
	_test_rampage_gate()
	_test_forks()
	_test_seal_sweep()
	_finish("OK: anatomy intact, %d seeds valid, rooms build clean." % TRIALS)


## No wall in the body may be asked to hold more doors than fits. The failure
## this catches is a fork opening onto the short end of a lane, which produces
## overlapping doorways and a wall segment with negative width.
func _test_wall_capacity() -> void:
	var map := MapData.generate(1, 4)
	for cell: Vector2i in map.rooms:
		var size := map.size_of(cell)
		var per_dir: Dictionary = {}
		for e: Dictionary in map.exits_of(cell):
			per_dir[e["dir"]] = int(per_dir.get(e["dir"], 0)) + 1
		for dir: String in per_dir:
			var span: float = size.x if dir == "n" or dir == "s" else size.y
			var cap := Room.wall_capacity(span)
			_check(int(per_dir[dir]) <= cap,
				"'%s': %d doors on the %s wall, which fits %d at %d wide" % [
					map.name_of(cell), per_dir[dir], dir, cap, int(span)])


## Two doors on one wall, checked directly rather than waiting for a body that
## has one. Positions, pier widths and the resulting holes all have to line up,
## and none of it is exercised by a floor where every wall holds a single door.
func _test_multi_slot_wall() -> void:
	var room := Room.new()
	room.interior = MapData.CHAMBER_SIZE
	root.add_child(room)

	var a := room.door_point("n", 0, 2)
	var b := room.door_point("n", 1, 2)
	_check(is_equal_approx(a.x, MapData.CHAMBER_SIZE.x / 3.0), "slot 0 of 2 is not at a third")
	_check(is_equal_approx(b.x, MapData.CHAMBER_SIZE.x * 2.0 / 3.0), "slot 1 of 2 is not at two thirds")
	_check(b.x - a.x >= Door.GAP + Room.MIN_PIER, "two doors on a chamber wall are too close")

	# A single door has to land exactly where it always did.
	_check(is_equal_approx(room.door_point("n").x, MapData.CHAMBER_SIZE.x * 0.5),
		"a lone door moved off centre")

	# The boundary is a closed loop with a hole at every doorway. Walls are no
	# longer per-side pieces, so what is checked is the property that matters:
	# the outline closes, and each door punches exactly one gap in it.
	#
	# Built directly here: this room was never put through build(), because the
	# case under test is two doors on one wall, which no single body part has.
	room._exits = [
		{"link": "test_a", "dir": "n", "slot": 0, "count": 2, "to": Vector2i.ZERO},
		{"link": "test_b", "dir": "n", "slot": 1, "count": 2, "to": Vector2i.ZERO},
	]
	var outline_rng := RandomNumberGenerator.new()
	outline_rng.seed = 12345
	room._build_outline(outline_rng)

	# Sample count is approximate by design: each straight and each arc rounds to
	# a whole number of samples, so the total lands near the target rather than
	# on it. What matters is that the loop is dense enough to be smooth.
	var outline: PackedVector2Array = room._outline
	_check(absi(outline.size() - Room.OUTLINE_SAMPLES) <= 8,
		"outline has %d points, expected about %d" % [outline.size(), Room.OUTLINE_SAMPLES])

	var flags: PackedByteArray = room._outline_door
	var runs := 0
	for i in flags.size():
		var prev: int = flags[(i - 1 + flags.size()) % flags.size()]
		if flags[i] == 1 and prev == 0:
			runs += 1
	_check(runs == room._exits.size(),
		"outline has %d openings for %d doorways" % [runs, room._exits.size()])

	# The doorway itself must still be reachable: the boundary is pinned to the
	# rectangle there, so a point just inside the door is inside the room.
	for e: Dictionary in room._exits:
		var entry: Vector2 = room.entry_point(e["dir"], e["slot"], e["count"])
		_check(room.contains_point(entry),
			"entry point for door %s is outside the room" % e["link"])

	_check(room.contains_point(room.interior * 0.5), "the middle of the room is not in it")
	_check(not room.contains_point(Vector2(-40.0, -40.0)), "outside the room counts as inside")

	room.free()


func _test_anatomy() -> void:
	var map := MapData.generate(1, 4)

	_check(map.rooms.size() == BodyPlan.PARTS.size(),
		"map has %d rooms for %d parts" % [map.rooms.size(), BodyPlan.PARTS.size()])

	# A tree over every part, plus exactly one extra edge per fork -- each fork
	# closes one loop. A stray link or a missing one changes this count, which is
	# the whole anatomy contract stated once instead of sixty times.
	_check(BodyPlan.LINKS.size() == BodyPlan.PARTS.size() - 1 + BodyPlan.FORKS.size(),
		"%d links for %d parts and %d forks -- expected %d" % [
			BodyPlan.LINKS.size(), BodyPlan.PARTS.size(), BodyPlan.FORKS.size(),
			BodyPlan.PARTS.size() - 1 + BodyPlan.FORKS.size()])

	var seen_links: Dictionary = {}
	for link: Dictionary in BodyPlan.LINKS:
		var a: String = link["a"]
		var b: String = link["b"]
		_check(BodyPlan.PARTS.has(a), "link names unknown part '%s'" % a)
		_check(BodyPlan.PARTS.has(b), "link names unknown part '%s'" % b)
		_check(a != b, "part '%s' links to itself" % a)
		var id := BodyPlan.link_id(a, b)
		_check(not seen_links.has(id), "link %s appears twice" % id)
		seen_links[id] = true
		_check(MapData.DIRS.has(link["a_dir"]), "link %s has no real direction" % id)

	# Two parts on one cell would draw as one room on the minimap.
	var cells_used: Dictionary = {}
	for id: String in BodyPlan.PARTS:
		var cell := BodyPlan.cell_of(id)
		_check(not cells_used.has(cell), "'%s' and '%s' share a cell" % [id, cells_used.get(cell, "")])
		cells_used[cell] = id

	for cell: Vector2i in map.rooms:
		var id: String = map.rooms[cell]["id"]
		_check(not BodyPlan.links_of(id).is_empty(), "part '%s' connects to nothing" % id)

		# Both ends of a link must agree, or a door leads into a wall.
		for e: Dictionary in map.exits_of(cell):
			var n: Vector2i = e["to"]
			_check(map.has_room(n), "part '%s': exit %s to nowhere" % [id, e["link"]])
			var back := map.exit_by_link(n, e["link"])
			_check(not back.is_empty(), "part '%s': one-way door %s" % [id, e["link"]])
			if back.is_empty():
				continue
			_check(back["to"] == cell, "link %s does not come back to '%s'" % [e["link"], id])
			_check(back["dir"] == MapData.OPPOSITE[e["dir"]],
				"link %s: %s side is %s, other side is %s" % [e["link"], id, e["dir"], back["dir"]])

	for row: Array in EXPECTED_WALK:
		var d := _walk(map, BodyPlan.cell_of(row[0]), BodyPlan.cell_of(row[1]))
		_check(d == row[2], "walk %s -> %s is %d rooms, expected %d" % [row[0], row[1], d, row[2]])


func _test_generation() -> void:
	var entries_used: Dictionary = {}
	var bosses_used: Dictionary = {}
	for t in TRIALS:
		var seed_value := 1 + t * 7919
		var map := MapData.generate(seed_value, 4)

		var start_id: String = map.rooms[map.start_cell]["id"]
		entries_used[start_id] = true

		_check(BodyPlan.ENTRY_POINTS.has(start_id), "seed %d: started at '%s', not an extremity" % [seed_value, start_id])
		_check(map.kind_of(map.start_cell) == MapData.RoomKind.START, "seed %d: start not marked" % seed_value)

		# --- the infections ---
		_check(map.boss_count() >= MapData.BOSS_COUNT_MIN
				and map.boss_count() <= MapData.BOSS_COUNT_MAX,
			"seed %d: %d infections, wanted %d..%d" % [seed_value, map.boss_count(),
				MapData.BOSS_COUNT_MIN, MapData.BOSS_COUNT_MAX])

		var kinds_seen: Dictionary = {}
		for cell: Vector2i in map.boss_cells:
			var boss_id: String = map.rooms[cell]["id"]
			bosses_used[boss_id] = true
			# An infection may be anywhere the player cannot wall off, and nowhere
			# else -- one behind a seal is a run that cannot be finished.
			_check(BodyPlan.is_spine(boss_id),
				"seed %d: boss in '%s', which a fork can seal" % [seed_value, boss_id])
			_check(cell != map.start_cell, "seed %d: boss in the entry wound" % seed_value)
			_check(map.kind_of(cell) == MapData.RoomKind.BOSS, "seed %d: boss not marked" % seed_value)
			# Every one of them is a genuine journey, not just the deepest.
			var depth := map.distance_from_start(cell)
			_check(depth >= MapData.BOSS_MIN_DEPTH,
				"seed %d: infection only %d rooms from entry" % [seed_value, depth])
			_check(depth <= 30, "seed %d: infection %d rooms from entry, a slog" % [seed_value, depth])
			kinds_seen[map.boss_kind_of(cell)] = true

		# Three fights, not the same fight three times.
		_check(kinds_seen.size() == map.boss_count(),
			"seed %d: %d infections but only %d kinds" % [seed_value, map.boss_count(), kinds_seen.size()])

		# Scattered. This is the assertion that makes "spread out" a fact rather
		# than an intention -- see MapData.BOSS_MIN_DEPTH_GAP for why depth is a
		# sound (and conservative) stand-in for the walk between two rooms.
		for i in map.boss_cells.size():
			for j in range(i + 1, map.boss_cells.size()):
				var gap: int = absi(int(map.rooms[map.boss_cells[i]]["depth"])
					- int(map.rooms[map.boss_cells[j]]["depth"]))
				_check(gap >= MapData.BOSS_MIN_DEPTH_GAP,
					"seed %d: two infections only %d deep apart" % [seed_value, gap])

		# The DEEPEST one keeps the original rule: the far end of this run's walk.
		# Checked as a share of the deepest room the run could put it in, which is
		# the same rule the generator uses.
		var deepest := 0
		for cell: Vector2i in map.rooms:
			if cell != map.start_cell and BodyPlan.is_spine(map.rooms[cell]["id"]):
				deepest = maxi(deepest, map.rooms[cell]["depth"])
		_check(map.rooms[map.boss_cells[0]]["depth"] >= int(ceil(float(deepest) * MapData.BOSS_DEPTH_SHARE)),
			"seed %d: deepest infection at depth %d, too near the wound (deepest %d)" % [
				seed_value, map.rooms[map.boss_cells[0]]["depth"], deepest])

		# Every part must be walkable, and depth must be real walking distance.
		for cell: Vector2i in map.rooms:
			var depth := map.distance_from_start(cell)
			_check(depth >= 0, "seed %d: '%s' unreachable" % [seed_value, map.rooms[cell]["id"]])
			_check(depth == _walk(map, map.start_cell, cell), "seed %d: depth disagrees with walk" % seed_value)

		var item_cells: Array[Vector2i] = []
		for cell: Vector2i in map.rooms:
			if map.kind_of(cell) == MapData.RoomKind.ITEM:
				item_cells.append(cell)
		# Counted in groups, not rooms: a cache inside a fork is mirrored into the
		# sibling branch, and the pair is one cache as far as the budget and the
		# player are concerned.
		var groups := _cache_groups(map)
		_check(groups == 4, "seed %d: %d caches (in %d rooms)" % [seed_value, groups, item_cells.size()])

		# Caches must be spread along the journey, not clustered in one limb.
		var depths: Array[int] = []
		for cell in item_cells:
			depths.append(map.distance_from_start(cell))
		depths.sort()
		_check(depths[depths.size() - 1] - depths[0] >= 4,
			"seed %d: caches clustered, depth spread only %d" % [seed_value, depths[depths.size() - 1] - depths[0]])

		for cell in item_cells:
			var id: String = map.rooms[cell]["id"]
			_check(not BodyPlan.NO_ITEM.has(id), "seed %d: cache in dead-end '%s'" % [seed_value, id])
			_check(cell != map.start_cell and not map.is_boss(cell), "seed %d: cache overlaps start/boss" % seed_value)

		# Same seed, same run. The KINDS are compared as well as the cells: the
		# kind draw is new randomness off the same rng, and is exactly the sort of
		# thing that silently desyncs a seeded run.
		var again := MapData.generate(seed_value, 4)
		_check(again.start_cell == map.start_cell, "seed %d: entry moved on regenerate" % seed_value)
		_check(again.boss_cells == map.boss_cells, "seed %d: infections moved on regenerate" % seed_value)
		for cell: Vector2i in map.boss_cells:
			_check(again.boss_kind_of(cell) == map.boss_kind_of(cell),
				"seed %d: infection kind changed on regenerate" % seed_value)

	_check(entries_used.size() == BodyPlan.ENTRY_POINTS.size(),
		"only %d of %d entry points ever chosen" % [entries_used.size(), BodyPlan.ENTRY_POINTS.size()])

	# One organ is the furthest from every entry point on a body this tall, so
	# "deepest wins" would nest the infection in the same gland every single run.
	_check(bosses_used.size() >= 3,
		"infection only ever nests in %d places: %s" % [bosses_used.size(), bosses_used.keys()])


## Caches, counting each mirrored set once. Every branch of a fork holding a
## cache at the same position along it is one group; a spine cache is its own.
func _cache_groups(map: MapData) -> int:
	var groups: Dictionary = {}
	for cell: Vector2i in map.rooms:
		if map.kind_of(cell) != MapData.RoomKind.ITEM:
			continue
		var id: String = map.rooms[cell]["id"]
		var key := id
		for fork: Dictionary in BodyPlan.FORKS:
			var found := false
			for branch: String in fork["branches"]:
				var index: int = (BodyPlan.branch_cells(branch) as Array).find(id)
				if index >= 0:
					key = "%s#%d" % [fork["from"], index]
					found = true
					break
			if found:
				break
		groups[key] = true
	return groups.size()


func _walk(map: MapData, from: Vector2i, to: Vector2i) -> int:
	var dist: Dictionary = {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == to:
			return dist[cell]
		for e: Dictionary in map.exits_of(cell):
			var n: Vector2i = e["to"]
			if map.has_room(n) and not dist.has(n):
				dist[n] = dist[cell] + 1
				queue.append(n)
	return -1


func _test_room_build() -> void:
	var map := MapData.generate(12345, 4)
	var item := load("res://items/rusty_needle.tres") as Item
	for cell: Vector2i in map.rooms:
		if map.kind_of(cell) == MapData.RoomKind.ITEM:
			map.rooms[cell]["items"] = [item, item] as Array[Item]

	var rng := RandomNumberGenerator.new()
	rng.seed = 999

	for cell: Vector2i in map.rooms:
		var room := Room.new()
		root.add_child(room)
		room.build(map, cell, rng)

		var exits := map.exits_of(cell)
		_check(room.doors.size() == exits.size(),
			"'%s': %d doors for %d exits" % [room.display_name, room.doors.size(), exits.size()])
		for e: Dictionary in exits:
			_check(room.doors.has(e["link"]), "'%s': missing door %s" % [room.display_name, e["link"]])

		var first: String = exits[0]["link"]
		match map.kind_of(cell):
			MapData.RoomKind.COMBAT, MapData.RoomKind.BOSS:
				_check(room.doors[first].locked, "'%s': combat room opened early" % room.display_name)
			MapData.RoomKind.ITEM:
				# A cache is GUARDED. It locks like a combat room and holds its
				# pedestals back until its waves are down -- walking in on one is
				# the start of a fight rather than the end of a decision. This
				# used to assert the opposite, when a cache was walk-in-and-take.
				_check(room.doors[first].locked, "'%s': cache opened early" % room.display_name)
				var pedestals := 0
				for c in room.get_children():
					if c is Pedestal:
						pedestals += 1
				_check(pedestals == 0,
					"'%s': %d pedestals up before the gate" % [room.display_name, pedestals])
				_check(room._pending_offer.size() == 2,
					"'%s': %d items held for the gate" % [room.display_name, room._pending_offer.size()])
				# Exactly two waves, whatever size room the cache landed in --
				# "two waves" is a promise the player reads off the map.
				_check(room._pending_waves.size() + 1 == Room.ITEM_GATE_WAVES,
					"'%s': gate planned %d waves, wanted %d" % [room.display_name,
						room._pending_waves.size() + 1, Room.ITEM_GATE_WAVES])
			_:
				pass

		room.free()


## The shape of every fork: two ways round, the same length, meeting again, and
## nothing the run cannot afford to lose sitting inside one.
func _test_forks() -> void:
	var claimed: Dictionary = {}
	for fork: Dictionary in BodyPlan.FORKS:
		var from: String = fork["from"]
		var join: String = fork["join"]
		var branches: Array = fork["branches"]
		_check(branches.size() >= 2, "fork at '%s' offers %d ways" % [from, branches.size()])

		var length := -1
		for branch: String in branches:
			var members: Array = BodyPlan.branch_cells(branch)
			_check(not members.is_empty(), "branch '%s' is empty" % branch)

			# Length must match, or depth stops being a fact about the body and
			# starts depending on a choice made rooms ago.
			if length < 0:
				length = members.size()
			_check(members.size() == length,
				"fork at '%s': branch '%s' is %d rooms, sibling is %d" % [
					from, branch, members.size(), length])

			# Branches must not overlap, and must reach the join.
			for id: String in members:
				_check(not claimed.has(id), "'%s' belongs to two branches" % id)
				claimed[id] = true
				_check(id != from and id != join, "branch '%s' swallowed its own fork end" % branch)
			_check(BodyPlan.neighbours_of(members[members.size() - 1]).has(join)
				or _branch_reaches(members, join),
				"branch '%s' never comes back to '%s'" % [branch, join])

	# Nothing a run depends on REACHING may sit where a seal can reach it.
	var map := MapData.generate(1, 4)
	for cell: Vector2i in map.escape_cells():
		_check(BodyPlan.is_spine(map.rooms[cell]["id"]),
			"escape '%s' is inside a fork branch" % map.rooms[cell]["id"])

	# Entry points are the exception, and are allowed inside a branch. You cannot
	# be sealed out of the room you woke up in: entering a branch is what COMMITS
	# its fork, so a run that starts in an ear has already chosen that ear before
	# anything could have closed it. What every entry does have to be is a room
	# with a way onward, or the run is over where it started.
	for id: String in BodyPlan.ENTRY_POINTS:
		_check(BodyPlan.PARTS.has(id), "entry point '%s' is not a part" % id)
		_check(BodyPlan.neighbours_of(id).size() > 0, "entry point '%s' is a dead end" % id)


func _branch_reaches(members: Array, target: String) -> bool:
	for id: String in members:
		if BodyPlan.neighbours_of(id).has(target):
			return true
	return false


## Every way the forks can fall, checked one at a time. The floor must come out
## the same size, the infection must always be reachable, there must always be a
## way out, and walking distance must not move.
func _test_seal_sweep() -> void:
	var forks: Array = BodyPlan.FORKS
	var combinations := 1
	for fork: Dictionary in forks:
		combinations *= (fork["branches"] as Array).size()

	# Exhaustive while that is cheap, sampled once it is not. Regenerating the
	# floor per combination is the expensive part, and a hundred thousand of them
	# turns a two-second test into a coffee break.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260811
	var runs := mini(combinations, SEAL_SAMPLES)
	var exhaustive := combinations <= SEAL_SAMPLES

	var reference := MapData.generate(1, 4)
	for i in runs:
		var combo := i if exhaustive else rng.randi_range(0, combinations - 1)
		var map := MapData.generate(1, 4)
		var rest := combo
		for fork: Dictionary in forks:
			var branches: Array = fork["branches"]
			map.commit_fork(branches[rest % branches.size()])
			@warning_ignore("integer_division")
			rest = rest / branches.size()

		var open := 0
		for cell: Vector2i in map.rooms:
			if not map.is_sealed_cell(cell):
				open += 1
		_check(open == REACHABLE_ROOMS,
			"combination %d leaves %d rooms, expected %d" % [combo, open, REACHABLE_ROOMS])

		# One BFS answers reachability and walking distance together.
		var dist := _distances(map, map.start_cell)
		# EVERY infection, not just the first. This is the test that proves none of
		# them can be walled off, and checking one of three would pass a map that
		# sealed another away.
		for boss_cell: Vector2i in map.boss_cells:
			_check(dist.has(boss_cell), "combination %d seals an infection away" % combo)
		for exit_cell in map.escape_cells():
			_check(dist.has(exit_cell), "combination %d seals off an escape" % combo)
		_check(dist.size() == REACHABLE_ROOMS,
			"combination %d strands %d rooms" % [combo, REACHABLE_ROOMS - dist.size()])

		for cell: Vector2i in dist:
			_check(dist[cell] == reference.distance_from_start(cell),
				"combination %d moved '%s' to depth %d from %d" % [
					combo, map.name_of(cell), dist[cell], reference.distance_from_start(cell)])

		# Caches are mirrored, so the same number survives whichever way you go.
		var caches := 0
		for cell: Vector2i in dist:
			if map.kind_of(cell) == MapData.RoomKind.ITEM:
				caches += 1
		_check(caches == 4, "combination %d leaves %d caches, expected 4" % [combo, caches])


func _distances(map: MapData, from: Vector2i) -> Dictionary:
	var dist: Dictionary = {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for e: Dictionary in map.exits_of(cell):
			var n: Vector2i = e["to"]
			if not dist.has(n):
				dist[n] = dist[cell] + 1
				queue.append(n)
	return dist


## What a seal does downstream, driven directly rather than through a fork:
## a sealed doorway stops existing, and a sealed room stops being something the
## floor is waiting on.
func _test_sealing() -> void:
	var map := MapData.generate(1, 4)
	var pericardium := BodyPlan.cell_of("pericardium")
	var heart := BodyPlan.cell_of("heart")
	var before := map.exits_of(pericardium).size()

	map.sealed_links[BodyPlan.link_id("pericardium", "heart")] = true
	map.sealed_cells[heart] = true

	_check(map.exits_of(pericardium).size() == before - 1, "sealing a link left its doorway in place")
	_check(map.exit_by_link(pericardium, BodyPlan.link_id("pericardium", "heart")).is_empty(),
		"a sealed door is still findable by link id")
	_check(map.all_exits_of(pericardium).size() == before,
		"sealing a link removed it from the anatomy, not just from the run")

	# Every room but the sealed one cleared: the floor must count as done.
	for cell: Vector2i in map.rooms:
		if cell != heart:
			map.mark_cleared(cell)
	_check(map.all_combat_cleared(), "a sealed room is still being waited on")

	# Depth is a fact about the body, so it must not move when a branch closes.
	var again := MapData.generate(1, 4)
	for cell: Vector2i in map.rooms:
		_check(map.distance_from_start(cell) == again.distance_from_start(cell),
			"depth of '%s' changed after sealing" % map.name_of(cell))


## The endgame needs EVERY infection dead first. Clearing the whole floor around
## a living one must not start it.
func _test_rampage_gate() -> void:
	var map := MapData.generate(1, 4)
	for cell: Vector2i in map.rooms:
		if not map.is_boss(cell):
			map.mark_cleared(cell)
	_check(not map.rampage_ready(), "rampage started with the infections still alive")

	# Killed one at a time, asserting the gate stays shut until the LAST one goes
	# down. Clearing them in one go would pass just as well against a gate that
	# only ever checked the first, which is the bug this is here to catch.
	for i in map.boss_cells.size():
		map.mark_cleared(map.boss_cells[i])
		var last := i == map.boss_cells.size() - 1
		if last:
			_check(map.rampage_ready(), "rampage refused to start on a dead floor")
		else:
			_check(not map.rampage_ready(),
				"rampage started with %d infections left" % (map.boss_cells.size() - i - 1))

	# Bosses dead, most of the body untouched: too early.
	var fresh := MapData.generate(1, 4)
	for cell: Vector2i in fresh.boss_cells:
		fresh.mark_cleared(cell)
	_check(not fresh.rampage_ready(), "rampage started on the bosses alone")


## assert() prints and keeps going in this context, which would let a red run
## still end on "OK". Count failures and set the exit code instead.
var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


func _finish(summary: String) -> void:
	if _failures > 0:
		printerr("%d FAILURE(S)" % _failures)
		quit(1)
	else:
		print(summary)
		quit()
