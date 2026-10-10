class_name Wrap
extends RefCounted
## Where a line of text may break, for every language the game ships.
##
## Latin and Korean break between words, on spaces. Japanese and Chinese write no spaces, so a
## sentence of them used to reach every wrapper in the game as one "word" and run across the
## screen (2026-10-10). Here a break may also fall between any two of their characters, held by
## the line-break rules both languages use (kinsoku): no row starts with a closing mark, a
## small kana or a prolonged sound, and no row ends on an opening bracket. Hangul is left to
## its spaces, which Korean has.
##
## One place decides, and every wrapper asks it: `lines` for plain text, `breaks_before` for
## the letter's marked words (`Letter._tokens`), which the cue cards read too.

## Characters a row may not start with: closing brackets and quotes, sentence marks, small
## kana, iteration marks, the prolonged sound mark, and the Latin marks that close a phrase.
const NO_START := "、。，．・：；？！ー－～…‥」』）】〕〉》｝〟’”〙〗ぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ々〻ゝゞヽヾ!?.,:;)]}%"
## Characters a row may not end on: opening brackets and quotes.
const NO_END := "「『（【〔〈《｛〝‘“〘〖([{"


## Whether `ch` is written without spaces round it: Han, kana, CJK marks and full-width forms.
static func is_cjk(ch: String) -> bool:
	if ch.is_empty():
		return false
	var c := ch.unicode_at(0)
	return (c >= 0x3000 and c <= 0x30FF) or (c >= 0x3400 and c <= 0x4DBF) \
		or (c >= 0x4E00 and c <= 0x9FFF) or (c >= 0xF900 and c <= 0xFAFF) \
		or (c >= 0xFF00 and c <= 0xFFEF) or (c >= 0x31F0 and c <= 0x31FF)


## Whether a row may break between `before` and `ch`, two characters of one space-free run.
## Only beside Japanese or Chinese, and never against the line-break rules.
static func breaks_before(before: String, ch: String) -> bool:
	if before.is_empty() or ch.is_empty():
		return false
	if not (is_cjk(before) or is_cjk(ch)):
		return false
	return not NO_START.contains(ch) and not NO_END.contains(before)


## A line cut into the pieces a row may break between: `{text, glue}`, where `glue` means the
## piece follows the last with no space (inside a Japanese or Chinese run).
static func units(line: String) -> Array:
	var out: Array = []
	for word in line.split(" ", false):
		var piece := ""
		var before := ""
		var glue := false
		for ch in word:
			if not piece.is_empty() and breaks_before(before, ch):
				out.append({"text": piece, "glue": glue})
				piece = ""
				glue = true
			piece += ch
			before = ch
		out.append({"text": piece, "glue": glue})
	return out


## Text broken greedily into rows no wider than `wide`, as `measure(text) -> float` reads
## them; a newline starts a row. A piece too wide for a row alone is left long rather than
## cut, as the credits ask: no string here may be shortened.
static func lines(text: String, measure: Callable, wide: float) -> Array[String]:
	var out: Array[String] = []
	for para in text.split("\n"):
		var row := ""
		for unit: Dictionary in units(para):
			var piece := String(unit["text"])
			var tried := piece if row.is_empty() else row + ("" if bool(unit["glue"]) else " ") + piece
			if not row.is_empty() and float(measure.call(tried)) > wide:
				out.append(row)
				row = piece
			else:
				row = tried
		out.append(row)
	return out
