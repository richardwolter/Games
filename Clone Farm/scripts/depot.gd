## Where carried produção ends up: a worker with crates in hand walks up and DELIVERs them
## (docs/decisoes/2026-10-07-nucleo.md: máquina, cocho, venda). The machine extends this
## with cloning; the trough lets clones EAT from its stock; the market turns it into money.
class_name Depot
extends Workplace

const DELIVER := &"deliver"
const EAT := &"eat"
const DELIVER_TIME := 0.5
const EAT_TIME := 1.0
const SIZE := 1.6

## Units of produção held (the market's is the money made).
var stock := 0
var label := ""
var color := Color(0.6, 0.6, 0.6)
## Its number key when choosing a Carregar destination (1 máquina, 2 cocho, 3 venda).
var slot := 0

var _tag: Label3D


func _ready() -> void:
	super()
	add_to_group("depots")
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SIZE, _height(), SIZE)
	mesh.mesh = box
	mesh.position.y = _height() / 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	add_child(mesh)
	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.pixel_size = 0.01
	_tag.font_size = 40
	_tag.outline_size = 8
	_tag.position.y = _height() + 0.5
	add_child(_tag)


func _process(_delta: float) -> void:
	_tag.text = tag_text()


func tag_text() -> String:
	return "%s: %d" % [label, stock]


func half_size() -> float:
	return SIZE / 2.0


## A hungry clone at the trough eats before it unloads; anyone else with crates delivers.
func next_task_for(worker: Worker) -> StringName:
	if is_trough() and worker is Clone and worker.wants_meal() \
			and stock >= worker.meal_size():
		return EAT
	if worker.carrying > 0:
		return DELIVER
	return &""


func work_time(task: StringName) -> float:
	return EAT_TIME if task == EAT else DELIVER_TIME


func perform(task: StringName, by: Worker = null) -> int:
	if by == null:
		return 0
	if task == DELIVER and by.carrying > 0:
		stock += by.carrying
		by.carrying = 0
	elif task == EAT and by is Clone:
		var take: int = by.meal_size()
		if stock >= take:
			stock -= take
			by.eat(take)
	return 0


func is_trough() -> bool:
	return is_in_group("troughs")


func _height() -> float:
	return 0.8
