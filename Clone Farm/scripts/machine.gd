## The cloning machine. A worker stands at it for WORK_TIME and a clone comes out, paid for
## in produção (docs/decisoes/2026-10-07-nucleo.md). The farm owns the stock, so it tells
## the machine whether a clone is affordable and does the paying and spawning on `cloned`.
class_name Machine
extends Workplace

const CLONE := &"clone"
const COST := 3
const WORK_TIME := 2.0
const SIZE := 1.6

signal cloned

## Set by the farm: true when the stock covers COST.
var can_afford: Callable = func() -> bool: return true


func _ready() -> void:
	super()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SIZE, 1.8, SIZE)
	mesh.mesh = box
	mesh.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.50, 0.70)
	mesh.material_override = mat
	add_child(mesh)
	var tag := Label3D.new()
	tag.text = "Máquina (%d produção)" % COST
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.01
	tag.font_size = 40
	tag.outline_size = 8
	tag.position.y = 2.3
	add_child(tag)


func half_size() -> float:
	return SIZE / 2.0


func next_task() -> StringName:
	return CLONE if can_afford.call() else &""


func work_time(_task: StringName) -> float:
	return WORK_TIME


func perform(task: StringName, _by: Worker = null) -> int:
	if task == CLONE and can_afford.call():
		cloned.emit()
	return 0
