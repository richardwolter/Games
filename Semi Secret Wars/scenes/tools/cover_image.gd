extends Node
## Bakes the game's cover image (Designer, 2026-07-26) from assets already in
## the project — no new art. Run this scene and it writes OUTPUT_PATH, prints
## the path, and quits.
##
## Composition, top to bottom:
##   * the notebook page every menu already uses (PrepPage), which brings its
##     own ruled paper, scribbles, bloodstains and scenery props with it — so
##     the cover is literally the same page the game is played on;
##   * the hand-drawn logo;
##   * a row of hero portraits cropped to their FACES.
##
## The face boxes are authored per hero (FACE_BOXES). An automatic version of
## this was tried first — take the opaque bounding box, crop its top third — and
## it failed on exactly the units that matter: Thundaar's raised hammer and
## Beacon's staff-sun sit ABOVE their heads and beside them, so the "head band"
## measured nearly the full sprite width and the crop zoomed back out to a whole
## body. Four hand-placed rectangles are both correct and re-checkable by eye.
##
## Rendered through a SubViewport at exactly COVER_SIZE rather than screenshotting
## the window: the game window is 1280x720 and the cover is 630x500, and a
## resized screenshot would resample the hand-drawn linework.

const COVER_SIZE := Vector2i(630, 500)
const OUTPUT_PATH := "res://assets/Cover_630x500.png"

const LOGO := preload("res://assets/sprites/Logo_Semi-Secret-Wars.png")

## Heroes on the cover, left to right. Four of them — the whole roster, and the
## row balances the logo's width above it.
const COVER_HEROES: Array[String] = ["THUNDAAR", "ARTEMIS", "WARDEN", "BEACON"]

## -- Layout (design pixels, in COVER_SIZE space) -------------------------------
const LOGO_WIDTH := 404.0
const LOGO_TOP := 2.0
## Portrait row. Four squares plus three gaps, centred.
const FACE_SIZE := 118.0
const FACE_GAP := 16.0
const FACE_TOP := 358.0
## Ink border thickness on each portrait card.
const FACE_BORDER := 4

## -- Face crop -----------------------------------------------------------------
## Head box per hero, in SOURCE PIXELS on the shared 936x601 sprite canvas that
## all four hero PNGs use (verified, not assumed — if a sprite is ever redrawn
## on a different canvas these need revisiting, hence SPRITE_CANVAS below as the
## tripwire).
##
## Each box is square and centred on the face, sized to include the headgear
## that identifies the hero — Thundaar's horned helm, Artemis's hood, Beacon's
## crown — but not the weapon above it.
const SPRITE_CANVAS := Vector2i(936, 601)
const FACE_BOXES := {
	"THUNDAAR": Rect2i(418, 45, 165, 165),
	"ARTEMIS": Rect2i(452, 8, 165, 165),
	"WARDEN": Rect2i(348, 0, 128, 128),
	"BEACON": Rect2i(430, 118, 180, 180),
}

func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = COVER_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	viewport.add_child(_build_cover())

	# Two frames: one for the layout pass to resolve every Control's rect, one
	# for the renderer to actually draw it. Capturing after a single frame gives
	# a half-laid-out page.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var image := viewport.get_texture().get_image()
	var err := image.save_png(OUTPUT_PATH)
	if err == OK:
		print("Cover written: %s (%dx%d)" % [OUTPUT_PATH, image.get_width(), image.get_height()])
	else:
		push_error("Cover save failed (%d): %s" % [err, OUTPUT_PATH])
	get_tree().quit()

func _build_cover() -> Control:
	var root := Control.new()
	root.size = Vector2(COVER_SIZE)

	# The menus' own page — ruled paper, margin rule, scribbles, stains and
	# scenery props, all scaled down to this canvas by PrepPage itself.
	var page := PrepPage.new()
	page.size = Vector2(COVER_SIZE)
	root.add_child(page)

	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var logo_height := LOGO_WIDTH * float(LOGO.get_height()) / float(LOGO.get_width())
	logo.position = Vector2((float(COVER_SIZE.x) - LOGO_WIDTH) * 0.5, LOGO_TOP)
	logo.size = Vector2(LOGO_WIDTH, logo_height)
	root.add_child(logo)

	var row_width := COVER_HEROES.size() * FACE_SIZE + (COVER_HEROES.size() - 1) * FACE_GAP
	var x := (float(COVER_SIZE.x) - row_width) * 0.5
	for i in COVER_HEROES.size():
		# The right half of the row faces inward. Hero art follows Combatant's
		# face-left house convention, so the left two already look toward the
		# centre and only the right two need mirroring — the row reads as the
		# party facing each other rather than all four staring off-page.
		var face := _face_card(COVER_HEROES[i], i >= COVER_HEROES.size() / 2)
		face.position = Vector2(x + i * (FACE_SIZE + FACE_GAP), FACE_TOP)
		root.add_child(face)
	return root

## One portrait: the hero's face cropped out of their battlefield sprite, on a
## paper card with the same ink border every card in the game carries.
func _face_card(hero_name: String, flip: bool) -> Control:
	var card := PanelContainer.new()
	card.size = Vector2(FACE_SIZE, FACE_SIZE)
	# Content margin = border width, so the portrait stops at the inside edge of
	# the frame instead of painting over it (Beacon's dark hair reached the card
	# edge and swallowed the border on the first bake).
	card.add_theme_stylebox_override("panel",
			UIStyle.panel(UIStyle.CARD_STRONG, UIStyle.ability_color(
					Hero.ability_name_for(hero_name)), FACE_BORDER, FACE_BORDER,
					hero_name.length()))

	# clip_contents so a face slightly larger than its card is cropped by the
	# card instead of spilling over its neighbour.
	var frame := Control.new()
	frame.clip_contents = true
	card.add_child(frame)

	var portrait := TextureRect.new()
	portrait.texture = _face_texture(hero_name)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.flip_h = flip
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(portrait)
	return card


## An AtlasTexture over just this hero's face. Falls back to the whole sprite
## when the hero has no authored box, or when the sprite is not on the canvas
## FACE_BOXES was measured against — a silently mis-cropped face would be worse
## than an un-zoomed one.
func _face_texture(hero_name: String) -> Texture2D:
	var tex := Hero.sprite_for(hero_name)
	if tex == null:
		return null
	if not FACE_BOXES.has(hero_name):
		push_warning("No face box for %s — using the full sprite." % hero_name)
		return tex
	if tex.get_size() != Vector2(SPRITE_CANVAS):
		push_warning("%s is %s, not the %s FACE_BOXES were measured on — using the full sprite."
				% [hero_name, tex.get_size(), SPRITE_CANVAS])
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(FACE_BOXES[hero_name])
	return atlas
