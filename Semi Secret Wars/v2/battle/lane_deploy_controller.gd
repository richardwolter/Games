class_name LaneDeployController
extends Node2D
## V2's pre-battle placement phase: click to place every drafted hero inside
## the fixed deploy band, then press START BATTLE to commit.
##
## Modeled on V1's one-shot DeployController (scenes/battle/deploy_controller.gd),
## constrained to LaneField's authored deploy band instead of the whole open
## field. Replaces the old persistent live-redeploy verb (Designer, 2026-07-19:
## remove mid-battle respawn) — a hero that dies mid-battle is now permanently
## down for the run, same finality as V1 (see LaneBattleManager._on_hero_died).
##
## Camera controls (wheel zoom, edge/WASD pan) stay live during placement, same
## as V1, so the player can scout the lane before committing.

signal deploy_chosen(positions: Array)

## Injected by LaneBattleManager before entering the tree.
var field: LaneField
var hero_names: Array = []

var _placed: Array[Vector2] = []
var _cursor := Vector2.ZERO
var _valid := false
var _hint: Label
var _start_button: Button

func _ready() -> void:
	z_index = 40
	_build_ui()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color("2c2c2c"))
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.position.y = 24.0
	layer.add_child(_hint)

	_start_button = Button.new()
	_start_button.text = "START BATTLE"
	_start_button.add_theme_font_size_override("font_size", 22)
	_start_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_start_button.position.y = 64.0
	_start_button.pressed.connect(_on_start_pressed)
	layer.add_child(_start_button)

	_update_hint()

func _all_placed() -> bool:
	return _placed.size() >= hero_names.size()

func _update_hint() -> void:
	_start_button.disabled = not _all_placed()
	if _all_placed():
		_hint.text = "All heroes placed — press START BATTLE"
	else:
		var current: String = hero_names[_placed.size()]
		_hint.text = "DEPLOYMENT — click the band to place %s (%d/%d)" % \
				[current, _placed.size() + 1, hero_names.size()]

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
			_placed.append(world)
			_update_hint()

func _on_start_pressed() -> void:
	if not _all_placed():
		return
	deploy_chosen.emit(_placed)
	queue_free()

func _draw() -> void:
	# Markers for heroes already placed.
	for i in _placed.size():
		var color: Color = GameState.HERO_CATALOG[hero_names[i]].color
		draw_circle(_placed[i], 16.0, color)
		draw_arc(_placed[i], 16.0, 0.0, TAU, 24, Color.BLACK, 2.0, true)
	if _all_placed():
		return
	# Ghost marker under the cursor for the hero being placed next.
	var current_name: String = hero_names[_placed.size()]
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
