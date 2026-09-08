## A find held up to the player: the piece that just came out of the water, shining, with
## a line saying what it is.
##
## The shed is the only place a find is ever seen properly, and the shed is behind two
## clicks — so a player pulling a wardrobe out of a lake got a line of small text in the
## corner and nothing else. This is the moment that was missing: the thing itself, big, in
## the middle of the screen, in the cleaned-up palette it will wear on the shelf rather
## than the grimy one it came up in.
##
## Drawn rather than built from nodes, like the farewell screen and the shop board. It
## never blocks the lake: the mouse goes straight through it, the angler keeps their legs,
## nothing is dimmed, and a second find arriving while one is up is queued behind it rather
## than lost. It sits low and small on purpose — this happens mid-cast, and a card that
## takes the middle of the screen takes the lake away from a player who is still fishing.
class_name Trophy
extends Control

const Style := preload("res://scripts/style.gd")

## What is always said. The name of the piece goes underneath it.
const TITLE := "You got a new decoration"

## The three parts of one showing, in seconds: the pop in, how long it is held, and the
## fade out. Short — this happens mid-cast, and a player who is fishing should not be made
## to wait for a card to leave.
const RISE := 0.42
const HOLD := 1.9
const LEAVE := 0.5

## Where the card sits, as a fraction of the window's height. Down in the open water under
## the island, clear of the HUD along the top and of the buttons in the corners.
const MIDDLE := 0.79

## The piece's height as a fraction of the window's, and the most it may be blown up from
## its own pixels. Furniture is cut small; past a point it stops being a picture of a chair
## and becomes a grid of squares.
const PIECE_HEIGHT := 0.13
const PIECE_ZOOM := 4.5

## The shine behind it: how many rays, how far they reach past the piece, and how fast the
## wheel turns in turns a second. Slow — this is a glow, not a siren.
const RAYS := 10
const RAY_REACH := 1.9
const RAY_SPIN := 0.05

## The dark disc the piece stands in, as a multiple of its own half-size, and how solid
## that pool is. The lake is a busy picture, and a chair drawn straight onto it is a chair
## lost in a field of bottles; this gives the find something to be seen against without
## covering the game up.
const DISC := 2.6
const DISC_DARK := 0.72

## The motes drifting off it, how far out they start, and how long each one lives as a
## fraction of the showing.
const MOTES := 14
const MOTE_SPREAD := 0.85

## Emitted when the last queued find has left the screen, so the lake can hush whatever it
## turned on for it.
signal emptied

## The atlas the pieces are cut from. Set by the lake before anything is shown.
var sheets: Sheets

## What is waiting to be shown, each `{piece, title}`. The one being shown is the first.
var _queue: Array = []

## How far through the current showing, in seconds, and the font it is written in.
var _age: float = 0.0
var _font: Font

## Fixed seed: the motes scatter the same way every frame of one showing, and are re-dealt
## for the next.
var _rng := RandomNumberGenerator.new()

## The card is three layers, and they have to be drawn in this order: the dimmed lake and
## the words, then the light, then the piece itself. So the middle two are children — a
## child draws after its parent, and two children draw in the order they were added.
##
## The light is a child for a second reason as well: it is added to what is behind it
## rather than painted over it. Shine mixed the ordinary way is a pale wedge sitting on the
## lake; shine that is added is light. The words must not be treated that way, which is why
## the material is on the child and not on this node.
var _glow: Node2D
var _art: Node2D


func _ready() -> void:
	# Straight through: this is a card laid over a game that is still being played.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = Style.font()
	# The parent is a CanvasLayer, which lays out nobody, so the card keeps up with the
	# window itself the way the ending screen does.
	_fill()
	get_viewport().size_changed.connect(_fill)
	_glow = Node2D.new()
	_glow.name = &"Glow"
	var lit := CanvasItemMaterial.new()
	lit.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = lit
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	# After the light, so the piece is lit from behind rather than through.
	_art = Node2D.new()
	_art.name = &"Piece"
	_art.draw.connect(_draw_piece)
	add_child(_art)
	set_process(false)
	visible = false


func _fill() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


## Hold a find up. `piece` is its catalogue name and `title` the name a person would call
## it. A find arriving while another is up waits its turn: two wardrobes in one cast is a
## rare thing, but it is not a reason to lose one of them.
func show_find(piece: StringName, title: String) -> void:
	_queue.append({"piece": piece, "title": title})
	if _queue.size() == 1:
		_begin()


## Take everything down at once, without the fade. For a scene that is about to go away, or
## a load that has just replaced the run the finds belonged to.
func clear() -> void:
	_queue.clear()
	set_process(false)
	visible = false
	if _glow != null:
		_glow.queue_redraw()
	if _art != null:
		_art.queue_redraw()


func _begin() -> void:
	_age = 0.0
	_rng.seed = hash(String(_queue[0]["piece"]))
	visible = true
	set_process(true)
	queue_redraw()
	_glow.queue_redraw()
	_art.queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= RISE + HOLD + LEAVE:
		_queue.pop_front()
		if _queue.is_empty():
			clear()
			emptied.emit()
			return
		_begin()
		return
	queue_redraw()
	_glow.queue_redraw()
	_art.queue_redraw()


## How solid the card is, 0 to 1: eased in, held, and cut away again.
func _fade() -> float:
	if _age < RISE:
		return 1.0 - pow(1.0 - clampf(_age / RISE, 0.0, 1.0), 3.0)
	var left := RISE + HOLD + LEAVE - _age
	if left < LEAVE:
		return clampf(left / LEAVE, 0.0, 1.0)
	return 1.0


## The pop: overshoots a little and settles back, which is what makes it read as landing on
## the screen rather than being switched on. Sits at 1 for the whole of the hold, and
## shrinks a touch on the way out.
func _swell() -> float:
	if _age < RISE:
		var step := clampf(_age / RISE, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - step, 3.0)
		return lerpf(0.55, 1.0, eased) + sin(step * PI) * 0.12
	var left := RISE + HOLD + LEAVE - _age
	if left < LEAVE:
		return lerpf(0.94, 1.0, clampf(left / LEAVE, 0.0, 1.0))
	return 1.0


func _draw() -> void:
	if _queue.is_empty() or _font == null:
		return
	var fade := _fade()
	if fade <= 0.0:
		return
	var piece: StringName = _queue[0]["piece"]
	var swell := _swell()
	var centre := Vector2(size.x * 0.5, size.y * MIDDLE)

	var region := Rect2()
	if sheets != null and sheets.has(piece):
		region = sheets.alt_region_of(piece)
	var tall := size.y * PIECE_HEIGHT * swell
	var wide := tall
	if region.size.y > 0.0:
		wide = tall * (region.size.x / region.size.y)
		# Never past the point where the cut pixels stop being a picture.
		var most := region.size.y * PIECE_ZOOM * swell
		if tall > most:
			wide *= most / tall
			tall = most

	# The pool of dark the find stands in: a few discs inside each other rather than one, so
	# it falls off towards its edge instead of ending in a circle drawn on the lake.
	var pool := maxf(wide, tall) * 0.5 * DISC
	for step in 5:
		var part := float(step) / 4.0
		draw_circle(
			centre, pool * lerpf(1.0, 0.35, part),
			Style.scrim(DISC_DARK * 0.3 * fade)
		)

	# Where the light and the piece go, worked out here once and handed to the two children
	# that draw them.
	_glow.position = centre
	_glow.set_meta(&"radius", maxf(wide, tall) * 0.5)
	_glow.set_meta(&"fade", fade)
	_art.position = centre
	_art.set_meta(&"box", Vector2(wide, tall))
	_art.set_meta(&"region", region)
	_art.set_meta(&"fade", fade)

	var title := float(Style.TEXT_HEAD)
	var named := float(Style.TEXT_BODY)
	var ink := Color(Style.INK.r, Style.INK.g, Style.INK.b, fade)
	var shade := Color(Style.SHADE.r, Style.SHADE.g, Style.SHADE.b, Style.SHADE.a * fade)
	_line(TITLE, int(title), centre.y - tall * 0.5 - title * 0.7, ink, shade)
	# The piece's own name in gold, so the line that changes is the one the eye goes to.
	# Nothing at all for a piece that has not been named: the card is the picture, and a
	# card that says "Find 07" under it is worse than a card that says nothing.
	var named_title := String(_queue[0]["title"])
	if not named_title.is_empty():
		var named_ink := Style.GOLD.lerp(Style.INK, 0.4)
		_line(
			named_title, int(named), centre.y + tall * 0.5 + named * 1.3,
			Color(named_ink.r, named_ink.g, named_ink.b, fade), shade
		)


## The piece itself, over the light: its shadow first, so it sits on the shine rather than
## inside it. Drawn around the origin, because the node is moved to the middle of the card.
func _draw_piece() -> void:
	if _queue.is_empty():
		return
	var region: Rect2 = _art.get_meta(&"region", Rect2())
	var span: Vector2 = _art.get_meta(&"box", Vector2.ZERO)
	var fade := float(_art.get_meta(&"fade", 0.0))
	if region.size.x <= 0.0 or fade <= 0.0 or sheets == null:
		return
	var box := Rect2(-span * 0.5, span)
	_art.draw_texture_rect_region(
		sheets.atlas, Rect2(box.position + Vector2(0.0, span.y * 0.04), box.size),
		region, Color(0.0, 0.0, 0.0, 0.35 * fade)
	)
	_art.draw_texture_rect_region(sheets.atlas, box, region, Color(1.0, 1.0, 1.0, fade))


## Everything that is light rather than picture, drawn into the added-on child: the wheel
## of rays and the dust coming off them. Both are drawn around the origin, because the
## child is moved to the middle of the card rather than drawing there.
func _draw_glow() -> void:
	if _queue.is_empty():
		return
	var radius := float(_glow.get_meta(&"radius", 0.0))
	var fade := float(_glow.get_meta(&"fade", 0.0))
	if radius <= 0.0 or fade <= 0.0:
		return
	_draw_shine(Vector2.ZERO, radius, fade)
	_draw_motes(Vector2.ZERO, radius, fade)


## The shine: a wheel of tapering rays turning behind the piece, brightest at the moment it
## lands. Triangles rather than a texture — the whole game draws its own light — and an odd
## number of long ones among the short so the wheel does not read as a cog.
func _draw_shine(centre: Vector2, radius: float, fade: float) -> void:
	# The core: light gathered on the piece itself, brightest at the middle and gone by the
	# edge of the pool. Drawn before the rays, so they come out of it.
	for step in 6:
		var part := float(step) / 5.0
		_glow.draw_circle(
			centre, radius * lerpf(0.5, 2.0, part),
			Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, 0.05 * fade * (1.0 - part * 0.7))
		)

	var spin := _age * TAU * RAY_SPIN
	# Brightest during the pop, then settling to a steady glow behind the piece.
	var flare := 1.0 + (1.0 - clampf(_age / RISE, 0.0, 1.0)) * 2.2
	# Warm and thin. Rays this size drawn any brighter stop being light coming off a thing
	# and become a pinwheel drawn on the lake.
	var glow := Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, 0.085 * fade * flare)
	for i in RAYS:
		var angle := spin + TAU * float(i) / float(RAYS)
		var reach := radius * (RAY_REACH if i % 3 == 0 else RAY_REACH * 0.66)
		var wide := TAU / float(RAYS) * 0.16
		_glow.draw_colored_polygon(
			PackedVector2Array([
				centre,
				centre + Vector2(cos(angle - wide), sin(angle - wide)) * reach,
				centre + Vector2(cos(angle + wide), sin(angle + wide)) * reach,
			]),
			glow
		)


## The dust coming off it: a handful of points drifting outward and upward, each on its own
## clock, so the piece looks like it is giving something off rather than being lit.
func _draw_motes(centre: Vector2, radius: float, fade: float) -> void:
	_rng.seed = hash(String(_queue[0]["piece"])) ^ 0x51A2
	var span := RISE + HOLD + LEAVE
	for i in MOTES:
		var born := _rng.randf() * span * 0.7
		var life := span * 0.45
		var step := (_age - born) / life
		if step < 0.0 or step > 1.0:
			continue
		var angle := _rng.randf() * TAU
		var out := radius * lerpf(0.25, MOTE_SPREAD + 0.5, step)
		var at := centre + Vector2(cos(angle), sin(angle) * 0.8) * out
		at.y -= step * radius * 0.35
		# Bright at birth, gone by the end of its own life rather than the card's.
		var lit := (1.0 - step) * fade * 0.85
		_glow.draw_circle(at, maxf(radius * 0.045 * (1.0 - step * 0.5), 1.5),
			Color(1.0, 0.97, 0.80, lit))


## One line, centred, with a shadow under it — the same treatment the ending gives its
## words, and for the same reason: pale text over bright water needs an edge, not a panel.
func _line(text: String, height: int, baseline: float, ink: Color, shade: Color) -> void:
	Style.write(
		self, text, height, Vector2(0.0, baseline),
		Color(ink.r, ink.g, ink.b, 1.0), HORIZONTAL_ALIGNMENT_CENTER,
		Rect2(0.0, baseline, size.x, 1.0), ink.a
	)
