class_name BloodLayer
extends Node2D

## Everything that has bled on this floor, and nothing else.
##
## A separate node rather than more drawing in Room._draw, because the two have
## different lifetimes: the room's walls and hazards are rebuilt from the seed
## every time you walk in, and the pools are not. They belong to the RUN. Room
## hands this layer the list MapData is keeping, the layer draws it, and new
## deaths go back through Room into that same list -- so backtracking through a
## room you fought in shows the fight.
##
## Drawn as a child added before any creature, so pools sit on the floor and
## everything alive walks over them.

## The floor is seen at an angle (see ART_BIBLE), so a pool is an ellipse for
## the same reason a shadow is. Kept slightly rounder than the shadow squash:
## a pool has spread out on the surface, it is not a cast silhouette.
const SQUASH: float = 0.55

## How far a splat's edge wobbles off the circle, as a fraction of its radius.
const EDGE_NOISE: float = 0.34
const EDGE_POINTS: int = 18

## Satellite droplets thrown out around the main pool.
const DROPS_MIN: int = 3
const DROPS_MAX: int = 7

## The dark halo under the pool, which is what stops it reading as a flat sticker.
const RIM_SCALE: float = 1.12
const RIM_ALPHA: float = 0.3
const BODY_ALPHA: float = 0.82

## Ceiling on pools per room. A rampage can pour hundreds of white cells through
## one chamber, and past a certain point the floor is one flat sheet of colour
## that reads as a texture swap rather than as carnage. Oldest out first: the
## early splats are the ones already buried under the later ones.
const CAP: int = 90

## Every splat is one of these dictionaries: {"p": Vector2, "c": Color,
## "r": float, "s": int}. This is MapData's own array, held by reference, so
## appending here IS the save.
var splats: Array = []

## Polygons built once per splat and kept, so a redraw is not a re-simulation.
## Parallel to `splats` -- index i of one is index i of the other.
var _shapes: Array = []


## Deliberately no z_index of its own. Ordering here is child order and nothing
## else: Room paints its floor first as the parent, this layer is the first child
## added so it lands on top of that floor, and every creature is added after it
## and therefore walks over the pools. A negative z_index would push the pools
## UNDER the floor polygon, which is the one place they must not be.
## Takes the run's existing pools for this room. Called before anything spawns.
func load_splats(existing: Array) -> void:
	splats = existing
	_shapes.clear()
	for s: Dictionary in splats:
		_shapes.append(_build_shape(s))
	queue_redraw()


## Adds one pool and hands the caller the dictionary, so whoever owns the
## persistent list can keep it.
func add_splat(pos: Vector2, color: Color, size: float, rng_seed: int = 0) -> Dictionary:
	var s := {
		"p": pos,
		"c": color,
		"r": maxf(size, 4.0),
		"s": rng_seed if rng_seed != 0 else randi(),
	}
	splats.append(s)
	_shapes.append(_build_shape(s))
	while splats.size() > CAP:
		splats.pop_front()
		_shapes.pop_front()
	queue_redraw()
	return s


## The pool's outline plus its droplets, as flat local-space polygons. A splat's
## look is a pure function of its seed, so a room redraws identically forever
## and a saved pool comes back the shape it was.
func _build_shape(s: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s["s"])
	var r: float = s["r"]

	var body := PackedVector2Array()
	# Two overlapping lobes' worth of wobble on one ring: a smooth low-frequency
	# term for the overall lopsidedness, plus per-vertex noise for the edge.
	var lobe_phase := rng.randf() * TAU
	var lobe_amount := 0.12 + rng.randf() * 0.2
	for i in EDGE_POINTS:
		var a := TAU * float(i) / float(EDGE_POINTS)
		var wobble := 1.0 + sin(a * 2.0 + lobe_phase) * lobe_amount \
			+ rng.randf_range(-EDGE_NOISE, EDGE_NOISE) * 0.5
		body.append(Vector2.from_angle(a) * r * wobble)

	var drops: Array = []
	for i in rng.randi_range(DROPS_MIN, DROPS_MAX):
		var angle := rng.randf() * TAU
		var dist := r * rng.randf_range(1.0, 2.1)
		drops.append({
			"p": Vector2.from_angle(angle) * dist,
			"r": r * rng.randf_range(0.08, 0.24),
		})
	return {"body": body, "drops": drops}


func _draw() -> void:
	for i in splats.size():
		if i >= _shapes.size():
			continue
		var s: Dictionary = splats[i]
		var shape: Dictionary = _shapes[i]
		var col: Color = s["c"]
		var body: PackedVector2Array = shape["body"]

		draw_set_transform(s["p"], 0.0, Vector2(1.0, SQUASH))
		# Rim first, and darker: wet edges pool thicker than the middle spreads.
		var rim := PackedVector2Array()
		for v in body:
			rim.append(v * RIM_SCALE)
		draw_colored_polygon(rim, Color(col.darkened(0.45), RIM_ALPHA))
		draw_colored_polygon(body, Color(col, BODY_ALPHA))
		for d: Dictionary in shape["drops"]:
			draw_circle(d["p"], d["r"], Color(col, BODY_ALPHA * 0.9))
	draw_set_transform(Vector2.ZERO)
