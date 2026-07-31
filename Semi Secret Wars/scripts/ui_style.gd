class_name UIStyle
extends RefCounted
## Single source of truth for the game's UI look — the notebook/child's-comic
## language described in ART_BIBLE.md, matched to the hand-drawn logo, menu
## button art and hero sprites.
##
## Before this existed every screen built its own StyleBoxFlat inline, so the
## same "ink" was 2c2c2c in prep/title/results, 161412 in PrepPage and 3b3b3b
## in hud_theme, cards were flat white instead of paper, and only 2 scenes ever
## got the rounded hand-drawn corners. Everything now routes through here.
##
## Companion pieces:
##   - assets/ui/notebook_theme.tres — the project-wide default Theme (set in
##     project.godot gui/theme/custom), built from these same numbers so the
##     editor previews what the game ships.
##   - scripts/ui_boot.gd — autoload that injects the handwritten font at
##     runtime once the .ttf is present (see FONT_PATH).

# -- Pigments -----------------------------------------------------------------
## The crayon set the hand-drawn sprites are actually coloured with, sampled
## from the art (Designer, 2026-07-26: "all colours should derive from sprite
## colours"). Every palette entry below is one of these, a tint of one, or a
## darkened version of one — so the UI and the field read as the same box of
## pencils rather than two unrelated colour schemes.
##
## Where each was sampled:
##   PAPER       the cream the sprites are drawn on (already the page colour)
##   SOOT        the linework every sprite is outlined in — warm, not black
##   EMBER       Thundaar's tunic
##   NAVY        Thundaar's trousers
##   CANARY      Thundaar's boot/belt accents
##   FOREST      Artemis's scarf, Warden's leaves
##   BARK        Artemis's quiver, Warden's bark, Beacon's sash
##   GRAPHITE    Artemis's trousers, Thundaar's hammer head
##   LIME        Beacon's robe
##   LILAC       Beacon's face
##   CRIMSON     the gem atop Beacon's staff
##   VIOLET      the Dark Mage's robe and his minions — the ENEMY pigment, so
##               nothing friendly should be coloured with it
##
## Raw pigments are for reference and for deriving; screens should use the
## named palette entries below, not these.
const PAPER := Color("f4efe1")
const SOOT := Color("1f1c17")
const EMBER := Color("c4401a")
const NAVY := Color("232a8c")
const CANARY := Color("e0dc1e")
const FOREST := Color("1f7a33")
const BARK := Color("6b4423")
const GRAPHITE := Color("6e6e6e")
const LIME := Color("b9d81f")
const LILAC := Color("e9d8ee")
const CRIMSON := Color("c01818")
const VIOLET := Color("a3239e")
## Mustard — CANARY pushed warm and dark toward BARK. Not sampled from a sprite
## like the rest: added 2026-07-26 because RALLY was asked for in mustard. Kept
## with the pigments rather than the palette since it is a raw colour other
## entries can derive from, and it stays inside the existing crayon set (it is
## the yellow the sprites use, aged).
const MUSTARD := Color("c19a1c")

# -- Palette ------------------------------------------------------------------

## Notebook page. PAGE_SOLID is the opaque paper the battlefield and prep
## screens draw; PAGE is the same colour at overlay opacity, for modal panels
## that sit on top of the battle.
const PAGE_SOLID := PAPER
const PAGE := Color("f4efe1f0")
## Translucent paper for cards laid ON a page — was Color(1,1,1,0.5) in four
## different files, which read as a grey-white sticker rather than paper.
const CARD := Color("f4efe1a8")
const CARD_STRONG := Color("f4efe1d0")

## The one ink. Body text, outlines, borders — all of it. SOOT rather than a
## neutral grey: the sprite linework is a warm near-black, and UI drawn in a
## cooler grey read as printed onto the page instead of drawn on it.
const INK := SOOT
## Secondary/footnote text (lifetime stats, hints). Ink, just lighter.
## Alpha 0x99 -> 0xcc on 2026-07-26: at 60% the thin handwritten strokes on
## paper were the least readable text in the game. Still clearly secondary.
const INK_MUTED := Color("1f1c17cc")
## Ruled lines and the red margin rule of the notebook page — pale tints of
## NAVY and EMBER, so even the stationery comes out of the same box.
const RULE := Color("b7bedb")
const MARGIN := Color("dc9d87")

## Accents, each a sprite pigment adjusted only as far as legibility on cream
## paper demands:
##   GOLD   CANARY darkened — raw canary yellow on cream is nearly invisible.
##          The highlight/pick colour (boons, focus, unlocks, Duo A).
##   DANGER CRIMSON, the staff-gem red, used as-is.
##   GOOD   FOREST, used as-is.
##   INFO   NAVY lifted toward the page so it can be read as small text.
const GOLD := Color("a8861a")
const DANGER := CRIMSON
const GOOD := FOREST
const INFO := Color("5a6bc4")

## The two Duos. Gold and navy are the furthest-apart pair in this pigment set
## that BOTH stay legible on cream — deliberately not two hero colours, since a
## Duo is a pair of heroes and must not look like either one of them.
const DUO_A := GOLD
const DUO_B := NAVY

## Per-ABILITY identity colour (Designer, 2026-07-26). Keyed by the ability's
## display name (Hero.ABILITY_INFO), not by hero: the colour belongs to STOMP,
## and everywhere STOMP appears — the battle card's cooldown bar, the prep
## menu's filled Duo slot — it is the same colour. Since each hero owns exactly
## one ability today the two keyings coincide, but this way a second ability
## does not inherit its owner's colour by accident.
##
## Green is excluded on purpose: the cooldown bar sits directly under the HP
## bar, which is green at full health, and two green bars on one card read as
## one control. Yellow is out for the same reason (HP's half-health colour) and
## VIOLET because it is the enemy pigment — which rules out both casters' own
## robe/scarf pigments, so CLONE and RALLY take the next colour off their
## hero's art instead:
##   STOMP    EMBER    Thundaar's tunic
##   CLONE    INFO     the legible lift of NAVY, next to Artemis's trousers
##   ENSNARE  BARK     Warden's bark
##   RALLY    MUSTARD  Designer's call, 2026-07-26 (was the staff-gem red)
const ABILITY_COLORS := {
	"STOMP": EMBER,
	"CLONE": INFO,
	"ENSNARE": BARK,
	"RALLY": MUSTARD,
}
## Fallback GOLD, so an unlisted ability still gets a non-green colour rather
## than the theme default.
static func ability_color(ability_name: String) -> Color:
	return ABILITY_COLORS.get(ability_name, GOLD)

## -- Currency ------------------------------------------------------------------
## Gold and XP are the two things the player counts, and they were written five
## different ways: "Gold: 40" in ink on the abilities page, "GOLD: 40" in gold
## on the battle HUD, "Shared Banked XP: 40" a size smaller on the stats page,
## plain body text on the results screen. One shape, one size, one colour each,
## everywhere (Designer, 2026-07-26).
##
## GOLD_COLOR/XP_COLOR are aliases rather than new pigments — the point is that
## every screen reaches for the SAME name, not that the colours changed.
const GOLD_COLOR := GOLD
const XP_COLOR := INFO
## The size every currency readout is set at. SUBHEAD: these are headline
## numbers on the screens that show them, not footnotes.
const SIZE_CURRENCY := SIZE_SUBHEAD

## "GOLD: 40" / "BANKED XP: 40" as a finished label — uppercase caption, value
## after a colon, in that currency's colour at SIZE_CURRENCY. `caption` lets a
## screen say BANKED XP (the persistent pool) vs XP (this run's gain) without
## inventing its own typography for it.
static func gold_label(amount: int, caption: String = "GOLD") -> RichTextLabel:
	return numeric_label("%s: %d" % [caption, amount], SIZE_CURRENCY, GOLD_COLOR, true)

static func xp_label(amount: int, caption: String = "XP") -> RichTextLabel:
	return numeric_label("%s: %d" % [caption, amount], SIZE_CURRENCY, XP_COLOR, true)

## The same pairing as BBCode, for the rich-text readouts that put a currency
## inline in a sentence (the results screen's payout lines).
static func gold_bbcode(text: String) -> String:
	return "[b][color=#%s]%s[/color][/b]" % [GOLD_COLOR.to_html(false), text]

static func xp_bbcode(text: String) -> String:
	return "[b][color=#%s]%s[/color][/b]" % [XP_COLOR.to_html(false), text]

## Progress-bar fill, used by every bar that isn't semantically coloured
## (villain HP, objective). LIME darkened just enough to hold an edge against
## the page it fills on.
const BAR_FILL := Color("9cba28")

# -- Type scale ---------------------------------------------------------------
## Named sizes so screens stop inventing 11/12/13/14/15/16/17/18/20/22/26/36/
## 40/44 ad hoc. Keep every new label on one of these.
##
## Sizes are in DESIGN-CANVAS pixels (1920x1080), but the game window runs at
## 1280x720 with stretch mode "canvas_items" — so everything is drawn at 0.67x
## and a nominal 18px label reached the player as ~12px. That is why the UI
## read as unusably small (Designer, 2026-07-25). The scale below is sized so
## the SMALLEST step still clears ~11 real pixels at 720p; divide any of these
## by 1.5 to see what the player actually gets.
##
## Second pass 2026-07-26 (Designer: "the font is not readable for small
## text"). The handwritten face has thin, uneven strokes, so it needs more
## pixels than a sans at the same nominal size — the bottom of the scale was
## landing at ~11 real pixels, below where DrawFont's letterforms stay legible.
## The small end moved up hardest (TINY 17 -> 22 = ~15 real px, SMALL 20 -> 25)
## and the compression between steps was kept, so the hierarchy still reads.
## If a screen overflows after this, give it room rather than shrinking text
## back below TINY.
const SIZE_TITLE := 58
const SIZE_HEADING := 44
const SIZE_SUBHEAD := 34
const SIZE_BODY := 27
const SIZE_SMALL := 25
const SIZE_TINY := 22

# -- Font ---------------------------------------------------------------------
## Handwritten display font (Caveat Brush, Pablo Impallari / Google Fonts —
## Designer, 2026-07-28). Replaced DrawFont, whose thin uneven strokes stayed
## hard to read at the small end of the scale even after the 2026-07-26 size
## bump. Caveat Brush is a brush-marker hand: heavier, more even strokes and
## only lightly connected, so it keeps the notebook voice while surviving the
## 0.67x canvas downscale.
##
## Licensed SIL OFL 1.1 (CaveatBrush-OFL.txt alongside the .ttf) — free to
## embed and ship, unlike the Brush Script MT this was originally speced as.
## Godot bakes the face into the .pck and renders it with its own TextServer,
## so the HTML5 export looks identical to desktop and never touches the
## browser's font stack.
##
## Drop the .ttf at this exact path and every Control in the game picks it up
## via ui_boot.gd; until then the engine default is used and nothing breaks.
const FONT_PATH := "res://assets/fonts/CaveatBrush-Regular.ttf"

static var _font_cache: Font = null
static var _font_checked := false

## The handwritten font, or null when the .ttf hasn't been added yet.
static func font() -> Font:
	if not _font_checked:
		_font_checked = true
		if ResourceLoader.exists(FONT_PATH):
			_font_cache = load(FONT_PATH) as Font
	return _font_cache

# -- Hand-drawn shapes --------------------------------------------------------

## Deliberately uneven corner radii — a hand-drawn box never closes square.
## `variant` picks one of a few pre-set wobbles so adjacent panels don't all
## share the identical silhouette; pass a stable value (e.g. an index) rather
## than something random per frame, or the shape will crawl on redraw.
## Scaled up alongside the type scale — at the old radii a bigger panel read
## as a sharp rectangle with the corners merely nicked off.
const CORNER_SETS := [
	[13, 18, 14, 17],
	[17, 13, 20, 14],
	[14, 20, 13, 18],
	[18, 14, 17, 13],
]

static func _wobble(style: StyleBoxFlat, variant: int) -> void:
	var c: Array = CORNER_SETS[posmod(variant, CORNER_SETS.size())]
	style.corner_radius_top_left = c[0]
	style.corner_radius_top_right = c[1]
	style.corner_radius_bottom_right = c[2]
	style.corner_radius_bottom_left = c[3]

## A notebook panel: paper fill, thick ink outline, wobbly corners.
static func panel(bg: Color = PAGE, border: Color = INK, border_width: int = 5,
		margin: int = 16, variant: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_content_margin_all(margin)
	_wobble(s, variant)
	return s

## A card sitting on the page — lighter paper, same ink outline. `accent`
## recolours the border (Duo boxes, boon picks, focused hero).
static func card(accent: Color = INK, margin: int = 20, variant: int = 0) -> StyleBoxFlat:
	return panel(CARD, accent, 4, margin, variant)

## Modal overlay panel (results, level-up) — heavier margin, opaque-ish paper.
static func overlay_panel(variant: int = 0) -> StyleBoxFlat:
	return panel(PAGE, INK, 5, 40, variant)

# -- Control factories --------------------------------------------------------
## These exist so a screen never has to remember the ink colour or the font.
## The project-wide theme already supplies both, so these mostly just set the
## size — but they keep call sites uniform and give one place to change.

static func label(text: String, size: int = SIZE_BODY, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func centered_label(text: String, size: int = SIZE_BODY, color: Color = INK) -> Label:
	var l := label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## Wrapped body text at a fixed column width — used for role/ability blurbs
## that were each re-implementing autowrap + custom_minimum_size.
static func wrapped_label(text: String, width: float, size: int = SIZE_TINY,
		color: Color = INK) -> Label:
	var l := centered_label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(width, 0)
	return l

## Synthetic bold of the hand-drawn font. DrawFont.ttf ships as a single
## weight, so there is no real bold face to load — FontVariation's embolden
## thickens the existing outlines instead, which is what a hand-drawn font
## going bold would look like anyway. Cached: one FontVariation shared by every
## label that asks, rather than one per built card.
static var _bold_font_cache: FontVariation = null
const BOLD_EMBOLDEN := 0.6

static func bold_font() -> FontVariation:
	if _bold_font_cache == null:
		_bold_font_cache = FontVariation.new()
		_bold_font_cache.base_font = font()
		_bold_font_cache.variation_embolden = BOLD_EMBOLDEN
	return _bold_font_cache

## -- Numeric readouts ----------------------------------------------------------
## Every digit the player reads comes out bold (Designer, 2026-07-26). DrawFont
## is a handwritten face whose "g" and "9" are near-identical at UI sizes, and
## the same goes for 1/l and 0/O — emboldening the numbers is what tells the
## player they are looking at a value and not a word.
##
## Godot cannot weight individual glyphs, so this is done with BBCode: a digit
## run gets wrapped in [b]…[/b] and rendered by a RichTextLabel whose bold_font
## is the synthetic FontVariation above. Plain Labels cannot do it at all, which
## is why the readouts that show numbers are RichTextLabels now.
##
## Runs include separators that are part of the number — a decimal point, a
## thousands comma, a clock colon — and a trailing percent sign, so "2.1",
## "0:07" and "45%" each bold as one unit instead of fragmenting.
##
## IMPORTANT: pass PLAIN text only. Given a string that already contains BBCode
## this would bold the digits inside the tags themselves (a #c19a1c colour code,
## a font size) and corrupt them. Lines that are already hand-authored BBCode
## bold their own numbers — see HeroDetailsPanel._attributes_block.
static func bold_numbers(text: String) -> String:
	var out := ""
	var i := 0
	var n := text.length()
	while i < n:
		if not _is_digit(text[i]):
			out += text[i]
			i += 1
			continue
		var start := i
		while i < n:
			if _is_digit(text[i]):
				i += 1
			# A separator only stays inside the run when a digit follows it, so
			# the period ending "Costs 40." is not swallowed into the number.
			elif text[i] in [".", ",", ":"] and i + 1 < n and _is_digit(text[i + 1]):
				i += 1
			else:
				break
		if i < n and text[i] == "%":
			i += 1
		out += "[b]%s[/b]" % text.substr(start, i - start)
	return out

static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"

static func _has_digit(text: String) -> bool:
	for i in text.length():
		if _is_digit(text[i]):
			return true
	return false

## A readout whose numbers bold themselves — the drop-in replacement for
## UIStyle.label()/centered_label() anywhere the text contains a value. Set its
## contents through set_numeric_text(), not .text, or the digits stay plain.
static func numeric_label(text: String, size: int = SIZE_BODY, color: Color = INK,
		centered := false) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("normal_font_size", size)
	l.add_theme_font_size_override("bold_font_size", size)
	l.add_theme_font_override("bold_font", bold_font())
	l.add_theme_color_override("default_color", color)
	l.set_meta("centered", centered)
	set_numeric_text(l, text)
	return l

## Rewrites a numeric_label's contents, re-bolding the digits. Also re-applies
## the [center] wrapper, which is part of the text rather than a property and so
## would be lost by a plain .text assignment.
static func set_numeric_text(target: RichTextLabel, text: String) -> void:
	if target == null:
		return
	var body := bold_numbers(text)
	target.text = "[center]%s[/center]" % body if target.get_meta("centered", false) else body

## Retrofits an already-built RichTextLabel (one authored in a .tscn) with the
## bold font and sizes numeric_label sets up, so scene-authored readouts behave
## like code-built ones.
static func make_numeric(target: RichTextLabel, size: int, color: Color = INK,
		centered := false) -> void:
	if target == null:
		return
	target.bbcode_enabled = true
	target.fit_content = true
	target.scroll_active = false
	target.autowrap_mode = TextServer.AUTOWRAP_OFF
	target.add_theme_font_size_override("normal_font_size", size)
	target.add_theme_font_size_override("bold_font_size", size)
	target.add_theme_font_override("bold_font", bold_font())
	target.add_theme_color_override("default_color", color)
	target.set_meta("centered", centered)

## Centered rich text with [b] wired to the synthetic bold above — for lines
## that need part of themselves emphasised (a stat readout boldening its
## numbers but not its labels). A plain Label would render the BBCode tags
## literally, hence RichTextLabel.
##
## fit_content + no autowrap so it behaves like a Label in a VBox: the row
## takes exactly the height of its one line.
static func rich_stat_label(bbcode: String, size: int = SIZE_TINY, color: Color = INK) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("normal_font_size", size)
	l.add_theme_font_size_override("bold_font_size", size)
	l.add_theme_font_override("bold_font", bold_font())
	l.add_theme_color_override("default_color", color)
	l.text = "[center]%s[/center]" % bbcode
	return l

## A Button cannot render BBCode, so a price button can't bold just its digits
## the way a readout can. When the label contains a number the WHOLE button goes
## bold instead (Designer's rule, 2026-07-26, applied as far as the widget
## allows) — on a button like "Buy Lv3 — 60g" the number is the point of the
## control anyway, so emboldening all of it reads as intended rather than as an
## accident. Buttons with no digits are untouched.
static func button(text: String, size: int = SIZE_BODY, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	if _has_digit(text):
		b.add_theme_font_override("font", bold_font())
	add_click_sound(b)
	if cb.is_valid():
		b.pressed.connect(cb)
	add_hover_wiggle(b)
	return b

## Side padding on a compact button, against the theme's 22. The theme value is
## tuned for standalone menu buttons ("START BATTLE") with a whole screen to sit
## in; inside a card it is pure overhead, and it was overflowing (Designer,
## 2026-07-28: "fix text box to better fit text on stats and abilities upgrade
## buttons").
##
## Measured, not guessed: at SIZE_TINY the widest real price label
## ("Buy Lv10 — 240g") needs 136px of glyphs, so the theme's 22+22 pushed the
## button's minimum to 207px inside a skill node whose usable width is 194 —
## the card was forced wider than NODE_SIZE and broke the grid pitch it is
## placed on. At 12+12 the same button needs 160 and fits with room to spare.
const COMPACT_BUTTON_PAD_X := 12
## Vertical padding goes UP, not down. Caveat Brush is a brush script whose
## descenders and flourishes overshoot the font's reported descent, so at the
## theme's 10 the tails of "y"/"g" grazed the border.
const COMPACT_BUTTON_PAD_Y := 12

## A button sized for life inside a card — same hand-drawn look and states as
## UIStyle.button, tighter horizontally and slightly roomier vertically. Use it
## for price/action chips in dense layouts (stat cards, skill-tree nodes);
## standalone buttons should stay on the theme's own metrics.
static func compact_button(text: String, size: int = SIZE_TINY,
		cb: Callable = Callable(), variant: int = 0) -> Button:
	var b := button(text, size, cb)
	# Rebuilt from the palette rather than duplicated off the theme: a Button
	# that is not in the tree yet cannot resolve theme styleboxes, and every
	# caller here builds its button before parenting it.
	var fills := {
		"normal": Color(PAGE_SOLID, 0.94),
		"hover": Color("e5eecd"),
		"pressed": Color("cfe0b0"),
		"disabled": Color(PAGE_SOLID, 0.45),
	}
	for state in fills:
		var s := panel(fills[state], INK, 4, 0, variant)
		s.content_margin_left = COMPACT_BUTTON_PAD_X
		s.content_margin_right = COMPACT_BUTTON_PAD_X
		s.content_margin_top = COMPACT_BUTTON_PAD_Y
		s.content_margin_bottom = COMPACT_BUTTON_PAD_Y
		if state == "disabled":
			s.border_color = Color(INK, 0.4)
		b.add_theme_stylebox_override(state, s)
	# Focus reuses hover so keyboard focus reads the same as mouse-over, matching
	# the theme's own Button/styles/focus = button_hover.
	b.add_theme_stylebox_override("focus", b.get_theme_stylebox("hover"))
	return b

## UI click (Designer, 2026-07-26). The source file opens with a sliver of dead
## air, so playback starts past it — otherwise the click lands audibly late
## against the press that triggered it.
const CLICK_SOUND: AudioStream = preload("res://assets/Sounds/Button_Click.mp3")
const CLICK_SOUND_START := 0.048

## Wires the click sound to a button's press. Applied automatically by button()
## and texture_button(); call it directly for any other BaseButton.
##
## Connected BEFORE the button's own callback, and that order is load-bearing:
## half the buttons in this game change scene or free their own overlay, and
## Godot fires `pressed` handlers in connection order — wired afterwards, the
## sound would be requested from a node that had just left the tree, and
## BattleSfx would (correctly) drop it. The player itself is parented to the
## scene root, so it still finishes playing after the button is gone.
static func add_click_sound(b: BaseButton) -> void:
	b.pressed.connect(func() -> void:
		BattleSfx.play_clip(b, CLICK_SOUND, CLICK_SOUND_START))

## Hover feedback: a small tilt-and-swell the moment the pointer lands, easing
## back out when it leaves (Designer, 2026-07-26: "buttons should have a
## mouse-over effect, at least make it wiggle a bit"). Hand-drawn UI already
## implies a wobble, so the motion is a rotation rather than a colour change —
## it reads as the paper being nudged.
##
## Applied automatically by button() and texture_button(); call it directly for
## any other Control that should feel clickable.
const HOVER_TILT_DEG := 1.6
const HOVER_SCALE := 1.045
const HOVER_TIME := 0.12

static func add_hover_wiggle(c: Control) -> void:
	# Rotation and scale both work off pivot_offset, which defaults to the
	# top-left — without re-centring it every hover would swing the button
	# around its own corner. Re-set on resize because the size is 0 here, at
	# build time, and only becomes real once its container lays it out.
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	c.mouse_entered.connect(func() -> void:
		# A disabled button must not answer the pointer — wiggling one reads as
		# "this does something" when it doesn't.
		if c is Button and (c as Button).disabled:
			return
		_wiggle_to(c, HOVER_TILT_DEG, HOVER_SCALE))
	c.mouse_exited.connect(func() -> void: _wiggle_to(c, 0.0, 1.0))

static func _wiggle_to(c: Control, tilt_deg: float, scale_to: float) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	# One tween per hover, killing any in flight, so fast pointer sweeps across
	# a row of buttons can't leave one stuck mid-tilt.
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "rotation", deg_to_rad(tilt_deg), HOVER_TIME)
	tw.tween_property(c, "scale", Vector2.ONE * scale_to, HOVER_TIME)

## Hand-drawn button art cropped out of a shared sheet (the NEW GAME /
## CONTINUE / START RUN PNGs), scaled to `target_width` at the region's own
## aspect ratio. Was duplicated in title_screen.gd and prep_menu.gd.
static func texture_button(texture: Texture2D, region: Rect2, target_width: float,
		cb: Callable = Callable()) -> TextureButton:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	var b := TextureButton.new()
	b.texture_normal = atlas
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(target_width, target_width / (region.size.x / region.size.y))
	add_click_sound(b)
	if cb.is_valid():
		b.pressed.connect(cb)
	add_hover_wiggle(b)
	return b

## Hero portrait for menus — the actual in-battle sprite (Hero.sprite_for), so
## the roster art and the field art are literally the same drawing. Replaces
## the flat ColorRect swatches the prep cards used to show.
##
## Mirrored, like the battle card's portrait (HeroPanelUI.PORTRAIT_FACES_RIGHT):
## a hero shown STILL always faces east (Designer, 2026-07-30) and the source art
## follows Combatant's face-left house convention, so every menu that shows a
## hero flips it. The live unit on the battlefield is deliberately not pinned —
## it turns to face where it is going.
static func hero_portrait(hero_name: String, box: Vector2 = Vector2(120, 96)) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Hero.sprite_for(hero_name)
	t.flip_h = true
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = box
	return t

## Faded-out treatment for anything unavailable (locked hero, disabled button,
## dead hero panel) — one opacity instead of the 0.4/0.4/0.85 spread.
const DIM := Color(1, 1, 1, 0.4)
