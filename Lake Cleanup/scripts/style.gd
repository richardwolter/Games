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
## the lettering on it. INK_DARK is for text on a pale field, where a cream would vanish.
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

# ---------------------------------------------------------------------------------------
# The upgrades boards
# ---------------------------------------------------------------------------------------

## The three boards are the pollution meter's own colours, read off its sheets: the board
## is the dark between the meter's sheets, the rows are its murky water, a row that cannot
## be afforded sinks to the scummy green, the price tags are the clean end of the water,
## and the frame round each is the meter's oak. Picked (2026-09-11) over the oak alone, a
## clean-water board, and the sand-and-bin-bag circle: the clean-water board was tried
## first and read too bright against the lake.
const BOARD := Color(0.17, 0.24, 0.25)
const BOARD_ROW := Color(0.25, 0.41, 0.47)
const BOARD_ROW_OFF := Color(0.22, 0.35, 0.25)
const BOARD_INK := Color(0.85, 0.91, 0.94)
const BOARD_INK_DIM := Color(0.48, 0.55, 0.47)
## The settings board's rows, one tone a section so the eye finds a section by colour:
## sound on the murky water, the screen on the meter's scum green, the saves on oak like a
## price tag, and the quit on that same oak with its warning in the ink alone (a red plank
## was tried and did not work). A switch that is "on" is lit in the
## money's gold; a slider's played length is clean water — a volume is a level, and gold
## read as a price.
const ROW_SOUND := Color(0.25, 0.41, 0.47)
const ROW_SCREEN := Color(0.27, 0.40, 0.29)
const ROW_SAVE := Color(0.62, 0.46, 0.36)
const ON_GOLD := Color(0.72, 0.52, 0.14)
const ON_WATER := Color(0.31, 0.60, 0.75)

## The recycle box's own colours, read off `assets/Recycle_Box.png`: its planks, their lit
## and shaded tones, the dark hollow inside it, and the blue of the recycle mark on its
## front. The stock readout wears them, because it is the count of what is in that box.
const BOX := Color(0.47, 0.35, 0.25)
const BOX_LIT := Color(0.63, 0.44, 0.31)
const BOX_DEEP := Color(0.35, 0.22, 0.16)
const BOX_HOLLOW := Color(0.28, 0.09, 0.09)
const BOX_BLUE := Color(0.30, 0.52, 0.65)
const BOX_BLUE_LIT := Color(0.43, 0.66, 0.80)

## The price on its tag is the money plate's own figure colour, so a cost and a purse read
## as the same substance.
const PRICE_INK := Color(0.985, 0.87, 0.58)
## The frame's wood, read off the meter's frame sheet: the plank face, the redder lower
## plank, the broken peach highlight along a lit edge, the outline, the inset shadow where
## wood meets water, and the two grain tones.
const FRAME := Color(0.62, 0.46, 0.36)
const FRAME_LOW := Color(0.55, 0.33, 0.25)
const FRAME_LIT := Color(0.71, 0.55, 0.45)
const FRAME_GLOW := Color(0.86, 0.68, 0.58)
const FRAME_DEEP := Color(0.26, 0.17, 0.11)
const FRAME_SHADOW := Color(0.14, 0.07, 0.04)
const FRAME_GRAIN := Color(0.48, 0.30, 0.22)
const FRAME_GRAIN_LIT := Color(0.71, 0.55, 0.45)
## The title plank over each board is the frame's own oak; only its ink is its own.
const RIBBON_INK := Color(0.94, 0.85, 0.75)

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


# ---------------------------------------------------------------------------------------
# Meter wood
# ---------------------------------------------------------------------------------------

## The planks the upgrades boards and the corner cross are made of, drawn as the meter's
## frame is painted. One place, so the boards and the cross cannot be two woods.
const GRAIN_EVERY := 7.0
const GRAIN_LONG := 34.0
const GLOW_LONG := 22.0
const PLANK_DEEP := 12.0


## A plank: seam, face, the broken highlight along its top and left, a deep line under it
## and down its right, grain along it. `seed` picks the grain so two planks never match.
## `clip` cuts a step off each corner, for a plank that is a button rather than a frame.
static func plank(on: CanvasItem, box: Rect2, seed: int, face: Color = FRAME, clip: float = 0.0) -> void:
	if clip > 0.0:
		on.draw_colored_polygon(clipped(box.grow(1.0), clip), SEAM)
		on.draw_colored_polygon(clipped(box, clip), face)
	else:
		on.draw_rect(box.grow(1.0), SEAM, true)
		on.draw_rect(box, face, true)
	grain(on, box.grow(-clip * 0.5), true, seed, box.size.y - clip)
	highlight(on, box.position + Vector2(clip, 0.0), Vector2(box.size.x - clip * 2.0, 0.0), seed + 4)
	highlight(on, box.position + Vector2(0.0, clip), Vector2(0.0, box.size.y - clip * 2.0), seed + 5)
	on.draw_rect(Rect2(Vector2(box.position.x + clip, box.end.y - 1.0), Vector2(box.size.x - clip * 2.0, 1.0)), FRAME_DEEP, true)
	on.draw_rect(Rect2(Vector2(box.end.x - 1.0, box.position.y + clip), Vector2(1.0, box.size.y - clip * 2.0)), FRAME_DEEP, true)


## The broken highlight the light lays along a plank's lit edge: runs of pale peach a
## pixel in from the seam, gaps between, lengths off a hash so no two edges match.
static func highlight(on: CanvasItem, from: Vector2, along: Vector2, seed: int) -> void:
	var length := along.length()
	if length <= 0.0:
		return
	var dir := along / length
	var inward := Vector2(1.0, 1.0)
	var at := 3.0
	var i := 0
	while at < length - 3.0:
		var h := hash(seed * 97 + i)
		var run := 5.0 + float(h % 100) / 100.0 * (GLOW_LONG - 5.0)
		var gap := 3.0 + float((h / 100) % 9)
		var stop := minf(at + run, length - 3.0)
		var lit := FRAME_GLOW if h % 5 != 0 else FRAME_LIT
		on.draw_line(from + dir * at + inward, from + dir * stop + inward, lit, 1.0)
		at = stop + gap
		i += 1


## Grain: streaks running the length of a plank, staggered by a hash so no two planks
## repeat. A dark fibre, and a light one beside it on about a third of them.
static func grain(on: CanvasItem, plank_box: Rect2, across: bool, seed: int, deep: float = PLANK_DEEP) -> void:
	var length := plank_box.size.x if across else plank_box.size.y
	var lanes := maxi(int(deep - 5.0), 1)
	var n := int(length / GRAIN_EVERY)
	for i in n:
		var h := hash(seed * 131 + i)
		if h % 3 == 0:
			continue
		var at := (float(i) + 0.15 + 0.7 * float(h % 7) / 7.0) * GRAIN_EVERY
		var run := 8.0 + float(h % 100) / 100.0 * (GRAIN_LONG - 8.0)
		var lane := 2.5 + float((h / 7) % lanes)
		var start: Vector2
		var stop: Vector2
		if across:
			start = plank_box.position + Vector2(at, lane)
			stop = Vector2(minf(start.x + run, plank_box.end.x - 2.0), start.y)
		else:
			start = plank_box.position + Vector2(lane, at)
			stop = Vector2(start.x, minf(start.y + run, plank_box.end.y - 2.0))
		on.draw_line(start, stop, FRAME_GRAIN, 1.0)
		if h % 3 == 1:
			var step := Vector2(0.0, 1.0) if across else Vector2(1.0, 0.0)
			on.draw_line(start + step, stop + step, FRAME_GRAIN_LIT, 1.0)


## One bite out of a plank's edge: a dark rim round a hollow, and a lit lip along the
## hollow's lower edge where the light catches the broken wood. The rim is what keeps it
## from reading as a missing pixel.
static func chip(on: CanvasItem, box: Rect2) -> void:
	on.draw_rect(box.grow(1.0), FRAME_DEEP, true)
	on.draw_rect(box, FRAME_SHADOW, true)
	on.draw_rect(Rect2(Vector2(box.position.x, box.end.y - 1.0), Vector2(box.size.x, 1.0)), FRAME_GLOW, true)


## The oak frame round a drawn board, as the meter's is painted: a dark seam, the plank,
## a lit top and left edge, a shaded bottom and right, grain along each side, and chips out
## of the outer edge. `thick` is how wide the wood is; `chips` how many bites per edge.
##
## Lives here rather than in the shop, because the shop's boards, the settings board and the
## shed's shelf are one piece of furniture drawn three times. Two copies would drift into
## two woods the first time either was retuned.
static func board_frame(on: CanvasItem, box: Rect2, thick: float, chips: int) -> void:
	on.draw_rect(box.grow(1.0), SEAM, true)
	on.draw_rect(box, FRAME, true)
	# Lit from the upper left, as the meter is: the bottom plank is the redder low tone,
	# the top and left planks carry a broken highlight along their outer edge.
	on.draw_rect(
		Rect2(Vector2(box.position.x, box.end.y - thick), Vector2(box.size.x, thick)),
		FRAME_LOW, true
	)
	var seed := int(box.position.x) * 31 + int(box.position.y) * 17
	grain(on, Rect2(box.position, Vector2(box.size.x, thick)), true, seed)
	grain(on, Rect2(Vector2(box.position.x, box.end.y - thick), Vector2(box.size.x, thick)), true, seed + 1)
	grain(on, Rect2(box.position, Vector2(thick, box.size.y)), false, seed + 2)
	grain(on, Rect2(Vector2(box.end.x - thick, box.position.y), Vector2(thick, box.size.y)), false, seed + 3)
	highlight(on, box.position, Vector2(box.size.x, 0.0), seed + 4)
	highlight(on, box.position, Vector2(0.0, box.size.y), seed + 5)
	on.draw_rect(
		Rect2(Vector2(box.position.x, box.end.y - 1.0), Vector2(box.size.x, 1.0)), FRAME_DEEP, true
	)
	on.draw_rect(
		Rect2(Vector2(box.end.x - 1.0, box.position.y), Vector2(1.0, box.size.y)), FRAME_DEEP, true
	)
	# The inset shadow where the wood meets the board face: two deep along the top and
	# left, where the frame shades the face, one along the bottom and right.
	var face := box.grow(-thick)
	on.draw_rect(Rect2(face.position - Vector2(2.0, 2.0), Vector2(face.size.x + 4.0, 2.0)), FRAME_SHADOW, true)
	on.draw_rect(Rect2(face.position - Vector2(2.0, 2.0), Vector2(2.0, face.size.y + 4.0)), FRAME_SHADOW, true)
	on.draw_rect(Rect2(Vector2(face.position.x - 2.0, face.end.y + 1.0), Vector2(face.size.x + 4.0, 1.0)), FRAME_SHADOW, true)
	on.draw_rect(Rect2(Vector2(face.end.x + 1.0, face.position.y - 2.0), Vector2(1.0, face.size.y + 4.0)), FRAME_SHADOW, true)
	# Chips: small bites out of the outer edge, dark where the wood is gone.
	for i in chips:
		var along := (float(i) + 0.5 + 0.3 * float(hash(seed + i) % 5) / 5.0) / float(chips)
		var wide := 6.0 + 2.0 * float(hash(seed * 3 + i) % 3)
		var deep := 3.0 + float(hash(seed * 5 + i) % 3)
		var y := box.position.y + box.size.y * along
		var x := box.position.x + box.size.x * (1.0 - along)
		chip(on, Rect2(box.position.x - 1.0, y, deep, wide))
		chip(on, Rect2(box.end.x + 1.0 - deep, y - wide * 0.4, deep, wide))
		if i % 2 == 0:
			chip(on, Rect2(x, box.position.y - 1.0, wide, deep))
			chip(on, Rect2(x - wide * 0.6, box.end.y + 1.0 - deep, wide, deep))


## The title plank a board wears over its top edge. A plank of the same oak as the frame,
## lit the same way, with chips out of its edges. Cloth was tried — a bowed three-tone band,
## then one with tails — and read as a sticker.
## `within` is where the title is centred, for a ribbon with something else sitting on one
## end of it. Left empty, it is the plank itself.
static func board_ribbon(
	on: CanvasItem,
	box: Rect2,
	title: String,
	chips: int,
	size_px: int = TEXT_HEAD,
	within: Rect2 = Rect2()
) -> void:
	var seed := int(box.position.x) * 53 + int(box.position.y) * 29 + 7
	plank(on, box, seed)
	# Chips out of the top and bottom edges and one out of each end.
	for i in chips:
		var along := (float(i) + 0.5 + 0.3 * float(hash(seed + i) % 5) / 5.0) / float(chips)
		var wide := 6.0 + 2.0 * float(hash(seed * 3 + i) % 3)
		var deep := 3.0 + float(hash(seed * 5 + i) % 3)
		var x := box.position.x + box.size.x * along
		chip(on, Rect2(x, box.position.y - 1.0, wide, deep))
		chip(on, Rect2(box.end.x - box.size.x * along - wide * 0.6, box.end.y + 1.0 - deep, wide, deep))
	var y := box.position.y + box.size.y * 0.4
	chip(on, Rect2(box.position.x - 1.0, y, 4.0, 8.0))
	chip(on, Rect2(box.end.x - 3.0, y + 6.0, 4.0, 8.0))

	var text_box := box if within.size.x <= 0.0 else within
	write(
		on, title, size_px,
		Vector2(0.0, box.position.y + (box.size.y + float(size_px) * 0.62) * 0.5),
		RIBBON_INK, HORIZONTAL_ALIGNMENT_CENTER, text_box
	)


## One step cut off each corner of a plate: the pixel-art round corner.
const CLIP := 3.0


## A plate in a colour of its own, its corners clipped a step: a seam, the face, a lit edge
## top and left, a shaded one bottom and right. `plaque` bevels in wood and stays square;
## these are the boards' buttons and read better softened.
static func plate(on: CanvasItem, box: Rect2, face: Color, c: float = CLIP) -> void:
	var bevel := bevel_of(box)
	on.draw_colored_polygon(clipped(box.grow(1.0), c), SEAM)
	on.draw_colored_polygon(clipped(box, c), face)
	var lit := face.lightened(0.22)
	var deep := face.darkened(0.28)
	on.draw_rect(Rect2(box.position + Vector2(c, 0.0), Vector2(box.size.x - c * 2.0, bevel)), lit, true)
	on.draw_rect(Rect2(box.position + Vector2(0.0, c), Vector2(bevel, box.size.y - c * 2.0)), lit, true)
	on.draw_rect(
		Rect2(Vector2(box.position.x + c, box.end.y - bevel), Vector2(box.size.x - c * 2.0, bevel)),
		deep, true
	)
	on.draw_rect(
		Rect2(Vector2(box.end.x - bevel, box.position.y + c), Vector2(bevel, box.size.y - c * 2.0)),
		deep, true
	)


## A rectangle with one step cut off each corner.
static func clipped(box: Rect2, c: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(box.position.x + c, box.position.y),
		Vector2(box.end.x - c, box.position.y),
		Vector2(box.end.x, box.position.y + c),
		Vector2(box.end.x, box.end.y - c),
		Vector2(box.end.x - c, box.end.y),
		Vector2(box.position.x + c, box.end.y),
		Vector2(box.position.x, box.end.y - c),
		Vector2(box.position.x, box.position.y + c),
	])

