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

const ART := "res://assets/ui.json"

## Which piece of the sheet this button is, set in the scene.
@export var piece: StringName = &"upgrades"

## How much it lifts and brightens under the cursor. The same feedback the HUD's buttons
## give, because they are the same buttons.
const HOVER_LIFT := 2.0
const HOVER_WASH := Color(1.12, 1.12, 1.12)

signal pressed

static var _sheet: Texture2D
static var _pieces := {}
static var _looked: bool = false

var _hovered: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_art()
	queue_redraw()


## Read the sheet, once for every button that will ever exist.
static func _load_art() -> void:
	if _looked:
		return
	_looked = true
	var text := FileAccess.get_file_as_string(ART)
	if text.is_empty():
		return
	var book: Dictionary = JSON.parse_string(text)
	if book == null or not book.has("pieces"):
		return
	_sheet = Art.texture(book["sheet"])
	if _sheet == null:
		return
	for name: String in book["pieces"]:
		var box: Array = (book["pieces"][name] as Dictionary)["region"]
		_pieces[StringName(name)] = Rect2(box[0], box[1], box[2], box[3])


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
	if _sheet == null or not _pieces.has(piece):
		return
	var art: Rect2 = _pieces[piece]
	# Square, centred, and as tall as the box allows: these are square plaques and a
	# container that hands one a wide slot should not stretch it into a signboard.
	var side := minf(size.x, size.y)
	var at := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
	if _hovered:
		at.y -= HOVER_LIFT
	draw_texture_rect_region(
		_sheet, Rect2(at, Vector2(side, side)), art,
		HOVER_WASH if _hovered else Color.WHITE
	)
