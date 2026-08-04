## Saves a region of an image at full resolution, for looking at closely.
##
##   godot --headless --script tools/crop.gd -- --in=art/title_screen.jpg \
##       --rect=1600,900,320,180 --out=tools/_crop.png
extends SceneTree


func _initialize() -> void:
	var args := {}
	for arg: String in OS.get_cmdline_user_args():
		var bits := arg.trim_prefix("--").split("=", true, 1)
		args[bits[0]] = bits[1] if bits.size() > 1 else ""

	var src := Image.load_from_file(ProjectSettings.globalize_path(
		"res://" + str(args.get("in", ""))
	))
	print("source %dx%d" % [src.get_width(), src.get_height()])

	var nums := str(args.get("rect", "")).split(",")
	if nums.size() == 4:
		var rect := Rect2i(int(nums[0]), int(nums[1]), int(nums[2]), int(nums[3]))
		var out := src.get_region(rect)
		var scale := int(args.get("scale", "1"))
		if scale > 1:
			out.resize(rect.size.x * scale, rect.size.y * scale, Image.INTERPOLATE_NEAREST)
		out.save_png(ProjectSettings.globalize_path("res://" + str(args.get("out", "tools/_crop.png"))))
	quit()
