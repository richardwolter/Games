## Store art for the itch.io page, painted out of the game's own sprites.
##
##   godot --headless --script tools/make_itch_art.gd
##
## Two images, both written to build/itch/:
##
##   page_background.png   2560x1440, sits behind the whole itch page. The page's
##                         content column is centred and roughly a thousand px
##                         wide, so the middle has to stay quiet — anything
##                         painted there is either hidden behind the column or
##                         fighting the text beside it. The junk goes down the
##                         two sides, and the middle is dimmed further so light
##                         text reads over it wherever the column doesn't reach.
##
##   embed_background.png  1280x720, the game frame before the player clicks
##                         play. Same aspect as the viewport, so it reads as the
##                         game waiting rather than as a poster. The play button
##                         lands dead centre, so the bridge is built across the
##                         lower third and the sky above it is left empty.
##
## Both are composed from art/background.png and the real piece sprites rather
## than drawn fresh, so the store page cannot drift away from what the game
## actually looks like — change the backdrop, rebuild, and the page follows.
extends SceneTree

const BACKDROP := "res://art/background.png"
const ART := "res://art/"
const OUT_DIR := "res://build/itch/"

## Where the horizon sits in the backdrop, top to bottom. Same figure as
## Backdrop.horizon_frac — if that moves, this has to move with it or the pieces
## float above the waterline.
const BACKDROP_HORIZON := 0.55

const PAGE_SIZE := Vector2i(2560, 1440)
const EMBED_SIZE := Vector2i(1280, 720)

## How far down each output the waterline lands, and how far the backdrop is
## magnified to allow it.
##
## Left to the cover-crop, the horizon lands wherever it was painted — 0.55, near
## enough the middle, which splits both pictures in half and gives the bottom
## one to flat water. Pushing it down buys sky for the sun and the mountains and
## costs only water nobody was looking at. The zoom is what makes the room: at
## 1.0 the backdrop exactly fills the height and there is nothing to slide.
const PAGE_WATERLINE := 0.62
const EMBED_WATERLINE := 0.66
const ZOOM := 1.28

## The strait, taken from shaders/water.gdshader so the two cannot disagree.
##
## art/background.png is only sky and mountains — the game paints no water into
## its backdrop, it lays a translucent overlay over everything below the surface
## at runtime. Reproducing that here rather than compositing onto a painted sea
## is what makes a half-sunk barrel look half-sunk: the same sprite is simply
## tinted from the waterline down.
const SHALLOW := Color(0.24, 0.55, 0.66)
const SHALLOW_ALPHA := 0.55
const DEEP := Color(0.07, 0.18, 0.30)
const DEEP_ALPHA := 0.86
const FOAM := Color(0.72, 0.88, 0.92)


## One piece in a composition: which sprite, where its centre goes as a fraction
## of the output, how tall it is as a fraction of the output height, and how far
## it is tipped over. Fractions rather than pixels so the same layout describes
## both sizes.
class Piece:
	var art: String
	var at: Vector2
	var height: float
	var angle: float
	var dim: float

	func _init(a: String, x: float, y: float, h: float, deg: float, d: float = 0.0) -> void:
		art = a
		at = Vector2(x, y)
		height = h
		angle = deg_to_rad(deg)
		dim = d


func _initialize() -> void:
	var backdrop := Image.load_from_file(ProjectSettings.globalize_path(BACKDROP))
	if backdrop == null:
		print("missing: %s" % BACKDROP)
		quit()
		return
	backdrop.convert(Image.FORMAT_RGBA8)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	_render(backdrop, PAGE_SIZE, PAGE_WATERLINE, _page_layout(), true, "page_background.png")
	_render(backdrop, EMBED_SIZE, EMBED_WATERLINE, _embed_layout(), false, "embed_background.png")
	quit()


## The page: two loaded shores facing each other across an empty middle.
##
## Everything is kept outside the middle 44% of the width. That band is where the
## itch content column sits, and a plank crossing it would be sliced in half by
## the column's own edge — which looks like a rendering fault rather than like a
## design.
##
## The two sides are deliberately not mirrored. A pile of junk that is
## symmetrical reads as wallpaper; one side heavier than the other reads as a
## bridge someone is halfway through building, which is the game.
func _page_layout() -> Array[Piece]:
	return [
		# Left shore: the heavy end, stacked and spilling into the water.
		Piece.new("refrigerator", 0.055, 0.545, 0.20, -8.0),
		Piece.new("crate", 0.135, 0.595, 0.13, 4.0),
		Piece.new("barrel", 0.205, 0.620, 0.11, -14.0),
		Piece.new("plank", 0.145, 0.512, 0.035, -12.0),
		Piece.new("beam", 0.238, 0.548, 0.036, 7.0),
		Piece.new("tire", 0.085, 0.660, 0.085, 0.0),
		Piece.new("crate", 0.258, 0.672, 0.10, -6.0, 0.22),
		Piece.new("plank_3", 0.315, 0.605, 0.030, 16.0, 0.30),
		Piece.new("barrel_2", 0.045, 0.712, 0.095, 9.0, 0.34),

		# The truck, parked at the head of the left shore looking across. It is
		# the only thing in the picture with a face, so it goes where a reader's
		# eye lands first and points at the gap.
		Piece.new("car", 0.185, 0.470, 0.105, -4.0),

		# Right shore: lighter, further off, more of it in the water than on it.
		Piece.new("pontoon", 0.845, 0.600, 0.030, 5.0),
		Piece.new("girder", 0.895, 0.556, 0.032, -10.0),
		Piece.new("barrel_4", 0.945, 0.600, 0.10, 12.0),
		Piece.new("crate", 0.795, 0.640, 0.105, -5.0, 0.18),
		Piece.new("raft", 0.745, 0.616, 0.026, 3.0, 0.26),
		Piece.new("tire", 0.885, 0.682, 0.075, 0.0, 0.30),
		Piece.new("plank_5", 0.955, 0.512, 0.032, -18.0, 0.20),
		Piece.new("barrel_3", 0.775, 0.700, 0.085, -7.0, 0.38),
	]


## The embed: one ramshackle span across the bottom, sky left empty above it.
##
## The pieces climb from the left shore, sag through the middle and come up
## again — a bridge that is clearly holding, and just as clearly should not be.
## Nothing rises above 0.46 of the height, which keeps the whole upper half free
## for the play button and whatever chrome itch draws around it.
func _embed_layout() -> Array[Piece]:
	return [
		Piece.new("crate", 0.075, 0.615, 0.155, 3.0),
		Piece.new("barrel", 0.170, 0.640, 0.130, -11.0),
		Piece.new("plank", 0.270, 0.612, 0.042, -7.0),
		# These two are the longest sprites in the set and at this scale each is a
		# fifth of the width, so they have to be spaced by their span rather than
		# by their centres — closer together they overlap into one grey smear.
		Piece.new("pontoon", 0.355, 0.648, 0.038, 4.0),
		Piece.new("beam", 0.570, 0.664, 0.040, 2.0),
		Piece.new("raft", 0.650, 0.656, 0.032, -3.0),
		Piece.new("girder", 0.765, 0.628, 0.038, 8.0),
		Piece.new("barrel_2", 0.860, 0.645, 0.120, 6.0),
		Piece.new("refrigerator", 0.945, 0.600, 0.200, -6.0),
		Piece.new("tire", 0.335, 0.700, 0.090, 0.0, 0.20),
		Piece.new("tire", 0.705, 0.712, 0.080, 0.0, 0.26),
		Piece.new("crate", 0.475, 0.740, 0.110, -9.0, 0.34),

		# The truck, up on the first crate at the near end. Small, because the
		# joke is the size of the gap in front of it.
		Piece.new("car", 0.122, 0.484, 0.115, -5.0),
	]


func _render(
	backdrop: Image,
	size: Vector2i,
	waterline: float,
	layout: Array[Piece],
	dim_middle: bool,
	name: String
) -> void:
	var out := _cover(backdrop, size, waterline)

	for piece: Piece in layout:
		var sprite := Image.load_from_file(
			ProjectSettings.globalize_path(ART + piece.art + ".png")
		)
		if sprite == null:
			print("  missing sprite: %s" % piece.art)
			continue
		sprite.convert(Image.FORMAT_RGBA8)
		_stamp(out, sprite, size, piece)

	# After the pieces, never before. The water goes OVER them exactly as the
	# shader does in game, which is the whole reason a piece can be half in it.
	_flood(out, waterline)

	if dim_middle:
		_dim_middle(out)

	var path := OUT_DIR + name
	out.save_png(ProjectSettings.globalize_path(path))
	print("%s  %dx%d  (%d pieces)" % [path, size.x, size.y, layout.size()])


## The backdrop scaled to cover the output, cropped so its horizon lands where
## the composition wants it.
##
## Scaled by whichever axis needs the most and then magnified by ZOOM, which is
## what leaves slack to slide vertically — without it the backdrop exactly fills
## the height and the horizon can only be where it was painted. Horizontally it
## stays centred, because the sun is painted in the middle and it is the one
## thing in the picture that must not drift.
func _cover(backdrop: Image, size: Vector2i, waterline: float) -> Image:
	var src := backdrop.duplicate() as Image
	var factor: float = maxf(
		float(size.x) / float(src.get_width()), float(size.y) / float(src.get_height())
	) * ZOOM
	var scaled := Vector2i(
		int(ceil(float(src.get_width()) * factor)),
		int(ceil(float(src.get_height()) * factor))
	)
	src.resize(scaled.x, scaled.y, Image.INTERPOLATE_LANCZOS)

	# Slide so the painted horizon sits at `waterline`, then clamp — asking for
	# more sky than the picture has would otherwise crop past the top edge and
	# blit a transparent band.
	var painted: float = float(scaled.y) * BACKDROP_HORIZON
	var top: int = clampi(
		int(painted - waterline * float(size.y)), 0, maxi(scaled.y - size.y, 0)
	)

	var out := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(
		src, Rect2i((scaled.x - size.x) / 2, top, size.x, size.y), Vector2i.ZERO
	)
	return out


## Draw one sprite, scaled and rotated, onto the output.
##
## Done by hand rather than with blit_rect because these have to be tipped over.
## A bridge of pieces all sitting perfectly level is the one arrangement that
## looks deliberate, and deliberate is the opposite of what the picture is for.
##
## The loop walks the DESTINATION rectangle and reads backwards through the
## rotation into the source. Walking the source instead leaves unwritten pixels
## between the ones it lands on — a rotated sprite full of holes.
func _stamp(dst: Image, src: Image, size: Vector2i, piece: Piece) -> void:
	var wanted: float = piece.height * float(size.y)
	var factor: float = wanted / float(src.get_height())
	var half := Vector2(float(src.get_width()), float(src.get_height())) * 0.5
	var centre := Vector2(piece.at.x * float(size.x), piece.at.y * float(size.y))

	# The destination box: the sprite's own corners, rotated, then bounded. A
	# rotated rectangle needs more room than it started with, and clipping to the
	# unrotated size shaves the corners off.
	var reach: float = half.length() * factor + 2.0
	var from := Vector2i(
		maxi(int(centre.x - reach), 0), maxi(int(centre.y - reach), 0)
	)
	var to := Vector2i(
		mini(int(centre.x + reach), size.x - 1), mini(int(centre.y + reach), size.y - 1)
	)

	# Inverse rotation, because the walk is destination to source.
	var cos_a: float = cos(-piece.angle)
	var sin_a: float = sin(-piece.angle)
	var keep: float = 1.0 - clampf(piece.dim, 0.0, 1.0)

	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			var offset := Vector2(float(x), float(y)) - centre
			var local := Vector2(
				offset.x * cos_a - offset.y * sin_a, offset.x * sin_a + offset.y * cos_a
			) / factor + half
			if local.x < 0.0 or local.y < 0.0:
				continue
			if local.x >= float(src.get_width()) or local.y >= float(src.get_height()):
				continue
			var texel := src.get_pixel(int(local.x), int(local.y))
			if texel.a <= 0.004:
				continue

			# Distance dims a piece towards the water's own colour rather than
			# towards black: these sit in front of a painted strait, and a grey
			# barrel on blue-green water reads as a hole in the picture.
			var under := dst.get_pixel(x, y)
			var shade := texel.lerp(Color(under.r, under.g, under.b, texel.a), 1.0 - keep)
			dst.set_pixel(x, y, under.lerp(Color(shade.r, shade.g, shade.b, 1.0), texel.a))


## Lay the strait over everything below the waterline.
##
## The surface is not a straight line. A ruled horizontal edge across a picture
## made entirely of hand-painted sprites is the one element that would read as
## having been done in a different program — so it carries a shallow two-wave
## wobble, the same shape the water shader runs at rest, and a foam edge sitting
## on it.
func _flood(image: Image, waterline: float) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var surface: float = float(height) * waterline
	var swell: float = float(height) * 0.010
	var foam_depth: float = maxf(float(height) * 0.007, 3.0)

	for x in width:
		var across: float = float(x) / float(width)
		# Two waves rather than one, at an irrational ratio, so the surface never
		# repeats across the width and cannot be read as a sine.
		var wave: float = sin(across * TAU * 2.0) * 0.6 + sin(across * TAU * 5.3 + 1.7) * 0.4
		var top: float = surface + wave * swell
		var span: float = maxf(float(height) - top, 1.0)

		for y in range(int(top), height):
			var under: float = float(y) - top
			var depth: float = clampf(under / span, 0.0, 1.0)
			# Square-rooted, so the colour turns over quickly just under the
			# surface and then settles. Linear left the whole strait the same
			# mid-teal and lost the sense of it having a bottom.
			var tint := SHALLOW.lerp(DEEP, sqrt(depth))
			var alpha: float = lerpf(SHALLOW_ALPHA, DEEP_ALPHA, depth)
			var pixel := image.get_pixel(x, y)
			var wet := pixel.lerp(tint, alpha)
			# The foam edge, brightest at the surface and gone within a few px.
			if under < foam_depth:
				wet = wet.lerp(FOAM, (1.0 - under / foam_depth) * 0.72)
			image.set_pixel(x, y, Color(wet.r, wet.g, wet.b, 1.0))


## Push the middle of the page background down and towards neutral.
##
## Two jobs. It clears a quiet strip for the itch content column to sit on, and
## it stops the join between the column and the picture being a hard vertical
## edge — the fall-off is a raised cosine across nearly half the width, so there
## is no line to see anywhere.
func _dim_middle(image: Image) -> void:
	const REACH := 0.30
	const DEEPEST := 0.55
	var width := image.get_width()
	var height := image.get_height()
	var centre: float = float(width) * 0.5
	var span: float = float(width) * REACH

	for x in width:
		var away: float = absf(float(x) - centre) / span
		if away >= 1.0:
			continue
		# Raised cosine: flat at the centre and flat where it lands, so neither
		# end of the fall-off shows as a band.
		var amount: float = DEEPEST * 0.5 * (1.0 + cos(away * PI))
		for y in height:
			var pixel := image.get_pixel(x, y)
			var luma: float = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114
			# Towards its own grey, not towards black: the backdrop keeps its
			# light and shade, it just stops competing for attention.
			var flat := Color(luma, luma, luma).darkened(0.45)
			image.set_pixel(x, y, pixel.lerp(flat, amount))
