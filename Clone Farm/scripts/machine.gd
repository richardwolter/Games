## The cloning machine, also a Depot: carried produção delivered here is its stock, and a
## clone costs COST of it (docs/decisoes/2026-10-07-nucleo.md). The farmer, hands empty,
## stands at it for WORK_TIME and a clone comes out; the farm spawns it on `cloned`. A clone
## sent to be recycled walks in, works RECYCLE_TIME and is gone, giving back REFUND (always
## less than COST, so cloning in a loop never pays).
class_name Machine
extends Depot

const CLONE := &"clone"
const RECYCLE := &"recycle"
const COST := 3
const REFUND := 2
const WORK_TIME := 2.0
const RECYCLE_TIME := 2.0

signal cloned
signal recycled(clone: Clone)


func _ready() -> void:
	super()
	add_to_group("machines")


func _init() -> void:
	label = "Máquina"
	color = Color(0.55, 0.50, 0.70)


func tag_text() -> String:
	return "Máquina: %d (clone custa %d)" % [stock, COST]


func next_task() -> StringName:
	return CLONE if stock >= COST else &""


## Crates in hand go in; empty-handed, the farmer can clone.
func next_task_for(worker: Worker) -> StringName:
	if worker.carrying > 0:
		return DELIVER
	if worker is Clone and worker.recycling:
		return RECYCLE
	if worker is Farmer:
		return next_task()
	return &""


func work_time(task: StringName) -> float:
	if task == CLONE:
		return WORK_TIME
	if task == RECYCLE:
		return RECYCLE_TIME
	return super(task)


func perform(task: StringName, by: Worker = null) -> int:
	if task == CLONE:
		if stock >= COST:
			stock -= COST
			cloned.emit()
		return 0
	if task == RECYCLE:
		if by is Clone:
			stock += REFUND
			recycled.emit(by)
		return 0
	return super(task, by)


func _height() -> float:
	return 1.8
