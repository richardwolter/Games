extends Node
## Does every text that wraps wrap properly, in every language? Headless:
##   <exe> --path . --headless res://tools/probe_wrap.tscn --log-file <path>
## A scene, not a `--script`: the letter and the cue cards reach the `Pad` autoload, which a
## bare SceneTree script does not load.
##
## `probe_text_fit` checks the one-line strings against their boxes and skips a `_width` of 0.
## This takes those: every string a board breaks into rows, laid out by **the game's own
## wrapper for it** (`Letter._wrap_marked`, `CueCard.lay_out`, `Wrap.lines`) in **that
## locale's face** (`Style.set_locale`), at the width and size ladder it is drawn at. Reported:
##   WIDE      a row wider than its box: a word or run too long to break
##   LONG      more rows than the board holds even at its smallest size
##   KINSOKU   a row starting with a closing mark or ending on an opening one
##   SPACES    a double space, a space at an end, or a space between two CJK characters
##   PARA      a different number of paragraphs (newlines) from English
## Plus each locale's line height against Bungee's, the gap a CJK face opens between rows.
##
## Writes `tools/last_wrap.log`; exits 1 on anything but SPACES-in-CJK notes. The widths are
## the boards' own constants at a 1280x720 window, written here once: re-read them if a
## board is resized (letter text 678, letter blurb 214, shop blurb 250, tour/note 184, cue
## hint 236, moment 760, farewell 1100, credits 430).

const Style := preload("res://scripts/style.gd")

const CSV_PATH := "res://locale/translations.csv"
const LOG_PATH := "res://tools/last_wrap.log"

## Key prefix (longest wins) -> [wrapper, wide, sizes, most rows (0: no limit)].
const SPECS := {
	"LETTER_WELCOME_LEAD": ["letter", 678.0, [16, 13, 11], 2.0],
	"LETTER_WELCOME_TEXT": ["letter", 678.0, [16, 13, 11], 4.0],
	"LETTER_NET_TEXT": ["letter", 678.0, [16, 13, 11], 4.0],
	"LETTER_WEIGHT_TEXT": ["letter", 678.0, [16, 13, 11], 3.0],
	"LETTER_DECOR_LINE": ["letter", 678.0, [16, 13, 11], 3.0],
	"LETTER_UPGRADES_": ["letter", 214.0, [13, 11], 3.0],
	"BLURB_": ["lines", 250.0, [13], 0.0],
	"SHOP_LEGEND": ["lines", 400.0, [13], 0.0],
	"SHOP_BONUS_LINE": ["lines", 400.0, [13], 0.0],
	"TOUR_": ["lines", 184.0, [10], 0.0],
	"STEPS_NOTE": ["lines", 184.0, [10], 0.0],
	"CAMERA_TIP": ["lines", 184.0, [10], 0.0],
	"CUE_": ["cue", 236.0, [13], 0.0],
	"TORNADO_FIRST": ["cue", 760.0, [20, 16], 2.0],
	"WILDLIFE_BACK": ["cue", 760.0, [20, 16], 2.0],
	"HIVE_SWARM": ["cue", 760.0, [20, 16], 2.0],
	"HIVE_READY": ["cue", 760.0, [20, 16], 2.0],
	"END_LINE": ["lines", 1100.0, [26, 20], 1.0],
	"DEMO_LINE": ["lines", 1100.0, [26, 20], 1.0],
	"CREDITS_": ["lines", 430.0, [16, 13], 0.0],
}


func _ready() -> void:
	var lines := PackedStringArray()
	var rows := _read_csv(CSV_PATH)
	var head: PackedStringArray = rows[0]
	var col := {}
	for i in head.size():
		col[head[i]] = i
	var locales: Array[String] = []
	for name in head:
		if name != "keys" and not name.begins_with("_"):
			locales.append(name)
	Style.set_locale("en")
	var bungee := Style.font().get_height(16)
	var bad := 0
	for locale in locales:
		Style.set_locale(locale)
		var found := PackedStringArray()
		var notes := PackedStringArray()
		var checked := 0
		for r in range(1, rows.size()):
			var row: PackedStringArray = rows[r]
			var key := row[col["keys"]]
			var spec: Array = _spec_of(key)
			if spec.is_empty():
				continue
			var text := row[col[locale]] if col[locale] < row.size() else ""
			if text.is_empty():
				continue
			checked += 1
			var en := row[col["en"]]
			for problem in _spaces(text):
				(notes if problem.begins_with("CJK") else found).append("  SPACES   %s  %s" % [key, problem])
			if text.count("\n") != en.count("\n"):
				found.append("  PARA     %s  %d paragraphs, English %d" % [key, text.count("\n") + 1, en.count("\n") + 1])
			var laid := _lay(spec, text)
			var px: int = laid["px"]
			var out: Array = laid["rows"]
			if float(spec[3]) > 0.0 and float(laid["tall"]) > float(spec[3]):
				found.append("  LONG     %s  %s rows at %dpx, %s at most" % [key, str(laid["tall"]), px, str(spec[3])])
			for line: String in out:
				var w := Style.measure(line.replace("*", ""), px).x
				if w > float(spec[1]) + 0.5:
					found.append("  WIDE     %s  %d/%d at %dpx: '%s'" % [key, int(w), int(spec[1]), px, line])
				if line.length() > 0 and Wrap.NO_START.contains(line[0]) and line != out[0] \
						and not line.begins_with("%s") and not line.begins_with("%d"):
					found.append("  KINSOKU  %s  row starts '%s': '%s'" % [key, line[0], line])
				if line.length() > 1 and Wrap.NO_END.contains(line[line.length() - 1]):
					found.append("  KINSOKU  %s  row ends '%s': '%s'" % [key, line[line.length() - 1], line])
		bad += found.size()
		lines.append("%s  %d wrapped strings, line height %.1f (Bungee %.1f)  %d problems" % [
			locale, checked, Style.font().get_height(16), bungee, found.size()])
		lines.append_array(found)
		lines.append_array(notes)
		lines.append("")
	Style.set_locale("en")
	_finish(lines, 1 if bad > 0 else 0)


func _spec_of(key: String) -> Array:
	var best := ""
	for prefix: String in SPECS:
		if key.begins_with(prefix) and prefix.length() > best.length():
			best = prefix
	return [] if best.is_empty() else SPECS[best]


## Laid out by the wrapper the board uses, down its ladder until it fits its rows.
func _lay(spec: Array, text: String) -> Dictionary:
	var sizes: Array = spec[2]
	var most: float = spec[3]
	var res := {}
	for px: int in sizes:
		var out: Array = []
		var tall := 0.0
		match String(spec[0]):
			"letter":
				for row: Dictionary in Letter._wrap_marked(Letter._tokens(text), px, float(spec[1])):
					out.append(Letter._row_plain(row))
					tall += 1.0 + (Letter.PARA_GAP if bool(row["para"]) else 0.0)
			"cue":
				for row: Array in CueCard.lay_out(text, px, float(spec[1])):
					out.append(CueCard.plain([row]))
				tall = float(out.size())
			_:
				out.assign(Wrap.lines(text, func(s: String) -> float: return Style.measure(s, px).x, float(spec[1])))
				tall = float(out.size())
		res = {"rows": out, "px": px, "tall": tall}
		if most <= 0.0 or tall <= most:
			break
	return res


func _spaces(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	if text.contains("  ") and not text.contains("  %d"):
		out.append("double space")
	for para in text.split("\n"):
		if para != para.strip_edges():
			out.append("space at an end of '%s'" % para)
	for mark in [" !", " ?", " :", " ;"]:
		if text.contains(mark):
			out.append("an ordinary space before '%s' (French takes U+00A0 there, or the mark can start a row)" % mark.strip_edges())
			break
	for i in range(1, text.length() - 1):
		if text[i] == " " and Wrap.is_cjk(text[i - 1]) and Wrap.is_cjk(text[i + 1]):
			out.append("CJK space at %d: '%s'" % [i, text.substr(maxi(0, i - 6), 13)])
			break
	return out


func _read_csv(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	var out: Array = []
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() > 1:
			out.append(row)
	f.close()
	return out


func _finish(lines: PackedStringArray, code: int) -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	get_tree().quit(code)
