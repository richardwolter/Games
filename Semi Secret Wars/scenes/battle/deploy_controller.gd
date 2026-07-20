class_name DeployController
extends Node2D
## Pre-battle placement phase: click to place every drafted hero inside
## LaneField's authored deploy band, then press START BATTLE to commit.
##
## Duo-aware (2026-07-20): heroes are placed as two waves — the two members
## of whichever Duo deploys first, then the two members of the other Duo,
## which arrives `_delay_seconds` later. The player picks BOTH which Duo
## goes first (SWAP ORDER, locked once placement starts) and how many
## seconds separate them (the -/+ stepper, live-persisted to
## GameState.duo_b_delay_seconds so the choice carries into the next run
## instead of resetting — the point is to let the player experiment across
## attempts and settle on a timing that reads well against how the fight
## unfolds). If only one Duo is fielded (the other never got paired at
## prep), deploy collapses back to a single wave — no swap/timer UI shown.
##
## One-shot — there is no mid-battle respawn (Designer, 2026-07-19): a hero
## that dies mid-battle is permanently down for the run (see
## BattleManager._on_hero_died).
##
## Camera controls (wheel zoom, edge/WASD pan) stay live during placement,
## so the player can scout the lane before committing.

signal deploy_chosen(payload: Dictionary)

## Injected by BattleManager before entering the tree. Each is 0, 1, or 2
## hero names — empty when that Duo never got paired at prep.
var field: LaneField
var duo_a: Array = []
var duo_b: Array = []

var _first_is_a := true
var _delay_seconds: float = 0.0
var _placed: Array[Vector2] = []
var _cursor := Vector2.ZERO
var _valid := false
var _hint: Label
var _start_button: Button
var _swap_button: Button
var _delay_label: Label

func _ready() -> void:
	z_index = 40
	_delay_seconds = clampf(GameState.duo_b_delay_seconds, GameState.DUO_B_DELAY_MIN, GameState.DUO_B_DELAY_MAX)
	_build_ui()

func _has_two_waves() -> bool:
	return not duo_a.is_empty() and not duo_b.is_empty()

## The full placement order: whichever Duo is "first" goes first.
func _ordered_names() -> Array:
	return (duo_a + duo_b) if _first_is_a else (duo_b + duo_a)

func _first_wave_count() -> int:
	# Single-wave case (one Duo never got paired at prep): everyone deploys
	# in the one and only wave — there's no "second wave" to hold back.
	if not _has_two_waves():
		return _ordered_names().size()
	return duo_a.size() if _first_is_a else duo_b.size()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color("2c2c2c"))
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.position.y = 24.0
	layer.add_child(_hint)

	if _has_two_waves():
		var controls := HBoxContainer.new()
		controls.set_anchors_preset(Control.PRESET_CENTER_TOP)
		controls.position.y = 64.0
		controls.add_theme_constant_override("separation", 12)
		layer.add_child(controls)

		_swap_button = Button.new()
		_swap_button.add_theme_font_size_override("font_size", 16)
		_swap_button.pressed.connect(_on_swap_pressed)
		controls.add_child(_swap_button)

		var minus := Button.new()
		minus.text = "-1s"
		minus.add_theme_font_size_override("font_size", 16)
		minus.pressed.connect(_on_delay_step.bind(-1.0))
		controls.add_child(minus)

		_delay_label = Label.new()
		_delay_label.add_theme_font_size_override("font_size", 16)
		_delay_label.add_theme_color_override("font_color", Color("2c2c2c"))
		controls.add_child(_delay_label)

		var plus := Button.new()
		plus.text = "+1s"
		plus.add_theme_font_size_override("font_size", 16)
		plus.pressed.connect(_on_delay_step.bind(1.0))
		controls.add_child(plus)

		_update_swap_button()
		_update_delay_label()

	_start_button = Button.new()
	_start_button.text = "START BATTLE"
	_start_button.add_theme_font_size_override("font_size", 22)
	_start_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_start_button.position.y = 104.0 if _has_two_waves() else 64.0
	_start_button.pressed.connect(_on_start_pressed)
	layer.add_child(_start_button)

	_update_hint()

func _on_swap_pressed() -> void:
	if not _placed.is_empty():
		return  # order locks the moment placement starts
	_first_is_a = not _first_is_a
	_update_swap_button()
	_update_hint()

func _update_swap_button() -> void:
	_swap_button.text = "1ST: DUO A (swap)" if _first_is_a else "1ST: DUO B (swap)"
	_swap_button.disabled = not _placed.is_empty()

func _on_delay_step(amount: float) -> void:
	_delay_seconds = clampf(_delay_seconds + amount, GameState.DUO_B_DELAY_MIN, GameState.DUO_B_DELAY_MAX)
	GameState.set_duo_b_delay(_delay_seconds)
	_update_delay_label()

func _update_delay_label() -> void:
	_delay_label.text = "2nd Duo arrives: %ds later" % int(round(_delay_seconds))

func _all_placed() -> bool:
	return _placed.size() >= _ordered_names().size()

func _update_hint() -> void:
	_start_button.disabled = not _all_placed()
	var names := _ordered_names()
	if _all_placed():
		_hint.text = "All heroes placed — press START BATTLE"
	else:
		var current: String = names[_placed.size()]
		var wave := "1st wave" if _placed.size() < _first_wave_count() else "2nd wave"
		_hint.text = "DEPLOYMENT — click the band to place %s (%s, %d/%d)" % \
				[current, wave, _placed.size() + 1, names.size()]

func _process(_delta: float) -> void:
	if field == null or not is_instance_valid(field):
		return
	_cursor = get_global_mouse_position()
	_valid = not _all_placed() and field.is_valid_deploy_point(_cursor)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if field == null or not is_instance_valid(field) or _all_placed():
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var world: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if field.is_valid_deploy_point(world):
			get_viewport().set_input_as_handled()
			var was_empty := _placed.is_empty()
			_placed.append(world)
			if was_empty and _has_two_waves():
				_update_swap_button()  # first click locks the swap toggle
			_update_hint()

func _on_start_pressed() -> void:
	if not _all_placed():
		return
	var names := _ordered_names()
	var first_count := _first_wave_count()
	deploy_chosen.emit({
		"first_names": names.slice(0, first_count),
		"first_positions": _placed.slice(0, first_count),
		"second_names": names.slice(first_count, names.size()),
		"second_positions": _placed.slice(first_count, _placed.size()),
		"delay": _delay_seconds,
	})
	queue_free()

func _draw() -> void:
	var names := _ordered_names()
	var first_count := _first_wave_count()
	# Markers for heroes already placed, tagged with which wave they're in.
	for i in _placed.size():
		var color: Color = GameState.HERO_CATALOG[names[i]].color
		draw_circle(_placed[i], 16.0, color)
		draw_arc(_placed[i], 16.0, 0.0, TAU, 24, Color.BLACK, 2.0, true)
		if _has_two_waves():
			var tag := "1ST" if i < first_count else "2ND"
			var font := ThemeDB.fallback_font
			var w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var at := _placed[i] + Vector2(-w * 0.5, 30.0)
			draw_string_outline(font, at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
			draw_string(font, at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	if _all_placed():
		return
	# Ghost marker under the cursor for the hero being placed next.
	var current_name: String = names[_placed.size()]
	var hero_color: Color = GameState.HERO_CATALOG[current_name].color
	var c := hero_color if _valid else Color(0.75, 0.2, 0.2)
	draw_arc(_cursor, 40.0, 0.0, TAU, 32, c, 4.0, true)
	draw_circle(_cursor, 6.0, c)
	if not _valid:
		draw_line(_cursor + Vector2(-24, -24), _cursor + Vector2(24, 24), c, 4.0, true)
		draw_line(_cursor + Vector2(-24, 24), _cursor + Vector2(24, -24), c, 4.0, true)
	else:
		var font := ThemeDB.fallback_font
		var size := 18
		var w := font.get_string_size(current_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := _cursor + Vector2(-w * 0.5, -48.0)
		draw_string_outline(font, at, current_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
		draw_string(font, at, current_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, hero_color)
