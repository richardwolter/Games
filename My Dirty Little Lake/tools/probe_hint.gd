## Measures the bind board's hint against the room the column band leaves it.
## Headless: `<godot> --path . --headless --script res://tools/probe_hint.gd`
extends SceneTree

const Style := preload("res://scripts/style.gd")
const ControlsSkin := preload("res://scripts/controls_skin.gd")

const TRIES := [
	"Click a cell and press it · right-click puts one back",
	"Click a cell and press · right-click resets it",
	"Click a cell, then press · right-click resets",
	"Click, then press · right-click resets",
	"Click to change · right-click resets",
	"Click a cell to change it",
	"Right-click puts one back",
]


func _initialize() -> void:
	var face_wide := ControlsSkin.BOARD_WIDE - float(Style.BORDER_WALL) * 2.0
	var wide := face_wide - ControlsSkin.BOARD_PAD * 2.0
	var room := (
		wide - ControlsSkin.ROW_INSET - ControlsSkin.PAD_WIDE - ControlsSkin.CELL_GAP
		- ControlsSkin.KEY_WIDE - ControlsSkin.CELL_GAP
	)
	var lines: PackedStringArray = ["room %.0f px, full band %.0f px" % [room, wide]]
	var font := Style.font()
	for pair: Array in [["middle dot", 0xB7], ["bullet", 0x2022], ["en dash", 0x2013]]:
		lines.append("%s U+%04X: %s" % [pair[0], pair[1], font.has_char(int(pair[1]))])
	for text: String in TRIES:
		lines.append("%6.0f  %6.0f   %s" % [
			Style.measure(text, Style.TEXT_TINY).x,
			Style.measure(text, Style.TEXT_SMALL).x,
			text,
		])
	var file := FileAccess.open("res://tools/last_hint.log", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	quit()
