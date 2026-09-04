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
		Piece.new("truck", 0.185, 0.462, 0.120, -4.0),

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
		Piece.new("truck", 0.122, 0.474, 0.132, -5.0),
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
		# "truck" is assembled rather than loaded — see _truck().
		var sprite := _truck() if piece.art == "truck" else _load(ART + piece.art + ".png")
		if sprite == null:
			continue
		_stamp(out, sprite, size, piece)

	# After the pieces, never before. The water goes OVER them exactly as the
	# shader does in game, which is the whole reason a piece can be half in it.
	_flood(out, waterline)

	if dim_middle:
		_dim_middle(out)

	var path := OUT_DIR + name
	out.save_png(ProjectSettings.globalize_path(path))
	print("%s  %dx%d  (%d pieces)" % [path, size.x, size.y, layout.size()])


## The truck, assembled the way scenes/car.tscn assembles it.
##
## art/car.png is NOT this vehicle. It is the little pickup on the title logo and
## it is the only place that sprite is still used — the truck the player actually
## watches fall in the water is a monster truck built at runtime from car_body,
## two car_tire, and a driver behind a punched-out cab window. Using car.png here
## put a vehicle on the store page that appears nowhere in the game.
##
## Every measurement below is lifted from car.tscn and driver.gd rather than
## eyeballed, so the proportion that makes the format read — the wheelbase
## measured in tyre radii — survives. Change the scene and this has to follow;
## there is no way to derive one from the other short of running the game.
const TRUCK_PX := 4.0
## Sprite scale and centre offset of the body, in world units.
const BODY_SCALE := 0.339
const BODY_AT := Vector2(0.0, -50.0)
## Axle half-spacing, and the tyre's drawn diameter — radius 38, oversized 2% by
## Wheel.SPRITE_OVERSCALE so the rubber covers its own collision circle.
const AXLE_X := 74.0
const TYRE_DIAMETER := 38.0 * 2.0 * 1.02
## The driver, from driver.gd's own defaults. He is behind the body, showing
## through the window punched in it — leave him out and the cab is a hole with
## the sunset visible through it.
const CAB_RECT := Rect2(-15.0, -97.0, 46.0, 35.0)
const CAB_COLOUR := Color("2b2724")
const DRIVER_AT := Vector2(20.0, -68.0)
const DRIVER_SCALE := 0.073
const DRIVER_VISIBLE := 0.62
const HEAD_AT := Vector2(16.0, -74.0)
const HEAD_RADIUS := 9.0
const HEAD_SKIN := Color("e0a878")
const HEAD_CAP := Color("d8892f")


func _truck() -> Image:
	# The bounding box, in world units: the body is wider than the axles and the
	# tyres reach lower than anything else.
	var half_body := Vector2(715.0, 339.0) * BODY_SCALE * 0.5
	var left: float = -half_body.x
	var top: float = BODY_AT.y - half_body.y
	var bottom: float = TYRE_DIAMETER * 0.5
	var canvas := Image.create_empty(
		int(half_body.x * 2.0 * TRUCK_PX), int((bottom - top) * TRUCK_PX), false,
		Image.FORMAT_RGBA8
	)
	# Where world (0,0) — the axle line, on the truck's centreline — lands.
	var origin := Vector2(-left, -top) * TRUCK_PX

	# 1. The cab interior, so the punched window shows upholstery and not sky.
	_fill(canvas, CAB_RECT, origin)

	# 2. The driver, cropped the way his Sprite2D's region crops him: only the
	#    top of the drawing is ever above the door line.
	var driver := _load(ART + "driver_body.png")
	if driver != null:
		var visible := Image.create_empty(
			driver.get_width(), int(float(driver.get_height()) * DRIVER_VISIBLE),
			false, Image.FORMAT_RGBA8
		)
		visible.blit_rect(
			driver, Rect2i(0, 0, visible.get_width(), visible.get_height()), Vector2i.ZERO
		)
		_paste(
			canvas, visible, origin + DRIVER_AT * TRUCK_PX,
			DRIVER_SCALE * TRUCK_PX, 0.0, 0.0
		)

	# 3. His head, which is drawn in code rather than being a sprite. Two tones
	#    on a disc: at the size this ends up on a store page the cap and the face
	#    are all that survive of driver_head.gd anyway.
	_head(canvas, origin + HEAD_AT * TRUCK_PX, HEAD_RADIUS * TRUCK_PX)

	# 4. The bodywork, over the driver.
	var body := _load(ART + "car_body.png")
	if body != null:
		_paste(
			canvas, body, origin + BODY_AT * TRUCK_PX, BODY_SCALE * TRUCK_PX, 0.0, 0.0
		)

	# 5. The tyres last. In the scene the wheels are siblings that come after the
	#    chassis, so they draw over the arches — which is what lets the body sit
	#    down into them rather than in front of them.
	var tyre := _load(ART + "car_tire.png")
	if tyre != null:
		var factor: float = TYRE_DIAMETER * TRUCK_PX / float(tyre.get_width())
		for side in [-1.0, 1.0]:
			_paste(
				canvas, tyre, origin + Vector2(AXLE_X * side, 0.0) * TRUCK_PX,
				factor, 0.0, 0.0
			)
	return canvas


func _load(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		print("  missing: %s" % path)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


## A flat rectangle given in world units, for the cab interior.
func _fill(canvas: Image, rect: Rect2, origin: Vector2) -> void:
	var from := origin + rect.position * TRUCK_PX
	var to := origin + rect.end * TRUCK_PX
	for y in range(maxi(int(from.y), 0), mini(int(to.y), canvas.get_height())):
		for x in range(maxi(int(from.x), 0), mini(int(to.x), canvas.get_width())):
			canvas.set_pixel(x, y, CAB_COLOUR)


## The driver's head: a disc of face with the cap over the top of it.
func _head(canvas: Image, centre: Vector2, radius: float) -> void:
	var brim: float = centre.y - radius * 0.18
	for y in range(maxi(int(centre.y - radius), 0), mini(int(centre.y + radius) + 1, canvas.get_height())):
		for x in range(maxi(int(centre.x - radius), 0), mini(int(centre.x + radius) + 1, canvas.get_width())):
			if Vector2(float(x), float(y)).distance_to(centre) > radius:
				continue
			canvas.set_pixel(x, y, HEAD_CAP if float(y) < brim else HEAD_SKIN)


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
	var factor: float = piece.height * float(size.y) / float(src.get_height())
	_paste(
		dst,
		src,
		Vector2(piece.at.x * float(size.x), piece.at.y * float(size.y)),
		factor,
		piece.angle,
		piece.dim
	)


## Composite one image onto another, scaled and rotated about `centre`.
##
## Alpha is composited properly rather than assumed opaque, because this draws
## both onto the finished backdrop AND onto the transparent canvas the truck is
## assembled on — writing 1.0 alpha unconditionally, which is the shortcut that
## works for the first case, turns the truck's bounding box into a solid block.
func _paste(
	dst: Image, src: Image, centre: Vector2, factor: float, angle: float, dim: float
) -> void:
	var bounds := Vector2i(dst.get_width(), dst.get_height())
	var half := Vector2(float(src.get_width()), float(src.get_height())) * 0.5

	# The destination box: the sprite's own corners, rotated, then bounded. A
	# rotated rectangle needs more room than it started with, and clipping to the
	# unrotated size shaves the corners off.
	var reach: float = half.length() * factor + 2.0
	var from := Vector2i(
		maxi(int(centre.x - reach), 0), maxi(int(centre.y - reach), 0)
	)
	var to := Vector2i(
		mini(int(centre.x + reach), bounds.x - 1), mini(int(centre.y + reach), bounds.y - 1)
	)

	# Inverse rotation, because the walk is destination to source.
	var cos_a: float = cos(-angle)
	var sin_a: float = sin(-angle)
	var keep: float = 1.0 - clampf(dim, 0.0, 1.0)

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

			var under := dst.get_pixel(x, y)
			# Distance dims a piece towards whatever it sits on rather than
			# towards black: these are in front of a painted strait, and a grey
			# barrel on blue-green water reads as a hole in the picture.
			var tint := texel
			if keep < 1.0:
				tint = texel.lerp(Color(under.r, under.g, under.b, texel.a), 1.0 - keep)
			var alpha: float = texel.a + under.a * (1.0 - texel.a)
			if alpha <= 0.0001:
				continue
			var rgb := (
				Vector3(tint.r, tint.g, tint.b) * texel.a
				+ Vector3(under.r, under.g, under.b) * under.a * (1.0 - texel.a)
			) / alpha
			dst.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, alpha))


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
