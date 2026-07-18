class_name BattleCamera
extends Camera2D
## Battlefield camera with smooth mouse-wheel / keyboard zoom (GDD visual
## direction). The field is deliberately larger than the widest view: fully
## zoomed out you still only frame a chunk of the battle, and zooming dives in
## toward the cursor to watch a skirmish up close. Starts centered on the field.
##
## Controls: mouse wheel (anchored on the cursor) or +/- keys (centered) to
## zoom. Pan by pushing the mouse to the screen edges, dragging with the middle
## mouse button, or WASD/arrow keys. Clicking a hero's HUD panel locks the
## camera onto that hero (focus_on); manual panning breaks the lock.

## World point the camera centers on at start (the field's midpoint).
@export var center_point := Vector2.ZERO
## Widest view. Keep 1920 / zoom_min well below the field width so the whole
## battle never fits on screen — the player surveys the war in chunks.
@export var zoom_min := 0.75
@export var zoom_max := 4.0
## Multiplicative zoom per wheel notch / key press, so each step feels the
## same whether zoomed far out or close in.
@export var zoom_factor := 1.15
## Higher = snappier zoom easing.
@export var zoom_smooth := 12.0
## Higher = tighter tracking while locked onto a followed hero.
@export var follow_smooth := 8.0

@export_group("Panning")
## Pan speed in screen pixels per second (scaled by zoom so travel feels constant).
@export var pan_speed := 1100.0
## How close (px) the mouse must be to a viewport edge to edge-pan.
@export var edge_margin := 24.0
## Half-extents of the pannable area around center_point; the field root sets
## this from its geometry. Zero disables clamping.
@export var pan_limits := Vector2.ZERO

var _target_zoom := 1.0
var _dragging := false
## True while easing toward a wheel zoom: keep the world point under the
## cursor fixed, so zooming in dives toward what the player is pointing at.
var _anchor_cursor := false
## Unit the camera is locked onto (hero-panel click). Null = free camera.
var _follow: Node2D = null

func _ready() -> void:
	add_to_group("battle_camera")
	make_current()
	position = center_point
	_target_zoom = zoom.x

## Lock the camera onto a unit; clicking the same unit's panel again releases.
func focus_on(target: Node2D) -> void:
	_follow = null if _follow == target else target

func follow_target() -> Node2D:
	# A freed instance compares equal to null, so guard with is_instance_valid
	# alone — otherwise a dead hero's freed reference leaks out of here.
	if not is_instance_valid(_follow):
		_follow = null
	return _follow

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
			if _dragging:
				_follow = null
		elif event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(zoom_factor, true)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(1.0 / zoom_factor, true)
	elif event is InputEventMouseMotion and _dragging:
		_move_by(-event.relative / zoom.x)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			_zoom_by(zoom_factor, false)
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			_zoom_by(1.0 / zoom_factor, false)

func _zoom_by(factor: float, anchor_cursor: bool) -> void:
	_target_zoom = clampf(_target_zoom * factor, zoom_min, zoom_max)
	_anchor_cursor = anchor_cursor

func _process(delta: float) -> void:
	_apply_pan(delta)
	_apply_follow(delta)
	if not is_equal_approx(zoom.x, _target_zoom):
		var z := lerpf(zoom.x, _target_zoom, clampf(zoom_smooth * delta, 0.0, 1.0))
		_apply_zoom(z)

## Ease toward the followed unit (released automatically when it's gone).
func _apply_follow(delta: float) -> void:
	if not is_instance_valid(_follow):
		_follow = null
		return
	var to := position.lerp(_follow.global_position, clampf(follow_smooth * delta, 0.0, 1.0))
	_move_by(to - position)

## Set the zoom level; wheel zoom holds the world point under the cursor fixed.
func _apply_zoom(z: float) -> void:
	var cursor_offset := Vector2.ZERO
	if _anchor_cursor:
		var vp := get_viewport()
		cursor_offset = vp.get_mouse_position() - vp.get_visible_rect().size * 0.5
	var anchor_world := position + cursor_offset / zoom.x
	zoom = Vector2(z, z)
	_move_by(anchor_world - cursor_offset / zoom.x - position)

func _apply_pan(delta: float) -> void:
	var dir := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	if dir != Vector2.ZERO:
		# Deliberate key pan breaks the follow lock.
		_follow = null
	if _follow == null:
		# Edge pan is passive (mouse resting near an edge) — ignored while
		# locked so it can't silently fight or cancel the follow.
		dir += _edge_pan_dir()
	if dir == Vector2.ZERO:
		return
	_move_by(dir.limit_length(1.0) * pan_speed * delta / zoom.x)

## Unit direction from the mouse hugging the viewport edges, zero elsewhere.
func _edge_pan_dir() -> Vector2:
	var vp := get_viewport()
	var mouse := vp.get_mouse_position()
	var size := Vector2(vp.get_visible_rect().size)
	if not Rect2(Vector2.ZERO, size).has_point(mouse):
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if mouse.x <= edge_margin:
		dir.x -= 1.0
	elif mouse.x >= size.x - edge_margin:
		dir.x += 1.0
	if mouse.y <= edge_margin:
		dir.y -= 1.0
	elif mouse.y >= size.y - edge_margin:
		dir.y += 1.0
	return dir

func _move_by(motion: Vector2) -> void:
	var p := position + motion
	if pan_limits != Vector2.ZERO:
		p = p.clamp(center_point - pan_limits, center_point + pan_limits)
	position = p
