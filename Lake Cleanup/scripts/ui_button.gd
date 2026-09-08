## One drawn button off the UI sheet, wherever a panel wants one.
##
## The HUD draws its own three because it lays them out itself; this is for the ones that sit
## inside an ordinary panel and want the container to place them — the way into the upgrades
## from the shed being the first. Same sheet, same pieces, so a button is the same button
## wherever it turns up rather than a picture in one place and a grey rectangle in another.
##
## The sheet is loaded once and shared. There is one of these on screen at a time today and
## there may be six tomorrow, and six copies of the same atlas is a silly way to find out.
class_name UiButton
extends Control

const Style := preload("res://scripts/style.gd")

## The books of cut pieces, later ones winning. Same list, and same reason, as HudSkin's.
const ART := ["res://assets/ui.json", "res://assets/buttons.json"]

## Which piece of the sheet this button is, set in the scene.
@export var piece: StringName = &"upgrades"

## A line written across the foot of the plaque, or empty for none.
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

## Where the note sits inside the plaque and how big it is lettered, as fractions of the
## plaque. HudSkin's own numbers — the two buttons are the same picture and the writing on
## them has to land in the same place.
const NOTE_PLATE := Rect2(0.09, 0.715, 0.82, 0.16)
const NOTE_TEXT := 0.8
const NOTE_LEAST := 8

## How much it lifts and brightens under the cursor. The same feedback the HUD's buttons
## give, because they are the same buttons.
const HOVER_LIFT := Style.HOVER_LIFT
const HOVER_WASH := Style.HOVER_WASH

signal pressed

## Every piece by name, each as `{region, sheet}` — a piece carries the texture it was cut
## from, so a plaque repainted onto a sheet of its own draws beside the older ones.
static var _pieces := {}
static var _looked: bool = false

var _hovered: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_art()
	queue_redraw()


## Read the sheets, once for every button that will ever exist.
static func _load_art() -> void:
	if _looked:
		return
	_looked = true
	for path: String in ART:
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			continue
		var book: Dictionary = JSON.parse_string(text)
		if book == null or not book.has("pieces"):
			continue
		var sheet := Art.texture(book["sheet"])
		if sheet == null:
			continue
		for name: String in book["pieces"]:
			var box: Array = (book["pieces"][name] as Dictionary)["region"]
			_pieces[StringName(name)] = {
				"region": Rect2(box[0], box[1], box[2], box[3]), "sheet": sheet
			}


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
	if not _pieces.has(piece):
		return
	var art: Rect2 = (_pieces[piece] as Dictionary)["region"]
	# Square, centred, and as tall as the box allows: these are square plaques and a
	# container that hands one a wide slot should not stretch it into a signboard.
	var side := minf(size.x, size.y)
	var at := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
	if _hovered:
		at.y -= HOVER_LIFT
	var box := Rect2(at, Vector2(side, side))
	draw_texture_rect_region(
		(_pieces[piece] as Dictionary)["sheet"], box, art,
		HOVER_WASH if _hovered else Color.WHITE
	)
	if not note.is_empty():
		_draw_note(box)


## The note, on a sunken panel across the foot of the plaque.
##
## Drawn the way HudSkin draws its own, down to the panel and the lettering, because it is the
## same button saying the same thing in a different room. Set to the panel's height and then
## shrunk to its width — the plaque is small and the game's ladder of text sizes starts wider
## than this panel.
func _draw_note(box: Rect2) -> void:
	var plate := Rect2(
		box.position + NOTE_PLATE.position * box.size, NOTE_PLATE.size * box.size
	)
	Style.plaque(self, plate, Style.WOOD_DEEP)
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
