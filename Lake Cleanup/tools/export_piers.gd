@tool
extends EditorScript

## Extract individual pier sprites from piers.png and save as separate files.
## Run this from Editor: right-click > Run

func _run() -> void:
	var json_text := FileAccess.get_file_as_string("res://assets/piers.json")
	var data: Variant = JSON.parse_string(json_text)

	if not (data is Dictionary):
		print("ERROR: Failed to parse piers.json")
		return

	var sheet_path: String = data["sheet"]
	var sheet: Texture2D = load(sheet_path)

	if sheet == null:
		print("ERROR: Could not load sheet: ", sheet_path)
		return

	var pieces: Dictionary = data["pieces"]
	var image := sheet.get_image()

	# Extract each pier
	for name: String in pieces:
		var rect_data: Variant = pieces[name]
		if not (rect_data is Array) or rect_data.size() < 4:
			continue

		var rect := Rect2i(rect_data[0], rect_data[1], rect_data[2], rect_data[3])
		var cropped := image.get_region(rect)

		var out_path := "res://assets/pier_%s.png" % name
		var error := cropped.save_png(out_path)

		if error == OK:
			print("✓ Exported: ", out_path)
		else:
			print("✗ Failed to export: ", out_path)

	print("\nDone. Check res://assets/ for pier_*.png files.")
