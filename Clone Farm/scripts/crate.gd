## One unit of produção on the ground, dropped beside a bed by a harvest. Someone has to
## walk up, pick it up (PICK_UP) and carry it to the machine, the trough or the market.
class_name Crate
extends Workplace

const PICK_UP := &"pick_up"
const WORK_TIME := 0.5
const SIZE := 0.5


func _ready() -> void:
	super()
	add_to_group("crates")
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SIZE, SIZE, SIZE)
	mesh.mesh = box
	mesh.position.y = SIZE / 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.80, 0.62, 0.30)
	mesh.material_override = mat
	add_child(mesh)


func half_size() -> float:
	return SIZE / 2.0


func next_task() -> StringName:
	return PICK_UP


## Only a worker with room in its hands can pick it up.
func next_task_for(worker: Worker) -> StringName:
	return PICK_UP if worker.carrying < worker.capacity() and not is_queued_for_deletion() else &""


func work_time(_task: StringName) -> float:
	return WORK_TIME


func perform(task: StringName, by: Worker = null) -> int:
	if task != PICK_UP or by == null or is_queued_for_deletion():
		return 0
	by.carrying += by.keep_of(1)
	queue_free()
	return 0
