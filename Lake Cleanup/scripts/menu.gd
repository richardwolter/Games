## The main menu: the logo and a stack of the game's own planks, standing over the lake itself.
##
## **The menu has no picture of its own** (2026-09-17, `/grill-me` with Richard). It is an
## overlay on the running lake — `Lake` builds it on a layer of its own and holds the world
## in a pose behind it (dogs asleep, hulls moored, the angler idle, the view pulled back to
## the whole lake) — so what is behind the doors is the player's own lake as they left it:
## their clean bays, their fleet, their pack, their flora. The lake clearing up is the
## progress bar, and it is the menu's too; nothing here says a figure.
##
## Nothing here changes scene. Continue, or New game where there is no run to lose, is
## `play_asked`: the lake takes the menu off and glides the view down to the angler. A run
## thrown away is `reload_asked`: the lake reloads itself and comes
## up playing. Supersedes the baked `assets/menu_lake.png` (2026-09-16), `scenes/menu.tscn`
## and the scene change into `main.tscn`.
##
## Six `PlankButton`s: Continue (only when the lake behind loaded a run), New game (over a
## run, `MenuConfirm` asks first — the save is the one thing the menu can destroy),
## Settings (the lake's own board in `menu_mode`: sound and screen, none of the lake's
## rows), How to play (the onboarding cards again — see `letter.gd`), Credits and Quit. Nothing here is a stock Button in a theme: the planks are the
## HUD's own wood, the boards the shop's.
class_name MainMenu
extends Control

const Style := preload("res://scripts/style.gd")
const LOGO := preload("res://assets/mdll_logo_stacked.png")

## Into the lake that is already there.
signal play_asked
## This lake is thrown away for another: a fresh run (`fresh`).
signal reload_asked(fresh: bool)

## The stack: one plank per door, in this order. **Credits is in the stack, above Quit**
## (2026-09-17, Richard); it used to stand alone in the bottom-right corner, which was where
## a credits button lived when the doors were in the opposite corner and the two had the
## screen between them.
##
## **The accented door is the one into the lake** (`PlankButton.accent`): Continue when
## there is a run to go back to, New game when there is not. The same wood, a lighter face
## and the lit edge the shop's affordable rows carry. Only ever one of them, or the accent
## says nothing.
const DOORS := [
	{"key": &"continue", "label": "Continue"},
	{"key": &"new", "label": "New game"},
	{"key": &"settings", "label": "Settings"},
	{"key": &"how", "label": "How to play"},
	{"key": &"credits", "label": "Credits"},
	{"key": &"quit", "label": "Quit"},
]
## Where the stack stands: **centred on the logo's own axis, directly under it**
## (2026-09-17), so the title and the doors read as one block. `DROP` is the gap between the
## logo's foot and the first plank, in the design frame.
const PLANK := Vector2(232.0, 56.0)
const GAP := 12.0
const DROP := 24.0
## The logo, in the design frame: its width as a share of the window, and its top-left
## corner. Anchored to the corner rather than to the stack, which grows and shrinks with
## Continue — a title that moved when a save appeared would read as a bug. Smaller than it
## stood on the baked picture (0.50): that picture was there to carry a title, and the lake
## behind this one is the thing to be looked at. By eye on `tools/last_menu_main.png`.
const LOGO_WIDE := 0.40
const LOGO_AT := Vector2(56.0, 40.0)

## The dark the logo and the planks stand on: a band down the left of the window, full at
## the edge and gone by `SCRIM_TO` of the width. **Drawn, not baked**: the old menu's
## darkening was baked into its picture by decision, and there is no picture any more. The
## left band only — no flat darkening and no vignette, which the baked recipe had — because
## the lake is the message and dimming it dims what the menu is there to show.
const SCRIM := Color(0.02, 0.07, 0.06, 0.78)
const SCRIM_TO := 0.58

## How long the menu takes to come and go. Going is the first stretch of the lake's glide.
const FADE := 0.45

## Whether the lake behind holds a run that was loaded. Decides Continue, the accent, and
## whether New game has anything to ask about. Set by the lake before the menu is shown.
var has_run: bool = false:
	set(on):
		has_run = on
		if is_node_ready():
			_lay_out()

var _scrim: TextureRect
var _logo: TextureRect
var _planks: Dictionary = {}
var _settings: SettingsSkin
var _controls: ControlsSkin
var _credits: CreditsBoard
## The onboarding cards, read again (2026-09-19, issue #24). The same board the letter on
## the shed door opens on a new game; the plank stands above Credits because this is the
## only way back to it once the intro is over.
var _letter: Letter
var _confirm: MenuConfirm
## Whether the doors answer. Not while the menu is fading either way: a plank pressed on its
## way out is a second answer to a question already answered.
var _live: bool = false
var _fade: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Sized by hand rather than by anchors: the parent is a CanvasLayer, and a Control whose
	# parent is not a Control is laid out by nobody. See `Farewell._fill`.
	get_viewport().size_changed.connect(_fill)

	_scrim = TextureRect.new()
	_scrim.name = &"Scrim"
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	_scrim.texture = _band()
	add_child(_scrim)

	_logo = TextureRect.new()
	_logo.name = &"Logo"
	_logo.texture = LOGO
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	# The lockup is a sticker with a soft rim, not pixel art.
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_logo)

	for door: Dictionary in DOORS:
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

	_letter = Letter.new()
	_letter.name = &"Letter"
	_letter.visible = false
	_letter.close_asked.connect(_shut.bind(_show_letter))
	add_child(_letter)

	_confirm = MenuConfirm.new()
	_confirm.name = &"Confirm"
	_confirm.visible = false
	_confirm.confirmed.connect(_start_over)
	_confirm.cancelled.connect(_shut.bind(_show_confirm))
	add_child(_confirm)

	_fill()


## The left band, as a texture: `SCRIM` at the edge, nothing by `SCRIM_TO`. A gradient rather
## than a shader, so there is nothing to compile and a headless run lays it out the same.
func _band() -> GradientTexture2D:
	var ramp := Gradient.new()
	var clear := SCRIM
	clear.a = 0.0
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([SCRIM, clear])
	var band := GradientTexture2D.new()
	band.gradient = ramp
	band.width = 256
	band.height = 4
	band.fill_from = Vector2.ZERO
	band.fill_to = Vector2(SCRIM_TO, 0.0)
	return band


## Cover the window, whatever shape it currently is.
func _fill() -> void:
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	for over: Control in [_scrim, _settings, _controls, _credits, _letter, _confirm]:
		over.position = Vector2.ZERO
		over.size = size
	_lay_out()


## Which doors are open, and where they stand. Continue comes and goes with the run, and
## the rest close up under it rather than leaving its gap.
func _lay_out() -> void:
	# The logo first: its own corner, in proportion to the window, whatever the stack does.
	var frame := size.x / 1280.0
	var wide := size.x * LOGO_WIDE
	var tall := wide * float(LOGO.get_height()) / float(LOGO.get_width())
	_logo.position = (LOGO_AT * frame).floor()
	_logo.size = Vector2(wide, tall).floor()
	var shown: Array = []
	for door: Dictionary in DOORS:
		var key: StringName = door["key"]
		var plank: PlankButton = _planks[key]
		plank.visible = key != &"continue" or has_run
		plank.accent = key == (&"continue" if has_run else &"new")
		plank.queue_redraw()
		if plank.visible:
			shown.append(plank)
	# Under the logo, on its axis. Both come off `_logo`'s own drawn box rather than off
	# `LOGO_AT` and `LOGO_WIDE` again, so the stack cannot drift from the picture it hangs
	# under when either is retuned.
	var middle := _logo.position.x + _logo.size.x * 0.5
	var y := _logo.position.y + _logo.size.y + DROP * frame
	for plank: PlankButton in shown:
		plank.size = PLANK
		plank.position = Vector2(middle - PLANK.x * 0.5, y).floor()
		y += PLANK.y + GAP


## Bring the menu up over the lake: at once (the boot, which comes up under the splash's own
## cover) or faded in (the way back from the game, out of the dark the pose was struck in).
func show_up(at_once: bool = false) -> void:
	_kill_fade()
	for over: Control in [_settings, _controls, _credits, _letter, _confirm]:
		over.visible = false
	visible = true
	_live = true
	_lay_out()
	if at_once:
		modulate.a = 1.0
		return
	modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self, ^"modulate:a", 1.0, FADE)


## Take it off again. The doors stop answering on the instant; the picture takes `FADE`.
func put_away(at_once: bool = false) -> void:
	_kill_fade()
	_live = false
	if at_once:
		visible = false
		return
	_fade = create_tween()
	_fade.tween_property(self, ^"modulate:a", 0.0, FADE)
	_fade.tween_callback(func() -> void: visible = false)


## Whether the menu is up and answering.
func live() -> bool:
	return visible and _live


func _kill_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null


func _take(key: StringName) -> void:
	if not _live:
		return
	var asks := key == &"new" and has_run
	if key == &"quit":
		Sfx.ui(&"ui_close")
	elif key in [&"settings", &"credits", &"how"] or asks:
		# A question only; the start sound waits for the answer.
		Sfx.ui(&"ui_click")
	match key:
		&"continue":
			_play()
		&"new":
			if has_run:
				_show_confirm(true)
			else:
				_play()
		&"settings":
			_show_settings(true)
		&"how":
			_show_letter(true)
		&"credits":
			_show_credits(true)
		&"quit":
			get_tree().quit()


## "Start over?", answered yes. The lake deletes the file: it knows which one is its own.
func _start_over() -> void:
	_show_confirm(false)
	_reload(true)


func _play() -> void:
	_start_sound()
	play_asked.emit()


func _reload(fresh: bool) -> void:
	_live = false
	_start_sound()
	reload_asked.emit(fresh)


## Played on the autoload, which outlives a reload: it is still ringing as the lake comes up.
func _start_sound() -> void:
	var sound := Sfx.main()
	if sound != null:
		sound.play_start()


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


## The same board the letter on the shed door opens, for the harness to ask.
func letter() -> Letter:
	return _letter


func _show_letter(open: bool) -> void:
	_letter.visible = open
	if open:
		_letter.open()


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
##
## The lake under the menu reads no input at all while it is up (`Lake._in_menu`), so
## whatever is left unhandled here is nobody's.
func _unhandled_input(event: InputEvent) -> void:
	if not live():
		return
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
			elif _letter.visible:
				_shut(_show_letter)
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
