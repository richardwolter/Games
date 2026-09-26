extends Node2D
## Renders the crow rig big, one wingbeat phase per frame, into a strip PNG
## (tools/_rig_strip.png) for checking the flap by eye. Run windowed:
##   <godot> --path . tools/rig_preview.tscn --log-file tools/_rig.log

const CrowScript = preload("res://scripts/crow.gd")
const FRAMES := 8
var _crow: Node2D
var _i := -3
var _shots: Array[Image] = []

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.93, 0.91, 0.86))
	_crow = CrowScript.new()
	_crow.position = Vector2(576, 400)
	_crow.scale = Vector2(10, 10)
	add_child(_crow)
	_crow.set_process(false)
	_crow.set("_flying", true)
	_crow.set("is_out", true)

func _physics_process(_d: float) -> void:
	if _i >= 0 and _i <= FRAMES:
		var img := get_viewport().get_texture().get_image()
		_shots.append(img.get_region(Rect2i(226, 20, 700, 620)))
	_i += 1
	if _i < FRAMES:
		_crow.set("_wing_phase", TAU * float(maxi(_i, 0)) / FRAMES)
		_crow.queue_redraw()
	elif _i == FRAMES:
		_crow.set("_flying", false)
		_crow.queue_redraw()
	elif _i > FRAMES + 1:
		var w := 350
		var strip := Image.create(w * _shots.size(), 310, false, Image.FORMAT_RGBA8)
		for k in _shots.size():
			var s := _shots[k]
			s.resize(w, 310)
			strip.blit_rect(s, Rect2i(0, 0, w, 310), Vector2i(k * w, 0))
		strip.save_png("res://tools/_rig_strip.png")
		get_tree().quit()
