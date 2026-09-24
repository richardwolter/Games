class_name FirstSteps
extends Control
## The first steps (2026-09-22, `/grill-me` with Richard, issue #24): after the letter's
## cards close on a new game, the controls are taught on the lake itself.
##
## 1. **Move** — the mouse and the walk keys (the stick in pad mode) over the angler's head,
##    and a pulsing ring with an arrow on a spot of the island's beach. Ends when the angler
##    stands on it, not on the first press.
## 2. **Cast** — a ring on green water in reach of that spot and the click (RT) over the
##    head. Ends on the first cast that catches anything.
## 3. **The note** — a paper card by the recycle box saying what the catch is for, and an
##    arrow on the box. Closes on a click or a few seconds after the catch lands.
##
## This node only draws; the lake decides the steps, the spots and when each ends
## (`Lake._first_steps_step`). It lives on the HUD's layer and draws in **screen space**,
## taking world points through the camera's own transform, so the prompts are always the
## same size on screen whatever the zoom. Picked off `tools/last_tutorial_mockup.png`.

const Style := preload("res://scripts/style.gd")

enum Step { OFF, MOVE, CAST, NOTE }

## Kenney's Input Prompts Pixel (CC0), cut by `tools/build_prompts.py`.
const PROMPTS := "res://assets/ui/prompts/%s.png"
## Physical screen pixels to one of the pack's pixels, picked off the mockup ("a little
## bit smaller" than three). Worked out against the window's stretch every frame, so the
## pack's pixels land on whole screen pixels at any window size.
const PROMPT_PX := 2.0
## How far over the angler's feet the prompts stand, in world pixels (`Angler.HEIGHT` is 40).
const HEAD_UP := 50.0
## Gap between the mouse and the keys, in the pack's pixels.
const PROMPT_GAP := 3.0
## The mouse's two frames, and the stick's, swap at this pace — a click, a push.
const BLINK := 0.5

## The beach ring, in tiles across; the water ring is the net's own open mouth.
const BEACH_RING := 0.7
## Ring ink: white over a dark backing, the aim ring's own trick for water of any colour.
const RING_INK := Color(1.0, 1.0, 1.0, 0.92)
const RING_BACK := Color(0.0, 0.0, 0.0, 0.45)
const RING_LINE := 2.0
const RING_BACK_LINE := 4.5
## The pulse: a fainter ring breathing out past the solid one, once a `PULSE_TIME`.
const PULSE_TIME := 1.1
const PULSE_OUT := 0.4
const PULSE_ALPHA := 0.55
## The arrow bobs over its ring by this many of the pack's pixels.
const ARROW_BOB := 2.0
const ARROW_LIFT := 6.0

## The note: a paper card beside the box, in canvas pixels.
const NOTE_TEXT := "Objects caught go to the recycle box so boats can take them to piers for money"
const NOTE_WIDE := 200.0
## A pixel under `Style.TEXT_TINY`, so the sentence sits in four lines with none alone.
const NOTE_SIZE := 10
const NOTE_PAD := Vector2(8.0, 6.0)
const NOTE_FROM_BOX := Vector2(40.0, 0.0)
const NOTE_RIM := 2.0
const NOTE_OUTER := Color(0.235, 0.165, 0.118)

var step: int = Step.OFF
## World points, handed in by the lake every frame; INF draws nothing there.
var head := Vector2.INF
var beach := Vector2.INF
var water := Vector2.INF
## The water ring's half-width in world pixels: the net's open mouth.
var water_wide := 24.0
var crate := Vector2.INF
var pad := false
## The walk keys as printed on this keyboard, up/left/down/right (`Binds.key_name`).
var keys: Array[String] = ["W", "A", "S", "D"]

var _clock := 0.0
var _tex := {}
var _note_box := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for piece: String in [
		"mouse_idle", "mouse_click", "key_w", "key_a", "key_s", "key_d", "key_z", "key_q",
		"stick", "stick_dirs", "pad_rt", "arrow_up",
	]:
		var path := PROMPTS % piece
		if ResourceLoader.exists(path):
			_tex[piece] = load(path)


func _process(delta: float) -> void:
	if step == Step.OFF:
		return
	_clock += delta
	queue_redraw()


## Whether a click at this canvas point lands on the note.
func note_hit(at: Vector2) -> bool:
	return step == Step.NOTE and _note_box.has_point(at)


## The prompt tile for a key label, or "" where the pack has none (a layout past these six).
static func key_tile(label: String) -> String:
	var tile := "key_" + label.to_lower()
	return tile if tile in ["key_w", "key_a", "key_s", "key_d", "key_z", "key_q"] else ""


func _draw() -> void:
	_note_box = Rect2()
	if step == Step.OFF:
		return
	var xf := get_viewport().get_canvas_transform()
	var px := _px()
	match step:
		Step.MOVE:
			if beach != Vector2.INF:
				_ring(xf, beach, Iso.TILE_W * 0.5 * BEACH_RING)
				_arrow(xf * beach, px)
			if head != Vector2.INF:
				_move_prompts(_on_screen(xf * head), px)
		Step.CAST:
			if water != Vector2.INF:
				_ring(xf, water, water_wide)
				_arrow(xf * water, px)
			if head != Vector2.INF:
				var tile := "pad_rt" if pad else _blink("mouse_idle", "mouse_click")
				_prompt(tile, _on_screen(xf * head), px, true)
		Step.NOTE:
			if crate != Vector2.INF:
				var at := _on_screen(xf * crate)
				_arrow(at, px)
				_note(at)


## A canvas point put on the window's own pixel grid (2026-09-24). The world is snapped to
## whole *screen* pixels (`Lake._snap_camera`), and at a 1.5 stretch a canvas pixel is one and
## a half of those: rounded to whole canvas pixels, the recycle note stepped against the box
## it stands by on every other frame of a walk, and read as trembling.
func _on_screen(at: Vector2) -> Vector2:
	var s := get_viewport().get_final_transform().get_scale().x
	if s <= 0.0:
		return at.round()
	return (at * s).round() / s


## Canvas pixels to one of the pack's: `PROMPT_PX` physical ones through the window stretch.
func _px() -> float:
	var canvas := get_viewport_rect().size.y
	var window := float(get_window().size.y) if get_window() != null else canvas
	return PROMPT_PX * canvas / maxf(window, 1.0)


func _blink(a: String, b: String) -> String:
	return a if fmod(_clock, BLINK * 2.0) < BLINK else b


## The walk prompts: the mouse, then the four keys in their cross, both on the head point.
func _move_prompts(at: Vector2, px: float) -> void:
	var cell := 16.0 * px
	if pad:
		_prompt(_blink("stick", "stick_dirs"), at, px, true)
		return
	var keys_wide := cell * 3.0
	var total := cell + PROMPT_GAP * px + keys_wide
	var left := at.x - total * 0.5
	var foot := at.y
	_prompt(_blink("mouse_idle", "mouse_click"), Vector2(left + cell * 0.5, foot - cell * 0.5), px, true)
	var kx := left + cell + PROMPT_GAP * px
	var tiles: Array[String] = []
	var fall: Array[String] = ["key_w", "key_a", "key_s", "key_d"]
	for i in 4:
		var t := key_tile(keys[i]) if i < keys.size() else ""
		tiles.append(t if t != "" else fall[i])
	_prompt(tiles[0], Vector2(kx + cell * 1.5, foot - cell * 1.5), px, true)
	for i in 3:
		_prompt(tiles[i + 1], Vector2(kx + cell * (0.5 + i), foot - cell * 0.5), px, true)


## One tile, centred on `at` (or with its foot on it when `centred` is false).
func _prompt(tile: String, at: Vector2, px: float, centred: bool) -> void:
	var tex: Texture2D = _tex.get(tile)
	if tex == null:
		return
	var size := tex.get_size() * px
	var corner := at - size * 0.5 if centred else at - Vector2(size.x * 0.5, size.y)
	draw_texture_rect(tex, Rect2(corner.round(), size), false)


## The down arrow over a spot, bobbing: the pack's up arrow turned over.
func _arrow(at: Vector2, px: float) -> void:
	var tex: Texture2D = _tex.get("arrow_up")
	if tex == null:
		return
	var size := tex.get_size() * px
	var bob := roundf(sin(_clock * TAU / PULSE_TIME) * ARROW_BOB) * px
	var foot := at.y - ARROW_LIFT * px + bob
	var corner := Vector2(at.x - size.x * 0.5, foot - size.y).round()
	draw_set_transform(corner + Vector2(0.0, size.y), 0.0, Vector2(1.0, -1.0))
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	draw_set_transform(Vector2.ZERO)


## A ring on the ground (2:1, the game's ellipse), solid, and its pulse breathing out.
func _ring(xf: Transform2D, at: Vector2, half_wide: float) -> void:
	var pulse := fmod(_clock, PULSE_TIME) / PULSE_TIME
	var out := _ellipse(xf, at, half_wide * (1.0 + PULSE_OUT * pulse))
	draw_polyline(out, Color(RING_INK, RING_INK.a * PULSE_ALPHA * (1.0 - pulse)), RING_LINE, true)
	var ring := _ellipse(xf, at, half_wide)
	draw_polyline(ring, RING_BACK, RING_BACK_LINE, true)
	draw_polyline(ring, RING_INK, RING_LINE, true)


func _ellipse(xf: Transform2D, at: Vector2, half_wide: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 49:
		var a := TAU * float(i % 48) / 48.0
		points.append(xf * (at + Vector2(cos(a) * half_wide, sin(a) * half_wide * 0.5)))
	return points


## The paper card beside the box: the letter's paper and inks, a dark rim, the words
## wrapped to its width and centred.
func _note(box_at: Vector2) -> void:
	var face := Style.font()
	var size_px := NOTE_SIZE
	var lines := _wrap(NOTE_TEXT, face, size_px, NOTE_WIDE - NOTE_PAD.x * 2.0)
	var line_tall := face.get_height(size_px) + 1.0
	var tall := line_tall * lines.size() + NOTE_PAD.y * 2.0
	var box := Rect2(_on_screen(box_at + NOTE_FROM_BOX), Vector2(NOTE_WIDE, tall).round())
	# Kept on the screen: the box can be near an edge after a pan.
	var view := get_viewport_rect().size
	box.position.x = clampf(box.position.x, 4.0, view.x - box.size.x - 4.0)
	box.position.y = clampf(box.position.y, 4.0, view.y - box.size.y - 4.0)
	_note_box = box
	draw_rect(box.grow(NOTE_RIM + 1.0), NOTE_OUTER, true)
	draw_rect(box, Style.PAPER, true)
	draw_rect(box.grow(-1.0), Style.PAPER_EDGE, false, NOTE_RIM)
	var y := box.position.y + NOTE_PAD.y + face.get_ascent(size_px)
	for line in lines:
		draw_string(
			face, Vector2(box.position.x, y), line, HORIZONTAL_ALIGNMENT_CENTER, box.size.x,
			size_px, Style.PAPER_INK
		)
		y += line_tall


static func _wrap(text: String, face: Font, size_px: int, wide: float) -> Array[String]:
	var lines: Array[String] = []
	var line := ""
	for word in text.split(" "):
		var tried := word if line.is_empty() else line + " " + word
		if face.get_string_size(tried, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x > wide \
				and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = tried
	if not line.is_empty():
		lines.append(line)
	return lines
