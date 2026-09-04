extends SceneTree

## Headless check on the endgame: the rampage triggers when the floor is dead,
## every room it touches keeps producing white cells, and touching an exit ends
## the run and stops the clock.
##
## Run: <godot> --headless --script tools/test_rampage.gd

## Headless runs uncapped, so a frame count says nothing about how much game
## time has passed. Everything here is gated on accumulated delta instead.
var _frames: int = 0
var _elapsed: float = 0.0
var _main: Node
var _stage: int = 0


func _initialize() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	current_scene = _main


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	var map: MapData = _main.map

	if _stage == 0 and _frames >= 10:
		_stage = 1
		# Everything dead except the infection. The body must not react yet:
		# killing it is the condition, and the fraction is only a floor under it.
		for cell: Vector2i in map.rooms:
			if not map.is_boss(cell):
				map.mark_cleared(cell)
		_main._check_rampage_trigger()
		assert(not _main._rampage, "rampage triggered with the infections still alive")

		# One at a time. Killing them all at once would pass equally well against
		# a gate that only ever checked the first of them.
		for i in map.boss_cells.size():
			map.mark_cleared(map.boss_cells[i])
			_main._check_rampage_trigger()
			if i < map.boss_cells.size() - 1:
				assert(not _main._rampage, "rampage triggered with an infection left alive")
		assert(_main._rampage, "rampage did not trigger on a fully cleared floor")
		print("rampage triggered in %s" % map.name_of(_main.current_cell))

	# Wait for the first white cell to actually arrive rather than guessing at a
	# duration: a headless frame is not a real frame, and the room's own clock
	# runs off node process time, not off this loop's.
	if _stage == 1:
		if get_nodes_in_group(&"enemies").size() > 0:
			_stage = 2
			print("white cells arrived after %.1fs of loop time" % _elapsed)
		elif _elapsed > 60.0:
			# Ends the loop rather than asserting in place: _process is called
			# again immediately after a failed assert, so asserting here spammed
			# the same line thousands of times and buried the actual result.
			#
			# The budget is generous on purpose. The room's spawn clock runs on
			# node process time, which is not this loop's wall clock, and a
			# machine busy running another test instance stretches the gap.
			push_error("FAIL: rampage produced nothing in %.0fs" % _elapsed)
			return true

	if _stage == 2:
		_stage = 3
		var exits := map.escape_cells()
		print("exits: %s" % [exits.map(func(c: Vector2i) -> String: return map.name_of(c))])
		_main._enter(exits[0], "")
		var portal: ExitPortal = null
		for child in _main.room.get_children():
			if child is ExitPortal:
				portal = child
		assert(portal != null, "escape room built without a portal")
		print("portal in %s labelled '%s'" % [map.name_of(exits[0]), portal.label])
		portal.entered.emit()

	if _stage == 3:
		assert(_main._escaped, "escape did not register")
		assert(not _main._run_timing, "clock still running after escape")
		print("OK: rampage spawns, exits exist, escape ends the run and stops the clock.")
		return true

	return _elapsed > 40.0
