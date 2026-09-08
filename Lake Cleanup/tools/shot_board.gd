## Opens the shed with a few finds in it and saves what it looks like.
##
## The shed is the one screen the headless harness cannot judge and the lake's own shot tool
## never reaches: it is behind a button, and its layout is worked out from the panel it is
## given rather than written down anywhere. Laying out a room by reasoning about numbers is
## how the list ended up over the floor in the first place.
##
##   godot --path . res://tools/shot_board.tscn
extends Node

const SETTLE_FRAMES := 30
const OUT_PATH := "res://tools/shot_board.png"

## How many finds to put in the store, so the inventory column is drawn with rows in it
## rather than with its one empty line.
const KEPT := 6

var _main: Node2D
var _frames: int = 0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"autoload_save", false)
	add_child(_main)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 2:
		_stock_the_shed()
		_main.call(&"_set_menu", true)
	if _frames < SETTLE_FRAMES:
		return
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(OUT_PATH))
	get_tree().quit(0)


## Every keepsake the lake knows about, put in the store as found-but-not-placed, which is
## the state the inventory column exists to show.
func _stock_the_shed() -> void:
	var grid := _main.get_node(^"Grid") as LakeGrid
	var kept: Array[String] = []
	for def: TrashDef in grid.defs:
		if def.keepsake and kept.size() < KEPT:
			kept.append(String(def.piece))
	_main.set(&"unlocked", kept)
