extends Node
## Opens the main menu on a real window and saves a picture of it bare, with the settings
## board up, with the credits up, and with the start-over question up. A probe, not a test:
## where the planks stand on the art, and whether the boards read as the lake's, are things
## to look at.
##
## Run it with the desktop build, not --headless: nothing renders under the dummy driver.
## The Continue plank shows only if a save exists on this machine.

const SHOTS := {
	&"main": "res://tools/last_menu_main.png",
	&"settings": "res://tools/last_menu_main_settings.png",
	&"credits": "res://tools/last_menu_credits.png",
	&"confirm": "res://tools/last_menu_confirm.png",
}

var _menu: Node
var _frames := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_menu = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_menu)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _menu == null or not _menu.is_inside_tree():
		return
	match _frames:
		# The first frames after the window is resized come back blank.
		14:
			_save(&"main")
			_menu.call(&"_show_settings", true)
		26:
			_save(&"settings")
			_menu.call(&"_show_settings", false)
			_menu.call(&"_show_credits", true)
		38:
			_save(&"credits")
			_menu.call(&"_show_credits", false)
			_menu.call(&"_show_confirm", true)
		50:
			_save(&"confirm")
		54:
			get_tree().quit()


func _save(which: StringName) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOTS[which]))
