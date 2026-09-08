## Average top-face colour of each grass slice, to sort border tiles into the light/dark pools.
##   godot --path . --headless res://tools/tile_color_check.tscn
extends Node
const TILES := "res://assets/Forest Isometric Pack Free/Tileset/Slice %d.png"
const LOOK := [1, 2, 19, 18, 20, 21, 37, 38, 43, 45]
func _ready() -> void:
	for n: int in LOOK:
		var img := (load(TILES % n) as Texture2D).get_image()
		img.convert(Image.FORMAT_RGBA8)
		var r := 0.0
		var g := 0.0
		var b := 0.0
		var c := 0
		for y in img.get_height():
			for x in img.get_width():
				var p := img.get_pixel(x, y)
				if p.a > 0.5:
					r += p.r
					g += p.g
					b += p.b
					c += 1
		print("slice %3d  avg rgb  %.2f %.2f %.2f" % [n, r / c, g / c, b / c])
	get_tree().quit()
