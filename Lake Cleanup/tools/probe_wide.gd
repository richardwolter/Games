extends Node
var _main: Node2D
var _frames := 0
func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"autoload_save", false)
	add_child(_main)
func _process(_delta: float) -> void:
	_frames += 1
	var camera: Camera2D = null
	for child in _main.get_children():
		if child is Camera2D:
			camera = child
	if camera != null:
		var fit: float = _main.call(&"_fit_zoom")
		_main.set(&"_view_zoom", fit)
		camera.zoom = Vector2(fit, fit)
		# Drag hard into the corner, same as the wheel and the mouse would.
		var far: Vector2 = _main.call(&"_clamped_view", Vector2(999999.0, 999999.0))
		camera.global_position = far
	if _frames < 30:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tools/shot_wide.png")
	get_tree().quit()
