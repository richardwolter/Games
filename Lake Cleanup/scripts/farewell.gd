## The end of the run: the lake is empty, and this says so.
##
## Drawn rather than built out of Labels, for the same reason the shop board and the HUD are
## drawn — the game writes its own text everywhere else, and a centred pair of Label nodes
## with a StyleBox behind them would be the one screen that came from a different game. It
## also means the words are sized off the window rather than off a font size chosen for one
## resolution, which matters here: this is the last thing a player sees, and it should not
## be a caption on a phone and a wall of text on a monitor.
##
## Owns its own fade and its own dismissal. The lake underneath is still running and still
## sparkling; this is a note laid over it, not a scene change.
class_name Farewell
extends Control

## The words. Two lines because they are two thoughts: what the player did, and goodbye.
const LINES := [
	"You have cleaned your lake and can now live in peace.",
	"Thanks for playing!",
]

## The display face, and how far to fall back if it is missing. A missing font should cost
## the look of the screen, not the screen.
const FONT := "res://assets/RubbishFont2-Regular.ttf"

## How long the words take to arrive, and how long they take to go once dismissed. Slow in,
## because it is the end of a long job and the end of a long job is not a pop-up; quicker
## out, because by then the player has decided.
const FADE_IN := 1.6
const FADE_OUT := 0.5

## Nothing may be dismissed for this long. A player whose last catch happened under the
## cursor would otherwise click the screen away before reading a word of it.
const SETTLE := 0.6

## Text sizes as a fraction of the window's height, and the gap between the lines as a
## fraction of the first one's size.
const FIRST_SIZE := 0.068
const SECOND_SIZE := 0.050
const GAP := 1.5

## How dark the lake goes behind the words. Enough to read against, nowhere near enough to
## hide what the player has just finished — the sparkle is the other half of this ending.
const WASH := 0.55

## Emitted once the screen has faded out and is on its way to being freed, so the lake can
## give the angler their legs back.
signal dismissed

var _font: Font
## 0 to 1 on the way in, and back to 0 on the way out.
var _shown: float = 0.0
var _leaving: bool = false
var _age: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load(FONT) as Font
	if _font == null:
		_font = ThemeDB.fallback_font
	# Sized by hand rather than by anchors: the parent is a CanvasLayer, and a Control whose
	# parent is not a Control is not laid out by anyone. It has to keep up with the window
	# itself.
	_fill()
	get_viewport().size_changed.connect(_fill)


## Cover the window, whatever shape it currently is.
func _fill() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _process(delta: float) -> void:
	_age += delta
	var rate := 1.0 / (FADE_OUT if _leaving else FADE_IN)
	_shown = move_toward(_shown, 0.0 if _leaving else 1.0, rate * delta)
	queue_redraw()
	if _leaving and _shown <= 0.0:
		set_process(false)
		# The layer it was given is its own, so it takes that with it.
		var over := get_parent()
		if over is CanvasLayer:
			over.queue_free()
		else:
			queue_free()


## The player has read it. Called by the click, and safe to call twice.
func dismiss() -> void:
	if _leaving or _age < SETTLE:
		return
	_leaving = true
	dismissed.emit()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	dismiss()


func _draw() -> void:
	if _font == null or _shown <= 0.0:
		return
	# Eased so the words do not arrive at a constant rate, which reads as a machine doing
	# it. In fast, then a long settle.
	var fade := 1.0 - pow(1.0 - _shown, 3.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.03, WASH * fade))

	var first := maxf(size.y * FIRST_SIZE, 15.0)
	var second := maxf(size.y * SECOND_SIZE, 13.0)
	var ink := Color(0.96, 0.94, 0.87, fade)
	var shade := Color(0.0, 0.0, 0.0, 0.55 * fade)

	# The pair is centred as a block rather than each line on its own row, so the gap
	# between them belongs to the words and not to the window.
	var block := first + first * GAP
	# A little below the middle, because the middle is where the island is and the island is
	# the thing the sentence is about. The words sit on open water under it.
	var top := size.y * 0.60 - block * 0.5
	# Lifted a little as it arrives: the words settle onto the lake rather than appearing
	# on it.
	top += (1.0 - fade) * size.y * 0.03
	_line(LINES[0], int(first), top + first, ink, shade)
	_line(LINES[1], int(second), top + first + first * GAP, ink, shade)


## One line, centred, with a shadow under it. The shadow is what lets pale text sit over
## bright water without a panel behind it.
func _line(text: String, height: int, baseline: float, ink: Color, shade: Color) -> void:
	var wide := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, height).x
	var at := Vector2((size.x - wide) * 0.5, baseline)
	var drop := maxf(float(height) * 0.06, 1.0)
	_font.draw_string(
		get_canvas_item(), at + Vector2(drop, drop), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, height, shade
	)
	_font.draw_string(
		get_canvas_item(), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, height, ink
	)
