## Small pixel-art wood-plank pieces, drawn once into textures rather than loaded from a
## sheet. Nothing here is baked art: every pixel is placed by this file from the wood tones in
## style.gd, so the look changes by changing those rather than by repainting a PNG. Built for
## the settings panel first, but kept apart from lake.gd because the shop board and the shed
## room are meant to pick up the same pieces once this pass reaches them.
##
## Style reference: the wood-plank UI kit Richard shared (close button, slider track/thumb,
## toggle, text button, empty plank, and a composed settings mockup) — a reference for the
## look only, not a sprite sheet; there was no real PNG to slice, so this rebuilds the pieces
## it describes in code.
class_name WoodUI
extends RefCounted

## The tones every piece is built from: the plank itself, a lit edge, a dark edge, and the
## ink between planks. Callers can pass their own for a lighter or darker variant (a button's
## hover state, say) but these are the one wood the whole panel should read as.
##
## They are aliases now, not values. The wood is decided once in style.gd, for the drawn
## surfaces as well as these stylebox ones; these names stay because every caller in the game
## already spells the wood this way.
const Style := preload("res://scripts/style.gd")
const PLANK := Style.WOOD
const PLANK_LIGHT := Style.WOOD_LIT
const PLANK_DARK := Style.WOOD_DEEP
const SEAM := Style.SEAM

## The highlight line along a lit edge. It used to be a `.lightened()` call written out at
## each of the three places that wanted it, with a different amount at one of them, so no two
## lit edges in the kit were the same colour.
const PLANK_PALE := Style.WOOD_PALE


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var w_i := img.get_width()
	var h_i := img.get_height()
	for yy in range(y, y + h):
		if yy < 0 or yy >= h_i:
			continue
		for xx in range(x, x + w):
			if xx < 0 or xx >= w_i:
				continue
			img.set_pixel(xx, yy, c)


## A tileable plank patch: a base fill, a lit edge along the top and left, a dark edge along
## the bottom and right, and a few grain flecks so it does not read as a flat colour once it
## is repeated across a whole panel.
static func plank_tile(w: int, h: int, base: Color, light: Color, dark: Color, seed: int) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	_rect(img, 0, 0, w, h, base)
	_rect(img, 0, 0, w, 1, light)
	_rect(img, 0, 0, 1, h, light)
	_rect(img, 0, h - 1, w, 1, dark)
	_rect(img, w - 1, 0, 1, h, dark)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var flecks := maxi(2, (w * h) / 30)
	for i in flecks:
		var fx := rng.randi_range(1, maxi(1, w - 2))
		var fy := rng.randi_range(1, maxi(1, h - 2))
		var tone := dark if rng.randf() < 0.5 else light
		img.set_pixel(fx, fy, tone.lerp(base, 0.5))
	return ImageTexture.create_from_image(img)


## A resizable wood-plank background: a plank_tile repeated across the panel, with a frame of
## margins so the bevel and flecks the tile draws stay a fixed pixel width at any panel size
## instead of stretching wider as the panel grows.
static func panel_style(margin: int, base: Color, light: Color, dark: Color, seed: int) -> StyleBoxTexture:
	var tile_size := margin * 4
	var box := StyleBoxTexture.new()
	box.texture = plank_tile(tile_size, tile_size, base, light, dark, seed)
	box.texture_margin_left = margin
	box.texture_margin_top = margin
	box.texture_margin_right = margin
	box.texture_margin_bottom = margin
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return box


## A two-position wood switch for CheckButton's "on"/"off" theme icons: a track the size of
## the whole icon and a thumb block pushed to whichever side is active.
static func switch_icon(on: bool, w: int = 34, h: int = 16) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	_rect(img, 0, 0, w, h, SEAM)
	_rect(img, 1, 1, w - 2, h - 2, PLANK_DARK)
	var thumb_w := h - 2
	var thumb_x := (w - h + 1) if on else 1
	_rect(img, thumb_x, 1, thumb_w, h - 2, PLANK_LIGHT)
	_rect(img, thumb_x, 1, thumb_w, 1, PLANK_PALE)
	return ImageTexture.create_from_image(img)


## The groove a slider's fill sits in, and the fill itself — the same plank patch, dark for
## the empty track and lit for the played portion, so the two read as one grooved plank
## rather than two unrelated bars.
static func slider_groove() -> StyleBoxTexture:
	return panel_style(3, PLANK_DARK, PLANK, SEAM, 3)


static func slider_fill() -> StyleBoxTexture:
	return panel_style(3, PLANK_LIGHT, PLANK_PALE, PLANK, 4)


## The small block that rides the slider: a plank square with its own lit top edge, distinct
## enough from the groove underneath it to read as a separate piece.
static func slider_thumb(size: int = 14) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	_rect(img, 0, 0, size, size, SEAM)
	_rect(img, 1, 1, size - 2, size - 2, PLANK_LIGHT)
	_rect(img, 1, 1, size - 2, 1, PLANK_PALE)
	return ImageTexture.create_from_image(img)
