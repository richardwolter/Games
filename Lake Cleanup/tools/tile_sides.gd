## How the side of each grass tile is coloured, row by row below its top face.
##
## The lawn's exposed edge is going to show some of the tile's own side instead of stopping
## at a flat cut, and how much is worth showing depends on what is actually drawn there:
## how far down the side stays grass before it turns to earth, and whether the line between
## face and side is straight or ragged.
##
##   godot --path . --headless res://tools/tile_sides.tscn
extends Node

const TILES := "res://assets/Forest Isometric Pack Free/Tileset/Slice %d.png"
const LOOK := [37, 38, 43, 45]

func _ready() -> void:
	for n: int in LOOK:
		var img := (load(TILES % n) as Texture2D).get_image()
		img.convert(Image.FORMAT_RGBA8)
		var top := 0
		for y in img.get_height():
			var hit := false
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					hit = true
					break
			if hit:
				top = y
				break
		var face_end := top + 16
		var rows: Array[String] = []
		for y in range(face_end, mini(face_end + 14, img.get_height())):
			var green := 0
			var seen := 0
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				seen += 1
				if c.g > c.r:
					green += 1
			if seen == 0:
				rows.append("-")
			else:
				rows.append("g" if float(green) / float(seen) > 0.5 else "e")
		print("slice %3d  face_top %2d  side rows below face: %s" % [n, top, "".join(rows)])
	get_tree().quit()
