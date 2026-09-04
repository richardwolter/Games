## Paints out the generator's sparkle watermark on the title art.
##
##   godot --headless --script tools/scrub_watermark.gd
##
## The mark sits in the bottom-right corner, on the barrels' reflection in the
## water — a smooth, dark, low-contrast patch, which is the one kind of region a
## diffusion fill handles well. The hole is seeded from its own boundary and
## relaxed towards a harmonic surface (repeated four-neighbour averaging), so the
## fill leaves the surrounding gradient continuous instead of a flat blob.
##
## A tool rather than a one-off edit because the art gets regenerated: when a new
## title image arrives with the same mark in the same corner, this is one command
## instead of an image editor and a steady hand.
extends SceneTree

const SOURCE := "res://art/title_screen.jpg"
## The sparkle's bounding ellipse, measured off the 1024x559 image. Slightly
## larger than the mark itself so the JPEG ringing around its edge goes too —
## leaving that behind is what makes a patched watermark still visible.
const CENTRE := Vector2(937.0, 472.0)
const RADIUS := Vector2(24.0, 25.0)
## Relaxation sweeps. The hole is ~48px across and the fill spreads about one
## pixel per sweep from each side, so this is comfortably past convergence.
const SWEEPS := 600
## Written back as JPEG at high quality, so the .import file and every reference
## to the path keep working. Re-encoding a JPEG loses a little, but only in this
## corner does it matter and the corner is being repainted anyway.
const QUALITY := 0.95


func _initialize() -> void:
	var path := ProjectSettings.globalize_path(SOURCE)
	var img := Image.load_from_file(path)
	if img == null:
		printerr("could not read ", path)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBF)

	# The patch is worked on as a small local grid rather than over the whole
	# image: 600 sweeps of a 1024x559 image is 344 million pixel reads for a
	# region 48 across.
	var box := Rect2i(
		int(CENTRE.x - RADIUS.x) - 2, int(CENTRE.y - RADIUS.y) - 2,
		int(RADIUS.x * 2.0) + 5, int(RADIUS.y * 2.0) + 5
	)

	var w := box.size.x
	var h := box.size.y
	var hole := PackedByteArray()
	hole.resize(w * h)
	var field: Array[Color] = []
	field.resize(w * h)

	var holes := 0
	for y in h:
		for x in w:
			var px := Vector2(box.position.x + x, box.position.y + y)
			var d := (px - CENTRE) / RADIUS
			var inside := d.length_squared() <= 1.0
			hole[y * w + x] = 1 if inside else 0
			field[y * w + x] = img.get_pixel(box.position.x + x, box.position.y + y)
			holes += 1 if inside else 0

	# Seeded flat at the boundary's average, so the first sweeps have something
	# sane to relax from rather than the watermark's own white.
	var seed_colour := Color(0, 0, 0)
	var edge := 0
	for y in h:
		for x in w:
			if hole[y * w + x] == 0:
				seed_colour += field[y * w + x]
				edge += 1
	seed_colour /= float(maxi(edge, 1))
	for i in hole.size():
		if hole[i] == 1:
			field[i] = seed_colour

	for sweep in SWEEPS:
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var i := y * w + x
				if hole[i] == 0:
					continue
				field[i] = (
					field[i - 1] + field[i + 1] + field[i - w] + field[i + w]
				) * 0.25

	for y in h:
		for x in w:
			if hole[y * w + x] == 1:
				img.set_pixel(box.position.x + x, box.position.y + y, field[y * w + x])

	img.convert(Image.FORMAT_RGB8)
	var err := img.save_jpg(path, QUALITY)
	print("scrubbed %d px in %s (err %d)" % [holes, box, err])
	quit()
