## The shore: a merchant yard, the bank behind it, and the water in front.
##
##   godot --path . res://tools/shot_shore.tscn
extends Node

const SETTLE_FRAMES := 30
const OUT_PATH := "res://tools/shot_shore.png"

var _main: Node2D
var _frames: int = 0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"autoload_save", false)
	add_child(_main)


func _process(_delta: float) -> void:
	_frames += 1
	# Every frame, not once: the lake writes the camera itself from the angler's position
	# and its own zoom, so anything set from outside is gone by the next frame.
	var yard := _main.get_node_or_null(^"DropoffTimber") as Dropoff
	var camera := _main.get_node(^"Camera") as Camera2D
	_main.set(&"_view_zoom", 0.85)
	camera.zoom = Vector2(0.85, 0.85)
	if yard != null:
		camera.position = Iso.tile_to_world(yard.berth.x - 1.0, yard.berth.y)
	if _frames < SETTLE_FRAMES:
		return
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(OUT_PATH))
	get_tree().quit(0)
