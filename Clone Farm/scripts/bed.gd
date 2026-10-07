## A garden bed. It cycles empty -> planted -> growing -> ripe -> (harvest) -> empty, and a
## harvest drops crates beside it for someone to carry. A Forte clone walking over a plant
## tramples it; only the farmer fixes a trampled bed (back to empty). The task functions
## don't know who is working, so the farmer and the clones call the same ones.
class_name Bed
extends Workplace

enum State { EMPTY, PLANTED, GROWING, RIPE, TRAMPLED }

## Task names, one per farm function in docs/scope.md (Carregar acts on crates).
const PLANT := &"plant"
const WATER := &"water"
const HARVEST := &"harvest"
const FIX := &"fix"

## Seconds of work each task takes a worker at speed 1 (tools and traits scale the speed).
const WORK_TIME := {
	PLANT: 1.0,
	WATER: 1.0,
	HARVEST: 1.0,
	FIX: 2.0,
}

const SIZE := 1.6
const GROW_TIME := 8.0
const YIELD := 1

const SOIL_DRY := Color(0.55, 0.40, 0.25)
const SOIL_WET := Color(0.32, 0.22, 0.14)
const PLANT_GREEN := Color(0.30, 0.65, 0.25)
const PLANT_RIPE := Color(0.95, 0.75, 0.20)
const PLANT_TRAMPLED := Color(0.45, 0.38, 0.25)

## `amount` crates to drop beside the bed.
signal harvested(amount: int)

var state := State.EMPTY
var grow_left := 0.0
## How fast the plant grows (a Dedo Verde clone that planted or watered it raises it).
var grow_rate := 1.0

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
	grow_left -= delta * grow_rate
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
		State.TRAMPLED: return FIX
	return &""


## Only the farmer fixes a trampled bed; clones leave it alone.
func next_task_for(worker: Worker) -> StringName:
	var task := next_task()
	if task == FIX and not worker is Farmer:
		return &""
	return task


## True while there is a plant to trample.
func has_plant() -> bool:
	return state == State.PLANTED or state == State.GROWING or state == State.RIPE


## A Forte clone walked over it: the plant is lost until the farmer fixes the bed.
func trample() -> bool:
	if not has_plant():
		return false
	state = State.TRAMPLED
	grow_rate = 1.0
	_refresh()
	return true


## True when `point` (on the ground) is over the soil.
func covers(point: Vector3) -> bool:
	return absf(point.x - global_position.x) < SIZE / 2.0 \
			and absf(point.z - global_position.z) < SIZE / 2.0


## Finishes `task` (the worker `by` has already spent its work time) if the bed is waiting
## for it. Returns what the task produced (crates; only a harvest produces any); a task the
## bed isn't waiting for does nothing. The worker's traits can boost growth and the harvest.
func perform(task: StringName, by: Worker = null) -> int:
	if task != next_task():
		return 0
	var boost := by.grow_boost() if by != null else 1.0
	match task:
		PLANT:
			state = State.PLANTED
			grow_rate = boost
		WATER:
			state = State.GROWING
			grow_left = GROW_TIME
			grow_rate = maxf(grow_rate, boost)
		HARVEST:
			var amount := YIELD + (by.harvest_bonus() if by != null else 0)
			if by != null:
				amount = by.keep_of(amount)
			state = State.EMPTY
			grow_rate = 1.0
			harvested.emit(amount)
			_refresh()
			return amount
		FIX:
			state = State.EMPTY
	_refresh()
	return 0


func _refresh() -> void:
	var wet := state == State.GROWING or state == State.RIPE
	_soil_mat.albedo_color = SOIL_WET if wet else SOIL_DRY
	_plant.visible = state != State.EMPTY
	if state == State.TRAMPLED:
		_plant.scale = Vector3(1.1, 0.15, 1.1)
		_plant.position.y = 0.25
		_plant_mat.albedo_color = PLANT_TRAMPLED
		return
	var grown := 1.0
	if state == State.PLANTED:
		grown = 0.0
	elif state == State.GROWING:
		grown = 1.0 - grow_left / GROW_TIME
	var r := lerpf(0.12, 0.5, grown)
	_plant.scale = Vector3.ONE * r * 2.0
	_plant.position.y = 0.2 + r
	_plant_mat.albedo_color = PLANT_RIPE if state == State.RIPE else PLANT_GREEN
