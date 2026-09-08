## Cuts the dog sheet into named animations and writes down where each frame sits.
##
## This sheet is a plain grid — eight frames across, nine rows down, every cell 64x48 — so
## unlike the pigeons there is nothing to find. What has to be measured is where the dog
## actually is inside its cell: the frames are drawn loose in the box and the animal moves
## around inside it, so laying every cell out by its corner makes the dog jitter on the spot
## while it walks. Each frame is shrunk onto its own pixels and its footline written down,
## and the game stands the dog on that instead.
##
## Only the rows the game uses are named. The sheet has sitting, a second run and a beg
## in it; naming rows nobody draws makes a catalogue that lies about what the game has.
##
## Writes assets/dog.json. scripts/dog.gd reads it and never runs this.
##
##   godot --headless --path . --script res://tools/slice_dog.gd
extends SceneTree

const SHEET := "res://assets/Dogs-Sprite-Sheet.png"
const OUT_JSON := "res://assets/dog.json"

## The grid the sheet is drawn on.
const CELL := Vector2i(64, 48)
const COLUMNS := 8

## Anything at or under this alpha is background rather than dog.
const CLEAR_ALPHA := 0.35

## A cell with less than this drawn in it is an empty corner of the sheet, not a frame. The
## sleeping row is the short one — four frames and then nothing.
const MIN_PIXELS := 20

## Which row is which, counting from the top. The names are what scripts/dog.gd asks for.
const ROWS := {
	"idle": 0,
	"laid": 2,
	"run": 3,
	"walk": 4,
	"sleep": 8,
}


func _init() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if image == null:
		printerr("could not read %s" % SHEET)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)

	var sequences := {}
	for name: String in ROWS:
		var frames: Array = []
		var row: int = ROWS[name]
		for column in COLUMNS:
			var corner := Vector2i(column * CELL.x, row * CELL.y)
			var box := _trim(image, corner)
			if box.size.x <= 0:
				continue
			frames.append({
				"region": [box.position.x, box.position.y, box.size.x, box.size.y],
				# Where the dog stands, as an offset inside the trimmed box: the middle of
				# its own cell along the bottom edge. The middle of the *box* would be
				# wrong — a wagging tail widens the box on one side, and standing the dog on
				# the middle of that makes it shuffle sideways on the spot while it breathes.
				"foot": [CELL.x / 2 - (box.position.x - corner.x), box.size.y],
			})
		if frames.is_empty():
			printerr("no frames in row %s" % name)
			quit(1)
			return
		sequences[name] = frames

	var file := FileAccess.open(OUT_JSON, FileAccess.WRITE)
	if file == null:
		printerr("could not write %s" % OUT_JSON)
		quit(1)
		return
	file.store_string(JSON.stringify({
		"sheet": SHEET,
		"cell": [CELL.x, CELL.y],
		"sequences": sequences,
	}, "\t", true) + "\n")
	file.close()
	for name: String in sequences:
		print("%s: %d frames" % [name, (sequences[name] as Array).size()])
	print("wrote %s" % OUT_JSON)
	quit()


## One cell shrunk onto the pixels drawn in it. An empty cell comes back with no size.
func _trim(image: Image, corner: Vector2i) -> Rect2i:
	var low := Vector2i(CELL.x, CELL.y)
	var high := Vector2i(-1, -1)
	var drawn := 0
	for y in CELL.y:
		for x in CELL.x:
			if image.get_pixel(corner.x + x, corner.y + y).a <= CLEAR_ALPHA:
				continue
			drawn += 1
			low.x = mini(low.x, x)
			low.y = mini(low.y, y)
			high.x = maxi(high.x, x)
			high.y = maxi(high.y, y)
	if drawn < MIN_PIXELS or high.x < low.x:
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)
	return Rect2i(corner + low, high - low + Vector2i.ONE)
