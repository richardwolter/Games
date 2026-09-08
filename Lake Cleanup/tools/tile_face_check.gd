## Where each tall-grass tile's face actually sits: the widest opaque row, not the first one.
##
##   godot --path . --headless res://tools/tile_face_check.tscn
extends Node
const TILES := "res://assets/Forest Isometric Pack Free/Tileset/Slice %d.png"
const LOOK := [37, 38, 43, 45, 1, 2]
func _ready() -> void:
	for n: int in LOOK:
		var img := (load(TILES % n) as Texture2D).get_image()
		img.convert(Image.FORMAT_RGBA8)
		var first := -1
		var widest_y := -1
		var widest_w := -1
		for y in img.get_height():
			var minx := img.get_width()
			var maxx := -1
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					minx = mini(minx, x)
					maxx = maxi(maxx, x)
			if maxx >= 0:
				if first < 0:
					first = y
				var w := maxx - minx + 1
				if w > widest_w:
					widest_w = w
					widest_y = y
		print("slice %3d  first_opaque_row %2d  widest_row %2d (w=%2d)" % [n, first, widest_y, widest_w])
	get_tree().quit()
