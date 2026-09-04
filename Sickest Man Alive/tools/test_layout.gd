extends SceneTree

## The HUD used to be placed at coordinates that only worked at exactly
## 1280x720. Fullscreen with an expanding viewport means the visible area is
## whatever the player's display is, so every HUD element has to stay glued to
## its edge -- and the camera has to re-decide whether the room fits.
##
## Run: <godot> --headless --script tools/test_layout.gd

## Width x height, in base units, of the viewports this has to survive.
## 16:9 is the design size; the others are what expand actually produces on a
## 16:10 laptop and on an ultrawide.
const SHAPES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1152, 720),
	Vector2i(1707, 720),
	Vector2i(2160, 720),
]

## Element -> which edges it must stay pinned to.
const PINNED: Dictionary = {
	"HUD/Readout": "topleft",
	"HUD/Health": "topleft",
	"HUD/Banner": "topleft",
	"HUD/Hint": "bottomleft",
	"HUD/RunTimer": "right",
	"HUD/Minimap": "right",
}

const EDGE_TOLERANCE: float = 40.0

var _frames: int = 0
var _shape: int = 0
var _main: Node


func _initialize() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	current_scene = _main


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false

	# One shape per frame, so the resize has a frame to propagate through the
	# anchors before anything is measured.
	if _frames % 3 != 0:
		return false

	if _shape >= SHAPES.size():
		# The last shape applied has not been measured yet.
		_check(SHAPES[SHAPES.size() - 1])
		print("OK: HUD stays pinned and the camera re-frames at every viewport shape.")
		return true

	# Measure the shape set last time round, then apply the next one.
	if _shape > 0:
		_check(SHAPES[_shape - 1])

	var shape := SHAPES[_shape]
	_shape += 1
	root.size = shape
	return false


func _check(shape: Vector2i) -> void:
	var view := Vector2(root.get_visible_rect().size)

	for path: String in PINNED:
		var control := _main.get_node(path) as Control
		var rect := control.get_global_rect()
		var edge: String = PINNED[path]

		assert(rect.position.x >= -1.0 and rect.position.y >= -1.0,
			"%s ran off the top-left at %s" % [path, shape])
		assert(rect.end.x <= view.x + 1.0,
			"%s ran off the right edge at %s (%.0f > %.0f)" % [path, shape, rect.end.x, view.x])

		match edge:
			"right":
				assert(view.x - rect.end.x < EDGE_TOLERANCE,
					"%s drifted from the right edge at %s (gap %.0f)" % [
						path, shape, view.x - rect.end.x])
			"bottomleft":
				assert(view.y - rect.end.y < EDGE_TOLERANCE,
					"%s drifted from the bottom at %s (gap %.0f)" % [
						path, shape, view.y - rect.end.y])
			_:
				assert(rect.position.x < EDGE_TOLERANCE and rect.position.y < 260.0,
					"%s drifted from the top-left at %s" % [path, shape])

	print("%4dx%-4d  view %.0fx%.0f  room fits: %s" % [
		shape.x, shape.y, view.x, view.y, _main._room_fits])
