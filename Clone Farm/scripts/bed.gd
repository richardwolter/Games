## A garden bed, the thing every farm task acts on. It cycles empty -> planted -> growing
## -> ripe -> (harvest) -> empty. The task functions don't know who is working, so the
## farmer and the clones call the same ones.
class_name Bed
extends Workplace

enum State { EMPTY, PLANTED, GROWING, RIPE }

## Task names, one per farm function in docs/scope.md (Carregar comes with the stock trips).
const PLANT := &"plant"
const WATER := &"water"
const HARVEST := &"harvest"

## Seconds of work each task takes a worker at speed 1 (tools and traits scale the speed).
const WORK_TIME := {
	PLANT: 1.0,
	WATER: 1.0,
	HARVEST: 1.0,
}

const SIZE := 1.6
const GROW_TIME := 8.0
const YIELD := 1

const SOIL_DRY := Color(0.55, 0.40, 0.25)
const SOIL_WET := Color(0.32, 0.22, 0.14)
const PLANT_GREEN := Color(0.30, 0.65, 0.25)
const PLANT_RIPE := Color(0.95, 0.75, 0.20)

signal harvested(amount: int)

var state := State.EMPTY
var grow_left := 0.0

var _soil_mat: StandardMaterial3D
var _plant: MeshInstance3D
var _plant_mat: StandardMaterial3D


func _ready() -> void:
	super()
	add_to_group("beds")
	var soil := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SIZE, 0.2, SIZE)
	soil.mesh = box
	soil.position.y = 0.1
	_soil_mat = StandardMaterial3D.new()
	soil.material_override = _soil_mat
	add_child(soil)
	_plant = MeshInstance3D.new()
	_plant.mesh = SphereMesh.new()
	_plant_mat = StandardMaterial3D.new()
	_plant.material_override = _plant_mat
	add_child(_plant)
	_refresh()


func _process(delta: float) -> void:
	if state != State.GROWING:
		return
	grow_left -= delta
	if grow_left <= 0.0:
		state = State.RIPE
	_refresh()


func half_size() -> float:
	return SIZE / 2.0


func work_time(task: StringName) -> float:
	return WORK_TIME[task]


## The task this bed is waiting for, or &"" while it grows on its own.
func next_task() -> StringName:
	match state:
		State.EMPTY: return PLANT
		State.PLANTED: return WATER
		State.RIPE: return HARVEST
	return &""


## Finishes `task` (the worker has already spent its work time) if the bed is waiting for it. Returns what the task produced (only a
## harvest produces anything); a task the bed isn't waiting for does nothing.
func perform(task: StringName) -> int:
	if task != next_task():
		return 0
	match task:
		PLANT:
			state = State.PLANTED
		WATER:
			state = State.GROWING
			grow_left = GROW_TIME
		HARVEST:
			state = State.EMPTY
			harvested.emit(YIELD)
			_refresh()
			return YIELD
	_refresh()
	return 0


func _refresh() -> void:
	var wet := state == State.GROWING or state == State.RIPE
	_soil_mat.albedo_color = SOIL_WET if wet else SOIL_DRY
	_plant.visible = state != State.EMPTY
	var grown := 1.0
	if state == State.PLANTED:
		grown = 0.0
	elif state == State.GROWING:
		grown = 1.0 - grow_left / GROW_TIME
	var r := lerpf(0.12, 0.5, grown)
	_plant.scale = Vector3.ONE * r * 2.0
	_plant.position.y = 0.2 + r
	_plant_mat.albedo_color = PLANT_RIPE if state == State.RIPE else PLANT_GREEN
