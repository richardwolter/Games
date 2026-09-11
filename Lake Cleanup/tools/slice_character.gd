## Cuts the angler's sprite sheet into a catalogue.
##
## The source is twelve flat, hand-trimmed strips — one per animation and compass direction,
## already merged — out of Character_Sprite_Sheet.psd via the psd-extract skill, not a
## grid-aligned PNG. There is no shared cell size to check against; each strip's own width
## divided by its own frame count is the only grid there is, and it is allowed to differ
## a pixel or two between directions of the same animation, because the source does.
##
## Four real directions: the art draws north, south, east and west each on their own, so
## there is nothing here to flip at draw time. The hat is painted in.
##
##   godot --headless --path . --script res://tools/slice_character.gd
extends SceneTree

## Where the psd-extract skill left the twelve strips.
const SOURCE_DIR := "res://art_source/character_extracted/"

## Each animation: the pose-name prefix the game will ask for, the layer-name slug
## psd-extract wrote the strip under (they don't all match the prefix), and the frame count.
const ANIMS := [
	{"prefix": "idle", "slug": "idle", "frames": 9},
	{"prefix": "run", "slug": "running", "frames": 17},
	{"prefix": "cast", "slug": "casting", "frames": 16},
]

const DIRS := ["south", "north", "east", "west"]

const OUT_PNG := "res://assets/character.png"
const OUT_JSON := "res://assets/character.json"
const DEBUG_PNG := "res://assets/sliced_character.png"

const ZOOM := 5

## Anything at or over this alpha counts as the figure when its box is measured.
const INK_ALPHA := 0.5


func _init() -> void:
	var strips: Array = []
	var packed_wide := 0
	var packed_tall := 0
	for anim: Dictionary in ANIMS:
		for dir in DIRS:
			var path := "%s%s_%s.png" % [SOURCE_DIR, anim["slug"], dir]
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			if image == null:
				printerr("could not read %s" % path)
				quit(1)
				return
			image.convert(Image.FORMAT_RGBA8)
			var frames := int(anim["frames"])
			var cell_w := image.get_width() / float(frames)
			if cell_w < 4.0:
				printerr("%s is too narrow for %d frames" % [path, frames])
				quit(1)
				return
			strips.append({
				"pose": "%s_%s" % [anim["prefix"], dir],
				"art": image,
				"frames": frames,
				"cell_w": cell_w,
				"cell_h": image.get_height(),
			})
			packed_wide = maxi(packed_wide, image.get_width())
			packed_tall += image.get_height()

	var atlas := Image.create(packed_wide, packed_tall, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0.0, 0.0, 0.0, 0.0))

	var poses := {}
	var y := 0
	for strip: Dictionary in strips:
		var image: Image = strip["art"]
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(0, y))
		var cell_w: float = strip["cell_w"]
		var cell_h: int = strip["cell_h"]
		var frames: Array = []
		for column in int(strip["frames"]):
			# Whole-pixel columns off a fractional cell width: rounded edges rather than a
			# truncated width repeated, so the last frame is not left thinner than the rest
			# by everyone else's rounding.
			var left := int(round(column * cell_w))
			var right := int(round((column + 1) * cell_w))
			var box := Rect2i(left, y, right - left, cell_h)
			var ink := _ink(atlas, box)
			frames.append({
				"region": [box.position.x, box.position.y, box.size.x, box.size.y],
				"ink": (
					[
						ink.position.x - box.position.x, ink.position.y - box.position.y,
						ink.size.x, ink.size.y,
					] if ink.size.x > 0 else [0, 0, box.size.x, box.size.y]
				),
			})
		poses[strip["pose"]] = frames
		y += cell_h

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
		"poses": poses,
	}, "\t"))
	file.close()

	_debug_picture(atlas, poses)
	printerr("wrote %s: %s" % [OUT_JSON, ", ".join(PackedStringArray(poses.keys()))])
	quit(0)


## The box the drawing actually fills inside its cell.
func _ink(atlas: Image, cell: Rect2i) -> Rect2i:
	var low := Vector2i(cell.position.x + cell.size.x, cell.position.y + cell.size.y)
	var high := Vector2i(cell.position.x - 1, cell.position.y - 1)
	for y in range(cell.position.y, cell.position.y + cell.size.y):
		for x in range(cell.position.x, cell.position.x + cell.size.x):
			if atlas.get_pixel(x, y).a < INK_ALPHA:
				continue
			low.x = mini(low.x, x)
			low.y = mini(low.y, y)
			high.x = maxi(high.x, x)
			high.y = maxi(high.y, y)
	if high.x < low.x or high.y < low.y:
		return Rect2i()
	return Rect2i(low, high - low + Vector2i.ONE)


## The atlas blown up over a grey, with the cell grid on it and every measured ink box.
func _debug_picture(atlas: Image, poses: Dictionary) -> void:
	var shown := Image.create(
		atlas.get_width() * ZOOM, atlas.get_height() * ZOOM, false, Image.FORMAT_RGBA8
	)
	shown.fill(Color(0.4, 0.42, 0.45, 1.0))
	for y in atlas.get_height():
		for x in atlas.get_width():
			var pixel := atlas.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			for dy in ZOOM:
				for dx in ZOOM:
					shown.set_pixel(x * ZOOM + dx, y * ZOOM + dy, pixel)
	for name: String in poses:
		for frame: Dictionary in poses[name]:
			var region: Array = frame["region"]
			_outline(
				shown,
				Rect2i(
					region[0] * ZOOM, region[1] * ZOOM, region[2] * ZOOM, region[3] * ZOOM
				),
				Color(0.35, 0.6, 1.0)
			)
			var ink: Array = frame["ink"]
			_outline(
				shown,
				Rect2i(
					(region[0] + ink[0]) * ZOOM, (region[1] + ink[1]) * ZOOM,
					ink[2] * ZOOM, ink[3] * ZOOM
				),
				Color(1.0, 0.45, 0.2)
			)
	shown.save_png(ProjectSettings.globalize_path(DEBUG_PNG))


func _outline(image: Image, box: Rect2i, tint: Color) -> void:
	var right := mini(box.position.x + box.size.x - 1, image.get_width() - 1)
	var bottom := mini(box.position.y + box.size.y - 1, image.get_height() - 1)
	if right < box.position.x or bottom < box.position.y:
		return
	for x in range(box.position.x, right + 1):
		image.set_pixel(x, box.position.y, tint)
		image.set_pixel(x, bottom, tint)
	for y in range(box.position.y, bottom + 1):
		image.set_pixel(box.position.x, y, tint)
		image.set_pixel(right, y, tint)
