## Pushes a backdrop further away by growing its canvas around it.
##
##   godot --headless --script tools/pad_backdrop.gd -- \
##       --in=art/background_outskirts.png --out=art/background_outskirts.png \
##       --factor=1.8 --horizon=0.55
##
## Backdrop.fit_to() always stretches the texture across the camera's whole
## travel, so nothing in the game can make a painting read as more distant —
## scale is decided by the canvas, not by the content. The only lever is how much
## of the canvas the subject occupies, so that is what this changes: the painting
## is left at its own pixel size and the canvas grows around it by `factor`,
## which shrinks the subject on screen by the same amount.
##
## Growing BOTH axes by the same factor is what keeps it honest. Backdrop scales
## x and y independently — x from the canvas width, y from where the horizon sits
## — so padding only the sides would leave the skyline the same height and half
## the width.
##
## The side margins are MIRRORED SLICES that fade into haze. Two simpler fills
## were tried first and both look wrong in the sky, which is most of what the
## margin is:
##
##   - clamp-to-edge repeats one column outward and paints hard vertical streaks;
##   - a flat band of the edge strip's average colour has no cloud in it at all,
##     so the painted sky stops dead at the seam and becomes paper.
##
## So the margin is built from `slice` pixels of real picture taken at the edge,
## reflected and tiled outward — actual cloud, actual haze, continuous across the
## seam because a mirror matches the edge exactly. Each tile is then blended
## towards the flat average with distance, so the repeat fades out before the eye
## can count it. Only a NARROW slice is mirrored: reflecting half the picture
## would drag the subject back into frame and the city would appear three times.
##
## Prints the new horizon fraction, which the level's .tres has to be given: the
## painted horizon has moved down the taller canvas.
extends SceneTree


func _initialize() -> void:
	var args := _parse_args()
	if not args.has("in") or not args.has("out"):
		printerr("usage: --in=<path> --out=<path> [--factor=1.8] [--horizon=0.55]")
		quit(1)
		return

	var source: String = args["in"]
	var image := Image.load_from_file(ProjectSettings.globalize_path(_res(source)))
	if image == null:
		printerr("could not load ", source)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)

	# Trim the outermost pixels before anything reads them.
	#
	# A painted backdrop usually carries a hairline of lighter edge along its
	# border — a canvas edge, a resampling artefact, whatever the export left
	# there. Untrimmed it is the exact column the mirror reflects around, so the
	# margin gets a copy of it every `slice` pixels and the sky ends up ruled with
	# faint vertical lines. Two pixels off each side removes the cause.
	var inset: int = maxi(int(args.get("inset", 2)), 0)
	if inset > 0 and image.get_width() > inset * 4 and image.get_height() > inset * 4:
		image = image.get_region(Rect2i(
			inset, inset,
			image.get_width() - inset * 2, image.get_height() - inset * 2
		))

	var factor: float = maxf(float(args.get("factor", 1.8)), 1.0)
	var horizon: float = float(args.get("horizon", 0.55))
	var w := image.get_width()
	var h := image.get_height()
	var new_w := int(round(w * factor))
	var new_h := int(round(h * factor))
	# Horizontally centred; vertically placed so the horizon lands in the middle
	# of the new canvas, which spends the added pixels on sky rather than on more
	# of the foreground nobody sees.
	var offset_x := (new_w - w) / 2
	var offset_y := int(round(new_h * 0.5 - horizon * h))
	offset_y = clampi(offset_y, 0, new_h - h)

	var feather: float = maxf(float(args.get("feather", 90.0)), 1.0)
	# Width of the strip that gets mirrored outward. Wide enough to carry whole
	# clouds — a narrow slice repeats too fast to read as sky — and well short of
	# the subject, which must never be reflected back into frame.
	var slice: int = maxi(int(args.get("slice", mini(w / 6, 240))), 8)
	# The vertical equivalent. Smaller, because the bands it reflects — open sky
	# above, open ground below — carry far less structure than the sides do, and a
	# tall reflection would bring the subject's own silhouette back down into the
	# margin.
	var v_slice: int = maxi(int(args.get("v_slice", mini(h / 8, 120))), 8)
	# One flat colour per source row for the side margins, and one for each of the
	# top and bottom margins. Averaged over a strip rather than a single line, so a
	# lone dark cloud pixel on the edge can't set the colour of half the sky.
	var strip: int = mini(48, w / 4)
	var left_avg := _row_averages(image, 0, strip)
	var right_avg := _row_averages(image, w - strip, strip)
	var top_avg := _band_average(image, 0, mini(48, h / 4))
	var bottom_avg := _band_average(image, h - mini(48, h / 4), mini(48, h / 4))

	var out := Image.create_empty(new_w, new_h, false, Image.FORMAT_RGBA8)
	for y in new_h:
		var sy := y - offset_y
		var vertical_pad: float = 0.0
		# Mirrored the same way as the sides. Clamping here stretched the top row
		# of cloud down the whole margin, which is the same vertical streaking in
		# the corners that the side fill was rewritten to avoid.
		if sy < 0:
			vertical_pad = float(-sy)
			sy = _mirrored(int(vertical_pad) - 1, v_slice)
		elif sy >= h:
			vertical_pad = float(sy - h + 1)
			sy = h - 1 - _mirrored(int(vertical_pad) - 1, v_slice)
		sy = clampi(sy, 0, h - 1)

		for x in new_w:
			var sx := x - offset_x
			var horizontal_pad: float = 0.0
			if sx < 0:
				horizontal_pad = float(-sx)
				# Walk back INTO the picture, reflecting every `slice` pixels.
				sx = _mirrored(int(horizontal_pad) - 1, slice)
			elif sx >= w:
				horizontal_pad = float(sx - w + 1)
				sx = w - 1 - _mirrored(int(horizontal_pad) - 1, slice)
			sx = clampi(sx, 0, w - 1)

			var c := image.get_pixel(sx, sy)
			# Sides first, then top/bottom over the result: a corner is a side
			# fade that then fades into the sky or the ground, which keeps the two
			# margins agreeing where they meet.
			if horizontal_pad > 0.0:
				var side: Color = left_avg[sy] if x < offset_x else right_avg[sy]
				c = c.lerp(side, minf(horizontal_pad / feather, 1.0))
			if vertical_pad > 0.0:
				var band: Color = top_avg if y < offset_y else bottom_avg
				c = c.lerp(band, minf(vertical_pad / feather, 1.0))
			out.set_pixel(x, y, c)

	out.save_png(ProjectSettings.globalize_path(_res(args["out"])))
	print("%s -> %s   %dx%d from %dx%d   backdrop_horizon = %.4f" % [
		source, args["out"], new_w, new_h, w, h,
		(offset_y + horizon * h) / float(new_h),
	])
	quit()


## Where a pixel `distance` outside the edge reads from, given a mirror every
## `slice` pixels: 0,1,2..slice-1 then back slice-1..0, and so on. Returned as a
## distance INTO the picture, which the caller turns into a column.
func _mirrored(distance: int, slice: int) -> int:
	var period := slice * 2
	var phase := distance % period
	return phase if phase < slice else period - 1 - phase


## Average colour of `width` columns starting at `from_x`, one entry per row.
func _row_averages(image: Image, from_x: int, width: int) -> Array[Color]:
	var out: Array[Color] = []
	for y in image.get_height():
		var sum := Color(0, 0, 0, 0)
		for i in width:
			var c := image.get_pixel(clampi(from_x + i, 0, image.get_width() - 1), y)
			sum += c
		out.append(sum / float(width))
	return out


## One colour for a horizontal band, used to fill the sky above and the ground
## below.
func _band_average(image: Image, from_y: int, height: int) -> Color:
	var sum := Color(0, 0, 0, 0)
	var count := 0
	for i in height:
		var y := clampi(from_y + i, 0, image.get_height() - 1)
		for x in image.get_width():
			sum += image.get_pixel(x, y)
			count += 1
	return sum / float(maxi(count, 1))


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
