class_name MendShine
extends Node2D
## Gold over the house's room while it mends itself (2026-10-29, Richard: "give some shine on
## house being fixed, so it is more visible"): the finds' four-point stars, whole art pixels,
## popping over the places being mended in time with the mending's taps and boards, and a
## burst with a warm wash over the room on its closing chime.
##
## Drawn only. The room (`ShedRoom._shine_*`) says where and when; nothing here reads the house.

## How long one star lives, popping in and out.
const STAR_LIFE := Vector2(0.6, 1.1)
## The longest arm a star grows, in art pixels.
const ARM := 4
## The warm wash on the chime: peak alpha and how long it takes to go.
const WASH := 0.22
const WASH_TIME := 1.0
const GOLD := Color(1.0, 0.8, 0.3)
const WHITE := Color(1.0, 0.98, 0.88)

## One art pixel of the room, in this node's pixels: the room's zoom.
var cell := 2.0
## Where the grid of art pixels starts, so a star lands on the house's own pixels.
var grid_from := Vector2.ZERO

var _stars: Array[Dictionary] = []
var _wash := 0.0
var _wash_box := Rect2()
var _roll := RandomNumberGenerator.new()


func _ready() -> void:
	_roll.randomize()
	set_process(false)


## A star at `at` (this node's pixels), starting `delay` seconds from now.
func sprinkle(at: Vector2, delay := 0.0, big := true) -> void:
	_stars.append({
		"at": at, "age": -delay, "life": _roll.randf_range(STAR_LIFE.x, STAR_LIFE.y),
		"arm": ARM if big else 2, "grain": 2.0 if big else 1.0,
	})
	set_process(true)


## The closing chime: the room washed warm for a moment.
func wash(box: Rect2) -> void:
	_wash = 1.0
	_wash_box = box
	set_process(true)


## How many stars are up or still to come: the harness asks.
func stars() -> int:
	return _stars.size()


func clear() -> void:
	_stars.clear()
	_wash = 0.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for star: Dictionary in _stars:
		star["age"] = float(star["age"]) + delta
		if float(star["age"]) < float(star["life"]):
			kept.append(star)
	_stars = kept
	_wash = maxf(_wash - delta / WASH_TIME, 0.0)
	if _stars.is_empty() and _wash <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _wash > 0.0:
		var ink := GOLD
		ink.a = WASH * _wash * _wash
		draw_rect(_wash_box, ink)
	for star: Dictionary in _stars:
		var t := float(star["age"])
		if t < 0.0:
			continue
		var bright := sin(clampf(t / float(star["life"]), 0.0, 1.0) * PI)
		_star(star["at"], int(roundf(float(star["arm"]) * bright)), bright, cell * float(star["grain"]))


## A plus of whole art pixels (two for a big star, so it reads across the room): a white
## middle, gold arms fading out along their length.
func _star(at: Vector2, arm: int, bright: float, grain: float) -> void:
	var middle := grid_from + ((at - grid_from) / grain).floor() * grain
	var px := Vector2.ONE * grain
	var core := WHITE
	core.a = clampf(bright * 1.4, 0.0, 1.0)
	draw_rect(Rect2(middle, px), core)
	for k in range(1, arm + 1):
		var ink := GOLD.lerp(WHITE, 0.4 if k == 1 else 0.0)
		ink.a = core.a * (1.0 - float(k - 1) / float(arm + 1))
		var step := float(k) * grain
		draw_rect(Rect2(middle + Vector2(step, 0.0), px), ink)
		draw_rect(Rect2(middle + Vector2(-step, 0.0), px), ink)
		draw_rect(Rect2(middle + Vector2(0.0, step), px), ink)
		draw_rect(Rect2(middle + Vector2(0.0, -step), px), ink)
