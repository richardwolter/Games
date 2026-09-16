## The main menu: a picture of the lake itself, the logo standing on it, and a stack of the
## game's own planks under that.
##
## The first thing the game shows (2026-09-12, issue #12). The art fills the window — cropped
## to cover rather than letterboxed — and five `PlankButton`s stand on it: Continue, New game,
## Settings, Credits, Quit. Nothing here is a stock Button in a theme: the planks are the
## HUD's own wood, the boards the shop's, so the menu and the lake are one game.
##
## The art is `assets/menu_lake.png` (2026-09-16, replacing the painted
## `MDLL_Menu_Background.jpg`): the trailer's own last page — the lake still filthy, a few
## clear pools, the angler with a net out and the pack on the island — filmed by
## `tools/shot_menu_bg.tscn` and darkened by `tools/bake_menu_bg.py`. The picture has no
## title painted into it, so the logo is its own node: `mdll_logo_stacked.png`, the v1
## lockup the trailer and the capsules use, standing in the top-left corner over the
## darkened soup with the plank stack below it.
##
## Continue is only there when there is a lake to go back to. New game over a saved lake
## asks first (`MenuConfirm`) — the save is the one thing the menu can destroy. Settings is
## the lake's own board in `menu_mode` (sound and screen, none of the lake's rows), reading
## and writing `Prefs`, so what is set here is what the lake finds. The lake comes back here
## from its own settings board and from the farewell.
class_name MainMenu
extends Control

const Style := preload("res://scripts/style.gd")

const LAKE_SCENE := "res://scenes/main.tscn"

## The stack: one plank per door, in this order. Credits stands alone in the bottom right
## corner, where a credits button lives, and leaves the stack a plank shorter.
##
## The two tree doors start and resume tree test mode (`Lake.tree_mode`, 2026-09-12): the
## proposed upgrade tree played as its own run on its own save, so it can be tried before it
## replaces the shop. Shown in every build, by decision; cleared out before a release export.
const DOORS := [
	{"key": &"continue", "label": "Continue"},
	{"key": &"new", "label": "New game"},
	{"key": &"continue_tree", "label": "Continue (tree)"},
	{"key": &"new_tree", "label": "New game (tree)"},
	{"key": &"settings", "label": "Settings"},
	{"key": &"quit", "label": "Quit"},
]
const CREDITS := {"key": &"credits", "label": "Credits"}
## The tree doors are hidden (2026-09-14, Richard: the tree is set aside, the shop stays).
## The code behind them is kept; flip this to play the tree again.
const TREE_DOORS := false

## Where the stack stands, in the design frame: in from the left edge, up from the foot,
## over the darkened soup on the left. The HUD's settings button's size, wider for the
## longest word.
const PLANK := Vector2(232.0, 56.0)
const GAP := 12.0
const LEFT := 64.0
const FOOT := 44.0
## The credits plank's corner: in from the right edge and up from the foot.
const CORNER := Vector2(28.0, 28.0)

## The logo, in the design frame: its width as a share of the window, and its top-left
## corner. Anchored to the corner rather than to the stack, which grows and shrinks with
## Continue — a title that moved when a save appeared would read as a bug. Both by eye on
## `tools/last_menu_main.png`; retune them there.
const LOGO_WIDE := 0.50
const LOGO_AT := Vector2(64.0, 48.0)

## The art covers the window, centred, cropped where it is wider than the window. **Never
## stretched or padded** (Richard, 2026-09-12): a fit-to-width with the edge rows smeared
## into the bands was tried and rejected as a distortion. It is filmed at 16:9, so at 16:9
## nothing is lost and it is drawn one screen pixel to one on 1080p; a taller or wider
## window crops the sides or the sky.

@onready var _art: TextureRect = %Art
@onready var _logo: TextureRect = %Logo

var _planks: Dictionary = {}
var _settings: SettingsSkin
var _controls: ControlsSkin
var _credits: CreditsBoard
var _confirm: MenuConfirm
## Which save "Start over?" is about: the ordinary one, or the tree run's.
var _confirm_tree: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	for door: Dictionary in DOORS + [CREDITS]:
		var plank := PlankButton.new()
		plank.name = StringName("Door_" + String(door["key"]))
		plank.label = String(door["label"])
		plank.size = PLANK
		# The doors into the lake play the start sound rather than a click; `_take` decides.
		plank.clicks = false
		plank.pressed.connect(_take.bind(door["key"] as StringName))
		add_child(plank)
		_planks[door["key"]] = plank

	_settings = SettingsSkin.new()
	_settings.name = &"Settings"
	_settings.menu_mode = true
	_settings.visible = false
	_settings.close_asked.connect(_shut.bind(_show_settings))
	_settings.controls_asked.connect(_show_controls.bind(true))
	add_child(_settings)

	# The bind board, over the settings board that opens it.
	_controls = ControlsSkin.new()
	_controls.name = &"Controls"
	_controls.visible = false
	_controls.close_asked.connect(_shut.bind(_show_controls))
	add_child(_controls)

	_credits = CreditsBoard.new()
	_credits.name = &"Credits"
	_credits.visible = false
	_credits.close_asked.connect(_shut.bind(_show_credits))
	add_child(_credits)

	_confirm = MenuConfirm.new()
	_confirm.name = &"Confirm"
	_confirm.visible = false
	_confirm.confirmed.connect(_start_over)
	_confirm.cancelled.connect(_shut.bind(_show_confirm))
	add_child(_confirm)

	for over: Control in [_settings, _controls, _credits, _confirm]:
		over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	resized.connect(_lay_out)
	_lay_out()
	_start_music()


## Which doors are open, and where they stand. Continue comes and goes with the save, and
## the rest close up under it rather than leaving its gap.
func _lay_out() -> void:
	# The logo first: its own corner, in proportion to the window, whatever the stack does.
	var frame := size.x / 1280.0
	var wide := size.x * LOGO_WIDE
	var tall := wide * float(_logo.texture.get_height()) / float(_logo.texture.get_width())
	_logo.position = (LOGO_AT * frame).floor()
	_logo.size = Vector2(wide, tall).floor()
	var shown: Array = []
	for door: Dictionary in DOORS:
		var key: StringName = door["key"]
		var plank: PlankButton = _planks[key]
		plank.visible = (
			(key != &"continue" or has_save())
			and (key != &"continue_tree" or (TREE_DOORS and has_tree_save()))
			and (key != &"new_tree" or TREE_DOORS)
		)
		if plank.visible:
			shown.append(plank)
	var stack := float(shown.size()) * PLANK.y + float(maxi(shown.size() - 1, 0)) * GAP
	var y := size.y - FOOT - stack
	for plank: PlankButton in shown:
		plank.position = Vector2(LEFT, y).floor()
		plank.size = PLANK
		y += PLANK.y + GAP
	var credits: PlankButton = _planks[CREDITS["key"]]
	credits.size = PLANK
	credits.position = (size - PLANK - CORNER).floor()


func has_save() -> bool:
	return FileAccess.file_exists(Lake.SAVE_PATH)


func has_tree_save() -> bool:
	return FileAccess.file_exists(Lake.TREE_SAVE_PATH)


func _take(key: StringName) -> void:
	if key == &"quit":
		Sfx.ui(&"ui_close")
	elif key in [&"settings", &"credits"]:
		Sfx.ui(&"ui_click")
	elif (key == &"new" and has_save()) or (key == &"new_tree" and has_tree_save()):
		# Only asks; the start sound waits for the answer.
		Sfx.ui(&"ui_click")
	match key:
		&"continue":
			_open_lake()
		&"new":
			_confirm_tree = false
			if has_save():
				_show_confirm(true)
			else:
				_open_lake()
		&"continue_tree":
			_open_lake(true)
		&"new_tree":
			_confirm_tree = true
			if has_tree_save():
				_show_confirm(true)
			else:
				_open_lake(true)
		&"settings":
			_show_settings(true)
		&"credits":
			_show_credits(true)
		&"quit":
			get_tree().quit()


## The saved lake is thrown away and a fresh one opened. The lake finds no file and starts
## clean; nothing has to be told.
func _start_over() -> void:
	var path := Lake.TREE_SAVE_PATH if _confirm_tree else Lake.SAVE_PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_open_lake(_confirm_tree)


func _open_lake(tree: bool = false) -> void:
	# Played on the autoload, which outlives this scene: it is still ringing as the lake
	# comes up.
	var sound := Sfx.main()
	if sound != null:
		sound.play_start()
	Lake.start_tree = tree
	get_tree().change_scene_to_file(LAKE_SCENE)


## A board closed by the player: the cross, a click off it, Escape, "keep it".
func _shut(close: Callable) -> void:
	Sfx.ui(&"ui_close")
	close.call(false)


func _show_settings(open: bool) -> void:
	if open:
		_settings.pull_prefs()
	elif _controls.visible:
		_controls.visible = false
	_settings.visible = open


## The bind board. Closing it leaves the settings board up: the player asked for the
## controls, not for the settings to go away.
func _show_controls(open: bool) -> void:
	_controls.visible = open


func _show_credits(open: bool) -> void:
	_credits.visible = open
	# The credits roll to the end song, and the playlist comes back under it on the way out.
	var music := MusicStation.main()
	if music != null:
		music.set_ending(open)


func _show_confirm(open: bool) -> void:
	_confirm.visible = open


## Escape backs out of whichever board is up. On the bare menu it does nothing: the way out
## of the game is the Quit plank, and a key that quits by accident is not a shortcut.
func _unhandled_input(event: InputEvent) -> void:
	# Start is the pad's way to the settings, as on the lake. Everything else on the menu is
	# the pad's pointer (scripts/pad.gd): A clicks a plank, B is Escape.
	if event is InputEventJoypadButton and event.is_action_pressed(&"open_settings"):
		_show_settings(not _settings.visible)
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			if _confirm.visible:
				_shut(_show_confirm)
			elif _controls.visible:
				_shut(_show_controls)
			elif _credits.visible:
				_shut(_show_credits)
			elif _settings.visible:
				_shut(_show_settings)
			else:
				return
			get_viewport().set_input_as_handled()
		KEY_F11:
			# Windowed and borderless, the two modes that cannot go wrong. Exclusive is the
			# settings board's, where it can be asked about.
			Prefs.store(&"window_mode", (
				Prefs.WindowMode.WINDOWED if Prefs.is_fullscreen()
				else Prefs.WindowMode.BORDERLESS
			))
			Prefs.apply_window()
			get_viewport().set_input_as_handled()


## The music is the `Music` station's (`scripts/music_station.gd`), an autoload that has been
## playing since the engine started: the menu only clears any room the lake left open.
## Nothing starts or restarts here, so going into the lake is not a cut, and how loud it is
## is the Music bus's (`Prefs`), not this scene's.
func _start_music() -> void:
	var music := MusicStation.main()
	if music != null:
		music.leave_rooms()
