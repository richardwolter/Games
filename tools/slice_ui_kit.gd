## Cuts the UI kit sheets into one transparent PNG per element.
##
##   godot --headless --script tools/slice_ui_kit.gd -- [--dump]
##
## Both sheets are PNGs drawn on flat white with black annotation text, so the
## backdrop keys cleanly. Annotation letters are small blobs; they are dropped by
## area rather than absorbed, which is the opposite of the button sheet, where
## loose bolts belonged to the sign beside them. Nothing here has detached parts
## except the SALVAGE SHOP header, which is why absorb distance is not zero.
##
## --dump prints every surviving blob's box and writes nothing, which is how the
## name table below was built.
extends SceneTree

const OUT_DIR := "res://art/ui/kit"
const BACKDROP_TOLERANCE := 0.22
const MIN_AREA := 3000
## Kept tight. The sheet rules a dashed measuring arrow beside and below several
## frames, and those dashes are small blobs sitting a few pixels off the art: at
## 14 they were absorbed and every frame came out with a ruler drawn on it.
const ABSORB_DISTANCE := 3

## name -> centre of the element on its sheet, as a fraction of sheet size.
const BORDERS := "res://art_source/UI_Elements_Borders.png"
const BUTTONS := "res://art_source/UI_Elements_Buttons.png"

var _sheets := {
	BORDERS: {
		"panel_settings_example": Vector2(0.169, 0.213),
		"panel_shop_example": Vector2(0.499, 0.239),
		"panel_levels_example": Vector2(0.833, 0.243),
		"frame_settings_sm": Vector2(0.243, 0.425),
		"frame_settings_md": Vector2(0.213, 0.595),
		"frame_settings_lg": Vector2(0.193, 0.840),
		"frame_scrap_metal": Vector2(0.417, 0.513),
		"frame_shop_sm": Vector2(0.600, 0.469),
		"frame_shop_md": Vector2(0.584, 0.622),
		"frame_shop_lg": Vector2(0.557, 0.850),
		"frame_levels_sm": Vector2(0.931, 0.472),
		"frame_levels_md": Vector2(0.899, 0.615),
		"frame_levels_lg": Vector2(0.887, 0.857),
		"hazard_stripe": Vector2(0.732, 0.493),
	},
	BUTTONS: {
		"btn_settings": Vector2(0.271, 0.133),
		"btn_keep_building": Vector2(0.271, 0.354),
		"btn_level_selection": Vector2(0.271, 0.563),
		"btn_buy": Vector2(0.278, 0.729),
		"btn_saved_builds": Vector2(0.287, 0.881),
		"btn_replay_save": Vector2(0.746, 0.208),
		"btn_next_crossing": Vector2(0.759, 0.609),
		"btn_leaderboard": Vector2(0.763, 0.837),
	},
}


## Frames whose painted interior is example content rather than panel fill, and
## the border thickness to keep, in left/top/right/bottom pixels. The level
## selection frames are drawn over a map with padlock nodes on it; the game puts
## its own cards there, so the middle is punched out to transparency.
const HOLLOW := {
	"frame_levels_lg": Vector4i(19, 33, 19, 21),
	"frame_levels_md": Vector4i(15, 25, 15, 16),
	"frame_levels_sm": Vector4i(10, 17, 10, 11),
}


## Frames whose painted title has to come off the frame and become a sprite of
## its own.
##
## A 9-patched frame stretches its top rail to whatever width the screen needs,
## and lettering painted on that rail stretches with it — at level select the
## panel is five times the width the artwork was drawn at. So the plate is cut
## out, and the rail behind it is rebuilt by copying a clean column of rail
## sideways across the hole. The game then draws the plate centred, at its own
## size, over the top edge.
##
## `rect` is the plate on the slice, `rail` the x of a column of rail to copy
## from, and `rail_bottom` how far down that copy runs.
const TITLE_CUT := {
	"frame_levels_lg": {
		# Wider than the plate looks: its shadow and bolt heads run a few pixels
		# past the lettering, and at 140 they survived the cut and came out
		# stretched across the rail as a ghost of the title.
		"rect": Rect2i(52, 0, 152, 36),
		"rail": 208,
		# The plate stood proud of the rail, so the rows above the rail's own top
		# edge belong to nothing once it is gone and are cleared rather than
		# filled — left filled, they were a pale bar hanging over the frame.
		"rail_top": 7,
		"rail_bottom": 36,
		"out": "levels_title",
	},
}


func _initialize() -> void:
	var dump := "--dump" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for sheet: String in _sheets:
		_slice(sheet, _sheets[sheet], dump)
	quit()


func _slice(path: String, names: Dictionary, dump: bool) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		printerr("could not load ", path)
		return
	image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()
	print("\n%s  %dx%d" % [path.get_file(), w, h])

	var backdrop := image.get_pixel(2, 2)
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			var d := absf(c.r - backdrop.r) + absf(c.g - backdrop.g) + absf(c.b - backdrop.b)
			solid[y * w + x] = 1 if d > BACKDROP_TOLERANCE else 0

	var labels := PackedInt32Array()
	labels.resize(w * h)
	var owner := PackedInt32Array()
	var boxes := _find_blobs(solid, w, h, labels, owner)

	for slot in boxes.size():
		var box: Rect2i = boxes[slot]
		var centre := Vector2(
			(box.position.x + box.size.x * 0.5) / float(w),
			(box.position.y + box.size.y * 0.5) / float(h)
		)
		var best := ""
		var best_distance := 0.06
		for key: String in names:
			var d: float = centre.distance_to(names[key] as Vector2)
			if d < best_distance:
				best_distance = d
				best = key
		if dump or best.is_empty():
			print("  blob %2d  %4d,%-4d %4dx%-4d  centre %.3f,%.3f  %s" % [
				slot, box.position.x, box.position.y, box.size.x, box.size.y,
				centre.x, centre.y, best
			])
			continue
		_write_cutout(image, box, labels, owner, slot, w, "%s/%s.png" % [OUT_DIR, best])


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

	var kept: Array[int] = []
	for id in boxes.size():
		if areas[id] >= MIN_AREA:
			kept.append(id)

	owner.resize(boxes.size())
	for id in boxes.size():
		owner[id] = -1
	for slot in kept.size():
		owner[kept[slot]] = slot

	for id in boxes.size():
		if owner[id] != -1 or areas[id] >= MIN_AREA:
			continue
		var best := -1
		var best_distance := float(ABSORB_DISTANCE)
		for slot in kept.size():
			var gap := _box_gap(boxes[id], boxes[kept[slot]])
			if gap <= best_distance:
				best_distance = gap
				best = slot
		if best != -1:
			owner[id] = best

	var out: Array[Rect2i] = []
	for slot in kept.size():
		out.append(boxes[kept[slot]])
	for id in boxes.size():
		if owner[id] != -1 and areas[id] < MIN_AREA:
			out[owner[id]] = out[owner[id]].merge(boxes[id])
	return out


func _box_gap(a: Rect2i, b: Rect2i) -> float:
	var dx := maxi(maxi(b.position.x - a.end.x, a.position.x - b.end.x), 0)
	var dy := maxi(maxi(b.position.y - a.end.y, a.position.y - b.end.y), 0)
	return Vector2(dx, dy).length()


func _write_cutout(
	sheet: Image, box: Rect2i,
	labels: PackedInt32Array, owner: PackedInt32Array, slot: int, sheet_width: int,
	path: String
) -> void:
	box = box.grow(1).intersection(Rect2i(0, 0, sheet.get_width(), sheet.get_height()))
	var out := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	for y in box.size.y:
		for x in box.size.x:
			var sx := box.position.x + x
			var sy := box.position.y + y
			var label := labels[sy * sheet_width + sx]
			if label < 0 or owner[label] != slot:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			out.set_pixel(x, y, sheet.get_pixel(sx, sy))
	var key := path.get_file().get_basename()
	if TITLE_CUT.has(key):
		var cut: Dictionary = TITLE_CUT[key]
		var rect: Rect2i = cut["rect"]
		var plate := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
		plate.blit_rect(out, rect, Vector2i.ZERO)
		plate.save_png(ProjectSettings.globalize_path(
			"%s/%s.png" % [path.get_base_dir(), cut["out"]]
		))
		var rail_x: int = cut["rail"]
		var rail_bottom: int = cut["rail_bottom"]
		var rail_top: int = cut["rail_top"]
		for y in rail_bottom:
			var run := out.get_pixel(rail_x, y) if y >= rail_top else Color(0, 0, 0, 0)
			for x in range(rect.position.x, rect.end.x):
				out.set_pixel(x, y, run)
		print("  %-22s %4dx%-4d  cut from %s" % [
			cut["out"] + ".png", rect.size.x, rect.size.y, key
		])
	if HOLLOW.has(key):
		var edge: Vector4i = HOLLOW[key]
		for y in range(edge.y, box.size.y - edge.w):
			for x in range(edge.x, box.size.x - edge.z):
				out.set_pixel(x, y, Color(0, 0, 0, 0))
	out.save_png(ProjectSettings.globalize_path(path))
	print("  %-22s %4dx%-4d%s" % [
		path.get_file(), box.size.x, box.size.y, "  hollowed" if HOLLOW.has(key) else ""
	])
