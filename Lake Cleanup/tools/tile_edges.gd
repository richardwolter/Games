## Reads the pack's tiles and works out, for each one, which of its four sides are sand.
##
## `ground.gd` has to pick a tile by what its neighbours are, and that needs a table saying
## which slice carries its sand along which edge. Eyeballing a 32-pixel tile to decide whether
## the worn patch is on its north-east or its north-west side is guesswork; the pixels know.
##
## The top face is a diamond 32 across and 16 tall starting at the picture's first opaque row.
## Its four sides face the four tile neighbours: north-west is (-1, 0), north-east is (0, -1),
## south-east is (+1, 0), south-west is (0, +1) — the same mapping `Iso.tile_to_world` implies.
## Each side is sampled just inside its middle and the pixels there are called sand or grass by
## whether they are more red than green.
##
##   godot --path . --headless res://tools/tile_edges.tscn
extends Node

const TILES := "res://assets/Forest Isometric Pack Free/Tileset/Slice %d.png"
const OUT := "res://tools/tile_edges.log"

## How far in from a side's middle to sample, as a fraction of the way to the face's middle,
## and how big a blob to take. Far enough in to miss the outline the pack draws round the
## face, small enough that a tile whose sand only reaches part way along a side still reads as
## sand on that side rather than as an average of the two.
const INSET := 0.30
const BLOB := 3

## The four sides, as the tile step each faces.
const SIDES := {
	"NW": Vector2i(-1, 0),
	"NE": Vector2i(0, -1),
	"SE": Vector2i(1, 0),
	"SW": Vector2i(0, 1),
}


func _ready() -> void:
	var lines: Array[String] = []
	lines.append("slice  face_top  NW NE SE SW  sand%  note")
	var n := 1
	while ResourceLoader.exists(TILES % n):
		var tex := load(TILES % n) as Texture2D
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		var top := _top_of(img)
		var mid := Vector2(img.get_width() * 0.5, float(top) + img.get_width() * 0.25)
		var marks: Array[String] = []
		for key: String in ["NW", "NE", "SE", "SW"]:
			marks.append(_side_mark(img, mid, key))
		lines.append(
			"%5d  %8d  %2s %2s %2s %2s  %4.0f  %s"
			% [n, top, marks[0], marks[1], marks[2], marks[3], _face_sand(img, mid) * 100.0,
				_note(img, mid)]
		)
		n += 1
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	for line in lines:
		f.store_line(line)
		print(line)
	f.close()
	get_tree().quit()


## The first row of the picture with anything in it. Same measure `Ground._top_of` takes, so
## the diamond this tool reasons about is the one the game draws.
func _top_of(img: Image) -> int:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				return y
	return 0


## Where on the face a side's sample sits: out from the middle towards that side, stopping
## short of the edge by INSET. The face is twice as wide as it is tall, so the step out is
## halved vertically.
func _side_at(mid: Vector2, side: String) -> Vector2:
	var step: Vector2i = SIDES[side]
	# Screen direction of a tile step: +x goes down-right, +y goes down-left.
	var dir := Vector2(float(step.x - step.y), float(step.x + step.y) * 0.5)
	return mid + dir * (1.0 - INSET) * 8.0


func _side_mark(img: Image, mid: Vector2, side: String) -> String:
	var at := _side_at(mid, side)
	var sand := _sand_share(img, at)
	if sand > 0.6:
		return "S"
	if sand < 0.2:
		return "g"
	return "?"


## How much of a blob at a spot is sand rather than grass. Sand in this pack is warm — more
## red than green — and every grass in it is the other way round, so the two never meet in
## the middle and no threshold has to be tuned.
func _sand_share(img: Image, at: Vector2) -> float:
	var sand := 0
	var seen := 0
	for dy in range(-BLOB, BLOB + 1):
		for dx in range(-BLOB, BLOB + 1):
			var x := int(at.x) + dx
			var y := int(at.y) + dy
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			seen += 1
			if c.r > c.g:
				sand += 1
	return float(sand) / float(seen) if seen > 0 else 0.0


## How much of the whole top face is sand, which separates a tile with a bite out of it from
## one that is sand all over.
func _face_sand(img: Image, mid: Vector2) -> float:
	var sand := 0
	var seen := 0
	for dy in range(-7, 8):
		for dx in range(-15, 16):
			# Inside the diamond: |dx|/2 + |dy| under its half-height.
			if absf(float(dx)) * 0.5 + absf(float(dy)) > 7.0:
				continue
			var x := int(mid.x) + dx
			var y := int(mid.y) + dy
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			seen += 1
			if c.r > c.g:
				sand += 1
	return float(sand) / float(seen) if seen > 0 else 0.0


## Whether the picture is a cube or a slab, which is the other thing the table needs: a slab
## laid next to a cube is a step, and the beach is slabs where the lawn is cubes.
func _note(img: Image, mid: Vector2) -> String:
	var bottom := 0
	for y in range(img.get_height() - 1, -1, -1):
		var hit := false
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				hit = true
				break
		if hit:
			bottom = y
			break
	var depth := float(bottom) - (mid.y + 8.0)
	return "slab" if depth < 4.0 else "cube(%d)" % int(depth)
