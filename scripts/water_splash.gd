## Splashes where things hit the water.
##
## Ported from Strait Across (scripts/water_splash.gd). The sound hook is dropped
## for now — this project has no audio autoload yet — everything else is kept
## because it is exactly what a lake full of settling junk needs.
##
## Drawn by hand rather than with a particle node. Two reasons. The game renders on
## the Compatibility backend for the web build, where GPUParticles2D is the part of
## the engine most likely to behave differently from the desktop editor, and a
## splash that only appears for the developer is worse than none. And the art is
## flat and illustrated — default round particle dots read as a different game
## pasted over this one, where a drawn crown of water does not.
##
## One node handles every splash in the lake. Nothing is instanced per impact:
## drops and crowns live in flat arrays, are integrated in _process, and the node
## stops processing entirely the moment the last one dies. A lake of gently bobbing
## rubbish is the common case and it must cost nothing.
##
## Isometric, so a splash is three things at once: a ring spreading flat across the
## surface, a crown thrown up off it, and a scatter of drops falling back in. The
## ring is what places the splash on the plane — without it, a crown drawn at a
## point could be anywhere along that line of sight.
class_name WaterSplash
extends Node2D

## Pale, faintly blue-shifted white. The water shader already tints everything
## below the line, so a splash drawn in flat white would be the only pure white on
## screen and would read as a hole rather than as water.
const FOAM := Color(0.93, 0.98, 1.0)

## Most opaque a crown ever gets. Short of solid on purpose: several pieces
## breaking the surface at once at full opacity merge into a single white slab
## rather than reading as several separate splashes.
const PEAK_ALPHA := 0.72

## Hard ceiling on live drops. Past this the extra drops are invisible anyway and
## only cost draw calls.
const MAX_DROPS := 260

## How long a crown takes to rise and fade, in seconds. Short: a splash is a
## punctuation mark, and one that hangs about turns into fog.
const CROWN_LIFE := 0.42

## Pixels per second squared pulling drops back down. Not the world's gravity —
## drops are small and read better falling a little faster than the junk does.
const DROP_GRAVITY := 1400.0

## Below this there is no splash at all. A piece drifting down onto the water under
## buoyancy alone is settling, not landing, and giving that a crown makes the lake
## look permanently agitated.
const MIN_SPEED := 135.0

## Shortest gap between two splashes from the same body. Junk jostling on the
## surface crosses the waterline many times a second, and without this every one of
## those is a full crown.
const RETRIGGER_DELAY := 0.22

## How far a ring spreads, as a multiple of its crown's span. Isometric, so a splash also
## gets the flat ring a side view could never show.
const RING_SPREAD := 1.6

## Live drops, as parallel arrays. Swap-removed on death, so the live range is
## always the front of each array and there are no holes to skip.
var _drop_pos := PackedVector2Array()
var _drop_vel := PackedVector2Array()
var _drop_life := PackedFloat32Array()
var _drop_size := PackedFloat32Array()
## The surface height each drop came off, and falls back through. Per drop rather than one
## waterline for the lake: on an isometric plane, the surface is at a different screen
## height everywhere.
var _drop_floor := PackedFloat32Array()

## Live crowns: where, how far along, and how wide at full spread.
var _crown_at := PackedVector2Array()
var _crown_age := PackedFloat32Array()
var _crown_span := PackedFloat32Array()

var _last_splash: Dictionary[int, float] = {}


func _ready() -> void:
	set_process(false)


## Throw up a splash. `strength` is 0..1 — a cup slipping in against a fridge
## dropped from the sky.
func splash(at: Vector2, strength: float) -> void:
	var force := clampf(strength, 0.0, 1.0)
	var span := lerpf(40.0, 130.0, force)

	_crown_at.append(at)
	_crown_age.append(0.0)
	_crown_span.append(span)

	var wanted := 4 + roundi(force * 13.0)
	for i in wanted:
		if _drop_life.size() >= MAX_DROPS:
			break
		# Thrown from across the crown's mouth rather than all from its centre, so
		# the scatter reads as water leaving a surface instead of a firework.
		var from_centre := randf_range(-1.0, 1.0)
		_drop_pos.append(at + Vector2(from_centre * span * 0.4, 0.0))
		_drop_floor.append(at.y)
		_drop_vel.append(Vector2(
			from_centre * span * randf_range(0.8, 1.7),
			-lerpf(170.0, 430.0, force) * randf_range(0.55, 1.15)
		))
		_drop_life.append(randf_range(0.32, 0.7))
		# Sized against the crown rather than in absolute pixels, so drops stay
		# readable if the lake view is ever zoomed out.
		_drop_size.append(span * randf_range(0.018, 0.05))

	set_process(true)
	queue_redraw()


## A single drop of water, thrown from wherever you say. For water running off something
## hauled out of the lake. It falls back through the height it was thrown from.
func drip(at: Vector2, vel: Vector2, size: float, life: float) -> void:
	if _drop_life.size() >= MAX_DROPS:
		return
	_drop_pos.append(at)
	_drop_floor.append(at.y)
	_drop_vel.append(vel)
	_drop_life.append(life)
	_drop_size.append(size)
	set_process(true)
	queue_redraw()


## Splash for a body that has just crossed the surface, if it was moving fast
## enough to be worth one and hasn't splashed a moment ago.
##
## `width` is how wide the thing is in world units, which is most of what decides
## how big a splash looks right — a pallet going in flat throws a long low sheet, a
## bottle a small one, at the same speed.
func splash_for(body: Node2D, speed: float, width: float) -> void:
	if speed < MIN_SPEED:
		return
	var id := body.get_instance_id()
	var now := float(Time.get_ticks_msec()) * 0.001
	if now - float(_last_splash.get(id, -99.0)) < RETRIGGER_DELAY:
		return
	_last_splash[id] = now

	var from_speed := clampf(speed / 720.0, 0.0, 1.0)
	var from_size := clampf(width / 300.0, 0.15, 1.0)
	splash(body.global_position, from_speed * 0.65 + from_size * 0.35)


func _process(delta: float) -> void:
	var i := 0
	while i < _drop_life.size():
		var life := _drop_life[i] - delta
		var vel := _drop_vel[i] + Vector2(0.0, DROP_GRAVITY * delta)
		var pos := _drop_pos[i] + vel * delta
		# Gone when it runs out or when it falls back through the surface it came
		# from. Drops must not be seen underwater — the water is drawn over
		# everything below the line and a drop under it looks like a bug.
		if life <= 0.0 or (vel.y > 0.0 and pos.y >= _drop_floor[i]):
			var last := _drop_life.size() - 1
			_drop_pos[i] = _drop_pos[last]
			_drop_vel[i] = _drop_vel[last]
			_drop_life[i] = _drop_life[last]
			_drop_size[i] = _drop_size[last]
			_drop_floor[i] = _drop_floor[last]
			_drop_pos.resize(last)
			_drop_vel.resize(last)
			_drop_life.resize(last)
			_drop_size.resize(last)
			_drop_floor.resize(last)
			continue
		_drop_pos[i] = pos
		_drop_vel[i] = vel
		_drop_life[i] = life
		i += 1

	var c := 0
	while c < _crown_age.size():
		var age := _crown_age[c] + delta
		if age >= CROWN_LIFE:
			var last := _crown_age.size() - 1
			_crown_at[c] = _crown_at[last]
			_crown_age[c] = _crown_age[last]
			_crown_span[c] = _crown_span[last]
			_crown_at.resize(last)
			_crown_age.resize(last)
			_crown_span.resize(last)
			continue
		_crown_age[c] = age
		c += 1

	queue_redraw()
	if _drop_life.is_empty() and _crown_age.is_empty():
		set_process(false)
		# The cooldown table is the one thing here that would otherwise grow for the
		# life of the session, and with nothing splashing there is nothing whose
		# cooldown can still matter.
		_last_splash.clear()


func _draw() -> void:
	for c in _crown_age.size():
		var t := _crown_age[c] / CROWN_LIFE
		var span := _crown_span[c]
		var at := _crown_at[c]
		# Spreads outward and sinks as it fades, which is the whole motion of a
		# crown collapsing back into the surface.
		var width := span * lerpf(0.5, 1.0, t)
		var height := span * 0.5 * (1.0 - t * t)
		# Full strength for the first half, then out. Fading from the first frame
		# made the crown look like it was already dying when it appeared, which at a
		# quarter of a second is the only impression it gets to make.
		var alpha := clampf((1.0 - t) / 0.5, 0.0, 1.0) * PEAK_ALPHA
		var ink := Color(FOAM, alpha)
		# The ring: flat on the water, spreading and thinning. Only an isometric view can
		# show this, and it is what tells the eye where on the plane the splash happened.
		var ring := span * RING_SPREAD * t
		# On the frame a splash is born the ring has no radius at all, and a polygon whose
		# points are all the same point cannot be triangulated — the engine says so, once
		# per splash, which on a lake this size is a lot of saying so.
		if ring > 1.0:
			draw_colored_polygon(
				_ellipse(at, Vector2(ring, ring * 0.5)), Color(FOAM, alpha * 0.20)
			)
		# Likewise at the other end: the crown has collapsed to nothing before it has
		# finished fading.
		if height <= 0.5 or width <= 0.5:
			continue
		# The mound next, so the plumes stand in it rather than on top of it.
		draw_colored_polygon(_mound(at, width, height * 0.3), Color(FOAM, alpha * 0.9))
		# Three plumes: one up the middle and one leaning out each way. Two alone
		# read as a pair of antlers — there was nothing between them, so the eye
		# joined the tips instead of the bases.
		draw_colored_polygon(_plume(at, -1.0, width, height * 0.8), ink)
		draw_colored_polygon(_plume(at, 1.0, width, height * 0.8), ink)
		draw_colored_polygon(_plume(at, 0.0, width * 0.5, height), ink)

	for i in _drop_life.size():
		# Drops fade over their last quarter only. Fading from the moment they leave
		# the water makes the whole scatter look like it is already dying.
		var fade := clampf(_drop_life[i] * 4.0, 0.0, 1.0)
		draw_circle(_drop_pos[i], _drop_size[i], Color(FOAM, fade * 0.95))


## One plume of a crown: a tapered sheet of water arcing up and outward, built as a
## polygon rather than a stroked curve so it can narrow to a point.
##
## The spine is a quadratic curve whose control point sits high and *inboard* of
## the tip, which is what makes the plume lean over at the top the way thrown water
## does. Control point outboard gives a pair of inward-hooking antlers instead.
func _plume(origin: Vector2, dir: float, width: float, height: float) -> PackedVector2Array:
	var base := origin + Vector2(dir * width * 0.12, 0.0)
	var control := origin + Vector2(dir * width * 0.22, -height * 1.05)
	var tip := origin + Vector2(dir * width * 0.5, -height * 0.62)
	var thickness := maxf(width * 0.16, 3.0)

	var steps := 7
	var spine := PackedVector2Array()
	for step in steps + 1:
		var t := float(step) / float(steps)
		spine.append(base.bezier_interpolate(control, control, tip, t))

	# Walk up one side of the spine and back down the other, with the width closing
	# to nothing at the tip.
	var out := PackedVector2Array()
	for i in spine.size():
		out.append(spine[i] + _across(spine, i) * thickness * _taper(i, spine.size()))
	for i in range(spine.size() - 1, -1, -1):
		out.append(spine[i] - _across(spine, i) * thickness * _taper(i, spine.size()))
	return out


## How wide the plume is at a point along its spine: full at the waterline, nothing
## at the tip.
func _taper(i: int, count: int) -> float:
	var t := float(i) / float(count - 1)
	return (1.0 - t) * (1.0 - t) * 0.5 + (1.0 - t) * 0.5


## Unit normal to the spine at a point, so thickness is measured across the curve
## rather than horizontally — a near-vertical plume offset sideways would be a
## parallelogram, not a plume.
func _across(spine: PackedVector2Array, i: int) -> Vector2:
	var before := spine[maxi(i - 1, 0)]
	var after := spine[mini(i + 1, spine.size() - 1)]
	var along := after - before
	if along.length_squared() < 0.0001:
		return Vector2.RIGHT
	return along.normalized().orthogonal()


## The dome of disturbed water the plumes stand in.
func _mound(origin: Vector2, width: float, height: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var steps := 11
	for step in steps + 1:
		var t := float(step) / float(steps)
		out.append(origin + Vector2(
			lerpf(-width * 0.5, width * 0.5, t), -height * sin(t * PI)
		))
	out.append(origin + Vector2(width * 0.5, 3.0))
	out.append(origin + Vector2(-width * 0.5, 3.0))
	return out


## A flat ellipse on the plane, for the spreading ring.
func _ellipse(at: Vector2, extent: Vector2, steps: int = 20) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		out.append(at + Vector2(cos(angle) * extent.x * 0.5, sin(angle) * extent.y * 0.5))
	return out
