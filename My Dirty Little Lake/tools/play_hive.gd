extends Node
## A playable lake for judging the beehive (2026-10-04, the hive fixes): a fresh lake on a save
## of its own, the hive already holding a swarm and the angler a few steps from it, so the gold
## mark can be seen turning into the key chip on the walk up. E opens the room as in play.
## Desktop build:
##
##   godot --path . res://tools/play_hive.tscn
##
## Keys, on the lake (not while the room is up):
##   F1  a swarm on the hive (catch, smoke, queen)
##   F2  honey ready (uncap, pour)
##   F3  a colony caught and left before its queen (smoke, queen)
##   F5  the angler back beside the hive
##
## Nothing it does reaches the player's run: its own save, never loaded, removed on the way in.

const Style := preload("res://scripts/style.gd")
const SAVE_PATH := "user://play_hive.save"
## Where the angler is put: a few steps off the hive, out of its reach, so the walk up shows
## the mark turning into the key.
const START_OFF := Vector2(3.0, 1.0)
const HELP := "F1 swarm   F2 honey ready   F3 colony to settle   F5 back to the hive   E at the hive opens it"

var _main: Node
var _frames := 0
var _help: Label


func _ready() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Lake.force_hive = true
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	# Under this node, not the root: the root's lake wears the menu.
	add_child.call_deferred(_main)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_help = Label.new()
	_help.text = HELP
	_help.position = Vector2(16.0, 8.0)
	_help.add_theme_font_override(&"font", Style.font())
	_help.add_theme_font_size_override(&"font_size", Style.TEXT_SMALL)
	_help.add_theme_color_override(&"font_color", Style.INK)
	_help.add_theme_color_override(&"font_outline_color", Color(0.09, 0.07, 0.07))
	_help.add_theme_constant_override(&"outline_size", 4)
	layer.add_child(_help)


func _process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 6:
		_put(Hive.Stage.SWARM)
		_back_to_hive()
	_help.visible = not bool(_main.get(&"_hive_open"))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _main == null or bool(_main.get(&"_hive_open")):
		return
	match key.keycode:
		KEY_F1:
			_put(Hive.Stage.SWARM)
		KEY_F2:
			_put(Hive.Stage.READY)
		KEY_F3:
			_put(Hive.Stage.SETTLE)
		KEY_F5:
			_back_to_hive()
		_:
			return
	get_viewport().set_input_as_handled()


## The hive at `stage`, its moments already seen so no glide takes the hands.
func _put(stage: Hive.Stage) -> void:
	var hive: Hive = _main.get(&"_hive")
	if hive == null:
		return
	hive.moment_seen = true
	hive.ready_seen = true
	if stage == Hive.Stage.READY:
		hive.first_done = true
		hive.jars = mini(hive.jars, Hive.JARS_PER * (Hive.HARVESTS_MOST - 1))
		hive.harvests = mini(hive.harvests, Hive.HARVESTS_MOST - 1)
	elif stage == Hive.Stage.SWARM:
		hive.first_done = false
		hive.jars = 0
		hive.harvests = 0
	hive.set_stage(stage)


func _back_to_hive() -> void:
	var angler: Angler = _main.get(&"_angler")
	if angler != null and Hive.tile != Vector2.INF:
		angler.stand_at(Hive.tile + Hive.centre + START_OFF)
