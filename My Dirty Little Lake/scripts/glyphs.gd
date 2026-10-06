## The pad's buttons as pictures: which family of glyphs is shown, and how a glyph rides
## inside a line of text.
##
## Issue #33, decided with `/grill-me` (2026-10-06). **Every pad button on screen is a glyph,
## never a word** — the bind board's cells, the tour cards, the key chips, the hints. The
## tiles are Kenney's Input Prompts Pixel, cut by `tools/build_prompts.py`.
##
## **Two families, Xbox and PlayStation.** Which one is shown is the pad's own say
## (`detected`, set by `Pad` off the vendor the last pad pressed reports: Sony is PlayStation,
## anything else Xbox) unless the player picked one on the Controls board (`choice`, saved by
## `Prefs` as `pad_prompts`). The override exists for the third-party pads that report
## themselves as something they are not, and for a DualSense under Steam Input, which reaches
## the game as a virtual Xbox pad.
##
## **A glyph in a sentence is a token**: `token()` wraps a written binding in two
## private-use characters, and `Style.write` / `Style.measure` draw and measure it as the
## picture. So a caller that fills a `%s` with `Binds.shown(action, true)` gets the glyph with
## nothing else changed. Bungee carries neither character, so a token that reaches a plain
## `draw_string` shows as tofu — loudly wrong, which is the point.
class_name Glyphs
extends RefCounted

enum Family { XBOX, PLAYSTATION }

## What the Controls board's chooser can be set to. `AUTO` follows the pad.
enum Choice { AUTO, XBOX, PLAYSTATION }

const DIR := "res://assets/ui/prompts/%s.png"
const OPEN := ""
const SHUT := ""

## Sony's USB vendor id, and the words a pad's name carries when the id is not reported.
const SONY := 0x054C
const SONY_NAMES := ["playstation", "dualsense", "dualshock", "ps5", "ps4", "ps3", "sony"]

## Written binding to tile, per family; `SHARED` is the same picture on both pads.
const XBOX := {
	"pad:0": "xb_a", "pad:1": "xb_b", "pad:2": "xb_x", "pad:3": "xb_y",
	"pad:4": "xb_view", "pad:6": "xb_menu", "pad:9": "xb_lb", "pad:10": "xb_rb",
	"pad:15": "xb_share", "axis:4:1": "xb_lt", "axis:5:1": "xb_rt",
}
const PLAYSTATION := {
	"pad:0": "ps_cross", "pad:1": "ps_circle", "pad:2": "ps_square", "pad:3": "ps_triangle",
	"pad:4": "ps_create", "pad:6": "ps_options", "pad:9": "ps_l1", "pad:10": "ps_r1",
	"pad:20": "ps_touchpad", "axis:4:1": "ps_l2", "axis:5:1": "ps_r2",
}
const SHARED := {
	"pad:7": "ls", "pad:8": "rs",
	"pad:11": "dpad_up", "pad:12": "dpad_down", "pad:13": "dpad_left", "pad:14": "dpad_right",
	"stick": "stick",
}

## The words a binding falls back to where no glyph is drawn: a button the pack has no tile
## for, or a place that can only take text. Xbox's in `Binds.PAD_NAMES`.
const PS_NAMES := {
	0: "Cross", 1: "Circle", 2: "Square", 3: "Triangle",
	4: "Create", 5: "PS", 6: "Options",
	7: "L3", 8: "R3", 9: "L1", 10: "R1",
	11: "D-Pad Up", 12: "D-Pad Down", 13: "D-Pad Left", 14: "D-Pad Right", 20: "Touchpad",
}
const PS_AXIS_NAMES := {"4:1": "L2", "5:1": "R2"}

## The glyph against the line of text it sits in: about this much taller than the type, in
## whole screen pixels to a pixel of the pack's, so it is never smeared between two.
const INLINE_GROW := 1.25
## How many screen pixels a pixel of the pack's is when a glyph stands on its own (a prompt
## over the angler's head, a card's foot). `FirstSteps.PROMPT_PX` is the same number.
const PROMPT_PX := 2.0

## What the pad last pressed says it is, and what the player picked over it.
static var detected: Family = Family.XBOX
static var choice: Choice = Choice.AUTO
static var _tex: Dictionary = {}


## The family whose glyphs are on screen now.
static func family() -> Family:
	match choice:
		Choice.XBOX:
			return Family.XBOX
		Choice.PLAYSTATION:
			return Family.PLAYSTATION
	return detected


## Which family a connected pad is, off what it reports about itself.
static func family_of(device: int) -> Family:
	var info := Input.get_joy_info(device)
	var vendor := int(info.get("vendor_id", -1))
	if vendor == SONY:
		return Family.PLAYSTATION
	var name_of := Input.get_joy_name(device).to_lower()
	for word: String in SONY_NAMES:
		if name_of.contains(word):
			return Family.PLAYSTATION
	return Family.XBOX


## The tile name for a written binding in a family, or "".
static func tile_of(written: String, in_family: Family) -> String:
	if SHARED.has(written):
		return String(SHARED[written])
	var table := PLAYSTATION if in_family == Family.PLAYSTATION else XBOX
	return String(table.get(written, ""))


## The glyph for a written binding in the family on screen, or null.
static func texture(written: String) -> Texture2D:
	return texture_in(written, family())


static func texture_in(written: String, in_family: Family) -> Texture2D:
	var tile := tile_of(written, in_family)
	if tile.is_empty():
		return null
	if not _tex.has(tile):
		var path := DIR % tile
		_tex[tile] = load(path) if ResourceLoader.exists(path) else null
	return _tex[tile] as Texture2D


## The glyph of whatever an action is bound to on the pad.
static func of_action(action: StringName) -> Texture2D:
	return texture(Binds.bound(action, "pad"))


## The pad's "yes": A on Xbox, Cross on PlayStation — whatever `interact` is bound to, since
## that is the button `Pad` turns into the click.
static func confirm() -> Texture2D:
	return of_action(&"interact")


## The words for a pad binding in the family on screen.
static func pad_words(written: String) -> String:
	if family() != Family.PLAYSTATION:
		return ""
	var parts := written.split(":")
	if parts[0] == "pad" and parts.size() > 1:
		return String(PS_NAMES.get(int(parts[1]), ""))
	if parts[0] == "axis" and parts.size() > 2:
		return String(PS_AXIS_NAMES.get("%s:%s" % [parts[1], parts[2]], ""))
	return ""


## A binding as something a sentence can carry: the glyph's token where there is a glyph,
## its words where there is not.
static func token(written: String) -> String:
	if texture(written) == null:
		return Binds.label_of(written)
	return OPEN + written + SHUT


static func has_tokens(text: String) -> bool:
	return text.contains(OPEN)


## Text cut into its runs: Strings, and Textures where a token stood.
static func pieces(text: String) -> Array:
	var out: Array = []
	var rest := text
	while true:
		var at := rest.find(OPEN)
		if at < 0:
			break
		var end := rest.find(SHUT, at)
		if end < 0:
			break
		if at > 0:
			out.append(rest.substr(0, at))
		var glyph := texture(rest.substr(at + 1, end - at - 1))
		out.append(glyph if glyph != null else "?")
		rest = rest.substr(end + 1)
	if not rest.is_empty():
		out.append(rest)
	return out


## Screen pixels to a canvas pixel: the window's stretch. Never under one: the least window
## is the canvas (`Prefs.LEAST_WINDOW`), and a headless run reports a window of nothing.
static func stretch() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return 1.0
	return maxf(tree.root.get_final_transform().get_scale().y, 1.0)


## Canvas pixels to one of the pack's, for a glyph inside text of this size.
static func inline_px(size_px: int) -> float:
	var s := stretch()
	var whole := maxf(1.0, floorf(float(size_px) * s * INLINE_GROW / 16.0 + 0.15))
	return whole / s


## Canvas pixels to one of the pack's, for a glyph standing on its own.
static func prompt_px() -> float:
	return PROMPT_PX / stretch()


## How wide a line is, glyphs counted as pictures.
static func measure(text: String, face: Font, size_px: int) -> Vector2:
	if not has_tokens(text):
		return face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px)
	var wide := 0.0
	var px := inline_px(size_px)
	for piece: Variant in pieces(text):
		if piece is Texture2D:
			wide += (piece as Texture2D).get_size().x * px + 1.0
		else:
			wide += face.get_string_size(String(piece), HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
	return Vector2(wide, face.get_height(size_px))


## A line with its glyphs, from a baseline at its left end, in plain ink (no shade). The
## glyphs keep their own colours, faded by the ink's alpha.
static func draw_line(on: CanvasItem, face: Font, at: Vector2, text: String, size_px: int, ink: Color) -> void:
	var x := at.x
	var px := inline_px(size_px)
	for piece: Variant in pieces(text):
		if piece is Texture2D:
			var tex := piece as Texture2D
			var box := tex.get_size() * px
			var middle := at.y - float(size_px) * 0.36
			var corner := snap(Vector2(x + 0.5, middle - box.y * 0.5))
			on.draw_texture_rect(tex, Rect2(corner, box), false, Color(1, 1, 1, ink.a))
			x += box.x + 1.0
		else:
			var words := String(piece)
			on.draw_string(face, Vector2(x, at.y), words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, ink)
			x += face.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x


## One glyph standing on its own, centred on a point, at `PROMPT_PX` or a scale given.
static func draw_centred(on: CanvasItem, tex: Texture2D, middle: Vector2, px: float = -1.0, alpha: float = 1.0) -> Rect2:
	if tex == null:
		return Rect2()
	var scale := px if px > 0.0 else prompt_px()
	var box := tex.get_size() * scale
	var corner := snap(middle - box * 0.5)
	on.draw_texture_rect(tex, Rect2(corner, box), false, Color(1, 1, 1, alpha))
	return Rect2(corner, box)


## A canvas point on the window's own pixel grid, so a glyph's pixels land whole.
static func snap(at: Vector2) -> Vector2:
	var s := stretch()
	return (at * s).round() / s


## The glyph a token string stands for, when the whole string is one token; null otherwise.
## The key chips draw the picture alone rather than a picture inside a chip.
static func lone(text: String) -> Texture2D:
	var parts := pieces(text)
	if parts.size() == 1 and parts[0] is Texture2D:
		return parts[0] as Texture2D
	return null
