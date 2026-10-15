class_name HeavyNote
extends Control
## "Need more Strength" over a net that came down on rubbish too heavy for it and lifted
## nothing (2026-10-15, issue #41: a demo player could not tell why pieces right by the island
## would not come up). From the third such landing on, until the next Strength level is bought;
## the lake counts and calls `show_at`.
##
## Screen space on the HUD's layer, placed through the canvas transform the way `HaulCount`
## is, so the line is the font's own size at every zoom. It rises a little and fades. One at a
## time: a new one replaces the last.

const Style := preload("res://scripts/style.gd")

## How long a line lasts, how far it rises, and how far over the net it starts, in world px.
const LIFE := 1.8
const RISE := 18.0
const OVER := 16.0
## When it starts to fade, as a share of `LIFE`.
const FADE_FROM := 0.6
## The full net's pale red (`HaulCount.FULL_INK`): this is the net saying no.
const INK := Color(1.0, 0.55, 0.45)

## What the line says: `Text.NEED_STRENGTH`, or in the demo at its Strength cap
## `Text.DEMO_LOCKED` (2026-10-15, `/grill-me` with Richard, a second player's notes: maxed out,
## told to buy more Strength that the demo does not sell). Set by the lake with each line.
var words := ""
var _at := Vector2.INF
var _age := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	get_viewport().size_changed.connect(_fit)


## See `HaulCount._fit`: a Control on a CanvasLayer has no parent rect to anchor to.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


## A line over `at`, a point on the lake in world space.
func show_at(at: Vector2) -> void:
	_at = at
	_age = 0.0
	queue_redraw()


## Whether a line is up: the harness asks.
func showing() -> bool:
	return _age >= 0.0


func _process(delta: float) -> void:
	if _age < 0.0:
		return
	_age += delta
	if _age >= LIFE:
		_age = -1.0
	queue_redraw()


func _draw() -> void:
	if _age < 0.0 or _at == Vector2.INF:
		return
	var t := _age / LIFE
	var at := get_viewport().get_canvas_transform() * (_at + Vector2(0.0, -OVER))
	at.y -= RISE * t
	var alpha := 1.0 if t < FADE_FROM else 1.0 - (t - FADE_FROM) / (1.0 - FADE_FROM)
	Style.write(
		self, words if not words.is_empty() else Text.NEED_STRENGTH, Style.TEXT_BODY, at, INK, HORIZONTAL_ALIGNMENT_CENTER,
		Rect2(at.x - 200.0, at.y - Style.TEXT_BODY, 400.0, Style.TEXT_BODY), alpha
	)
