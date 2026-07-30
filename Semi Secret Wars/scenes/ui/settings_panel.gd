class_name SettingsPanel
extends CanvasLayer
## The Settings modal — Master / Music / Effects volume, reachable from the
## title screen, the prep menu and the battle HUD (Designer, 2026-07-26).
##
## Same construction as ConfirmPanel (read its doc first — the reasoning about
## PROCESS_MODE_ALWAYS, the click-swallowing scrim, and building from UIStyle
## instead of Godot's own dialogs applies here identically). The one addition
## is the open/close toggle below: this panel is reachable mid-battle, so it
## has to cope with being asked to open while it is already up.
##
## Values are pushed to AudioSettings live as the slider moves — there is no
## OK/Apply step to get wrong, and no "cancel" to restore, because hearing the
## change as you drag IS the confirmation.
##
## Usage: SettingsPanel.toggle(host) from a button, or .open(host).

## Above ConfirmPanel's 200 so a settings panel opened over a prompt is still
## on top and its own Escape handler is the one that answers.
const LAYER := 210
const GROUP := "settings_panel"

const SLIDER_WIDTH := 420.0
const PANEL_WIDTH := 720.0

## Fallback music, played only when nothing else is audible — a volume slider
## with silence behind it can't be judged (Designer, 2026-07-26). The three
## screens that open this panel all run their own theme and keep it playing
## while paused, so in practice this covers the cases they don't: a battle
## whose music failed to start, or a future screen that has none.
const PREVIEW_MUSIC: AudioStream = preload("res://assets/Sounds/Theme_Song_Menu.mp3")
var _preview_music: AudioStreamPlayer

signal closed

## The tree's paused state from BEFORE this panel opened. Settings is reachable
## mid-battle, so it pauses — tweaking volume while the swarm eats your party
## isn't a setting screen, it's a penalty. But it can also be opened on TOP of
## something that already paused (a level-up pick, the results screen), and
## closing must not unpause that. So we restore what we found rather than
## blindly setting false.
var _was_paused := false

## Opens the panel unless one is already up. Returns the live panel either way.
## `host` is any node in the tree — like ConfirmPanel, the panel parents itself
## to the scene root so a caller that frees itself can't take it along.
static func open(host: Node) -> SettingsPanel:
	var existing := _existing(host)
	if existing != null:
		return existing
	var panel := SettingsPanel.new()
	host.get_tree().root.add_child(panel)
	return panel

## Button/hotkey behavior: a second press on the thing that opened it closes it
## again, rather than doing nothing or stacking a second copy.
static func toggle(host: Node) -> void:
	var existing := _existing(host)
	if existing != null:
		existing.close()
		return
	open(host)

static func _existing(host: Node) -> SettingsPanel:
	if host == null or not host.is_inside_tree():
		return null
	var found := host.get_tree().get_first_node_in_group(GROUP)
	return found as SettingsPanel

func _ready() -> void:
	# Reachable during a level-up pick or a results screen, both of which pause
	# the tree — a PAUSABLE panel would freeze its own sliders.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	add_to_group(GROUP)
	_was_paused = get_tree().paused
	get_tree().paused = true
	_build()
	_start_preview_music_if_silent()

## Scans for a music player that's actually audible right now; starts our own
## looping preview only if there is none. Walks the tree rather than reading a
## known node path because the panel is opened from three different scenes,
## each with its own music node — and may outlive any of them.
func _start_preview_music_if_silent() -> void:
	if _music_playing(get_tree().root):
		return
	_preview_music = AudioStreamPlayer.new()
	_preview_music.stream = PREVIEW_MUSIC
	_preview_music.bus = AudioSettings.BUS_MUSIC
	_preview_music.process_mode = Node.PROCESS_MODE_ALWAYS
	if _preview_music.stream is AudioStreamMP3:
		(_preview_music.stream as AudioStreamMP3).loop = true
	add_child(_preview_music)
	_preview_music.play()

## True if any AudioStreamPlayer/2D on the Music bus is mid-playback.
func _music_playing(node: Node) -> bool:
	if node == self:
		return false  # our own preview player doesn't count as pre-existing music
	# Cast explicitly rather than reading .bus/.playing off a plain Node — the
	# two player types share no common base that declares them.
	var p1 := node as AudioStreamPlayer
	if p1 != null and p1.bus == AudioSettings.BUS_MUSIC and p1.playing:
		return true
	var p2 := node as AudioStreamPlayer2D
	if p2 != null and p2.bus == AudioSettings.BUS_MUSIC and p2.playing:
		return true
	for child in node.get_children():
		if _music_playing(child):
			return true
	return false

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.1, 0.1, 0.1, 0.55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.add_theme_stylebox_override("panel", UIStyle.overlay_panel())
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	box.add_child(UIStyle.centered_label("SETTINGS", UIStyle.SIZE_HEADING))

	box.add_child(_build_slider_row("MASTER VOLUME", AudioSettings.master,
			AudioSettings.set_master))
	box.add_child(_build_slider_row("MUSIC VOLUME", AudioSettings.music,
			AudioSettings.set_music))
	# The Effects slider is the one with nothing playing behind it — music runs
	# continuously, combat SFX don't. It previews the UI click on release so the
	# setting can be judged the same way the other two can.
	box.add_child(_build_slider_row("EFFECTS VOLUME", AudioSettings.effects,
			AudioSettings.set_effects, true))

	var display_row := HBoxContainer.new()
	display_row.alignment = BoxContainer.ALIGNMENT_CENTER
	display_row.add_theme_constant_override("separation", 16)
	box.add_child(display_row)
	_fullscreen_button = UIStyle.button(_fullscreen_text(), UIStyle.SIZE_SUBHEAD,
			_on_fullscreen_pressed)
	display_row.add_child(_fullscreen_button)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	row.add_child(UIStyle.button("CLOSE", UIStyle.SIZE_SUBHEAD, close))
	row.add_child(UIStyle.button("EXIT GAME", UIStyle.SIZE_SUBHEAD, _on_exit_pressed))

## FULLSCREEN / WINDOWED toggle (Designer, 2026-07-27). On itch.io the embedded
## canvas has no window chrome to go fullscreen with, so without this the player
## has to leave the page to change it; on desktop it's the display option
## BACKLOG has been carrying. DisplayServer, not the project setting — this
## changes the live window, and is deliberately NOT persisted (a run that boots
## into an unexpected display mode is worse than re-toggling it).
var _fullscreen_button: Button

func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func _fullscreen_text() -> String:
	return "WINDOWED" if _is_fullscreen() else "FULLSCREEN"

func _on_fullscreen_pressed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if _is_fullscreen()
			else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_fullscreen_button.text = _fullscreen_text()

## EXIT GAME. Confirms first — it's reachable mid-battle, and the panel sits
## right next to CLOSE. On desktop it quits the process; on web (itch.io)
## quitting does nothing the player can see, so there it drops back to the title
## screen instead, which is the "quit" a browser build can actually offer
## without a page reload (Designer, 2026-07-27).
func _on_exit_pressed() -> void:
	var prompt := ConfirmPanel.ask(self, "EXIT GAME?",
			"Leave the current run and quit. Progress since your last completed level is lost.",
			"EXIT", _do_exit)
	# ConfirmPanel's own layer (200) sits BELOW this panel's 210 — that ordering
	# exists so a settings panel opened over a prompt wins (see LAYER), but a
	# prompt WE opened has to be the one on top or it's invisible behind us.
	prompt.layer = LAYER + 10

func _do_exit() -> void:
	if OS.has_feature("web"):
		# The tree must NOT be restored to the paused state we found — that state
		# belonged to the battle we're leaving, and a paused title screen is dead
		# input. Cleared before the free so _exit_tree restores false.
		_was_paused = false
		var tree := get_tree()
		close()
		tree.paused = false
		tree.change_scene_to_file(GameState.TITLE_SCREEN)
		return
	get_tree().quit()

## One labeled slider bound to an AudioSettings setter. The live "70%" readout
## is the only reason this needs a closure rather than a direct connect — the
## setter itself takes just the value.
func _build_slider_row(text: String, value: float, setter: Callable,
		preview_on_release := false) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)

	var header := HBoxContainer.new()
	col.add_child(header)
	var name_label := UIStyle.label(text, UIStyle.SIZE_BODY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var pct_label := UIStyle.numeric_label(_pct_text(value), UIStyle.SIZE_BODY, UIStyle.INK_MUTED)
	header.add_child(pct_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Keyboard/gamepad focus would let ui_left/ui_right fight the Escape-to-close
	# handler for the same input; the slider is mouse-driven only.
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		UIStyle.set_numeric_text(pct_label, _pct_text(v)))
	# On release, not on every value change: a sample retriggered each step of
	# a drag is a stutter, not a preview.
	if preview_on_release:
		slider.drag_ended.connect(func(_changed: bool) -> void:
			BattleSfx.play_clip(self, UIStyle.CLICK_SOUND, UIStyle.CLICK_SOUND_START))
	col.add_child(slider)

	return col

func _pct_text(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))

func close() -> void:
	closed.emit()
	queue_free()

## Unpausing happens here, not in close(), so ANY route to this node dying
## restores the tree — including being freed by something other than its own
## close button (an F12 full reset, say). Leaving the game paused forever is
## the one failure mode of pausing here that the player can't recover from.
func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = _was_paused

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
