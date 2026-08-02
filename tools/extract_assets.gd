## Cuts the art sheets into one PNG per game object.
##
## Two kinds of input:
##   - the master sheet, one drawing per object, named in reading order by NAMES;
##   - per-object variant sheets (VARIANT_SHEETS), every drawing on them being
##     another version of the same object, written as <name>_1.png upwards.
##
## The sheets are already transparent but laid out by eye rather than on a grid,
## so items are found as connected runs of opaque pixels. Re-run this if a sheet
## is redrawn; if items are added or moved, update NAMES to match.
##
## Run with:  godot --headless --script tools/extract_assets.gd
extends SceneTree

const SOURCE := "res://art_source/Strait_Across_Assets.png"
## object name -> a sheet of that object's variants. A piece with a sheet here
## draws a random one of these instead of its master-sheet drawing.
const VARIANT_SHEETS: Dictionary = {
	"plank": "res://art_source/Wooden Plank.png",
	"barrel": "res://art_source/Barrel.png",
}
## output name -> a sheet holding a single drawing, for art that arrives on its
## own rather than as part of a set.
const SINGLE_SHEETS: Dictionary = {
	"car_tire": "res://art_source/Car_Tire.png",
	"crate": "res://art_source/Crate.png",
	"beam": "res://art_source/Metal Bean.png",
	"pontoon": "res://art_source/Pontoon.png",
	"refrigerator": "res://art_source/Refrigerator.png",
	"tire": "res://art_source/Tire.png",
}
const OUT_DIR := "res://art"
## Below this the pixel is sheet background, not artwork.
const ALPHA_CUTOFF := 0.35
## Ignore specks: stray antialiasing and detached bits of drop shadow.
const MIN_BLOB_PIXELS := 1500
## How much of the car's artwork is body rather than wheels, top-down. The tyres
## in the sheet run from about 63% of its height to the bottom.
const CAR_BODY_FRACTION := 0.675
## Rows this far apart belong to different rows of the sheet.
const ROW_TOLERANCE := 120

## Reading order: left to right, top row first. "" skips an item.
const NAMES: Array[String] = [
	"plank", "barrel", "crate", "girder",
	"beam", "raft",
	"refrigerator", "tire", "pontoon", "car",
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_cut_master_sheet()
	for name: String in VARIANT_SHEETS:
		_cut_variant_sheet(name, VARIANT_SHEETS[name] as String)
	for name: String in SINGLE_SHEETS:
		_cut_single_sheet(name, SINGLE_SHEETS[name] as String)
	quit()


func _cut_single_sheet(name: String, source: String) -> void:
	var image := _load(source)
	if image == null:
		return
	var blobs := _sorted_blobs(image)
	if blobs.is_empty():
		push_warning("%s has nothing on it" % source)
		return
	# Blurred sheet edges can survive the checkerboard strip as faint scraps, so
	# take the biggest drawing rather than the first one found.
	var best: Rect2i = blobs[0]
	for box: Rect2i in blobs:
		if box.get_area() > best.get_area():
			best = box
	if blobs.size() > 1:
		push_warning("%s has %d drawings — taking the largest" % [source, blobs.size()])
	var cut := image.get_region(best)
	var path := "%s/%s.png" % [OUT_DIR, name]
	cut.save_png(ProjectSettings.globalize_path(path))
	print("%s  %dx%d" % [path, cut.get_width(), cut.get_height()])


## Every drawing on a variant sheet is the same object again, so they're just
## numbered top to bottom. The master sheet's drawing for that object is left
## alone — a variant sheet replaces it in the .tres, it doesn't overwrite it.
func _cut_variant_sheet(name: String, source: String) -> void:
	var image := _load(source)
	if image == null:
		return
	var blobs := _sorted_blobs(image)
	print("%s: %d variants" % [source, blobs.size()])
	for i in blobs.size():
		var path := "%s/%s_%d.png" % [OUT_DIR, name, i + 1]
		var cut := image.get_region(blobs[i])
		cut.save_png(ProjectSettings.globalize_path(path))
		print("  %s  %dx%d" % [path, cut.get_width(), cut.get_height()])


func _load(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		push_error("could not load %s" % path)
		return null
	image.convert(Image.FORMAT_RGBA8)
	if _is_fully_opaque(image):
		# Some sheets come out of the exporter with the transparency checkerboard
		# painted in as actual pixels. Reconstruct the alpha before cutting, or
		# every piece arrives on a grey tile.
		print("  %s has no alpha — stripping the checkerboard" % path)
		_strip_checkerboard(image)
	return image


func _is_fully_opaque(image: Image) -> bool:
	# A grid of samples: a sheet with real transparency has plenty of it.
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			if image.get_pixel(x, y).a < ALPHA_CUTOFF:
				return false
	return true


## True for the pale neutral squares the exporter paints behind transparency.
## Artwork is either coloured or dark, so this leaves most of it alone — but
## bare steel and white enamel land in here too, hence the tone test below.
func _is_checker(c: Color) -> bool:
	var spread: float = maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
	return spread < 0.05 and c.get_luminance() > 0.72
## How close a pixel must be to one of the sheet's two checker tones to count as
## more of the same checkerboard.
const TONE_MATCH := 0.012
## Share of a patch that must sit on those tones. Not all of it: the sheets are
## saved with a slight blur, which smears the squares where they meet.
const TONE_PURITY := 0.8


## Clears the checkerboard: first everything reachable from the border, then any
## enclosed patch of the same two flat tones — the hole through a wheel hub, say.
##
## The enclosed pass is deliberately strict. Painted metal and white enamel are
## pale and neutral too, but they're shaded, so they never consist of exactly the
## two tones the checkerboard is made of.
func _strip_checkerboard(image: Image) -> void:
	var tones := _strip_checkerboard_from_border(image)
	if tones.size() < 2:
		return

	var w := image.get_width()
	var h := image.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	for start in w * h:
		if seen[start] == 1 or not _is_checker(image.get_pixel(start % w, start / w)):
			continue
		# Gather the patch, then decide as a whole whether it's background.
		var patch := PackedInt32Array([start])
		seen[start] = 1
		var head := 0
		var on_tone := 0
		var hits := [false, false]
		while head < patch.size():
			var i := patch[head]
			head += 1
			var x := i % w
			var y := i / w
			var lum := image.get_pixel(x, y).get_luminance()
			var near := -1
			for t in tones.size():
				if absf(lum - tones[t]) <= TONE_MATCH:
					near = t
					break
			if near >= 0:
				on_tone += 1
				hits[near] = true
			for offset: Vector2i in [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
			]:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var j := ny * w + nx
				if seen[j] == 1 or not _is_checker(image.get_pixel(nx, ny)):
					continue
				seen[j] = 1
				patch.append(j)
		# Both tones must appear: a single flat tone is paint, not checks.
		if not (hits[0] and hits[1]):
			continue
		if float(on_tone) / float(patch.size()) < TONE_PURITY:
			continue
		for i: int in patch:
			image.set_pixel(i % w, i / w, Color(0, 0, 0, 0))


## Returns the two tones the checkerboard turned out to be made of, most common
## first, so the enclosed pass knows exactly what it's looking for.
func _strip_checkerboard_from_border(image: Image) -> PackedFloat32Array:
	var w := image.get_width()
	var h := image.get_height()
	var queue := PackedInt32Array()
	var seen := PackedByteArray()
	seen.resize(w * h)
	# Luminance histogram of what gets cleared, in 1/256 buckets.
	var buckets := PackedInt32Array()
	buckets.resize(256)

	for x in w:
		queue.append(x)
		queue.append((h - 1) * w + x)
	for y in h:
		queue.append(y * w)
		queue.append(y * w + w - 1)

	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		if seen[i] == 1:
			continue
		seen[i] = 1
		var x := i % w
		var y := i / w
		var here := image.get_pixel(x, y)
		if not _is_checker(here):
			continue
		buckets[clampi(roundi(here.get_luminance() * 255.0), 0, 255)] += 1
		image.set_pixel(x, y, Color(0, 0, 0, 0))
		for offset: Vector2i in [
			Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
		]:
			var nx := x + offset.x
			var ny := y + offset.y
			if nx >= 0 and ny >= 0 and nx < w and ny < h and seen[ny * w + nx] == 0:
				queue.append(ny * w + nx)

	return _dominant_tones(buckets)


## The two most-used luminances in the histogram, ignoring buckets adjacent to
## the winner — a tone smeared over neighbouring buckets is still one tone.
func _dominant_tones(buckets: PackedInt32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for _pass in 2:
		var best := -1
		for i in buckets.size():
			if buckets[i] > 0 and (best < 0 or buckets[i] > buckets[best]):
				best = i
		if best < 0:
			break
		out.append(best / 255.0)
		for i in range(maxi(best - 4, 0), mini(best + 5, buckets.size())):
			buckets[i] = 0
	return out


## Items in reading order: top row first, left to right within a row.
func _sorted_blobs(image: Image) -> Array[Rect2i]:
	var blobs := _find_blobs(image)
	blobs.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		if absi(a.position.y - b.position.y) > ROW_TOLERANCE:
			return a.position.y < b.position.y
		return a.position.x < b.position.x
	)
	return blobs


func _cut_master_sheet() -> void:
	var image := _load(SOURCE)
	if image == null:
		return
	print("source %dx%d" % [image.get_width(), image.get_height()])

	var blobs := _sorted_blobs(image)
	if blobs.size() != NAMES.size():
		push_warning("sheet has %d items but %d names" % [blobs.size(), NAMES.size()])

	for i in blobs.size():
		var name: String = NAMES[i] if i < NAMES.size() else "item_%d" % i
		if name.is_empty():
			continue
		var cut := image.get_region(blobs[i])
		# The car's wheels are drawn into its artwork, but the game's wheels are
		# separate bodies that spin. So the car also gets a wheel-less crop, and
		# the tyre art is used on the wheels themselves.
		if name == "car":
			var body := cut.get_region(Rect2i(
				0, 0, cut.get_width(), roundi(cut.get_height() * CAR_BODY_FRACTION)
			))
			body.save_png(ProjectSettings.globalize_path("%s/car_body.png" % OUT_DIR))
			print("%s/car_body.png  %dx%d" % [
				OUT_DIR, body.get_width(), body.get_height()
			])
		var path := "%s/%s.png" % [OUT_DIR, name]
		cut.save_png(ProjectSettings.globalize_path(path))
		print("%s  %dx%d  at %d,%d" % [
			path, cut.get_width(), cut.get_height(),
			blobs[i].position.x, blobs[i].position.y
		])


## Bounding boxes of the connected opaque regions, each item's drop shadow
## included — it's attached to the artwork and reads fine once the piece is
## scaled down into the strait.
func _find_blobs(image: Image) -> Array[Rect2i]:
	var w := image.get_width()
	var h := image.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var out: Array[Rect2i] = []

	for start in w * h:
		if seen[start] == 1 or image.get_pixel(start % w, start / w).a < ALPHA_CUTOFF:
			continue
		var queue := PackedInt32Array([start])
		seen[start] = 1
		var head := 0
		var box := Rect2i(Vector2i(start % w, start / w), Vector2i(1, 1))
		while head < queue.size():
			var i := queue[head]
			head += 1
			var x := i % w
			var y := i / w
			box = box.expand(Vector2i(x + 1, y + 1))
			# 8-connected: antialiased outlines leave diagonal-only links
			# between parts of the same drawing.
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var j: int = ny * w + nx
					if seen[j] == 1 or image.get_pixel(nx, ny).a < ALPHA_CUTOFF:
						continue
					seen[j] = 1
					queue.append(j)
		if queue.size() >= MIN_BLOB_PIXELS:
			out.append(box)
	return out
