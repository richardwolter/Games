## Cuts the button sheet into one transparent PNG per button.
##
##   godot --headless --script tools/slice_buttons.gd
##
## The sheet is a JPEG on a flat backdrop, so there is no alpha to work from and
## no clean colour key either — JPEG rings every edge with off-colour pixels. The
## backdrop is sampled from a corner and everything close to it is cut; the
## threshold is deliberately loose enough to take the ringing with it.
##
## Buttons are found rather than hand-measured: a flood fill labels every blob of
## non-backdrop pixels, the big ones are the buttons, and small ones near a big
## one are absorbed into it, which is what keeps the loose bolts and the wrench
## with the Salvage Shop sign they belong to.
extends SceneTree

const SHEET := "res://art_source/Buttons.jpg"
const OUT_DIR := "res://art/ui"

## Colour distance from the sampled backdrop, summed across RGB in 0..1, below
## which a pixel is considered backdrop.
const BACKDROP_TOLERANCE := 0.30
## Blobs smaller than this are decorations, not buttons.
const MIN_BUTTON_AREA := 4000
## A decoration this close to a button's box is part of that button. Kept tight:
## at 46 the NEW GAME sign reached down and swallowed the wrench and bolts that
## belong to SALVAGE SHOP, and came out as one 423x492 blob covering both.
const ABSORB_DISTANCE := 18

## Where each button sits on the sheet, as a fraction of its size. Blobs are
## named by whichever of these they land nearest.
##
## Not by reading order, which is what this first tried: RECALL ALL and START
## CROSSING share a column, so sorting by row-then-column interleaved them and
## handed two buttons each other's names.
const CENTRES := {
	"new_game": Vector2(0.20, 0.22),
	"continue": Vector2(0.53, 0.22),
	"quit": Vector2(0.84, 0.22),
	"salvage_shop": Vector2(0.21, 0.70),
	"recall_all": Vector2(0.57, 0.52),
	"start_crossing": Vector2(0.57, 0.83),
	"piece_blank": Vector2(0.86, 0.73),
}


func _initialize() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if image == null:
		printerr("could not load ", SHEET)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()
	print("sheet %dx%d" % [w, h])

	var backdrop := image.get_pixel(2, 2)
	print("backdrop %s" % backdrop)

	# Mask: true where a pixel belongs to a button.
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			var d := (
				absf(c.r - backdrop.r) + absf(c.g - backdrop.g) + absf(c.b - backdrop.b)
			)
			solid[y * w + x] = 1 if d > BACKDROP_TOLERANCE else 0

	var labels := PackedInt32Array()
	labels.resize(w * h)
	var owner := PackedInt32Array()
	var boxes := _find_blobs(solid, w, h, labels, owner)
	print("found %d blobs over %d px" % [boxes.size(), MIN_BUTTON_AREA])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var taken: Dictionary = {}
	for button in boxes.size():
		var box: Rect2i = boxes[button]
		var centre := Vector2(
			(box.position.x + box.size.x * 0.5) / float(w),
			(box.position.y + box.size.y * 0.5) / float(h)
		)
		var best := ""
		var best_distance := INF
		for key: String in CENTRES:
			if taken.has(key):
				continue
			var d: float = centre.distance_to(CENTRES[key] as Vector2)
			if d < best_distance:
				best_distance = d
				best = key
		if best.is_empty():
			printerr("unmatched blob at %s" % str(box))
			continue
		taken[best] = true
		_write_cutout(image, box, backdrop, labels, owner, button, w,
			"%s/%s.png" % [OUT_DIR, best])
	quit()


## Flood fills every solid region, then works out which button each region
## belongs to.
##
## `labels` comes back holding a region id per pixel (-1 for backdrop) and
## `owner` maps each region to the button that owns it (-1 for discarded). That
## pairing is what lets a cutout keep only its own pixels: the buttons sit close
## enough that RECALL ALL's box, once grown to take in its pipe fittings, reaches
## over the top of the START CROSSING sign below it. Cropping by box alone
## printed a slice of one button into another.
func _find_blobs(
	solid: PackedByteArray, w: int, h: int,
	labels: PackedInt32Array, owner: PackedInt32Array
) -> Array[Rect2i]:
	for i in labels.size():
		labels[i] = -1

	var boxes: Array[Rect2i] = []
	var areas: Array[int] = []
	for start_y in h:
		for start_x in w:
			var start := start_y * w + start_x
			if solid[start] == 0 or labels[start] != -1:
				continue
			var id := boxes.size()
			labels[start] = id
			var queue: Array[int] = [start]
			var area := 0
			var box := Rect2i(start_x, start_y, 1, 1)
			while not queue.is_empty():
				var index: int = queue.pop_back()
				var x := index % w
				var y := index / w
				area += 1
				box = box.expand(Vector2i(x, y))
				for dy: int in [-1, 0, 1]:
					for dx: int in [-1, 0, 1]:
						var nx: int = x + dx
						var ny: int = y + dy
						if nx < 0 or ny < 0 or nx >= w or ny >= h:
							continue
						var n: int = ny * w + nx
						if solid[n] == 1 and labels[n] == -1:
							labels[n] = id
							queue.append(n)
			boxes.append(box)
			areas.append(area)

	# Which regions are buttons, and which are loose bolts and wrenches.
	var buttons: Array[int] = []
	for id in boxes.size():
		if areas[id] >= MIN_BUTTON_AREA:
			buttons.append(id)

	owner.resize(boxes.size())
	for id in boxes.size():
		owner[id] = -1
	for slot in buttons.size():
		owner[buttons[slot]] = slot

	# Each decoration joins the NEAREST button, not the first one whose grown box
	# happens to touch it. First-match handed RECALL ALL a bolt that actually
	# belonged to the sign below, dragging its box down over that sign.
	for id in boxes.size():
		if owner[id] != -1 or areas[id] >= MIN_BUTTON_AREA:
			continue
		var best := -1
		var best_distance := float(ABSORB_DISTANCE)
		for slot in buttons.size():
			var gap := _box_gap(boxes[id], boxes[buttons[slot]])
			if gap <= best_distance:
				best_distance = gap
				best = slot
		if best != -1:
			owner[id] = best

	var out: Array[Rect2i] = []
	for slot in buttons.size():
		out.append(boxes[buttons[slot]])
	for id in boxes.size():
		if owner[id] != -1 and areas[id] < MIN_BUTTON_AREA:
			out[owner[id]] = out[owner[id]].merge(boxes[id])
	return out


## Shortest distance between two boxes, 0 if they touch or overlap.
func _box_gap(a: Rect2i, b: Rect2i) -> float:
	var dx := maxi(maxi(b.position.x - a.end.x, a.position.x - b.end.x), 0)
	var dy := maxi(maxi(b.position.y - a.end.y, a.position.y - b.end.y), 0)
	return Vector2(dx, dy).length()


## Crops one button out, keying the backdrop to transparent and dropping any
## pixel that belongs to a different button.
func _write_cutout(
	sheet: Image, box: Rect2i, backdrop: Color,
	labels: PackedInt32Array, owner: PackedInt32Array, button: int, sheet_width: int,
	path: String
) -> void:
	# A pixel of margin, so a button that touches its own bounding box doesn't
	# come out with a hard-clipped edge.
	box = box.grow(1).intersection(Rect2i(0, 0, sheet.get_width(), sheet.get_height()))
	var out := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	var kept := 0
	var rejected := 0
	for y in box.size.y:
		for x in box.size.x:
			var sx := box.position.x + x
			var sy := box.position.y + y
			var label := labels[sy * sheet_width + sx]
			if label < 0:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			if owner[label] != button:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
				rejected += 1
				continue
			out.set_pixel(x, y, sheet.get_pixel(sx, sy))
			kept += 1
	out.save_png(ProjectSettings.globalize_path(path))
	print("  %-18s %4dx%-4d  %6d px kept, %5d px belonged to a neighbour" % [
		path.get_file(), box.size.x, box.size.y, kept, rejected
	])
