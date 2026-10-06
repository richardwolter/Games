extends SceneTree
## Desktop build, not --headless: draws the free camera's button shut and open, at 1x and 4x,
## and saves tools/last_camera_mark.png.

var _frames := 0


func _initialize() -> void:
	var back := ColorRect.new()
	back.color = Color(0.2, 0.3, 0.3)
	back.size = Vector2(560, 330)
	root.add_child(back)
	for i in 2:
		for zoom in [1.0, 4.0]:
			var b := PlankButton.new()
			b.mark = &"camera"
			b.size = Vector2(56, 56)
			b.lit = i == 1
			b.scale = Vector2(zoom, zoom)
			b.position = Vector2(20 + i * 70, 20) if zoom == 1.0 else Vector2(20 + i * 260, 90)
			root.add_child(b)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		var img := root.get_texture().get_image()
		img.save_png("res://tools/last_camera_mark.png")
		return true
	return false
