## Measures the upgrades shop's row text against the room a row actually leaves it.
##
## The shop drops a name to a smaller size and then cuts it with an ellipsis
## (`ShopSkin._draw_row`), and does the same to a value. None of that is visible in the
## source: whether a row reads whole depends on the width of Bungee's glyphs at the ladder's
## sizes, which is a measurement, not an opinion. This is the measurement.
##
## Four-up was chosen knowing some rows cut at the dear end of a run (Richard, 2026-09-17).
## This says which, so that is a known list rather than a surprise.
##
## Headless: `<godot> --path . --headless --script res://tools/probe_shop_text.gd`
## Writes `tools/last_shop_text.log`. Reads nothing, writes nothing else.
extends SceneTree

const Style := preload("res://scripts/style.gd")
const ShopSkin := preload("res://scripts/shop_skin.gd")

const OUT := "res://tools/last_shop_text.log"

## The design frame at three window shapes. `canvas_items` + `expand` keeps the shorter
## axis at the base and grows the longer, so height is never under 720 and width never
## under 1280 — but a 21:9 monitor hands the shop 1706 design pixels of width.
const FRAMES := [
	["16:9  1920x1080", Vector2(1280.0, 720.0)],
	["16:10 1920x1200", Vector2(1280.0, 800.0)],
	["21:9  2560x1080", Vector2(1706.0, 720.0)],
]

## Every live row: board, name, the value at level 0, **mid-run**, at the top of its track,
## and the dearest price that track ever asks. Lifted from `Lake._shop_rows` and the `.tres`
## curves rather than run off a live lake, so this needs no scene.
##
## Mid-run is here because it is the worst case and neither end is: a rate track reads
## `+0% → +35%` at the start and `+700%` at the top, but `+385% → +420%` in the middle,
## which is longer than both. Measuring only the two ends said two rows cut; the real answer
## is what this reports.
const ROWS := [
	["net", "Width", "100 → 135%", "485 → 520%", "800%", "$6820"],
	["net", "Strength", "Tier 0 → 1", "Tier 2 → 3", "Tier 4", "$4100"],
	["net", "Range", "100 → 140%", "500 → 540%", "900%", "$5760"],
	["net", "Reel", "100 → 133%", "400 → 433%", "767%", "$3310"],
	["net", "Catch", "4 → 5", "17 → 18", "24", "$420000"],
	["boat", "Sailing", "100 → 140%", "700 → 740%", "900%", "$7300"],
	["boat", "Hold", "4 → 5", "19 → 20", "24", "$420000"],
	["boat", "Loading", "100 → 118%", "143 → 182%", "250%", "$3194"],
	["boat", "Fleet", "1 → 2", "2 → 3", "4", "$5000"],
	["dog", "Pack", "1 → 2", "2 → 3", "4", "$8112"],
	["dog", "Carry", "Tier 0 → 1", "Tier 2 → 3", "Tier 4", "$5271"],
	["dog", "Fetch", "1 → 2", "3 → 4", "5", "$2400"],
	["dog", "Keenness", "12 → 9s", "8 → 6s", "4s", "$1800"],
	["luck", "Lucky cast", "0 → 6%", "22 → 26%", "60%", "$21400"],
	["luck", "Double cast", "0 → 5%", "17 → 21%", "50%", "$18600"],
	["luck", "Bonus yard", "0 → 15%", "100 → 115%", "120%", "$9300"],
	["luck", "Pigeons", "$8 → 10", "$26 → 30", "$34", "$7700"],
]


func _initialize() -> void:
	var lines: PackedStringArray = []
	lines.append("Shop row text, measured in Bungee at the ladder's sizes.")
	lines.append("body=%d small=%d tiny=%d" % [Style.TEXT_BODY, Style.TEXT_SMALL, Style.TEXT_TINY])
	for frame: Array in FRAMES:
		var size: Vector2 = frame[1]
		lines.append("")
		lines.append("=== %s  design frame %dx%d ===" % [frame[0], int(size.x), int(size.y)])
		lines.append_array(_report(size))
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	quit()


## The room a row leaves its writing, and what happens to each row's text in it.
func _report(frame: Vector2) -> PackedStringArray:
	var out: PackedStringArray = []
	var boards := ShopSkin.BOARDS.size()
	var wide := minf(ShopSkin.BOARDS_WIDE, frame.x - 40.0)
	var each := (wide - ShopSkin.BOARD_GAP * float(boards - 1)) / float(boards)
	var box := Rect2(Vector2.ZERO, Vector2(floorf(each), 400.0))
	var face := Style.board_face(box, ShopSkin.FRAME)
	var row_wide := face.size.x - ShopSkin.BOARD_PAD * 2.0
	var text_at := ShopSkin.RAIL_WIDE + ShopSkin.RAIL_GAP
	var tag_wide := row_wide * ShopSkin.TAG_SHARE
	out.append("board %.0f wide, face %.0f, row %.0f, text starts at %.0f, tag slot %.0f"
		% [each, face.size.x, row_wide, text_at, tag_wide])
	out.append("")
	for entry: Array in ROWS:
		var cost: String = entry[5]
		var room := _room(row_wide, tag_wide, text_at, cost)
		out.append("%-7s %-13s room %.0fpx  price %s" % [entry[0], entry[1], room, cost])
		out.append("    name  %s" % _verdict(String(entry[1]), room, Style.TEXT_BODY, Style.TEXT_SMALL))
		out.append("    now   %s" % _verdict(String(entry[2]), room, Style.TEXT_SMALL, Style.TEXT_TINY))
		out.append("    mid   %s" % _verdict(String(entry[3]), room, Style.TEXT_SMALL, Style.TEXT_TINY))
		out.append("    maxed %s" % _verdict(String(entry[4]), room, Style.TEXT_SMALL, Style.TEXT_TINY))
	return out


## How much width a row's two lines of writing get, after the price tag has taken its end.
## The same sum `ShopSkin._tag_of` makes.
func _room(row_wide: float, tag_wide: float, text_at: float, cost: String) -> float:
	if cost.is_empty():
		return row_wide - 8.0 - text_at
	var slot_x := row_wide - tag_wide - 6.0
	var want := Style.measure(cost, Style.TEXT_BODY).x + float(Style.TEXT_BODY) * 1.2
	var taken := minf(want, tag_wide)
	return slot_x + (tag_wide - taken) - 8.0 - text_at


## What the row does to a line that will not fit: drop it a rung, then cut it.
func _verdict(text: String, room: float, first: int, second: int) -> String:
	var size := first
	var note := "whole at %d" % size
	if Style.measure(text, size).x > room:
		size = second
		note = "shrunk to %d" % size
	if Style.measure(text, size).x > room:
		note = "CUT at %d" % size
	return "%s  [%.0fpx at %d]" % [note, Style.measure(text, first).x, first]
