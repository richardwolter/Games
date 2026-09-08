## The shed is down, and this says so.
##
## The other side of the coin from farewell.gd, and built the same way for the same reason:
## drawn text sized off the window, on its own layer over a lake that is still running
## underneath. A defeat screen assembled out of Labels and a StyleBox would be the one
## screen in this game that came from somewhere else.
##
## Unlike the ending, this one has to be answered. There are two doors and no way to click
## past them: losing the shed is not something to dismiss.
class_name Defeat
extends Control

## What happened, and what to do about it.
const LINES := [
	"The shed is gone.",
	"The lake has taken it back.",
]

const Style := preload("res://scripts/style.gd")

## Slow in: the player has just watched the last of the roof go, and a snap cut to a menu
## would be the game changing the subject.
const FADE_IN := 1.4
const FADE_OUT := 0.4

## Nothing may be answered for this long, so a click aimed at the water does not pick a
## door on the way past.
const SETTLE := 0.9

## The gap between the two lines, as a fraction of the first one's size. The sizes
## themselves come off the shared ladder: the window fraction they used to be worked out to
## one fixed number anyway, since the game already scales from a 1280x720 frame.
const GAP := 1.5

## How dark the lake goes behind the words. Darker than the ending: there is nothing down
## there worth looking at now.
const WASH := Style.SCRIM_HEAVY

## The doors: the padding inside one, the gap between them, and how far below the words
## they sit.
const DOOR_PAD := Vector2(30.0, 15.0)
const DOOR_GAP := 26.0
const DOOR_DROP := 3.0

const AGAIN := "Hold the shed again"
const BACK := "Back to the quiet lake"

## Which door was taken. The siege does the scene change; this only says which.
signal again
signal back

var _font: Font
var _shown: float = 0.0
var _leaving: bool = false
var _age: float = 0.0
## Where the two doors were last drawn, so a click is tested against the rectangles the
## player was actually looking at.
var _again_rect := Rect2()
var _back_rect := Rect2()
var _hot: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = Style.font()
	_fill()
	get_viewport().size_changed.connect(_fill)


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
		var over := get_parent()
		if over is CanvasLayer:
			over.queue_free()
		else:
			queue_free()


func _take(which: int) -> void:
	if _leaving or _age < SETTLE:
		return
	_leaving = true
	if which == 0:
		again.emit()
	else:
		back.emit()


func _gui_input(event: InputEvent) -> void:
	var moved := event as InputEventMouseMotion
	if moved != null:
		var over := _door_at(moved.position)
		if over != _hot:
			_hot = over
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	var door := _door_at(click.position)
	if door >= 0:
		_take(door)


## Which door a point is over: 0 for another go, 1 for the quiet lake, -1 for neither.
func _door_at(where: Vector2) -> int:
	if _again_rect.has_point(where):
		return 0
	if _back_rect.has_point(where):
		return 1
	return -1


func _draw() -> void:
	if _font == null or _shown <= 0.0:
		return
	var fade := 1.0 - pow(1.0 - _shown, 3.0)
	Style.dim(self, Rect2(Vector2.ZERO, size), WASH, fade)

	var first := float(Style.TEXT_TITLE)
	var second := float(Style.TEXT_HEAD)
	var ink := Color(Style.INK.r, Style.INK.g, Style.INK.b, fade)
	var shade := Color(Style.SHADE.r, Style.SHADE.g, Style.SHADE.b, Style.SHADE.a * fade)

	var block := first + first * GAP
	var top := size.y * 0.44 - block * 0.5
	top += (1.0 - fade) * size.y * 0.03
	_line(LINES[0], int(first), top + first, ink, shade)
	var under := top + first + first * GAP
	_line(LINES[1], int(second), under, ink, shade)

	# The two doors, side by side and centred as a pair, so neither is the default.
	var height := float(Style.TEXT_BODY)
	var again_box := _box(AGAIN, height)
	var back_box := _box(BACK, height)
	var wide := again_box.x + DOOR_GAP + back_box.x
	var left := (size.x - wide) * 0.5
	var row := under + height * DOOR_DROP
	_again_rect = Rect2(Vector2(left, row), again_box)
	_back_rect = Rect2(Vector2(left + again_box.x + DOOR_GAP, row), back_box)

	# One door back into the fight and one out of it, told apart by colour rather than by
	# which is on the left.
	_door(_again_rect, AGAIN, height, fade, shade, Style.DANGER.darkened(0.5), _hot == 0)
	_door(_back_rect, BACK, height, fade, shade, Style.COOL.darkened(0.6), _hot == 1)


func _box(text: String, height: float) -> Vector2:
	var wide := Style.measure(text, int(height)).x
	return Vector2(wide, height) + DOOR_PAD * 2.0


func _door(
	rect: Rect2, text: String, height: float, fade: float, shade: Color, tint: Color,
	hot: bool
) -> void:
	var lit := 0.20 if hot else 0.0
	# The rect drawn is the rect hit-tested — a door that moved under the cursor when hovered
	# would be unclickable at its own edge, on the one screen with no other way out.
	Style.plaque(self, rect, Color(tint.r, tint.g, tint.b, minf(1.0, 0.7 + lit)), fade)
	_line(
		text, int(height), rect.position.y + DOOR_PAD.y + height * 0.82,
		Color(Style.INK.r, Style.INK.g, Style.INK.b, fade), shade, rect
	)


## One line, centred in the window or in a box, with a shadow under it.
func _line(
	text: String, height: int, baseline: float, ink: Color, shade: Color,
	within: Rect2 = Rect2()
) -> void:
	var box := within if within.size.x > 0.0 else Rect2(0.0, baseline, size.x, 1.0)
	Style.write(
		self, text, height, Vector2(0.0, baseline),
		Color(ink.r, ink.g, ink.b, 1.0), HORIZONTAL_ALIGNMENT_CENTER,
		Rect2(box.position.x, baseline, box.size.x, 1.0), ink.a
	)
