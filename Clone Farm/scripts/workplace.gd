## Something a Worker can walk up to and work: a garden bed, the cloning machine. Says which
## task it is waiting for, how long that task takes, and does it when the work is done.
## Workers stand just outside its square footprint, so nothing is done from a distance.
class_name Workplace
extends Node3D


func _ready() -> void:
	add_to_group("workplaces")


## Half the width of the square footprint.
func half_size() -> float:
	return 0.5


## The task this place is waiting for, or &"" when there is nothing to do.
func next_task() -> StringName:
	return &""


## Seconds of work `task` takes a worker at speed 1.
func work_time(_task: StringName) -> float:
	return 1.0


## Finishes `task` (the worker `by` has already spent its work time; null when called
## directly). Returns what it produced.
func perform(_task: StringName, _by: Worker = null) -> int:
	return 0
