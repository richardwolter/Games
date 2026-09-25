extends Node
## Opens the shed on a real window, stands a few finds on the shelf, and saves a picture of
## it plus the rectangles it was drawn from. A probe, not a test: the alignment between the
## shelf board and the room beside it is a thing to look at, and the numbers beside the
## picture say which edge moved.
##
## Run it with the desktop build, not --headless: nothing renders under the dummy driver.

const SHOT := "res://tools/last_shed.png"
const LOG := "res://tools/last_shed.log"

var _main: Node
var _frames := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	# Under this node, NOT the tree root (2026-09-19). A lake whose parent is the root is
	# the game: since The Front it strikes the menu pose, hides the HUD layer and holds the
	# player, so the shed it opens is behind a main menu and its Controls are never laid
	# out. This probe had been photographing that — `room size (0.0, 200.0)` in its own log,
	# which nobody read. The ending probe learned the same lesson in 2026-09-18.
	add_child(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 8:
		var room: ShedRoom = _main.get_node(^"HUD/Shed/Pad/Lines/Room")
		# Enough finds to fill the shelf past its bottom edge, so the scrollbar is in shot.
		# A room in use, for the placement rules to be looked at (2026-09-13): the tall
		# bookcase and the fridge against the wall, a painting hung over them, the table
		# with a pot set on it, two chairs on one row, and the bed. Every name that the
		# catalogue does not know is skipped, so a re-cut costs the probe nothing.
		var decor: Array = _main.get(&"decor")
		decor.clear()
		room.decor = decor
		for want: Array in [
			[&"decor_bookcase_tall", 1, -4], [&"decor_fridge", 9, -4],
			[&"decor_painting_a", 14, -3], [&"decor_painting_b", 18, -4],
			[&"decor_kitchen_counter", 22, -2], [&"decor_stove", 32, -3],
			[&"decor_big_table", 4, 8], [&"decor_flower_pot", 6, 6], [&"decor_globe", 9, 5],
			[&"decor_dining_chair", 12, 10], [&"decor_dining_chair", 14, 10],
			[&"decor_pet_bed", 24, 14], [&"decor_big_rug", 20, 6], [&"decor_sofa", 22, 8],
			# The potted plant pushed as far up the back wall as the room will let it
			# (2026-09-19, issue #30): what its pixel base bought is a thing to look at,
			# and neither pot in the list above was standing against the wall.
			[&"decor_loveseat", 34, 8],
			# Lit, for the light the room throws (2026-09-20): the pools are what the three
			# ringed circles were replaced by, and a probe that never lights a fire is a
			# probe that cannot show them.
			[&"decor_fireplace", 30, 2],
		]:
			if room.sheets.has(want[0]):
				# Written in cells, which is what the eye lays a room out in; the room places
				# in source pixels now (2026-09-16, ShedRoom.CELL), so they are scaled here.
				var at := Vector2i(int(want[1]), int(want[2])) * ShedRoom.CELL
				if not room.place(want[0], at):
					push_warning("shot_shed: %s refused at %s,%s" % want)
		# The potted plant as far up the back wall as the room will let it (2026-09-19,
		# issue #30): what its pixel base bought is a thing to look at, and neither pot in
		# the list above is standing against a wall. In pixels, not cells — the whole point
		# is that its limit is not a whole cell.
		var pot := &"decor_plant_pot"
		if room.sheets.has(pot):
			var top := room.base_of(pot) - room.span_of(pot).y
			if not room.place(pot, Vector2i(28 * ShedRoom.CELL, top)):
				push_warning("shot_shed: the pot would not stand at %d" % top)

		# The whole pack, rather than whatever DOG_ODDS rolls: which dogs are in is random
		# in play and a picture that changes run to run says nothing. The seats in the list
		# above are the pet bed, the sofa and the armchair.
		# Every switchable piece on, for the light it throws.
		for k in room.decor.size():
			var row: Dictionary = room.decor[k]
			var piece := StringName(row["piece"])
			var on := room.sheets.switched(piece, int(row.get("view", 0)))
			if on >= 0 and not room.sheets.is_on(piece, int(row.get("view", 0))):
				row["view"] = on
		room.pack_size = func() -> int: return ShedRoom.DOGS_MOST
		_main.call(&"_set_shed", true)
		# Enough finds to fill the shelf past its bottom edge, so the scrollbar is in shot.
		# **After** the door is open, not before: `Lake._set_shed` re-points `unlocked` at
		# the lake's own list on the way in, so a shelf filled first showed one row.
		var names: Array = room.titles.keys()
		var unlocked: Array[String] = []
		# SHED_ONE=1: one find on the shelf and one at the pump, for the wash plank under a
		# single row (2026-09-24).
		var one := OS.get_environment("SHED_ONE") == "1"
		if one:
			unlocked.append(String(names[names.size() - 1]))
		else:
			for i in mini(names.size(), 24):
				unlocked.append(String(names[i]))
		room.unlocked = unlocked
		if one:
			var waiting: Array[String] = [String(names[names.size() - 2])]
			room.unwashed = waiting
		_force_the_pack(room)
	if _frames == 20:
		_write()
	if _frames >= 24:
		get_tree().quit()


## Open the room over and over until the whole pack is in. `_room_shown` rolls each dog on
## its own, so this is the honest path rather than a list of dogs written straight into the
## room; the alternative is a picture that has a different number of animals in it every
## time it is taken.
func _force_the_pack(room: ShedRoom) -> void:
	for _try in 400:
		if room.dogs().size() >= ShedRoom.DOGS_MOST:
			return
		room.call(&"_room_shown")


func _write() -> void:
	var room: ShedRoom = _main.get_node(^"HUD/Shed/Pad/Lines/Room")
	var f := FileAccess.open(LOG, FileAccess.WRITE)
	f.store_line("room size      %s" % room.size)
	f.store_line("shed  rect     %s" % room.call(&"_shed_rect"))
	f.store_line("floor rect     %s" % room.call(&"_floor_rect"))
	f.store_line("board rect     %s" % room.call(&"_board_rect"))
	f.store_line("ribbon rect    %s" % room.call(&"_ribbon_rect"))
	f.store_line("list  rect     %s" % room.call(&"_list_rect"))
	f.store_line("dogs in        %d of %d" % [room.dogs().size(), ShedRoom.DOGS_MOST])
	for dog in room.dogs():
		f.store_line("  dog  %-28s at %s  %s" % [
			dog.seat if not dog.seat.is_empty() else "(floor)", str(dog.at), dog.state
		])
	var pot := &"decor_plant_pot"
	if room.sheets != null and room.sheets.has(pot):
		f.store_line("pot   base     %d px of %d" % [
			room.base_of(pot), room.span_of(pot).y
		])
	f.flush()
	f.close()
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(SHOT))
	# The two seams worth looking at close up: where the room's top edge meets the board's,
	# and where their bottom edges meet. Scaled up, because a one-pixel step is the whole
	# question and it is invisible at window size.
	var shed: Rect2 = room.call(&"_shed_rect")
	var board: Rect2 = room.call(&"_board_rect")
	var to_shot := float(shot.get_width()) / room.size.x
	# Where each of the two actually puts ink, rather than where its rect says it does.
	# The moulding sheets carry transparent padding, so the wall's rect and the wall's
	# drawn edge are not the same line.
	var f2 := FileAccess.open(LOG, FileAccess.READ_WRITE)
	f2.seek_end()
	f2.store_line("shed  ink rows %s (rect %.1f .. %.1f)" % [
		_ink_rows(shot, (shed.end.x - 8.0) * to_shot), shed.position.y, shed.end.y
	])
	f2.store_line("board ink rows %s (rect %.1f .. %.1f)" % [
		_ink_rows(shot, (board.position.x + 4.0) * to_shot), board.position.y, board.end.y
	])
	f2.store_line("to_shot %.4f" % to_shot)
	f2.flush()
	f2.close()


## The first few colour changes down a column, in room pixels. Eyeballing a screenshot to
## a pixel does not work; this says exactly which row each edge is on.
func _ink_rows(shot: Image, at_x: float) -> String:
	var x := clampi(int(at_x), 0, shot.get_width() - 1)
	var to_room := float(shot.get_width()) / 1264.0
	var out := PackedStringArray()
	var last := Color(-1.0, -1.0, -1.0)
	for y in shot.get_height():
		var c := shot.get_pixel(x, y)
		if last.r >= 0.0 and c.is_equal_approx(last):
			continue
		last = c
		out.append("%.1f:%s" % [float(y) / to_room, c.to_html(false)])
		if out.size() >= 10:
			break
	return " ".join(out)
