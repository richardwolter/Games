## Checks that zooming keeps the world point under the cursor pinned to the same
## place on screen.
##
##   godot --headless --quit-after 2000 --script tools/zoom_probe.gd
extends SceneTree


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 60:
		await process_frame

	var cam: Camera2D = root.get_child(root.get_child_count() - 1).get_node("World/Camera")
	var anchor := Vector2(900.0, 120.0)

	for factor: float in [1.12, 1.0 / 1.12, 1.12 * 1.12 * 1.12]:
		var before_screen := _to_screen(cam, anchor)
		var before_zoom := cam.zoom.x
		cam._apply_zoom(factor, anchor)
		var after_screen := _to_screen(cam, anchor)
		print("factor=%.3f zoom %.4f -> %.4f  anchor_screen %s -> %s  drift=%.2f" % [
			factor, before_zoom, cam.zoom.x, before_screen, after_screen,
			before_screen.distance_to(after_screen)
		])
	quit()


## Where a world point lands on screen, given the camera's centre and zoom.
func _to_screen(cam: Camera2D, world: Vector2) -> Vector2:
	return (world - cam.position) * cam.zoom.x + cam.get_viewport_rect().size * 0.5
