## The pigeon that pops into the corner when the net closes on one.
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

## The portrait, cut off its page by tools/slice_pigeon_head.gd. Drawn turned over: the bird
## is painted facing left, and one poking in from the left edge of the screen has to be looking
## into the screen rather than back out of it.
##
## Its own drawing rather than a crop of the flock's art: the birds on the water are eleven
## pixels across, and the top of one blown up twenty times is a blur of six feathers. This is
## the same bird drawn at a size that can be looked at.
const ART := "res://assets/pigeon_head.png"

## How tall the head draws, in screen pixels.
##
## No margin goes with it: the head sits flush in the corner, its neck on the bottom edge and
## its back against the left one, the way Dan Forden does. A gap around it turns a head leaning
## into shot into a picture of a head placed near a corner.
const HEAD_TALL := 128.0

## How far past the corner the head is pushed, as fractions of its own size: down past the
## bottom edge and out past the left one.
##
## Flush was not enough. The drawing is a head cut off at the neck, and the neck runs away at
## an angle — so a picture sitting exactly on the corner still shows a wedge of lake under it
## and reads as a sticker placed near the corner. Pushed past it, the screen edge does the
## cutting, which is the whole look: a bird leaning in from outside the frame.
const HEAD_SINK := 0.16
const HEAD_TUCK := 0.1

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
var _head: Texture2D
var _paid: int = 0
var _showing: bool = false
var _age: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_head = _turned(Art.texture(ART))
	_fill()
	get_viewport().size_changed.connect(_fill)


## The picture, mirrored. A copy rather than a flip at draw time: both ways of asking a
## canvas for one — a negative destination width, and a transform scaled by minus one — went
## through without complaint elsewhere in this game and drew the picture exactly as it was.
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


## A CanvasLayer does no layout, so the Control is sized to the viewport by hand.
func _fill() -> void:
	size = get_viewport_rect().size
	queue_redraw()


## Show the bird. `paid` is what the catch was worth.
##
## A second bird while one is up restarts this one rather than queueing behind it: two pigeons
## netted in one cast is one joke, and a queue of them would still be popping long after the
## player had stopped finding it funny.
func pop(paid: int) -> void:
	if _head == null:
		return
	_paid = paid
	_age = 0.0
	_showing = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= RISE + HOLD + LEAVE:
		_showing = false
		set_process(false)
	queue_redraw()


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


func _draw() -> void:
	if not _showing or _head == null:
		return

	var art := _head.get_size()
	var span := art * (HEAD_TALL / maxf(art.y, 1.0))

	# Measured here rather than trusted from `size`.
	#
	# The Control is sized in `_fill`, and `_fill` runs when the viewport says it changed —
	# which on a window that opens maximised is once, early, at the size it had before it was
	# maximised. The card was then laid out against a screen taller than the real one and hung
	# off the bottom of it, so the head came in with its chin cut off. What is wanted is the
	# neck exactly on the bottom edge, which needs the edge to be where it really is.
	var view := get_viewport_rect().size

	# In from the left edge rather than up from the bottom: the whole picture is a head, and a
	# head arrives by being put round the side of something. Off screen it is off the left of
	# the screen entirely, so nothing fades and nothing hangs half-drawn over the lake. Once it
	# is in, it is in the corner itself and a little past it: see HEAD_SINK.
	var out_by := (1.0 - _shown()) * span.x
	var at := Vector2(
		-span.x * HEAD_TUCK - out_by,
		view.y - span.y * (1.0 - HEAD_SINK)
	)
	draw_texture_rect(_head, Rect2(at, span), false)

	# What it paid, on a tag to the right of the bird now that the bird is in the left corner:
	# the tag goes on the side with screen on it, not off the edge.
	var height := PAID_TEXT
	var label := "+%d$" % _paid
	var words := Style.measure(label, height)
	var tag := Rect2(
		Vector2(
			at.x + span.x + PAID_GAP,
			at.y + span.y * 0.35 - (words.y + PAID_PAD.y * 2.0) * 0.5
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
