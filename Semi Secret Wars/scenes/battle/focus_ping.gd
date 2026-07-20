class_name FocusPing
extends Node2D
## The player's one in-battle command verb (gameplay-loop rework): a limited-
## charge "focus here" ping. Left-click drops a marker; it stays active
## indefinitely — every hero biases toward it — free (untargeted) heroes walk to
## it (Hero's goal override) and target selection prefers enemies near it
## (Hero._target_score) — until the player right-clicks to cancel it or
## re-pings a new spot (spending another charge). Recharges on objective capture.
##
## Deliberately minimal: the battle stays "off the player's hands" (heroes still
## fight autonomously), but the player gets one simple, meaningful lever to
## commit the party to a spot — a threat to crush, an objective to rush, a
## retreat to cover. In group "focus_ping" so heroes query it each frame.

const MAX_CHARGES := 3
## Visual ring radius (world px).
const PING_RADIUS := 90.0
## How close an enemy must be to the ping to get the targeting bonus. Also read
## by Hero._focus_ping_bonus via influence_radius().
const INFLUENCE_RADIUS := 320.0
## Ring pulse period (seconds) for the idle "still active" breathing animation,
## now that the ring no longer contracts toward an expiry.
const PULSE_PERIOD := 1.4

var charges := MAX_CHARGES
var _pos := Vector2.INF
## True while a ping is live. No timer — stays active until _cancel() (player
## right-click) or a fresh left-click ping replaces it.
var _active := false
## Free-running clock driving the idle pulse animation (see _draw).
var _pulse_t := 0.0
var _field: StageField
var _label: Label

func _ready() -> void:
	add_to_group("focus_ping")
	# Above the fog (z 20), below the HUD CanvasLayer. Deploy (z 40) is gone by
	# the time this exists (created once the battle starts).
	z_index = 30
	_field = get_tree().get_first_node_in_group("field")
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color("2c2c2c"))
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.position.y = -40.0
	layer.add_child(_label)
	_refresh_label()

## True while a live ping is on the field (heroes query this).
func has_active_ping() -> bool:
	return _active and _pos != Vector2.INF

func ping_pos() -> Vector2:
	return _pos

func influence_radius() -> float:
	return INFLUENCE_RADIUS

## Objective capture refunds a charge (BattleManager._on_objective_captured).
func add_charge() -> void:
	charges = mini(charges + 1, MAX_CHARGES)
	_refresh_label()

func _process(delta: float) -> void:
	if _active:
		_pulse_t = fmod(_pulse_t + delta, PULSE_PERIOD)
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if _active:
			get_viewport().set_input_as_handled()
			_cancel()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if charges <= 0:
		return
	var world: Vector2 = get_canvas_transform().affine_inverse() * event.position
	# Ignore clicks off the field ellipse (e.g. panning past the page edge).
	if _field != null and (world / _field.field_radius).length_squared() > 1.0:
		return
	get_viewport().set_input_as_handled()
	_pos = world
	_active = true
	_pulse_t = 0.0
	charges -= 1
	_refresh_label()
	queue_redraw()

## Player right-click: cancels a live ping without spending/refunding a charge.
func _cancel() -> void:
	_active = false
	_pos = Vector2.INF
	queue_redraw()

func _refresh_label() -> void:
	if _label != null:
		_label.text = "FOCUS PING: %d/%d   (left-click a spot, right-click to cancel)" % [charges, MAX_CHARGES]

func _draw() -> void:
	if not has_active_ping():
		return
	# Idle "still active" breathing pulse (no expiry to count down to anymore).
	var a: float = 0.5 + 0.5 * sin(_pulse_t / PULSE_PERIOD * TAU)
	var col := Color(0.95, 0.72, 0.18, 0.55 + 0.3 * a)
	var r := PING_RADIUS * (0.9 + 0.1 * a)
	draw_arc(_pos, r, 0.0, TAU, 44, col, 4.0, true)
	draw_arc(_pos, r * 0.45, 0.0, TAU, 28, col, 3.0, true)
	draw_line(_pos + Vector2(-r, 0.0), _pos + Vector2(r, 0.0), col, 2.0, true)
	draw_line(_pos + Vector2(0.0, -r), _pos + Vector2(0.0, r), col, 2.0, true)
