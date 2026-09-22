## Cuts the dog sheets into named animations and writes down where each frame sits.
##
## Every sheet in the PixelDogsSprites pack is the same plain grid — eight frames across,
## nine rows down, every cell 64x48 — so unlike the pigeons there is nothing to find. What
## has to be measured is where the dog actually is inside its cell: the frames are drawn
## loose in the box and the animal moves around inside it, so laying every cell out by its
## corner makes the dog jitter on the spot while it walks. Each frame is shrunk onto its own
## pixels and its footline written down, and the game stands the dog on that instead.
##
## Three breeds (2026-09-22, Richard's pick off `tools/last_dog_pack.png`): 22 the yellow
## dog the game always had, 02 the orange one, 20 the tan-and-white one. One json each,
## because the trimmed boxes are the drawing's own and no two breeds are drawn identically.
##
## The mouth is measured, not guessed. The pack pairs every plain sheet with an odd-numbered
## twin of the same dog with its mouth open, and the three red pixels of its tongue say how
## high the jaws are. Where a twin frame is the same drawing (a few dozen pixels differ, the
## mouth itself) that row is the mouth's height; where the twin's row runs out or holds a
## different pose, the height is the one the matched frames of that row agree on (the idle
## row's for a row with none). The mouth's *x* is always the plain frame's own leading edge
## at that height, `JAW_IN` pixels in — the tongue sits that far behind the nose tip, and
## taking the tongue's x where it was found and the nose's where it was not put the mouth
## three pixels apart on neighbouring frames. The twins are read from art_source and never
## ship.
##
## Only the rows the game uses are named. The beg row stays unnamed: naming rows nobody
## draws makes a catalogue that lies about what the game has.
##
## Writes assets/dogs/dog_NN.json. scripts/dog_art.gd reads them and never runs this.
##
##   godot --headless --path . --script res://tools/slice_dog.gd
extends SceneTree

const PACK := "res://art_source/PixelDogsSprites/Dogs-Remastered-%02d.png"
const SHEET := "res://assets/dogs/dog_%02d.png"
const OUT_JSON := "res://assets/dogs/dog_%02d.json"

## The pack numbers of the plain sheets, in the order the pack hands them out.
const BREEDS := [22, 2, 20]

## The grid the sheets are drawn on.
const CELL := Vector2i(64, 48)
const COLUMNS := 8

## Anything at or under this alpha is background rather than dog.
const CLEAR_ALPHA := 0.35

## A cell with less than this drawn in it is an empty corner of the sheet, not a frame. The
## sleeping row is the short one — four frames and then nothing.
const MIN_PIXELS := 20

## A twin frame that differs from the plain one by more pixels than this is another pose,
## and its tongue says nothing about this frame.
const TWIN_SAME := 80

## How far behind the nose tip the jaws are, in sheet pixels.
const JAW_IN := 2

## Which row is which, counting from the top. The names are what scripts/dog.gd asks for.
## The odd twin's rows: idle 0, sit 1, laid 2, run 3, walk 4, beg 5, sleep 6.
const ROWS := {
	"idle": 0,
	"sit": 1,
	"laid": 2,
	"run": 3,
	"walk": 4,
	"run2": 5,
	"walk2": 6,
	"sleep": 8,
}
const TWIN_ROWS := {"idle": 0, "sit": 1, "laid": 2, "run": 3, "walk": 4}


func _init() -> void:
	for breed: int in BREEDS:
		if not _cut(breed):
			quit(1)
			return
	quit()


func _cut(breed: int) -> bool:
	var sheet := SHEET % breed
	var image := Image.load_from_file(ProjectSettings.globalize_path(sheet))
	if image == null:
		printerr("could not read %s" % sheet)
		return false
	image.convert(Image.FORMAT_RGBA8)
	var twin := Image.load_from_file(ProjectSettings.globalize_path(PACK % (breed + 1)))
	if twin != null:
		twin.convert(Image.FORMAT_RGBA8)

	var sequences := {}
	var idle_row := -1
	for name: String in ROWS:
		var frames: Array = []
		var row: int = ROWS[name]
		var mouth_rows: Array = []
		for column in COLUMNS:
			var corner := Vector2i(column * CELL.x, row * CELL.y)
			var box := _trim(image, corner)
			if box.size.x <= 0:
				continue
			var tongue := -1
			if twin != null and TWIN_ROWS.has(name):
				var twin_corner := Vector2i(column * CELL.x, int(TWIN_ROWS[name]) * CELL.y)
				if _differ(image, corner, twin, twin_corner) <= TWIN_SAME:
					tongue = _tongue(twin, twin_corner)
			if tongue >= 0:
				mouth_rows.append(tongue)
			frames.append({
				"region": [box.position.x, box.position.y, box.size.x, box.size.y],
				# Where the dog stands, as an offset inside the trimmed box: the middle of
				# its own cell along the bottom edge. The middle of the *box* would be
				# wrong — a wagging tail widens the box on one side, and standing the dog on
				# the middle of that makes it shuffle sideways on the spot while it breathes.
				"foot": [CELL.x / 2 - (box.position.x - corner.x), box.size.y],
				"mouth": null,
				"_tongue": tongue,
				"_corner": [corner.x, corner.y],
			})
		if frames.is_empty():
			printerr("no frames in row %s" % name)
			return false
		# Every frame's mouth: its own nose at the tongue's height — this frame's where the
		# twin answered, the row's where it did not, the idle row's for a row with none.
		var row_height := _typical(mouth_rows)
		if row_height < 0:
			row_height = idle_row if idle_row >= 0 else int(CELL.y * 0.55)
		for cell: Dictionary in frames:
			var corner := Vector2i(cell["_corner"][0], cell["_corner"][1])
			var height: int = cell["_tongue"] if int(cell["_tongue"]) >= 0 else row_height
			# A sleeping dog is a short picture and the idle row's height is over its head:
			# keep the height inside the drawing.
			var top := int(cell["region"][1]) - corner.y
			var bottom := top + int(cell["region"][3]) - 1
			height = clampi(height, top, bottom)
			var nose := _nose(image, corner, height)
			cell["mouth"] = [nose.x + JAW_IN - (int(cell["region"][0]) - corner.x), nose.y - top]
			cell.erase("_corner")
			cell.erase("_tongue")
		if name == "idle":
			idle_row = _typical(mouth_rows)
		sequences[name] = frames

	var out := OUT_JSON % breed
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		printerr("could not write %s" % out)
		return false
	file.store_string(JSON.stringify({
		"sheet": sheet,
		"breed": breed,
		"cell": [CELL.x, CELL.y],
		"sequences": sequences,
	}, "\t", true) + "\n")
	file.close()
	for name: String in sequences:
		print("%02d %s: %d frames" % [breed, name, (sequences[name] as Array).size()])
	print("wrote %s" % out)
	return true


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


## How many pixels two cells disagree on: drawn in one and not the other, or a different colour.
func _differ(a: Image, at: Vector2i, b: Image, bt: Vector2i) -> int:
	var count := 0
	for y in CELL.y:
		for x in CELL.x:
			var p := a.get_pixel(at.x + x, at.y + y)
			var q := b.get_pixel(bt.x + x, bt.y + y)
			var pa := p.a > CLEAR_ALPHA
			var qa := q.a > CLEAR_ALPHA
			if pa != qa or (pa and not p.is_equal_approx(q)):
				count += 1
	return count


## The row of the tongue in a twin cell — the leftmost pure-red pixels, which is the tongue
## and not the dog's own shading (an orange coat has red-leaning shadows under the belly).
## -1 with no tongue there.
func _tongue(twin: Image, corner: Vector2i) -> int:
	var best := Vector2i(CELL.x, -1)
	for y in CELL.y:
		for x in CELL.x:
			var p := twin.get_pixel(corner.x + x, corner.y + y)
			if p.a <= CLEAR_ALPHA or p.r < 0.6 or p.g > 0.3 or p.b > 0.3:
				continue
			if x < best.x:
				best = Vector2i(x, y)
	return best.y


## The median of a list of rows; -1 for none.
func _typical(rows: Array) -> int:
	if rows.is_empty():
		return -1
	var sorted := rows.duplicate()
	sorted.sort()
	return int(sorted[sorted.size() / 2])


## The leading edge of the plain frame at about `height`: the leftmost drawn pixel over the
## few rows round it, one pixel in, which is the tip of the nose on this left-facing sheet.
func _nose(image: Image, corner: Vector2i, height: int) -> Vector2i:
	var best := Vector2i(CELL.x, height)
	for y in range(maxi(height - 3, 0), mini(height + 4, CELL.y)):
		for x in CELL.x:
			if image.get_pixel(corner.x + x, corner.y + y).a > CLEAR_ALPHA:
				if x < best.x:
					best = Vector2i(x, y)
				break
	if best.x >= CELL.x:
		return Vector2i(0, height)
	return Vector2i(best.x + 1, best.y)
