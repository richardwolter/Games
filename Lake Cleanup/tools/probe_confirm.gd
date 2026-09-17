## Measures the confirm board's two doors against the room a door actually gets.
## Headless: `<godot> --path . --headless --script res://tools/probe_confirm.gd`
extends SceneTree

const Style := preload("res://scripts/style.gd")
const MenuConfirm := preload("res://scripts/menu_confirm.gd")

const WORDS := [
	"Set to default", "Keep current buttons", "Start over", "Keep it",
	"Are you sure?", "Every key and button goes back to its own default.",
	"The saved lake will be thrown away.",
	"Your own keys and buttons will be thrown away.",
	"Every key and button goes back to its default.",
	"Every key and button goes back.",
	"Keep current",
]


func _initialize() -> void:
	var lines: PackedStringArray = []
	for wide: float in [420.0, 480.0, 500.0, 540.0]:
		var face := wide - float(Style.BORDER_WALL) * 2.0
		var room := face - MenuConfirm.BOARD_PAD * 2.0
		var door := (room - MenuConfirm.ROW_GAP) * 0.5
		lines.append("board %.0f: line %.0f, each door %.0f" % [wide, room, door])
	for text: String in WORDS:
		lines.append("%6.0f body  %6.0f small   %s" % [
			Style.measure(text, Style.TEXT_BODY).x,
			Style.measure(text, Style.TEXT_SMALL).x,
			text,
		])
	var file := FileAccess.open("res://tools/last_confirm.log", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	quit()
