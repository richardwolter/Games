extends SceneTree
## Does every string fit its box, in every language? (Issue #28.) Headless:
##   <exe> --path . --headless --script res://tools/probe_text_fit.gd
##
## Reads `locale/translations.csv` — the keys, the budget columns (`_size`, `_least`,
## `_width`) and every locale column — and measures each cell in **that locale's own face**
## through `Style.set_locale` / `Style.font()`, so Japanese is measured in M PLUS Rounded 1c
## and not in a Bungee that cannot draw it. A cell is tried at `_size` and then down the
## size ladder to `_least`, which is what the boards themselves do before they cut:
##   fits      at `_size`
##   shrinks   only at a smaller rung, still at or above `_least`
##   OVER      not even at `_least` — the board has to widen, or the words have to change
## A `_width` of 0 is a line that wraps; it is only checked for its placeholders.
##
## And the placeholders: every `%d` / `%s` in `en` must appear the same number of times in a
## translation, or the game's `%` operator throws at the call site.
##
## Writes `tools/last_text_fit.log` (by locale, worst first) and exits 1 if anything is OVER
## or a placeholder is wrong, so it can gate a commit. **English is expected to fit
## everywhere** — an English OVER means the budget is wrong, not the word.

const Style := preload("res://scripts/style.gd")

const CSV_PATH := "res://locale/translations.csv"
const LOG_PATH := "res://tools/last_text_fit.log"
const LADDER: Array[int] = [26, 20, 16, 13, 11]
const PSEUDO := "qps"


func _init() -> void:
	var lines := PackedStringArray()
	var rows := _read_csv(CSV_PATH)
	if rows.size() < 2:
		lines.append("no rows in %s" % CSV_PATH)
		_finish(lines, 1)
		return
	var head: PackedStringArray = rows[0]
	var col := {}
	for i in head.size():
		col[head[i]] = i
	var locales: Array[String] = []
	for name in head:
		if name != "keys" and not name.begins_with("_"):
			locales.append(name)
	var bad := 0
	for locale in locales:
		Style.set_locale(locale)
		var face := Style.font()
		var fits := 0
		var shrinks: Array[String] = []
		var over: Array[String] = []
		var marks: Array[String] = []
		var empty := 0
		for r in range(1, rows.size()):
			var row: PackedStringArray = rows[r]
			var key := row[col["keys"]]
			var text := _cell(row, col, locale)
			if text.is_empty():
				empty += 1
				continue
			var en := _cell(row, col, "en")
			if not _same_marks(en, text):
				marks.append("  %s  '%s'  (en: '%s')" % [key, text, en])
			var width := float(_cell(row, col, "_width"))
			if width <= 0.0:
				fits += 1
				continue
			var size := int(_cell(row, col, "_size"))
			var least := int(_cell(row, col, "_least"))
			var took := face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
			if took <= width:
				fits += 1
				continue
			# The boards snap to the ladder; a size that is not a rung (the pier sign's 18)
			# belongs to something that steps down a pixel at a time instead.
			var tries: Array[int] = []
			if size in LADDER:
				tries = LADDER
			else:
				for px in range(size - 1, least - 1, -1):
					tries.append(px)
			var landed := 0
			for rung in tries:
				if rung >= size or rung < least:
					continue
				if face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, rung).x <= width:
					landed = rung
					break
			if landed > 0:
				shrinks.append("  %-24s %4.0f px at %d > %3.0f, fits at %d  '%s'" % [
					key, took, size, width, landed, text])
			else:
				var at_least := face.get_string_size(
					text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, least).x
				over.append("  %-24s %4.0f px at %d against %3.0f (+%.0f)  '%s'" % [
					key, at_least, least, width, at_least - width, text])
		# The pseudo-locale is built to overflow; it is read, not gated. Its placeholders
		# still count, because a pseudo string that breaks `%` breaks the game in `qps`.
		bad += marks.size() + (0 if locale == PSEUDO else over.size())
		lines.append("== %s  (%s)   fits %d  shrinks %d  OVER %d  bad marks %d  empty %d" % [
			locale, face.get_font_name(), fits, shrinks.size(), over.size(), marks.size(), empty])
		if not over.is_empty():
			lines.append(" OVER — the board must widen, or the words must change:")
			lines.append_array(over)
		if not marks.is_empty():
			lines.append(" placeholders differ from English:")
			lines.append_array(marks)
		if not shrinks.is_empty():
			lines.append(" shrinks to fit:")
			lines.append_array(shrinks)
	Style.set_locale("en")
	_finish(lines, 1 if bad > 0 else 0)


func _cell(row: PackedStringArray, col: Dictionary, name: String) -> String:
	var i: int = col.get(name, -1)
	return row[i] if i >= 0 and i < row.size() else ""


## Every `%d` and `%s`, counted. Order is not checked: `%` fills them left to right, so a
## language that needs them the other way round has to say so in the call site, and none
## does yet.
func _same_marks(a: String, b: String) -> bool:
	for mark in ["%d", "%s"]:
		if a.count(mark) != b.count(mark):
			return false
	return true


func _read_csv(path: String) -> Array:
	var out: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		out.append(row)
	return out


func _finish(lines: PackedStringArray, code: int) -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		for line in lines:
			file.store_line(line)
		file.close()
	quit(code)
