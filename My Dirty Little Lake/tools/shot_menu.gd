extends Node
## Opens the lake with its menu on a real window and photographs the whole front of the
## game: the loading picture it comes up under, the menu over the lake, its three boards,
## the glide down to the angler part way and landed, and the way back to the menu — the
## view dimming and the frozen frame dissolving (`Curtain.dissolve`).
##
## A probe, not a test. `test_lake` guards the rules — the pose, the holds, the glide landing
## on a stop, nothing lost on the way back; where the logo stands on the lake, how dark the
## band under it wants to be and whether the glide reads are things to look at.
##
## Run it with the desktop build, not --headless (nothing renders under the dummy driver),
## and at a fixed rate so the times below are the times that are drawn:
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_menu.tscn --log-file tools/last_menu_engine.log
##
## **On a copy of the player's save, never the save itself.** Going back to the menu writes
## the run, and a probe may not hand the player back a run it has touched. The lake is
## borrowed, so it is told to wear the front anyway (`Lake.force_front`).

const SAVE_COPY := "user://probe_menu.save"
const LOG_PATH := "res://tools/last_menu.log"

## What happens when, in seconds after the lake goes in. A picture is taken *before* the
## step's own action, so each one shows what the step before it left.
const STEPS := [
	[0.05, &"curtain", &""],
	# Part way through the loading picture going: the lake alone, no logo and no bar.
	[0.55, &"lifting", &""],
	[2.2, &"main", &"settings"],
	[2.7, &"main_settings", &"credits"],
	[3.2, &"credits", &"confirm"],
	[3.7, &"confirm", &"play"],
	[4.5, &"glide", &""],
	[6.2, &"landed", &"back"],
	# The way back: the view part dimmed, the frozen frame part dissolved, the menu.
	[6.4, &"dim", &""],
	[7.0, &"dissolve", &""],
	[8.2, &"back", &"quit"],
]

var _lake: Node
var _age := 0.0
var _next := 0
var _log: FileAccess


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if FileAccess.file_exists(Lake.SAVE_PATH):
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(Lake.SAVE_PATH),
			ProjectSettings.globalize_path(SAVE_COPY)
		)
		_say("on a copy of the player's save")
	else:
		if FileAccess.file_exists(SAVE_COPY):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_COPY))
		_say("no save: a fresh lake, and New game is the accented door")
	_lake = load("res://scenes/main.tscn").instantiate()
	_lake.set(&"save_path", SAVE_COPY)
	_lake.set(&"force_front", true)
	add_child(_lake)


func _process(delta: float) -> void:
	_age += delta
	if _next >= STEPS.size() or _age < float(STEPS[_next][0]):
		return
	var step: Array = STEPS[_next]
	_next += 1
	var shot := step[1] as StringName
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://tools/last_menu_%s.png" % shot)
	)
	_note(shot)
	var menu := _lake.get(&"_menu") as MainMenu
	match step[2] as StringName:
		&"settings":
			menu.call(&"_show_settings", true)
		&"credits":
			menu.call(&"_show_settings", false)
			menu.call(&"_show_credits", true)
		&"confirm":
			menu.call(&"_show_credits", false)
			menu.call(&"_show_confirm", true)
		&"play":
			menu.call(&"_show_confirm", false)
			menu.call(&"_take", &"continue" if menu.has_run else &"new")
		&"back":
			_lake.call(&"_quit")
		&"quit":
			_say("done")
			get_tree().quit()


## Where things stand as each picture is taken.
func _note(shot: StringName) -> void:
	var camera := _lake.get(&"_camera") as Camera2D
	var view := get_viewport().get_visible_rect().size
	var middle := Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)
	var across := 0.5 + (middle.x - camera.position.x) * camera.zoom.x / view.x
	var asleep := 0
	var dogs := _lake.get(&"_dogs") as Array
	for dog: Dog in dogs:
		if dog.dozing:
			asleep += 1
	var moored := 0
	var boats := _lake.get(&"_boats") as Array
	for boat: Boat in boats:
		if boat.moored and not boat.is_running():
			moored += 1
	_say("%-14s %5.2f s  zoom %.3f  lake's middle %.2f across  dogs asleep %d/%d  hulls moored %d/%d  in menu %s  hud %s" % [
		shot, _age, camera.zoom.x, across, asleep, dogs.size(), moored, boats.size(),
		str(_lake.get(&"_in_menu")), str((_lake.get(&"_hud_layer") as CanvasLayer).visible),
	])


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()
