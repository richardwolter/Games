extends Node
## Opens each of the three menus on a real window in turn — settings, upgrades, the shed's
## shelf — and saves a picture of each. A probe, not a test: where a title plank crosses its
## board's frame, and where the close cross is nailed to it, are things to look at close up.
##
## Run it with the desktop build, not --headless: nothing renders under the dummy driver.

const SHOTS := {
	&"settings": "res://tools/last_menu_settings.png",
	&"settings_list": "res://tools/last_menu_settings_list.png",
	&"controls": "res://tools/last_menu_controls.png",
	&"controls_capture": "res://tools/last_menu_controls_capture.png",
	&"controls_confirm": "res://tools/last_menu_controls_confirm.png",
	&"upgrades": "res://tools/last_menu_upgrades.png",
	&"upgrades_help": "res://tools/last_menu_upgrades_help.png",
	&"shed": "res://tools/last_menu_shed.png",
}

var _main: Node
var _frames := 0
## The window mode the probe found, put back after the resolution list has been filmed.
var _was_mode: int = DisplayServer.WINDOW_MODE_WINDOWED
## The player's own key overrides while the probe borrows the bind board.
var _was_binds: Dictionary = {}


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	# Under this node and on a save of its own: hung off the root it was the game's own lake,
	# wearing the front over every board it was sent to photograph, on the player's own save.
	_main.set(&"save_path", "user://probe_menus.save")
	add_child.call_deferred(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	match _frames:
		8:
			_main.call(&"_set_settings", true)
		20:
			_save(&"settings")
			# The resolution's dropped list, the one chooser that opens a second layer. The
			# row is a windowed-mode setting and draws no list while it is dead, so the
			# window is put into windowed for these frames — through `DisplayServer`, not
			# `Prefs`, so nothing in `user://` is touched.
			_was_mode = DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1920, 1080))
			var board: Control = _main.get_node(^"HUD/Settings")
			board.set(&"_listing", &"window_size")
			board.queue_redraw()
		26:
			_save(&"settings_list")
			DisplayServer.window_set_mode(_was_mode)
			_main.get_node(^"HUD/Settings").set(&"_listing", &"")
			_main.call(&"_set_controls", true)
		34:
			_save(&"controls")
			# And a cell waiting to be pressed into, over a board that has been touched — the
			# hint and the swap flash only exist in that state. The player's own overrides are
			# taken down first and put back at 40, as `test_lake` does.
			var binds: Node = _main.get(&"_controls")
			_was_binds = Binds.overrides()
			Binds.bind(&"interact", "key", "key:70")
			binds.call(&"_start_capture", &"open_shed", "pad")
		40:
			_save(&"controls_capture")
			# And the question the foot plank asks, whose words are the widest on any board.
			_main.get(&"_controls").call(&"_stop_capture")
			_main.get(&"_controls").call(&"_ask_reset")
		46:
			_save(&"controls_confirm")
			_main.get(&"_controls").get(&"_confirm").visible = false
			Binds.take_overrides(_was_binds)
			_main.call(&"_set_controls", false)
			_main.call(&"_set_settings", false)
			_main.call(&"_set_menu", true)
		52:
			_save(&"upgrades")
			# The first row's "?" hovered, so its blurb is in the picture.
			var skin := _main.get_node(^"HUD/ShopSkin")
			skin.set(&"_help_hovered", 0)
			skin.queue_redraw()
		58:
			_save(&"upgrades_help")
			_main.get_node(^"HUD/ShopSkin").set(&"_help_hovered", -1)
			_main.call(&"_set_menu", false)
			_main.call(&"_set_shed", true)
		70:
			_save(&"shed")
		74:
			get_tree().quit()


func _save(which: StringName) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOTS[which]))
