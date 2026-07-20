class_name DeployController
extends Node2D
## Pre-battle deployment phase: the player clicks a spot for each hero in turn.
##
## The player may deploy anywhere on the battlefield (clear of obstacles and
## the Poison Lake). A ghost marker follows the mouse — green when the point
## is legal, red otherwise. Left-click on a legal point places the current
## hero (drawn as a small filled marker in that hero's color) and advances to
## the next one. Once every hero in hero_names has a spot, deploy_chosen
## emits the full array of positions (same order as hero_names) and this
## node removes itself; the BattleManager then spawns the party at those
## exact points and starts the swarm.
##
## Camera controls (wheel zoom, edge/WASD pan) stay live during placement so
## the player can scout the field before committing.

signal deploy_chosen(positions: Array)

## Injected by BattleManager before entering the tree.
var field: StageField
var spawner: MinionSpawner
var hero_names: Array = []

var _placed: Array[Vector2] = []
var _cursor := Vector2.ZERO
var _valid := false
var _hint: Label


func _ready() -> void:
	z_index = 40
	_build_hint()

func _build_hint() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color("2c2c2c"))
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.position.y = 24.0
	layer.add_child(_hint)
	_update_hint()

func _update_hint() -> void:
	var current: String = hero_names[_placed.size()]
	_hint.text = "DEPLOYMENT — click to place %s (%d/%d)" % \
			[current, _placed.size() + 1, hero_names.size()]

func _process(_delta: float) -> void:
	# Defensive: BattleManager now owns freeing this node the instant deploy
	# resolves (see BattleManager._deploy_controller), but guard `field` too —
	# queue_free() defers to end-of-frame, so a node can still take one more
	# _process tick after being queued, and `field` (a separate node this one
	# only holds a reference to) isn't guaranteed to outlive it.
	if field == null or not is_instance_valid(field):
		return
	_cursor = get_global_mouse_position()
	_valid = field.is_valid_deploy_point(_cursor)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if field == null or not is_instance_valid(field):
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		# Validate the click's own position (not the hover cursor) so the
		# confirmed point is exactly where the player clicked.
		var world: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if field.is_valid_deploy_point(world):
			_placed.append(world)
			if _placed.size() >= hero_names.size():
				deploy_chosen.emit(_placed)
				queue_free()
			else:
				_update_hint()

func _draw() -> void:
	# Markers for heroes already placed this deployment.
	for i in _placed.size():
		var color: Color = GameState.HERO_CATALOG[hero_names[i]].color
		draw_circle(_placed[i], 16.0, color)
		draw_arc(_placed[i], 16.0, 0.0, TAU, 24, Color.BLACK, 2.0, true)
	# Ghost marker under the cursor — tinted the CURRENT hero's own color when the
	# point is legal (so the player sees WHO they're placing right at the cursor,
	# not just in the top hint), red when illegal so validity still reads instantly.
	var current_name: String = hero_names[_placed.size()]
	var hero_color: Color = GameState.HERO_CATALOG[current_name].color
	var c := hero_color if _valid else Color(0.75, 0.2, 0.2)
	draw_arc(_cursor, 40.0, 0.0, TAU, 32, c, 4.0, true)
	draw_circle(_cursor, 6.0, c)
	if not _valid:
		draw_line(_cursor + Vector2(-24, -24), _cursor + Vector2(24, 24), c, 4.0, true)
		draw_line(_cursor + Vector2(-24, 24), _cursor + Vector2(24, -24), c, 4.0, true)
	else:
		# Hero name floating just above the ghost ring.
		var font := ThemeDB.fallback_font
		var size := 18
		var w := font.get_string_size(current_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := _cursor + Vector2(-w * 0.5, -48.0)
		draw_string_outline(font, at, current_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
		draw_string(font, at, current_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, hero_color)
