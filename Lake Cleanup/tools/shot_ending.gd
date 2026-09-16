extends Node
## The ending, photographed: the beat of clean water, the words arriving over it, the credits
## partway up, and what is left once the roll has been skipped.
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
	get_tree().root.add_child.call_deferred(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	match _frames:
		20:
			_empty_the_lake()
		# Mid-beat: the water is lighting up and not a word has been written.
		40:
			_note("beat left %.2f s" % float(_main.get(&"_ending_in")))
			_save(&"beat")
		# The words have arrived and the roll is starting from under the glass. The beat is
		# two seconds, so this is well past the frame the lake was emptied on.
		170:
			_note("words up: %s" % str(_main.get_node_or_null(^"Farewell") != null))
			_save(&"words")
		# The first credits reaching the message's band, where the two cross and the roll
		# dims under the words.
		540:
			_save(&"behind")
		# Well up the screen, with the whole roll in the picture.
		640:
			_note("rolling: %s" % str(_ending() != null and _ending().rolling()))
			_save(&"roll")
			if _ending() != null:
				_ending().skip_roll()
		# The skip runs at ROLL_SKIP times the pace, so three seconds is plenty of room for
		# what is left of a twenty-six second roll.
		820:
			_note("after the skip, rolling: %s" % str(_ending() != null and _ending().rolling()))
			_save(&"skipped")
		828:
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
	_main.set(&"pollution", 0.0)
	_main.set(&"_filth_left", 0.0)
	_main.set(&"_clean_check_in", 0.0)


func _note(line: String) -> void:
	_log += line + "\n"
	print(line)


func _save(which: StringName) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOTS[which]))
