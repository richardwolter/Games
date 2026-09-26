@tool
extends Node2D
## Procedural balcony: warm wood deck with receding planks plus a cozy railing along
## the far edge, drawn as flat shapes. The crew perches on the railing and the HUD
## furniture (panels, signs, dispatch button) sits on the deck below it.

const DESIGN_SIZE := Vector2(1152, 648)

const FLOOR_TOP := 578.0
const RAIL_TOP := 496.0
const RAIL_BOTTOM := 590.0

const POST_X: Array[float] = [
	32.0, 128.0, 224.0, 320.0, 416.0, 512.0,
	608.0, 704.0, 800.0, 896.0, 992.0, 1088.0,
]

var wood_base := Color(0.6, 0.4, 0.25)
var wood_dark := Color(0.47, 0.3, 0.18)
var wood_light := Color(0.74, 0.54, 0.33)
var post_col := Color(0.52, 0.35, 0.22)
var rail_col := Color(0.68, 0.48, 0.3)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var view := DESIGN_SIZE
	# deck planks (the floor we stand on)
	draw_rect(Rect2(0.0, FLOOR_TOP, view.x, view.y - FLOOR_TOP), wood_base, true)
	var plank_count := 5
	for i in range(1, plank_count + 1):
		var t := float(i) / float(plank_count)
		var y := FLOOR_TOP + (view.y - FLOOR_TOP) * t * t
		draw_rect(Rect2(0.0, y - 1.0, view.x, 2.0), wood_dark, true)
	# vertical plank seams converging toward a vanishing point above the deck
	var vanish := Vector2(view.x * 0.5, FLOOR_TOP - 90.0)
	var seams := 12
	for i in range(1, seams):
		var bx := view.x * float(i) / float(seams)
		var ty := lerpf(vanish.x, bx, 0.42)
		draw_line(Vector2(bx, view.y), Vector2(ty, FLOOR_TOP), wood_dark, 2.0)
	# soft shadow where the railing meets the deck
	draw_rect(Rect2(0.0, FLOOR_TOP, view.x, 8.0), Color(0.2, 0.12, 0.07, 0.2), true)
	# railing posts (planted into the deck)
	for px in POST_X:
		draw_rect(Rect2(px - 5.0, RAIL_TOP + 2.0, 10.0, RAIL_BOTTOM - RAIL_TOP), post_col, true)
		draw_rect(Rect2(px - 5.0, RAIL_TOP + 2.0, 10.0, 3.0), wood_light, true)
	# mid rail
	draw_rect(Rect2(-8.0, 548.0, view.x + 16.0, 10.0), rail_col, true)
	draw_rect(Rect2(-8.0, 548.0, view.x + 16.0, 3.0), wood_light, true)
	# top rail (the far edge of the balcony between us and the city)
	draw_rect(Rect2(-8.0, RAIL_TOP, view.x + 16.0, 18.0), rail_col, true)
	draw_rect(Rect2(-8.0, RAIL_TOP, view.x + 16.0, 6.0), wood_light, true)
	draw_rect(Rect2(-8.0, RAIL_TOP + 16.0, view.x + 16.0, 2.0), wood_dark, true)
