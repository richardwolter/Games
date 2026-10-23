extends Node
## The camera tip under a board (2026-10-23, Richard's QA run: "the hint for camera lock
## showed and it was covered" by the upgrades shop). Puts the tip up on the bare lake, opens
## the shop over it, then the settings, and closes each, logging every frame whether the tip
## is drawn, its time left and where it stands among the HUD layer's children.
##
##   godot --headless --path . --fixed-fps 60 res://tools/probe_camera_tip.tscn
##
## Own save, under its own node. `tools/last_probe_camera_tip.log`.

const LOG := "res://tools/last_probe_camera_tip.log"
const SAVE_PATH := "user://probe_camera_tip.save"
var _main: Node
var _frames := 0
var _log: FileAccess


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	add_child.call_deferred(_main)
	_log = FileAccess.open(LOG, FileAccess.WRITE)


func _say(what: String) -> void:
	_log.store_line(what)
	_log.flush()


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > 900:
		_say("timed out")
		get_tree().quit(2)
		return
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 20:
		_main.set(&"_camera_tip_seen", false)
		_main.set(&"_camera_tip_left", -1.0)
		_main.set(&"_play", float(Lake.CAMERA_TIP_AT) + 1.0)
		_say("tip asked for")
	if _frames == 60:
		_main.call(&"_set_menu", true)
		_say("shop opened")
	if _frames == 120:
		_main.call(&"_set_menu", false)
		_say("shop closed")
	if _frames == 160:
		_main.call(&"_set_settings", true)
		_say("settings opened")
	if _frames == 220:
		_main.call(&"_set_settings", false)
		_say("settings closed")
	if _frames >= 20 and _frames % 5 == 0:
		var tip: Node = _main.get(&"_camera_tip")
		var shown := tip != null and (tip as CanvasItem).is_visible_in_tree()
		var index := tip.get_index() if tip != null else -1
		var shop: Node = _main.get(&"_shop_skin")
		var free_cam: Control = _main.get(&"_free_camera")
		_say("%d tip %s left %.2f index %d shop index %d menu %s settings %s paused %s cam %s" % [
			_frames, shown, float(_main.get(&"_camera_tip_left")), index,
			shop.get_index() if shop != null else -1, _main.get(&"_menu_open"),
			_main.get(&"_settings_open"), _main.get(&"_world_paused"),
			free_cam.visible if free_cam != null else null,
		])
	if _frames == 300:
		_say("done")
		get_tree().quit(0)
