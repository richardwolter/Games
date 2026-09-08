## Lays every tile in the Forest pack out on one sheet, big enough to tell apart.
##
## The pack's tiles are 32x32 and its own atlas is a 320-pixel thumbnail, which is not
## something you can read an edge set off. This blows each tile up and puts them in slice
## order, ten to a row, so slice N is at row N/10, column N%10 counting from one at the top
## left. That mapping is the whole point: `ground.gd` names tiles by slice number, and the
## only way to decide which number is a rim and which is a middle is to look at them in that
## order.
##
##   godot --path . --headless res://tools/contact_tiles.tscn
extends Node

const TILES := "res://assets/Forest Isometric Pack Free/Tileset/Slice %d.png"
const OUT := "res://tools/contact_tiles.png"

## How many tiles across, how big each is drawn, and the gap between them in output pixels.
## TILES_FROM and TILES_TO narrow the sheet to a run of slices when a handful of them need
## looking at closely; TILES_ZOOM and TILES_COLS trade width for size. All optional.
const COLS := 10
const ZOOM := 5
const CELL := 32 * ZOOM
const GAP := 4

func _num(name: String, fallback: int) -> int:
	var raw := OS.get_environment(name)
	return int(raw) if raw.is_valid_int() else fallback


func _ready() -> void:
	var total := 0
	while ResourceLoader.exists(TILES % (total + 1)):
		total += 1
	var first := _num("TILES_FROM", 1)
	var last := mini(_num("TILES_TO", total), total)
	var cols := _num("TILES_COLS", COLS)
	var zoom := _num("TILES_ZOOM", ZOOM)
	var cell := 32 * zoom
	var count := maxi(last - first + 1, 0)
	var rows := int(ceil(float(count) / float(cols)))
	var sheet := Image.create(
		cols * (cell + GAP) + GAP, rows * (cell + GAP) + GAP, false, Image.FORMAT_RGBA8
	)
	# Magenta, so the empty part of a cell and a tile's own transparent corners are obvious.
	sheet.fill(Color(1.0, 0.0, 1.0, 1.0))
	for i in count:
		var tex := load(TILES % (first + i)) as Texture2D
		if tex == null:
			continue
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(cell, cell, Image.INTERPOLATE_NEAREST)
		var col := i % cols
		var row := i / cols
		sheet.blit_rect(
			img,
			Rect2i(0, 0, cell, cell),
			Vector2i(GAP + col * (cell + GAP), GAP + row * (cell + GAP))
		)
	sheet.save_png(OUT)
	print("wrote %s: slices %d..%d, %d cols, %d rows" % [OUT, first, last, cols, rows])
	get_tree().quit()
