## Cuts a piece out of a screenshot and blows it up, so a seam a few pixels across can be
## looked at. CROP_RECT is "x,y,w,h" in the shot's own pixels; CROP_IN and CROP_OUT name the
## files. Nothing here is part of the game.
##
##   godot --path . --headless res://tools/crop_shot.tscn
extends Node

func _ready() -> void:
	var src := OS.get_environment("CROP_IN")
	var dst := OS.get_environment("CROP_OUT")
	var parts := OS.get_environment("CROP_RECT").split(",")
	var zoom := 4
	if OS.get_environment("CROP_ZOOM").is_valid_int():
		zoom = int(OS.get_environment("CROP_ZOOM"))
	var img := Image.load_from_file(ProjectSettings.globalize_path(src))
	var rect := Rect2i(
		int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3])
	)
	var cut := img.get_region(rect)
	cut.resize(rect.size.x * zoom, rect.size.y * zoom, Image.INTERPOLATE_NEAREST)
	cut.save_png(ProjectSettings.globalize_path(dst))
	print("wrote ", dst)
	get_tree().quit()
