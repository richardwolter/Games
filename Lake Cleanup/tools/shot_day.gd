## The daylight, at four times of day, from the same camera.
##
## The cycle takes ten minutes to come round, which is the right length to play under and a
## useless one to look at while working on it. This puts the day where it is told, settles
## the frame and saves it, four times over: first light, noon, evening, and the dim trough
## the sun swings back through.
##
## Needs a real window — `get_viewport().get_texture()` never comes good under --headless.
##
##   godot --path . res://tools/shot_day.tscn
extends Node

const SETTLE_FRAMES := 24

## What to shoot, as a name and the point in the loop it sits at. Mirrors the gradient in
## resources/day.tres: dawn at the start, noon halfway through the daylight half, evening
## late in it, and the trough past DayConfig.trough_at.
const TIMES := [
	["dawn", 0.02], ["noon", 0.45], ["evening", 0.8], ["trough", 0.95],
]

var _main: Node2D
var _day: DayCycle
var _shot: int = 0
var _frames: int = 0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"autoload_save", false)
	add_child(_main)
	_day = _main.get_node(^"Day") as DayCycle


func _process(_delta: float) -> void:
	_frames += 1
	# Held every frame: the cycle is running on its own clock and would walk off whatever
	# was set once, and the lake rewrites the camera from the angler every frame besides.
	var camera := _main.get_node(^"Camera") as Camera2D
	_main.set(&"_view_zoom", 0.9)
	camera.zoom = Vector2(0.9, 0.9)
	if _day != null:
		_day.set_process(false)
		_day.set_phase(float((TIMES[_shot] as Array)[1]))
	if _frames < SETTLE_FRAMES:
		return
	var name: String = (TIMES[_shot] as Array)[0]
	var out := "res://tools/shot_day_%s.png" % name
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out))
	print("saved %s at phase %.2f" % [out, _day.phase if _day != null else -1.0])
	_shot += 1
	_frames = 0
	if _shot >= TIMES.size():
		get_tree().quit(0)
