## Cuts the bird and fish sheets into one transparent PNG per animal.
##
##   godot --headless --script tools/slice_wildlife.gd
##
## Same problem as the button sheet: a JPEG on a flat backdrop, so there is no
## alpha and no clean colour key either — JPEG rings every edge with off-colour
## pixels. The backdrop is sampled from a corner and everything close to it is
## cut, with the tolerance loose enough to take the ringing with it.
##
## Animals are found rather than measured out: a flood fill labels every blob of
## non-backdrop pixels and the big ones are the animals. The small ones are the
## sparkle watermark in the corner of both sheets, which the area floor drops.
##
## They come out sorted left-to-right, top-to-bottom and numbered, because
## nothing downstream cares which bird is which — they are picked at random.
extends SceneTree

const SHEETS: Array[Dictionary] = [
	{
		"source": "res://art_source/Birds_Background.jpg",
		"out_dir": "res://art/wildlife",
		"prefix": "bird",
		# The distant trio is one small blob and wanted as one sprite, so the
		# floor here is far below the button sheet's.
		"min_area": 900,
	},
	{
		"source": "res://art_source/Fishes_Strait.jpg",
		"out_dir": "res://art/wildlife",
		"prefix": "fish",
		"min_area": 4000,
	},
]

## Colour distance from the sampled backdrop, summed across RGB in 0..1, below
## which a pixel counts as backdrop.
const TOLERANCE := 0.30
## Pixels this close to the backdrop colour are faded rather than cut outright,
## which is what keeps the animals' outlines from coming out jagged.
const FEATHER := 0.14


func _initialize() -> void:
	for sheet: Dictionary in SHEETS:
		_slice(sheet)
	quit()


func _slice(sheet: Dictionary) -> void:
	var source: String = sheet["source"]
	var image := _load(source)
	if image == null:
		print("missing: %s" % source)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sheet["out_dir"]))
	var backdrop := image.get_pixel(2, 2)
	var mask := _key_out(image, backdrop)
	var blobs := _find_blobs(mask, image.get_width(), image.get_height(), sheet["min_area"])
	blobs.sort_custom(_reading_order)

	var index := 1
	for box: Rect2i in blobs:
		var cut := image.get_region(box)
		var out: String = "%s/%s_%d.png" % [sheet["out_dir"], sheet["prefix"], index]
		cut.save_png(ProjectSettings.globalize_path(out))
		print("%s  %dx%d" % [out, box.size.x, box.size.y])
		index += 1


## Reads the sheet and replaces the backdrop with transparency in place, then
## returns a per-pixel "is this part of an animal" mask.
## Read off disk rather than through load(): these are source art, and a sheet
## dropped in the folder five minutes ago has no import record yet.
func _load(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


func _key_out(image: Image, backdrop: Color) -> PackedByteArray:
	var width := image.get_width()
	var height := image.get_height()
	var mask := PackedByteArray()
	mask.resize(width * height)
	for y in height:
		for x in width:
			var pixel := image.get_pixel(x, y)
			var distance: float = (
				absf(pixel.r - backdrop.r)
				+ absf(pixel.g - backdrop.g)
				+ absf(pixel.b - backdrop.b)
			)
			if distance <= TOLERANCE:
				image.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b, 0.0))
				mask[y * width + x] = 0
			else:
				# A soft ramp just past the threshold, so an edge that the key
				# only half caught fades out instead of stepping.
				var alpha: float = clampf((distance - TOLERANCE) / FEATHER, 0.0, 1.0)
				image.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b, alpha))
				mask[y * width + x] = 1 if alpha > 0.5 else 0
	return mask


## Every connected run of animal pixels, as bounding boxes, biggest-first filter
## applied. Iterative rather than recursive: a bird is tens of thousands of
## pixels and a recursive fill would blow the stack.
func _find_blobs(
	mask: PackedByteArray, width: int, height: int, min_area: int
) -> Array[Rect2i]:
	var seen := PackedByteArray()
	seen.resize(width * height)
	var boxes: Array[Rect2i] = []

	for start in width * height:
		if mask[start] == 0 or seen[start] == 1:
			continue
		var stack := PackedInt32Array([start])
		seen[start] = 1
		var min_x := width
		var min_y := height
		var max_x := 0
		var max_y := 0
		var area := 0

		while not stack.is_empty():
			var at := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var x := at % width
			var y := at / width
			area += 1
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

			for step: Vector2i in [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
			]:
				var nx := x + step.x
				var ny := y + step.y
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					continue
				var next := ny * width + nx
				if mask[next] == 1 and seen[next] == 0:
					seen[next] = 1
					stack.append(next)

		if area >= min_area:
			boxes.append(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
	return boxes


## Top row before bottom row, left before right. Rows are decided by overlap
## rather than by exact y, since nothing on these sheets is aligned.
func _reading_order(a: Rect2i, b: Rect2i) -> bool:
	if absf(float(a.position.y - b.position.y)) > float(maxi(a.size.y, b.size.y)) * 0.6:
		return a.position.y < b.position.y
	return a.position.x < b.position.x
