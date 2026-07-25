class_name TitleScreen
extends Control
## Entry point scene. Boots before the prep menu — game title, a NEW GAME
## button (always available) and a CONTINUE button (only enabled when a
## save with actual progress exists). Same notebook-page visual language as
## PrepPage/ResultsScreen so the game reads as one continuous world from the
## very first frame.

const INK_COLOR := UIStyle.INK

## Hand-drawn logo replacing the plain text title (Designer, 2026-07-25).
const LOGO_TEXTURE := preload("res://assets/Logo_Menu.png")

## NEW GAME / CONTINUE share one source PNG, stacked top/bottom in two equal
## halves — sliced into separate AtlasTexture regions below instead of two
## source files (Designer, 2026-07-25).
const BUTTONS_TEXTURE := preload("res://assets/Buttons_New_Continue.png")
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
	logo.custom_minimum_size = Vector2(640, 530)
	root.add_child(logo)

	root.add_child(UIStyle.centered_label("A roguelite hero-swarm run", UIStyle.SIZE_BODY))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	root.add_child(spacer)

	root.add_child(UIStyle.texture_button(BUTTONS_TEXTURE, NEW_GAME_REGION, BUTTON_WIDTH, _on_new_game))

	var continue_btn := UIStyle.texture_button(BUTTONS_TEXTURE, CONTINUE_REGION, BUTTON_WIDTH, _on_continue)
	continue_btn.disabled = not _has_progress()
	if continue_btn.disabled:
		continue_btn.modulate = UIStyle.DIM
	root.add_child(continue_btn)

	root.add_child(UIStyle.centered_label("v0.1 — demo build", UIStyle.SIZE_TINY, UIStyle.INK_MUTED))

## Progress worth resuming: any gold banked, any hero unlocked beyond the
## defaults, or a run already in flight. A fresh install has nothing to
## "continue" into that differs from NEW GAME, so the button stays disabled.
func _has_progress() -> bool:
	return GameState.gold > 0 or GameState.banked_xp > 0 or RunState.current_level > 1

func _on_new_game() -> void:
	# full_reset() already routes to the prep menu itself (see its doc
	# comment) — do not change_scene_to_file again here, the node calling
	# this has already been removed from the tree by that point.
	GameState.full_reset()

func _on_continue() -> void:
	get_tree().change_scene_to_file(GameState.PREP_MENU)
