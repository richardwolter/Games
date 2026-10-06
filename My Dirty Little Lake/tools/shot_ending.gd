extends Node
## The ending, photographed: the words starting to arrive over the clean water, the words up,
## the credits partway up, and what is left once the roll has been skipped.
##
## A probe, not a test — the harness runs headless and headless has no renderer, so nothing
## in `Farewell._draw` is exercised by it. Run this one with the desktop build.
##
##     <godot> --path . --fixed-fps 60 res://tools/shot_ending.tscn
##
## The lake is emptied by hand rather than played to the end: what is being looked at is the
## screen, and the screen does not know how the water was cleared.
##
## **It writes to a save of its own** (`SAVE_PATH`), because finishing a lake saves it on the
## spot — the probe would otherwise hand the player back an emptied, finished lake in place
## of their run. Nothing in `tools/` may leave `user://` changed; `test_lake` does the same.

const SHOTS := {
	&"beat": "res://tools/last_ending_beat.png",
	&"words": "res://tools/last_ending_words.png",
	&"roll": "res://tools/last_ending_roll.png",
	&"behind": "res://tools/last_ending_behind.png",
	&"skipped": "res://tools/last_ending_skipped.png",
}

## The probe's own save file. The lake saves itself the moment it is finished, and the one
## thing this probe does is finish a lake.
const SAVE_PATH := "user://shot_ending.save"

var _main: Node
var _frames := 0
var _log := ""


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	# Under this node, not under the root: a lake hung off the root is the game's own and
	# wears the front (2026-09-17), and nothing behind the menu looks for the ending. This
	# probe did exactly that for a day and photographed a menu five times.
	add_child.call_deferred(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	match _frames:
		20:
			_empty_the_lake()
		# A third of a second in: the water is lighting up and the words have barely begun to
		# arrive. There is no beat in front of them any more (2026-09-18); the shot keeps its
		# name so the pictures line up with the older ones.
		40:
			_note("words begun: %s" % str(_main.get_node_or_null(^"Farewell") != null))
			_save(&"beat")
		# The words have arrived and the roll is starting from under the glass.
		330:
			_note("words up: %s" % str(_main.get_node_or_null(^"Farewell") != null))
			_save(&"words")
		# The first credits reaching the message's band, where the two cross and the roll
		# dims under the words.
		760:
			_save(&"behind")
		# Spotify's mark and the name beside it, frame by frame: if the two move by the same
		# whole pixel every frame they are locked, and if they do not the mark jitters
		# against the word. Eyeballing a still cannot tell the difference (2026-09-16).
		#
		# Measured well clear of the message, where the roll is at full strength: inside the
		# band it dims to ROLL_BEHIND and neither the green nor the cream is itself any more.
		700, 701, 702, 703, 704, 705:
			_save_frame()
		# Well up the screen, with the whole roll in the picture.
		900:
			_note("rolling: %s" % str(_ending() != null and _ending().rolling()))
			_save(&"roll")
			if _ending() != null:
				_ending().skip_roll()
		# The skip runs at ROLL_SKIP times the pace, so three seconds is plenty of room for
		# what is left of a twenty-six second roll.
		1080:
			_note("after the skip, rolling: %s" % str(_ending() != null and _ending().rolling()))
			_save(&"skipped")
		1088:
			FileAccess.open("res://tools/last_ending.log", FileAccess.WRITE).store_string(_log)
			if FileAccess.file_exists(SAVE_PATH):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
			get_tree().quit()


func _ending() -> Farewell:
	return _main.get(&"_farewell") as Farewell


## Take every piece out of the water and let the lake notice. Nothing is in a net's hold or a
## dog's mouth, so `_all_landed` is true on the spot and the ending opens on the next check.
func _empty_the_lake() -> void:
	var grid: LakeGrid = _main.get(&"_grid")
	for i in grid.stacks.size():
		var stack: Array = grid.stacks[i]
		if not stack.is_empty():
			stack.resize(0)
			grid.stacks[i] = stack
	# The soup is one triangle array, laid out when something is taken. Emptying the stacks
	# by hand takes nothing, so the mesh has to be told or the probe photographs a clean
	# lake with the old rubbish still drawn over it.
	grid.set(&"_dirty", true)
	grid.queue_redraw()
	_main.set(&"pollution", 0.0)
	_main.set(&"_filth_left", 0.0)
	_main.set(&"_filth_stale", true)
	_main.set(&"_clean_check_in", 0.0)


func _note(line: String) -> void:
	_log += line + "\n"
	print(line)


## Six frames in a row, well clear of the message, for `tools/check_mark_jitter.py` to
## measure Spotify's mark against the name beside it.
##
## The pictures are what is measured, not the scene: reading the viewport's texture inside
## `_physics_process` hands back a stale capture, which said the mark was in open water and
## never moved. `_save` writes a real frame, so the check is made off the files.
func _save_frame() -> void:
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://tools/last_ending_jitter_%d.png" % _frames)
	)


func _save(which: StringName) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOTS[which]))
