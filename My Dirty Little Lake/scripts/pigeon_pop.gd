## The pigeon that pops in at the side of the screen when the net closes on one.
##
## Netting a bird is the one thing in this game that pays the moment it happens — no ferry,
## no sale, the money simply arrives — and until now the only sign of it was a small splash
## out on the water where the player was not looking. This is the sign: the bird's head slides
## in from the left edge of the screen, coos, says what it paid, and pulls back out of sight.
##
## It is Mortal Kombat II's Toasty, and it is deliberately not solemn. That is also why it
## only fires on some catches (the lake rolls for it) — a gag that happens every single time
## is a notification.
##
## A Control on a CanvasLayer of its own, like the finds card: a layer does no layout, so the
## size is taken from the viewport whenever that changes, and `_process` runs only while
## something is actually on screen.
class_name PigeonPop
extends Control

const Style := preload("res://scripts/style.gd")

## How long the card takes to slide in, how long it sits there, and how long it takes to drop
## back out, in seconds. Quick: the whole thing is over in under a second, because it happens
## while the player is doing something else and it is not asking to be dealt with.
const RISE := 0.12
const HOLD := 0.55
const LEAVE := 0.16

## The portrait, cut off its page by tools/slice_pigeon_head.gd, and mirrored.
##
## The painting faces left with its neck cut off along the bottom. Mirrored it faces right,
## and leaning it over clockwise then swings the beak **down** and carries the cut round to
## the left — which is the whole trick: whichever edge of the screen the cut is laid against
## is the edge that does the hiding, and here it is the screen's own side.
##
## Its own drawing rather than a crop of the flock's art: the birds on the water are eleven
## pixels across, and the top of one blown up twenty times is a blur of six feathers. This is
## the same bird drawn at a size that can be looked at.
##
## It used to stand upright in the bottom left corner with its neck on the bottom edge
## (2026-09-16: that corner is the pollution meter's, and the two sat on top of each other).
const ART := "res://assets/pigeon_head.png"

## How tall the painting draws, in screen pixels, before it is leant over.
const HEAD_TALL := 128.0

## How far the head leans, clockwise, in degrees.
##
## Not a quarter turn: a head at ninety degrees is lying flat on its side, which was the
## first pass and read as a bird that had fallen over. At this angle the crown points up
## into the screen and the beak points down and out — a bird craning round the edge to look
## at what the player is doing (2026-09-16, Richard: "looking down, more diagonal"; 65
## degrees was tried first and 54 picked off the mockup).
##
## The lean is applied at draw time rather than baked, because there is no turning a picture
## a fraction of a quarter without resampling it, and this is pixel art. Only the head turns:
## the price tag beside it is drawn after the canvas is put back.
const HEAD_LEAN := 54.0

## How far past the left edge the cut is pushed, as a fraction of the head's height.
##
## Flush is not enough. The cut runs away at an angle, so a picture standing exactly on the
## edge still shows the flat of it and reads as a sticker placed near the edge. Pushed past,
## the screen's side does the cutting: a bird leaning in from outside the frame.
const HEAD_TUCK := 0.04

## Where the head sits down the screen, as a fraction of its height. Halfway: the bottom left
## corner belongs to the pollution meter, and a head in it covered the one reading the player
## watches all run (2026-09-16).
const HEAD_DOWN := 0.5

## How deep a band of the painting's bottom edge counts as the neck's cut, in its own pixels.
const CUT_BAND := 6

## The payment plaque: how far in the figure sits from its ends, and how far the tag stands
## off the bird. Small and close — it is a caption on the head, not a sign of its own.
const PAID_PAD := Vector2(5.0, 2.0)
const PAID_GAP := 2.0

## How big the figure is lettered. A rung down from the head-height it was: the tag is read in
## the corner of the eye while the head is what is being looked at.
const PAID_TEXT := Style.TEXT_SMALL


## The portrait, the figure to write, whether one is up, and how far through it is. A missing
## picture means nothing is ever drawn — the art can go missing, and that must cost the joke
## and not the game.
## The head has finished sliding in, at this point on the screen. The lake sends the
## catch's coin from here: the money is a pigeon's, so it should leave the pigeon, and it
## cannot leave a bird that is still off the edge.
signal arrived(at: Vector2)

var _head: Texture2D
var _paid: int = 0
var _showing: bool = false
var _age: float = 0.0
## Whether this pop has already said it arrived. One coin a head, however many frames the
## hold lasts.
var _announced: bool = false

## How far to the right of the picture's middle the neck's cut still reaches once the head is
## leant over, as a fraction of the picture's height. Measured off the art in `_measure_cut`,
## never written down: it is the lean that decides it, so a change to HEAD_LEAN moves it.
var _cut_reach: float = 0.5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_head = _turned(Art.texture(ART))
	_measure_cut(_head)
	_fill()
	get_viewport().size_changed.connect(_fill)


## The picture, mirrored, so that leaning it clockwise swings the beak down rather than up.
##
## A baked copy rather than a flip at draw time: both ways of asking a canvas for one — a
## negative destination width, and a transform scaled by minus one — went through without
## complaint elsewhere in this game and drew the picture exactly as it was.
func _turned(art: Texture2D) -> Texture2D:
	if art == null:
		return null
	var image := art.get_image()
	if image == null:
		return art
	if image.is_compressed():
		image.decompress()
	image.flip_x()
	return ImageTexture.create_from_image(image)


## Read the neck's cut off the painting and work out how far it reaches once leant over.
##
## The drawing knows where it ends and a constant does not — `Skirt.hem` reads a silhouette
## the same way and for the same reason. Without this the number that hides the cut would
## have to be re-guessed by eye every time the lean was nudged, and a guess that is a pixel
## short leaves the flat of the neck showing on screen.
func _measure_cut(art: Texture2D) -> void:
	if art == null:
		return
	var image := art.get_image()
	if image == null:
		return
	if image.is_compressed():
		image.decompress()
	var wide := image.get_width()
	var tall := image.get_height()
	if tall <= 0:
		return
	var middle := Vector2(float(wide), float(tall)) * 0.5
	var lean := deg_to_rad(HEAD_LEAN)
	# Started below anything the picture can give, not at zero: leant far enough over, the
	# whole cut sits *left* of the head's middle, and a floor of zero would throw that away
	# and shove the bird half off the screen for no reason.
	var reach := -INF
	for y in range(maxi(tall - CUT_BAND, 0), tall):
		for x in wide:
			if image.get_pixel(x, y).a <= 0.0:
				continue
			reach = maxf(reach, (Vector2(float(x), float(y)) - middle).rotated(lean).x)
	if reach == -INF:
		return
	_cut_reach = reach / float(tall)


## How far the cut reaches right of the head's middle, as a fraction of HEAD_TALL.
func cut_reach() -> float:
	return _cut_reach


## A CanvasLayer does no layout, so the Control is sized to the viewport by hand.
func _fill() -> void:
	size = get_viewport_rect().size
	queue_redraw()


## Show the bird. `paid` is what the catch was worth.
##
## A second bird while one is up restarts this one rather than queueing behind it: two pigeons
## netted in one cast is one joke, and a queue of them would still be popping long after the
## player had stopped finding it funny.
## Returns false when there is no art: the caller then knows no bird is coming and can
## fall back, rather than waiting for an `arrived` that will never be emitted.
func pop(paid: int) -> bool:
	if _head == null:
		return false
	_paid = paid
	_age = 0.0
	_showing = true
	_announced = false
	set_process(true)
	queue_redraw()
	return true


func _process(delta: float) -> void:
	_age += delta
	if not _announced and _age >= RISE:
		_announced = true
		arrived.emit(coin_from())
	if _age >= RISE + HOLD + LEAVE:
		_showing = false
		set_process(false)
	queue_redraw()


## Where a coin leaves the bird: the middle of what the head covers on screen, which is
## inside the picture at any lean and always this side of the edge. The beak was the other
## candidate and it is the part that swings furthest about as the lean is retuned.
func coin_from() -> Vector2:
	return head_box().get_center()


## How far up the card is, from 0 hidden below the edge to 1 fully in.
##
## Eased on the way in and left linear on the way out: a thing that arrives has to overcome
## something, and a thing that leaves is just gone.
func _shown() -> float:
	if _age < RISE:
		var through := _age / RISE
		return 1.0 - (1.0 - through) * (1.0 - through)
	if _age < RISE + HOLD:
		return 1.0
	return clampf(1.0 - (_age - RISE - HOLD) / LEAVE, 0.0, 1.0)


## How big the painting draws, before the lean.
func _span() -> Vector2:
	if _head == null:
		return Vector2.ZERO
	var art := _head.get_size()
	return art * (HEAD_TALL / maxf(art.y, 1.0))


## The point the head turns about, `out` being how far it still has to come in (0 fully in,
## 1 gone).
##
## The whole placement is this one point: the head is pushed left until the far end of the
## neck's cut has gone past the edge, and set halfway down the screen. Its own function
## because the harness asks it too — a check that worked the corner out for itself would be
## a second layout to drift from this one.
##
## The viewport is measured rather than `size` trusted. The Control is sized in `_fill`, and
## `_fill` runs when the viewport says it changed — which on a window that opens maximised is
## once, early, at the size it had before it was maximised. The head was then laid out against
## a screen of the wrong height and hung off the edge of the real one.
func head_centre(out: float = 0.0) -> Vector2:
	if _head == null:
		return Vector2.ZERO
	var view := get_viewport_rect().size
	# Off screen it is off the left of the screen entirely, so nothing fades and nothing
	# hangs half-drawn over the lake.
	var gone := out * (_span().length() + HEAD_TALL)
	return Vector2(
		-(_cut_reach + HEAD_TUCK) * HEAD_TALL - gone,
		view.y * HEAD_DOWN
	)


## What the leant-over head covers on screen, `out` as above. The bounds of the turned
## picture, not the picture — it is the tag's left-hand edge and the harness's yardstick.
func head_box(out: float = 0.0) -> Rect2:
	if _head == null:
		return Rect2()
	var span := _span()
	var lean := deg_to_rad(HEAD_LEAN)
	var centre := head_centre(out)
	var box := Rect2(centre, Vector2.ZERO)
	for corner: Vector2 in [
		Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)
	]:
		box = box.expand(centre + (corner * span).rotated(lean))
	return box


func _draw() -> void:
	if not _showing or _head == null:
		return

	var out := 1.0 - _shown()
	var centre := head_centre(out)
	var span := _span()

	# Only the head turns. The canvas is put straight again before anything else is drawn,
	# or the price tag leans over with the bird.
	draw_set_transform(centre, deg_to_rad(HEAD_LEAN), Vector2.ONE)
	draw_texture_rect(_head, Rect2(-span * 0.5, span), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# What it paid, on a tag to the right of the bird: the tag goes on the side with screen
	# on it, not off the edge.
	var box := head_box(out)
	var height := PAID_TEXT
	var label := "+%d$" % _paid
	var words := Style.measure(label, height)
	var tag := Rect2(
		Vector2(
			box.end.x + PAID_GAP,
			centre.y - (words.y + PAID_PAD.y * 2.0) * 0.5
		),
		words + PAID_PAD * 2.0
	)
	Style.plaque(self, tag, Style.WOOD_DEEP)
	Style.write(
		self,
		label,
		height,
		Vector2(0.0, tag.position.y + tag.size.y * 0.5 + float(height) * 0.35),
		Style.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER,
		tag
	)
