extends Node
## The Steam Deck pass on the desktop (2026-10-06, issue #33): the game in a 1280 x 800
## window, the Deck's screen, with every board opened in turn. Saves
## tools/last_deck_<board>.png and tools/last_deck.log: the canvas size, the stretch, and
## what each drawn board reports it could not fit (`dropped_lines`, the letter's `overruns`).
##
## What this cannot prove is the Deck itself: its GPU, its Steam Input and Valve's review.
##
## Run with the desktop build (not --headless), --fixed-fps 60:
##   godot --path . --fixed-fps 60 res://tools/shot_deck.tscn
## On a save of its own, under its own node, so the player's run and front are untouched.

## DECK_H=720 runs it at the smallest window the game supports instead, to compare.
var DECK := Vector2i(1280, 800 if OS.get_environment("DECK_H").is_empty() else int(OS.get_environment("DECK_H")))
const LOG := "res://tools/last_deck.log"

var _main: Node
var _frames := 0
var _out: FileAccess


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(DECK)
	_out = FileAccess.open(LOG, FileAccess.WRITE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://probe_deck.save"))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", "user://probe_deck.save")
	add_child.call_deferred(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	match _frames:
		30:
			# The window can be held to the monitor's work area; say what it really is.
			DisplayServer.window_set_size(DECK)
		40:
			var vp := get_viewport()
			_out.store_line("window %s  canvas %s  stretch %.2f" % [DisplayServer.window_get_size(),
				vp.get_visible_rect().size, float(DisplayServer.window_get_size().y) / vp.get_visible_rect().size.y])
			_save(&"lake")
			_main.call(&"_set_settings", true)
		50:
			_save(&"settings")
			_report(&"settings", _main.get(&"_settings"))
			_main.call(&"_set_controls", true)
		60:
			_save(&"controls")
			_report(&"controls", _main.get(&"_controls"))
			_main.call(&"_set_controls", false)
			_main.call(&"_set_settings", false)
			_main.call(&"_set_menu", true)
		72:
			_save(&"upgrades")
			_main.call(&"_set_menu", false)
			_main.call(&"_set_letter", true)
		84:
			var letter: Node = _main.get(&"_letter")
			_save(&"letter_1")
			_report(&"letter_1", letter)
			_out.store_line("letter overruns %s" % str(letter.call(&"overruns")))
			letter.call(&"turn", 1)
		96:
			_save(&"letter_2")
			_report(&"letter_2", _main.get(&"_letter"))
			_main.call(&"_set_letter", false)
			_main.call(&"_set_shed", true)
		112:
			_save(&"shed")
			_main.call(&"_set_shed", false)
			_main.call(&"_set_wash", true)
		126:
			_save(&"wash")
			_main.call(&"_set_wash", false)
		130:
			_out.store_line("done")
			_out.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://probe_deck.save"))
			get_tree().quit()


func _report(what: StringName, board: Object) -> void:
	if board == null:
		_out.store_line("%s: no board" % what)
		return
	_out.store_line("%s: dropped_lines %s" % [what, str(board.get(&"dropped_lines"))])


func _save(which: StringName) -> void:
	var path := "res://tools/last_deck_%s.png" % which
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	_out.store_line("shot %s" % which)
