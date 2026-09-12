extends Node
## Opens the settings board and the shed's shelf over a flat magenta ground — the world hidden,
## the clear colour set — and saves a picture of each. Anything magenta inside a board is a
## hole in it. A probe, not a test: `last_holes.log` lists the boards' rects in screen pixels.
##
## Run it with the desktop build, not --headless: nothing renders under the dummy driver.

const SHOTS := {
	&"settings": "res://tools/last_holes_settings.png",
	&"shed": "res://tools/last_holes_shed.png",
}
const LOG := "res://tools/last_holes.log"

var _main: Node
var _frames := 0
var _log: FileAccess


func _ready() -> void:
	var wide := int(OS.get_environment("HOLES_W")) if OS.has_environment("HOLES_W") else 1920
	var tall := int(OS.get_environment("HOLES_H")) if OS.has_environment("HOLES_H") else 1080
	DisplayServer.window_set_size(Vector2i(wide, tall))
	RenderingServer.set_default_clear_color(Color.MAGENTA)
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_main)
	_log = FileAccess.open(LOG, FileAccess.WRITE)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 6:
		# The save puts the window back in fullscreen; the size under test needs a window.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var wide := int(OS.get_environment("HOLES_W")) if OS.has_environment("HOLES_W") else 1920
		var tall := int(OS.get_environment("HOLES_H")) if OS.has_environment("HOLES_H") else 1080
		DisplayServer.window_set_size(Vector2i(wide, tall))
	if _frames == 4:
		for child in _main.get_children():
			if child.name != &"HUD" and (child is CanvasItem or child is CanvasLayer):
				child.set(&"visible", false)
	match _frames:
		14:
			_main.call(&"_set_settings", true)
		26:
			var settings: Control = _main.get_node(^"HUD/Settings")
			var skin := settings.find_child("*", true, false)
			_note("settings", settings)
			_save(&"settings")
			_main.call(&"_set_settings", false)
			_main.call(&"_set_shed", true)
		40:
			var room: ShedRoom = _main.get_node(^"HUD/Shed/Pad/Lines/Room")
			var board: Rect2 = room.call(&"_board_rect")
			_log.store_line("shed board (room)  %s  room global %s" % [board, room.get_global_rect()])
			_save(&"shed")
		44:
			_log.close()
			get_tree().quit()


func _note(what: String, node: Node) -> void:
	for child in node.find_children("*", "SettingsSkin", true, false):
		_log.store_line("%s board  %s  node global %s" % [what, child.get(&"_board"), (child as Control).get_global_rect()])
	if node is SettingsSkin:
		_log.store_line("%s board  %s  node global %s" % [what, node.get(&"_board"), (node as Control).get_global_rect()])


func _save(which: StringName) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOTS[which]))
