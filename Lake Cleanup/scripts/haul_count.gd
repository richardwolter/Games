class_name HaulCount
extends Control
## How much the cast has aboard, over the angler's head: "7/24", pieces over this cast's room
## (2026-09-26, `/grill-me` with Richard). Both nets of a double cast count, so "11/32"; up
## while anything is aboard, ticking with each grab; when the last net of the cast is home it
## pops and fades.
##
## A lucky throw or a double cast is up from the throw, at "0/..", with a burst of stars (same
## day, second pass): a lucky net's figure is gold with art-pixel stars twinkling round it, a
## double cast wears an "x2" tag, and both together swell bigger with more stars. A full cast
## is pale red, so gold means lucky and nothing else.
##
## Screen space on the HUD's layer, placed through the canvas transform the way
## `FirstSteps` places its prompts, so the figure is the font's own size at every zoom.
## Draws only: the lake hands it `count`, `room` and `head` every frame, `throw` at a cast and
## `pop` when the cast is home.

const Style := preload("res://scripts/style.gd")

## How far over the angler's feet the figure stands, in world px (the prompts' own height).
const HEAD_UP := 50.0
## The pop: how long it lasts, how much it swells at its peak, and how far it rises.
const POP_TIME := 0.7
const POP_SWELL := 0.35
const POP_RISE := 14.0
## A tick when a grab lands: the figure swells this much and settles over `TICK_TIME`.
const TICK_SWELL := 0.2
const TICK_TIME := 0.18
## The burst at a lucky or double throw: how long, and how much the figure swells. Both
## together swell `BOTH_SWELL` instead.
const BURST_TIME := 0.6
const BURST_SWELL := 0.5
const BOTH_SWELL := 0.8
## Stars round a lucky figure: how many (both lucky and double: `STARS_BOTH`), how far out
## they wander from the figure's box, one art pixel's size, and how long each lives.
const STARS := 5
const STARS_BOTH := 9
const STAR_OUT := 10.0
const STAR_PIXEL := 2.0
const STAR_LIFE := 0.7
const INK := Color(0.98, 0.96, 0.88)
## Lucky: the finds' gold, which on this lake is treasure.
const LUCKY_INK := Color(1.0, 0.84, 0.35)
## Full: a pale red, so a full plain net cannot read as a lucky one.
const FULL_INK := Color(1.0, 0.55, 0.45)
const TAG_INK := Color(0.62, 0.9, 1.0)

## Pieces aboard, room this cast, and the angler's feet in world space.
var count: int = 0
var room: int = 0
var head: Vector2 = Vector2.INF
## This cast's luck, set by `throw`.
var lucky := false
var double := false

var _shown_count: int = 0
var _heard: int = 0
var _shown_room: int = 0
var _tick: float = 0.0
var _burst: float = 0.0
var _clock: float = 0.0
## Up at nought: a lucky or double cast shows before anything is caught.
var _armed := false
## Seconds into a pop, or -1 while none is running.
var _popping: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	get_viewport().size_changed.connect(_fit)


## A Control on a CanvasLayer has no parent rect to anchor to; size it by hand (see
## `ClickRipple`), or a zero-sized one is culled before it draws.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


## A cast has left the hand. A lucky or double one is up at once, with its burst.
func throw(is_lucky: bool, is_double: bool) -> void:
	_popping = -1.0
	lucky = is_lucky
	double = is_double
	_armed = lucky or double
	_shown_count = 0
	_burst = BURST_TIME if _armed else 0.0
	queue_redraw()


## The cast is home: hold the last figure, swell it and let it go.
func pop() -> void:
	if _shown_count <= 0 and not _armed:
		return
	_popping = 0.0
	queue_redraw()


## Whether anything is on screen: the harness asks.
func showing() -> bool:
	return visible and (_shown_count > 0 or _armed or _popping >= 0.0)


func _process(delta: float) -> void:
	_clock += delta
	if _popping >= 0.0:
		_popping += delta
		if _popping >= POP_TIME:
			_popping = -1.0
			_shown_count = 0
			_armed = false
			lucky = false
			double = false
		queue_redraw()
		return
	# Up one figure a catch pop while the pops are still sounding, so the count and the
	# sound are one run (2026-10-01); with none waiting it snaps to the truth.
	var sound := Sfx.main()
	var heard := sound.pops_heard if sound != null else 0
	var stepped := heard - _heard
	_heard = heard
	if count != _shown_count:
		var to := count
		if count > _shown_count and sound != null and sound.pops_waiting() > 0:
			to = mini(count, _shown_count + stepped)
		if to > _shown_count:
			_tick = TICK_TIME
		_shown_count = to
	_shown_room = room
	_tick = maxf(_tick - delta, 0.0)
	_burst = maxf(_burst - delta, 0.0)
	if _shown_count > 0 or _armed:
		# The angler walks, the camera eases and the stars twinkle: keep up with all three.
		queue_redraw()


func _draw() -> void:
	if head == Vector2.INF or (_shown_count <= 0 and not _armed):
		return
	var xf := get_viewport().get_canvas_transform()
	var at := xf * (head + Vector2(0.0, -HEAD_UP))
	var both := lucky and double
	var swell := 1.0 + TICK_SWELL * (_tick / TICK_TIME)
	if _burst > 0.0:
		var b := _burst / BURST_TIME
		swell += (BOTH_SWELL if both else BURST_SWELL) * sin(b * PI)
	var alpha := 1.0
	if _popping >= 0.0:
		var t := _popping / POP_TIME
		swell = 1.0 + POP_SWELL * sin(minf(t * 2.0, 1.0) * PI * 0.5) * (1.0 - t * 0.5)
		at.y -= POP_RISE * t
		alpha = 1.0 - t * t
	var full := _shown_room > 0 and _shown_count >= _shown_room
	var size_px := Style.step(Style.TEXT_BODY * swell)
	var text := "%d/%d" % [_shown_count, _shown_room]
	var ink := FULL_INK if full else (LUCKY_INK if lucky else INK)
	var face := Style.font()
	var wide := face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
	var box := Rect2(at.x - wide * 0.5, at.y - face.get_ascent(size_px), wide, face.get_height(size_px))
	if lucky:
		_draw_stars(box, STARS_BOTH if both else STARS, alpha)
	Style.write(
		self, text, size_px, Vector2(0.0, at.y), Color(ink.r, ink.g, ink.b, alpha),
		HORIZONTAL_ALIGNMENT_CENTER, Rect2(at.x - 100.0, at.y - 40.0, 200.0, 80.0)
	)
	if double:
		var tag_px := Style.step(Style.TEXT_SMALL * maxf(swell * 0.9, 1.0))
		Style.write(
			self, "x2", tag_px, Vector2(box.end.x + 4.0, at.y - float(size_px) * 0.35),
			Color(TAG_INK.r, TAG_INK.g, TAG_INK.b, alpha)
		)


## Four-point stars of whole pixels round the figure, each on its own cycle, popping in and
## fading; a burst packs them in close for its first moment.
func _draw_stars(box: Rect2, n: int, alpha: float) -> void:
	for i in n:
		var cycle := _clock / STAR_LIFE + float(i) * 0.618
		var life := fposmod(cycle, 1.0)
		var roll := int(floor(cycle)) * 31 + i * 17
		var u := fposmod(sin(float(roll) * 12.9898) * 43758.5453, 1.0)
		var v := fposmod(sin(float(roll) * 78.233) * 12543.1234, 1.0)
		var area := box.grow(STAR_OUT)
		var spot := area.position + Vector2(u, v) * area.size
		var lit := sin(life * PI)
		if lit <= 0.05:
			continue
		var arm := 1 if lit < 0.6 else 2
		var tone := LUCKY_INK.lerp(Color.WHITE, lit * 0.6)
		tone.a = alpha * lit
		spot = (spot / STAR_PIXEL).round() * STAR_PIXEL
		draw_rect(Rect2(spot, Vector2.ONE * STAR_PIXEL), tone)
		for k in range(1, arm + 1):
			for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				draw_rect(Rect2(spot + d * STAR_PIXEL * float(k), Vector2.ONE * STAR_PIXEL), tone)
