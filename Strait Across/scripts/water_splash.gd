## Splashes where things hit the water.
##
## Drawn by hand rather than with a particle node. Two reasons. The game renders
## on the Compatibility backend for the web build, where GPUParticles2D is the
## part of the engine most likely to behave differently from the desktop editor,
## and a splash that only appears for the developer is worse than none. And the
## art is flat, hand-painted and outlined — default round particle dots read as a
## different game pasted over this one, where a drawn crown of water does not.
##
## One node handles every splash in the strait. Nothing is instanced per impact:
## drops and crowns live in flat arrays, are integrated in _process, and the node
## stops processing entirely the moment the last one dies. A strait full of
## settling pieces is the common case and it must cost nothing.
##
## Side view, so there are no expanding rings — a splash here is a crown thrown
## up off the surface and a scatter of drops falling back into it.
class_name WaterSplash
extends Node2D

## Pale, faintly blue-shifted white. The water shader already tints everything
## below the line, so a splash drawn in flat white would be the only pure white
## on screen and would read as a hole rather than as water.
const FOAM := Color(0.93, 0.98, 1.0)

## Most opaque a crown ever gets. Short of solid on purpose: a collapsing bridge
## puts several pieces through the surface at once, and at full opacity their
## crowns merged into a single white slab across the strait rather than reading
## as several separate splashes.
const PEAK_ALPHA := 0.72

## Hard ceiling on live drops. At the object cap a collapsing bridge can put
## twenty pieces through the surface in the same second; past this the extra
## drops are invisible anyway and only cost draw calls.
const MAX_DROPS := 260

## How long a crown takes to rise and fade, in seconds. Short: a splash is a
## punctuation mark, and one that hangs about turns into fog.
const CROWN_LIFE := 0.42

## Pixels per second squared pulling drops back down. Not the world's gravity —
## drops are small and read better falling a little faster than the pieces do.
const DROP_GRAVITY := 1400.0

## The waterline splashes sit on. Set from the WaterBody that owns this node.
var surface_y: float = 300.0

## Live drops, as parallel arrays. Swap-removed on death, so the live range is
## always the front of each array and there are no holes to skip.
var _drop_pos := PackedVector2Array()
var _drop_vel := PackedVector2Array()
var _drop_life := PackedFloat32Array()
var _drop_size := PackedFloat32Array()

## Live crowns: where, how far along, and how wide at full spread.
var _crown_x := PackedFloat32Array()
var _crown_age := PackedFloat32Array()
var _crown_span := PackedFloat32Array()

## Last time each body splashed, keyed by instance id. A wheel bouncing along a
## half-sunk plank crosses the surface many times a second, and without this
## every one of those is a full crown.
var _last_splash: Dictionary[int, float] = {}
const RETRIGGER_DELAY := 0.22


func _ready() -> void:
	set_process(false)


## Throw up a splash. `strength` is 0..1 — a plank slipping in against a
## refrigerator dropped from the sky.
func splash(at_x: float, strength: float) -> void:
	var force := clampf(strength, 0.0, 1.0)
	var span := lerpf(60.0, 240.0, force)

	_crown_x.append(at_x)
	_crown_age.append(0.0)
	_crown_span.append(span)

	var wanted := 4 + roundi(force * 13.0)
	for i in wanted:
		if _drop_life.size() >= MAX_DROPS:
			break
		# Thrown from across the crown's mouth rather than all from its centre, so
		# the scatter reads as water leaving a surface instead of a firework.
		var from_centre := randf_range(-1.0, 1.0)
		_drop_pos.append(Vector2(at_x + from_centre * span * 0.4, surface_y))
		_drop_vel.append(Vector2(
			from_centre * span * randf_range(0.8, 1.7),
			-lerpf(170.0, 430.0, force) * randf_range(0.55, 1.15)
		))
		_drop_life.append(randf_range(0.32, 0.7))
		# Sized against the crown rather than in absolute pixels. The camera sits a
		# long way back on the wider straits, and drops that were readable while
		# testing zoomed in became a scatter of single pixels there.
		_drop_size.append(span * randf_range(0.018, 0.05))

	_play_splash_sound(force)
	set_process(true)
	queue_redraw()


## Shortest gap between two audible splashes, in seconds. The visuals can take
## several splashes at once — they are spread across the strait and read as
## separate events — but the sounds pile up into one loud smear, so a collapse
## gets one splash you can hear rather than eight on top of each other.
const SOUND_GAP := 0.09
## How much quieter the smallest splash is than the largest.
const QUIET_DB := -12.0
var _last_sound: float = -99.0


func _play_splash_sound(force: float) -> void:
	var now := float(Time.get_ticks_msec()) * 0.001
	if now - _last_sound < SOUND_GAP:
		return
	_last_sound = now
	# Reached by path rather than by the autoload's global name, the way the rest
	# of the project does it: the headless tools run individual scenes with no
	# autoloads, and there a missing sound must be silence, not a crash.
	var tree := get_tree()
	if tree == null:
		return
	var audio := tree.root.get_node_or_null(^"/root/Audio")
	if audio == null:
		return
	var clip: Vector2 = audio.SPLASH_CLIPS.pick_random()
	audio.play_clip(&"water_splash", clip.x, clip.y, lerpf(QUIET_DB, 0.0, force))


## A single drop of water, thrown from wherever you say rather than off the
## surface. For water running off something that has been in the strait and come
## back out — see WheelDrip.
##
## Silently ignored below the waterline: the water body is drawn over everything
## under the line, so a drop down there is invisible at best and, if it drifts
## up, a bead that appears out of nothing.
func drip(at: Vector2, vel: Vector2, size: float, life: float) -> void:
	if at.y >= surface_y or _drop_life.size() >= MAX_DROPS:
		return
	_drop_pos.append(at)
	_drop_vel.append(vel)
	_drop_life.append(life)
	_drop_size.append(size)
	set_process(true)
	queue_redraw()


## Splash for a body that has just crossed the surface, if it was moving fast
## enough to be worth one and hasn't splashed a moment ago.
##
## `width` is how wide the thing is in world units, which is most of what decides
## how big a splash looks right — a girder going in flat throws a long low sheet,
## a tyre a small one, at the same speed.
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
	splash(body.global_position.x, from_speed * 0.65 + from_size * 0.35)


## Below this there is no splash at all. A piece drifting down onto the water
## under buoyancy alone is settling, not landing, and giving that a crown makes
## a bridge look permanently agitated.
const MIN_SPEED := 135.0


func _process(delta: float) -> void:
	var alive := false

	var i := 0
	while i < _drop_life.size():
		var life := _drop_life[i] - delta
		var vel := _drop_vel[i] + Vector2(0.0, DROP_GRAVITY * delta)
		var pos := _drop_pos[i] + vel * delta
		# Gone when it runs out or when it falls back through the surface it came
		# from. Drops must not be seen underwater — the water body is drawn over
		# everything below the line and a drop under it looks like a bug.
		if life <= 0.0 or (vel.y > 0.0 and pos.y >= surface_y):
			var last := _drop_life.size() - 1
			_drop_pos[i] = _drop_pos[last]
			_drop_vel[i] = _drop_vel[last]
			_drop_life[i] = _drop_life[last]
			_drop_size[i] = _drop_size[last]
			_drop_pos.resize(last)
			_drop_vel.resize(last)
			_drop_life.resize(last)
			_drop_size.resize(last)
			continue
		_drop_pos[i] = pos
		_drop_vel[i] = vel
		_drop_life[i] = life
		i += 1
	alive = alive or _drop_life.size() > 0

	var c := 0
	while c < _crown_age.size():
		var age := _crown_age[c] + delta
		if age >= CROWN_LIFE:
			var last := _crown_age.size() - 1
			_crown_x[c] = _crown_x[last]
			_crown_age[c] = _crown_age[last]
			_crown_span[c] = _crown_span[last]
			_crown_x.resize(last)
			_crown_age.resize(last)
			_crown_span.resize(last)
			continue
		_crown_age[c] = age
		c += 1
	alive = alive or _crown_age.size() > 0

	queue_redraw()
	if not alive:
		set_process(false)
		# The cooldown table is the one thing here that would otherwise grow for
		# the life of the level, and with nothing splashing there is nothing whose
		# cooldown can still matter.
		_last_splash.clear()


func _draw() -> void:
	for c in _crown_age.size():
		var t := _crown_age[c] / CROWN_LIFE
		var span := _crown_span[c]
		var x := _crown_x[c]
		# Spreads outward and sinks as it fades, which is the whole motion of a
		# crown collapsing back into the surface.
		var width := span * lerpf(0.5, 1.0, t)
		var height := span * 0.5 * (1.0 - t * t)
		# Full strength for the first half, then out. Fading from the first frame
		# made the crown look like it was already dying when it appeared, which at
		# a quarter of a second is the only impression it gets to make.
		var alpha := clampf((1.0 - t) / 0.5, 0.0, 1.0) * PEAK_ALPHA
		var ink := Color(FOAM, alpha)
		# The mound first, so the plumes stand in it rather than on top of it.
		draw_colored_polygon(_mound(x, width, height * 0.3), Color(FOAM, alpha * 0.9))
		# Three plumes: one up the middle and one leaning out each way. Two alone
		# read as a pair of antlers — there was nothing between them, so the eye
		# joined the tips instead of the bases.
		draw_colored_polygon(_plume(x, -1.0, width, height * 0.8), ink)
		draw_colored_polygon(_plume(x, 1.0, width, height * 0.8), ink)
		draw_colored_polygon(_plume(x, 0.0, width * 0.5, height), ink)

	for i in _drop_life.size():
		# Drops fade over their last quarter only. Fading from the moment they
		# leave the water makes the whole scatter look like it is already dying.
		var fade := clampf(_drop_life[i] * 4.0, 0.0, 1.0)
		draw_circle(_drop_pos[i], _drop_size[i], Color(FOAM, fade * 0.95))


## One plume of a crown: a tapered sheet of water arcing up and outward, built as
## a polygon rather than a stroked curve so it can narrow to a point.
##
## The spine is a quadratic curve whose control point sits high and *inboard* of
## the tip, which is what makes the plume lean over at the top the way thrown
## water does. Getting that backwards — control point outboard — is what produced
## the pair of inward-hooking antlers this replaced.
func _plume(x: float, dir: float, width: float, height: float) -> PackedVector2Array:
	var base := Vector2(x + dir * width * 0.12, surface_y)
	var control := Vector2(x + dir * width * 0.22, surface_y - height * 1.05)
	var tip := Vector2(x + dir * width * 0.5, surface_y - height * 0.62)
	var thickness := maxf(width * 0.16, 3.0)

	var steps := 7
	var spine := PackedVector2Array()
	for step in steps + 1:
		var t := float(step) / float(steps)
		spine.append(base.bezier_interpolate(control, control, tip, t))

	# Walk up one side of the spine and back down the other, with the width
	# closing to nothing at the tip.
	var out := PackedVector2Array()
	for i in spine.size():
		out.append(spine[i] + _across(spine, i) * thickness * _taper(i, spine.size()))
	for i in range(spine.size() - 1, -1, -1):
		out.append(spine[i] - _across(spine, i) * thickness * _taper(i, spine.size()))
	return out


## How wide the plume is at a point along its spine: full at the waterline,
## nothing at the tip.
func _taper(i: int, count: int) -> float:
	var t := float(i) / float(count - 1)
	return (1.0 - t) * (1.0 - t) * 0.5 + (1.0 - t) * 0.5


## Unit normal to the spine at a point, so thickness is measured across the
## curve rather than horizontally — a near-vertical plume offset sideways would
## be a parallelogram, not a plume.
func _across(spine: PackedVector2Array, i: int) -> Vector2:
	var before := spine[maxi(i - 1, 0)]
	var after := spine[mini(i + 1, spine.size() - 1)]
	var along := after - before
	if along.length_squared() < 0.0001:
		return Vector2.RIGHT
	return along.normalized().orthogonal()


## The dome of disturbed water the plumes stand in.
func _mound(x: float, width: float, height: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var steps := 11
	for step in steps + 1:
		var t := float(step) / float(steps)
		out.append(Vector2(
			x + lerpf(-width * 0.5, width * 0.5, t),
			surface_y - height * sin(t * PI)
		))
	out.append(Vector2(x + width * 0.5, surface_y + 3.0))
	out.append(Vector2(x - width * 0.5, surface_y + 3.0))
	return out
