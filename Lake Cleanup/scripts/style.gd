## The one place the UI's colours, sizes and shapes are decided.
##
## Before this file there were five separate brown palettes, thirteen near-identical creams,
## four hover washes for the same gesture, two fonts sitting side by side in the same HUD,
## and four independent implementations of "a rectangle with a border and a label in the
## middle". None of that was a decision anyone made; it is what happens when each surface is
## styled on the day it is written. This file is the single answer, and every UI script reads
## from it rather than carrying its own.
##
## Split of duty with wood_ui.gd: WoodUI builds StyleBox and Texture resources, for the real
## Controls that live in a scene and hold a theme override. Style draws immediately, for the
## Controls that paint themselves in `_draw` and cannot hold a stylebox at all. Both read the
## constants below, so the two halves cannot drift apart.
##
## This file must never reference WoodUI. Two scripts that name each other cycle at parse
## time and take the whole project down at load; the dependency runs one way only.
##
## Deliberately no `class_name`: consumers preload it as `const Style := preload(...)`. A
## global class is registered by the editor into its own cache, so a headless tool run — the
## test harness, the screenshot tool — can hit a stale cache and fail to see it. A preload is
## resolved by the parser from the path, every time, in every context.
extends RefCounted

# ---------------------------------------------------------------------------------------
# Wood
# ---------------------------------------------------------------------------------------

## The five tones every wooden surface is built from. Five rather than four: the old set had
## no pale highlight, which is why callers kept reaching for an ad-hoc `.lightened(0.3)` and
## why no two lit edges in the game were the same colour.
##
## They form an even luminance ladder, so a bevel stays readable whichever two of them meet.
## WOOD is a half-step off pure orange — enough that GOLD reads as a different material
## rather than as a plank someone turned the brightness up on.
const SEAM := Color(0.13, 0.09, 0.06)
const WOOD_DEEP := Color(0.26, 0.17, 0.11)
const WOOD := Color(0.47, 0.33, 0.21)
const WOOD_LIT := Color(0.62, 0.45, 0.29)
const WOOD_PALE := Color(0.79, 0.60, 0.41)

# ---------------------------------------------------------------------------------------
# Ink
# ---------------------------------------------------------------------------------------

## Text. INK on WOOD is about 5.2:1, comfortable down to the smallest rung on the ladder
## below; INK on WOOD_LIT is about 3.4:1, which is why hovering lightens the plank and never
## the lettering on it. INK_DARK is for the one place text sits on a pale field — the price
## tag — where a cream would vanish.
const INK := Color(0.97, 0.94, 0.86)
const INK_DIM := Color(0.74, 0.69, 0.60)
const INK_DARK := Color(0.14, 0.10, 0.06)
const SHADE := Color(0.00, 0.00, 0.00, 0.55)

# ---------------------------------------------------------------------------------------
# Accents
# ---------------------------------------------------------------------------------------

## Money, and the things that are not money. GOLD is deliberately more yellow and less
## orange than any wood tone — both R and G at or above 0.80, B down at 0.30 — because that
## gap is the whole reason a coin reads as a coin against a plank.
const GOLD := Color(1.00, 0.80, 0.30)
const GOLD_DEEP := Color(0.72, 0.52, 0.14)

## The price tag: a pale plank, dark ink on it, a gold-brown edge.
const TAG := Color(0.88, 0.74, 0.50)
const TAG_LIT := Color(0.94, 0.83, 0.62)
const TAG_OFF := Color(0.55, 0.48, 0.39)

## The three things the UI says with colour rather than words.
const DANGER := Color(0.80, 0.24, 0.19)
const SAFE := Color(0.44, 0.78, 0.42)
const COOL := Color(0.36, 0.66, 0.74)

## How the angler is brought into the game's own light: how much saturation comes out, what
## colour the figure leans toward and how far, and how much of its brightness goes.
##
## The one place these live. The lake draws the character through shaders/figure.gdshader,
## whose uniform defaults are these numbers; the shed room has no shader — it draws the whole
## room on one canvas item and a material there would tint the floor and the inventory list
## too — so it bakes the same arithmetic into a copy of the sheet when the room opens. Two
## implementations, one set of numbers, because a player who looks like one person outdoors
## and another indoors is worse than either.
const FIGURE_DESAT := 0.18
const FIGURE_TONE := WOOD
const FIGURE_TONE_MIX := 0.10
const FIGURE_DARKEN := 0.05


## The angler's own colour, taken down into the lake's. See FIGURE_DESAT.
static func figure_tone(art: Color) -> Color:
	# Rec. 601 luma, which is what the eye reads as brightness rather than the average of the
	# three channels: a plain average turns the skin grey before it touches the denim.
	var lit := art.r * 0.299 + art.g * 0.587 + art.b * 0.114
	var out := art.lerp(Color(lit, lit, lit, art.a), FIGURE_DESAT)
	out = out.lerp(Color(FIGURE_TONE.r, FIGURE_TONE.g, FIGURE_TONE.b, art.a), FIGURE_TONE_MIX)
	return Color(
		out.r * (1.0 - FIGURE_DARKEN),
		out.g * (1.0 - FIGURE_DARKEN),
		out.b * (1.0 - FIGURE_DARKEN),
		art.a
	)



# ---------------------------------------------------------------------------------------
# Scrims
# ---------------------------------------------------------------------------------------

## One near-black, three weights of it: a light veil for a disc behind a trophy, the normal
## dim behind a board, and the heavy wash a defeat screen puts over the whole game.
const SCRIM_RGB := Color(0.03, 0.04, 0.05)
const SCRIM_LIGHT := 0.35
const SCRIM := 0.55
const SCRIM_HEAVY := 0.72

# ---------------------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------------------

## What a button does when the pointer is on it and when it is pressed. One wash, not four:
## the difference between 1.12 and 1.15 was never a decision, and a player who moves between
## two buttons should not be able to tell they were written on different days.
const HOVER_WASH := Color(1.14, 1.14, 1.14)

## The warmer wash a payment puts on the money plate. Warmed rather than blown out: the coin
## is already the brightest thing on the plate, and multiplying it evenly pushes it past
## white and out the other side.
const SHINE_WASH := Color(1.22, 1.16, 1.02)
const HOVER_LIFT := 2.0
const PRESS_SINK := 1.0

# ---------------------------------------------------------------------------------------
# Crates
# ---------------------------------------------------------------------------------------

## The yard crate and the charm box are props standing in daylight, not UI panels, so they
## keep a family of their own — a lit face and a shaded one read as a solid in the world,
## where a flat UI plank does not. What they do not keep is a private copy each: these were
## two palettes with the same five names and different values, identical by coincidence and
## drifting apart every time either was touched.
const CRATE := Color(0.53, 0.38, 0.24)
const CRATE_LIT := Color(0.66, 0.48, 0.31)
const CRATE_DARK := Color(0.36, 0.25, 0.16)
const CRATE_IN := Color(0.18, 0.14, 0.10)

# ---------------------------------------------------------------------------------------
# Type
# ---------------------------------------------------------------------------------------

const FONT_PATH := "res://assets/Bungee-Regular.ttf"

## The size ladder, in pixels.
##
## The game runs `canvas_items` stretch from a 1280x720 base, so a Control's size is already
## in that design frame and the engine does the scaling to the real window. That means the
## fraction-of-window sizing some screens used was not resolution independence — it was one
## fixed number written as a multiplication. So: pixels, on a ladder, and the rungs are far
## enough apart that two of them can never be mistaken for a mistake.
const TEXT_TITLE := 26
const TEXT_HEAD := 20
const TEXT_BODY := 16
const TEXT_SMALL := 13
const TEXT_TINY := 11

# ---------------------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------------------

## The height of a stock button, the padding inside a panel, and the gap between the things
## in it. PAD is the shed's existing value on purpose: the shed's floor is whatever is left
## after its inventory list, so moving its padding moves where a dragged piece lands.
const CONTROL_H := 40.0
const PAD := Vector2(20.0, 16.0)
const SEP := 8.0

## The margin around the HUD, and the gap between the pieces of it.
const EDGE := 18.0
const GAP := 10.0

## The bevel on a drawn plaque, as a fraction of its shortest side, and the range it is held
## to — thin enough on a small tag to leave a face, thick enough on a big panel to be seen.
const BEVEL_SHARE := 0.06
const BEVEL_LEAST := 1.0
const BEVEL_MOST := 3.0

## How much room a label is given around itself inside a button it is measured for.
const LABEL_PAD := Vector2(18.0, 10.0)

## Loaded once and kept. A font is a resource load per call otherwise, and these are called
## from `_draw`.
static var _font: Font = null


## The one face the UI is set in. Falls back to the engine default rather than failing, so
## the game still runs with the font missing — the same bargain the sheets strike.
static func font() -> Font:
	if _font == null:
		var loaded := load(FONT_PATH)
		_font = loaded as Font if loaded != null else ThemeDB.fallback_font
	return _font


## The near-black at a given weight. Callers pass one of the three SCRIM constants rather
## than inventing a fourth alpha.
static func scrim(weight: float) -> Color:
	return Color(SCRIM_RGB.r, SCRIM_RGB.g, SCRIM_RGB.b, weight)


## The nearest rung to a size a caller worked out for itself. Surfaces that size their text
## against their own box — a shop row, the stock plate — keep doing that, but land on the
## ladder, so a row and the plate beside it can never end up at 15 and 16.
static func step(px: float) -> int:
	var best := TEXT_TINY
	var gap := absf(px - float(TEXT_TINY))
	for rung in [TEXT_SMALL, TEXT_BODY, TEXT_HEAD, TEXT_TITLE]:
		var here := absf(px - float(rung))
		if here < gap:
			gap = here
			best = rung
	return best


# ---------------------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------------------


## How thick the bevel on this box should be.
static func bevel_of(box: Rect2) -> float:
	return clampf(minf(box.size.x, box.size.y) * BEVEL_SHARE, BEVEL_LEAST, BEVEL_MOST)


## The primitive every drawn button, tag, tile and plate is made of: a seam outline, a face,
## a lit edge along the top and left, a dark one along the bottom and right. Square — there
## is no corner radius anywhere in this game, and the relief is the bevel.
##
## `alpha` multiplies everything, so a screen fading in can hand its own fade straight
## through instead of rebuilding each colour.
static func plaque(on: CanvasItem, box: Rect2, face: Color, alpha: float = 1.0) -> void:
	if alpha <= 0.0 or box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	var bevel := bevel_of(box)
	on.draw_rect(box.grow(1.0), Color(SEAM.r, SEAM.g, SEAM.b, SEAM.a * alpha), true)
	on.draw_rect(box, Color(face.r, face.g, face.b, face.a * alpha), true)
	var lit := WOOD_PALE if face.get_luminance() < WOOD_PALE.get_luminance() else face.lightened(0.25)
	var deep := WOOD_DEEP if face.get_luminance() > WOOD_DEEP.get_luminance() else face.darkened(0.3)
	lit.a *= alpha
	deep.a *= alpha
	on.draw_rect(Rect2(box.position, Vector2(box.size.x, bevel)), lit, true)
	on.draw_rect(Rect2(box.position, Vector2(bevel, box.size.y)), lit, true)
	on.draw_rect(
		Rect2(Vector2(box.position.x, box.end.y - bevel), Vector2(box.size.x, bevel)), deep, true
	)
	on.draw_rect(
		Rect2(Vector2(box.end.x - bevel, box.position.y), Vector2(bevel, box.size.y)), deep, true
	)


## One line of text with the shadow every drawn label in the game wears. Returns the size it
## took, so a caller stacking lines does not have to measure twice.
##
## `within` is for a line that should sit inside a box rather than start at a point: pass the
## box and an alignment and `at` is ignored but for its y.
static func write(
	on: CanvasItem,
	text: String,
	size_px: int,
	at: Vector2,
	ink: Color = INK,
	align: int = HORIZONTAL_ALIGNMENT_LEFT,
	within: Rect2 = Rect2(),
	alpha: float = 1.0
) -> Vector2:
	var face := font()
	var span := face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px)
	if alpha <= 0.0:
		return span
	var start := at
	if within.size.x > 0.0:
		start.x = within.position.x
		if align == HORIZONTAL_ALIGNMENT_CENTER:
			start.x = within.position.x + (within.size.x - span.x) * 0.5
		elif align == HORIZONTAL_ALIGNMENT_RIGHT:
			start.x = within.end.x - span.x
	on.draw_string(
		face,
		start + Vector2(1.0, 1.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		size_px,
		Color(SHADE.r, SHADE.g, SHADE.b, SHADE.a * alpha)
	)
	on.draw_string(
		face,
		start,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		size_px,
		Color(ink.r, ink.g, ink.b, ink.a * alpha)
	)
	return span


## What a line of text takes up, without drawing it.
static func measure(text: String, size_px: int) -> Vector2:
	return font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px)


## The box a label wants, with the standard padding around it, placed with `at` as its top
## left. For callers that size a button to its text rather than the other way round.
static func button_box(label: String, size_px: int, at: Vector2) -> Rect2:
	var span := measure(label, size_px)
	return Rect2(at, span + LABEL_PAD * 2.0)


## A plaque with a label centred on it, and the hover and press the whole game shares.
##
## Returns the box it was *given*, not the one it drew — a hovered button lifts by a couple
## of pixels, and a caller that hit-tests the lifted rect has a button that slides out from
## under the pointer at its own edge. On a screen with no other way out that is a soft lock.
static func button(
	on: CanvasItem,
	box: Rect2,
	label: String,
	size_px: int,
	hovered: bool = false,
	pressed: bool = false,
	face: Color = WOOD,
	ink: Color = INK,
	alpha: float = 1.0
) -> Rect2:
	var drawn := box
	var tint := face
	if pressed:
		drawn.position.y += PRESS_SINK
		tint = face.darkened(0.18)
	elif hovered:
		drawn.position.y -= HOVER_LIFT
		tint = Color(face.r * HOVER_WASH.r, face.g * HOVER_WASH.g, face.b * HOVER_WASH.b, face.a)
	plaque(on, drawn, tint, alpha)
	if label != "":
		var span := measure(label, size_px)
		var baseline := drawn.position.y + (drawn.size.y + span.y * 0.62) * 0.5
		write(
			on,
			label,
			size_px,
			Vector2(drawn.position.x, baseline),
			ink,
			HORIZONTAL_ALIGNMENT_CENTER,
			Rect2(drawn.position.x, baseline, drawn.size.x, 1.0),
			alpha
		)
	return box


## A reading: a sunken trough, a fill across whatever fraction of it, a seam outline, and an
## optional label centred on the whole thing. The shed's health and the siege's shield are
## the same object. The pollution meter is not — it is art, assembled in hud_skin.gd.
static func bar(
	on: CanvasItem,
	box: Rect2,
	fill: float,
	tint: Color,
	label: String = "",
	trough: Color = WOOD_DEEP
) -> void:
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	on.draw_rect(box, trough, true)
	var share := clampf(fill, 0.0, 1.0)
	if share > 0.0:
		on.draw_rect(Rect2(box.position, Vector2(box.size.x * share, box.size.y)), tint, true)
	on.draw_rect(box, SEAM, false, 1.0)
	if label == "":
		return
	var size_px := step(box.size.y * 0.62)
	var span := measure(label, size_px)
	write(
		on,
		label,
		size_px,
		Vector2(box.position.x, box.position.y + (box.size.y + span.y * 0.62) * 0.5),
		INK,
		HORIZONTAL_ALIGNMENT_CENTER,
		box
	)


## The wash a screen puts over what is behind it. `fade` is the screen's own fade-in, kept
## separate from the weight so a caller cannot lose one by passing the other.
static func dim(on: CanvasItem, box: Rect2, weight: float, fade: float = 1.0) -> void:
	if fade <= 0.0:
		return
	on.draw_rect(box, scrim(weight * fade), true)
