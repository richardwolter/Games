extends Node
## Photographs the language chooser: the flag in the main menu's corner, the board of flags,
## and the menu in every language — `tools/last_language_{main,board,<locale>}.png` and
## `tools/last_language.log`.
##
## Desktop build, not --headless (nothing renders under the dummy driver):
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_language.tscn --log-file tools/last_language_engine.log
##
## **Never writes `settings.cfg`**: each language is applied by hand, not through
## `Prefs.set_language`, and the player's own is put back before quitting. Its own save,
## under its own node, so it cannot touch the player's run.

const SAVE_PATH := "user://probe_language.save"
const LOG_PATH := "res://tools/last_language.log"
const SETTLE := 2.2
const EACH := 0.35
const QUIT_AFTER := 40.0

var _lake: Node
var _age := 0.0
var _log: FileAccess
var _was := ""
var _steps: Array = []
var _next := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_was = Prefs.language
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	Lake.session_save_path = SAVE_PATH
	_lake = load("res://scenes/main.tscn").instantiate()
	_lake.set(&"save_path", SAVE_PATH)
	_lake.set(&"force_front", true)
	add_child(_lake)
	var at := SETTLE
	_steps.append([at, &"main", ""])
	at += EACH
	_steps.append([at, &"board", "open"])
	for entry: Dictionary in Prefs.languages():
		at += EACH
		_steps.append([at, StringName(entry["locale"]), entry["locale"]])
	at += EACH
	_steps.append([at, &"", "quit"])


func _process(delta: float) -> void:
	_age += delta
	if _age > QUIT_AFTER:
		_finish()
		return
	if _next >= _steps.size() or _age < float(_steps[_next][0]):
		return
	var step: Array = _steps[_next]
	_next += 1
	var menu := _lake.get(&"_menu") as MainMenu
	var what: String = step[2]
	if what == "open":
		menu.call(&"_show_languages", true)
	elif what == "quit":
		_finish()
		return
	elif what != "":
		menu.call(&"_show_languages", false)
		_apply(what)
	# Two frames for the redraw to land before the picture.
	await get_tree().process_frame
	await get_tree().process_frame
	var shot := step[1] as StringName
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://tools/last_language_%s.png" % shot)
	)
	_log.store_line("%s: locale %s, flag %s" % [
		shot, TranslationServer.get_locale(), Prefs.current_entry()["flag"]
	])
	_log.flush()


func _apply(locale: String) -> void:
	Prefs.language = locale
	Prefs.apply_language()
	Prefs.call(&"_redraw_all", get_tree().root)
	Prefs.language_changed.emit()


func _finish() -> void:
	Prefs.language = _was
	Prefs.apply_language()
	get_tree().quit()
