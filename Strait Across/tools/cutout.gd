## Prepares a single piece of UI art: keys its flat backdrop to transparent,
## trims the empty margin, and optionally flattens interior grunge.
##
##   godot --headless --script tools/cutout.gd -- --in=Foo.jpg --out=art/ui/foo.png
##   godot --headless --script tools/cutout.gd -- --in=art/ui/plate.png \
##       --out=art/ui/plate.png --flatten=0.42
##
## slice_buttons.gd is the tool for a whole sheet of buttons; this is the one for
## a single image, which is what arrives when one button gets redrawn.
##
## `--flatten` replaces every pixel brighter than the given luminance with a flat
## colour, which scrubs painted smudges and scuff marks off a surface while
## leaving the dark outline and fixings alone. Off by default.
##
## `--fill-holes` paints any transparent area that the outside cannot reach. A
## backdrop key cuts by colour, not by position, so a pale surface enclosed by a
## dark frame gets cut along with the backdrop it resembles and the shape comes
## out hollow — which is exactly what happened to the piece plate, whose middle
## was close enough to the button sheet's tan to be keyed away. Filling from the
## inside restores the surface without loosening the tolerance and dragging the
## real backdrop back in.
extends SceneTree

## Colour distance from the sampled backdrop, summed across RGB in 0..1, below
## which a pixel is treated as backdrop and cut.
const DEFAULT_TOLERANCE := 0.30
## What --flatten paints over the smudges. Slightly off-white, so a cleaned plate
## still reads as painted metal rather than as a hole in the screen.
const FLAT_COLOUR := Color("f1f0ec")


func _initialize() -> void:
	var args := _parse_args()
	if not args.has("in") or not args.has("out"):
		printerr("usage: --in=<path> --out=<path> [--tolerance=0.30] [--flatten=0.42]")
		quit(1)
		return

	var source: String = args["in"]
	var image := Image.load_from_file(ProjectSettings.globalize_path(
		source if source.begins_with("res://") else "res://" + source
	))
	if image == null:
		printerr("could not load ", source)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()

	var tolerance := float(args.get("tolerance", DEFAULT_TOLERANCE))
	# Sampled rather than assumed: these arrive on white, on the button sheet's
	# tan, and sometimes already transparent.
	var backdrop := image.get_pixel(0, 0)
	var keyed := backdrop.a > 0.5

	var flatten := float(args.get("flatten", -1.0))

	# Pass 1: cut the backdrop.
	if keyed:
		for y in h:
			for x in w:
				var c := image.get_pixel(x, y)
				if c.a < 0.5:
					continue
				var d := (
					absf(c.r - backdrop.r) + absf(c.g - backdrop.g) + absf(c.b - backdrop.b)
				)
				if d <= tolerance:
					image.set_pixel(x, y, Color(0, 0, 0, 0))

	# Pass 2: a hollow shape's holes are part of the shape. Must follow the key,
	# which is what makes the holes in the first place.
	var filled := 0
	if args.has("fill-holes"):
		filled = _fill_holes(image, w, h)

	# Pass 3: scrub the surface, and measure what's left.
	var kept := Rect2i(-1, -1, 0, 0)
	var smudges := 0
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			if c.a < 0.5:
				continue
			if flatten >= 0.0 and _luminance(c) > flatten:
				image.set_pixel(x, y, Color(FLAT_COLOUR, c.a))
				smudges += 1
			kept = Rect2i(Vector2i(x, y), Vector2i.ONE) if kept.position.x < 0 \
				else kept.expand(Vector2i(x, y))

	if kept.position.x < 0:
		printerr("nothing left after keying ", source)
		quit(1)
		return

	# One pixel of margin so a shape touching its own bounds isn't hard-clipped.
	kept = kept.grow(1).intersection(Rect2i(0, 0, w, h))
	var out := image.get_region(kept)
	var destination: String = args["out"]
	out.save_png(ProjectSettings.globalize_path(
		destination if destination.begins_with("res://") else "res://" + destination
	))
	print("%s -> %s   %dx%d from %dx%d%s%s" % [
		source, destination, kept.size.x, kept.size.y, w, h,
		("   %d px hole-filled" % filled) if filled > 0 else "",
		("   %d px flattened" % smudges) if flatten >= 0.0 else ""
	])
	quit()


## Paints every transparent pixel the outside edge cannot reach.
##
## Flood fills transparency inward from the border; whatever transparency the
## flood never touches is enclosed, and therefore a hole in the artwork rather
## than the space around it.
func _fill_holes(image: Image, w: int, h: int) -> int:
	var outside := PackedByteArray()
	outside.resize(w * h)
	var queue: Array[int] = []
	for x in w:
		for y: int in [0, h - 1]:
			var i := y * w + x
			if image.get_pixel(x, y).a < 0.5 and outside[i] == 0:
				outside[i] = 1
				queue.append(i)
	for y in h:
		for x: int in [0, w - 1]:
			var i := y * w + x
			if image.get_pixel(x, y).a < 0.5 and outside[i] == 0:
				outside[i] = 1
				queue.append(i)

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
			if outside[n] == 1 or image.get_pixel(nx, ny).a >= 0.5:
				continue
			outside[n] = 1
			queue.append(n)

	var filled := 0
	for y in h:
		for x in w:
			if image.get_pixel(x, y).a < 0.5 and outside[y * w + x] == 0:
				image.set_pixel(x, y, FLAT_COLOUR)
				filled += 1
	return filled


func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _parse_args() -> Dictionary:
	var out := {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--") or not arg.contains("="):
			continue
		var pair := arg.substr(2).split("=", true, 1)
		out[pair[0]] = pair[1]
	return out
