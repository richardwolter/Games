## Cuts the net sheets into named animations and keys their white background out.
##
## Two sheets, drawn as greyscale etching on white with no alpha channel between them: the
## cast is three rows of five — a far throw, a near throw, and the landing — and the drag
## is one row of five. Which row is which is not written down anywhere, so it is stated
## here, as a table rather than as two code paths.
##
## The frames are measured, not cut on a grid. The first version of this assumed five even
## columns and clipped half the art: the drawings overrun their nominal cells, and on the
## drag sheet the open circle is twice the width of the closed bag. So rows are the bands
## of the sheet with anything in them and frames are the runs of ink inside a band, the
## same way tools/slice_pigeons.gd finds birds.
##
## Each frame also gets its **rim** measured — where it is at its widest, and how wide. That
## is the one line of this tool the game leans on hardest: the drag sequence narrows as the
## net purses, and scripts/net.gd takes the shrink curve of the sweep from those numbers
## rather than from a constant somebody guessed. The net cannot then close on screen at a
## different rate from the water it is closing over.
##
## The keying is the other half of the job. The art is dark line on white, which means the
## darkness is the picture: alpha comes from `1 - luminance` through a threshold curve, and
## the colour is thrown away and written flat white so the game can tint the net to its own
## ink. The threshold matters more than it looks — these are JPEGs, and JPEG leaves a grey
## ring around every dark line on a white field. Keyed naively that ring becomes a halo.
##
## Writes assets/net_frames.png and assets/net_frames.json, which scripts/net.gd reads, and
## assets/sliced_net.png, which is for looking at. Cutting art by rule is a thing you have
## to check, not a thing you assert.
##
##   godot --headless --path . --script res://tools/slice_net.gd
extends SceneTree

## The sheets and what each band of each one is, top to bottom. `frames` is how many are
## expected in every band — the count is known, so it is used to put detached bits of a
## drawing back onto the drawing they came off.
const SHEETS := [
	{
		"path": "res://assets/Net_Cast_spritesheet.jpg",
		"frames": 5,
		"rows": ["cast_far", "cast_near", "land"],
	},
	{
		"path": "res://assets/Net_Closing_Drag.jpg",
		"frames": 5,
		"rows": ["drag"],
	},
]

const OUT_PNG := "res://assets/net_frames.png"
const OUT_JSON := "res://assets/net_frames.json"
const DEBUG_PNG := "res://assets/sliced_net.png"

## Where the background starts and where the art is solid, as luminance. Anything lighter
## than `CLEAR_AT` is thrown away outright — that band is where the JPEG ringing lives —
## and anything darker than `SOLID_AT` is fully opaque. Between them it ramps.
## How much of a frame's ink, from the top down, counts as its crown: the gathered apex a
## cast net is hauled from, where the hand line's loop and the bridle meet the mesh.
##
## A share of the ink rather than a number of pixels, because these frames are drawn at
## wildly different sizes — the landed net is 274 px across and the bundled throw is 115.
## An eighth is enough to land on the apex ring of the landed frames without creeping down
## the dome, and on a balled-up throw it simply takes the top of the bundle, which is where
## the line is in those drawings too.
const CROWN_BAND := 0.12

const CLEAR_AT := 0.88
const SOLID_AT := 0.42

## The ramp's shape. Above one, so the faint end of the ramp is pushed down harder than the
## dark end: what survives keying is the line, not the grey it is sitting in.
const RAMP_GAMMA := 1.6

## Alpha under this is dropped to nothing. The last of the ringing, and the difference
## between a clean edge and a grey fog around every frame.
const FLOOR_ALPHA := 0.06

## What counts as ink when bands and runs are being found. Higher than the floor: the
## faintest keyed pixels are the mesh fading out, and letting those define a boundary
## stretches every box by a few pixels of nothing.
const INK_ALPHA := 0.2

## A band or a run holding fewer ink pixels than this is dust rather than a drawing.
const MIN_PIXELS := 40

## Padding between the sheets in the packed atlas, so filtering never samples across.
const PAD := 2


func _init() -> void:
	var sheets: Array = []
	var packed_height := 0
	var packed_width := 0

	for sheet: Dictionary in SHEETS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(sheet["path"]))
		if image == null:
			printerr("could not read %s" % sheet["path"])
			quit(1)
			return
		image.convert(Image.FORMAT_RGBA8)
		_key(image)
		sheets.append({"art": image, "of": sheet})
		# Stacked down the atlas rather than fitted: two sheets of the same width is not a
		# packing problem, and a packer here would be cleverness with nothing to show.
		packed_width = maxi(packed_width, image.get_width())
		packed_height += image.get_height() + PAD

	var atlas := Image.create(packed_width, packed_height, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(1.0, 1.0, 1.0, 0.0))

	var sequences := {}
	var y := 0
	var counted := 0
	for entry: Dictionary in sheets:
		var image: Image = entry["art"]
		var of: Dictionary = entry["of"]
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(0, y))

		var names: Array = of["rows"]
		var wanted := int(of["frames"])
		var bands := _bands(atlas, y, image.get_height())
		if bands.size() != names.size():
			printerr(
				"%s: found %d bands, expected %d" % [of["path"], bands.size(), names.size()]
			)
			quit(1)
			return

		for row in names.size():
			var band: Vector2i = bands[row]
			var runs := _runs(atlas, band)
			runs = _merge_to(runs, wanted)
			if runs.size() != wanted:
				printerr(
					"%s row %d: found %d frames, expected %d"
					% [of["path"], row, runs.size(), wanted]
				)
				quit(1)
				return
			var frames: Array = []
			for box: Rect2i in runs:
				var rim := _rim(atlas, box)
				var crown := _crown(atlas, box)
				frames.append({
					"region": [box.position.x, box.position.y, box.size.x, box.size.y],
					# Where the drawing is at its widest, and how wide: the net's rim, and
					# the anchor the game hangs the frame from.
					"rim_width": rim.x,
					"rim_y": rim.y,
					# And the crown: the middle of the gathered apex, and how wide the ink
					# is across it. The game ties the rope there — see CastNet._line_end.
					"crown_x": crown.x,
					"crown_y": crown.y,
					"crown_w": crown.z,
				})
				counted += 1
			sequences[names[row]] = frames
		y += image.get_height() + PAD

	if atlas.save_png(ProjectSettings.globalize_path(OUT_PNG)) != OK:
		printerr("could not write %s" % OUT_PNG)
		quit(1)
		return

	var file := FileAccess.open(OUT_JSON, FileAccess.WRITE)
	if file == null:
		printerr("could not write %s" % OUT_JSON)
		quit(1)
		return
	file.store_string(JSON.stringify({
		"sheet": OUT_PNG,
		"size": [atlas.get_width(), atlas.get_height()],
		"sequences": sequences,
	}, "\t"))
	file.close()

	_debug_picture(atlas, sequences)
	printerr("wrote %s: %d frames in %d sequences" % [OUT_JSON, counted, sequences.size()])
	quit(0)


## White out, ink in. The colour is discarded on purpose: what is kept is a mask of where
## the drawing is, which the game tints to whatever the lake's ink happens to be.
func _key(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var was := image.get_pixel(x, y)
			# Perceptual rather than a flat average: the art is grey, but the paper is not
			# quite white and the difference between them is what is being measured.
			var light := was.r * 0.299 + was.g * 0.587 + was.b * 0.114
			var alpha := 0.0
			if light < SOLID_AT:
				alpha = 1.0
			elif light < CLEAR_AT:
				alpha = pow(
					(CLEAR_AT - light) / maxf(CLEAR_AT - SOLID_AT, 0.0001), RAMP_GAMMA
				)
			if alpha < FLOOR_ALPHA:
				alpha = 0.0
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))


## The horizontal bands of one sheet that have anything drawn in them, as (top, height) in
## atlas coordinates.
func _bands(atlas: Image, from_y: int, height: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var start := -1
	for y in range(from_y, from_y + height):
		var used := false
		for x in atlas.get_width():
			if atlas.get_pixel(x, y).a >= INK_ALPHA:
				used = true
				break
		if used and start < 0:
			start = y
		elif not used and start >= 0:
			out.append(Vector2i(start, y - start))
			start = -1
	if start >= 0:
		out.append(Vector2i(start, from_y + height - start))

	var kept: Array[Vector2i] = []
	for band: Vector2i in out:
		if _pixels_in(atlas, Rect2i(0, band.x, atlas.get_width(), band.y)) >= MIN_PIXELS:
			kept.append(band)
	return kept


## The runs of ink across one band, each shrunk onto its own pixels in both directions.
func _runs(atlas: Image, band: Vector2i) -> Array[Rect2i]:
	var spans: Array[Vector2i] = []
	var start := -1
	for x in atlas.get_width():
		var used := false
		for y in range(band.x, band.x + band.y):
			if atlas.get_pixel(x, y).a >= INK_ALPHA:
				used = true
				break
		if used and start < 0:
			start = x
		elif not used and start >= 0:
			spans.append(Vector2i(start, x - start))
			start = -1
	if start >= 0:
		spans.append(Vector2i(start, atlas.get_width() - start))

	var out: Array[Rect2i] = []
	for span: Vector2i in spans:
		var box := Rect2i(span.x, band.x, span.y, band.y)
		if _pixels_in(atlas, box) < MIN_PIXELS:
			continue
		out.append(_shrink(atlas, box))
	return out


## Weld runs together, closest pair first, until there are as many as there should be.
##
## This is what puts a drawing back together when part of it stands clear of the rest — the
## little loop of line hanging off a folded net reads as its own run otherwise. Merging by
## smallest gap needs no threshold to be tuned: the count is known, so the rule is just
## "join whatever is nearest until the number is right".
func _merge_to(runs: Array[Rect2i], wanted: int) -> Array[Rect2i]:
	var out := runs.duplicate()
	while out.size() > wanted:
		var best := -1
		var closest := 1 << 30
		for i in out.size() - 1:
			var here: Rect2i = out[i]
			var next: Rect2i = out[i + 1]
			var gap := next.position.x - (here.position.x + here.size.x)
			if gap < closest:
				closest = gap
				best = i
		if best < 0:
			break
		out[best] = out[best].merge(out[best + 1])
		out.remove_at(best + 1)
	return out


## Where a frame is at its widest, and how wide it is there: `Vector2i(width, y)`.
##
## For a net this is the rim — the ring of weights — whichever way the drawing is turned.
## Seen from above the widest line is across the middle of the circle; seen from the side
## it is the mouth; on a bag pulled shut it is the knot of weights near the bottom. So one
## measurement gives both the size the frame should be drawn at and the height in it that
## belongs on the water.
func _rim(atlas: Image, box: Rect2i) -> Vector2i:
	var widest := 0
	var at := box.position.y + box.size.y / 2
	for y in range(box.position.y, box.position.y + box.size.y):
		var low := -1
		var high := -1
		for x in range(box.position.x, box.position.x + box.size.x):
			if atlas.get_pixel(x, y).a < INK_ALPHA:
				continue
			if low < 0:
				low = x
			high = x
		if low < 0:
			continue
		var width := high - low + 1
		if width > widest:
			widest = width
			at = y
	return Vector2i(widest, at)


## The crown: the middle of the top `CROWN_BAND` of a frame's ink, and how wide the ink runs
## across it. `Vector3i(x, y, width)`, in atlas pixels.
##
## This is where a cast net is actually hauled from. The hand line goes to a swivel at the
## gathered apex and a bridle fans from there to the rim — so a rope drawn to anywhere else
## is a rope tied to the wrong part of the net. Measured rather than authored because the
## apex sits somewhere different in every frame: dead centre on the landed net, off to one
## side on a throw still opening, inside the bundle on the first frame of a cast.
##
## The middle is the ink's own centre of mass across the band, not the middle of the box.
## A drawing whose skirt hangs further one way than the other would otherwise pull the
## crown off the apex it is supposed to name.
func _crown(atlas: Image, box: Rect2i) -> Vector3i:
	var top := -1
	var bottom := -1
	for y in range(box.position.y, box.position.y + box.size.y):
		if not _inked_row(atlas, box, y):
			continue
		if top < 0:
			top = y
		bottom = y
	if top < 0:
		return Vector3i(box.position.x + box.size.x / 2, box.position.y, box.size.x)
	var deep := maxi(int(round(float(bottom - top + 1) * CROWN_BAND)), 1)
	var weight := 0
	var sum_x := 0
	var low := box.position.x + box.size.x
	var high := box.position.x - 1
	for y in range(top, mini(top + deep, box.position.y + box.size.y)):
		for x in range(box.position.x, box.position.x + box.size.x):
			if atlas.get_pixel(x, y).a < INK_ALPHA:
				continue
			weight += 1
			sum_x += x
			low = mini(low, x)
			high = maxi(high, x)
	if weight == 0:
		return Vector3i(box.position.x + box.size.x / 2, top, box.size.x)
	return Vector3i(sum_x / weight, top + deep / 2, high - low + 1)


func _inked_row(atlas: Image, box: Rect2i, y: int) -> bool:
	for x in range(box.position.x, box.position.x + box.size.x):
		if atlas.get_pixel(x, y).a >= INK_ALPHA:
			return true
	return false


## Shrink a box onto its own ink, in both directions.
func _shrink(atlas: Image, box: Rect2i) -> Rect2i:
	var low := Vector2i(box.position.x + box.size.x, box.position.y + box.size.y)
	var high := Vector2i(box.position.x - 1, box.position.y - 1)
	for y in range(box.position.y, box.position.y + box.size.y):
		for x in range(box.position.x, box.position.x + box.size.x):
			if atlas.get_pixel(x, y).a < INK_ALPHA:
				continue
			low.x = mini(low.x, x)
			low.y = mini(low.y, y)
			high.x = maxi(high.x, x)
			high.y = maxi(high.y, y)
	if high.x < low.x or high.y < low.y:
		return Rect2i()
	return Rect2i(low, high - low + Vector2i.ONE)


func _pixels_in(atlas: Image, box: Rect2i) -> int:
	var count := 0
	for y in range(box.position.y, box.position.y + box.size.y):
		for x in range(box.position.x, box.position.x + box.size.x):
			if atlas.get_pixel(x, y).a >= INK_ALPHA:
				count += 1
	return count


## The check-my-work picture: the keyed atlas over a mid grey, every frame boxed, and every
## measured rim drawn as the line it is. Grey because the art is now white on nothing, and
## white on white shows you exactly as much as it sounds like it would.
func _debug_picture(atlas: Image, sequences: Dictionary) -> void:
	var shown := Image.create(
		atlas.get_width(), atlas.get_height(), false, Image.FORMAT_RGBA8
	)
	shown.fill(Color(0.45, 0.47, 0.5, 1.0))
	for y in atlas.get_height():
		for x in atlas.get_width():
			var pixel := atlas.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			# The art is a mask, so it is shown as ink over the grey rather than as itself.
			shown.set_pixel(
				x, y, shown.get_pixel(x, y).lerp(Color(0.1, 0.1, 0.12), pixel.a)
			)

	for name: String in sequences:
		for frame: Dictionary in sequences[name]:
			var region: Array = frame["region"]
			var box := Rect2i(region[0], region[1], region[2], region[3])
			_outline(shown, box, Color(0.35, 0.6, 1.0))
			# The rim, drawn where it was measured and as wide as it was measured: if the
			# net is going to hang off this line, it wants looking at.
			var rim_y: int = frame["rim_y"]
			var half: int = int(frame["rim_width"]) / 2
			var middle := box.position.x + box.size.x / 2
			for x in range(maxi(middle - half, 0), mini(middle + half, shown.get_width())):
				shown.set_pixel(x, rim_y, Color(1.0, 0.45, 0.2))
	shown.save_png(ProjectSettings.globalize_path(DEBUG_PNG))


func _outline(image: Image, box: Rect2i, tint: Color) -> void:
	var right := mini(box.position.x + box.size.x - 1, image.get_width() - 1)
	var bottom := mini(box.position.y + box.size.y - 1, image.get_height() - 1)
	for x in range(box.position.x, right + 1):
		image.set_pixel(x, box.position.y, tint)
		image.set_pixel(x, bottom, tint)
	for y in range(box.position.y, bottom + 1):
		image.set_pixel(box.position.x, y, tint)
		image.set_pixel(right, y, tint)
