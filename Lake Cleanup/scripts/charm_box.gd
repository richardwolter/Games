## The box beside the yard: where netted charms queue, and where they go off.
##
## A crate with a row of slots in it. What the net brings in goes into the first empty slot
## from the left, and the box works its way along the row on its own clock, firing the head
## slot and shuffling the rest down. First in, first out — so the order the player catches
## things in is the order they happen in, and choosing what to go for next is choosing what
## the lake does next.
##
## The clock is deliberately faster than the effects it sets off. A charm fired at the head
## of the queue starts something that runs for ten or twelve seconds, and the next slot
## goes two seconds later, so a well-fed box has several things live at once — which is how
## fire and ice end up on the net together.
##
## Same shape as the yard it stands next to: an array, a put, a fill fraction, a signal,
## and one `_draw`.
class_name CharmBox
extends Node2D

const Style := preload("res://scripts/style.gd")

## How many charms it holds. Past this the net keeps what it caught and the box says no,
## which is the only pressure the queue applies.
const SLOTS := 6

## Seconds between one slot firing and the next.
const ACTIVATE_EVERY := 2.0

## The crate, on the plane, and how tall its walls stand.
const BOX := Vector2(96.0, 34.0)
const BOX_TALL := 20.0

## The crate's colours, matched to the yard's so the two read as a pair.
const WOOD := Style.CRATE
const WOOD_LIT := Style.CRATE_LIT
const WOOD_DARK := Style.CRATE_DARK
const INSIDE := Style.CRATE_IN
const INK := Style.SEAM

## Charm kinds waiting, oldest first.
var slots := PackedInt32Array()

## Off between waves and while the shed is down: a box that keeps firing into an empty lake
## wastes what the player caught.
var running: bool = true

## A slot has gone off. The siege decides what that means.
signal fired(kind: int)
## The box was full and something was offered to it.
signal refused(kind: int)

var _next: float = ACTIVATE_EVERY
var _flash: float = 0.0


func room_left() -> int:
	return SLOTS - slots.size()


## How full it is, 0 to 1. For the HUD and for the drawn lid.
func fullness() -> float:
	return clampf(float(slots.size()) / float(SLOTS), 0.0, 1.0)


## Seconds until the head slot goes off, or 0 when there is nothing queued.
func next_in() -> float:
	return _next if not slots.is_empty() else 0.0


## Put a charm in the queue. False means there was no room for it.
func put(kind: int) -> bool:
	if room_left() <= 0:
		refused.emit(kind)
		return false
	# An empty box fires its first charm promptly rather than sitting on it for a full
	# interval: the first thing you catch in a fight should do something.
	if slots.is_empty():
		_next = minf(_next, ACTIVATE_EVERY * 0.5)
	slots.append(kind)
	queue_redraw()
	return true


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 2.5, 0.0)
	if not running or slots.is_empty():
		queue_redraw()
		return
	_next -= delta
	if _next > 0.0:
		queue_redraw()
		return
	_next = ACTIVATE_EVERY
	var kind := slots[0]
	slots.remove_at(0)
	_flash = 1.0
	# No sound. The box fires every couple of seconds for as long as the player keeps
	# feeding it, and a chime on each one turned a fight into a doorbell.
	fired.emit(kind)
	queue_redraw()


## The crate and its row of slots. A lit slot is a charm waiting; the head one pulses
## against its own clock, so the player can see what is about to happen and how soon.
func _draw() -> void:
	var half := BOX * 0.5
	var top := PackedVector2Array([
		Vector2(0.0, -half.y), Vector2(half.x, 0.0),
		Vector2(0.0, half.y), Vector2(-half.x, 0.0),
	])
	# Walls first, so the rim sits on top of them.
	var wall := PackedVector2Array([
		Vector2(-half.x, 0.0), Vector2(0.0, half.y), Vector2(0.0, half.y + BOX_TALL),
		Vector2(-half.x, BOX_TALL),
	])
	draw_colored_polygon(wall, WOOD_DARK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(half.x, 0.0), Vector2(0.0, half.y), Vector2(0.0, half.y + BOX_TALL),
		Vector2(half.x, BOX_TALL),
	]), WOOD)
	draw_colored_polygon(top, INSIDE)
	var rim := top.duplicate()
	rim.append(top[0])
	draw_polyline(rim, INK, 1.8)

	# The slots, laid along the crate's long axis. Drawn from the queue, so an empty box is
	# visibly a row of empty holes rather than nothing at all.
	for i in SLOTS:
		var along := (float(i) + 0.5) / float(SLOTS) - 0.5
		var at := Vector2(along * BOX.x * 0.82, along * BOX.y * 0.82)
		var lit := i < slots.size()
		if not lit:
			_slot(at, Color(0.10, 0.09, 0.08, 0.85), 0.0)
			continue
		var tint: Color = CharmField.KIND_COLOURS[slots[i]]
		# The head slot breathes in time with what is left on its clock.
		var pulse := 0.0
		if i == 0 and running:
			pulse = 0.35 + 0.35 * (1.0 - clampf(_next / ACTIVATE_EVERY, 0.0, 1.0))
		_slot(at, tint, pulse)

	if _flash > 0.0:
		draw_circle(Vector2(0.0, 0.0), BOX.x * 0.42, Color(1.0, 0.96, 0.85, 0.25 * _flash))
		_lid(top, Color(1.0, 0.96, 0.85, 0.35 * _flash))


func _slot(at: Vector2, tint: Color, pulse: float) -> void:
	var extent := Vector2(BOX.x * 0.075, BOX.y * 0.15)
	var ring := PackedVector2Array()
	for i in 10:
		var angle := TAU * float(i) / 10.0
		ring.append(at + Vector2(cos(angle) * extent.x, sin(angle) * extent.y))
	# A dark seat under each slot, so an empty hole and a lit charm are different pictures
	# rather than two shades of brown.
	draw_circle(at, extent.x * 1.35, Color(0.05, 0.05, 0.05, 0.6))
	draw_colored_polygon(ring, tint.lightened(pulse * 0.6))
	if pulse > 0.0:
		draw_circle(at, extent.x * (1.6 + pulse), Color(tint.r, tint.g, tint.b, 0.25 * pulse))
	var edge := ring.duplicate()
	edge.append(ring[0])
	draw_polyline(edge, INK, 1.2)


func _lid(top: PackedVector2Array, tint: Color) -> void:
	draw_colored_polygon(top, tint)
	draw_colored_polygon(top, Color(WOOD_LIT.r, WOOD_LIT.g, WOOD_LIT.b, tint.a * 0.5))
