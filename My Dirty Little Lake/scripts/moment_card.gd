class_name MomentCard
extends Control
## The words over the wildlife moment (`Lake._start_owed_moment`): one line on the recycle
## note's paper, low in the window so the animal it is about stays in the middle. It fades in
## after `delay`, holds, and fades out; clicks pass through. Draws only.

const Style := preload("res://scripts/style.gd")

## How far down the window the card's middle stands.
const DOWN := 0.78
const PAD := Vector2(22.0, 12.0)
const RIM := 2.0
const OUTER := Color(0.08, 0.06, 0.06)
const FADE := 0.4

var text := ""
var _clock := -1.0
var _delay := 0.0
var _hold := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	get_viewport().size_changed.connect(_fit)
	set_process(false)


## Sized by hand: a Control on a CanvasLayer has no parent rect to anchor to.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


## Up after `delay` seconds, for `hold` seconds, then gone.
func show_for(delay: float, hold: float) -> void:
	_delay = delay
	_hold = hold
	_clock = 0.0
	set_process(true)
	queue_redraw()


## Whether the card is on the screen: the harness asks.
func showing() -> bool:
	return _clock >= _delay and _clock < _delay + _hold + FADE


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= _delay + _hold + FADE:
		_clock = -1.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _clock < _delay or text.is_empty():
		return
	var t := _clock - _delay
	var alpha := clampf(t / FADE, 0.0, 1.0) * clampf((_hold + FADE - t) / FADE, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var face := Style.font()
	var size_px := Style.TEXT_HEAD
	var wide := face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
	var room := size.x - 40.0 - PAD.x * 2.0
	if wide > room:
		size_px = Style.TEXT_BODY
		wide = face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
	var box := Rect2(
		Vector2(size.x * 0.5 - wide * 0.5 - PAD.x, size.y * DOWN - face.get_height(size_px) * 0.5 - PAD.y),
		Vector2(wide + PAD.x * 2.0, face.get_height(size_px) + PAD.y * 2.0)
	)
	box.position = box.position.round()
	box.size = box.size.round()
	modulate.a = alpha
	draw_rect(box.grow(RIM + 1.0), OUTER, true)
	draw_rect(box, Style.PAPER, true)
	draw_rect(box.grow(-1.0), Style.PAPER_EDGE, false, RIM)
	draw_string(
		face, Vector2(box.position.x, box.position.y + PAD.y + face.get_ascent(size_px)),
		text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, size_px, Style.PAPER_HEAD
	)
