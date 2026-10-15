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

## How many upgrades can be paid for, worn on a badge the way the HUD's own upgrades button
## wears it, or -1 for no badge.
##
## The shed has the same button on it, so without this, walking indoors was walking away from
## the one number that says whether the board is worth opening. It used to be written across
## the foot as "3 for sale" in place of the button's name (2026-10-15, issue #41: a demo player
## clicked it and could not tell what it had become). The foot says "Upgrades" now, as the
## HUD's does, and the count rides the badge.
var count: int = -1:
	set(value):
		if value == count:
			return
		count = value
		queue_redraw()

## How much it lifts under the cursor. The same feedback the HUD's buttons give, because
## they are the same buttons.
const HOVER_LIFT := Style.HOVER_LIFT

## The size the HUD draws this button at; the container's slot is centred on it.
const SIZES := {&"upgrades": Vector2(120.0, 100.0), &"shed": Vector2(120.0, 100.0)}

signal pressed

## The sprites every button draws from, lent once by the lake (`Lake._lend_button_art`).
## Static: there is one of these on screen at a time today and there may be six tomorrow.
static var sprites := {}

var _hovered: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The button wears the meter's painted border, which is pixel art and wants its own filter.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		_hovered = what == NOTIFICATION_MOUSE_ENTER
		if _hovered:
			Sfx.ui(&"ui_hover")
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if piece != &"shed":
		Sfx.ui(&"ui_click")
	pressed.emit()


func _draw() -> void:
	# The HUD's own size, centred, shrunk only if the slot is smaller: a container that
	# hands one a wide slot should not stretch it into a signboard.
	var wanted: Vector2 = SIZES.get(piece, Vector2(100.0, 100.0))
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
	if count >= 0:
		# HudSkin._draw_available's own two calls: the same button saying the same thing in a
		# different room.
		var face := HudButtons.face_of(box)
		HudButtons.label(self, face, Text.HUD_UPGRADES)
		HudButtons.badge(self, face, str(count), count > 0)
