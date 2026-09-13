## The main menu: the capsule art, and a stack of the game's own planks over it.
##
## The first thing the game shows (2026-09-12, issue #12). The art fills the window — cropped
## to cover rather than letterboxed, anchored so the painted title and the angler stay in —
## and five `PlankButton`s stand on the water under the title: Continue, New game, Settings,
## Credits, Quit. Nothing here is a stock Button in a theme: the planks are the HUD's own
## wood, the boards the shop's, so the menu and the lake are one game.
##
## The art is `assets/MDLL_Menu_Background.jpg` (2026-09-12, replacing the capsule art): the
## title sits in the top middle, so a centred crop keeps it at any aspect.
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

## Where the stack stands, in the design frame: in from the left edge, up from the foot,
## over the open water on the left. The HUD's settings button's size, wider for the longest
## word.
const PLANK := Vector2(232.0, 56.0)
const GAP := 12.0
const LEFT := 64.0
const FOOT := 44.0
## The credits plank's corner: in from the right edge and up from the foot.
const CORNER := Vector2(28.0, 28.0)

## The art covers the window, centred, cropped where it is wider than the window. **Never
## stretched or padded** (Richard, 2026-09-12): a fit-to-width with the edge rows smeared
## into the bands was tried and rejected as a distortion. It is 2.63:1 against 16:9, so at
## 16:9 a strip goes off each side; the art's own margins are what is lost.

## The music, the lake's own track, at the lake's own levels. It starts over when the lake
## does: the lake's two-player crossfade is built into its scene, and one song restarting on
## a scene change was weighed against reworking that, and kept.
const MUSIC_SILENT := -60.0
const MUSIC_LOUDEST := 4.0

@onready var _art: TextureRect = %Art
@onready var _music: AudioStreamPlayer = %Music

var _planks: Dictionary = {}
var _settings: SettingsSkin
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
	for door: Dictionary in DOORS + [CREDITS]:
		var plank := PlankButton.new()
		plank.name = StringName("Door_" + String(door["key"]))
		plank.label = String(door["label"])
		plank.size = PLANK
		plank.pressed.connect(_take.bind(door["key"] as StringName))
		add_child(plank)
		_planks[door["key"]] = plank

	_settings = SettingsSkin.new()
	_settings.name = &"Settings"
	_settings.menu_mode = true
	_settings.visible = false
	_settings.close_asked.connect(_show_settings.bind(false))
	_settings.fullscreen_toggled.connect(func(_on: bool) -> void: Prefs.apply_fullscreen())
	_settings.music_toggled.connect(func(_on: bool) -> void: _push_music())
	_settings.music_level_changed.connect(func(_level: float) -> void: _push_music())
	add_child(_settings)

	_credits = CreditsBoard.new()
	_credits.name = &"Credits"
	_credits.visible = false
	_credits.close_asked.connect(_show_credits.bind(false))
	add_child(_credits)

	_confirm = MenuConfirm.new()
	_confirm.name = &"Confirm"
	_confirm.visible = false
	_confirm.confirmed.connect(_start_over)
	_confirm.cancelled.connect(_show_confirm.bind(false))
	add_child(_confirm)

	for over: Control in [_settings, _credits, _confirm]:
		over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	resized.connect(_lay_out)
	_lay_out()
	_start_music()
	Prefs.changed.connect(_push_music)


## Which doors are open, and where they stand. Continue comes and goes with the save, and
## the rest close up under it rather than leaving its gap.
func _lay_out() -> void:
	var shown: Array = []
	for door: Dictionary in DOORS:
		var key: StringName = door["key"]
		var plank: PlankButton = _planks[key]
		plank.visible = (
			(key != &"continue" or has_save())
			and (key != &"continue_tree" or has_tree_save())
		)
		if plank.visible:
			shown.append(plank)
	var tall := float(shown.size()) * PLANK.y + float(maxi(shown.size() - 1, 0)) * GAP
	var y := size.y - FOOT - tall
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
	Lake.start_tree = tree
	get_tree().change_scene_to_file(LAKE_SCENE)


func _show_settings(open: bool) -> void:
	if open:
		_settings.pull_prefs()
	_settings.visible = open


func _show_credits(open: bool) -> void:
	_credits.visible = open


func _show_confirm(open: bool) -> void:
	_confirm.visible = open


## Escape backs out of whichever board is up. On the bare menu it does nothing: the way out
## of the game is the Quit plank, and a key that quits by accident is not a shortcut.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			if _confirm.visible:
				_show_confirm(false)
			elif _credits.visible:
				_show_credits(false)
			elif _settings.visible:
				_show_settings(false)
			else:
				return
			get_viewport().set_input_as_handled()
		KEY_F11:
			Prefs.store(&"fullscreen", not Prefs.is_fullscreen())
			Prefs.apply_fullscreen()
			_settings.fullscreen = Prefs.is_fullscreen()
			get_viewport().set_input_as_handled()


func _start_music() -> void:
	var track := _music.stream as AudioStreamMP3
	if track != null:
		track.loop = true
	_push_music()
	if not _music.playing:
		_music.play()


## Muting leaves the track running quietly rather than stopping it, as the lake does, so
## turning it back on does not start the song again.
func _push_music() -> void:
	_music.volume_db = (
		lerpf(MUSIC_SILENT, MUSIC_LOUDEST, Prefs.music_level) if Prefs.music_on else MUSIC_SILENT
	)
