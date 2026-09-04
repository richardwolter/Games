class_name TitleScreen
extends Control
## Entry point scene. Boots before the prep menu — game title, a NEW GAME
## button (always available) and a CONTINUE button (only enabled when a
## save with actual progress exists). Same notebook-page visual language as
## PrepPage/ResultsScreen so the game reads as one continuous world from the
## very first frame.

const INK_COLOR := UIStyle.INK

## Hand-drawn logo replacing the plain text title (Designer, 2026-07-25).
## Swapped to the coloured version 2026-07-26, then to the final wordmark
## 2026-07-28 — the new canvas is 3024x2028 (wider than the old 3024x2502), so
## the box height below drops to keep the art at its natural aspect.
const LOGO_TEXTURE := preload("res://assets/sprites/Logo_Semi-Secret-Wars.png")

## NEW GAME / CONTINUE share one source PNG, stacked top/bottom in two equal
## halves — sliced into separate AtlasTexture regions below instead of two
## source files (Designer, 2026-07-25). Coloured version 2026-07-26: identical
## 1590x1152 canvas with the same two halves, so the regions carry over
## unchanged.
const BUTTONS_TEXTURE := preload("res://assets/Buttons_New_Continue_Color.png")
const NEW_GAME_REGION := Rect2(0, 0, 1590, 576)
const CONTINUE_REGION := Rect2(0, 576, 1590, 576)
const BUTTON_WIDTH := 340.0

func _ready() -> void:
	var bg := PrepPage.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_theme_constant_override("separation", 28)
	add_child(root)

	var logo := TextureRect.new()
	logo.texture = LOGO_TEXTURE
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(640, 429)
	root.add_child(logo)

	# SUBHEAD, not BODY (Designer, 2026-07-26): under a 640-wide logo the tagline
	# was reading as fine print rather than as the game's one-line pitch.
	root.add_child(UIStyle.centered_label("Hero team-up Autobattler", UIStyle.SIZE_SUBHEAD))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	root.add_child(spacer)

	root.add_child(UIStyle.texture_button(BUTTONS_TEXTURE, NEW_GAME_REGION, BUTTON_WIDTH, _on_new_game))

	var continue_btn := UIStyle.texture_button(BUTTONS_TEXTURE, CONTINUE_REGION, BUTTON_WIDTH, _on_continue)
	continue_btn.disabled = not _has_progress()
	if continue_btn.disabled:
		continue_btn.modulate = UIStyle.DIM
	root.add_child(continue_btn)

	# SETTINGS and CREDITS share a row: both are secondary to the two art
	# buttons above, and stacking them would push the version line off the
	# bottom of the layout.
	var minor_row := HBoxContainer.new()
	minor_row.alignment = BoxContainer.ALIGNMENT_CENTER
	minor_row.add_theme_constant_override("separation", 18)
	minor_row.add_child(UIStyle.button("HOW TO PLAY", UIStyle.SIZE_SMALL, _open_how_to_play))
	minor_row.add_child(UIStyle.button("SETTINGS", UIStyle.SIZE_SMALL, _open_settings))
	minor_row.add_child(UIStyle.button("CREDITS", UIStyle.SIZE_SMALL, _open_credits))
	root.add_child(minor_row)

	root.add_child(UIStyle.numeric_label("v0.1 — demo build", UIStyle.SIZE_TINY, UIStyle.INK_MUTED, true))

	# The title music player lives in title_screen.tscn, so it can't be given a
	# bus in the inspector (AudioSettings creates the buses at runtime) — route
	# it here so the Music slider reaches the menu theme too.
	var music := get_node_or_null("AudioListener2D/1StMenu") as AudioStreamPlayer
	if music != null:
		music.bus = AudioSettings.BUS_MUSIC
		# SettingsPanel pauses the tree; a PAUSABLE player would cut out exactly
		# when the player opens Settings to set the music volume.
		music.process_mode = Node.PROCESS_MODE_ALWAYS
		# Loop it — the title is a screen players leave sitting.
		if music.stream is AudioStreamMP3:
			(music.stream as AudioStreamMP3).loop = true

func _open_settings() -> void:
	SettingsPanel.toggle(self)

func _open_credits() -> void:
	CreditsPanel.toggle(self)

func _open_how_to_play() -> void:
	HowToPlayPanel.toggle(self)

## Escape opens Settings from the title screen — there's nothing else for it to
## back out to here. ConfirmPanel, SettingsPanel and CreditsPanel all consume
## Escape while they're up, so this can't fire underneath any of them.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_settings()

## Progress worth resuming: a run saved mid-flight, any gold banked, or any
## hero unlocked beyond the defaults. A fresh install has nothing to "continue"
## into that differs from NEW GAME, so the button stays disabled.
func _has_progress() -> bool:
	return RunState.resumable or GameState.gold > 0 or GameState.banked_xp > 0

## NEW GAME wipes the save (gold, banked XP, skill trees, career stats), so it
## asks first whenever there is anything to lose (Designer, 2026-07-26). On a
## fresh install there is no save to destroy and the prompt would be noise, so
## it starts straight away — the same _has_progress test the CONTINUE button
## uses to decide whether a save is worth resuming.
func _on_new_game() -> void:
	if not _has_progress():
		_start_new_game()
		return
	ConfirmPanel.ask(self, "CAREFUL",
			"Starting a new game erases your saved progress. This cannot be undone.",
			"Start New Game", _start_new_game, "Cancel")

func _start_new_game() -> void:
	# full_reset() routes itself — into the TUTORIAL for a wiped save (which is
	# what this always produces), or to the prep menu once the tutorial has been
	# played. Either way do not change_scene_to_file again here: the node calling
	# this has already been removed from the tree by that point.
	GameState.full_reset()

## CONTINUE resumes an in-flight run straight into its battlefield when one was
## saved (Designer, 2026-07-26 — closing the game after clearing a level must
## not cost you the run); otherwise it lands on the prep menu, which is what
## "continue" meant before runs persisted. RunState loaded the run at boot, so
## current_level/party/boons are already in place by the time the battlefield
## reads them.
func _on_continue() -> void:
	if RunState.resumable:
		get_tree().change_scene_to_file(GameState.BATTLEFIELD)
		return
	get_tree().change_scene_to_file(GameState.PREP_MENU)
