class_name Mold
extends Node2D

## A spore clump. Drifts the room until it touches the player, then rides him
## and slows him down. It never damages and it cannot be killed by shooting --
## the only answer is the dash, which shakes it off and destroys it.
##
## That is the whole point of it: a hazard that is not a health problem but a
## resource problem, spending the one button that is also the escape.

enum State { DRIFTING, ATTACHED }

const RADIUS: float = 11.0
const DRIFT_SPEED: float = 46.0
## Radians per second of aimless turn while drifting.
const DRIFT_TURN: float = 1.1
## Once the player is this close the clump stops drifting and homes. Short, so it
## is avoidable, and the drift does most of the work of arriving.
const NOTICE_RANGE: float = 210.0
const HOME_SPEED: float = 118.0
## Distance at which it lands on him.
const GRAB_RANGE: float = 26.0
## Where on the body it sits once attached, and how far it wanders around that.
const CLING_RADIUS: float = 16.0

const COLOR_BODY: Color = Color(0.42, 0.55, 0.32)
const COLOR_SPORE: Color = Color(0.68, 0.78, 0.48)

var bounds: Rect2 = Rect2()

var _state: State = State.DRIFTING
var _dir: Vector2 = Vector2.RIGHT
var _time: float = 0.0
var _cling_angle: float = 0.0
var _host: Node2D = null
var _dying: bool = false


func _ready() -> void:
	_dir = Vector2.from_angle(randf() * TAU)
	_time = randf() * TAU
	_cling_angle = randf() * TAU
	z_index = 1


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _dying:
		return

	match _state:
		State.ATTACHED:
			_ride(delta)
		_:
			_drift(delta)


func _drift(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player_body") as Node2D
	if player != null:
		var to_player := player.global_position - global_position
		if to_player.length() < GRAB_RANGE:
			_attach(player)
			return
		if to_player.length() < NOTICE_RANGE:
			# Homing is deliberately slower than the player's walk. Mold catches
			# people who stand still, not people who are moving.
			_dir = _dir.lerp(to_player.normalized(), minf(1.0, delta * 3.0)).normalized()
			position += _dir * HOME_SPEED * delta
			_confine()
			return

	# Aimless: a slow constant turn, sign flipping on its own clock.
	_dir = _dir.rotated(sin(_time * 0.7) * DRIFT_TURN * delta).normalized()
	position += _dir * DRIFT_SPEED * delta
	_confine()


## Keeps the clump inside the room and turns it around at the edge, so a room
## left alone does not slowly empty itself into the walls.
func _confine() -> void:
	if bounds.size == Vector2.ZERO:
		return
	if position.x < bounds.position.x or position.x > bounds.end.x:
		_dir.x = -_dir.x
	if position.y < bounds.position.y or position.y > bounds.end.y:
		_dir.y = -_dir.y
	position = position.clamp(bounds.position, bounds.end)


func _attach(player: Node2D) -> void:
	_state = State.ATTACHED
	_host = player
	if player.has_method(&"attach_mold"):
		player.attach_mold(self)


## Rides the host, crawling slowly around him. Reparenting was the obvious
## implementation and the wrong one: the player's rig is scaled by the size stat
## and mirrored by facing, and a child of it would flip and squash along with
## him. Following in world space keeps the clump the size it is.
func _ride(_delta: float) -> void:
	if not is_instance_valid(_host):
		burst()
		return
	_cling_angle += 0.9 * _delta
	global_position = _host.global_position \
		+ Vector2.from_angle(_cling_angle) * CLING_RADIUS \
		+ Vector2(0.0, -6.0)


## Shaken off and killed. Called by the dash, and by the clump itself if its
## host stops existing.
func burst() -> void:
	if _dying:
		return
	_dying = true
	if is_instance_valid(_host) and _host.has_method(&"detach_mold"):
		_host.detach_mold(self)
	_host = null
	set_process(true)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, ^"scale", Vector2.ONE * 1.8, 0.22)
	tween.tween_property(self, ^"modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(queue_free)


func is_attached() -> bool:
	return _state == State.ATTACHED


func _draw() -> void:
	# A clump of overlapping blobs that breathe, so it reads as alive rather than
	# as a pickup the player should be walking into.
	var pulse := 1.0 + sin(_time * 3.0) * 0.06
	draw_circle(Vector2.ZERO, RADIUS * pulse, Color(COLOR_BODY, 0.9))
	for i in 5:
		var a := TAU * float(i) / 5.0 + _time * 0.5
		var p := Vector2.from_angle(a) * RADIUS * 0.7
		draw_circle(p, RADIUS * 0.45 * pulse, Color(COLOR_SPORE, 0.75))
	draw_arc(Vector2.ZERO, RADIUS * pulse, 0.0, TAU, 18, COLOR_BODY.darkened(0.4), 1.5)
