## What the four yards on the bank make now that nobody is buying rubbish.
##
## The same four spots that used to take plastic, wood, metal and rubber off the ferry
## have been turned round: each one fabricates one charm and pushes it out onto the water.
## Ammo, shield, fire and ice, one to a yard, always from the same yard — so the player
## learns the lake as four sources rather than as a scatter, and going for ice means going
## to a place.
##
## They are not rubbish and they are not in the grid. They float on their own, drift out
## from their pier, and are lifted by the same cast that lifts everything else: the net
## already had a pass for picking up things that are not grid pieces (the pigeons), and
## this hangs off the same hook.
class_name CharmField
extends Node2D

## The four. Their order is the order of the yards on the bank, which is the order of
## TrashDef.Kind, so a yard's index is its charm.
enum Kind { AMMO, SHIELD, FIRE, ICE }

const KIND_NAMES := ["Ammo", "Shield", "Fire", "Ice"]

## What each one looks like on the water. Not the yard's own colour: four charms that have
## to be told apart at a glance across a dark lake need four strong colours of their own,
## and the yard's tint is already doing the job of telling the piers apart.
const KIND_COLOURS := [
	Color(0.72, 0.88, 1.00),
	Color(1.00, 0.82, 0.34),
	Color(1.00, 0.48, 0.20),
	Color(0.55, 0.92, 0.98),
]

## Seconds between one yard finishing a charm and starting the next, at wave one, and how
## much of that each wave takes off. The siege gets harder and the shore gets busier at the
## same time, so a later wave is not simply a worse version of an earlier one.
const MAKE_EVERY := 7.0
const MAKE_FASTER := 0.5
const MAKE_FASTEST := 2.5

## How many of one yard's charms may be on the water at once. A yard that has been ignored
## stops making more rather than carpeting its corner of the lake.
const AFLOAT_EACH := 3

## How long a charm takes to come up out of the yard and onto the water, in seconds, and
## how far it slides out from the pier while it does.
##
## A charm does not appear. The yard makes it, and making it takes a moment the player can
## see and hear: it swells up out of the water at the end of the pier, and only when it is
## properly afloat can a net take it. That moment is most of what turns four bank yards
## from scenery into machines.
const SURFACE := 1.2
const SURFACE_SLIDE := 1.0

## How much of the surfacing has to be done before a net can lift one, so a charm that is
## visibly still coming up cannot be taken. Not the whole of it: the last of the rise is
## the thing settling, and refusing a cast aimed at something that looks finished is worse
## than allowing one aimed at something that nearly is.
const CATCHABLE_AT := 0.75

## How fast a charm drifts away from its pier, in tiles a second, and how far out it gets
## before it stops drifting and simply bobs.
const DRIFT := 0.55
const DRIFT_FOR := 9.0

## How long a charm lasts on the water before it sinks, in seconds, and how long the sink
## itself takes. Charms expire on purpose: the box is meant to be fed during a fight, not
## stockpiled in the lake between waves.
const LIFE := 40.0
const SINK := 0.8

## Drawn size, in world pixels.
const BODY := Vector2(19.0, 19.0)

## How near a tile a charm has to be, in tiles, for a net sweeping that tile to close on it.
##
## A radius rather than "is it in this cell". A charm is never still — it slides out of its
## yard as it surfaces and drifts afterwards — so cell membership flips while the net is in
## the air, and a cast aimed squarely at one would come back empty because the thing had
## crossed a line the player cannot see. A net closing over a charm catches it.
const CATCH_NEAR := 0.9

## The works on the bank: how big the mark at a pier is drawn, and how much of the wait has
## to have passed before it starts showing. Early on there is nothing to see because there
## is nothing happening yet — the yard is between jobs.
const SPOUT_MARK := Vector2(26.0, 13.0)
const SPOUT_FROM := 0.35

## The tile each yard pushes its charms out from, in yard order. Filled in by the siege
## from the dropoffs it already placed.
var spouts: Array[Vector2] = []

## Which wave the lake is on, so the yards speed up with it.
var wave: int = 1

## Off while the shed is down or the siege has not started.
var making: bool = true

var grid: LakeGrid
var sfx: Sfx
var splash: WaterSplash

## Everything floating. Rows, like every other population in this game.
var charms: Array = []

## A yard has finished one. Carries where it appeared, for the sound and the splash.
signal made(kind: int, at: Vector2)

var _rng := RandomNumberGenerator.new()
var _next: PackedFloat32Array = PackedFloat32Array([2.0, 4.0, 6.0, 8.0])
var _time: float = 0.0


func _ready() -> void:
	_rng.randomize()


## How long a yard waits between charms at the current wave.
func make_every() -> float:
	return maxf(MAKE_EVERY - MAKE_FASTER * float(maxi(wave - 1, 0)), MAKE_FASTEST)


## Put one on the water by hand. Used by the yards and by the harness, which does not have
## seven seconds to wait for one.
func add_charm(kind: int, at: Vector2 = Vector2.ZERO) -> bool:
	var from := at
	if from == Vector2.ZERO:
		if kind < 0 or kind >= spouts.size():
			return false
		from = spouts[kind]
	if not Iso.in_lake(int(from.x), int(from.y)):
		return false
	# Outward from the middle of the basin is where the bank is, so a charm pushed that way
	# would beach itself. They drift in towards the water instead.
	var inward := (Iso.CENTRE - from).normalized()
	charms.append({
		"kind": kind,
		"tile": from,
		"born": from,
		"drift": inward,
		"rise": 0.0,
		"age": 0.0,
		"sink": 0.0,
		"phase": _rng.randf() * TAU,
	})
	made.emit(kind, Iso.tile_to_world(from.x, from.y))
	if splash != null:
		# Small: this is something being pushed up through the surface, not something
		# dropped into it.
		splash.splash(Iso.tile_to_world(from.x, from.y), 0.25)
	queue_redraw()
	return true


## How many of one kind belong to this yard at the moment: on the water, or still coming
## up out of it. Both count, or a yard would start a second charm while the first was still
## surfacing and the pier would stack them.
func afloat(kind: int) -> int:
	var count := 0
	for charm: Dictionary in charms:
		if int(charm["kind"]) == kind and float(charm["sink"]) <= 0.0:
			count += 1
	return count


## Is this one properly on the water yet?
func is_up(charm: Dictionary) -> bool:
	return float(charm["rise"]) >= CATCHABLE_AT and float(charm["sink"]) <= 0.0


## Is a charm sitting on this tile? Returns its row, or -1. The same shape as
## Flock.bird_on, because the net asks both the same question in the same pass.
func charm_on(tile: int) -> int:
	if grid == null:
		return -1
	var cell := grid.tile_of(tile)
	var middle := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
	for i in charms.size():
		var charm: Dictionary = charms[i]
		# Still coming up out of the yard: the net passes over it. A charm is catchable when
		# it is floating, not when it exists.
		if not is_up(charm):
			continue
		if (charm["tile"] as Vector2).distance_to(middle) <= CATCH_NEAR:
			return i
	return -1


## A charm's drawing as the net sees it: its middle and the half-size of its flat disc, in
## world pixels, from the same numbers `_draw` uses.
func footprint(i: int) -> Array:
	var charm: Dictionary = charms[i]
	var at: Vector2 = charm["tile"]
	var seat := Iso.tile_to_world(at.x, at.y) + Vector2(0.0, sin(float(charm["phase"])) * 2.0)
	var body := BODY * (1.0 - float(charm["sink"]) * 0.5)
	return [seat, Vector2(body.x * 0.5, body.y * 0.5 * 0.55)]


## The net has it. Returns which kind it was, and takes it off the water.
func take(index: int) -> int:
	if index < 0 or index >= charms.size():
		return -1
	var kind := int((charms[index] as Dictionary)["kind"])
	charms.remove_at(index)
	queue_redraw()
	return kind


func _process(delta: float) -> void:
	_time += delta
	if making:
		_keep_making(delta)
	for i in range(charms.size() - 1, -1, -1):
		if not _step(charms[i], delta):
			charms.remove_at(i)
	# A charm surfacing or sinking animates, and so does the works on the bank while a yard
	# is building one. With neither, the layer is empty and repainting it draws nothing.
	if making or not charms.is_empty():
		queue_redraw()


## Each yard on its own clock, so the four do not arrive in step.
func _keep_making(delta: float) -> void:
	var gap := make_every()
	for kind in mini(spouts.size(), _next.size()):
		_next[kind] -= delta
		if _next[kind] > 0.0:
			continue
		_next[kind] = gap
		if afloat(kind) < AFLOAT_EACH:
			add_charm(kind)


## One charm, one frame. False means it is gone.
func _step(charm: Dictionary, delta: float) -> bool:
	charm["phase"] = float(charm["phase"]) + delta * 2.2

	# Coming up out of the yard: it slides out along its own pier as it surfaces, so what
	# the player sees is the spot pushing it out rather than something fading in over the
	# water. Its life does not start running until it is up.
	if float(charm["rise"]) < 1.0:
		charm["rise"] = minf(float(charm["rise"]) + delta / SURFACE, 1.0)
		var out: Vector2 = charm["drift"]
		var slid: Vector2 = (charm["born"] as Vector2) + out * SURFACE_SLIDE * float(charm["rise"])
		if Iso.in_lake(int(slid.x), int(slid.y)):
			charm["tile"] = slid
		return true

	charm["age"] = float(charm["age"]) + delta
	if float(charm["sink"]) > 0.0 or float(charm["age"]) >= LIFE:
		charm["sink"] = float(charm["sink"]) + delta / SINK
		return float(charm["sink"]) < 1.0
	if float(charm["age"]) < DRIFT_FOR:
		var next: Vector2 = (charm["tile"] as Vector2) + (charm["drift"] as Vector2) * DRIFT * delta
		if Iso.in_lake(int(next.x), int(next.y)):
			charm["tile"] = next
	return true


## A charm on the water: a lit disc lying flat in the plane, a mark on it saying which of
## the four it is, and a halo so it can be found at low zoom against black water.
func _draw() -> void:
	if making:
		_draw_works()
	for charm: Dictionary in charms:
		var kind := int(charm["kind"])
		var at: Vector2 = charm["tile"]
		var where := Iso.tile_to_world(at.x, at.y)
		var fade := 1.0 - float(charm["sink"])
		# The last few seconds blink, so a charm about to sink is not a surprise.
		var left := LIFE - float(charm["age"])
		if left < 6.0:
			fade *= 0.55 + 0.45 * absf(sin(float(charm["phase"]) * 2.0))
		var bob := sin(float(charm["phase"])) * 2.0
		var tint: Color = KIND_COLOURS[kind]
		var body := BODY * (1.0 - float(charm["sink"]) * 0.5)

		# Coming up: it grows into its own size and rides up out of the water rather than
		# fading in, and the water it is pushing through is drawn breaking around it.
		var rise := float(charm["rise"])
		if rise < 1.0:
			var eased := rise * rise * (3.0 - 2.0 * rise)
			body *= 0.25 + 0.75 * eased
			fade *= 0.35 + 0.65 * eased
			bob += (1.0 - eased) * 7.0
			_boil(where, BODY.x * (0.5 + 0.5 * eased), tint, 1.0 - eased,
				float(charm["phase"]))
		var seat := where + Vector2(0.0, bob)

		# Water light under it, then the disc, flattened to the plane like everything else.
		draw_circle(seat + Vector2(0.0, body.y * 0.22), body.x * 0.85, Color(tint.r, tint.g, tint.b, 0.16 * fade))
		_flat_disc(seat, body * 0.5, Color(tint.r, tint.g, tint.b, 0.9 * fade))
		_flat_disc(seat, body * 0.30, Color(1.0, 1.0, 1.0, 0.75 * fade))
		_mark(kind, seat, body, Color(0.06, 0.07, 0.08, 0.9 * fade))


## The water breaking over something on its way up. Rings that shrink as the thing rises,
## which is the opposite of a splash and reads as a push from underneath.
func _boil(at: Vector2, reach: float, tint: Color, left: float, phase: float) -> void:
	for i in 3:
		var ripple := fposmod(phase * 0.5 + float(i) / 3.0, 1.0)
		var span := reach * (0.4 + ripple * 1.1)
		var ring := PackedVector2Array()
		for k in 15:
			var angle := TAU * float(k % 14) / 14.0
			ring.append(at + Vector2(cos(angle) * span, sin(angle) * span * 0.5))
		draw_polyline(
			ring, Color(tint.r, tint.g, tint.b, 0.45 * left * (1.0 - ripple)), 1.6
		)
	draw_circle(at, reach * 0.5, Color(tint.r, tint.g, tint.b, 0.20 * left))


## The four yards at work.
##
## A mark at the end of each pier that fills as its next charm gets closer, in that charm's
## own colour, and starts to churn when it is nearly out. Without it the shore is four
## piers that occasionally produce something; with it, it is four machines the player can
## read from across the lake and decide which one to go and stand near.
func _draw_works() -> void:
	var gap := make_every()
	for kind in mini(spouts.size(), _next.size()):
		var ready := clampf(1.0 - _next[kind] / maxf(gap, 0.001), 0.0, 1.0)
		if ready < SPOUT_FROM:
			continue
		var along := (ready - SPOUT_FROM) / (1.0 - SPOUT_FROM)
		var at := spouts[kind]
		var where := Iso.tile_to_world(at.x, at.y)
		var tint: Color = KIND_COLOURS[kind]

		# The pool the charm will come out of: a flat disc that brightens and widens as the
		# yard gets there.
		var span := SPOUT_MARK * (0.55 + 0.45 * along)
		var pool := PackedVector2Array()
		for i in 20:
			var angle := TAU * float(i) / 20.0
			pool.append(where + Vector2(cos(angle) * span.x, sin(angle) * span.y))
		draw_colored_polygon(pool, Color(tint.r, tint.g, tint.b, 0.10 + 0.16 * along))

		# And a ring around it that closes as it fills, so the wait has a shape.
		var arc := PackedVector2Array()
		var steps := maxi(int(20.0 * along), 2)
		for i in steps + 1:
			var angle := -PI * 0.5 + TAU * float(i) / 20.0
			arc.append(where + Vector2(
				cos(angle) * span.x * 1.25, sin(angle) * span.y * 1.25
			))
		if arc.size() > 1:
			draw_polyline(arc, Color(tint.r, tint.g, tint.b, 0.35 + 0.45 * along), 2.0)

		# Nearly there: it starts to churn.
		if along > 0.72:
			var churn := (along - 0.72) / 0.28
			_boil(where, span.x * 0.9, tint, churn * 0.8, _time * 3.0 + float(kind))


## An ellipse on the plane, at the same 2:1 the tiles use.
func _flat_disc(at: Vector2, extent: Vector2, tint: Color) -> void:
	var ring := PackedVector2Array()
	for i in 14:
		var angle := TAU * float(i) / 14.0
		ring.append(at + Vector2(cos(angle) * extent.x, sin(angle) * extent.y * 0.55))
	draw_colored_polygon(ring, tint)


## The four marks. Drawn from lines rather than from a font, so they read at any zoom and
## cost nothing when the art is missing: a shell, a shield, a flame, a flake.
func _mark(kind: int, at: Vector2, body: Vector2, ink: Color) -> void:
	var r := body.x * 0.22
	match kind:
		Kind.AMMO:
			draw_line(at + Vector2(0.0, r), at + Vector2(0.0, -r), ink, 2.4)
			draw_line(at + Vector2(0.0, -r), at + Vector2(-r * 0.5, -r * 0.3), ink, 2.0)
			draw_line(at + Vector2(0.0, -r), at + Vector2(r * 0.5, -r * 0.3), ink, 2.0)
		Kind.SHIELD:
			var shield := PackedVector2Array([
				at + Vector2(-r, -r * 0.7), at + Vector2(r, -r * 0.7),
				at + Vector2(0.0, r),
			])
			draw_colored_polygon(shield, ink)
		Kind.FIRE:
			var flame := PackedVector2Array([
				at + Vector2(0.0, -r * 1.2), at + Vector2(r * 0.75, r * 0.2),
				at + Vector2(0.0, r * 0.8), at + Vector2(-r * 0.75, r * 0.2),
			])
			draw_colored_polygon(flame, ink)
		Kind.ICE:
			for i in 3:
				var angle := PI * float(i) / 3.0
				var arm := Vector2(cos(angle), sin(angle)) * r
				draw_line(at - arm, at + arm, ink, 2.0)
