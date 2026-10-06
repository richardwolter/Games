## Which separator glyphs Bungee actually has, and what the proposed row strings measure.
## Headless: `<godot> --path . --headless --script res://tools/probe_shop_glyphs.gd`
extends SceneTree

const Style := preload("res://scripts/style.gd")

const MARKS := {
	"arrow U+2192": 0x2192, "arrow bar U+21E2": 0x21E2, "greater >": 0x3E,
	"bullet U+2022": 0x2022, "middot U+00B7": 0xB7, "en dash U+2013": 0x2013,
	"em dash U+2014": 0x2014, "triangle U+25B8": 0x25B8, "chevron U+203A": 0x203A,
	"plus +": 0x2B, "slash /": 0x2F,
}

const PROPOSED := [
	["Width", "+0% > +35%"], ["Strength", "Tier 0 > 1"], ["Range", "+0% > +40%"],
	["Reel", "+0% > +33%"], ["Catch", "4 > 5 a cast"],
	["Lucky cast", "0% > 6%"], ["Double cast", "0% > 5%"],
	["Sailing", "+0% > +40%"], ["Hold", "4 > 5 aboard"],
	["Loading", "+0% > +18%"], ["Fleet", "1 > 2 ferries"],
	["Fetch", "1 > 2 a trip"], ["Keenness", "12s > 9s"],
	["Carry", "Tier 0 > 1"], ["Pack", "1 > 2 dogs"],
	["Bonus yard", "off > +15%"], ["Pigeons", "$8 > $10 a bird"],
]


func _initialize() -> void:
	var out: PackedStringArray = ["Bungee glyph coverage:"]
	var font := Style.font()
	for name: String in MARKS:
		out.append("  %-16s %s" % [name, "yes" if font.has_char(int(MARKS[name])) else "NO"])
	out.append("")
	out.append("Proposed strings, against the 108px a row leaves its writing:")
	for line: Array in PROPOSED:
		var name: String = line[0]
		var value: String = line[1]
		var nw := Style.measure(name, Style.TEXT_BODY).x
		var vw := Style.measure(value, Style.TEXT_SMALL).x
		out.append("  %-12s name %3.0fpx@16   value %3.0fpx@13  %s"
			% [name, nw, vw, "" if vw <= 108.0 else "<-- still over"])
	var file := FileAccess.open("res://tools/last_shop_glyphs.log", FileAccess.WRITE)
	file.store_string("\n".join(out) + "\n")
	file.close()
	quit()
