## Turns a painted landscape into a level backdrop: cut at the shoreline, water
## painted below.
##
##   godot --headless --script tools/make_backdrop.gd -- \
##       --in="art_source/Background level 3.png" --out=art/background_quarry.png \
##       --shore=0.63 --crop=0.11 --water=17,20,25 --deep=75,85,115
##
## Then ALWAYS pad it to the level's own aspect, or the whole painting is
## stretched sideways by fit_to():
##
##   godot --headless --script tools/pad_backdrop.gd -- \
##       --in=<out> --out=<out> --factor=1.0 --aspect=<n> --horizon=0.5 \
##       --feather=620 --slice=360
##
## The aspect per level comes from tools/backdrop_aspect.gd, and it must be read
## AFTER the level's backdrop_horizon is set — the wanted aspect depends on it,
## so a level with no backdrop yet reports a number for the wrong horizon.
##
## What has been built with this, all at horizon 0.5:
##
##   level 3  Background level 3.png  --shore=0.63 --crop=0.11  aspect 2.623
##            --water=43,51,64 --deep=19,22,29
##   level 5  Background Level 5.png  --shore=0.60 --crop=0.16  aspect 2.439
##            --water=52,56,52 --deep=20,26,26
##   level 6  Background Level 6.png  --shore=0.66 --crop=0.16  aspect 2.927
##            --water=46,60,76 --deep=18,26,36
##
## WHY THE PICTURE IS CUT. The sources are complete landscapes and their bottom
## third is dry ground — cracked pan, foreground boulders, the bases of the trees
## that frame the shot. Used whole, the waterline lands in the middle of that and
## everything painted below it drowns. Trees growing out of the seabed is exactly
## the artefact to avoid, so everything under the shoreline is discarded and
## repainted.
##
## WHY THE SIDES ARE CROPPED. These levels are wide, so the canvas has to be
## padded well past the painting, and the margins are built by mirroring whatever
## the picture ends on. Every one of these sources ends on a big foreground rock
## or a palm — mirror that and the margin is a slab with a hard edge running out
## to the corner. Cutting the frame off first leaves open ground and sky at the
## edges, which extends outward without anyone being able to point at where the
## painting stopped.
extends SceneTree


func _initialize() -> void:
	var args := _parse_args()
	if not args.has("in") or not args.has("out"):
		printerr("usage: --in=<path> --out=<path> [--shore=0.63] [--crop=0.11]",
			" [--water=r,g,b] [--deep=r,g,b] [--shallow=0.30]")
		quit(1)
		return

	var source: String = _res(args["in"])
	var image := Image.load_from_file(ProjectSettings.globalize_path(source))
	if image == null:
		printerr("could not load ", source)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)

	var crop: float = clampf(float(args.get("crop", 0.0)), 0.0, 0.4)
	var cut := int(float(image.get_width()) * crop)
	if cut > 0:
		image = image.get_region(Rect2i(
			cut, 0, image.get_width() - cut * 2, image.get_height()
		))

	var shore_frac: float = clampf(float(args.get("shore", 0.63)), 0.1, 0.95)
	## How much of the source's own colour survives at the waterline before the
	## depth gradient takes over. Some is needed or the join is a hard line.
	var shallow_blend: float = float(args.get("shallow", 0.30))
	## The hue the shallows are pulled towards, before each column's own
	## brightness scales it.
	var water := _colour(args.get("water", "43,51,64"))
	## The bottom of the painted water. Darker than `water` but never black — the
	## water shader darkens everything behind it again, and black on black loses
	## the seabed entirely.
	var deep := _colour(args.get("deep", "19,22,29"))

	var width := image.get_width()
	var shore := int(float(image.get_height()) * shore_frac)
	# The cut lands at the bottom of the output's top half, so the level's
	# backdrop_horizon is 0.5 — the same as every other level's.
	var out := Image.create(width, shore * 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(image, Rect2i(0, 0, width, shore), Vector2i.ZERO)

	# Each column of water starts from the brightness the picture actually ends
	# on at that x, so a shadowed bank goes down dark and lit ground goes down
	# pale. Smeared sideways first, or every outline above the waterline
	# continues into the water as a hard vertical stripe.
	var edges := _blurred_edges(image, shore, width, water, deep)
	for x in width:
		var edge := edges[x]
		for y in shore:
			var depth: float = float(y) / float(shore - 1)
			var shallow := edge.lerp(deep, shallow_blend)
			# Squared, so the shallows hold their colour and the fall-off to deep
			# water happens lower down. Linear reads as a flat wash.
			out.set_pixel(x, shore + y, shallow.lerp(deep, depth * depth))

	out.save_png(ProjectSettings.globalize_path(_res(args["out"])))
	print("%s  %dx%d  (shore at %d of %d, %d px cropped each side)" % [
		args["out"], out.get_width(), out.get_height(),
		shore, image.get_height(), cut
	])
	quit()


## Every column's edge colour, smeared sideways and turned into water.
func _blurred_edges(image: Image, shore: int, width: int, water: Color,
		deep: Color) -> Array[Color]:
	var raw: Array[Color] = []
	raw.resize(width)
	for x in width:
		raw[x] = _column_edge(image, x, shore, deep)

	# Wide enough to erase individual outlines, narrow enough that the broad
	# light-and-dark across the scene survives.
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
		# Take the bank's BRIGHTNESS and throw its hue away. Blending towards
		# water still leaves the bank's colour in the mix, so sand reads as a
		# sandbar and grass as green water. What wants carrying down is only the
		# light: dark under the rocks, bright where the sun is on the ground.
		var luma: float = mean.r * 0.299 + mean.g * 0.587 + mean.b * 0.114
		var lift: float = clampf(luma / 0.34, 0.55, 2.2)
		out[x] = Color(water.r * lift, water.g * lift, water.b * lift)
	return out


## Average of the last few rows above the cut, so one stray outline pixel doesn't
## set the tone for a whole column of water.
func _column_edge(image: Image, x: int, shore: int, deep: Color) -> Color:
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
		return deep
	return Color(total.r / taken, total.g / taken, total.b / taken)


## "r,g,b" in 0-255, which is how these get picked off a colour wheel.
func _colour(text: String) -> Color:
	var parts := text.split(",")
	if parts.size() != 3:
		return Color(0.1, 0.12, 0.15)
	return Color(
		float(parts[0]) / 255.0, float(parts[1]) / 255.0, float(parts[2]) / 255.0
	)


func _res(path: String) -> String:
	return path if path.begins_with("res://") else "res://" + path


func _parse_args() -> Dictionary:
	var out := {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--") or not arg.contains("="):
			continue
		var pair := arg.substr(2).split("=", true, 1)
		out[pair[0]] = pair[1]
	return out
