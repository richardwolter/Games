class_name TourCard
extends Control
## One card of a tour over whatever is on screen: the decoration tour's (2026-09-22,
## `/grill-me` with Richard, issue #24) spotlight, arrow and paper card, the shop tour's look
## (`ShopSkin._draw_tour`) for boards that are not the shop. The lake says what to point at
## and what to say (`Lake._decor_tour_step`); this draws it and reports the clicks.
##
## Three ways to be up:
## - **a card** (`count` > 0): the target lit, everything else dimmed, the paper card with
##   "n/total", "Skip" and "Continue". It takes every click — a click goes on, "Skip" ends.
## - **a hint** (`count` 0 with text): the target outlined and pointed at with a card that has
##   no count, no dimming, and clicks passing straight through — the player is being shown
##   where to click, so the click has to reach it.
## - **a pointer** (no text): the outline and the arrow only, clicks passing through.

const Style := preload("res://scripts/style.gd")

signal next_asked
signal skip_asked

const DIM := Color(0.0, 0.0, 0.0, 0.58)
const OUTLINE := Color(1.0, 1.0, 1.0, 0.9)
const GAP := 20.0
const CONTINUE := "Continue"
const SKIP := "Skip"

## What is pointed at, in this control's pixels. Empty: nothing up.
var target := Rect2()
var text := ""
## This card's place in the tour, and how many there are. `count` 0 is a hint.
var count := 0
var total := 0
var pad := false

## Whether a click on the lit target reaches what is under it (2026-09-24, Richard: a
## click on the button a card points at should do what the button does). The card's own
## paper still takes its clicks.
var through := false
var _card := Rect2()
var _skip := Rect2()
var _clock := 0.0
var _mouse: Texture2D = _load("mouse_click")
var _a: Texture2D = _load("pad_a")
var _arrow: Texture2D = _load("arrow_up")


static func _load(name_of: String) -> Texture2D:
	var path := "res://assets/ui/prompts/%s.png" % name_of
	return load(path) if ResourceLoader.exists(path) else null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Put a card up, or a hint (`at` 0), or a pointer (no words); an empty target takes it down.
func show_card(at: Rect2, words: String = "", place: int = 0, of: int = 0,
		pass_through: bool = false) -> void:
	through = pass_through
	target = at
	text = words
	count = place
	total = of
	var blocking := at.size.x > 0.0 and count > 0
	mouse_filter = Control.MOUSE_FILTER_STOP if blocking else Control.MOUSE_FILTER_IGNORE
	visible = at.size.x > 0.0
	queue_redraw()


func is_card() -> bool:
	return visible and count > 0


func _process(delta: float) -> void:
	# Hung off a CanvasLayer, where anchors have no parent rect to fill: sized by hand.
	var view := get_viewport_rect().size
	if size != view or position != Vector2.ZERO:
		position = Vector2.ZERO
		size = view
	if visible:
		_clock += delta
		queue_redraw()


## Not here over the lit target of a pass-through card, so the GUI picks what is under it.
func _has_point(point: Vector2) -> bool:
	if through and is_card() and target.has_point(point) and not _card.has_point(point):
		return false
	return Rect2(Vector2.ZERO, size).has_point(point)


func _gui_input(event: InputEvent) -> void:
	if not is_card():
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	Sfx.ui(&"ui_click")
	if _skip.has_point(click.position):
		skip_asked.emit()
	else:
		next_asked.emit()


func _draw() -> void:
	_skip = Rect2()
	_card = Rect2()
	if target.size.x <= 0.0:
		return
	var view := Rect2(Vector2.ZERO, size)
	if count > 0:
		draw_rect(Rect2(0.0, 0.0, size.x, target.position.y), DIM, true)
		draw_rect(Rect2(0.0, target.end.y, size.x, size.y - target.end.y), DIM, true)
		draw_rect(Rect2(0.0, target.position.y, target.position.x, target.size.y), DIM, true)
		draw_rect(Rect2(target.end.x, target.position.y, size.x - target.end.x, target.size.y), DIM, true)
	draw_rect(target, OUTLINE, false, 2.0)
	var px := _px()
	if _arrow != null:
		var a := _arrow.get_size() * px
		var bob := roundf(sin(_clock * TAU / FirstSteps.PULSE_TIME) * FirstSteps.ARROW_BOB) * px
		var corner := Vector2(target.get_center().x - a.x * 0.5, target.position.y - a.y - 2.0 + bob).round()
		draw_set_transform(corner + Vector2(0.0, a.y), 0.0, Vector2(1.0, -1.0))
		draw_texture_rect(_arrow, Rect2(Vector2.ZERO, a), false)
		draw_set_transform(Vector2.ZERO)
	if text.is_empty():
		return
	var face := Style.font()
	var size_px := FirstSteps.NOTE_SIZE
	var wide := FirstSteps.NOTE_WIDE
	var pad_in := FirstSteps.NOTE_PAD
	var lines := FirstSteps._wrap(text, face, size_px, wide - pad_in.x * 2.0)
	var line_tall := face.get_height(size_px) + 1.0
	var icon := _a if pad else _mouse
	var icon_size := icon.get_size() * px if icon != null else Vector2.ZERO
	var foot_tall := maxf(line_tall, icon_size.y) if count > 0 else 0.0
	var head := line_tall if count > 0 else 0.0
	var tall := pad_in.y * 2.0 + head + line_tall * float(lines.size()) + (4.0 + foot_tall if count > 0 else 0.0)
	var card := Rect2(_card_at(Vector2(wide, tall)), Vector2(wide, tall)).abs()
	card.position.x = clampf(card.position.x, 4.0, view.size.x - card.size.x - 4.0)
	card.position.y = clampf(card.position.y, 4.0, view.size.y - card.size.y - 4.0)
	card.position = card.position.round()
	card.size = card.size.round()
	_card = card.grow(FirstSteps.NOTE_RIM + 1.0)
	draw_rect(card.grow(FirstSteps.NOTE_RIM + 1.0), FirstSteps.NOTE_OUTER, true)
	draw_rect(card, Style.PAPER, true)
	draw_rect(card.grow(-1.0), Style.PAPER_EDGE, false, FirstSteps.NOTE_RIM)
	var ascent := face.get_ascent(size_px)
	var inner := card.grow_individual(-pad_in.x, -pad_in.y, -pad_in.x, -pad_in.y)
	if count > 0:
		draw_string(face, Vector2(inner.position.x, inner.position.y + ascent), "%d/%d" % [count, total],
			HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x, size_px, Style.PAPER_SOFT)
	var y := inner.position.y + head + ascent
	for line in lines:
		draw_string(face, Vector2(card.position.x, y), line, HORIZONTAL_ALIGNMENT_CENTER, card.size.x,
			size_px, Style.PAPER_INK)
		y += line_tall
	if count <= 0:
		return
	var foot_mid := inner.end.y - foot_tall * 0.5
	var base := foot_mid + ascent * 0.5 - 1.0
	var skip_wide := face.get_string_size(SKIP, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
	draw_string(face, Vector2(inner.position.x, base), SKIP, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, Style.PAPER_SOFT)
	_skip = Rect2(inner.position.x - 4.0, foot_mid - foot_tall * 0.5 - 2.0, skip_wide + 8.0, foot_tall + 4.0)
	var icon_at := Vector2(inner.end.x - icon_size.x, foot_mid - icon_size.y * 0.5).round()
	if icon != null:
		draw_texture_rect(icon, Rect2(icon_at, icon_size), false)
	var go_wide := face.get_string_size(CONTINUE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
	draw_string(face, Vector2(icon_at.x - 4.0 - go_wide, base), CONTINUE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, Style.PAPER_INK)


## Where the card goes: inside the top right of a target that fills most of the screen, under
## one near the top, above one near the foot, else beside it on the side with more room.
func _card_at(card: Vector2) -> Vector2:
	if target.size.x > size.x * 0.45 and target.size.y > size.y * 0.55:
		return Vector2(target.end.x - card.x - GAP, target.position.y + GAP)
	if target.end.y < size.y * 0.25:
		return Vector2(target.get_center().x - card.x, target.end.y + GAP)
	if target.position.y > size.y * 0.7:
		return Vector2(target.get_center().x - card.x * 0.5, target.position.y - card.y - GAP * 2.0)
	if target.get_center().x < size.x * 0.5:
		return Vector2(target.end.x + GAP, target.position.y + minf(target.size.y * 0.2, 60.0))
	return Vector2(target.position.x - GAP - card.x, target.position.y + 10.0)


func _px() -> float:
	var canvas := get_viewport_rect().size.y
	var window := float(get_window().size.y) if get_window() != null else canvas
	return FirstSteps.PROMPT_PX * canvas / maxf(window, 1.0)
