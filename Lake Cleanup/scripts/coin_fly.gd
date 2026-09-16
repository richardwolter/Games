## Coins flying from a sale to the money plate.
##
## The ferry sells at a pier somewhere across the lake, and the purse in the corner moved
## with nothing between the two: a piece came down into a box and a number changed. This is
## the thing between. Every piece that lands at a yard sends a coin up out of the box that
## arcs across the screen to the plate's own coin, and the plate lights as it arrives
## (HudSkin.shine). The purse itself is paid when the piece lands, as before — the coin is
## the receipt on its way, not the money.
##
## Screen space, not world space: it lives on the HUD's layer, takes the sale's world point
## through the canvas transform once when the coin sets off, and flies in the pixels the
## plate is drawn in, so it reads the same at every zoom — a delivery seen from the far end
## of the lake still pays into the corner at the same size.
##
## One node draws all of them, like the haul. A coin in the air is a row in an array.
class_name CoinFly
extends Control

## Preloaded, as every user of it does: hud_buttons.gd has no class_name.
const HudButtons := preload("res://scripts/hud_buttons.gd")

## How long a coin is in the air, and how high it arcs above the straight line, in screen
## px. About the plate's shine time, so the plate stays lit from the first coin's landing
## to the last one's arrival.
const FLIGHT := 0.5
const ARC := 56.0

## The coin's size on the screen at the start and at the end: it comes up out of the box
## small and grows to about the plate's own coin as it arrives.
const SIZE_FROM := 12.0
const SIZE_TO := 22.0

## How many may be in the air at once. Past this a landing piece joins the last coin sent
## rather than sending its own: a late-game hold is a hundred pieces, and a hundred coins
## in a second is a fountain that hides the plate it is aimed at. What a coin carries is
## reported when it lands, so nothing is lost by the merge.
const MOST := 12

## A coin reached the plate, carrying this many pieces' worth.
signal landed(carry: int)

## Where the plate's coin is, in this control's own coordinates. Set by the lake to the
## HUD's `coin_centre`; without it coins fly to the top left corner, which is the bug to
## look for.
var target: Callable

## Coins in the air, as `{from, to, age, carry, spin}`.
var _flying: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7707
	set_process(false)


## How many coins are in the air.
func flying() -> int:
	return _flying.size()


## A piece landed at a yard: a coin sets off from there. `from_world` is the world point;
## it is turned into screen px here and now, so a camera that pans during the flight does
## not drag the coin's start about with it.
func fly(from_world: Vector2) -> void:
	fly_from(get_viewport().get_canvas_transform() * from_world)


## The same, from a point already in screen pixels. Used by the pigeon that pops into the
## side of the screen: it is drawn on a CanvasLayer and has no place on the lake at all, so
## there is no world point to put through the transform.
func fly_from(from: Vector2) -> void:
	if _flying.size() >= MOST:
		var last: Dictionary = _flying.back()
		last["carry"] = int(last["carry"]) + 1
		return
	_flying.append({
		"from": from,
		"to": _target(),
		"age": 0.0,
		"carry": 1,
		"spin": _rng.randf_range(0.6, 1.4),
	})
	set_process(true)
	queue_redraw()


## Drop whatever is in the air, unpaid-for on screen only: the purse was paid when each piece
## landed. Used when the shed covers the lake — a coin arcing over the decoration room, towards
## a plate that is not drawn, is a receipt for something the player cannot see.
func clear() -> void:
	_flying.clear()
	queue_redraw()


func _target() -> Vector2:
	if target.is_valid():
		return target.call()
	return Vector2.ZERO


func _process(delta: float) -> void:
	for i in range(_flying.size() - 1, -1, -1):
		var coin: Dictionary = _flying[i]
		coin["age"] = float(coin["age"]) + delta
		if float(coin["age"]) >= FLIGHT:
			landed.emit(int(coin["carry"]))
			_flying.remove_at(i)
	if _flying.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for coin: Dictionary in _flying:
		var t := clampf(float(coin["age"]) / FLIGHT, 0.0, 1.0)
		# Quick off the box and easing onto the plate, and an arc over the straight line.
		var eased := 1.0 - (1.0 - t) * (1.0 - t)
		var from: Vector2 = coin["from"]
		var to: Vector2 = coin["to"]
		var at := from.lerp(to, eased) - Vector2(0.0, sin(t * PI) * ARC)
		var size := lerpf(SIZE_FROM, SIZE_TO, t)
		# The coin turns over as it flies: its width narrows and widens with the spin, and it
		# lands face on.
		var turn := absf(cos(t * TAU * float(coin["spin"])))
		var wide := lerpf(maxf(size * lerpf(0.3, 1.0, turn), 3.0), size, t * t)
		draw_set_transform(at, 0.0, Vector2(wide / size, 1.0))
		HudButtons.coin(
			self, Rect2(Vector2(-size * 0.5, -size * 0.5), Vector2(size, size)), Color.WHITE
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
