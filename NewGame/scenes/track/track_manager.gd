class_name TrackManager
extends Node2D

@export var car_scene: PackedScene = preload("res://scenes/car/car.tscn")
@export var car_start_position: Vector2 = Vector2.ZERO
@export var track_id: String = "track_1"
@export var course_id: String = "course_1"
@export var spark_reward: int = 50
@export var target_time: float = 12.0   ## finish at/under this = 3 stars
@export var time_limit: float = 25.0    ## countdown deadline; finish after this = fail

const CAR_VISUAL_SCENE := preload("res://scenes/car/car_visual.tscn")
const ZOMBIE_VISUAL_SCENE := preload("res://scenes/enemies/zombie_visual.tscn")
const CHARGING_VISUAL_SCENE := preload("res://scenes/charging/charging_station_visual.tscn")
const CHECKPOINT_VISUAL_SCENE := preload("res://scenes/track/checkpoint_visual.tscn")
const GOAL_VISUAL_SCENE := preload("res://scenes/track/goal_visual.tscn")

var car: Car = null
var _finished: bool = false

@onready var checkpoints: Array[Node] = get_tree().get_nodes_in_group("checkpoints")
@onready var goal_zone: GoalZone = $GoalZone if has_node("GoalZone") else null
@onready var actors_layer: Node2D = $IsoWorld/Actors if has_node("IsoWorld/Actors") else null
@onready var track_camera: Node = $TrackCamera if has_node("TrackCamera") else null

func _ready() -> void:
	_spawn_car()
	TrackState.reset_course(car_get_id(), track_id, "%s/%s" % [track_id, course_id], checkpoints.size(), target_time, time_limit)

	if goal_zone:
		goal_zone.car_reached_goal.connect(_on_goal_reached)

	_spawn_visuals()

func car_get_id() -> String:
	return "default"

func _spawn_car() -> void:
	car = car_scene.instantiate()
	add_child(car)
	car.global_position = car_start_position

	var upgrades: Dictionary = GameState.get_car_config(car_get_id())
	car.apply_upgrades(
		upgrades.get("battery_tier", 1),
		upgrades.get("motor_tier", 1),
		upgrades.get("chassis_tier", 1),
		upgrades.get("charger_tier", 1)
	)
	car.start()

	if track_camera:
		track_camera.target = car
		track_camera.make_current()

func _spawn_visuals() -> void:
	if actors_layer == null:
		return

	var car_visual: Node2D = CAR_VISUAL_SCENE.instantiate()
	actors_layer.add_child(car_visual)
	car_visual.source = car
	var barrel_visual := car_visual.get_node("BarrelVisual")
	barrel_visual.turret_source = car.get_node("Turret")
	barrel_visual.car_source = car

	for z in get_tree().get_nodes_in_group("zombies"):
		_spawn_synced_visual(z, ZOMBIE_VISUAL_SCENE)

	for cs in get_tree().get_nodes_in_group("charging_stations"):
		_spawn_synced_visual(cs, CHARGING_VISUAL_SCENE)

	for cp in checkpoints:
		_spawn_synced_visual(cp, CHECKPOINT_VISUAL_SCENE)

	if goal_zone:
		_spawn_synced_visual(goal_zone, GOAL_VISUAL_SCENE)

func _spawn_synced_visual(source: Node2D, visual_scene: PackedScene) -> Node2D:
	var visual: Node2D = visual_scene.instantiate()
	actors_layer.add_child(visual)
	visual.source = source
	return visual

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().reload_current_scene()
		return

	if _finished:
		return
	TrackState.update_time(delta)

	if TrackState.time_elapsed >= time_limit:
		_finished = true
		car.stop()
		TrackState.complete_course(false, 0, 0)

func _on_goal_reached() -> void:
	if _finished:
		return
	_finished = true
	car.stop()

	var stars := TrackState.compute_stars()
	var full_course_id := "%s/%s" % [track_id, course_id]
	var spark_awarded := GameState.award_spark_for_course(full_course_id, TrackState.time_elapsed, spark_reward, stars)
	TrackState.complete_course(true, stars, spark_awarded)
