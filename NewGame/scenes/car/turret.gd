class_name Turret
extends Node2D

@export var bullet_scene: PackedScene = preload("res://scenes/car/bullet.tscn")
@export var bullet_visual_scene: PackedScene = preload("res://scenes/car/bullet_visual.tscn")
@export var target_range: float = 260.0
@export var fire_interval: float = 0.6

@onready var muzzle: Marker2D = $Muzzle

var _cooldown: float = 0.0

func _physics_process(delta: float) -> void:
	if TrackState.course_complete:
		return

	_cooldown -= delta

	var target := _find_nearest_zombie()
	if target == null:
		return

	look_at(target.global_position)

	if _cooldown <= 0.0:
		_fire(target.global_position)
		_cooldown = fire_interval

func _find_nearest_zombie() -> Node2D:
	var zombies := get_tree().get_nodes_in_group("zombies")
	var nearest: Node2D = null
	var nearest_dist := target_range

	for z in zombies:
		if not is_instance_valid(z):
			continue
		var d := global_position.distance_to(z.global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = z

	return nearest

func _fire(target_pos: Vector2) -> void:
	var bullet: Node2D = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.direction = (target_pos - muzzle.global_position).normalized()

	var visual: Node2D = bullet_visual_scene.instantiate()
	var actors := get_tree().get_first_node_in_group("iso_actors")
	if actors:
		actors.add_child(visual)
	else:
		get_tree().current_scene.add_child(visual)
	visual.source = bullet
