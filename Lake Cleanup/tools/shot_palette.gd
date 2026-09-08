## Renders the lake at several pollution levels to check the palette-driven water
## colour end to end: resources/palette.tres -> lake.gd -> water.gdshader.
##
## Hides the Grid (floating trash) and pins filth_mapped to 0 so the shader
## reads the forced `pollution` scalar everywhere instead of the real
## per-tile filth map — that map reflects actual trash left on the grid,
## which forcing the scalar alone does not touch, and would otherwise keep
## the scum overlay (and so most of the visible colour) dirty regardless of
## what this script asks for.
##
##   godot --path . res://tools/shot_palette.tscn
extends Node

const OUT_DIR := "res://tools/"
const LEVELS := [1.0, 0.75, 0.5, 0.34, 0.1, 0.0]
const SETTLE_FRAMES := 20

var _main: Node2D
var _frames: int = 0
var _level_i: int = 0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"autoload_save", false)
	add_child(_main)
	var grid := _main.get_node_or_null("Grid")
	if grid != null:
		grid.visible = false


func _process(_dt: float) -> void:
	if _main == null:
		return

	_frames += 1
	if _frames == 2:
		_main.set(&"pollution", LEVELS[_level_i])
		_main.call(&"_push_water_colours")
		var mat: ShaderMaterial = _main.get(&"_water_material")
		if mat != null:
			mat.set_shader_parameter(&"filth_mapped", 0.0)
	if _frames == SETTLE_FRAMES:
		var img := get_viewport().get_texture().get_image()
		var path := OUT_DIR + "shot_water_%d.png" % int(LEVELS[_level_i] * 100)
		img.save_png(path)
		print("Saved ", path, " at pollution=", _main.get(&"pollution"))
		_level_i += 1
		_frames = 0
		if _level_i >= LEVELS.size():
			get_tree().quit()
