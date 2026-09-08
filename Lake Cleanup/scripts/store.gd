## The yard behind the shed: where the catch goes, and the reason the boat exists.
##
## Rubbish pulled out of the lake is not money yet. It sits here until the ferry takes it
## to the shore and sells it.
##
## It does not fill up. It used to: the yard was a hard cap, and when it was full the net
## stopped catching until a boat had run. On paper that made the two halves of the game
## need each other, and in play it made the player stand on the bank watching a boat, which
## is not a game. The ferry earns its place by being the only thing that turns a pile into
## money, and that is enough of a reason for it to exist.
##
## The pile is drawn from what is actually in it rather than from a fill fraction, so a
## yard holding three fridges looks different from one holding three cups, and the player
## can see what is waiting to be sold without opening anything.
class_name Yard
extends Node2D

const Style := preload("res://scripts/style.gd")

## How many pieces the pile is drawn from, at most. Past this the yard is a wall of junk
## either way, and the draw cost of a late-game store is not worth paying.
const MAX_DRAWN := 24

## How wide and deep the crate is on the plane, and how tall its walls stand.
const CRATE := Vector2(84.0, 42.0)
const CRATE_TALL := 26.0

## The crate's shadow: how much bigger than its footprint it is drawn, and how far down the
## screen it sits. Barely either — it is a box on the ground, and the shadow is the sliver of
## it the sun does not reach rather than a halo.
const SHADOW_SPREAD := 1.0
const SHADOW_DROP := 3.0

## How many pieces fill it to the brim. Past this the heap simply stops rising — the crate is
## a picture of how the run is going, not a second cap on it.
const CRATE_FULL := 40

## The crate's colours: the planks, the shadowed inside, and the lines between boards.
const WOOD := Style.CRATE
const WOOD_LIT := Style.CRATE_LIT
const WOOD_DARK := Style.CRATE_DARK
const INSIDE := Style.CRATE_IN
const CRATE_INK := Style.SEAM


## Def indices waiting to be sold, oldest first. No limit: a lake's worth of rubbish can
## sit here, and the pile stops being drawn long before it stops being counted.
var held := PackedInt32Array()

## Set by lake.gd, for drawing the pieces.
var grid: LakeGrid

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Fixed seed: the pile's scatter should not reshuffle itself every time a piece is
	# added or sold.
	_rng.seed = 90210


## Take a piece. Never refuses — kept returning a bool so callers that want to know it
## landed still read the same, and so a yard that grows a rule later has somewhere to put
## it.
func put(def_index: int) -> bool:
	held.append(def_index)
	queue_redraw()
	return true


## Load out up to `n` pieces, oldest first. The boat's loading step, and the only way
## anything leaves the yard.
func take_lot(n: int) -> PackedInt32Array:
	var count := mini(n, held.size())
	var lot := held.slice(0, count)
	held = held.slice(count)
	queue_redraw()
	return lot


## Where a piece thrown at the yard should land: inside the crate rather than on the ground
## in front of it, and higher as the crate fills.
func drop_point() -> Vector2:
	return position + Vector2(0.0, -CRATE_TALL * 0.5 - _heap_rise())


## How far the top of the heap has risen off the crate's floor.
func _heap_rise() -> float:
	return CRATE_TALL * 0.55 * clampf(float(held.size()) / float(CRATE_FULL), 0.0, 1.0)


## The crate, with the catch in it.
##
## An open box drawn on the plane: the far wall and the floor first, then the heap, then the
## two near walls over the top of it, so what is in the crate is inside it rather than piled
## in front. The heap climbs as the yard fills, which makes the box a readout — a glance says
## whether the ferry is keeping up without reading a number.
func _draw() -> void:
	var half := CRATE * 0.5
	var lift := Vector2(0.0, -CRATE_TALL)

	# The ground it stands on, and the inside of the box seen over the near wall. The shadow
	# is the crate's own footprint — a square on the plane, which is this diamond on screen —
	# rather than a soft pool bigger than the box: nothing else here casts one of those, and
	# a crate is a box sitting flat on the sand.
	_diamond(Vector2(0.0, SHADOW_DROP), CRATE * SHADOW_SPREAD, Color(0.0, 0.0, 0.0, 0.22))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, -half.y), Vector2(half.x, 0.0),
			Vector2(0.0, half.y), Vector2(-half.x, 0.0)
		]),
		INSIDE
	)

	# The far two walls, standing up off the back edges.
	_wall(Vector2(-half.x, 0.0), Vector2(0.0, -half.y), lift, WOOD_DARK)
	_wall(Vector2(0.0, -half.y), Vector2(half.x, 0.0), lift, WOOD)

	if grid != null and not held.is_empty():
		_draw_heap()

	# The near two walls, over the heap, which is what puts the heap inside the box.
	_wall(Vector2(half.x, 0.0), Vector2(0.0, half.y), lift, WOOD_LIT)
	_wall(Vector2(0.0, half.y), Vector2(-half.x, 0.0), lift, WOOD)

	# And the rim, so the box has an edge at the top rather than fading into the pile.
	draw_polyline(
		PackedVector2Array([
			Vector2(0.0, -half.y) + lift, Vector2(half.x, 0.0) + lift,
			Vector2(0.0, half.y) + lift, Vector2(-half.x, 0.0) + lift,
			Vector2(0.0, -half.y) + lift
		]),
		CRATE_INK, 1.6
	)


## One wall of the crate: the quad between an edge of the floor and the same edge lifted,
## with a couple of board lines across it.
func _wall(from: Vector2, to: Vector2, lift: Vector2, tint: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([from, to, to + lift, from + lift]), tint
	)
	for i in 2:
		var down := lift * ((float(i) + 1.0) / 3.0)
		draw_line(from + down, to + down, Color(CRATE_INK.r, CRATE_INK.g, CRATE_INK.b, 0.35), 1.0)
	draw_polyline(
		PackedVector2Array([from, to, to + lift, from + lift, from]), CRATE_INK, 1.4
	)


## The catch in the crate. Scattered inside its footprint and stacked upward as it fills,
## drawn back to front so the near pieces overlap the far ones.
func _draw_heap() -> void:
	_rng.seed = 90210
	var count := mini(held.size(), MAX_DRAWN)
	var floor_at := -CRATE_TALL * 0.25
	var spots: Array[Vector2] = []
	for i in count:
		var angle := _rng.randf_range(0.0, TAU)
		var reach := sqrt(_rng.randf()) * 0.6
		spots.append(
			Vector2(cos(angle) * CRATE.x * 0.5, sin(angle) * CRATE.y * 0.5) * reach
			+ Vector2(0.0, floor_at - float(i / 6) * 7.0)
		)
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	for i in count:
		draw_set_transform(spots[i], _rng.randf_range(-0.2, 0.2), Vector2(0.62, 0.62))
		grid.defs[held[i]].stamp_iso(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _diamond(at: Vector2, extent: Vector2, colour: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			at + Vector2(0.0, -extent.y * 0.5), at + Vector2(extent.x * 0.5, 0.0),
			at + Vector2(0.0, extent.y * 0.5), at + Vector2(-extent.x * 0.5, 0.0)
		]),
		colour
	)
