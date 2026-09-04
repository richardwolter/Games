## Turns the painted forest valley into a usable backdrop.
##
##   godot --headless --script tools/make_forest_backdrop.gd
##   godot --headless --script tools/pad_backdrop.gd -- \
##       --in=art/background_forest.png --out=art/background_forest.png \
##       --factor=1.0 --aspect=3.443 --horizon=0.5 --feather=760 --slice=430
##
## BOTH steps, in that order. This one cuts the valley at its shoreline and paints
## the water; the pad step widens the canvas to the shape level 4's camera bounds
## want. Level 4 is the widest strait in the game, and unpadded the painting is
## stretched sideways by more than two — every tree twice as wide as it was drawn.
## The aspect comes from tools/backdrop_aspect.gd.
##
## The source is a complete landscape: forested slopes, a waterfall, and a flat
## meadow filling the whole bottom third with foreground rocks and pine trunks
## along the very bottom edge. Used as-is it would put the waterline somewhere in
## the middle of that meadow, and everything painted below — the meadow, the
## boulders, the bases of two large pines — would end up underwater. Trees
## growing out of the seabed is exactly the artefact to avoid.
##
## So the picture is cut at the far shoreline, where the trees stop and the flat
## ground begins. Everything above that is kept and becomes the far bank; the
## meadow and the foreground are discarded outright. The half below the cut is
## then painted here: a depth gradient from the shoreline's own colour down to
## dark water, which is what the strait's seabed and water shader sit in front of.
##
## The cut lands at the bottom of the output's top half, so horizon_frac is 0.5
## and Backdrop.fit_to() welds it to the waterline the same way as level 1's.
extends SceneTree

const SOURCE := "res://art_source/Forest_Background.png"
const OUT := "res://art/background_forest.png"

## Where the far shoreline sits in the source, top to bottom. Just below the
## small bridge at the foot of the waterfall, where the treeline meets the flat
## ground — raise it and meadow creeps in above the waterline, lower it and the
## valley loses its floor.
## Raised from 0.615, which took in the first rows of the meadow. That tan then
## became the colour of the shallows right across the middle of the strait — a
## sandbar sitting on the waterline exactly where the bridge gets built, and the
## first thing to notice about the level.
const SHORE_FRAC := 0.588
## How much of the source's own colour survives at the waterline before the
## depth gradient takes over. Some is needed or the join is a hard line.
const SHALLOW_BLEND := 0.32
## The bottom of the painted water. Deliberately not black — the water shader
## darkens everything behind it again, and black on black loses the seabed.
const DEEP := Color(0.055, 0.105, 0.125)
## The hue the shallows are pulled towards, so the bank's greens and tans become
## water rather than a submerged copy of the bank.
const WATER := Color(0.14, 0.26, 0.27)


func _initialize() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if image == null:
		print("missing: %s" % SOURCE)
		quit()
		return
	image.convert(Image.FORMAT_RGBA8)

	var width := image.get_width()
	var shore := int(float(image.get_height()) * SHORE_FRAC)
	var out := Image.create(width, shore * 2, false, Image.FORMAT_RGBA8)

	# The kept half: the valley above its own shoreline.
	out.blit_rect(image, Rect2i(0, 0, width, shore), Vector2i.ZERO)

	# The painted half. Each column starts from the colour the picture actually
	# ends on at that x — so the reflection of a dark treeline is dark and the
	# gap where the waterfall comes down stays pale — and then all of them run
	# together into the same deep water further down.
	#
	# Those column colours are then smeared sideways. Taken raw they carry every
	# tree trunk and outline straight down the image as a hard vertical stripe,
	# which read as corduroy rather than as water; a wide blur keeps the broad
	# light-and-dark of the bank and throws away the detail that caused it.
	var edges := _blurred_edges(image, shore, width)
	for x in width:
		var edge := edges[x]
		for y in shore:
			var depth: float = float(y) / float(shore - 1)
			# Squared, so the shallows keep the bank's colour for a while and the
			# fall-off happens lower down. Linear read as a flat wash.
			var shallow := edge.lerp(DEEP, SHALLOW_BLEND)
			out.set_pixel(x, shore + y, shallow.lerp(DEEP, depth * depth))

	out.save_png(ProjectSettings.globalize_path(OUT))
	print("%s  %dx%d  (shore at %d of %d)" % [
		OUT, out.get_width(), out.get_height(), shore, image.get_height()
	])
	quit()


## Every column's edge colour, smeared sideways and pulled towards water.
func _blurred_edges(image: Image, shore: int, width: int) -> Array[Color]:
	var raw: Array[Color] = []
	raw.resize(width)
	for x in width:
		raw[x] = _column_edge(image, x, shore)

	# Wide enough to erase tree trunks, narrow enough that the waterfall — which
	# is only a couple of dozen pixels across — survives as a bright column.
	var radius: int = maxi(width / 48, 1)
	var out: Array[Color] = []
	out.resize(width)
	for x in width:
		var total := Color(0, 0, 0)
		var taken := 0
		for i in range(x - radius, x + radius + 1):
			if i < 0 or i >= width:
				continue
			total += raw[i]
			taken += 1
		var mean := Color(total.r / taken, total.g / taken, total.b / taken)
		# Take the bank's BRIGHTNESS and throw its hue away.
		#
		# Blending towards water still left the bank's colour in the mix, so the
		# meadow read as sand and the treeline as green water. What actually
		# wants carrying down is only the light: dark under the trees, bright
		# under the waterfall. So every column is the same water colour, scaled
		# by how light or dark the bank above it is — which is what makes the
		# fall's plunge read as continuing into the strait rather than stopping
		# at the waterline.
		var luma: float = mean.r * 0.299 + mean.g * 0.587 + mean.b * 0.114
		var lift: float = clampf(luma / 0.32, 0.55, 2.4)
		out[x] = Color(WATER.r * lift, WATER.g * lift, WATER.b * lift)
	return out


## Average of the last few rows above the cut, so one stray dark outline pixel
## doesn't set the tone for a whole column of water.
func _column_edge(image: Image, x: int, shore: int) -> Color:
	const SAMPLE := 6
	var total := Color(0, 0, 0)
	var taken := 0
	for i in SAMPLE:
		var y := shore - 1 - i
		if y < 0:
			break
		var pixel := image.get_pixel(x, y)
		total += Color(pixel.r, pixel.g, pixel.b)
		taken += 1
	if taken == 0:
		return DEEP
	return Color(total.r / taken, total.g / taken, total.b / taken)
