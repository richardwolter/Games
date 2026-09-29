extends Control
## One board: the screen veiled in paper, a paper panel in the middle with a
## headed title, and a body the caller fills. Everything in the menus is a board.
## `close()` emits `closed` and frees it; the menu stack decides what is under it.

signal closed

const Ink = preload("res://scripts/ink.gd")

## How much of the game the veil lets through. First guess.
const VEIL := Color(0.97, 0.95, 0.9, 0.55)

var body: VBoxContainer
var panel: PanelContainer
var title_label: Label
## Set by the menu: opens another board over this one.
var push_board: Callable


func _init(title: String = "", wide: float = 420.0) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Ink.theme()
	var veil := ColorRect.new()
	veil.color = VEIL
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(wide, 0)
	center.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	if title != "":
		var head := Ink.heading(title)
		title_label = head.get_child(0)
		body.add_child(head)


## Whether this board wants Escape for itself (a capture in progress).
func holds_escape() -> bool:
	return false


func close() -> void:
	closed.emit()
	queue_free()
