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

# -- Palette ------------------------------------------------------------------

## Notebook page. PAGE_SOLID is the opaque paper the battlefield and prep
## screens draw; PAGE is the same colour at overlay opacity, for modal panels
## that sit on top of the battle.
const PAGE_SOLID := Color("f4efe1")
const PAGE := Color("f4efe1f0")
## Translucent paper for cards laid ON a page — was Color(1,1,1,0.5) in four
## different files, which read as a grey-white sticker rather than paper.
const CARD := Color("f4efe1a8")
const CARD_STRONG := Color("f4efe1d0")

## The one ink. Body text, outlines, borders — all of it.
const INK := Color("2c2c2c")
## Secondary/footnote text (lifetime stats, hints). Ink, just lighter.
const INK_MUTED := Color("2c2c2c99")
## Ruled lines and the red margin rule of the notebook page.
const RULE := Color("aac4dd")
const MARGIN := Color("d98f8f")

## Accents. GOLD is the highlight/pick colour (boons, focus, unlocks, Duo A),
## TEAL the second Duo, and the three status colours read as pencil-crayon.
const GOLD := Color("b08a3e")
const TEAL := Color("2c8f7a")
const DANGER := Color("c63d3d")
const GOOD := Color("5c7a3f")
const INFO := Color("6fa8dc")

const DUO_A := GOLD
const DUO_B := TEAL

## Progress-bar fill (pencil green), used by every bar that isn't semantically
## coloured (villain HP, objective).
const BAR_FILL := Color("a3c06f")

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
const SIZE_TITLE := 56
const SIZE_HEADING := 42
const SIZE_SUBHEAD := 32
const SIZE_BODY := 24
const SIZE_SMALL := 20
const SIZE_TINY := 17

# -- Font ---------------------------------------------------------------------
## Handwritten display font (DrawFont, dafont.com — Designer, 2026-07-25).
## Drop the .ttf at this exact path and every Control in the game picks it up
## via ui_boot.gd; until then the engine default is used and nothing breaks.
const FONT_PATH := "res://assets/fonts/DrawFont.ttf"

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

static func button(text: String, size: int = SIZE_BODY, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

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
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

## Hero portrait for menus — the actual in-battle sprite (Hero.sprite_for), so
## the roster art and the field art are literally the same drawing. Replaces
## the flat ColorRect swatches the prep cards used to show.
static func hero_portrait(hero_name: String, box: Vector2 = Vector2(120, 96)) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Hero.sprite_for(hero_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = box
	return t

## Faded-out treatment for anything unavailable (locked hero, disabled button,
## dead hero panel) — one opacity instead of the 0.4/0.4/0.85 spread.
const DIM := Color(1, 1, 1, 0.4)
