## Pan, zoom, and follow the car during a crossing.
##
## The strait is far wider than the screen, so the camera is a real tool now:
## you zoom out to plan the span and in to seat a piece precisely.
extends Camera2D

@export var pan_speed: float = 1400.0
@export var zoom_step: float = 1.12
@export var max_zoom: float = 1.6
## Raised from 3.0 when the lead offset below went in. A lerp against a moving
## target settles at a lag proportional to speed, and at 3.0 that lag was ~8% of
## the screen — enough that the car sat at 0.25 while driving and 0.33 parked,
## so the framing visibly shifted every time it set off or stopped. At 5.0 both
## land on 0.33.
@export var follow_smoothing: float = 5.0
## Where the car sits across the screen while the camera is following it, as a
## fraction from the left edge. 0.5 would centre it; below that it rides left of
## centre and the extra room goes ahead of it, which is the direction it is
## about to drive into and the only direction anything new appears from.
##
## Expressed as a fraction of the view rather than a distance in world units so
## it holds at every zoom level: zoomed right in, a fixed offset would throw the
## car off screen entirely.
@export_range(0.1, 0.5, 0.01) var follow_screen_position: float = 0.33

var _follow_target: Node2D = null
var _dragging: bool = false
## Mouse-drag pan accumulated since the last physics step.
##
## Applied in _physics_process rather than straight from the input callback: the
## camera's transform is interpolated now, and writing it between physics steps
## puts it somewhere the interpolator is about to overwrite, which shows up as the
## view snagging while you drag.
var _pan_pending: Vector2 = Vector2.ZERO
## Wheel zoom accumulated since the last physics step, and the world point the
## cursor was over when it was rolled. Deferred for the same reason the pan is:
## zoom moves the camera, and moving it between physics steps puts it somewhere
## the interpolator overwrites.
var _zoom_pending: float = 1.0
var _zoom_anchor: Vector2 = Vector2.ZERO
## Zooming out further than this would put terrain edges on screen. Derived from
## the limits, so it changes with the level.
var _min_zoom: float = 0.12


## The camera runs on the physics clock and IS interpolated, like everything else
## it can see.
##
## It used to do the opposite — interpolation switched off, movement driven from
## _process, and _follow_point() blending the target's last two physics positions
## by hand — on the reasoning that interpolating a camera makes the view lag the
## input by a physics frame. That reasoning is sound and the setup still did not
## work, because of something the engine does that the script could not see:
## Camera2D FORCES its process callback to physics whenever physics interpolation
## is enabled for the project (camera_2d.cpp, and it says so in a warning on every
## run). So the position computed each rendered frame was never applied when it
## was computed — it sat until the next physics tick and was then applied in one
## step, with no interpolation on the camera to smooth it, while the truck it was
## chasing was being interpolated perfectly. The relative motion between the two
## is the judder, and it is worst on the fastest-moving thing on screen, which is
## exactly the truck at speed.
##
## Both on the same clock, interpolated the same way, is the only arrangement in
## which a followed body can sit still on screen. The physics frame of latency is
## real and is not perceptible; the judder was.
func _ready() -> void:
	# Stated outright rather than left to the engine to override, which is what it
	# was doing — with a warning on every run that turned out to be the whole bug.
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	get_viewport().size_changed.connect(refit)


## Recompute how far out the player may zoom and pull the current zoom into
## range. Call after the limits change.
func refit() -> void:
	var vp := get_viewport_rect().size
	var span := Vector2(
		maxf(float(limit_right - limit_left), 1.0),
		maxf(float(limit_bottom - limit_top), 1.0)
	)
	# Whichever axis runs out of world first sets the floor: below this the
	# viewport is wider (or taller) than the terrain and you see past its edge.
	_min_zoom = maxf(vp.x / span.x, vp.y / span.y)
	_apply_zoom(1.0)
	# A level build moves the camera outright before calling this. Now that the
	# camera is interpolated, an unannounced jump gets smeared into a pan from
	# wherever the last level left it — so the jump has to be declared.
	reset_physics_interpolation()


func follow(target: Node2D) -> void:
	_follow_target = target


func stop_following() -> void:
	_follow_target = null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_queue_zoom(zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_queue_zoom(1.0 / zoom_step)
			MOUSE_BUTTON_MIDDLE:
				_dragging = mb.pressed
				if _dragging:
					stop_following()
	elif event is InputEventMouseMotion and _dragging:
		_pan_pending -= (event as InputEventMouseMotion).relative / zoom.x


## A wheel notch, held until the next physics step. The anchor is recorded here,
## while the zoom the cursor was read under is still the current one.
func _queue_zoom(factor: float) -> void:
	_zoom_pending *= factor
	_zoom_anchor = get_global_mouse_position()


func _apply_zoom(factor: float, anchor := Vector2.INF) -> void:
	var before := zoom.x
	var level := clampf(before * factor, _min_zoom, maxf(max_zoom, _min_zoom))
	zoom = Vector2(level, level)

	# Zoom toward the cursor: keep whatever the mouse is over sitting still on
	# screen, so zooming in on a piece at the far end of the strait doesn't also
	# require panning back to it. Uses the achieved ratio rather than the
	# requested factor, so a notch that hits the zoom limit doesn't slide the view
	# sideways for nothing.
	#
	# Skipped while following the truck — there the camera's job is to frame the
	# truck, and an anchor pull would only be fought back by the next lerp.
	if anchor.is_finite() and not is_instance_valid(_follow_target):
		position = anchor - (anchor - position) * (before / level)

	_clamp_to_limits()


## Camera2D's limits clamp what gets DRAWN, not where the node sits — so without
## this you can keep dragging past the edge while the view stays put, and the
## camera then lags on the way back. Clamping the position makes the edge feel
## solid.
func _clamp_to_limits() -> void:
	var half := get_viewport_rect().size * 0.5 / zoom
	var min_x := float(limit_left) + half.x
	var max_x := float(limit_right) - half.x
	var min_y := float(limit_top) + half.y
	var max_y := float(limit_bottom) - half.y

	# Zoomed out far enough that the whole level fits, there is nothing to pan
	# to — centre on the bounds rather than letting it drift.
	position.x = clampf(position.x, min_x, max_x) if min_x <= max_x \
		else (float(limit_left) + float(limit_right)) * 0.5
	position.y = clampf(position.y, min_y, max_y) if min_y <= max_y \
		else (float(limit_top) + float(limit_bottom)) * 0.5


func _physics_process(delta: float) -> void:
	if _pan_pending != Vector2.ZERO:
		position += _pan_pending
		_pan_pending = Vector2.ZERO

	if not is_equal_approx(_zoom_pending, 1.0):
		_apply_zoom(_zoom_pending, _zoom_anchor)
		_zoom_pending = 1.0

	var move := Vector2(
		Input.get_axis(&"ui_left", &"ui_right"),
		Input.get_axis(&"ui_up", &"ui_down")
	)
	if move != Vector2.ZERO:
		stop_following()
		position += move * pan_speed * delta / zoom.x
	elif is_instance_valid(_follow_target):
		# Exponential rather than `smoothing * delta`, so the chase settles at the
		# same rate whatever the tick rate is. That matters more than it used to:
		# desktop runs physics at 120 and web at 60, and the naive form makes the
		# camera twice as tight on one as on the other.
		position = position.lerp(
			_follow_point(), 1.0 - exp(-follow_smoothing * delta)
		)
	_clamp_to_limits()


## Where the camera wants to be so the car lands at follow_screen_position.
##
## Sitting the camera ahead of the car by that much is the whole trick; the
## clamp then quietly cancels it at the ends of the level, where there is no
## more world to show and centring is the only option anyway.
##
## Reads global_position directly. This used to blend the target's last two
## physics positions by hand, to get where the car was being DRAWN rather than
## where it last stepped — which is the right thing to do from a _process camera,
## and the wrong thing from this one. Both nodes are now sampled on the same
## physics tick and interpolated together by the engine, so reaching for the
## interpolated position here would apply the blend twice and put the camera half
## a step ahead of the truck instead of on it.
func _follow_point() -> Vector2:
	var half_width := get_viewport_rect().size.x * 0.5 / zoom.x
	var lead := half_width * (0.5 - follow_screen_position) * 2.0
	return _follow_target.global_position + Vector2(lead, 0.0)
