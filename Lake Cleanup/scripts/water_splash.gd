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
## surface, a crown thrown up off it, and a scatter of drops falling back in. The ring is
## what places the splash on the plane — without it, a crown drawn at a point could be
## anywhere along that line of sight.
##
## Drawn as foam (issue #31, 2026-09-16, Richard: "replaced by our foam look, but keep its
## sizes and splash movement"): every shape and every number of motion below is as it was,
## and what changed is the ink. The crown, its ring, the drops and the ripples go through
## shaders/splash_foam.gdshader — the collar's own rules: worked out per art pixel on the
## world grid, hard edges, palette swatches, dissolving into whole bubbles rather than
## fading — and the speck sheet through splash_specks.gdshader, which re-cuts its frames on
## the same grid. Rings are drawn as bands rather than lines so the foam has something to
## tear; drops are whole art pixels rather than circles. Colours come from the palette
## through Palette.dress_foam, so a repainted pack repaints the splashes.
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


## How far a ring spreads, as a multiple of its crown's span. Isometric, so a splash also
## gets the flat ring a side view could never show.
const RING_SPREAD := 1.6

## How long a ripple takes to spread and go, in seconds. Far longer than a crown: a crown is
## the impact and a ripple is the water still telling you about it afterwards.
const RIPPLE_LIFE := 1.15

## How far a ripple grows, as a multiple of the width it was born at. The ring the crown
## already draws is the impact spreading; this is the swell going on out across the lake, so
## it travels further and lives longer than that one.
const RIPPLE_GROWTH := 2.6

## Most opaque a ripple ring ever is. Faint on purpose — a lake with hard white rings on it
## looks like a puddle in the rain, and what is wanted is the surface being disturbed enough
## to stop reading as a painted floor. Higher than the 0.3 the line was drawn at: the band
## is torn into bubbles by the shader, so at the old figure most of it dissolved away.
const RIPPLE_ALPHA := 0.5

## How thick a ripple's band is, and the crown's own ring, in art pixels. A ripple is one
## pixel of foam: at that width the bubble cells tear it into a dashed ring, which is what a
## ring of foam on pixel-art water is. The crown's ring is the splash spreading and is
## thicker, in proportion to its span, with this as its least.
const RIPPLE_THICK := 1.0
const RING_THICK := 0.06
## What the crown's flat ring is drawn at, as a share of the crown's own alpha.
const RING_ALPHA := 0.6

## Hard ceiling on live ripples, the same bargain the drops strike.
const MAX_RIPPLES := 90

## The surface-particle burst that rides along with every crown, from Water_Splash_Particles.png:
## one strip, BURST_FRAMES square frames of BURST_FRAME_SIZE px, played once through at
## BURST_FPS and then gone. Sized off the same span a crown is, not off a fixed pixel count, so
## it stays in proportion whether a bottle or a pallet made it.
const BURST_TEX := preload("res://assets/Water_Splash_Particles.png")
const BURST_FRAMES := 32
const BURST_FRAME_SIZE := 96.0
const BURST_FPS := 26.0
const BURST_SCALE := 1.1
## Most opaque a burst frame ever draws at. Short of solid: the sheet's own frames already
## carry bright spray, and full alpha on top of the hand-drawn crown reads as two splashes
## fighting for the same pixel.
const BURST_ALPHA := 0.6
## Hard ceiling on live bursts. A burst is one draw call regardless of how showy the sheet
## is, so this can stay generous without costing what MAX_DROPS costs.
const MAX_BURSTS := 40

## How far a speck sheet is flattened to lie on the water: the plane's own 2:1, the same squash
## the ripple rings are drawn with. The sheets are drawn face-on, and a round spray standing up
## off an isometric lake reads as a disc facing the camera. Shared with LakeGrid's gold sparkle.
const SPECK_SQUASH := 0.5

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
## One roll per crown (Richard, 2026-09-16: "randomize a bit of the crown format, so it is
## not repetitive"): the plumes' lean, their heights against each other and the middle
## one's width are read off it, within CROWN_VARY of the drawn shape. The span — the size —
## is untouched: the roll is the shape, not the scale.
var _crown_roll := PackedFloat32Array()
## Whether each crown throws its plumes. A low one is the mound and the ring alone: an
## empty net landing on the water, with nothing in the mesh to throw anything up.
var _crown_tall := PackedByteArray()

## How far a crown's shape may wander from the drawn one, as a fraction: the side plumes'
## lean and heights and the middle plume's width each move by up to this much.
const CROWN_VARY := 0.3

## Live ripples: where on the plane, how far along, and how wide at birth.
var _ripple_at := PackedVector2Array()
var _ripple_age := PackedFloat32Array()
var _ripple_span := PackedFloat32Array()
## 1 where the ring at its widest lies wholly on open water, so its quads need no dry test.
## Asked once at birth: the test is a shore walk, and rain keeps forty-odd rings up at once.
var _ripple_open := PackedByteArray()

## Live surface-particle bursts: where, how far along, and how wide the sheet draws.
var _burst_at := PackedVector2Array()
var _burst_age := PackedFloat32Array()
var _burst_span := PackedFloat32Array()

var _last_splash: Dictionary[int, float] = {}
## When each body last shed a ripple, so a trail is spaced by time rather than by how often
## its owner remembers to ask.
var _last_ripple: Dictionary[int, float] = {}


## The two parts of a splash that carry their own shader, each on a child of its own: a
## CanvasItem material applies to everything that node draws, so the white-ink specks and
## the bubbling foam cannot share a node, and neither can share this one, whose ripples are
## plain lines. Children draw after their parent, in the order added, which is exactly the
## stack wanted: ripples, then specks, then the crown on top.
class SplashPart extends Node2D:
	var splash: WaterSplash
	var draws: Callable

	func _draw() -> void:
		draws.call(self)


var _rings: SplashPart
var _specks: SplashPart
var _crowns: SplashPart


func _ready() -> void:
	set_process(false)

	# The foam ink, one material shared by the rings and the crowns: the rings and the crowns
	# are the same substance, and two materials would be two places to tune it.
	var froth := ShaderMaterial.new()
	froth.shader = load("res://shaders/splash_foam.gdshader")
	froth.set_shader_parameter(&"peak_alpha", PEAK_ALPHA)
	froth.set_shader_parameter(&"foam", FOAM)
	froth.set_shader_parameter(&"foam_pixel", Lake.ART_PIXEL)
	Palette.dress_foam(froth, 1.0)

	_rings = SplashPart.new()
	_rings.name = &"Rings"
	_rings.draws = _draw_rings
	_rings.material = froth
	add_child(_rings)

	_specks = SplashPart.new()
	_specks.name = &"Specks"
	_specks.draws = _draw_specks
	var ink := ShaderMaterial.new()
	ink.shader = load("res://shaders/splash_specks.gdshader")
	ink.set_shader_parameter(&"foam", FOAM)
	ink.set_shader_parameter(&"foam_pixel", Lake.ART_PIXEL)
	Palette.dress_foam(ink, 1.0)
	_specks.material = ink
	add_child(_specks)

	_crowns = SplashPart.new()
	_crowns.name = &"Crowns"
	_crowns.draws = _draw_crowns
	_crowns.material = froth
	add_child(_crowns)


## Every layer of the splash, redrawn together: they all read the same arrays.
func _redraw() -> void:
	if _rings != null:
		_rings.queue_redraw()
	if _specks != null:
		_specks.queue_redraw()
	if _crowns != null:
		_crowns.queue_redraw()


## The most crowns on the water at once, for a light piece and a heavy one. See `splash`.
const CROWNS_MOST := 24
const CROWNS_HEAVY := 32
## What counts as heavy, of `splash`'s strength.
const HEAVY_FROM := 0.6


## Throw up a splash. `strength` is 0..1 — a cup slipping in against a fridge
## dropped from the sky.
func splash(at: Vector2, strength: float, tall: bool = true) -> void:
	# A sweep of a maxed net throws a crown a piece, and past CROWNS_MOST on the water at once
	# another is lost in the spray of the rest and costs script time every frame it lives
	# (2026-10-05, Richard: big catches stuttered). The light ones go first: a heavy piece
	# still gets its crown up to CROWNS_HEAVY.
	if _crown_age.size() >= (CROWNS_HEAVY if strength >= HEAVY_FROM else CROWNS_MOST):
		return
	var force := clampf(strength, 0.0, 1.0)
	var span := lerpf(40.0, 130.0, force)

	_crown_at.append(at)
	_crown_age.append(0.0)
	_crown_span.append(span)
	_crown_roll.append(randf())
	_crown_tall.append(1 if tall else 0)
	# A low splash is the mound and its ring: no spray sheet and no drops, since those are
	# water thrown up and nothing threw it.
	if not tall:
		set_process(true)
		_redraw()
		return

	if _burst_age.size() < MAX_BURSTS:
		_burst_at.append(at)
		_burst_age.append(0.0)
		_burst_span.append(span * BURST_SCALE)

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
	_redraw()


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
	_redraw()


## One ring of disturbed water, spreading flat on the surface from `at`. `span` is how wide
## it starts, in world pixels — the mouth of a net, the beam of a hull.
##
## No crown, no drops: this is not something hitting the water, it is water that has been
## pushed. Everything dragged across the lake leaves these, which is the difference between
## a surface and a floor.
## How many rings are out on the water now. The rain and the animals keep to a share of the
## cap so a walker's entry ring is never refused for want of room.
func ripples_up() -> int:
	return _ripple_age.size()


func ripple(at: Vector2, span: float) -> void:
	if _ripple_age.size() >= MAX_RIPPLES:
		return
	_ripple_at.append(at)
	_ripple_age.append(0.0)
	_ripple_span.append(maxf(span, 4.0))
	_ripple_open.append(1 if _open_round(at, maxf(span, 4.0) * RIPPLE_GROWTH) else 0)
	set_process(true)
	_redraw()


## A trail of them behind something moving: one ripple every `every` seconds, per body.
##
## The spacing lives here rather than in the callers because it is the same spacing for all
## of them, and because a net and a boat both want to say "I am ploughing through the lake"
## once a frame and have the water work out what that is worth.
func wake(body: Object, at: Vector2, span: float, every: float = 0.16) -> void:
	var id := body.get_instance_id()
	var now := float(Time.get_ticks_msec()) * 0.001
	if now - float(_last_ripple.get(id, -99.0)) < every:
		return
	_last_ripple[id] = now
	ripple(at, span)



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
			_crown_roll[c] = _crown_roll[last]
			_crown_tall[c] = _crown_tall[last]
			_crown_at.resize(last)
			_crown_age.resize(last)
			_crown_span.resize(last)
			_crown_roll.resize(last)
			_crown_tall.resize(last)
			continue
		_crown_age[c] = age
		c += 1

	var b := 0
	var burst_life := float(BURST_FRAMES) / BURST_FPS
	while b < _burst_age.size():
		var age := _burst_age[b] + delta
		if age >= burst_life:
			var last := _burst_age.size() - 1
			_burst_at[b] = _burst_at[last]
			_burst_age[b] = _burst_age[last]
			_burst_span[b] = _burst_span[last]
			_burst_at.resize(last)
			_burst_age.resize(last)
			_burst_span.resize(last)
			continue
		_burst_age[b] = age
		b += 1

	var r := 0
	while r < _ripple_age.size():
		var age := _ripple_age[r] + delta
		if age >= RIPPLE_LIFE:
			var last := _ripple_age.size() - 1
			_ripple_at[r] = _ripple_at[last]
			_ripple_age[r] = _ripple_age[last]
			_ripple_span[r] = _ripple_span[last]
			_ripple_open[r] = _ripple_open[last]
			_ripple_at.resize(last)
			_ripple_age.resize(last)
			_ripple_span.resize(last)
			_ripple_open.resize(last)
			continue
		_ripple_age[r] = age
		r += 1

	_redraw()
	if (
		_drop_life.is_empty() and _crown_age.is_empty()
		and _ripple_age.is_empty() and _burst_age.is_empty()
	):
		set_process(false)
		# The cooldown table is the one thing here that would otherwise grow for the
		# life of the session, and with nothing splashing there is nothing whose
		# cooldown can still matter.
		_last_splash.clear()
		_last_ripple.clear()


## The ripples, on the Rings child, under everything: a ripple is the surface itself, and
## the splash is something happening on top of it.
func _draw_rings(on: CanvasItem) -> void:
	# Every ring in one triangle array: one draw command however many are up.
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	for r in _ripple_age.size():
		var t := _ripple_age[r] / RIPPLE_LIFE
		# Out fast and then coasting, the way a ring of water actually leaves what made it.
		var out := 1.0 - (1.0 - t) * (1.0 - t)
		var wide := _ripple_span[r] * lerpf(1.0, RIPPLE_GROWTH, out)
		if wide < 2.0:
			continue
		# In over the first fifth so a ring does not appear at full strength on top of the
		# thing that made it, then away for the rest of its life.
		var alpha := minf(t * 5.0, 1.0) * (1.0 - t) * (1.0 - t) * RIPPLE_ALPHA
		_band_into(points, colours, indices, _ripple_at[r], Vector2(wide, wide * 0.5),
			RIPPLE_THICK * Lake.ART_PIXEL, Color(FOAM, alpha * PEAK_ALPHA),
			_ripple_open[r] == 0)
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(
			on.get_canvas_item(), indices, points, colours
		)


## Whether a ring `wide` across at its widest, round `at`, lies wholly on drawn water.
func _open_round(at: Vector2, wide: float) -> bool:
	var reach := wide * 0.5 + RIPPLE_THICK * Lake.ART_PIXEL
	for k in 8:
		var angle := TAU * float(k) / 8.0
		if not wet_at(at + Vector2(cos(angle) * reach, sin(angle) * reach * 0.5)):
			return false
	return wet_at(at)


## The speck ring, on the Specks child: over the ripples, under the crowns. The burst is spray
## lying on the surface, and the crown is thrown up out of that surface, so it stands in front.
func _draw_specks(on: CanvasItem) -> void:
	for b in _burst_age.size():
		var t := _burst_age[b] / (float(BURST_FRAMES) / BURST_FPS)
		var frame := mini(int(t * float(BURST_FRAMES)), BURST_FRAMES - 1)
		var size := _burst_span[b]
		var at := _burst_at[b]
		on.draw_texture_rect_region(
			BURST_TEX,
			Rect2(
				at - Vector2(size, size * SPECK_SQUASH) * 0.5, Vector2(size, size * SPECK_SQUASH)
			),
			Rect2(float(frame) * BURST_FRAME_SIZE, 0.0, BURST_FRAME_SIZE, BURST_FRAME_SIZE),
			Color(1.0, 1.0, 1.0, BURST_ALPHA)
		)


## The crowns and the drops, on the Crowns child, which bubbles them like the foam collar.
##
## Every ring, mound, plume and drop goes into one triangle array: one draw command however
## many are up (2026-09-26, Richard: a big net lagged, above all lucky or doubled). Every
## piece a sweep lifts throws a crown of its own, so a full Catch landing with a lucky hold
## and a second net put sixty-odd crowns up at once, and drawn as four `draw_colored_polygon`s
## each (every one triangulated and drawn on its own) plus a rect per drop, that was most of
## the frame for the crowns' whole life. The shapes are laid out exactly as before.
func _draw_crowns(on: CanvasItem) -> void:
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
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
		# On the frame a splash is born the ring has no radius at all, and a band with no
		# radius is nothing; the old filled disc could not be triangulated there either.
		if ring > 1.0:
			_band_into(
				points, colours, indices, at, Vector2(ring, ring * 0.5),
				maxf(span * RING_THICK, Lake.ART_PIXEL), Color(FOAM, alpha * RING_ALPHA)
			)
		# Likewise at the other end: the crown has collapsed to nothing before it has
		# finished fading.
		if height <= 0.5 or width <= 0.5:
			continue
		# The mound next, so the plumes stand in it rather than on top of it.
		_fan_into(points, colours, indices, _mound(at, width, height * 0.3),
			Color(FOAM, alpha * 0.9))
		if _crown_tall[c] == 0:
			continue
		# Three plumes: one up the middle and one leaning out each way. Two alone
		# read as a pair of antlers — there was nothing between them, so the eye
		# joined the tips instead of the bases. Each crown's roll sets how far the sides
		# lean, which side stands taller, and how broad the middle is, so no two are alike.
		var roll := _crown_roll[c]
		var lean := 1.0 + (_unroll(roll, 1.0) * 2.0 - 1.0) * CROWN_VARY
		var tilt := (_unroll(roll, 2.0) * 2.0 - 1.0) * CROWN_VARY
		var broad := 1.0 + (_unroll(roll, 3.0) * 2.0 - 1.0) * CROWN_VARY
		_strip_into(points, colours, indices,
			_plume(at, -1.0, width, height * 0.8 * (1.0 + tilt), lean), ink)
		_strip_into(points, colours, indices,
			_plume(at, 1.0, width, height * 0.8 * (1.0 - tilt), lean), ink)
		_strip_into(points, colours, indices, _plume(at, 0.0, width * 0.5 * broad, height), ink)

	for i in _drop_life.size():
		# Drops fade over their last quarter only. Fading from the moment they leave
		# the water makes the whole scatter look like it is already dying.
		var fade := clampf(_drop_life[i] * 4.0, 0.0, 1.0)
		# A drop is a whole number of art pixels square, never a circle: the smallest are
		# one pixel of foam. It glides between pixels as everything moving on the lake does.
		var side := maxf(roundf(_drop_size[i] * 2.0 / Lake.ART_PIXEL), 1.0) * Lake.ART_PIXEL
		var corner := _drop_pos[i] - Vector2(side, side) * 0.5
		# The square as a two-triangle fan off its corner, written straight in: a drop is
		# the commonest thing here and an array per drop was most of its cost.
		var first := points.size()
		var tone := Color(FOAM, fade * PEAK_ALPHA)
		points.push_back(corner)
		points.push_back(corner + Vector2(side, 0.0))
		points.push_back(corner + Vector2(side, side))
		points.push_back(corner + Vector2(0.0, side))
		for k in 4:
			colours.push_back(tone)
		indices.push_back(first)
		indices.push_back(first + 1)
		indices.push_back(first + 2)
		indices.push_back(first)
		indices.push_back(first + 2)
		indices.push_back(first + 3)
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(
			on.get_canvas_item(), indices, points, colours
		)


## A shape that every point of can see its first point from — the mound (an arc over its own
## base) and a drop's square — appended as a fan off that point.
func _fan_into(
	points: PackedVector2Array, colours: PackedColorArray, indices: PackedInt32Array,
	shape: PackedVector2Array, colour: Color
) -> void:
	var first := points.size()
	for p in shape:
		points.append(p)
		colours.append(colour)
	for i in range(1, shape.size() - 1):
		indices.push_back(first)
		indices.push_back(first + i)
		indices.push_back(first + i + 1)


## A plume as `_plume` lays it out — up one side of the spine and back down the other —
## appended as the strip of quads between the two sides.
func _strip_into(
	points: PackedVector2Array, colours: PackedColorArray, indices: PackedInt32Array,
	shape: PackedVector2Array, colour: Color
) -> void:
	var first := points.size()
	for p in shape:
		points.append(p)
		colours.append(colour)
	var count := shape.size()
	var half := count / 2
	for i in half - 1:
		var up := first + i
		var down := first + count - 1 - i
		indices.push_back(up)
		indices.push_back(up + 1)
		indices.push_back(down - 1)
		indices.push_back(up)
		indices.push_back(down - 1)
		indices.push_back(down)


## One plume of a crown: a tapered sheet of water arcing up and outward, built as a
## polygon rather than a stroked curve so it can narrow to a point.
##
## The spine is a quadratic curve whose control point sits high and *inboard* of
## the tip, which is what makes the plume lean over at the top the way thrown water
## does. Control point outboard gives a pair of inward-hooking antlers instead.
##
## `lean` scales how far out the tip and the control point sit, 1 for the drawn shape.
func _plume(
	origin: Vector2, dir: float, width: float, height: float, lean: float = 1.0
) -> PackedVector2Array:
	var base := origin + Vector2(dir * width * 0.12, 0.0)
	var control := origin + Vector2(dir * width * 0.22 * lean, -height * 1.05)
	var tip := origin + Vector2(dir * width * 0.5 * lean, -height * 0.62)
	var thickness := maxf(width * 0.16, 3.0)

	var steps := 7
	var spine := PackedVector2Array()
	for step in steps + 1:
		var t := float(step) / float(steps)
		spine.append(base.bezier_interpolate(control, control, tip, t))

	# Walk up one side of the spine and back down the other, with the width closing
	# to nothing at the tip.
	# Each point's offset worked out once and used for both sides.
	var count := spine.size()
	var off := PackedVector2Array()
	off.resize(count)
	for i in count:
		off[i] = _across(spine, i) * thickness * _taper(i, count)
	var out := PackedVector2Array()
	out.resize(count * 2)
	for i in count:
		out[i] = spine[i] + off[i]
		out[count * 2 - 1 - i] = spine[i] - off[i]
	return out


## A second, third... number off one roll, 0 to 1, so a crown carries one float and reads
## several independent-enough shapes off it.
func _unroll(roll: float, salt: float) -> float:
	return fposmod(roll * (17.0 + salt * 11.0) + salt * 0.37, 1.0)


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


## A flat ring on the plane with a width to it: the ellipse at `extent` as the band's
## middle, `thick` world px across, drawn as one strip of triangles so the shader has an
## area to tear into bubbles. A polyline had no area, and a line the foam cannot break up
## is a line, not foam.
## Whether water is drawn at this world point: off the island's drawn ground and inside the
## outer bank. The rain's own test (`Weather._landing`). Public for the test.
static func wet_at(world: Vector2) -> bool:
	var at := Iso.world_to_tile(world)
	return not Iso.on_island_ground(at) and Iso.shore_fraction(at.x, at.y) < 1.0


## `water_only` drops every quad whose outer edge lies on dry ground (2026-09-26, Richard:
## rings from the walkers at the shore were drawn over the island's sand). The ripples ask
## it; the crown's ring is thrown where something hit the water and needs no test.
func _band(
	on: CanvasItem, at: Vector2, extent: Vector2, thick: float, colour: Color,
	water_only: bool = false
) -> void:
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	_band_into(points, colours, indices, at, extent, thick, colour, water_only)
	if indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(
		on.get_canvas_item(), indices, points, colours
	)


## `_band`'s strip appended to arrays a caller draws, so many bands can be one draw.
func _band_into(
	points: PackedVector2Array, colours: PackedColorArray, indices: PackedInt32Array,
	at: Vector2, extent: Vector2, thick: float, colour: Color, water_only: bool = false
) -> void:
	var steps := 20
	var first := points.size()
	var half := thick * 0.5
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		var dir := Vector2(cos(angle), sin(angle))
		# The band's inner and outer edges, the width measured on the plane's own squash so
		# the ring is as thick at its ends as at its front.
		var outer := at + Vector2(
			dir.x * (extent.x * 0.5 + half), dir.y * (extent.y * 0.5 + half * 0.5)
		)
		var inner := at + Vector2(
			dir.x * maxf(extent.x * 0.5 - half, 0.0), dir.y * maxf(extent.y * 0.5 - half * 0.5, 0.0)
		)
		points.append(outer)
		points.append(inner)
		colours.append(colour)
		colours.append(colour)
		var base := first + i * 2
		var next := first + ((i + 1) % steps) * 2
		if water_only:
			var mid_angle := TAU * (float(i) + 0.5) / float(steps)
			var edge := at + Vector2(cos(mid_angle) * (extent.x * 0.5 + half),
				sin(mid_angle) * (extent.y * 0.5 + half * 0.5))
			if not wet_at(edge):
				continue
		indices.push_back(base)
		indices.push_back(base + 1)
		indices.push_back(next + 1)
		indices.push_back(base)
		indices.push_back(next + 1)
		indices.push_back(next)
