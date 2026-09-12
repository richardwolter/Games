## One drawn button, wherever a panel wants one.
##
## The HUD draws its own three because it lays them out itself; this is for the ones that sit
## inside an ordinary panel and want the container to place them — the way into the upgrades
## from the shed being the first. Same drawing (`hud_buttons.gd`), same sprites, so a button
## is the same button wherever it turns up rather than a picture in one place and a grey
## rectangle in another. It was a piece off the painted UI sheet until 2026-09-11.
class_name UiButton
extends Control

const Style := preload("res://scripts/style.gd")
const HudButtons := preload("res://scripts/hud_buttons.gd")

## Which button this is, set in the scene: `upgrades` or `shed`.
@export var piece: StringName = &"upgrades"

## A line written across the foot of the button, or empty for none.
##
## The HUD writes how many upgrades can be paid for on its own upgrades button, and the shed
## has the same button on it — so without this, walking indoors was walking away from the one
## number that says whether the board is worth opening.
var note: String = "":
	set(value):
		if value == note:
			return
		note = value
		queue_redraw()

## How tall the note's panel is and how big it is lettered against that. HudSkin's own
## numbers — the two buttons are the same picture and the writing on them has to land in
## the same place.
const NOTE_TALL := 14.0
const NOTE_TEXT := 0.8
const NOTE_LEAST := 8

## How much it lifts under the cursor. The same feedback the HUD's buttons give, because
## they are the same buttons.
const HOVER_LIFT := Style.HOVER_LIFT

## The size the HUD draws this button at; the container's slot is centred on it.
const SIZES := {&"upgrades": Vector2(132.0, 84.0), &"shed": Vector2(104.0, 84.0)}

signal pressed

## The sprites every button draws from, lent once by the lake (`Lake._lend_button_art`).
## Static: there is one of these on screen at a time today and there may be six tomorrow.
static var sprites := {}

var _hovered: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		_hovered = what == NOTIFICATION_MOUSE_ENTER
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	pressed.emit()


func _draw() -> void:
	# The HUD's own size, centred, shrunk only if the slot is smaller: a container that
	# hands one a wide slot should not stretch it into a signboard.
	var wanted: Vector2 = SIZES.get(piece, Vector2(84.0, 84.0))
	var scale := minf(1.0, minf(size.x / wanted.x, size.y / wanted.y))
	var side := (wanted * scale).floor()
	var at := ((size - side) * 0.5).floor()
	if _hovered:
		at.y -= HOVER_LIFT
	var box := Rect2(at, side)
	match piece:
		&"shed":
			HudButtons.draw_shed(self, box, _hovered, sprites)
		_:
			HudButtons.draw_upgrades(self, box, _hovered, sprites)
	if not note.is_empty():
		_draw_note(box.grow(-HudButtons.FRAME))


## The note, on a sunken panel across the foot of the button.
##
## Drawn the way HudSkin draws its own, down to the panel and the lettering, because it is the
## same button saying the same thing in a different room. Set to the panel's height and then
## shrunk to its width — the button is small and the game's ladder of text sizes starts wider
## than this panel.
func _draw_note(face: Rect2) -> void:
	var plate := Rect2(
		Vector2(face.position.x + 4.0, face.end.y - NOTE_TALL - 3.0),
		Vector2(face.size.x - 8.0, NOTE_TALL)
	)
	Style.plate(self, plate, Style.BOARD.darkened(0.35), 2.0)
	var height := maxi(NOTE_LEAST, int(plate.size.y * NOTE_TEXT))
	var wide := Style.measure(note, height).x
	if wide > plate.size.x:
		height = maxi(NOTE_LEAST, int(float(height) * plate.size.x / wide))
	Style.write(
		self,
		note,
		height,
		Vector2(0.0, plate.position.y + plate.size.y * 0.5 + float(height) * 0.35),
		Style.INK,
		HORIZONTAL_ALIGNMENT_CENTER,
		plate
	)
