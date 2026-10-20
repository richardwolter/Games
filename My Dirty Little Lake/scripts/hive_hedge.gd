## The hive room's hedge: a low bed of the island's own flowers along the window's foot, with
## bees working it (2026-10-18, the hive overhaul; Richard's pick A, "LOW HEDGE", off
## `tools/hive_look/last_backdrop.png`).
##
## **The bed is baked** (`tools/build_hive_hedge.py` -> `assets/hive_hedge.png`/`.json`): real
## pieces of `assets/flora.png` in drifts of one colour, graded by depth (small heads behind,
## the pack's clumps and tulips, four rows of the big heads at the foot) on a dark leaf body,
## ringed once in the outline ink, open at the foot. One period wide and wrapping, laid from
## the room's art grid (`HiveRoom.origin`) across the whole window, its last row on the
## window's foot, each painted pixel `HiveArt.PIXEL` canvas pixels: the steps' own grain.
## Drawn over the backdrop's darkening (it is in front of it), under the step's work and the
## hint card.
##
## **The bees are `BeeArt`'s worker** (bee A, the one every bee in the game is), working the
## flower pixels the builder listed: hovering beside a head facing it, resting on one with a
## blink now and then, or roaming a little over the bed, then off to another head in their own
## stretch of the hedge. As in the mockup, five a side of the hint card's columns (`CARD_COLS`,
## the widest card: a bee under it is not seen), a few more on a window wider than the grid,
## and two painted pixels clear of each other. On the art grid, like the steps. Decoration:
## nothing reads them back and nothing is saved.
class_name HiveHedge
extends Control

const ART := "res://assets/hive_hedge.png"
const CONTRACT := "res://assets/hive_hedge.json"

## Grid columns the hint card stands over at its widest (the mockup's `CARD_COLS`).
const CARD_COLS := Vector2(188.0, 452.0)
## A side of the card's grid gets one bee per this many painted pixels of hedge, as the
## mockup put five in its 188.
const BEE_EVERY := 37.0
## Nine, down from fourteen (2026-10-19, Richard: fewer bees in general).
const BEES_MOST := 9
## Two bees keep this far apart, box to box, in painted pixels (the mockup's `BEE_APART`).
const BEE_APART := Vector2(12.0, 10.0)
## Flight: painted pixels a second, and the wobble up and down on the way.
const FLY_PACE := 34.0
const WOBBLE := 1.5
const WOBBLE_RATE := 7.0
## How long a bee stays at a head (seconds), and how long it roams over the bed.
const HOVER_FOR := Vector2(1.4, 3.6)
const REST_FOR := Vector2(2.0, 5.0)
const ROAM_FOR := Vector2(1.5, 3.5)
## What a bee does next: hover, rest, roam (the mockup's two, two and one).
const PLAN_ODDS := Vector3(0.4, 0.4, 0.2)
## Where a bee stands at its head, in painted pixels: beside it and a little above (hover),
## on it (rest), over it (roam).
const HOVER_ASIDE := 7.0
const HOVER_UP := Vector2(3.0, 7.0)
const REST_UP := 3.0
const ROAM_UP := Vector2(9.0, 15.0)
const ROAM_ACROSS := 6.0
## A hovering bee's bob, a painted pixel, this many times a second.
const BOB_RATE := 1.6
## A resting bee blinks for `BLINK_FOR` once every `BLINK_EVERY`.
const BLINK_EVERY := 3.2
const BLINK_FOR := 0.15
const REST_HOLD := 0.6

enum Mode { GO, HOVER, REST, ROAM }

## The room whose art grid the hedge is laid from. Without one the grid is centred in the
## hedge's own box, as the room centres it.
var room: HiveRoom

var _strip: Texture2D
var _period := 640.0
var _tall := 0.0
var _heads := PackedVector2Array()
var _bees: Array[Bee] = []
var _roll := RandomNumberGenerator.new()
var _laid_for := Vector2(-1.0, -1.0)


class Bee:
	var at := Vector2.ZERO
	var to := Vector2.ZERO
	var head := Vector2.ZERO
	var mode := Mode.HOVER
	var next := Mode.HOVER
	var wait := 0.0
	var age := 0.0
	var left := false
	## The stretch of the hedge it works, grid x from and to.
	var lo := 0.0
	var hi := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_roll.randomize()
	if ResourceLoader.exists(ART):
		_strip = load(ART)
	if FileAccess.file_exists(CONTRACT):
		var book: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
		if book is Dictionary:
			_period = float((book as Dictionary).get("period", 640))
			_tall = float((book as Dictionary).get("tall", 0))
			var flat: Array = (book as Dictionary).get("heads", [])
			for k in range(0, flat.size() - 1, 2):
				_heads.append(Vector2(float(flat[k]), float(flat[k + 1])))
	if _strip != null and _tall <= 0.0:
		_tall = float(_strip.get_height())
	resized.connect(func() -> void: _laid_for = Vector2(-1.0, -1.0))


func is_painted() -> bool:
	return _strip != null


## The bees, for a harness.
func bees() -> Array[Bee]:
	return _bees


## The room coming up: the bees stood at their flowers afresh.
func reset() -> void:
	_laid_for = Vector2(-1.0, -1.0)
	_lay_bees()


## The art grid's top left in this control's canvas pixels.
func grid_origin() -> Vector2:
	if room != null and is_instance_valid(room):
		return room.origin()
	return HiveArt.snap((size - HiveArt.GRID * HiveArt.PIXEL) * 0.5)


## The hedge's top row, canvas pixels: its last row on the window's foot.
func top() -> float:
	return size.y - _tall * HiveArt.PIXEL


## A point in hedge space (grid x, rows down from the hedge's top) in canvas pixels, on the
## art grid.
func to_canvas(at: Vector2) -> Vector2:
	return Vector2(grid_origin().x + roundf(at.x) * HiveArt.PIXEL, top() + roundf(at.y) * HiveArt.PIXEL)


func _visible_span() -> Vector2:
	var left := -grid_origin().x / HiveArt.PIXEL
	return Vector2(left, left + size.x / HiveArt.PIXEL)


## Every flower pixel in the visible hedge between grid x `lo` and `hi`.
func _heads_in(lo: float, hi: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var first := floori(lo / _period)
	var last := floori(hi / _period)
	for tile in range(first, last + 1):
		var shift := float(tile) * _period
		for head in _heads:
			var x := head.x + shift
			if x >= lo and x < hi:
				out.append(Vector2(x, head.y))
	return out


func _lay_bees() -> void:
	_bees.clear()
	if _heads.is_empty() or size.x <= 0.0 or not BeeArt.ready():
		return
	_laid_for = size
	var span := _visible_span()
	var parts: Array[Vector2] = [
		Vector2(span.x, minf(CARD_COLS.x, span.y)), Vector2(maxf(CARD_COLS.y, span.x), span.y)
	]
	for part in parts:
		var wide := part.y - part.x
		if wide < BEE_APART.x:
			continue
		var count := clampi(int(wide / BEE_EVERY), 1, BEES_MOST / 2)
		var plan: Array[int] = []
		for k in count:
			plan.append([Mode.HOVER, Mode.HOVER, Mode.REST, Mode.REST, Mode.ROAM][k % 5])
		plan.shuffle()
		for k in count:
			var bee := Bee.new()
			bee.lo = part.x + wide * float(k) / float(count)
			bee.hi = part.x + wide * float(k + 1) / float(count)
			bee.age = _roll.randf() * 10.0
			if _choose(bee, plan[k] as Mode):
				bee.at = bee.to
				bee.mode = bee.next
			else:
				bee.at = Vector2((bee.lo + bee.hi) * 0.5, -6.0)
				bee.mode = Mode.ROAM
				bee.to = bee.at
			bee.wait = _hold_of(bee.mode) * _roll.randf_range(0.3, 1.0)
			_bees.append(bee)


func _hold_of(mode: Mode) -> float:
	match mode:
		Mode.REST:
			return _roll.randf_range(REST_FOR.x, REST_FOR.y)
		Mode.ROAM:
			return _roll.randf_range(ROAM_FOR.x, ROAM_FOR.y)
	return _roll.randf_range(HOVER_FOR.x, HOVER_FOR.y)


## Pick a head in the bee's stretch and where to be at it for `mode`, clear of every other
## bee's place. True when one was found.
func _choose(bee: Bee, mode: Mode) -> bool:
	var heads := _heads_in(bee.lo, bee.hi)
	if heads.is_empty():
		heads = _heads_in(bee.lo - 20.0, bee.hi + 20.0)
	if heads.is_empty():
		return false
	for attempt in 40:
		var head := heads[_roll.randi() % heads.size()]
		var left := _roll.randf() < 0.5
		var spot := head
		match mode:
			Mode.HOVER:
				var side := -1.0 if left else 1.0
				spot = head + Vector2(-side * HOVER_ASIDE, -_roll.randf_range(HOVER_UP.x, HOVER_UP.y))
			Mode.REST:
				spot = head + Vector2(0.0, -REST_UP)
			Mode.ROAM:
				spot = head + Vector2(
					_roll.randf_range(-ROAM_ACROSS, ROAM_ACROSS), -_roll.randf_range(ROAM_UP.x, ROAM_UP.y)
				)
		spot = spot.round()
		if not _clear(spot, bee):
			continue
		bee.head = head
		bee.to = spot
		bee.next = mode
		if mode != Mode.ROAM:
			bee.left = left
		return true
	return false


func _clear(spot: Vector2, me: Bee) -> bool:
	for other in _bees:
		if other == me:
			continue
		for place: Vector2 in [other.to, other.at]:
			if absf(place.x - spot.x) < BEE_APART.x and absf(place.y - spot.y) < BEE_APART.y:
				return false
	return true


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _laid_for != size:
		_lay_bees()
	for bee in _bees:
		bee.age += delta
		if bee.mode == Mode.GO:
			var gap := bee.to - bee.at
			var stride := FLY_PACE * delta
			if gap.length() <= stride:
				bee.at = bee.to
				bee.mode = bee.next
				bee.wait = _hold_of(bee.mode)
			else:
				bee.at += gap.normalized() * stride
				if absf(gap.x) > 0.5:
					bee.left = gap.x < 0.0
			continue
		bee.wait -= delta
		if bee.wait > 0.0:
			continue
		var roll := _roll.randf()
		var mode := Mode.HOVER
		if roll > PLAN_ODDS.x + PLAN_ODDS.y:
			mode = Mode.ROAM
		elif roll > PLAN_ODDS.x:
			mode = Mode.REST
		if _choose(bee, mode):
			bee.mode = Mode.GO
		else:
			bee.wait = 0.5
	queue_redraw()


func _draw() -> void:
	if _strip == null:
		return
	var grain := HiveArt.PIXEL
	var wide := _period * grain
	var origin_x := grid_origin().x
	var y := top()
	var x := origin_x - ceilf(origin_x / wide) * wide
	while x < size.x:
		draw_texture_rect(_strip, Rect2(Vector2(x, y), Vector2(wide, _tall * grain)), false)
		x += wide
	for bee in _bees:
		_draw_bee(bee)


func _draw_bee(bee: Bee) -> void:
	var at := bee.at
	var anim := &"worker_hover"
	var frame := 0
	match bee.mode:
		Mode.GO, Mode.ROAM:
			anim = &"worker_fly"
			frame = BeeArt.frame_at(anim, bee.age)
			if bee.mode == Mode.GO:
				at.y += roundf(sin(bee.age * WOBBLE_RATE) * WOBBLE)
		Mode.HOVER:
			frame = BeeArt.frame_at(anim, bee.age)
			at.y -= 1.0 if sin(bee.age * TAU * BOB_RATE) > 0.0 else 0.0
		Mode.REST:
			anim = &"worker_rest"
			frame = 3 if fposmod(bee.age, BLINK_EVERY) < BLINK_FOR else int(bee.age / REST_HOLD) % 3
	BeeArt.stamp(self, anim, frame, to_canvas(at), bee.left, HiveArt.PIXEL)
