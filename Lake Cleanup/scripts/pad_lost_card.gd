class_name PadLostCard
extends Control
## The card that holds the lake when the pad goes away in the player's hands (issue #33,
## decided with `/grill-me`, 2026-10-06): the battery dies or the cable comes out, and the
## world pauses (the settings board's pause) under two lines on the recycle note's paper, in
## the middle of the window. It stays until the pad comes back or the mouse is picked up;
## the lake decides both (`Lake._on_pad_lost`). Draws only; clicks pass through.

const Style := preload("res://scripts/style.gd")

const PAD := Vector2(26.0, 16.0)
const RIM := 2.0
const LINE_GAP := 8.0
const OUTER := Color(0.08, 0.06, 0.06)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	get_viewport().size_changed.connect(_fit)
	Prefs.language_changed.connect(queue_redraw)


## Sized by hand: a Control on a CanvasLayer has no parent rect to anchor to.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


func _draw() -> void:
	var head := Text.PAD_LOST_HEAD
	var line := Text.PAD_LOST_TEXT
	var head_size := Style.TEXT_HEAD
	var line_size := Style.TEXT_SMALL
	var room := size.x - 40.0 - PAD.x * 2.0
	if Style.measure(head, head_size).x > room:
		head_size = Style.TEXT_BODY
	var wide := maxf(Style.measure(head, head_size).x, Style.measure(line, line_size).x)
	var face := Style.font()
	var tall := face.get_height(head_size) + LINE_GAP + face.get_height(line_size)
	var box := Rect2(
		Vector2(size.x * 0.5 - wide * 0.5 - PAD.x, size.y * 0.5 - tall * 0.5 - PAD.y),
		Vector2(wide + PAD.x * 2.0, tall + PAD.y * 2.0)
	)
	box.position = box.position.round()
	box.size = box.size.round()
	Style.dim(self, Rect2(Vector2.ZERO, size), Style.SCRIM)
	draw_rect(box.grow(RIM + 1.0), OUTER, true)
	draw_rect(box, Style.PAPER, true)
	draw_rect(box.grow(-1.0), Style.PAPER_EDGE, false, RIM)
	var inner := box.grow_individual(-PAD.x, -PAD.y, -PAD.x, -PAD.y)
	var y := inner.position.y + face.get_ascent(head_size)
	Style.write(self, head, head_size, Vector2(0.0, y), Style.PAPER_HEAD, HORIZONTAL_ALIGNMENT_CENTER, inner)
	y += face.get_descent(head_size) + LINE_GAP + face.get_ascent(line_size)
	Style.write(self, line, line_size, Vector2(0.0, y), Style.PAPER_INK, HORIZONTAL_ALIGNMENT_CENTER, inner)
