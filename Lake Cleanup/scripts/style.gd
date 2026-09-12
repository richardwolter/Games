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
## The level on an upgrades row, after its name: the slider's clean-water blue, lifted a
## step so it reads on the row's murky plate. A level is not a price, so not the gold.
const LEVEL_INK := Color(0.47, 0.78, 0.92)

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

## The bites out of a plank's edge are holes, not paint (2026-09-11): the wood is drawn as
## a polygon with the bites cut out of it, so whatever is behind the plank — the lake, the
## board face under a title plank — shows through, and each hole is ringed in one pixel of
## pure black. Before this a chip was a brown rim round a darker brown hollow with a lit
## lip, painted over the finished plank, and read as a smudge rather than as broken wood.
const HOLE_RIM := Color(0.0, 0.0, 0.0)


## Where the bites out of a board frame's outer edge fall: `chips` per side, staggered by
## the seed, sized 6-8 wide by 3-5 deep, starting a pixel outside the seam so the hole is
## open to the outside. Whole pixels, so the polygon edges land on the pixel grid.
static func frame_bites(box: Rect2, seed: int, chips: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in chips:
		var along := (float(i) + 0.5 + 0.3 * float(hash(seed + i) % 5) / 5.0) / float(chips)
		var wide := 6.0 + 2.0 * float(hash(seed * 3 + i) % 3)
		var deep := 3.0 + float(hash(seed * 5 + i) % 3)
		var y := floorf(box.position.y + box.size.y * along)
		var x := floorf(box.position.x + box.size.x * (1.0 - along))
		out.append(Rect2(box.position.x - 1.0, y, deep, wide))
		out.append(Rect2(box.end.x + 1.0 - deep, y - floorf(wide * 0.4), deep, wide))
		if i % 2 == 0:
			out.append(Rect2(x, box.position.y - 1.0, wide, deep))
			out.append(Rect2(x - floorf(wide * 0.6), box.end.y + 1.0 - deep, wide, deep))
	return out


## Where the bites out of a title plank fall: `chips` along the top and bottom edges and
## one out of each end.
static func ribbon_bites(box: Rect2, seed: int, chips: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in chips:
		var along := (float(i) + 0.5 + 0.3 * float(hash(seed + i) % 5) / 5.0) / float(chips)
		var wide := 6.0 + 2.0 * float(hash(seed * 3 + i) % 3)
		var deep := 3.0 + float(hash(seed * 5 + i) % 3)
		var x := floorf(box.position.x + box.size.x * along)
		out.append(Rect2(x, box.position.y - 1.0, wide, deep))
		out.append(Rect2(
			floorf(box.end.x - box.size.x * along - wide * 0.6), box.end.y + 1.0 - deep, wide, deep
		))
	var y := floorf(box.position.y + box.size.y * 0.4)
	out.append(Rect2(box.position.x - 1.0, y, 4.0, 8.0))
	out.append(Rect2(box.end.x - 3.0, y + 6.0, 4.0, 8.0))
	return out


## The bites a button plank takes: one out of the top edge, one out of the bottom.
static func button_bites(box: Rect2, seed: int) -> Array[Rect2]:
	var wide := 5.0 + float(seed % 3)
	var out: Array[Rect2] = []
	out.append(Rect2(floorf(box.position.x + box.size.x * (0.2 + 0.5 * float(seed % 7) / 7.0)), box.position.y - 1.0, wide, 3.0))
	out.append(Rect2(floorf(box.end.x - box.size.x * (0.15 + 0.4 * float(seed % 5) / 5.0)), box.end.y - 2.0, wide, 3.0))
	return out


static func rect_poly(box: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)
	])


## A polygon with the bites cut out of it, each bite grown by `grow` first. What comes
## back is the pieces left, minus any that are holes — bites sit on an edge, so there are
## none, but a caller who hands a bite in the middle of a plank gets the plank and not a
## polygon it cannot draw.
static func carved(poly: PackedVector2Array, bites: Array[Rect2], grow: float = 0.0) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [poly]
	for bite in bites:
		var cut := rect_poly(bite.grow(grow))
		var next: Array[PackedVector2Array] = []
		for piece in pieces:
			for got in Geometry2D.clip_polygons(piece, cut):
				if got.size() >= 3 and not Geometry2D.is_polygon_clockwise(got):
					next.append(got)
		pieces = next
	return pieces


static func fill_carved(on: CanvasItem, poly: PackedVector2Array, bites: Array[Rect2], colour: Color, grow: float = 0.0) -> void:
	if bites.is_empty():
		on.draw_colored_polygon(poly, colour)
		return
	for piece in carved(poly, bites, grow):
		on.draw_colored_polygon(piece, colour)


## A one-pixel line along an axis, with the stretches that cross a bite left out. Grain,
## highlights and the shaded edges are all such lines; anything else through a hole would
## be a line drawn across the air.
static func line_carved(on: CanvasItem, from: Vector2, to: Vector2, colour: Color, bites: Array[Rect2]) -> void:
	if bites.is_empty():
		on.draw_line(from, to, colour, 1.0)
		return
	var across := is_equal_approx(from.y, to.y)
	var lo := minf(from.x, to.x) if across else minf(from.y, to.y)
	var hi := maxf(from.x, to.x) if across else maxf(from.y, to.y)
	var at := from.y if across else from.x
	var spans: Array[Vector2] = [Vector2(lo, hi)]
	for bite in bites:
		var hole := bite.grow(1.0)
		var cut_lo := hole.position.x if across else hole.position.y
		var cut_hi := hole.end.x if across else hole.end.y
		var side_lo := hole.position.y if across else hole.position.x
		var side_hi := hole.end.y if across else hole.end.x
		if at < side_lo or at >= side_hi:
			continue
		var next: Array[Vector2] = []
		for span in spans:
			if span.y <= cut_lo or span.x >= cut_hi:
				next.append(span)
				continue
			if span.x < cut_lo:
				next.append(Vector2(span.x, cut_lo))
			if span.y > cut_hi:
				next.append(Vector2(cut_hi, span.y))
		spans = next
	for span in spans:
		if span.y - span.x < 1.0:
			continue
		if across:
			on.draw_line(Vector2(span.x, at), Vector2(span.y, at), colour, 1.0)
		else:
			on.draw_line(Vector2(at, span.x), Vector2(at, span.y), colour, 1.0)


## The black pixel round each hole: a one-pixel ring outside the bite, kept inside the
## plank's seam so the open side of the hole stays open.
static func rims(on: CanvasItem, box: Rect2, bites: Array[Rect2]) -> void:
	var keep := box.grow(1.0)
	for bite in bites:
		var ring := bite.grow(1.0)
		for strip: Rect2 in [
			Rect2(ring.position, Vector2(ring.size.x, 1.0)),
			Rect2(Vector2(ring.position.x, ring.end.y - 1.0), Vector2(ring.size.x, 1.0)),
			Rect2(ring.position, Vector2(1.0, ring.size.y)),
			Rect2(Vector2(ring.end.x - 1.0, ring.position.y), Vector2(1.0, ring.size.y)),
		]:
			var shown := strip.intersection(keep)
			if shown.size.x > 0.0 and shown.size.y > 0.0:
				on.draw_rect(shown, HOLE_RIM, true)


## A plank: seam, face, the broken highlight along its top and left, a deep line under it
## and down its right, grain along it. `seed` picks the grain so two planks never match.
## `clip` cuts a step off each corner, for a plank that is a button rather than a frame.
## `bites` are the holes out of its edges (see `frame_bites`, `ribbon_bites`, `button_bites`).
static func plank(on: CanvasItem, box: Rect2, seed: int, face: Color = FRAME, clip: float = 0.0, bites: Array[Rect2] = []) -> void:
	fill_carved(on, clipped(box.grow(1.0), clip), bites, SEAM)
	fill_carved(on, clipped(box, clip), bites, face, 1.0)
	grain(on, box.grow(-clip * 0.5), true, seed, box.size.y - clip, bites)
	highlight(on, box.position + Vector2(clip, 0.0), Vector2(box.size.x - clip * 2.0, 0.0), seed + 4, bites)
	highlight(on, box.position + Vector2(0.0, clip), Vector2(0.0, box.size.y - clip * 2.0), seed + 5, bites)
	fill_carved(on, rect_poly(Rect2(Vector2(box.position.x + clip, box.end.y - 1.0), Vector2(box.size.x - clip * 2.0, 1.0))), bites, FRAME_DEEP, 1.0)
	fill_carved(on, rect_poly(Rect2(Vector2(box.end.x - 1.0, box.position.y + clip), Vector2(1.0, box.size.y - clip * 2.0))), bites, FRAME_DEEP, 1.0)
	rims(on, box, bites)


## The broken highlight the light lays along a plank's lit edge: runs of pale peach a
## pixel in from the seam, gaps between, lengths off a hash so no two edges match.
static func highlight(on: CanvasItem, from: Vector2, along: Vector2, seed: int, bites: Array[Rect2] = []) -> void:
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
		line_carved(on, from + dir * at + inward, from + dir * stop + inward, lit, bites)
		at = stop + gap
		i += 1


## Grain: streaks running the length of a plank, staggered by a hash so no two planks
## repeat. A dark fibre, and a light one beside it on about a third of them.
static func grain(on: CanvasItem, plank_box: Rect2, across: bool, seed: int, deep: float = PLANK_DEEP, bites: Array[Rect2] = []) -> void:
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
		line_carved(on, start, stop, FRAME_GRAIN, bites)
		if h % 3 == 1:
			var step := Vector2(0.0, 1.0) if across else Vector2(1.0, 0.0)
			line_carved(on, start + step, stop + step, FRAME_GRAIN_LIT, bites)


## The oak frame round a drawn board, as the meter's is painted: a dark seam, the plank,
## a lit top and left edge, a shaded bottom and right, grain along each side, and bites
## out of the outer edge. `thick` is how wide the wood is; `chips` how many bites per edge.
##
## Lives here rather than in the shop, because the shop's boards, the settings board and the
## shed's shelf are one piece of furniture drawn three times. Two copies would drift into
## two woods the first time either was retuned.
static func board_frame(on: CanvasItem, box: Rect2, thick: float, chips: int) -> void:
	var seed := int(box.position.x) * 31 + int(box.position.y) * 17
	var bites := frame_bites(box, seed, chips)
	fill_carved(on, rect_poly(box.grow(1.0)), bites, SEAM)
	fill_carved(on, rect_poly(box), bites, FRAME, 1.0)
	# Lit from the upper left, as the meter is: the bottom plank is the redder low tone,
	# the top and left planks carry a broken highlight along their outer edge.
	fill_carved(
		on, rect_poly(Rect2(Vector2(box.position.x, box.end.y - thick), Vector2(box.size.x, thick))),
		bites, FRAME_LOW, 1.0
	)
	grain(on, Rect2(box.position, Vector2(box.size.x, thick)), true, seed, PLANK_DEEP, bites)
	grain(on, Rect2(Vector2(box.position.x, box.end.y - thick), Vector2(box.size.x, thick)), true, seed + 1, PLANK_DEEP, bites)
	grain(on, Rect2(box.position, Vector2(thick, box.size.y)), false, seed + 2, PLANK_DEEP, bites)
	grain(on, Rect2(Vector2(box.end.x - thick, box.position.y), Vector2(thick, box.size.y)), false, seed + 3, PLANK_DEEP, bites)
	highlight(on, box.position, Vector2(box.size.x, 0.0), seed + 4, bites)
	highlight(on, box.position, Vector2(0.0, box.size.y), seed + 5, bites)
	fill_carved(on, rect_poly(Rect2(Vector2(box.position.x, box.end.y - 1.0), Vector2(box.size.x, 1.0))), bites, FRAME_DEEP, 1.0)
	fill_carved(on, rect_poly(Rect2(Vector2(box.end.x - 1.0, box.position.y), Vector2(1.0, box.size.y))), bites, FRAME_DEEP, 1.0)
	# The inset shadow where the wood meets the board face: two deep along the top and
	# left, where the frame shades the face, one along the bottom and right.
	var face := box.grow(-thick)
	on.draw_rect(Rect2(face.position - Vector2(2.0, 2.0), Vector2(face.size.x + 4.0, 2.0)), FRAME_SHADOW, true)
	on.draw_rect(Rect2(face.position - Vector2(2.0, 2.0), Vector2(2.0, face.size.y + 4.0)), FRAME_SHADOW, true)
	on.draw_rect(Rect2(Vector2(face.position.x - 2.0, face.end.y + 1.0), Vector2(face.size.x + 4.0, 1.0)), FRAME_SHADOW, true)
	on.draw_rect(Rect2(Vector2(face.end.x + 1.0, face.position.y - 2.0), Vector2(1.0, face.size.y + 4.0)), FRAME_SHADOW, true)
	rims(on, box, bites)


# ---------------------------------------------------------------------------------------
# The meter's own border
# ---------------------------------------------------------------------------------------

## The pollution meter's painted frame, cut up and built back into a frame of any size.
##
## The corner buttons asked for the meter's border rather than the drawn one, and that art is
## one painting 188 pixels wide by 49 tall with its grain running the full length. **Nothing
## here is ever stretched or squeezed**: a nine-patch was tried first (2026-09-11) and tiling
## eight-pixel slices of that grain turned the oak into corduroy and flattened the chamfer off
## its corners. Every piece below is cut at 1:1, cropped to length, or turned ninety degrees.
##
## The recipe, Richard's:
## - the top and bottom edges are the art's own planks, **cropped** out of their long clean
##   runs — a shorter edge is a shorter cut of the plank, never the same plank squashed;
## - the side walls are a length cut out of that top plank and **turned on its side**, so the
##   grain runs down the stile the way a real frame's sides do;
## - the corners are the meter's own, stamped whole;
## - the butt joints are painted over in the wood's own outline colour, so a join reads as two
##   boards meeting rather than as a cut.
##
## The left half is the right half mirrored. The meter's left side was never painted — the
## garbage circle sits over it, and all that is there is two pixels of edge.
const METER_BORDER := "res://assets/ui/meter/Meter_Border.png"

## Preloaded rather than reached as the global `Art`: this file has no `class_name` and a
## headless tool run cannot count on the global class cache. art.gd depends on nothing, so
## there is no cycle.
const Pics := preload("res://scripts/art.gd")

## The pieces on that sheet. Measured off the sheet's alpha — the planks' clean runs are the
## stretches where every row of the plank is solid, so a crop never lands half on a chip.
## Re-measure all of these if the meter art is repainted.
const BORDER_WALL := 15
const BORDER_TOP := 16
const BORDER_FOOT := 14
const BORDER_CORNER_TOP := Rect2i(256, 24, BORDER_WALL, BORDER_TOP)
const BORDER_CORNER_FOOT := Rect2i(256, 59, BORDER_WALL, BORDER_FOOT)
const BORDER_TOP_RUN := Rect2i(142, 24, 110, BORDER_TOP)
const BORDER_FOOT_RUN := Rect2i(106, 59, 95, BORDER_FOOT)
## The line painted over a butt joint, read off the art's own outer outline.
const BORDER_SEAM := Color8(66, 43, 28)

## The smallest box that can wear it: two corners across and the two planks down, with a
## pixel of face left over.
const BORDER_LEAST := Vector2i(BORDER_WALL * 2 + 2, BORDER_TOP + BORDER_FOOT + 2)

## One built frame per size, kept. There are three buttons and they change size only when the
## window does, so this holds three or four images for the life of the run.
static var _frames := {}
static var _sheet: Image
static var _looked: bool = false


## The sheet, read once. Null if the art is missing, and every caller falls back to the drawn
## frame — the game runs with the art missing rather than failing to load.
static func border_sheet() -> Image:
	if not _looked:
		_looked = true
		_sheet = Pics.image(METER_BORDER)
		if _sheet != null:
			_sheet.convert(Image.FORMAT_RGBA8)
	return _sheet


## How far in from a button's edge its face starts, once it is wearing the meter's border.
static func border_inset(box: Rect2) -> Rect2:
	return Rect2(
		box.position + Vector2(float(BORDER_WALL), float(BORDER_TOP)),
		box.size - Vector2(float(BORDER_WALL * 2), float(BORDER_TOP + BORDER_FOOT))
	)


## Whether a box of this size can wear the border at all.
static func border_fits(box: Rect2) -> bool:
	return (
		border_sheet() != null
		and int(box.size.x) >= BORDER_LEAST.x and int(box.size.y) >= BORDER_LEAST.y
	)


## The meter's border round a box. False if there is no art or the box is too small for it,
## and the caller draws `board_frame` instead.
static func meter_frame(on: CanvasItem, box: Rect2, tint: Color = Color.WHITE) -> bool:
	if not border_fits(box):
		return false
	var want := Vector2i(int(box.size.x), int(box.size.y))
	var built: ImageTexture = _frames.get(want)
	if built == null:
		built = _build_border(want)
		if built == null:
			return false
		_frames[want] = built
	on.draw_texture_rect(built, Rect2(box.position.floor(), Vector2(want)), false, tint)
	return true


## One piece of the sheet as an image of its own.
static func _cut(from: Image, box: Rect2i) -> Image:
	var out := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(from, box, Vector2i.ZERO)
	return out


## A run of plank `length` long, laid out of `piece` end to end, every other length mirrored
## so the grain turns back on itself instead of repeating. Only long edges need more than one
## length: the clean runs are over ninety pixels and most buttons are shorter than that.
static func _plank_run(piece: Image, length: int) -> Image:
	var out := Image.create(maxi(length, 1), piece.get_height(), false, Image.FORMAT_RGBA8)
	var back := piece.duplicate() as Image
	back.flip_x()
	var at := 0
	var turn := false
	while at < length:
		var take := mini(piece.get_width(), length - at)
		var from := back if turn else piece
		# Cut from the far end of a mirrored length, so the two meet on the same grain.
		var start := from.get_width() - take if turn else 0
		out.blit_rect(from, Rect2i(start, 0, take, piece.get_height()), Vector2i(at, 0))
		at += take
		turn = not turn
	return out


## The frame for one size, built out of the sheet.
static func _build_border(want: Vector2i) -> ImageTexture:
	var art := border_sheet()
	if art == null:
		return null
	var out := Image.create(want.x, want.y, false, Image.FORMAT_RGBA8)
	var run := want.x - BORDER_WALL * 2
	var down := want.y - BORDER_TOP - BORDER_FOOT

	# The top and bottom edges: a cropped length of each plank between the two corners.
	if run > 0:
		out.blit_rect(_plank_run(_cut(art, BORDER_TOP_RUN), run), Rect2i(0, 0, run, BORDER_TOP), Vector2i(BORDER_WALL, 0))
		out.blit_rect(
			_plank_run(_cut(art, BORDER_FOOT_RUN), run), Rect2i(0, 0, run, BORDER_FOOT),
			Vector2i(BORDER_WALL, want.y - BORDER_FOOT)
		)
	# The walls: a length of the top plank turned on its side, and mirrored for the far one.
	if down > 0:
		var stile := _plank_run(_cut(art, BORDER_TOP_RUN), down)
		stile.rotate_90(CLOCKWISE)
		# Rotating the plank puts its lit edge down the right-hand side, which is the near
		# wall; the far one is that mirrored, so the light stays on the outside of both.
		var right := _cut(stile, Rect2i(stile.get_width() - BORDER_WALL, 0, BORDER_WALL, down))
		var left := right.duplicate() as Image
		left.flip_x()
		out.blit_rect(left, Rect2i(0, 0, BORDER_WALL, down), Vector2i(0, BORDER_TOP))
		out.blit_rect(right, Rect2i(0, 0, BORDER_WALL, down), Vector2i(want.x - BORDER_WALL, BORDER_TOP))
	# The corners, stamped whole over the ends of both.
	var top_right := _cut(art, BORDER_CORNER_TOP)
	var foot_right := _cut(art, BORDER_CORNER_FOOT)
	var top_left := top_right.duplicate() as Image
	top_left.flip_x()
	var foot_left := foot_right.duplicate() as Image
	foot_left.flip_x()
	var corner := Rect2i(0, 0, BORDER_WALL, BORDER_TOP)
	var foot_box := Rect2i(0, 0, BORDER_WALL, BORDER_FOOT)
	out.blit_rect(top_left, corner, Vector2i.ZERO)
	out.blit_rect(top_right, corner, Vector2i(want.x - BORDER_WALL, 0))
	out.blit_rect(foot_left, foot_box, Vector2i(0, want.y - BORDER_FOOT))
	out.blit_rect(foot_right, foot_box, Vector2i(want.x - BORDER_WALL, want.y - BORDER_FOOT))
	_border_seams(out, want)
	_border_bites(out, want)
	return ImageTexture.create_from_image(out)


## The bites out of the built frame's outer edge, the same holes the drawn wood takes
## (`frame_bites`, `rims`): the pixels go, and what is left round each is ringed in black.
##
## Punched here rather than drawn over the button, because this is an image and a hole in it
## is a real hole — the lake shows through. The meter's own art has chips in its bottom
## plank, but the clean runs the edges are cropped from deliberately avoid them, so without
## this a built frame comes out unbroken and reads as plastic beside the drawn boards.
##
## One bite per `BITE_EVERY` of each edge, staggered off the size so two buttons side by side
## are not bitten in the same places, and kept off the corners — the art's chamfer is already
## the corner's shape and a hole in it reads as damage rather than as wear.
const BITE_EVERY := 46.0
const BITE_WIDE := Vector2i(6, 8)
const BITE_DEEP := Vector2i(3, 5)
const BITE_CLEAR := 5


static func _border_bites(out: Image, want: Vector2i) -> void:
	var seed := want.x * 31 + want.y * 17
	for edge in 4:
		var along := want.x if edge < 2 else want.y
		var room := along - (BORDER_WALL + BITE_CLEAR) * 2 - BITE_WIDE.y
		if room <= 0:
			continue
		var count := maxi(int(float(along) / BITE_EVERY), 1)
		for i in count:
			var h := hash(seed * 97 + edge * 13 + i)
			var wide := BITE_WIDE.x + int(h % (BITE_WIDE.y - BITE_WIDE.x + 1))
			var deep := BITE_DEEP.x + int((h / 11) % (BITE_DEEP.y - BITE_DEEP.x + 1))
			var step := float(room) / float(count)
			var at := BORDER_WALL + BITE_CLEAR + int(step * (float(i) + 0.15 + 0.7 * float((h / 131) % 100) / 100.0))
			var bite: Rect2i
			match edge:
				0:
					bite = Rect2i(at, 0, wide, deep)
				1:
					bite = Rect2i(at, want.y - deep, wide, deep)
				2:
					bite = Rect2i(0, at, deep, wide)
				_:
					bite = Rect2i(want.x - deep, at, deep, wide)
			_bite_out(out, bite)


## One hole: the pixels inside it cleared, and every pixel of wood touching it blacked.
static func _bite_out(out: Image, bite: Rect2i) -> void:
	var box := Rect2i(Vector2i.ZERO, out.get_size())
	var hole := bite.intersection(box)
	if hole.size.x <= 0 or hole.size.y <= 0:
		return
	for y in range(hole.position.y, hole.end.y):
		for x in range(hole.position.x, hole.end.x):
			out.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	var ring := bite.grow(1).intersection(box)
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			if hole.has_point(Vector2i(x, y)):
				continue
			if out.get_pixel(x, y).a > 0.5:
				out.set_pixel(x, y, HOLE_RIM)


## The joints, painted in the wood's own outline: down each side of both corners, and across
## the top and bottom of each wall. A butt joint between two boards is a line; a cut with no
## line is where the eye finds the seam.
static func _border_seams(out: Image, want: Vector2i) -> void:
	for x: int in [BORDER_WALL - 1, want.x - BORDER_WALL]:
		_border_line(out, Rect2i(x, 0, 1, BORDER_TOP))
		_border_line(out, Rect2i(x, want.y - BORDER_FOOT, 1, BORDER_FOOT))
	for y: int in [BORDER_TOP, want.y - BORDER_FOOT - 1]:
		_border_line(out, Rect2i(0, y, BORDER_WALL, 1))
		_border_line(out, Rect2i(want.x - BORDER_WALL, y, BORDER_WALL, 1))


## A line, drawn only where there is wood: a joint painted across a corner's chamfer would
## put pixels out in the air beside it.
static func _border_line(out: Image, box: Rect2i) -> void:
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			if x < 0 or y < 0 or x >= out.get_width() or y >= out.get_height():
				continue
			if out.get_pixel(x, y).a > 0.5:
				out.set_pixel(x, y, BORDER_SEAM)


## The title plank a board wears over its top edge. A plank of the same oak as the frame,
## lit the same way, with bites out of its edges. Cloth was tried — a bowed three-tone band,
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
	plank(on, box, seed, FRAME, 0.0, ribbon_bites(box, seed, chips))
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

