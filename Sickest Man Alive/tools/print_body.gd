extends SceneTree

## Prints a floor as ASCII. Run:
##   godot --headless --script res://tools/print_body.gd
## Fastest way to check a BodyPlan edit did what you meant without launching
## the game. S = entry, B = infection, * = supply cache, # = combat.


func _initialize() -> void:
	var map := MapData.generate(0, 4)

	var min_c := Vector2i(999, 999)
	var max_c := Vector2i(-999, -999)
	for cell: Vector2i in map.rooms:
		min_c.x = mini(min_c.x, cell.x)
		min_c.y = mini(min_c.y, cell.y)
		max_c.x = maxi(max_c.x, cell.x)
		max_c.y = maxi(max_c.y, cell.y)

	var nests := PackedStringArray()
	for cell: Vector2i in map.boss_cells:
		nests.append("%s %s (%d away)" % [
			map.name_of(cell),
			MapData.BossKind.keys()[map.boss_kind_of(cell)],
			map.distance_from_start(cell),
		])
	print("seed %d | entry: %s | infections: %s\n" % [
		map.seed_used,
		map.name_of(map.start_cell),
		"; ".join(nests),
	])

	for y in range(min_c.y, max_c.y + 1):
		var line := ""
		for x in range(min_c.x, max_c.x + 1):
			var cell := Vector2i(x, y)
			if not map.has_room(cell):
				line += "   "
				continue
			var glyph := "#"
			match map.kind_of(cell):
				MapData.RoomKind.START:
					glyph = "S"
				MapData.RoomKind.BOSS:
					# One letter per kind, so a printed floor shows the spread AND
					# which fight is where at a glance.
					match map.boss_kind_of(cell):
						MapData.BossKind.CAN:
							glyph = "C"
						MapData.BossKind.FUNGUS:
							glyph = "F"
						_:
							glyph = "B"
				MapData.RoomKind.ITEM:
					glyph = "*"
				_:
					pass
			# Branch rooms are bracketed differently, so a fork reads as a pair of
			# alternatives rather than as two rooms that happen to be side by side.
			var id: String = map.rooms[cell]["id"]
			line += "(%s)" % glyph if not BodyPlan.is_spine(id) else "[%s]" % glyph
		print(line)

	print("")
	print("forks -- one branch of each is sealed the moment you pick the other:")
	for fork: Dictionary in BodyPlan.FORKS:
		var names: Array[String] = []
		for branch: String in fork["branches"]:
			names.append("%s (%d)" % [
				BodyPlan.PARTS[branch]["name"], BodyPlan.branch_cells(branch).size()])
		print("  %-16s -> [ %s ] -> %s" % [
			BodyPlan.PARTS[fork["from"]]["name"], " | ".join(names),
			BodyPlan.PARTS[fork["join"]]["name"]])
	print("  %d forks, %d parts, %d reachable per run" % [
		BodyPlan.FORKS.size(), BodyPlan.PARTS.size(),
		BodyPlan.PARTS.size() - BodyPlan.FORKS.size()])

	# Layout and topology are separate facts now, so they can disagree without
	# breaking a door. Worth knowing about anyway: a link that does not point the
	# way its cells do draws as a line across the map to nowhere.
	print("")
	var odd := 0
	for link: Dictionary in BodyPlan.LINKS:
		var delta := BodyPlan.cell_of(link["b"]) - BodyPlan.cell_of(link["a"])
		var want: Vector2i = MapData.DIRS[link["a_dir"]]
		if signi(delta.x) != want.x and signi(delta.y) != want.y:
			odd += 1
			print("  layout: %s -> %s declared %s but sits %s" % [
				link["a"], link["b"], link["a_dir"], delta])
	if odd == 0:
		print("  layout: every link points the way its cells do")

	print("")
	var by_depth: Array = []
	for cell: Vector2i in map.rooms:
		by_depth.append([map.distance_from_start(cell), map.name_of(cell), cell])
	by_depth.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for row: Array in by_depth:
		var cell: Vector2i = row[2]
		var size := map.size_of(cell)
		# Shape and footprint, because "is the throat a lane?" is exactly the
		# kind of thing that is obvious here and invisible in game until you have
		# walked halfway across the body to check.
		print("  %2d  %-16s %-8s %4d x %-4d" % [
			row[0], row[1], _shape_name(map.shape_of(cell)), int(size.x), int(size.y)])

	quit()


func _shape_name(shape: BodyPlan.RoomShape) -> String:
	match shape:
		BodyPlan.RoomShape.LANE:
			return "lane"
		BodyPlan.RoomShape.CAVERN:
			return "cavern"
		_:
			return "chamber"
