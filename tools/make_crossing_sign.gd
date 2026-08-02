## Splits the CROSSING sign into the two layers the progress fill needs.
##
##   godot --headless --script tools/make_crossing_sign.gd
##
## Writes, from one source and on one shared crop so they overlay exactly:
##
##   art/ui/crossing.png          the sign with the lettering punched out
##   art/ui/crossing_letters.png  the lettering alone, white
##
## The fill is then a green-tinted copy of the letters layer sitting UNDER the
## sign, revealed left to right. Green therefore appears only inside the letter
## holes: the sign covers everything else, and the letters layer is empty
## everywhere else, so there is no way for the bar to leak onto the wood or out
## past the plank's edge.
##
## LETTERS ARE FOUND BY SATURATION, NOT BRIGHTNESS ALONE. The cream lettering and
## the wood's lit grain overlap in luminance — thresholding on brightness alone
## turned patches of plank into lettering. They separate cleanly on saturation:
## the letters are near-neutral cream, the wood is a saturated brown.
##
## THE BACKDROP IS FOUND BY POSITION, NOT COLOUR. The lettering's core is the
## same white as the paper behind the sign, so keying on colour deleted the
## insides of every letter and left only their cream edges — 7,162 px of outline
## where there should have been a solid word. The backdrop is instead flood
## filled inward from the border, so white that the outside cannot reach is
## lettering rather than background.
extends SceneTree

const SOURCE := "res://art_source/Crossing_Button.jpg"
const SIGN_OUT := "res://art/ui/crossing.png"
const LETTERS_OUT := "res://art/ui/crossing_letters.png"

const BACKDROP_TOLERANCE := 0.30
## A letter pixel is at least this bright...
const LETTER_LUMINANCE := 0.58
## ...and no more saturated than this.
const LETTER_SATURATION := 0.24
## Letters only occur in the upper part of the sign. The truck parked along the
## bottom has white panels and headlights that pass both tests above, and would
## otherwise light up green as the bar swept past it.
##
## MEASURED, not guessed. Scanning the source row by row, cream low-saturation
## pixels span the sign's full width (x 89..947) down to row 386 and then
## collapse to x 450..550 — the letters stop and the truck begins. 387/559 is
## 0.6923, so the cut goes just under it.
##
## The first attempt used 0.66, which is row 369: seventeen rows up inside the
## lettering. Everything below that line stayed cream, which showed in game as a
## white fillet along the bottom of every letter that the green never filled.
const LETTER_MAX_Y := 0.691


func _initialize() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if image == null:
		printerr("could not load ", SOURCE)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()
	var backdrop := image.get_pixel(0, 0)
	var outside := _flood_backdrop(image, w, h, backdrop)

	# One crop for both layers, or they would not line up when stacked.
	var box := Rect2i(-1, -1, 0, 0)
	for y in h:
		for x in w:
			if outside[y * w + x] == 1:
				continue
			box = Rect2i(Vector2i(x, y), Vector2i.ONE) if box.position.x < 0 \
				else box.expand(Vector2i(x, y))
	box = box.grow(1).intersection(Rect2i(0, 0, w, h))

	var sign := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	var letters := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	var letter_pixels := 0
	for y in box.size.y:
		for x in box.size.x:
			var source_x := box.position.x + x
			var source_y := box.position.y + y
			var c := image.get_pixel(source_x, source_y)
			if outside[source_y * w + source_x] == 1:
				sign.set_pixel(x, y, Color(0, 0, 0, 0))
				letters.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			if _is_letter(c, float(source_y) / float(h)):
				# Punched out of the sign, and kept as white in the fill layer so
				# it can be modulated to any colour later.
				sign.set_pixel(x, y, Color(0, 0, 0, 0))
				letters.set_pixel(x, y, Color.WHITE)
				letter_pixels += 1
			else:
				sign.set_pixel(x, y, c)
				letters.set_pixel(x, y, Color(0, 0, 0, 0))

	sign.save_png(ProjectSettings.globalize_path(SIGN_OUT))
	letters.save_png(ProjectSettings.globalize_path(LETTERS_OUT))
	print("crop %dx%d from %dx%d" % [box.size.x, box.size.y, w, h])
	print("  %s      sign with %d px punched out" % [SIGN_OUT.get_file(), letter_pixels])
	print("  %s  %d px of lettering" % [LETTERS_OUT.get_file(), letter_pixels])
	quit()


## Marks every backdrop-coloured pixel the border can reach. White enclosed by
## the sign — the inside of an O, the core of a C — is therefore not marked.
func _flood_backdrop(image: Image, w: int, h: int, backdrop: Color) -> PackedByteArray:
	var outside := PackedByteArray()
	outside.resize(w * h)
	var queue: Array[int] = []

	var seed := func(x: int, y: int) -> void:
		var i := y * w + x
		if outside[i] == 0 and _matches(image.get_pixel(x, y), backdrop):
			outside[i] = 1
			queue.append(i)
	for x in w:
		seed.call(x, 0)
		seed.call(x, h - 1)
	for y in h:
		seed.call(0, y)
		seed.call(w - 1, y)

	while not queue.is_empty():
		var index: int = queue.pop_back()
		var x := index % w
		var y := index / w
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + step.x
			var ny: int = y + step.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var n: int = ny * w + nx
			if outside[n] == 1 or not _matches(image.get_pixel(nx, ny), backdrop):
				continue
			outside[n] = 1
			queue.append(n)
	return outside


func _matches(c: Color, backdrop: Color) -> bool:
	if c.a < 0.5:
		return true
	var d := absf(c.r - backdrop.r) + absf(c.g - backdrop.g) + absf(c.b - backdrop.b)
	return d <= BACKDROP_TOLERANCE


func _is_letter(c: Color, y_fraction: float) -> bool:
	if y_fraction > LETTER_MAX_Y:
		return false
	var luminance := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	if luminance < LETTER_LUMINANCE:
		return false
	var high: float = maxf(c.r, maxf(c.g, c.b))
	var low: float = minf(c.r, minf(c.g, c.b))
	var saturation: float = 0.0 if high <= 0.0 else (high - low) / high
	return saturation <= LETTER_SATURATION
