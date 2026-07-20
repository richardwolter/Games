class_name LaneForeground
extends Node2D
## Draws ALL of LaneField's border decor — the tree band framing every side of
## the lane, its scatter (mushrooms/plants), and any hand-placed border_decor
## extras — on its own canvas item, above BOTH units and FogOfWar. Godot's
## immediate-mode draw_* calls only affect whichever CanvasItem is currently
## inside its own _draw() — LaneField can't draw onto this node's canvas from
## its own _draw(), so this node fetches the entries via LaneField's get_*
## accessors and draws them itself.
##
## Two reasons this sits above the fog (z_index set below FogOfWar's 20 in
## _ready — see there):
## 1. The near (bottom) band was always meant to read in front of units for
##    depth (There Are No Orcs reference) — that only works if it's not then
##    covered by the fog layer drawn after it.
## 2. Designer, 2026-07-19: border scenery is pure environmental framing, not
##    a gameplay discovery — it should stay visible even in territory a hero
##    hasn't explored yet. Everything else (obstacles, spawn points, in-lane
##    scenery — still drawn by LaneField itself, below the fog) stays hidden
##    under unexplored fog until a hero has actually been there.

## Near-row (bottom) trees get a touch of alpha so a unit hugging the lane's
## bottom edge is never fully hidden behind a trunk/canopy. Every other decor
## layer here draws at full opacity — it doesn't overlap units the same way.
@export var near_row_alpha := 0.92

var _field: LaneField

func _ready() -> void:
	_field = get_tree().get_first_node_in_group("field") as LaneField
	# Must exceed FogOfWar's z_index (20, set in fog_of_war.gd) — see header.
	z_index = 21
	queue_redraw()

func _draw() -> void:
	if _field == null:
		return
	for e in _field.get_top_band():
		_draw_prop_sprite(e["pos"], e["height"], e["tex"], e["flip"], e["tint"], 1.0)
	for e in _field.get_left_band():
		_draw_prop_sprite(e["pos"], e["height"], e["tex"], e["flip"], e["tint"], 1.0)
	for e in _field.get_right_band():
		_draw_prop_sprite(e["pos"], e["height"], e["tex"], e["flip"], e["tint"], 1.0)
	for e in _field.get_scatter():
		_draw_prop_sprite(e["pos"], e["height"], e["tex"], e["flip"], e["tint"], 1.0)
	for e in _field.get_border_decor_entries():
		_draw_center_sprite(e["pos"], e["radius"], e["tex"])
	# Bottom band drawn last — nearest/tallest, and the one layer that
	# actually needs to occlude units in front of it.
	for e in _field.get_bottom_band():
		_draw_prop_sprite(e["pos"], e["height"], e["tex"], e["flip"], e["tint"], near_row_alpha)

## Duplicated (not shared) from StageField._draw_prop_sprite: this node isn't
## a StageField, and draw_* calls can't cross canvas items — see file header.
func _draw_prop_sprite(base: Vector2, height: float, tex: Texture2D, flip_h: bool, tint: Color, alpha: float) -> void:
	var tex_size := tex.get_size()
	if tex_size.y <= 0.0:
		return
	var draw_size := Vector2(tex_size.x * (height / tex_size.y), height)
	var rect := Rect2(base - Vector2(draw_size.x * 0.5, draw_size.y), draw_size)
	if flip_h:
		rect = Rect2(rect.position + Vector2(draw_size.x, 0.0), Vector2(-draw_size.x, draw_size.y))
	draw_texture_rect(tex, rect, false, Color(tint.r, tint.g, tint.b, tint.a * alpha))

## Duplicated (not shared) from StageField._draw_obstacle_sprite, for
## border_decor's hand-placed extras (center + radius, not base-anchored).
func _draw_center_sprite(center: Vector2, radius: float, tex: Texture2D) -> void:
	var diameter := radius * 2.0
	var tex_size := tex.get_size()
	var scale_factor := diameter / maxf(tex_size.x, tex_size.y)
	var draw_size := tex_size * scale_factor
	draw_texture_rect(tex, Rect2(center - draw_size * 0.5, draw_size), false)
