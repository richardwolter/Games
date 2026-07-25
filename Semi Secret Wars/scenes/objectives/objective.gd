class_name CaptureObjective
extends Node2D
## A capturable field objective (hold-to-capture, contested).
##
## A hero within `capture_radius` fills `progress` over `capture_time` seconds; a
## hostile within `contest_radius` pauses it (progress holds, it doesn't reset).
## On completion it grants a one-time farm/XP bonus — a placeholder for real
## experience once the Progression milestone exists — and stays captured. Shown
## as a diamond with a progress ring and a % label.

signal captured(bonus: int)

@export var label := "OBJECTIVE"
## Index into LaneField.objective_positions — which point this instance takes.
@export var objective_index := 0
@export var capture_radius := 80.0
@export var contest_radius := 45.0
@export var capture_time := 5.0
## One-time farm/XP bonus granted on capture (placeholder until Progression).
@export var farm_bonus := 20
@export var size := 22.0
@export var color := Color("d4a017")
@export var captured_color := Color("5aa85a")
@export var ring_color := Color("3a8a3a")
@export var outline_color := Color("2c2c2c")

var progress := 0.0
var is_captured := false
## True while a hostile inside contest_radius is holding progress (HUD display).
var contested := false

func _ready() -> void:
	# Positioned by the battlefield scene at the field's rolled objective point.
	var field: LaneField = get_tree().get_first_node_in_group("field")
	if field != null:
		if objective_index < field.objective_positions.size():
			global_position = field.objective_positions[objective_index]
		else:
			global_position = field.objective_pos
	add_to_group("objectives")

func _process(delta: float) -> void:
	if is_captured:
		return
	var hero_present := _any_in_group("heroes", capture_radius)
	contested = hero_present and _any_in_group("hostiles", contest_radius)
	if hero_present and not contested:
		progress = minf(progress + delta / capture_time, 1.0)
		if progress >= 1.0:
			is_captured = true
			captured.emit(farm_bonus)
	queue_redraw()

func _any_in_group(group: String, radius: float) -> bool:
	for n in get_tree().get_nodes_in_group(group):
		if is_instance_valid(n) and global_position.distance_to(n.global_position) <= radius:
			return true
	return false

func _draw() -> void:
	var col := captured_color if is_captured else color
	var d := PackedVector2Array([
		Vector2(0.0, -size), Vector2(size, 0.0), Vector2(0.0, size), Vector2(-size, 0.0)])
	draw_colored_polygon(d, col)
	var o := d.duplicate()
	o.append(d[0])
	draw_polyline(o, outline_color, 3.0, true)
	if not is_captured and progress > 0.0:
		draw_arc(Vector2.ZERO, size + 8.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 40, ring_color, 4.0, true)
	# No floating "<name> 40%" text any more (Designer, 2026-07-25 — names and
	# texts off lane props). Nothing is lost: the progress ring above already
	# shows the fraction, `captured_color` shows the captured state, and
	# BattleHUD's objective panel carries the written readout. `label` stays as
	# data for that panel.
