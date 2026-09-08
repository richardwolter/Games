extends SceneTree

## A contact sheet of the furniture pieces in catalogue order, so they can be named.
## Ten to a row, index order left to right, top to bottom.
func _init() -> void:
	var book: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/pieces.json")
	)
	var src := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/TopDownHouse_FurnitureState2.png")
	)
	src.convert(Image.FORMAT_RGBA8)
	var cols := 10
	var cell := 96
	var rows := 5
	var out := Image.create_empty(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.9, 0.9, 0.92))
	var i := 0
	for entry: Dictionary in book["pieces"]:
		if String(entry["sheet"]) != "furniture":
			continue
		var r: Array = entry["region"]
		var part := src.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		var zoom := mini(int(float(cell - 12) / float(r[2])), int(float(cell - 12) / float(r[3])))
		zoom = maxi(zoom, 1)
		part.resize(int(r[2]) * zoom, int(r[3]) * zoom, Image.INTERPOLATE_NEAREST)
		var x := (i % cols) * cell + (cell - part.get_width()) / 2
		var y := (i / cols) * cell + (cell - part.get_height()) / 2
		out.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i(x, y))
		i += 1
	out.save_png(ProjectSettings.globalize_path("res://tools/contact_furniture.png"))
	print("pieces ", i)
	quit(0)
