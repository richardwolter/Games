## A button that is the meter's wood with a word on it.
##
## For the buttons that live in the scene and are placed by anchors — the settings button in
## the HUD's corner — so they are the same wood as the HUD's own, rather than a stock Button
## in a theme override. It wears the meter's built border (`Style.meter_frame`) like the
## three corner buttons, and falls back to a clipped plank where that will not fit.
##
## The word is set to the face the border leaves rather than to the whole button, so a button
## sized to its own word has no empty wood around it.
class_name PlankButton
extends Control

const Style := preload("res://scripts/style.gd")

@export var label: String = "":
	set(value):
		label = value
		queue_redraw()

## A mark drawn in place of the word. The lake's settings button wears `&"gear"` and no word
## (2026-09-17, Richard: a gear is what every game uses); **the main menu's Settings plank
## keeps its word**, having the room and no convention to lean on.
##
## Drawn in code rather than fetched off a sheet, the way the close cross and the coin are:
## `assets/ui.png` has four pieces on it and none of them is a gear.
## The one door on a board that the player most often wants — the menu's Continue. It keeps
## the same wood; what changes is the face behind the word, from the boards' dark `BOARD` to
## the lighter `BOARD_ROW` an affordable shop row wears, plus the lit edge along its top.
##
## **Two channels, not one** (the shop's rule, 2026-09-17): the two faces are close in
## luminance, so told apart by hue alone they are one face to a red-green colourblind player.
## The lit edge is what carries it for them.
@export var accent: bool = false:
	set(value):
		accent = value
		queue_redraw()

@export var mark: StringName = &"":
	set(value):
		mark = value
		queue_redraw()

## How much of the face the word is set to, and how much room is left beside it.
const LABEL_SHARE := 0.78
const LABEL_PAD := 12.0

## The gear: how much of the face it fills, how many teeth, how far a tooth stands out of the
## rim, how wide a tooth is as a share of its pitch, and the hub's radius. First guesses, to
## be judged in the corner of the screen.
const GEAR_FILL := 0.76
const GEAR_TEETH := 8
const GEAR_TOOTH := 0.26
const GEAR_WIDTH := 0.46
const GEAR_HUB := 0.34

signal pressed

## Whether a press clicks. The menu's own planks turn it off and choose their sound there: New
## game and Continue play the start sound instead.
var clicks: bool = true

var _hovered: bool = false
var _held: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		_hovered = what == NOTIFICATION_MOUSE_ENTER
		if _hovered:
			Sfx.ui(&"ui_hover")
		if not _hovered:
			_held = false
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if click.pressed:
		_held = true
		if clicks:
			Sfx.ui(&"ui_click")
		queue_redraw()
		return
	if _held:
		_held = false
		queue_redraw()
		pressed.emit()


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	if _held:
		box.position.y += Style.PRESS_SINK
	elif _hovered:
		box.position.y -= Style.HOVER_LIFT
	var face := Style.FRAME
	if _hovered and not _held:
		face = Color(face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b)
	elif _held:
		face = face.darkened(0.15)
	var on := box
	var behind := Style.BOARD_ROW if accent else Style.BOARD
	if Style.border_fits(box):
		on = Style.border_inset(box)
		draw_rect(on.grow(2.0), behind, true)
		Style.meter_frame(self, box, Style.HOVER_WASH if _hovered and not _held else Color.WHITE)
		if accent and not _held:
			Style.lit_edge(self, on.grow(2.0), behind)
	else:
		Style.plank(self, box, int(global_position.x) * 7 + int(global_position.y) + 3, face, Style.CLIP)
	if not mark.is_empty():
		_draw_mark(on, behind)
		return
	if label.is_empty():
		return
	# Set to the face, and shrunk if the word is longer than the wood leaves room for.
	var height := Style.step(on.size.y * LABEL_SHARE)
	var wide := Style.measure(label, height).x
	if wide > on.size.x - LABEL_PAD:
		height = Style.step(float(height) * (on.size.x - LABEL_PAD) / wide)
	Style.write(
		self, label, height,
		Vector2(0.0, on.position.y + (on.size.y + float(height) * 0.62) * 0.5),
		Style.RIBBON_INK, HORIZONTAL_ALIGNMENT_CENTER, on
	)


## The mark on a button that carries no word. `behind` is the face the button is drawn on,
## because the gear's hub is a **hole**: filled with the oak it read as a disc of wood lying
## on the panel, which is the opposite of what a gear's middle is.
func _draw_mark(face: Rect2, behind: Color) -> void:
	if mark != &"gear":
		return
	var middle := face.position + face.size * 0.5
	var radius := minf(face.size.x, face.size.y) * 0.5 * GEAR_FILL
	var cog := _cog(middle, radius)
	# A black rim under the cog, and the hub punched out of it in the button's own face, so the
	# gear reads as a shape cut through the button rather than a sticker laid on it.
	draw_colored_polygon(_cog(middle, radius + 1.0), Style.HOLE_RIM)
	draw_colored_polygon(cog, Style.RIBBON_INK)
	draw_circle(middle, radius * GEAR_HUB + 1.0, Style.HOLE_RIM)
	draw_circle(middle, radius * GEAR_HUB, behind)


## A cog's outline: `GEAR_TEETH` teeth standing off a rim, each `GEAR_WIDTH` of its pitch
## wide, with square shoulders rather than a scalloped edge — the game's wood is all straight
## cuts and chamfers, and a soft gear beside it would read as borrowed from another game.
func _cog(middle: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var rim := radius * (1.0 - GEAR_TOOTH)
	var pitch := TAU / float(GEAR_TEETH)
	var half := pitch * GEAR_WIDTH * 0.5
	for i in GEAR_TEETH:
		var at := pitch * float(i)
		out.append(middle + Vector2(cos(at - half), sin(at - half)) * rim)
		out.append(middle + Vector2(cos(at - half), sin(at - half)) * radius)
		out.append(middle + Vector2(cos(at + half), sin(at + half)) * radius)
		out.append(middle + Vector2(cos(at + half), sin(at + half)) * rim)
		var gap := at + pitch * 0.5
		out.append(middle + Vector2(cos(gap), sin(gap)) * rim)
	return out
