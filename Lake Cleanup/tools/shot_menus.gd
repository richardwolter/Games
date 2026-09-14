extends Node
## Opens each of the three menus on a real window in turn — settings, upgrades, the shed's
## shelf — and saves a picture of each. A probe, not a test: where a title plank crosses its
## board's frame, and where the close cross is nailed to it, are things to look at close up.
##
## Run it with the desktop build, not --headless: nothing renders under the dummy driver.

const SHOTS := {
	&"settings": "res://tools/last_menu_settings.png",
	&"upgrades": "res://tools/last_menu_upgrades.png",
	&"upgrades_help": "res://tools/last_menu_upgrades_help.png",
	&"shed": "res://tools/last_menu_shed.png",
}

var _main: Node
var _frames := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_main)
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
			_main.call(&"_set_settings", false)
			_main.call(&"_set_menu", true)
		32:
			_save(&"upgrades")
			# The first row's "?" hovered, so its blurb is in the picture.
			var skin := _main.get_node(^"HUD/ShopSkin")
			skin.set(&"_help_hovered", 0)
			skin.queue_redraw()
		38:
			_save(&"upgrades_help")
			_main.get_node(^"HUD/ShopSkin").set(&"_help_hovered", -1)
			_main.call(&"_set_menu", false)
			_main.call(&"_set_shed", true)
		50:
			_save(&"shed")
		54:
			get_tree().quit()


func _save(which: StringName) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOTS[which]))
